import Base
import ./attachment_inventory.bend as Inventory
import ./attachment_extract.bend as Extract
import ./attachment_refs.bend as Ref
import ./archive_meta.bend as Meta
import ./domain.bend as Domain
import ./json.bend as Json
import ./brief_safe_text.bend as Safe

type Buffer is Data:
  Buffer{remaining: U32,reversed: List<&2,String>}

def consumed(allowed: Bool,left: U32,next: U32 -> Maybe<&2,U32>) -> Maybe<&2,U32>:
  match allowed:
    case False{}: None{}
    case True{}: next(left)

def consume(text: String,+left: U32) -> Maybe<&2,U32>:
  match text:
    case SNil{}: Some{left}
    case SCon{Chr{cp},rest}:
      +width = Ref.utf8_width(cp)
      consumed(U32.is_le(width,left),U32.sub(left,width),remaining => consume(rest,remaining))

def put_result(result: Maybe<&2,U32>,text: String,parts: List<&2,String>) -> Result<&2,&2,Inventory.Failure,Buffer>:
  match result:
    case Some{left}: Done{Buffer{left,text <> parts}}
    case None{}: Fail{Inventory.fail("attachment_output_limit",
      "Attachment inventory exceeds 262144 encoded UTF-8 bytes including newline; select fewer raw records. No records or occurrences were omitted")}

def put(+text: String,buffer: Buffer) -> Result<&2,&2,Inventory.Failure,Buffer>:
  Buffer{left,parts} = buffer
  put_result(consume(text,left),text,parts)

# JSON identity escapes preserve exact strings. Display names instead contain
# literal visible backslash-u escapes, so controls never rearrange native text.
def visible(text: String) -> String:
  match text:
    case SNil{}: ""
    case SCon{+c,rest}: Bool.pick(String,Safe.control(c),Safe.escaped(c),SCon{c,SNil{}}) ++ visible(rest)

def quote(text: String) -> String:
  visible(Json.quote(text))

def bool(value: Bool) -> String:
  Bool.pick(String,value,"true","false")

def last(parts: List<&2,String>,prior: String) -> String:
  match parts:
    case []: prior
    case value <> rest: last(rest,value)

def name(reference: Ref.Reference) -> String:
  match reference:
    case Ref.LocalPath{path}: visible(last(String.split(path,'/'),""))
    case Ref.LocalFileURL{_}: "Local file URL"
    case Ref.RemoteURL{_}: "Remote attachment"
    case Ref.InlineData{_,_,_}: "Inline attachment"
    case Ref.UnsupportedReference{_}: "Unsupported attachment"

def inline(check: Ref.InlineCheck) -> String:
  match check:
    case Ref.ValidBase64{encoded,decoded}:
      ",\"valid_base64\":true,\"encoded_characters\":" ++ U32.show(encoded) ++ ",\"decoded_bytes\":" ++ U32.show(decoded)
    case Ref.InvalidBase64{reason}:
      ",\"valid_base64\":false,\"encoding_issue\":" ++ quote(reason)

def reference_fields(reference: Ref.Reference) -> String:
  match reference:
    case Ref.LocalPath{_}: "\"type\":\"local_path\",\"availability\":\"external_bytes_uncaptured\""
    case Ref.LocalFileURL{_}: "\"type\":\"local_file_url\",\"availability\":\"external_bytes_uncaptured\""
    case Ref.RemoteURL{_}: "\"type\":\"remote_url\",\"availability\":\"not_fetched\""
    case Ref.InlineData{media,encoding,check}:
      "\"type\":\"inline\",\"availability\":\"representation_retained_in_raw\",\"media_type\":" ++ quote(media) ++
        ",\"encoding\":" ++ quote(encoding) ++ inline(check)
    case Ref.UnsupportedReference{reason}:
      "\"type\":\"unsupported\",\"availability\":\"unknown\",\"reason\":" ++ quote(reason)

def reference(+value: Ref.Reference) -> String:
  "{" ++ reference_fields(value) ++ ",\"name\":" ++ quote(name(value)) ++ ",\"summary\":" ++ quote(Ref.summary(value)) ++ "}"

def occurrence(value: Extract.Occurrence) -> String:
  Extract.Occurrence{ordinal,path,kind,value} = value
  "{\"reference\":" ++ U32.show(ordinal) ++ ",\"path\":" ++ quote(path) ++
    ",\"kind\":" ++ quote(kind) ++ ",\"descriptor\":" ++ reference(value) ++ "}"

def occurrences(rows: List<&2,Extract.Occurrence>,buffer: Buffer,first: Bool) -> Result<&2,&2,Inventory.Failure,Buffer>:
  match rows:
    case []: Done{buffer}
    case value <> rest:
      do Result<&2,&2,Inventory.Failure,Buffer>:
        next : Buffer <- put(Bool.pick(String,first,"",",") ++ occurrence(value),buffer)
        occurrences(rest,next,False{})

def coverage(value: Extract.ScanCoverage) -> String:
  match value:
    case Extract.CompleteScan{}:
      "{\"state\":\"extracted\",\"complete\":true,\"truncated\":false}"
    case Extract.PartialScan{reason,truncated}:
      "{\"state\":\"extracted\",\"complete\":false,\"truncated\":" ++ bool(truncated) ++
        ",\"reason\":" ++ quote(reason) ++ "}"

def body(value: Inventory.Body,buffer: Buffer) -> Result<&2,&2,Inventory.Failure,Buffer>:
  match value:
    case Inventory.Extracted{Extract.Report{rows,scan}}:
      do Result<&2,&2,Inventory.Failure,Buffer>:
        opened : Buffer <- put("\"coverage\":" ++ coverage(scan) ++ ",\"occurrences\":[",buffer)
        written : Buffer <- occurrences(rows,opened,True{})
        put("]",written)
    case Inventory.OversizedFragment{}:
      put("\"coverage\":{\"state\":\"oversized_fragment\",\"complete\":false,\"truncated\":false},\"occurrences\":[]",buffer)
    case Inventory.InvalidUtf8{}:
      put("\"coverage\":{\"state\":\"invalid_utf8\",\"complete\":false,\"truncated\":false},\"occurrences\":[]",buffer)

def record(value: Inventory.Record,buffer: Buffer) -> Result<&2,&2,Inventory.Failure,Buffer>:
  Inventory.Record{ordinal,offset,length,digest,value} = value
  do Result<&2,&2,Inventory.Failure,Buffer>:
    opened : Buffer <- put("{\"record\":" ++ U32.show(ordinal) ++ ",\"offset\":" ++ U32.show(offset) ++ ",\"length\":" ++ U32.show(length) ++
      ",\"digest\":" ++ quote(digest) ++ ",",buffer)
    written : Buffer <- body(value,opened)
    put("}",written)

def records(rows: List<&2,Inventory.Record>,buffer: Buffer,first: Bool) -> Result<&2,&2,Inventory.Failure,Buffer>:
  match rows:
    case []: Done{buffer}
    case value <> rest:
      do Result<&2,&2,Inventory.Failure,Buffer>:
        opened : Buffer <- put(Bool.pick(String,first,"",","),buffer)
        written : Buffer <- record(value,opened)
        records(rest,written,False{})

def capture(value: Meta.Header) -> String:
  Meta.Header{snapshot,source,generation,provider,locator,extent,total,_,_,_,encoding} = value
  "{\"provider\":" ++ quote(provider) ++ ",\"source_id\":" ++ quote(source) ++ ",\"source\":" ++ quote(locator) ++
    ",\"generation\":" ++ quote(generation) ++ ",\"snapshot\":" ++ quote(snapshot) ++ ",\"extent\":" ++ quote(U32.show(extent)) ++
    ",\"total_records\":" ++ U32.show(total) ++ ",\"encoding\":" ++ quote(encoding) ++ ",\"byte_space\":\"logical_source_bytes\"}"

def next(value: Maybe<&2,U32>) -> String:
  match value:
    case None{}: "null"
    case Some{ordinal}: U32.show(ordinal)

def encoded_counts(page: Inventory.Page,+complete: U32,refs: U32) -> String:
  Inventory.Page{+header,+start,requested,+selected,rows} = page
  Meta.Header{_,_,_,_,_,_,+total,_,_,_,_} = header
  "{\"kind\":\"attachment_inventory\",\"profile\":" ++ quote(Extract.version()) ++
    ",\"capture\":" ++ capture(header) ++ ",\"page\":{\"start\":" ++ U32.show(start) ++
    ",\"requested\":" ++ U32.show(requested) ++ ",\"selected\":" ++ U32.show(selected) ++
    ",\"verified\":" ++ U32.show(selected) ++ ",\"next\":" ++ next(Inventory.next(total,start,selected)) ++
    ",\"covers_snapshot_record_range\":" ++ bool(U32.is_eq(start,0) && U32.is_eq(selected,total)) ++
    ",\"complete_extraction_records\":" ++ U32.show(complete) ++ ",\"partial_extraction_records\":" ++ U32.show(U32.sub(selected,complete)) ++
    ",\"returned_occurrences\":" ++ U32.show(refs) ++ "},\"records\":["

def encoded_pair(page: Inventory.Page,pair: U32 & U32) -> String:
  (complete,refs) = pair
  encoded_counts(page,complete,refs)

def finish(buffer: Buffer) -> String:
  Buffer{_,parts} = buffer
  String.join(List.reverse(&2,String,parts),"")

def json(+page: Inventory.Page) -> Result<&2,&2,Inventory.Failure,String>:
  Inventory.Page{_,_,_,_,+rows} = page
  do Result<&2,&2,Inventory.Failure,String>:
    opened : Buffer <- put(encoded_pair(page,Inventory.record_counts(rows,0,0)),Buffer{262143,[]})
    written : Buffer <- records(rows,opened,True{})
    closed : Buffer <- put("],\"verification\":\"Selected retained raw records and immediate predecessors verified; archive metadata checked, compressed bytes and unselected raw ranges not reverified. External files not read.\"}",written)
    return finish(closed)

def valid_rows(rows: List<&2,Inventory.Record>,+ordinal: U32) -> Bool:
  match rows:
    case []: True{}
    case Inventory.Record{actual,_,+n,_,body} <> rest:
      U32.is_eq(actual,ordinal) && U32.is_gt(n,0) && U32.is_le(n,262144) &&
        U32.is_le(Inventory.body_count(body),64) && valid_rows(rest,U32.inc(ordinal))

def valid(page: Inventory.Page) -> Bool:
  Inventory.Page{+header,+start,+requested,+selected,+rows} = page
  Meta.Header{_,_,_,_,_,_,total,_,_,accepted,_} = header
  Meta.header_valid(header) && accepted && U32.is_gt(requested,0) && U32.is_le(requested,40) &&
    U32.is_eq(selected,Domain.bounded_count(start,requested,total)) &&
    Nat.is_eq(List.length(&2,Inventory.Record,rows),U32.to_nat(selected)) && valid_rows(rows,start)

def encode_valid(valid: Bool,page: Inventory.Page) -> Result<&2,&2,Inventory.Failure,String>:
  match valid:
    case False{}: Fail{Inventory.fail("attachment_page_invalid","Attachment page violates its immutable raw-range contract")}
    case True{}: json(page)

# Budget each encoded chunk before retaining it; concatenate only a completely
# successful <=262143-byte result. One bounded occurrence is the largest chunk.
# The reserved final byte covers IO.print's newline, never just displayed names.
def encode(+page: Inventory.Page) -> Result<&2,&2,Inventory.Failure,String>:
  encode_valid(valid(page),page)

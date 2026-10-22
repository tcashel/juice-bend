# Pure attachment view/transport state. Bytes and external references never enter
# this model. Raw-record scope is explicit and distinct from reader filters.
import Base
import ./json.bend as J
import ./gui_settings.bend as Shape
import ./provenance.bend as P
import ./attachment_refs.bend as Ref
import ./domain.bend as Domain
import ./brief_safe_text.bend as Safe

type Anchor is Data:
  Anchor{snapshot: String,start: U32,count: U32}

type OccurrenceKey is Data:
  OccurrenceKey{record: U32,reference: U32,path: String,offset: U32,length: U32,digest: String,
    media: String,bytes: U32,exportable: Bool}

type Item is Data:
  Item{title: String,detail: String,key: List<&2,OccurrenceKey>}

type Page is Data:
  Page{capture: J.Json,start: U32,selected: U32,items: List<&2,Item>,complete: U32,partial: U32,occurrences: U32}

type Model is Data:
  Model{anchor: Anchor,cursor: U32,nonce: U32,phase: U32,page: List<&2,Page>,selected: U32,
    request: List<&2,String>,message: String}

def scope() -> String:
  "All attachment references in these captured records"

def profile() -> String: "attachment-occurrences-v1"

def shown(text: String) -> String:
  match text:
    case SNil{}: ""
    case SCon{+c,rest}: Bool.pick(String,Safe.control(c),Safe.escaped(c),SCon{c,SNil{}}) ++ shown(rest)

def bounded(value: J.Json,limit: U32) -> Bool:
  match value:
    case J.JString{text}: Ref.bounded(text,limit)
    case _: False{}

def parsed_number(value: Maybe<&2,U32>) -> U32:
  match value:
    case Some{value}: value
    case None{}: 0

def number(value: J.Json) -> U32:
  parsed_number(Domain.parse_u32(J.text(value)))

def numeric(value: J.Json) -> Bool:
  match value:
    case J.JNumber{+text}: P.decimal_valid(text) && Bool.not(Cmp.is_gt(P.decimal_compare(text,"4294967295")))
    case _: False{}

def identity(value: J.Json) -> Bool:
  match value:
    case J.JString{+text}: P.decimal_valid(text) && Bool.not(String.eq(text,"0")) && Bool.not(Cmp.is_gt(P.decimal_compare(text,"9223372036854775807")))
    case _: False{}

def hex_chars(text: String) -> Bool:
  match text:
    case SNil{}: True{}
    case SCon{Chr{+code},rest}: ((code >= 48 && code <= 57 : U32) || (code >= 97 && code <= 102 : U32)) && hex_chars(rest)

def commitment(+text: String) -> Bool:
  Nat.is_eq(String.length(text),64n) && hex_chars(text)

def true(value: J.Json) -> Bool:
  match value:
    case J.JBool{flag}: flag
    case _: False{}

def same_bool(value: J.Json,expected: Bool) -> Bool:
  match value expected:
    case J.JBool{True{}} True{}: True{}
    case J.JBool{False{}} False{}: True{}
    case _ _: False{}

def guard(ok: Bool,message: String) -> Result<&2,&2,String,Unit>:
  Bool.pick(Result<&2,&2,String,Unit>,ok,Done{Unit{}},Fail{message})

def anchor_valid(anchor: Anchor) -> Bool:
  Anchor{snapshot,+start,+count} = anchor
  identity(J.JString{snapshot}) && U32.is_le(count,40) && U32.is_le(count,U32.sub(4294967295,start))

def anchor_snapshot(anchor: Anchor) -> String:
  Anchor{snapshot,_,_} = anchor
  snapshot

def anchor_start(anchor: Anchor) -> U32:
  Anchor{_,start,_} = anchor
  start

def anchor_count(anchor: Anchor) -> U32:
  Anchor{_,_,count} = anchor
  count

def initial(+anchor: Anchor) -> Model:
  Anchor{_,start,count} = anchor
  Model{anchor,start,0,Bool.pick(U32,U32.is_eq(count,0),2,0),[],0,[],""}

def anchor(model: Model) -> Anchor:
  Model{anchor,_,_,_,_,_,_,_} = model
  anchor

def phase(model: Model) -> U32:
  Model{_,_,_,phase,_,_,_,_} = model
  phase

def nonce(model: Model) -> U32:
  Model{_,_,nonce,_,_,_,_,_} = model
  nonce

def request(model: Model) -> List<&2,String>:
  Model{_,_,_,_,_,_,request,_} = model
  request

def page(model: Model) -> List<&2,Page>:
  Model{_,_,_,_,page,_,_,_} = model
  page

def cursor(model: Model) -> U32:
  Model{_,cursor,_,_,_,_,_,_} = model
  cursor

def page_count(anchor: Anchor,+cursor: U32) -> U32:
  Anchor{_,+start,+count} = anchor
  Bool.pick(U32,U32.is_ge(cursor,start) && U32.is_le(U32.sub(cursor,start),count),
    U32.min(10,U32.sub(count,U32.sub(cursor,start))),0)

def args(+anchor: Anchor,+cursor: U32) -> List<&2,String>:
  Anchor{snapshot,_,_} = anchor
  ["attachments",snapshot,U32.show(cursor),U32.show(page_count(anchor,cursor))]

def begin(+model: Model,+cursor: U32,nonce: U32) -> Model:
  Model{+anchor,_,_,_,page,_,_,_} = model
  Model{anchor,cursor,nonce,1,page,0,args(anchor,cursor),""}

def last_cursor(pages: List<&2,Page>,fallback: U32) -> U32:
  match pages:
    case [Page{_,cursor,_,_,_,_,_}]: cursor
    case _: fallback

def failed(model: Model,message: String) -> Model:
  Model{anchor,cursor,nonce,_,+page,selected,_,_} = model
  Model{anchor,last_cursor(page,cursor),nonce,2,page,selected,[],message}

def same_args(a: List<&2,String>,b: List<&2,String>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case x <> xs y <> ys: String.eq(x,y) && same_args(xs,ys)
    case _ _: False{}

def capture_valid(+value: J.Json,+snapshot: String) -> Bool:
  Shape.exact_object(value,["provider","source_id","source","generation","snapshot","extent","total_records","encoding","byte_space"]) &&
    (Shape.text_is(J.field(value,"provider"),"claude") || Shape.text_is(J.field(value,"provider"),"codex")) &&
    identity(J.field(value,"source_id")) && identity(J.field(value,"generation")) &&
    Shape.text_is(J.field(value,"snapshot"),snapshot) && identity(J.field(value,"snapshot")) &&
    bounded(J.field(value,"source"),4096) && String.starts_with(J.get(value,"source"),"/") &&
    bounded(J.field(value,"extent"),10) && numeric(J.JNumber{J.get(value,"extent")}) && numeric(J.field(value,"total_records")) &&
    (Shape.text_is(J.field(value,"encoding"),"identity") || Shape.text_is(J.field(value,"encoding"),"zstd-jsonl-v1")) &&
    Shape.text_is(J.field(value,"byte_space"),"logical_source_bytes")

def same_fields(names: List<&2,String>,+a: J.Json,+b: J.Json) -> Bool:
  match names:
    case []: True{}
    case +name <> rest: String.eq(J.text(J.field(a,name)),J.text(J.field(b,name))) && same_fields(rest,a,b)

def same_capture(a: J.Json,b: J.Json) -> Bool:
  same_fields(["provider","source_id","source","generation","snapshot","extent","total_records","encoding","byte_space"],a,b)

def prior_capture(pages: List<&2,Page>,capture: J.Json) -> Bool:
  match pages:
    case []: True{}
    case [Page{prior,_,_,_,_,_,_}]: same_capture(prior,capture)
    case _: False{}

def coverage_valid(+value: J.Json) -> Bool:
  (Shape.exact_object(value,["state","complete","truncated"]) &&
    ((Shape.text_is(J.field(value,"state"),"extracted") && same_bool(J.field(value,"complete"),True{}) && same_bool(J.field(value,"truncated"),False{})) ||
     ((Shape.text_is(J.field(value,"state"),"invalid_utf8") || Shape.text_is(J.field(value,"state"),"oversized_fragment")) &&
       same_bool(J.field(value,"complete"),False{}) && same_bool(J.field(value,"truncated"),False{})))) ||
    (Shape.exact_object(value,["state","complete","truncated","reason"]) && Shape.text_is(J.field(value,"state"),"extracted") &&
      same_bool(J.field(value,"complete"),False{}) && Shape.boolean(J.field(value,"truncated")) && bounded(J.field(value,"reason"),256))

def common_descriptor(+value: J.Json) -> Bool:
  bounded(J.field(value,"name"),32768) && bounded(J.field(value,"summary"),1024)

def descriptor_type(kind: String,+value: J.Json) -> Bool:
  match kind:
    case "local_path": Shape.exact_object(value,["type","availability","name","summary"]) && Shape.text_is(J.field(value,"availability"),"external_bytes_uncaptured")
    case "local_file_url": Shape.exact_object(value,["type","availability","name","summary"]) && Shape.text_is(J.field(value,"availability"),"external_bytes_uncaptured")
    case "remote_url": Shape.exact_object(value,["type","availability","name","summary"]) && Shape.text_is(J.field(value,"availability"),"not_fetched")
    case "unsupported": Shape.exact_object(value,["type","availability","name","summary","reason"]) && Shape.text_is(J.field(value,"availability"),"unknown") && bounded(J.field(value,"reason"),256)
    case "inline":
      Shape.text_is(J.field(value,"availability"),"representation_retained_in_raw") && bounded(J.field(value,"media_type"),127) &&
        Shape.text_is(J.field(value,"encoding"),"base64") &&
        ((Shape.exact_object(value,["type","availability","media_type","encoding","valid_base64","encoded_characters","decoded_bytes","name","summary"]) &&
          same_bool(J.field(value,"valid_base64"),True{}) && numeric(J.field(value,"encoded_characters")) && U32.is_le(number(J.field(value,"encoded_characters")),1048576) &&
          numeric(J.field(value,"decoded_bytes")) && U32.is_le(number(J.field(value,"decoded_bytes")),786432)) ||
        (Shape.exact_object(value,["type","availability","media_type","encoding","valid_base64","encoding_issue","name","summary"]) &&
          same_bool(J.field(value,"valid_base64"),False{}) && bounded(J.field(value,"encoding_issue"),256)))
    case _: False{}

def descriptor_valid(+value: J.Json) -> Bool:
  common_descriptor(value) && descriptor_type(J.get(value,"type"),value)

def occurrence_valid(+value: J.Json,ordinal: U32) -> Bool:
  Shape.exact_object(value,["reference","path","kind","descriptor"]) && Shape.number_is(J.field(value,"reference"),U32.show(ordinal)) &&
    bounded(J.field(value,"path"),2048) && String.starts_with(J.get(value,"path"),"/") &&
    (Shape.text_is(J.field(value,"kind"),"image") || Shape.text_is(J.field(value,"kind"),"document") ||
      Shape.text_is(J.field(value,"kind"),"input_image") || Shape.text_is(J.field(value,"kind"),"image_url")) && descriptor_valid(J.field(value,"descriptor"))

def occurrences_valid(items: List<&2,J.Json>,+ordinal: U32) -> Bool:
  match items:
    case []: True{}
    case value <> rest: U32.is_lt(ordinal,64) && occurrence_valid(value,ordinal) && occurrences_valid(rest,U32.inc(ordinal))

def array(value: J.Json) -> Bool:
  match value:
    case J.JArray{_}: True{}
    case _: False{}

def size(value: J.Json) -> U32:
  U32.from_nat(List.length(&2,J.Json,J.items(value)))

def record_valid(+value: J.Json,+ordinal: U32,+extent: U32) -> Bool:
  Shape.exact_object(value,["record","offset","length","digest","coverage","occurrences"]) &&
    Shape.number_is(J.field(value,"record"),U32.show(ordinal)) && numeric(J.field(value,"offset")) && numeric(J.field(value,"length")) &&
    U32.is_gt(number(J.field(value,"length")),0) &&
    U32.is_le(number(J.field(value,"offset")),extent) && U32.is_le(number(J.field(value,"length")),U32.sub(extent,number(J.field(value,"offset")))) &&
    (U32.is_ne(ordinal,0) || U32.is_eq(number(J.field(value,"offset")),0)) &&
    bounded(J.field(value,"digest"),64) && commitment(J.get(value,"digest")) && coverage_valid(J.field(value,"coverage")) &&
    array(J.field(value,"occurrences")) && occurrences_valid(J.items(J.field(value,"occurrences")),0) &&
    (Shape.text_is(J.field(J.field(value,"coverage"),"state"),"extracted") || U32.is_eq(size(J.field(value,"occurrences")),0))

def adjacent(expected: Maybe<&2,U32>,actual: U32) -> Bool:
  match expected:
    case None{}: True{}
    case Some{prior}: U32.is_eq(prior,actual)

def records_valid(items: List<&2,J.Json>,+ordinal: U32,+extent: U32,expected: Maybe<&2,U32>) -> Bool:
  match items:
    case []: True{}
    case +value <> rest:
      record_valid(value,ordinal,extent) && adjacent(expected,number(J.field(value,"offset"))) &&
        records_valid(rest,U32.inc(ordinal),extent,Some{U32.add(number(J.field(value,"offset")),number(J.field(value,"length")))})

def totals(items: List<&2,J.Json>,complete: U32,refs: U32) -> U32 & U32:
  match items:
    case []: (complete,refs)
    case +value <> rest: totals(rest,U32.add(complete,Bool.to_u32(true(J.field(J.field(value,"coverage"),"complete")))),U32.add(refs,size(J.field(value,"occurrences"))))

def counts_valid(+value: J.Json,pair: U32 & U32,+selected: U32) -> Bool:
  (+complete,refs) = pair
  Shape.number_is(J.field(value,"complete_extraction_records"),U32.show(complete)) &&
    Shape.number_is(J.field(value,"partial_extraction_records"),U32.show(U32.sub(selected,complete))) &&
    Shape.number_is(J.field(value,"returned_occurrences"),U32.show(refs))

def next_valid(value: J.Json,+next: U32,total: U32) -> Bool:
  match value:
    case J.JNull{}: U32.is_ge(next,total)
    case J.JNumber{text}: String.eq(text,U32.show(next)) && U32.is_lt(next,total)
    case _: False{}

def page_valid(+value: J.Json,+anchor: Anchor,+cursor: U32) -> Bool:
  Anchor{+snapshot,+start,+count} = anchor
  +capture = J.field(value,"capture")
  +page = J.field(value,"page")
  +selected = page_count(anchor,cursor)
  Shape.exact_object(value,["kind","profile","capture","page","records","verification"]) &&
    Shape.text_is(J.field(value,"kind"),"attachment_inventory") && Shape.text_is(J.field(value,"profile"),profile()) &&
    capture_valid(capture,snapshot) && U32.is_le(start,number(J.field(capture,"total_records"))) &&
    U32.is_le(count,U32.sub(number(J.field(capture,"total_records")),start)) &&
    Shape.exact_object(page,["start","requested","selected","verified","next","covers_snapshot_record_range","complete_extraction_records","partial_extraction_records","returned_occurrences"]) &&
    Shape.number_is(J.field(page,"start"),U32.show(cursor)) && Shape.number_is(J.field(page,"requested"),U32.show(selected)) &&
    Shape.number_is(J.field(page,"selected"),U32.show(selected)) && Shape.number_is(J.field(page,"verified"),U32.show(selected)) &&
    next_valid(J.field(page,"next"),U32.add(cursor,selected),number(J.field(capture,"total_records"))) &&
    same_bool(J.field(page,"covers_snapshot_record_range"),U32.is_eq(cursor,0) && U32.is_eq(selected,number(J.field(capture,"total_records")))) &&
    array(J.field(value,"records")) && U32.is_eq(size(J.field(value,"records")),selected) &&
    records_valid(J.items(J.field(value,"records")),cursor,number(J.field(capture,"extent")),None{}) &&
    counts_valid(page,totals(J.items(J.field(value,"records")),0,0),selected) && bounded(J.field(value,"verification"),1024)

def scope_text(anchor: Anchor) -> String:
  Anchor{snapshot,start,count} = anchor
  scope() ++ "\nSnapshot " ++ snapshot ++ " | physical records " ++ U32.show(start) ++ " + " ++ U32.show(count) ++
    "\nRepository, role and time filters do not apply here.\nBack restores the original filtered reader and text selection.\n\n"

def byte_range(+value: J.Json) -> String:
  "Physical record " ++ J.get(value,"record") ++ " | logical bytes " ++ J.get(value,"offset") ++
    ".." ++ U32.show(U32.add(number(J.field(value,"offset")),number(J.field(value,"length")))) ++
    " (end exclusive)\nRaw SHA256: " ++ J.get(value,"digest") ++ "\n"

def coverage_text(+value: J.Json) -> String:
  Bool.pick(String,true(J.field(value,"complete")),"Known attachment containers fully scanned.",
    "Partial attachment coverage: " ++ shown(J.get(value,"state")) ++ ". " ++ shown(J.get(value,"reason")) ++
    "\nAdditional references may exist; total is unknown.")

def available(+descriptor: J.Json) -> Bool:
  Shape.text_is(J.field(descriptor,"type"),"inline") && same_bool(J.field(descriptor,"valid_base64"),True{})

def occurrence_item(+raw: J.Json,+value: J.Json) -> Item:
  +descriptor = J.field(value,"descriptor")
  +ready = available(descriptor)
  Item{"  " ++ shown(J.get(value,"kind")) ++ " " ++ J.get(value,"reference") ++ " | " ++ String.take(shown(J.get(descriptor,"name")),40n),
    byte_range(raw) ++ "Reference " ++ J.get(value,"reference") ++ "\nStructural path: " ++ shown(J.get(value,"path")) ++
    "\n\n" ++ shown(J.get(descriptor,"summary")) ++
    Bool.pick(String,ready,"\nExport original bytes saves the retained inline representation as a new private file.",
      "\nByte export is unavailable for this reference. No external file is read and no URL is fetched.") ++
    "\n\n" ++ coverage_text(J.field(raw,"coverage")),
    [OccurrenceKey{number(J.field(raw,"record")),number(J.field(value,"reference")),J.get(value,"path"),number(J.field(raw,"offset")),number(J.field(raw,"length")),J.get(raw,"digest"),
      J.get(descriptor,"media_type"),number(J.field(descriptor,"decoded_bytes")),ready}]}

def occurrence_items(items: List<&2,J.Json>,+raw: J.Json) -> List<&2,Item>:
  match items:
    case []: []
    case value <> rest: occurrence_item(raw,value) <> occurrence_items(rest,raw)

def record_items(+value: J.Json) -> List<&2,Item>:
  +count = size(J.field(value,"occurrences"))
  Item{"Record " ++ J.get(value,"record") ++ " | " ++ U32.show(count) ++ " references" ++
      Bool.pick(String,true(J.field(J.field(value,"coverage"),"complete")),""," | partial"),
    byte_range(value) ++ "\n" ++ coverage_text(J.field(value,"coverage")) ++
    "\nRecognized references in this record: " ++ U32.show(count) ++ ".",[]} <>
    occurrence_items(J.items(J.field(value,"occurrences")),value)

def items(records: List<&2,J.Json>) -> List<&2,Item>:
  match records:
    case []: []
    case value <> rest: List.append(&2,Item,record_items(value),items(rest))

def decoded_page(+value: J.Json) -> Page:
  +meta = J.field(value,"page")
  Page{J.field(value,"capture"),number(J.field(meta,"start")),number(J.field(meta,"selected")),items(J.items(J.field(value,"records"))),
    number(J.field(meta,"complete_extraction_records")),number(J.field(meta,"partial_extraction_records")),number(J.field(meta,"returned_occurrences"))}

def apply_valid(valid: Bool,model: Model,value: J.Json) -> Model:
  match valid:
    case False{}: failed(model,"Attachment reply did not match the exact captured range or bounded schema; no attachment was selected.")
    case True{}:
      Model{anchor,cursor,nonce,_,_,_,_,_} = model
      Model{anchor,cursor,nonce,2,[decoded_page(value)],0,[],""}

def apply(+model: Model,result: Result<&2,&2,String,J.Json>) -> Model:
  match result:
    case Fail{message}: failed(model,message)
    case Done{+value}: apply_valid(U32.is_eq(phase(model),1) && anchor_valid(anchor(model)) &&
      same_args(request(model),args(anchor(model),cursor(model))) && page_valid(value,anchor(model),cursor(model)) && prior_capture(page(model),J.field(value,"capture")),model,value)

def titles(items: List<&2,Item>) -> List<&2,String>:
  match items:
    case []: []
    case Item{title,_,_} <> rest: title <> titles(rest)

def rows(model: Model) -> List<&2,String>:
  Model{_,_,_,_,page,_,_,_} = model
  match page:
    case [Page{_,_,_,items,_,_,_}]: titles(items)
    case _: []

def at(items: List<&2,Item>,index: Nat) -> Maybe<&2,Item>:
  match items index:
    case [] _: None{}
    case item <> _ 0n: Some{item}
    case _ <> rest 1n+left: at(rest,left)

def selected(model: Model) -> Maybe<&2,Item>:
  Model{_,_,_,_,page,index,_,_} = model
  match page:
    case [Page{_,_,_,items,_,_,_}]: at(items,U32.to_nat(index))
    case _: None{}

def selected_index(model: Model) -> U32:
  Model{_,_,_,_,_,index,_,_} = model
  index

def key(value: Maybe<&2,Item>) -> Maybe<&2,OccurrenceKey>:
  match value:
    case Some{Item{_,_,[key]}}: Some{key}
    case _: None{}

def key_exportable(value: Maybe<&2,OccurrenceKey>) -> Bool:
  match value:
    case Some{OccurrenceKey{_,_,_,_,_,_,_,_,ready}}: ready
    case _: False{}

def exportable(+model: Model) -> Bool:
  U32.is_eq(phase(model),2) && key_exportable(key(selected(model)))

def choose(model: Model,index: U32) -> Model:
  Model{anchor,cursor,nonce,phase,page,_,request,message} = model
  Model{anchor,cursor,nonce,phase,page,index,request,message}

def detail(value: Maybe<&2,Item>) -> String:
  match value:
    case Some{Item{_,text,_}}: text
    case _: "No attachment occurrence is selected. Empty and partial raw records remain visible as coverage entries."

def capture_text(+capture: J.Json) -> String:
  "Capture: " ++ shown(J.get(capture,"provider")) ++ " | source " ++ J.get(capture,"source_id") ++ " | generation " ++ J.get(capture,"generation") ++
    " | snapshot " ++ J.get(capture,"snapshot") ++ "\nSource: " ++ shown(J.get(capture,"source")) ++
    "\nLogical extent: " ++ J.get(capture,"extent") ++ " bytes | total records: " ++ J.get(capture,"total_records") ++
    "\nEncoding: " ++ shown(J.get(capture,"encoding")) ++ " | byte space: logical source bytes\n" ++
    "Selected raw records and immediate predecessors verified; archive metadata checked.\n" ++
    "Compressed container bytes and other raw ranges were not reverified.\n" ++
    "External files were not read; URLs were not fetched.\n\n"

def summary(page: List<&2,Page>) -> String:
  match page:
    case [Page{_,start,count,_,complete,partial,refs}]:
      "Showing physical records " ++ U32.show(start) ++ " + " ++ U32.show(count) ++ ". " ++ U32.show(refs) ++
      " recognized references.\n" ++ U32.show(complete) ++ " complete records; " ++ U32.show(partial) ++ " partial records.\n\n"
    case _: ""

def capture_details(pages: List<&2,Page>) -> String:
  match pages:
    case [Page{capture,_,_,_,_,_,_}]: "\n\n" ++ capture_text(capture)
    case _: ""

def text(+model: Model) -> String:
  Model{+anchor,_,_,+phase,+page,_,_,+message} = model
  scope_text(anchor) ++ Bool.pick(String,U32.is_eq(phase,1),"Reading verified retained records...\n\n","") ++
    Bool.pick(String,U32.is_eq(phase,3),"Exporting the explicitly selected retained inline bytes...\n\n","") ++
    summary(page) ++ detail(selected(model)) ++ capture_details(page) ++ Bool.pick(String,String.is_empty(message),"","\n\n" ++ shown(message))

def previous(+model: Model) -> Bool:
  start = anchor_start(anchor(model))
  U32.is_eq(phase(model),2) && U32.is_gt(cursor(model),start)

def next(+model: Model) -> Bool:
  start = anchor_start(anchor(model))
  count = anchor_count(anchor(model))
  U32.is_eq(phase(model),2) && U32.is_lt(U32.add(U32.sub(cursor(model),start),page_count(anchor(model),cursor(model))),count)

def next_cursor(+model: Model,forward: Bool) -> U32:
  +start = anchor_start(anchor(model))
  Bool.pick(U32,forward,U32.add(cursor(model),page_count(anchor(model),cursor(model))),
    U32.sub(cursor(model),U32.min(10,U32.sub(cursor(model),start))))

def export_args(snapshot: String,key: OccurrenceKey,destination: String) -> List<&2,String>:
  OccurrenceKey{record,reference,path,_,_,_,_,_,_} = key
  ["export-inline",snapshot,U32.show(record),U32.show(reference),path,destination]

def exporting(model: Model,request: List<&2,String>,nonce: U32) -> Model:
  Model{anchor,cursor,_,_,page,selected,_,_} = model
  Model{anchor,cursor,nonce,3,page,selected,request,""}

def ack_key(+value: J.Json,key: OccurrenceKey) -> Bool:
  OccurrenceKey{record,reference,path,offset,length,digest,media,bytes,ready} = key
  ready && Shape.number_is(J.field(value,"record"),U32.show(record)) && Shape.number_is(J.field(value,"reference"),U32.show(reference)) &&
    Shape.text_is(J.field(value,"path"),path) && Shape.number_is(J.field(value,"offset"),U32.show(offset)) &&
    Shape.number_is(J.field(value,"length"),U32.show(length)) && Shape.text_is(J.field(value,"raw_digest"),digest) &&
    Shape.text_is(J.field(value,"media_type"),media) && Shape.number_is(J.field(value,"decoded_bytes"),U32.show(bytes))

def ack_selected(+value: J.Json,page: List<&2,Page>,selected: Maybe<&2,OccurrenceKey>) -> Bool:
  match page selected:
    case [Page{capture,_,_,_,_,_,_}] Some{key}: same_capture(capture,J.field(value,"capture")) && ack_key(value,key)
    case _ _: False{}

def ack_args(args: List<&2,String>,+value: J.Json) -> Bool:
  match args:
    case "export-inline" <> snapshot <> record <> reference <> path <> destination <> []:
      Shape.text_is(J.field(J.field(value,"capture"),"snapshot"),snapshot) && Shape.number_is(J.field(value,"record"),record) &&
        Shape.number_is(J.field(value,"reference"),reference) && Shape.text_is(J.field(value,"path"),path) && Shape.text_is(J.field(value,"destination"),destination)
    case _: False{}

def ack_valid(+model: Model,+value: J.Json) -> Bool:
  snapshot = anchor_snapshot(anchor(model))
  U32.is_eq(phase(model),3) && Shape.exact_object(value,["kind","profile","capture","record","offset","length","raw_digest","reference","path","media_type","decoded_bytes","sha256","destination"]) &&
    Shape.text_is(J.field(value,"kind"),"attachment_inline_export") && Shape.text_is(J.field(value,"profile"),profile()) &&
    capture_valid(J.field(value,"capture"),snapshot) && bounded(J.field(value,"sha256"),64) && commitment(J.get(value,"sha256")) &&
    bounded(J.field(value,"destination"),4096) && String.starts_with(J.get(value,"destination"),"/") &&
    ack_args(request(model),value) && ack_selected(value,page(model),key(selected(model)))

def exported_valid(valid: Bool,model: Model,+value: J.Json) -> Model:
  match valid:
    case False{}: failed(model,"Export reply did not match the clicked occurrence and exact destination. The file may have been published; no success is assumed.")
    case True{}: failed(model,"Saved original inline bytes to " ++ J.get(value,"destination") ++ " | Bytes: " ++ J.get(value,"decoded_bytes") ++ " | SHA256: " ++ J.get(value,"sha256"))

def exported(+model: Model,result: Result<&2,&2,String,J.Json>) -> Model:
  match result:
    case Fail{message}: failed(model,message)
    case Done{+value}: exported_valid(ack_valid(model,value),model,value)

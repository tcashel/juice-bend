import Base
import ../src/json.bend as J
import ../src/domain.bend as D
import ../src/gui_settings.bend as S
import ../src/gui_attachments.bend as A

# Acceptance oracle only. Independent fixture tables admit actual bounded CLI
# receipts before the exact frozen presenter supplies expected clipboard text.
# No database/source/external attachment is opened, and no file is written.
# The presenter's exact transitive imports include unused SQL declarations.
type Choice is Data:
  Choice{raw: J.Json,occurrences: List<&2,J.Json>}

def checked(valid: Bool,message: String) -> IO(Unit):
  match valid:
    case True{}: IO.pure(Unit,Unit{})
    case False{}: IO.die(Unit,2,"Attachment native oracle: " ++ message)

def decoded(result: Result<&2,&2,String,String>) -> IO(String):
  match result:
    case Done{text}: IO.pure(String,text)
    case Fail{_}: IO.die(String,2,"Receipt is not strict UTF8")

def room(valid: Bool,file: File,total: U32,part: List<&2,U32>,chunks: List<&2,List<&2,U32>>,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(String)) -> IO(String):
  match valid:
    case False{}:
      do IO<String>:
        File.close(file)
        IO.die(String,2,"Receipt exceeds 262144 bytes")
    case True{}: next(file,total,part <> chunks)

def next_chunk(file: File,bytes: List<&2,U32>,+total: U32,chunks: List<&2,List<&2,U32>>,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(String)) -> IO(String):
  match bytes:
    case []:
      do IO<String>:
        File.close(file)
        decoded(D.decode(List.concat(&2,U32,List.reverse(&2,List<&2,U32>,chunks))))
    case byte <> rest:
      +part = {byte <> rest : List<&2,U32>}
      +size = U32.from_nat(List.length(&2,U32,part))
      room(U32.is_le(size,U32.sub(262144,total)),file,U32.add(total,size),part,chunks,next)

def read_result(got: File & Result<&1,&1,U32 & String,List<&2,U32>>,total: U32,chunks: List<&2,List<&2,U32>>,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(String)) -> IO(String):
  (file,result) = got
  match result:
    case Fail{_}:
      do IO<String>:
        File.close(file)
        IO.die(String,2,"Cannot read receipt")
    case Done{bytes}: next_chunk(file,bytes,total,chunks,next)

def read(fuel: Nat,+total: U32,chunks: List<&2,List<&2,U32>>,file: File) -> IO(String):
  match fuel:
    case 0n:
      do IO<String>:
        File.close(file)
        IO.die(String,2,"Receipt read iteration bound exceeded")
    case 1n+left:
      do IO<String>:
        got : File & Result<&1,&1,U32 & String,List<&2,U32>> <-
          File.read_bytes(file,U32.min(4096,U32.add(U32.sub(262144,total),1)))
        read_result(got,total,chunks,f => n => parts => read(left,n,parts,f))

def parse(result: Result<&2,&2,String,J.Json>) -> IO(J.Json):
  match result:
    case Done{value}: IO.pure(J.Json,value)
    case Fail{_}: IO.die(J.Json,2,"Receipt is not bounded valid JSON")

def input(path: String) -> IO(J.Json):
  do IO<J.Json>:
    file : File <- IO.try(File,File.open(path,"r"))
    raw : String <- read(262145n,0,[],file)
    parse(J.parse(raw))

def number_result(value: Maybe<&2,U32>,text: String) -> IO(U32):
  match value:
    case Some{+number}:
      do IO<U32>:
        checked(String.eq(U32.show(number),text),"noncanonical integer")
        return number
    case None{}: IO.die(U32,2,"Expected canonical U32")

def number(+text: String) -> IO(U32):
  number_result(D.parse_u32(text),text)

def numeric_result(value: Maybe<&2,U32>,text: String) -> Bool:
  match value:
    case Some{number}: String.eq(U32.show(number),text)
    case None{}: False{}

def numeric(value: J.Json) -> Bool:
  match value:
    case J.JNumber{+text}: numeric_result(D.parse_u32(text),text)
    case _: False{}

def natural_result(value: Maybe<&2,U32>) -> U32:
  match value:
    case Some{number}: number
    case None{}: 0

def natural(value: J.Json) -> U32:
  natural_result(D.parse_u32(J.text(value)))

def text(+value: J.Json,key: String,expected: String) -> Bool:
  S.text_is(J.field(value,key),expected)

def count(value: J.Json,key: String,expected: U32) -> Bool:
  S.number_is(J.field(value,key),U32.show(expected))

def flag(value: J.Json,key: String,expected: Bool) -> Bool:
  S.bool_is(J.field(value,key),expected)

def hex(text: String) -> Bool:
  match text:
    case SNil{}: True{}
    case SCon{Chr{+c},rest}:
      ((c >= 48 && c <= 57 : U32) || (c >= 97 && c <= 102 : U32)) && hex(rest)

def hex_part(+text: String,length: Nat) -> Bool:
  Nat.is_eq(String.length(text),length) && hex(text)

def uuid(parts: List<&2,String>) -> Bool:
  match parts:
    case [a,b,c,d,e]: hex_part(a,8n) && hex_part(b,4n) && hex_part(c,4n) && hex_part(d,4n) && hex_part(e,12n)
    case _: False{}

def root_valid(+root: String) -> Bool:
  +prefix = {"/private/tmp/juice-bend-attachments-fixture-" : String}
  String.starts_with(root,prefix) && uuid(String.split(String.drop(root,String.length(prefix)),'-'))

def source(root: String) -> String:
  root ++ "/sources/attachment-fixture.jsonl.zst"

def fixture_valid(+root: String,+value: J.Json) -> Bool:
  root_valid(root) && text(value,"fixture","juice-bend-attachments-fixture-v1") && flag(value,"synthetic",True{}) &&
    text(value,"root",root) && text(value,"data_dir",root ++ "/library") && text(value,"source",source(root)) &&
    flag(value,"source_removed",True{}) && text(value,"snapshot","1") && text(value,"provider","claude") &&
    text(value,"encoding","zstd-jsonl-v1") && count(value,"physical_records",42) &&
    numeric(J.field(value,"logical_bytes")) && U32.is_gt(natural(J.field(value,"logical_bytes")),0) &&
    U32.is_le(natural(J.field(value,"logical_bytes")),131072) && count(value,"reader_start",0) &&
    count(value,"reader_selected",40) && count(value,"second_reader_start",40) && count(value,"second_reader_selected",2)

def capture_valid(+root: String,extent: U32,+value: J.Json) -> Bool:
  S.exact_object(value,["provider","source_id","source","generation","snapshot","extent","total_records","encoding","byte_space"]) &&
    text(value,"provider","claude") && text(value,"source_id","1") && text(value,"source",source(root)) &&
    text(value,"generation","1") && text(value,"snapshot","1") && text(value,"extent",U32.show(extent)) &&
    count(value,"total_records",42) && text(value,"encoding","zstd-jsonl-v1") && text(value,"byte_space","logical_source_bytes")

def partial_reason(record: U32) -> String:
  match record:
    case 12: "unsupported_content_block; total unknown"
    case 14: "unsupported_claude_record; total unknown"
    case 17: "content_not_text_or_array; total unknown"
    case 21: "unsupported_content_block; total unknown"
    case _: ""

def coverage_valid(+value: J.Json,+reason: String) -> Bool:
  text(value,"state","extracted") && flag(value,"truncated",False{}) &&
    Bool.pick(Bool,String.is_empty(reason),
      S.exact_object(value,["state","complete","truncated"]) && flag(value,"complete",True{}),
      S.exact_object(value,["state","complete","truncated","reason"]) && flag(value,"complete",False{}) && text(value,"reason",reason))

def has_reference(record: U32) -> Bool:
  match record:
    case 0: True{}
    case 2: True{}
    case 3: True{}
    case 4: True{}
    case 5: True{}
    case 6: True{}
    case 7: True{}
    case 8: True{}
    case 10: True{}
    case 15: True{}
    case 20: True{}
    case _: False{}

def expected_bytes(+record: U32) -> U32:
  Bool.pick(U32,U32.is_eq(record,2) || U32.is_eq(record,3),0,4)

def expected_sha(+record: U32) -> String:
  Bool.pick(String,U32.is_eq(record,2) || U32.is_eq(record,3),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "c5dbae22661af6db18a1f676db82a7ef7de46d27c3a263a872f00478b0d99fc4")

def expected_path(record: U32) -> String:
  match record:
    case 5: "/message/content/0/source/path"
    case 6: "/message/content/0/source/url"
    case 7: "/message/content/0/source"
    case 8: "/message/content/0/content/1/source/data"
    case _: "/message/content/0/source/data"

def inline_descriptor(+value: J.Json,+record: U32) -> Bool:
  S.exact_object(value,["type","availability","media_type","encoding","valid_base64","encoded_characters","decoded_bytes","name","summary"]) &&
    text(value,"type","inline") && text(value,"availability","representation_retained_in_raw") &&
    text(value,"media_type","application/octet-stream") && text(value,"encoding","base64") && flag(value,"valid_base64",True{}) &&
    count(value,"encoded_characters",Bool.pick(U32,U32.is_eq(expected_bytes(record),0),0,8)) && count(value,"decoded_bytes",expected_bytes(record)) &&
    text(value,"name","Inline attachment") && text(value,"summary","Inline bytes retained in raw record; valid base64, " ++ U32.show(expected_bytes(record)) ++ " decoded bytes")

def descriptor_valid(record: U32,+value: J.Json) -> Bool:
  match record:
    case 4:
      S.exact_object(value,["type","availability","media_type","encoding","valid_base64","encoding_issue","name","summary"]) &&
        text(value,"type","inline") && text(value,"availability","representation_retained_in_raw") &&
        text(value,"media_type","application/octet-stream") && text(value,"encoding","base64") && flag(value,"valid_base64",False{}) &&
        text(value,"encoding_issue","invalid_base64_padding") && text(value,"name","Inline attachment") &&
        text(value,"summary","Inline data retained in raw record; invalid_base64_padding")
    case 5:
      S.exact_object(value,["type","availability","name","summary"]) && text(value,"type","local_path") &&
        text(value,"availability","external_bytes_uncaptured") && text(value,"name","local-photo.png") &&
        text(value,"summary","Local file reference; external bytes not captured")
    case 6:
      S.exact_object(value,["type","availability","name","summary"]) && text(value,"type","remote_url") &&
        text(value,"availability","not_fetched") && text(value,"name","Remote attachment") && text(value,"summary","Remote reference; never fetched")
    case 7:
      S.exact_object(value,["type","availability","reason","name","summary"]) && text(value,"type","unsupported") &&
        text(value,"availability","unknown") && text(value,"reason","unsupported_attachment_source_type") && text(value,"name","Unsupported attachment") &&
        text(value,"summary","Unsupported attachment reference: unsupported_attachment_source_type")
    case other: inline_descriptor(value,other)

def occurrence_valid(+value: J.Json,+record: U32) -> Bool:
  S.exact_object(value,["reference","path","kind","descriptor"]) && count(value,"reference",0) &&
    text(value,"path",expected_path(record)) && text(value,"kind",Bool.pick(String,U32.is_eq(record,15),"document","image")) &&
    descriptor_valid(record,J.field(value,"descriptor"))

def occurrences_valid(value: J.Json,+record: U32) -> Bool:
  match value:
    case J.JArray{[]} : Bool.not(has_reference(record))
    case J.JArray{[occurrence]}: has_reference(record) && occurrence_valid(occurrence,record)
    case _: False{}

def position_valid(+value: J.Json,+record: U32,+extent: U32) -> Bool:
  numeric(J.field(value,"offset")) && numeric(J.field(value,"length")) && U32.is_gt(natural(J.field(value,"length")),0) &&
    U32.is_le(natural(J.field(value,"offset")),extent) &&
    U32.is_le(natural(J.field(value,"length")),U32.sub(extent,natural(J.field(value,"offset")))) &&
    (U32.is_ne(record,0) || count(value,"offset",0)) &&
    (U32.is_ne(record,41) || U32.is_eq(U32.add(natural(J.field(value,"offset")),natural(J.field(value,"length"))),extent))

def record_valid(+value: J.Json,+record: U32,extent: U32) -> Bool:
  S.exact_object(value,["record","offset","length","digest","coverage","occurrences"]) && count(value,"record",record) &&
    position_valid(value,record,extent) && S.text_is(J.field(value,"digest"),J.get(value,"digest")) && hex_part(J.get(value,"digest"),64n) &&
    coverage_valid(J.field(value,"coverage"),partial_reason(record)) && occurrences_valid(J.field(value,"occurrences"),record)

def adjacent(value: Maybe<&2,U32>,actual: U32) -> Bool:
  match value:
    case None{}: True{}
    case Some{expected}: U32.is_eq(expected,actual)

def records_valid(records: List<&2,J.Json>,+ordinal: U32,+extent: U32,prior: Maybe<&2,U32>,remaining: Nat) -> Bool:
  match records remaining:
    case [] 0n: True{}
    case +value <> rest 1n+left:
      record_valid(value,ordinal,extent) && adjacent(prior,natural(J.field(value,"offset"))) &&
        records_valid(rest,U32.inc(ordinal),extent,Some{U32.add(natural(J.field(value,"offset")),natural(J.field(value,"length")))},left)
    case _ _: False{}

def page_refs(start: U32) -> U32:
  match start:
    case 0: 8
    case 10: 2
    case 20: 1
    case _: 0

def page_complete(start: U32) -> U32:
  match start:
    case 10: 7
    case 20: 9
    case 40: 2
    case _: 10

def page_count(start: U32) -> U32:
  match start:
    case 40: 2
    case _: 10

def range_valid(+start: U32,+count: U32,+cursor: U32) -> Bool:
  (U32.is_eq(start,0) && U32.is_eq(count,40) &&
    (U32.is_eq(cursor,0) || U32.is_eq(cursor,10) || U32.is_eq(cursor,20) || U32.is_eq(cursor,30))) ||
    (U32.is_eq(start,40) && U32.is_eq(count,2) && U32.is_eq(cursor,40))

def next_valid(value: J.Json,+cursor: U32) -> Bool:
  match value:
    case J.JNull{}: U32.is_eq(cursor,40)
    case J.JNumber{number}: U32.is_ne(cursor,40) && String.eq(number,U32.show(U32.add(cursor,10)))
    case _: False{}

def meta_valid(+value: J.Json,+cursor: U32) -> Bool:
  S.exact_object(value,["start","requested","selected","verified","next","covers_snapshot_record_range","complete_extraction_records","partial_extraction_records","returned_occurrences"]) &&
    count(value,"start",cursor) && count(value,"requested",page_count(cursor)) && count(value,"selected",page_count(cursor)) &&
    count(value,"verified",page_count(cursor)) && next_valid(J.field(value,"next"),cursor) && flag(value,"covers_snapshot_record_range",False{}) &&
    count(value,"complete_extraction_records",page_complete(cursor)) && count(value,"partial_extraction_records",U32.sub(page_count(cursor),page_complete(cursor))) &&
    count(value,"returned_occurrences",page_refs(cursor))

def inventory_valid(+value: J.Json,+root: String,+extent: U32,+cursor: U32) -> Bool:
  S.exact_object(value,["kind","profile","capture","page","records","verification"]) && text(value,"kind","attachment_inventory") &&
    text(value,"profile","attachment-occurrences-v1") && capture_valid(root,extent,J.field(value,"capture")) && meta_valid(J.field(value,"page"),cursor) &&
    records_valid(J.items(J.field(value,"records")),cursor,extent,None{},U32.to_nat(page_count(cursor))) &&
    text(value,"verification","Selected retained raw records and immediate predecessors verified; archive metadata checked, compressed bytes and unselected raw ranges not reverified. External files not read.")

def occurrence_choices(items: List<&2,J.Json>,+raw: J.Json) -> List<&2,Choice>:
  match items:
    case []: []
    case occurrence <> rest: Choice{raw,[occurrence]} <> occurrence_choices(rest,raw)

def choices(records: List<&2,J.Json>) -> List<&2,Choice>:
  match records:
    case []: []
    case +raw <> rest:
      Choice{raw,[]} <> List.append(&2,Choice,occurrence_choices(J.items(J.field(raw,"occurrences")),raw),choices(rest))

def at_choice(items: List<&2,Choice>,index: Nat) -> Maybe<&2,Choice>:
  match items index:
    case value <> _ 0n: Some{value}
    case _ <> rest 1n+left: at_choice(rest,left)
    case _ _: None{}

def choice(records: List<&2,J.Json>,index: U32) -> Maybe<&2,Choice>:
  at_choice(choices(records),U32.to_nat(index))

def require_choice(value: Maybe<&2,Choice>) -> IO(Choice):
  match value:
    case Some{value}: IO.pure(Choice,value)
    case None{}: IO.die(Choice,2,"Selected index is outside the independently expected rows")

def valid_export(record: U32) -> Bool:
  match record:
    case 0: True{}
    case 2: True{}
    case 3: True{}
    case 8: True{}
    case 10: True{}
    case 15: True{}
    case 20: True{}
    case _: False{}

def choice_exportable(value: Choice) -> Bool:
  match value:
    case Choice{raw,[_]}: valid_export(natural(J.field(raw,"record")))
    case _: False{}

def choice_fields(value: Choice) -> String:
  match value:
    case Choice{raw,[]}:
      ",\"record\":" ++ J.get(raw,"record") ++ ",\"reference\":\"\",\"path\":\"\",\"decoded_bytes\":\"\",\"sha256\":\"\""
    case Choice{+raw,[+occurrence]}:
      +record = natural(J.field(raw,"record"))
      ",\"record\":" ++ J.get(raw,"record") ++ ",\"reference\":0,\"path\":" ++ J.quote(expected_path(record)) ++
        ",\"decoded_bytes\":" ++ Bool.pick(String,valid_export(record),U32.show(expected_bytes(record)),"\"\"") ++
        ",\"sha256\":" ++ J.quote(Bool.pick(String,valid_export(record),expected_sha(record),""))
    case _: ""

def rows_json(rows: List<&2,String>) -> List<&2,J.Json>:
  match rows:
    case []: []
    case row <> rest: J.JString{row} <> rows_json(rest)

def output(+model: A.Model,+selected: Choice) -> String:
  "{\"kind\":\"validated_native_attachment_oracle_v1\",\"text\":" ++ J.quote(A.text(model)) ++
    ",\"exportable\":" ++ Bool.pick(String,choice_exportable(selected),"true","false") ++
    ",\"rows\":" ++ J.encode(J.JArray{rows_json(A.rows(model))}) ++ ",\"selected\":" ++ U32.show(A.selected_index(model)) ++ choice_fields(selected) ++ "}"

def destination_valid(+root: String,+destination: String) -> Bool:
  +prefix = root ++ "/library/"
  +leaf = String.drop(destination,String.length(prefix))
  String.starts_with(destination,prefix) && String.starts_with(leaf,"attachment-") && String.ends_with(leaf,".bin") &&
    Bool.not(String.contains(leaf,"/")) && Bool.not(String.contains(leaf,"\0")) &&
    U32.is_le(U32.from_nat(List.length(&2,U32,D.encode(leaf))),244)

def expected_ack(value: Choice,capture: J.Json,destination: String) -> String:
  Choice{+raw,_} = value
  +record = natural(J.field(raw,"record"))
  "{\"kind\":\"attachment_inline_export\",\"profile\":\"attachment-occurrences-v1\",\"capture\":" ++ J.encode(capture) ++
    ",\"record\":" ++ J.get(raw,"record") ++ ",\"offset\":" ++ J.get(raw,"offset") ++ ",\"length\":" ++ J.get(raw,"length") ++
    ",\"raw_digest\":" ++ J.quote(J.get(raw,"digest")) ++ ",\"reference\":0,\"path\":" ++ J.quote(expected_path(record)) ++
    ",\"media_type\":\"application/octet-stream\",\"decoded_bytes\":" ++ U32.show(expected_bytes(record)) ++
    ",\"sha256\":" ++ J.quote(expected_sha(record)) ++ ",\"destination\":" ++ J.quote(destination) ++ "}"

def export_args(value: Choice,destination: String) -> List<&2,String>:
  Choice{+raw,_} = value
  ["export-inline","1",J.get(raw,"record"),"0",expected_path(natural(J.field(raw,"record"))),destination]

def same_fields(names: List<&2,String>,+actual: J.Json,+expected: J.Json) -> Bool:
  match names:
    case []: True{}
    case +name <> rest:
      String.eq(J.encode(J.field(actual,name)),J.encode(J.field(expected,name))) && same_fields(rest,actual,expected)

def independent_ack(+actual: J.Json,+expected: J.Json) -> Bool:
  S.exact_object(actual,["kind","profile","capture","record","offset","length","raw_digest","reference","path","media_type","decoded_bytes","sha256","destination"]) &&
    same_fields(["kind","profile","record","offset","length","raw_digest","reference","path","media_type","decoded_bytes","sha256","destination"],actual,expected) &&
    S.exact_object(J.field(actual,"capture"),["provider","source_id","source","generation","snapshot","extent","total_records","encoding","byte_space"]) &&
    same_fields(["provider","source_id","source","generation","snapshot","extent","total_records","encoding","byte_space"],J.field(actual,"capture"),J.field(expected,"capture"))

def acknowledged(+model: A.Model,+selection: Choice,+destination: String,+expected: J.Json,+actual: J.Json) -> IO(Unit):
  +pending = A.exporting(model,export_args(selection,destination),2)
  do IO<Unit>:
    checked(independent_ack(actual,expected),"actual export acknowledgement differs from exact independent occurrence/digest/destination")
    checked(A.ack_valid(pending,actual),"presenter rejected independently admitted export acknowledgement")
    IO.print(output(A.exported(pending,Done{actual}),selection))

def export_mode(mode: String,model: A.Model,selection: Choice,destination: String,+expected: J.Json,ack_path: String) -> IO(Unit):
  match mode:
    case "saved": acknowledged(model,selection,destination,expected,expected)
    case "ack":
      do IO<Unit>:
        actual : J.Json <- input(ack_path)
        acknowledged(model,selection,destination,expected,actual)
    case _: IO.die(Unit,2,"Unknown export mode")

def exported(mode: String,root: String,model: A.Model,+selection: Choice,capture: J.Json,+destination: String,ack_path: String) -> IO(Unit):
  do IO<Unit>:
    checked(choice_exportable(selection),"selected row has no valid retained inline bytes")
    checked(destination_valid(root,destination),"expected export destination must be an owned attachment .bin in the fixture library")
    +expected : J.Json <- parse(J.parse(expected_ack(selection,capture,destination)))
    export_mode(mode,model,selection,destination,expected,ack_path)

def present_mode(mode: String,root: String,model: A.Model,selection: Choice,capture: J.Json,destination: String,ack_path: String) -> IO(Unit):
  match mode:
    case "view": IO.print(output(model,selection))
    case other: exported(other,root,model,selection,capture,destination,ack_path)

def present(mode: String,+root: String,+manifest: J.Json,+inventory: J.Json,+start: U32,+count: U32,+index: U32,destination: String,ack_path: String) -> IO(Unit):
  +extent = natural(J.field(manifest,"logical_bytes"))
  +cursor = natural(J.field(J.field(inventory,"page"),"start"))
  +anchor : A.Anchor = A.Anchor{"1",start,count}
  do IO<Unit>:
    checked(fixture_valid(root,manifest),"fixture identity, private root, logical extent or source-loss receipt differs")
    checked(numeric(J.field(J.field(inventory,"page"),"start")) && range_valid(start,count,cursor),"unsupported fixture anchor or page cursor")
    checked(inventory_valid(inventory,root,extent,cursor),"inventory differs from independently expected fixture identity, descriptors, paths or coverage")
    +selection : Choice <- require_choice(choice(J.items(J.field(inventory,"records")),index))
    checked(A.page_valid(inventory,anchor,cursor),"presenter rejected independently admitted inventory")
    +model : A.Model = A.choose(A.apply(A.begin(A.initial(anchor),cursor,1),Done{inventory}),index)
    checked(U32.is_eq(A.phase(model),2) && U32.is_eq(U32.from_nat(List.length(&2,String,A.rows(model))),U32.add(page_count(cursor),page_refs(cursor))) &&
      Bool.not(Bool.xor(A.exportable(model),choice_exportable(selection))),"presenter row count or export state disagrees with independent fixture")
    present_mode(mode,root,model,selection,J.field(inventory,"capture"),destination,ack_path)

def run(mode: String,root: String,fixture_path: String,inventory_path: String,start: String,count: String,index: String,destination: String,ack_path: String) -> IO(Unit):
  do IO<Unit>:
    manifest : J.Json <- input(fixture_path)
    inventory : J.Json <- input(inventory_path)
    begin : U32 <- number(start)
    total : U32 <- number(count)
    selection : U32 <- number(index)
    present(mode,root,manifest,inventory,begin,total,selection,destination,ack_path)

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "view" <> root <> fixture <> inventory <> start <> count <> index <> []:
      run("view",root,fixture,inventory,start,count,index,"","")
    case _ <> "saved" <> root <> fixture <> inventory <> start <> count <> index <> destination <> []:
      run("saved",root,fixture,inventory,start,count,index,destination,"")
    case _ <> "ack" <> root <> fixture <> inventory <> start <> count <> index <> destination <> ack <> []:
      run("ack",root,fixture,inventory,start,count,index,destination,ack)
    case _: IO.die(Unit,2,"Expected view|saved|ack ROOT FIXTURE_JSON INVENTORY_JSON ANCHOR_START ANCHOR_COUNT SELECTED_INDEX [DEST [ACK_JSON]]")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)

import Base
import ../src/gui_attachments.bend as A
import ../src/json.bend as J

# Wire fixtures are independently specified metadata, not extractor output.
def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def parsed(value: Result<&2,&2,String,J.Json>) -> J.Json:
  match value:
    case Done{value}: value
    case Fail{_}: J.JNull{}

def json(text: String) -> J.Json: parsed(J.parse(text))
def sha() -> String: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
def capture() -> String:
  "{\"provider\":\"claude\",\"source_id\":\"2\",\"source\":\"/synthetic/source.jsonl.zst\",\"generation\":\"3\",\"snapshot\":\"7\",\"extent\":\"400\",\"total_records\":40,\"encoding\":\"zstd-jsonl-v1\",\"byte_space\":\"logical_source_bytes\"}"

def inline() -> String:
  "{\"reference\":0,\"path\":\"/message/content/0/source\",\"kind\":\"image\",\"descriptor\":{\"type\":\"inline\",\"availability\":\"representation_retained_in_raw\",\"media_type\":\"image/png\",\"encoding\":\"base64\",\"valid_base64\":true,\"encoded_characters\":8,\"decoded_bytes\":4,\"name\":\"inline image\",\"summary\":\"Inline bytes retained\"}}"

def coverage(+ordinal: U32) -> String:
  Bool.pick(String,U32.is_eq(ordinal,5),"{\"state\":\"invalid_utf8\",\"complete\":false,\"truncated\":false}","{\"state\":\"extracted\",\"complete\":true,\"truncated\":false}")

def record(+ordinal: U32) -> String:
  "{\"record\":" ++ U32.show(ordinal) ++ ",\"offset\":" ++ U32.show(U32.mul(ordinal,10)) ++ ",\"length\":10,\"digest\":\"" ++ sha() ++ "\",\"coverage\":" ++ coverage(ordinal) ++ ",\"occurrences\":[" ++ Bool.pick(String,U32.is_eq(ordinal,4),inline(),"") ++ "]}"

def records(count: Nat,+ordinal: U32) -> List<&2,String>:
  match count:
    case 0n: []
    case 1n+left: record(ordinal) <> records(left,U32.inc(ordinal))

def has(+start: U32,+count: U32,+ordinal: U32) -> Bool:
  U32.is_ge(ordinal,start) && U32.is_lt(ordinal,U32.add(start,count))

def wire(+start: U32,+count: U32) -> String:
  "{\"kind\":\"attachment_inventory\",\"profile\":\"attachment-occurrences-v1\",\"capture\":" ++ capture() ++ ",\"page\":{\"start\":" ++ U32.show(start) ++ ",\"requested\":" ++ U32.show(count) ++ ",\"selected\":" ++ U32.show(count) ++ ",\"verified\":" ++ U32.show(count) ++ ",\"next\":" ++ Bool.pick(String,U32.is_eq(U32.add(start,count),40),"null",U32.show(U32.add(start,count))) ++ ",\"covers_snapshot_record_range\":false,\"complete_extraction_records\":" ++ U32.show(U32.sub(count,Bool.to_u32(has(start,count,5)))) ++ ",\"partial_extraction_records\":" ++ U32.show(Bool.to_u32(has(start,count,5))) ++ ",\"returned_occurrences\":" ++ U32.show(Bool.to_u32(has(start,count,4))) ++ "},\"records\":[" ++ String.join(records(U32.to_nat(count),start),",") ++ "],\"verification\":\"Selected records and immediate predecessors verified\"}"

def anchor() -> A.Anchor: A.Anchor{"7",4,13}
def waiting() -> A.Model: A.begin(A.initial(anchor()),4,9)
def ready() -> A.Model: A.apply(waiting(),Done{json(wire(4,10))})
def selected() -> A.Model: A.choose(ready(),1)
def exported() -> A.Model:
  A.exporting(selected(),["export-inline","7","4","0","/message/content/0/source","/synthetic/owned.bin"],10)

def ack(path: String,record: String) -> J.Json:
  json("{\"kind\":\"attachment_inline_export\",\"profile\":\"attachment-occurrences-v1\",\"capture\":" ++ capture() ++ ",\"record\":" ++ record ++ ",\"offset\":40,\"length\":10,\"raw_digest\":\"" ++ sha() ++ "\",\"reference\":0,\"path\":\"/message/content/0/source\",\"media_type\":\"image/png\",\"decoded_bytes\":4,\"sha256\":\"" ++ sha() ++ "\",\"destination\":\"" ++ path ++ "\"}")

def field_replace(fields: List<&2,J.Field>,+name: String,+replacement: J.Json) -> List<&2,J.Field>:
  match fields:
    case []: []
    case J.JField{+key,value} <> rest: J.JField{key,Bool.pick(J.Json,String.eq(key,name),replacement,value)} <> field_replace(rest,name,replacement)

def replace(value: J.Json,name: String,replacement: J.Json) -> J.Json:
  match value:
    case J.JObject{fields}: J.JObject{field_replace(fields,name,replacement)}
    case _: J.JNull{}

def changed_capture() -> J.Json:
  replace(json(wire(14,3)),"capture",replace(json(capture()),"generation",J.JString{"4"}))

def contracts() -> IO(Unit):
  do IO<Unit>:
    require(String.contains(A.text(ready()),"claude | source 2 | generation 3 | snapshot 7") && String.contains(A.text(ready()),"/synthetic/source.jsonl.zst"),"copied details retain exact provider source generation snapshot identity")
    require(String.contains(A.text(ready()),"400 bytes | total records: 40") && String.contains(A.text(ready()),"Encoding: zstd-jsonl-v1"),"archive metadata disclosure names logical extent total and encoding")
    require(String.contains(A.text(ready()),"Compressed container bytes and other raw ranges were not reverified") && String.contains(A.text(ready()),"URLs were not fetched"),"copyable details distinguish selected raw verification from unverified container external and other ranges")
    require(String.contains(A.capture_text(replace(json(capture()),"encoding",J.JString{"identity"})),"Encoding: identity"),"plain source detail does not label identity bytes as archive encoding")
    require(A.anchor_valid(anchor()),"bounded exact snapshot range admitted")
    require(Bool.not(A.anchor_valid(A.Anchor{"07",4,13})),"noncanonical snapshot rejected")
    require(Bool.not(A.anchor_valid(A.Anchor{"7",4294967290,13})),"range overflow rejected")
    require(A.same_args(A.request(waiting()),["attachments","7","4","10"]),"first request is ten raw records with no repository role time filters")
    require(A.page_valid(json(wire(4,10)),anchor(),4),"independent archive metadata page validates")
    require(U32.is_eq(A.phase(ready()),2) && Nat.is_eq(List.length(&2,String,A.rows(ready())),11n),"empty and partial records remain rows beside image-only occurrence")
    require(String.contains(A.text(ready()),A.scope()) && String.contains(A.text(ready()),"filters do not apply"),"raw scope displayed explicitly before export")
    require(Bool.not(A.exportable(ready())) && A.exportable(selected()),"record coverage row cannot export; valid inline occurrence can")
    require(String.contains(A.text(A.choose(ready(),2)),"Partial attachment coverage") && String.contains(A.text(A.choose(ready(),2)),"total is unknown"),"invalid utf8 record coverage remains explicit")
    require(A.next(ready()) && Bool.not(A.previous(ready())),"page controls remain inside frozen parent range")
    require(U32.is_eq(A.next_cursor(ready(),True{}),14),"next page starts at exact physical ordinal")
    require(A.same_args(A.args(anchor(),14),["attachments","7","14","3"]),"last page uses remaining three physical records")
    require(Bool.not(A.page_valid(json(wire(14,10)),anchor(),14)),"response beyond parent range rejected")
    require(U32.is_eq(A.cursor(A.apply(A.begin(ready(),14,10),Done{changed_capture()})),4),"changed generation response rejected and prior page restored")
    require(U32.is_eq(A.cursor(A.apply(A.begin(ready(),14,10),Fail{"synthetic failure"})),4),"page failure restores prior exact cursor")
    require(Bool.not(A.next(A.apply(A.begin(ready(),14,10),Done{json(wire(14,3))}))),"last page cannot escape frozen range despite later snapshot records")
    require(A.previous(A.apply(A.begin(ready(),14,10),Done{json(wire(14,3))})),"late page can return to first physical page")
    require(Bool.not(A.exportable(A.choose(ready(),650))),"out of range selection cannot export")
    require(String.contains(A.text(A.initial(A.Anchor{"7",0,0})),"No attachment occurrence"),"empty captured range is honest empty state")
    require(A.ack_valid(exported(),ack("/synthetic/owned.bin","4")),"exact clicked occurrence and destination acknowledgement validates")
    require(Bool.not(A.ack_valid(exported(),ack("/synthetic/other.bin","4"))),"different destination acknowledgement rejected")
    require(Bool.not(A.ack_valid(exported(),ack("/synthetic/owned.bin","5"))),"different physical record acknowledgement rejected")
    require(Bool.not(A.ack_valid(exported(),replace(ack("/synthetic/owned.bin","4"),"reference",J.JNumber{"1"}))),"duplicate-position reference ordinal cannot retarget export")
    require(Bool.not(A.ack_valid(exported(),replace(ack("/synthetic/owned.bin","4"),"path",J.JString{"/message/content/1/source"}))),"structural path cannot retarget export")
    require(Bool.not(A.ack_valid(exported(),replace(ack("/synthetic/owned.bin","4"),"decoded_bytes",J.JNumber{"3"}))),"decoded byte count must match selected descriptor")
    require(Bool.not(A.ack_valid(selected(),ack("/synthetic/owned.bin","4"))),"acknowledgement requires active export phase")
    require(String.contains(A.text(A.exported(exported(),Done{ack("/synthetic/owned.bin","4")})),"Saved original inline bytes"),"exact success renders original-byte receipt")
    require(String.contains(A.text(A.exported(exported(),Done{ack("/synthetic/other.bin","4")})),"file may have been published"),"mismatched completion never falsely claims success")

def main() -> IO(Unit): contracts()

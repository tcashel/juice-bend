import Base
import ./json.bend as Json
import ./request_evidence.bend as T
import ./recorded_commit.bend as C
import ./request_origin.bend as Origin

# Typed extraction from a verified retained logical source record, aligned to the
# provider's unchanged event ordinals. Duplicate fields are always unsupported.
type Item is Data:
  Ignore{}
  Unsupported{reason: String}
  Call{id: String,tool: String,args: String}
  Output{id: String,status: String,markers: List<&2,C.Marker>}

type Terminal is Data:
  Terminal{count: U32,status: String,body: String}

def valid_id(+id: String) -> Bool:
  Bool.not(String.is_empty(id)) && Nat.is_le(String.length(id),256n) &&
    Bool.not(String.contains(id,"\0"))

def call(id: String,tool: String,args: Json.Json) -> Item:
  Call{id,tool,Json.encode(args)}

def input(value: T.Lookup) -> Result<&2,&2,String,Json.Json>:
  match value:
    case T.Found{Json.JObject{fields}}: Done{Json.JObject{fields}}
    case _: Fail{"tool input object is missing, duplicated or wrongly typed"}

def claude_call(+block: Json.Json) -> Result<&2,&2,String,Item>:
  do Result<&2,&2,String,Item>:
    id : String <- C.typed_string(block,"id")
    tool : String <- C.typed_string(block,"name")
    args : Json.Json <- input(T.field(block,"input"))
    return call(id,tool,args)

def part(valid: Bool,raw: Json.Json) -> Result<&2,&2,String,String>:
  match valid:
    case True{}: C.typed_string(raw,"text")
    case False{}: Fail{"unsupported result content part"}

def string_parts(items: List<&2,Json.Json>) -> Result<&2,&2,String,List<&2,String>>:
  match items:
    case []: Done{[]}
    case +head <> rest:
      do Result<&2,&2,String,List<&2,String>>:
        text : String <- part(T.named(T.field(head,"type"),"text"),head)
        tail : List<&2,String> <- string_parts(rest)
        return text <> tail

def text(value: T.Lookup) -> Result<&2,&2,String,String>:
  match value:
    case T.Found{Json.JString{value}}: Done{value}
    case T.Found{Json.JArray{items}}:
      do Result<&2,&2,String,String>:
        parts : List<&2,String> <- string_parts(items)
        return String.join(parts,"\n")
    case _: Fail{"result text is missing, duplicated or wrongly typed"}

def claude_status(value: T.Lookup) -> String:
  match value:
    case T.Found{Json.JBool{False{}}}: "succeeded"
    case T.Found{Json.JBool{True{}}}: "failed"
    case T.Missing{}: "completion_unknown"
    case _: "unsupported_result"

def measured(value: Result<&2,&2,String,U32>,+id: String,status: String,+output: String) -> Item:
  match value:
    case Fail{_}: Output{id,"output_bound",[]}
    case Done{_}:
      Bool.pick(Item,Nat.is_le(List.length(&2,String,String.lines(output)),4096n),
        Output{id,status,C.markers(String.lines(output),4096n)},Output{id,"output_bound",[]})

def output(id: String,status: String,+text: String) -> Item:
  measured(Origin.measure(text,65536,0),id,status,text)

def result_text(value: Result<&2,&2,String,String>,id: String,status: String) -> Item:
  match value:
    case Done{value}: output(id,status,value)
    case Fail{_}: Output{id,"unsupported_result",[]}

def claude_result(+block: Json.Json) -> Result<&2,&2,String,Item>:
  do Result<&2,&2,String,Item>:
    id : String <- C.typed_string(block,"tool_use_id")
    return result_text(text(T.field(block,"content")),id,claude_status(T.field(block,"is_error")))

def from_result(value: Result<&2,&2,String,Item>) -> Item:
  match value:
    case Done{item}: item
    case Fail{reason}: Unsupported{reason}

def claude_block_code(code: U32,block: Json.Json) -> Item:
  match code:
    case 1: from_result(claude_call(block))
    case 2: from_result(claude_result(block))
    case _: Ignore{}

def claude_block_kind(kind: Maybe<&2,String>,block: Json.Json) -> Item:
  match kind:
    case Some{+kind}:
      claude_block_code(Bool.pick(U32,String.eq(kind,"tool_use"),1,
        Bool.pick(U32,String.eq(kind,"tool_result"),2,0)),block)
    case _: Unsupported{"duplicate or malformed Claude block type"}

def claude_block(+block: Json.Json) -> Item:
  claude_block_kind(T.string(T.field(block,"type")),block)

def at(items: List<&2,Json.Json>,index: U32) -> Item:
  match items index:
    case Nil{} _: Ignore{}
    case Con{head,_} 0: claude_block(head)
    case Con{_,rest} n: at(rest,U32.sub(n,1))

def claude_content(content: T.Lookup,index: U32) -> Item:
  match content:
    case T.Found{Json.JArray{items}}: at(items,index)
    case _: Ignore{}

def claude(raw: Json.Json,index: U32) -> Item:
  claude_content(T.field(T.value(T.field(raw,"message")),"content"),index)

def codex_call(+raw: Json.Json) -> Result<&2,&2,String,Item>:
  do Result<&2,&2,String,Item>:
    id : String <- C.typed_string(raw,"call_id")
    tool : String <- C.typed_string(raw,"name")
    args : String <- C.typed_string(raw,"arguments")
    return Call{id,tool,args}

def exit_value(value: T.Lookup) -> String:
  match value:
    case T.Found{Json.JNumber{"0"}}: "succeeded"
    case T.Found{Json.JNumber{_}}: "failed"
    case _: "unsupported_result"

def metadata_exit(value: T.Lookup) -> T.Lookup:
  match value:
    case T.Missing{}: T.Missing{}
    case T.Found{Json.JObject{fields}}: T.field(Json.JObject{fields},"exit_code")
    case _: T.Invalid{}

def completion_fields(top: T.Lookup,nested: T.Lookup) -> String:
  match top nested:
    case T.Missing{} T.Missing{}: "completion_unknown"
    case T.Missing{} value: exit_value(value)
    case value T.Missing{}: exit_value(value)
    case +one +two:
      Bool.pick(String,String.eq(exit_value(one),exit_value(two)),exit_value(one),"unsupported_result")

def structured_field(field: T.Lookup,raw: Json.Json) -> String:
  completion_fields(field,metadata_exit(T.field(raw,"metadata")))

def structured_status(+raw: Json.Json) -> String:
  structured_field(T.field(raw,"exit_code"),raw)

def terminal_line(final: Bool,+head: String,tail: List<&2,String>,count: U32,+status: String,
  next: List<&2,String> -> U32 -> String -> Terminal) -> Terminal:
  match final:
    case True{}: Terminal{count,status,String.join(tail,"\n")}
    case False{}:
      next(tail,U32.add(count,Bool.to_u32(String.starts_with(head,"Process exited with code "))),
        Bool.pick(String,String.eq(status,"incomplete") || String.starts_with(head,"Process running with session ID "),"incomplete",
          Bool.pick(String,String.starts_with(head,"Process exited with code "),
            Bool.pick(String,String.eq(head,"Process exited with code 0"),"succeeded","failed"),status)))

def terminal(fuel: Nat,lines: List<&2,String>,count: U32,status: String) -> Terminal:
  match fuel lines:
    case _ Nil{}: Terminal{count,status,""}
    case 0n _: Terminal{count,"output_bound",""}
    case 1n+more Con{+head,tail}:
      terminal_line(String.eq(head,"Final output:"),head,tail,count,status,
        rest => n => state => terminal(more,rest,n,state))

def terminal_output(id: String,state: Terminal) -> Item:
  Terminal{count,status,body} = state
  output(id,Bool.pick(String,U32.is_eq(count,1),status,"completion_unknown"),body)

def codex_object_text(text: Result<&2,&2,String,String>,id: String,raw: Json.Json) -> Item:
  match text:
    case Done{value}: output(id,structured_status(raw),value)
    case Fail{_}: Output{id,"unsupported_result",[]}

def codex_object(id: String,+raw: Json.Json) -> Item:
  codex_object_text(C.typed_string(raw,"output"),id,raw)

def codex_parsed(parsed: Result<&2,&2,String,Json.Json>,id: String,value: String) -> Item:
  # Structured JSON output is independently typed; wrapper prose is only
  # accepted in the terminal header before a literal Final output: boundary.
  match parsed:
    case Done{Json.JObject{fields}}: codex_object(id,Json.JObject{fields})
    case _: terminal_output(id,terminal(4097n,String.lines(value),0,"completion_unknown"))

def codex_bounded(bound: Result<&2,&2,String,U32>,id: String,+value: String) -> Item:
  match bound:
    case Fail{_}: Output{id,"output_bound",[]}
    case Done{_}: codex_parsed(Json.parse(value),id,value)

def codex_text(id: String,+value: String) -> Item:
  codex_bounded(Origin.measure(value,65536,0),id,value)

def codex_output(id: String,value: T.Lookup) -> Item:
  match value:
    case T.Found{Json.JString{value}}: codex_text(id,value)
    case T.Found{Json.JObject{fields}}: codex_object(id,Json.JObject{fields})
    case _: Output{id,"unsupported_result",[]}

def codex_result(+raw: Json.Json) -> Result<&2,&2,String,Item>:
  do Result<&2,&2,String,Item>:
    id : String <- C.typed_string(raw,"call_id")
    return codex_output(id,T.field(raw,"output"))

def custom_call(+raw: Json.Json) -> Result<&2,&2,String,Item>:
  do Result<&2,&2,String,Item>:
    id : String <- C.typed_string(raw,"call_id")
    tool : String <- C.typed_string(raw,"name")
    args : String <- C.typed_string(raw,"input")
    return Call{id,"unsupported custom wrapper: " ++ tool,args}

def custom_result(+raw: Json.Json) -> Result<&2,&2,String,Item>:
  do Result<&2,&2,String,Item>:
    id : String <- C.typed_string(raw,"call_id")
    return result_text(text(T.field(raw,"output")),id,"unsupported_wrapper")

def codex_kind_code(code: U32,payload: Json.Json) -> Item:
  match code:
    case 1: from_result(codex_call(payload))
    case 2: from_result(codex_result(payload))
    case 3: from_result(custom_call(payload))
    case 4: from_result(custom_result(payload))
    case _: Ignore{}

def codex_kind(kind: Maybe<&2,String>,payload: Json.Json) -> Item:
  match kind:
    case None{}: Ignore{}
    case Some{+kind}:
      codex_kind_code(Bool.pick(U32,String.eq(kind,"function_call"),1,
        Bool.pick(U32,String.eq(kind,"function_call_output"),2,
          Bool.pick(U32,String.eq(kind,"custom_tool_call"),3,
            Bool.pick(U32,String.eq(kind,"custom_tool_call_output"),4,0)))),payload)

def codex_payload(+payload: Json.Json) -> Item:
  codex_kind(T.string(T.field(payload,"type")),payload)

def codex(raw: Json.Json) -> Item:
  codex_payload(T.value(T.field(raw,"payload")))

def extract(provider: String,+raw: Json.Json,index: U32) -> Item:
  match provider:
    case "claude": claude(raw,index)
    case "codex":
      Bool.pick(Item,U32.is_eq(index,0) && T.named(T.field(raw,"type"),"response_item"),codex(raw),Ignore{})
    case _: Unsupported{"unsupported provider"}

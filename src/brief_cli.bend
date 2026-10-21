import Base
import ./continuation_brief.bend as Brief
import ./domain.bend as Domain
import ./evidence.bend as Evidence
import ./json.bend as Json
import ./scoped_reader.bend as Scoped
import ./tool_activity.bend as Activity

# Isolated stateless CLI adapter. The embedding executable owns its existing
# database connection. This module never opens a library, persists a preview,
# reads a default home history, resolves latest, or executes captured text.
type Command is Data:
  Prepare{input: Brief.Input}
  Check{input: Brief.Input,commitment: String,text: String}

def protocol() -> String:
  "juice-bend-brief-transport-v1"

def stdin_limit() -> U32:
  131072

def output_limit() -> U32:
  32768

def encode_scope(scope: Scoped.Scope) -> String:
  Scoped.Scope{provider,repository,role,after} = scope
  "{\"provider\":" ++ Json.quote(provider) ++ ",\"repository\":" ++ Json.quote(repository) ++
    ",\"role\":" ++ Json.quote(role) ++ ",\"after\":" ++ Json.quote(after) ++ "}"

def encode_input(input: Brief.Input) -> String:
  Brief.Input{snapshot,start,count,scope,repository} = input
  "{\"snapshot\":" ++ Json.quote(snapshot) ++ ",\"start\":" ++ Json.quote(U32.show(start)) ++
    ",\"count\":" ++ Json.quote(U32.show(count)) ++ ",\"scope\":" ++ encode_scope(scope) ++
    ",\"repository\":" ++ Json.quote(repository) ++ "}"

def prepare_request(input: Brief.Input) -> String:
  "{\"protocol\":" ++ Json.quote(protocol()) ++ ",\"input\":" ++ encode_input(input) ++ "}"

def check_request(input: Brief.Input,commitment: String,text: String) -> String:
  "{\"protocol\":" ++ Json.quote(protocol()) ++ ",\"input\":" ++ encode_input(input) ++
    ",\"commitment\":" ++ Json.quote(commitment) ++ ",\"text\":" ++ Json.quote(text) ++ "}"

# These are closed shapes, even when called on a constructed Json value rather
# than the production parser (which already rejects duplicate object keys).
def occurrences(fields: List<&2,Json.Field>,+key: String) -> U32:
  match fields:
    case []: 0
    case Json.JField{name,_} <> rest:
      U32.add(Bool.to_u32(String.eq(name,key)),occurrences(rest,key))

def required_keys(+fields: List<&2,Json.Field>,keys: List<&2,String>) -> Bool:
  match keys:
    case []: True{}
    case key <> rest: U32.is_eq(occurrences(fields,key),1) && required_keys(fields,rest)

def shape(value: Json.Json,+keys: List<&2,String>) -> Bool:
  match value:
    case Json.JObject{+fields}:
      Nat.is_eq(List.length(&2,Json.Field,fields),List.length(&2,String,keys)) && required_keys(fields,keys)
    case _: False{}

def guard(ok: Bool,code: String,message: String) -> Result<&2,&2,Brief.Problem,Unit>:
  match ok:
    case True{}: Done{Unit{}}
    case False{}: Fail{Brief.Problem{code,message}}

def string(value: Json.Json) -> Result<&2,&2,Brief.Problem,String>:
  match value:
    case Json.JString{text}: Done{text}
    case _: Fail{Brief.Problem{"invalid_request","Every scalar protocol field must be a string"}}

def number(value: Maybe<&2,U32>) -> Result<&2,&2,Brief.Problem,U32>:
  match value:
    case Some{number}: Done{number}
    case None{}: Fail{Brief.Problem{"invalid_request","Range fields must be canonical decimal U32 strings"}}

def path_bound(+value: String) -> Bool:
  Nat.is_le(String.length(value),4096n) && Brief.has_budget(Activity.consume(value,16384)) &&
    Bool.not(String.contains(value,"\0"))

def valid_input(input: Brief.Input) -> Bool:
  Brief.Input{snapshot,_,+count,+scope,+repository} = input
  Scoped.Scope{_,scope_repo,_,_} = scope
  Evidence.positive_id(snapshot) && U32.is_gt(count,0) && U32.is_le(count,100) &&
    Scoped.valid(scope) && path_bound(scope_repo) && path_bound(repository) && Brief.scope_path(repository)

def scope(+value: Json.Json) -> Result<&2,&2,Brief.Problem,Scoped.Scope>:
  do Result<&2,&2,Brief.Problem,Scoped.Scope>:
    guard(shape(value,["provider","repository","role","after"]),"invalid_request","Frozen scope has an invalid object shape")
    provider : String <- string(Json.field(value,"provider"))
    repository : String <- string(Json.field(value,"repository"))
    role : String <- string(Json.field(value,"role"))
    after : String <- string(Json.field(value,"after"))
    return Scoped.Scope{provider,repository,role,after}

def input(+value: Json.Json) -> Result<&2,&2,Brief.Problem,Brief.Input>:
  do Result<&2,&2,Brief.Problem,Brief.Input>:
    guard(shape(value,["snapshot","start","count","scope","repository"]),"invalid_request","Frozen input has an invalid object shape")
    snapshot : String <- string(Json.field(value,"snapshot"))
    start_text : String <- string(Json.field(value,"start"))
    count_text : String <- string(Json.field(value,"count"))
    start : U32 <- number(Domain.parse_u32(start_text))
    count : U32 <- number(Domain.parse_u32(count_text))
    filters : Scoped.Scope <- scope(Json.field(value,"scope"))
    repository : String <- string(Json.field(value,"repository"))
    +input : Brief.Input = Brief.Input{snapshot,start,count,filters,repository}
    guard(valid_input(input),"invalid_request","Brief requires exact snapshot/range, valid frozen scope and explicit repository paths of at most 4096 Unicode scalars")
    return input

def hex_tail(text: String) -> Bool:
  match text:
    case SNil{}: True{}
    case SCon{Chr{+cp},rest}:
      ((cp >= 48 && cp <= 57 : U32) || (cp >= 97 && cp <= 102 : U32)) && hex_tail(rest)

def commitment_valid(+text: String) -> Bool:
  Nat.is_eq(String.length(text),64n) && hex_tail(text)

def text_valid(text: String) -> Bool:
  Brief.has_budget(Activity.consume(text,8192))

def parsed_operation(operation: String,+value: Json.Json) -> Result<&2,&2,Brief.Problem,Command>:
  match operation:
    case "brief-prepare":
      do Result<&2,&2,Brief.Problem,Command>:
        guard(shape(value,["protocol","input"]),"invalid_request","Prepare request has an invalid object shape")
        version : String <- string(Json.field(value,"protocol"))
        guard(String.eq(version,protocol()),"protocol","Unsupported continuation brief protocol")
        anchor : Brief.Input <- input(Json.field(value,"input"))
        return Prepare{anchor}
    case "brief-check":
      do Result<&2,&2,Brief.Problem,Command>:
        guard(shape(value,["protocol","input","commitment","text"]),"invalid_request","Check request has an invalid object shape")
        version : String <- string(Json.field(value,"protocol"))
        guard(String.eq(version,protocol()),"protocol","Unsupported continuation brief protocol")
        anchor : Brief.Input <- input(Json.field(value,"input"))
        +commitment : String <- string(Json.field(value,"commitment"))
        +text : String <- string(Json.field(value,"text"))
        guard(commitment_valid(commitment) && text_valid(text),"invalid_request","Check requires lowercase SHA256 and at most 8192 decoded UTF8 text bytes")
        return Check{anchor,commitment,text}
    case _: Fail{Brief.Problem{"usage","Expected brief-prepare or brief-check with versioned JSON on stdin"}}

def parsed(operation: String,result: Result<&2,&2,String,Json.Json>) -> Result<&2,&2,Brief.Problem,Command>:
  match result:
    case Fail{_}: Fail{Brief.Problem{"invalid_json","Brief request is not valid unambiguous JSON"}}
    case Done{value}: parsed_operation(operation,value)

def parse_bounded(valid: Bool,operation: String,body: String) -> Result<&2,&2,Brief.Problem,Command>:
  match valid:
    case False{}: Fail{Brief.Problem{"input_limit","Brief stdin exceeds 131072 UTF8 bytes or contains invalid Unicode"}}
    case True{}: parsed(operation,Json.parse(body))

def parse(operation: String,+body: String) -> Result<&2,&2,Brief.Problem,Command>:
  parse_bounded(Brief.has_budget(Activity.consume(body,stdin_limit())),operation,body)

# This public digest is a commitment, not a MAC or authentication capability.
# preview_text binds every retained public Preview field, including the full
# private anchor/descriptors and redundant indices. Only the hash is transported.
def commitment(preview: Brief.Preview) -> String:
  Domain.digest(Domain.encode(protocol() ++ "|preview|" ++ Brief.preview_text(preview)))

def preview_text(preview: Brief.Preview) -> String:
  Brief.Preview{_,_,_,_,_,_,_,_,_,_,text,_} = preview
  text

def encoded(kind: String,preview: Brief.Preview,commitment: String,text: String) -> String:
  Brief.Preview{Brief.Anchor{Brief.Input{snapshot,start,count,_,_},_,_,_,_,_,_},_,_,_,_,_,_,_,_,_,_,bytes} = preview
  "{\"protocol\":" ++ Json.quote(protocol()) ++ ",\"kind\":" ++ Json.quote(kind) ++
    ",\"snapshot\":" ++ Json.quote(snapshot) ++ ",\"start\":" ++ Json.quote(U32.show(start)) ++
    ",\"count\":" ++ Json.quote(U32.show(count)) ++ ",\"commitment\":" ++ Json.quote(commitment) ++
    ",\"text\":" ++ Json.quote(text) ++ ",\"utf8_bytes\":" ++ Json.quote(U32.show(bytes)) ++ "}"

def bounded_response(+text: String) -> Result<&2,&2,Brief.Problem,String>:
  do Result<&2,&2,Brief.Problem,String>:
    guard(Brief.has_budget(Activity.consume(text,U32.sub(output_limit(),1))),"output_limit","Brief response exceeds the bounded worker envelope")
    return text

def prepared(result: Result<&2,&2,Brief.Problem,Brief.Preview>) -> Result<&2,&2,Brief.Problem,String>:
  match result:
    case Fail{problem}: Fail{problem}
    case Done{+preview}: bounded_response(encoded("prepared",preview,commitment(preview),preview_text(preview)))

def checked_equal(equal: Bool,preview: Brief.Preview,commitment: String,text: String) -> Result<&2,&2,Brief.Problem,String>:
  match equal:
    case False{}: Fail{Brief.Problem{"stale","Frozen input, retained evidence, policy, repository mapping or exact preview text changed; prepare a new brief"}}
    case True{}: bounded_response(encoded("checked",preview,commitment,text))

def checked(result: Result<&2,&2,Brief.Problem,Brief.Preview>,+expected: String,+text: String) -> Result<&2,&2,Brief.Problem,String>:
  match result:
    case Fail{problem}: Fail{problem}
    case Done{+fresh}:
      checked_equal(String.eq(commitment(fresh),expected) && String.eq(preview_text(fresh),text),fresh,expected,text)

def command_valid(command: Command) -> Bool:
  match command:
    case Prepare{input}: valid_input(input)
    case Check{input,commitment,text}: valid_input(input) && commitment_valid(commitment) && text_valid(text)

def dispatch_valid(valid: Bool,+db: U32,command: Command) -> IO(Result<&2,&2,Brief.Problem,String>):
  match valid:
    case False{}: IO.pure(Result<&2,&2,Brief.Problem,String>,Fail{Brief.Problem{"invalid_request","Invalid frozen input, commitment or text bounds"}})
    case True{}:
      match command:
        case Prepare{input}:
          do IO<Result<&2,&2,Brief.Problem,String>>:
            fresh : Result<&2,&2,Brief.Problem,Brief.Preview> <- Brief.prepare(db,input)
            return prepared(fresh)
        case Check{input,expected,text}:
          do IO<Result<&2,&2,Brief.Problem,String>>:
            # Exactly one fresh preparation, in its own read transaction. No
            # caller-supplied descriptor or cached Preview bypasses that read.
            fresh : Result<&2,&2,Brief.Problem,Brief.Preview> <- Brief.prepare(db,input)
            return checked(fresh,expected,text)

def dispatch(db: U32,+command: Command) -> IO(Result<&2,&2,Brief.Problem,String>):
  dispatch_valid(command_valid(command),db,command)

# The byte reader takes at most remaining+1 bytes and verifies EOF. It admits
# exactly 131072 bytes but rejects the next byte; UTF8 is decoded once afterward.
def decoded(result: Result<&2,&2,String,String>) -> Result<&2,&2,Brief.Problem,String>:
  match result:
    case Done{text}: Done{text}
    case Fail{_}: Fail{Brief.Problem{"invalid_utf8","Brief stdin contains invalid UTF8"}}

def read_sized(valid: Bool,file: File,size: U32,total: U32,part: List<&2,U32>,chunks: List<&2,List<&2,U32>>,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(Result<&2,&2,Brief.Problem,String>)) -> IO(Result<&2,&2,Brief.Problem,String>):
  match valid:
    case False{}:
      do IO<Result<&2,&2,Brief.Problem,String>>:
        File.close(file)
        return Fail{Brief.Problem{"input_limit","Brief stdin exceeds 131072 bytes"}}
    case True{}: next(file,U32.add(total,size),part <> chunks)

def read_chunk(file: File,bytes: List<&2,U32>,+total: U32,chunks: List<&2,List<&2,U32>>,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(Result<&2,&2,Brief.Problem,String>)) -> IO(Result<&2,&2,Brief.Problem,String>):
  match bytes:
    case []:
      do IO<Result<&2,&2,Brief.Problem,String>>:
        File.close(file)
        return decoded(Domain.decode(List.concat(&2,U32,List.reverse(&2,List<&2,U32>,chunks))))
    case byte <> rest:
      +part = {byte <> rest : List<&2,U32>}
      +size = U32.from_nat(List.length(&2,U32,part))
      read_sized(U32.is_le(size,U32.sub(stdin_limit(),total)),file,size,total,part,chunks,next)

def read_result(got: File & Result<&1,&1,U32 & String,List<&2,U32>>,total: U32,chunks: List<&2,List<&2,U32>>,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(Result<&2,&2,Brief.Problem,String>)) -> IO(Result<&2,&2,Brief.Problem,String>):
  (file,result) = got
  match result:
    case Fail{_}:
      do IO<Result<&2,&2,Brief.Problem,String>>:
        File.close(file)
        return Fail{Brief.Problem{"stdin","Unable to read brief request"}}
    case Done{bytes}: read_chunk(file,bytes,total,chunks,next)

def read(fuel: Nat,+total: U32,chunks: List<&2,List<&2,U32>>,file: File) -> IO(Result<&2,&2,Brief.Problem,String>):
  match fuel:
    case 0n:
      do IO<Result<&2,&2,Brief.Problem,String>>:
        File.close(file)
        return Fail{Brief.Problem{"input_limit","Brief stdin read limit exceeded"}}
    case 1n+rest:
      do IO<Result<&2,&2,Brief.Problem,String>>:
        got : File & Result<&1,&1,U32 & String,List<&2,U32>> <-
          File.read_bytes(file,U32.min(4096,U32.add(U32.sub(stdin_limit(),total),1)))
        read_result(got,total,chunks,f => n => parts => read(rest,n,parts,f))

def stdin_opened(result: Result<&1,&1,U32 & String,File>) -> IO(Result<&2,&2,Brief.Problem,String>):
  match result:
    case Fail{_}: IO.pure(Result<&2,&2,Brief.Problem,String>,Fail{Brief.Problem{"stdin","Unable to open brief stdin"}})
    case Done{file}: read(131073n,0,[],file)

def stdin() -> IO(Result<&2,&2,Brief.Problem,String>):
  do IO<Result<&2,&2,Brief.Problem,String>>:
    opened : Result<&1,&1,U32 & String,File> <- File.open("/dev/stdin","r")
    stdin_opened(opened)

def error(problem: Brief.Problem) -> String:
  Brief.Problem{code,message} = problem
  "{\"protocol\":" ++ Json.quote(protocol()) ++ ",\"kind\":\"error\",\"code\":" ++ Json.quote(code) ++
    ",\"message\":" ++ Json.quote(message) ++ "}"

def emit(result: Result<&2,&2,Brief.Problem,String>) -> IO(Unit):
  match result:
    case Done{text}: IO.print(text)
    case Fail{problem}: IO.die(Unit,2,error(problem))

def run_parsed(db: U32,result: Result<&2,&2,Brief.Problem,Command>) -> IO(Unit):
  match result:
    case Fail{problem}: emit(Fail{problem})
    case Done{command}:
      do IO<Unit>:
        response : Result<&2,&2,Brief.Problem,String> <- dispatch(db,command)
        emit(response)

def run_body(db: U32,operation: String,result: Result<&2,&2,Brief.Problem,String>) -> IO(Unit):
  match result:
    case Fail{problem}: emit(Fail{problem})
    case Done{body}:
      run_parsed(db,parse(operation,body))

def run(db: U32,operation: String) -> IO(Unit):
  do IO<Unit>:
    request : Result<&2,&2,Brief.Problem,String> <- stdin()
    run_body(db,operation,request)

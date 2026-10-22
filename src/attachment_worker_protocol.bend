import Base
import ./domain.bend as Domain

# Pure protocol only. The parent owns authorization and capture identities.
# No child field is SQL, a command, an export path, or capture metadata.
type Request is Data:
  Request{program: String,root: String,relative: String,nonce: String}

type Route is Data:
  Worker{request: Request}
  Rejected{}
  Ordinary{args: List<&2,String>}

type Payload is Data:
  Payload{count: U32,digest: String,bytes: List<&2,U32>}

type ReadStep is Data:
  Progress{offset: U32}
  Complete{}
  Unstable{}

type ReadPermit is Data:
  ReadPermit{remaining: Nat,maximum: U32}

def byte_limit() -> U32:
  1048576

def output_limit() -> U32:
  2101248

def timeout_ms() -> U32:
  30000

def text_next(valid: Bool,left: U32,next: U32 -> Bool) -> Bool:
  match valid:
    case False{}: False{}
    case True{}: next(left)

# UTF8 byte limit, NUL exclusion and scalar validation precede path operations.
def bounded(text: String,+left: U32) -> Bool:
  match text:
    case SNil{}: True{}
    case SCon{Chr{+cp},rest}:
      +width = U32.inc(Domain.encode_width(cp))
      text_next(Domain.scalar(cp) && U32.is_ne(cp,0) && U32.is_le(width,left),
        U32.sub(left,width),remaining => bounded(rest,remaining))

def components(parts: List<&2,String>) -> Bool:
  match parts:
    case []: True{}
    case +part <> rest:
      Bool.not(String.is_empty(part)) && Bool.not(String.eq(part,".")) &&
        Bool.not(String.eq(part,"..")) && components(rest)

def absolute_parts(parts: List<&2,String>) -> Bool:
  match parts:
    case "" <> []: False{}
    case "" <> rest: components(rest)
    case _: False{}

def absolute_checked(valid: Bool,path: String) -> Bool:
  match valid:
    case False{}: False{}
    case True{}: absolute_parts(String.split(path,'/'))

# Canonical spelling only; this is not a replacement for kernel confinement.
def absolute(+path: String) -> Bool:
  absolute_checked(bounded(path,4096),path)

def relative_checked(valid: Bool,path: String) -> Bool:
  match valid:
    case False{}: False{}
    case True{}: components(String.split(path,'/'))

def relative(+path: String) -> Bool:
  relative_checked(bounded(path,4096) && Bool.not(String.is_empty(path)),path)

def nibble(+cp: U32) -> U32:
  Bool.pick(U32,U32.is_ge(cp,48) && U32.is_le(cp,57),U32.sub(cp,48),
    Bool.pick(U32,U32.is_ge(cp,97) && U32.is_le(cp,102),U32.add(U32.sub(cp,97),10),16))

def hex_length(text: String,left: Nat) -> Bool:
  match text left:
    case SNil{} 0n: True{}
    case SCon{Chr{cp},rest} 1n+left: U32.is_lt(nibble(cp),16) && hex_length(rest,left)
    case _ _: False{}

def request_fields(value: Request) -> Bool:
  Request{+program,+root,+path,nonce} = value
  absolute(program) && absolute(root) && relative(path) && hex_length(nonce,32n) &&
    bounded(root ++ "/" ++ path,4096) &&
    Bool.not(String.eq(program,root)) && Bool.not(String.starts_with(program,root ++ "/"))

def request_bounded(valid: Bool,value: Request) -> Bool:
  match valid:
    case False{}: False{}
    case True{}: request_fields(value)

def valid_request(+value: Request) -> Bool:
  Request{program,root,path,nonce} = value
  request_bounded(bounded(program,4096) && bounded(root,4096) && bounded(path,4096) && bounded(nonce,32),value)

def admitted(valid: Bool,value: Request) -> Route:
  match valid:
    case True{}: Worker{value}
    case False{}: Rejected{}

def request(+value: Request) -> Route:
  admitted(valid_request(value),value)

def ordinary(reserved: Bool,command: String,args: List<&2,String>) -> Route:
  match reserved:
    case True{}: Rejected{}
    case False{}: Ordinary{command <> args}

def classify(program: String,args: List<&2,String>) -> Route:
  match args:
    case "--attachment-worker-v1" <> root <> relative <> nonce <> []:
      request(Request{program,root,relative,nonce})
    case "--attachment-worker-v1" <> _: Rejected{}
    case []: Ordinary{[]}
    case +command <> rest: ordinary(String.starts_with(command,"--attachment-worker"),command,rest)

def target(value: Request) -> String:
  Request{_,root,relative,_} = value
  root ++ "/" ++ relative

def read_admitted(valid: Bool,+offset: U32,received: U32,finished: Bool) -> ReadStep:
  match valid received finished:
    case False{} _ _: Unstable{}
    case True{} 0 True{}: Complete{}
    case True{} 0 False{}: Unstable{}
    case True{} count _: Progress{U32.add(offset,count)}

# Short reads advance; only an explicit zero-byte read at the exact extent is
# EOF. A byte beyond the selected size is instability, never a truncated success.
def read_step(+expected: U32,+offset: U32,+received: U32) -> ReadStep:
  read_admitted(U32.is_le(expected,byte_limit()) && U32.is_le(offset,expected) &&
    U32.is_le(received,32768) && U32.is_le(received,U32.sub(expected,offset)),
    offset,received,U32.is_eq(offset,expected))

def permit(valid: Bool,left: Nat,expected: U32,offset: U32) -> Result<&2,&2,String,ReadPermit>:
  match valid:
    case False{}: Fail{"attachment_worker_unstable"}
    case True{}: Done{ReadPermit{left,U32.min(32768,U32.inc(U32.sub(expected,offset)))}}

# Fuel is consumed before every actual read, including the explicit EOF probe.
def read_plan(fuel: Nat,+expected: U32,+offset: U32) -> Result<&2,&2,String,ReadPermit>:
  match fuel:
    case 0n: Fail{"attachment_worker_read_limit"}
    case 1n+left: permit(U32.is_le(expected,byte_limit()) && U32.is_le(offset,expected),left,expected,offset)

def byte_scan(bytes: List<&2,U32>,left: U32) -> Bool:
  match bytes left:
    case [] _: True{}
    case _ <> _ 0: False{}
    case byte <> rest +left: U32.is_le(byte,255) && byte_scan(rest,U32.sub(left,1))

def hex(bytes: List<&2,U32>) -> String:
  match bytes:
    case []: ""
    case +byte <> rest:
      SCon{Domain.hex_digit(U32.div(byte,16)),SCon{Domain.hex_digit(U32.mod(byte,16)),hex(rest)}}

def wire_valid(valid: Bool,nonce: String,+bytes: List<&2,U32>) -> Result<&2,&2,String,String>:
  match valid:
    case False{}: Fail{"attachment_worker_invalid_payload"}
    case True{}:
      Done{"JBATT1 " ++ nonce ++ " " ++ U32.show(U32.from_nat(List.length(&2,U32,bytes))) ++
        " " ++ Domain.digest(bytes) ++ "\n" ++ hex(bytes) ++ "\n"}

def wire(+nonce: String,+bytes: List<&2,U32>) -> Result<&2,&2,String,String>:
  wire_valid(hex_length(nonce,32n) && byte_scan(bytes,byte_limit()),nonce,bytes)

def decoded_pair(valid: Bool,byte: U32,left: U32,bytes: List<&2,U32>,
  next: U32 -> List<&2,U32> -> Result<&2,&2,String,List<&2,U32>>) -> Result<&2,&2,String,List<&2,U32>>:
  match valid:
    case False{}: Fail{"attachment_worker_protocol"}
    case True{}: next(left,byte <> bytes)

def decode_hex(text: String,left: U32,bytes: List<&2,U32>) -> Result<&2,&2,String,List<&2,U32>>:
  match text left:
    case SNil{} 0: Done{List.reverse(&2,U32,bytes)}
    case SCon{Chr{+a},SCon{Chr{+b},rest}} +left:
      decoded_pair(U32.is_gt(left,0) && U32.is_lt(nibble(a),16) && U32.is_lt(nibble(b),16),
        U32.add(U32.mul(nibble(a),16),nibble(b)),U32.sub(left,1),bytes,
        remaining => acc => decode_hex(rest,remaining,acc))
    case _ _: Fail{"attachment_worker_protocol"}

def verified(valid: Bool,count: U32,digest: String,bytes: List<&2,U32>) -> Result<&2,&2,String,Payload>:
  match valid:
    case False{}: Fail{"attachment_worker_digest"}
    case True{}: Done{Payload{count,digest,bytes}}

def digest_checked(result: Result<&2,&2,String,List<&2,U32>>,count: U32,+digest: String) -> Result<&2,&2,String,Payload>:
  match result:
    case Fail{error}: Fail{error}
    case Done{+bytes}: verified(String.eq(Domain.digest(bytes),digest),count,digest,bytes)

def count_checked(valid: Bool,+count: U32,digest: String,body: String) -> Result<&2,&2,String,Payload>:
  match valid:
    case False{}: Fail{"attachment_worker_protocol"}
    case True{}: digest_checked(decode_hex(body,count,[]),count,digest)

def number(value: Maybe<&2,U32>,digest: String,body: String) -> Result<&2,&2,String,Payload>:
  match value:
    case None{}: Fail{"attachment_worker_protocol"}
    case Some{+count}: count_checked(U32.is_le(count,byte_limit()),count,digest,body)

def header_valid(valid: Bool,count: String,digest: String,body: String) -> Result<&2,&2,String,Payload>:
  match valid:
    case False{}: Fail{"attachment_worker_protocol"}
    case True{}: number(Domain.parse_u32(count),digest,body)

def header(parts: List<&2,String>,expected: String,body: String) -> Result<&2,&2,String,Payload>:
  match parts:
    case "JBATT1" <> nonce <> +count <> +digest <> []:
      header_valid(String.eq(nonce,expected) && bounded(count,7) && hex_length(digest,64n),count,digest,body)
    case _: Fail{"attachment_worker_protocol"}

def lines(parts: List<&2,String>,expected: String) -> Result<&2,&2,String,Payload>:
  match parts:
    case first <> body <> "" <> []: header(String.split(first,' '),expected,body)
    case _: Fail{"attachment_worker_protocol"}

def parse_bounded(valid: Bool,text: String,expected: String) -> Result<&2,&2,String,Payload>:
  match valid:
    case False{}: Fail{"attachment_worker_protocol"}
    case True{}: lines(String.split(text,'\n'),expected)

def parse(+text: String,+expected: String) -> Result<&2,&2,String,Payload>:
  parse_bounded(bounded(text,output_limit()) && hex_length(expected,32n),text,expected)

def response(result: Result<&1,&1,U32 & String,U32 & (String & String)>,expected: String) -> Result<&2,&2,String,Payload>:
  match result:
    case Fail{_}: Fail{"attachment_worker_transport"}
    case Done{(0,(text,""))}: parse(text,expected)
    case Done{(73,("","attachment_worker_missing\n"))}: Fail{"attachment_worker_missing"}
    case Done{(74,("","attachment_worker_blocked\n"))}: Fail{"attachment_worker_blocked"}
    case Done{(75,("","attachment_worker_size_limit\n"))}: Fail{"attachment_worker_size_limit"}
    case Done{(76,("","attachment_worker_unstable\n"))}: Fail{"attachment_worker_unstable"}
    case Done{(76,("","attachment_worker_read_limit\n"))}: Fail{"attachment_worker_read_limit"}
    case Done{_}: Fail{"attachment_worker_failed"}

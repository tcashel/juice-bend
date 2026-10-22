import Base
import ./domain.bend as D
import ./attachment_root_rules.bend as Rules
import ./attachment_worker_protocol.bend as Worker

# No filesystem operation or relative-path inference. A file URL is decoded
# once into strict UTF8, then subjected to the same component policy as paths.
def answer() -> Data: Result<&2,&2,String,String>

def nibble(+c: U32) -> U32:
  Bool.pick(U32,U32.is_ge(c,65) && U32.is_le(c,70),U32.add(U32.sub(c,65),10),Worker.nibble(c))

def decoded(value: Result<&2,&2,String,String>) -> answer():
  match value:
    case Fail{_}: Fail{"attachment_capture_url_malformed"}
    case Done{+path}: Bool.pick(answer(),Rules.path(path),Done{path},Fail{"attachment_capture_path_blocked"})

def percent(valid: Bool,byte: U32,acc: List<&2,U32>,next: List<&2,U32> -> answer()) -> answer():
  match valid:
    case False{}: Fail{"attachment_capture_url_malformed"}
    case True{}: next(byte <> acc)

def unescape(bytes: List<&2,U32>,acc: List<&2,U32>) -> answer():
  match bytes:
    case []: decoded(D.decode(List.reverse(&2,U32,acc)))
    case 37 <> a <> b <> rest:
      +hi = nibble(a)
      +lo = nibble(b)
      percent(U32.is_lt(hi,16) && U32.is_lt(lo,16),U32.add(U32.mul(hi,16),lo),acc,
        prior => unescape(rest,prior))
    case 37 <> _: Fail{"attachment_capture_url_malformed"}
    case 63 <> _: Fail{"attachment_capture_url_unsupported"}
    case 35 <> _: Fail{"attachment_capture_url_unsupported"}
    case byte <> rest: unescape(rest,byte <> acc)

def url_kind(file: Bool,localhost: Bool,value: String) -> answer():
  match file localhost:
    case True{} _: unescape(D.encode(String.drop(value,7n)),[])
    case False{} True{}: unescape(D.encode(String.drop(value,16n)),[])
    case False{} False{}: Fail{"attachment_capture_url_unsupported"}

def url_allowed(valid: Bool,+value: String) -> answer():
  match valid:
    case False{}: Fail{"attachment_capture_url_malformed"}
    case True{}: url_kind(String.starts_with(value,"file:///"),String.starts_with(value,"file://localhost/"),value)

def url(+value: String) -> answer():
  url_allowed(Worker.bounded(value,4096),value)

def path(+value: String) -> answer():
  Bool.pick(answer(),Rules.path(value),Done{value},Fail{"attachment_capture_path_blocked"})

def relative_checked(valid: Bool,root: String,target: String) -> answer():
  match valid:
    case False{}: Fail{"attachment_capture_outside_root"}
    case True{}: Done{String.drop(target,Nat.add(String.length(root),1n))}

def relative(+root: String,+target: String) -> answer():
  relative_checked(Rules.beneath(root,target),root,target)

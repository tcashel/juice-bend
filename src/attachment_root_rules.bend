import Base
import ./attachment_worker_protocol.bend as Worker

# All counters remain exact decimal strings; the pinned Nat is only48 bits.
def digits(value: String) -> Bool:
  match value:
    case "": True{}
    case SCon{Chr{+c},rest}: U32.is_ge(c,48) && U32.is_le(c,57) && digits(rest)

def positive(value: String) -> Bool:
  match value:
    case SCon{Chr{+c},rest}: U32.is_ge(c,49) && U32.is_le(c,57) && digits(rest)
    case "": False{}

def identity_checked(valid: Bool,+value: String) -> Bool:
  match valid:
    case False{}: False{}
    case True{}: positive(value) && (Nat.is_lt(String.length(value),19n) ||
      Bool.not(Cmp.is_gt(String.order(value,"9223372036854775807"))))

def identity(+value: String) -> Bool:
  identity_checked(Worker.bounded(value,19),value)

def carry(reversed: String) -> String:
  match reversed:
    case "": "1"
    case SCon{'9',rest}: SCon{'0',carry(rest)}
    case SCon{Chr{c},rest}: SCon{Chr{U32.inc(c)},rest}

def increment_checked(valid: Bool,value: String) -> Maybe<&2,String>:
  match valid:
    case False{}: None{}
    case True{}: Some{String.reverse(carry(String.reverse(value)))}

# Zero is accepted only as the allocation seed for an empty root table.
def increment(+value: String) -> Maybe<&2,String>:
  increment_checked((String.eq(value,"0") || identity(value)) &&
    Bool.not(String.eq(value,"9223372036854775807")),value)

def no_controls(value: String) -> Bool:
  match value:
    case "": True{}
    case SCon{Chr{+c},rest}: U32.is_ge(c,32) &&
      (U32.is_lt(c,127) || U32.is_gt(c,159)) && no_controls(rest)

def path_checked(valid: Bool,value: String) -> Bool:
  match valid:
    case False{}: False{}
    case True{}: no_controls(value)

def path(+value: String) -> Bool:
  path_checked(Worker.absolute(value),value)

def beneath(+root: String,+target: String) -> Bool:
  path(root) && path(target) && String.starts_with(target,root ++ "/")

# A metadata-only realpath response is exactly one newline-terminated value.
# Embedded line breaks/control characters, stderr and transport errors refuse.
def canonical_value(valid: Bool,value: String) -> Maybe<&2,String>:
  match valid:
    case False{}: None{}
    case True{}: Some{value}

def resolved_output(code: U32,+out: String,err: String) -> Maybe<&2,String>:
  +canonical = String.take(out,Nat.sub(String.length(out),1n))
  canonical_value(U32.is_eq(code,0) && String.is_empty(err) &&
    String.ends_with(out,"\n") && path(canonical),canonical)

def resolved(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Maybe<&2,String>:
  match result:
    case Fail{_}: None{}
    case Done{(code,(out,err))}: resolved_output(code,out,err)

def directory(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Bool:
  match result:
    case Done{(0,("",""))}: True{}
    case _: False{}

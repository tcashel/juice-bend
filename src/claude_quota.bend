import Base
import ./json.bend as Json
import ./domain.bend as Domain

# A passive status-line observation, not identity, freshness, billing or a fetch.
# Only these four numeric fields survive parsing. Missing/null is never zero.
type Failure is Data:
  Failure{code: String,message: String}

type QuotaWindow is Data:
  QuotaWindow{used_millionths: Maybe<&2,U32>,resets_at: Maybe<&2,Nat>}

type Observation is Data:
  Observation{five_hour: Maybe<&2,QuotaWindow>,seven_day: Maybe<&2,QuotaWindow>}

def byte_step(valid: Bool,budget: U32,next: U32 -> Maybe<&2,U32>) -> Maybe<&2,U32>:
  match valid:
    case False{}: None{}
    case True{}: next(budget)

def consume(text: String,+budget: U32) -> Maybe<&2,U32>:
  match text:
    case SNil{}: Some{budget}
    case SCon{Chr{+cp},rest}:
      +size = U32.inc(Domain.encode_width(cp))
      byte_step(Domain.scalar(cp) && U32.is_le(size,budget),U32.sub(budget,size),
        left => consume(rest,left))

def digit(+cp: U32) -> Bool:
  U32.is_ge(cp,48) && U32.is_le(cp,57)

def percent_step(valid: Bool,next: Unit -> Result<&2,&2,Failure,Maybe<&2,U32>>) -> Result<&2,&2,Failure,Maybe<&2,U32>>:
  match valid:
    case False{}:
      Fail{Failure{"invalid_percentage","Quota percentage must be an exact decimal from 0 through 100 with at most six meaningful fractional places; exponents are unsupported"}}
    case True{}: next(Unit{})

# Remaining fractional digits are permitted only when they are zero. In
# particular, 0.0000001 is refused rather than rounded to an invented zero.
def percent_fraction(text: String,+value: U32,+place: U32) -> Result<&2,&2,Failure,Maybe<&2,U32>>:
  match text:
    case SNil{}: Done{Some{value}}
    case SCon{Chr{+cp},rest}:
      +next_value = U32.add(value,U32.mul(U32.sub(cp,48),place))
      percent_step(digit(cp) && (U32.is_ne(place,0) || U32.is_eq(cp,48)) &&
        U32.is_le(next_value,100000000),_ => percent_fraction(rest,next_value,U32.div(place,10)))

def percent_whole(text: String,+value: U32) -> Result<&2,&2,Failure,Maybe<&2,U32>>:
  match text:
    case SNil{}: Done{Some{U32.mul(value,1000000)}}
    case SCon{Chr{46},rest}:
      percent_fraction(rest,U32.mul(value,1000000),100000)
    case SCon{Chr{+cp},rest}:
      +next_value = U32.add(U32.mul(value,10),U32.sub(cp,48))
      percent_step(digit(cp) && U32.is_le(next_value,100),_ => percent_whole(rest,next_value))

def percentage(value: Json.Json) -> Result<&2,&2,Failure,Maybe<&2,U32>>:
  match value:
    case Json.JNull{}: Done{None{}}
    case Json.JNumber{lexeme}: percent_whole(lexeme,0)
    case _:
      Fail{Failure{"invalid_percentage","Quota percentage must be an exact decimal from 0 through 100 with at most six meaningful fractional places; exponents are unsupported"}}

def digits(text: String) -> Bool:
  match text:
    case SNil{}: True{}
    case SCon{Chr{cp},rest}: digit(cp) && digits(rest)

def reset_bound(valid: Bool,value: Nat) -> Result<&2,&2,Failure,Maybe<&2,Nat>>:
  match valid:
    case True{}: Done{Some{value}}
    case False{}:
      Fail{Failure{"invalid_reset","Quota reset must be an exact nonnegative integer Unix timestamp no greater than 253402300799"}}

def reset_number(value: Maybe<&2,Nat>) -> Result<&2,&2,Failure,Maybe<&2,Nat>>:
  match value:
    case None{}:
      Fail{Failure{"invalid_reset","Quota reset must be an exact nonnegative integer Unix timestamp no greater than 253402300799"}}
    case Some{+number}: reset_bound(Nat.is_le(number,Nat.add(Nat.mul(253n,1000000000n),402300799n)),number)

def reset_digits(valid: Bool,text: String) -> Result<&2,&2,Failure,Maybe<&2,Nat>>:
  match valid:
    case True{}: reset_number(Nat.read(text))
    case False{}:
      Fail{Failure{"invalid_reset","Quota reset must be an exact nonnegative integer Unix timestamp no greater than 253402300799"}}

def reset(value: Json.Json) -> Result<&2,&2,Failure,Maybe<&2,Nat>>:
  match value:
    case Json.JNull{}: Done{None{}}
    case Json.JNumber{+lexeme}:
      reset_digits(Bool.not(String.is_empty(lexeme)) && digits(lexeme),lexeme)
    case _:
      Fail{Failure{"invalid_reset","Quota reset must be an exact nonnegative integer Unix timestamp no greater than 253402300799"}}

def window(value: Json.Json) -> Result<&2,&2,Failure,Maybe<&2,QuotaWindow>>:
  match value:
    case Json.JNull{}: Done{None{}}
    case Json.JObject{+fields}:
      do Result<&2,&2,Failure,Maybe<&2,QuotaWindow>>:
        used : Maybe<&2,U32> <- percentage(Json.field(Json.JObject{fields},"used_percentage"))
        resets : Maybe<&2,Nat> <- reset(Json.field(Json.JObject{fields},"resets_at"))
        return Some{QuotaWindow{used,resets}}
    case _:
      Fail{Failure{"invalid_shape","Quota windows must be objects or null"}}

def rate_limits(value: Json.Json) -> Result<&2,&2,Failure,Observation>:
  match value:
    case Json.JNull{}: Done{Observation{None{},None{}}}
    case Json.JObject{+fields}:
      do Result<&2,&2,Failure,Observation>:
        five : Maybe<&2,QuotaWindow> <- window(Json.field(Json.JObject{fields},"five_hour"))
        seven : Maybe<&2,QuotaWindow> <- window(Json.field(Json.JObject{fields},"seven_day"))
        return Observation{five,seven}
    case _:
      Fail{Failure{"invalid_shape","Quota rate_limits must be an object or null"}}

def root(value: Json.Json) -> Result<&2,&2,Failure,Observation>:
  match value:
    case Json.JObject{fields}: rate_limits(Json.field(Json.JObject{fields},"rate_limits"))
    case _:
      Fail{Failure{"invalid_shape","Quota input must be a JSON object"}}

def parsed(value: Result<&2,&2,String,Json.Json>) -> Result<&2,&2,Failure,Observation>:
  match value:
    case Done{json}: root(json)
    case Fail{_}:
      Fail{Failure{"invalid_json","Quota input must be strict JSON with unique object keys"}}

def bounded(left: Maybe<&2,U32>,text: String) -> Result<&2,&2,Failure,Observation>:
  match left:
    case None{}:
      Fail{Failure{"input_limit","Quota input exceeds 1048576 UTF-8 bytes or contains an invalid Unicode scalar"}}
    case Some{_}: parsed(Json.parse(text))

# The CLI must strictly decode its original input bytes before supplying String.
# Json.parse rejects all duplicate decoded object keys, including unknown keys.
def parse(+text: String) -> Result<&2,&2,Failure,Observation>:
  bounded(consume(text,1048576),text)

def empty_window(value: Maybe<&2,QuotaWindow>) -> Bool:
  match value:
    case None{}: True{}
    case Some{QuotaWindow{None{},None{}}}: True{}
    case _: False{}

def empty(value: Observation) -> Bool:
  Observation{five,seven} = value
  empty_window(five) && empty_window(seven)

def same_percent(a: Maybe<&2,U32>,b: Maybe<&2,U32>) -> Bool:
  match a b:
    case None{} None{}: True{}
    case Some{x} Some{y}: U32.is_eq(x,y)
    case _ _: False{}

def same_reset(a: Maybe<&2,Nat>,b: Maybe<&2,Nat>) -> Bool:
  match a b:
    case None{} None{}: True{}
    case Some{x} Some{y}: Nat.is_eq(x,y)
    case _ _: False{}

def same_window(a: Maybe<&2,QuotaWindow>,b: Maybe<&2,QuotaWindow>) -> Bool:
  match a b:
    case None{} None{}: True{}
    case Some{QuotaWindow{used,reset}} Some{QuotaWindow{other_used,other_reset}}:
      same_percent(used,other_used) && same_reset(reset,other_reset)
    case _ _: False{}

def same(a: Observation,b: Observation) -> Bool:
  Observation{five,seven} = a
  Observation{other_five,other_seven} = b
  same_window(five,other_five) && same_window(seven,other_seven)

def fraction_digits(fuel: Nat,+value: U32,+place: U32) -> String:
  match fuel value:
    case 0n _: ""
    case _ 0: ""
    case 1n+left _:
      SCon{Chr{U32.add(48,U32.div(value,place))},
        fraction_digits(left,U32.mod(value,place),U32.div(place,10))}

def percent_parts(value: U32,+fraction: U32) -> String:
  match fraction:
    case 0: U32.show(U32.div(value,1000000))
    case _:
      U32.show(U32.div(value,1000000)) ++ "." ++ fraction_digits(6n,fraction,100000)

def percent_text(+value: U32) -> String:
  percent_parts(value,U32.mod(value,1000000))

def encode_percentage(value: Maybe<&2,U32>) -> String:
  match value:
    case None{}: "null"
    case Some{value}: percent_text(value)

def encode_reset(value: Maybe<&2,Nat>) -> String:
  match value:
    case None{}: "null"
    case Some{value}: Nat.show(value)

def encode_window(value: Maybe<&2,QuotaWindow>) -> String:
  match value:
    case None{}: "null"
    case Some{QuotaWindow{used,reset}}:
      "{\"used_percentage\":" ++ encode_percentage(used) ++ ",\"resets_at\":" ++ encode_reset(reset) ++ "}"

def encode(value: Observation) -> String:
  Observation{five,seven} = value
  "{\"rate_limits\":{\"five_hour\":" ++ encode_window(five) ++ ",\"seven_day\":" ++ encode_window(seven) ++ "}}"

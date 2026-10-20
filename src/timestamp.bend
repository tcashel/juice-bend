import Base
import ./query.bend as Query
import ./domain.bend as Domain

# Exact RFC3339 subset: years 0001..9999, second precision through nanoseconds,
# Z or a numeric ±HH:MM offset. Leap seconds and >9 fraction digits stay unknown.
# Normalization uses calendar arithmetic, never float/timezone/environment state.
type Zone is Data:
  Zone{negative: Bool, minutes: U32}

type FractionZone is Data:
  FractionZone{fraction: String, zone: Zone}

def number_result(value: Maybe<&2,U32>) -> U32:
  match value:
    case Some{n}:
      n
    case None{}:
      0

def number(value: String) -> U32:
  number_result(U32.read(value))

def digits(value: String) -> Bool:
  match value:
    case SNil{}:
      True{}
    case SCon{c,rest}:
      Char.is_digit(c) && digits(rest)

def leading_digits(value: String) -> Nat:
  match value:
    case SNil{}:
      0n
    case SCon{c,rest}:
      Bool.pick(Nat,Char.is_digit(c),1n+leading_digits(rest),0n)

def two(n: U32) -> String:
  +s = U32.show(n)
  String.repeat("0",Nat.sub(2n,String.length(s))) ++ s

def four(n: U32) -> String:
  +s = U32.show(n)
  String.repeat("0",Nat.sub(4n,String.length(s))) ++ s

def zone_numbers(sign: Char,+hour: U32,+minute: U32,valid: Bool) -> Result<&2,&2,String,Zone>:
  do Result<&2,&2,String,Zone>:
    Query.validate(valid && (hour <= 23 : U32) && (minute <= 59 : U32),"Invalid timestamp offset")
    return Zone{Char.is_eq(sign,'-'),(hour * 60 + minute : U32)}

def zone_chars(chars: List<&2,Char>) -> Result<&2,&2,String,Zone>:
  match chars:
    case ['Z']:
      Done{Zone{False{},0}}
    case [+sign,+a,+b,':',+c,+d]:
      zone_numbers(sign,(Query.digit(a) * 10 + Query.digit(b) : U32),(Query.digit(c) * 10 + Query.digit(d) : U32),
        (Char.is_eq(sign,'+') || Char.is_eq(sign,'-')) && Char.is_digit(a) && Char.is_digit(b) && Char.is_digit(c) && Char.is_digit(d))
    case _:
      Fail{"Timestamp requires Z or a numeric UTC offset"}

def fractional(+suffix: String) -> Result<&2,&2,String,FractionZone>:
  +n = leading_digits(suffix)
  do Result<&2,&2,String,FractionZone>:
    Query.validate((n > 0n : Nat) && (n <= 9n : Nat),"Timestamp fraction requires one to nine digits")
    zone : Zone <- zone_chars(String.to_list(String.drop(suffix,n)))
    return FractionZone{String.take(suffix,n) ++ String.repeat("0",Nat.sub(9n,n)),zone}

def suffix(value: String) -> Result<&2,&2,String,FractionZone>:
  match value:
    case SCon{'.',rest}:
      fractional(rest)
    case _:
      do Result<&2,&2,String,FractionZone>:
        zone : Zone <- zone_chars(String.to_list(value))
        return FractionZone{"000000000",zone}

def previous_date(+year: U32,+month: U32,+day: U32) -> String:
  +y = Bool.pick(U32,U32.is_eq(month,1),U32.sub(year,1),year)
  +m = Bool.pick(U32,U32.is_eq(month,1),12,U32.sub(month,1))
  Bool.pick(String,(day > 1 : U32),four(year) ++ "-" ++ two(month) ++ "-" ++ two(U32.sub(day,1)),
    four(y) ++ "-" ++ two(m) ++ "-" ++ two(Query.month_days(m,y)))

def next_date(+year: U32,+month: U32,+day: U32) -> String:
  +y = Bool.pick(U32,U32.is_eq(month,12),U32.add(year,1),year)
  +m = Bool.pick(U32,U32.is_eq(month,12),1,U32.add(month,1))
  Bool.pick(String,(day < Query.month_days(month,year) : U32),four(year) ++ "-" ++ two(month) ++ "-" ++ two(U32.add(day,1)),
    four(y) ++ "-" ++ two(m) ++ "-01")

def date_shift(+date: String,+total: U32) -> String:
  +y = number(String.take(date,4n))
  +m = number(String.take(String.drop(date,5n),2n))
  +d = number(String.drop(date,8n))
  Bool.pick(String,(total < 1440 : U32),previous_date(y,m,d),
    Bool.pick(String,(total >= 2880 : U32),next_date(y,m,d),date))

def normalized(date: String,+hour: U32,minute: U32,second: U32,zone_fraction: FractionZone) -> Result<&2,&2,String,String>:
  FractionZone{fraction,Zone{+negative,+offset}} = zone_fraction
  +local = (1440 + hour * 60 + minute : U32)
  +total = Bool.pick(U32,negative,U32.add(local,offset),U32.sub(local,offset))
  +utc_date = date_shift(date,total)
  do Result<&2,&2,String,String>:
    Query.validate(Query.date_valid(utc_date),"Timestamp UTC conversion exceeds supported calendar")
    return utc_date ++ "T" ++ two(U32.div(U32.mod(total,1440),60)) ++ ":" ++ two(U32.mod(total,60)) ++ ":" ++ two(second) ++ "." ++ fraction ++ "Z"

def parse(+value: String) -> Result<&2,&2,String,String>:
  +date = String.take(value,10n)
  +clock = String.take(String.drop(value,11n),8n)
  +hour = String.take(clock,2n)
  +minute = String.take(String.drop(clock,3n),2n)
  +second = String.take(String.drop(clock,6n),2n)
  do Result<&2,&2,String,String>:
    Query.validate(Query.length_ok(value,35n) && Query.date_valid(date) &&
      String.eq(String.take(String.drop(value,10n),1n),"T") &&
      String.eq(String.take(String.drop(clock,2n),1n),":") &&
      String.eq(String.take(String.drop(clock,5n),1n),":") &&
      Nat.is_eq(String.length(clock),8n) && digits(hour) && digits(minute) && digits(second) &&
      (number(hour) <= 23 : U32) && (number(minute) <= 59 : U32) && (number(second) <= 59 : U32),
      "Invalid recorded timestamp")
    rest : FractionZone <- suffix(String.drop(value,19n))
    normalized(date,number(hour),number(minute),number(second),rest)

def value(result: Result<&2,&2,String,String>) -> String:
  match result:
    case Done{text}:
      text
    case Fail{error}:
      ""

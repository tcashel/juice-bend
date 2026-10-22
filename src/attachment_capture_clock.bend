import Base
import ./sql.bend as Sql
import ./attachment_asset_types.bend as T
import ./attachment_root_rules.bend as Rules

# SQLite supplies wall-clock primitive text only. Bend validates and assembles
# exact signed64 milliseconds; no Julian-day/float or Nat conversion occurs.
def result() -> Data: Result<&2,&2,String,String>

def canonical(value: String) -> String:
  match value:
    case "": "0"
    case SCon{'0',rest}: canonical(rest)
    case other: other

def fraction(+value: String) -> Bool:
  match value:
    case SCon{Chr{+tens},SCon{Chr{+ones},SCon{'.',+rest}}}:
      U32.is_ge(tens,48) && U32.is_le(tens,53) && U32.is_ge(ones,48) && U32.is_le(ones,57) &&
        Nat.is_eq(String.length(rest),3n) && Rules.digits(rest)
    case _: False{}

def millis(allowed: Bool,+seconds: String,fractional: String) -> result():
  match allowed:
    case False{}: Fail{"attachment_capture_clock"}
    case True{}:
      +value = canonical(seconds ++ String.drop(fractional,3n))
      Bool.pick(result(),T.valid_time(value),Done{value},Fail{"attachment_capture_clock"})

def values(+seconds: String,+fractional: String) -> result():
  millis(T.valid_time(seconds) && fraction(fractional),seconds,fractional)

def rows(value: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>) -> result():
  match value:
    case Done{[[Sql.Cell.Text{seconds},Sql.Cell.Text{fractional}]]}: values(seconds,fractional)
    case _: Fail{"attachment_capture_clock"}

def now(db: U32) -> IO(result()):
  do IO<result()>:
    value : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <-
      Sql.query(db,"SELECT strftime('%s','now'),strftime('%f','now')",[],1)
    return rows(value)

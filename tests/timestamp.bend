import Base
import ../src/timestamp.bend as Time

def assert(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ label)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ label)

def same(got: Result<&2,&2,String,String>,expected: String) -> Bool:
  match got:
    case Done{value}:
      String.eq(value,expected)
    case Fail{error}:
      False{}

def invalid(got: Result<&2,&2,String,String>) -> Bool:
  match got:
    case Done{value}:
      False{}
    case Fail{error}:
      True{}

def main() -> IO(Unit):
  do IO<Unit>:
    assert(same(Time.parse("2026-10-20T12:34:56Z"),"2026-10-20T12:34:56.000000000Z"),"UTC normalized with exact zero fraction")
    assert(same(Time.parse("2026-10-20T12:34:56.123456789Z"),"2026-10-20T12:34:56.123456789Z"),"nanoseconds preserved exactly")
    assert(same(Time.parse("2026-10-20T12:34:56.12Z"),"2026-10-20T12:34:56.120000000Z"),"fraction right-padded exactly")
    assert(same(Time.parse("2026-10-20T12:34:56+04:30"),"2026-10-20T08:04:56.000000000Z"),"positive offset normalized")
    assert(same(Time.parse("2026-10-20T12:34:56-04:30"),"2026-10-20T17:04:56.000000000Z"),"negative offset normalized")
    assert(same(Time.parse("2026-01-01T00:05:00+01:00"),"2025-12-31T23:05:00.000000000Z"),"offset crosses previous year")
    assert(same(Time.parse("2026-12-31T23:05:00-01:00"),"2027-01-01T00:05:00.000000000Z"),"offset crosses next year")
    assert(same(Time.parse("2024-03-01T00:05:00+01:00"),"2024-02-29T23:05:00.000000000Z"),"offset previous date respects leap year")
    assert(same(Time.parse("1900-03-01T00:05:00+01:00"),"1900-02-28T23:05:00.000000000Z"),"offset previous date respects nonleap century")
    assert(invalid(Time.parse("unknown")),"unknown timestamp rejected")
    assert(invalid(Time.parse("2026-02-30T00:00:00Z")),"invalid calendar date rejected")
    assert(invalid(Time.parse("2026-10-20T24:00:00Z")),"hour overflow rejected")
    assert(invalid(Time.parse("2026-10-20T12:60:00Z")),"minute overflow rejected")
    assert(invalid(Time.parse("2026-10-20T12:00:60Z")),"unsupported leap second explicit")
    assert(invalid(Time.parse("2026-10-20T12:00:00")),"missing timezone rejected")
    assert(invalid(Time.parse("2026-10-20T12:00:00.1234567890Z")),"subnanosecond precision not truncated")
    assert(invalid(Time.parse("0001-01-01T00:00:00+01:00")),"UTC calendar underflow rejected")
    assert(invalid(Time.parse("9999-12-31T23:59:00-01:00")),"UTC calendar overflow rejected")

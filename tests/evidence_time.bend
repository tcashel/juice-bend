import Base
import ../src/evidence.bend as Evidence
import ../src/provenance.bend as P

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def key(value: P.Attribution) -> String:
  match value:
    case P.Content{key,_,_}:
      key
    case _:
      ""

def candidate(key: String,time: String) -> P.Candidate:
  P.Candidate{"/synthetic/time",key,Evidence.candidate_time(time),["let exact = 1"],True{}}

def main() -> IO(Unit):
  do IO<Unit>:
    assert(String.eq(Evidence.candidate_time("2026-10-20T12:34:56.123456789Z"),
      "20261020123456123456789"),"RFC3339 calendar rank preserves every nanosecond digit")
    assert(String.eq(Evidence.candidate_time("2026-10-20T08:34:56.123456789-04:00"),
      Evidence.candidate_time("2026-10-20T12:34:56.123456789Z")),"equal offset instants have equal exact provenance ranks")
    assert(Cmp.is_gt(P.decimal_compare(Evidence.candidate_time("2026-10-20T00:00:00.000000002Z"),
      Evidence.candidate_time("2026-10-20T00:00:00.000000001Z"))),"one nanosecond determines exact order beyond float precision")
    assert(Cmp.is_gt(P.decimal_compare(Evidence.candidate_time("2026-01-01T00:00:00Z"),
      Evidence.candidate_time("2025-12-31T23:59:59.999999999Z"))),"UTC date boundary preserves exact rank order")
    assert(P.decimal_valid(Evidence.candidate_time("0001-01-01T00:00:00Z")),
      "early supported years produce canonical decimal ranks")
    assert(String.eq(Evidence.candidate_time("unknown"),"0") &&
      String.eq(Evidence.candidate_time("2026-02-30T00:00:00Z"),"0"),"unknown and malformed timestamps do not invent rank")
    assert(String.eq(Evidence.candidate_time("9007199254740993"),"0"),
      "numeric timestamp of unspecified units cannot compete with UTC calendar rank")
    assert(String.eq(key(P.content("/synthetic/time",["let exact = 1"],
      [candidate("a-old","2026-10-20T12:00:00.000000001Z"),
       candidate("z-new","2026-10-20T12:00:00.000000002Z")])),"z-new"),
      "production content attribution chooses newer exact RFC3339 time before key order")
    assert(String.eq(key(P.content("/synthetic/time",["let exact = 1"],
      [candidate("z-equivalent","2026-10-20T08:00:00-04:00"),
       candidate("a-equivalent","2026-10-20T12:00:00Z")])),"a-equivalent"),
      "equal UTC instants retain deterministic stable-key ordering")

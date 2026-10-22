import Base
import ../src/attachment_root_rules.bend as Rules

# Pure contract tests. Every expected decimal and path is independent of the
# rule implementation; no filesystem, subprocess, SQLite or HOME access.
def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def same(value: Maybe<&2,String>,expected: String) -> Bool:
  match value:
    case Some{actual}: String.eq(actual,expected)
    case None{}: False{}

def absent(value: Maybe<&2,String>) -> Bool:
  match value:
    case None{}: True{}
    case Some{_}: False{}

def identities() -> IO(Unit):
  do IO<Unit>:
    check(Rules.identity("1") && Rules.identity("9") && Rules.identity("10"),
      "root identities are canonical positive decimal strings")
    check(Rules.identity("4294967295") && Rules.identity("4294967296") &&
      Rules.identity("281474976710655") && Rules.identity("281474976710656"),
      "identities retain exact values at and beyond U32 and pinned Nat boundaries")
    check(Rules.identity("9007199254740992") && Rules.identity("9007199254740993") &&
      Rules.identity("9223372036854775806") && Rules.identity("9223372036854775807"),
      "identities above float precision through signed64 maximum remain valid")
    check(Bool.not(Rules.identity("")) && Bool.not(Rules.identity("0")) &&
      Bool.not(Rules.identity("00")) && Bool.not(Rules.identity("01")) &&
      Bool.not(Rules.identity("-1")) && Bool.not(Rules.identity("+1")),
      "empty zero signed and leading-zero identities are refused")
    check(Bool.not(Rules.identity(" 1")) && Bool.not(Rules.identity("1 ")) &&
      Bool.not(Rules.identity("1\n")) && Bool.not(Rules.identity("1\0")) &&
      Bool.not(Rules.identity("1.0")) && Bool.not(Rules.identity("1e3")),
      "whitespace controls decimal points and exponent spellings never coerce to identities")
    check(Bool.not(Rules.identity("١")) && Bool.not(Rules.identity("１")) &&
      Bool.not(Rules.identity("1a")) && Bool.not(Rules.identity(SCon{Chr{55296},""})),
      "only ASCII decimal digits form identities and invalid scalars are refused")
    check(Bool.not(Rules.identity("9223372036854775808")) &&
      Bool.not(Rules.identity("9999999999999999999")) &&
      Bool.not(Rules.identity("10000000000000000000")) &&
      Bool.not(Rules.identity(String.repeat("1",4096n))),
      "signed64 overflow and oversized decimal identities are refused")

def increments() -> IO(Unit):
  do IO<Unit>:
    check(same(Rules.increment("0"),"1") && same(Rules.increment("1"),"2") &&
      same(Rules.increment("8"),"9"),
      "zero is an allocation seed and ordinary increments remain exact")
    check(same(Rules.increment("9"),"10") && same(Rules.increment("99"),"100") &&
      same(Rules.increment("1099"),"1100") && same(Rules.increment("1999"),"2000"),
      "decimal carry propagates across suffix nines without changing earlier digits")
    check(same(Rules.increment("4294967295"),"4294967296") &&
      same(Rules.increment("281474976710655"),"281474976710656") &&
      same(Rules.increment("281474976710656"),"281474976710657"),
      "decimal increment crosses U32 and pinned Nat limits without numeric conversion")
    check(same(Rules.increment("9007199254740992"),"9007199254740993") &&
      same(Rules.increment("9007199254740993"),"9007199254740994"),
      "adjacent values above float precision never round together")
    check(same(Rules.increment("999999999999999999"),"1000000000000000000") &&
      same(Rules.increment("9223372036854775799"),"9223372036854775800") &&
      same(Rules.increment("9223372036854775806"),"9223372036854775807"),
      "large carries and the last signed64 increment have explicit expected values")
    check(absent(Rules.increment("9223372036854775807")) &&
      absent(Rules.increment("9223372036854775808")) &&
      absent(Rules.increment("9999999999999999999")),
      "exhausted and overflowing counters refuse rather than wrap or allocate")
    check(absent(Rules.increment("")) && absent(Rules.increment("00")) &&
      absent(Rules.increment("01")) && absent(Rules.increment("-1")) &&
      absent(Rules.increment("+1")) && absent(Rules.increment("1\n")) &&
      absent(Rules.increment("１")),
      "increment preserves canonical input rules except its sole zero seed")

def point(code: U32) -> String:
  "/synthetic/" ++ SCon{Chr{code},""}

def controls(left: Nat,+code: U32) -> Bool:
  match left:
    case 0n: True{}
    case 1n+rest: Bool.not(Rules.path(point(code))) && controls(rest,U32.inc(code))

def paths() -> IO(Unit):
  do IO<Unit>:
    check(Rules.path("/synthetic") && Rules.path("/synthetic/child") &&
      Rules.path("/synthetic/café é 中文 🙂"),
      "absolute scalar Unicode paths preserve accents combining sequences CJK and emoji")
    check(Rules.path("/synthetic/ space ") && Rules.path("/synthetic/a'b;$()") &&
      Rules.path("/synthetic/.hidden") && Rules.path("/synthetic/..."),
      "ordinary literal filename characters and nontraversal dot names remain usable")
    check(Bool.not(Rules.path("")) && Bool.not(Rules.path("relative")) &&
      Bool.not(Rules.path("/")) && Bool.not(Rules.path("//")) &&
      Bool.not(Rules.path("//synthetic")),
      "empty relative root-only and leading-empty-component paths are refused")
    check(Bool.not(Rules.path("/synthetic/")) && Bool.not(Rules.path("/synthetic//child")) &&
      Bool.not(Rules.path("/synthetic/./child")) && Bool.not(Rules.path("/synthetic/../child")) &&
      Bool.not(Rules.path("/synthetic/.")) && Bool.not(Rules.path("/synthetic/..")),
      "empty and dot components are refused at internal and final positions")
    check(controls(32n,0) && Bool.not(Rules.path(point(127))),
      "every C0 control including NUL and DEL is refused in a component")
    check(controls(32n,128) && Bool.not(Rules.path("/synthetic/\u{85}/child")),
      "every Unicode C1 control including NEL is refused")
    check(Rules.path(point(32)) && Rules.path(point(126)) && Rules.path(point(160)),
      "ordinary characters immediately outside control ranges remain accepted")
    check(Rules.path(point(55295)) && Rules.path(point(57344)) && Rules.path(point(1114111)),
      "valid scalar endpoints around surrogate range and Unicode maximum are supported")
    check(Bool.not(Rules.path(point(55296))) && Bool.not(Rules.path(point(57343))) &&
      Bool.not(Rules.path(point(1114112))) && Bool.not(Rules.path(point(4294967295))),
      "surrogate endpoints and values above Unicode maximum are refused")
    check(Rules.path("/" ++ String.repeat("x",4095n)) &&
      Bool.not(Rules.path("/" ++ String.repeat("x",4096n))),
      "ASCII absolute path accepts exactly4096 UTF8 bytes and refuses4097")
    check(Rules.path("/" ++ String.repeat("é",2047n) ++ "x") &&
      Bool.not(Rules.path("/" ++ String.repeat("é",2047n) ++ "xx")),
      "two-byte scalars use byte capacity rather than character count")
    check(Rules.path("/" ++ String.repeat("中",1365n)) &&
      Bool.not(Rules.path("/" ++ String.repeat("中",1365n) ++ "x")),
      "three-byte scalars meet the exact4096-byte boundary")
    check(Rules.path("/" ++ String.repeat("🙂",1023n) ++ "abc") &&
      Bool.not(Rules.path("/" ++ String.repeat("🙂",1023n) ++ "abcd")),
      "four-byte scalars cannot bypass the exact UTF8 path limit")
    check(Rules.path("/" ++ String.repeat("é",1365n)) &&
      Bool.not(Rules.path("/" ++ String.repeat("é",1365n) ++ "x")),
      "combining sequences retain their actual UTF8 byte count without normalization")

def containment() -> IO(Unit):
  do IO<Unit>:
    check(Rules.beneath("/capture","/capture/a") &&
      Rules.beneath("/capture","/capture/nested/file") &&
      Rules.beneath("/café 中文","/café 中文/🙂.bin"),
      "valid descendants require an exact root plus component separator")
    check(Bool.not(Rules.beneath("/capture","/capture")) &&
      Bool.not(Rules.beneath("/capture","/capture/")) &&
      Bool.not(Rules.beneath("/capture","/capture-other/a")) &&
      Bool.not(Rules.beneath("/capture","/captured/a")),
      "root equality empty descendants and prefix siblings never count as beneath")
    check(Bool.not(Rules.beneath("/capture","/CAPTURE/a")) &&
      Bool.not(Rules.beneath("/café","/café/a")),
      "containment conservatively preserves exact case and scalar spelling")
    check(Bool.not(Rules.beneath("/","/capture/a")) &&
      Bool.not(Rules.beneath("/capture/..","/capture/../a")) &&
      Bool.not(Rules.beneath("/capture","/capture/../outside")) &&
      Bool.not(Rules.beneath("/capture","/capture/a\0")) &&
      Bool.not(Rules.beneath("capture","capture/a")),
      "both root and target must pass strict absolute path validation")

def realpath_results() -> IO(Unit):
  do IO<Unit>:
    check(same(Rules.resolved(Done{(0,("/synthetic/café é 中文 🙂\n",""))}),
      "/synthetic/café é 中文 🙂"),
      "successful realpath retains exact Unicode spelling and removes only its final newline")
    check(same(Rules.resolved(Done{(0,("/synthetic/ trailing space \n",""))}),
      "/synthetic/ trailing space "),
      "realpath output preserves filename whitespace instead of trimming it")
    check(absent(Rules.resolved(Done{(0,("",""))})) &&
      absent(Rules.resolved(Done{(0,("\n",""))})) &&
      absent(Rules.resolved(Done{(0,("/synthetic",""))})),
      "realpath requires one nonempty newline-terminated canonical path")
    check(absent(Rules.resolved(Done{(0,("/synthetic\n\n",""))})) &&
      absent(Rules.resolved(Done{(0,("/synthetic\n/other\n",""))})) &&
      absent(Rules.resolved(Done{(0,("/synthetic\r\n",""))})) &&
      absent(Rules.resolved(Done{(0,("/synthetic\0\n",""))})),
      "extra lines CRLF and embedded NUL cannot be accepted as canonical output")
    check(absent(Rules.resolved(Done{(0,("/\n",""))})) &&
      absent(Rules.resolved(Done{(0,("relative\n",""))})) &&
      absent(Rules.resolved(Done{(0,("/synthetic/../other\n",""))})) &&
      absent(Rules.resolved(Done{(0,(point(55296) ++ "\n",""))})) &&
      absent(Rules.resolved(Done{(0,(point(133) ++ "\n",""))})),
      "realpath output independently enforces root traversal scalar and control restrictions")
    check(absent(Rules.resolved(Done{(1,("/synthetic\n",""))})) &&
      absent(Rules.resolved(Done{(4294967295,("/synthetic\n",""))})) &&
      absent(Rules.resolved(Done{(0,("/synthetic\n","warning"))})) &&
      absent(Rules.resolved(Done{(0,("/synthetic\n","\n"))})),
      "nonzero exits or any stderr refuse even plausible canonical output")
    check(absent(Rules.resolved(Fail{(2,"synthetic missing executable")})) &&
      absent(Rules.resolved(Fail{(27,"synthetic output limit")})) &&
      absent(Rules.resolved(Fail{(60,"synthetic timeout")})),
      "transport missing overflow and timeout failures never become roots")
    check(same(Rules.resolved(Done{(0,("/" ++ String.repeat("x",4095n) ++ "\n",""))}),
      "/" ++ String.repeat("x",4095n)) &&
      absent(Rules.resolved(Done{(0,("/" ++ String.repeat("x",4096n) ++ "\n",""))})),
      "realpath terminator is outside the exact4096-byte canonical path budget")

def directory_results() -> IO(Unit):
  do IO<Unit>:
    check(Rules.directory(Done{(0,("",""))}),
      "directory observation accepts only a clean empty successful process result")
    check(Bool.not(Rules.directory(Done{(1,("",""))})) &&
      Bool.not(Rules.directory(Done{(2,("",""))})) &&
      Bool.not(Rules.directory(Done{(4294967295,("",""))})),
      "directory false command error and abnormal exit all refuse")
    check(Bool.not(Rules.directory(Done{(0,("yes",""))})) &&
      Bool.not(Rules.directory(Done{(0,("\n",""))})) &&
      Bool.not(Rules.directory(Done{(0,("","warning"))})) &&
      Bool.not(Rules.directory(Done{(0,("","\n"))})),
      "directory result refuses every nonempty stdout or stderr spelling")
    check(Bool.not(Rules.directory(Fail{(2,"synthetic missing executable")})) &&
      Bool.not(Rules.directory(Fail{(27,"synthetic output limit")})) &&
      Bool.not(Rules.directory(Fail{(60,"synthetic timeout")})),
      "directory transport failures cannot be mistaken for a successful observation")

def main() -> IO(Unit):
  do IO<Unit>:
    identities()
    increments()
    paths()
    containment()
    realpath_results()
    directory_results()

import Base
import ../src/attachment_capture_path.bend as P
import ../src/attachment_capture_clock.bend as C
import ../src/sql.bend as Sql
import ./attachment_asset_identity.bend as F

def good(value: P.answer(),expected: String) -> Bool:
  match value:
    case Done{actual}: String.eq(actual,expected)
    case _: False{}

def bad(value: P.answer(),expected: String) -> Bool:
  match value:
    case Fail{actual}: String.eq(actual,expected)
    case _: False{}

def repeat(left: Nat) -> String:
  match left:
    case 0n: ""
    case 1n+rest: "a" ++ repeat(rest)

def suite() -> IO(Unit):
  do IO<Unit>:
    F.assert(good(P.path("/synthetic/a%20b#q?"),"/synthetic/a%20b#q?"),"local paths retain literal percent hash and question-mark filename characters")
    F.assert(good(P.url("file:///synthetic/a%20b%23q%3F"),"/synthetic/a b#q?"),"file URL decodes legitimate escaped filename punctuation once")
    F.assert(good(P.url("file://localhost/synthetic/caf%C3%A9%20%E4%B8%AD%E6%96%87%20%F0%9F%99%82"),"/synthetic/café 中文 🙂"),"localhost file URL decodes exact multibyte UTF8")
    F.assert(good(P.url("file:///synthetic/a%252Fb"),"/synthetic/a%2Fb"),"double escaping is decoded only once")
    F.assert(good(P.url("file:///synthetic/a%2fb"),"/synthetic/a/b"),"encoded separator is validated as an actual component boundary")
    F.assert(bad(P.url("file:///synthetic/%"),"attachment_capture_url_malformed") && bad(P.url("file:///synthetic/%a"),"attachment_capture_url_malformed") && bad(P.url("file:///synthetic/%gg"),"attachment_capture_url_malformed"),"incomplete and nonhex escapes are malformed")
    F.assert(bad(P.url("file:///synthetic/%c0%af"),"attachment_capture_url_malformed") && bad(P.url("file:///synthetic/%ed%a0%80"),"attachment_capture_url_malformed"),"overlong and surrogate UTF8 escapes are malformed")
    F.assert(bad(P.url("file:///synthetic/a?query"),"attachment_capture_url_unsupported") && bad(P.url("file:///synthetic/a#fragment"),"attachment_capture_url_unsupported"),"URL query and fragment are unsupported rather than silently stripped")
    F.assert(bad(P.url("https://example.invalid/a"),"attachment_capture_url_unsupported") && bad(P.url("file://remote/synthetic/a"),"attachment_capture_url_unsupported") && bad(P.url("file:/synthetic/a"),"attachment_capture_url_unsupported"),"remote authorities and unsupported URL spellings never become local reads")
    F.assert(bad(P.url("file:///synthetic/%00a"),"attachment_capture_path_blocked") && bad(P.url("file:///synthetic/%0Aa"),"attachment_capture_path_blocked"),"decoded NUL and control characters are blocked")
    F.assert(bad(P.url("file:///synthetic/%2e%2e/private"),"attachment_capture_path_blocked") && bad(P.url("file:///synthetic/a/%2E/b"),"attachment_capture_path_blocked"),"decoded traversal and dot components are blocked")
    F.assert(bad(P.path("/synthetic//a"),"attachment_capture_path_blocked") && bad(P.path("/synthetic/a/"),"attachment_capture_path_blocked") && bad(P.path("relative/a"),"attachment_capture_path_blocked"),"empty components trailing slash and relative paths cannot be inferred")
    F.assert(good(P.relative("/synthetic/root","/synthetic/root/a b"),"a b") && bad(P.relative("/synthetic/root","/synthetic/rooted/a"),"attachment_capture_outside_root") && bad(P.relative("/synthetic/root","/synthetic/root"),"attachment_capture_outside_root"),"chosen root requires strict component descendant and a nonempty relative target")
    F.assert(good(P.path("/" ++ repeat(4095n)),"/" ++ repeat(4095n)) && bad(P.path("/" ++ repeat(4096n)),"attachment_capture_path_blocked"),"local path admission enforces exact4096 UTF8-byte limit")
    F.assert(bad(P.url("file:///" ++ repeat(4089n)),"attachment_capture_url_malformed"),"URL admission bounds original encoded text before decoding")
    F.assert(good(C.values("0","00.000"),"0") && good(C.values("0","00.007"),"7") && good(C.values("1","01.002"),"1002"),"clock preserves epoch zero and canonical millisecond spelling")
    F.assert(good(C.values("9007199254740","00.993"),"9007199254740993"),"clock preserves milliseconds above double precision without float conversion")
    F.assert(good(C.values("9223372036854775","00.807"),"9223372036854775807") && bad(C.values("9223372036854775","00.808"),"attachment_capture_clock"),"clock accepts exact signed64 maximum and rejects one millisecond overflow")
    F.assert(bad(C.values("01","01.000"),"attachment_capture_clock") && bad(C.values("-1","59.999"),"attachment_capture_clock") && bad(C.values("1e2","00.000"),"attachment_capture_clock"),"clock refuses noncanonical negative and exponent seconds")
    F.assert(bad(C.values("1","60.000"),"attachment_capture_clock") && bad(C.values("1","01.2"),"attachment_capture_clock") && bad(C.values("1","01.00x"),"attachment_capture_clock"),"clock refuses invalid seconds-within-minute and fraction shape")
    F.assert(bad(C.rows(Done{[[Sql.Cell.Real{"1.0"},Sql.Cell.Text{"01.000"}]]}),"attachment_capture_clock") && bad(C.rows(Done{[[Sql.Cell.Null{},Sql.Cell.Null{}]]}),"attachment_capture_clock"),"clock never promotes float NULL or invalid SQL row types")

def main() -> IO(Unit): suite()

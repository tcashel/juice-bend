import Base
import ../src/attachment_worker_protocol.bend as P

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def nonce() -> String:
  "0123456789abcdef0123456789abcdef"

def same_args(a: List<&2,String>,b: List<&2,String>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case first <> rest other <> tail: String.eq(first,other) && same_args(rest,tail)
    case _ _: False{}

def ordinary(route: P.Route,expected: List<&2,String>) -> Bool:
  match route:
    case P.Ordinary{actual}: same_args(actual,expected)
    case _: False{}

def unchanged(+args: List<&2,String>) -> Bool:
  ordinary(P.classify("/app",args),args)

def rejected(route: P.Route) -> Bool:
  match route:
    case P.Rejected{}: True{}
    case _: False{}

def refused(args: List<&2,String>) -> Bool:
  rejected(P.classify("/app",args))

def exact(route: P.Route,program: String,root: String,path: String,nonce: String) -> Bool:
  match route:
    case P.Worker{P.Request{a,b,c,d}}:
      String.eq(a,program) && String.eq(b,root) && String.eq(c,path) && String.eq(d,nonce)
    case _: False{}

def accepted() -> IO(Unit):
  do IO<Unit>:
    check(unchanged([]),"empty argv remains ordinary")
    check(exact(P.classify("/app",["--attachment-worker-v1","/root","a",nonce()]),"/app","/root","a",nonce()),
      "exact worker spelling and three operands preserve every request field")
    check(exact(P.classify("/Applications/Juice Bend.app/Contents/MacOS/JuiceBend",
      ["--attachment-worker-v1","/private/tmp/café 中文","child/🙂.png",nonce()]),
      "/Applications/Juice Bend.app/Contents/MacOS/JuiceBend","/private/tmp/café 中文","child/🙂.png",nonce()),
      "spaces and Unicode in executable root and relative path remain literal")

def arity() -> IO(Unit):
  do IO<Unit>:
    check(refused(["--attachment-worker-v1"]),"worker with zero operands is rejected")
    check(refused(["--attachment-worker-v1","/root"]),"worker with one operand is rejected")
    check(refused(["--attachment-worker-v1","/root","a"]),"worker with two operands is rejected")
    check(refused(["--attachment-worker-v1","/root","a",nonce(),"extra"]),"worker with a fourth operand is rejected")
    check(refused("--attachment-worker-v1" <> "/root" <> "a" <> nonce() <> List.replicate(String,128n,"extra")),
      "worker with a long trailing operand list is rejected")
    check(refused(["--attachment-worker-v1","relative-root","a",nonce()]) &&
      refused(["--attachment-worker-v1","/root","../a",nonce()]) &&
      refused(["--attachment-worker-v1","/root","a","bad-nonce"]),
      "accepted arity still validates root relative path and nonce")
    check(rejected(P.classify("/root/app",["--attachment-worker-v1","/root","a",nonce()])) &&
      rejected(P.classify("relative-app",["--attachment-worker-v1","/root","a",nonce()])),
      "accepted arity still validates executable identity and root separation")
    check(refused(["--attachment-worker-v1","/root","a\0b",nonce()]) &&
      refused(["--attachment-worker-v1","/root",String.repeat("a",4097n),nonce()]),
      "accepted arity still rejects NUL and oversized relative paths")

def reserved() -> IO(Unit):
  do IO<Unit>:
    check(refused(["--attachment-worker"]),"bare reserved prefix cannot reach ordinary startup")
    check(refused(["--attachment-worker-v2","/root","a",nonce()]),"unknown worker version cannot reach ordinary startup")
    check(refused(["--attachment-worker-v1x","/root","a",nonce()]),"exact-version suffix cannot enter the worker or ordinary startup")
    check(refused(["--attachment-workers"]),"reserved prefix neighbors keep the existing refusal policy")
    check(refused(["--attachment-worker-v1\0","/root","a",nonce()]),"NUL suffix cannot masquerade as exact worker command")
    check(refused(["--attachment-worker-v1\n","/root","a",nonce()]) &&
      refused(["--attachment-worker-v1 ","/root","a",nonce()]),"whitespace suffixes cannot masquerade as exact worker command")
    check(refused(["--attachment-worker-🙂","/root","a",nonce()]),"Unicode suffix inside reserved namespace is rejected")
    check(refused(["--attachment-worker" ++ String.repeat("x",16384n)]),"oversized reserved command is rejected without path startup")

def passthrough() -> IO(Unit):
  do IO<Unit>:
    check(unchanged(["search","--attachment-worker-v1","/root","a",nonce()]),"worker spelling in an operand does not redirect ordinary command")
    check(unchanged(["--attachment-worke","/root","a",nonce()]) &&
      unchanged(["--attachment-workes","/root","a",nonce()]),"nearby nonreserved prefixes retain all ordinary operands")
    check(unchanged(["--Attachment-worker-v1","/root","a",nonce()]) &&
      unchanged([" --attachment-worker-v1","/root","a",nonce()]),"case or leading-space variants remain ordinary exactly as before")
    check(unchanged(["🙂--attachment-worker-v1","café 中文","x|y",""]),"Unicode prefix and delimiter-like operands pass through losslessly")
    check(unchanged(["","a","", "b"]),"empty command and empty operands retain their positions")
    check(unchanged(["\0--attachment-worker-v1","a\0b","", "🙂"]),"NUL in a nonreserved command or operand passes through unchanged")
    check(unchanged([String.repeat("z",16384n),"first",String.repeat("x",16384n),"last"]),
      "large ordinary command and operands are neither truncated nor reclassified")
    check(unchanged(["--data-dir","/synthetic","quota","status"]),"existing data root quota routing remains unchanged")

def main() -> IO(Unit):
  do IO<Unit>:
    accepted()
    arity()
    reserved()
    passthrough()

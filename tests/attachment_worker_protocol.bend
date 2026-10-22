import Base
import ../src/attachment_worker_protocol.bend as P
import ../src/attachment_worker_parent.bend as Parent
import ../src/domain.bend as Domain

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def copied(args: List<String>) -> List<&2,String>:
  match args:
    case []: []
    case value <> rest: value <> copied(rest)

def nonce() -> String:
  "0123456789abcdef0123456789abcdef"

def request() -> P.Request:
  P.Request{"/Applications/Juice Bend.app/Contents/MacOS/JuiceBend","/private/tmp/attachment-root","café/中文.bin",nonce()}

def worker(route: P.Route) -> Bool:
  match route:
    case P.Worker{value}: String.eq(P.target(value),"/private/tmp/attachment-root/café/中文.bin")
    case _: False{}

def rejected(route: P.Route) -> Bool:
  match route:
    case P.Rejected{}: True{}
    case _: False{}

def ordinary(route: P.Route,text: String) -> Bool:
  match route:
    case P.Ordinary{args}: String.eq(String.join(args,"|"),text)
    case _: False{}

def route_checks() -> IO(Unit):
  do IO<Unit>:
    check(worker(P.request(request())),"explicit Unicode root-relative request preserves exact literal path")
    check(rejected(P.classify("/app",["--attachment-worker-v1"])) &&
      rejected(P.classify("/app",["--attachment-worker-v1","/root","a",nonce(),"extra"])) &&
      rejected(P.classify("/app",["--attachment-worker-v2"])),"malformed or unknown worker namespace never falls through to HOME and capture startup")
    check(ordinary(P.classify("/app",[]),"") &&
      ordinary(P.classify("/app",["search","--attachment-worker-v1"]),"search|--attachment-worker-v1") &&
      ordinary(P.classify("/app",["--data-dir","/synthetic","quota","status"]),"--data-dir|/synthetic|quota|status"),
      "ordinary app quota and search operands preserve existing routing")
    check(Bool.not(P.valid_request(P.Request{"/app","/","a",nonce()})) &&
      Bool.not(P.valid_request(P.Request{"/app","","a",nonce()})) &&
      Bool.not(P.valid_request(P.Request{"app","/root","a",nonce()})),"root directory grant and missing or relative executable identity are refused")
    check(Bool.not(P.valid_request(P.Request{"/root/app","/root","a",nonce()})) &&
      Bool.not(P.valid_request(P.Request{"/root","/root","a",nonce()})),"own executable must be outside enabled root for the negative startup oracle")
    check(P.valid_request(P.Request{"/root-two/app","/root","a",nonce()}),"root containment uses a path separator rather than a textual prefix")
    check(Bool.not(P.relative("../secret")) && Bool.not(P.relative("a/../secret")) &&
      Bool.not(P.relative("/secret")) && Bool.not(P.relative("a//b")) &&
      Bool.not(P.relative("a/./b")) && Bool.not(P.relative("a/")),"relative path traversal absolute paths and empty components are refused")
    check(Bool.not(P.relative("bad\0name")) && P.bounded("é",2) && Bool.not(P.bounded("é",1)) &&
      Bool.not(P.relative(String.repeat("x",4097n))),"scalar and UTF8 byte limits run before filesystem use")
    check(Bool.not(P.valid_request(P.Request{"/app","/root","a","0123456789ABCDEF0123456789abcdef"})) &&
      Bool.not(P.valid_request(P.Request{"/app","/root","a",nonce() ++ "0"})),"nonce accepts only exactly32 lowercase hexadecimal characters")

def need(result: Result<&2,&2,String,String>) -> IO(String):
  match result:
    case Fail{error}: IO.die(String,1,error)
    case Done{text}: IO.pure(String,text)

def bytes(result: Result<&2,&2,String,P.Payload>,+expected: List<&2,U32>,digest: String) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{P.Payload{count,actual,value}}:
      U32.is_eq(count,U32.from_nat(List.length(&2,U32,expected))) &&
        String.eq(actual,digest) && Domain.bytes_equal(value,expected)

def failed(result: Result<&2,&2,String,P.Payload>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def reason(result: Result<&2,&2,String,P.Payload>,expected: String) -> Bool:
  match result:
    case Fail{actual}: String.eq(actual,expected)
    case Done{_}: False{}

def empty() -> String:
  "JBATT1 " ++ nonce() ++ " 0 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\n\n"

def abc() -> String:
  "JBATT1 " ++ nonce() ++ " 3 ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad\n616263\n"

def protocol_checks() -> IO(Unit):
  do IO<Unit>:
    +encoded : String <- need(P.wire(nonce(),[97,98,99]))
    check(String.eq(encoded,abc()),"worker wire format matches independent SHA256 and exact ASCII envelope")
    check(bytes(P.parse(abc(),nonce()),[97,98,99],"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),"parent validates exact independently known bytes count and digest")
    check(bytes(P.parse(empty(),nonce()),[],"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),"empty regular payload has explicit exact EOF count and standard empty digest")
    +binary : String <- need(P.wire(nonce(),[0,255,128,65,10,195,169]))
    check(bytes(P.parse(binary,nonce()),[0,255,128,65,10,195,169],Domain.digest([0,255,128,65,10,195,169])),
      "binary NUL and invalid UTF8 bytes roundtrip only through ASCII hex")
    check(failed(P.parse(abc(),String.repeat("a",32n))) && failed(P.parse(abc() ++ "extra",nonce())) &&
      failed(P.parse("noise\n" ++ abc(),nonce())) && failed(P.parse(String.take(abc(),10n),nonce())),
      "wrong request identity extra output prefixes and truncation cannot be accepted")
    check(failed(P.parse("JBATT1 " ++ nonce() ++ " 03 ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad\n616263\n",nonce())) &&
      failed(P.parse("JBATT1 " ++ nonce() ++ " 1048577 " ++ String.repeat("a",64n) ++ "\n00\n",nonce())),
      "counts must be canonical and below the fixed byte cap before decoding")
    check(failed(P.parse("JBATT1 " ++ nonce() ++ " 1 " ++ String.repeat("a",64n) ++ "\nzz\n",nonce())) &&
      failed(P.parse("JBATT1 " ++ nonce() ++ " 1 " ++ String.repeat("a",64n) ++ "\nff\n",nonce())) &&
      failed(P.parse("JBATT1 " ++ nonce() ++ " 2 " ++ String.repeat("a",64n) ++ "\nff\n",nonce())),
      "invalid hex incorrect digest and short payload fail without returning bytes")
    check(failed(P.response(Done{(0,(encoded,"unexpected"))},nonce())) &&
      failed(P.response(Done{(1,(abc(),""))},nonce())) &&
      reason(P.response(Fail{(27,"untrusted child text")},nonce()),"attachment_worker_transport"),
      "stderr nonzero exit and transport overflow cannot become successful payloads")
    check(reason(P.response(Done{(73,("","attachment_worker_missing\n"))},nonce()),"attachment_worker_missing") &&
      reason(P.response(Done{(74,("","attachment_worker_blocked\n"))},nonce()),"attachment_worker_blocked") &&
      reason(P.response(Done{(75,("","attachment_worker_size_limit\n"))},nonce()),"attachment_worker_size_limit"),
      "only exact static failure envelopes retain missing blocked and size-limit coverage")
    check(reason(P.response(Done{(73,("","DROP TABLE assets;"))},nonce()),"attachment_worker_failed"),
      "child-controlled diagnostics are discarded and never become SQL or a parent command")

def progress(step: P.ReadStep,expected: U32) -> Bool:
  match step:
    case P.Progress{offset}: U32.is_eq(offset,expected)
    case _: False{}

def complete(step: P.ReadStep) -> Bool:
  match step:
    case P.Complete{}: True{}
    case _: False{}

def unstable(step: P.ReadStep) -> Bool:
  match step:
    case P.Unstable{}: True{}
    case _: False{}

def permitted(result: Result<&2,&2,String,P.ReadPermit>,expected: U32) -> Bool:
  match result:
    case Done{P.ReadPermit{0n,maximum}}: U32.is_eq(maximum,expected)
    case _: False{}

def exhausted(result: Result<&2,&2,String,P.ReadPermit>) -> Bool:
  match result:
    case Fail{"attachment_worker_read_limit"}: True{}
    case _: False{}

def io_contract_checks() -> IO(Unit):
  do IO<Unit>:
    check(progress(P.read_step(10,0,3),3) && progress(P.read_step(10,3,7),10) &&
      complete(P.read_step(10,10,0)),"production read state accepts partial reads only with exact final EOF")
    check(unstable(P.read_step(10,3,0)) && unstable(P.read_step(10,10,1)) &&
      unstable(P.read_step(10,11,0)) && unstable(P.read_step(10,3,8)),
      "premature EOF growth and invalid offsets cannot bless a partial capture")
    check(complete(P.read_step(0,0,0)) && unstable(P.read_step(1048577,0,0)) &&
      unstable(P.read_step(1048576,0,32769)) && progress(P.read_step(1048576,1048575,1),1048576),
      "empty maximum extent and chunk boundaries are explicit without U32 wrap acceptance")
    check(exhausted(P.read_plan(0n,10,10)) && permitted(P.read_plan(1n,10,10),1) &&
      permitted(P.read_plan(1n,10,3),8) && permitted(P.read_plan(1n,1048576,0),32768),
      "exhausted read fuel differs from EOF and every actual read including final probe consumes fuel")
    check(String.eq(String.join(copied(Parent.arguments(request())),"|"),
      "-i|PATH=/usr/bin:/bin|LANG=C|LC_ALL=C|/usr/bin/sandbox-exec|-p|" ++ Parent.policy() ++
      "|-D|ROOT=/private/tmp/attachment-root|-D|WORKER=/Applications/Juice Bend.app/Contents/MacOS/JuiceBend|" ++
      "/Applications/Juice Bend.app/Contents/MacOS/JuiceBend|--attachment-worker-v1|/private/tmp/attachment-root|café/中文.bin|" ++ nonce()),
      "parent launch keeps exact profile and literal executable root relative path and nonce arguments")
    check(String.contains(Parent.policy(),"(literal \"/\")\n    (vnode-type DIRECTORY)") &&
      String.contains(Parent.policy(),"(subpath (param \"ROOT\"))\n    (vnode-type REGULAR-FILE)") &&
      Bool.not(String.contains(Parent.policy(),"(allow file-write")),
      "profile retains regular-byte confinement and literal root-directory exception without writes")

def zero_bytes(values: List<&2,U32>) -> Bool:
  match values:
    case []: True{}
    case value <> rest: U32.is_eq(value,0) && zero_bytes(rest)

def full_payload(result: Result<&2,&2,String,P.Payload>) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{P.Payload{count,digest,+bytes}}:
      U32.is_eq(count,1048576) &&
        String.eq(digest,"30e14955ebf1352266dc2ff8067e68104607e750abb9d3b36582b8af909fcb58") &&
        Nat.is_eq(List.length(&2,U32,bytes),1048576n) && zero_bytes(bytes)

def wire_refused(result: Result<&2,&2,String,String>) -> Bool:
  match result:
    case Fail{"attachment_worker_invalid_payload"}: True{}
    case _: False{}

def cap_checks() -> IO(Unit):
  do IO<Unit>:
    +encoded : String <- need(P.wire(nonce(),List.replicate(U32,1048576n,0)))
    check(Nat.is_eq(String.length(encoded),2097266n) && U32.is_lt(2097266,P.output_limit()),
      "exact1MiB payload frames to2097266 ASCII bytes within the combined output budget")
    check(full_payload(P.parse(encoded,nonce())),"parent verifies full1MiB payload against independent SHA256 and exact zero octets")
    check(wire_refused(P.wire(nonce(),List.replicate(U32,1048577n,0))) &&
      wire_refused(P.wire(nonce(),[256])),"one byte above asset cap and non-octet data refuse framing before hashing or publication")

def main() -> IO(Unit):
  do IO<Unit>:
    route_checks()
    protocol_checks()
    io_contract_checks()
    cap_checks()

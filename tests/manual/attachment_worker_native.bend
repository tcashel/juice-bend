import Base
import ../../src/attachment_worker_protocol.bend as P
import ../../src/attachment_worker_parent.bend as Parent
import ../../src/domain.bend as Domain

# Synthetic native acceptance harness. No SQLite/GUI dependency. The candidate
# is the actual full product binary; every capture calls its unchanged Parent.run.
# Shell supplies a fresh owned root and only orchestrates fixtures/observations.
def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def alnum(value: String) -> Bool:
  match value:
    case SNil{}: True{}
    case SCon{+char,rest}: (Char.is_alpha(char) || Char.is_digit(char)) && alnum(rest)

def run_root(+root: String) -> Bool:
  +prefix = {"/private/tmp/juice-bend-worker-native." : String}
  +suffix = String.drop(root,String.length(prefix))
  String.starts_with(root,prefix) && Nat.is_eq(String.length(suffix),8n) && alnum(suffix)

def nonce() -> String:
  "0123456789abcdef0123456789abcdef"

def absent(value: Result<&1,&1,U32 & String,String>) -> Bool:
  match value:
    case Fail{_}: True{}
    case Done{_}: False{}

def written(value: File & Result<&1,&1,U32 & String,Unit>) -> IO(Unit):
  (file,result) = value
  do IO<Unit>:
    File.close(file)
    IO.try(Unit,IO.pure(Result<&1,&1,U32 & String,Unit>,result))

def write_bytes(path: String,bytes: List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    result : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    written(result)

def text(path: String,value: String) -> IO(Unit):
  write_bytes(path,Domain.encode(value))

def good() -> List<&2,U32>:
  [0,255,128,65,10,195,169]

def binary(value: Result<&2,&2,String,P.Payload>,+bytes: List<&2,U32>) -> Bool:
  match value:
    case Fail{_}: False{}
    case Done{P.Payload{count,digest,data}}:
      U32.is_eq(count,U32.from_nat(List.length(&2,U32,bytes))) &&
      String.eq(digest,Domain.digest(bytes)) && Domain.bytes_equal(data,bytes)

def reason(value: Result<&2,&2,String,P.Payload>,expected: String) -> Bool:
  match value:
    case Fail{actual}: String.eq(actual,expected)
    case Done{_}: False{}

def zeros(value: List<&2,U32>) -> Bool:
  match value:
    case []: True{}
    case byte <> rest: U32.is_eq(byte,0) && zeros(rest)

def maximum(value: Result<&2,&2,String,P.Payload>) -> Bool:
  match value:
    case Fail{_}: False{}
    case Done{P.Payload{count,digest,+bytes}}:
      U32.is_eq(count,1048576) &&
      String.eq(digest,"30e14955ebf1352266dc2ff8067e68104607e750abb9d3b36582b8af909fcb58") &&
      Nat.is_eq(List.length(&2,U32,bytes),1048576n) && zeros(bytes)

def summary(value: Result<&2,&2,String,P.Payload>) -> String:
  match value:
    case Fail{error}: "refused " ++ error
    case Done{P.Payload{count,digest,_}}: "accepted " ++ U32.show(count) ++ " " ++ digest

def call(+root: String,program: String,relative: String,+label: String) -> IO(Result<&2,&2,String,P.Payload>):
  do IO<Result<&2,&2,String,P.Payload>>:
    start : Nat <- IO.now()
    +answer : Result<&2,&2,String,P.Payload> <- Parent.run(P.Request{program,root ++ "/approved",relative,nonce()})
    end : Nat <- IO.now()
    text(root ++ "/receipts/" ++ label ++ ".result",summary(answer) ++ "\nelapsed-ms=" ++ Nat.show(Nat.sub(end,start)) ++ "\n")
    return answer

def raw_completed(+prefix: String,+code: U32,+out: String,+err: String) -> IO(U32 & (String & String)):
  do IO<U32 & (String & String)>:
    text(prefix ++ ".result","exit=" ++ U32.show(code) ++ "\n")
    text(prefix ++ ".stdout",out)
    text(prefix ++ ".stderr",err)
    IO.pure(U32 & (String & String),(code,(out,err)))

def raw_saved(prefix: String,value: U32 & (String & String)) -> IO(U32 & (String & String)):
  (code,(out,err)) = value
  raw_completed(prefix,code,out,err)

def raw_result(+prefix: String,value: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(U32 & (String & String)):
  match value:
    case Fail{(code,error)}:
      do IO<U32 & (String & String)>:
        text(prefix ++ ".result","transport errno=" ++ U32.show(code) ++ "\n")
        text(prefix ++ ".stderr",error)
        IO.die(U32 & (String & String),1,"FAIL direct startup/loader process did not complete")
    case Done{completed}: raw_saved(prefix,completed)

def direct(+root: String,program: String,args: List<String>,label: String) -> IO(U32 & (String & String)):
  do IO<U32 & (String & String)>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/usr/bin/env","-i" <> "PATH=/usr/bin:/bin" <> "LANG=C" <> "LC_ALL=C" <> program <> args,"",8192,5000)
    raw_result(root ++ "/receipts/" ++ label,result)

def exact_failure(value: U32 & (String & String),expected: U32,message: String,label: String) -> IO(Unit):
  (code,(out,err)) = value
  check(U32.is_eq(code,expected) && String.is_empty(out) && String.eq(err,message ++ "\n"),label)

def prepare(+root: String) -> IO(Unit):
  do IO<Unit>:
    write_bytes(root ++ "/approved/binary.bin",good())
    write_bytes(root ++ "/approved/empty.bin",[])
    write_bytes(root ++ "/approved/max.bin",List.replicate(U32,1048576n,0))
    write_bytes(root ++ "/approved/oversize.bin",List.replicate(U32,1048577n,0))
    write_bytes(root ++ "/approved/inside/binary.bin",good())
    write_bytes(root ++ "/approved/rename/binary.bin",good())
    write_bytes(root ++ "/outside/binary.bin",[88,79,85,84,83,73,68,69,88])
    write_bytes(root ++ "/outside/sentinel.bin",[88,79,85,84,83,73,68,69,88])
    text(root ++ "/receipts/fixture.txt","synthetic-only\ngood=00ff80410ac3a9\noutside=584f55545349444558\n")
    check(True{},"Bend created exact binary empty cap and outside sentinel fixtures")

def startup(+root: String,+program: String) -> IO(Unit):
  do IO<Unit>:
    home : Result<&1,&1,U32 & String,String> <- IO.get_env("HOME")
    check(absent(home),"native parent harness HOME is absent")
    malformed : U32 & (String & String) <- direct(root,program,["--attachment-worker-v1"],"01-malformed")
    exact_failure(malformed,64,"attachment_worker_arguments","full app malformed reserved route refuses before ordinary startup")
    version : U32 & (String & String) <- direct(root,program,["--attachment-worker-v2"],"02-version")
    exact_failure(version,64,"attachment_worker_arguments","unknown reserved version refuses before ordinary startup")
    unconfined : U32 & (String & String) <- direct(root,program,["--attachment-worker-v1",root ++ "/approved","binary.bin",nonce()],"03-unconfined")
    exact_failure(unconfined,78,"attachment_worker_confinement_required","readable full app self-open sanity check rejects an ordinary direct launch")
    good_result : Result<&2,&2,String,P.Payload> <- call(root,program,"binary.bin","04-confined-binary")
    check(binary(good_result,good()),"actual full app Parent.run captures all seven binary bytes under unchanged policy")
    empty_result : Result<&2,&2,String,P.Payload> <- call(root,program,"empty.bin","05-confined-empty")
    check(binary(empty_result,[]),"actual full app Parent.run captures an empty regular file")
    missing : Result<&2,&2,String,P.Payload> <- call(root,program,"missing.bin","06-missing")
    check(reason(missing,"attachment_worker_missing"),"missing path remains an explicit failure")
    text(root ++ "/receipts/STARTUP-PASSED","full-app-startup-only; nonregular and races remain separate\n")

def prompt_blocked(+root: String,program: String,relative: String,+label: String) -> IO(Unit):
  do IO<Unit>:
    +start : Nat <- IO.now()
    result : Result<&2,&2,String,P.Payload> <- call(root,program,relative,label)
    end : Nat <- IO.now()
    check(reason(result,"attachment_worker_blocked") && Nat.is_lt(Nat.sub(end,start),5000n),
      label ++ " explicitly denied before five seconds; timeout is not acceptance")

# A Unix-domain socket can fail in the OS open path before an EPERM/EACCES
# policy result. This one fixture must reproduce the exact observed raw refusal
# under unchanged Parent.arguments, then separately verify actual Parent.run
# stays closed. Generic failures and transport timeouts are never acceptance.
def socket_raw(+root: String,program: String) -> IO(Unit):
  do IO<Unit>:
    start : Nat <- IO.now()
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/usr/bin/env",Parent.arguments(P.Request{program,root ++ "/approved","socket",nonce()}),
        "",P.output_limit(),P.timeout_ms())
    end : Nat <- IO.now()
    +elapsed : Nat = Nat.sub(end,start)
    text(root ++ "/receipts/13-unix-socket-raw.elapsed-ms",Nat.show(elapsed) ++ "\n")
    completed : U32 & (String & String) <- raw_result(root ++ "/receipts/13-unix-socket-raw",result)
    exact_failure(completed,77,"attachment_worker_open_error",
      "13-unix-socket raw completion has exit77 empty stdout and exact static open error")
    check(Nat.is_lt(elapsed,5000n),"13-unix-socket exact raw refusal completed before five seconds")

def socket_refused(+root: String,+program: String) -> IO(Unit):
  do IO<Unit>:
    socket_raw(root,program)
    start : Nat <- IO.now()
    +result : Result<&2,&2,String,P.Payload> <- Parent.run(P.Request{program,root ++ "/approved","socket",nonce()})
    end : Nat <- IO.now()
    +elapsed : Nat = Nat.sub(end,start)
    text(root ++ "/receipts/13-unix-socket.result",summary(result) ++ "\nelapsed-ms=" ++ Nat.show(elapsed) ++ "\n")
    check(reason(result,"attachment_worker_failed") && Nat.is_lt(elapsed,5000n),
      "13-unix-socket actual Parent.run maps the observed raw refusal to closed failure before five seconds")

def nonregular(+root: String,+program: String) -> IO(Unit):
  do IO<Unit>:
    prompt_blocked(root,program,"fifo","11-fifo-no-writer")
    prompt_blocked(root,program,"directory","12-directory")
    socket_refused(root,program)
    prompt_blocked(root,program,"null-device","14-safe-null-device-alias")
    prompt_blocked(root,program,"outside-link","15-outside-final-symlink")
    prompt_blocked(root,program,"outside-parent/binary.bin","16-outside-ancestor-symlink")
    prompt_blocked(root,program,"self-executable","17-own-executable-symlink")
    text(root ++ "/receipts/NONREGULAR-PASSED","policy-denials plus exact socket-open refusal; no bytes or timeout accepted\n")

def limits(+root: String,+program: String) -> IO(Unit):
  do IO<Unit>:
    value : Result<&2,&2,String,P.Payload> <- call(root,program,"max.bin","21-maximum")
    check(maximum(value),"actual Parent.run verifies full1MiB payload count known SHA256 and every zero byte")
    over : Result<&2,&2,String,P.Payload> <- call(root,program,"oversize.bin","22-oversize")
    check(reason(over,"attachment_worker_size_limit"),"actual worker refuses1MiB plus one byte")

# Each stress observation can only be known in-root bytes or a recognized
# refusal. Generic process/loader/timeout failures fail the stress gate. This
# does not prove that any particular before/during/after-open timing occurred.
def race_ok(value: Result<&2,&2,String,P.Payload>) -> Bool:
  match value:
    case Fail{+error}: String.eq(error,"attachment_worker_blocked") ||
      String.eq(error,"attachment_worker_missing") || String.eq(error,"attachment_worker_unstable")
    case Done{+payload}: binary(Done{payload},good())

def race_loop(fuel: Nat,+root: String,+program: String,+relative: String,+label: String,+index: U32) -> IO(Unit):
  match fuel:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+left:
      do IO<Unit>:
        start : Nat <- IO.now()
        answer : Result<&2,&2,String,P.Payload> <- call(root,program,relative,label ++ "-" ++ U32.show(index))
        end : Nat <- IO.now()
        check(race_ok(answer) && Nat.is_lt(Nat.sub(end,start),5000n),label ++ " observation " ++ U32.show(index) ++ " has only approved bytes or explicit refusal")
        race_loop(left,root,program,relative,label,U32.inc(index))

def process_errno(value: Result<&1,&1,U32 & String,U32 & (String & String)>,wanted: U32) -> Bool:
  match value:
    case Fail{(actual,_)}: U32.is_eq(actual,wanted)
    case Done{_}: False{}

def process_case(+root: String,self: String,kind: String,cap: U32,ms: U32,wanted: U32,+label: String) -> IO(Unit):
  do IO<Unit>:
    start : Nat <- IO.now()
    value : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run(self,["child",kind],"",cap,ms)
    end : Nat <- IO.now()
    +elapsed : Nat = Nat.sub(end,start)
    text(root ++ "/receipts/" ++ label ++ ".elapsed-ms",Nat.show(elapsed) ++ "\n")
    check(process_errno(value,wanted) && Nat.is_lt(elapsed,5000n),label ++ " returns exact transport errno without partial output")

def process_bounds(+root: String,+self: String) -> IO(Unit):
  do IO<Unit>:
    process_case(root,self,"stdout",4096,1000,27,"31-stdout-cap")
    process_case(root,self,"stderr",4096,1000,27,"32-stderr-cap")
    process_case(root,self,"mixed",4096,1000,27,"33-combined-cap")
    process_case(root,self,"sleep",4096,250,60,"34-timeout")
    IO.print("PASS Process.run transport tests complete; wrapper must verify owned child reaping and memory separately")

def child(kind: String) -> IO(Unit):
  match kind:
    case "stdout":
      do IO<Unit>:
        IO.sleep(200)
        IO.write(String.repeat("x",8192n))
    case "stderr":
      do IO<Unit>:
        IO.sleep(200)
        IO.print_err(String.repeat("e",8192n))
    case "mixed":
      do IO<Unit>:
        IO.sleep(200)
        IO.write(String.repeat("x",3000n))
        IO.print_err(String.repeat("e",3000n))
    case "sleep": IO.sleep(10000)
    case _: IO.die(Unit,2,"Unknown synthetic child mode")

def stage(name: String,+root: String,+program: String,self: String) -> IO(Unit):
  match name:
    case "prepare": prepare(root)
    case "startup": startup(root,program)
    case "nonregular": nonregular(root,program)
    case "limits": limits(root,program)
    case "process": process_bounds(root,self)
    case "final-link": race_loop(24n,root,program,"race.bin","41-final-link",0)
    case "ancestor-link": race_loop(24n,root,program,"ancestor/binary.bin","42-ancestor-link",0)
    case "rename": race_loop(24n,root,program,"rename/binary.bin","43-parent-rename",0)
    case "root-link": race_loop(24n,root,program,"binary.bin","44-root-link",0)
    case "fifo-swap": race_loop(24n,root,program,"race-fifo.bin","45-fifo-swap",0)
    case _: IO.die(Unit,2,"Unknown finite native stage")

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "child" <> kind <> []: child(kind)
    case +self <> name <> +root <> +program <> []:
      do IO<Unit>:
        check(run_root(root) && P.absolute(program) && P.absolute(self),"owned synthetic root and absolute executables")
        stage(name,root,program,self)
    case _: IO.die(Unit,2,"Expected STAGE OWNED-ROOT ABSOLUTE-FULL-APP")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)

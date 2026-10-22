import Base
import ../src/attachment_image_cancel.bend as C
import ../src/attachment_image_spool_path.bend as P
import ../src/jpeg/types.bend as T
import ../src/jpeg/container.bend as Container
import ../src/jpeg/raster.bend as Raster
import ../src/jpeg/cooperative.bend as Cooperative
import ../src/attachment_image_types.bend as Image
import ./attachment_image_spool.bend as S
import ./attachment_image_file.bend as Files
import ./attachment_archive_export.bend as F
import ./jpeg_fixtures.bend as JPEG

type Run is Type:
  Run{value: Result<&1,&1,U32 & String,U32 & (String & String)>}

def check(ok: Bool,label: String) -> IO(Unit): S.check(ok,label)
def observed(value: C.Watched,canceled: Bool) -> Bool:
  match value:
    case C.Watched{+actual,True{}}: Bool.pick(Bool,canceled,actual,Bool.not(actual))
    case _: False{}
def error_expected(code: U32,error: String) -> Bool:
  match code:
    case 3: String.eq(error,C.error() ++ "\n")
    case _: String.is_empty(error)
def ended(value: Run,+code: U32,out: String) -> Bool:
  match value:
    case Run{Done{(actual,(text,error))}}:
      U32.is_eq(actual,code) && String.eq(text,out) && error_expected(code,error)
    case _: False{}

def child(self: String,mode: String,request: P.Request) -> IO(Run):
  P.Request{root,nonce,identity} = request
  do IO<Run>:
    value : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run(self,[mode,root,nonce,identity],"",256,10000)
    return Run{value}

def ready_opened(value: Result<&1,&1,U32 & String,File>) -> IO(Bool):
  match value:
    case Fail{_}: IO.pure(Bool,False{})
    case Done{file}:
      do IO<Bool>:
        File.close(file)
        return True{}
def wait_step(ready: Bool,next: Unit -> IO(Unit)) -> IO(Unit):
  match ready:
    case True{}: IO.pure(Unit,Unit{})
    case False{}: next(Unit{})
def wait_ready(fuel: Nat,+request: P.Request) -> IO(Unit):
  match fuel:
    case 0n: IO.die(Unit,1,"FAIL first MCU barrier did not appear")
    case 1n+left:
      do IO<Unit>:
        IO.sleep(10)
        value : Result<&1,&1,U32 & String,File> <- File.open(P.output(request),"r")
        ready : Bool <- ready_opened(value)
        wait_step(ready,_ => wait_ready(left,request))

def normal(+root: String,+self: String) -> IO(Unit):
  do IO<Unit>:
    +request : P.Request <- S.request(root)
    file : File <- IO.try(File,C.create(request))
    +cancel : Chan(Unit) <- Chan.new(Unit,1)
    +reader : Chan(Unit) <- Chan.new(Unit,1)
    watcher : Chan(C.Watched) <- IO.fork(C.Watched,C.watch(cancel,file,reader))
    value : Run <- child(self,"--check",request)
    check(ended(value,0,"continued\n"),"empty private control permits the actual child checkpoint")
    Chan.close(Unit,cancel)
    watched : C.Watched <- IO.join(C.Watched,watcher)
    check(observed(watched,False{}),"normal completion closes and joins the scoped watcher without signaling")
    C.signal(cancel)
    value : Run <- child(self,"--check",request)
    check(ended(value,0,"continued\n"),"late signal after watcher join cannot write a retired request control")
    Chan.close(Unit,reader)
    S.removed(request)

def reader_closed(value: Poll<&1,&1,Maybe<&1,Unit>,Unit>) -> Bool:
  match value:
    case Ready{None{}}: True{}
    case _: False{}

def canceled(+root: String,+self: String) -> IO(Unit):
  do IO<Unit>:
    +request : P.Request <- S.request(root)
    file : File <- IO.try(File,C.create(request))
    +cancel : Chan(Unit) <- Chan.new(Unit,1)
    +reader : Chan(Unit) <- Chan.new(Unit,1)
    watcher : Chan(C.Watched) <- IO.fork(C.Watched,C.watch(cancel,file,reader))
    worker : Chan(Run) <- IO.fork(Run,child(self,"--jpeg-step",request))
    wait_ready(1000n,request)
    check(True{},"real child completed the first shared JPEG MCU before parent cancellation")
    C.signal(cancel)
    value : Run <- IO.join(Run,worker)
    check(ended(value,3,""),"next real JPEG MCU checkpoint exits the child; exact Process.run has returned and reaped")
    Chan.close(Unit,cancel)
    watched : C.Watched <- IO.join(C.Watched,watcher)
    check(observed(watched,True{}),"parent cancellation writer finishes before any request cleanup")
    polled : Poll<&1,&1,Maybe<&1,Unit>,Unit> <- Chan.try_recv(Unit,reader,0)
    check(reader_closed(polled),"same cancellation also closes the parent streaming-reader control")
    Chan.close(Unit,reader)
    S.removed(request)


def missing(+root: String,+self: String) -> IO(Unit):
  do IO<Unit>:
    +request : P.Request <- S.request(root)
    value : Run <- child(self,"--check",request)
    check(ended(value,3,""),"missing control cannot be interpreted as successful cancellation permission")
    S.removed(request)

def zero_size(value: Result<&1,&1,U32 & String,U32>) -> Bool:
  match value:
    case Done{0}: True{}
    case _: False{}
def target_size(pair: File & Result<&1,&1,U32 & String,U32>) -> IO(Bool):
  (file,result) = pair
  do IO<Bool>:
    File.close(file)
    return zero_size(result)
def empty_target(value: Result<&1,&1,U32 & String,File>) -> IO(Bool):
  match value:
    case Fail{_}: IO.pure(Bool,False{})
    case Done{file}:
      do IO<Bool>:
        value : File & Result<&1,&1,U32 & String,U32> <- File.size(file)
        target_size(value)

def symlink(+root: String,+self: String) -> IO(Unit):
  do IO<Unit>:
    +request : P.Request <- S.request(root)
    F.write_bytes(root ++ "/unrelated",[])
    linked : Result<&2,&2,String,String> <- P.command("/bin/ln",["-s",root ++ "/unrelated",C.control(request)])
    S.primitive(linked)
    value : Run <- child(self,"--check",request)
    check(ended(value,3,""),"child rejects a symlink control before opening it")
    S.removed(request)
    target : Result<&1,&1,U32 & String,File> <- File.open(root ++ "/unrelated","r")
    target_empty : Bool <- empty_target(target)
    check(target_empty,"control cleanup preserves the existing empty symlink target unchanged")
    removed : Result<&2,&2,String,String> <- P.command("/bin/rm",["--",root ++ "/unrelated"])
    S.primitive(removed)

def finished(value: Result<&2,&1,T.Failure,Image.Raster>) -> IO(Unit):
  match value:
    case Fail{_}: IO.die(Unit,1,"FAIL fixture JPEG decode")
    case Done{_}: IO.print("completed")
def signal_bytes(value: Result<&1,&1,U32 & String,List<&2,U32>>) -> Bool:
  match value:
    case Done{[]}: False{}
    case Done{_}: True{}
    case _: False{}
def signal_read(pair: File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(Bool):
  (file,value) = pair
  do IO<Bool>:
    File.close(file)
    return signal_bytes(value)
def signal_open(value: Result<&1,&1,U32 & String,File>) -> IO(Bool):
  match value:
    case Fail{_}: IO.pure(Bool,False{})
    case Done{file}:
      do IO<Bool>:
        value : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_at(file,0,2)
        signal_read(value)
def wait_signal(fuel: Nat,+request: P.Request) -> IO(Unit):
  match fuel:
    case 0n: IO.die(Unit,1,"FAIL parent cancellation acknowledgment did not arrive")
    case 1n+left:
      do IO<Unit>:
        IO.sleep(10)
        value : Result<&1,&1,U32 & String,File> <- File.open(C.control(request),"r")
        ready : Bool <- signal_open(value)
        wait_step(ready,_ => wait_signal(left,request))

def after_first(value: Result<&2,&1,T.Failure,Raster.Advanced>,+prepared: Raster.Prepared,+request: P.Request) -> IO(Unit):
  match value:
    case Fail{_}: IO.die(Unit,1,"FAIL first shared JPEG MCU")
    case Done{Raster.Advanced{mcu,pixels}}:
      Raster.Prepared{+frame,jobs,interval,_,color,notice} = prepared
      T.Frame{_,_,_,_,_,columns,rows} = frame
      do IO<Unit>:
        # Test-only two-way handshake after real MCU work. Wait for the actual
        # parent's byte, then let the next production MCU checkpoint see it.
        # This is ordering evidence, never a production timing measurement.
        F.write_bytes(P.output(request),[1])
        wait_signal(1000n,request)
        value : Result<&2,&1,T.Failure,Image.Raster> <- Cooperative.mcus(U32.to_nat(U32.sub(U32.mul(columns,rows),1)),mcu,pixels,1,frame,jobs,interval,color,notice,C.Checked{request})
        finished(value)
def first(+prepared: Raster.Prepared,request: P.Request) -> IO(Unit):
  Raster.Prepared{+frame,+jobs,+interval,entropy,+color,_} = prepared
  Raster.unpack(IO(Unit),Raster.initial(frame,entropy),mcu => pixels =>
    after_first(Raster.step(mcu,pixels,0,frame,jobs,interval,color),prepared,request))
def step_prepared(value: Result<&2,&2,T.Failure,Raster.Prepared>,request: P.Request) -> IO(Unit):
  match value:
    case Fail{_}: IO.die(Unit,1,"FAIL JPEG fixture preparation")
    case Done{prepared}: first(prepared,request)
def step_document(value: Result<&2,&2,T.Failure,T.Document>,request: P.Request) -> IO(Unit):
  match value:
    case Fail{_}: IO.die(Unit,1,"FAIL JPEG fixture document")
    case Done{document}: step_prepared(Raster.prepare(document),request)
def child_mode(mode: String,request: P.Request) -> IO(Unit):
  match mode:
    case "--jpeg-step": step_document(Container.decode(JPEG.restart_420_bytes()),request)
    case _: IO.print("continued")
def child_ready(value: Result<&2,&2,String,Unit>,mode: String,+request: P.Request) -> IO(Unit):
  match value:
    case Fail{_}: IO.die(Unit,3,C.error())
    case Done{_}:
      do IO<Unit>:
        C.check(C.Checked{request})
        child_mode(mode,request)
def child_checked(value: Result<&2,&2,String,P.Request>,mode: String) -> IO(Unit):
  match value:
    case Fail{_}: IO.die(Unit,3,C.error())
    case Done{+request}:
      do IO<Unit>:
        value : Result<&2,&2,String,Unit> <- C.readable(request)
        child_ready(value,mode,request)
def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +root : String <- Files.root()
    normal(root,self)
    canceled(root,self)
    missing(root,self)
    symlink(root,self)
    result : Result<&2,&2,String,String> <- P.command("/bin/rmdir",["--",root])
    S.primitive(result)
def argv(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> mode <> root <> nonce <> identity <> []:
      do IO<Unit>:
        value : Result<&2,&2,String,P.Request> <- P.check(P.Request{root,nonce,identity})
        child_checked(value,mode)
    case _: IO.die(Unit,1,"FAIL cancellation gate arguments")
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    argv(args)

import Base
import ./attachment_image_spool_path.bend as Path

# Only the private, parent-created request owns this fixed control pathname.
# The parent keeps its original empty write handle until cancellation/completion.
# A child checkpoint opens, reads at most two bytes, and closes before deciding.
# This is cooperative child exit; Process.run in the parent still owns reaping.
type Mode is Data:
  Unchecked{}
  Checked{request: Path.Request}
type Watched is Data:
  Watched{canceled: Bool,ok: Bool}

def control(request: Path.Request) -> String: Path.directory(request) ++ "/cancel.control"
def error() -> String: "image_preview_canceled_or_control_failed"

def empty(+request: Path.Request) -> IO(Result<&2,&2,String,Unit>):
  do IO<Result<&2,&2,String,Unit>>:
    exists : Result<&2,&2,String,Bool> <- Path.test("-e",control(request))
    link : Result<&2,&2,String,Bool> <- Path.test("-L",control(request))
    return Path.empty_values(exists,link)

def open_empty(value: Result<&2,&2,String,Unit>,request: Path.Request) -> IO(Result<&1,&1,U32 & String,File>):
  match value:
    case Fail{message}: IO.pure(Result<&1,&1,U32 & String,File>,Fail{(2,message)})
    case Done{_}: File.open(control(request),"w")

def create_checked(value: Result<&2,&2,String,Path.Request>) -> IO(Result<&1,&1,U32 & String,File>):
  match value:
    case Fail{message}: IO.pure(Result<&1,&1,U32 & String,File>,Fail{(2,message)})
    case Done{+request}:
      do IO<Result<&1,&1,U32 & String,File>>:
        value : Result<&2,&2,String,Unit> <- empty(request)
        open_empty(value,request)

def create(request: Path.Request) -> IO(Result<&1,&1,U32 & String,File>):
  do IO<Result<&1,&1,U32 & String,File>>:
    checked : Result<&2,&2,String,Path.Request> <- Path.check(request)
    create_checked(checked)

def readable_context(value: Result<&2,&2,String,Path.Context>,request: Path.Request) -> IO(Result<&2,&2,String,Unit>):
  match value:
    case Fail{message}: IO.pure(Result<&2,&2,String,Unit>,Fail{message})
    case Done{+context}:
      +path = control(request)
      do IO<Result<&2,&2,String,Unit>>:
        regular : Result<&2,&2,String,Bool> <- Path.test("-f",path)
        link : Result<&2,&2,String,Bool> <- Path.test("-L",path)
        observed : Result<&2,&2,String,String> <- Path.stat(context,path)
        return Path.readable_values(context,regular,link,observed)

def readable(request: Path.Request) -> IO(Result<&2,&2,String,Unit>):
  do IO<Result<&2,&2,String,Unit>>:
    context : Result<&2,&2,String,Path.Context> <- Path.context()
    readable_context(context,request)

def valid_bytes(value: Result<&1,&1,U32 & String,List<&2,U32>>) -> Bool:
  match value:
    case Done{[]}: True{}
    case _: False{}

def allowed(value: Bool) -> IO(Unit):
  match value:
    case True{}: IO.pure(Unit,Unit{})
    case False{}: IO.die(Unit,3,error())

def read_closed(pair: File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(Unit):
  (file,result) = pair
  do IO<Unit>:
    File.close(file)
    allowed(valid_bytes(result))

def opened(value: Result<&1,&1,U32 & String,File>) -> IO(Unit):
  match value:
    case Fail{_}: IO.die(Unit,3,error())
    case Done{file}:
      do IO<Unit>:
        value : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_at(file,0,2)
        read_closed(value)

def check(mode: Mode) -> IO(Unit):
  match mode:
    case Unchecked{}: IO.sleep(0)
    case Checked{request}:
      do IO<Unit>:
        value : Result<&1,&1,U32 & String,File> <- File.open(control(request),"r")
        opened(value)

def write_ok(value: Result<&1,&1,U32 & String,Unit>) -> Bool:
  match value:
    case Done{_}: True{}
    case _: False{}

def written(pair: File & Result<&1,&1,U32 & String,Unit>) -> IO(Watched):
  (file,result) = pair
  do IO<Watched>:
    File.close(file)
    return Watched{True{},write_ok(result)}

def watching(value: Maybe<&1,Unit>,file: File,read_cancel: Chan(Unit)) -> IO(Watched):
  match value:
    case None{}:
      do IO<Watched>:
        File.close(file)
        return Watched{False{},True{}}
    case Some{_}:
      do IO<Watched>:
        # Also retire the parent file reader if the child has already reaped.
        Chan.close(Unit,read_cancel)
        value : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,[1])
        written(value)

def watch(cancel: Chan(Unit),file: File,read_cancel: Chan(Unit)) -> IO(Watched):
  do IO<Watched>:
    value : Maybe<&1,Unit> <- Chan.recv(Unit,cancel)
    watching(value,file,read_cancel)

def signal(channel: Chan(Unit)) -> IO(Unit):
  do IO<Unit>:
    _ : Poll<&1,&1,Result<&1,&1,Unit,Unit>,Unit> <- Chan.try_send(Unit,channel,Unit{},0)
    return Unit{}

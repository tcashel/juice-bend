import Base
import ../src/attachment_image_spool_protocol.bend as P
import ../src/attachment_image_spool_path.bend as Path
import ../src/attachment_image_spool_encode.bend as E
import ../src/attachment_image_file.bend as FileImage
import ../src/attachment_image_types.bend as Image
import ./attachment_image_stream.bend as Literal
import ./attachment_image_file.bend as Files
import ./attachment_preview_packet.bend as Fixture

def check(ok: Bool,label: String) -> IO(Unit): Fixture.check(ok,label)
def nonce() -> String: "0123456789abcdef0123456789abcdef"
def accepted(value: Result<&2,&2,String,P.Completion>,bytes: U32,digest: String) -> Bool:
  match value:
    case Done{P.Completion{actual,sha}}: U32.is_eq(actual,bytes) && String.eq(sha,digest)
    case _: False{}
def rejected(value: Result<&2,&2,String,P.Completion>) -> Bool:
  match value:
    case Fail{_}: True{}
    case _: False{}
def refuse(text: String,label: String) -> IO(Unit): check(rejected(P.parse(nonce(),text)),label)
def protocols() -> IO(Unit):
  do IO<Unit>:
    check(accepted(P.parse(nonce(),P.format(nonce(),700,Literal.sha())),700,Literal.sha()),"exact nonce count digest completion admitted")
    check(accepted(P.parse(nonce(),P.format(nonce(),700,"none")),700,"none"),"failure completion uses literal none")
    refuse(P.format("fedcba9876543210fedcba9876543210",700,Literal.sha()),"stale request nonce refused")
    refuse(P.format(nonce(),0,Literal.sha()),"zero completion count refused")
    refuse(P.format(nonce(),8454146,Literal.sha()),"oversized completion count refused")
    refuse("juice-bend-image-spool-v1 " ++ nonce() ++ " 4294967296 none\n","overflow completion count refused")
    refuse("juice-bend-image-spool-v1 " ++ nonce() ++ " 0700 none\n","noncanonical completion count refused")
    refuse(P.format(nonce(),700,"NONE"),"failure sentinel is exact")
    refuse(P.format(nonce(),700,"ABCDEF"),"digest must be64 lowercase hex bytes")
    refuse(P.format(nonce(),700,Literal.sha()) ++ "extra","completion cannot hide extra stdout")
    refuse("juice-bend-image-spool-v1 " ++ nonce() ++ " 700 none\r\n","CRLF completion refused")
    refuse("juice-bend-image-spool-v1 " ++ nonce() ++ " 700 none","missing completion separator refused")
    refuse(Fixture.repeat(161n,"x"),"completion has independent160byte bound")
    check(Bool.not(Path.nonce("../pixels.wire")) && Bool.not(Path.root_valid("relative")) && Bool.not(Path.root_valid("/tmp/\nwrong")),"path traversal and malformed roots refused")
    check(Bool.not(Path.identity("1:2:501:755","501")) && Bool.not(Path.identity("1:2:502:700","501")),"directory authority requires exact0700 and current owner")

def need_request(value: Result<&2,&2,String,Path.Request>) -> IO(Path.Request):
  match value:
    case Done{request}: IO.pure(Path.Request,request)
    case Fail{message}: IO.die(Path.Request,1,"FAIL request creation: " ++ message)
def is_request(value: Result<&2,&2,String,Path.Request>) -> Bool:
  match value:
    case Done{_}: True{}
    case _: False{}
def unit(value: Result<&2,&2,String,Unit>) -> Bool:
  match value:
    case Done{_}: True{}
    case _: False{}
def absent(value: Result<&2,&2,String,Bool>) -> Bool:
  match value:
    case Done{False{}}: True{}
    case _: False{}
def incorrect(value: Path.Request) -> Path.Request:
  Path.Request{root,key,identity} = value
  Path.Request{root,key,identity ++ "0"}
def raster() -> Image.Raster:
  Image.Raster{3,1,3,4,ANode{ANode{ALeaf{130815},ALeaf{305419896}},ANode{ALeaf{4278190080},ALeaf{0}}},False{}}
def encoded(value: Result<&2,&2,String,E.Receipt>,path: String) -> IO(Unit):
  match value:
    case Fail{message}: IO.die(Unit,1,"FAIL bounded writer: " ++ message)
    case Done{E.Receipt{+bytes,+digest}}:
      do IO<Unit>:
        check(U32.is_eq(bytes,Files.byte_count(Literal.packet(Literal.body()))) && String.eq(digest,Literal.sha()),"bounded writer reports independent exact count and SHA")
        value : FileImage.answer_type() <- FileImage.read(Literal.expected(),path,bytes,digest)
        check(Literal.good(value),"bounded writer and file reader preserve independent RGBA pixels and padding")
def removed(+request: Path.Request) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,String,Unit> <- Path.cleanup(request)
    check(unit(result),"cleanup removes only verified fixed file and empty request directory")
    result : Result<&2,&2,String,Bool> <- Path.test("-e",Path.directory(request))
    check(absent(result),"completed request leaves no directory")
def request(+root: String) -> IO(Path.Request):
  do IO<Path.Request>:
    value : Result<&2,&2,String,Path.Request> <- Path.create(root)
    need_request(value)
def request_nonce(request: Path.Request) -> String:
  Path.Request{_,key,_} = request
  key
def writing(+root: String) -> IO(Unit):
  do IO<Unit>:
    +request : Path.Request <- request(root)
    value : Result<&2,&2,String,Path.Request> <- Path.check(request)
    check(is_request(value),"fresh exclusive directory has exact device inode owner and0700 identity")
    key : String = request_nonce(request)
    collision : Result<&2,&2,String,Path.Request> <- Path.create_nonce(Done{key},root)
    check(Bool.not(is_request(collision)),"exclusive creation refuses an existing request directory")
    value : Result<&2,&2,String,Unit> <- Path.empty(request)
    check(unit(value),"fresh fixed output is absent")
    value : Result<&2,&2,String,Path.Request> <- Path.check(incorrect(request))
    check(Bool.not(is_request(value)),"changed directory identity refused before use")
    value : Result<&2,&2,String,Unit> <- Path.cleanup(incorrect(request))
    check(Bool.not(unit(value)),"changed directory identity cannot authorize cleanup")
    value : Result<&2,&2,String,E.Receipt> <- E.raster(Fixture.json(Literal.binding()),Path.output(request),raster())
    encoded(value,Path.output(request))
    value : Result<&2,&2,String,Unit> <- Path.empty(request)
    check(Bool.not(unit(value)),"existing fixed output cannot be overwritten")
    value : Result<&2,&2,String,Unit> <- Path.readable(request)
    check(unit(value),"completed output is verified regular and current-owner before admission")
    removed(request)
def primitive(result: Result<&2,&2,String,String>) -> IO(Unit):
  match result:
    case Done{""}: IO.pure(Unit,Unit{})
    case _: IO.die(Unit,1,"FAIL isolated fixture filesystem primitive")
def symlink(+root: String) -> IO(Unit):
  do IO<Unit>:
    +request : Path.Request <- request(root)
    result : Result<&2,&2,String,String> <- Path.command("/bin/ln",["-s",root ++ "/missing-target",Path.output(request)])
    primitive(result)
    value : Result<&2,&2,String,Unit> <- Path.empty(request)
    check(Bool.not(unit(value)),"dangling output symlink is not treated as empty")
    value : Result<&2,&2,String,Unit> <- Path.readable(request)
    check(Bool.not(unit(value)),"symlink output is refused before parent file open")
    removed(request)
    value : Result<&2,&2,String,Bool> <- Path.test("-e",root ++ "/missing-target")
    check(absent(value),"fixed-file cleanup did not follow a symlink target")
def failure_result(value: Result<&2,&2,String,E.Receipt>,path: String) -> IO(Unit):
  match value:
    case Fail{message}: IO.die(Unit,1,"FAIL failure spool write: " ++ message)
    case Done{E.Receipt{bytes,+digest}}:
      do IO<Unit>:
        check(String.eq(digest,"none"),"unsupported decode uses exact failure completion sentinel")
        read : FileImage.answer_type() <- FileImage.read(Literal.expected(),path,bytes,digest)
        check(Literal.failed(read,"unsupported_jpeg: Progressive JPEG is not yet supported"),"typed unsupported reason keeps exact occurrence binding through file transport")
def failure(+root: String) -> IO(Unit):
  do IO<Unit>:
    +request : Path.Request <- request(root)
    result : Result<&2,&2,String,E.Receipt> <- E.decoded(Fixture.json(Literal.binding()),Path.output(request),Fail{"unsupported_jpeg: Progressive JPEG is not yet supported"})
    failure_result(result,Path.output(request))
    removed(request)
type Written is Type:
  Written{result: Result<&2,&2,String,E.Receipt>}
def write_many(path: String) -> IO(Written):
  do IO<Written>:
    result : Result<&2,&2,String,E.Receipt> <- E.raster(Fixture.json(Literal.binding()),path,Image.Raster{32,32,1024,1024,Array.new(U32,10n,287454020),False{}})
    return Written{result}
def many_result(value: Result<&2,&2,String,E.Receipt>,path: String) -> IO(Unit):
  match value:
    case Fail{message}: IO.die(Unit,1,"FAIL many pixel writer: " ++ message)
    case Done{E.Receipt{bytes,+digest}}:
      do IO<Unit>:
        check(String.eq(digest,Literal.many_sha()),"chunked writer hashes1024pixels against independent SHA")
        actual : FileImage.answer_type() <- FileImage.read(Literal.expected(),path,bytes,digest)
        check(Literal.many(actual),"all1024pixels survive writer batches and file admission")
def heartbeat_step(channel: Chan(Written),turns: U32,path: String,result: Poll<&1,&1,Maybe<&1,Written>,Unit>,next: Chan(Written) -> U32 -> IO(Unit)) -> IO(Unit):
  match result:
    case Ready{Some{Written{result}}}:
      do IO<Unit>:
        check(U32.is_ge(turns,2),"heartbeat runs between bounded writer batches")
        many_result(result,path)
        Chan.close(Written,channel)
    case Ready{None{}}: IO.die(Unit,1,"FAIL writer closed without result")
    case Wait{_}: next(channel,U32.inc(turns))
def heartbeat(fuel: Nat,+channel: Chan(Written),turns: U32,+path: String) -> IO(Unit):
  match fuel:
    case 0n: IO.die(Unit,1,"FAIL writer heartbeat bound")
    case 1n+left:
      do IO<Unit>:
        IO.sleep(0)
        result : Poll<&1,&1,Maybe<&1,Written>,Unit> <- Chan.try_recv(Written,channel,0)
        heartbeat_step(channel,turns,path,result,c => t => heartbeat(left,c,t,path))
def many(+root: String) -> IO(Unit):
  do IO<Unit>:
    +request : Path.Request <- request(root)
    channel : Chan(Written) <- IO.fork(Written,write_many(Path.output(request)))
    heartbeat(20000n,channel,0,Path.output(request))
    removed(request)
def main() -> IO(Unit):
  do IO<Unit>:
    protocols()
    +root : String <- Files.root()
    writing(root)
    symlink(root)
    failure(root)
    many(root)
    result : Result<&2,&2,String,String> <- Path.command("/bin/rmdir",["--",root])
    primitive(result)

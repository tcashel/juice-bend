import Base
import ../src/attachment_image_stream.bend as S
import ../src/attachment_image_binding.bend as H
import ../src/attachment_image_encode.bend as E
import ../src/attachment_image_types.bend as T
import ../src/domain.bend as D
import ../src/json.bend as J
import ./attachment_preview_packet.bend as F

# Pixel hashes are independent hashlib constants over big-endian RGBA bytes.
# The main accepted packet is an independently specified literal, not the
# encoder under test. No database, file, image source or network is used.
def sha() -> String: "4eb212c64e01c33a2f178ee3a46212c41c9347d9deb0b9c54644e4fd8e9c1c0c"
def many_sha() -> String: "d54f649382b0515e55ca23670a0300f8083ca1d7f9f90fa818697c2c7e71b831"
def expected() -> H.Expected: H.ExpectedInline{F.expected(4)}
def binding() -> String:
  "{\"kind\":\"inline\",\"capture\":" ++ F.capture() ++ ",\"record\":1,\"ref\":2,\"path\":\"/message/content/2/source/data\",\"offset\":40,\"length\":20,\"raw_sha256\":\"" ++ F.raw_sha() ++ "\",\"media\":\"image/png\",\"byte_count\":4,\"byte_sha256\":\"" ++ F.binary_sha() ++ "\"}"
def header(w: U32,h: U32,count: U32,capacity: U32,digest: String) -> String:
  "{\"kind\":\"attachment_image_raster\",\"version\":1,\"binding\":" ++ binding() ++ ",\"result\":{\"kind\":\"pixels\",\"width\":" ++ U32.show(w) ++ ",\"height\":" ++ U32.show(h) ++ ",\"count\":" ++ U32.show(count) ++ ",\"capacity\":" ++ U32.show(capacity) ++ ",\"notice\":false,\"sha256\":\"" ++ digest ++ "\"}}"
def packet(body: String) -> String: header(3,1,3,4,sha()) ++ "\n" ++ body
def body() -> String: "0001feff12345678ff000000"
def failure() -> String:
  "{\"kind\":\"attachment_image_raster\",\"version\":1,\"binding\":" ++ binding() ++ ",\"result\":{\"kind\":\"failure\",\"message\":\"unsupported_jpeg: Progressive JPEG is not yet supported\"}}\n"
def check(ok: Bool,label: String) -> IO(Unit): F.check(ok,label)

def array_after(pair: Array<U32> & U32,expected: U32,next: Array<U32> -> Bool) -> Bool:
  (array,value) = pair
  U32.is_eq(value,expected) && next(array)
def array_equal(values: List<&2,U32>,array: Array<U32>,+index: U32) -> Bool:
  match values:
    case []: True{}
    case value <> rest: array_after(Array.get(U32,array,index),value,a => array_equal(rest,a,U32.inc(index)))
def good(value: Result<&2,&1,String,T.Raster>) -> Bool:
  match value:
    case Done{T.Raster{3,1,3,4,pixels,False{}}}: array_equal([130815,305419896,4278190080,0],pixels,0)
    case _: False{}
def many(value: Result<&2,&1,String,T.Raster>) -> Bool:
  match value:
    case Done{T.Raster{32,32,1024,1024,pixels,False{}}}: array_equal(List.replicate(U32,1024n,287454020),pixels,0)
    case _: False{}
def failed(value: Result<&2,&1,String,T.Raster>,wanted: String) -> Bool:
  match value:
    case Fail{message}: String.eq(message,wanted)
    case _: False{}
def rejected(text: String,wanted: String,label: String) -> IO(Unit):
  do IO<Unit>:
    value : Result<&2,&1,String,T.Raster> <- S.read(expected(),text)
    check(failed(value,wanted),label)
def encoded(value: Result<&2,&2,String,String>) -> IO(Unit):
  match value:
    case Fail{message}: IO.die(Unit,1,"FAIL child raster encoding: " ++ message)
    case Done{text}:
      do IO<Unit>:
        actual : Result<&2,&1,String,T.Raster> <- S.read(expected(),text)
        check(good(actual),"child pixel serializer survives strict independent parent admission without dropping alpha")

type Returned is Type:
  Returned{value: Result<&2,&1,String,T.Raster>}
def reading() -> IO(Returned):
  do IO<Returned>:
    value : Result<&2,&1,String,T.Raster> <- S.read(expected(),header(32,32,1024,1024,many_sha()) ++ "\n" ++ F.repeat(1024n,"11223344"))
    return Returned{value}
def heartbeat_step(channel: Chan(Returned),turns: U32,result: Poll<&1,&1,Maybe<&1,Returned>,Unit>,next: Chan(Returned) -> U32 -> IO(Unit)) -> IO(Unit):
  match result:
    case Ready{Some{Returned{value}}}:
      do IO<Unit>:
        check(many(value),"forked admission preserves all1024 exact pixels")
        check(U32.is_ge(turns,2),"independent heartbeat runs between bounded parent admission chunks")
        Chan.close(Returned,channel)
    case Ready{None{}}: IO.die(Unit,1,"FAIL incremental admission closed without a result")
    case Wait{_}: next(channel,U32.inc(turns))
def heartbeat(fuel: Nat,+channel: Chan(Returned),turns: U32) -> IO(Unit):
  match fuel:
    case 0n: IO.die(Unit,1,"FAIL incremental admission heartbeat bound")
    case 1n+left:
      do IO<Unit>:
        IO.sleep(0)
        value : Poll<&1,&1,Maybe<&1,Returned>,Unit> <- Chan.try_recv(Returned,channel,0)
        heartbeat_step(channel,turns,value,c => t => heartbeat(left,c,t))

def main() -> IO(Unit):
  do IO<Unit>:
    value : Result<&2,&1,String,T.Raster> <- S.read(expected(),packet(body()))
    check(good(value),"literal pixel packet preserves zero nonUTF8 and alpha bytes with exact zero padding")
    rejected(packet("0001feff12345678ff00000"),"image_pixel_length_mismatch","short final pixel is refused")
    rejected(packet("0001FEff12345678ff000000"),"image_pixel_invalid_hex","uppercase hex is refused")
    rejected(packet("0001geff12345678ff000000"),"image_pixel_invalid_hex","nonhex is refused")
    rejected(packet(body() ++ "00"),"image_pixel_trailing_data","extra pixels or suffix are refused")
    rejected(packet(body() ++ "\n"),"image_pixel_trailing_data","final newline is refused")
    rejected(packet("0001feff12345678ff000001"),"image_pixel_digest_or_array_mismatch","changed pixel with original digest is refused")
    rejected(header(3,1,3,4,sha()),"image_header_missing_separator","missing header separator is refused")
    rejected(F.repeat(65537n,"x") ++ "\n","image_header_limit_or_encoding","oversized header refuses before JSON parse")
    rejected(SCon{Chr{55296},"\n"},"image_header_limit_or_encoding","invalid Unicode scalar in header is refused")
    rejected(failure(),"unsupported_jpeg: Progressive JPEG is not yet supported","bound exact failure identity reaches visible typed reason")
    rejected(failure() ++ "0","image_failure_trailing_data","failure packets cannot carry a hidden pixel body")
    encoded(E.raster(F.json(binding()),T.Raster{3,1,3,4,ANode{ANode{ALeaf{130815},ALeaf{305419896}},ANode{ALeaf{4278190080},ALeaf{0}}},False{}}))
    channel : Chan(Returned) <- IO.fork(Returned,reading())
    heartbeat(20000n,channel,0)

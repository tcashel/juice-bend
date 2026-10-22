import Base
import ../src/attachment_image_file.bend as FileImage
import ../src/attachment_image_stream.bend as Stream
import ../src/attachment_image_binding.bend as Header
import ../src/attachment_image_types.bend as Image
import ../src/domain.bend as D
import ./attachment_image_stream.bend as Literal
import ./attachment_preview_packet.bend as Fixture

# Actual file IO with independently specified packets and SHA constants from
# the legacy admission fixture. No encoder, SQLite, decoder, original source,
# home directory or network participates. The test creates one private root.
def check(ok: Bool,label: String) -> IO(Unit): Fixture.check(ok,label)
def length(bytes: List<&2,U32>) -> U32: U32.from_nat(List.length(&2,U32,bytes))
def wire() -> String: Literal.packet(Literal.body())
def byte_count(text: String) -> U32: length(D.encode(text))
def unicode_message() -> String: "Unsupported café 中文 🙂 é"
def unicode_failure() -> String:
  "{\"kind\":\"attachment_image_raster\",\"version\":1,\"binding\":" ++ Literal.binding() ++ ",\"result\":{\"kind\":\"failure\",\"message\":\"Unsupported café 中文 🙂 é\"}}\n"

def root_result(value: U32 & (String & String)) -> IO(String):
  match value:
    case (0,(text,"")): IO.pure(String,String.trim(text))
    case _: IO.die(String,1,"FAIL private image file fixture root")

def root() -> IO(String):
  do IO<String>:
    value : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/usr/bin/mktemp",["-d","/tmp/juice-bend-image-file.XXXXXX"],"",1024,2000))
    root_result(value)

def written(value: File & Result<&1,&1,U32 & String,Unit>) -> IO(Unit):
  (file,result) = value
  do IO<Unit>:
    File.close(file)
    IO.try(Unit,IO.pure(Result<&1,&1,U32 & String,Unit>,result))

def write(path: String,bytes: List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    value : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    written(value)

def remove_result(value: U32 & (String & String)) -> IO(Unit):
  match value:
    case (0,("","")): IO.pure(Unit,Unit{})
    case _: IO.die(Unit,1,"FAIL private image file fixture cleanup")

def cleanup(+directory: String) -> IO(Unit):
  do IO<Unit>:
    removed : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/bin/rm",["--",directory ++ "/wire"],"",1024,2000))
    remove_result(removed)
    removed : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/bin/rmdir",["--",directory],"",1024,2000))
    remove_result(removed)

def widths(sizes: List<&2,U32>,+path: String) -> IO(Unit):
  match sizes:
    case []: IO.pure(Unit,Unit{})
    case +size <> rest:
      do IO<Unit>:
        value : FileImage.answer_type() <- FileImage.read_bounded(Literal.expected(),path,byte_count(wire()),Literal.sha(),size,None{})
        check(Literal.good(value),"file literal exact pixels and zero padding with read size " ++ U32.show(size))
        widths(rest,path)

def unicode_widths(sizes: List<&2,U32>,+path: String) -> IO(Unit):
  match sizes:
    case []: IO.pure(Unit,Unit{})
    case +size <> rest:
      do IO<Unit>:
        value : FileImage.answer_type() <- FileImage.read_bounded(Literal.expected(),path,byte_count(unicode_failure()),"none",size,None{})
        check(Literal.failed(value,unicode_message()),"UTF8 failure reason survives every scalar boundary with read size " ++ U32.show(size))
        unicode_widths(rest,path)

def rejected(+path: String,bytes: List<&2,U32>,count: U32,digest: String,wanted: String,label: String) -> IO(Unit):
  do IO<Unit>:
    write(path,bytes)
    value : FileImage.answer_type() <- FileImage.read(Literal.expected(),path,count,digest)
    check(Literal.failed(value,wanted),label)

def reject_text(path: String,+text: String,digest: String,wanted: String,label: String) -> IO(Unit):
  rejected(path,D.encode(text),byte_count(text),digest,wanted,label)

def bad_utf8(cases: List<&2,List<&2,U32>>,+path: String,+index: U32) -> IO(Unit):
  match cases:
    case []: IO.pure(Unit,Unit{})
    case bytes <> rest:
      +packet : List<&2,U32> = List.append(&2,U32,bytes,[10])
      do IO<Unit>:
        rejected(path,packet,length(packet),"none","image_header_limit_or_encoding","malformed UTF8 file fixture " ++ U32.show(index))
        bad_utf8(rest,path,U32.inc(index))

# Cancellation signals are checked through the same channel as production.
# The channel remains owned by the caller. This does not claim UI/child exit.
def cancelled(+path: String) -> IO(Unit):
  do IO<Unit>:
    +channel : Chan(Unit) <- Chan.new(Unit,1)
    _ : Result<&1,&1,Unit,Unit> <- Chan.send(Unit,channel,Unit{})
    value : FileImage.answer_type() <- FileImage.read_checked(Literal.expected(),path,byte_count(wire()),Literal.sha(),Some{channel})
    check(Literal.failed(value,"image_file_cancelled"),"signalled request cancels before file admission")
    Chan.close(Unit,channel)
    value : FileImage.answer_type() <- FileImage.read_checked(Literal.expected(),path,byte_count(wire()),Literal.sha(),Some{channel})
    check(Literal.failed(value,"image_file_cancelled"),"closed request channel also cancels admission")
    value : FileImage.answer_type() <- FileImage.read(Literal.expected(),path,byte_count(wire()),Literal.sha())
    check(Literal.good(value),"same retained file can be read after cancelled admission")

def parse_next(result: FileImage.feed_type(),next: FileImage.State -> List<&2,U32> -> FileImage.feed_type()) -> FileImage.feed_type():
  match result:
    case Fail{message}: Fail{message}
    case Done{FileImage.Fed{state,rest}}: next(state,rest)

def parse_steps(fuel: Nat,state: FileImage.State,bytes: List<&2,U32>,+digest: String) -> FileImage.feed_type():
  match fuel:
    case 0n: Done{FileImage.Fed{state,bytes}}
    case 1n+left:
      parse_next(FileImage.feed(256n,state,bytes,Literal.expected(),digest),s => b => parse_steps(left,s,b,digest))

def eof_cancel(value: File & Result<&1,&1,U32 & String,List<&2,U32>>,state: FileImage.State,cancel: Maybe<&2,Chan(Unit)>) -> IO(FileImage.answer_type()):
  (file,result) = value
  match result:
    case Done{[]}: FileImage.eof(True{},file,state,cancel)
    case _: FileImage.close(file,Fail{"fixture_expected_eof"})

def cancel_stage(padding: Bool,file: File,state: FileImage.State,buffer: List<&2,U32>,total: U32,+config: FileImage.Config,cancel: Maybe<&2,Chan(Unit)>) -> IO(FileImage.answer_type()):
  match padding:
    case True{}:
      do IO<FileImage.answer_type()>:
        value : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,1)
        eof_cancel(value,state,cancel)
    case False{}: FileImage.pump(FileImage.turn_limit(config),file,total,state,buffer,config,cancel)

def checked_stage(state: FileImage.State,+buffer: List<&2,U32>,file: File,+total: U32,+config: FileImage.Config,+padding: Bool,cancel: Maybe<&2,Chan(Unit)>) -> IO(FileImage.answer_type()):
  match state:
    case FileImage.Pixels{Stream.Receiving{header,+index,tail,hash,stack},+digits,word}:
      Stream.Extent{w,h,+count,capacity,notice,sha} = header
      do IO<FileImage.answer_type()>:
        check(Bool.pick(Bool,padding,
          U32.is_eq(index,count) && U32.is_eq(digits,0) && List.is_empty(&2,U32,buffer) && U32.is_eq(total,FileImage.known(config)),
          U32.is_gt(index,0) && U32.is_lt(index,count) && Bool.not(List.is_empty(&2,U32,buffer))),
          Bool.pick(String,padding,"fixture reaches exact EOF before padding cancellation","fixture reaches partially consumed real file buffer"))
        cancel_stage(padding,file,FileImage.Pixels{Stream.Receiving{Stream.Extent{w,h,count,capacity,notice,sha},index,tail,hash,stack},digits,word},
          buffer,total,config,cancel)
    case _: FileImage.close(file,Fail{"fixture_expected_pixel_state"})

def staged(result: FileImage.feed_type(),file: File,total: U32,config: FileImage.Config,padding: Bool,cancel: Maybe<&2,Chan(Unit)>) -> IO(FileImage.answer_type()):
  match result:
    case Fail{message}: FileImage.close(file,Fail{message})
    case Done{FileImage.Fed{state,buffer}}: checked_stage(state,buffer,file,total,config,padding,cancel)

def stage_read(value: File & Result<&1,&1,U32 & String,List<&2,U32>>,steps: Nat,+config: FileImage.Config,padding: Bool,cancel: Maybe<&2,Chan(Unit)>) -> IO(FileImage.answer_type()):
  (file,result) = value
  match result:
    case Fail{_}: FileImage.close(file,Fail{"fixture_read_failed"})
    case Done{+bytes}:
      staged(parse_steps(steps,FileImage.Heading{D.DecodeState{0,0,0,""},0},bytes,FileImage.digest(config)),file,length(bytes),config,padding,cancel)

# These phase-entry tests read a real owned file and use production feed
# kernels to reach the target state, then cancel at the production checkpoint.
# They do not infer a wall-clock Close bound or child-process cancellation.
def staged_cancel(+path: String,+text: String,+digest: String,steps: Nat,+padding: Bool) -> IO(Unit):
  do IO<Unit>:
    write(path,D.encode(text))
    +channel : Chan(Unit) <- Chan.new(Unit,1)
    Chan.close(Unit,channel)
    file : File <- IO.try(File,File.open(path,"r"))
    value : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,4096)
    answer : FileImage.answer_type() <- stage_read(value,steps,FileImage.Config{Literal.expected(),byte_count(text),digest,4096},padding,Some{channel})
    check(Literal.failed(answer,"image_file_cancelled"),Bool.pick(String,padding,
      "EOF admission polls cancellation before padding and digest","partly consumed file buffer polls cancellation before its next feed"))

type Returned is Type:
  Returned{value: FileImage.answer_type()}

def reading(path: String,count: U32) -> IO(Returned):
  do IO<Returned>:
    value : FileImage.answer_type() <- FileImage.read(Literal.expected(),path,count,Literal.many_sha())
    return Returned{value}

def heartbeat_step(channel: Chan(Returned),turns: U32,result: Poll<&1,&1,Maybe<&1,Returned>,Unit>,next: Chan(Returned) -> U32 -> IO(Unit)) -> IO(Unit):
  match result:
    case Ready{Some{Returned{value}}}:
      do IO<Unit>:
        check(Literal.many(value),"4096-byte file buffers preserve all 1024 exact pixels")
        check(U32.is_ge(turns,8),"heartbeat runs between sub-buffer admission steps")
        Chan.close(Returned,channel)
    case Ready{None{}}: IO.die(Unit,1,"FAIL file admission closed without a result")
    case Wait{_}: next(channel,U32.inc(turns))

def heartbeat(fuel: Nat,+channel: Chan(Returned),turns: U32) -> IO(Unit):
  match fuel:
    case 0n: IO.die(Unit,1,"FAIL file admission heartbeat bound")
    case 1n+left:
      do IO<Unit>:
        IO.sleep(0)
        value : Poll<&1,&1,Maybe<&1,Returned>,Unit> <- Chan.try_recv(Returned,channel,0)
        heartbeat_step(channel,turns,value,c => t => heartbeat(left,c,t))

def limits(+path: String) -> IO(Unit):
  do IO<Unit>:
    value : FileImage.answer_type() <- FileImage.read(Literal.expected(),path,8454146,Literal.sha())
    check(Literal.failed(value,"image_file_limit"),"completion byte count above 8454145 refuses before file access")
    value : FileImage.answer_type() <- FileImage.read(Literal.expected(),path,0,Literal.sha())
    check(Literal.failed(value,"image_file_limit"),"zero completion byte count is refused")
    value : FileImage.answer_type() <- FileImage.read_bounded(Literal.expected(),path,1,Literal.sha(),4097,None{})
    check(Literal.failed(value,"image_file_limit"),"file read size cannot exceed 4096")
    value : FileImage.answer_type() <- FileImage.read_bounded(Literal.expected(),path,1,Literal.sha(),0,None{})
    check(Literal.failed(value,"image_file_limit"),"zero read size cannot create a nonprogressing reader")

def failures(+path: String) -> IO(Unit):
  do IO<Unit>:
    rejected(path,D.encode(wire()),U32.inc(byte_count(wire())),Literal.sha(),"image_file_byte_count_mismatch","short file refuses a larger claimed completion count")
    rejected(path,D.encode(wire()),U32.sub(byte_count(wire()),1),Literal.sha(),"image_file_byte_count_mismatch","actual file cannot exceed its completion count")
    reject_text(path,Literal.packet("0001feff12345678ff00000"),Literal.sha(),"image_pixel_length_mismatch","short final pixel at exact EOF is refused")
    reject_text(path,Literal.packet("0001FEff12345678ff000000"),Literal.sha(),"image_pixel_invalid_hex","uppercase pixel hex is refused")
    reject_text(path,Literal.packet("0001geff12345678ff000000"),Literal.sha(),"image_pixel_invalid_hex","nonhex pixel byte is refused")
    reject_text(path,Literal.packet("0001feff12345678ff000001"),Literal.sha(),"image_pixel_digest_or_array_mismatch","pixel SHA mutation is refused by shared finalization")
    reject_text(path,wire() ++ "00",Literal.sha(),"image_pixel_trailing_data","trailing bytes are refused even when completion count includes them")
    reject_text(path,wire() ++ "\n",Literal.sha(),"image_pixel_trailing_data","final newline is not treated as harmless whitespace")
    reject_text(path,wire(),Fixture.raw_sha(),"image_completion_digest_mismatch","completion digest must bind the admitted header")
    reject_text(path,Literal.failure(),Literal.sha(),"image_completion_digest_mismatch","failure header requires completion digest none")
    reject_text(path,Literal.failure(),"none","unsupported_jpeg: Progressive JPEG is not yet supported","exact bound failure reason survives EOF")
    reject_text(path,Literal.failure() ++ "0","none","image_failure_trailing_data","failure packet cannot hide a body")
    reject_text(path,Literal.header(3,1,3,4,Literal.sha()),Literal.sha(),"image_header_missing_separator","missing separator never starts body admission")
    reject_text(path,Fixture.repeat(65537n,"x") ++ "\n","none","image_header_limit_or_encoding","65537-byte header is refused before JSON parsing")
    reject_text(path,"{}\n","none","image_header_shape","invalid closed metadata shape is refused")
    reject_text(path,Literal.header(3,1,3,8,Literal.sha()) ++ "\n" ++ Literal.body(),Literal.sha(),"image_pixel_geometry","incorrect array capacity is refused")
    bad_utf8([[128],[192,175],[224,128,175],[237,160,128],[244,144,128,128],[194,32],[240,159,153]],path,1)
    limits(path)

def main() -> IO(Unit):
  do IO<Unit>:
    +directory : String <- root()
    +path : String = directory ++ "/wire"
    write(path,D.encode(wire()))
    widths([1,2,3,4,5,6,7,8,9,15,31,255,256,257,4095,4096],path)
    cancelled(path)
    staged_cancel(path,wire(),Literal.sha(),U32.to_nat(U32.div(U32.add(byte_count(wire()),255),256)),True{})
    write(path,D.encode(unicode_failure()))
    unicode_widths([1,2,3,4,5,7,255,256,257,4096],path)
    failures(path)
    write(path,D.encode(wire()))
    value : FileImage.answer_type() <- FileImage.read(Header.ExpectedInline{Fixture.expected(5)},path,byte_count(wire()),Literal.sha())
    check(Literal.failed(value,"image_inline_binding_mismatch"),"file header cannot substitute a different retained occurrence")
    +large : String = Literal.header(32,32,1024,1024,Literal.many_sha()) ++ "\n" ++ Fixture.repeat(1024n,"11223344")
    staged_cancel(path,large,Literal.many_sha(),U32.to_nat(U32.inc(U32.div(U32.add(byte_count(Literal.header(32,32,1024,1024,Literal.many_sha()) ++ "\n"),255),256))),False{})
    write(path,D.encode(large))
    channel : Chan(Returned) <- IO.fork(Returned,reading(path,byte_count(large)))
    heartbeat(20000n,channel,0)
    value : FileImage.answer_type() <- FileImage.read(Literal.expected(),directory ++ "/absent",1,"none")
    check(Literal.failed(value,"image_file_open_error"),"missing request-owned spool returns a bounded open error")
    cleanup(directory)

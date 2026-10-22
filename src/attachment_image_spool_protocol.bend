import Base
import ./domain.bend as D
import ./attachment_image_stream.bend as Stream
import ./attachment_image_spool_path.bend as Path

type Completion is Data:
  Completion{bytes: U32,digest: String}

def limit() -> U32: 160
def format(nonce: String,bytes: U32,digest: String) -> String:
  "juice-bend-image-spool-v1 " ++ nonce ++ " " ++ U32.show(bytes) ++ " " ++ digest ++ "\n"
def digest(+value: String) -> Bool: String.eq(value,"none") || Path.hex(64n,value)
def count(value: Maybe<&2,U32>,+text: String,digest: String) -> Result<&2,&2,String,Completion>:
  match value:
    case Some{+bytes}:
      Bool.pick(Result<&2,&2,String,Completion>,U32.is_gt(bytes,0) && U32.is_le(bytes,Stream.max_output()) && String.eq(U32.show(bytes),text),Done{Completion{bytes,digest}},Fail{"image_spool_completion_extent"})
    case None{}: Fail{"image_spool_completion_extent"}
def parts(parts: List<&2,String>,+nonce: String) -> Result<&2,&2,String,Completion>:
  match parts:
    case ["juice-bend-image-spool-v1",actual,+bytes,+sha]:
      do Result<&2,&2,String,Completion>:
        _ : Unit <- Path.require(Path.nonce(nonce) && String.eq(actual,nonce) && digest(sha),"image_spool_completion_identity")
        count(D.parse_u32(bytes),bytes,sha)
    case _: Fail{"image_spool_completion_shape"}
def parse(nonce: String,+text: String) -> Result<&2,&2,String,Completion>:
  do Result<&2,&2,String,Completion>:
    _ : Unit <- Path.require(U32.is_le(U32.from_nat(String.length(text)),limit()),"image_spool_completion_limit")
    body : String <- Path.line(Done{text})
    parts(String.split(body,' '),nonce)

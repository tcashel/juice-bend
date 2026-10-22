import Base
import ./native_repository.bend as Safe
import ./native_request_origin.bend as Origin
import ../src/domain.bend as Domain
import ../src/json.bend as Json
import ../src/paths.bend as Paths
import ../tests/zstd/frame_vectors.bend as Vectors

# Synthetic native-UI fixture generator. It creates only a new canonical
# /private/tmp/juice-bend-native-archive-UUID root, with no capture or app launch.
# The fixed entropy frame predates the decoder; expected JSONL is independent.
def checked(ok: Bool,message: String) -> IO(Unit):
  match ok:
    case True{}: IO.pure(Unit,Unit{})
    case False{}: IO.die(Unit,1,"Native archive fixture: " ++ message)

def closed(result: File & Result<&1,&1,U32 & String,Unit>) -> IO(Unit):
  (file,value) = result
  do IO<Unit>:
    File.close(file)
    IO.try(Unit,IO.pure(Result<&1,&1,U32 & String,Unit>,value))

def write(path: String,bytes: List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    result : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    closed(result)

def text(path: String,value: String) -> IO(Unit):
  write(path,Domain.encode(value))

def records(fuel: Nat,+index: U32) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest:
      +role = Bool.pick(String,U32.is_eq(U32.mod(index,3),0),"user","assistant")
      "{\"type\":\"" ++ role ++ "\",\"sessionId\":\"synthetic-zstd\",\"message\":{\"role\":\"" ++ role ++
        "\",\"content\":\"Archive record " ++ U32.show(index) ++ ": keep exact cafe and code path src/" ++
        U32.show(U32.mod(index,7)) ++ ".bend; value=" ++ U32.show(U32.mul(index,index)) ++ "\"}}\n" ++ records(rest,U32.inc(index))

def request(+repo: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"native-archive-brief\",\"cwd\":" ++ Json.quote(repo) ++
    ",\"message\":{\"content\":\"Preserve this archived calculation and its recorded evidence.\"}}\n" ++
    "{\"type\":\"assistant\",\"sessionId\":\"native-archive-brief\",\"cwd\":" ++ Json.quote(repo) ++
    ",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"archive-write-1\",\"name\":\"Write\",\"input\":{\"file_path\":\"archive-proof.txt\",\"content\":\"let archived = 42\\n\"}}]}}\n" ++
    "{\"type\":\"user\",\"sessionId\":\"native-archive-brief\",\"cwd\":" ++ Json.quote(repo) ++
    ",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"archive-write-1\",\"content\":\"Saved archive-proof.txt\"}]}}\n"

def raw_frame(+bytes: List<&2,U32>) -> List<&2,U32>:
  +header = U32.add(U32.mul(U32.from_nat(List.length(&2,U32,bytes)),8),1)
  List.append(&2,U32,[40,181,47,253,0,56,U32.and(header,255),
    U32.and(U32.shrn(header,8n),255),U32.and(U32.shrn(header,16n),255)],bytes)

def manifest(+root: String) -> String:
  "{\"fixture\":\"juice-bend-native-archive-v1\",\"synthetic\":true,\"root\":" ++ Json.quote(root) ++
    ",\"repository\":" ++ Json.quote(root ++ "/repository") ++ ",\"data_dir\":" ++ Json.quote(root ++ "/library") ++
    ",\"entropy_records\":100,\"brief_records\":3,\"entropy_sha256\":" ++ Json.quote(Domain.digest(Vectors.jsonl_check())) ++
    ",\"entropy_logical_sha256\":" ++ Json.quote(Domain.digest(Domain.encode(records(100n,0)))) ++
    ",\"brief_sha256\":" ++ Json.quote(Domain.digest(raw_frame(Domain.encode(request(root ++ "/repository"))))) ++
    ",\"brief_logical_sha256\":" ++ Json.quote(Domain.digest(Domain.encode(request(root ++ "/repository")))) ++ "}"

def prepare(+root: String) -> IO(Unit):
  +repo = root ++ "/repository"
  do IO<Unit>:
    Safe.directory(root)
    Safe.regular_path(root,True{})
    Safe.directory(repo)
    Safe.directory(root ++ "/library")
    Safe.directory(root ++ "/sources")
    Safe.directory(root ++ "/expected")
    initialized : String <- Safe.git(repo,["-c","init.defaultBranch=main","init","--quiet","--template="])
    text(repo ++ "/archive-proof.txt","let archived = 42\n")
    commit : String <- Safe.commit(repo,"Create synthetic archive proof\n\nClaude-Session: native-archive-brief")
    write(root ++ "/sources/entropy.jsonl.zst",Vectors.jsonl_check())
    write(root ++ "/sources/request.jsonl.zst",raw_frame(Domain.encode(request(repo))))
    write(root ++ "/sources/broken.jsonl.zst",List.take(&2,U32,Vectors.jsonl_check(),20n))
    text(root ++ "/sources/plain.jsonl",request(repo))
    text(root ++ "/expected/entropy.jsonl",records(100n,0))
    text(root ++ "/expected/request.jsonl",request(repo))
    +description : String = manifest(root)
    text(root ++ "/.juice-bend-native-archive-v1.json",description ++ "\n")
    IO.print(description)

def fixture(+root: String) -> IO(Unit):
  +prefix = {"/private/tmp/juice-bend-native-archive-" : String}
  do IO<Unit>:
    checked(String.starts_with(root,prefix) && Origin.uuid(String.split(String.drop(root,String.length(prefix)),'-')),
      "requires a new /private/tmp/juice-bend-native-archive-UUID root")
    canonical : String <- Paths.destination(root)
    checked(String.eq(root,canonical),"root spelling must already be canonical")
    prepare(root)

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "fixture" <> root <> []: fixture(root)
    case _: IO.die(Unit,2,"Usage: native-archive fixture NEW-ROOT")

def main() -> IO(Unit):
  do IO<Unit>:
    Safe.environment(["GIT_DIR","GIT_WORK_TREE","GIT_COMMON_DIR","GIT_INDEX_FILE",
      "GIT_OBJECT_DIRECTORY","GIT_ALTERNATE_OBJECT_DIRECTORIES","GIT_CONFIG",
      "GIT_CONFIG_PARAMETERS","GIT_CONFIG_COUNT","GIT_TEMPLATE_DIR","GIT_SHALLOW_FILE","GIT_NAMESPACE"])
    args : List<String> <- IO.args()
    arguments(args)

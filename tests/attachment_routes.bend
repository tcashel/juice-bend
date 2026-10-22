import Base
import ../src/cli.bend as Cli
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/capture.bend as Capture
import ../src/domain.bend as Domain
import ../src/json.bend as J
import ./attachment_archive_export.bend as F

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def json(value: Result<&2,&2,String,J.Json>) -> J.Json:
  match value:
    case Done{value}: value
    case _: J.JNull{}

def output(result: U32 & (String & String)) -> J.Json:
  (code,(out,error)) = result
  Bool.pick(J.Json,U32.is_eq(code,0) && String.is_empty(error),json(J.parse(out)),J.JNull{})

def inventory(+value: J.Json) -> Bool:
  String.eq(J.get(value,"kind"),"attachment_inventory") && String.eq(J.get(J.field(value,"page"),"returned_occurrences"),"1")

def exported(+value: J.Json) -> Bool:
  String.eq(J.get(value,"kind"),"attachment_inline_export") && String.eq(J.get(value,"decoded_bytes"),"4") &&
    String.eq(J.get(value,"sha256"),"c5dbae22661af6db18a1f676db82a7ef7de46d27c3a263a872f00478b0d99fc4")

def invalid(result: U32 & (String & String)) -> Bool:
  (code,(out,error)) = result
  U32.is_eq(code,2) && String.eq(J.get(json(J.parse(error)),"code"),"attachment_usage") && String.is_empty(out)

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/attachment-archive-export.sqlite")
    F.write_bytes("route-source.jsonl",Domain.encode(F.fixture()))
    +snapshot : String <- Capture.import_file(db,"claude","route-source.jsonl")
    IO.try(Unit,Sql.close(db))
    listed : U32 & (String & String) <- F.child(self,"attachments",[snapshot,"0","1"])
    check(inventory(output(listed)),"actual Cli.command attachments route returns bounded metadata")
    saved : U32 & (String & String) <- F.child(self,"export-inline",[snapshot,"0","0",F.path(),"route-owned.bin"])
    check(exported(output(saved)),"actual Cli.command inline route publishes exact original-byte receipt")
    bytes : List<&2,U32> <- F.read_bytes("route-owned.bin")
    check(Domain.bytes_equal(bytes,[0,1,254,255]),"actual CLI dispatch preserves independent binary octets")
    bad : U32 & (String & String) <- F.child(self,"attachments",[snapshot,"0","0"])
    check(invalid(bad),"actual CLI invalid attachment range returns structured nonzero diagnostic")

def route(command: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/attachment-archive-export.sqlite")
    Cli.command(db,".",command,args)
    IO.try(Unit,Sql.close(db))

def argv(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case self <> "route" <> command <> rest: route(command,rest)
    case _: IO.die(Unit,2,"Expected synthetic attachment route gate")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    argv(args)

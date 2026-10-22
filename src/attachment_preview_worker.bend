import Base
import ./attachment_inline.bend as Inline
import ./attachment_cli.bend as Cli
import ./attachment_inventory.bend as Inventory
import ./attachment_decode.bend as Decode
import ./attachment_preview_packet.bend as Packet
import ./gui_attachments.bend as Attachments
import ./sql.bend as Sql
import ./attachment_refs.bend as Ref

# This is a read-only retained-byte child, separate from the external-file worker.
# It never opens an attachment source or URL and never publishes bytes to disk.
def command() -> String: "attachment-preview-inline-v1"

def parsed(result: Result<&2,&2,Inventory.Failure,Cli.Command>) -> Result<&2,&2,String,Inline.Request>:
  match result:
    case Done{Cli.ExportCommand{request,_}}: Done{request}
    case _: Fail{"Invalid exact retained-image request"}

def parse(args: List<String>) -> Result<&2,&2,String,Inline.Request>:
  match args:
    case snapshot <> record <> reference <> path <> []:
      parsed(Cli.parse("export-inline",[snapshot,record,reference,path,"/preview-unused"]))
    case _: Fail{"Invalid exact retained-image request"}

def resolved(value: Result<&2,&2,Inventory.Failure,Inline.Resolved>) -> Result<&2,&2,String,String>:
  match value:
    case Fail{Inventory.Failure{_,message}}: Fail{message}
    case Done{value}: Packet.encode(value)

def execute(db: U32,request: Result<&2,&2,String,Inline.Request>) -> IO(Result<&2,&2,String,String>):
  match request:
    case Fail{message}: IO.pure(Result<&2,&2,String,String>,Fail{message})
    case Done{request}:
      do IO<Result<&2,&2,String,String>>:
        value : Result<&2,&2,Inventory.Failure,Inline.Resolved> <- Inline.resolve(db,request)
        return resolved(value)

def emit(value: Result<&2,&2,String,String>) -> IO(Unit):
  match value:
    case Fail{message}: IO.die(Unit,2,message)
    case Done{text}: IO.print(text)

def run(db: U32,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    value : Result<&2,&2,String,String> <- execute(db,parse(args))
    emit(value)

def arguments(dir: String,value: Packet.Expected) -> List<String>:
  Packet.Expected{_,snapshot,Attachments.OccurrenceKey{record,reference,path,_,_,_,_,_,_}} = value
  ["--data-dir",dir,command(),snapshot,U32.show(record),U32.show(reference),path]

def output_ok(valid: Bool,expected: Packet.Expected,out: String) -> Result<&2,&2,String,Decode.Bytes>:
  match valid:
    case False{}: Fail{"The retained-byte reader failed. The capture and reader selection are unchanged."}
    case True{}: Packet.verify(expected,out)

def completed(expected: Packet.Expected,result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Result<&2,&2,String,Decode.Bytes>:
  match result:
    case Fail{_}: Fail{"The retained-byte reader could not complete within its process limits."}
    case Done{(code,(out,error))}: output_ok(U32.is_eq(code,0) && String.is_empty(error),expected,out)

def read(program: String,dir: String,+expected: Packet.Expected) -> IO(Result<&2,&2,String,Decode.Bytes>):
  do IO<Result<&2,&2,String,Decode.Bytes>>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(program,arguments(dir,expected),"",2162688,60000)
    return completed(expected,result)

# Existing-only SQLite open avoids startup schema creation/migration. SQLITE
# READONLY does not grant attachment-file reads; normal WAL bookkeeping remains
# SQLite behavior. A missing selected library is never silently initialized.
def closed(result: Result<&1,&1,U32 & String,Unit>,prior: Result<&2,&2,String,String>) -> Result<&2,&2,String,String>:
  match result:
    case Done{_}: prior
    case Fail{_}: Fail{"The retained-image database did not close cleanly"}

def opened(result: Result<&1,&1,U32 & String,U32>,request: Inline.Request) -> IO(Unit):
  match result:
    case Fail{_}: IO.die(Unit,2,"Cannot open the existing selected retained-image library")
    case Done{+db}:
      do IO<Unit>:
        value : Result<&2,&2,String,String> <- execute(db,Done{request})
        result : Result<&1,&1,U32 & String,Unit> <- Sql.close(db)
        emit(closed(result,value))

def root_valid(valid: Bool,dir: String,request: Result<&2,&2,String,Inline.Request>) -> IO(Unit):
  match valid request:
    case True{} Done{request}:
      do IO<Unit>:
        result : Result<&1,&1,U32 & String,U32> <- Sql.open_existing(dir ++ "/juice-bend.sqlite",0)
        opened(result,request)
    case _ _: IO.die(Unit,2,"Invalid explicit retained-image library or occurrence request")

def root(+dir: String,args: List<String>) -> IO(Unit):
  root_valid(String.starts_with(dir,"/") && Ref.bounded(dir,4000),dir,parse(args))

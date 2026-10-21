import Base
import ../src/quota_entry.bend as E
import ../src/quota_paths.bend as P
import ../src/quota_cli.bend as C
import ../src/quota_store.bend as S
import ../src/claude_quota.bend as Q
import ../src/domain.bend as D
import ../src/sql.bend as Sql

def assert(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def need(-A: Data,value: Result<&2,&2,Q.Failure,A>) -> IO(A):
  match value:
    case Done{value}: IO.pure(A,value)
    case Fail{Q.Failure{code,message}}: IO.die(A,1,code ++ ": " ++ message)

def command_result(value: P.Reply) -> IO(Unit):
  match value:
    case P.Reply{0,_,""}: IO.pure(Unit,Unit{})
    case _: IO.die(Unit,1,"fixture command failed")

def command(program: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,Q.Failure,P.Reply> <- P.command(program,args)
    value : P.Reply <- need(P.Reply,result)
    command_result(value)

def root_output(value: P.Reply) -> IO(String):
  match value:
    case P.Reply{0,out,""}: need(String,P.line(String.split(out,'\n')))
    case _: IO.die(String,1,"fixture mktemp failed")

def canonical(root: P.Root) -> String:
  P.Root{_,_,path,_} = root
  path

def root() -> IO(String):
  do IO<String>:
    result : Result<&2,&2,Q.Failure,P.Reply> <- P.command("/usr/bin/mktemp",["-d","/tmp/juice-bend-quota-entry.XXXXXX"])
    value : P.Reply <- need(P.Reply,result)
    path : String <- root_output(value)
    checked : Result<&2,&2,Q.Failure,P.Root> <- P.inspect_root(path)
    value : P.Root <- need(P.Root,checked)
    return canonical(value)

def inspect(root: String) -> IO(P.Root):
  do IO<P.Root>:
    value : Result<&2,&2,Q.Failure,P.Root> <- P.inspect_root(root)
    need(P.Root,value)

def failure(value: S.answer_type(),wanted: String,label: String) -> IO(Unit):
  match value:
    case Fail{Q.Failure{actual,_}}: assert(String.eq(actual,wanted),label)
    case Done{_}: assert(False{},label)

def rejected(value: S.answer_type(),label: String) -> IO(Unit):
  match value:
    case Fail{_}: assert(True{},label)
    case Done{_}: assert(False{},label)

def answer(value: S.answer_type(),epoch: Nat,on: Bool,outcome: String,count: Nat,label: String) -> IO(Unit):
  match value:
    case Fail{Q.Failure{code,_}}: IO.die(Unit,1,"FAIL " ++ label ++ ": " ++ code)
    case Done{S.View{S.State{actual,enabled},samples,more,word}}:
      assert(Nat.is_eq(actual,epoch) && U32.is_eq(Bool.to_u32(on),Bool.to_u32(enabled)) &&
        String.eq(word,outcome) && Nat.is_eq(List.length(&2,S.Sample,samples),count) && Bool.not(more),label)

def file_absent(value: Maybe<&2,P.Metadata>,label: String) -> IO(Unit):
  match value:
    case None{}: assert(True{},label)
    case Some{_}: assert(False{},label)

def absent(+root: P.Root,label: String) -> IO(Unit):
  do IO<Unit>:
    value : Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>> <- P.inspect_file(root,P.main(root))
    m : Maybe<&2,P.Metadata> <- need(Maybe<&2,P.Metadata>,value)
    file_absent(m,label)

def exec(db: U32,statement: String) -> IO(Unit):
  do IO<Unit>:
    rows : S.rows_type() <- IO.try(S.rows_type(),Sql.query(db,statement,[],0))
    return Unit{}

def bytes_eof(tail: List<&2,U32>,bytes: List<&2,U32>) -> IO(List<&2,U32>):
  match tail:
    case []: IO.pure(List<&2,U32>,bytes)
    case _: IO.die(List<&2,U32>,1,"fixture byte comparison requires exact EOF")

def bytes_end(value: File & Result<&1,&1,U32 & String,List<&2,U32>>,bytes: List<&2,U32>) -> IO(List<&2,U32>):
  (file,result) = value
  do IO<List<&2,U32>>:
    File.close(file)
    tail : List<&2,U32> <- IO.try(List<&2,U32>,IO.pure(Result<&1,&1,U32 & String,List<&2,U32>>,result))
    bytes_eof(tail,bytes)

def bytes_sized(fits: Bool,file: File,bytes: List<&2,U32>) -> IO(List<&2,U32>):
  match fits:
    case False{}:
      do IO<List<&2,U32>>:
        File.close(file)
        IO.die(List<&2,U32>,1,"fixture byte comparison exceeds its 64KiB bound")
    case True{}:
      do IO<List<&2,U32>>:
        ending : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,1)
        bytes_end(ending,bytes)

def bytes_read(value: File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(List<&2,U32>):
  (file,result) = value
  match result:
    case Fail{_}:
      do IO<List<&2,U32>>:
        File.close(file)
        IO.die(List<&2,U32>,1,"fixture bytes could not be read")
    case Done{+bytes}: bytes_sized(Nat.is_le(List.length(&2,U32,bytes),65536n),file,bytes)

def file_bytes(path: String) -> IO(List<&2,U32>):
  do IO<List<&2,U32>>:
    file : File <- IO.try(File,File.open(path,"r"))
    value : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,65537)
    bytes_read(value)

def digest(path: String) -> IO(String):
  do IO<String>:
    bytes : List<&2,U32> <- file_bytes(path)
    return D.digest(bytes)

def bytes_written(value: File & Result<&1,&1,U32 & String,Unit>) -> IO(Unit):
  (file,result) = value
  do IO<Unit>:
    File.close(file)
    IO.try(Unit,IO.pure(Result<&1,&1,U32 & String,Unit>,result))

def write_bytes(path: String,bytes: List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    value : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    bytes_written(value)

def empty(path: String) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    File.close(file)


def no_create() -> IO(Unit):
  do IO<Unit>:
    +path : String <- root()
    +checked : P.Root <- inspect(path)
    result : S.answer_type() <- E.dispatch(path,C.Status{},"")
    answer(result,0n,False{},"status",0n,"missing status is explicitly off")
    result : S.answer_type() <- E.dispatch(path,C.History{0},"")
    answer(result,0n,False{},"history",0n,"missing history is empty without creating storage")
    result : S.answer_type() <- E.dispatch(path,C.Disconnect{},"")
    answer(result,0n,False{},"disconnected",0n,"disconnect of absent storage is off")
    result : S.answer_type() <- E.dispatch(path,C.Observe{1n,False{}},"{}")
    failure(result,"quota_epoch_retired","receiver cannot create or enable missing storage")
    absent(checked,"all non-enable commands leave quota database absent")
    result : S.answer_type() <- E.dispatch(path ++ "/missing",C.Enable{},"")
    failure(result,"quota_root","even Enable cannot create a data root")
    result : S.answer_type() <- E.dispatch("relative",C.Enable{},"")
    failure(result,"quota_root","entry requires explicit absolute selected root")

def lifecycle() -> IO(Unit):
  do IO<Unit>:
    +path : String <- root()
    result : S.answer_type() <- E.dispatch(path,C.Enable{},"")
    answer(result,1n,True{},"enabled",0n,"Enable privately provisions and allocates first epoch")
    +checked : P.Root <- inspect(path)
    metadata : Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>> <- E.bundle(checked)
    value : Maybe<&2,P.Metadata> <- need(Maybe<&2,P.Metadata>,metadata)
    assert(Maybe.is_some(&2,P.Metadata,value),"published main is private0600 regular single-link and no unsafe sidecars")
    result : S.answer_type() <- E.dispatch(path,C.Observe{1n,False{}},"{\"session_id\":\"private sentinel\",\"rate_limits\":{\"five_hour\":{\"used_percentage\":0}}}")
    answer(result,1n,True{},"accepted",1n,"safe receiver records known zero with local clock")
    result : S.answer_type() <- E.dispatch(path,C.Status{},"")
    answer(result,1n,True{},"status",1n,"readonly safe status returns recorded observation")
    result : S.answer_type() <- E.dispatch(path,C.Disconnect{},"")
    answer(result,1n,False{},"disconnected",0n,"Disconnect transaction retires current epoch")
    result : S.answer_type() <- E.dispatch(path,C.Observe{1n,False{}},"{\"rate_limits\":{\"five_hour\":{\"used_percentage\":99}}}")
    failure(result,"quota_epoch_retired","delayed callback cannot reactivate private connection")
    result : S.answer_type() <- E.dispatch(path,C.Enable{},"")
    answer(result,2n,True{},"enabled",0n,"re-enable allocates distinct epoch")
    result : S.answer_type() <- E.dispatch(path,C.Observe{1n,False{}},"{}")
    failure(result,"quota_epoch_retired","old callback remains retired after re-enable")
    result : S.answer_type() <- E.dispatch(path,C.Status{},"")
    answer(result,2n,True{},"status",0n,"new epoch starts waiting without copying old window")
    result : S.answer_type() <- E.dispatch(path,C.History{0},"")
    answer(result,2n,True{},"history",1n,"history retains accepted old-epoch observation separately")
    command("/bin/chmod",["644",P.main(checked)])
    result : S.answer_type() <- E.dispatch(path,C.Status{},"")
    failure(result,"quota_file","changed main permissions are refused without repair")
    command("/bin/chmod",["600",P.main(checked)])
    command("/bin/ln",[P.main(checked),path ++ "/extra-hardlink"])
    result : S.answer_type() <- E.dispatch(path,C.Enable{},"")
    failure(result,"quota_file","linked main is refused before any write")

def foreign() -> IO(Unit):
  do IO<Unit>:
    +path : String <- root()
    +checked : P.Root <- inspect(path)
    +db : U32 <- IO.try(U32,Sql.open(P.main(checked)))
    exec(db,"CREATE TABLE unrelated(value TEXT)")
    exec(db,"INSERT INTO unrelated VALUES('synthetic unchanged sentinel')")
    IO.try(Unit,Sql.close(db))
    command("/bin/chmod",["600",P.main(checked)])
    before : String <- digest(P.main(checked))
    result : S.answer_type() <- E.dispatch(path,C.Enable{},"")
    failure(result,"quota_storage_invalid","foreign private database is refused by readonly identity admission")
    after : String <- digest(P.main(checked))
    assert(String.eq(before,after),"foreign database retained bytes are unchanged after refused Enable")

def zeros(count: Nat) -> List<&2,U32>:
  match count:
    case 0n: []
    case 1n+rest: 0 <> zeros(rest)

def header(write_version: U32,read_version: U32) -> List<&2,U32>:
  List.append(&2,U32,[83,81,76,105,116,101,32,102,111,114,109,97,116,32,51,0,16,0,write_version,read_version],zeros(80n))

def header_cases() -> IO(Unit):
  do IO<Unit>:
    assert(E.rollback_header(header(1,1)),"header gate admits exact 100-byte rollback-format prefix")
    assert(Bool.not(E.rollback_header([])),"header gate refuses an existing empty file")
    assert(Bool.not(E.rollback_header(List.take(&2,U32,header(1,1),99n))),"header gate refuses a truncated 99-byte prefix")
    assert(Bool.not(E.rollback_header(List.append(&2,U32,header(1,1),[0]))),"header predicate requires exactly 100 sampled bytes")
    assert(Bool.not(E.rollback_header(0 <> List.drop(&2,U32,header(1,1),1n))),"header gate refuses incorrect SQLite magic")
    assert(Bool.not(E.rollback_header(header(2,1))),"header gate checks write-version byte 18 independently")
    assert(Bool.not(E.rollback_header(header(1,2))),"header gate checks read-version byte 19 independently")
    assert(Bool.not(E.rollback_header(header(2,2))),"header gate refuses persisted WAL format")
    assert(Bool.not(E.rollback_header(header(0,1))),"header gate refuses unknown zero write version")
    assert(Bool.not(E.rollback_header(header(1,3))),"header gate refuses unknown read version")

def sidecar_absent(+root: P.Root,path: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>> <- P.inspect_file(root,path)
    value : Maybe<&2,P.Metadata> <- need(Maybe<&2,P.Metadata>,result)
    file_absent(value,label)

def no_sidecars(+root: P.Root,+label: String) -> IO(Unit):
  +path = P.main(root)
  do IO<Unit>:
    sidecar_absent(root,path ++ "-wal",label ++ ": WAL absent")
    sidecar_absent(root,path ++ "-shm",label ++ ": shared memory absent")
    sidecar_absent(root,path ++ "-journal",label ++ ": rollback journal absent")

def invalid_file(+bytes: List<&2,U32>,+label: String) -> IO(Unit):
  do IO<Unit>:
    +path : String <- root()
    +checked : P.Root <- inspect(path)
    write_bytes(P.main(checked),bytes)
    command("/bin/chmod",["600",P.main(checked)])
    result : S.answer_type() <- E.dispatch(path,C.Status{},"")
    failure(result,"quota_header",label ++ ": status refuses before SQLite admission")
    result : S.answer_type() <- E.dispatch(path,C.Enable{},"")
    failure(result,"quota_header",label ++ ": Enable refuses before SQLite admission")
    after : List<&2,U32> <- file_bytes(P.main(checked))
    assert(D.bytes_equal(bytes,after),label ++ ": complete file bytes unchanged")
    no_sidecars(checked,label)

def wal_mode(rows: S.rows_type()) -> Bool:
  match rows:
    case [[Sql.Cell.Text{"wal"}]]: True{}
    case _: False{}

def malformed_sqlite() -> IO(Unit):
  do IO<Unit>:
    +path : String <- root()
    +checked : P.Root <- inspect(path)
    +before : List<&2,U32> = header(1,1)
    write_bytes(P.main(checked),before)
    command("/bin/chmod",["600",P.main(checked)])
    admitted : E.result_type() <- E.inspect_header(P.main(checked))
    value : Unit <- need(Unit,admitted)
    result : S.answer_type() <- E.dispatch(path,C.Enable{},"")
    rejected(result,"header admission does not replace actual SQLite and quota schema validation")
    after : List<&2,U32> <- file_bytes(P.main(checked))
    assert(D.bytes_equal(before,after),"malformed rollback-format database bytes remain unchanged")
    no_sidecars(checked,"malformed rollback-format database")

def wal_checkpoint(rows: S.rows_type()) -> Bool:
  match rows:
    case [[Sql.Cell.Integer{"0"},Sql.Cell.Integer{"0"},Sql.Cell.Integer{"0"}]]: True{}
    case _: False{}

# SQLite may retain sidecars after close on macOS. Checkpoint a real synthetic
# WAL database, then place its exact closed main bytes at a fresh admission path.
# The source database and its sidecars are preserved; no sidecar is removed.
def foreign_wal() -> IO(Unit):
  do IO<Unit>:
    +path : String <- root()
    +checked : P.Root <- inspect(path)
    +source : String = path ++ "/closed-wal-source.sqlite3"
    +db : U32 <- IO.try(U32,Sql.open(source))
    rows : S.rows_type() <- IO.try(S.rows_type(),Sql.query(db,"PRAGMA main.journal_mode=WAL",[],1))
    assert(wal_mode(rows),"foreign fixture actually entered SQLite WAL mode")
    exec(db,"CREATE TABLE unrelated(value TEXT)")
    exec(db,"INSERT INTO unrelated VALUES('synthetic closed WAL sentinel')")
    rows : S.rows_type() <- IO.try(S.rows_type(),Sql.query(db,"PRAGMA main.wal_checkpoint(TRUNCATE)",[],1))
    assert(wal_checkpoint(rows),"foreign WAL source checkpoint completed with no remaining frames")
    IO.try(Unit,Sql.close(db))
    command("/bin/chmod",["600",source])
    absent(checked,"standalone WAL admission destination is initially absent")
    +source_bytes : List<&2,U32> <- file_bytes(source)
    write_bytes(P.main(checked),source_bytes)
    command("/bin/chmod",["600",P.main(checked)])
    no_sidecars(checked,"closed WAL fixture before admission")
    +before : List<&2,U32> <- file_bytes(P.main(checked))
    assert(D.bytes_equal(source_bytes,before),"standalone WAL file preserves all checkpointed source bytes")
    assert(D.bytes_equal(List.take(&2,U32,List.drop(&2,U32,before,18n),2n),[2,2]),
      "closed foreign file retains actual WAL header bytes")
    result : S.answer_type() <- E.dispatch(path,C.Status{},"")
    failure(result,"quota_header","closed WAL status refuses before any SQLite open")
    no_sidecars(checked,"standalone WAL after refused status")
    result : S.answer_type() <- E.dispatch(path,C.Enable{},"")
    failure(result,"quota_header","closed WAL Enable refuses before readonly/write admission")
    no_sidecars(checked,"standalone WAL after refused Enable")
    result : S.answer_type() <- E.dispatch(path,C.Observe{1n,False{}},"{}")
    failure(result,"quota_header","closed WAL callback refuses before readonly/write admission")
    after : List<&2,U32> <- file_bytes(P.main(checked))
    assert(D.bytes_equal(before,after),"closed foreign WAL file retains all exact bytes after refusals")
    no_sidecars(checked,"standalone WAL after refused callback")
    source_after : List<&2,U32> <- file_bytes(source)
    assert(D.bytes_equal(source_bytes,source_after),"original checkpointed WAL source bytes remain unchanged")

def header_files() -> IO(Unit):
  do IO<Unit>:
    invalid_file([],"existing empty file")
    invalid_file(List.take(&2,U32,header(1,1),99n),"truncated header file")
    invalid_file(0 <> List.drop(&2,U32,header(1,1),1n),"invalid SQLite magic file")
    invalid_file(header(2,1),"mixed WAL write-version file")
    invalid_file(header(1,2),"mixed WAL read-version file")
    invalid_file(header(0,1),"unknown rollback-version file")
    malformed_sqlite()
    foreign_wal()

def sidecars() -> IO(Unit):
  do IO<Unit>:
    +path : String <- root()
    +checked : P.Root <- inspect(path)
    +sidecar : String = P.main(checked) ++ "-journal"
    empty(sidecar)
    command("/bin/chmod",["600",sidecar])
    result : S.answer_type() <- E.dispatch(path,C.Enable{},"")
    failure(result,"quota_orphan","orphan sidecar refuses creation without removal")
    absent(checked,"orphan refusal leaves main absent")
    command("/bin/rm",["--",sidecar])
    result : S.answer_type() <- E.dispatch(path,C.Enable{},"")
    answer(result,1n,True{},"enabled",0n,"explicit Enable works after fixture removes its own orphan")
    command("/bin/ln",["-s",path ++ "/missing-target",sidecar])
    result : S.answer_type() <- E.dispatch(path,C.Status{},"")
    failure(result,"quota_file","dangling sidecar symlink is refused before SQLite opens")
    command("/bin/rm",["--",sidecar])
    empty(sidecar)
    command("/bin/chmod",["644",sidecar])
    result : S.answer_type() <- E.dispatch(path,C.Observe{1n,False{}},"{}")
    failure(result,"quota_file","unsafe sidecar refuses receiver without permissions repair")

def publication() -> IO(Unit):
  do IO<Unit>:
    +path : String <- root()
    result : S.answer_type() <- E.dispatch(path,C.Enable{},"")
    answer(result,1n,True{},"enabled",0n,"publication collision fixture owns an enabled original")
    +checked : P.Root <- inspect(path)
    +temp : String = path ++ "/owned-temp"
    empty(temp)
    command("/bin/chmod",["600",temp])
    metadata : Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>> <- P.inspect_file(checked,temp)
    value : Maybe<&2,P.Metadata> <- need(Maybe<&2,P.Metadata>,metadata)
    owned : E.Temp <- need(E.Temp,E.temp_metadata(value,temp))
    +before : String <- digest(P.main(checked))
    result : S.answer_type() <- E.publish(checked,owned)
    failure(result,"quota_exists","publication collision never replaces existing main")
    after : String <- digest(P.main(checked))
    assert(String.eq(before,after),"publication collision preserves exact existing database bytes")
    result : Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>> <- P.inspect_file(checked,temp)
    value : Maybe<&2,P.Metadata> <- need(Maybe<&2,P.Metadata>,result)
    file_absent(value,"publication collision removes only its verified owned temp")

def child_result(value: U32 & (String & String),code: U32,wanted: String,label: String) -> IO(Unit):
  (actual,(out,err)) = value
  assert(U32.is_eq(actual,code) && String.contains(out ++ err,wanted),label)

def child(self: String,root: String,operation: String,args: List<String>,body: String,code: U32,wanted: String,label: String) -> IO(Unit):
  do IO<Unit>:
    value : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,List.append(&1,String,["--data-dir",root,"quota",operation],args),body,65536,15000))
    child_result(value,code,wanted,label)

def refused_prefix(self: String,args: List<String>,label: String) -> IO(Unit):
  do IO<Unit>:
    value : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,args,"",65536,15000))
    child_result(value,2,"quota_usage",label)

def transport(+self: String) -> IO(Unit):
  do IO<Unit>:
    +path : String <- root()
    child(self,path,"status",[],"",0,"\"enabled\":false","actual CLI missing status returns closed off response")
    child(self,path,"enable",[],"",0,"\"epoch\":\"1\"","actual CLI Enable returns allocated epoch")
    child(self,path,"observe-claude",["1"],"{\"rate_limits\":{\"seven_day\":{\"used_percentage\":12.5}}}",0,"12500000","actual bounded stdin receiver returns allowlisted numeric payload")
    child(self,path,"statusline-claude",["1"],"{}",0,"Juice Bend quota: waiting for limits","actual statusline mode produces static waiting footer")
    child(self,path,"disconnect",[],"",0,"\"enabled\":false","actual CLI disconnect returns retired state")
    child(self,path,"observe-claude",["1"],"{}",2,"quota_epoch_retired","actual delayed CLI callback emits closed failure and nonzero exit")
    child(self,path,"statusline-claude",["1"],"{}",0,"Juice Bend quota: unavailable","actual delayed footer remains static unavailable")
    child(self,path,"enable",["extra"],"",2,"quota_usage","unexpected transport args are refused before storage")
    refused_prefix(self,["quota","status"],"public transport refuses absent explicit data-root flag")
    refused_prefix(self,["--data-dir",path,"status"],"public transport refuses missing quota namespace")
    refused_prefix(self,["--data-dir",path,"quota"],"public transport refuses missing operation")
    child(self,path ++ "/missing-root","status",[],"",2,"quota_root","exact public transport cannot create a missing root")

def suite(self: String) -> IO(Unit):
  do IO<Unit>:
    header_cases()
    no_create()
    lifecycle()
    foreign()
    header_files()
    sidecars()
    publication()
    transport(self)

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case [self]: suite(self)
    case _ <> rest: E.argv(rest)
    case _: IO.die(Unit,2,"fixture arguments invalid")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)

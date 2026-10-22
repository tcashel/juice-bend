import Base
import ../src/attachment_assets.bend as A
import ../src/attachment_asset_types.bend as T
import ../src/attachment_asset_identity.bend as Identity
import ../src/attachment_asset_schema.bend as Schema
import ../src/attachment_worker_protocol.bend as Worker
import ../src/attachment_inventory.bend as Inventory
import ../src/archive_meta.bend as Meta
import ../src/archive_maintenance.bend as ArchiveMaintenance
import ../src/capture.bend as Capture
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as D
import ../src/paths.bend as Paths
import ./attachment_asset_identity.bend as Fixture

def failed(result: T.answer(),expected: String) -> Bool:
  match result:
    case Fail{Inventory.Failure{code,_}}: String.eq(code,expected)
    case _: False{}

def initialized(value: T.answer()) -> Bool:
  match value:
    case Done{T.Initialized{}}: True{}
    case _: False{}

def receipt(value: T.answer(),retry: Bool) -> IO(T.Receipt):
  match value:
    case Done{T.Published{receipt,actual}}:
      do IO<T.Receipt>:
        Fixture.assert(U32.is_eq(Bool.to_u32(retry),Bool.to_u32(actual)),"publication retry state matches independent expectation")
        return receipt
    case Fail{Inventory.Failure{code,_}}: IO.die(T.Receipt,1,"Unexpected publication refusal: " ++ code)
    case _: IO.die(T.Receipt,1,"Unexpected publication outcome")

def root() -> T.RootEvidence: T.RootEvidence{"1","/synthetic/authorized","7",True{}}

def policy_row(rows: List<&2,List<&2,Sql.Cell>>) -> Bool:
  match rows:
    case [[Sql.Cell.Text{id},Sql.Cell.Text{path},Sql.Cell.Text{revision},Sql.Cell.Integer{enabled}]]:
      String.eq(id,"1") && String.eq(path,"/synthetic/authorized") && String.eq(revision,"7") && String.eq(enabled,"1")
    case _: False{}

def policy_evidence(evidence: T.RootEvidence) -> Bool:
  T.RootEvidence{id,path,revision,enabled} = evidence
  String.eq(id,"1") && String.eq(path,"/synthetic/authorized") && String.eq(revision,"7") && enabled

def policy_rows(rows: List<&2,List<&2,Sql.Cell>>,evidence: T.RootEvidence) -> T.unit_result():
  Bool.pick(T.unit_result(),policy_row(rows) && policy_evidence(evidence),Done{Unit{}},
    Fail{T.failure("test_root_policy_refused","Current root identity, path, revision or enabled state differs")})

# Test policy uses the SAME supplied handle and current transaction. This is
# never production's authority; its table is unique to this synthetic fixture.
def validate(db: U32,evidence: T.RootEvidence) -> IO(T.unit_result()):
  do IO<T.unit_result()>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT id,path,revision,enabled FROM test_root_policy",[],2)
    return policy_rows(rows,evidence)

def payload(+bytes: List<&2,U32>) -> Worker.Payload:
  Worker.Payload{U32.from_nat(List.length(&2,U32,bytes)),D.digest(bytes),bytes}

def admission(occurrence: Identity.Resolved,bytes: List<&2,U32>) -> T.Admission:
  T.Admission{occurrence,root(),"1792540800123",payload(bytes)}

def publish(+db: U32,occurrence: Identity.Resolved,bytes: List<&2,U32>,retry: Bool) -> IO(T.Receipt):
  do IO<T.Receipt>:
    value : T.answer() <- A.publish(db,admission(occurrence,bytes),d => evidence => validate(d,evidence))
    receipt(value,retry)

def loaded(value: T.answer(),wanted: T.Receipt,expected: List<&2,U32>) -> Bool:
  match value:
    case Done{T.Loaded{+owned}}:
      T.Owned{actual,chunks} = owned
      T.owned_valid(owned) && T.same(actual,wanted) && D.bytes_equal(A.bytes(chunks),expected)
    case _: False{}

def count_text(value: List<&2,List<&2,Sql.Cell>>) -> String:
  match value:
    case [[Sql.Cell.Integer{a},Sql.Cell.Integer{b},Sql.Cell.Integer{c},Sql.Cell.Integer{d},Sql.Cell.Integer{e},Sql.Cell.Integer{f},Sql.Cell.Integer{g}]]:
      a ++ ":" ++ b ++ ":" ++ c ++ ":" ++ d ++ ":" ++ e ++ ":" ++ f ++ ":" ++ g
    case _: "invalid"

def counts(+db: U32) -> IO(String):
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT (SELECT count(*) FROM attachment_asset_meta),(SELECT count(*) FROM attachment_assets),(SELECT count(*) FROM attachment_asset_chunks),(SELECT coalesce(sum(n),0) FROM attachment_asset_chunks),(SELECT count(*) FROM snapshots),(SELECT count(*) FROM raw),(SELECT count(*) FROM records)",[],1)
    return count_text(rows)

def cell(value: Sql.Cell) -> String:
  match value:
    case Sql.Cell.Null{}: "null"
    case Sql.Cell.Integer{text}: "integer:" ++ text
    case Sql.Cell.Text{text}: "text:" ++ text
    case Sql.Cell.Blob{+bytes}: "blob:" ++ U32.show(U32.from_nat(List.length(&2,U32,bytes))) ++ ":" ++ D.digest(bytes)
    case Sql.Cell.Real{text}: "real:" ++ text

def row_fields(values: List<&2,Sql.Cell>) -> List<&2,String>:
  match values:
    case []: []
    case first <> rest: cell(first) <> row_fields(rest)

def row_seals(values: List<&2,List<&2,Sql.Cell>>) -> List<&2,String>:
  match values:
    case []: []
    case row <> rest: T.frames(row_fields(row)) <> row_seals(rest)

def state(+db: U32) -> IO(String):
  do IO<String>:
    meta : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT * FROM attachment_asset_meta ORDER BY id",[],2)
    assets : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT * FROM attachment_assets ORDER BY snapshot,record,reference",[],20)
    chunks : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT * FROM attachment_asset_chunks ORDER BY snapshot,record,reference,ordinal",[],50)
    return T.frames(List.append(&2,String,row_seals(meta),List.append(&2,String,row_seals(assets),row_seals(chunks))))

def unchanged(+db: U32,wanted: String,label: String) -> IO(Unit):
  do IO<Unit>:
    actual : String <- state(db)
    Fixture.assert(String.eq(actual,wanted),label)

def generate(fuel: Nat,+index: U32) -> List<&2,U32>:
  match fuel:
    case 0n: []
    case 1n+rest: U32.and(index,255) <> generate(rest,U32.inc(index))

def selected_phase(phase: T.Phase,index: U32) -> Bool:
  match phase index:
    case T.AssociationInserted{} 0: True{}
    case T.ChunkInserted{0} 1: True{}
    case T.BeforeCommit{} 2: True{}
    case _ _: False{}

def step_phase(fail_now: Bool,next: T.Observer) -> IO(Result<&2,&1,Inventory.Failure,T.Observer>):
  match fail_now:
    case True{}: IO.pure(Result<&2,&1,Inventory.Failure,T.Observer>,Fail{T.failure("test_interruption","deliberate synthetic transaction seam")})
    case False{}: IO.pure(Result<&2,&1,Inventory.Failure,T.Observer>,Done{next})

def observer(fuel: Nat,+index: U32) -> T.Observer:
  match fuel:
    case 0n: T.Inert{}
    case 1n+left: T.Observed{phase => step_phase(selected_phase(phase,index),observer(left,index))}

def interruption(fuel: Nat,+index: U32,+db: U32,+occurrence: Identity.Resolved,+before: String) -> IO(Unit):
  match fuel:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        result : T.answer() <- A.publish_observed(db,admission(occurrence,[7,0,255]),d => evidence => validate(d,evidence),observer(4n,index))
        Fixture.assert(failed(result,"test_interruption"),"test observer refusal reaches requested publication phase " ++ U32.show(index))
        unchanged(db,before,"observer refusal rolls back all owned asset tables exactly")
        interruption(rest,U32.inc(index),db,occurrence,before)

def stale_raw(value: Identity.Resolved) -> Identity.Resolved:
  Identity.Resolved{capture,record,offset,length,_,reference,path,kind,local} = value
  Identity.Resolved{capture,record,offset,length,"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",reference,path,kind,local}

def publication_refusals(+db: U32,+occurrence: Identity.Resolved) -> IO(Unit):
  do IO<Unit>:
    +before : String <- state(db)
    wrong : T.answer() <- A.publish(db,admission(stale_raw(occurrence),[1]),d => r => validate(d,r))
    Fixture.assert(failed(wrong,"attachment_asset_occurrence_changed"),"stale supplied raw digest cannot publish even valid worker bytes")
    Store.exec(db,"UPDATE test_root_policy SET revision='8'",[])
    revision : T.answer() <- A.publish(db,admission(occurrence,[1]),d => r => validate(d,r))
    Fixture.assert(failed(revision,"test_root_policy_refused"),"revision changed after bytes were observed refuses publication")
    Store.exec(db,"UPDATE test_root_policy SET revision='7',enabled=0",[])
    disabled : T.answer() <- A.publish(db,admission(occurrence,[1]),d => r => validate(d,r))
    Fixture.assert(failed(disabled,"test_root_policy_refused"),"revoked root refuses publication on the current owned transaction")
    unchanged(db,before,"authorization refusals leave every owned asset table exact")
    Store.exec(db,"UPDATE test_root_policy SET enabled=1",[])
    interruption(3n,0,db,occurrence,before)
    Store.exec(db,"BEGIN IMMEDIATE",[])
    busy : T.answer() <- A.publish(db,admission(occurrence,[1]),d => r => validate(d,r))
    Fixture.assert(failed(busy,"attachment_asset_transaction_unavailable"),"public publication refuses to borrow caller transaction")
    Store.exec(db,"INSERT INTO test_root_policy(id,path,revision,enabled) VALUES('caller','/caller','1',1)",[])
    Store.exec(db,"ROLLBACK",[])
    unchanged(db,before,"failed BEGIN leaves caller transaction usable and never rolls it back")

def read_failed(+db: U32,+request: Identity.Request,label: String) -> IO(Unit):
  do IO<Unit>:
    result : T.answer() <- A.read(db,request)
    Fixture.assert(failed(result,"attachment_asset_invalid"),label)

def corruptions(+db: U32,+occurrence: Identity.Resolved,+receipt: T.Receipt) -> IO(Unit):
  +request : Identity.Request = Identity.request(occurrence)
  do IO<Unit>:
    +before : String <- state(db)
    Store.exec(db,"UPDATE attachment_asset_chunks SET bytes=x'0001FE00' WHERE snapshot=1 AND record=0 AND reference=0",[])
    read_failed(db,request,"changed binary byte is refused by per-chunk and whole integrity")
    Store.exec(db,"UPDATE attachment_asset_chunks SET bytes=x'0001FEFF' WHERE snapshot=1 AND record=0 AND reference=0",[])
    Store.exec(db,"PRAGMA ignore_check_constraints=ON",[])
    Store.exec(db,"UPDATE attachment_asset_chunks SET offset=zeroblob(1048576) WHERE snapshot=1 AND record=0 AND reference=0",[])
    read_failed(db,request,"wrong-type oversized numeric cell is not transferred by metadata preflight")
    Store.exec(db,"UPDATE attachment_asset_chunks SET offset=0 WHERE snapshot=1 AND record=0 AND reference=0",[])
    Store.exec(db,"PRAGMA ignore_check_constraints=OFF",[])
    Store.exec(db,"INSERT INTO attachment_asset_chunks(snapshot,record,reference,ordinal,offset,n,sha256,bytes) VALUES(1,0,0,1,4,1,?,x'00')",[Sql.Cell.Text{D.digest([0])}])
    read_failed(db,request,"extra chunk cannot extend an immutable accepted byte extent")
    Store.exec(db,"DELETE FROM attachment_asset_chunks WHERE snapshot=1 AND record=0 AND reference=0 AND ordinal=1",[])
    Store.exec(db,"DELETE FROM attachment_asset_chunks WHERE snapshot=1 AND record=0 AND reference=0 AND ordinal=0",[])
    read_failed(db,request,"missing chunk cannot turn accepted binary bytes into an empty asset")
    Store.exec(db,"INSERT INTO attachment_asset_chunks(snapshot,record,reference,ordinal,offset,n,sha256,bytes) VALUES(1,0,0,0,0,4,?,x'0001FEFF')",[Sql.Cell.Text{"c5dbae22661af6db18a1f676db82a7ef7de46d27c3a263a872f00478b0d99fc4"}])
    Store.exec(db,"UPDATE attachment_asset_chunks SET bytes=zeroblob(1048576) WHERE snapshot=1 AND record=0 AND reference=0",[])
    read_failed(db,request,"oversized corrupt BLOB fails metadata admission before allocation")
    Store.exec(db,"UPDATE attachment_asset_chunks SET bytes=x'0001FEFF' WHERE snapshot=1 AND record=0 AND reference=0",[])
    Store.exec(db,"UPDATE attachment_asset_chunks SET bytes='fake' WHERE snapshot=1 AND record=0 AND reference=0",[])
    read_failed(db,request,"TEXT cannot impersonate byte storage")
    Store.exec(db,"UPDATE attachment_asset_chunks SET bytes=x'0001FEFF' WHERE snapshot=1 AND record=0 AND reference=0",[])
    Store.exec(db,"UPDATE attachment_assets SET observed_at_ms='1792540800124' WHERE snapshot=1 AND record=0 AND reference=0",[])
    read_failed(db,request,"metadata observation time is bound by the receipt commitment")
    Store.exec(db,"UPDATE attachment_assets SET observed_at_ms='1792540800123' WHERE snapshot=1 AND record=0 AND reference=0",[])
    Store.exec(db,"UPDATE attachment_assets SET identity='forged' WHERE snapshot=1 AND record=0 AND reference=0",[])
    read_failed(db,request,"stored retained identity must match freshly verified raw occurrence")
    Store.exec(db,"UPDATE attachment_assets SET identity=? WHERE snapshot=1 AND record=0 AND reference=0",[Sql.Cell.Text{T.identity_text(occurrence)}])
    unchanged(db,before,"synthetic corruption restoration recovers exact prior owned tables")
    valid : T.answer() <- A.read(db,request)
    Fixture.assert(loaded(valid,receipt,[0,1,254,255]),"restored storage verifies exact binary bytes again")
    Store.exec(db,"CREATE TRIGGER attachment_asset_probe AFTER INSERT ON attachment_assets BEGIN SELECT 1; END",[])
    trigger : T.answer() <- A.read(db,request)
    Fixture.assert(failed(trigger,"attachment_asset_schema_invalid"),"unexpected owned-table trigger is incompatible shape")
    Store.exec(db,"DROP TRIGGER attachment_asset_probe",[])
    Store.exec(db,"UPDATE attachment_asset_meta SET profile='foreign'",[])
    foreign : T.answer() <- A.initialize(db)
    Fixture.assert(failed(foreign,"attachment_asset_schema_invalid"),"initialize refuses to bless incompatible identity metadata")
    Store.exec(db,"UPDATE attachment_asset_meta SET profile='external-attachment-bytes-v1'",[])
    unchanged(db,before,"schema refusal does not repair or overwrite accepted data")

def exit_phase(phase: T.Phase,next: T.Observer) -> IO(Result<&2,&1,Inventory.Failure,T.Observer>):
  match phase:
    case T.BeforeCommit{}: IO.die(Result<&2,&1,Inventory.Failure,T.Observer>,77,"owned test process exited before COMMIT")
    case _: IO.pure(Result<&2,&1,Inventory.Failure,T.Observer>,Done{next})

def exit_observer(fuel: Nat) -> T.Observer:
  match fuel:
    case 0n: T.Inert{}
    case 1n+left: T.Observed{phase => exit_phase(phase,exit_observer(left))}

def child_result(result: U32 & (String & String),expected: U32,needle: String,label: String) -> IO(Unit):
  (code,(out,err)) = result
  Fixture.assert(U32.is_eq(code,expected) && String.contains(out ++ err,needle),label)

def child(+self: String,+directory: String,mode: String,snapshot: String,record: String,reference: String,path: String,destination: String,exit: U32,needle: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,[mode,directory,snapshot,record,reference,path,destination],"",16384,30000))
    child_result(result,exit,needle,label)

def read_file(path: String) -> IO(List<&2,U32>):
  do IO<List<&2,U32>>:
    file : File <- IO.try(File,File.open(path,"r"))
    value : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,1048577)
    Fixture.read_closed(value)

def output_modes(system: String,+directory: String) -> IO(Unit):
  match system:
    case "Linux\n":
      do IO<Unit>:
        binary : String <- Fixture.command("/usr/bin/stat",["-c","%a",directory ++ "/binary.out"])
        empty : String <- Fixture.command("/usr/bin/stat",["-c","%a",directory ++ "/empty.out"])
        Fixture.assert(String.eq(binary,"600\n") && String.eq(empty,"600\n"),"both exported files retain private0600 permissions")
    case "Darwin\n":
      do IO<Unit>:
        binary : String <- Fixture.command("/usr/bin/stat",["-f","%Lp",directory ++ "/binary.out"])
        empty : String <- Fixture.command("/usr/bin/stat",["-f","%Lp",directory ++ "/empty.out"])
        Fixture.assert(String.eq(binary,"600\n") && String.eq(empty,"600\n"),"both exported files retain private0600 permissions")
    case _: IO.die(Unit,1,"Unrecognized native test host")

def outputs(+directory: String) -> IO(Unit):
  do IO<Unit>:
    system : String <- Fixture.command("/usr/bin/uname",["-s"])
    output_modes(system,directory)
    temporary : String <- Fixture.command("/usr/bin/find",[directory,"-name","*.out.tmp.*","-print"])
    Fixture.assert(String.eq(temporary,""),"successful and no-clobber exports leave no private temporary files")

def schema_cases(+directory: String) -> IO(Unit):
  do IO<Unit>:
    +partial : U32 <- Store.open(directory ++ "/partial.sqlite")
    Store.exec(partial,"CREATE TABLE attachment_assets(foreign_value TEXT)",[])
    result : T.answer() <- A.initialize(partial)
    Fixture.assert(failed(result,"attachment_asset_schema_invalid"),"partial or foreign owned namespace is refused rather than repaired")
    partial_rows : List<&2,List<&2,Sql.Cell>> <- Store.q(partial,"SELECT count(*) FROM sqlite_master WHERE name LIKE 'attachment_asset%'",[],1)
    Fixture.assert(String.eq(Store.field(Store.first(partial_rows),0n),"1"),"partial schema failure creates no other owned table")
    IO.try(Unit,Sql.close(partial))
    +version : U32 <- Store.open(directory ++ "/version.sqlite")
    Store.exec(version,"PRAGMA user_version=1",[])
    unsupported : T.answer() <- A.initialize(version)
    Fixture.assert(failed(unsupported,"attachment_asset_schema_invalid"),"unsupported library version is refused without migration")
    unchanged : List<&2,List<&2,Sql.Cell>> <- Store.q(version,"PRAGMA user_version",[],1)
    Fixture.assert(String.eq(Store.field(Store.first(unchanged),0n),"1"),"asset initialization never rewrites library user_version")
    Store.exec(version,"PRAGMA user_version=2",[])
    Store.exec(version,"PRAGMA foreign_keys=OFF",[])
    foreign_keys : T.answer() <- A.initialize(version)
    Fixture.assert(failed(foreign_keys,"attachment_asset_schema_invalid"),"asset writes require the existing foreign key capability")
    IO.try(Unit,Sql.close(version))

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +directory : String <- Fixture.create_root()
    Fixture.guard(directory)
    schema_cases(directory)
    +program : String <- Paths.resolve(self)
    +db : U32 <- Store.open(directory ++ "/library.sqlite")
    uninitialized : T.answer() <- A.read(db,Identity.Request{"1",0,0,Fixture.path(0)})
    Fixture.assert(failed(uninitialized,"attachment_asset_schema_invalid"),"ordinary read never creates missing owned tables")
    init : T.answer() <- A.initialize(db)
    Fixture.assert(initialized(init),"explicit initialization creates exact additive schema")
    again : T.answer() <- A.initialize(db)
    Fixture.assert(initialized(again),"matching owned schema initialization is idempotent")
    Store.exec(db,"CREATE TABLE test_root_policy(id TEXT,path TEXT,revision TEXT,enabled INTEGER)",[])
    Store.exec(db,"INSERT INTO test_root_policy VALUES('1','/synthetic/authorized','7',1)",[])
    Fixture.write_bytes(directory ++ "/capture.jsonl.zst",Fixture.raw_frame(D.encode(Fixture.fixture())))
    +snapshot : String <- Capture.import_file(db,"claude",directory ++ "/capture.jsonl.zst")
    +first : Identity.Resolved <- Fixture.get(db,snapshot,0,0,Fixture.path(0))
    +empty : Identity.Resolved <- Fixture.get(db,snapshot,1,0,Fixture.path(0))
    +many : Identity.Resolved <- Fixture.get(db,snapshot,1,1,Fixture.path(1))
    +last : Identity.Resolved <- Fixture.get(db,snapshot,1,2,"/message/content/2/content/0/source/path")
    Fixture.remove(directory ++ "/capture.jsonl.zst")
    +binary : T.Receipt <- publish(db,first,[0,1,254,255],False{})
    retry : T.Receipt <- publish(db,first,[0,1,254,255],True{})
    Fixture.assert(T.same(binary,retry),"exact retry preserves original observed time root revision and every byte")
    +blank : T.Receipt <- publish(db,empty,[],False{})
    +multi : T.Receipt <- publish(db,many,generate(65537n,0),False{})
    +summary : String <- counts(db)
    Fixture.assert(String.eq(summary,"1:3:3:65541:1:2:2"),"three distinct occurrences own binary empty and two-chunk assets without changing captured raw counts")
    got : T.answer() <- A.read(db,Identity.request(empty))
    Fixture.assert(loaded(got,blank,[]),"zero-length captured bytes are a saved empty asset not missing external bytes")
    large : T.answer() <- A.read(db,Identity.request(many))
    Fixture.assert(loaded(large,multi,generate(65537n,0)),"multichunk bytes retain exact order binary values and final partial length")
    +before : String <- state(db)
    conflict : T.answer() <- A.publish(db,admission(first,[1]),d => r => validate(d,r))
    Fixture.assert(failed(conflict,"attachment_asset_conflict"),"different content cannot overwrite an accepted occurrence association")
    unchanged(db,before,"conflicting capture leaves exact asset metadata and bytes unchanged")
    publication_refusals(db,last)
    child(program,directory,"interrupt",snapshot,"1","2","/message/content/2/content/0/source/path","unused",77,"before COMMIT","owned child exits with uncommitted complete association")
    unchanged(db,before,"fresh connection teardown rolls back child process interruption before commit")
    corruptions(db,first,binary)
    Store.exec(db,"UPDATE test_root_policy SET enabled=0,revision='8',path='/synthetic/replaced'",[])
    revoked_retry : T.answer() <- A.publish(db,admission(first,[0,1,254,255]),d => r => validate(d,r))
    Fixture.assert(failed(revoked_retry,"test_root_policy_refused"),"exact retry still revalidates current authorization inside publication transaction")
    still_owned : T.answer() <- A.read(db,Identity.request(first))
    Fixture.assert(loaded(still_owned,binary,[0,1,254,255]),"disable and revision/path change never revoke already-owned byte preservation")
    IO.try(Unit,Sql.close(db))
    child(program,directory,"export",snapshot,"0","0",Fixture.path(0),"binary.out",0,"EXPORTED","source loss plus disabled root survives new-process verified binary export")
    child(program,directory,"export",snapshot,"1","0",Fixture.path(0),"empty.out",0,"EXPORTED","new-process export preserves accepted empty bytes after disable")
    binary_file : List<&2,U32> <- read_file(directory ++ "/binary.out")
    empty_file : List<&2,U32> <- read_file(directory ++ "/empty.out")
    Fixture.assert(D.bytes_equal(binary_file,[0,1,254,255]) && D.bytes_equal(empty_file,[]),"exported bytes equal independent exact binary and empty fixtures")
    child(program,directory,"export",snapshot,"0","0",Fixture.path(0),"binary.out",1,"already exists","no-clobber refuses existing output without replacing bytes")
    unchanged_file : List<&2,U32> <- read_file(directory ++ "/binary.out")
    Fixture.assert(D.bytes_equal(unchanged_file,[0,1,254,255]),"no-clobber refusal leaves original binary output exact")
    outputs(directory)
    +reopened : U32 <- IO.try(U32,Sql.open_existing(directory ++ "/library.sqlite",0))
    Store.exec(reopened,"PRAGMA foreign_keys=ON",[])
    unchanged(reopened,before,"fresh reopen export and refusal do not mutate any accepted asset table")
    +end : String <- counts(reopened)
    Fixture.assert(String.eq(end,summary),"exports preserve retained capture and asset counts")
    ArchiveMaintenance.verify(reopened,snapshot)
    Fixture.assert(True{},"full retained archive and logical capture integrity survive attachment exports")
    IO.try(Unit,Sql.close(reopened))
    IO.print("Synthetic attachment assets test root: " ++ directory)

def exported(value: T.answer()) -> IO(Unit):
  match value:
    case Done{T.Exported{+receipt,_}}:
      do IO<Unit>:
        Fixture.assert(T.receipt_valid(receipt),"fresh export receipt is fully bound")
        IO.print("EXPORTED")
    case Fail{Inventory.Failure{code,_}}: IO.die(Unit,1,code)
    case _: IO.die(Unit,1,"Unexpected export outcome")

def child_export(+db: U32,request: Identity.Request,path: String) -> IO(Unit):
  do IO<Unit>:
    result : T.answer() <- A.export(db,request,path)
    exported(result)

def child_interrupt(+db: U32,request: Identity.Request) -> IO(Unit):
  do IO<Unit>:
    value : Result<&2,&2,Inventory.Failure,Identity.Resolved> <- Identity.resolve(db,request)
    occurrence : Identity.Resolved <- Fixture.need(Identity.Resolved,value)
    result : T.answer() <- A.publish_observed(db,admission(occurrence,[3,2,1]),d => r => validate(d,r),exit_observer(4n))
    IO.die(Unit,1,"Interruption observer was not reached")

def child_mode(mode: String,db: U32,request: Identity.Request,path: String) -> IO(Unit):
  match mode:
    case "export": child_export(db,request,path)
    case "interrupt": child_interrupt(db,request)
    case _: IO.die(Unit,2,"Invalid owned test mode")

def child_run(mode: String,+directory: String,snapshot: String,record: String,reference: String,path: String,+destination: String) -> IO(Unit):
  do IO<Unit>:
    Fixture.guard(directory)
    Fixture.assert(String.eq(destination,"binary.out") || String.eq(destination,"empty.out") || String.eq(destination,"unused"),"child output leaf is owned and fixed")
    +db : U32 <- IO.try(U32,Sql.open_existing(directory ++ "/library.sqlite",1))
    Store.exec(db,"PRAGMA foreign_keys=ON",[])
    child_mode(mode,db,Identity.Request{snapshot,Store.number(record),Store.number(reference),path},directory ++ "/" ++ destination)
    IO.try(Unit,Sql.close(db))

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> mode <> directory <> snapshot <> record <> reference <> path <> destination <> []:
      child_run(mode,directory,snapshot,record,reference,path,destination)
    case _: IO.die(Unit,2,"Invalid owned synthetic attachment assets arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)

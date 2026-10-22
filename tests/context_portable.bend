import Base
import ../src/store.bend as Store
import ../src/maintenance.bend as Maintenance
import ../src/sql.bend as Sql
import ../src/context_binding.bend as Binding
import ../src/context_store.bend as ContextStore
import ../src/json.bend as Json
import ./context.bend as Context
import ./publication_crash.bend as Check
import ./append_integrity.bend as Append

# Integration assertions use only the production capture, selected reader and
# rebuild entry points. Fixtures and fault children stay in the isolated root.
def fixture() -> String:
  Check.fixture("oldcapture") ++ String.repeat(Check.message("assistant","portable retained repetition"),64n)

def tail() -> String:
  Check.tail()

def scalar(db: U32,sql: String,args: List<&2,Sql.Cell>,expected: String,label: String) -> IO(Unit):
  Check.equal_scalar(db,sql,args,expected,label)

def version() -> String:
  Binding.version_v2(Store.projection_version())

def shared(db: U32,old: String,new: String,expected: String,label: String) -> IO(Unit):
  scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=?",
    [Sql.Cell.Integer{old},Sql.Cell.Integer{new}],expected,label)

def same_generation(db: U32,old: String,new: String,label: String) -> IO(Unit):
  scalar(db,"SELECT count(*) FROM snapshots a JOIN snapshots b ON a.generation=b.generation WHERE a.id=? AND b.id=?",
    [Sql.Cell.Integer{old},Sql.Cell.Integer{new}],"1",label)

def selected(+db: U32,snapshot: String,ordinal: U32,model: String,label: String) -> IO(Unit):
  do IO<Unit>:
    value : Maybe<&2,Store.Context> <- Context.context(db,snapshot,ordinal)
    Check.assert(Context.has(value,"/synthetic/publication|publication-session|" ++ model ++ "|"),label)

def current(+db: U32,+snapshot: String,count: String,+label: String) -> IO(Unit):
  do IO<Unit>:
    scalar(db,"SELECT count(*) FROM snapshot_context WHERE snapshot=? AND version=?",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Text{version()}],count,label ++ " writes one v2 checkpoint per physical record")
    +valid : Bool <- Store.projection_valid(db,snapshot)
    Check.assert(valid,label ++ " complete event projection remains valid")
    Maintenance.verify(db,snapshot)

def context_columns() -> String:
  "ordinal,repository,session,model,parent,version,digest"

def copied_contexts(+db: U32,+old: String,+new: String,+count: String,+label: String) -> IO(Unit):
  do IO<Unit>:
    scalar(db,"SELECT count(*) FROM snapshot_context a JOIN snapshot_context b ON a.ordinal=b.ordinal AND a.digest=b.digest AND a.version=b.version WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{new}],count,label ++ " copies exact checksum bytes across snapshot identities")
    scalar(db,"SELECT count(*) FROM (SELECT " ++ context_columns() ++ " FROM snapshot_context WHERE snapshot=? EXCEPT SELECT " ++ context_columns() ++ " FROM snapshot_context WHERE snapshot=?)",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{new}],"0",label ++ " retains every typed prefix context cell")

def lifecycle() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/portable-lifecycle.sqlite")
    Store.write_text("portable-lifecycle.jsonl","w",fixture())
    +old : String <- Store.import_file(db,"codex","portable-lifecycle.jsonl")
    current(db,old,"72","initial capture")
    +baseline : Check.Baseline <- Check.capture_baseline(db,old)
    selected(db,old,32,"oldcapture-model","selected context crosses the first32-record boundary")
    selected(db,old,64,"oldcapture-model","selected context crosses the second32-record boundary")
    Store.exec(db,"CREATE TABLE original_context AS SELECT * FROM snapshot_context WHERE snapshot=?",[Sql.Cell.Integer{old}])
    Store.write_text("portable-lifecycle.jsonl","a",tail())
    +new : String <- Store.import_file(db,"codex","portable-lifecycle.jsonl")
    shared(db,old,new,"72","healthy append reuses every complete raw occurrence")
    copied_contexts(db,old,new,"72","healthy append")
    same_generation(db,old,new,"healthy append retains the original generation")
    current(db,new,"80","appended capture")
    selected(db,new,72,"oldcapture-model","first appended context starts from the complete prefix state")
    selected(db,new,73,"newcapture-model","appended turn context changes the following incoming model")
    selected(db,old,64,"oldcapture-model","old selected checkpoint remains readable after append")
    Store.write_text("portable-lifecycle-fresh.jsonl","w",fixture() ++ tail())
    +fresh : String <- Store.import_file(db,"codex","portable-lifecycle-fresh.jsonl")
    Append.equivalent(db,new,fresh,"portable append equals independent complete provider parsing")
    Maintenance.rebuild(db,old)
    current(db,old,"72","historical rebuild")
    scalar(db,"SELECT count(*) FROM (SELECT * FROM original_context EXCEPT SELECT * FROM snapshot_context)",[],"0",
      "historical rebuild reproduces exact portable checksums for unchanged raw identities")
    selected(db,old,64,"oldcapture-model","old selected context remains readable after verified rebuild")
    Check.pinned(db,baseline,"portable append and historical rebuild")
    scalar(db,"SELECT count(*) FROM search WHERE snapshot=?",[Sql.Cell.Integer{old}],"0",
      "historical context rebuild cannot republish historical search rows")
    Check.check_integrity(db,"portable lifecycle")
    IO.try(Unit,Sql.close(db))

def partial(+name: String,+partial: String,+model: String) -> IO(Unit):
  +path = ".build/portable-partial-" ++ name
  do IO<Unit>:
    +db : U32 <- Store.open(path ++ ".sqlite")
    Store.write_text(path ++ ".jsonl","w",fixture() ++ partial)
    +old : String <- Store.import_file(db,"codex",path ++ ".jsonl")
    selected(db,old,72,"oldcapture-model",name ++ " unfinished context keeps its incoming checkpoint")
    Store.write_text(path ++ ".jsonl","a","\n" ++ Check.message("assistant","after completed tail"))
    +new : String <- Store.import_file(db,"codex",path ++ ".jsonl")
    shared(db,old,new,"72",name ++ " shares only complete prefix raw records")
    scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=? AND a.ordinal=72",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{new}],"0",name ++ " completion replaces the unfinished raw identity")
    scalar(db,"SELECT count(*) FROM snapshot_context a JOIN snapshot_context b ON a.ordinal=b.ordinal AND a.digest<>b.digest WHERE a.snapshot=? AND b.snapshot=? AND a.ordinal=72",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{new}],"1",name ++ " new raw binding changes the replacement checksum")
    selected(db,new,72,"oldcapture-model",name ++ " replacement starts from complete-prefix context")
    selected(db,new,73,model,name ++ " completed record governs the following incoming model")
    selected(db,old,72,"oldcapture-model",name ++ " old unfinished checkpoint stays pinned")
    Store.write_text(path ++ "-fresh.jsonl","w",fixture() ++ partial ++ "\n" ++ Check.message("assistant","after completed tail"))
    +fresh : String <- Store.import_file(db,"codex",path ++ "-fresh.jsonl")
    Append.equivalent(db,new,fresh,name ++ " incomplete-tail replay equals fresh parsing")
    current(db,new,"74",name ++ " completed capture")
    IO.try(Unit,Sql.close(db))

def extra_from(ordinal: String,target: String,source: String) -> String:
  "INSERT INTO snapshot_context SELECT snapshot," ++ ordinal ++
    ",repository,session,model,parent,version,digest FROM snapshot_context WHERE snapshot=" ++ target ++ " AND ordinal=" ++ source

def extra_context(ordinal: String,target: String) -> String:
  extra_from(ordinal,target,"0")

def fallback(+name: String,mutation: String) -> IO(Unit):
  +path = ".build/portable-fallback-" ++ name
  do IO<Unit>:
    +db : U32 <- Store.open(path ++ ".sqlite")
    Store.write_text(path ++ ".jsonl","w",fixture())
    +old : String <- Store.import_file(db,"codex",path ++ ".jsonl")
    Store.exec(db,mutation,[Sql.Cell.Integer{old}])
    event_valid : Bool <- Store.projection_valid(db,old)
    Check.assert(event_valid,name ++ " context-only corruption leaves event seal independently valid")
    Store.write_text(path ++ ".jsonl","a",tail())
    +new : String <- Store.import_file(db,"codex",path ++ ".jsonl")
    shared(db,old,new,"0",name ++ " forces complete verified raw replay")
    same_generation(db,old,new,name ++ " replay preserves exact-append generation")
    current(db,new,"80",name ++ " recovery")
    selected(db,new,73,"newcapture-model",name ++ " recovery reconstructs actual parser context")
    Store.write_text(path ++ "-fresh.jsonl","w",fixture() ++ tail())
    +fresh : String <- Store.import_file(db,"codex",path ++ "-fresh.jsonl")
    Append.equivalent(db,new,fresh,name ++ " replay equals independently fresh full import")
    Check.check_integrity(db,name ++ " recovery")
    IO.try(Unit,Sql.close(db))

def fallbacks() -> IO(Unit):
  do IO<Unit>:
    fallback("v1-tag","UPDATE snapshot_context SET version='providers-v4-utc-context-relay|incoming-context-v1' WHERE snapshot=?")
    fallback("unknown","UPDATE snapshot_context SET version='future|incoming-context-v99' WHERE snapshot=? AND ordinal=31")
    fallback("missing","DELETE FROM snapshot_context WHERE snapshot=? AND ordinal=31")
    fallback("digest","UPDATE snapshot_context SET digest='damaged' WHERE snapshot=? AND ordinal=31")
    fallback("payload","UPDATE snapshot_context SET model='forged' WHERE snapshot=? AND ordinal=31")
    fallback("payload-blob","UPDATE snapshot_context SET model=CAST(model AS BLOB) WHERE snapshot=? AND ordinal=31")
    fallback("digest-blob","UPDATE snapshot_context SET digest=CAST(digest AS BLOB) WHERE snapshot=? AND ordinal=31")
    fallback("version-blob","UPDATE snapshot_context SET version=CAST(version AS BLOB) WHERE snapshot=? AND ordinal=31")
    fallback("negative-extra",extra_context("-1","?"))
    fallback("real-extra",extra_context("-1e100","?"))
    fallback("fractional31",extra_context("31.5","?"))
    fallback("fractional63",extra_context("63.5","?"))
    fallback("text-extra",extra_context("'foreign-key'","?"))
    fallback("positive-extra",extra_context("999","?"))
    fallback("samecount-gap","UPDATE snapshot_context SET ordinal=999 WHERE snapshot=? AND ordinal=31")
    fallback("blob-key","UPDATE snapshot_context SET ordinal=CAST(ordinal AS BLOB) WHERE snapshot=? AND ordinal=31")

def rejected(result: U32 & (String & String),label: String) -> IO(Unit):
  (code,(out,err)) = result
  +text = out ++ err
  Check.assert(U32.is_ne(code,0) && (String.contains(text,"integrity") ||
    String.contains(text,"context") || String.contains(text,"Context")),label)

def marker_read(got: File & Result<&1,&1,U32 & String,String>,expected: String) -> IO(Unit):
  (file,result) = got
  do IO<Unit>:
    File.close(file)
    text : String <- IO.try(String,IO.pure(Result<&1,&1,U32 & String,String>,result))
    Check.assert(String.eq(text,expected),"fault reached its exact isolated marker")

def marker(path: String,expected: String) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"r"))
    result : File & Result<&1,&1,U32 & String,String> <- File.read(file,256)
    marker_read(result,expected)

def trigger(temp: Bool,mutate: Bool) -> String:
  "CREATE " ++ Bool.pick(String,temp,"TEMP ","") ++
    "TRIGGER portable_context_trigger AFTER INSERT ON main.snapshot_context WHEN new.ordinal=31 BEGIN " ++
    Bool.pick(String,mutate,"UPDATE snapshot_context SET model='forged-trigger' WHERE snapshot=new.snapshot AND ordinal=new.ordinal;",
      "SELECT 1;") ++ " END"

def publication_trigger(temp: Bool,latest: Bool) -> String:
  "CREATE " ++ Bool.pick(String,temp,"TEMP ","") ++ "TRIGGER portable_context_trigger " ++
    Bool.pick(String,latest,
      "AFTER UPDATE OF latest ON main.sources WHEN new.latest<>old.latest BEGIN UPDATE snapshot_context SET model='forged-trigger' WHERE snapshot=new.latest AND ordinal=31; END",
      "AFTER UPDATE OF accepted ON main.snapshots WHEN new.accepted=1 AND old.accepted=0 BEGIN UPDATE snapshot_context SET model='forged-trigger' WHERE snapshot=new.id AND ordinal=31; END")

def existing_main(+mode: String) -> Bool:
  String.eq(mode,"main-existing") || String.eq(mode,"main-accepted") || String.eq(mode,"main-latest")

def existing_temp(+mode: String) -> Bool:
  String.eq(mode,"temp-existing") || String.eq(mode,"temp-accepted") || String.eq(mode,"temp-latest")

def publication(+mode: String) -> Bool:
  String.contains(mode,"accepted") || String.contains(mode,"latest")

def expected_marker(+mode: String) -> String:
  Bool.pick(String,publication(mode),
    Bool.pick(String,String.contains(mode,"latest"),"latest_repointed:","accepted:"),
    Bool.pick(String,String.eq(mode,"main-existing") || String.eq(mode,"temp-existing"),"armed:",
      Bool.pick(String,String.contains(mode,"before-commit"),"before_commit:",
        Bool.pick(String,String.eq(mode,"search-removed"),"search_removed:","staged:")))) ++ mode ++ "\n"

def staged_sql(mode: String) -> String:
  match mode:
    case "delete":
      "DELETE FROM snapshot_context WHERE snapshot=(SELECT max(id) FROM snapshots) AND ordinal=31"
    case "type":
      "UPDATE snapshot_context SET model=CAST(model AS BLOB) WHERE snapshot=(SELECT max(id) FROM snapshots) AND ordinal=31"
    case "extra":
      extra_context("-1","(SELECT max(id) FROM snapshots)")
    case "fractional31":
      extra_context("31.5","(SELECT max(id) FROM snapshots)")
    case "fractional63":
      extra_context("63.5","(SELECT max(id) FROM snapshots)")
    case "fractional-byte":
      extra_from("2.5","(SELECT max(id) FROM snapshots)","1")
    case "text-extra":
      extra_context("'foreign-key'","(SELECT max(id) FROM snapshots)")
    case "tail":
      "UPDATE snapshot_context SET repository='/forged/tail' WHERE snapshot=(SELECT max(id) FROM snapshots) AND ordinal=79"
    case _:
      "UPDATE snapshot_context SET model='forged-staged' WHERE snapshot=(SELECT max(id) FROM snapshots) AND ordinal=31"

def keys(rows: List<&2,List<&2,Sql.Cell>>) -> String:
  match rows:
    case []:
      ""
    case row <> rest:
      Store.field(row,0n) ++ "," ++ keys(rest)

def verify_byte_fault(enabled: Bool,+db: U32) -> IO(Unit):
  match enabled:
    case False{}:
      IO.pure(Unit,Unit{})
    case True{}:
      do IO<Unit>:
        +target : String <- Check.scalar(db,"SELECT max(id) FROM snapshots",[])
        old : String <- Check.scalar(db,"SELECT min(id) FROM snapshots",[])
        rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.equality_query(db,old,target,9,0,True{})
        Check.assert(String.eq(keys(rows),"0,1,2,"),
          "extra copied fractional key lies just beyond the actual comparison byte cut")

def mutate_at(enabled: Bool,+db: U32,+mode: String,prefix: String,phase: String) -> IO(Unit):
  match enabled:
    case False{}:
      IO.pure(Unit,Unit{})
    case True{}:
      do IO<Unit>:
        Store.exec(db,staged_sql(mode),[])
        verify_byte_fault(String.eq(mode,"fractional-byte"),db)
        Store.write_text(prefix ++ ".marker","w",phase ++ ":" ++ mode ++ "\n")

def staged_trigger(enabled: Bool,+db: U32,+mode: String,+prefix: String) -> IO(Unit):
  match enabled:
    case True{}:
      do IO<Unit>:
        Store.exec(db,trigger(String.eq(mode,"temp-staged"),False{}),[])
        mutate_at(True{},db,mode,prefix,"staged")
    case False{}:
      mutate_at(Bool.not(existing_main(mode) || existing_temp(mode) || publication(mode) ||
        String.contains(mode,"before-commit") || String.eq(mode,"search-removed")),db,mode,prefix,"staged")

def late_trigger(enabled: Bool,+db: U32,+mode: String,+prefix: String) -> IO(Unit):
  match enabled:
    case False{}:
      IO.pure(Unit,Unit{})
    case True{}:
      do IO<Unit>:
        Store.exec(db,trigger(String.contains(mode,"temp-"),False{}),[])
        mutate_at(True{},db,mode,prefix,"before_commit")

def sealed_trigger(enabled: Bool,db: U32,+mode: String) -> IO(Unit):
  match enabled:
    case False{}:
      IO.pure(Unit,Unit{})
    case True{}:
      Store.exec(db,publication_trigger(String.contains(mode,"temp-"),String.contains(mode,"latest")),[])

def publication_marker(enabled: Bool,+db: U32,+mode: String,prefix: String,phase: String) -> IO(Unit):
  match enabled:
    case False{}:
      IO.pure(Unit,Unit{})
    case True{}:
      do IO<Unit>:
        scalar(db,"SELECT count(*) FROM snapshot_context WHERE snapshot=(SELECT max(id) FROM snapshots) AND ordinal=31 AND model='forged-trigger'",[],"1",
          mode ++ " trigger actually changed the published target context")
        Store.write_text(prefix ++ ".marker","w",phase ++ ":" ++ mode ++ "\n")

def dispatch_stage(enabled: Bool,db: U32,+mode: String,prefix: String) -> IO(Unit):
  match enabled:
    case False{}:
      IO.pure(Unit,Unit{})
    case True{}:
      staged_trigger(String.eq(mode,"main-staged") || String.eq(mode,"temp-staged"),db,mode,prefix)

def dispatch(+phase: String,+db: U32,+mode: String,+prefix: String) -> IO(Unit):
  do IO<Unit>:
    dispatch_stage(String.eq(phase,"staged"),db,mode,prefix)
    sealed_trigger(String.eq(phase,"sealed") && String.contains(mode,"sealed-"),db,mode)
    late_trigger(String.eq(phase,"before_commit") && String.contains(mode,"before-commit"),db,mode,prefix)
    mutate_at(String.eq(phase,"search_removed") && String.eq(mode,"search-removed"),db,mode,prefix,phase)
    publication_marker(publication(mode) &&
      String.eq(phase,Bool.pick(String,String.contains(mode,"latest"),"latest_repointed","accepted")),db,mode,prefix,phase)

def observe(fuel: Nat,+db: U32,+mode: String,+prefix: String) -> Store.ImportObserver:
  match fuel:
    case 0n:
      Store.Unobserved{}
    case 1n+rest:
      Store.Observed{phase => do IO<Store.ImportObserver>:
        dispatch(Store.phase_name(phase),db,mode,prefix)
        return observe(rest,db,mode,prefix)}

def install_existing(enabled: Bool,db: U32,+temp: Bool,+mode: String) -> IO(Unit):
  match enabled:
    case False{}:
      IO.pure(Unit,Unit{})
    case True{}:
      Store.exec(db,Bool.pick(String,publication(mode),
        publication_trigger(temp,String.contains(mode,"latest")),trigger(temp,True{})),[])

def drop_existing(enabled: Bool,db: U32) -> IO(Unit):
  match enabled:
    case False{}:
      IO.pure(Unit,Unit{})
    case True{}:
      Store.exec(db,"DROP TRIGGER portable_context_trigger",[])

def fault(+self: String,+mode: String) -> IO(Unit):
  +prefix = ".build/portable-fault-" ++ mode
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.write_text(prefix ++ ".jsonl","w",fixture())
    +old : String <- Store.import_file(db,"codex",prefix ++ ".jsonl")
    +baseline : Check.Baseline <- Check.capture_baseline(db,old)
    install_existing(existing_main(mode),db,False{},mode)
    Check.remember_tables(Check.tables(),db)
    Store.write_text(prefix ++ ".jsonl","a",tail())
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,["fault",mode,prefix],"",8192,30000))
    rejected(result,mode ++ " context mutation cannot publish an accepted snapshot")
    marker(prefix ++ ".marker",expected_marker(mode))
    Check.unchanged_tables(Check.tables(),db,mode ++ " complete transaction")
    Check.pinned(db,baseline,mode ++ " complete transaction")
    scalar(db,"SELECT count(*) FROM sqlite_master WHERE type='trigger' AND name='portable_context_trigger'",[],
      Bool.pick(String,existing_main(mode),"1","0"),mode ++ " trigger schema has expected rollback state")
    drop_existing(existing_main(mode),db)
    +new : String <- Store.import_file(db,"codex",prefix ++ ".jsonl")
    shared(db,old,new,"72",mode ++ " failed mutation leaves healthy retry reusable")
    current(db,new,"80",mode ++ " healthy retry")
    Check.check_integrity(db,mode ++ " rollback and retry")
    IO.try(Unit,Sql.close(db))

def fault_child(+mode: String,+prefix: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    install_existing(existing_temp(mode),db,True{},mode)
    Store.write_text(prefix ++ ".marker","w","armed:" ++ mode ++ "\n")
    ignored : String <- Store.import_observed(db,"codex",prefix ++ ".jsonl",observe(9n,db,mode,prefix))
    IO.die(Unit,1,"FAIL unsafe publication succeeded")

# The fixture is below the physical-record limit but its inherited context
# crosses the real SQL byte limits before either 32-row limit is reached.
def large_fixture() -> String:
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"large-context\",\"cwd\":" ++
    Json.quote("/synthetic/" ++ String.repeat("x",230000n)) ++ "}}\n" ++
    String.repeat(Check.message("assistant","bounded large inherited scope"),8n)

def byte_boundaries(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.scan_query(db,snapshot,0,True{})
    Check.assert(String.eq(keys(rows),"0,1,2,3,4,"),
      "production context scan hits its1MiB byte cut immediately after ordinal4")
    rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.equality_query(db,snapshot,snapshot,9,0,True{})
    Check.assert(String.eq(keys(rows),"0,1,2,"),
      "production copied-context comparison hits its1MiB byte cut immediately after ordinal2")

def byte_old() -> IO(Unit):
  +prefix = {".build/portable-byte-old" : String}
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.write_text(prefix ++ ".jsonl","w",large_fixture())
    +old : String <- Store.import_file(db,"codex",prefix ++ ".jsonl")
    byte_boundaries(db,old)
    Store.exec(db,extra_from("4.5","?","1"),[Sql.Cell.Integer{old}])
    rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.scan_query(db,old,0,True{})
    Check.assert(String.eq(keys(rows),"0,1,2,3,4,"),
      "extra old fractional key lies just beyond the actual first byte-limited page")
    Store.write_text(prefix ++ ".jsonl","a",Check.message("assistant","byte boundary tail"))
    +new : String <- Store.import_file(db,"codex",prefix ++ ".jsonl")
    shared(db,old,new,"0","old fractional key after byte cut forces verified full replay")
    same_generation(db,old,new,"byte-cut replay preserves source generation")
    current(db,new,"10","byte-cut old corruption recovery")
    Store.write_text(prefix ++ "-fresh.jsonl","w",large_fixture() ++ Check.message("assistant","byte boundary tail"))
    +fresh : String <- Store.import_file(db,"codex",prefix ++ "-fresh.jsonl")
    Append.equivalent(db,new,fresh,"byte-cut replay equals independently fresh full parsing")
    Check.check_integrity(db,"old byte-cut fractional corruption")
    IO.try(Unit,Sql.close(db))

def byte_new(+self: String) -> IO(Unit):
  +prefix = {".build/portable-byte-new" : String}
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.write_text(prefix ++ ".jsonl","w",large_fixture())
    +old : String <- Store.import_file(db,"codex",prefix ++ ".jsonl")
    byte_boundaries(db,old)
    Check.remember_tables(Check.tables(),db)
    Store.write_text(prefix ++ ".jsonl","a",Check.message("assistant","byte boundary tail"))
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,["fault","fractional-byte",prefix],"",8192,30000))
    rejected(result,"extra copied fractional key after byte cut rejects publication")
    marker(prefix ++ ".marker","staged:fractional-byte\n")
    Check.unchanged_tables(Check.tables(),db,"byte-cut fractional copied prefix")
    +new : String <- Store.import_file(db,"codex",prefix ++ ".jsonl")
    shared(db,old,new,"9","byte-cut fault leaves exact prefix reusable on retry")
    copied_contexts(db,old,new,"9","byte-cut healthy retry")
    current(db,new,"10","byte-cut healthy retry")
    Check.check_integrity(db,"new byte-cut fractional corruption")
    IO.try(Unit,Sql.close(db))

def empty_and_zero_checkpoint() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/portable-zero.sqlite")
    Store.write_text("portable-empty.jsonl","w","")
    +empty : String <- Store.import_file(db,"codex","portable-empty.jsonl")
    current(db,empty,"0","empty capture")
    Store.write_text("portable-empty.jsonl","a",Check.message("assistant","first complete record"))
    +first : String <- Store.import_file(db,"codex","portable-empty.jsonl")
    shared(db,empty,first,"0","empty capture has no raw occurrence to reuse")
    same_generation(db,empty,first,"append to empty capture retains generation")
    current(db,first,"1","append to empty capture")
    Store.write_text("portable-zero.jsonl","w","{\"type\":\"turn_context\",\"payload\":{\"model\":\"zero-tail\"}}")
    +partial : String <- Store.import_file(db,"codex","portable-zero.jsonl")
    scalar(db,"SELECT checkpoint_ordinal FROM snapshots WHERE id=?",[Sql.Cell.Integer{partial}],"0",
      "unfinished first physical record retains checkpoint ordinal0")
    Store.write_text("portable-zero.jsonl","a","\n" ++ Check.message("assistant","after zero checkpoint"))
    +complete : String <- Store.import_file(db,"codex","portable-zero.jsonl")
    shared(db,partial,complete,"0","checkpoint0 completion allocates a fresh raw identity")
    current(db,complete,"2","checkpoint0 completed capture")
    selected_context : Maybe<&2,Store.Context> <- Context.context(db,complete,1)
    Check.assert(Context.has(selected_context,"||zero-tail|"),"checkpoint0 replacement restores outgoing context")
    Store.write_text("portable-zero-fresh.jsonl","w",Check.context("zero-tail") ++ Check.message("assistant","after zero checkpoint"))
    +fresh : String <- Store.import_file(db,"codex","portable-zero-fresh.jsonl")
    Append.equivalent(db,complete,fresh,"checkpoint0 replay equals fresh full parsing")
    Check.check_integrity(db,"empty and checkpoint0 captures")
    IO.try(Unit,Sql.close(db))

def binding_mutation(+db: U32,+snapshot: String,mode: String) -> IO(Unit):
  match mode:
    case "raw-id":
      do IO<Unit>:
        Store.exec(db,"INSERT INTO raw(generation,ordinal,offset,n,digest,bytes,complete,oversized) SELECT r.generation,r.ordinal,r.offset,r.n,r.digest,r.bytes,r.complete,r.oversized FROM raw r JOIN records i ON i.raw=r.id WHERE i.snapshot=? AND i.ordinal=31",
          [Sql.Cell.Integer{snapshot}])
        Store.exec(db,"UPDATE records SET raw=last_insert_rowid() WHERE snapshot=? AND ordinal=31",[Sql.Cell.Integer{snapshot}])
    case "generation":
      do IO<Unit>:
        Store.exec(db,"INSERT INTO generations(source) SELECT g.source FROM generations g JOIN snapshots p ON p.generation=g.id WHERE p.id=?",
          [Sql.Cell.Integer{snapshot}])
        Store.exec(db,"UPDATE snapshots SET generation=last_insert_rowid() WHERE id=?",[Sql.Cell.Integer{snapshot}])
    case "source":
      do IO<Unit>:
        Store.exec(db,"PRAGMA defer_foreign_keys=ON",[])
        Store.exec(db,"UPDATE sources SET id=id+1000000 WHERE id=(SELECT g.source FROM generations g JOIN snapshots p ON p.generation=g.id WHERE p.id=?)",
          [Sql.Cell.Integer{snapshot}])
        Store.exec(db,"UPDATE generations SET source=source+1000000 WHERE id=(SELECT generation FROM snapshots WHERE id=?)",
          [Sql.Cell.Integer{snapshot}])
    case "provider":
      Store.exec(db,"UPDATE sources SET provider='claude' WHERE id=(SELECT g.source FROM generations g JOIN snapshots p ON p.generation=g.id WHERE p.id=?)",
        [Sql.Cell.Integer{snapshot}])
    case "locator":
      Store.exec(db,"UPDATE sources SET locator=locator||'/changed' WHERE id=(SELECT g.source FROM generations g JOIN snapshots p ON p.generation=g.id WHERE p.id=?)",
        [Sql.Cell.Integer{snapshot}])
    case _:
      IO.die(Unit,2,"Unknown isolated binding fault")

def binding_child(+mode: String,+prefix: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.exec(db,"BEGIN IMMEDIATE",[])
    binding_mutation(db,snapshot,mode)
    Store.write_text(prefix ++ ".marker","w","binding:" ++ mode ++ "\n")
    ignored : Maybe<&2,Store.Context> <- Context.context(db,snapshot,31)
    IO.die(Unit,1,"FAIL corrupt selected row accepted")

def binding_fault(+self: String,+mode: String) -> IO(Unit):
  +prefix = ".build/portable-binding-" ++ mode
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.write_text(prefix ++ ".jsonl","w",fixture())
    +snapshot : String <- Store.import_file(db,"codex",prefix ++ ".jsonl")
    +baseline : Check.Baseline <- Check.capture_baseline(db,snapshot)
    Check.remember_tables(Check.tables(),db)
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,["binding",mode,prefix,snapshot],"",8192,30000))
    rejected(result,mode ++ " cannot reinterpret an existing portable checkpoint")
    marker(prefix ++ ".marker","binding:" ++ mode ++ "\n")
    Check.unchanged_tables(Check.tables(),db,mode ++ " selected binding failure")
    Check.pinned(db,baseline,mode ++ " selected binding failure")
    selected(db,snapshot,31,"oldcapture-model",mode ++ " rollback preserves the original selected context")
    Check.check_integrity(db,mode ++ " selected binding rollback")
    IO.try(Unit,Sql.close(db))

def wide_ids() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/portable-wide.sqlite")
    Store.exec(db,"INSERT INTO sources(id,provider,locator) VALUES(9007199254740992,'codex','/synthetic/unimported-portable-seed')",[])
    Store.exec(db,"INSERT INTO generations(id,source) VALUES(9007199254740992,9007199254740992)",[])
    Store.exec(db,"INSERT INTO snapshots(id,generation,extent) VALUES(9007199254740992,9007199254740992,0)",[])
    Store.exec(db,"INSERT INTO raw(id,generation,ordinal,offset,n,digest,bytes,complete,oversized) VALUES(9007199254740992,9007199254740992,0,0,0,'',x'',1,0)",[])
    Store.write_text("portable-wide.jsonl","w",Check.fixture("oldcapture"))
    +old : String <- Store.import_file(db,"codex","portable-wide.jsonl")
    Check.assert(String.eq(old,"9007199254740993"),"portable production capture preserves odd snapshot ID above2^53")
    scalar(db,"SELECT p.id||'|'||g.id||'|'||s.id||'|'||i.raw FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source JOIN records i ON i.snapshot=p.id WHERE p.id=? AND i.ordinal=0",
      [Sql.Cell.Integer{old}],"9007199254740993|9007199254740993|9007199254740993|9007199254740993",
      "portable binding retains exact wide snapshot generation source and raw identities")
    current(db,old,"8","wide initial capture")
    selected(db,old,3,"oldcapture-model","wide identities verify through the real selected context reader")
    Store.write_text("portable-wide.jsonl","a",Check.message("assistant","wide tail"))
    +new : String <- Store.import_file(db,"codex","portable-wide.jsonl")
    Check.assert(String.eq(new,"9007199254740994"),"portable append allocates the exact next wide snapshot identity")
    shared(db,old,new,"8","wide append reuses exact retained raw identities")
    copied_contexts(db,old,new,"8","wide append")
    current(db,new,"9","wide append")
    selected(db,old,3,"oldcapture-model","wide old selected context stays stable after append")
    Check.check_integrity(db,"portable wide identities")
    IO.try(Unit,Sql.close(db))

def old_answer(answer: U32 & (String & String)) -> IO(String):
  (code,(out,err)) = answer
  do IO<String>:
    Check.assert(U32.is_eq(code,0),"actual frozen old worker exits zero")
    Check.assert(String.is_empty(err),"actual frozen old worker stderr is empty")
    return String.trim(out)

def old_run(worker: String,args: List<String>) -> IO(String):
  do IO<String>:
    answer : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(worker,args,"",8192,30000))
    old_answer(answer)

def legacy_rows(db: U32,snapshot: String,count: String,label: String) -> IO(Unit):
  scalar(db,"SELECT count(*) FROM snapshot_context WHERE snapshot=? AND version=?",
    [Sql.Cell.Integer{snapshot},Sql.Cell.Text{Binding.version_v1(Store.projection_version())}],count,label)

def compatibility_plain(+worker: String) -> IO(Unit):
  +path = {".build/portable-compat" : String}
  do IO<Unit>:
    reported : String <- old_run(worker,["version"])
    Check.assert(String.eq(reported,Binding.version_v1(Store.projection_version())),
      "compatibility worker actually implements the frozen v1 context format")
    Store.write_text(path ++ ".jsonl","w",fixture())
    +old : String <- old_run(worker,["append",path ++ ".sqlite","codex",path ++ ".jsonl"])
    +db : U32 <- Store.open(path ++ ".sqlite")
    legacy_rows(db,old,"72","actual old binary writes72 genuine legacy checkpoints")
    selected(db,old,31,"oldcapture-model","new reader validates real historical v1 context bytes")
    Store.write_text(path ++ ".jsonl","a",Check.message("assistant","first compatibility tail"))
    +new : String <- Store.import_file(db,"codex",path ++ ".jsonl")
    shared(db,old,new,"0","new importer fully replays actual v1 writer output")
    same_generation(db,old,new,"actual v1 fallback retains the source generation")
    current(db,new,"73","current append after actual v1 capture")
    ignored : String <- old_run(worker,["rebuild",path ++ ".sqlite",old])
    selected(db,old,31,"oldcapture-model","new reader retains actual v1 selection after old historical rebuild")
    Store.write_text(path ++ ".jsonl","a",Check.message("assistant","second compatibility tail"))
    +old_again : String <- old_run(worker,["append",path ++ ".sqlite","codex",path ++ ".jsonl"])
    shared(db,new,old_again,"0","actual old importer fully replays unrecognized portable contexts")
    legacy_rows(db,old_again,"74","actual old append preserves its legacy write format")
    selected(db,old_again,31,"oldcapture-model","new selected reader validates the old writer after v2 exposure")
    Store.write_text(path ++ ".jsonl","a",Check.message("assistant","third compatibility tail"))
    +current_again : String <- Store.import_file(db,"codex",path ++ ".jsonl")
    shared(db,old_again,current_again,"0","current importer safely returns from the actual old writer")
    Store.write_text(path ++ ".jsonl","a",Check.message("assistant","fourth compatibility tail"))
    +latest : String <- Store.import_file(db,"codex",path ++ ".jsonl")
    shared(db,current_again,latest,"75","successive current imports resume portable checksum reuse")
    copied_contexts(db,current_again,latest,"75","actual compatibility roundtrip")
    Store.write_text(path ++ "-fresh.jsonl","w",fixture() ++ Check.message("assistant","first compatibility tail") ++
      Check.message("assistant","second compatibility tail") ++ Check.message("assistant","third compatibility tail") ++
      Check.message("assistant","fourth compatibility tail"))
    +fresh : String <- Store.import_file(db,"codex",path ++ "-fresh.jsonl")
    Append.equivalent(db,latest,fresh,"actual alternating old and new writers equal fresh raw replay")
    Maintenance.rebuild(db,old)
    current(db,old,"72","current rebuild of actual v1 historical snapshot")
    selected(db,old,31,"oldcapture-model","current historical upgrade preserves selected context")
    scalar(db,"PRAGMA user_version",[],"3","portable context format retains its codec under schema3 archive fence")
    Check.check_integrity(db,"actual old and new context writers")
    IO.try(Unit,Sql.close(db))

def file_text(result: File & Result<&1,&1,U32 & String,String>) -> IO(String):
  (file,value) = result
  do IO<String>:
    File.close(file)
    IO.try(String,IO.pure(Result<&1,&1,U32 & String,String>,value))

def file_present(result: Result<&1,&1,U32 & String,File>,expected: String) -> IO(Bool):
  match result:
    case Fail{_}:
      IO.pure(Bool,False{})
    case Done{file}:
      do IO<Bool>:
        result : File & Result<&1,&1,U32 & String,String> <- File.read(file,256)
        text : String <- file_text(result)
        return String.eq(text,expected)

def poll_next(found: Bool,next: Unit -> IO(Unit)) -> IO(Unit):
  match found:
    case True{}:
      IO.pure(Unit,Unit{})
    case False{}:
      do IO<Unit>:
        IO.sleep(1)
        next(Unit{})

def wait_file(fuel: Nat,+path: String,+expected: String) -> IO(Unit):
  match fuel:
    case 0n:
      IO.die(Unit,1,"FAIL exact compatibility connection marker was not observed")
    case 1n+rest:
      do IO<Unit>:
        result : Result<&1,&1,U32 & String,File> <- File.open(path,"r")
        found : Bool <- file_present(result,expected)
        poll_next(found,unused => wait_file(rest,path,expected))

def compatibility_waiting(+worker: String) -> IO(Unit):
  +path = {".build/portable-waiting" : String}
  do IO<Unit>:
    Store.write_text(path ++ ".jsonl","w",fixture())
    +old : String <- old_run(worker,["append",path ++ ".sqlite","codex",path ++ ".jsonl"])
    +db : U32 <- Store.open(path ++ ".sqlite")
    Store.write_text(path ++ ".jsonl","a",Check.message("assistant","waiting compatibility tail"))
    job : Chan(Result<&1,&1,U32 & String,U32 & (String & String)>) <-
      IO.fork(Result<&1,&1,U32 & String,U32 & (String & String)>,
        Process.run(worker,["waiting",path ++ ".sqlite","codex",path ++ ".jsonl",
          path ++ ".ready",path ++ ".gate",path ++ ".begin"],"",8192,30000))
    wait_file(30000n,path ++ ".ready","old-connection-open\n")
    marker(path ++ ".ready","old-connection-open\n")
    Store.exec(db,"BEGIN IMMEDIATE",[])
    +header : Maintenance.Header <- Maintenance.header(db,old)
    Maintenance.verify_header(db,old,header)
    Maintenance.rebuild_header(db,old,header)
    scalar(db,"SELECT count(*) FROM snapshot_context WHERE snapshot=? AND version=?",
      [Sql.Cell.Integer{old},Sql.Cell.Text{version()}],"72","parent stages real v2 context rewrite while old connection remains open")
    Store.write_text(path ++ ".gate","w","go\n")
    wait_file(30000n,path ++ ".begin","old-connection-before-transaction\n")
    Store.exec(db,"COMMIT",[])
    marker(path ++ ".begin","old-connection-before-transaction\n")
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      IO.join(Result<&1,&1,U32 & String,U32 & (String & String)>,job)
    answer : U32 & (String & String) <- IO.try(U32 & (String & String),
      IO.pure(Result<&1,&1,U32 & String,U32 & (String & String)>,result))
    +new : String <- old_answer(answer)
    shared(db,old,new,"0","already-open old connection observes committed v2 tags and fully replays")
    legacy_rows(db,new,"73","waiting actual old writer retains legacy format")
    selected(db,new,31,"oldcapture-model","new reader validates the waiting old writer output")
    Store.write_text(path ++ "-fresh.jsonl","w",fixture() ++ Check.message("assistant","waiting compatibility tail"))
    +fresh : String <- Store.import_file(db,"codex",path ++ "-fresh.jsonl")
    Append.equivalent(db,new,fresh,"waiting old connection produces exactly fresh normalized fields")
    Check.check_integrity(db,"already-open old connection compatibility")
    IO.try(Unit,Sql.close(db))

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    lifecycle()
    partial("model-change","{\"type\":\"turn_context\",\"payload\":{\"model\":\"tail-model\"}}","tail-model")
    partial("model-clear","{\"type\":\"turn_context\",\"payload\":{}}","")
    fallbacks()
    byte_old()
    byte_new(self)
    empty_and_zero_checkpoint()
    fault(self,"body")
    fault(self,"type")
    fault(self,"delete")
    fault(self,"extra")
    fault(self,"fractional31")
    fault(self,"fractional63")
    fault(self,"text-extra")
    fault(self,"tail")
    fault(self,"main-existing")
    fault(self,"temp-existing")
    fault(self,"main-staged")
    fault(self,"temp-staged")
    fault(self,"main-accepted")
    fault(self,"temp-accepted")
    fault(self,"main-latest")
    fault(self,"temp-latest")
    fault(self,"main-sealed-accepted")
    fault(self,"temp-sealed-accepted")
    fault(self,"main-sealed-latest")
    fault(self,"temp-sealed-latest")
    fault(self,"main-before-commit")
    fault(self,"temp-before-commit")
    fault(self,"search-removed")
    binding_fault(self,"raw-id")
    binding_fault(self,"generation")
    binding_fault(self,"source")
    binding_fault(self,"provider")
    binding_fault(self,"locator")
    wide_ids()
    IO.print("Portable context integration suite passed")

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case self <> []:
      suite(self)
    case _ <> "fault" <> mode <> prefix <> []:
      fault_child(mode,prefix)
    case _ <> "binding" <> mode <> prefix <> snapshot <> []:
      binding_child(mode,prefix,snapshot)
    case _ <> "compat" <> +worker <> []:
      do IO<Unit>:
        compatibility_plain(worker)
        compatibility_waiting(worker)
        IO.print("Portable context actual old-worker compatibility passed")
    case _:
      IO.die(Unit,2,"Usage: context-portable [compat ABSOLUTE_FROZEN_OLD_WORKER]")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)

import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./paths.bend as Paths
import ./archive_meta.bend as Meta
import ./archive_maintenance.bend as Retained
import ./archive_compare.bend as Compare
import ./context_store.bend as ContextStore
import ./projection_seal.bend as Seal
import ./zstd/frame.bend as Frame

type Captured is Data:
  Captured{chunks: List<&2,List<&2,U32>>,extent: U32,digest: String}

def limits() -> Frame.Limits:
  Frame.Limits{Meta.input_limit(),Meta.output_limit(),8388608,64,4096}

def extent(chunks: List<&2,List<&2,U32>>,total: U32) -> U32:
  match chunks:
    case []: total
    case chunk <> rest:
      extent(rest,U32.add(total,U32.from_nat(List.length(&2,U32,chunk))))

def decoded(result: Result<&2,&2,String,List<&2,List<&2,U32>>>) -> IO(Captured):
  match result:
    case Fail{+message}:
      IO.die(Captured,2,
        Bool.pick(String,String.contains(message,"dictionary"),"archive_dictionary: ",
          Bool.pick(String,String.contains(message,"limit") || String.contains(message,"exceeds"),
            "archive_limit: ","archive_corrupt: ")) ++ message)
    case Done{+chunks}:
      IO.pure(Captured,Captured{chunks,extent(chunks,0),Meta.digest_chunks(chunks)})

def decode(container: Captured) -> IO(Captured):
  Captured{chunks,_,_} = container
  decoded(Frame.decode(List.concat(&2,U32,chunks),limits()))

def size_checked(got: File & Result<&1,&1,U32 & String,U32>,expected: U32) -> IO(File):
  (file,result) = got
  do IO<File>:
    size : U32 <- IO.try(U32,IO.pure(Result<&1,&1,U32 & String,U32>,result))
    Store.checked(U32.is_eq(size,expected),"archive_changed: compressed extent changed during capture")
    return file

def require_size(file: File,expected: U32) -> IO(File):
  do IO<File>:
    result : File & Result<&1,&1,U32 & String,U32> <- File.size(file)
    size_checked(result,expected)

def read_piece(file: File,+bytes: List<&2,U32>,wanted: U32,
  next: File -> List<&2,U32> -> IO(File & List<&2,List<&2,U32>>)) ->
  IO(File & List<&2,List<&2,U32>>):
  do IO<File & List<&2,List<&2,U32>>>:
    Store.checked(Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(wanted)),
      "archive_changed: compressed source ended before selected extent")
    next(file,bytes)

def read_step(file: File,+offset: U32,+size: U32,reversed: List<&2,List<&2,U32>>,done: Bool,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(File & List<&2,List<&2,U32>>)) ->
  IO(File & List<&2,List<&2,U32>>):
  match done:
    case True{}:
      do IO<File & List<&2,List<&2,U32>>>:
        checked : File <- require_size(file,size)
        return (checked,List.reverse(&2,List<&2,U32>,reversed))
    case False{}:
      +wanted = U32.min(65536,U32.sub(size,offset))
      Store.read(File & List<&2,List<&2,U32>>,file,offset,wanted,
        f => bytes => read_piece(f,bytes,wanted,
          after => chunk => next(after,U32.add(offset,wanted),chunk <> reversed)))

def read_all(fuel: Nat,file: File,+offset: U32,+size: U32,reversed: List<&2,List<&2,U32>>) ->
  IO(File & List<&2,List<&2,U32>>):
  match fuel:
    case 0n: IO.die(File & List<&2,List<&2,U32>>,2,"archive_limit: compressed read budget exhausted")
    case 1n+rest:
      read_step(file,offset,size,reversed,U32.is_eq(offset,size),
        f => pos => chunks => read_all(rest,f,pos,size,chunks))

def compare_read(file: File,+expected: List<&2,U32>,actual: List<&2,U32>,
  next: File -> IO(File)) -> IO(File):
  do IO<File>:
    Store.checked(Compare.equal([expected],[actual]),
      "archive_changed: compressed bytes changed during capture")
    next(file)

def compare_file(chunks: List<&2,List<&2,U32>>,file: File,+offset: U32) -> IO(File):
  match chunks:
    case []: IO.pure(File,file)
    case +chunk <> rest:
      +length = U32.from_nat(List.length(&2,U32,chunk))
      Store.read(File,file,offset,length,
        f => actual => compare_read(f,chunk,actual,
          checked => compare_file(rest,checked,U32.add(offset,length))))

# Reopen the canonical locator. Original descriptor-only comparison would miss
# an ordinary path replacement while continuing to read the detached old inode.
def canonical_stable(+path: String,result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Unit):
  match result:
    case Fail{_}:
      IO.die(Unit,2,"archive_changed: source locator could not be revalidated")
    case Done{(code,(out,_))}:
      Store.checked(U32.is_eq(code,0) && String.eq(out,path ++ "\n"),
        "archive_changed: source locator changed or disappeared during capture")

def reopened(result: Result<&1,&1,U32 & String,File>) -> IO(File):
  match result:
    case Fail{_}:
      IO.die(File,2,"archive_changed: source could not be reopened during capture")
    case Done{file}:
      IO.pure(File,file)

def revalidate(+path: String,container: Captured) -> IO(Unit):
  Captured{chunks,+size,_} = container
  do IO<Unit>:
    resolved : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/bin/realpath",["--",path],"",8192,2000)
    canonical_stable(path,resolved)
    opened : Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    file : File <- reopened(opened)
    sized : File <- require_size(file,size)
    compared : File <- compare_file(chunks,sized,0)
    final : File <- require_size(compared,size)
    File.close(final)

def flush(state: Store.ImportState,tail: List<&2,U32>,length: U32,oversized: Bool) -> IO(Store.ImportState):
  match tail:
    case []: IO.pure(Store.ImportState,state)
    case byte <> rest:
      Store.put_piece(state,Store.Piece{List.reverse(&2,U32,byte <> rest),length,False{},oversized})

def split_ready(state: Store.ImportState,result: Store.Split,
  next: Store.ImportState -> List<&2,U32> -> U32 -> Bool -> IO(Store.ImportState)) -> IO(Store.ImportState):
  Store.Split{pieces,tail,length,oversized} = result
  do IO<Store.ImportState>:
    after : Store.ImportState <- Store.put_pieces(pieces,state)
    next(after,tail,length,oversized)

def feed(chunks: List<&2,List<&2,U32>>,state: Store.ImportState,
  tail: List<&2,U32>,length: U32,oversized: Bool) -> IO(Store.ImportState):
  match chunks:
    case []: flush(state,tail,length,oversized)
    case chunk <> rest:
      split_ready(state,Store.split(chunk,tail,length,oversized,[]),
        after => pending => size => over => feed(rest,after,pending,size,over))

def latest_rows(+source: String,+snapshot: String,rows: List<&2,List<&2,Sql.Cell>>) -> IO(Unit):
  match rows:
    case [[Sql.Cell.Integer{actual_source},Sql.Cell.Integer{latest},
      Sql.Cell.Integer{actual_snapshot},Sql.Cell.Integer{accepted},Sql.Cell.Integer{owner}]]:
      Store.checked(String.eq(actual_source,source) && String.eq(latest,snapshot) &&
        String.eq(actual_snapshot,snapshot) && String.eq(accepted,"1") && String.eq(owner,source),
        "archive_corrupt: final source/latest/snapshot binding changed")
    case _:
      IO.die(Unit,2,"archive_corrupt: final source/latest/snapshot binding is invalid")

def latest_bound(+db: U32,+source: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT s.id,s.latest,p.id,p.accepted,g.source FROM sources s LEFT JOIN snapshots p ON p.id=? LEFT JOIN generations g ON g.id=p.generation WHERE s.id=?",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{source}],1)
    latest_rows(source,snapshot,rows)

def search_rows(rows: List<&2,List<&2,Sql.Cell>>) -> IO(Unit):
  match rows:
    case [[Sql.Cell.Integer{"0"}]]:
      IO.pure(Unit,Unit{})
    case _:
      IO.die(Unit,2,"archive_corrupt: final lexical search projection changed")

# Compare every typed search field and row identity in both directions. The
# rowid branch also sees malformed snapshot keys on otherwise owned rows; the
# final branch refuses stale search rows belonging to this source's history.
# The bridge's existing bounded SQLite deadline fails this check closed.
def search_exact(+db: U32,source: String,+snapshot: String) -> IO(Unit):
  +columns = {"rowid,body,typeof(body),arguments,typeof(arguments),result,typeof(result),tool,typeof(tool),snapshot,typeof(snapshot),ordinal,typeof(ordinal),event,typeof(event)" : String}
  +events = {"SELECT " ++ columns ++ " FROM events WHERE snapshot=?" : String}
  +search = {"SELECT " ++ columns ++ " FROM search WHERE snapshot=? OR rowid IN (SELECT rowid FROM events WHERE snapshot=?)" : String}
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT EXISTS(" ++ events ++ " EXCEPT " ++ search ++ ") OR EXISTS(" ++ search ++ " EXCEPT " ++ events ++
      ") OR EXISTS(SELECT 1 FROM search f JOIN snapshots p ON p.id=f.snapshot JOIN generations g ON g.id=p.generation WHERE g.source=? AND p.id<>?)",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{snapshot},Sql.Cell.Integer{snapshot},
       Sql.Cell.Integer{snapshot},Sql.Cell.Integer{snapshot},Sql.Cell.Integer{snapshot},
       Sql.Cell.Integer{source},Sql.Cell.Integer{snapshot}],1)
    search_rows(rows)

def projection_gate(+db: U32,+source: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    latest_bound(db,source,snapshot)
    sealed : Bool <- Store.projection_valid(db,snapshot)
    Store.checked(sealed,"archive_corrupt: final event projection seal changed")
    search_exact(db,source,snapshot)

def publication_gate(+db: U32,source: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    Retained.verify_owned(db,snapshot,True{})
    projection_gate(db,source,snapshot)

# Identical complete containers retain their accepted transform without another
# full decompression. Recheck the committed byte hashes and typed projections
# after the final observer, but never parse or manufacture a new snapshot.
def unchanged_gate(+db: U32,source: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    compressed : List<&2,List<&2,U32>> <- Meta.container(db,snapshot,True{})
    logical : List<&2,List<&2,U32>> <- Retained.logical(db,snapshot,True{})
    projection_gate(db,source,snapshot)

def finish_ready(state: Store.ImportState,+container: Captured,logical: Captured,path: String) -> IO(String):
  Store.ImportState{+db,file,provider,+source,gen,+snapshot,extent,off,ord,checkpoint,cpord,ctx,observe,seal,contexts} = state
  Captured{_,compressed,compressed_sha} = container
  Captured{_,_,logical_sha} = logical
  do IO<String>:
    Meta.seal(db,snapshot,compressed,compressed_sha,logical_sha)
    staged : Store.ImportObserver <- Store.observe_phase(observe,Store.Staged{})
    Retained.verify_owned(db,snapshot,False{})
    revalidate(path,container)
    File.close(file)
    Store.publish(db,source,snapshot,staged,seal,contexts,publication_gate(db,source,snapshot))

def staged(+db: U32,file: File,provider: String,source: String,+generation: String,+snapshot: String,
  +container: Captured,+logical: Captured,path: String,observe: Store.ImportObserver) -> IO(String):
  Captured{compressed,_,_} = container
  Captured{chunks,+length,_} = logical
  do IO<String>:
    Meta.stage(db,snapshot,compressed)
    staged_observer : Store.ImportObserver <- Store.observe_phase(observe,Store.ContainerStaged{})
    contexts : ContextStore.Plan <- ContextStore.fresh(db,Store.projection_version(),generation)
    state : Store.ImportState <- feed(chunks,
      Store.ImportState{db,file,provider,source,generation,snapshot,length,0,0,0,0,
        Store.Context{"","","",""},staged_observer,Seal.SealReplay{},contexts},[],0,False{})
    finished : Store.ImportState <- Store.finalize_rows(state)
    finish_ready(finished,container,logical,path)

def generation(+db: U32,source: String,reuse: Maybe<&2,String>) -> IO(String):
  match reuse:
    case Some{identity}: IO.pure(String,identity)
    case None{}:
      do IO<String>:
        Store.exec(db,"INSERT INTO generations(source,encoding) VALUES(?,?)",
          [Sql.Cell.Integer{source},Sql.Cell.Text{Meta.encoding()}])
        Store.last_id(db)

def create(+db: U32,file: File,provider: String,+source: String,+container: Captured,
  +logical: Captured,path: String,observe: Store.ImportObserver,reuse: Maybe<&2,String>) -> IO(String):
  Captured{_,length,_} = logical
  do IO<String>:
    +gen : String <- generation(db,source,reuse)
    Store.exec(db,"INSERT INTO snapshots(generation,extent) VALUES(?,?)",
      [Sql.Cell.Integer{gen},Sql.Cell.Integer{U32.show(length)}])
    snapshot : String <- Store.last_id(db)
    staged(db,file,provider,source,gen,snapshot,container,logical,path,observe)

def fresh(db: U32,file: File,provider: String,source: String,+container: Captured,
  path: String,observe: Store.ImportObserver) -> IO(String):
  do IO<String>:
    logical : Captured <- decode(container)
    create(db,file,provider,source,container,logical,path,observe,None{})

def unchanged(+db: U32,file: File,source: String,+snapshot: String,+container: Captured,path: String,
  observe: Store.ImportObserver) -> IO(String):
  do IO<String>:
    revalidate(path,container)
    File.close(file)
    commit_observer : Store.ImportObserver <- Store.observe_phase(observe,Store.BeforeCommit{})
    unchanged_gate(db,source,snapshot)
    Store.exec(db,"COMMIT",[])
    finished_observer : Store.ImportObserver <- Store.observe_phase(commit_observer,Store.Committed{})
    return snapshot

def appended(db: U32,file: File,provider: String,source: String,+container: Captured,
  +logical: Captured,path: String,observe: Store.ImportObserver,generation: String,
  old: List<&2,List<&2,U32>>,+physical_prefix: Bool) -> IO(String):
  Captured{new_bytes,_,_} = logical
  do IO<String>:
    Store.checked(Bool.not(physical_prefix) || Compare.prefix(old,new_bytes),
      "archive_corrupt: preserved container prefix changed logical bytes")
    create(db,file,provider,source,container,logical,path,observe,
      Bool.pick(Maybe<&2,String>,physical_prefix,Some{generation},None{}))

def changed(db: U32,file: File,provider: String,source: String,+container: Captured,
  path: String,observe: Store.ImportObserver,origin: Meta.Origin,
  physical: List<&2,List<&2,U32>>,old: List<&2,List<&2,U32>>,same: Bool) -> IO(String):
  Captured{bytes,_,_} = container
  Meta.Origin{snapshot,_,generation,_,_,_,_,_,_,_,_} = origin
  match same:
    case True{}: unchanged(db,file,source,snapshot,container,path,observe)
    case False{}:
      do IO<String>:
        logical : Captured <- decode(container)
        appended(db,file,provider,source,container,logical,path,observe,generation,old,
          Compare.prefix(physical,bytes))

def old_origin(+db: U32,file: File,provider: String,source: String,+container: Captured,
  path: String,observe: Store.ImportObserver,origin: Maybe<&2,Meta.Origin>) -> IO(String):
  Captured{bytes,_,_} = container
  match origin:
    case None{}: fresh(db,file,provider,source,container,path,observe)
    case Some{+old}:
      Meta.Origin{+snapshot,_,_,_,_,_,_,_,_,_,_} = old
      do IO<String>:
        +physical : List<&2,List<&2,U32>> <- Meta.container(db,snapshot,True{})
        logical : List<&2,List<&2,U32>> <- Retained.logical(db,snapshot,True{})
        changed(db,file,provider,source,container,path,observe,old,physical,logical,
          Compare.equal(physical,bytes))

def previous(+db: U32,file: File,provider: String,+source: String,container: Captured,
  path: String,observe: Store.ImportObserver,rows: List<&2,List<&2,Sql.Cell>>) -> IO(String):
  match rows:
    case [Sql.Cell.Null{},Sql.Cell.Null{},Sql.Cell.Null{},Sql.Cell.Null{}] <> []:
      fresh(db,file,provider,source,container,path,observe)
    case [Sql.Cell.Integer{latest},Sql.Cell.Integer{+snapshot},Sql.Cell.Integer{owner},Sql.Cell.Integer{accepted}] <> []:
      do IO<String>:
        Store.checked(String.eq(latest,snapshot) && String.eq(owner,source) && String.eq(accepted,"1"),
          "archive_corrupt: latest snapshot belongs to another source or is unaccepted")
        origin : Maybe<&2,Meta.Origin> <- Meta.read(db,snapshot,True{})
        old_origin(db,file,provider,source,container,path,observe,origin)
    case _: IO.die(String,2,"archive_corrupt: latest source binding is invalid")

def captured(+db: U32,provider: String,+source: String,+path: String,size: U32,
  observe: Store.ImportObserver,result: File & List<&2,List<&2,U32>>) -> IO(String):
  (file,+chunks) = result
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT s.latest,p.id,g.source,p.accepted FROM sources s LEFT JOIN snapshots p ON p.id=s.latest LEFT JOIN generations g ON g.id=p.generation WHERE s.id=?",
      [Sql.Cell.Integer{source}],1)
    previous(db,file,provider,source,Captured{chunks,size,Meta.digest_chunks(chunks)},path,observe,rows)

def sized(+db: U32,+provider: String,+path: String,observe: Store.ImportObserver,
  result: File & Result<&1,&1,U32 & String,U32>) -> IO(String):
  (file,size_result) = result
  do IO<String>:
    +size : U32 <- IO.try(U32,IO.pure(Result<&1,&1,U32 & String,U32>,size_result))
    Store.checked(U32.is_gt(size,0),"archive_corrupt: empty compressed source")
    Store.checked(U32.is_le(size,Meta.input_limit()),"archive_limit: compressed source exceeds 1 MiB")
    transaction_observer : Store.ImportObserver <- Store.observe_phase(observe,Store.BeforeTransaction{})
    Store.exec(db,"BEGIN IMMEDIATE",[])
    +source : String <- Store.source(db,provider,path)
    bytes : File & List<&2,List<&2,U32>> <- read_all(17n,file,0,size,[])
    captured(db,provider,source,path,size,transaction_observer,bytes)

def import_canonical(db: U32,provider: String,+path: String,observe: Store.ImportObserver) -> IO(String):
  do IO<String>:
    file : File <- IO.try(File,File.open(path,"r"))
    size : File & Result<&1,&1,U32 & String,U32> <- File.size(file)
    sized(db,provider,path,observe,size)

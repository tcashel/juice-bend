import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./domain.bend as Domain
import ./archive_meta.bend as Meta
import ./archive_profile.bend as Profile
import ./archive_stream.bend as Streaming
import ./archive_maintenance.bend as Retained
import ./archive_compare.bend as Compare
import ./context_store.bend as ContextStore
import ./projection_seal.bend as Seal
import ./zstd/stream.bend as Decoder
import ./zstd/output.bend as Output
import ./zstd/pair.bend as Pair

# Captured metadata contains no compressed or logical byte collection.
type Captured is Data:
  Captured{extent: U32,chunks: U32,digest: String}

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

# Compare the immutable owned chunks against the live descriptor without
# retaining their predecessors. A short live source is a rewrite, not an
# excuse to skip validation of the remaining owned container.
def compared(file: File,expected: List<&2,U32>,actual: List<&2,U32>,same: Bool,
  next: File -> Bool -> IO(File & Bool)) -> IO(File & Bool):
  next(file,same && Compare.equal([expected],[actual]))

def compare_step(read: Meta.Read,file: File,+offset: U32,same: Bool,
  next: Meta.Reader -> File -> U32 -> Bool -> IO(File & Bool)) -> IO(File & Bool):
  Meta.Read{reader,bytes} = read
  match bytes:
    case None{}: IO.pure(File & Bool,(file,same))
    case Some{+chunk}:
      +length = U32.from_nat(List.length(&2,U32,chunk))
      Store.read(File & Bool,file,offset,length,
        f => actual => compared(f,chunk,actual,same,
          after => equal => next(reader,after,U32.add(offset,length),equal)))

def compare_live(fuel: Nat,+db: U32,reader: Meta.Reader,file: File,offset: U32,same: Bool) -> IO(File & Bool):
  match fuel:
    case 0n: IO.die(File & Bool,2,"archive_limit: comparison exceeded bounded chunk count")
    case 1n+rest:
      do IO<File & Bool>:
        read : Meta.Read <- Meta.next(db,reader)
        compare_step(read,file,offset,same,next => f => pos => equal => compare_live(rest,db,next,f,pos,equal))

def compare_reader(db: U32,+reader: Meta.Reader,file: File) -> IO(File & Bool):
  Meta.Reader{_,_,_,count,_,_,_,_} = reader
  compare_live(U32.to_nat(U32.inc(count)),db,reader,file,0,True{})

def revalidated(result: File & Bool,size: U32) -> IO(Unit):
  (file,equal) = result
  do IO<Unit>:
    Store.checked(equal,"archive_changed: compressed bytes changed during capture")
    final : File <- require_size(file,size)
    File.close(final)

def revalidate_opened(+db: U32,+path: String,opened: Meta.Open) -> IO(Unit):
  Meta.Open{Meta.Origin{_,_,_,_,_,_,_,+size,_,_,_},reader} = opened
  do IO<Unit>:
    resolved : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/bin/realpath",["--",path],"",8192,2000)
    canonical_stable(path,resolved)
    handle : Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    file : File <- reopened(handle)
    sized : File <- require_size(file,size)
    comparison : File & Bool <- compare_reader(db,reader,sized)
    revalidated(comparison,size)

def revalidate(+db: U32,snapshot: String,path: String,accepted: Bool) -> IO(Unit):
  do IO<Unit>:
    opened : Meta.Open <- Meta.open_reader(db,snapshot,accepted)
    revalidate_opened(db,path,opened)

def publication_gate(+db: U32,source: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    Retained.verify_owned(db,snapshot,True{})
    projection_gate(db,source,snapshot)

def unchanged_gate(+db: U32,source: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    opened : Meta.Open <- Meta.open_reader(db,snapshot,True{})
    Retained.validate_opened(db,opened)
    projection_gate(db,source,snapshot)

# The first pass stages exactly the selected physical bytes. No commit is
# possible until all later decode/hash/prefix/source checks have completed.
def stage_piece(+db: U32,+snapshot: String,+policy: Profile.Profile,file: File,+bytes: List<&2,U32>,
  +wanted: U32,+offset: U32,+ordinal: U32,hash: Domain.HashContext,
  next: File -> U32 -> U32 -> Domain.HashContext -> IO(File & Captured)) -> IO(File & Captured):
  do IO<File & Captured>:
    Store.checked(Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(wanted)),
      "archive_changed: compressed source ended before selected extent")
    Meta.stage_one(db,snapshot,policy,ordinal,offset,bytes)
    next(file,U32.add(offset,wanted),U32.inc(ordinal),Domain.hash_bytes(bytes,hash))

def stage_step(+db: U32,+snapshot: String,+policy: Profile.Profile,file: File,+size: U32,
  +offset: U32,ordinal: U32,hash: Domain.HashContext,done: Bool,
  next: File -> U32 -> U32 -> Domain.HashContext -> IO(File & Captured)) -> IO(File & Captured):
  match done:
    case True{}:
      do IO<File & Captured>:
        stable : File <- require_size(file,size)
        return (stable,Captured{size,ordinal,Domain.hash_finish(hash)})
    case False{}:
      +wanted = U32.min(65536,U32.sub(size,offset))
      Store.read(File & Captured,file,offset,wanted,
        f => bytes => stage_piece(db,snapshot,policy,f,bytes,wanted,offset,ordinal,hash,next))

def stage_file(fuel: Nat,+db: U32,+snapshot: String,+policy: Profile.Profile,file: File,+size: U32,
  +offset: U32,ordinal: U32,hash: Domain.HashContext) -> IO(File & Captured):
  match fuel:
    case 0n: IO.die(File & Captured,2,"archive_limit: compressed read budget exhausted")
    case 1n+rest:
      stage_step(db,snapshot,policy,file,size,offset,ordinal,hash,U32.is_eq(offset,size),
        f => pos => ord => state => stage_file(rest,db,snapshot,policy,f,size,pos,ord,state))

def reader(db: U32,snapshot: String,container: Captured) -> IO(Meta.Reader):
  Captured{size,count,digest} = container
  Meta.reader(db,snapshot,Profile.streaming(),size,count,digest)

type Preflight is Data:
  Preflight{db: U32,hash: Domain.HashContext,extent: U32,prefix: Maybe<&2,Retained.Logical>}

def preflight_visit(+db: U32,hash: Domain.HashContext,extent: U32,prefix: Maybe<&2,Retained.Logical>,+bytes: List<&2,U32>,
  next: Preflight -> IO(Streaming.Visitor<Preflight>)) -> IO(Streaming.Visitor<Preflight>):
  match prefix:
    case None{}: next(Preflight{db,hash,extent,None{}})
    case Some{cursor}:
      do IO<Streaming.Visitor<Preflight>>:
        checked : Retained.Logical <- Retained.logical_compare(U32.to_nat(U32.add(U32.mul(U32.from_nat(List.length(&2,U32,bytes)),2),2)),db,cursor,bytes,True{})
        next(Preflight{db,hash,extent,Some{checked}})

def preflight_consume(fuel: Nat,state: Preflight,+bytes: List<&2,U32>) -> IO(Streaming.Visitor<Preflight>):
  match fuel:
    case 0n: IO.die(Streaming.Visitor<Preflight>,2,"archive_limit: preflight visits exceeded bounded input")
    case 1n+rest:
      Preflight{db,hash,extent,prefix} = state
      preflight_visit(db,Domain.hash_bytes(bytes,hash),U32.add(extent,U32.from_nat(List.length(&2,U32,bytes))),prefix,bytes,
        next => IO.pure(Streaming.Visitor<Preflight>,Streaming.Visitor{next,state => chunk => preflight_consume(rest,state,chunk)}))

def preflight_prefix(prefix: Maybe<&2,Retained.Logical>) -> IO(Unit):
  match prefix:
    case None{}: IO.pure(Unit,Unit{})
    case Some{cursor}: Retained.logical_complete(cursor)

def preflight_done(result: Preflight & Decoder.Summary) -> IO(U32 & String):
  (Preflight{_,hash,+extent,prefix},Decoder.Summary{_,output,_}) = result
  do IO<U32 & String>:
    Store.checked(U32.is_eq(extent,output),"archive_corrupt: decoder output count differs from visited bytes")
    preflight_prefix(prefix)
    return (extent,Domain.hash_finish(hash))

def prefix_cursor(db: U32,origin: Maybe<&2,Meta.Origin>) -> IO(Maybe<&2,Retained.Logical>):
  match origin:
    case None{}: IO.pure(Maybe<&2,Retained.Logical>,None{})
    case Some{old}:
      do IO<Maybe<&2,Retained.Logical>>:
        cursor : Retained.Logical <- Retained.logical_begin(db,old)
        return Some{cursor}

def prefix_taken(expected: List<&2,U32>,input: Pair.Duo(Streaming.Cursor,List<&2,U32>),
  next: Streaming.Cursor -> IO(Unit)) -> IO(Unit):
  (cursor,actual) = input
  do IO<Unit>:
    Store.checked(Compare.equal([expected],[actual]),"archive_changed: staged compressed prefix differs from accepted container")
    next(cursor)

def prefix_read(+db: U32,read: Meta.Read,cursor: Streaming.Cursor,
  next: Meta.Reader -> Streaming.Cursor -> IO(Unit)) -> IO(Unit):
  Meta.Read{old,bytes} = read
  match bytes:
    case None{}: IO.pure(Unit,Unit{})
    case Some{+expected}:
      do IO<Unit>:
        input : Pair.Duo(Streaming.Cursor,List<&2,U32>) <- Streaming.read_exact(db,cursor,U32.from_nat(List.length(&2,U32,expected)))
        prefix_taken(expected,input,after => next(old,after))

def prefix_walk(fuel: Nat,+db: U32,old: Meta.Reader,cursor: Streaming.Cursor) -> IO(Unit):
  match fuel:
    case 0n: IO.die(Unit,2,"archive_limit: physical prefix check exceeded chunk count")
    case 1n+rest:
      do IO<Unit>:
        read : Meta.Read <- Meta.next(db,old)
        prefix_read(db,read,cursor,prior => next => prefix_walk(rest,db,prior,next))

def prefix_opened(db: U32,opened: Meta.Open,input: Meta.Reader) -> IO(Unit):
  Meta.Open{Meta.Origin{_,_,_,_,_,_,_,_,count,_,_},old} = opened
  prefix_walk(U32.to_nat(U32.inc(count)),db,old,Streaming.Cursor{input,[],0,0})

def physical_prefix(+db: U32,snapshot: String,container: Captured,previous: Maybe<&2,Meta.Origin>) -> IO(Unit):
  match previous:
    case None{}: IO.pure(Unit,Unit{})
    case Some{Meta.Origin{old,_,_,_,_,_,_,_,_,_,_}}:
      do IO<Unit>:
        opened : Meta.Open <- Meta.open_reader(db,old,True{})
        input : Meta.Reader <- reader(db,snapshot,container)
        prefix_opened(db,opened,input)

def preflight(+db: U32,+snapshot: String,+container: Captured,+previous: Maybe<&2,Meta.Origin>) -> IO(U32 & String):
  do IO<U32 & String>:
    physical_prefix(db,snapshot,container,previous)
    input : Meta.Reader <- reader(db,snapshot,container)
    prefix : Maybe<&2,Retained.Logical> <- prefix_cursor(db,previous)
    measured : Preflight & Decoder.Summary <- Streaming.run(Preflight,db,input,
      Streaming.Visitor{Preflight{db,Meta.initial_hash(),0,prefix},state => chunk => preflight_consume(67108864n,state,chunk)})
    preflight_done(measured)

type Feed is Type:
  Feed{state: Store.ImportState,tail: List<&2,U32>,length: U32,oversized: Bool,hash: Domain.HashContext}

def feed_split(state: Store.ImportState,hash: Domain.HashContext,result: Store.Split,
  next: Feed -> IO(Streaming.Visitor<Feed>)) -> IO(Streaming.Visitor<Feed>):
  Store.Split{pieces,tail,length,oversized} = result
  do IO<Streaming.Visitor<Feed>>:
    after : Store.ImportState <- Store.put_pieces(pieces,state)
    next(Feed{after,tail,length,oversized,hash})

def feed_consume(fuel: Nat,feed: Feed,+bytes: List<&2,U32>) -> IO(Streaming.Visitor<Feed>):
  match fuel:
    case 0n: IO.die(Streaming.Visitor<Feed>,2,"archive_limit: capture visits exceeded bounded input")
    case 1n+rest:
      Feed{state,tail,length,oversized,hash} = feed
      feed_split(state,Domain.hash_bytes(bytes,hash),Store.split(bytes,tail,length,oversized,[]),
        next => IO.pure(Streaming.Visitor<Feed>,Streaming.Visitor{next,state => chunk => feed_consume(rest,state,chunk)}))

def flush(state: Store.ImportState,tail: List<&2,U32>,length: U32,oversized: Bool) -> IO(Store.ImportState):
  match tail:
    case []: IO.pure(Store.ImportState,state)
    case byte <> rest: Store.put_piece(state,Store.Piece{List.reverse(&2,U32,byte <> rest),length,False{},oversized})

def feed_done(result: Feed & Decoder.Summary,expected: String) -> IO(Store.ImportState):
  (Feed{state,tail,length,oversized,hash},_) = result
  do IO<Store.ImportState>:
    Store.checked(String.eq(Domain.hash_finish(hash),expected),"archive_corrupt: decoded replay differs from measured logical commitment")
    complete : Store.ImportState <- flush(state,tail,length,oversized)
    Store.finalize_rows(complete)

def finish_ready(state: Store.ImportState,container: Captured,logical_sha: String,path: String) -> IO(String):
  Store.ImportState{+db,file,_,+source,_,+snapshot,_,_,_,_,_,_,observe,seal,contexts} = state
  Captured{size,_,sha} = container
  do IO<String>:
    Meta.seal_for(db,snapshot,Profile.streaming(),size,sha,logical_sha)
    staged : Store.ImportObserver <- Store.observe_phase(observe,Store.Staged{})
    Retained.verify_owned(db,snapshot,False{})
    revalidate(db,snapshot,path,False{})
    File.close(file)
    Store.publish(db,source,snapshot,staged,seal,contexts,publication_gate(db,source,snapshot))

def feed_measured(+db: U32,file: File,provider: String,source: String,+generation: String,+snapshot: String,
  +container: Captured,path: String,observe: Store.ImportObserver,result: U32 & String) -> IO(String):
  (+extent,+digest) = result
  do IO<String>:
    Store.exec(db,"UPDATE snapshots SET extent=? WHERE id=? AND accepted=0",
      [Sql.Cell.Integer{U32.show(extent)},Sql.Cell.Integer{snapshot}])
    contexts : ContextStore.Plan <- ContextStore.fresh(db,Store.projection_version(),generation)
    input : Meta.Reader <- reader(db,snapshot,container)
    result : Feed & Decoder.Summary <- Streaming.run(Feed,db,input,
      Streaming.Visitor{Feed{Store.ImportState{db,file,provider,source,generation,snapshot,extent,0,0,0,0,
        Store.Context{"","","",""},observe,Seal.SealReplay{},contexts},[],0,False{},Meta.initial_hash()},state => chunk => feed_consume(67108864n,state,chunk)})
    finished : Store.ImportState <- feed_done(result,digest)
    finish_ready(finished,container,digest,path)

def staged_file(+db: U32,provider: String,source: String,generation: String,+snapshot: String,path: String,
  observe: Store.ImportObserver,previous: Maybe<&2,Meta.Origin>,result: File & Captured) -> IO(String):
  (file,+container) = result
  do IO<String>:
    staged : Store.ImportObserver <- Store.observe_phase(observe,Store.ContainerStaged{})
    measured : U32 & String <- preflight(db,snapshot,container,previous)
    feed_measured(db,file,provider,source,generation,snapshot,container,path,staged,measured)

def generation(+db: U32,source: String,reuse: Maybe<&2,Meta.Origin>) -> IO(String):
  match reuse:
    case Some{Meta.Origin{_,_,identity,_,_,_,_,_,_,_,_}}: IO.pure(String,identity)
    case None{}:
      do IO<String>:
        Store.exec(db,"INSERT INTO generations(source,encoding) VALUES(?,?)",
          [Sql.Cell.Integer{source},Sql.Cell.Text{Meta.encoding()}])
        Store.last_id(db)

def create(+db: U32,file: File,provider: String,+source: String,path: String,size: U32,
  observe: Store.ImportObserver,+reuse: Maybe<&2,Meta.Origin>) -> IO(String):
  do IO<String>:
    +gen : String <- generation(db,source,reuse)
    Store.exec(db,"INSERT INTO snapshots(generation,extent) VALUES(?,0)",[Sql.Cell.Integer{gen}])
    +snapshot : String <- Store.last_id(db)
    Meta.empty_archive(db,snapshot)
    captured : File & Captured <- stage_file(1025n,db,snapshot,Profile.streaming(),file,size,0,0,Meta.initial_hash())
    staged_file(db,provider,source,gen,snapshot,path,observe,reuse,captured)

def unchanged(+db: U32,file: File,source: String,+snapshot: String,path: String,observe: Store.ImportObserver) -> IO(String):
  do IO<String>:
    revalidate(db,snapshot,path,True{})
    File.close(file)
    commit_observer : Store.ImportObserver <- Store.observe_phase(observe,Store.BeforeCommit{})
    unchanged_gate(db,source,snapshot)
    Store.exec(db,"COMMIT",[])
    finished : Store.ImportObserver <- Store.observe_phase(commit_observer,Store.Committed{})
    return snapshot

def previous_decide(same: Bool,db: U32,file: File,provider: String,source: String,path: String,size: U32,
  observe: Store.ImportObserver,origin: Meta.Origin,prefix: Bool) -> IO(String):
  match same:
    case True{}:
      Meta.Origin{snapshot,_,_,_,_,_,_,_,_,_,_} = origin
      unchanged(db,file,source,snapshot,path,observe)
    case False{}:
      create(db,file,provider,source,path,size,observe,Bool.pick(Maybe<&2,Meta.Origin>,prefix,Some{origin},None{}))

def previous_compared(db: U32,provider: String,source: String,path: String,+size: U32,
  observe: Store.ImportObserver,+origin: Meta.Origin,result: File & Bool) -> IO(String):
  Meta.Origin{_,_,_,_,_,_,_,old_size,_,_,_} = origin
  (file,+prefix) = result
  previous_decide(prefix && U32.is_eq(size,old_size),db,file,provider,source,path,size,observe,origin,prefix)

def previous_opened(+db: U32,file: File,provider: String,source: String,path: String,size: U32,
  observe: Store.ImportObserver,origin: Meta.Origin,opened: Meta.Open) -> IO(String):
  Meta.Open{_,reader} = opened
  do IO<String>:
    comparison : File & Bool <- compare_reader(db,reader,file)
    previous_compared(db,provider,source,path,size,observe,origin,comparison)

def previous_origin(+db: U32,file: File,provider: String,source: String,path: String,size: U32,
  observe: Store.ImportObserver,origin: Maybe<&2,Meta.Origin>) -> IO(String):
  match origin:
    case None{}: create(db,file,provider,source,path,size,observe,None{})
    case Some{+old}:
      Meta.Origin{snapshot,_,_,_,_,_,_,_,_,_,_} = old
      do IO<String>:
        Retained.validate_logical(db,old)
        opened : Meta.Open <- Meta.open_reader(db,snapshot,True{})
        previous_opened(db,file,provider,source,path,size,observe,old,opened)

def previous(+db: U32,file: File,provider: String,+source: String,path: String,size: U32,
  observe: Store.ImportObserver,rows: List<&2,List<&2,Sql.Cell>>) -> IO(String):
  match rows:
    case [[Sql.Cell.Null{},Sql.Cell.Null{},Sql.Cell.Null{},Sql.Cell.Null{}]]:
      create(db,file,provider,source,path,size,observe,None{})
    case [[Sql.Cell.Integer{latest},Sql.Cell.Integer{+snapshot},Sql.Cell.Integer{owner},Sql.Cell.Integer{accepted}]]:
      do IO<String>:
        Store.checked(String.eq(latest,snapshot) && String.eq(owner,source) && String.eq(accepted,"1"),
          "archive_corrupt: latest snapshot belongs to another source or is unaccepted")
        origin : Maybe<&2,Meta.Origin> <- Meta.read(db,snapshot,True{})
        previous_origin(db,file,provider,source,path,size,observe,origin)
    case _: IO.die(String,2,"archive_corrupt: latest source binding is invalid")

def sized(+db: U32,+provider: String,+path: String,observe: Store.ImportObserver,
  result: File & Result<&1,&1,U32 & String,U32>) -> IO(String):
  (file,size_result) = result
  do IO<String>:
    +size : U32 <- IO.try(U32,IO.pure(Result<&1,&1,U32 & String,U32>,size_result))
    Store.checked(U32.is_gt(size,0),"archive_corrupt: empty compressed source")
    Store.checked(U32.is_le(size,Profile.input(Profile.streaming())),"archive_limit: compressed source exceeds stream profile")
    transaction_observer : Store.ImportObserver <- Store.observe_phase(observe,Store.BeforeTransaction{})
    Store.exec(db,"BEGIN IMMEDIATE",[])
    +source : String <- Store.source(db,provider,path)
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT s.latest,p.id,g.source,p.accepted FROM sources s LEFT JOIN snapshots p ON p.id=s.latest LEFT JOIN generations g ON g.id=p.generation WHERE s.id=?",
      [Sql.Cell.Integer{source}],1)
    previous(db,file,provider,source,path,size,transaction_observer,rows)

def import_canonical(db: U32,provider: String,+path: String,observe: Store.ImportObserver) -> IO(String):
  do IO<String>:
    file : File <- IO.try(File,File.open(path,"r"))
    size : File & Result<&1,&1,U32 & String,U32> <- File.size(file)
    sized(db,provider,path,observe,size)

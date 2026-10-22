import Base
import ../src/catalog.bend as Catalog
import ../src/store.bend as Store
import ../src/sql.bend as Sql

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def line(text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"catalog-collision\",\"cwd\":\"/synthetic/catalog\",\"message\":{\"role\":\"user\",\"content\":\"" ++ text ++ "\"}}\n"

def row_at(index: Nat,rows: List<&2,List<&2,Sql.Cell>>) -> List<&2,Sql.Cell>:
  match index:
    case 0n:
      Store.first(rows)
    case 1n+rest:
      match rows:
        case []:
          []
        case row <> tail:
          row_at(rest,tail)

def typed(rows: List<&2,List<&2,Sql.Cell>>) -> Bool:
  match rows:
    case []:
      True{}
    case row <> rest:
      match row:
        case [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{generation},
          Sql.Cell.Integer{extent},Sql.Cell.Integer{records},Sql.Cell.Integer{+latest}]:
          (String.eq(latest,"0") || String.eq(latest,"1")) && typed(rest)
        case _:
          False{}

def flags(rows: List<&2,List<&2,Sql.Cell>>,+expected: String) -> Bool:
  match rows:
    case []:
      True{}
    case row <> rest:
      String.eq(Store.field(row,4n),expected) && flags(rest,expected)

def scalar(+db: U32,sql: String,args: List<&2,Sql.Cell>,expected: String,name: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,args,1)
    assert(String.eq(Store.field(Store.first(rows),0n),expected),name)

def latest_is(db: U32,snapshot: String,expected: String,name: String) -> IO(Unit):
  do IO<Unit>:
    target : String <- Catalog.latest(db,snapshot)
    assert(String.eq(target,expected),name)

def no_flags(db: U32,snapshot: String,name: String) -> IO(Unit):
  do IO<Unit>:
    +rows : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,snapshot,100,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),3n) && flags(rows,"0"),name)

def child_result(result: U32 & (String & String),expected: String,name: String) -> IO(Unit):
  (code,(out,err)) = result
  assert(U32.is_eq(code,1) && String.contains(out ++ err,expected),name)

def rejected(self: String,mode: String,snapshot: String,expected: String,name: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,[mode,snapshot],"",8192,10000))
    child_result(result,expected,name)

def pointer(+db: U32,snapshot: String,current: Sql.Cell) -> IO(Unit):
  Store.exec(db,"UPDATE sources SET latest=? WHERE id=(SELECT g.source FROM snapshots p JOIN generations g ON g.id=p.generation WHERE p.id=?)",
    [current,Sql.Cell.Integer{snapshot}])

def pagination(+db: U32,+old: String,appended: String) -> IO(Unit):
  do IO<Unit>:
    +middle : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,old,1,1)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,middle),1n) &&
      String.eq(Store.field(Store.first(middle),0n),appended),"offset selects the older appended snapshot")
    empty : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,old,0,0)
    assert(List.is_empty(&2,List<&2,Sql.Cell>,empty),"zero limit returns an empty validated page")
    exhausted : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,old,100,3)
    assert(List.is_empty(&2,List<&2,Sql.Cell>,exhausted),"offset beyond versions returns no rows")
    far : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,old,100,4294967295)
    assert(List.is_empty(&2,List<&2,Sql.Cell>,far),"maximum U32 offset remains exact and returns no rows")

def pointer_states(+db: U32,+self: String,+old: String,+rewritten: String,other: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"INSERT INTO snapshots(generation,extent,records) SELECT generation,0,0 FROM snapshots WHERE id=?",
      [Sql.Cell.Integer{old}])
    +pending : String <- Store.last_id(db)
    +accepted : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,old,100,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,accepted),3n) &&
      String.eq(Store.field(Store.first(accepted),0n),rewritten),"unaccepted staging snapshot is excluded even with a newer ID")
    latest_is(db,old,rewritten,"latest follows the accepted source pointer rather than the largest ID")
    rejected(self,"versions",pending,"snapshot is not accepted","unaccepted snapshot cannot anchor a catalog")
    pointer(db,old,Sql.Cell.Null{})
    no_flags(db,old,"saved versions remain browsable when current is absent")
    rejected(self,"latest",old,"Catalog unavailable:","absent current is an explicit navigation failure")
    pointer(db,old,Sql.Cell.Integer{"999999"})
    no_flags(db,old,"dangling current does not mark an unrelated version latest")
    rejected(self,"latest",old,"Catalog unavailable:","dangling current is not replaced with the newest version")
    pointer(db,old,Sql.Cell.Integer{other})
    no_flags(db,old,"cross-source current pointer does not leak another source into versions")
    rejected(self,"latest",old,"source identity mismatch","cross-source latest navigation is rejected")
    pointer(db,old,Sql.Cell.Integer{pending})
    no_flags(db,old,"unaccepted current pointer never marks an accepted saved version latest")
    rejected(self,"latest",old,"snapshot is not accepted","unaccepted current is not a navigation target")
    pointer(db,old,Sql.Cell.Text{"invalid"})
    rejected(self,"versions",old,"latest snapshot identity is not an integer","malformed current type fails closed")
    pointer(db,old,Sql.Cell.Integer{rewritten})
    latest_is(db,old,rewritten,"restored source pointer resolves without changing old selection")

def invalid_inputs(+self: String) -> IO(Unit):
  do IO<Unit>:
    assert(Catalog.identity_valid("9223372036854775807"),"signed SQLite maximum identity is accepted without U32 narrowing")
    assert(Bool.not(Catalog.identity_valid("9223372036854775808")),"identity above signed SQLite maximum is rejected")
    assert(Catalog.quantity_valid("0") && Catalog.quantity_valid("4294967295") &&
      Bool.not(Catalog.quantity_valid("4294967296")),"quantity bounds match exact capture U32 extents and record counts")
    rejected(self,"versions","","positive canonical SQLite integer","empty anchor fails explicitly")
    rejected(self,"latest","0","positive canonical SQLite integer","zero anchor cannot select a source")
    rejected(self,"versions","01","positive canonical SQLite integer","noncanonical leading-zero anchor is rejected")
    rejected(self,"versions","-1","positive canonical SQLite integer","negative anchor is rejected")
    rejected(self,"versions","1.0","positive canonical SQLite integer","noninteger anchor is rejected")
    rejected(self,"versions","9223372036854775808","positive canonical SQLite integer","overflowing anchor fails before SQLite binding")
    rejected(self,"versions","1 OR 1=1","positive canonical SQLite integer","SQL-shaped anchor is rejected")
    rejected(self,"versions","999999","accepted snapshot not found","missing positive anchor is explicit")
    rejected(self,"zero","999999","accepted snapshot not found","zero-limit request still validates its anchor")

def malformed_metadata(+db: U32,+self: String,+old: String,+rewritten: String) -> IO(Unit):
  do IO<Unit>:
    +saved : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT extent,records FROM snapshots WHERE id=?",[Sql.Cell.Integer{rewritten}],1)
    +extent : String = Store.field(Store.first(saved),0n)
    +records : String = Store.field(Store.first(saved),1n)
    Store.exec(db,"UPDATE snapshots SET records=-1 WHERE id=?",[Sql.Cell.Integer{rewritten}])
    rejected(self,"versions",old,"invalid extent or record count","malformed returned version count rejects the whole page")
    Store.exec(db,"UPDATE snapshots SET records=?,extent=0.5 WHERE id=?",[Sql.Cell.Integer{records},Sql.Cell.Integer{rewritten}])
    rejected(self,"latest",old,"wrong SQLite type","fractional extent cannot become a truncated navigation target")
    Store.exec(db,"UPDATE snapshots SET extent=4294967296 WHERE id=?",[Sql.Cell.Integer{rewritten}])
    rejected(self,"versions",old,"invalid extent or record count","oversized stored extent is rejected")
    Store.exec(db,"UPDATE snapshots SET extent=? WHERE id=?",[Sql.Cell.Integer{extent},Sql.Cell.Integer{rewritten}])
    latest_is(db,old,rewritten,"catalog recovers after synthetic metadata is restored")

# These extra accepted zero-byte versions are metadata-only pagination fixtures;
# real nonempty publication and retained-page behavior are tested in suite.
def empty_versions(count: Nat,+db: U32,+generation: String) -> IO(Unit):
  match count:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        Store.exec(db,"INSERT INTO snapshots(generation,extent,records,accepted) VALUES(?,0,0,1)",[Sql.Cell.Integer{generation}])
        empty_versions(rest,db,generation)

def capacity(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("catalog-empty.jsonl","w","")
    +initial : String <- Store.import_file(db,"claude","catalog-empty.jsonl")
    metadata : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT generation FROM snapshots WHERE id=?",[Sql.Cell.Integer{initial}],1)
    generation : String = Store.field(Store.first(metadata),0n)
    empty_versions(105n,db,generation)
    +page : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,initial,4294967295,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,page),100n) && flags(page,"0"),"oversized requested limit clamps to 100 and does not invent a latest flag")
    +last : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,initial,100,100)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,last),6n),"offset page reaches all remaining saved metadata rows")
    assert(String.eq(Store.field(row_at(5n,last),0n),initial),"deterministic descending IDs leave the initial version last")
    latest_is(db,initial,initial,"explicit current pointer remains authoritative when newer metadata IDs exist")

def wide_identities(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"INSERT INTO sources(id,provider,locator,latest) VALUES(4294967297,'claude','/synthetic/catalog-wide',9223372036854775807)",[])
    Store.exec(db,"INSERT INTO generations(id,source) VALUES(4294967298,4294967297)",[])
    Store.exec(db,"INSERT INTO snapshots(id,generation,extent,records,accepted) VALUES(9223372036854775807,4294967298,0,0,1)",[])
    +rows : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,"9223372036854775807",100,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),1n) &&
      String.eq(Store.field(Store.first(rows),0n),"9223372036854775807") &&
      String.eq(Store.field(Store.first(rows),1n),"4294967298") && flags(rows,"1"),"wide source, generation and snapshot identities survive exact typed lookup")
    latest_is(db,"9223372036854775807","9223372036854775807","latest preserves the complete signed 64-bit snapshot ID")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/catalog.sqlite")
    +first_line : String = line("old retained citrus")
    +second_line : String = line("appended apricot")
    +replacement : String = line("rewritten mango")
    Store.write_text("catalog-a.jsonl","w",first_line)
    +old : String <- Store.import_file(db,"claude","catalog-a.jsonl")
    +old_text : String <- Store.page(db,old,0,10)
    Store.write_text("catalog-a.jsonl","a",second_line)
    +appended : String <- Store.import_file(db,"claude","catalog-a.jsonl")
    Store.write_text("catalog-a.jsonl","w",replacement)
    +rewritten : String <- Store.import_file(db,"claude","catalog-a.jsonl")
    Store.write_text("catalog-b.jsonl","w",replacement)
    +other : String <- Store.import_file(db,"claude","catalog-b.jsonl")
    +provider_other : String <- Store.import_file(db,"codex","catalog-a.jsonl")
    +rows : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,old,100,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),3n),"one exact source includes append and rewrite versions only")
    assert(typed(rows),"every result row contains exactly five integer cells")
    assert(String.eq(Store.field(row_at(0n,rows),0n),rewritten) &&
      String.eq(Store.field(row_at(1n,rows),0n),appended) &&
      String.eq(Store.field(row_at(2n,rows),0n),old),"accepted versions are deterministically newest ID first")
    assert(String.eq(Store.field(row_at(1n,rows),1n),Store.field(row_at(2n,rows),1n)) &&
      Bool.not(String.eq(Store.field(row_at(0n,rows),1n),Store.field(row_at(2n,rows),1n))),"append retains generation while rewrite creates a distinct generation")
    assert(String.eq(Store.field(row_at(0n,rows),3n),"1") &&
      String.eq(Store.field(row_at(1n,rows),3n),"2") && String.eq(Store.field(row_at(2n,rows),3n),"1"),"physical record counts belong to each immutable snapshot")
    assert(String.eq(Store.field(row_at(0n,rows),2n),Nat.show(String.length(replacement))) &&
      String.eq(Store.field(row_at(1n,rows),2n),Nat.show(String.length(first_line ++ second_line))),"ASCII fixture extents retain exact captured byte lengths")
    assert(String.eq(Store.field(row_at(0n,rows),4n),"1") &&
      String.eq(Store.field(row_at(1n,rows),4n),"0") && String.eq(Store.field(row_at(2n,rows),4n),"0"),"latest flag marks only the accepted source pointer")
    latest_is(db,old,rewritten,"old selection can request an explicit current-version target")
    +from_latest : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,rewritten,100,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,from_latest),3n) &&
      String.eq(Store.field(row_at(2n,from_latest),0n),old),"current anchor can navigate retained old versions")
    +other_rows : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,other,100,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,other_rows),1n) &&
      String.eq(Store.field(Store.first(other_rows),0n),other),"colliding session identity in another locator remains a separate source")
    +provider_rows : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,provider_other,100,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,provider_rows),1n) &&
      String.eq(Store.field(Store.first(provider_rows),0n),provider_other),"same locator under another provider remains a separate source")
    pagination(db,old,appended)
    pointer_states(db,self,old,rewritten,other)
    invalid_inputs(self)
    malformed_metadata(db,self,old,rewritten)
    retained : String <- Store.page(db,old,0,10)
    assert(String.eq(retained,old_text),"catalog operations and explicit latest navigation preserve the selected old transcript")
    scalar(db,"SELECT s.latest FROM sources s JOIN generations g ON g.source=s.id JOIN snapshots p ON p.generation=g.id WHERE p.id=?",
      [Sql.Cell.Integer{old}],rewritten,"catalog reads leave the stored current pointer unchanged")
    capacity(db)
    wide_identities(db)
    IO.try(Unit,Sql.close(db))

def child_query(db: U32,mode: String,snapshot: String) -> IO(Unit):
  match mode:
    case "versions":
      do IO<Unit>:
        rows : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,snapshot,100,0)
        IO.die(Unit,3,"UNEXPECTED catalog version query succeeded")
    case "zero":
      do IO<Unit>:
        rows : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,snapshot,0,0)
        IO.die(Unit,3,"UNEXPECTED zero-limit catalog query succeeded")
    case "latest":
      do IO<Unit>:
        target : String <- Catalog.latest(db,snapshot)
        IO.die(Unit,3,"UNEXPECTED catalog latest query succeeded")
    case _:
      IO.die(Unit,2,"Unknown catalog test mode")

def child(mode: String,snapshot: String) -> IO(Unit):
  do IO<Unit>:
    db : U32 <- Store.open(".build/catalog.sqlite")
    child_query(db,mode,snapshot)

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case Con{self,Nil{}}:
      suite(self)
    case Con{self,Con{mode,Con{snapshot,Nil{}}}}:
      child(mode,snapshot)
    case _:
      IO.die(Unit,2,"Catalog test expects zero or two arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)

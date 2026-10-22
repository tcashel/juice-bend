import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./provenance.bend as Provenance

# Catalog metadata is not a transcript-integrity verdict. Opening a returned
# snapshot must still use the ordinary retained-record verifier. This module
# reads SQLite only and never changes a selected snapshot or source pointer.
type Entry is Data:
  Entry{snapshot: String,generation: String,extent: String,records: String,
    source: String,current: Maybe<&2,String>}

def identity_valid(+value: String) -> Bool:
  Provenance.decimal_valid(value) && Bool.not(String.eq(value,"0")) &&
    Bool.not(Cmp.is_gt(Provenance.decimal_compare(value,"9223372036854775807")))

def quantity_valid(+value: String) -> Bool:
  Provenance.decimal_valid(value) &&
    Bool.not(Cmp.is_gt(Provenance.decimal_compare(value,"4294967295")))

def current_value(value: Sql.Cell) -> IO(Maybe<&2,String>):
  match value:
    case Sql.Cell.Null{}:
      IO.pure(Maybe<&2,String>,None{})
    case Sql.Cell.Integer{+snapshot}:
      do IO<Maybe<&2,String>>:
        Store.checked(identity_valid(snapshot),"Catalog unavailable: invalid latest snapshot identity")
        return Some{snapshot}
    case _:
      IO.die(Maybe<&2,String>,1,"Catalog unavailable: latest snapshot identity is not an integer")

def entry(row: List<&2,Sql.Cell>,+expected_source: String) -> IO(Entry):
  match row:
    case [Sql.Cell.Integer{+snapshot},Sql.Cell.Integer{+generation},
      Sql.Cell.Integer{+extent},Sql.Cell.Integer{+records},Sql.Cell.Integer{accepted},
      Sql.Cell.Integer{generation_id},Sql.Cell.Integer{+source},
      Sql.Cell.Integer{source_id},current]:
      do IO<Entry>:
        Store.checked(identity_valid(snapshot) && identity_valid(generation) && identity_valid(source),
          "Catalog unavailable: invalid stored snapshot, generation or source identity")
        Store.checked(String.eq(generation,generation_id) && String.eq(source,source_id) &&
          (String.is_empty(expected_source) || String.eq(source,expected_source)),
          "Catalog unavailable: source identity mismatch")
        Store.checked(String.eq(accepted,"1"),"Catalog unavailable: snapshot is not accepted")
        Store.checked(quantity_valid(extent) && quantity_valid(records),
          "Catalog unavailable: invalid extent or record count")
        latest : Maybe<&2,String> <- current_value(current)
        return Entry{snapshot,generation,extent,records,source,latest}
    case _:
      IO.die(Entry,1,"Catalog unavailable: snapshot metadata or identity is missing or has the wrong SQLite type")

def one(rows: List<&2,List<&2,Sql.Cell>>,source: String) -> IO(Entry):
  match rows:
    case [row]:
      entry(row,source)
    case _:
      IO.die(Entry,1,"Catalog unavailable: accepted snapshot not found")

def anchor(+db: U32,+snapshot: String) -> IO(Entry):
  do IO<Entry>:
    Store.checked(identity_valid(snapshot),"Catalog unavailable: snapshot must be a positive canonical SQLite integer")
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT p.id,p.generation,p.extent,p.records,p.accepted,g.id,g.source,s.id,s.latest FROM snapshots p LEFT JOIN generations g ON g.id=p.generation LEFT JOIN sources s ON s.id=g.source WHERE p.id=?",
      [Sql.Cell.Integer{snapshot}],1)
    one(rows,"")

def source_of(value: Entry) -> String:
  Entry{snapshot,generation,extent,records,source,current} = value
  source

def current_matches(current: Maybe<&2,String>,snapshot: String) -> Bool:
  match current:
    case None{}:
      False{}
    case Some{latest}:
      String.eq(latest,snapshot)

def cells(value: Entry) -> List<&2,Sql.Cell>:
  Entry{+snapshot,generation,extent,records,source,current} = value
  [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{generation},Sql.Cell.Integer{extent},
    Sql.Cell.Integer{records},Sql.Cell.Integer{Bool.pick(String,current_matches(current,snapshot),"1","0")}]

def checked_rows(rows: List<&2,List<&2,Sql.Cell>>,+source: String) ->
  IO(List<&2,List<&2,Sql.Cell>>):
  match rows:
    case []:
      IO.pure(List<&2,List<&2,Sql.Cell>>,[])
    case row <> rest:
      do IO<List<&2,List<&2,Sql.Cell>>>:
        value : Entry <- entry(row,source)
        tail : List<&2,List<&2,Sql.Cell>> <- checked_rows(rest,source)
        return cells(value) <> tail

# Exactly five integer cells per row: snapshot, generation, extent, records,
# is_latest. Limit is clamped to100; zero is an empty page after validating the
# anchor. Offset is an exact U32. Accepted versions span this one source's
# generations, never another locator or provider with a colliding session ID.
def versions(+db: U32,snapshot: String,limit: U32,offset: U32) ->
  IO(List<&2,List<&2,Sql.Cell>>):
  do IO<List<&2,List<&2,Sql.Cell>>>:
    chosen : Entry <- anchor(db,snapshot)
    +source : String = source_of(chosen)
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT p.id,p.generation,p.extent,p.records,p.accepted,g.id,g.source,s.id,s.latest FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE g.source=? AND p.accepted=1 ORDER BY p.id DESC LIMIT ? OFFSET ?",
      [Sql.Cell.Integer{source},Sql.Cell.Integer{U32.show(U32.min(limit,100))},
       Sql.Cell.Integer{U32.show(offset)}],100)
    checked_rows(rows,source)

def latest_entry(value: Entry) -> IO(String):
  Entry{+snapshot,generation,extent,records,source,current} = value
  do IO<String>:
    Store.checked(current_matches(current,snapshot),"Catalog unavailable: accepted current snapshot is missing")
    return snapshot

# Return an explicit navigation target, without changing any selection or
# stored pointer. NULL, dangling, unaccepted and cross-source latest pointers
# are errors; the newest numerical ID is never substituted for latest.
def latest(+db: U32,snapshot: String) -> IO(String):
  do IO<String>:
    chosen : Entry <- anchor(db,snapshot)
    +source : String = source_of(chosen)
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT p.id,p.generation,p.extent,p.records,p.accepted,g.id,g.source,s.id,s.latest FROM sources s LEFT JOIN snapshots p ON p.id=s.latest LEFT JOIN generations g ON g.id=p.generation WHERE s.id=?",
      [Sql.Cell.Integer{source}],1)
    current : Entry <- one(rows,source)
    latest_entry(current)

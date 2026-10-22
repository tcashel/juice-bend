import Base
import ./atif_types.bend as T
import ./atif_format.bend as F
import ./providers.bend as P
import ./store.bend as S
import ./sql.bend as Sql
import ./json.bend as J
import ./domain.bend as D

# Only private connection-local TEMP state is written, inside the exporter's
# owned transaction. ROLLBACK removes the table and index before publication.
# SQLite matches exact BINARY strings; no JSON interpretation or provider logic
# is delegated to SQL.
def initialize(+db: U32) -> IO(Unit):
  do IO<Unit>:
    +mode : List<&2,List<&2,Sql.Cell>> <- S.q(db,"PRAGMA temp_store",[],1)
    compile : List<&2,List<&2,Sql.Cell>> <- S.q(db,"SELECT count(*) FROM pragma_compile_options WHERE compile_options IN ('TEMP_STORE=0','TEMP_STORE=1')",[],1)
    S.checked((String.eq(S.field(S.first(mode),0n),"0") || String.eq(S.field(S.first(mode),0n),"1")) && String.eq(S.field(S.first(compile),0n),"1"),
      "ATIF requires verified disk-backed SQLite TEMP staging; unsupported TEMP capabilities are refused")
    S.exec(db,"CREATE TEMP TABLE jb_atif_events_v1 (id INTEGER PRIMARY KEY,record INTEGER NOT NULL,slot INTEGER NOT NULL,offset INTEGER NOT NULL,n INTEGER NOT NULL,digest TEXT NOT NULL,complete INTEGER NOT NULL,oversized INTEGER NOT NULL,recorded TEXT NOT NULL,role TEXT NOT NULL,body TEXT NOT NULL,tool TEXT NOT NULL,call_id TEXT NOT NULL,args TEXT NOT NULL,result TEXT NOT NULL,repository TEXT NOT NULL,session TEXT NOT NULL,stamp TEXT NOT NULL,model TEXT NOT NULL,usage TEXT NOT NULL,parent TEXT NOT NULL,coverage TEXT NOT NULL,kind INTEGER NOT NULL)",[])
    S.exec(db,"CREATE INDEX temp.jb_atif_pairs_v1 ON jb_atif_events_v1(session,call_id,kind,id)",[])

def kind(value: P.Record) -> U32:
  P.ProviderEvent{role,_,tool,_,_,_,_,_,_,_,_,_,_} = value
  Bool.pick(U32,Bool.not(String.is_empty(tool)),1,Bool.pick(U32,String.eq(role,"tool"),2,0))

def recorded(value: P.Record) -> String:
  P.ProviderEvent{_,_,_,_,_,_,repo,session,stamp,model,_,parent,coverage} = value
  "{\"repository\":" ++ J.quote(repo) ++ ",\"session\":" ++ J.quote(session) ++
    ",\"timestamp\":" ++ J.quote(stamp) ++ ",\"model\":" ++ J.quote(model) ++
    ",\"parent\":" ++ J.quote(parent) ++ ",\"coverage\":" ++ J.quote(coverage) ++ "}"

def cells(event: T.AtifEvent) -> List<&2,Sql.Cell>:
  T.AtifEvent{number,record,slot,offset,length,digest,complete,oversized,metadata,
    +value} = event
  P.ProviderEvent{role,body,tool,call,args,result,repo,session,stamp,model,usage,parent,coverage} = value
  [Sql.Cell.Integer{U32.show(number)},Sql.Cell.Integer{U32.show(record)},Sql.Cell.Integer{U32.show(slot)},
    Sql.Cell.Integer{U32.show(offset)},Sql.Cell.Integer{U32.show(length)},Sql.Cell.Text{digest},
    Sql.Cell.Integer{Bool.pick(String,complete,"1","0")},Sql.Cell.Integer{Bool.pick(String,oversized,"1","0")},
    Sql.Cell.Text{metadata},Sql.Cell.Text{role},Sql.Cell.Text{body},Sql.Cell.Text{tool},Sql.Cell.Text{call},
    Sql.Cell.Text{args},Sql.Cell.Text{result},Sql.Cell.Text{repo},Sql.Cell.Text{session},Sql.Cell.Text{stamp},
    Sql.Cell.Text{model},Sql.Cell.Text{usage},Sql.Cell.Text{parent},Sql.Cell.Text{coverage},Sql.Cell.Integer{U32.show(kind(value))}]

def cell_size(value: Sql.Cell) -> U32:
  match value:
    case Sql.Cell.Text{text}: U32.from_nat(List.length(&2,U32,D.encode(text)))
    case _: 32

def size(values: List<&2,Sql.Cell>) -> U32:
  match values:
    case []: 0
    case first <> rest: U32.add(cell_size(first),size(rest))

def insert(+db: U32,+event: T.AtifEvent,+prior: U32,+limit: U32) -> IO(U32):
  +args = cells(event)
  +bytes = size(args)
  do IO<U32>:
    S.checked(U32.is_le(bytes,2097152) && U32.is_le(prior,limit) && U32.is_le(bytes,U32.sub(limit,prior)),
      "ATIF staging payload exceeds its supported envelope")
    S.exec(db,"INSERT INTO temp.jb_atif_events_v1 VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",args)
    return U32.add(prior,bytes)

def event(+row: List<&2,Sql.Cell>) -> T.AtifEvent:
  T.AtifEvent{S.number(S.field(row,0n)),S.number(S.field(row,1n)),S.number(S.field(row,2n)),
    S.number(S.field(row,3n)),S.number(S.field(row,4n)),S.field(row,5n),String.eq(S.field(row,6n),"1"),
    String.eq(S.field(row,7n),"1"),S.field(row,8n),
    P.ProviderEvent{S.field(row,9n),S.field(row,10n),S.field(row,11n),S.field(row,12n),S.field(row,13n),
      S.field(row,14n),S.field(row,15n),S.field(row,16n),S.field(row,17n),S.field(row,18n),S.field(row,19n),S.field(row,20n),S.field(row,21n)}}

def read(+db: U32,number: U32) -> IO(T.AtifEvent):
  do IO<T.AtifEvent>:
    +rows : List<&2,List<&2,Sql.Cell>> <- S.q(db,"SELECT * FROM temp.jb_atif_events_v1 WHERE id=?",[Sql.Cell.Integer{U32.show(number)}],1)
    S.checked(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),1n),"ATIF staging row missing")
    return event(S.first(rows))

# Pair only a unique call and unique later result in the same nonempty retained
# session. Exact original positions/IDs stay in both events' metadata.
type Match is Data:
  Match{other: Maybe<&2,T.AtifEvent>,skip: Bool,status: String}

def pair_unique(unique: Bool,db: U32,kind: U32,result: U32) -> IO(Match):
  match unique kind:
    case True{} 1:
      do IO<Match>:
        event : T.AtifEvent <- read(db,result)
        return Match{Some{event},False{},"unique-pair"}
    case True{} 2:
      IO.pure(Match,Match{None{},True{},"represented in unique call step; original chronology retained"})
    case _ _:
      IO.pure(Match,Match{None{},False{},"unpaired: missing, duplicate or non-later call/result; no authored chronology inferred"})

def pair_rows(rows: List<&2,List<&2,Sql.Cell>>,db: U32,kind: U32) -> IO(Match):
  match rows:
    case [[Sql.Cell.Integer{call},Sql.Cell.Integer{"1"}],[Sql.Cell.Integer{+result},Sql.Cell.Integer{"2"}]]:
      pair_unique(U32.is_gt(S.number(result),S.number(call)),db,kind,S.number(result))
    case _: pair_unique(False{},db,kind,0)

def key_ready(missing: Bool,+db: U32,kind: U32,session: String,call: String) -> IO(Match):
  match missing:
    case True{}: IO.pure(Match,Match{None{},False{},"unpaired: retained session or provider call ID absent"})
    case False{}:
      do IO<Match>:
        rows : List<&2,List<&2,Sql.Cell>> <- S.q(db,
          "SELECT id,kind FROM temp.jb_atif_events_v1 WHERE session=? AND call_id=? AND kind IN (1,2) ORDER BY kind,id LIMIT 3",
          [Sql.Cell.Text{session},Sql.Cell.Text{call}],3)
        pair_rows(rows,db,kind)

def pair_key(db: U32,kind: U32,+session: String,+call: String) -> IO(Match):
  key_ready(String.is_empty(session) || String.is_empty(call),db,kind,session,call)

def ordinary(event: T.AtifEvent) -> Match:
  T.AtifEvent{_,_,_,_,_,_,_,_,_,P.ProviderEvent{_,_,_,call,_,_,_,_,_,_,_,_,_}} = event
  Match{None{},False{},Bool.pick(String,String.is_empty(call),"not a tool call/result","unmapped tool call: function name missing; original provider ID and arguments retained")}

def pair_kind(kind: U32,db: U32,event: T.AtifEvent) -> IO(Match):
  match kind:
    case 0: IO.pure(Match,ordinary(event))
    case _:
      T.AtifEvent{number,_,_,_,_,_,_,_,_,P.ProviderEvent{_,_,_,call,_,_,_,session,_,_,_,_,_}} = event
      pair_key(db,kind,session,call)

def pair(db: U32,+event: T.AtifEvent) -> IO(Match):
  T.AtifEvent{_,_,_,_,_,_,_,_,_,value} = event
  pair_kind(kind(value),db,event)

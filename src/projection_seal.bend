import Base
import ./sql.bend as Sql
import ./domain.bend as Domain
import ./json.bend as Json

# Codec for the existing snapshot-owned event projection. This module does not
# change parser/context versions, schema, raw ownership or search. A reusable
# prefix is valid only after a caller has scanned ALL actual old events and
# compared the complete envelope, inside its current write transaction.
type Header is Data:
  Header{snapshot: String, source: String, generation: String, provider: String,
    locator: String, extent: U32, records: U32, checkpoint: U32,
    checkpoint_ordinal: U32}

type EventKey is Data:
  EventKey{ordinal: U32, event: U32}

type Scan is Data:
  Scan{chain: String, count: Nat, checkpoint_chain: String,
    checkpoint_count: Nat, last: Maybe<&2,EventKey>}

type Envelope is Data:
  Envelope{checkpoint_count: Nat, checkpoint_chain: String, count: Nat,
    chain: String, commitment: String}

def format() -> String:
  "event-seal-v1"

def version(parser: String) -> String:
  parser ++ "|" ++ format()

def digits(value: String) -> Bool:
  match value:
    case SNil{}:
      True{}
    case SCon{+head,tail}:
      Char.is_digit(head) && digits(tail)

def decimal(+value: String) -> Bool:
  match value:
    case "0":
      True{}
    case SCon{+head,tail}:
      Char.is_digit(head) && U32.is_ne(Char.to_u32(head),48) && digits(tail)
    case _:
      False{}

def signed_count(+value: String) -> Bool:
  decimal(value) &&
    (Nat.is_lt(String.length(value),19n) ||
      (Nat.is_eq(String.length(value),19n) &&
        Bool.not(Cmp.is_gt(String.order(value,"9223372036854775807")))))

def identity(+value: String) -> Bool:
  signed_count(value) && Bool.not(String.eq(value,"0"))

def header_valid(h: Header) -> Bool:
  Header{snapshot,source,generation,provider,locator,+extent,+records,+checkpoint,+ordinal} = h
  identity(snapshot) && identity(source) && identity(generation) &&
    U32.is_le(checkpoint,extent) && U32.is_le(ordinal,records) &&
    (U32.is_ne(ordinal,0) || U32.is_eq(checkpoint,0)) &&
    (U32.is_ne(records,0) || (U32.is_eq(extent,0) && U32.is_eq(checkpoint,0)))

def header_cells(h: Header) -> List<&2,Sql.Cell>:
  Header{snapshot,source,generation,provider,locator,extent,records,checkpoint,ordinal} = h
  [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{source},Sql.Cell.Integer{generation},
   Sql.Cell.Text{provider},Sql.Cell.Text{locator},Sql.Cell.Integer{U32.show(extent)},
   Sql.Cell.Integer{U32.show(records)},Sql.Cell.Integer{U32.show(checkpoint)},
   Sql.Cell.Integer{U32.show(ordinal)}]

# Input Text comes from the strict SQLite boundary or the provider parser.
# Both reject invalid Unicode scalars. Quotes/escapes remain explicit data;
# colon and pipe inside a quoted field cannot alter the typed field framing.
def encoded_cell(value: Sql.Cell) -> String:
  match value:
    case Sql.Cell.Integer{number}:
      "integer:" ++ Json.quote(number)
    case Sql.Cell.Text{text}:
      "text:" ++ Json.quote(text)
    case _:
      "invalid"

def encoded(cells: List<&2,Sql.Cell>) -> String:
  match cells:
    case []:
      ""
    case head <> tail:
      encoded_cell(head) ++ ":" ++ encoded(tail)

# Keep encoded/encoded_cell above unchanged as the historical scalar codec.
# These suffix constructors emit the SAME preimage directly as UTF-8 bytes.
# Every recursive step consumes one scalar/cell and attaches a fixed-size
# prefix to its suffix; no append traverses an already-built prefix or suffix.
# Scalar validity and SQLite storage classes retain their existing callers.
def text_bytes_onto(text: String,tail: List<&2,U32>) -> List<&2,U32>:
  match text:
    case SNil{}:
      tail
    case SCon{Chr{+cp},rest}:
      Domain.encode_scalar(cp,text_bytes_onto(rest,tail),Domain.encode_width(cp))

def escape_hex_byte(+value: U32) -> U32:
  Bool.pick(U32,U32.is_lt(value,10),U32.add(value,48),U32.add(value,87))

def escaped_other_onto(+cp: U32,tail: List<&2,U32>,control: Bool) -> List<&2,U32>:
  match control:
    case True{}:
      92 <> 117 <> 48 <> 48 <> escape_hex_byte(U32.div(cp,16)) <>
        escape_hex_byte(U32.mod(cp,16)) <> tail
    case False{}:
      Domain.encode_scalar(cp,tail,Domain.encode_width(cp))

def escaped_scalar_onto(+cp: U32,tail: List<&2,U32>) -> List<&2,U32>:
  match cp:
    case 34:
      92 <> 34 <> tail
    case 92:
      92 <> 92 <> tail
    case _:
      escaped_other_onto(cp,tail,U32.is_lt(cp,32))

def escaped_bytes_onto(text: String,tail: List<&2,U32>) -> List<&2,U32>:
  match text:
    case SNil{}:
      tail
    case SCon{Chr{cp},rest}:
      escaped_scalar_onto(cp,escaped_bytes_onto(rest,tail))

def quoted_bytes_onto(text: String,tail: List<&2,U32>) -> List<&2,U32>:
  34 <> escaped_bytes_onto(text,34 <> tail)

def cell_bytes_onto(value: Sql.Cell,tail: List<&2,U32>) -> List<&2,U32>:
  match value:
    case Sql.Cell.Integer{number}:
      text_bytes_onto("integer:",quoted_bytes_onto(number,tail))
    case Sql.Cell.Text{text}:
      text_bytes_onto("text:",quoted_bytes_onto(text,tail))
    case _:
      text_bytes_onto("invalid",tail)

def encoded_bytes_onto(cells: List<&2,Sql.Cell>,tail: List<&2,U32>) -> List<&2,U32>:
  match cells:
    case []:
      tail
    case head <> rest:
      cell_bytes_onto(head,58 <> encoded_bytes_onto(rest,tail))

def preimage_bytes(domain: String,cells: List<&2,Sql.Cell>) -> List<&2,U32>:
  text_bytes_onto(format(),124 <> text_bytes_onto(domain,124 <> encoded_bytes_onto(cells,[])))

def digest(domain: String,cells: List<&2,Sql.Cell>) -> String:
  Domain.digest(preimage_bytes(domain,cells))

def seed(parser: String) -> String:
  digest("seed",[Sql.Cell.Text{parser}])

def start(parser: String) -> Scan:
  +root = seed(parser)
  Scan{root,0n,root,0n,None{}}

# This function alone does not authenticate a prefix. Integration may call it
# only with values derived by a successful whole-envelope verification in the
# same write transaction; persisted checkpoint roots are never sufficient.
def resume(+chain: String,+count: Nat) -> Scan:
  Scan{chain,count,chain,count,None{}}

# Event counts are capped at U32_MAX before increment or decoding. Identity
# strings retain the full signed64 range and are never converted to native Nat.
def maximum_count() -> Nat:
  4294967295n

def text_fields(count: Nat,cells: List<&2,Sql.Cell>) -> Bool:
  match count cells:
    case 0n Nil{}:
      True{}
    case 1n+rest Con{Sql.Cell.Text{_},tail}:
      text_fields(rest,tail)
    case _ _:
      False{}

def bounded_parsed(value: String,parsed: Maybe<&2,U32>) -> Bool:
  match parsed:
    case Some{n}:
      String.eq(U32.show(n),value)
    case None{}:
      False{}

def bounded(+value: String) -> Bool:
  bounded_parsed(value,Domain.parse_u32(value))

def parsed_number(parsed: Maybe<&2,U32>) -> U32:
  match parsed:
    case Some{n}:
      n
    case None{}:
      0

def number(value: String) -> U32:
  parsed_number(Domain.parse_u32(value))

def ordered(last: Maybe<&2,EventKey>,+ordinal: U32,+event: U32) -> Bool:
  match last:
    case None{}:
      U32.is_eq(event,0)
    case Some{EventKey{+previous,+index}}:
      (U32.is_gt(ordinal,previous) && U32.is_eq(event,0)) ||
        (U32.is_eq(ordinal,previous) && U32.is_lt(index,4294967295) &&
          U32.is_eq(event,U32.add(index,1)))

def push_valid(row: List<&2,Sql.Cell>,state: Scan,+ordinal: U32,event: U32,
  +checkpoint: U32) -> Maybe<&2,Scan>:
  Scan{chain,count,checkpoint_chain,checkpoint_count,_} = state
  +next = digest("event",Sql.Cell.Text{chain} <> row)
  +total = Nat.add(count,1n)
  Some{Scan{next,total,
    Bool.pick(String,U32.is_lt(ordinal,checkpoint),next,checkpoint_chain),
    Bool.pick(Nat,U32.is_lt(ordinal,checkpoint),total,checkpoint_count),
    Some{EventKey{ordinal,event}}}}

def pushed(row: List<&2,Sql.Cell>,state: Scan,ordinal: U32,event: U32,
  checkpoint: U32,valid: Bool) -> Maybe<&2,Scan>:
  match valid:
    case False{}:
      None{}
    case True{}:
      push_valid(row,state,ordinal,event,checkpoint)

def push_fields(h: Header,floor: U32,+ordinal: String,+event: String,
  +fields: List<&2,Sql.Cell>,+state: Scan) -> Maybe<&2,Scan>:
  Header{_,_,_,_,_,_,records,_,checkpoint} = h
  Scan{_,count,_,_,last} = state
  pushed(Sql.Cell.Integer{ordinal} <> Sql.Cell.Integer{event} <> fields,state,
    number(ordinal),number(event),checkpoint,
    bounded(ordinal) && bounded(event) && text_fields(13n,fields) &&
    U32.is_ge(number(ordinal),floor) && U32.is_lt(number(ordinal),records) &&
    ordered(last,number(ordinal),number(event)) && Nat.is_lt(count,maximum_count()))

def push(h: Header,floor: U32,row: List<&2,Sql.Cell>,state: Scan) -> Maybe<&2,Scan>:
  match row:
    case Sql.Cell.Integer{ordinal} <> Sql.Cell.Integer{event} <> fields:
      push_fields(h,floor,ordinal,event,fields,state)
    case _:
      None{}

def feed_next(state: Maybe<&2,Scan>,next: Scan -> Maybe<&2,Scan>) -> Maybe<&2,Scan>:
  match state:
    case None{}:
      None{}
    case Some{scan}:
      next(scan)

def feed(+h: Header,+floor: U32,rows: List<&2,List<&2,Sql.Cell>>,state: Scan) -> Maybe<&2,Scan>:
  match rows:
    case []:
      Some{state}
    case row <> rest:
      feed_next(push(h,floor,row,state),scan => feed(h,floor,rest,scan))

def commitment(h: Header,parser: String,checkpoint_count: Nat,checkpoint_chain: String,
  count: Nat,chain: String) -> String:
  digest("snapshot",Sql.Cell.Text{parser} <>
    List.append(&2,Sql.Cell,header_cells(h),
      [Sql.Cell.Integer{Nat.show(checkpoint_count)},Sql.Cell.Text{checkpoint_chain},
       Sql.Cell.Integer{Nat.show(count)},Sql.Cell.Text{chain}]))

def finish(h: Header,parser: String,scan: Scan) -> Envelope:
  Scan{+chain,+count,+checkpoint_chain,+checkpoint_count,_} = scan
  Envelope{checkpoint_count,checkpoint_chain,count,chain,
    commitment(h,parser,checkpoint_count,checkpoint_chain,count,chain)}

def encode(envelope: Envelope) -> String:
  Envelope{checkpoint_count,checkpoint_chain,count,chain,commitment} = envelope
  format() ++ "|" ++ Nat.show(checkpoint_count) ++ "|" ++ checkpoint_chain ++ "|" ++
    Nat.show(count) ++ "|" ++ chain ++ "|" ++ commitment

def matches(h: Header,parser: String,scan: Scan,stored: String) -> Bool:
  String.eq(encode(finish(h,parser,scan)),stored)

def hex_char(+value: U32) -> Bool:
  (U32.is_ge(value,48) && U32.is_le(value,57)) ||
    (U32.is_ge(value,97) && U32.is_le(value,102))

def hex_chars(value: String) -> Bool:
  match value:
    case SNil{}:
      True{}
    case SCon{Chr{head},tail}:
      hex_char(head) && hex_chars(tail)

def hash_valid(+value: String) -> Bool:
  Nat.is_eq(String.length(value),64n) && hex_chars(value)

def natural(value: String,acc: Nat) -> Nat:
  match value:
    case SNil{}:
      acc
    case SCon{Chr{head},tail}:
      natural(tail,Nat.add(Nat.mul(acc,10n),U32.to_nat(U32.sub(head,48))))

def decode_counts(checkpoint_count: Nat,checkpoint_chain: String,count: Nat,
  chain: String,commitment: String,valid: Bool) -> Maybe<&2,Envelope>:
  match valid:
    case False{}:
      None{}
    case True{}:
      Some{Envelope{checkpoint_count,checkpoint_chain,count,chain,commitment}}

def decode_valid(checkpoint_count: String,checkpoint_chain: String,count: String,
  chain: String,commitment: String,valid: Bool) -> Maybe<&2,Envelope>:
  match valid:
    case False{}:
      None{}
    case True{}:
      +prefix = natural(checkpoint_count,0n)
      +total = natural(count,0n)
      decode_counts(prefix,checkpoint_chain,total,chain,commitment,Nat.is_le(prefix,total))

def decoded(parts: List<&2,String>) -> Maybe<&2,Envelope>:
  match parts:
    case [tag,+checkpoint_count,+checkpoint_chain,+count,+chain,+commitment]:
      decode_valid(checkpoint_count,checkpoint_chain,count,chain,commitment,
        String.eq(tag,format()) && bounded(checkpoint_count) && bounded(count) &&
        hash_valid(checkpoint_chain) && hash_valid(chain) && hash_valid(commitment))
    case _:
      None{}

def decode_bounded(value: String,valid: Bool) -> Maybe<&2,Envelope>:
  match valid:
    case False{}:
      None{}
    case True{}:
      decoded(String.split(value,'|'))

def decode(+value: String) -> Maybe<&2,Envelope>:
  decode_bounded(value,Nat.is_le(String.length(value),256n))

# This affine value is an internal operation result, not a persisted capability
# or an opaque security boundary (Bend exports constructors). Keep verification
# and consumption within one uninterrupted BEGIN IMMEDIATE. Ordinary capture
# must never modify the old snapshot. Privileged callbacks that rewrite both
# the verification anchor and copied data violate that caller contract.
type Prefix is Type:
  Prefix{connection: U32, parser: String, header: Header, chain: String,
    count: Nat, reusable: Bool}

type Validation is Type:
  SealReplay{}
  SealVerified{prefix: Prefix}

def checked(ok: Bool,message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit,Unit{})
    case False{}:
      IO.die(Unit,1,"Event projection integrity: " ++ message)

def q(db: U32,statement: String,bindings: List<&2,Sql.Cell>,limit: U32) ->
  IO(List<&2,List<&2,Sql.Cell>>):
  IO.try(List<&2,List<&2,Sql.Cell>>,Sql.query(db,statement,bindings,limit))

def exec(db: U32,statement: String,bindings: List<&2,Sql.Cell>) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- q(db,statement,bindings,1)
    return Unit{}

def header_checked(h: Header,valid: Bool) -> Maybe<&2,Header>:
  match valid:
    case True{}:
      Some{h}
    case False{}:
      None{}

def header_fields(+snapshot: String,+source: String,+generation: String,provider: String,
  locator: String,+extent: String,+records: String,+checkpoint: String,+ordinal: String) -> Maybe<&2,Header>:
  +h = {Header{snapshot,source,generation,provider,locator,number(extent),number(records),
    number(checkpoint),number(ordinal)} : Header}
  header_checked(h,identity(snapshot) && identity(source) && identity(generation) &&
    bounded(extent) && bounded(records) && bounded(checkpoint) && bounded(ordinal) && header_valid(h))

def header_rows(rows: List<&2,List<&2,Sql.Cell>>) -> Maybe<&2,Header>:
  match rows:
    case [[Sql.Cell.Integer{snapshot},Sql.Cell.Integer{source},Sql.Cell.Integer{generation},
      Sql.Cell.Text{provider},Sql.Cell.Text{locator},Sql.Cell.Integer{extent},
      Sql.Cell.Integer{records},Sql.Cell.Integer{checkpoint},Sql.Cell.Integer{ordinal}]]:
      header_fields(snapshot,source,generation,provider,locator,extent,records,checkpoint,ordinal)
    case _:
      None{}

def read_header(db: U32,snapshot: String) -> IO(Maybe<&2,Header>):
  do IO<Maybe<&2,Header>>:
    rows : List<&2,List<&2,Sql.Cell>> <- q(db,
      "SELECT p.id,g.source,p.generation,s.provider,s.locator,p.extent,p.records,p.checkpoint,p.checkpoint_ordinal FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=?",
      [Sql.Cell.Integer{snapshot}],1)
    return header_rows(rows)

def required_header(result: Maybe<&2,Header>) -> IO(Header):
  match result:
    case Some{h}:
      IO.pure(Header,h)
    case None{}:
      IO.die(Header,1,"Event projection integrity: missing or invalid snapshot header")

def scalar_bit(rows: List<&2,List<&2,Sql.Cell>>) -> Bool:
  match rows:
    case [[Sql.Cell.Integer{"0"}]]:
      False{}
    case _:
      True{}

def has_triggers(db: U32) -> IO(Bool):
  do IO<Bool>:
    rows : List<&2,List<&2,Sql.Cell>> <- q(db,
      "SELECT EXISTS(SELECT 1 FROM main.sqlite_schema WHERE type='trigger') OR EXISTS(SELECT 1 FROM temp.sqlite_schema WHERE type='trigger')",[],1)
    return scalar_bit(rows)

def snapshot(h: Header) -> String:
  Header{id,_,_,_,_,_,_,_,_} = h
  id

def payload_bytes(+alias: String) -> String:
  "length(CAST(" ++ alias ++ ".role AS BLOB))+length(CAST(" ++ alias ++
  ".body AS BLOB))+length(CAST(" ++ alias ++ ".tool AS BLOB))+length(CAST(" ++ alias ++
  ".call_id AS BLOB))+length(CAST(" ++ alias ++ ".arguments AS BLOB))+length(CAST(" ++ alias ++
  ".result AS BLOB))+length(CAST(" ++ alias ++ ".repository AS BLOB))+length(CAST(" ++ alias ++
  ".session AS BLOB))+length(CAST(" ++ alias ++ ".timestamp AS BLOB))+length(CAST(" ++ alias ++
  ".model AS BLOB))+length(CAST(" ++ alias ++ ".usage AS BLOB))+length(CAST(" ++ alias ++
  ".parent AS BLOB))+length(CAST(" ++ alias ++ ".coverage AS BLOB))"

def columns() -> String:
  "ordinal,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage"

def page_first(floor: Maybe<&2,U32>) -> String & List<&2,Sql.Cell>:
  match floor:
    case None{}:
      ("",[])
    case Some{ordinal}:
      (" AND ordinal>=?",[Sql.Cell.Integer{U32.show(ordinal)}])

def page_filter(floor: Maybe<&2,U32>,last: Maybe<&2,EventKey>) -> String & List<&2,Sql.Cell>:
  match last:
    case None{}:
      page_first(floor)
    case Some{EventKey{ordinal,event}}:
      (" AND (ordinal,event)>(?,?)",[Sql.Cell.Integer{U32.show(ordinal)},Sql.Cell.Integer{U32.show(event)}])

def page_query(db: U32,id: String,filter: String & List<&2,Sql.Cell>) -> IO(List<&2,List<&2,Sql.Cell>>):
  (condition,args) = filter
  q(db,"SELECT " ++ columns() ++
    " FROM (SELECT e.*,row_number() OVER (ORDER BY ordinal,event) AS rn,sum(" ++ payload_bytes("e") ++
    "+256) OVER (ORDER BY ordinal,event) AS total_bytes FROM (SELECT * FROM events WHERE snapshot=?" ++
    condition ++ " ORDER BY ordinal,event LIMIT 64) e) WHERE total_bytes<=1048576 OR rn=1 ORDER BY ordinal,event",
    Sql.Cell.Integer{id} <> args,64)

# The first complete scan has NO lower key predicate. Negative INTEGER, REAL,
# TEXT or BLOB keys must reach the typed validator instead of falling beneath
# an invented cursor sentinel. Later cursors come only from validated rows.
def page(db: U32,h: Header,floor: Maybe<&2,U32>,state: Scan) -> IO(List<&2,List<&2,Sql.Cell>>):
  Scan{_,_,_,_,last} = state
  page_query(db,snapshot(h),page_filter(floor,last))

def floor_value(value: Maybe<&2,U32>) -> U32:
  match value:
    case None{}:
      0
    case Some{n}:
      n

def scan_next(value: Maybe<&2,Scan>,next: Scan -> IO(Maybe<&2,Scan>)) -> IO(Maybe<&2,Scan>):
  match value:
    case None{}:
      IO.pure(Maybe<&2,Scan>,None{})
    case Some{state}:
      next(state)

def scan_page(rows: List<&2,List<&2,Sql.Cell>>,h: Header,floor: U32,state: Scan,
  next: Scan -> IO(Maybe<&2,Scan>)) -> IO(Maybe<&2,Scan>):
  match rows:
    case []:
      IO.pure(Maybe<&2,Scan>,Some{state})
    case row <> rest:
      scan_next(feed(h,floor,row <> rest,state),next)

def scan_walk(fuel: Nat,+db: U32,+h: Header,+floor: Maybe<&2,U32>,+state: Scan) -> IO(Maybe<&2,Scan>):
  match fuel:
    case 0n:
      IO.die(Maybe<&2,Scan>,1,"Event projection verification budget exhausted")
    case 1n+rest:
      do IO<Maybe<&2,Scan>>:
        rows : List<&2,List<&2,Sql.Cell>> <- page(db,h,floor,state)
        scan_page(rows,h,floor_value(floor),state,
          next => scan_walk(rest,db,h,floor,next))

def prefix(db: U32,parser: String,h: Header,state: Scan,reusable: Bool) -> Prefix:
  Scan{_,_,chain,count,_} = state
  Prefix{db,parser,h,chain,count,reusable}

def verified(db: U32,parser: String,h: Header,state: Scan,reusable: Bool,valid: Bool) -> Validation:
  match valid:
    case True{}:
      SealVerified{prefix(db,parser,h,state,reusable)}
    case False{}:
      SealReplay{}

def verify_scanned(db: U32,+parser: String,+h: Header,stored: String,reusable: Bool,
  scanned: Maybe<&2,Scan>) -> Validation:
  match scanned:
    case None{}:
      SealReplay{}
    case Some{+state}:
      verified(db,parser,h,state,reusable,matches(h,parser,state,stored))

def verify_current(+db: U32,+parser: String,+h: Header,stored: String,reusable: Bool,current: Bool) -> IO(Validation):
  match current:
    case False{}:
      IO.pure(Validation,SealReplay{})
    case True{}:
      do IO<Validation>:
        scanned : Maybe<&2,Scan> <- scan_walk(4294967295n,db,h,None{},start(parser))
        return verify_scanned(db,parser,h,stored,reusable,scanned)

def verify_rows(db: U32,+parser: String,h: Header,reusable: Bool,rows: List<&2,List<&2,Sql.Cell>>) -> IO(Validation):
  match rows:
    case [[Sql.Cell.Text{tag},Sql.Cell.Text{stored}]]:
      verify_current(db,parser,h,stored,reusable,String.eq(tag,version(parser)))
    case _:
      IO.pure(Validation,SealReplay{})

def verify_header(+db: U32,parser: String,reusable: Bool,result: Maybe<&2,Header>) -> IO(Validation):
  match result:
    case None{}:
      IO.pure(Validation,SealReplay{})
    case Some{+h}:
      do IO<Validation>:
        rows : List<&2,List<&2,Sql.Cell>> <- q(db,"SELECT version,digest FROM projection_checks WHERE snapshot=?",
          [Sql.Cell.Integer{snapshot(h)}],1)
        verify_rows(db,parser,h,reusable,rows)

def verify(+db: U32,id: String,parser: String) -> IO(Validation):
  do IO<Validation>:
    triggers : Bool <- has_triggers(db)
    h : Maybe<&2,Header> <- read_header(db,id)
    verify_header(db,parser,Bool.not(triggers),h)

def is_verified(value: Validation) -> Bool:
  match value:
    case SealReplay{}:
      False{}
    case SealVerified{_}:
      True{}

def write_scanned(db: U32,+h: Header,+parser: String,result: Maybe<&2,Scan>) -> IO(Unit):
  match result:
    case None{}:
      IO.die(Unit,1,"Event projection integrity: invalid fresh event projection")
    case Some{scan}:
      exec(db,"INSERT OR REPLACE INTO projection_checks(snapshot,version,digest) VALUES(?,?,?)",
        [Sql.Cell.Integer{snapshot(h)},Sql.Cell.Text{version(parser)},Sql.Cell.Text{encode(finish(h,parser,scan))}])

def write_full_header(+db: U32,+h: Header,+parser: String) -> IO(Unit):
  do IO<Unit>:
    scanned : Maybe<&2,Scan> <- scan_walk(4294967295n,db,h,None{},start(parser))
    write_scanned(db,h,parser,scanned)

def write_full(+db: U32,id: String,parser: String) -> IO(Unit):
  do IO<Unit>:
    result : Maybe<&2,Header> <- read_header(db,id)
    h : Header <- required_header(result)
    write_full_header(db,h,parser)

def import_binding(h: Header,source: String,provider: String,generation: String,
  id: String,extent: String,checkpoint: String,ordinal: String) -> Bool:
  Header{old_id,old_source,old_generation,old_provider,_,old_extent,_,old_checkpoint,old_ordinal} = h
  String.eq(id,old_id) && String.eq(source,old_source) && String.eq(generation,old_generation) &&
    String.eq(provider,old_provider) && String.eq(extent,U32.show(old_extent)) &&
    String.eq(checkpoint,U32.show(old_checkpoint)) && String.eq(ordinal,U32.show(old_ordinal))

def require_import(db: U32,value: Prefix,source: String,provider: String,generation: String,
  id: String,extent: String,checkpoint: String,ordinal: String) -> IO(Prefix):
  Prefix{+connection,parser,+h,chain,count,reusable} = value
  do IO<Prefix>:
    checked(U32.is_eq(connection,db) &&
      import_binding(h,source,provider,generation,id,extent,checkpoint,ordinal),
      "verified prefix does not belong to the importing source or checkpoint")
    return Prefix{connection,parser,h,chain,count,reusable}

def target_matches(old: Header,target: Header) -> Bool:
  Header{old_id,source,generation,provider,locator,extent,_,checkpoint,+ordinal} = old
  Header{id,new_source,new_generation,new_provider,new_locator,new_extent,new_records,new_checkpoint,new_ordinal} = target
  Bool.not(String.eq(id,old_id)) && String.eq(source,new_source) &&
    String.eq(generation,new_generation) && String.eq(provider,new_provider) &&
    String.eq(locator,new_locator) && U32.is_ge(new_extent,extent) &&
    U32.is_ge(new_records,ordinal) && U32.is_ge(new_checkpoint,checkpoint) &&
    U32.is_ge(new_ordinal,ordinal)

def checkpoint_ordinal(h: Header) -> U32:
  Header{_,_,_,_,_,_,_,_,ordinal} = h
  ordinal

def equal_maps_step(+db: U32,+old: String,+target: String,+count: U32,+ordinal: U32,
  done: Bool,next: U32 -> IO(Unit)) -> IO(Unit):
  match done:
    case True{}:
      IO.pure(Unit,Unit{})
    case False{}:
      +stop = U32.add(ordinal,U32.min(256,U32.sub(count,ordinal)))
      do IO<Unit>:
        rows : List<&2,List<&2,Sql.Cell>> <- q(db,
          "SELECT (SELECT count(*) FROM records WHERE snapshot=? AND ordinal>=? AND ordinal<?)<>? OR (SELECT count(*) FROM records WHERE snapshot=? AND ordinal>=? AND ordinal<?)<>? OR EXISTS(SELECT 1 FROM records a LEFT JOIN records b ON b.snapshot=? AND b.ordinal=a.ordinal WHERE a.snapshot=? AND a.ordinal>=? AND a.ordinal<? AND (b.raw IS NULL OR typeof(a.ordinal)<>typeof(b.ordinal) OR typeof(a.raw)<>typeof(b.raw) OR a.raw IS NOT b.raw))",
          [Sql.Cell.Integer{old},Sql.Cell.Integer{U32.show(ordinal)},Sql.Cell.Integer{U32.show(stop)},Sql.Cell.Integer{U32.show(U32.sub(stop,ordinal))},
           Sql.Cell.Integer{target},Sql.Cell.Integer{U32.show(ordinal)},Sql.Cell.Integer{U32.show(stop)},Sql.Cell.Integer{U32.show(U32.sub(stop,ordinal))},
           Sql.Cell.Integer{target},Sql.Cell.Integer{old},Sql.Cell.Integer{U32.show(ordinal)},Sql.Cell.Integer{U32.show(stop)}],1)
        checked(Bool.not(scalar_bit(rows)),"copied raw prefix mapping differs from the verified old snapshot")
        next(stop)

def equal_maps(fuel: Nat,+db: U32,+old: String,+target: String,+count: U32,+ordinal: U32) -> IO(Unit):
  match fuel:
    case 0n:
      IO.die(Unit,1,"Copied map comparison budget exhausted")
    case 1n+rest:
      equal_maps_step(db,old,target,count,ordinal,U32.is_ge(ordinal,count),
        stop => equal_maps(rest,db,old,target,count,stop))

def compared_columns() -> List<&2,String>:
  ["ordinal","event","role","body","tool","call_id","arguments","result",
   "repository","session","timestamp","model","usage","parent","coverage"]

def unequal_columns(columns: List<&2,String>) -> String:
  match columns:
    case []:
      "0"
    case +column <> rest:
      "typeof(a." ++ column ++ ")<>typeof(b." ++ column ++ ") OR a." ++ column ++
        " IS NOT b." ++ column ++ " OR " ++ unequal_columns(rest)

def equality_page_query(db: U32,+old: String,+target: String,+stop: U32,
  filter: String & List<&2,Sql.Cell>) -> IO(List<&2,List<&2,Sql.Cell>>):
  (+condition,+args) = filter
  q(db,
    "WITH keys AS MATERIALIZED (SELECT ordinal,event FROM (SELECT ordinal,event FROM events WHERE snapshot=? AND ordinal<?" ++ condition ++
    " ORDER BY ordinal,event LIMIT 64) UNION SELECT ordinal,event FROM (SELECT ordinal,event FROM events WHERE snapshot=? AND ordinal<?" ++ condition ++
    " ORDER BY ordinal,event LIMIT 64) ORDER BY ordinal,event LIMIT 64), compared AS MATERIALIZED (SELECT k.ordinal,k.event,CASE WHEN a.rowid IS NULL OR b.rowid IS NULL OR " ++
    unequal_columns(compared_columns()) ++ " THEN 0 ELSE 1 END AS same,coalesce(" ++ payload_bytes("a") ++
    ",0)+coalesce(" ++ payload_bytes("b") ++
    ",0)+512 AS n FROM keys k LEFT JOIN events a ON a.snapshot=? AND a.ordinal=k.ordinal AND a.event=k.event LEFT JOIN events b ON b.snapshot=? AND b.ordinal=k.ordinal AND b.event=k.event), limited AS (SELECT *,row_number() OVER (ORDER BY ordinal,event) AS rn,sum(n) OVER (ORDER BY ordinal,event) AS total_bytes FROM compared) SELECT ordinal,event,same FROM limited WHERE total_bytes<=1048576 OR rn=1 ORDER BY ordinal,event",
    List.append(&2,Sql.Cell,Sql.Cell.Integer{old} <> Sql.Cell.Integer{U32.show(stop)} <> args,
      List.append(&2,Sql.Cell,Sql.Cell.Integer{target} <> Sql.Cell.Integer{U32.show(stop)} <> args,
        [Sql.Cell.Integer{old},Sql.Cell.Integer{target}])),64)

# Unioning bounded key candidates from BOTH snapshots detects additions as well
# as omissions. Payload comparison includes SQLite storage types; empty Blob,
# Text and numerically equal REAL/INTEGER values are never interchangeable.
# At most128 candidate keys precede64 payload pairs; the payload window has a
# 1MiB target with a first-row progress exception, plus the unchanged bridge cap.
def equality_page(db: U32,old: String,target: String,stop: U32,
  last: Maybe<&2,EventKey>) -> IO(List<&2,List<&2,Sql.Cell>>):
  equality_page_query(db,old,target,stop,page_filter(None{},last))

def equal_key(row: List<&2,Sql.Cell>,stop: U32) -> IO(EventKey):
  match row:
    case [Sql.Cell.Integer{+ordinal},Sql.Cell.Integer{+event},Sql.Cell.Integer{"1"}]:
      do IO<EventKey>:
        checked(bounded(ordinal) && bounded(event) && U32.is_lt(number(ordinal),stop),
          "copied event prefix has an invalid key")
        return EventKey{number(ordinal),number(event)}
    case _:
      IO.die(EventKey,1,"Event projection integrity: copied event prefix differs from the verified old snapshot")

def equal_rows(rows: List<&2,List<&2,Sql.Cell>>,+stop: U32,last: Maybe<&2,EventKey>) -> IO(Maybe<&2,EventKey>):
  match rows:
    case []:
      IO.pure(Maybe<&2,EventKey>,last)
    case row <> rest:
      do IO<Maybe<&2,EventKey>>:
        key : EventKey <- equal_key(row,stop)
        equal_rows(rest,stop,Some{key})

def equal_next(last: Maybe<&2,EventKey>,next: EventKey -> IO(Unit)) -> IO(Unit):
  match last:
    case None{}:
      IO.pure(Unit,Unit{})
    case Some{key}:
      next(key)

def equal_events(fuel: Nat,+db: U32,+old: String,+target: String,+stop: U32,
  last: Maybe<&2,EventKey>) -> IO(Unit):
  match fuel:
    case 0n:
      IO.die(Unit,1,"Copied event comparison budget exhausted")
    case 1n+rest:
      do IO<Unit>:
        rows : List<&2,List<&2,Sql.Cell>> <- equality_page(db,old,target,stop,last)
        following : Maybe<&2,EventKey> <- equal_rows(rows,stop,None{})
        equal_next(following,key => equal_events(rest,db,old,target,stop,Some{key}))

def write_extended(+db: U32,+old: Header,+target: Header,+parser: String,chain: String,count: Nat) -> IO(Unit):
  +stop = checkpoint_ordinal(old)
  do IO<Unit>:
    equal_maps(4294967295n,db,snapshot(old),snapshot(target),stop,0)
    equal_events(4294967295n,db,snapshot(old),snapshot(target),stop,None{})
    scanned : Maybe<&2,Scan> <- scan_walk(4294967295n,db,target,Some{stop},resume(chain,count))
    write_scanned(db,target,parser,scanned)

def write_mode(db: U32,old: Header,target: Header,parser: String,chain: String,count: Nat,reusable: Bool) -> IO(Unit):
  match reusable:
    case False{}:
      write_full_header(db,target,parser)
    case True{}:
      write_extended(db,old,target,parser,chain,count)

def write_prefix(+db: U32,+id: String,+parser: String,value: Prefix) -> IO(Unit):
  Prefix{connection,old_parser,+old,chain,count,reusable} = value
  do IO<Unit>:
    checked(U32.is_eq(db,connection) && String.eq(parser,old_parser),
      "verified prefix belongs to another connection or parser")
    old_result : Maybe<&2,Header> <- read_header(db,snapshot(old))
    old_current : Header <- required_header(old_result)
    checked(String.eq(encoded(header_cells(old)),encoded(header_cells(old_current))),
      "verified old snapshot header changed during capture")
    target_result : Maybe<&2,Header> <- read_header(db,id)
    +target : Header <- required_header(target_result)
    checked(target_matches(old,target),"new snapshot does not extend the verified source generation and checkpoint")
    triggers : Bool <- has_triggers(db)
    write_mode(db,old,target,parser,chain,count,reusable && Bool.not(triggers))

def write(db: U32,id: String,parser: String,plan: Validation) -> IO(Unit):
  match plan:
    case SealReplay{}:
      write_full(db,id,parser)
    case SealVerified{value}:
      write_prefix(db,id,parser,value)

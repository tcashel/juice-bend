import Base
import ./sql.bend as Sql
import ./context_binding.bend as Binding
import ./projection_seal.bend as Seal

# Transaction-local context reuse. This is not a persisted capability or an
# opaque security boundary: Bend exports constructors. Keep verification and
# consumption inside one uninterrupted BEGIN IMMEDIATE, on this connection,
# without ordinary capture writes to the old snapshot. Privileged callbacks
# that rewrite both anchors and checksums are outside the corruption boundary.
type Reuse is Type:
  Reuse.Fresh{}
  Reuse.Verified{connection: U32,header: Seal.Header,reusable: Bool}

type Plan is Type:
  Plan{prefix: Binding.Prefix,reuse: Reuse}

type Validation is Type:
  Validation.Replay{}
  Validation.Ready{plan: Plan}

def checked(ok: Bool,message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit,Unit{})
    case False{}:
      IO.die(Unit,1,"Context checkpoint integrity: " ++ message)

def prefix_required(result: Result<&2,&2,String,Binding.Prefix>) -> IO(Binding.Prefix):
  match result:
    case Done{prefix}:
      IO.pure(Binding.Prefix,prefix)
    case Fail{message}:
      IO.die(Binding.Prefix,1,"Context checkpoint integrity: " ++ message)

def digest_required(result: Result<&2,&2,String,String>) -> IO(String):
  match result:
    case Done{digest}:
      IO.pure(String,digest)
    case Fail{message}:
      IO.die(String,1,"Context checkpoint integrity: " ++ message)

def binding_required(result: Maybe<&2,Binding.Binding>) -> IO(Binding.Binding):
  match result:
    case Some{binding}:
      IO.pure(Binding.Binding,binding)
    case None{}:
      IO.die(Binding.Binding,1,"Context checkpoint integrity: invalid source or generation binding")

def generation_rows(parser: String,rows: List<&2,List<&2,Sql.Cell>>) -> IO(Binding.Binding):
  match rows:
    case [row]:
      binding_required(Binding.decode_binding(Sql.Cell.Text{parser} <> row))
    case _:
      IO.die(Binding.Binding,1,"Context checkpoint integrity: missing source or generation")

# One bounded lookup per capture/rebuild, never one lookup per context record.
def generation_binding(+db: U32,parser: String,generation: String) -> IO(Binding.Binding):
  do IO<Binding.Binding>:
    rows : List<&2,List<&2,Sql.Cell>> <- Seal.q(db,
      "SELECT s.id,s.provider,s.locator,g.id FROM generations g JOIN sources s ON s.id=g.source WHERE g.id=?",
      [Sql.Cell.Integer{generation}],1)
    generation_rows(parser,rows)

def generation_prefix(db: U32,parser: String,generation: String) -> IO(Binding.Prefix):
  do IO<Binding.Prefix>:
    binding : Binding.Binding <- generation_binding(db,parser,generation)
    prefix_required(Binding.prefix(binding))

def fresh(db: U32,parser: String,generation: String) -> IO(Plan):
  do IO<Plan>:
    prefix : Binding.Prefix <- generation_prefix(db,parser,generation)
    return Plan{prefix,Reuse.Fresh{}}

def header_binding(parser: String,header: Seal.Header) -> Binding.Binding:
  Seal.Header{_,source,generation,provider,locator,_,_,_,_} = header
  Binding.Binding{parser,source,provider,locator,generation}

def header_records(header: Seal.Header) -> U32:
  Seal.Header{_,_,_,_,_,_,records,_,_} = header
  records

def parser_of(prefix: Binding.Prefix) -> String:
  Binding.Prefix{Binding.Binding{parser,_,_,_,_},_,_} = prefix
  parser

def prefix_matches(+prefix: Binding.Prefix,header: Seal.Header) -> Bool:
  Binding.Prefix{binding,_,_} = prefix
  String.eq(Binding.encoded(Binding.binding_cells(binding)),
    Binding.encoded(Binding.binding_cells(header_binding(parser_of(prefix),header))))

def stored_cells(snapshot: String,ordinal: U32,context: Binding.Context,tag: String,digest: String) -> List<&2,Sql.Cell>:
  List.append(&2,Sql.Cell,[Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(ordinal)}],
    List.append(&2,Sql.Cell,Binding.context_cells(context),[Sql.Cell.Text{tag},Sql.Cell.Text{digest}]))

def write(+db: U32,snapshot: String,+prefix: Binding.Prefix,+raw: Binding.Raw,+context: Binding.Context) -> IO(Unit):
  Binding.Raw{_,ordinal,_,_,_} = raw
  do IO<Unit>:
    digest : String <- digest_required(Binding.digest_cached(prefix,raw,context))
    Seal.exec(db,"INSERT OR REPLACE INTO snapshot_context(snapshot,ordinal,repository,session,model,parent,version,digest) VALUES(?,?,?,?,?,?,?,?)",
      stored_cells(snapshot,ordinal,context,Binding.version_v2(parser_of(prefix)),digest))

# A scan starts without a sentinel when start=0: negative, REAL and nonnumeric
# actual keys cannot hide below a synthetic initial ordinal. Subsequent pages
# continue strictly after the preceding accepted key. Fractional keys between
# consecutive integers remain visible. Missing joined maps/raw remain visible.
# Candidate stages retain numeric keys or empty typed failure markers, plus
# independently coalesced byte lengths. REAL keys retain their exact order for
# byte-cut detection; TEXT/BLOB keys become small values of the same storage
# class, so they remain after numeric keys and still fail the typed validator.
# ORDER BY uses the actual stored key before the 128-key bound. Invalid marker
# keys never perform payload lookups, even if an actual empty-key row exists.
# Payload joins
# occur after the 1MiB counted-byte window, with first-row
# progress. Length inspection can still read an oversized value; neither this
# window nor the unchanged bridge cap is a total SQLite memory/work bound.
def context_bytes(+alias: String) -> String:
  "coalesce(length(CAST(" ++ alias ++ ".repository AS BLOB)),0)+coalesce(length(CAST(" ++ alias ++
    ".session AS BLOB)),0)+coalesce(length(CAST(" ++ alias ++ ".model AS BLOB)),0)+coalesce(length(CAST(" ++ alias ++
    ".parent AS BLOB)),0)+coalesce(length(CAST(" ++ alias ++ ".version AS BLOB)),0)+coalesce(length(CAST(" ++ alias ++ ".digest AS BLOB)),0)"

def raw_metadata_bytes() -> String:
  "coalesce(length(CAST(i.ordinal AS BLOB)),0)+coalesce(length(CAST(i.raw AS BLOB)),0)+coalesce(length(CAST(r.generation AS BLOB)),0)+coalesce(length(CAST(r.ordinal AS BLOB)),0)+coalesce(length(CAST(r.offset AS BLOB)),0)+coalesce(length(CAST(r.n AS BLOB)),0)+coalesce(length(CAST(r.digest AS BLOB)),0)"

def scan_query(db: U32,+snapshot: String,start: U32,+initial: Bool) -> IO(List<&2,List<&2,Sql.Cell>>):
  +condition = Bool.pick(String,initial,""," AND c.ordinal>?")
  +args = Bool.pick(List<&2,Sql.Cell>,initial,[Sql.Cell.Integer{snapshot}],
    [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(U32.sub(start,1))}])
  Seal.q(db,
    "WITH keys AS MATERIALIZED (SELECT CASE typeof(c.ordinal) WHEN 'integer' THEN c.ordinal WHEN 'real' THEN c.ordinal WHEN 'text' THEN '' WHEN 'blob' THEN x'' ELSE NULL END AS ordinal," ++ context_bytes("c") ++ "+" ++ raw_metadata_bytes() ++ "+512 AS n FROM snapshot_context c LEFT JOIN records i ON i.snapshot=c.snapshot AND i.ordinal=c.ordinal LEFT JOIN raw r ON r.id=i.raw WHERE c.snapshot=?" ++ condition ++ " ORDER BY c.ordinal LIMIT 128), windowed AS (SELECT ordinal,row_number() OVER (ORDER BY ordinal) AS rn,sum(n) OVER (ORDER BY ordinal) AS total_bytes FROM keys), limited AS MATERIALIZED (SELECT ordinal FROM windowed WHERE total_bytes<=1048576 OR rn=1) SELECT k.ordinal,i.ordinal,i.raw,r.generation,r.ordinal,r.offset,r.n,r.digest,c.repository,c.session,c.model,c.parent,c.version,c.digest FROM limited k LEFT JOIN snapshot_context c ON typeof(k.ordinal) IN('integer','real') AND c.snapshot=? AND c.ordinal=k.ordinal LEFT JOIN records i ON i.snapshot=c.snapshot AND i.ordinal=c.ordinal LEFT JOIN raw r ON r.id=i.raw ORDER BY k.ordinal",
    List.append(&2,Sql.Cell,args,[Sql.Cell.Integer{snapshot}]),128)

def row_decoded(prefix: Binding.Prefix,context: Binding.Context,tag: String,stored: String,
  result: Maybe<&2,Binding.Raw>) -> Bool:
  match result:
    case None{}:
      False{}
    case Some{raw}:
      Binding.verify_v2(prefix,raw,context,tag,stored)


def row_fields(+prefix: Binding.Prefix,+expected: U32,records: U32,+ordinal: String,map_ordinal: String,
  identity: String,generation: String,raw_ordinal: String,offset: String,length: String,digest: String,
  context: Binding.Context,tag: String,stored: String) -> Bool:
  Binding.Prefix{Binding.Binding{_,_,_,_,expected_generation},_,_} = prefix
  U32.is_lt(expected,records) && String.eq(ordinal,U32.show(expected)) &&
    String.eq(map_ordinal,ordinal) && String.eq(raw_ordinal,ordinal) && String.eq(generation,expected_generation) &&
    row_decoded(prefix,context,tag,stored,Binding.decode_raw([Sql.Cell.Integer{identity},Sql.Cell.Integer{ordinal},
      Sql.Cell.Integer{offset},Sql.Cell.Integer{length},Sql.Cell.Text{digest}]))


def row_matches(prefix: Binding.Prefix,expected: U32,records: U32,row: List<&2,Sql.Cell>) -> Bool:
  match row:
    case [Sql.Cell.Integer{+ordinal},Sql.Cell.Integer{map_ordinal},Sql.Cell.Integer{identity},
      Sql.Cell.Integer{generation},Sql.Cell.Integer{raw_ordinal},Sql.Cell.Integer{offset},Sql.Cell.Integer{length},
      Sql.Cell.Text{digest},Sql.Cell.Text{repository},Sql.Cell.Text{session},Sql.Cell.Text{model},Sql.Cell.Text{parent},
      Sql.Cell.Text{tag},Sql.Cell.Text{stored}]:
      row_fields(prefix,expected,records,ordinal,map_ordinal,identity,generation,raw_ordinal,
        offset,length,digest,Binding.Context{repository,session,model,parent},tag,stored)
    case _:
      False{}



def scan_rows(rows: List<&2,List<&2,Sql.Cell>>,+prefix: Binding.Prefix,+records: U32,
  +expected: U32,valid: Bool) -> Maybe<&2,U32>:
  match rows valid:
    case _ False{}:
      None{}
    case Nil{} True{}:
      Some{expected}
    case Con{row,rest} True{}:
      scan_rows(rest,prefix,records,U32.add(expected,1),row_matches(prefix,expected,records,row))

def scan_continue(rows: List<&2,List<&2,Sql.Cell>>,result: Maybe<&2,U32>,records: U32,
  next: U32 -> IO(Bool)) -> IO(Bool):
  match rows result:
    case _ None{}:
      IO.pure(Bool,False{})
    case Nil{} Some{count}:
      IO.pure(Bool,U32.is_eq(count,records))
    case Con{_,_} Some{count}:
      next(count)


def scan_walk(fuel: Nat,+db: U32,+snapshot: String,+prefix: Binding.Prefix,+records: U32,
  +expected: U32,initial: Bool) -> IO(Bool):
  match fuel:
    case 0n:
      IO.pure(Bool,False{})
    case 1n+rest:
      do IO<Bool>:
        +rows : List<&2,List<&2,Sql.Cell>> <- scan_query(db,snapshot,expected,initial)
        scan_continue(rows,scan_rows(rows,prefix,records,expected,True{}),records,
          next => scan_walk(rest,db,snapshot,prefix,records,next,False{}))


def scan(db: U32,snapshot: String,prefix: Binding.Prefix,records: U32,+start: U32) -> IO(Bool):
  scan_walk(4294967295n,db,snapshot,prefix,records,start,U32.is_eq(start,0))

def verified(db: U32,header: Seal.Header,prefix: Binding.Prefix,reusable: Bool,valid: Bool) -> IO(Validation):
  match valid:
    case False{}:
      IO.pure(Validation,Validation.Replay{})
    case True{}:
      IO.pure(Validation,Validation.Ready{Plan{prefix,Reuse.Verified{db,header,reusable}}})

# All actual current-format context rows are checked, including a discarded
# partial tail; only checkpoint_ordinal rows are witnessed for copying. A
# missing, old, malformed or damaged row conservatively requests raw replay.
def verify(+db: U32,parser: String,+header: Seal.Header) -> IO(Validation):
  do IO<Validation>:
    triggers : Bool <- Seal.has_triggers(db)
    +prefix : Binding.Prefix <- prefix_required(Binding.prefix(header_binding(parser,header)))
    valid : Bool <- scan(db,Seal.snapshot(header),prefix,header_records(header),0)
    verified(db,header,prefix,Bool.not(triggers),valid)

def copy_keys(db: U32,+snapshot: String,+ordinal: U32,+count: U32) -> IO(List<&2,List<&2,Sql.Cell>>):
  +initial = U32.is_eq(ordinal,0)
  +condition = Bool.pick(String,initial,""," AND c.ordinal>?")
  +args = Bool.pick(List<&2,Sql.Cell>,initial,
    [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(count)}],
    [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(count)},Sql.Cell.Integer{U32.show(U32.sub(ordinal,1))}])
  Seal.q(db,
    "WITH keys AS MATERIALIZED (SELECT CASE typeof(c.ordinal) WHEN 'integer' THEN c.ordinal WHEN 'real' THEN c.ordinal WHEN 'text' THEN '' WHEN 'blob' THEN x'' ELSE NULL END AS ordinal," ++ context_bytes("c") ++ "+256 AS n FROM snapshot_context c WHERE c.snapshot=? AND c.ordinal<?" ++ condition ++ " ORDER BY c.ordinal LIMIT 128), windowed AS (SELECT ordinal,row_number() OVER (ORDER BY ordinal) AS rn,sum(n) OVER (ORDER BY ordinal) AS total_bytes FROM keys) SELECT ordinal FROM windowed WHERE total_bytes<=1048576 OR rn=1 ORDER BY ordinal",
    args,128)

def keys_next(rows: List<&2,List<&2,Sql.Cell>>,+expected: U32,+stop: U32) -> IO(U32):
  match rows:
    case []:
      IO.pure(U32,expected)
    case [Sql.Cell.Integer{key}] <> rest:
      do IO<U32>:
        checked(String.eq(key,U32.show(expected)) && U32.is_lt(expected,stop),"copied context key changed")
        keys_next(rest,U32.add(expected,1),stop)
    case _:
      IO.die(U32,1,"Context checkpoint integrity: invalid copied context key type")

def copy_step(+db: U32,+old: String,+target: String,+count: U32,+ordinal: U32,
  done: Bool,next: U32 -> IO(Unit)) -> IO(Unit):
  match done:
    case True{}:
      IO.pure(Unit,Unit{})
    case False{}:
      do IO<Unit>:
        rows : List<&2,List<&2,Sql.Cell>> <- copy_keys(db,old,ordinal,count)
        +stop : U32 <- keys_next(rows,ordinal,count)
        checked(U32.is_gt(stop,ordinal),"copied context prefix is incomplete")
        Seal.exec(db,"INSERT INTO snapshot_context(snapshot,ordinal,repository,session,model,parent,version,digest) SELECT ?,ordinal,repository,session,model,parent,version,digest FROM snapshot_context WHERE snapshot=? AND ordinal>=? AND ordinal<=? ORDER BY ordinal",
          [Sql.Cell.Integer{target},Sql.Cell.Integer{old},Sql.Cell.Integer{U32.show(ordinal)},Sql.Cell.Integer{U32.show(U32.sub(stop,1))}])
        next(stop)


def copy_walk(fuel: Nat,+db: U32,+old: String,+target: String,+count: U32,+ordinal: U32) -> IO(Unit):
  match fuel:
    case 0n:
      IO.die(Unit,1,"Context checkpoint copy budget exhausted")
    case 1n+rest:
      copy_step(db,old,target,count,ordinal,U32.is_ge(ordinal,count),
        next => copy_walk(rest,db,old,target,count,next))


def unequal(columns: List<&2,String>) -> String:
  match columns:
    case []:
      "0"
    case +name <> rest:
      "typeof(a." ++ name ++ ")<>typeof(b." ++ name ++ ") OR a." ++ name ++ " IS NOT b." ++ name ++ " OR " ++ unequal(rest)

def equality_query(db: U32,+old: String,+target: String,+count: U32,+start: U32,+initial: Bool) -> IO(List<&2,List<&2,Sql.Cell>>):
  +condition = Bool.pick(String,initial,""," AND c.ordinal>?")
  +left = Bool.pick(List<&2,Sql.Cell>,initial,[Sql.Cell.Integer{old},Sql.Cell.Integer{U32.show(count)}],
    [Sql.Cell.Integer{old},Sql.Cell.Integer{U32.show(count)},Sql.Cell.Integer{U32.show(U32.sub(start,1))}])
  +right = Bool.pick(List<&2,Sql.Cell>,initial,[Sql.Cell.Integer{target},Sql.Cell.Integer{U32.show(count)}],
    [Sql.Cell.Integer{target},Sql.Cell.Integer{U32.show(count)},Sql.Cell.Integer{U32.show(U32.sub(start,1))}])
  Seal.q(db,
    "WITH keys AS MATERIALIZED (SELECT ordinal FROM (SELECT CASE typeof(c.ordinal) WHEN 'integer' THEN c.ordinal WHEN 'real' THEN c.ordinal WHEN 'text' THEN '' WHEN 'blob' THEN x'' ELSE NULL END AS ordinal FROM snapshot_context c WHERE c.snapshot=? AND c.ordinal<?" ++ condition ++ " ORDER BY c.ordinal LIMIT 128) UNION SELECT ordinal FROM (SELECT CASE typeof(c.ordinal) WHEN 'integer' THEN c.ordinal WHEN 'real' THEN c.ordinal WHEN 'text' THEN '' WHEN 'blob' THEN x'' ELSE NULL END AS ordinal FROM snapshot_context c WHERE c.snapshot=? AND c.ordinal<?" ++ condition ++ " ORDER BY c.ordinal LIMIT 128) ORDER BY ordinal LIMIT 128), pairs AS MATERIALIZED (SELECT k.ordinal," ++ context_bytes("a") ++ "+" ++ context_bytes("b") ++ "+512 AS n FROM keys k LEFT JOIN snapshot_context a ON typeof(k.ordinal) IN('integer','real') AND a.snapshot=? AND a.ordinal=k.ordinal LEFT JOIN snapshot_context b ON typeof(k.ordinal) IN('integer','real') AND b.snapshot=? AND b.ordinal=k.ordinal), windowed AS (SELECT ordinal,row_number() OVER (ORDER BY ordinal) AS rn,sum(n) OVER (ORDER BY ordinal) AS total_bytes FROM pairs), limited AS MATERIALIZED (SELECT ordinal FROM windowed WHERE total_bytes<=1048576 OR rn=1) SELECT k.ordinal,CASE WHEN a.snapshot IS NULL OR b.snapshot IS NULL OR " ++ unequal(["ordinal","repository","session","model","parent","version","digest"]) ++ " THEN 0 ELSE 1 END FROM limited k LEFT JOIN snapshot_context a ON typeof(k.ordinal) IN('integer','real') AND a.snapshot=? AND a.ordinal=k.ordinal LEFT JOIN snapshot_context b ON typeof(k.ordinal) IN('integer','real') AND b.snapshot=? AND b.ordinal=k.ordinal ORDER BY k.ordinal",
    List.append(&2,Sql.Cell,left,List.append(&2,Sql.Cell,right,
      [Sql.Cell.Integer{old},Sql.Cell.Integer{target},Sql.Cell.Integer{old},Sql.Cell.Integer{target}])),128)

def equality_rows(rows: List<&2,List<&2,Sql.Cell>>,+expected: U32,+stop: U32) -> IO(U32):
  match rows:
    case []:
      IO.pure(U32,expected)
    case [Sql.Cell.Integer{key},Sql.Cell.Integer{"1"}] <> rest:
      do IO<U32>:
        checked(String.eq(key,U32.show(expected)) && U32.is_lt(expected,stop),"copied context prefix key differs")
        equality_rows(rest,U32.add(expected,1),stop)
    case _:
      IO.die(U32,1,"Context checkpoint integrity: copied context prefix differs from verified old context")

def equality_next(rows: List<&2,List<&2,Sql.Cell>>,next: U32,count: U32,more: Unit -> IO(Unit)) -> IO(Unit):
  match rows:
    case []:
      checked(U32.is_eq(next,count),"copied context prefix count differs")
    case _ <> _:
      more(Unit{})


def equality_walk(fuel: Nat,+db: U32,+old: String,+target: String,+count: U32,+ordinal: U32) -> IO(Unit):
  match fuel:
    case 0n:
      IO.die(Unit,1,"Context checkpoint comparison budget exhausted")
    case 1n+rest:
      do IO<Unit>:
        +rows : List<&2,List<&2,Sql.Cell>> <- equality_query(db,old,target,count,ordinal,U32.is_eq(ordinal,0))
        +next : U32 <- equality_rows(rows,ordinal,count)
        equality_next(rows,next,count,unused => equality_walk(rest,db,old,target,count,next))


def finish_mode(+db: U32,+target: Seal.Header,+prefix: Binding.Prefix,start: U32) -> IO(Unit):
  do IO<Unit>:
    valid : Bool <- scan(db,Seal.snapshot(target),prefix,header_records(target),start)
    checked(valid,"fresh target context rows do not match their raw bindings")

def finish_reuse(+db: U32,+target: Seal.Header,+prefix: Binding.Prefix,reuse: Reuse) -> IO(Unit):
  match reuse:
    case Reuse.Fresh{}:
      finish_mode(db,target,prefix,0)
    case Reuse.Verified{connection,+old,reusable}:
      do IO<Unit>:
        checked(U32.is_eq(db,connection),"context witness belongs to another connection")
        old_result : Maybe<&2,Seal.Header> <- Seal.read_header(db,Seal.snapshot(old))
        old_now : Seal.Header <- Seal.required_header(old_result)
        checked(String.eq(Seal.encoded(Seal.header_cells(old)),Seal.encoded(Seal.header_cells(old_now))) &&
          Seal.target_matches(old,target),"context witness header changed or target does not extend its source")
        Seal.equal_maps(4294967295n,db,Seal.snapshot(old),Seal.snapshot(target),Seal.checkpoint_ordinal(old),0)
        equality_walk(4294967295n,db,Seal.snapshot(old),Seal.snapshot(target),Seal.checkpoint_ordinal(old),0)
        triggers : Bool <- Seal.has_triggers(db)
        finish_mode(db,target,prefix,Bool.pick(U32,reusable && Bool.not(triggers),Seal.checkpoint_ordinal(old),0))

# Called after all publication SQL and the BeforeCommit observer, immediately
# before COMMIT. Read-only queries here cannot fire SQL triggers. A trigger
# seen before verification or now disables
# the digest shortcut, even if it was removed in between; all target contexts
# are then verified again. Normal append verifies the new tail plus exact typed
# copied-prefix equality, never treating a persisted digest as a witness.
def finish(+db: U32,snapshot: String,plan: Plan) -> IO(Unit):
  Plan{+prefix,reuse} = plan
  do IO<Unit>:
    result : Maybe<&2,Seal.Header> <- Seal.read_header(db,snapshot)
    +target : Seal.Header <- Seal.required_header(result)
    checked(prefix_matches(prefix,target),"target source or parser differs from context prefix")
    finish_reuse(db,target,prefix,reuse)

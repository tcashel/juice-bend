import Base
import ./sql.bend as Sql
import ./attachment_asset_types.bend as Types
import ./attachment_root_rules.bend as Rules
import ./attachment_root_schema.bend as S
import ./attachment_root_path.bend as Path

def valid(value: Types.RootEvidence) -> Bool:
  Types.RootEvidence{identity,path,revision,_} = value
  Rules.identity(identity) && Rules.path(path) && Rules.identity(revision)

def same(a: Types.RootEvidence,b: Types.RootEvidence) -> Bool:
  Types.RootEvidence{ai,ap,ar,ae} = a
  Types.RootEvidence{bi,bp,br,be} = b
  String.eq(ai,bi) && String.eq(ap,bp) && String.eq(ar,br) && U32.is_eq(Bool.to_u32(ae),Bool.to_u32(be))

def state_checked(valid: Bool,value: Types.RootEvidence) -> Maybe<&2,Types.RootEvidence>:
  match valid:
    case False{}: None{}
    case True{}: Some{value}

def state_fields(identity: String,path: String,revision: String,enabled: Sql.Cell) -> Maybe<&2,Types.RootEvidence>:
  match enabled:
    case Sql.Cell.Integer{"0"}: Some{Types.RootEvidence{identity,path,revision,False{}}}
    case Sql.Cell.Integer{"1"}: Some{Types.RootEvidence{identity,path,revision,True{}}}
    case _: None{}

def state(value: S.rows()) -> Maybe<&2,Types.RootEvidence>:
  match value:
    case [Sql.Cell.Integer{+identity},Sql.Cell.Text{+path},Sql.Cell.Integer{+revision},enabled] <> []:
      S.branch(Maybe<&2,Types.RootEvidence>,Rules.identity(identity) && Rules.path(path) && Rules.identity(revision),
        _ => state_fields(identity,path,revision,enabled),_ => None{})
    case _: None{}

def head_matches(value: Types.RootEvidence,rows: S.rows()) -> Bool:
  Types.RootEvidence{_,path,_,enabled} = value
  match rows:
    case [Sql.Cell.Text{actual},Sql.Cell.Integer{flag}] <> []:
      String.eq(path,actual) && String.eq(flag,Bool.pick(String,enabled,"1","0"))
    case _: False{}

def history_checked(valid: Bool,db: U32,+value: Types.RootEvidence) -> IO(S.result(Types.RootEvidence)):
  Types.RootEvidence{identity,_,revision,_} = value
  S.branch(IO(S.result(Types.RootEvidence)),valid,_ =>
    S.query(Types.RootEvidence,db,"SELECT canonical_path,enabled FROM main.attachment_root_revisions WHERE root_id=? AND revision=? LIMIT 2",
      [Sql.Cell.Integer{identity},Sql.Cell.Integer{revision}],2,
      rows => S.branch(IO(S.result(Types.RootEvidence)),head_matches(value,rows),
        _ => S.pure(Types.RootEvidence,Done{value}),_ => S.fail(Types.RootEvidence,"attachment_root_invalid"))),
    _ => S.fail(Types.RootEvidence,"attachment_root_invalid"))

def history_counts(+value: Types.RootEvidence,rows: S.rows(),+db: U32) -> IO(S.result(Types.RootEvidence)):
  Types.RootEvidence{_,_,+revision,_} = value
  match rows:
    case [Sql.Cell.Integer{count},Sql.Cell.Integer{"1"},Sql.Cell.Integer{maximum},Sql.Cell.Integer{"0"}] <> []:
      history_checked(String.eq(count,revision) && String.eq(maximum,revision),db,value)
    case _: S.fail(Types.RootEvidence,"attachment_root_invalid")

def loaded(value: Maybe<&2,Types.RootEvidence>,+db: U32) -> IO(S.result(Types.RootEvidence)):
  match value:
    case None{}: S.fail(Types.RootEvidence,"attachment_root_invalid")
    case Some{+root}:
      Types.RootEvidence{identity,_,_,_} = root
      S.query(Types.RootEvidence,db,"SELECT count(*),min(revision),max(revision),sum(CASE WHEN typeof(revision)<>'integer' OR typeof(root_id)<>'integer' OR typeof(canonical_path)<>'text' OR typeof(enabled)<>'integer' OR enabled NOT IN(0,1) THEN 1 ELSE 0 END) FROM main.attachment_root_revisions WHERE root_id=?",
        [Sql.Cell.Integer{identity}],1,rows => history_counts(root,rows,db))

def load_rows(+rows: S.rows(),db: U32) -> IO(S.result(Types.RootEvidence)):
  match rows:
    case []: S.fail(Types.RootEvidence,"attachment_root_missing")
    case _: loaded(state(rows),db)

def load(+db: U32,identity: String) -> IO(S.result(Types.RootEvidence)):
  S.query(Types.RootEvidence,db,"SELECT id,canonical_path,current_revision,enabled FROM main.attachment_roots WHERE id=? LIMIT 2",
    [Sql.Cell.Integer{identity}],2,rows => load_rows(rows,db))

# Internal precondition: caller owns the current transaction on this handle.
# No public read creates schema or reads/canonicalizes any filesystem path.
def read_owned(+db: U32,+identity: String) -> IO(S.result(Types.RootEvidence)):
  S.branch(IO(S.result(Types.RootEvidence)),Rules.identity(identity),
    _ => S.owned(Types.RootEvidence,db,_ => load(db,identity)),
    _ => S.fail(Types.RootEvidence,"attachment_root_request"))

def read(db: U32,identity: String) -> IO(S.result(Types.RootEvidence)):
  S.transaction(Types.RootEvidence,db,False{},d => read_owned(d,identity))

def validated(value: S.result(Types.RootEvidence),wanted: Types.RootEvidence) -> IO(S.result(Unit)):
  match value:
    case Fail{error}: S.pure(Unit,Fail{error})
    case Done{+actual}:
      Types.RootEvidence{_,_,_,enabled} = actual
      S.branch(IO(S.result(Unit)),enabled && same(actual,wanted),
        _ => S.pure(Unit,Done{Unit{}}),_ => S.fail(Unit,"attachment_root_revoked"))

def validate_checked(valid: Bool,db: U32,+wanted: Types.RootEvidence) -> IO(S.result(Unit)):
  match valid:
    case False{}: S.fail(Unit,"attachment_root_request")
    case True{}:
      Types.RootEvidence{identity,_,_,_} = wanted
      do IO<S.result(Unit)>:
        actual : S.result(Types.RootEvidence) <- read_owned(db,identity)
        validated(actual,wanted)

# Required publication callback. The asset writer must successfully own BEGIN
# IMMEDIATE on this SAME handle first. This helper has no transaction effects
# and deliberately makes no error-code inference about caller ownership.
def validate_owned(db: U32,+wanted: Types.RootEvidence) -> IO(S.result(Unit)):
  Types.RootEvidence{_,_,_,enabled} = wanted
  validate_checked(valid(wanted) && enabled,db,wanted)

def append_history(+db: U32,+value: Types.RootEvidence) -> IO(S.result(Types.RootEvidence)):
  Types.RootEvidence{+identity,path,revision,enabled} = value
  S.query(Types.RootEvidence,db,"INSERT INTO main.attachment_root_revisions(root_id,revision,canonical_path,enabled) VALUES(?,?,?,?)",
    [Sql.Cell.Integer{identity},Sql.Cell.Integer{revision},Sql.Cell.Text{path},Sql.Cell.Integer{Bool.pick(String,enabled,"1","0")}],0,
    _ => load(db,identity))

def changed_rows(rows: S.rows(),db: U32,value: Types.RootEvidence) -> IO(S.result(Types.RootEvidence)):
  match rows:
    case [Sql.Cell.Integer{"1"}] <> []: append_history(db,value)
    case _: S.fail(Types.RootEvidence,"attachment_root_invalid")

def changed(+db: U32,value: Types.RootEvidence) -> IO(S.result(Types.RootEvidence)):
  S.query(Types.RootEvidence,db,"SELECT changes()",[],1,rows => changed_rows(rows,db,value))

def transition_next(next: Maybe<&2,String>,+db: U32,current: Types.RootEvidence,+path: String,+enabled: Bool) -> IO(S.result(Types.RootEvidence)):
  match next:
    case None{}: S.fail(Types.RootEvidence,"attachment_root_exhausted")
    case Some{+revision}:
      Types.RootEvidence{+identity,_,old,_} = current
      +value : Types.RootEvidence = Types.RootEvidence{identity,path,revision,enabled}
      S.query(Types.RootEvidence,db,"UPDATE main.attachment_roots SET canonical_path=?,current_revision=?,enabled=? WHERE id=? AND current_revision=?",
        [Sql.Cell.Text{path},Sql.Cell.Integer{revision},Sql.Cell.Integer{Bool.pick(String,enabled,"1","0")},
          Sql.Cell.Integer{identity},Sql.Cell.Integer{old}],0,_ => changed(db,value))

def collision(+current: Types.RootEvidence,rows: S.rows(),db: U32,path: String,enabled: Bool) -> IO(S.result(Types.RootEvidence)):
  Types.RootEvidence{_,_,revision,_} = current
  match rows:
    case []: transition_next(Rules.increment(revision),db,current,path,enabled)
    case _: S.fail(Types.RootEvidence,"attachment_root_conflict")

def transition_same(unchanged: Bool,+db: U32,+current: Types.RootEvidence,+path: String,enabled: Bool) -> IO(S.result(Types.RootEvidence)):
  match unchanged:
    case True{}: S.pure(Types.RootEvidence,Done{current})
    case False{}:
      Types.RootEvidence{identity,_,_,_} = current
      S.query(Types.RootEvidence,db,"SELECT id FROM main.attachment_roots WHERE canonical_path=? AND id<>? LIMIT 2",
        [Sql.Cell.Text{path},Sql.Cell.Integer{identity}],2,rows => collision(current,rows,db,path,enabled))

def transition(value: S.result(Types.RootEvidence),db: U32,+path: String,+enabled: Bool) -> IO(S.result(Types.RootEvidence)):
  match value:
    case Fail{error}: S.pure(Types.RootEvidence,Fail{error})
    case Done{+current}:
      Types.RootEvidence{_,prior,_,was_enabled} = current
      transition_same(String.eq(prior,path) && U32.is_eq(Bool.to_u32(was_enabled),Bool.to_u32(enabled)),db,current,path,enabled)

def change(+db: U32,identity: String,path: String,enabled: Bool) -> IO(S.result(Types.RootEvidence)):
  do IO<S.result(Types.RootEvidence)>:
    current : S.result(Types.RootEvidence) <- load(db,identity)
    transition(current,db,path,enabled)

def new_next(next: Maybe<&2,String>,+db: U32,+path: String) -> IO(S.result(Types.RootEvidence)):
  match next:
    case None{}: S.fail(Types.RootEvidence,"attachment_root_exhausted")
    case Some{+identity}:
      +value : Types.RootEvidence = Types.RootEvidence{identity,path,"1",True{}}
      S.query(Types.RootEvidence,db,"INSERT INTO main.attachment_roots(id,canonical_path,current_revision,enabled) VALUES(?,?,1,1)",
        [Sql.Cell.Integer{identity},Sql.Cell.Text{path}],0,_ => append_history(db,value))

def maximum(rows: S.rows(),db: U32,path: String) -> IO(S.result(Types.RootEvidence)):
  match rows:
    case [Sql.Cell.Null{}] <> []: new_next(Some{"1"},db,path)
    case [Sql.Cell.Integer{+value}] <> []:
      S.branch(IO(S.result(Types.RootEvidence)),Rules.identity(value),
        _ => new_next(Rules.increment(value),db,path),_ => S.fail(Types.RootEvidence,"attachment_root_invalid"))
    case _: S.fail(Types.RootEvidence,"attachment_root_invalid")

def found(rows: S.rows(),+db: U32,path: String) -> IO(S.result(Types.RootEvidence)):
  match rows:
    case []: S.query(Types.RootEvidence,db,"SELECT max(id) FROM main.attachment_roots",[],1,values => maximum(values,db,path))
    case [Sql.Cell.Integer{+identity}] <> []:
      S.branch(IO(S.result(Types.RootEvidence)),Rules.identity(identity),
        _ => change(db,identity,path,True{}),_ => S.fail(Types.RootEvidence,"attachment_root_invalid"))
    case _: S.fail(Types.RootEvidence,"attachment_root_invalid")

def enable_owned(+db: U32,identity: Maybe<&2,String>,+path: String) -> IO(S.result(Types.RootEvidence)):
  match identity:
    case None{}: S.query(Types.RootEvidence,db,"SELECT id FROM main.attachment_roots WHERE canonical_path=? LIMIT 2",
      [Sql.Cell.Text{path}],2,rows => found(rows,db,path))
    case Some{id}: change(db,id,path,True{})

def enable_path(value: S.result(String),db: U32,identity: Maybe<&2,String>) -> IO(S.result(Types.RootEvidence)):
  match value:
    case Fail{error}: S.pure(Types.RootEvidence,Fail{error})
    case Done{path}:
      S.transaction(Types.RootEvidence,db,True{},+d => S.owned(Types.RootEvidence,d,_ => enable_owned(d,identity,path)))

def requested_identity(value: Maybe<&2,String>) -> Bool:
  match value:
    case None{}: True{}
    case Some{id}: Rules.identity(id)

def enable_checked(valid: Bool,db: U32,identity: Maybe<&2,String>,requested_path: String) -> IO(S.result(Types.RootEvidence)):
  match valid:
    case False{}: S.fail(Types.RootEvidence,"attachment_root_request")
    case True{}:
      do IO<S.result(Types.RootEvidence)>:
        canonical : S.result(String) <- Path.resolve(requested_path)
        enable_path(canonical,db,identity)

def enable(db: U32,+identity: Maybe<&2,String>,requested_path: String) -> IO(S.result(Types.RootEvidence)):
  enable_checked(requested_identity(identity),db,identity,requested_path)

def disable_value(value: S.result(Types.RootEvidence),db: U32) -> IO(S.result(Types.RootEvidence)):
  match value:
    case Fail{error}: S.pure(Types.RootEvidence,Fail{error})
    case Done{+current}:
      Types.RootEvidence{_,path,_,enabled} = current
      transition_same(Bool.not(enabled),db,current,path,False{})

def disable_read(+db: U32,identity: String) -> IO(S.result(Types.RootEvidence)):
  do IO<S.result(Types.RootEvidence)>:
    value : S.result(Types.RootEvidence) <- read_owned(db,identity)
    disable_value(value,db)

def disable(db: U32,identity: String) -> IO(S.result(Types.RootEvidence)):
  S.transaction(Types.RootEvidence,db,True{},d => disable_read(d,identity))

def initialize(db: U32) -> IO(S.result(Unit)):
  S.initialize(db)

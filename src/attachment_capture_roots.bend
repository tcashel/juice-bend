import Base
import ./attachment_asset_types.bend as T
import ./attachment_root_policy.bend as P
import ./attachment_root_schema.bend as S
import ./attachment_root_rules.bend as R
import ./attachment_root_path.bend as Path
import ./sql.bend as Sql

type Page is Data:
  Page{after: String,requested: U32,roots: List<&2,T.RootEvidence>,next: Maybe<&2,String>}

def completed(after: String,count: U32,reversed: List<&2,T.RootEvidence>,next: Maybe<&2,String>) -> IO(S.result(Page)):
  S.pure(Page,Done{Page{after,count,List.reverse(&2,T.RootEvidence,reversed),next}})
def added(value: S.result(T.RootEvidence),after: String,count: U32,prior: List<&2,T.RootEvidence>,
  next: List<&2,T.RootEvidence> -> IO(S.result(Page))) -> IO(S.result(Page)):
  match value:
    case Fail{error}: S.pure(Page,Fail{error})
    case Done{root}: next(root <> prior)
def tail(rows: S.rows(),after: String,count: U32,prior: List<&2,T.RootEvidence>,last: String) -> IO(S.result(Page)):
  match rows:
    case []: completed(after,count,prior,None{})
    case [[Sql.Cell.Integer{id}]]:
      S.branch(IO(S.result(Page)),R.identity(id),_ => completed(after,count,prior,Some{last}),_ => S.fail(Page,"attachment_root_invalid"))
    case _: S.fail(Page,"attachment_root_invalid")
def walk(left: Nat,rows: S.rows(),+db: U32,+after: String,+count: U32,prior: List<&2,T.RootEvidence>,last: String) -> IO(S.result(Page)):
  match left:
    case 0n: tail(rows,after,count,prior,last)
    case 1n+rest:
      match rows:
        case []: completed(after,count,prior,None{})
        case [Sql.Cell.Integer{+id}] <> remaining:
          do IO<S.result(Page)>:
            value : S.result(T.RootEvidence) <- P.read_owned(db,id)
            added(value,after,count,prior,values => walk(rest,remaining,db,after,count,values,id))
        case _: S.fail(Page,"attachment_root_invalid")
def list_owned(+db: U32,+after: String,+count: U32) -> IO(S.result(Page)):
  S.owned(Page,db,_ => S.query(Page,db,"SELECT id FROM main.attachment_roots WHERE id>? ORDER BY id LIMIT ?",
    [Sql.Cell.Integer{after},Sql.Cell.Integer{U32.show(U32.inc(count))}],U32.inc(count),
    rows => walk(U32.to_nat(count),rows,db,after,count,[],after)))
def list(db: U32,+after: String,+count: U32) -> IO(S.result(Page)):
  S.branch(IO(S.result(Page)),(String.eq(after,"0") || R.identity(after)) && U32.is_gt(count,0) && U32.is_le(count,40),
    _ => S.transaction(Page,db,False{},d => list_owned(d,after,count)),_ => S.fail(Page,"attachment_root_request"))

# Enable uses the retained root path, canonicalizes metadata outside the write
# transaction, then compares the complete prior root before changing anything.
def current(value: S.result(T.RootEvidence),db: U32,+expected: T.RootEvidence) -> IO(S.result(T.RootEvidence)):
  match value:
    case Fail{error}: S.pure(T.RootEvidence,Fail{error})
    case Done{actual}:
      T.RootEvidence{_,path,_,enabled} = expected
      S.branch(IO(S.result(T.RootEvidence)),P.same(actual,expected),
        _ => P.transition_same(enabled,db,expected,path,True{}),_ => S.fail(T.RootEvidence,"attachment_root_revoked"))
def enable_owned(+db: U32,+expected: T.RootEvidence) -> IO(S.result(T.RootEvidence)):
  T.RootEvidence{id,_,_,_} = expected
  do IO<S.result(T.RootEvidence)>:
    actual : S.result(T.RootEvidence) <- P.read_owned(db,id)
    current(actual,db,expected)
def canonical(value: S.result(String),db: U32,+expected: T.RootEvidence) -> IO(S.result(T.RootEvidence)):
  match value:
    case Fail{error}: S.pure(T.RootEvidence,Fail{error})
    case Done{actual}:
      T.RootEvidence{_,path,_,_} = expected
      S.branch(IO(S.result(T.RootEvidence)),String.eq(actual,path),
        _ => S.transaction(T.RootEvidence,db,True{},d => enable_owned(d,expected)),_ => S.fail(T.RootEvidence,"attachment_root_revoked"))
def enable_read(value: S.result(T.RootEvidence),db: U32) -> IO(S.result(T.RootEvidence)):
  match value:
    case Fail{error}: S.pure(T.RootEvidence,Fail{error})
    case Done{+expected}:
      T.RootEvidence{_,path,_,_} = expected
      do IO<S.result(T.RootEvidence)>:
        resolved : S.result(String) <- Path.resolve(path)
        canonical(resolved,db,expected)
def enable(+db: U32,id: String) -> IO(S.result(T.RootEvidence)):
  do IO<S.result(T.RootEvidence)>:
    value : S.result(T.RootEvidence) <- P.read(db,id)
    enable_read(value,db)

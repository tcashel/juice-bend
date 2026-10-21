import Base
import ./claude_quota.bend as Q
import ./quota_paths.bend as P
import ./quota_store.bend as S
import ./quota_cli.bend as C
import ./sql.bend as Sql

# Sole production-intended quota entry point. All paths derive from the explicit
# selected root. Status/history/receivers never create a root or database.
# No native file helper: bounded literal OS primitives implement Bend policy.
# Checked paths plus 0700 ownership do not bind parent inodes to SQLite handles;
# concurrent replacement by the same UID remains outside this path-based seam.
type Temp is Data:
  Temp{path: String,identity: P.Metadata}

def result_type() -> Data:
  Result<&2,&2,Q.Failure,Unit>

def ok() -> result_type():
  Done{Unit{}}

def view_unit(value: S.answer_type()) -> result_type():
  match value:
    case Fail{problem}: Fail{problem}
    case Done{_}: ok()

def sql_opened(value: Result<&1,&1,U32 & String,U32>) -> Result<&2,&2,Q.Failure,U32>:
  match value:
    case Fail{_}: P.fail(U32,"quota_open","Cannot open existing quota storage with the required SQLite access mode")
    case Done{db}: Done{db}

def opened(path: String,mode: U32) -> IO(Result<&2,&2,Q.Failure,U32>):
  do IO<Result<&2,&2,Q.Failure,U32>>:
    result : Result<&1,&1,U32 & String,U32> <- Sql.open_existing(path,mode)
    return sql_opened(result)

# A read-only SQLite open can create WAL bookkeeping files. Reject a persisted
# WAL/unknown format before SQLite sees any existing main file. This is only a
# bounded file-header admission, not schema validation or an inode-bound open;
# the existing pre/post identity checks and runtime journal check still apply.
# Owned newly-created empty temporary files bypass this gate for initialization.
def header_magic(value: List<&2,U32>) -> Bool:
  match value:
    case [83,81,76,105,116,101,32,102,111,114,109,97,116,32,51,0]: True{}
    case _: False{}

def header_versions(value: List<&2,U32>) -> Bool:
  match value:
    case 1 <> 1 <> _: True{}
    case _: False{}

def rollback_header(+value: List<&2,U32>) -> Bool:
  Nat.is_eq(List.length(&2,U32,value),100n) &&
    header_magic(List.take(&2,U32,value,16n)) &&
    header_versions(List.drop(&2,U32,value,18n))

def header_result(value: Result<&1,&1,U32 & String,List<&2,U32>>) -> result_type():
  match value:
    case Fail{_}: P.fail(Unit,"quota_header","Cannot read the quota database header without opening SQLite")
    case Done{bytes}: P.gate(Unit,rollback_header(bytes),Unit{},"quota_header",
      "Existing quota storage requires a complete SQLite rollback-journal header")

def header_read(value: File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(result_type()):
  (file,result) = value
  do IO<result_type()>:
    File.close(file)
    return header_result(result)

def header_opened(value: Result<&1,&1,U32 & String,File>) -> IO(result_type()):
  match value:
    case Fail{_}: P.pure(Unit,P.fail(Unit,"quota_header","Cannot read the quota database header without opening SQLite"))
    case Done{file}:
      do IO<result_type()>:
        value : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,100)
        header_read(value)

def inspect_header(path: String) -> IO(result_type()):
  do IO<result_type()>:
    result : Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    header_opened(result)

def closed(value: Result<&1,&1,U32 & String,Unit>,prior: S.answer_type()) -> S.answer_type():
  match value:
    case Done{_}: prior
    case Fail{_}: S.fail("quota_close","Quota storage did not close cleanly")

def close(db: U32,prior: S.answer_type()) -> IO(S.answer_type()):
  do IO<S.answer_type()>:
    result : Result<&1,&1,U32 & String,Unit> <- Sql.close(db)
    return closed(result,prior)

def sql_rows(value: Result<&1,&1,U32 & String,S.rows_type()>) -> Result<&2,&2,Q.Failure,S.rows_type()>:
  match value:
    case Fail{_}: P.fail(S.rows_type(),"quota_inspect","Cannot validate dedicated quota storage without changing it")
    case Done{rows}: Done{rows}

def rows(db: U32,statement: String,limit: U32) -> IO(Result<&2,&2,Q.Failure,S.rows_type()>):
  do IO<Result<&2,&2,Q.Failure,S.rows_type()>>:
    result : Result<&1,&1,U32 & String,S.rows_type()> <- Sql.query(db,statement,[],limit)
    return sql_rows(result)

def database_list(value: S.rows_type(),path: String) -> result_type():
  match value:
    case [[Sql.Cell.Integer{"0"},Sql.Cell.Text{"main"},Sql.Cell.Text{actual}]]:
      P.gate(Unit,String.eq(actual,path),Unit{},"quota_handle_path","Quota handle does not report the selected database path")
    case _: P.fail(Unit,"quota_handle_path","Quota handle has an unexpected database list")

def journal(value: S.rows_type()) -> result_type():
  match value:
    case [[Sql.Cell.Text{"delete"}]]: ok()
    case _: P.fail(Unit,"quota_journal","Quota storage must use its original DELETE journal mode")

# Read-only validation precedes every writable open. A hot journal that cannot
# be inspected read-only fails closed; this seam never recovers an unverified
# database or changes a foreign database's journal mode/schema/application id.
def validate_store(db: U32) -> IO(result_type()):
  do IO<result_type()>:
    answer : S.answer_type() <- S.status(db)
    return view_unit(answer)

def validate_journal(+db: U32) -> IO(result_type()):
  do IO<result_type()>:
    result : Result<&2,&2,Q.Failure,S.rows_type()> <- rows(db,"PRAGMA main.journal_mode",1)
    P.bind(S.rows_type(),Unit,result,r => P.bind(Unit,Unit,journal(r),_ => validate_store(db)))

def validate(+db: U32,path: String) -> IO(result_type()):
  do IO<result_type()>:
    result : Result<&2,&2,Q.Failure,S.rows_type()> <- rows(db,"PRAGMA database_list",2)
    P.bind(S.rows_type(),Unit,result,r => P.bind(Unit,Unit,database_list(r,path),_ => validate_journal(db)))

def sidecars(paths: List<&2,String>,+root: P.Root,found: Bool) -> IO(Result<&2,&2,Q.Failure,Bool>):
  match paths:
    case []: P.pure(Bool,Done{found})
    case path <> rest:
      do IO<Result<&2,&2,Q.Failure,Bool>>:
        result : Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>> <- P.inspect_file(root,path)
        P.bind(Maybe<&2,P.Metadata>,Bool,result,m =>
          sidecars(rest,root,found || Maybe.is_some(&2,P.Metadata,m)))

def orphan(value: Maybe<&2,P.Metadata>,sidecar: Bool) -> Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>>:
  match value:
    case None{}: P.gate(Maybe<&2,P.Metadata>,Bool.not(sidecar),None{},"quota_orphan","Quota sidecars exist without a database; they were left untouched")
    case Some{metadata}: Done{Some{metadata}}

def bundle_main(+root: P.Root) -> IO(Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>>):
  +path = P.main(root)
  do IO<Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>>>:
    result : Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>> <- P.inspect_file(root,path)
    P.bind(Maybe<&2,P.Metadata>,Maybe<&2,P.Metadata>,result,m =>
      do IO<Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>>>:
        checked : Result<&2,&2,Q.Failure,Bool> <- sidecars([path ++ "-journal",path ++ "-wal",path ++ "-shm"],root,False{})
        P.bind(Bool,Maybe<&2,P.Metadata>,checked,found => P.pure(Maybe<&2,P.Metadata>,orphan(m,found))))

def bundle(root: P.Root) -> IO(Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>>):
  do IO<Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>>>:
    checked : Result<&2,&2,Q.Failure,P.Root> <- P.recheck(root)
    P.bind(P.Root,Maybe<&2,P.Metadata>,checked,r => bundle_main(r))

def unchanged(value: Maybe<&2,P.Metadata>,expected: P.Metadata) -> result_type():
  match value:
    case Some{actual}: P.gate(Unit,P.same(actual,expected),Unit{},"quota_file_changed","Quota storage identity or permissions changed")
    case None{}: P.fail(Unit,"quota_file_changed","Quota storage disappeared during the operation")

def inspect_same(root: P.Root,expected: P.Metadata) -> IO(result_type()):
  do IO<result_type()>:
    result : Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>> <- bundle(root)
    P.bind(Maybe<&2,P.Metadata>,Unit,result,m => P.pure(Unit,unchanged(m,expected)))

def post_result(checked: result_type(),prior: S.answer_type()) -> S.answer_type():
  match checked:
    case Fail{problem}: Fail{problem}
    case Done{_}: prior

def post(root: P.Root,expected: P.Metadata,prior: S.answer_type()) -> IO(S.answer_type()):
  do IO<S.answer_type()>:
    checked : result_type() <- inspect_same(root,expected)
    return post_result(checked,prior)

def finish(db: U32,root: P.Root,expected: P.Metadata,prior: S.answer_type()) -> IO(S.answer_type()):
  do IO<S.answer_type()>:
    result : S.answer_type() <- close(db,prior)
    post(root,expected,result)

def dispatch_valid(value: result_type(),db: U32,command: C.Command,body: String) -> IO(S.answer_type()):
  match value:
    case Fail{problem}: S.pure(Fail{problem})
    case Done{_}: C.dispatch(db,command,body)

def dispatch_open(+db: U32,+root: P.Root,+expected: P.Metadata,command: C.Command,body: String) -> IO(S.answer_type()):
  do IO<S.answer_type()>:
    same : result_type() <- inspect_same(root,expected)
    valid : result_type() <- P.bind(Unit,Unit,same,_ => validate(db,P.main(root)))
    answer : S.answer_type() <- dispatch_valid(valid,db,command,body)
    finish(db,root,expected,answer)

def operation_opened(value: Result<&2,&2,Q.Failure,U32>,root: P.Root,expected: P.Metadata,command: C.Command,body: String) -> IO(S.answer_type()):
  match value:
    case Fail{problem}: S.pure(Fail{problem})
    case Done{db}: dispatch_open(db,root,expected,command,body)

def operation_admitted(value: result_type(),+root: P.Root,expected: P.Metadata,command: C.Command,body: String,mode: U32) -> IO(S.answer_type()):
  match value:
    case Fail{problem}: S.pure(Fail{problem})
    case Done{_}:
      do IO<S.answer_type()>:
        result : Result<&2,&2,Q.Failure,U32> <- opened(P.main(root),mode)
        operation_opened(result,root,expected,command,body)

def operation_checked(value: result_type(),+root: P.Root,+expected: P.Metadata,command: C.Command,body: String,mode: U32) -> IO(S.answer_type()):
  match value:
    case Fail{problem}: S.pure(Fail{problem})
    case Done{_}:
      do IO<S.answer_type()>:
        header : result_type() <- inspect_header(P.main(root))
        checked : result_type() <- P.bind(Unit,Unit,header,_ => inspect_same(root,expected))
        operation_admitted(checked,root,expected,command,body,mode)

def operation(+root: P.Root,+expected: P.Metadata,command: C.Command,body: String,mode: U32) -> IO(S.answer_type()):
  do IO<S.answer_type()>:
    checked : result_type() <- inspect_same(root,expected)
    operation_checked(checked,root,expected,command,body,mode)

def admitted(value: S.answer_type(),root: P.Root,expected: P.Metadata,command: C.Command,body: String) -> IO(S.answer_type()):
  match value:
    case Fail{problem}: S.pure(Fail{problem})
    case Done{_}: operation(root,expected,command,body,1)

def existing(+root: P.Root,+expected: P.Metadata,command: C.Command,body: String) -> IO(S.answer_type()):
  match command:
    case C.Status{}: operation(root,expected,C.Status{},body,0)
    case C.History{offset}: operation(root,expected,C.History{offset},body,0)
    case other:
      do IO<S.answer_type()>:
        admission : S.answer_type() <- operation(root,expected,C.Status{},"",0)
        admitted(admission,root,expected,other,body)

def command_ok(reply: P.Reply) -> result_type():
  match reply:
    case P.Reply{0,"",""}: ok()
    case _: P.fail(Unit,"quota_publish","Quota private file operation failed; existing storage was left in place")

def primitive(program: String,args: List<String>) -> IO(result_type()):
  do IO<result_type()>:
    result : Result<&2,&2,Q.Failure,P.Reply> <- P.command(program,args)
    P.bind(P.Reply,Unit,result,r => P.pure(Unit,command_ok(r)))

def linked(metadata: P.Metadata) -> P.Metadata:
  P.Metadata{mode,uid,_,device,inode} = metadata
  P.Metadata{mode,uid,"2",device,inode}

def temp_same(value: Maybe<&2,P.Metadata>,+expected: P.Metadata,allow_linked: Bool) -> result_type():
  match value:
    case None{}: P.fail(Unit,"quota_temp_changed","Quota temporary file disappeared; no unrelated path was removed")
    case Some{+actual}: P.gate(Unit,P.same(actual,expected) || (allow_linked && P.same(actual,linked(expected))),Unit{},
      "quota_temp_changed","Quota temporary file identity changed; no unrelated path was removed")

def temp_inspect(root: P.Root,+temp: Temp,allow_linked: Bool) -> IO(result_type()):
  P.Root{platform,_,_,_} = root
  Temp{path,expected} = temp
  do IO<result_type()>:
    result : Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>> <- P.stat(platform,path)
    P.bind(Maybe<&2,P.Metadata>,Unit,result,m => P.pure(Unit,temp_same(m,expected,allow_linked)))

def cleanup_checked(value: result_type(),temp: Temp) -> IO(result_type()):
  match value:
    case Fail{problem}: P.pure(Unit,Fail{problem})
    case Done{_}:
      Temp{path,_} = temp
      primitive("/bin/rm",["--",path])

def cleanup(+root: P.Root,+temp: Temp) -> IO(result_type()):
  do IO<result_type()>:
    checked : Result<&2,&2,Q.Failure,P.Root> <- P.recheck(root)
    P.bind(P.Root,Unit,checked,r =>
      do IO<result_type()>:
        value : result_type() <- temp_inspect(r,temp,True{})
        cleanup_checked(value,temp))

def cleaned(root: P.Root,temp: Temp,prior: S.answer_type()) -> IO(S.answer_type()):
  do IO<S.answer_type()>:
    result : result_type() <- cleanup(root,temp)
    return post_result(result,prior)

def published_meta(value: Maybe<&2,P.Metadata>,expected: P.Metadata) -> Result<&2,&2,Q.Failure,P.Metadata>:
  match value:
    case Some{+actual}: P.gate(P.Metadata,P.same(actual,expected),actual,"quota_publish_changed","Published quota database identity changed")
    case None{}: P.fail(P.Metadata,"quota_publish_changed","Published quota database disappeared")

def published_clean(value: result_type(),+root: P.Root,expected: P.Metadata) -> IO(S.answer_type()):
  match value:
    case Fail{problem}: S.pure(Fail{problem})
    case Done{_}:
      do IO<S.answer_type()>:
        result : Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>> <- bundle(root)
        P.bind(Maybe<&2,P.Metadata>,S.View,result,m =>
          P.bind(P.Metadata,S.View,published_meta(m,expected),meta => existing(root,meta,C.Enable{},"")))

def publication_result(value: result_type(),+root: P.Root,+temp: Temp) -> IO(S.answer_type()):
  match value:
    case Fail{problem}: cleaned(root,temp,Fail{problem})
    case Done{_}:
      Temp{_,expected} = temp
      do IO<S.answer_type()>:
        result : result_type() <- cleanup(root,temp)
        published_clean(result,root,expected)

def publication_checked(value: result_type(),+root: P.Root,+temp: Temp) -> IO(S.answer_type()):
  match value:
    case Fail{problem}: cleaned(root,temp,Fail{problem})
    case Done{_}:
      Temp{path,_} = temp
      do IO<S.answer_type()>:
        result : result_type() <- primitive("/bin/link",[path,P.main(root)])
        publication_result(result,root,temp)

def absent(value: Maybe<&2,P.Metadata>) -> result_type():
  match value:
    case None{}: ok()
    case Some{_}: P.fail(Unit,"quota_exists","Quota database appeared before publication; it was not replaced")

def publish_absent(value: Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>>,+root: P.Root,+temp: Temp) -> IO(S.answer_type()):
  match value:
    case Fail{problem}: cleaned(root,temp,Fail{problem})
    case Done{m}:
      do IO<S.answer_type()>:
        checked : result_type() <- P.bind(Unit,Unit,absent(m),_ => temp_inspect(root,temp,False{}))
        publication_checked(checked,root,temp)

def publish(+root: P.Root,temp: Temp) -> IO(S.answer_type()):
  do IO<S.answer_type()>:
    checked : Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>> <- bundle(root)
    publish_absent(checked,root,temp)

def initialized(value: S.answer_type(),root: P.Root,temp: Temp) -> IO(S.answer_type()):
  match value:
    case Fail{Q.Failure{"quota_close",message}}: S.pure(S.fail("quota_close",message))
    case Fail{problem}: cleaned(root,temp,Fail{problem})
    case Done{_}: publish(root,temp)

def initialize_opened(value: Result<&2,&2,Q.Failure,U32>,root: P.Root,temp: Temp) -> IO(S.answer_type()):
  match value:
    case Fail{problem}: cleaned(root,temp,Fail{problem})
    case Done{+db}:
      do IO<S.answer_type()>:
        result : S.answer_type() <- S.initialize(db)
        finished : S.answer_type() <- close(db,result)
        initialized(finished,root,temp)

def initialize_temp(root: P.Root,+temp: Temp) -> IO(S.answer_type()):
  Temp{path,_} = temp
  do IO<S.answer_type()>:
    result : Result<&2,&2,Q.Failure,U32> <- opened(path,1)
    initialize_opened(result,root,temp)

def temp_metadata(value: Maybe<&2,P.Metadata>,path: String) -> Result<&2,&2,Q.Failure,Temp>:
  match value:
    case None{}: P.fail(Temp,"quota_create","Private quota temporary file was not created")
    case Some{metadata}: Done{Temp{path,metadata}}

def temp_chars(value: String) -> Bool:
  match value:
    case "": True{}
    case SCon{Chr{+c},rest}:
      ((U32.is_ge(c,48) && U32.is_le(c,57)) || (U32.is_ge(c,65) && U32.is_le(c,90)) ||
        (U32.is_ge(c,97) && U32.is_le(c,122))) && temp_chars(rest)

def temp_name(+value: String,+prefix: String) -> Bool:
  String.starts_with(value,prefix) && Nat.is_eq(String.length(value),Nat.add(String.length(prefix),6n)) &&
    temp_chars(String.drop(value,String.length(prefix)))

def temp_line(value: Result<&2,&2,Q.Failure,String>,prefix: String) -> Result<&2,&2,Q.Failure,String>:
  match value:
    case Fail{problem}: Fail{problem}
    case Done{+value}: P.gate(String,temp_name(value,prefix),value,"quota_create","Private quota temporary filename was invalid")

def temp_reply(value: P.Reply,prefix: String) -> Result<&2,&2,Q.Failure,String>:
  match value:
    case P.Reply{0,out,""}: temp_line(P.line(String.split(out,'\n')),prefix)
    case _: P.fail(String,"quota_create","Cannot create a private quota temporary file in the selected data root")

def created_temp(+root: P.Root,+path: String) -> IO(S.answer_type()):
  do IO<S.answer_type()>:
    result : Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>> <- P.inspect_file(root,path)
    P.bind(Maybe<&2,P.Metadata>,S.View,result,m =>
      P.bind(Temp,S.View,temp_metadata(m,path),temp => initialize_temp(root,temp)))

def provision(+root: P.Root) -> IO(S.answer_type()):
  P.Root{_,_,path,_} = root
  +prefix = path ++ "/.quota-create."
  do IO<S.answer_type()>:
    result : Result<&2,&2,Q.Failure,P.Reply> <- P.command("/usr/bin/mktemp",[prefix ++ "XXXXXX"])
    P.bind(P.Reply,S.View,result,r => P.bind(String,S.View,temp_reply(r,prefix),temp => created_temp(root,temp)))

def missing(command: C.Command,root: P.Root) -> IO(S.answer_type()):
  match command:
    case C.Enable{}: provision(root)
    case C.Status{}: S.pure(S.blank(S.State{0n,False{}},"status"))
    case C.History{_}: S.pure(S.blank(S.State{0n,False{}},"history"))
    case C.Disconnect{}: S.pure(S.blank(S.State{0n,False{}},"disconnected"))
    case C.Observe{_,_}: S.pure(S.fail("quota_epoch_retired","Quota collection is off or this callback belongs to a retired connection"))

def selected(value: Maybe<&2,P.Metadata>,root: P.Root,command: C.Command,body: String) -> IO(S.answer_type()):
  match value:
    case None{}: missing(command,root)
    case Some{metadata}: existing(root,metadata,command,body)

def at_root(+root: P.Root,command: C.Command,body: String) -> IO(S.answer_type()):
  do IO<S.answer_type()>:
    result : Result<&2,&2,Q.Failure,Maybe<&2,P.Metadata>> <- bundle(root)
    P.bind(Maybe<&2,P.Metadata>,S.View,result,m => selected(m,root,command,body))

def dispatch(selected: String,command: C.Command,body: String) -> IO(S.answer_type()):
  do IO<S.answer_type()>:
    result : Result<&2,&2,Q.Failure,P.Root> <- P.inspect_root(selected)
    P.bind(P.Root,S.View,result,root => at_root(root,command,body))

# GUI worker passes exact typed command/body here. CLI receiver reads bounded
# stdin before this safe entry, and emits only after its SQLite handle is closed.
def body_read(value: C.result_type(),root: String,epoch: Nat,+footer: Bool) -> IO(Unit):
  match value:
    case Fail{problem}: C.emit(Fail{problem},footer)
    case Done{body}:
      do IO<Unit>:
        result : S.answer_type() <- dispatch(root,C.Observe{epoch,footer},body)
        C.emit(result,footer)

def run_command(command: C.Command,root: String) -> IO(Unit):
  match command:
    case C.Observe{epoch,+footer}:
      do IO<Unit>:
        body : C.result_type() <- C.stdin()
        body_read(body,root,epoch,footer)
    case other:
      do IO<Unit>:
        result : S.answer_type() <- dispatch(root,other,"")
        C.emit(result,False{})

def run_parsed(value: Result<&2,&2,Q.Failure,C.Command>,root: String) -> IO(Unit):
  match value:
    case Fail{problem}: C.emit(Fail{problem},False{})
    case Done{command}: run_command(command,root)

def run(root: String,operation: String,args: List<&2,String>) -> IO(Unit):
  run_parsed(C.parse(operation,args),root)

# This exact worker/CLI prefix carries the selected root explicitly. Main must
# dispatch it before capture-library initialization; no default-root fallback.
def copied_args(args: List<String>) -> List<&2,String>:
  match args:
    case []: []
    case value <> rest: value <> copied_args(rest)

def argv(args: List<String>) -> IO(Unit):
  match args:
    case "--data-dir" <> root <> "quota" <> operation <> rest:
      run(root,operation,copied_args(rest))
    case _:
      C.emit(S.fail("quota_usage","Quota requires --data-dir ROOT quota OPERATION with an explicitly selected private root"),False{})

import Base
import ./library_usage.bend as L
import ./library_usage_types.bend as T
import ./library_usage_wire.bend as Wire
import ./session_usage.bend as S
import ./domain.bend as D
import ./attachment_refs.bend as Ref
import ./json.bend as J
import ./sql.bend as Sql
import ./maintenance.bend as Maintenance
import ./scoped_reader.bend as Scoped
import ./reader_document.bend as Reader
import ./reader_wire.bend as ReaderWire

# Same-app child entry. The caller must select a root explicitly; this module
# never resolves HOME, creates directories, opens sources, or initializes or
# migrates the library. SQLite READONLY may retain its normal WAL bookkeeping.
def command() -> String: "library-usage-v1"
def command_capture() -> String: "library-usage-capture-v1"

type CaptureRequest is Data:
  CaptureRequest{nonce: U32,capture: S.Capture,start: U32}

def answer() -> Data:
  Result<&2,&2,S.Failure,String>

def invalid() -> S.Failure:
  S.Failure{"library_usage_arguments","Expected library-usage-v1 NONCE with one canonical nonzero U32 request identity"}

def parsed_number(value: Maybe<&2,U32>) -> Result<&2,&2,S.Failure,U32>:
  match value:
    case Some{0}: Fail{invalid()}
    case Some{nonce}: Done{nonce}
    case None{}: Fail{invalid()}

def parsed_bound(valid: Bool,value: String) -> Result<&2,&2,S.Failure,U32>:
  match valid:
    case False{}: Fail{invalid()}
    case True{}: parsed_number(D.parse_u32(value))

def parse(args: List<String>) -> Result<&2,&2,S.Failure,U32>:
  match args:
    case +value <> []: parsed_bound(Ref.bounded(value,10),value)
    case _: Fail{invalid()}

# A successful raw-window step advances at least one physical record. Each
# admitted source takes at most one header/admission step and one completion
# step; a limited source takes fewer. The final empty catalog takes one step.
# Defaults therefore need at most 1,000,000 + 2*256 + 1 calls to L.step.
# Fuel is independent of raw strings and still terminates a broken reader.
def fuel() -> Nat: 1000513n

def exhausted(value: Result<&2,&2,S.Failure,Unit>) -> Result<&2,&2,S.Failure,T.Report>:
  Fail{S.failed_cleanup(value,S.Failure{"library_usage_step_limit","Bounded library Usage scan did not finish; no report was published"})}

def drive(left: Nat,value: L.Step) -> IO(Result<&2,&2,S.Failure,T.Report>):
  match left value:
    case _ L.Finished{report}: IO.pure(Result<&2,&2,S.Failure,T.Report>,Done{report})
    case _ L.Failed{failure}: IO.pure(Result<&2,&2,S.Failure,T.Report>,Fail{failure})
    case 0n L.More{run}:
      do IO<Result<&2,&2,S.Failure,T.Report>>:
        closed : Result<&2,&2,S.Failure,Unit> <- L.cancel(run)
        return exhausted(closed)
    case 1n+rest L.More{run}:
      do IO<Result<&2,&2,S.Failure,T.Report>>:
        next : L.Step <- L.step(run)
        drive(rest,next)

def begun(value: Result<&2,&1,S.Failure,L.Run>,left: Nat) -> IO(Result<&2,&2,S.Failure,T.Report>):
  match value:
    case Fail{failure}: IO.pure(Result<&2,&2,S.Failure,T.Report>,Fail{failure})
    case Done{run}: drive(left,L.More{run})

def encoded(value: Result<&2,&2,String,String>) -> answer():
  match value:
    case Fail{message}: Fail{S.Failure{"library_usage_wire",message}}
    case Done{text}: Done{text}

def report(value: Result<&2,&2,S.Failure,T.Report>,nonce: U32) -> answer():
  match value:
    case Fail{failure}: Fail{failure}
    case Done{value}: encoded(Wire.encode(nonce,value))

def execute_valid(valid: Bool,db: U32,nonce: U32) -> IO(answer()):
  match valid:
    case False{}: IO.pure(answer(),Fail{invalid()})
    case True{}:
      do IO<answer()>:
        started : Result<&2,&1,S.Failure,L.Run> <- L.begin(db,T.defaults())
        value : Result<&2,&2,S.Failure,T.Report> <- begun(started,fuel())
        return report(value,nonce)

# Internal caller-handle seam for tests and owned routing. The core owns and
# releases its read transaction; this function never closes a caller's handle.
def execute(db: U32,+nonce: U32) -> IO(answer()):
  execute_valid(U32.is_ne(nonce,0),db,nonce)

def closed(value: Result<&1,&1,U32 & String,Unit>,prior: answer()) -> answer():
  match value:
    case Done{_}: prior
    case Fail{_}: Fail{S.Failure{"library_usage_close","Selected library did not close cleanly; no report was published"}}

def opened(value: Result<&1,&1,U32 & String,U32>,nonce: U32) -> IO(answer()):
  match value:
    case Fail{_}: IO.pure(answer(),Fail{S.Failure{"library_usage_open","Cannot open the existing selected library read-only"}})
    case Done{+db}:
      do IO<answer()>:
        prior : answer() <- execute(db,nonce)
        result : Result<&1,&1,U32 & String,Unit> <- Sql.close(db)
        return closed(result,prior)

def root_valid(valid: Bool,dir: String,nonce: U32) -> IO(answer()):
  match valid:
    case False{}: IO.pure(answer(),Fail{S.Failure{"library_usage_root","Library Usage requires an explicit bounded absolute existing data directory"}})
    case True{}:
      do IO<answer()>:
        value : Result<&1,&1,U32 & String,U32> <- Sql.open_existing(dir ++ "/juice-bend.sqlite",0)
        opened(value,nonce)

def dispatch_parsed(value: Result<&2,&2,S.Failure,U32>,+dir: String) -> IO(answer()):
  match value:
    case Fail{failure}: IO.pure(answer(),Fail{failure})
    case Done{nonce}: root_valid(String.starts_with(dir,"/") && Ref.bounded(dir,4000),dir,nonce)

# Argument admission precedes every database open, including for missing roots.
# A typed failure or success returns only after this seam closes its handle.
def dispatch(dir: String,args: List<String>) -> IO(answer()):
  dispatch_parsed(parse(args),dir)

def error(value: S.Failure) -> String:
  S.Failure{code,message} = value
  "{\"kind\":\"library_usage_error\",\"version\":1,\"code\":" ++ J.quote(String.take(code,64n)) ++
    ",\"message\":" ++ J.quote(String.take(message,512n)) ++ "}"

def emit(value: answer()) -> IO(Unit):
  match value:
    case Fail{failure}: IO.die(Unit,2,error(failure))
    case Done{text}: IO.print(text)

def root(dir: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    value : answer() <- dispatch(dir,args)
    emit(value)

# Capture activation is a separate exact-identity request, not a latest lookup.
# The selected source is retained metadata, never opened as a filesystem path.
def capture_invalid() -> S.Failure:
  S.Failure{"library_usage_capture_arguments","Expected library-usage-capture-v1 NONCE CAPTURE_JSON START with exact bounded capture identity and canonical U32 start"}

def capture_value(value: Result<&2,&2,String,S.Capture>) -> Result<&2,&2,S.Failure,S.Capture>:
  match value:
    case Fail{_}: Fail{capture_invalid()}
    case Done{capture}: Done{capture}

def capture_json(value: Result<&2,&2,String,J.Json>) -> Result<&2,&2,S.Failure,S.Capture>:
  match value:
    case Fail{_}: Fail{capture_invalid()}
    case Done{json}: capture_value(Wire.parse_capture(json))

def capture_numbers(nonce: Result<&2,&2,S.Failure,U32>,start: Maybe<&2,U32>,text: String) -> Result<&2,&2,S.Failure,CaptureRequest>:
  match nonce start:
    case Done{nonce} Some{start}:
      do Result<&2,&2,S.Failure,CaptureRequest>:
        capture : S.Capture <- capture_json(J.parse(text))
        return CaptureRequest{nonce,capture,start}
    case _ _: Fail{capture_invalid()}

def capture_bound(valid: Bool,nonce: String,text: String,start: String) -> Result<&2,&2,S.Failure,CaptureRequest>:
  match valid:
    case False{}: Fail{capture_invalid()}
    case True{}: capture_numbers(parse([nonce]),D.parse_u32(start),text)

def parse_capture(args: List<String>) -> Result<&2,&2,S.Failure,CaptureRequest>:
  match args:
    case +nonce <> +text <> +start <> []:
      capture_bound(Ref.bounded(nonce,10) && Ref.bounded(text,16384) && Ref.bounded(start,10),nonce,text,start)
    case _: Fail{capture_invalid()}

# Same optional metadata admission as Cli.optional_response: the entire escaped
# page plus its LF must fit 1 MiB before cards are attached. Metadata may be
# omitted; canonical text is never truncated to make room for cards.
def optional_admitted(valid: Bool,prefix: String,full: String) -> String:
  match valid:
    case False{}: prefix ++ "}"
    case True{}: full

def optional_response(+prefix: String,metadata: String) -> String:
  +full = prefix ++ metadata ++ "}"
  optional_admitted(Ref.bounded(full,1048575),prefix,full)

# The existing eight-field scoped transcript envelope plus its optional typed
# descriptors. The outer capture remains identity authority, never page labels.
def page_text(capture: S.Capture,+start: U32,+document: Reader.Document) -> String:
  S.Capture{_,_,_,_,snapshot,_,records} = capture
  optional_response("{\"snapshot\":" ++ J.quote(snapshot) ++ ",\"start\":" ++ U32.show(start) ++
    ",\"requested_records\":40,\"selected_records\":" ++ U32.show(D.bounded_count(start,40,records)) ++
    ",\"kind\":\"scoped_transcript_page\",\"byte_space\":\"logical_source_bytes\",\"complete_export\":false,\"text\":" ++ J.quote(Reader.text(document)),
    ",\"reader_view\":" ++ ReaderWire.encode(document))

def capture_encoded(valid: Bool,text: String) -> answer():
  match valid:
    case False{}: Fail{S.Failure{"library_usage_capture_output","Whole captured transcript response exceeds the bounded output size; no page was published"}}
    case True{}: Done{text}

def capture_text_bounded(valid: Bool,nonce: U32,+capture: S.Capture,start: U32,document: Reader.Document) -> answer():
  match valid:
    case False{}: Fail{S.Failure{"library_usage_capture_output","Captured transcript text exceeds 1 MiB UTF8; no page was published"}}
    case True{}:
      +encoded = "{\"kind\":\"library_usage_capture\",\"version\":1,\"nonce\":" ++ U32.show(nonce) ++
        ",\"capture\":" ++ S.capture_text(capture) ++ ",\"page\":" ++ page_text(capture,start,document) ++ "}"
      capture_encoded(Ref.bounded(encoded,2097151),encoded)

def capture_reply(nonce: U32,capture: S.Capture,start: U32,+document: Reader.Document) -> answer():
  capture_text_bounded(Ref.bounded(Reader.text(document),1048576),nonce,capture,start,document)

def capture_rollback(+db: U32,failure: S.Failure) -> IO(answer()):
  do IO<answer()>:
    result : Result<&2,&2,S.Failure,Unit> <- S.cleanup(db)
    return Fail{S.failed_cleanup(result,failure)}

def capture_committed(value: Result<&2,&2,S.Failure,List<&2,List<&2,Sql.Cell>>>,db: U32,
  nonce: U32,capture: S.Capture,start: U32,document: Reader.Document) -> IO(answer()):
  match value:
    case Fail{failure}: capture_rollback(db,failure)
    case Done{[]}: IO.pure(answer(),capture_reply(nonce,capture,start,document))
    case Done{_}: IO.pure(answer(),Fail{S.Failure{"library_usage_capture_commit","Capture read transaction returned an unexpected completion result"}})

# Existing Maintenance/Scoped integrity aborts are worker-fatal; the parent
# catches the nonzero process exit. They are not converted into success or a
# weaker alternate reader. Normal typed refusals roll back before handle close.
def capture_verified(valid: Bool,+db: U32,nonce: U32,+capture: S.Capture,+start: U32) -> IO(answer()):
  match valid:
    case False{}: capture_rollback(db,S.Failure{"library_usage_capture_identity","Selected retained capture no longer matches every requested identity field"})
    case True{}:
      S.Capture{provider,_,source,_,+snapshot,_,records} = capture
      +scope : Scoped.Scope = Scoped.Scope{provider,"","",""}
      +size = D.bounded_count(start,40,records)
      stop = Bool.pick(U32,U32.is_eq(size,0),0,U32.add(start,size))
      do IO<answer()>:
        header : Maintenance.Header <- Maintenance.header(db,snapshot)
        output : Scoped.ReadState <- Scoped.scope_walk(False{},db,snapshot,header,source,scope,start,size,stop,False{})
        document : Reader.Document = Scoped.document_rendered(output,snapshot,start,40,scope)
        committed : Result<&2,&2,S.Failure,List<&2,List<&2,Sql.Cell>>> <- S.query(db,"COMMIT",[],0)
        capture_committed(committed,db,nonce,capture,start,document)

def capture_header(value: Result<&2,&2,S.Failure,S.Capture>,db: U32,nonce: U32,+expected: S.Capture,start: U32) -> IO(answer()):
  match value:
    case Fail{failure}: capture_rollback(db,failure)
    case Done{actual}: capture_verified(Wire.same_capture(actual,expected),db,nonce,expected,start)

def capture_started(value: Result<&2,&2,S.Failure,Unit>,+db: U32,request: CaptureRequest) -> IO(answer()):
  match value:
    case Fail{failure}: IO.pure(answer(),Fail{failure})
    case Done{_}:
      CaptureRequest{nonce,+capture,start} = request
      S.Capture{_,_,_,_,snapshot,_,_} = capture
      do IO<answer()>:
        actual : Result<&2,&2,S.Failure,S.Capture> <- S.header(db,snapshot)
        capture_header(actual,db,nonce,capture,start)

# Internal typed request comes only from parse_capture in the root route. The
# supplied handle remains caller-owned, and a failed BEGIN never rolls it back.
def execute_capture(+db: U32,request: CaptureRequest) -> IO(answer()):
  do IO<answer()>:
    started : Result<&2,&2,S.Failure,Unit> <- S.start(db)
    capture_started(started,db,request)

def capture_opened(value: Result<&1,&1,U32 & String,U32>,request: CaptureRequest) -> IO(answer()):
  match value:
    case Fail{_}: IO.pure(answer(),Fail{S.Failure{"library_usage_open","Cannot open the existing selected library read-only"}})
    case Done{+db}:
      do IO<answer()>:
        prior : answer() <- execute_capture(db,request)
        result : Result<&1,&1,U32 & String,Unit> <- Sql.close(db)
        return closed(result,prior)

def capture_root_valid(valid: Bool,dir: String,request: CaptureRequest) -> IO(answer()):
  match valid:
    case False{}: IO.pure(answer(),Fail{S.Failure{"library_usage_root","Library Usage requires an explicit bounded absolute existing data directory"}})
    case True{}:
      do IO<answer()>:
        value : Result<&1,&1,U32 & String,U32> <- Sql.open_existing(dir ++ "/juice-bend.sqlite",0)
        capture_opened(value,request)

def capture_dispatch_parsed(value: Result<&2,&2,S.Failure,CaptureRequest>,+dir: String) -> IO(answer()):
  match value:
    case Fail{failure}: IO.pure(answer(),Fail{failure})
    case Done{request}: capture_root_valid(String.starts_with(dir,"/") && Ref.bounded(dir,4000),dir,request)

def dispatch_capture(dir: String,args: List<String>) -> IO(answer()):
  capture_dispatch_parsed(parse_capture(args),dir)

def root_capture(dir: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    value : answer() <- dispatch_capture(dir,args)
    emit(value)

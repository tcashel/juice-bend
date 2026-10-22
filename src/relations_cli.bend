import Base
import ./relations.bend as R
import ./scoped_reader.bend as Scoped
import ./catalog.bend as Catalog
import ./provenance.bend as P
import ./json.bend as Json

# This adapter owns no transaction. Relations owns its bounded retained-raw
# read, and its exact snapshot references are the only navigation targets.
def failure(-A: Type,code: String,message: String) -> IO(A):
  IO.die(A,2,"{\"error\":" ++ Json.quote(message) ++ ",\"code\":" ++ Json.quote(code) ++ "}")

def require(-A: Kind(&2),result: Result<&2,&2,String,A>,code: String) -> IO(A):
  match result:
    case Done{value}:
      IO.pure(A,value)
    case Fail{message}:
      failure(A,code,message)

def ensure(valid: Bool,code: String,message: String) -> IO(Unit):
  match valid:
    case True{}:
      IO.pure(Unit,Unit{})
    case False{}:
      failure(Unit,code,message)

def number(value: Maybe<&2,U32>) -> IO(U32):
  match value:
    case Some{value}:
      IO.pure(U32,value)
    case None{}:
      failure(U32,"invalid_number","LIMIT must be an unsigned integer from 1 to 16")

def reference_json(reference: R.SnapshotRef) -> String:
  R.SnapshotRef{provider,source,generation,snapshot,extent} = reference
  "{\"provider\":" ++ Json.quote(provider) ++ ",\"source\":" ++ Json.quote(source) ++
    ",\"generation\":" ++ Json.quote(generation) ++ ",\"snapshot\":" ++ Json.quote(snapshot) ++
    ",\"extent\":" ++ Json.quote(extent) ++ "}"

def identity_json(identity: R.Identity) -> String:
  match identity:
    case R.Missing{}:
      "{\"kind\":\"missing\"}"
    case R.Known{value,record}:
      "{\"kind\":\"known\",\"value\":" ++ Json.quote(value) ++ ",\"record\":" ++ U32.show(record) ++ "}"
    case R.Invalid{reason}:
      "{\"kind\":\"invalid\",\"reason\":" ++ Json.quote(reason) ++ "}"
    case R.Conflicting{reason}:
      "{\"kind\":\"conflicting\",\"reason\":" ++ Json.quote(reason) ++ "}"

def parent_json(parent: R.Parent) -> String:
  match parent:
    case R.UnknownParent{}:
      "{\"kind\":\"unknown\"}"
    case R.RecordedParent{id,record}:
      "{\"kind\":\"recorded\",\"id\":" ++ Json.quote(id) ++ ",\"record\":" ++ U32.show(record) ++ "}"
    case R.PathAssociated{locator,parent_alias,child_alias}:
      "{\"kind\":\"path_associated\",\"locator\":" ++ Json.quote(locator) ++
        ",\"parent_alias\":" ++ Json.quote(parent_alias) ++ ",\"child_alias\":" ++ Json.quote(child_alias) ++ "}"
    case R.UnsupportedParent{reason}:
      "{\"kind\":\"unsupported\",\"reason\":" ++ Json.quote(reason) ++ "}"
    case R.ConflictingParent{reason}:
      "{\"kind\":\"conflicting\",\"reason\":" ++ Json.quote(reason) ++ "}"

def boolean(value: Bool) -> String:
  Bool.pick(String,value,"true","false")

def facts_json(facts: R.Facts) -> String:
  R.Facts{reference,session,repository,parent,inspected,total,bytes,complete,coverage} = facts
  "{\"reference\":" ++ reference_json(reference) ++ ",\"session\":" ++ identity_json(session) ++
    ",\"repository\":" ++ identity_json(repository) ++ ",\"parent\":" ++ parent_json(parent) ++
    ",\"inspected\":" ++ U32.show(inspected) ++ ",\"total_records\":" ++ U32.show(total) ++
    ",\"bytes\":" ++ U32.show(bytes) ++ ",\"complete\":" ++ boolean(complete) ++
    ",\"coverage\":" ++ Json.quote(coverage) ++ "}"

def record_json(value: Maybe<&2,U32>) -> String:
  match value:
    case None{}:
      "null"
    case Some{record}:
      U32.show(record)

def next_json(value: Maybe<&2,String>) -> String:
  match value:
    case None{}:
      "null"
    case Some{cursor}:
      Json.quote(cursor)

def row_json(row: R.Row) -> String:
  R.Row{target,direction,basis,witness,record,ambiguous} = row
  "{\"target\":" ++ facts_json(target) ++ ",\"direction\":" ++ Json.quote(direction) ++
    ",\"basis\":" ++ Json.quote(basis) ++ ",\"witness\":" ++ reference_json(witness) ++
    ",\"record\":" ++ record_json(record) ++ ",\"ambiguous_on_page\":" ++ boolean(ambiguous) ++ "}"

def rows_json(rows: List<&2,R.Row>) -> List<&2,String>:
  match rows:
    case []:
      []
    case row <> rest:
      row_json(row) <> rows_json(rest)

def coverage_json(coverage: R.Coverage) -> String:
  R.Coverage{unknown,conflicting,unsupported,partial,budget} = coverage
  "{\"unknown\":" ++ U32.show(unknown) ++ ",\"conflicting\":" ++ U32.show(conflicting) ++
    ",\"unsupported\":" ++ U32.show(unsupported) ++ ",\"partial\":" ++ U32.show(partial) ++
    ",\"unexamined_budget\":" ++ U32.show(budget) ++ "}"

def scope_json(scope: Scoped.Scope) -> String:
  Scoped.Scope{provider,repository,role,after} = scope
  "{\"provider\":" ++ Json.quote(provider) ++ ",\"repository\":" ++ Json.quote(repository) ++
    ",\"role\":" ++ Json.quote(role) ++ ",\"after\":" ++ Json.quote(after) ++ "}"

def facts_text(facts: R.Facts) -> String:
  R.Facts{reference,session,repository,parent,inspected,total,bytes,complete,coverage} = facts
  "Capture: " ++ reference_json(reference) ++ "\nSession: " ++ identity_json(session) ++
    "\nRepository: " ++ identity_json(repository) ++ "\nParent metadata: " ++ parent_json(parent) ++
    "\nVerified prefix: " ++ U32.show(inspected) ++ " of " ++ U32.show(total) ++
    " captured records; " ++ U32.show(bytes) ++ " retained logical source bytes; prefix interpretation complete: " ++
    boolean(complete) ++ "\nPrefix coverage: " ++ Json.quote(coverage) ++ "\n"

def row_text(row: R.Row,index: U32) -> String:
  R.Row{target,direction,basis,witness,record,ambiguous} = row
  U32.show(index) ++ ". " ++ direction ++ " · " ++ basis ++
    Bool.pick(String,ambiguous," · ambiguity observed in this page","") ++ "\n" ++ facts_text(target) ++
    "Relationship witness: " ++ reference_json(witness) ++ "\nCaptured record: " ++ record_json(record) ++
    " (null means retained path association; no event ordinal is asserted)\n\n"

def rows_text(rows: List<&2,R.Row>,+index: U32) -> String:
  match rows:
    case []:
      ""
    case row <> rest:
      row_text(row,index) ++ rows_text(rest,U32.inc(index))

def render(page: R.Page,scope: Scoped.Scope) -> String:
  R.Page{anchor,repository,watermark,after,next,limit,scanned,records,bytes,coverage,+rows} = page
  "Juice Bend · related captured sessions\nLibrary watermark: " ++ watermark ++
    " · inspected candidate sources: " ++ U32.show(scanned) ++ " of at most " ++ U32.show(limit) ++
    "\nRelated captures in this library as of the watermark; this is not a reconstructed historical graph." ++
    "\nRecorded parent links and retained path associations are separate. Path associations do not prove a recorded session parent." ++
    "\nAmbiguity flags cover this page only. Missing rows, a final cursor, or complete prefixes do not establish global uniqueness or absence of relatives." ++
    "\nOnly self-parent and directly observed two-way conflicts are checked; longer graph cycles are not detected or traversed." ++
    "\nRole/date filters are preserved for target readers; they do not filter relationship metadata." ++
    "\nFrozen reader scope: " ++ scope_json(scope) ++ "\nExact repository restriction: " ++ Json.quote(repository) ++
    "\nSource cursor: " ++ Json.quote(after) ++ " · next source: " ++ next_json(next) ++
    "\nVerified captured records including anchor: " ++ U32.show(records) ++
    " · retained logical source bytes: " ++ U32.show(bytes) ++ "\nCoverage counts: " ++ coverage_json(coverage) ++
    "\n\n" ++ Bool.pick(String,List.is_empty(&2,R.Row,rows),
      "No related capture was established in this inspected page. Unexamined sources or records may contain further metadata.\n\n","") ++
    rows_text(rows,1) ++ "Anchor\n" ++ facts_text(anchor)

def json(page: R.Page,scope: Scoped.Scope,requested: U32,text: String) -> String:
  R.Page{anchor,repository,watermark,after,next,limit,scanned,records,bytes,coverage,rows} = page
  "{\"kind\":\"related_captures\",\"anchor\":" ++ facts_json(anchor) ++
    ",\"watermark\":" ++ Json.quote(watermark) ++ ",\"after_source\":" ++ Json.quote(after) ++
    ",\"next_source\":" ++ next_json(next) ++ ",\"requested_limit\":" ++ U32.show(requested) ++
    ",\"limit\":" ++ U32.show(limit) ++ ",\"scanned_sources\":" ++ U32.show(scanned) ++
    ",\"inspected_records\":" ++ U32.show(records) ++ ",\"inspected_bytes\":" ++ U32.show(bytes) ++
    ",\"coverage\":" ++ coverage_json(coverage) ++ ",\"scope\":" ++ scope_json(scope) ++
    ",\"rows\":[" ++ String.join(rows_json(rows),",") ++ "],\"text\":" ++ Json.quote(text) ++ "}"

def next_valid(next: Maybe<&2,String>,after: String,scanned: U32,limit: U32) -> Bool:
  match next:
    case None{}:
      True{}
    case Some{+cursor}:
      Catalog.identity_valid(cursor) && Cmp.is_gt(P.decimal_compare(cursor,after)) && U32.is_eq(scanned,limit)

def page_valid(page: R.Page,+scope: Scoped.Scope,+requested: U32) -> Bool:
  R.Page{+anchor,repository,+watermark,+after,next,+limit,+scanned,records,bytes,_,rows} = page
  Scoped.Scope{_,expected_repo,_,_} = scope
  R.valid_ref(R.facts_ref(anchor)) && Catalog.identity_valid(watermark) &&
    Bool.not(Cmp.is_gt(P.decimal_compare(R.ref_id(R.facts_ref(anchor)),watermark))) &&
    (String.eq(after,"0") || Catalog.identity_valid(after)) &&
    U32.is_gt(requested,0) && U32.is_le(requested,16) && U32.is_eq(limit,U32.min(requested,15)) &&
    U32.is_le(scanned,limit) && U32.is_le(records,256) && U32.is_le(bytes,2097152) &&
    Nat.is_le(List.length(&2,R.Row,rows),U32.to_nat(U32.mul(scanned,2))) &&
    next_valid(next,after,scanned,limit) && String.eq(repository,expected_repo) &&
    Scoped.valid(scope) && Scoped.provider_allowed(scope,R.ref_provider(R.facts_ref(anchor)))

def bounded(valid: Bool,text: String) -> Result<&2,&2,String,String>:
  match valid:
    case True{}:
      Done{text}
    case False{}:
      Fail{"Escaped related-capture output exceeds the 1048576-byte worker bound; choose a smaller candidate page. No payload was truncated"}

def encoded(valid: Bool,page: R.Page,scope: Scoped.Scope,requested: U32,text: String) -> Result<&2,&2,String,String>:
  match valid:
    case False{}:
      Fail{"Related-capture metadata violates its identity, scope, cursor, or bounded-page contract"}
    case True{}:
      +output = json(page,scope,requested,text)
      bounded(R.utf8_fits(output,1048575),output)

# Includes the escaped envelope and IO.print's trailing newline in the bound.
def encode(+page: R.Page,+scope: Scoped.Scope,+requested: U32,text: String) -> Result<&2,&2,String,String>:
  encoded(page_valid(page,scope,requested),page,scope,requested,text)

def provider(page: R.Page) -> String:
  R.Page{anchor,_,_,_,_,_,_,_,_,_,_} = page
  R.ref_provider(R.facts_ref(anchor))

def output(result: Result<&2,&2,String,R.Page>,+scope: Scoped.Scope,requested: U32) -> IO(Unit):
  do IO<Unit>:
    +page : R.Page <- require(R.Page,result,"relations_unavailable")
    ensure(Scoped.provider_allowed(scope,provider(page)),"scope_mismatch",
      "Selected capture does not match the frozen provider filter; the filter was not cleared")
    +text : String = render(page,scope)
    encoded : String <- require(String,encode(page,scope,requested,text),"output_too_large")
    IO.print(encoded)

def valid_scope(+scope: Scoped.Scope) -> Bool:
  Scoped.Scope{_,+repo,_,_} = scope
  Scoped.valid(scope) && (String.is_empty(repo) || R.canonical_path(repo))

def open(db: U32,snapshot: String,limit: String,+scope: Scoped.Scope) -> IO(Unit):
  Scoped.Scope{_,repository,_,_} = scope
  do IO<Unit>:
    +size : U32 <- number(P.parse_u32(limit))
    ensure(valid_scope(scope),"invalid_scope","Invalid provider, canonical repository, role, or calendar date scope")
    result : Result<&2,&2,String,R.Page> <- R.open(db,snapshot,repository,size)
    output(result,scope,size)

def page(db: U32,expected: R.SnapshotRef,watermark: String,after: String,limit: String,+scope: Scoped.Scope) -> IO(Unit):
  Scoped.Scope{_,repository,_,_} = scope
  do IO<Unit>:
    +size : U32 <- number(P.parse_u32(limit))
    ensure(valid_scope(scope),"invalid_scope","Invalid provider, canonical repository, role, or calendar date scope")
    result : Result<&2,&2,String,R.Page> <- R.page(db,expected,repository,watermark,after,size)
    output(result,scope,size)

def command(db: U32,mode: String,args: List<String>) -> IO(Unit):
  match mode args:
    case "relations-scope" snapshot <> limit <> provider <> repository <> role <> after <> []:
      open(db,snapshot,limit,Scoped.Scope{provider,repository,role,after})
    case "relations-page" provider <> source <> generation <> snapshot <> extent <> watermark <> cursor <> limit <> filter_provider <> repository <> role <> after <> []:
      page(db,R.SnapshotRef{provider,source,generation,snapshot,extent},watermark,cursor,limit,
        Scoped.Scope{filter_provider,repository,role,after})
    case _ _:
      failure(Unit,"usage","usage: relations-scope SNAPSHOT LIMIT FILTER_PROVIDER FILTER_REPOSITORY FILTER_ROLE FILTER_AFTER; relations-page PROVIDER SOURCE GENERATION SNAPSHOT EXTENT WATERMARK AFTER_SOURCE LIMIT FILTER_PROVIDER FILTER_REPOSITORY FILTER_ROLE FILTER_AFTER; LIMIT is 1..16, effective maximum 15")

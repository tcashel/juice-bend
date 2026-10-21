import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./domain.bend as Domain
import ./providers.bend as Providers
import ./json.bend as Json
import ./provenance.bend as P
import ./timestamp.bend as Timestamp

# Only retained, integrity-checked bytes create evidence. SQL events are
# candidate locators; their text/arguments never become the quoted authority.
# Extents and record ordinals describe logical source bytes and source record
# order. Archives keep compressed-container offsets in their separate envelope.
type Verified is Data:
  Verified{provider: String, source: String, generation: String, snapshot: String,
    extent: String, ordinal: String, events: List<&2, Providers.Record>}

type PatchState is Data:
  PatchState{active: Bool, added: List<&2, String>}

def quote(s: String) -> String:
  Json.encode(Json.JString{s})

def citation(record: Verified, event: U32) -> String:
  Verified{provider, source, generation, snapshot, extent, ordinal, _} = record
  "{\"provider\":" ++ quote(provider) ++ ",\"source\":" ++ quote(source) ++
    ",\"generation\":" ++ quote(generation) ++ ",\"snapshot\":" ++ quote(snapshot) ++
    ",\"extent\":" ++ quote(extent) ++ ",\"record\":" ++ quote(ordinal) ++
    ",\"event\":" ++ quote(U32.show(event)) ++ "}"

def event_at(events: List<&2, Providers.Record>, index: Nat) -> Maybe<&2, Providers.Record>:
  match events index:
    case [] _:
      None{}
    case event <> _ 0n:
      Some{event}
    case _ <> rest 1n+tail:
      event_at(rest, tail)

def record_event(record: Verified, index: U32) -> Maybe<&2, Providers.Record>:
  Verified{_, _, _, _, _, _, events} = record
  event_at(events, U32.to_nat(index))

def verified_row(db: U32, +snapshot: String, +ordinal: U32, rows: List<&2, List<&2, Sql.Cell>>) ->
  IO(Verified):
  match rows:
    case []:
      IO.die(Verified, 1, "Captured evidence record is missing")
    case +row <> _:
      do IO<Verified>:
        Store.checked(Store.numeric(Store.field(row, 1n)) &&
          Store.numeric(Store.field(row, 2n)), "Captured evidence snapshot numeric metadata is corrupt")
        +raw : List<&2,Sql.Cell> <- Store.selected_record(db,snapshot,Store.field(row,0n),
          Store.number(Store.field(row,1n)),Store.number(Store.field(row,2n)),ordinal)
        return Verified{Store.field(row, 3n), Store.field(row, 4n),
          Store.field(row, 0n), snapshot, Store.field(row, 1n), U32.show(ordinal),
          Store.piece_events(U32.is_ne(Store.number(Store.field(raw, 6n)), 0),
            Store.field(row, 3n), Store.blob(Store.cell(raw, 5n)))}

def record_rows(db: U32, snapshot: String, ordinal: U32) ->
  IO(List<&2, List<&2, Sql.Cell>>):
  Store.q(db,
    "SELECT p.generation,p.extent,p.records,s.provider,s.locator FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=? AND p.accepted=1 AND EXISTS(SELECT 1 FROM records i WHERE i.snapshot=p.id AND i.ordinal=?)",
    [Sql.Cell.Integer{snapshot}, Sql.Cell.Integer{U32.show(ordinal)}], 1)

def read_record(+db: U32, +snapshot: String, +ordinal: U32) -> IO(Verified):
  do IO<Verified>:
    rows : List<&2, List<&2, Sql.Cell>> <- record_rows(db,snapshot,ordinal)
    verified_row(db, snapshot, ordinal, rows)

def first_repo(events: List<&2, Providers.Record>) -> String:
  match events:
    case []:
      ""
    case Providers.ProviderEvent{_, _, _, _, _, _, repo, _, _, _, _, _, _} <> rest:
      Store.nonempty(repo, first_repo(rest))

def record_repo(record: Verified) -> String:
  Verified{_, _, _, _, _, _, events} = record
  first_repo(events)

# A missing per-record cwd may use the verified first raw record's cwd.
# Other metadata layouts remain unsupported instead of trusting SQL scope alone.
def event_repo(event: Providers.Record) -> String:
  Providers.ProviderEvent{_, _, _, _, _, _, repo, _, _, _, _, _, _} = event
  repo

def scoped_repository(+repo: String, event: Providers.Record, first: Verified) -> Bool:
  String.eq(repo, Store.nonempty(event_repo(event), record_repo(first)))

def path_equal(+repo: String, +path: String, +logged: String) -> Bool:
  P.safe_path(path) && (String.eq(logged, path) || String.eq(logged, repo ++ "/" ++ path))

def edit_fields(tool: String, +args: Json.Json) -> String:
  match tool:
    case "Edit":
      Json.get(args, "new_string")
    case "Write":
      Json.get(args, "content")
    case _:
      ""

def patch_path(line: String) -> String:
  String.drop(line, 17n)

def patch_step_kind(state: PatchState, kind: U32, +line: String, +repo: String, +path: String) -> PatchState:
  PatchState{+active, +added} = state
  match kind:
    case 1:
      PatchState{path_equal(repo, path, String.drop(line, 17n)), added}
    case 2:
      PatchState{path_equal(repo, path, String.drop(line, 14n)), added}
    case 3:
      PatchState{False{}, added}
    case 4:
      PatchState{active, Bool.pick(List<&2, String>, active,
        String.drop(line, 1n) <> added, added)}
    case _:
      PatchState{active, added}

def patch_kind(+line: String) -> U32:
  Bool.pick(U32, String.starts_with(line, "*** Update File: "), 1,
    Bool.pick(U32, String.starts_with(line, "*** Add File: "), 2,
      Bool.pick(U32, String.starts_with(line, "*** "), 3,
        Bool.pick(U32, String.starts_with(line, "+"), 4, 0))))

def patch_scan(lines: List<&2, String>, +repo: String, +path: String,
  state: PatchState) -> List<&2, String>:
  match lines:
    case []:
      PatchState{_, added} = state
      List.reverse(&2, String, added)
    case +line <> rest:
      patch_scan(rest, repo, path, patch_step_kind(state, patch_kind(line), line, repo, path))

def patch_lines(valid: Bool, patch: String, repo: String, path: String) -> List<&2, String>:
  match valid:
    case False{}:
      []
    case True{}:
      patch_scan(String.lines(patch), repo, path, PatchState{False{}, []})

def patch_text(+patch: String, repo: String, path: String) -> List<&2, String>:
  patch_lines(String.starts_with(patch, "*** Begin Patch\n") &&
    String.contains(patch, "*** End Patch") &&
    Bool.not(String.contains(patch, "*** Move to:")), patch, repo, path)

def argument_patch(+args: Json.Json) -> String:
  Store.nonempty(Json.get(args, "patch"), Json.get(args, "input"))

def edit_decoded(result: Result<&2, &2, String, Json.Json>, +tool: String,
  +raw: String, +repo: String, +path: String) -> List<&2, String>:
  match result:
    case Fail{_}:
      Bool.pick(List<&2, String>,
        String.eq(tool, "apply_patch") || String.eq(tool, "functions.apply_patch"),
        patch_text(raw, repo, path), [])
    case Done{+args}:
      match tool:
        case "Edit":
          Bool.pick(List<&2, String>, path_equal(repo, path, Json.get(args, "file_path")),
            String.lines(edit_fields("Edit", args)), [])
        case "Write":
          Bool.pick(List<&2, String>, path_equal(repo, path, Json.get(args, "file_path")),
            String.lines(edit_fields("Write", args)), [])
        case "apply_patch":
          patch_text(argument_patch(args), repo, path)
        case "functions.apply_patch":
          patch_text(argument_patch(args), repo, path)
        case _:
          []

def edit_lines(+tool: String, +arguments: String, +repo: String, +path: String) ->
  List<&2, String>:
  edit_decoded(Json.parse(arguments), tool, arguments, repo, path)

def time_digits(value: String) -> String:
  match value:
    case SNil{}:
      ""
    case SCon{+head,rest}:
      +tail = time_digits(rest)
      Bool.pick(String,Char.is_digit(head),SCon{head,tail},tail)

def time_canonical(value: String) -> String:
  match value:
    case SCon{'0',SCon{head,rest}}:
      time_canonical(SCon{head,rest})
    case other:
      other

def time_rank(result: Result<&2,&2,String,String>) -> String:
  match result:
    case Fail{_}:
      "0"
    case Done{normalized}:
      time_canonical(time_digits(normalized))

# A UTC calendar rank preserves exact timestamp ordering through nanoseconds.
# It is not Unix time. Numeric or unparseable source times remain unknown so
# incompatible timestamp units cannot silently compete with calendar ranks.
def candidate_time(time: String) -> String:
  time_rank(Timestamp.parse(time))

def candidate_event(event: Maybe<&2, Providers.Record>, +record: Verified,
  first: Verified, +repo: String, path: String, event_index: U32) -> Maybe<&2, P.Candidate>:
  match event:
    case None{}:
      None{}
    case Some{+value}:
      Providers.ProviderEvent{_, _, +tool, _, arguments, _, _, _, timestamp, _, _, _, coverage} = value
      Bool.pick(Maybe<&2, P.Candidate>,
        scoped_repository(repo, value, first) && String.eq(coverage, "complete"),
        Some{P.Candidate{repo, citation(record, event_index), candidate_time(timestamp),
          edit_lines(tool, arguments, repo, path), True{}}}, None{})

def candidates_add(value: Maybe<&2, P.Candidate>, rest: List<&2, P.Candidate>) ->
  List<&2, P.Candidate>:
  match value:
    case None{}:
      rest
    case Some{candidate}:
      candidate <> rest

def candidates(rows: List<&2, List<&2, Sql.Cell>>, +db: U32, +repo: String, +path: String) ->
  IO(List<&2, P.Candidate>):
  match rows:
    case []:
      IO.pure(List<&2, P.Candidate>, [])
    case +row <> rest:
      +snap = Store.field(row, 0n)
      +ord = Store.number(Store.field(row, 1n))
      +event_index = Store.number(Store.field(row, 2n))
      do IO<List<&2, P.Candidate>>:
        Store.checked(Store.numeric(Store.field(row, 1n)) && Store.numeric(Store.field(row, 2n)),
          "Candidate event index is corrupt")
        +record : Verified <- read_record(db, snap, ord)
        first : Verified <- read_record(db, snap, 0)
        tail : List<&2, P.Candidate> <- candidates(rest, db, repo, path)
        return candidates_add(candidate_event(record_event(record, event_index),
          record, first, repo, path, event_index), tail)

def candidate_rows(db: U32, repo: String) -> IO(List<&2, List<&2, Sql.Cell>>):
  Store.q(db,
    "SELECT e.snapshot,e.ordinal,e.event FROM events e JOIN snapshots p ON p.id=e.snapshot AND p.accepted=1 JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source AND s.latest=p.id WHERE e.repository=? AND e.tool IN ('Edit','Write','apply_patch','functions.apply_patch') ORDER BY e.snapshot DESC,e.ordinal DESC,e.event LIMIT 32",
    [Sql.Cell.Text{repo}], 32)

def attribution_text(result: P.Attribution) -> String:
  match result:
    case P.Content{key, matched, eligible}:
      "content · " ++ Nat.show(matched) ++ "/" ++ Nat.show(eligible) ++
        " eligible lines\nCitation: " ++ key
    case P.Uncommitted{}:
      "uncommitted · no committed authorship claimed"
    case P.Ambiguous{reason}:
      "ambiguous · " ++ reason
    case P.NotIndexed{reason}:
      "not_indexed · " ++ reason
    case P.Exact{key}:
      "exact\nCitation: " ++ key
    case P.Probable{key, basis}:
      "probable · " ++ basis ++ "\nCitation: " ++ key

def line_attribution(is_uncommitted: Bool, repo: String, text: String,
  pool: List<&2, P.Candidate>) -> P.Attribution:
  match is_uncommitted:
    case True{}:
      P.Uncommitted{}
    case False{}:
      P.content(repo, [text], pool)

def render_regions(regions: List<&2, P.Region>, +repo: String, +pool: List<&2, P.Candidate>) ->
  String:
  match regions:
    case []:
      ""
    case P.Region{+sha, original, current, _, +text} <> rest:
      "Line " ++ U32.show(current) ++ " · commit " ++ sha ++
        " · original line " ++ U32.show(original) ++ "\n" ++
        String.take(text, 400n) ++ "\n" ++
        attribution_text(line_attribution(P.uncommitted(sha), repo, text, pool)) ++
        "\n\n" ++ render_regions(rest, repo, pool)

def blame_git(result: Result<&2, &2, String, List<&2, P.Region>>,
  +db: U32, +repo: String, +path: String) -> IO(String):
  match result:
    case Fail{error}:
      IO.pure(String, "Blame unavailable: " ++ error)
    case Done{regions}:
      do IO<String>:
        rows : List<&2, List<&2, Sql.Cell>> <- candidate_rows(db, repo)
        pool : List<&2, P.Candidate> <- candidates(rows, db, repo, path)
        return "Juice Bend · captured content provenance\nRepository: " ++ repo ++
          "\nFile: " ++ path ++
          "\nCoverage: newest 32 edit events considered; selected raw records verified." ++
          "\nPer-line content overlap is not an exact Git commit link. Recorded edit requests do not prove tool success." ++
          "\nOrigin eligibility and child-parent remapping are not established. Valid RFC3339 timestamps break equal-content ties in exact UTC order; unsupported times remain unknown." ++
          "\nNon-ASCII-only content cannot establish attribution.\n\n" ++
          render_regions(regions, repo, pool)

def blame_valid(valid: Bool, +db: U32, +repo: String, +path: String,
  +start: U32, count: U32) -> IO(String):
  match valid:
    case False{}:
      IO.pure(String, "Blame unavailable: line range must be 1 through 100 lines without overflow")
    case True{}:
      do IO<String>:
        result : Result<&2, &2, String, List<&2, P.Region>> <-
          P.git_blame(repo, path, start, U32.sub(U32.add(start, count), 1))
        blame_git(result, db, repo, path)

def blame(db: U32, repo: String, path: String, +start: U32, +count: U32) -> IO(String):
  blame_valid(U32.is_gt(start, 0) && U32.is_gt(count, 0) && U32.is_le(count, 100) &&
    U32.is_le(start, U32.sub(4294967295, count)), db, repo, path, start, count)

def why_event(+record: Verified, index: U32, event: Providers.Record) -> String:
  Providers.ProviderEvent{+role, text, +tool, _, arguments, result, _, _, timestamp, model, _, parent, coverage} = event
  "Recorded " ++ role ++ Store.nonempty(tool, "") ++
    "\nCitation: " ++ citation(record, index) ++
    "\nTime: " ++ timestamp ++ " · recorded model: " ++ Store.nonempty(model, "unknown") ++
    "\nCoverage: " ++ coverage ++ " · parent reference: " ++ Store.nonempty(parent, "not captured") ++
    "\n" ++ String.take(text, 2048n) ++
    "\nArguments: " ++ String.take(arguments, 2048n) ++
    "\nResult: " ++ String.take(result, 2048n) ++ "\n\n"

def why_events(events: List<&2, Providers.Record>, +record: Verified, +index: U32) -> String:
  match events:
    case []:
      ""
    case event <> rest:
      why_event(record, index, event) ++ why_events(rest, record, U32.add(index, 1))

def why_record(+record: Verified) -> String:
  Verified{_, _, _, _, _, _, events} = record
  why_events(events, record, 0)

def why_records(fuel: Nat, +db: U32, +snapshot: String, +ordinal: U32) -> IO(String):
  match fuel:
    case 0n:
      IO.pure(String, "")
    case 1n+rest:
      do IO<String>:
        record : Verified <- read_record(db, snapshot, ordinal)
        tail : String <- why_records(rest, db, snapshot, U32.add(ordinal, 1))
        return why_record(record) ++ tail

def why_header(rows: List<&2, List<&2, Sql.Cell>>, db: U32, snapshot: String,
  +start: U32, count: U32) -> IO(String):
  match rows:
    case []:
      IO.pure(String, "Why unavailable: accepted snapshot not found")
    case +row <> _:
      do IO<String>:
        Store.checked(Store.numeric(Store.field(row, 0n)), "Snapshot record count is corrupt")
        content : String <- why_records(U32.to_nat(Domain.bounded_count(start, U32.min(count, 20),
          Store.number(Store.field(row, 0n)))), db, snapshot, start)
        return "Juice Bend · captured Why evidence\nRationale: only the recorded requests below; no inferred explanation." ++
          "\nCommit linkage: not_captured. Tool arguments are recorded intent; successful changes are not inferred." ++
          "\nCoverage: selected retained records verified; at most 20 records; each field excerpt bounded to 2048 characters." ++
          "\nByte offsets: logical source bytes (decompressed for archives)." ++
          "\nOrigin eligibility and parent remapping are not assessed; unsupported records remain explicit.\n\n" ++ content

def why(+db: U32, +snapshot: String, start: U32, count: U32) -> IO(String):
  do IO<String>:
    rows : List<&2, List<&2, Sql.Cell>> <- Store.q(db,
      "SELECT records FROM snapshots WHERE id=? AND accepted=1",
      [Sql.Cell.Integer{snapshot}], 1)
    why_header(rows, db, snapshot, start, count)

# Consume exported citation descriptors without following "latest". Every
# component is checked against retained evidence, including provider/source
# ownership and the immutable generation. No original log is consulted.
type Descriptor is Data:
  Descriptor{key: Domain.EvidenceKey, extent: String, ordinal: U32, event: U32}

def descriptor_field(value: Json.Json) -> String:
  match value:
    case Json.JString{text}:
      text
    case _:
      ""

def descriptor_get(value: Json.Json,name: String) -> String:
  descriptor_field(Json.field(value,name))

def positive_id(+id: String) -> Bool:
  P.decimal_valid(id) && Bool.not(String.eq(id,"0")) &&
    Bool.not(Cmp.is_gt(P.decimal_compare(id,"9223372036854775807")))

def descriptor_checked(key: Domain.EvidenceKey,extent: String,
  ordinal: U32,event: U32,valid: Bool) -> Result<&2,&2,String,Descriptor>:
  match valid:
    case False{}:
      Fail{"Citation requires canonical string-valued provider/source/generation/snapshot/extent/record/event fields"}
    case True{}:
      Done{Descriptor{key,extent,ordinal,event}}

def descriptor_json(+value: Json.Json) -> Result<&2,&2,String,Descriptor>:
  +provider = descriptor_get(value,"provider")
  +source = descriptor_get(value,"source")
  +generation = descriptor_get(value,"generation")
  +snapshot = descriptor_get(value,"snapshot")
  +extent = descriptor_get(value,"extent")
  +ordinal = descriptor_get(value,"record")
  +event = descriptor_get(value,"event")
  descriptor_checked(Domain.EvidenceKey{provider,source,generation,snapshot,ordinal,event},
    extent,Store.number(ordinal),Store.number(event),
    (String.eq(provider,"claude") || String.eq(provider,"codex")) &&
      Bool.not(String.is_empty(source)) && Nat.is_le(String.length(source),4096n) &&
      positive_id(generation) && positive_id(snapshot) &&
      Store.numeric(extent) && Store.numeric(ordinal) && Store.numeric(event))

def descriptor_parse(result: Result<&2,&2,String,Json.Json>) ->
  Result<&2,&2,String,Descriptor>:
  match result:
    case Fail{error}:
      Fail{"Invalid citation JSON: " ++ error}
    case Done{value}:
      descriptor_json(value)

def record_key(record: Verified,event: U32) -> Domain.EvidenceKey:
  Verified{provider,source,generation,snapshot,_,ordinal,_} = record
  Domain.EvidenceKey{provider,source,generation,snapshot,ordinal,U32.show(event)}

def citation_event(valid: Bool,record: Verified,index: U32,
  event: Maybe<&2,Providers.Record>) -> Result<&2,&2,String,String>:
  match valid:
    case False{}:
      Fail{"Citation identity or extent differs from the retained captured record"}
    case True{}:
      match event:
        case None{}:
          Fail{"Citation event is absent from the retained raw record"}
        case Some{value}:
          Done{why_event(record,index,value)}

def citation_verified(descriptor: Descriptor,+record: Verified) ->
  Result<&2,&2,String,String>:
  Descriptor{key,extent,_,+index} = descriptor
  Verified{_,_,_,_,actual_extent,_,_} = record
  citation_event(Domain.ref_equal(key,record_key(record,index)) &&
    String.eq(extent,actual_extent),record,index,record_event(record,index))

def citation_rows(db: U32,rows: List<&2,List<&2,Sql.Cell>>,+descriptor: Descriptor) ->
  IO(Result<&2,&2,String,String>):
  match rows:
    case []:
      IO.pure(Result<&2,&2,String,String>,Fail{"Citation snapshot or record is not captured"})
    case row <> rest:
      Descriptor{Domain.EvidenceKey{_,_,_,snapshot,_,_},_,ordinal,_} = descriptor
      do IO<Result<&2,&2,String,String>>:
        record : Verified <- verified_row(db,snapshot,ordinal,row <> rest)
        return citation_verified(descriptor,record)

def citation_descriptor(+db: U32,result: Result<&2,&2,String,Descriptor>) ->
  IO(Result<&2,&2,String,String>):
  match result:
    case Fail{error}:
      IO.pure(Result<&2,&2,String,String>,Fail{error})
    case Done{+descriptor}:
      Descriptor{Domain.EvidenceKey{_,_,_,snapshot,_,_},_,ordinal,_} = descriptor
      do IO<Result<&2,&2,String,String>>:
        rows : List<&2,List<&2,Sql.Cell>> <- record_rows(db,snapshot,ordinal)
        citation_rows(db,rows,descriptor)

def citation_size(db: U32,descriptor: String,bounded: Bool) ->
  IO(Result<&2,&2,String,String>):
  match bounded:
    case False{}:
      IO.pure(Result<&2,&2,String,String>,Fail{"Citation exceeds 16384 characters"})
    case True{}:
      citation_descriptor(db,descriptor_parse(Json.parse(descriptor)))

def resolve_citation(db: U32,+descriptor: String) -> IO(Result<&2,&2,String,String>):
  citation_size(db,descriptor,Nat.is_le(String.length(descriptor),16384n))

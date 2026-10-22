import Base
import ./result_links.bend as Links
import ./result_link.bend as Link
import ./relations.bend as R
import ./relations_cli.bend as RC
import ./scoped_reader.bend as Scoped
import ./json.bend as Json
import ./provenance.bend as P

# Additive worker adapter. The shared CLI/GUI owner must explicitly route these
# commands; existing related_captures envelopes are not relabeled or weakened.
def recorded_fields(recorded: Link.Recorded) -> String:
  match recorded:
    case Link.Agent{id,call}:
      ",\"agent_id\":" ++ Json.quote(id) ++ ",\"tool_use_id\":" ++ Json.quote(call)
    case _: ""

def recorded_json(+recorded: Link.Recorded) -> String:
  "{\"kind\":" ++ Json.quote(Link.status(recorded)) ++
    ",\"reason\":" ++ Json.quote(Link.reason(recorded)) ++ recorded_fields(recorded) ++ "}"

def selected_json(selection: Links.Selected) -> String:
  Links.Selected{reference,ordinal,event,scope,recorded,facts,citation,bytes} = selection
  "{\"reference\":" ++ RC.reference_json(reference) ++ ",\"record\":" ++ U32.show(ordinal) ++
    ",\"event\":" ++ U32.show(event) ++ ",\"scope\":" ++ RC.scope_json(scope) ++
    ",\"recorded\":" ++ recorded_json(recorded) ++ ",\"facts\":" ++ RC.facts_json(facts) ++
    ",\"citation\":" ++ citation ++ ",\"selected_and_predecessor_bytes\":" ++ U32.show(bytes) ++ "}"

def state(recorded: Link.Recorded,+count: Nat,complete: Bool) -> String:
  match recorded:
    case Link.Agent{_,_}:
      Bool.pick(String,Nat.is_gt(count,1n),"ambiguous_on_page",
        Bool.pick(String,Nat.is_eq(count,1n),"candidate_on_page",
          Bool.pick(String,complete,"missing_on_page","incomplete")))
    case other: Link.status(other)

def status(+page: Links.Page) -> String:
  Links.Page{Links.Selected{_,_,_,_,recorded,_,_,_},_,_,_,_,_,_,_,_,rows} = page
  state(recorded,List.length(&2,R.Row,rows),Links.complete(page))

def render(+page: Links.Page) -> String:
  Links.Page{Links.Selected{_,_,_,scope,+recorded,_,citation,_},watermark,after,next,limit,
    scanned,records,bytes,coverage,rows} = page
  "Juice Bend · recorded child result\nStatus: " ++ status(page) ++ "\n" ++ Link.reason(recorded) ++
    "\nSelected result citation: " ++ citation ++ "\nFrozen target-reader scope: " ++ RC.scope_json(scope) ++
    "\nRecorded agentId plus retained path and repository matching supports navigation only; it does not establish authorship or a human request." ++
    "\nEach target retains its own provider session identity. A standalone result needs no recovered tool call." ++
    "\nCandidates and ambiguity are page-local. Other pages, partial prefixes and skipped sources remain incomplete; no global uniqueness is claimed." ++
    "\nLibrary watermark: " ++ watermark ++ " · source cursor: " ++ after ++ " · next: " ++ RC.next_json(next) ++
    "\nInspected sources: " ++ U32.show(scanned) ++ " of " ++ U32.show(limit) ++
    "; selected/predecessor plus candidate records: " ++ U32.show(records) ++ "; retained bytes: " ++ U32.show(bytes) ++
    "\nCoverage: " ++ RC.coverage_json(coverage) ++ "\n\n" ++ RC.rows_text(rows,1)

def json(+page: Links.Page) -> String:
  Links.Page{selection,watermark,after,next,limit,scanned,records,bytes,coverage,rows} = page
  "{\"kind\":\"recorded_child_result\",\"status\":" ++ Json.quote(status(page)) ++
    ",\"selected\":" ++ selected_json(selection) ++ ",\"watermark\":" ++ Json.quote(watermark) ++
    ",\"after_source\":" ++ Json.quote(after) ++ ",\"next_source\":" ++ RC.next_json(next) ++
    ",\"limit\":" ++ U32.show(limit) ++ ",\"scanned_sources\":" ++ U32.show(scanned) ++
    ",\"inspected_records\":" ++ U32.show(records) ++ ",\"inspected_bytes\":" ++ U32.show(bytes) ++
    ",\"page_metadata_complete\":" ++ RC.boolean(Links.complete(page)) ++
    ",\"coverage\":" ++ RC.coverage_json(coverage) ++ ",\"rows\":[" ++ String.join(RC.rows_json(rows),",") ++
    "],\"text\":" ++ Json.quote(render(page)) ++ "}"

def encode(page: Links.Page) -> Result<&2,&2,String,String>:
  +text = json(page)
  RC.bounded(R.utf8_fits(text,1048575),text)

def output(value: Result<&2,&2,String,Links.Page>) -> IO(Unit):
  do IO<Unit>:
    page : Links.Page <- RC.require(Links.Page,value,"child_result_unavailable")
    text : String <- RC.require(String,encode(page),"output_too_large")
    IO.print(text)

def number(value: Maybe<&2,U32>) -> IO(U32):
  match value:
    case Some{value}: IO.pure(U32,value)
    case None{}: RC.failure(U32,"invalid_number","Record, event and limit require unsigned integers; limit is 1 to 15")

def page(db: U32,reference: R.SnapshotRef,ordinal: String,event: String,scope: Scoped.Scope,
  watermark: String,after: String,limit: String) -> IO(Unit):
  do IO<Unit>:
    at : U32 <- number(P.parse_u32(ordinal))
    slot : U32 <- number(P.parse_u32(event))
    size : U32 <- number(P.parse_u32(limit))
    value : Result<&2,&2,String,Links.Page> <- Links.page(db,reference,at,slot,scope,watermark,after,size)
    output(value)

def command(db: U32,mode: String,args: List<String>) -> IO(Unit):
  match mode args:
    case "result-link-page" provider <> source <> generation <> snapshot <> extent <> ordinal <> event <> watermark <> cursor <> limit <> filter_provider <> repository <> role <> after <> []:
      page(db,R.SnapshotRef{provider,source,generation,snapshot,extent},ordinal,event,
        Scoped.Scope{filter_provider,repository,role,after},watermark,cursor,limit)
    case _ _:
      RC.failure(Unit,"usage","usage: result-link-page PROVIDER SOURCE GENERATION SNAPSHOT EXTENT RECORD EVENT WATERMARK AFTER_SOURCE LIMIT FILTER_PROVIDER FILTER_REPOSITORY FILTER_ROLE FILTER_AFTER; empty WATERMARK and cursor 0 open a new page; LIMIT is 1 to 15")

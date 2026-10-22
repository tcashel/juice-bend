import Base
import ./result_events.bend as Events
import ./result_links_cli.bend as Links
import ./relations_cli.bend as RC
import ./relations.bend as R
import ./scoped_reader.bend as Scoped
import ./json.bend as Json
import ./provenance.bend as P

def row(value: Events.ResultEvent) -> String:
  Events.ResultEvent{record,event,recorded,citation} = value
  "{\"record\":" ++ U32.show(record) ++ ",\"event\":" ++ U32.show(event) ++
    ",\"recorded\":" ++ Links.recorded_json(recorded) ++ ",\"citation\":" ++ citation ++ "}"

def rows(values: List<&2,Events.ResultEvent>) -> List<&2,String>:
  match values:
    case []: []
    case head <> tail: row(head) <> rows(tail)

def render(page: Events.Page) -> String:
  Events.Page{_,start,count,record,event,next_record,next_event,more,scanned,bytes,unavailable,_,rows} = page
  "Select a recorded tool result to inspect its retained child captures.\n\n" ++
    "Only typed Claude tool_result blocks inside the captured range and current filters appear here. Text that resembles a citation does not create a link.\n\n" ++
    "Captured range: " ++ U32.show(start) ++ " + " ++ U32.show(count) ++ " records.\nPage cursor: " ++ U32.show(record) ++ ":" ++ U32.show(event) ++
    ". Inspected records: " ++ U32.show(scanned) ++ "; retained bytes: " ++ U32.show(bytes) ++
    ". Unavailable records skipped: " ++ U32.show(unavailable) ++ ".\n" ++
    Bool.pick(String,more,"More records or events remain in this captured range. Use Next results.","End of this captured range. This is not a search of the complete session.") ++
    "\nMissing, malformed and ambiguous agent IDs stay explicit. A recorded ID supports navigation only, never authorship or human intent.\n\nBack restores the exact original reader and text selection."

def json(+page: Events.Page) -> String:
  Events.Page{reference,start,count,record,event,next_record,next_event,more,scanned,bytes,unavailable,scope,items} = page
  "{\"kind\":\"recorded_child_events\",\"reference\":" ++ RC.reference_json(reference) ++
    ",\"start\":" ++ U32.show(start) ++ ",\"count\":" ++ U32.show(count) ++ ",\"record\":" ++ U32.show(record) ++
    ",\"event\":" ++ U32.show(event) ++ ",\"next_record\":" ++ U32.show(next_record) ++ ",\"next_event\":" ++ U32.show(next_event) ++
    ",\"more\":" ++ RC.boolean(more) ++ ",\"scanned_records\":" ++ U32.show(scanned) ++
    ",\"inspected_bytes\":" ++ U32.show(bytes) ++ ",\"unavailable_records\":" ++ U32.show(unavailable) ++
    ",\"scope\":" ++ RC.scope_json(scope) ++ ",\"rows\":[" ++ String.join(rows(items),",") ++ "],\"text\":" ++ Json.quote(render(page)) ++ "}"

def output(value: Result<&2,&2,String,Events.Page>) -> IO(Unit):
  do IO<Unit>:
    page : Events.Page <- RC.require(Events.Page,value,"child_events_unavailable")
    +text : String = json(page)
    rendered : String <- RC.require(String,RC.bounded(R.utf8_fits(text,1048575),text),"output_too_large")
    IO.print(rendered)

def unsigned(value: Maybe<&2,U32>) -> IO(U32):
  match value:
    case Some{value}: IO.pure(U32,value)
    case None{}: RC.failure(U32,"invalid_number","Child result range and cursors require unsigned integer values; COUNT is at most 40")

def arguments(db: U32,args: List<String>) -> IO(Unit):
  match args:
    case snapshot <> start <> count <> record <> event <> provider <> repository <> role <> after <> []:
      do IO<Unit>:
        first : U32 <- unsigned(P.parse_u32(start))
        size : U32 <- unsigned(P.parse_u32(count))
        cursor : U32 <- unsigned(P.parse_u32(record))
        slot : U32 <- unsigned(P.parse_u32(event))
        result : Result<&2,&2,String,Events.Page> <- Events.page(db,snapshot,first,size,cursor,slot,Scoped.Scope{provider,repository,role,after})
        output(result)
    case _: RC.failure(Unit,"usage","result-link-events SNAPSHOT START COUNT RECORD EVENT PROVIDER REPOSITORY ROLE AFTER; COUNT <=40, first RECORD=START and EVENT=0")

def command_known(known: Bool,db: U32,args: List<String>) -> IO(Unit):
  match known:
    case True{}: arguments(db,args)
    case False{}: RC.failure(Unit,"usage","Unknown child event command")

def command(db: U32,mode: String,args: List<String>) -> IO(Unit):
  command_known(String.eq(mode,"result-link-events"),db,args)

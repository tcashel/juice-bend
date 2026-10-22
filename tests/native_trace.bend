import Base
import ../benchmarks/native_trace.bend as Trace
import ../src/json.bend as Json
import ../src/gui.bend as Gui

def require(value: Bool,name: String) -> IO(Unit):
  match value:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def repeated(fuel: Nat) -> List<&2,Event>:
  match fuel:
    case 0n:
      []
    case 1n+rest:
      Text{"x"} <> repeated(rest)

def main() -> IO(Unit):
  +events = { [Key{99,True{}},Text{"é\"🙂"},Mouse{12,34,1,False{}},Key{99,False{}}] : List<&2,Event> }
  +fields = Trace.event_fields(events,4n,True{})
  +expected = ",\"native_events\":[{\"type\":\"Key\",\"code\":99,\"down\":true}," ++
    "{\"type\":\"Text\",\"text\":" ++ Json.quote("é\"🙂") ++ "}," ++
    "{\"type\":\"Mouse\",\"x\":12,\"y\":34,\"button\":1,\"down\":false}," ++
    "{\"type\":\"Key\",\"code\":99,\"down\":false}],\"native_events_omitted\":0"
  do IO<Unit>:
    Unit <- require(String.eq(Trace.event_fields(events,4n,False{}),""),"native event detail is absent without synthetic trace opt-in")
    Unit <- require(String.eq(fields,expected),"ordered Text Key Mouse details preserve Unicode escaping and key-up")
    Unit <- require(String.eq(Trace.event_fields([],0n,True{}),",\"native_events\":[],\"native_events_omitted\":0"),"empty native batch records zero omitted events")
    Unit <- require(String.eq(Trace.event_fields(repeated(65n),65n,True{}),
      ",\"native_events\":[" ++ Trace.event_entries(repeated(64n),64n,"") ++ "],\"native_events_omitted\":1"),"native details stop at64 and report the exact omission")
    Unit <- require(String.eq(Trace.event_entries(repeated(65n),64n,""),Trace.event_entries(repeated(64n),64n,"")),"detail limit does not serialize the65th event")
    Unit <- require(String.eq(Trace.event_fields(Trace.copy_events(Trace.linear_events(events)),4n,True{}),expected),
      "diagnostic event copy preserves full dispatch order and contents")
    Unit <- require(Nat.is_eq(List.length(&2,Event,Trace.copy_events(Trace.linear_events(repeated(65n)))),65n),
      "event detail cap never removes the65th dispatched event")
    Unit <- require(String.eq(Trace.event_json(Text{"active-capture-vm"}),"{\"type\":\"Text\",\"text\":\"active-capture-vm\"}"),
      "native Text logging retains the complete17ASCII diagnostic commit")
    Unit <- require(String.eq(Trace.entry_line(1,1000n,4n,Gui.initial(0,"/tmp/trace-fixture","/usr/bin/false"),events,False{}),
      "{\"phase\":\"frame_return_tick_entry\",\"frame\":1,\"monotonic_ms\":1000,\"event_count\":4,\"query_scalars\":0,\"writer_present\":false,\"paused\":false}\n"),
      "entry metadata does not expose event details without opt-in")
    require(String.eq(Trace.entry_line(1,1000n,4n,Gui.initial(0,"/tmp/trace-fixture","/usr/bin/false"),events,True{}),
      "{\"phase\":\"frame_return_tick_entry\",\"frame\":1,\"monotonic_ms\":1000,\"event_count\":4,\"query_scalars\":0,\"writer_present\":false,\"paused\":false" ++ expected ++ "}\n"),
      "opted-in entry contains the ordered native detail fields")

import Base
import ../src/main.bend as Main
import ../src/gui.bend as Gui
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as Geometry
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json

# Diagnostic only. Ordinary application builds never import this entry point.
# App calls Window.frame before tick: entry observes its return, not when a
# pixel became visible. The log adds file IO and scheduling overhead. It must
# not be treated as uninstrumented input latency or input-to-photon evidence.
# Query text and ordered native events are omitted unless --trace-query opts
# into synthetic input logging. Event details stop after 64 events per frame.
type Book is Data:
  Book{frame: U32, last_query: String, trace_query: Bool}

# Retain one linear append stream instead of opening a file for every record.
type State is Type:
  State{gui: Gui.State, book: Book, log: File}

def bool_json(value: Bool) -> String:
  Bool.pick(String,value,"true","false")

def gui_query(gui: Gui.State) -> String:
  Gui.State{db,dir,program,ui,selection,form,jobs,ticks,serial} = gui
  UI.query(ui)

def writer_present(pending: Maybe<&2,Gui.Pending>) -> Bool:
  match pending:
    case None{}:
      False{}
    case Some{pending}:
      True{}

def state_fields(gui: Gui.State) -> String:
  Gui.State{db,dir,program,ui,selection,form,
    Gui.Jobs{revision,wanted,reader,writer,paused},ticks,serial} = gui
  ",\"query_scalars\":" ++ Nat.show(String.length(UI.query(ui))) ++
  ",\"writer_present\":" ++ bool_json(writer_present(writer)) ++
  ",\"paused\":" ++ bool_json(paused)

def query_field(+query: String,last: String,enabled: Bool) -> String:
  Bool.pick(String,enabled && Bool.not(String.eq(query,last)),
    ",\"query_changed\":" ++ Json.quote(query),"")

def event_json(event: Event) -> String:
  match event:
    case Text{text}:
      "{\"type\":\"Text\",\"text\":" ++ Json.quote(text) ++ "}"
    case Key{code,down}:
      "{\"type\":\"Key\",\"code\":" ++ U32.show(code) ++ ",\"down\":" ++ bool_json(down) ++ "}"
    case Mouse{x,y,button,down}:
      "{\"type\":\"Mouse\",\"x\":" ++ U32.show(x) ++ ",\"y\":" ++ U32.show(y) ++
      ",\"button\":" ++ U32.show(button) ++ ",\"down\":" ++ bool_json(down) ++ "}"
    case Move{x,y}:
      "{\"type\":\"Move\",\"x\":" ++ U32.show(x) ++ ",\"y\":" ++ U32.show(y) ++ "}"
    case Look{dx,dy}:
      "{\"type\":\"Look\",\"dx\":" ++ Json.quote(F32.show(dx)) ++ ",\"dy\":" ++ Json.quote(F32.show(dy)) ++ "}"
    case Scroll{x,y,dx,dy}:
      "{\"type\":\"Scroll\",\"x\":" ++ U32.show(x) ++ ",\"y\":" ++ U32.show(y) ++
      ",\"dx\":" ++ Json.quote(F32.show(dx)) ++ ",\"dy\":" ++ Json.quote(F32.show(dy)) ++ "}"
    case Close{}:
      "{\"type\":\"Close\"}"

def event_entries(events: List<&2,Event>,fuel: Nat,separator: String) -> String:
  match events fuel:
    case [] _:
      ""
    case _ 0n:
      ""
    case event <> tail 1n+rest:
      separator ++ event_json(event) ++ event_entries(tail,rest,",")

def event_fields(events: List<&2,Event>,count: Nat,enabled: Bool) -> String:
  match enabled:
    case False{}:
      ""
    case True{}:
      ",\"native_events\":[" ++ event_entries(events,64n,"") ++
      "],\"native_events_omitted\":" ++ Nat.show(Nat.sub(count,64n))

def entry_line(frame: U32,now: Nat,+count: Nat,gui: Gui.State,
  events: List<&2,Event>,enabled: Bool) -> String:
  "{\"phase\":\"frame_return_tick_entry\",\"frame\":" ++ U32.show(frame) ++
  ",\"monotonic_ms\":" ++ Nat.show(now) ++
  ",\"event_count\":" ++ Nat.show(count) ++ state_fields(gui) ++
  event_fields(events,count,enabled) ++ "}\n"

def exit_line(frame: U32,now: Nat,start: Nat,events: Nat,+gui: Gui.State,
  last: String,enabled: Bool,closed: Bool) -> String:
  "{\"phase\":\"tick_exit\",\"frame\":" ++ U32.show(frame) ++
  ",\"monotonic_ms\":" ++ Nat.show(now) ++
  ",\"gui_tick_start_ms\":" ++ Nat.show(start) ++
  ",\"event_count\":" ++ Nat.show(events) ++ state_fields(gui) ++
  query_field(gui_query(gui),last,enabled) ++
  ",\"closed\":" ++ bool_json(closed) ++ "}\n"

def written(result: File & Result<&1,&1,U32 & String,Unit>) -> IO(File):
  (file,result) = result
  do IO<File>:
    IO.try(Unit,IO.pure(Result<&1,&1,U32 & String,Unit>,result))
    return file

def write(log: File,text: String) -> IO(File):
  do IO<File>:
    result : File & Result<&1,&1,U32 & String,Unit> <- File.write(log,text)
    written(result)

def copy_events(events: List<Event>) -> List<&2,Event>:
  match events:
    case []:
      []
    case event <> rest:
      event <> copy_events(rest)

def linear_events(events: List<&2,Event>) -> List<Event>:
  match events:
    case []:
      []
    case event <> rest:
      event <> linear_events(rest)

def view_result(book: Book,log: File,result: Gui.State & Image) -> State & Image:
  (gui,image) = result
  (State{gui,book,log},image)

def view(state: State) -> State & Image:
  State{gui,book,log} = state
  view_result(book,log,Gui.view(gui))

def limit_line(frame: U32) -> String:
  Bool.pick(String,U32.is_eq(frame,12000),
    "{\"phase\":\"trace_limit\",\"paired_ticks\":12000,\"gui_continues\":true}\n","")

def traced_finish(book: Book,+prior: Gui.State,
  log: File,start: Nat,events: Nat,now: Nat,result: Maybe<Gui.State>) ->
  IO(Maybe<State>):
  Book{+frame,+last,+enabled} = book
  match result:
    case None{}:
      do IO<Maybe<State>>:
        log : File <- write(log,exit_line(frame,now,start,events,prior,last,enabled,True{}))
        File.close(log)
        return None{}
    case Some{+gui}:
      do IO<Maybe<State>>:
        log : File <- write(log,exit_line(frame,now,start,events,gui,last,enabled,False{}) ++
          limit_line(frame))
        return Some{State{gui,Book{U32.add(frame,1),gui_query(gui),enabled},log}}

def traced_tick(events: List<Event>,+gui: Gui.State,+book: Book,log: File,entry: Nat) ->
  IO(Maybe<State>):
  Book{frame,last,enabled} = book
  +captured = copy_events(events)
  +count = List.length(&2,Event,captured)
  do IO<Maybe<State>>:
    log : File <- write(log,entry_line(frame,entry,count,gui,captured,enabled))
    start : Nat <- IO.now()
    result : Maybe<Gui.State> <- Gui.tick(linear_events(captured),gui)
    end : Nat <- IO.now()
    traced_finish(book,gui,log,start,count,end,result)

def untraced_finish(result: Maybe<Gui.State>,book: Book,log: File) -> IO(Maybe<State>):
  match result:
    case None{}:
      do IO<Maybe<State>>:
        File.close(log)
        return None{}
    case Some{gui}:
      IO.pure(Maybe<State>,Some{State{gui,book,log}})

def tick_bounded(events: List<Event>,gui: Gui.State,book: Book,log: File,active: Bool) ->
  IO(Maybe<State>):
  match active:
    case True{}:
      do IO<Maybe<State>>:
        entry : Nat <- IO.now()
        traced_tick(events,gui,book,log,entry)
    case False{}:
      do IO<Maybe<State>>:
        result : Maybe<Gui.State> <- Gui.tick(events,gui)
        untraced_finish(result,book,log)

def tick(events: List<Event>,state: State) -> IO(Maybe<State>):
  State{gui,+book,log} = state
  Book{frame,last,enabled} = book
  tick_bounded(events,gui,book,log,U32.is_le(frame,12000))

def header(+enabled: Bool) -> String:
  "{\"phase\":\"trace_header\",\"version\":2,\"clock\":\"CLOCK_MONOTONIC milliseconds\"," ++
  "\"max_paired_ticks\":12000,\"query_logging\":" ++ bool_json(enabled) ++
  ",\"native_event_logging\":" ++ bool_json(enabled) ++ ",\"max_events_per_frame\":64" ++
  ",\"production_callbacks\":\"Gui.view,Gui.tick\",\"input_to_photon\":false," ++
  "\"entry_before_trace_write\":true,\"tick_start_after_trace_write\":true," ++
  "\"instrumentation\":\"two log writes and three clock reads per traced tick\"}\n"

def trace_dir(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(String):
  match result:
    case Done{(0,(path,error))}:
      IO.pure(String,String.trim(path))
    case _:
      IO.die(String,1,"Cannot create a fresh diagnostic log directory")

def launch(+program: String,+dir: String,+enabled: Bool) -> IO(Unit):
  do IO<Unit>:
    made : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/bin/mkdir",["-p","-m","700",dir],"",4096,5000)
    Main.mkdir_result(made)
    created : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/usr/bin/mktemp",["-d",dir ++ "/native-trace.XXXXXX"],"",4096,5000)
    +trace : String <- trace_dir(created)
    log : File <- IO.try(File,File.open(trace ++ "/trace.jsonl","w"))
    log : File <- write(log,header(enabled))
    IO.print("Native diagnostic trace: " ++ trace ++ "/trace.jsonl")
    +db : U32 <- Store.open(dir ++ "/juice-bend.sqlite")
    App.run(~State,~App{view,tick},"Juice Bend native trace",Geometry.width(),Geometry.height(),
      State{Gui.initial(db,dir,program),Book{1,"",enabled},log})
    IO.try(Unit,Sql.close(db))

def usage() -> IO(Unit):
  IO.die(Unit,2,"Use --trace-ui --data-dir /absolute/isolated-dir [--trace-query]. Synthetic data only. Worker commands require --data-dir /absolute/isolated-dir COMMAND.")

def launch_valid(program: String,dir: String,enabled: Bool,valid: Bool) -> IO(Unit):
  match valid:
    case True{}:
      launch(program,dir,enabled)
    case False{}:
      usage()

def launch_checked(program: String,+dir: String,enabled: Bool) -> IO(Unit):
  launch_valid(program,dir,enabled,String.starts_with(dir,"/"))

def worker_valid(program: String,dir: String,command: String,rest: List<String>,valid: Bool) -> IO(Unit):
  match valid:
    case True{}:
      Main.argv(program <> "--data-dir" <> dir <> command <> rest)
    case False{}:
      usage()

def worker(program: String,+dir: String,+command: String,rest: List<String>) -> IO(Unit):
  worker_valid(program,dir,command,rest,
    String.starts_with(dir,"/") && Bool.not(String.starts_with(command,"--")))

def argv(args: List<String>) -> IO(Unit):
  match args:
    case program <> "--trace-ui" <> "--data-dir" <> dir <> []:
      launch_checked(program,dir,False{})
    case program <> "--trace-ui" <> "--data-dir" <> dir <> "--trace-query" <> []:
      launch_checked(program,dir,True{})
    case program <> "--data-dir" <> dir <> command <> rest:
      worker(program,dir,command,rest)
    case _:
      usage()

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    argv(args)

import Base
import ./gui.bend as Gui
import ./ui.bend as UI
import ./ui_geometry.bend as Geometry
import ./gui_attachments.bend as Attachments
import ./attachment_preview_packet.bend as Packet
import ./attachment_preview_external_packet.bend as External
import ./attachment_preview_selection.bend as Selection
import ./attachment_asset_identity.bend as Identity
import ./attachment_preview_chrome.bend as Chrome
import ./attachment_preview.bend as Preview
import ./attachment_image_decode.bend as ImageDecode
import ./attachment_image_spool_worker.bend as ImageWorker
import ./attachment_image_binding.bend as ImageBinding
import ./attachment_image_types.bend as T
import ./attachment_decode.bend as Decode

# The ordinary coordinator stays Data. Only this outer native app owns affine
# image arrays. The complete original coordinator is the preview bookmark.
type Request is Data:
  InlinePreview{expected: Packet.Expected}
  RetainedPreview{expected: External.External}
type Reply is Type:
  Reply{value: Result<&2,&1,String,T.Raster>}
type Pending is Data:
  Pending{expected: Request,bookmark: Gui.State,channel: Chan(Reply),active: Bool}
type State is Type:
  Browsing{gui: Gui.State,pending: Maybe<&2,Pending>}
  Showing{preview: Preview.State<Gui.State>,caption: String}
  Unavailable{bookmark: Gui.State,caption: String,message: String}

def inline_caption(value: Packet.Expected) -> String:
  Packet.Expected{_,snapshot,Attachments.OccurrenceKey{record,reference,_,_,_,_,_,_,_}} = value
  "Snapshot " ++ snapshot ++ " | record " ++ U32.show(record) ++ " | reference " ++ U32.show(reference)

def caption(value: Request) -> String:
  match value:
    case InlinePreview{expected}: inline_caption(expected)
    case RetainedPreview{External.External{Identity.Request{snapshot,record,reference,_},_}}:
      "Snapshot " ++ snapshot ++ " | record " ++ U32.show(record) ++ " | reference " ++ U32.show(reference)

def page_key(page: List<&2,Attachments.Page>,snapshot: String,value: Maybe<&2,Attachments.OccurrenceKey>) -> Maybe<&2,Packet.Expected>:
  match page value:
    case Attachments.Page{capture,_,_,_,_,_,_} <> [] Some{key}: Some{Packet.Expected{capture,snapshot,key}}
    case _ _: None{}

def expected_ready(ready: Bool,+model: Attachments.Model) -> Maybe<&2,Packet.Expected>:
  match ready:
    case False{}: None{}
    case True{}:
      Attachments.Model{anchor,_,_,_,page,_,_,_} = model
      page_key(page,Attachments.anchor_snapshot(anchor),Attachments.key(Attachments.selected(model)))

def expected(value: Maybe<&2,Attachments.Model>) -> Maybe<&2,Packet.Expected>:
  match value:
    case None{}: None{}
    case Some{+model}: expected_ready(Attachments.exportable(model),model)

def idle(value: Gui.State) -> Bool:
  Gui.State{_,_,_,_,_,_,Gui.Jobs{_,wanted,reader,writer,_},_,_} = value
  Bool.not(Gui.pending_request(wanted) || Gui.pending_job(reader) || Gui.pending_job(writer))

def work_result(result: Result<&2,&1,String,T.Raster>) -> Reply:
  Reply{result}

def work(program: String,dir: String,expected: Request) -> IO(Reply):
  match expected:
    case InlinePreview{expected}:
      do IO<Reply>:
        result : Result<&2,&1,String,T.Raster> <- ImageWorker.read(program,dir,ImageBinding.ExpectedInline{expected})
        return work_result(result)
    case RetainedPreview{expected}:
      do IO<Reply>:
        result : Result<&2,&1,String,T.Raster> <- ImageWorker.read(program,dir,ImageBinding.ExpectedExternal{expected})
        return work_result(result)

def begin_allowed(valid: Bool,+gui: Gui.State,+expected: Request) -> IO(Maybe<State>):
  match valid:
    case False{}: IO.pure(Maybe<State>,Some{Browsing{Gui.status(gui,"Wait for the current capture or reader operation before opening an image."),None{}}})
    case True{}:
      Gui.State{_,dir,program,_,_,_,_,_,_} = gui
      do IO<Maybe<State>>:
        channel : Chan(Reply) <- IO.fork(Reply,work(program,dir,expected))
        return Some{Browsing{Gui.status(gui,"Opening verified retained image. You can continue navigating; navigation cancels this preview."),Some{Pending{expected,gui,channel,True{}}}}}

def begin_retained(+gui: Gui.State,value: Maybe<&2,External.External>) -> IO(Maybe<State>):
  match value:
    case None{}: IO.pure(Maybe<State>,Some{Browsing{Gui.status(gui,"Select retained inline bytes or a captured local attachment to open its image."),None{}}})
    case Some{value}: begin_allowed(idle(gui),gui,RetainedPreview{value})

def begin_key(+gui: Gui.State,value: Maybe<&2,Packet.Expected>) -> IO(Maybe<State>):
  match value:
    case None{}: begin_retained(gui,Selection.selected(Gui.attachment_model(Gui.navigation(gui)),Gui.attachment_retained(gui)))
    case Some{+value}:
      Packet.Expected{_,_,Attachments.OccurrenceKey{_,_,_,_,_,_,_,_,available}} = value
      begin_allowed(available && idle(gui),gui,InlinePreview{value})

def begin(+gui: Gui.State,pending: Maybe<&2,Pending>) -> IO(Maybe<State>):
  match pending:
    case None{}: begin_key(gui,expected(Gui.attachment_model(Gui.navigation(gui))))
    case Some{value}: IO.pure(Maybe<State>,Some{Browsing{Gui.status(gui,"The prior image reader is finishing. You may continue navigating."),Some{value}}})

# Any meaningful new input retires the pending result before ordinary GUI work.
# The supervised child and bounded incremental admission still finish. Keep
# this channel until completion, so cancellation never admits a second worker.
# A retired affine raster is discarded before it can replace the new reader.
def retires(event: Event) -> Bool:
  match event:
    case Key{_,True{}}: True{}
    case Mouse{_,_,_,True{}}: True{}
    case Scroll{_,_,_,_}: True{}
    case Text{_}: True{}
    case Close{}: True{}
    case _: False{}

def retire(needed: Bool,pending: Maybe<&2,Pending>) -> Maybe<&2,Pending>:
  match needed pending:
    case True{} Some{Pending{expected,bookmark,channel,_}}: Some{Pending{expected,bookmark,channel,False{}}}
    case _ value: value

def close_pending(pending: Maybe<&2,Pending>) -> IO(Unit):
  match pending:
    case None{}: IO.pure(Unit,Unit{})
    case Some{Pending{_,_,channel,_}}: Chan.close(Reply,channel)

def ordinary_result(result: Maybe<Gui.State>,pending: Maybe<&2,Pending>) -> IO(Maybe<State>):
  match result:
    case None{}:
      do IO<Maybe<State>>:
        close_pending(pending)
        return None{}
    case Some{gui}: IO.pure(Maybe<State>,Some{Browsing{gui,pending}})

def action(action: UI.Action,+gui: Gui.State,ui: UI.State,pending: Maybe<&2,Pending>) -> IO(Maybe<State>):
  match action:
    case UI.AttachmentPreview{}: begin(Gui.replace_ui(gui,ui),pending)
    case other:
      do IO<Maybe<State>>:
        result : Maybe<Gui.State> <- Gui.event(gui,(ui,other))
        ordinary_result(result,pending)

def gui_event(pair: UI.State & UI.Action,gui: Gui.State,pending: Maybe<&2,Pending>) -> IO(Maybe<State>):
  (ui,kind) = pair
  action(kind,gui,ui,pending)

def canceled_notice(needed: Bool,gui: Gui.State,pending: Maybe<&2,Pending>) -> Gui.State:
  match needed pending:
    case True{} Some{Pending{_,_,_,True{}}}: Gui.status(gui,"Image preview canceled. Your reader navigation continues.")
    case _ _: gui

# Keep the pending request boxed while UI.event calculates its native action.
# Public state remains Maybe<Pending>; the exact value is restored afterwards.
def pending_box(value: Maybe<&2,Pending>) -> List<&2,Pending>:
  match value:
    case None{}: []
    case Some{pending}: [pending]

def pending_unbox(value: List<&2,Pending>) -> Maybe<&2,Pending>:
  match value:
    case []: None{}
    case pending <> _: Some{pending}

def gui_event_boxed(pair: UI.State & UI.Action,gui: Gui.State,pending: List<&2,Pending>) -> IO(Maybe<State>):
  gui_event(pair,gui,pending_unbox(pending))

def browse_input_boxed(event: Event,+gui: Gui.State,pending: List<&2,Pending>) -> IO(Maybe<State>):
  Gui.State{_,_,_,ui,_,_,_,_,_} = gui
  gui_event_boxed(UI.event(event,ui),gui,pending)

def browse_input(event: Event,gui: Gui.State,pending: Maybe<&2,Pending>) -> IO(Maybe<State>):
  browse_input_boxed(event,gui,pending_box(pending))

# Persistent reader state is exact; transient native key/drag state must not
# survive a key release delivered while the preview owned the event stream.
def resume(+gui: Gui.State) -> Gui.State:
  Gui.State{_,_,_,+ui,_,_,_,_,_} = gui
  Gui.replace_ui(gui,UI.restore(ui,UI.bookmark(ui)))

def browse_ordinary(+event: Event,gui: Gui.State,+pending: Maybe<&2,Pending>) -> IO(Maybe<State>):
  +needed = retires(event)
  browse_input(event,canceled_notice(needed,gui,pending),retire(needed,pending))

# Escape cancels only the currently active preview and restores the exact
# pre-Open text selection. After navigation has retired it, Escape belongs to
# the new screen and cannot resurrect the old bookmark. Keep the one channel.
def browse_event(event: Event,gui: Gui.State,pending: Maybe<&2,Pending>) -> IO(Maybe<State>):
  match event pending:
    case Key{27,True{}} Some{Pending{expected,+bookmark,channel,True{}}}:
      IO.pure(Maybe<State>,Some{Browsing{resume(bookmark),Some{Pending{expected,bookmark,channel,False{}}}}})
    case other value: browse_ordinary(other,gui,value)

def preview_outcome(step: Preview.Step<Gui.State>,caption: String) -> Maybe<State>:
  match step:
    case Preview.Kept{value}: Some{Showing{value,caption}}
    case Preview.Back{gui}: Some{Browsing{resume(gui),None{}}}
    case Preview.Closed{_}: None{}

def unavailable_event(event: Event,+gui: Gui.State,caption: String,message: String) -> Maybe<State>:
  match event:
    case Close{}: None{}
    case Key{27,True{}}: Some{Browsing{resume(gui),None{}}}
    case Mouse{x,y,0,True{}}:
      Bool.pick(Maybe<State>,U32.is_eq(Preview.mouse_code(x,y),27),Some{Browsing{resume(gui),None{}}},Some{Unavailable{gui,caption,message}})
    case _: Some{Unavailable{gui,caption,message}}

def event(event: Event,state: State) -> IO(Maybe<State>):
  match state:
    case Browsing{gui,pending}: browse_event(event,gui,pending)
    case Showing{preview,caption}: IO.pure(Maybe<State>,preview_outcome(Preview.event(Gui.State,event,preview),caption))
    case Unavailable{gui,caption,message}: IO.pure(Maybe<State>,unavailable_event(event,gui,caption,message))

def events(rest: List<Event>,state: State) -> IO(Maybe<State>):
  match rest:
    case []: IO.pure(Maybe<State>,Some{state})
    case first <> tail:
      do IO<Maybe<State>>:
        next : Maybe<State> <- event(first,state)
        App.more(State,s => events(tail,s),next)

def opened(result: Result<&2,&1,T.Failure,Preview.State<Gui.State>>,gui: Gui.State,label: String) -> State:
  match result:
    case Done{preview}: Showing{preview,label}
    case Fail{T.Failure{kind,detail}}: Unavailable{gui,label,T.label(kind) ++ ": " ++ detail}

def decoded(result: Result<&2,&1,String,T.Raster>,+gui: Gui.State,+label: String) -> State:
  match result:
    case Fail{message}: Unavailable{gui,label,message}
    case Done{raster}: opened(Preview.open(Gui.State,gui,raster),gui,label)

def accepted(result: Result<&2,&2,String,Decode.Bytes>,gui: Gui.State,label: String) -> State:
  match result:
    case Fail{message}: Unavailable{gui,label,message}
    case Done{Decode.Bytes{bytes,_,_}}: decoded(ImageDecode.decode(bytes),gui,label)

def arrived(active: Bool,result: Maybe<&1,Reply>,+gui: Gui.State,expected: Request,bookmark: Gui.State) -> State:
  match active result:
    case False{} _: Browsing{gui,None{}}
    case True{} None{}: Unavailable{bookmark,caption(expected),"The retained-byte reader ended without a result."}
    case True{} Some{Reply{result}}: decoded(result,bookmark,caption(expected))

def polled(result: Poll<&1,&1,Maybe<&1,Reply>,Unit>,gui: Gui.State,+pending: Pending) -> IO(State):
  match result:
    case Wait{_}: IO.pure(State,Browsing{gui,Some{pending}})
    case Ready{result}:
      Pending{expected,bookmark,channel,active} = pending
      do IO<State>:
        Chan.close(Reply,channel)
        return arrived(active,result,gui,expected,bookmark)

def service_ordinary(+gui: Gui.State,pending: Maybe<&2,Pending>) -> IO(State):
  do IO<State>:
    next : Gui.State <- Gui.service(gui)
    return Browsing{next,pending}

def service_wait(active: Bool,gui: Gui.State,+pending: Pending) -> IO(State):
  match active:
    case True{}: IO.pure(State,Browsing{gui,Some{pending}})
    case False{}: service_ordinary(gui,Some{pending})

def poll_after(result: Poll<&1,&1,Maybe<&1,Reply>,Unit>,gui: Gui.State,+pending: Pending) -> IO(State):
  match result:
    case Wait{_}:
      Pending{_,_,_,active} = pending
      service_wait(active,gui,pending)
    case Ready{result}: polled(Ready{result},gui,pending)

def browse_service(gui: Gui.State,pending: Maybe<&2,Pending>) -> IO(State):
  match pending:
    case None{}: service_ordinary(gui,None{})
    case Some{+pending}:
      Pending{_,_,channel,_} = pending
      do IO<State>:
        result : Poll<&1,&1,Maybe<&1,Reply>,Unit> <- Chan.try_recv(Reply,channel,0)
        poll_after(result,gui,pending)

def service(state: State) -> IO(State):
  match state:
    case Browsing{gui,pending}: browse_service(gui,pending)
    case other: IO.pure(State,other)

def pending_active(value: Maybe<&2,Pending>) -> Bool:
  match value:
    case None{}: False{}
    case Some{_}: True{}

def paced(state: State,had_events: Bool) -> State & U32:
  match state:
    case Browsing{+gui,pending}:
      (Browsing{gui,pending},Gui.sleep_ms(gui,had_events))
    case Showing{Preview.State{bookmark,raster,view,image,+dirty},caption}:
      (Showing{Preview.State{bookmark,raster,view,image,dirty},caption},Bool.pick(U32,had_events || dirty,1,80))
    case Unavailable{bookmark,caption,message}:
      (Unavailable{bookmark,caption,message},Bool.pick(U32,had_events,1,80))

def slept(pair: State & U32) -> IO(Maybe<State>):
  (state,delay) = pair
  do IO<Maybe<State>>:
    IO.sleep(delay)
    return Some{state}

def tick_result(had_events: Bool,value: Maybe<State>) -> IO(Maybe<State>):
  match value:
    case None{}: IO.pure(Maybe<State>,None{})
    case Some{state}:
      do IO<Maybe<State>>:
        next : State <- service(state)
        slept(paced(next,had_events))

def tick_input(rest: List<Event>,state: State,had_events: Bool) -> IO(Maybe<State>):
  do IO<Maybe<State>>:
    value : Maybe<State> <- events(rest,state)
    tick_result(had_events,value)

def tick(rest: List<Event>,state: State) -> IO(Maybe<State>):
  match rest:
    case []: tick_input([],state,False{})
    case first <> tail: tick_input(first <> tail,state,True{})

def gui_view(pair: Gui.State & Image,pending: Maybe<&2,Pending>) -> State & Image:
  (gui,image) = pair
  (Browsing{gui,pending},image)

def preview_view(pair: Preview.State<Gui.State> & Image,caption: String) -> State & Image:
  (preview,image) = pair
  (Showing{preview,caption},image)

def show_view(preview: Preview.State<Gui.State>,+caption: String) -> State & Image:
  Preview.State{bookmark,T.Raster{+w,+h,count,capacity,pixels,+notice},+view,image,dirty} = preview
  preview_view(Preview.draw(Gui.State,Preview.State{bookmark,T.Raster{w,h,count,capacity,pixels,notice},view,image,dirty},Chrome.ready(caption,w,h,view,notice)),caption)

def view(state: State) -> State & Image:
  match state:
    case Browsing{gui,pending}: gui_view(Gui.view(gui),pending)
    case Showing{preview,caption}: show_view(preview,caption)
    case Unavailable{gui,+caption,+message}: (Unavailable{gui,caption,message},Chrome.failure(caption,message))

def run(db: U32,dir: String,program: String) -> IO(Unit):
  App.run(~State,~App{view,tick},"Juice Bend",Geometry.width(),Geometry.height(),Browsing{Gui.initial(db,dir,program),None{}})

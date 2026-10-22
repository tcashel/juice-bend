import Base
import ../src/attachment_preview_app.bend as A
import ../src/attachment_preview.bend as P
import ../src/attachment_preview_packet.bend as Packet
import ../src/attachment_decode.bend as Decode
import ../src/attachment_png.bend as Png
import ../src/attachment_image_decode.bend as ImageDecode
import ../src/attachment_image_types.bend as T
import ../src/gui.bend as G
import ../src/gui_attachments.bend as Attachments
import ../src/ui.bend as UI
import ../src/domain.bend as D
import ../src/json.bend as J
import ./gui_attachments.bend as F
import ./gui_settings.bend as S
import ./png_fixtures.bend as PNG
import ./jpeg_fixtures.bend as JPEG

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def expected_value(value: Maybe<&2,Packet.Expected>) -> Packet.Expected:
  match value:
    case Some{value}: value
    case None{}: Packet.Expected{J.JNull{},"0",Attachments.OccurrenceKey{0,0,"",0,0,"","",0,False{}}}

def expected() -> Packet.Expected: expected_value(A.expected(G.attachment_model(G.navigation(F.picked()))))

def observed(state: A.State) -> String:
  match state:
    case A.Browsing{gui,None{}}: S.observation(gui)
    case _: "wrong screen"

def returned(value: Maybe<A.State>) -> String:
  match value:
    case Some{state}: observed(state)
    case None{}: "closed"

def back(event: Event,state: A.State) -> IO(String):
  do IO<String>:
    value : Maybe<A.State> <- A.event(event,state)
    return returned(value)

def ready() -> A.State:
  A.accepted(Done{Decode.Bytes{PNG.rgb(),72,D.digest(PNG.rgb())}},F.picked(),"Synthetic exact occurrence")

def jpeg_ready() -> A.State:
  A.accepted(Done{Decode.Bytes{JPEG.gray_constant_bytes(),333,D.digest(JPEG.gray_constant_bytes())}},F.picked(),"Synthetic exact JPEG occurrence")

def jpeg_showing(state: A.State) -> Bool:
  match state:
    case A.Showing{P.State{_,T.Raster{8,8,64,64,_,False{}},_,_,_},_}: True{}
    case _: False{}

def failed() -> A.State:
  A.accepted(Fail{"Corrupt owned capture"},F.picked(),"Synthetic exact occurrence")

def unsupported() -> A.State:
  A.accepted(Done{Decode.Bytes{PNG.jpeg(),3,D.digest(PNG.jpeg())}},F.picked(),"Synthetic exact occurrence")

def preview_kind(action: UI.Action) -> Bool:
  match action:
    case UI.AttachmentPreview{}: True{}
    case _: False{}

def preview_action(pair: UI.State & UI.Action) -> Bool:
  (ui,action) = pair
  preview_kind(action)

def selection_expected(value: Packet.Expected) -> Bool:
  Packet.Expected{_,snapshot,Attachments.OccurrenceKey{record,reference,path,offset,length,_,media,count,available}} = value
  String.eq(snapshot,"7") && U32.is_eq(record,4) && U32.is_eq(reference,0) &&
    String.eq(path,"/message/content/0/source") && U32.is_eq(offset,40) && U32.is_eq(length,10) &&
    String.eq(media,"image/png") && U32.is_eq(count,4) && available

def retired(value: Maybe<&2,A.Pending>) -> Bool:
  match value:
    case Some{A.Pending{_,_,_,active}}: Bool.not(active)
    case _: False{}

def sticky(+gui: G.State) -> G.State:
  G.State{_,_,_,UI.State{content,UI.Input{selected,scroll,UI.Edit{focus,caret,anchor,_,viewport},_,_},image,_},_,_,_,_,_} = gui
  G.replace_ui(gui,UI.State{content,UI.Input{selected,scroll,UI.Edit{focus,caret,anchor,True{},viewport},True{},True{}},image,False{}})

def clean(gui: G.State) -> Bool:
  G.State{_,_,_,UI.State{_,UI.Input{_,_,UI.Edit{_,_,_,drag,_},command,shift},_,dirty},_,_,_,_,_} = gui
  Bool.not(drag || command || shift) && dirty

def resumed(value: Maybe<A.State>) -> Bool:
  match value:
    case Some{A.Browsing{+gui,None{}}}: clean(gui) && String.eq(S.observation(gui),S.observation(F.picked()))
    case _: False{}

def pending_restored(value: Maybe<A.State>,want: String) -> Bool:
  match value:
    case Some{A.Browsing{+gui,+pending}}: String.eq(S.observation(gui),want) && retired(pending)
    case _: False{}

def sent(value: Result<&1,&1,A.Reply,Unit>) -> Bool:
  match value:
    case Done{_}: True{}
    case Fail{_}: False{}

def reopen(value: Maybe<A.State>) -> IO(Maybe<A.State>):
  match value:
    case Some{A.Browsing{gui,pending}}: A.begin(gui,pending)
    case _: IO.die(Maybe<A.State>,1,"FAIL repeated Open left the pending reader unexpectedly")

def drained(value: Maybe<A.State>) -> IO(String):
  match value:
    case Some{state}:
      do IO<String>:
        after : A.State <- A.service(state)
        return observed(after)
    case _: IO.die(String,1,"FAIL pending reader unexpectedly closed")

def pending_lifecycle() -> IO(Unit):
  do IO<Unit>:
    +channel : Chan(A.Reply) <- Chan.new(A.Reply,1)
    escaped : Maybe<A.State> <- A.event(Key{27,True{}},A.Browsing{sticky(F.picked()),Some{A.Pending{A.InlinePreview{expected()},F.picked(),channel,True{}}}})
    check(pending_restored(escaped,S.observation(F.picked())),"Escape while image work is pending preserves exact pre-Open selection and retires its original channel")
    backed : Maybe<A.State> <- A.event(Mouse{20,88,0,True{}},A.Browsing{F.picked(),Some{A.Pending{A.InlinePreview{expected()},F.picked(),channel,True{}}}})
    check(pending_restored(backed,S.observation(F.origin())),"Back navigation remains active while the image child is pending and restores the exact filtered parent reader")
    refused : Maybe<A.State> <- A.begin(F.origin(),Some{A.Pending{A.InlinePreview{expected()},F.picked(),channel,False{}}})
    again : Maybe<A.State> <- reopen(refused)
    delivered : Result<&1,&1,A.Reply,Unit> <- Chan.send(A.Reply,channel,A.Reply{ImageDecode.decode(PNG.rgb())})
    check(sent(delivered),"one original channel accepts a completed affine raster after cancellation")
    observation : String <- drained(again)
    check(String.eq(observation,S.observation(F.origin())),"repeated Open cannot replace the occupied worker channel; its late raster drains without changing the new reader")

def lifecycle() -> IO(Unit):
  do IO<Unit>:
    +original : String = S.observation(F.picked())
    fixed : Maybe<A.State> <- A.event(Key{27,True{}},A.accepted(Done{Decode.Bytes{PNG.rgb(),72,D.digest(PNG.rgb())}},sticky(F.picked()),"Synthetic exact occurrence"))
    check(resumed(fixed),"Back clears released modifiers and dragging while preserving persistent selection and requesting redraw")
    by_key : String <- back(Key{27,True{}},ready())
    check(String.eq(by_key,original),"Escape from retained PNG restores exact selected attachment and parent reader")
    by_button : String <- back(Mouse{552,136,0,True{}},ready())
    check(String.eq(by_button,original),"Back button restores exact complete coordinator bookmark")
    check(jpeg_showing(jpeg_ready()),"verified retained JPEG enters the actual preview state with exact raster dimensions")
    jpeg_key : String <- back(Key{27,True{}},jpeg_ready())
    check(String.eq(jpeg_key,original),"Escape from retained JPEG restores exact selected attachment and filtered parent reader")
    jpeg_button : String <- back(Mouse{552,136,0,True{}},jpeg_ready())
    check(String.eq(jpeg_button,original),"JPEG Back restores the complete coordinator bookmark")
    bad : String <- back(Key{27,True{}},failed())
    check(String.eq(bad,original),"worker failure remains dismissible without reader loss")
    other : String <- back(Key{27,True{}},unsupported())
    check(String.eq(other,original),"malformed JPEG remains dismissible with exact selection")
    check(String.eq(observed(A.arrived(False{},Some{A.Reply{ImageDecode.decode(PNG.rgb())}},F.origin(),A.InlinePreview{expected()},F.picked())),S.observation(F.origin())),"late retired preview cannot replace newly navigated reader")
    check(selection_expected(expected()),"Open binds snapshot physical record reference path offset length media and count")
    check(preview_action(UI.attachment_action(S.ui(F.picked()),7)),"selected retained inline occurrence has native Open action")
    check(U32.is_eq(UI.attachment_top_index(3),7),"top Open uses shared control7 without changing export action")
    check(Bool.not(UI.attachment_control(7,2,False{},True{},True{})),"uncaptured local or remote row cannot launch inline image preview")
    check(Bool.not(UI.attachment_control(7,1,True{},True{},True{})),"loading inventory cannot launch preview")
    check(A.retires(Mouse{1,1,0,True{}}) && A.retires(Key{27,True{}}) && A.retires(Text{"x"}) && A.retires(Scroll{1,1,0.0,1.0}),"new navigation and editing retire in-flight result")
    check(Bool.not(A.retires(Move{1,1})) && Bool.not(A.retires(Key{27,False{}})),"idle movement and key release do not spuriously cancel preview")
    +channel : Chan(A.Reply) <- Chan.new(A.Reply,1)
    check(retired(A.retire(True{},Some{A.Pending{A.InlinePreview{expected()},F.picked(),channel,True{}}})),"retirement marks exact existing child stale")
    Chan.close(A.Reply,channel)

# Pacing is a pure policy check. These channels have no worker and receive no
# messages: the fixture only supplies the same presence flags as real jobs.
# Build one coordinator per check rather than retaining many wide states across
# IO continuations. Existing lifecycle checks above exercise actual draining.
def pacing_request() -> G.Request:
  G.Request{1,["history","",""],"",0,"Synthetic pacing request"}

def pacing_jobs(kind: U32,channel: Chan(G.Reply)) -> G.Jobs:
  match kind:
    case 1: G.Jobs{0,Some{pacing_request()},None{},None{},False{}}
    case 2: G.Jobs{0,None{},Some{G.Pending{1,pacing_request(),channel}},None{},False{}}
    case 3: G.Jobs{0,None{},None{},Some{G.Pending{1,pacing_request(),channel}},False{}}
    case _: G.Jobs{0,None{},None{},None{},False{}}

def pacing_gui_from(state: G.State,dirty: Bool,job_kind: U32,channel: Chan(G.Reply)) -> G.State:
  G.State{db,dir,program,UI.State{content,input,image,_},selection,form,_,refresh_at,serial} = state
  G.State{db,dir,program,UI.State{content,input,image,dirty},selection,form,pacing_jobs(job_kind,channel),refresh_at,serial}

def pacing_gui(dirty: Bool,job_kind: U32,channel: Chan(G.Reply)) -> G.State:
  pacing_gui_from(F.picked(),dirty,job_kind,channel)

def pacing_pending(kind: U32,channel: Chan(A.Reply)) -> Maybe<&2,A.Pending>:
  match kind:
    case 1: Some{A.Pending{A.InlinePreview{expected()},F.picked(),channel,True{}}}
    case 2: Some{A.Pending{A.InlinePreview{expected()},F.picked(),channel,False{}}}
    case _: None{}

def pacing_delay(value: A.State & U32,want: U32) -> Bool:
  (state,delay) = value
  U32.is_eq(delay,want)

def pacing_check(preview_channel: Chan(A.Reply),job_channel: Chan(G.Reply),pending_kind: U32,had_events: Bool,dirty: Bool,job_kind: U32,want: U32,label: String) -> IO(Unit):
  check(pacing_delay(A.paced(A.Browsing{pacing_gui(dirty,job_kind,job_channel),pacing_pending(pending_kind,preview_channel)},had_events),want),label)

def pacing() -> IO(Unit):
  do IO<Unit>:
    +preview_channel : Chan(A.Reply) <- Chan.new(A.Reply,1)
    +job_channel : Chan(G.Reply) <- Chan.new(G.Reply,1)
    pacing_check(preview_channel,job_channel,0,False{},False{},0,80,"settled browsing without image work uses 80 ms pacing")
    pacing_check(preview_channel,job_channel,1,False{},False{},0,80,"settled active image work uses 80 ms pacing")
    pacing_check(preview_channel,job_channel,2,False{},False{},0,80,"settled retired image work uses 80 ms pacing")
    pacing_check(preview_channel,job_channel,1,True{},False{},0,1,"active image work preserves 1 ms pacing after input")
    pacing_check(preview_channel,job_channel,2,True{},False{},0,1,"retired image work preserves 1 ms pacing after input")
    pacing_check(preview_channel,job_channel,1,False{},True{},0,1,"active image work preserves 1 ms pacing for dirty UI")
    pacing_check(preview_channel,job_channel,2,False{},True{},0,1,"retired image work preserves 1 ms pacing for dirty UI")
    pacing_check(preview_channel,job_channel,1,False{},False{},1,1,"active image work preserves 1 ms pacing for wanted work")
    pacing_check(preview_channel,job_channel,2,False{},False{},1,1,"retired image work preserves 1 ms pacing for wanted work")
    pacing_check(preview_channel,job_channel,1,False{},False{},2,1,"active image work preserves 1 ms pacing for a pending reader")
    pacing_check(preview_channel,job_channel,2,False{},False{},2,1,"retired image work preserves 1 ms pacing for a pending reader")
    pacing_check(preview_channel,job_channel,1,False{},False{},3,1,"active image work preserves 1 ms pacing for a pending writer")
    pacing_check(preview_channel,job_channel,2,False{},False{},3,1,"retired image work preserves 1 ms pacing for a pending writer")
    Chan.close(A.Reply,preview_channel)
    Chan.close(G.Reply,job_channel)

def main() -> IO(Unit):
  do IO<Unit>:
    lifecycle()
    pending_lifecycle()
    pacing()

import Base
import ../src/attachment_preview_app.bend as A
import ../src/gui.bend as Gui
import ./attachment_preview_app.bend as Fixture
import ./attachment_archive_export.bend as F
import ./gui_attachments.bend as GuiFixture
import ./gui_settings.bend as Settings

def check(ok: Bool,label: String) -> IO(Unit): F.check(ok,label)
def received(value: Maybe<&1,Unit>) -> Bool:
  match value:
    case Some{_}: True{}
    case _: False{}
def request_received(value: Poll<&1,&1,Maybe<&1,Unit>,Unit>) -> Bool:
  match value:
    case Ready{Some{_}}: True{}
    case _: False{}
def reply_closed(value: Poll<&1,&1,Maybe<&1,A.Reply>,Unit>) -> Bool:
  match value:
    case Ready{None{}}: True{}
    case _: False{}
def closed(value: Maybe<A.State>) -> Bool:
  match value:
    case None{}: True{}
    case _: False{}
def waiting(value: Poll<&1,&1,Maybe<&1,Bool>,Unit>) -> Bool:
  match value:
    case Wait{_}: True{}
    case _: False{}
def close_with_gui(active: Bool,cancel: Chan(Unit),reply: Chan(A.Reply),+gui: Gui.State) -> IO(Bool):
  do IO<Bool>:
    after : Maybe<A.State> <- A.event(Close{},A.Browsing{gui,Some{A.Pending{A.InlinePreview{Fixture.expected()},gui,reply,active,Some{cancel}}}})
    return closed(after)
def close_action(active: Bool,cancel: Chan(Unit),reply: Chan(A.Reply)) -> IO(Bool):
  close_with_gui(active,cancel,reply,GuiFixture.picked())
def close(active: Bool) -> IO(Unit):
  do IO<Unit>:
    +cancel : Chan(Unit) <- Chan.new(Unit,1)
    +reply : Chan(A.Reply) <- Chan.new(A.Reply,1)
    +task : Chan(Bool) <- IO.fork(Bool,close_action(active,cancel,reply))
    signal : Maybe<&1,Unit> <- Chan.recv(Unit,cancel)
    check(received(signal),"active or retired Close sends cancellation to the exact worker")
    before : Poll<&1,&1,Maybe<&1,Bool>,Unit> <- Chan.try_recv(Bool,task,100)
    check(waiting(before),"Close remains pending while its exact cleanup reply is deliberately withheld")
    delivered : Result<&1,&1,A.Reply,Unit> <- Chan.send(A.Reply,reply,A.Reply{Fail{"synthetic child completed cleanup"}})
    check(Fixture.sent(delivered),"Close keeps the exact result channel open for its cleanup acknowledgment")
    after : Bool <- IO.join(Bool,task)
    check(after,"Close returns after the exact error reply acknowledges worker completion")
    value : Poll<&1,&1,Maybe<&1,A.Reply>,Unit> <- Chan.try_recv(A.Reply,reply,0)
    check(reply_closed(value),"Close drains and closes its exact affine result channel")
    Chan.close(Unit,cancel)
def escaped(value: Maybe<A.State>) -> Bool:
  match value:
    case Some{A.Browsing{_,pending}}: Fixture.retired(pending)
    case _: False{}
def escape() -> IO(Unit):
  do IO<Unit>:
    +cancel : Chan(Unit) <- Chan.new(Unit,1)
    +reply : Chan(A.Reply) <- Chan.new(A.Reply,1)
    after : Maybe<A.State> <- A.event(Key{27,True{}},A.Browsing{GuiFixture.picked(),Some{A.Pending{A.InlinePreview{Fixture.expected()},GuiFixture.picked(),reply,True{},Some{cancel}}}})
    check(Fixture.pending_restored(after,Settings.observation(GuiFixture.picked())),"Escape keeps the original reader and retires the pending image")
    value : Poll<&1,&1,Maybe<&1,Unit>,Unit> <- Chan.try_recv(Unit,cancel,0)
    check(request_received(value),"Escape sends the real cooperative cancellation signal without waiting for a raster")
    Chan.close(Unit,cancel)
    Chan.close(A.Reply,reply)
def main() -> IO(Unit):
  do IO<Unit>:
    close(True{})
    close(False{})
    escape()

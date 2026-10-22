# Presentation checks use independent synthetic metadata. No source file or
# attachment bytes are read, and no UI authority comes from these strings.
import Base
import ../src/gui_attachments.bend as A
import ../src/gui_attachment_capture.bend as C
import ../src/ui.bend as UI
import ../src/json.bend as J
import ../src/attachment_asset_types.bend as T
import ./gui_attachments_model.bend as F
import ./attachment_asset_types.bend as Assets
import ./ui_attachments.bend as Painter
import ./tab_readability.bend as Tiles

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def find_before(+text: String,+first: String,+second: String) -> Bool:
  match text:
    case SNil{}: False{}
    case SCon{_,rest}:
      String.starts_with(text,first) || (Bool.not(String.starts_with(text,second)) && find_before(rest,first,second))

def before(+text: String,first: String,+second: String) -> Bool:
  String.contains(text,second) && find_before(text,first,second)

def exact_key(value: Maybe<&2,A.OccurrenceKey>) -> Bool:
  match value:
    case Some{A.OccurrenceKey{record,reference,path,offset,length,digest,media,count,ready}}:
      U32.is_eq(record,4) && U32.is_eq(reference,0) && String.eq(path,"/message/content/0/source") &&
        U32.is_eq(offset,40) && U32.is_eq(length,10) && String.eq(digest,F.sha()) &&
        String.eq(media,"image/png") && U32.is_eq(count,4) && ready
    case _: False{}

def detail_order() -> IO(Unit):
  +text = A.text(F.selected())
  +state = UI.set_results(UI.set_reader(UI.init(),"Attachment references",text),UI.AttachmentResults{2,True{},True{},True{}})
  +selected = UI.attachment_select_all(state)
  +restored = UI.restore(UI.init(),UI.bookmark(selected))
  do IO<Unit>:
    check(before(text,"All attachment references in these captured records","Saved inline attachment") &&
      before(text,"Repository, role and time filters do not apply here.","Saved inline attachment"),
      "raw-record scope and filter caveat remain ahead of the selected availability")
    check(before(text,"Saved inline attachment · 4 bytes","Evidence details") &&
      before(text,"Known attachment containers fully scanned.","Raw SHA256:"),
      "saved status and coverage precede low-level identity metadata")
    check(String.contains(text,"Physical record 4 | logical bytes 40..50 (end exclusive)") &&
      String.contains(text,"Raw SHA256: " ++ F.sha()) && String.contains(text,"Reference 0\nStructural path: /message/content/0/source"),
      "exact record byte range hash ordinal and structural path remain copyable")
    check(String.contains(text,"Inline bytes retained") && String.contains(text,"Page coverage") &&
      String.contains(text,"9 complete records; 1 partial records.") &&
      String.contains(text,"claude | source 2 | generation 3 | snapshot 7"),
      "original descriptor summary full page coverage and capture identity remain present")
    check(exact_key(A.key(A.selected(F.selected()))) && A.exportable(F.selected()),
      "presentation leaves exact selected occurrence and export eligibility unchanged")
    check(String.eq(Painter.copied(UI.event(Mouse{312,88,0,True{}},state)),text) &&
      String.eq(UI.selection(restored),text) && String.eq(Painter.copied(UI.event(Mouse{824,136,0,True{}},restored)),text),
      "Copy details and selection copy use the same complete text after bookmark restoration")
    check(before(A.text(A.choose(F.ready(),2)),"Partial attachment coverage","Raw SHA256:") &&
      String.contains(A.text(A.choose(F.ready(),2)),"Additional references may exist; total is unknown."),
      "partial and invalid record coverage stays prominent without claiming a complete total")

def retained_order() -> IO(Unit):
  +receipt = T.receipt(T.Admission{Assets.identity(99),Assets.root(99),"9007199254740993",Assets.binary()})
  +text = C.retained_text(C.RetainedReady{receipt})
  do IO<Unit>:
    check(before(text,"Saved in this library.","Saved-byte evidence") &&
      before(text,"they do not prove the file's earlier contents.","SHA256:"),
      "owned external availability and historical limitation precede its hash")
    check(String.contains(text,"Observed at Unix millisecond 9007199254740993") &&
      String.contains(text,"SHA256: " ++ Assets.binary_sha()) && String.starts_with(text,"Retained asset · 4 bytes"),
      "exact external observation time byte count and digest are preserved")
    check(String.starts_with(A.availability("remote_url",J.JNull{}),"Remote attachment · not downloaded") &&
      String.starts_with(A.availability("local_path",J.JNull{}),"Local file reference · not captured") &&
      String.starts_with(A.availability("unsupported",J.JNull{}),"Unsupported attachment reference"),
      "short labels distinguish remote uncaptured and unsupported references honestly")
    check(String.eq(A.availability("inline",J.JNull{}),"Inline attachment cannot be decoded"),
      "an invalid inline representation never receives a saved-byte label")

def unique_controls() -> IO(Unit):
  +local = UI.set_results(UI.init(),UI.AttachmentCaptureResults{2,False{},True{},True{},True{},False{}})
  +folders = UI.set_results(UI.init(),UI.AttachmentFoldersResults{2,True{},True{},True{},True{},True{}})
  +canvas = UI.draw_canvas_capture(local,"Pause",True{})
  +folder_canvas = UI.draw_canvas_capture(folders,"Pause",True{})
  do IO<Unit>:
    check(UI.attachment_available(UI.AttachmentCaptureResults{2,False{},True{},True{},True{},False{}},6) &&
      Painter.glyph(canvas,16,312,67,UI.ink(),UI.rail()),
      "unique Capture file remains painted at its existing sidebar target")
    check(Painter.glyph(folder_canvas,16,280,82,UI.ink(),UI.rail()) &&
      Painter.glyph(folder_canvas,160,88,85,UI.accent(),UI.panel()),
      "folder Reload remains in sidebar while Use remains in toolbar")
    check(U32.is_eq(Painter.action(UI.event(Mouse{16,120,0,True{}},folders)),0) &&
      U32.is_eq(Painter.action(UI.event(Mouse{16,152,0,True{}},folders)),0) &&
      U32.is_eq(Painter.action(UI.event(Mouse{200,600,0,True{}},folders)),0),
      "removed folder sidebar and list paging targets are inert")
    check(Tiles.tile.empty(Tiles.tile.at(8n,canvas,24,74),UI.panel()) &&
      Tiles.tile.empty(Tiles.tile.at(8n,folder_canvas,45,74),UI.panel()) &&
      Tiles.tile.empty(Tiles.tile.at(8n,canvas,114,16),UI.paper()),
      "duplicate paging and inapplicable Paste are absent from the actual canvas")

def main() -> IO(Unit):
  do IO<Unit>:
    detail_order()
    retained_order()
    unique_controls()

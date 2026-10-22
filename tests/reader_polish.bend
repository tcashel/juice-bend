import Base
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G
import ./polish.bend as P
import ./ui_attachments.bend as A
import ./tab_readability.bend as Tiles

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def line(value: UI.Line,start: U32,text: String) -> Bool:
  UI.Line{actual,body} = value
  U32.is_eq(actual,start) && String.eq(body,text)

# Independent invariant: visible pieces cover exact original scalar slices.
# The only character not in a piece may be one explicit LF between two lines.
def exact_slices(lines: List<&2,UI.Line>,+source: String,+offset: U32) -> Bool:
  match lines:
    case []: U32.is_eq(offset,UI.length(source))
    case UI.Line{+start,+text} <> rest:
      (U32.is_eq(start,offset) || (U32.is_eq(start,U32.add(offset,1)) && String.eq(UI.span(source,offset,start),"\n"))) &&
        U32.is_le(UI.length(text),80) &&
        String.eq(text,UI.span(source,start,U32.add(start,UI.length(text)))) &&
        exact_slices(rest,source,U32.add(start,UI.length(text)))

def preserved(+text: String,label: String) -> IO(Unit):
  require(exact_slices(UI.wrap(text),text,0),label)

def wrap_cases() -> IO(Unit):
  +words = P.repeat(77n,"x") ++ " café 中文 🙂"
  +wrapped = UI.wrap(words)
  +boundary = UI.wrap(P.repeat(75n,"x") ++ " café 中文 🙂")
  +tabs = UI.wrap(P.repeat(77n,"x") ++ "\tabc")
  +blank = UI.wrap("\n\n")
  +exact = UI.wrap(P.repeat(80n,"x") ++ "\nZ")
  +long = UI.wrap(P.repeat(161n,"x"))
  +spaces = UI.wrap(P.repeat(161n," "))
  do IO<Unit>:
    require(line(UI.line_at(UI.wrap(""),0),0,"") && U32.is_eq(U32.from_nat(List.length(&2,UI.Line,UI.wrap(""))),1),"empty text has one bounded empty line")
    require(line(UI.line_at(wrapped,0),0,P.repeat(77n,"x") ++ " ") && line(UI.line_at(wrapped,1),78,"café 中文 🙂"),"ordinary word crossing width moves intact with its Unicode tail")
    require(line(UI.line_at(boundary,0),0,P.repeat(75n,"x") ++ " café") && line(UI.line_at(boundary,1),80," 中文 🙂"),"word ending exactly at width stays on the first line; following space is retained")
    require(line(UI.line_at(tabs,0),0,P.repeat(77n,"x") ++ "\t") && line(UI.line_at(tabs,1),78,"abc"),"tab is a retained soft-break boundary without offset expansion")
    require(line(UI.line_at(exact,0),0,P.repeat(80n,"x")) && line(UI.line_at(exact,1),81,"Z"),"exact-width LF creates one explicit source gap without a phantom line")
    require(line(UI.line_at(blank,0),0,"") && line(UI.line_at(blank,1),1,"") && line(UI.line_at(blank,2),2,""),"consecutive and trailing LF preserve each empty line and scalar start")
    require(line(UI.line_at(long,0),0,P.repeat(80n,"x")) && line(UI.line_at(long,1),80,P.repeat(80n,"x")) && line(UI.line_at(long,2),160,"x"),"overlong token hard-wraps with strict forward progress")
    require(line(UI.line_at(spaces,0),0,P.repeat(80n," ")) && line(UI.line_at(spaces,1),80,P.repeat(80n," ")) && line(UI.line_at(spaces,2),160," "),"all-whitespace input progresses and never trims or duplicates spaces")
    require(U32.is_eq(U32.from_nat(List.length(&2,UI.Line,UI.wrap(P.repeat(80n," ")))),1),"exact-width whitespace does not add a phantom line")
    preserved(words,"word-wrapped pieces cover the exact original Unicode source")
    preserved("  leading\tand  repeated spaces \n\n" ++ P.repeat(165n,"z") ++ "\n", "leading repeated tab and newline whitespace survives all slices")
    preserved(P.repeat(77n,"x") ++ " é中文🙂", "combining scalars CJK and emoji keep original slice offsets")
    preserved(P.repeat(79n,"x") ++ " Y", "nonbreaking space remains an exact unmodified scalar in a hard token")

def pointer_cases() -> IO(Unit):
  +text = P.repeat(77n,"x") ++ " café 中文 🙂"
  +base = UI.set_reader(UI.init(),"Wrap selection",text)
  +drag = A.changed(UI.event(Move{608,200},A.changed(UI.event(Mouse{1144,176,0,True{}},base))))
  +reverse = A.changed(UI.event(Move{1144,176},A.changed(UI.event(Mouse{608,200,0,True{}},base))))
  +saved = UI.bookmark(drag)
  +restored = UI.restore(UI.set_results(UI.set_reader(base,"Other view","different"),UI.SettingsResults{0,0,"Pause",True{}}),saved)
  +all = UI.select_all(UI.set_edit(base,UI.Edit{2,0,0,False{},0}))
  +newline = UI.set_reader(UI.init(),"LF","left\nright")
  +across_lf = A.changed(UI.event(Move{552,200},A.changed(UI.event(Mouse{552,176,0,True{}},newline))))
  do IO<Unit>:
    require(String.eq(UI.reader(base),text),"word wrapping leaves canonical reader bytes unchanged")
    require(U32.is_eq(UI.reader_at(base,536,192),78) && U32.is_eq(UI.reader_at(base,608,200),87),"second visual line resolves to exact original Unicode scalar offsets")
    require(U32.is_eq(UI.reader_at(base,1175,176),78),"pointer past the short first line clamps to its exact canonical end")
    require(String.eq(UI.selection(drag),"x café 中文 🙂") && String.eq(UI.selection(reverse),UI.selection(drag)),"forward and reverse pointer selection across soft wrap preserve complete Unicode text")
    require(String.eq(A.copied(UI.event(Mouse{824,136,0,True{}},drag)),"x café 中文 🙂"),"native Copy action returns the exact cross-wrap substring")
    require(String.eq(UI.selection(all),text) && String.eq(A.copied(UI.event(Mouse{824,136,0,True{}},all)),text),"Select all and Copy retain all original spaces without inserted soft newlines")
    require(String.eq(UI.selection(restored),UI.selection(drag)) && String.eq(UI.reader(restored),text) && U32.is_eq(UI.reader_at(restored,536,192),78),"bookmark restoration retains canonical text selection and wrapped source mapping")
    require(String.eq(UI.selection(across_lf),"ft\nri"),"pointer selection across an explicit LF retains the source newline")

def contexts() -> List<&2,UI.State>:
  +base = UI.set_reader(UI.init(),"Short","selected body")
  [UI.set_results(base,UI.SettingsResults{0,0,"Pause",True{}}),
   UI.set_results(base,UI.QuotaResults{2,True{},True{},0,0,0,False{}}),
   UI.set_results(base,UI.BriefResults{0}),
   UI.set_results(base,UI.AttachmentResults{2,False{},False{},False{}}),
   UI.set_files(base,True{})]

def context_checks(states: List<&2,UI.State>,+index: U32) -> IO(Unit):
  match states:
    case []: IO.pure(Unit,Unit{})
    case +state <> rest:
      +label = "hidden attachment context " ++ U32.show(index)
      +short = UI.draw_canvas_capture(state,"Pause",False{})
      +long = UI.draw_canvas_capture(UI.set_reader(state,P.repeat(33n,"W"),"selected body"),"Pause",False{})
      do IO<Unit>:
        require(Bool.not(UI.attachment_entry_visible(state)) && U32.is_eq(UI.reader_title_columns(state),33),label ++ " reclaims title space")
        require(U32.is_eq(A.action(UI.event(Mouse{696,120,0,True{}},state)),0) && U32.is_eq(A.action(UI.event(Mouse{799,151,0,True{}},state)),0),label ++ " entry rectangle is inert at both edges")
        require(Tiles.tile.empty(Tiles.tile.at(8n,short,88,16),UI.paper()) && Tiles.tile.empty(Tiles.tile.at(8n,short,98,16),UI.paper()),label ++ " actual painter omits the entry label")
        require(A.glyph(long,792,128,87,UI.accent(),UI.paper()) && Tiles.tile.empty(Tiles.tile.at(8n,long,100,16),UI.paper()) && A.glyph(long,816,128,67,UI.accent(),UI.paper()),label ++ " title uses reclaimed columns and stops before Copy")
        context_checks(rest,U32.inc(index))

def attachment_contexts() -> IO(Unit):
  +normal = UI.set_reader(UI.init(),P.repeat(33n,"W"),"selected body")
  +canvas = UI.draw_canvas_capture(normal,"Pause",False{})
  do IO<Unit>:
    context_checks(contexts(),0)
    require(UI.attachment_entry_visible(normal) && U32.is_eq(UI.reader_title_columns(normal),18),"captured reader keeps its existing attachment entry title budget")
    require(U32.is_eq(A.action(UI.event(Mouse{696,120,0,True{}},normal)),1) && U32.is_eq(A.action(UI.event(Mouse{799,151,0,True{}},normal)),1),"captured reader still emits the request at both exact entry boundaries")
    require(A.glyph(canvas,704,128,65,UI.accent(),UI.paper()) && A.glyph(canvas,816,128,67,UI.accent(),UI.paper()),"captured reader paints Attachments and unchanged Copy controls")

def main() -> IO(Unit):
  do IO<Unit>:
    wrap_cases()
    pointer_cases()
    attachment_contexts()

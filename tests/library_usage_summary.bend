import Base
import ../src/library_usage_view_types.bend as V
import ../src/library_usage_types.bend as T
import ../src/library_usage_presentation.bend as P
import ../src/library_usage_summary.bend as Summary
import ../src/library_usage_screen.bend as Screen
import ../src/bend_ui/metric_card.bend as Card
import ../src/bend_ui/canvas.bend as C
import ../src/bend_ui/region.bend as R
import ../src/bend_ui/label.bend as Label
import ../src/ui_palette.bend as Palette
import ../src/font.bend as Font

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def known() -> T.Metric: T.Metric{"9007199254740993",1,0,0}
def unknown() -> T.Metric: T.Metric{"",0,1,0}
def providers() -> List<&2,V.ProviderCard>:
  P.cards(True{},[T.Provider{"claude",1,0,0,0,known(),unknown(),known(),unknown(),known()}])
def summary(selected: String) -> V.Summary:
  V.Summary{True{},providers(),[V.Notice{True{},"Unknown counters are not zero."},V.Notice{True{},"Some captures are excluded."}],selected,False{}}
def typed_view() -> V.View:
  V.View{"Usage","Captured library · All time",[V.Notice{True{},"Unknown counters are not zero."}],True{},providers(),"claude",[]}
def amount(value: V.Measure) -> String:
  V.Measure{_,amount,_,_} = value
  amount
def first_input(values: List<&2,V.ProviderCard>) -> V.Measure:
  match values:
    case V.ProviderCard{_,_,_,_,_,_,measures} <> _: Summary.measure_at(measures,0n)
    case _: V.Measure{"","",V.UnobservedValue{},""}

def screen_projection(value: Screen.Screen) -> Bool:
  match value:
    case Screen.Screen{_,text,_,"claude",2,[],[V.Summary{True{},cards,notices,"claude",False{}}]}:
      String.eq(text,P.text(typed_view())) && String.eq(amount(first_input(cards)),"9007199254740993") && U32.is_eq(Summary.warning_count(notices),1)
    case _: False{}

def refused(value: Result<&2,&2,C.Failure,C.Canvas>) -> Bool:
  match value:
    case Fail{C.InvalidBounds{}}: True{}
    case _: False{}
def canvas(value: Result<&2,&2,C.Failure,C.Canvas>) -> C.Canvas:
  match value:
    case Done{c}: c
    case _: C.Flat{0}
def choose(right: Bool,bottom: Bool,tl: C.Canvas,tr: C.Canvas,bl: C.Canvas,br: C.Canvas) -> C.Canvas:
  match right bottom:
    case False{} False{}: tl
    case True{} False{}: tr
    case False{} True{}: bl
    case True{} True{}: br
def pixel(fuel: Nat,c: C.Canvas,+x: U32,+y: U32) -> U32:
  match fuel c:
    case _ C.Flat{color}: color
    case _ C.Tile{bits,fg,bg}: C.blend(fg,bg,Font.coverage(bits,U32.mod(x,8),U32.mod(y,8)))
    case 0n _: 0
    case 1n+ +n C.Four{tl,tr,bl,br}:
      +half = U32.shln(8,n)
      pixel(n,choose(U32.is_ge(x,half),U32.is_ge(y,half),tl,tr,bl,br),U32.mod(x,half),U32.mod(y,half))

def paint(selected: String) -> C.Canvas:
  canvas(Summary.draw(C.Flat{16777215},summary(selected)))

def fits_value(text: String,+width: U32) -> Bool:
  +face = Card.value_face(text,width)
  U32.is_le(Label.height(face),32) && U32.is_eq(Label.face_index(face),1)

def main() -> IO(Unit):
  do IO<Unit>:
    check(String.eq(amount(first_input(providers())),"9007199254740993"),"summary values come from exact typed decimal counters")
    check(screen_projection(Screen.ready_view(typed_view(),"Ready")),"real Screen adapter preserves the canonical report and typed overview together")
    check(Summary.shown_provider("","claude") && Summary.shown_provider("","codex"),"All providers summary includes both typed provider cards")
    check(Summary.shown_provider("claude","claude") && Bool.not(Summary.shown_provider("claude","codex")),"provider-filtered overview does not imply unfiltered totals")
    check(String.eq(Summary.scope("codex"),"Captured library · All time · Codex"),"summary scope explicitly names provider and all-time capture basis")
    check(Summary.metric_unknown(V.UnknownValue{}) && Summary.metric_unknown(V.KnownSubtotal{}) && Summary.metric_unknown(V.WithheldValue{}),"unknown subtotal and withheld counters retain visible caution styling")
    check(String.eq(Summary.warning_title(False{},0),"Totals withheld · catalog coverage is incomplete"),"withheld coverage never presents invented zero totals")
    check(String.eq(Summary.provider_label(P.card(False{},P.empty_provider("claude"))),"Claude · Totals withheld"),"withheld provider cards do not label their placeholder counts as zero sessions")
    check(fits_value("9007199254740993",184) && U32.is_le(Label.measured(128n,1,"9007199254740993",0,184),184),"long exact counters use the smaller strong face before any ellipsis")
    check(String.eq(Summary.first_warning([V.Notice{False{},"scope"},V.Notice{True{},"exact warning"}]),"exact warning"),"overview warning is selected from typed notices")
    check(U32.is_eq(Summary.warning_count([V.Notice{True{},"one"},V.Notice{False{},"scope"},V.Notice{True{},"two"}]),2),"visible warning count includes every typed warning")
    check(U32.is_eq(pixel(8n,paint(""),536,352),Palette.surface(Palette.List{})),"known input metric has its ordinary summary surface")
    check(U32.is_eq(pixel(8n,paint(""),752,352),Palette.surface(Palette.Current{})),"unknown cached input has a visibly distinct surface")
    check(U32.is_eq(pixel(8n,paint(""),536,488),Palette.surface(Palette.Current{})),"All providers paints the unobserved second provider without zero substitution")
    check(U32.is_eq(pixel(8n,paint("claude"),536,488),16777215),"selected provider removes unrelated summary cards")
    check(U32.is_eq(pixel(8n,paint(""),535,352),16777215) && U32.is_eq(pixel(8n,paint(""),736,352),16777215),"summary cards preserve adjacent pixels and inter-card spacing")
    check(refused(Card.draw(C.Flat{0},Card.Model{"x","1","Recorded"},R.Rect{0,0,200,88},Card.Style{1,2,3})),"metric component refuses a clipped height")
    check(refused(Card.draw(C.Flat{0},Card.Model{"x","1","Recorded"},R.Rect{4294967295,0,0,96},Card.Style{1,2,3})),"metric component rejects wrapping bounds")
    check(refused(Card.draw(C.Flat{0},Card.Model{"x","1","Recorded"},R.Rect{1,0,201,96},Card.Style{1,2,3})),"metric component rejects an unaligned rectangle")

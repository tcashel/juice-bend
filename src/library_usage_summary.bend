import Base
import ./library_usage_view_types.bend as V
import ./library_usage_presentation.bend as P
import ./ui_palette.bend as Palette
import ./bend_ui/canvas.bend as C
import ./bend_ui/label.bend as Label
import ./bend_ui/region.bend as Region
import ./bend_ui/metric_card.bend as MetricCard

def shown_provider(+selected: String,key: String) -> Bool:
  String.is_empty(selected) || String.eq(selected,key)

def scope(+selected: String) -> String:
  "Captured library · All time · " ++ Bool.pick(String,String.is_empty(selected),"All providers",P.provider_name(selected))

def warning_count(values: List<&2,V.Notice>) -> U32:
  match values:
    case []: 0
    case V.Notice{warning,_} <> rest: U32.add(Bool.to_u32(warning),warning_count(rest))

def warning_title(available: Bool,+count: U32) -> String:
  match available:
    case False{}: "Totals withheld · catalog coverage is incomplete"
    case True{}: Bool.pick(String,U32.is_gt(count,0),U32.show(count) ++ " library accounting notices · Read report for details","Recorded counters · retained captures only")

def first_warning(values: List<&2,V.Notice>) -> String:
  match values:
    case []: "No inferred cost, activity dates, live usage or billed spend."
    case V.Notice{True{},text} <> _: text
    case _ <> rest: first_warning(rest)

def label(c: C.Canvas,text: String,+x: U32,+y: U32,+width: U32,+face: Label.Face,fg: U32,bg: U32) -> Result<&2,&2,C.Failure,C.Canvas>:
  +height = Label.height(face)
  Label.draw(c,text,Region.Rect{x,y,U32.add(x,width),U32.add(y,height)},Label.Style{face,fg,bg})

def metric_unknown(style: V.MetricStyle) -> Bool:
  match style:
    case V.RecordedValue{}: False{}
    case V.NotApplicableValue{}: False{}
    case _: True{}

def measure_at(values: List<&2,V.Measure>,index: Nat) -> V.Measure:
  match values index:
    case Con{value,_} 0n: value
    case Con{_,rest} 1n+n: measure_at(rest,n)
    case Nil{} _: V.Measure{"Unavailable","Unknown",V.UnknownValue{},"No typed counter is available."}

def metric(c: C.Canvas,measure: V.Measure,+x: U32,+y: U32) -> Result<&2,&2,C.Failure,C.Canvas>:
  V.Measure{label,value,+style,_} = measure
  MetricCard.draw(c,MetricCard.Model{label,value,P.style(style)},Region.Rect{x,y,U32.add(x,200),U32.add(y,96)},
    MetricCard.Style{Palette.ink(Palette.Heading{}),Palette.ink(Palette.Secondary{}),
      Palette.surface(Bool.pick(Palette.Surface,metric_unknown(style),Palette.Current{},Palette.List{}))})

def provider_label(value: V.ProviderCard) -> String:
  V.ProviderCard{_,label,sessions,_,_,_,measures} = value
  label ++ " · " ++ Bool.pick(String,P.is_withheld(measures),"Totals withheld",U32.show(sessions) ++ " contributing sessions")

def provider(c: C.Canvas,+value: V.ProviderCard,+y: U32) -> Result<&2,&2,C.Failure,C.Canvas>:
  V.ProviderCard{_,_,_,_,_,_,+measures} = value
  do Result<&2,&2,C.Failure,C.Canvas>:
    heading : C.Canvas <- label(c,provider_label(value),536,y,640,Label.Strong{},Palette.ink(Palette.Heading{}),Palette.surface(Palette.Paper{}))
    input : C.Canvas <- metric(heading,measure_at(measures,0n),536,U32.add(y,32))
    cached : C.Canvas <- metric(input,measure_at(measures,1n),752,U32.add(y,32))
    metric(cached,measure_at(measures,4n),968,U32.add(y,32))

def provider_step(show: Bool,c: C.Canvas,value: V.ProviderCard,y: U32,next: C.Canvas -> Result<&2,&2,C.Failure,C.Canvas>) -> Result<&2,&2,C.Failure,C.Canvas>:
  match show:
    case False{}: next(c)
    case True{}:
      do Result<&2,&2,C.Failure,C.Canvas>:
        drawn : C.Canvas <- provider(c,value,y)
        next(drawn)

# The typed presentation has exactly the two supported provider cards.
def providers(fuel: Nat,c: C.Canvas,values: List<&2,V.ProviderCard>,+selected: String,+y: U32) -> Result<&2,&2,C.Failure,C.Canvas>:
  match fuel values:
    case _ Nil{}: Done{c}
    case 0n _: Fail{C.InvalidBounds{}}
    case 1n+n Con{+value,rest}:
      V.ProviderCard{key,_,_,_,_,_,_} = value
      +show = shown_provider(selected,key)
      provider_step(show,c,value,y,
        drawn => providers(n,drawn,rest,selected,Bool.pick(U32,show,U32.add(y,136),y)))

def draw(c: C.Canvas,value: V.Summary) -> Result<&2,&2,C.Failure,C.Canvas>:
  V.Summary{+available,values,+notices,+selected,_} = value
  +paper = Palette.surface(Palette.Paper{})
  +warning = Bool.not(available) || U32.is_gt(warning_count(notices),0)
  +notice_bg = Palette.surface(Bool.pick(Palette.Surface,warning,Palette.Current{},Palette.List{}))
  do Result<&2,&2,C.Failure,C.Canvas>:
    heading : C.Canvas <- label(c,"Usage",536,168,640,Label.Heading{},Palette.ink(Palette.Heading{}),paper)
    scoped : C.Canvas <- label(heading,scope(selected),536,200,640,Label.Regular{},Palette.ink(Palette.Secondary{}),paper)
    unknown : C.Canvas <- label(scoped,"Unknown counters are not zero. Totals use recorded contributions only.",536,224,640,Label.Regular{},Palette.ink(Palette.Secondary{}),paper)
    notice : C.Canvas <- C.fill_rect(unknown,Region.Rect{536,256,1176,312},notice_bg)
    first : C.Canvas <- label(notice,warning_title(available,warning_count(notices)),544,256,624,Label.Strong{},Palette.ink(Palette.Heading{}),notice_bg)
    second : C.Canvas <- label(first,first_warning(notices),544,280,624,Label.Regular{},Palette.ink(Palette.Secondary{}),notice_bg)
    cards : C.Canvas <- providers(2n,second,values,selected,320)
    label(cards,"Full report includes cache creation, aliases and every accounting notice.",536,592,640,Label.Regular{},Palette.ink(Palette.Secondary{}),paper)

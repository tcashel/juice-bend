import Base
import ../src/reader_document.bend as Doc
import ../src/reader_projection.bend as P

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def key(part: U32) -> Doc.PartKey:
  Doc.PartKey{"9007199254740993","9007199254740995",3,part}

def part(index: U32,kind: Doc.PartKind,start: U32,count: U32,collapsible: Bool) -> Doc.Part:
  Doc.Part{key(index),kind,Doc.Span{start,count},"assistant","synthetic-tool",collapsible}

def parts() -> List<&2,Doc.Part>:
  [part(0,Doc.MessageText{},0,2,False{}),part(1,Doc.ToolArguments{},2,7,True{}),part(2,Doc.MessageText{},9,1,False{})]

def canonical() -> String: "A\nsecret\nB"
def document() -> Doc.Document: Doc.admit(canonical(),7,parts())
def collapsed() -> P.Projection: P.build(document(),[key(1)])

def span_equal(left: Doc.Span,right: Doc.Span) -> Bool:
  Doc.Span{a,b} = left
  Doc.Span{x,y} = right
  U32.is_eq(a,x) && U32.is_eq(b,y)

def spans_equal(left: List<&2,Doc.Span>,right: List<&2,Doc.Span>) -> Bool:
  match left right:
    case Nil{} Nil{}: True{}
    case Con{a,rest} Con{b,tail}: span_equal(a,b) && spans_equal(rest,tail)
    case _ _: False{}

def selection_is(value: Maybe<&2,P.Selection>,text: String,spans: List<&2,Doc.Span>) -> Bool:
  match value:
    case None{}: False{}
    case Some{P.Selection{actual,mapping}}: String.eq(actual,text) && spans_equal(mapping,spans)

def refused(value: Maybe<&2,P.Selection>) -> Bool:
  match value:
    case None{}: True{}
    case Some{_}: False{}

def plain_full(+value: Doc.Document,+expected: String) -> Bool:
  Bool.not(Doc.structured(value)) && String.eq(Doc.text(value),expected)

def fallback(parts: List<&2,Doc.Part>) -> Bool:
  plain_full(Doc.admit(canonical(),7,parts),canonical())

def table(fuel: Nat,+index: U32) -> List<&2,Doc.Part>:
  match fuel:
    case 0n: []
    case 1n+n: part(index,Doc.MessageText{},index,1,False{}) <> table(n,U32.inc(index))

def admission() -> IO(Unit):
  do IO<Unit>:
    require(Doc.structured(document()) && String.eq(Doc.text(document()),canonical()) && U32.is_eq(Doc.revision(document()),7),"adjacent descriptor spans cover unchanged canonical text exactly")
    require(Doc.structured(Doc.admit("",7,[])),"empty canonical document accepts an empty table")
    require(fallback([]),"nonempty canonical text cannot admit an empty table")
    require(fallback([part(0,Doc.MessageText{},0,0,False{}),part(1,Doc.MessageText{},0,10,False{})]),"zero-length descriptor falls back to complete plain text")
    require(fallback([part(0,Doc.MessageText{},0,5,False{}),part(1,Doc.MessageText{},4,6,False{})]),"overlapping descriptor ranges fall back without dropping source text")
    require(fallback([part(0,Doc.MessageText{},0,2,False{}),part(1,Doc.MessageText{},3,7,False{})]),"descriptor gap cannot hide a canonical scalar")
    require(fallback([part(0,Doc.MessageText{},2,8,False{}),part(1,Doc.MessageText{},0,2,False{})]),"out-of-order document descriptors are refused")
    require(fallback([part(0,Doc.MessageText{},0,9,False{})]),"missing canonical tail falls back to full reader")
    require(fallback([part(0,Doc.MessageText{},0,2,False{}),part(0,Doc.MessageText{},2,8,False{})]),"duplicate exact descriptor key is refused")
    require(fallback([part(0,Doc.MessageText{},4294967295,2,False{})]),"overflowed start and count cannot wrap into an admitted span")
    require(fallback([part(0,Doc.MessageText{},0,4294967295,False{})]),"oversized descriptor cannot claim a short canonical page")
    require(fallback([part(0,Doc.MessageText{},0,10,True{})]) && fallback([part(0,Doc.PageNotice{},0,10,True{})]),"message and coverage notice kinds cannot be made collapsible")
    require(Doc.structured(Doc.admit("a",7,[part(0,Doc.ToolResult{},0,1,True{})])) && Doc.structured(Doc.admit("a",7,[part(0,Doc.EvidenceDetails{},0,1,True{})])),"only explicit tool and evidence kinds admit disclosure state")
    require(plain_full(Doc.admit(String.repeat("a",2049n),7,table(2049n,0)),String.repeat("a",2049n)),"descriptor table over its bound falls back to complete text")
    require(String.eq(Doc.slice("A🙂B",Doc.Span{1,1}),"🙂") && String.eq(Doc.slice("A🙂B",Doc.Span{4294967295,2}),""),"slice counts Unicode scalars and refuses an overflowed range")
    require(Bool.not(Doc.span_valid(Doc.Span{4294967295,1},4294967295)) && Doc.span_valid(Doc.Span{4294967295,0},4294967295),"span validation distinguishes exact unsigned endpoint from overflowing addition")

def unicode_document() -> Doc.Document:
  Doc.admit("é\t é 中文 🙂\n",7,[part(0,Doc.MessageText{},0,3,False{}),part(1,Doc.EvidenceDetails{},3,8,True{})])

def visible_selection() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(P.text(P.build(document(),[])),canonical()),"unfolded projection retains every canonical separator")
    require(String.eq(P.text(collapsed()),"A\nB"),"collapsed tool arguments are absent from visible projection")
    require(selection_is(P.select(collapsed(),7,0,3),"A\nB",[Doc.Span{0,2},Doc.Span{9,1}]),"Select All across hidden content returns two exact canonical spans without an envelope")
    require(selection_is(P.select(collapsed(),7,3,0),"A\nB",[Doc.Span{0,2},Doc.Span{9,1}]),"reverse selection preserves visible copy order and excludes hidden content")
    require(selection_is(P.select(collapsed(),7,1,3),"\nB",[Doc.Span{1,1},Doc.Span{9,1}]),"partial boundary selection intersects each source piece independently")
    require(selection_is(P.select(collapsed(),7,2,2),"",[]),"empty selection returns no synthetic source span")
    require(refused(P.select(collapsed(),6,0,3)) && refused(P.select(collapsed(),7,0,4)),"stale revisions and out-of-bounds visible positions refuse copy")
    require(Doc.structured(unicode_document()) && U32.is_eq(Doc.length(Doc.text(unicode_document())),11),"tabs combining marks CJK emoji and accents count as exact decoded scalars")
    require(selection_is(P.select(P.build(unicode_document(),[]),7,0,11),"é\t é 中文 🙂\n",[Doc.Span{0,3},Doc.Span{3,8}]),"Unicode copy returns original tabs combining sequence CJK and emoji")
    require(selection_is(P.select(P.build(unicode_document(),[key(1)]),7,0,3),"é\t ",[Doc.Span{0,3}]),"collapsed Unicode evidence does not leak into copy")
    require(String.eq(P.text(P.build(document(),[key(0)])),canonical()) && String.eq(P.text(P.build(document(),[key(99)])),canonical()),"ineligible or unknown fold keys safely retain the full plain reader")
    require(String.eq(P.text(P.build(document(),[key(1),key(1)])),canonical()),"duplicate fold keys do not create an ambiguous hidden view")
    require(String.eq(P.text(P.build(Doc.Structured{canonical(),7,[part(0,Doc.MessageText{},2,8,False{})]},[])),canonical()),"direct malformed Structured constructors are re-admitted before projection")

def piece(visible: U32,source: U32,+count: U32,index: U32) -> P.Piece:
  P.Piece{Doc.Span{visible,count},Doc.Span{source,count},key(index)}

def reordered() -> P.Projection:
  P.admit(document(),"BA\n",[piece(0,9,1,2),piece(1,0,2,0)],7)

def full_fallback(+value: P.Projection) -> Bool:
  String.eq(P.text(value),canonical()) && U32.is_eq(P.revision(value),7)

def external_admission() -> IO(Unit):
  do IO<Unit>:
    require(selection_is(P.select(reordered(),7,0,3),"BA\n",[Doc.Span{9,1},Doc.Span{0,2}]),"explicit reordered pieces retain displayed selection order instead of canonical sorting")
    require(selection_is(P.select(reordered(),7,3,1),"A\n",[Doc.Span{0,2}]),"reverse selection over reordered pieces remains an exact visible slice")
    require(full_fallback(P.admit(document(),"A\nC",[piece(0,0,2,0),piece(2,9,1,2)],7)),"mismatched visible bytes fall back to full canonical text")
    require(full_fallback(P.admit(document(),"A\nB",[piece(0,0,2,0),piece(3,9,1,2)],7)),"visible piece gap is rejected")
    require(full_fallback(P.admit(document(),"A\nB",[piece(0,0,2,0),piece(1,9,1,2)],7)),"visible piece overlap is rejected")
    require(full_fallback(P.admit(document(),"A\nB",[piece(2,9,1,2),piece(0,0,2,0)],7)),"piece table must follow visible order even when canonical ranges are reordered")
    require(full_fallback(P.admit(document(),"A\nB",[piece(0,0,2,0),piece(2,9,1,99)],7)),"unrecognized part identity cannot authorize a canonical slice")
    require(full_fallback(P.admit(document(),"A\ns",[piece(0,0,3,0)],7)),"source interval cannot cross into a different descriptor")
    require(full_fallback(P.admit(document(),"A\nB",[piece(0,0,2,0),piece(2,4294967295,1,2)],7)),"external source overflow falls back before range addition")
    require(full_fallback(P.admit(document(),"A\nB",[piece(0,0,2,0),piece(2,9,1,2)],6)),"external projection must bind the admitted document revision")
    require(full_fallback(P.admit(document(),"",[],7)) && full_fallback(P.admit(document(),"B",[piece(0,9,1,2)],7)),"external projection cannot omit noncollapsible messages")
    require(String.eq(P.text(P.admit(Doc.admit("Warning\nbody",7,[part(0,Doc.PageNotice{},0,8,False{}),part(1,Doc.MessageText{},8,4,False{})]),"body",[piece(0,8,4,1)],7)),"Warning\nbody"),"external projection cannot suppress a page coverage warning")
    require(full_fallback(P.admit(document(),"A\nA\nB",[piece(0,0,2,0),piece(2,0,2,0),piece(4,9,1,2)],7)),"duplicate canonical pieces are refused even with matching visible text")
    require(full_fallback(P.admit(document(),"AAB",[piece(0,0,1,0),piece(1,0,1,0),piece(2,9,1,2)],7)),"equal summed lengths cannot conceal source overlap and a missing scalar")
    require(full_fallback(P.admit(document(),"A\nsB",[piece(0,0,2,0),piece(2,2,1,1),piece(3,9,1,2)],7)),"a collapsible descriptor is either fully visible or fully omitted")
    require(selection_is(P.select(P.admit(document(),"\nAB",[piece(0,1,1,0),piece(1,0,1,0),piece(2,9,1,2)],7),7,0,3),"\nAB",[Doc.Span{1,1},Doc.Span{0,1},Doc.Span{9,1}]),"exact split coverage may be reordered without losing its selection order")

def view_is(view: P.View,text: String,revision: U32,anchor: U32,caret: U32,drag: Bool) -> Bool:
  P.View{document,collapsed,+projection,a,c,d} = view
  String.eq(P.text(projection),text) && U32.is_eq(P.revision(projection),revision) &&
    U32.is_eq(a,anchor) && U32.is_eq(c,caret) && Bool.not(Bool.xor(d,drag)) && String.eq(Doc.text(document),canonical())

def selected_view() -> P.View:
  P.point(P.point(P.open(document()),7,0,False{},True{}),7,10,True{},True{})

def folded_view() -> P.View: P.toggle(selected_view(),7,key(1))

def state_changes() -> IO(Unit):
  do IO<Unit>:
    require(selection_is(P.selection(selected_view(),7),canonical(),[Doc.Span{0,2},Doc.Span{2,7},Doc.Span{9,1}]),"view selection uses the current projection and keeps individual span identities")
    require(view_is(folded_view(),"A\nB",8,0,0,False{}),"fold increments projection revision and clears caret anchor and drag without changing canonical text")
    require(selection_is(P.selection(folded_view(),8),"",[]) && refused(P.selection(folded_view(),7)),"copy after fold is empty and stale copy cannot reuse old selection")
    require(view_is(P.point(folded_view(),7,2,True{},True{}),"A\nB",8,0,0,False{}),"stale pointer event is inert after fold")
    require(view_is(P.point(folded_view(),8,4,True{},True{}),"A\nB",8,0,0,False{}),"pointer outside visible scalar bounds is inert")
    require(view_is(P.toggle(selected_view(),6,key(1)),canonical(),7,0,10,True{}),"stale disclosure leaves text selection and drag untouched")
    require(view_is(P.toggle(selected_view(),7,key(0)),canonical(),7,0,10,True{}),"message body cannot become a disclosure target")
    require(view_is(P.toggle(folded_view(),8,key(1)),canonical(),9,0,0,False{}),"expanding details restores every canonical scalar and clears selection again")
    require(selection_is(P.selection(P.point(P.point(folded_view(),8,3,False{},False{}),8,0,True{},True{}),8),"A\nB",[Doc.Span{0,2},Doc.Span{9,1}]),"extended reverse pointer selection crosses a fold without visiting hidden scalars")
    require(U32.is_eq(P.revision(P.projection(P.toggle(P.open(Doc.admit(canonical(),4294967295,parts())),4294967295,key(1)))),4294967295),"revision exhaustion refuses toggle instead of wrapping into a stale identity")

def large_plain() -> IO(Unit):
  +original = String.repeat("x",1048577n) ++ "Z"
  +document = Doc.admit(original,7,[])
  +projection = P.build(document,[])
  do IO<Unit>:
    require(plain_full(document,original) && U32.is_eq(Doc.length(P.text(projection)),1048578),"plain fallback above card scalar budget retains the complete original reader")
    require(selection_is(P.select(projection,7,1048577,1048578),"Z",[Doc.Span{1048577,1}]),"selection at the end of an oversized plain fallback is exact")

def main() -> IO(Unit):
  do IO<Unit>:
    admission()
    visible_selection()
    external_admission()
    state_changes()
    large_plain()

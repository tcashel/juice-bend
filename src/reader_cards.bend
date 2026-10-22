import Base
import ./reader_document.bend as Doc
import ./reader_projection.bend as P
import ./ui_geometry.bend as G

# Cached view-only rows. Text positions are visible Unicode scalars; section
# chrome has no selectable character and is never appended to copied text.
type Row is Data:
  TextRow{start: U32,text: String,count: U32,style: U32}
  SectionRow{label: String,key: Maybe<&2,Doc.PartKey>,closed: Bool}

type Hit is Data:
  NoHit{}
  TextHit{position: U32}
  FoldHit{key: Doc.PartKey}

# Always stored in a zero/one List at UI.Content, never flattened into Gui.State.
# Admission/layout and scalar counting run once per accepted page or fold.
type Token is Data:
  Token{page: String,epoch: U32,projection: U32}

type Model is Data:
  Model{page: String,epoch: U32,view: P.View,rows: List<&2,Row>,scalar_count: U32,row_count: U32,focused: Maybe<&2,Doc.PartKey>}

def text(model: Model) -> String:
  Model{_,_,view,_,_,_,_} = model
  P.text(P.projection(view))

def revision(model: Model) -> U32:
  Model{_,_,view,_,_,_,_} = model
  P.revision(P.projection(view))

def token(+model: Model) -> Token:
  Model{page,epoch,_,_,_,_,_} = model
  Token{page,epoch,revision(model)}

def accepts(+model: Model,expected: Token) -> Bool:
  Model{page,epoch,_,_,_,_,_} = model
  Token{old_page,old_epoch,old_projection} = expected
  String.eq(page,old_page) && U32.is_eq(epoch,old_epoch) && U32.is_eq(revision(model),old_projection)

def canonical(model: Model) -> String:
  Model{_,_,P.View{document,_,_,_,_,_},_,_,_,_} = model
  Doc.text(document)

def count(model: Model) -> U32:
  Model{_,_,_,_,count,_,_} = model
  count

def rows(model: Model) -> List<&2,Row>:
  Model{_,_,_,rows,_,_,_} = model
  rows

def row_count(model: Model) -> U32:
  Model{_,_,_,_,_,count,_} = model
  count

def focus(model: Model) -> Maybe<&2,Doc.PartKey>:
  Model{_,_,_,_,_,_,focused} = model
  focused

def clear_focus(model: Model) -> Model:
  Model{page,epoch,view,rows,count,total,_} = model
  Model{page,epoch,view,rows,count,total,None{}}

def with_focus(model: Model,key: Maybe<&2,Doc.PartKey>) -> Model:
  Model{page,epoch,view,rows,count,total,_} = model
  Model{page,epoch,view,rows,count,total,key}

def sync(model: Model,anchor: U32,caret: U32,drag: Bool) -> Model:
  Model{page,epoch,P.View{document,collapsed,projection,_,_,_},rows,+count,total,focused} = model
  Model{page,epoch,P.View{document,collapsed,projection,U32.min(anchor,count),U32.min(caret,count),drag},rows,count,total,focused}

def stop_drag(model: Model) -> Model:
  Model{page,epoch,P.View{document,collapsed,projection,anchor,caret,_},rows,count,total,focused} = model
  Model{page,epoch,P.View{document,collapsed,projection,anchor,caret,False{}},rows,count,total,focused}

def selection(+model: Model,expected: Token) -> Maybe<&2,P.Selection>:
  Model{_,_,view,_,_,_,_} = model
  Bool.pick(Maybe<&2,P.Selection>,accepts(model,expected),P.selection(view,revision(model)),None{})

def initial_folds(parts: List<&2,Doc.Part>) -> List<&2,Doc.PartKey>:
  match parts:
    case []: []
    case Doc.Part{key,_,_,_,_,True{}} <> rest: key <> initial_folds(rest)
    case _ <> rest: initial_folds(rest)

def style(kind: Doc.PartKind) -> U32:
  match kind:
    case Doc.PageNotice{}: 1
    case Doc.EventHeading{}: 1
    case Doc.FencedCode{}: 2
    case Doc.ToolArguments{}: 2
    case Doc.ToolResult{}: 2
    case Doc.ToolName{}: 1
    case Doc.EvidenceDetails{}: 1
    case _: 0

def reference(key: Doc.PartKey) -> String:
  Doc.PartKey{_,record,event,_} = key
  "r" ++ record ++ ":e" ++ U32.show(event)

def role_title(role: String) -> String:
  match role:
    case "user": "You"
    case "assistant": "Assistant"
    case "tool": "Tool"
    case "system": "System"
    case "": "Captured event"
    case value: value

def detail_title(kind: Doc.PartKind) -> String:
  match kind:
    case Doc.ToolArguments{}: "Tool input"
    case Doc.ToolResult{}: "Tool result"
    case _: "Evidence details"

def section(part: Doc.Part,closed: Bool) -> List<&2,Row>:
  Doc.Part{+key,kind,_,role,tool,collapsible} = part
  match kind collapsible:
    case Doc.EventHeading{} _:
      [SectionRow{role_title(role) ++ "  ·  " ++ reference(key),None{},False{}}]
    case _ True{}:
      [SectionRow{detail_title(kind) ++ "  ·  " ++ reference(key),Some{key},closed}]
    case _ _: []

def space(c: Char) -> Bool:
  Chr{+code} = c
  U32.is_eq(code,32) || U32.is_eq(code,9)

def line(start: U32,+text: String,style: U32) -> Row:
  TextRow{start,text,Doc.length(text),style}

# Same soft-wrap rule as the plain reader. Every body row is an exact visible
# slice. A terminal LF consumes its scalar but does not add a phantom empty row
# at a typed-part boundary; an actual blank LF still gets its own row.
def wrap.go(+s: String,+at: U32,+start: U32,+col: U32,+acc: String,+done: List<&2,Row>,full: Bool,+word: U32,+style: U32) -> List<&2,Row>:
  match s full:
    case SNil{} _:
      List.reverse(&2,Row,Bool.pick(List<&2,Row>,String.is_empty(acc),done,line(start,String.reverse(acc),style) <> done))
    case SCon{Chr{10},tail} _:
      wrap.go(tail,U32.add(at,1),U32.add(at,1),0,"",line(start,String.reverse(acc),style) <> done,False{},0,style)
    case SCon{+c,tail} True{}:
      +cut = Bool.pick(U32,space(c) || U32.is_eq(word,0),col,word)
      +text = String.reverse(acc)
      +next_col = U32.add(U32.sub(col,cut),1)
      wrap.go(tail,U32.add(at,1),U32.add(start,cut),next_col,
        SCon{c,String.reverse(String.drop(text,U32.to_nat(cut)))},
        line(start,String.take(text,U32.to_nat(cut)),style) <> done,
        U32.is_eq(next_col,G.reader_columns()),Bool.pick(U32,space(c),next_col,0),style)
    case SCon{+c,tail} False{}:
      wrap.go(tail,U32.add(at,1),start,U32.add(col,1),SCon{c,acc},done,
        U32.is_eq(U32.add(col,1),G.reader_columns()),Bool.pick(U32,space(c),U32.add(col,1),word),style)

def wrap(text: String,+start: U32,style: U32) -> List<&2,Row>:
  wrap.go(text,start,start,0,"",[],False{},0,style)

def body(part: Doc.Part,text: String,start: U32,closed: Bool) -> List<&2,Row>:
  Doc.Part{_,kind,_,_,_,_} = part
  match closed:
    case True{}: []
    case False{}: wrap(text,start,style(kind))

def layout(parts: List<&2,Doc.Part>,+canonical: String,+collapsed: List<&2,Doc.PartKey>,+visible: U32) -> List<&2,Row>:
  match parts:
    case []: []
    case +part <> rest:
      Doc.Part{key,_,Doc.Span{_,+count},_,_,can_fold} = part
      +closed = can_fold && Doc.has_key(collapsed,key)
      List.append(&2,Row,section(part,closed),List.append(&2,Row,
        body(part,String.take(canonical,U32.to_nat(count)),visible,closed),
        layout(rest,String.drop(canonical,U32.to_nat(count)),collapsed,
          U32.add(visible,Bool.pick(U32,closed,0,count)))))

def from_view(page: String,epoch: U32,+view: P.View) -> Model:
  P.View{+document,collapsed,projection,_,_,_} = view
  +rows = layout(Doc.parts(document),Doc.text(document),collapsed,0)
  Model{page,epoch,view,rows,Doc.length(P.text(projection)),U32.from_nat(List.length(&2,Row,rows)),None{}}

def open(+document: Doc.Document,page: String) -> Model:
  +folds = initial_folds(Doc.parts(document))
  from_view(page,Doc.revision(document),P.View{document,folds,P.build(document,folds),0,0,False{}})

def toggle.valid(+model: Model,expected: Token,+key: Doc.PartKey,valid: Bool) -> Model:
  Model{page,epoch,view,_,_,_,_} = model
  match valid:
    case False{}: model
    case True{}: with_focus(from_view(page,epoch,P.toggle(view,revision(model),key)),Some{key})

def toggle(+model: Model,+expected: Token,+key: Doc.PartKey) -> Model:
  Model{_,_,P.View{document,_,_,_,_,_},_,_,_,_} = model
  toggle.valid(model,expected,key,accepts(model,expected) &&
    U32.is_lt(revision(model),4294967295) && P.collapsible(P.find(Doc.parts(document),key)))

def row_at(rows: List<&2,Row>,at: Nat) -> Maybe<&2,Row>:
  match rows at:
    case Nil{} _: None{}
    case Con{row,rest} 0n: Some{row}
    case Con{_,rest} 1n+n: row_at(rest,n)

def hit_row(row: Maybe<&2,Row>,column: U32) -> Hit:
  match row:
    case Some{TextRow{start,_,count,_}}: TextHit{U32.add(start,U32.min(count,column))}
    case Some{SectionRow{_,Some{key},_}}: FoldHit{key}
    case _: NoHit{}

def hit(model: Model,row: U32,column: U32) -> Hit:
  Model{_,_,_,rows,_,_,_} = model
  hit_row(row_at(rows,U32.to_nat(row)),column)

def controls(rows: List<&2,Row>) -> List<&2,Doc.PartKey>:
  match rows:
    case []: []
    case SectionRow{_,Some{key},_} <> rest: key <> controls(rest)
    case _ <> rest: controls(rest)

def first(keys: List<&2,Doc.PartKey>) -> Maybe<&2,Doc.PartKey>:
  match keys:
    case []: None{}
    case key <> _: Some{key}

def next_key(keys: List<&2,Doc.PartKey>,+key: Doc.PartKey) -> Maybe<&2,Doc.PartKey>:
  match keys:
    case []: None{}
    case +head <> +tail:
      Bool.pick(Maybe<&2,Doc.PartKey>,Doc.key_equal(head,key),first(tail),next_key(tail,key))

def focus_from(focused: Maybe<&2,Doc.PartKey>,ordered: List<&2,Doc.PartKey>) -> Maybe<&2,Doc.PartKey>:
  match focused:
    case None{}: first(ordered)
    case Some{key}: next_key(ordered,key)

def focus_next(+model: Model,backward: Bool) -> Maybe<&2,Doc.PartKey>:
  Model{_,_,_,rows,_,_,focused} = model
  +keys = controls(rows)
  focus_from(focused,Bool.pick(List<&2,Doc.PartKey>,backward,List.reverse(&2,Doc.PartKey,keys),keys))

def focus_row(rows: List<&2,Row>,+key: Doc.PartKey,+at: U32) -> Maybe<&2,U32>:
  match rows:
    case []: None{}
    case SectionRow{_,Some{+other},_} <> rest:
      Bool.pick(Maybe<&2,U32>,Doc.key_equal(key,other),Some{at},focus_row(rest,key,U32.inc(at)))
    case _ <> rest: focus_row(rest,key,U32.inc(at))

def focused_row(model: Model) -> Maybe<&2,U32>:
  Model{_,_,_,rows,_,_,focused} = model
  match focused:
    case None{}: None{}
    case Some{key}: focus_row(rows,key,0)

def is_focused(focused: Maybe<&2,Doc.PartKey>,key: Maybe<&2,Doc.PartKey>) -> Bool:
  match focused key:
    case Some{left} Some{right}: Doc.key_equal(left,right)
    case _ _: False{}

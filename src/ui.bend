# Native Juice Bend UI. Layout, text editing, selection and hit testing are Bend.
# Coordinates use an 8px canvas grid; Unicode offsets count decoded Char values.
import Base
import ./font.bend as Font
import ./ui_geometry.bend as G

type Line is Data:
  Line{start: U32, text: String}

type Content is Data:
  Content{query: String, rows: List<&2, String>, reader: String,
    lines: List<&2, Line>, title: String, status: String, scope: String, results: Results, files: Bool}

type Results is Data:
  Results{offset: U32, count: U32, has_more: Bool, ready: Bool}
  RelatedResults{page: U32, count: U32, has_more: Bool, has_previous: Bool}
  SettingsResults{offset: U32,total: U32,automatic: String,ready: Bool}

type Edit is Data:
  Edit{focus: U32, caret: U32, anchor: U32, dragging: Bool, viewport: U32}

type Input is Data:
  Input{selected: U32, scroll: U32, edit: Edit, command: Bool, shift: Bool}

type State is Data:
  State{content: Content, input: Input, image: Image, dirty: Bool}

# Bookmarks retain text, list position and character selection, never an image
# or transient key/drag state. Restoration redraws with the current renderer.
type Bookmark is Data:
  Bookmark{content: Content,input: Input}

type Action is Data:
  NoAction{}
  Search{}
  Open{index: U32}
  Submit{}
  Scope{provider: String}
  Copy{text: String}
  Paste{}
  Export{}
  Why{}
  Usage{}
  Tools{}
  Related{}
  Back{}
  Rebuild{}
  Versions{}
  OpenLatest{}
  Blame{}
  Filter{}
  Refresh{}
  Pause{}
  Settings{}
  SettingsAddFolder{}
  SettingsImportFile{}
  SettingsEnable{}
  SettingsDisable{}
  SettingsInterval{seconds: U32}
  SettingsReload{}
  Storage{}
  Files{}
  RepoOpen{}
  RepoParent{}
  Previous{}
  Next{}
  ListPrevious{}
  ListNext{}
  Quit{}

# A compact application-specific cell canvas. Flat areas remain one Image node.
type Canvas is Data:
  Flat{color: U32}
  Tile{bits: Font.Half, foreground: U32, background: U32}
  Four{tl: Canvas, tr: Canvas, bl: Canvas, br: Canvas}

def length(+s: String) -> U32:
  U32.from_nat(String.length(s))

def minus(+a: U32, +b: U32) -> U32:
  Bool.pick(U32, U32.is_gt(a, b), U32.sub(a, b), 0)

def span(+s: String, +a: U32, +b: U32) -> String:
  String.take(String.drop(s, U32.to_nat(U32.min(a, b))),
    U32.to_nat(minus(U32.max(a, b), U32.min(a, b))))

def lines.go(+s: String,+at: U32,+start: U32,+col: U32,+acc: String,done: List<&2,Line>,full: Bool) -> List<&2,Line>:
  match s full:
    case SNil{} _: List.reverse(&2,Line,Line{start,String.reverse(acc)} <> done)
    case SCon{Chr{10},tail} _:
      lines.go(tail,U32.add(at,1),U32.add(at,1),0,"",Line{start,String.reverse(acc)} <> done,False{})
    case SCon{c,tail} True{}:
      lines.go(tail,U32.add(at,1),at,1,SCon{c,""},Line{start,String.reverse(acc)} <> done,False{})
    case SCon{c,tail} False{}:
      lines.go(tail,U32.add(at,1),start,U32.add(col,1),SCon{c,acc},done,U32.is_eq(U32.add(col,1),G.reader_columns()))

def wrap(+s: String) -> List<&2, Line>:
  lines.go(s, 0, 0, 0, "", [],False{})

def init() -> State:
  State{Content{"", [], "Choose a captured session to read its owned evidence.",
    wrap("Choose a captured session to read its owned evidence."),
    "Transcript", "Ready. Only explicitly enabled sources are scanned.", "all",Results{0,0,False{},False{}},False{}},
    Input{0, 0, Edit{0, 0, 0, False{}, 0}, False{}, False{}}, Pix{16777215}, True{}}

def bookmark(state: State) -> Bookmark:
  State{content,input,image,dirty} = state
  Bookmark{content,input}

def restore(state: State,bookmark: Bookmark) -> State:
  State{old,oldinput,image,dirty} = state
  Bookmark{content,Input{selected,scroll,Edit{focus,caret,anchor,drag,viewport},command,shift}} = bookmark
  State{content,Input{selected,scroll,Edit{focus,caret,anchor,False{},viewport},False{},False{}},image,True{}}

def bookmark_selected(bookmark: Bookmark,selected: U32) -> Bookmark:
  Bookmark{content,Input{old,scroll,edit,command,shift}} = bookmark
  Bookmark{content,Input{selected,scroll,edit,command,shift}}

def is_files(s: State) -> Bool:
  State{Content{q,rows,reader,lines,title,status,scope,results,+files},input,image,dirty} = s
  files

def set_files(s: State,files: Bool) -> State:
  State{Content{q,rows,reader,lines,title,status,scope,results,old},input,image,dirty} = s
  State{Content{q,rows,reader,lines,title,status,scope,results,files},input,image,True{}}

def is_settings(s: State) -> Bool:
  State{Content{q,rows,reader,lines,title,status,scope,results,files},input,image,dirty} = s
  match results:
    case SettingsResults{+offset,+total,automatic,ready}: True{}
    case _: False{}

def title(s: State) -> String:
  State{Content{q,rows,reader,lines,title,status,scope,results,+files},input,image,dirty} = s
  title

def focus(s: State) -> U32:
  State{content,Input{selected,scroll,Edit{focus,caret,anchor,drag,viewport},command,shift},image,dirty} = s
  focus

def scroll(s: State) -> U32:
  State{content,Input{selected,scroll,edit,command,shift},image,dirty} = s
  scroll

def query(+s: State) -> String:
  State{Content{q, rows, reader, lines, title, status, scope,+results,+files}, input, image, dirty} = s
  q

def selected(+s: State) -> U32:
  State{content, Input{n, scroll, edit, command, shift}, image, dirty} = s
  n

def scope(+s: State) -> String:
  State{Content{q, rows, reader, lines, title, status, scope,+results,+files}, input, image, dirty} = s
  scope

def reader(+s: State) -> String:
  State{Content{q, rows, reader, lines, title, status, scope,+results,+files}, input, image, dirty} = s
  reader

def set_status(+s: State, +status: String) -> State:
  State{Content{q, rows, reader, lines, title, old, scope,+results,+files}, input, image, dirty} = s
  State{Content{q, rows, reader, lines, title, status, scope,results,files}, input, image, True{}}

def set_rows(+s: State, rows: List<&2, String>) -> State:
  State{Content{q, old, reader, lines, title, status, scope,results,files},
    Input{selected, scroll, edit, command, shift}, image, dirty} = s
  State{Content{q, rows, reader, lines, title, status, scope,results,files},
    Input{0, scroll, edit, command, shift}, image, True{}}

def set_results(+s: State, results: Results) -> State:
  State{Content{q,rows,reader,lines,title,status,scope,old,+files},input,image,dirty} = s
  State{Content{q,rows,reader,lines,title,status,scope,results,files},input,image,True{}}

def ordinary_result_label(+offset: U32,+count: U32,more: Bool,ready: Bool) -> String:
  match count ready:
    case _ False{}:
      "Results not loaded"
    case 0 True{}:
      Bool.pick(String,U32.is_eq(offset,0),"No results","No results after " ++ U32.show(offset))
    case _ True{}:
      U32.show(U32.add(offset,1)) ++ "-" ++ Nat.show(Nat.add(U32.to_nat(offset),U32.to_nat(count))) ++
        Bool.pick(String,more," + more"," / end")

def result_label(results: Results) -> String:
  match results:
    case Results{offset,count,more,ready}: ordinary_result_label(offset,count,more,ready)
    case RelatedResults{page,count,more,previous}:
      "Page " ++ U32.show(page) ++ " | " ++ U32.show(count) ++ " links"
    case SettingsResults{+offset,+total,automatic,ready}:
      Bool.pick(String,ready,Bool.pick(String,U32.is_eq(total,0),"No registered folders",U32.show(U32.add(offset,1)) ++ "-" ++ U32.show(U32.min(U32.add(offset,14),total)) ++ "/" ++ U32.show(total)),"Inventory not loaded")

def result_available(results: Results,forward: Bool) -> Bool:
  match results:
    case Results{+offset,count,more,ready}:
      ready && Bool.pick(Bool,forward,more && U32.is_le(offset,4294967095),U32.is_gt(offset,0))
    case RelatedResults{page,count,more,previous}:
      Bool.pick(Bool,forward,more,previous)
    case SettingsResults{+offset,+total,automatic,ready}:
      ready && Bool.pick(Bool,forward,U32.is_lt(U32.add(offset,14),total),U32.is_gt(offset,0))

def result_action_if(+s: State,+forward: Bool,available: Bool) -> State & Action:
  match available:
    case True{}:
      (s,Bool.pick(Action,forward,ListNext{},ListPrevious{}))
    case False{}:
      (s,NoAction{})

def result_action(+s: State,+forward: Bool) -> State & Action:
  State{Content{q,rows,reader,lines,title,status,scope,results,+files},input,image,dirty} = s
  result_action_if(s,forward,result_available(results,forward))

def set_reader(+s: State, +title: String, +reader: String) -> State:
  State{Content{q, rows, old, oldlines, oldtitle, status, scope,results,files},
    Input{selected, scroll, Edit{+focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  State{Content{q, rows, reader, wrap(reader), title, status, scope,results,files},
    Input{selected, 0, Edit{focus, Bool.pick(U32,(U32.is_eq(focus,0) || U32.is_eq(focus,3)),caret,0),
      Bool.pick(U32,(U32.is_eq(focus,0) || U32.is_eq(focus,3)),anchor,0),
      Bool.pick(Bool,(U32.is_eq(focus,0) || U32.is_eq(focus,3)),drag,False{}),Bool.pick(U32,(U32.is_eq(focus,0) || U32.is_eq(focus,3)),viewport,0)}, command, shift}, image, True{}}

def set_scope(+s: State, +scope: String) -> State:
  State{Content{q, rows, reader, lines, title, status, old,+results,+files}, input, image, dirty} = s
  State{Content{q, rows, reader, lines, title, status, scope,results,files}, input, image, True{}}

def set_query(+s: State, +q: String) -> State:
  State{Content{old, rows, reader, lines, title, status, scope,results,files},
    Input{selected, scroll, edit, command, shift}, image, dirty} = s
  +n = length(q)
  State{Content{q, rows, reader, lines, title, status, scope,results,files},
    Input{selected, scroll, Edit{0, n, n, False{}, 0}, command, shift}, image, True{}}

def set_edit(+s: State, +edit: Edit) -> State:
  State{content, Input{selected, scroll, old, command, shift}, image, dirty} = s
  State{content, Input{selected, scroll, edit, command, shift}, image, True{}}

def set_position(+s: State, +selected: U32, +scroll: U32) -> State:
  State{content, Input{old, oldscroll, edit, command, shift}, image, dirty} = s
  State{content, Input{selected, scroll, edit, command, shift}, image, True{}}

def set_modifiers(+s: State, +command: Bool, +shift: Bool) -> State:
  State{content, Input{selected, scroll, edit, oldcmd, oldshift}, image, dirty} = s
  State{content, Input{selected, scroll, edit, command, shift}, image, dirty}

# Search edits are bounded to 512 committed Unicode characters.

def insert(+s: State, +text: String) -> State:
  State{Content{+q, rows, reader, lines, title, status, scope,results,files},
    Input{selected, scroll, Edit{focus, +caret, +anchor, drag, viewport}, command, shift}, image, dirty} = s
  +start = U32.min(caret, anchor)
  +ins = String.take(text, U32.to_nat(minus(512, minus(length(q),
    minus(U32.max(caret, anchor), start)))))
  +next = String.concat([String.take(q, U32.to_nat(start)), ins,
    String.drop(q, U32.to_nat(U32.max(caret, anchor)))])
  +pos = U32.add(start, length(ins))
  set_edit(set_query(s, next), Edit{0, pos, pos, False{}, 0})

def backspace(+s: State) -> State:
  State{content, Input{selected, scroll, Edit{focus, +caret, +anchor, drag, viewport}, command, shift}, image, dirty} = s
  +start = Bool.pick(U32, U32.is_eq(caret, anchor), minus(caret, 1), U32.min(caret, anchor))
  insert(set_edit(s, Edit{0, start, U32.max(caret, anchor), False{}, 0}), "")

def select_all(+s: State) -> State:
  State{Content{q, rows, reader, lines, title, status, scope,results,files},
    Input{selected, scroll, Edit{+focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  +n = Bool.pick(U32, U32.is_eq(focus, 0), length(q), length(reader))
  set_edit(s, Edit{Bool.pick(U32, U32.is_eq(focus, 0), 0, 2), n, 0, False{}, 0})

def selection(+s: State) -> String:
  State{Content{q, rows, reader, lines, title, status, scope,results,files},
    Input{selected, scroll, Edit{+focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  span(Bool.pick(String, U32.is_eq(focus, 0), q, reader), caret, anchor)

def move_caret(+s: State, +right: Bool) -> State:
  State{Content{q, rows, reader, lines, title, status, scope,results,files},
    Input{selected, scroll, Edit{+focus, +caret, anchor, drag, viewport}, command, +shift}, image, dirty} = s
  +n = Bool.pick(U32, U32.is_eq(focus, 0), length(q), length(reader))
  +pos = Bool.pick(U32, right, U32.min(n, U32.add(caret, 1)), minus(caret, 1))
  set_edit(s, Edit{focus, pos, Bool.pick(U32, shift, anchor, pos), False{}, 0})

def scroll_by(+s: State, +down: Bool, +amount: U32) -> State:
  State{Content{q, rows, reader, +lines, title, status, scope,results,files},
    Input{selected, +scroll, edit, command, shift}, image, dirty} = s
  +limit = minus(U32.from_nat(List.length(&2, Line, lines)), G.reader_rows())
  +next = Bool.pick(U32, down, U32.min(limit, U32.add(scroll, amount)), minus(scroll, amount))
  set_position(s, selected, next)

# The event API returns one explicit action for the integration owner to execute.

def line_at.go(lines: List<&2, Line>) -> Line:
  match lines:
    case []:
      Line{0, ""}
    case h <> rest:
      h

def line_at(lines: List<&2, Line>, +at: U32) -> Line:
  line_at.go(List.drop(&2, Line, lines, U32.to_nat(at)))

def reader_at_line(+line: Line,+x: U32) -> U32:
  Line{start,text} = line
  U32.add(start,U32.min(length(text),U32.div(minus(x,G.reader_x()),G.cell())))

def reader_at(+s: State,+x: U32,+y: U32) -> U32:
  State{Content{q,rows,reader,+lines,title,status,scope,results,files},Input{selected,scroll,edit,command,shift},image,dirty} = s
  reader_at_line(line_at(lines,U32.min(minus(U32.from_nat(List.length(&2,Line,lines)),1),U32.add(scroll,U32.min(U32.sub(G.reader_rows(),1),U32.div(minus(y,G.reader_y()),G.line_pitch()))))),x)

def query_offset(s: State) -> U32:
  State{content, Input{selected, scroll, Edit{focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  Bool.pick(U32, U32.is_eq(focus, 0), Bool.pick(U32,drag,viewport,minus(caret,U32.sub(G.query_columns(),2))), 0)

def query_at(+s: State,col: U32) -> U32:
  U32.min(length(query(s)),U32.add(query_offset(s),U32.min(G.query_columns(),minus(col,U32.div(G.query_x(),G.cell())))))

def drag_if(+s: State, +x: U32, +y: U32, +focus: U32, +anchor: U32, +dragging: Bool) -> State & Action:
  match dragging:
    case True{}:
      (set_edit(s, Edit{focus, Bool.pick(U32, U32.is_eq(focus, 0), query_at(s, U32.div(x, G.cell())), reader_at(s, x, y)), anchor, True{}, query_offset(s)}), NoAction{})
    case False{}:
      (s, NoAction{})

# OS clipboard transport only. No shell, no interpolated command, bounded IO.

def drag(+s: State, +x: U32, +y: U32) -> State & Action:
  State{content, Input{selected, scroll, Edit{focus, caret, anchor, dragging, viewport}, command, shift}, image, dirty} = s
  drag_if(s, x, y, focus, anchor, dragging)

def arrow_focus(+s: State, +down: Bool, +focus: U32, +count: U32) -> State & Action:
  State{content, Input{+selected, scroll, edit, command, shift}, image, dirty} = s
  match focus:
    case 2:
      (scroll_by(s, down, 1), NoAction{})
    case _:
      +next = Bool.pick(U32, down, U32.min(minus(count, 1), U32.add(selected, 1)), minus(selected, 1))
      (set_position(set_edit(s, Edit{1, 0, 0, False{}, 0}), next, scroll), Open{next})

def arrow(+s: State, +down: Bool) -> State & Action:
  State{Content{q, rows, reader, lines, title, status, scope,results,files},
    Input{selected, scroll, Edit{focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  arrow_focus(s, down, focus, U32.from_nat(List.length(&2, String, rows)))

def delete_focused(+s: State, +focus: U32) -> State & Action:
  match focus:
    case 0:
      (backspace(s), Search{})
    case _:
      (s, NoAction{})

def delete_query(+s: State) -> State & Action:
  State{content, Input{selected, scroll, Edit{focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  delete_focused(s, focus)

def tab(+s: State) -> State & Action:
  State{content, Input{selected, scroll, Edit{focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  (set_edit(s, Edit{U32.mod(U32.add(focus, 1), 3), 0, 0, False{}, 0}), NoAction{})

def copy_action(+s: State, empty: Bool) -> State & Action:
  match empty:
    case True{}:
      (s, NoAction{})
    case False{}:
      (s, Copy{selection(s)})

def paste_action(s: State, focus: U32) -> State & Action:
  match focus:
    case 0:
      (s, Paste{})
    case _:
      (s, NoAction{})

def paste_focused(+s: State) -> State & Action:
  State{content, Input{selected, scroll, Edit{focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  paste_action(s, focus)

def wheel_in(+s: State, down: Bool, list: Bool) -> State & Action:
  match list:
    case True{}:
      arrow(set_edit(s, Edit{1, 0, 0, False{}, 0}), down)
    case False{}:
      (scroll_by(s, down, 3), NoAction{})

def wheel(s: State,+x: U32,down: Bool) -> State & Action:
  wheel_in(s,down,(x >= G.sidebar_end() && x < G.list_end() : U32))

def key_down(+s: State, +code: U32, +command: Bool) -> State & Action:
  match code command:
    case 113 True{}:
      (s, Quit{})
    case 102 True{}:
      (select_all(set_edit(s, Edit{0, 0, 0, False{}, 0})), NoAction{})
    case 97 True{}:
      (select_all(s), NoAction{})
    case 99 True{}:
      copy_action(s, String.is_empty(selection(s)))
    case 118 True{}:
      paste_focused(s)
    case 114 True{}:
      (s, Refresh{})
    case 101 True{}:
      (s, Export{})
    case 98 True{}:
      (s, Blame{})
    case 108 True{}:
      (s, Filter{})
    case 116 True{}:
      (s, Tools{})
    case 103 True{}:
      (s, Related{})
    case 91 True{}:
      (s, Back{})
    case 13 _:
      (s, Submit{})
    case 127 False{}:
      delete_query(s)
    case 8 False{}:
      delete_query(s)
    case 63234 _:
      (move_caret(s, False{}), NoAction{})
    case 63235 _:
      (move_caret(s, True{}), NoAction{})
    case 63232 _:
      arrow(s, False{})
    case 63233 _:
      arrow(s, True{})
    case 63276 _:
      (scroll_by(s, False{}, U32.sub(G.reader_rows(),2)), NoAction{})
    case 63277 _:
      (scroll_by(s, True{}, U32.sub(G.reader_rows(),2)), NoAction{})
    case 9 _:
      tab(s)
    case 27 _:
      (set_edit(s, Edit{0, 0, 0, False{}, 0}), NoAction{})
    case _ _:
      (s, NoAction{})

def key(+s: State, +code: U32, +down: Bool) -> State & Action:
  State{content, Input{selected, scroll, edit, +command, +shift}, image, dirty} = s
  match code down:
    case 65591 d:
      (set_modifiers(s, d, shift), NoAction{})
    case 65590 d:
      (set_modifiers(s, d, shift), NoAction{})
    case 65592 d:
      (set_modifiers(s, command, d), NoAction{})
    case 65596 d:
      (set_modifiers(s, command, d), NoAction{})
    case c True{}:
      key_down(s, c, command)
    case _ False{}:
      (s, NoAction{})

def paste_query_at(+s: State,focus: U32) -> State & Action:
  match focus:
    case 0:
      (s,Paste{})
    case _:
      (set_query(s,query(s)),Paste{})

def paste_query(+s: State) -> State & Action:
  State{content,Input{selected,scroll,Edit{focus,caret,anchor,drag, viewport},command,shift},image,dirty} = s
  paste_query_at(s,focus)

def sidebar_normal(+s: State,index: U32) -> State & Action:
  match index:
    case 0: (s,Files{})
    case 1: (set_scope(s,"all"),Scope{"all"})
    case 2: (set_scope(s,"claude"),Scope{"claude"})
    case 3: (set_scope(s,"codex"),Scope{"codex"})
    case 4: (s,Filter{})
    case 5: (s,Tools{})
    case 6: (s,Usage{})
    case 7: (s,Related{})
    case 8: (s,Versions{})
    case 9: (s,OpenLatest{})
    case 10: (s,Settings{})
    case 11: (s,Storage{})
    case 12: (s,Rebuild{})
    case 13: copy_action(s,String.is_empty(selection(s)))
    case 14: paste_query(s)
    case 15: (set_query(s,""),Search{})
    case 16: (select_all(s),NoAction{})
    case 17: (s,Back{})
    case _: (s,NoAction{})

def sidebar_settings(+s: State,index: U32) -> State & Action:
  match index:
    case 0: (s,Settings{})
    case 1: (s,Pause{})
    case 2: (set_scope(s,"claude"),Scope{"claude"})
    case 3: (set_scope(s,"codex"),Scope{"codex"})
    case 4: (s,SettingsAddFolder{})
    case 5: (s,SettingsImportFile{})
    case 6: (s,Storage{})
    case 7: (s,SettingsReload{})
    case 8: (s,SettingsEnable{})
    case 9: (s,SettingsDisable{})
    case 10: (s,SettingsInterval{30})
    case 11: (s,SettingsInterval{7200})
    case 12: (s,SettingsInterval{14400})
    case 13: (s,SettingsInterval{28800})
    case 14: (s,SettingsInterval{86400})
    case 15: (set_query(s,""),Search{})
    case 16: (select_all(s),NoAction{})
    case 17: (s,Settings{})
    case _: (s,NoAction{})

def sidebar_mode(s: State,row: U32,settings: Bool) -> State & Action:
  match settings:
    case True{}: sidebar_settings(s,row)
    case False{}: sidebar_normal(s,row)

def sidebar_action(+s: State,row: U32) -> State & Action:
  sidebar_mode(s,row,is_settings(s))

def list_row_click(+s: State,+index: U32,valid: Bool) -> State & Action:
  match valid:
    case True{}:
      (set_position(set_edit(s,Edit{1,0,0,False{},0}),index,0),Open{index})
    case False{}:
      (s,NoAction{})

def list_click.body(+s: State,+x: U32,+y: U32,rows: List<&2,String>,parent: Bool) -> State & Action:
  match parent:
    case True{}: (s,RepoParent{})
    case False{}:
      +index = U32.add(minus(selected(s),U32.sub(G.list_rows(),1)),U32.div(minus(y,G.list_y()),G.list_pitch()))
      list_row_click(s,index,U32.is_ge(y,G.list_y()) && U32.is_lt(y,U32.add(G.list_y(),U32.mul(G.list_rows(),G.list_pitch()))) && U32.is_lt(index,U32.from_nat(List.length(&2,String,rows))))

def list_click.zone(+s: State,+x: U32,+y: U32,rows: List<&2,String>,files: Bool,pager: Bool) -> State & Action:
  match pager:
    case True{}: result_action(s,U32.is_ge(x,344))
    case False{}: list_click.body(s,x,y,rows,G.rect(x,y,G.sidebar_end(),120,G.list_end(),152) && files)

def list_click(+s: State,+col: U32,+row: U32) -> State & Action:
  State{Content{q,rows,reader,lines,title,status,scope,results,+files},input,image,dirty} = s
  +x = U32.mul(col,G.cell())
  +y = U32.mul(row,G.cell())
  list_click.zone(s,x,y,rows,files,U32.is_ge(y,G.list_pager_y()))

def text_action(+s: State,index: U32) -> State & Action:
  match index:
    case 0: copy_action(s,String.is_empty(selection(s)))
    case 1: paste_query(s)
    case 2: (set_query(s,""),Search{})
    case 3: (select_all(s),NoAction{})
    case _: (s,NoAction{})

def mouse_reader(+s: State,+x: U32,+y: U32,inside: Bool) -> State & Action:
  match inside:
    case True{}:
      +pos = reader_at(s,x,y)
      (set_edit(s,Edit{2,pos,pos,True{},0}),NoAction{})
    case False{}: (s,NoAction{})

def mouse_text(+s: State,+x: U32,+y: U32,actions: Bool) -> State & Action:
  match actions:
    case True{}: text_action(s,U32.div(U32.sub(x,G.text_actions_x()),G.text_action_width()))
    case False{}: mouse_reader(s,x,y,G.rect(x,y,G.list_end(),G.reader_y(),1408,G.footer_y()))

def mouse_body(+s: State,+x: U32,+y: U32,+col: U32,+row: U32,+sidebar: Bool,+list: Bool) -> State & Action:
  match sidebar list:
    case True{} _: sidebar_action(s,G.side_index(y))
    case False{} True{}: list_click(s,col,row)
    case False{} False{}: mouse_text(s,x,y,G.rect(x,y,G.text_actions_x(),G.text_actions_y(),G.text_action_x(4),U32.add(G.text_actions_y(),G.control_height())))

def top_normal(+s: State, +group: U32) -> State & Action:
  match group:
    case 0:
      (s, Bool.pick(Action,is_files(s),RepoOpen{},Refresh{}))
    case 1:
      (s, Pause{})
    case 2:
      (s, Blame{})
    case 3:
      (s, Why{})
    case 4:
      (s, Export{})
    case 5:
      (s, Previous{})
    case 6:
      (s, Next{})
    case 7:
      (s, Settings{})
    case _:
      (s, NoAction{})

def top_settings(s: State,group: U32) -> State & Action:
  match group:
    case 0: (s,Refresh{})
    case 1: (s,Pause{})
    case 2: (s,SettingsAddFolder{})
    case 3: (s,SettingsImportFile{})
    case 4: (s,SettingsEnable{})
    case 5: (s,SettingsDisable{})
    case 6: (s,SettingsReload{})
    case _: (s,NoAction{})

def top_mode(s: State,group: U32,settings: Bool) -> State & Action:
  match settings:
    case True{}: top_settings(s,group)
    case False{}: top_normal(s,group)

def top_action(+s: State,group: U32) -> State & Action:
  top_mode(s,group,is_settings(s))

def query_click(+s: State, col: U32) -> State & Action:
  +pos = query_at(s, col)
  (set_edit(s, Edit{0, pos, pos, True{}, query_offset(s)}), NoAction{})

def mouse_top.action(+s: State,x: U32,inside: Bool) -> State & Action:
  match inside:
    case True{}: top_action(s,G.top_index(x))
    case False{}: (s,NoAction{})

def mouse_top.query(+s: State,+col: U32,+x: U32,+y: U32,inside: Bool) -> State & Action:
  match inside:
    case True{}: query_click(s,col)
    case False{}: mouse_top.action(s,x,(y >= 80 && y < 112 : U32))

def mouse_top(+s: State,+col: U32,+row: U32) -> State & Action:
  +x = U32.mul(col,G.cell())
  +y = U32.mul(row,G.cell())
  mouse_top.query(s,col,x,y,G.rect(x,y,192,24,1384,64))

# A UI-only inspector. Canonical evidence and its reader scroll stay untouched.
def status_text(s: State) -> String:
  State{Content{q,rows,reader,lines,title,status,scope,results,files},input,image,dirty} = s
  status

# Focus 3/4/5 means status over query/list/reader. The evidence selection
# remains in caret/anchor; this inspector supports full-message copy only.
def status_open(+s: State) -> State:
  State{content,Input{selected,scroll,Edit{focus,caret,anchor,drag,viewport},command,shift},image,dirty} = s
  set_edit(s,Edit{U32.add(focus,3),caret,anchor,False{},0})

def status_close(+s: State) -> State:
  State{content,Input{selected,scroll,Edit{focus,caret,anchor,drag,viewport},command,shift},image,dirty} = s
  set_edit(s,Edit{U32.sub(focus,3),caret,anchor,False{},0})

def status_copy(+s: State) -> State & Action:
  (status_close(s),Copy{status_text(s)})

def status_scroll(+s: State,+down: Bool,+amount: U32) -> State:
  State{content,Input{selected,scroll,Edit{focus,caret,anchor,drag,+viewport},command,shift},image,dirty} = s
  +limit = minus(U32.from_nat(List.length(&2,Line,wrap(status_text(s)))),G.reader_rows())
  +next = Bool.pick(U32,down,U32.min(limit,U32.add(viewport,amount)),minus(viewport,amount))
  set_edit(s,Edit{focus,caret,anchor,False{},next})

def status_mouse_target(+s: State,close: Bool,copy: Bool) -> State & Action:
  match close copy:
    case True{} _: (status_close(s),NoAction{})
    case False{} True{}: status_copy(s)
    case False{} False{}: (s,NoAction{})

def status_mouse(+s: State,+x: U32,+y: U32,down: Bool) -> State & Action:
  match down:
    case False{}: (s,NoAction{})
    case True{}:
      status_mouse_target(s,G.rect(x,y,1296,120,1408,152) || U32.is_ge(y,G.footer_y()),G.rect(x,y,1120,120,1288,152))

def status_key(+s: State,code: U32,down: Bool,command: Bool) -> State & Action:
  match code down command:
    case 65591 d _: key(s,65591,d)
    case 65590 d _: key(s,65590,d)
    case 65592 d _: key(s,65592,d)
    case 65596 d _: key(s,65596,d)
    case 113 True{} True{}: (s,Quit{})
    case 99 True{} True{}: status_copy(s)
    case 91 True{} True{}: (status_close(s),NoAction{})
    case 27 True{} _: (status_close(s),NoAction{})
    case 63232 True{} _: (status_scroll(s,False{},1),NoAction{})
    case 63233 True{} _: (status_scroll(s,True{},1),NoAction{})
    case 63276 True{} _: (status_scroll(s,False{},26),NoAction{})
    case 63277 True{} _: (status_scroll(s,True{},26),NoAction{})
    case _ _ _: (s,NoAction{})

def status_wheel(+s: State,+dy: F32,zero: Bool) -> State & Action:
  match zero:
    case True{}: (s,NoAction{})
    case False{}: (status_scroll(s,F32.is_lt(dy,0.0),3),NoAction{})

def status_event(+s: State,e: Event) -> State & Action:
  State{content,Input{selected,scroll,edit,+command,shift},image,dirty} = s
  match e:
    case Close{}: (s,Quit{})
    case Key{code,down}: status_key(s,code,down,command)
    case Mouse{x,y,0,down}: status_mouse(s,x,y,down)
    case Scroll{x,y,dx,+dy}: status_wheel(s,dy,F32.is_eq(dy,0.0))
    case _: (s,NoAction{})

def mouse_toolbar.body(+s: State,+x: U32,+y: U32,+col: U32,+row: U32,footer: Bool) -> State & Action:
  match footer:
    case True{}: (status_open(s),NoAction{})
    case False{}: mouse_body(s,x,y,col,row,U32.is_lt(x,G.sidebar_end()),U32.is_lt(x,G.list_end()))

def mouse_toolbar(+s: State,+x: U32,+y: U32,+col: U32,+row: U32,toolbar: Bool) -> State & Action:
  match toolbar:
    case True{}: mouse_top(s,col,row)
    case False{}: mouse_toolbar.body(s,x,y,col,row,U32.is_ge(y,G.footer_y()))

def mouse_zone(+s: State,+x: U32,+y: U32,+col: U32,+row: U32) -> State & Action:
  mouse_toolbar(s,x,y,col,row,U32.is_lt(y,112))

def mouse(+s: State, +x: U32, +y: U32, +down: Bool) -> State & Action:
  State{content, Input{selected, scroll, Edit{focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  match down:
    case False{}:
      (set_edit(s, Edit{focus, caret, anchor, False{}, 0}), NoAction{})
    case True{}:
      mouse_zone(s, x, y, U32.div(x, G.cell()), U32.div(y, G.cell()))

def text_focused(+s: State, +text: String, +query_focus: Bool) -> State & Action:
  match query_focus:
    case True{}:
      (insert(s, text), Search{})
    case False{}:
      (s, NoAction{})

def text_event(+s: State, +text: String) -> State & Action:
  State{content, Input{selected, scroll, Edit{focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  text_focused(s, text, U32.is_eq(focus, 0))

def wheel_vertical(s: State, x: U32, dy: F32, zero: Bool) -> State & Action:
  match zero:
    case True{}:
      (s, NoAction{})
    case False{}:
      wheel(s, x, F32.is_lt(dy, 0.0))

def event_main(+e: Event, +s: State) -> State & Action:
  match e:
    case Close{}:
      (s, Quit{})
    case Text{text}:
      text_event(s, text)
    case Key{code, down}:
      key(s, code, down)
    case Mouse{x, y, 0, down}:
      mouse(s, x, y, down)
    case Move{x, y}:
      drag(s, x, y)
    case Scroll{x, y, dx, +dy}:
      wheel_vertical(s, x, dy, F32.is_eq(dy, 0.0))
    case _:
      (s, NoAction{})

def event_mode(e: Event,s: State,modal: Bool) -> State & Action:
  match modal:
    case True{}: status_event(s,e)
    case False{}: event_main(e,s)

def event(+e: Event,+s: State) -> State & Action:
  event_mode(e,s,U32.is_ge(focus(s),3))

def clipboard_copy(+text: String) -> IO(Result<&1, &1, U32 & String, U32 & (String & String)>):
  Process.run("/usr/bin/pbcopy", [], text, 4096, 2000)

def clipboard_paste() -> IO(Result<&1, &1, U32 & String, U32 & (String & String)>):
  Process.run("/usr/bin/pbpaste", [], "", 65536, 2000)

# Canvas operations.

def canvas.children(+tl: Canvas, +tr: Canvas, +bl: Canvas, +br: Canvas,
  +quad: U32, update: Canvas -> Canvas) -> Canvas:
  match quad:
    case 0:
      Four{update(tl), tr, bl, br}
    case 1:
      Four{tl, update(tr), bl, br}
    case 2:
      Four{tl, tr, update(bl), br}
    case _:
      Four{tl, tr, bl, update(br)}

def canvas.update(+c: Canvas, +quad: U32, update: Canvas -> Canvas) -> Canvas:
  match c:
    case Flat{+bg}:
      canvas.children(Flat{bg}, Flat{bg}, Flat{bg}, Flat{bg}, quad, update)
    case Tile{bits, fg, +bg}:
      canvas.children(Flat{bg}, Flat{bg}, Flat{bg}, Flat{bg}, quad, update)
    case Four{tl, tr, bl, br}:
      canvas.children(tl, tr, bl, br, quad, update)

def canvas.set(+d: Nat, +c: Canvas, +x: U32, +y: U32, +tile: Canvas) -> Canvas:
  match d:
    case 0n:
      tile
    case 1n+ +p:
      +half = U32.shln(1, p)
      +quad = U32.add(Bool.to_u32(U32.is_ge(x, half)), U32.mul(2, Bool.to_u32(U32.is_ge(y, half))))
      canvas.update(c, quad, sub => canvas.set(p, sub, U32.mod(x, half), U32.mod(y, half), tile))

def ink() -> U32: 2434867
def muted() -> U32: 6448740
def accent() -> U32: 3762751
def paper() -> U32: 16777215
def rail() -> U32: 16054255
def panel() -> U32: 16317176
def selected_bg() -> U32: 14872027
def selection_bg() -> U32: 12444155

def glyph.put(+c: Canvas,+bits: Font.Glyph,+x: U32,+y: U32,+foreground: U32,+background: U32) -> Canvas:
  top = canvas.set(8n,c,x,y,Tile{Font.half(bits,True{}),foreground,background})
  canvas.set(8n,top,x,U32.add(y,1),Tile{Font.half(bits,False{}),foreground,background})

def write(+count: Nat,+c: Canvas,text: String,+x: U32,+y: U32,+foreground: U32,+background: U32) -> Canvas:
  match count text:
    case 1n+n SCon{Chr{code},rest}:
      write(n,glyph.put(c,Font.glyph(code),x,y,foreground,background),rest,U32.add(x,1),y,foreground,background)
    case _ _: c

def fill.row(+width: Nat,+c: Canvas,+x: U32,+y: U32,+color: U32) -> Canvas:
  match width:
    case 0n: c
    case 1n+n: fill.row(n,canvas.set(8n,c,x,y,Flat{color}),U32.add(x,1),y,color)

def fill(+rows: Nat,+c: Canvas,+x: U32,+y: U32,+width: Nat,+color: U32) -> Canvas:
  match rows:
    case 0n: c
    case 1n+n: fill(n,fill.row(width,c,x,y,color),x,U32.add(y,1),width,color)

def box(c: Canvas,x: U32,y: U32,width: U32,height: U32,color: U32) -> Canvas:
  fill(U32.to_nat(U32.div(height,G.cell())),c,U32.div(x,G.cell()),U32.div(y,G.cell()),U32.to_nat(U32.div(width,G.cell())),color)

def text(c: Canvas,label: String,x: U32,y: U32,count: U32,fg: U32,bg: U32) -> Canvas:
  write(U32.to_nat(count),c,label,U32.div(x,G.cell()),U32.div(y,G.cell()),fg,bg)

def blend.channel(+fg: U32,+bg: U32,+coverage: U32) -> U32:
  U32.div(U32.add(U32.mul(fg,coverage),U32.mul(bg,U32.sub(15,coverage))),15)

def blend(+fg: U32,+bg: U32,+coverage: U32) -> U32:
  r = blend.channel(U32.and(U32.shrn(fg,16n),255),U32.and(U32.shrn(bg,16n),255),coverage)
  g = blend.channel(U32.and(U32.shrn(fg,8n),255),U32.and(U32.shrn(bg,8n),255),coverage)
  b = blend.channel(U32.and(fg,255),U32.and(bg,255),coverage)
  U32.add(U32.add(U32.shln(r,16n),U32.shln(g,8n)),b)

def glyph.draw(+d: Nat,+x: U32,+y: U32,+bits: Font.Half,+fg: U32,+bg: U32) -> Image:
  match d:
    case 0n: Pix{blend(fg,bg,Font.coverage(bits,x,y))}
    case 1n+ +p:
      +h = U32.shln(1,p)
      Qua{glyph.draw(p,x,y,bits,fg,bg),glyph.draw(p,U32.add(x,h),y,bits,fg,bg),
        glyph.draw(p,x,U32.add(y,h),bits,fg,bg),glyph.draw(p,U32.add(x,h),U32.add(y,h),bits,fg,bg)}

def canvas.image(c: Canvas) -> Image:
  match c:
    case Flat{color}: Pix{color}
    case Tile{bits,fg,bg}: glyph.draw(3n,0,0,bits,fg,bg)
    case Four{tl,tr,bl,br}: Qua{canvas.image(tl),canvas.image(tr),canvas.image(bl),canvas.image(br)}

def draw_line(+count: Nat,+c: Canvas,text: String,+x: U32,+y: U32,+at: U32,+low: U32,+high: U32) -> Canvas:
  match count text:
    case 1n+n SCon{Chr{code},rest}:
      +bg = Bool.pick(U32,(at >= low && at < high : U32),selection_bg(),paper())
      next = glyph.put(c,Font.glyph(code),x,y,ink(),bg)
      draw_line(n,next,rest,U32.add(x,1),y,U32.add(at,1),low,high)
    case _ _: c

def draw_reader(+fuel: Nat,+c: Canvas,lines: List<&2,Line>,+y: U32,+low: U32,+high: U32) -> Canvas:
  match fuel lines:
    case 1n+n Line{start,text} <> rest:
      draw_reader(n,draw_line(U32.to_nat(G.reader_columns()),c,text,U32.div(G.reader_x(),G.cell()),y,start,low,high),rest,U32.add(y,U32.div(G.line_pitch(),G.cell())),low,high)
    case _ _: c

# Result cards are a display projection. The original row and transcript remain
# unchanged. Keep a short trailing token with its preceding word when possible.
type Card is Data:
  Card{first: String,second: String}

def card_space(fuel: Nat,text: String,+at: U32,+last: U32) -> U32:
  match fuel text:
    case 1n+n SCon{Chr{32},rest}: card_space(n,rest,U32.add(at,1),at)
    case 1n+n SCon{c,rest}: card_space(n,rest,U32.add(at,1),last)
    case _ _: last

def card_trim(text: String) -> String:
  match text:
    case SCon{Chr{32},rest}: card_trim(rest)
    case _: text

def card_tail(+text: String) -> String:
  Bool.pick(String,U32.is_gt(length(text),38),String.take(text,37n) ++ "…",text)

def card_at(+text: String,+limit: U32,+space: U32) -> Card:
  +split = Bool.pick(U32,U32.is_eq(space,0),limit,space)
  Card{String.take(text,U32.to_nat(split)),card_tail(card_trim(String.drop(text,U32.to_nat(split))))}

def card_long(+text: String,+limit: U32) -> Card:
  card_at(text,limit,card_space(U32.to_nat(U32.add(limit,1)),text,0,0))

def card_mode(+text: String,long: Bool) -> Card:
  match long:
    case False{}: Card{text,""}
    case True{}: card_long(text,U32.min(38,minus(length(text),8)))

def card(+text: String) -> Card:
  card_mode(text,U32.is_gt(length(text),38))

def card_draw(c: Canvas,card: Card,+y: U32,+bg: U32) -> Canvas:
  Card{first,second} = card
  line1 = text(c,first,192,U32.add(y,8),38,ink(),bg)
  text(line1,second,192,U32.add(y,32),38,muted(),bg)

def draw_rows(+fuel: Nat,+c: Canvas,rows: List<&2,String>,+at: U32,+selected: U32) -> Canvas:
  match fuel rows:
    case 1n+n +row <> rest:
      +y = U32.add(G.list_y(),U32.mul(at,G.list_pitch()))
      +bg = Bool.pick(U32,U32.is_eq(at,selected),selected_bg(),panel())
      base = box(c,184,y,320,56,bg)
      second = card_draw(base,card(row),y,bg)
      draw_rows(n,second,rest,U32.add(at,1),selected)
    case _ _: c

def list_heading(results: Results,files: Bool) -> String:
  match results:
    case RelatedResults{page,count,more,previous}: "Related captures"
    case SettingsResults{offset,total,automatic,ready}: "Registered folders"
    case _: Bool.pick(String,files,"Up to parent folder","Sessions")

def automatic_label(results: Results,fallback: String) -> String:
  match results:
    case SettingsResults{offset,total,automatic,ready}: automatic
    case _: fallback

def side_label(settings: Bool,index: U32,files: Bool) -> String:
  match settings:
    case True{}:
      match index:
        case 0: "Back to history"
        case 1: "Automatic refresh"
        case 2: "Claude"
        case 3: "Codex"
        case 4: "Add folder"
        case 5: "Import file"
        case 6: "Storage"
        case 7: "Reload settings"
        case 8: "Enable selected"
        case 9: "Disable selected"
        case 10: "Every 30 seconds"
        case 11: "Every 2 hours"
        case 12: "Every 4 hours"
        case 13: "Every 8 hours"
        case 14: "Every 24 hours"
        case 15: "Clear input"
        case 16: "Select all"
        case _: "Back to history"
    case False{}:
      match index:
        case 0: Bool.pick(String,files,"History","Repository files")
        case 1: "All providers"
        case 2: "Claude"
        case 3: "Codex"
        case 4: "Search filters"
        case 5: "Tools"
        case 6: "Usage"
        case 7: "Related captures"
        case 8: "Saved versions"
        case 9: "Open latest"
        case 10: "Settings"
        case 11: "Storage"
        case 12: "Rebuild index"
        case 13: "Copy selection"
        case 14: "Paste"
        case 15: "Clear search"
        case 16: "Select all"
        case _: "Back"

def side_active(index: U32,scope: String) -> Bool:
  match index:
    case 1: String.eq(scope,"all")
    case 2: String.eq(scope,"claude")
    case 3: String.eq(scope,"codex")
    case _: False{}

def draw_side(fuel: Nat,c: Canvas,+index: U32,+files: Bool,+settings: Bool,+scope: String) -> Canvas:
  match fuel:
    case 0n: c
    case 1n+n:
      +y = G.sidebar_y(index)
      +bg = Bool.pick(U32,side_active(index,scope) && (Bool.not(settings) || U32.is_ne(index,1)),selected_bg(),rail())
      base = box(c,8,y,160,32,bg)
      label = text(base,side_label(settings,index,files),16,U32.add(y,8),18,ink(),bg)
      draw_side(n,label,U32.add(index,1),files,settings,scope)

def whole_usage(s: State) -> Bool:
  String.starts_with(title(s),"Usage | whole captured session")

def top_label(index: U32,files: Bool,settings: Bool,whole: Bool,automatic: String) -> String:
  match index:
    case 0: Bool.pick(String,files,"Open repository","Refresh")
    case 1: automatic
    case 2: Bool.pick(String,settings,"Add folder","Blame")
    case 3: Bool.pick(String,settings,"Import file","Why")
    case 4: Bool.pick(String,settings,"Enable selected","Export evidence")
    case 5: Bool.pick(String,settings,"Disable selected",Bool.pick(String,whole,"Whole session","Previous page"))
    case _: Bool.pick(String,settings,"Reload settings",Bool.pick(String,whole,"All retained records","Next page"))

def draw_top(fuel: Nat,c: Canvas,+index: U32,+files: Bool,+settings: Bool,+whole: Bool,+automatic: String) -> Canvas:
  match fuel:
    case 0n: c
    case 1n+n:
      +x = G.top_x(index)
      +w = G.top_width(index)
      base = box(c,x,80,w,32,panel())
      label = text(base,top_label(index,files,settings,whole,automatic),U32.add(x,8),88,U32.sub(U32.div(w,8),2),accent(),panel())
      draw_top(n,label,U32.add(index,1),files,settings,whole,automatic)

def draw_status(modal: Bool,+s: State,c: Canvas) -> Canvas:
  match modal:
    case False{}: c
    case True{}:
      State{content,Input{selected,scroll,Edit{focus,+caret,+anchor,drag,viewport},command,shift},image,dirty} = s
      base = box(c,G.list_end(),112,896,744,paper())
      label = text(base,"Current status · Scroll to read · Esc to return",G.reader_x(),128,64,accent(),paper())
      copy = text(label,"Copy and close",1128,128,19,accent(),paper())
      close = text(copy,"Close",1304,128,11,accent(),paper())
      draw_reader(U32.to_nat(G.reader_rows()),close,List.drop(&2,Line,wrap(status_text(s)),U32.to_nat(U32.min(viewport,minus(U32.from_nat(List.length(&2,Line,wrap(status_text(s)))),G.reader_rows())))),U32.div(G.reader_y(),G.cell()),0,0)

def capture_hint(suspended: Bool) -> String:
  Bool.pick(String,suspended,"Capture suspended","")

def draw_capture_hint(c: Canvas,+suspended: Bool) -> Canvas:
  first = text(c,capture_hint(suspended),824,80,26,muted(),rail())
  text(first,Bool.pick(String,suspended,"Back to History",""),824,96,26,muted(),rail())

def draw_automatic_capture(+s: State,automatic: String,suspended: Bool) -> Image:
  State{Content{+q,rows,reader,lines,title,status,+scope,+results,+files},Input{+selected,scroll,Edit{+focus,+caret,+anchor,drag,viewport},command,shift},image,dirty} = s
  base = box(Flat{paper()},0,0,1408,112,rail())
  side = box(base,0,112,176,744,rail())
  list = box(side,176,112,336,744,panel())
  foot = box(list,0,G.footer_y(),1408,40,rail())
  brand = text(foot,"JUICE BEND",16,24,18,accent(),rail())
  tagline = text(brand,"Your captured work",16,48,18,muted(),rail())
  input_label = text(tagline,Bool.pick(String,is_settings(s),"Source file or folder path",Bool.pick(String,files,"Repository folder path","Search captured history")),192,8,60,muted(),rail())
  query_bg = box(input_label,192,24,1192,40,paper())
  query = draw_line(U32.to_nat(G.query_columns()),query_bg,String.append(String.drop(q,U32.to_nat(query_offset(s)))," "),U32.div(G.query_x(),G.cell()),U32.div(G.query_y(),G.cell()),query_offset(s),Bool.pick(U32,U32.is_eq(focus,0),U32.min(caret,anchor),0),Bool.pick(U32,U32.is_eq(focus,0),Bool.pick(U32,U32.is_eq(caret,anchor),U32.add(caret,1),U32.max(caret,anchor)),0))
  top = draw_top(7n,query,0,files,is_settings(s),whole_usage(s),automatic_label(results,automatic))
  capture = draw_capture_hint(top,suspended)
  group1 = text(capture,Bool.pick(String,is_settings(s),"SOURCES","PROVIDERS"),16,160,18,muted(),rail())
  group2 = text(group1,Bool.pick(String,is_settings(s),"FOLDER ACTIONS","CAPTURED EVIDENCE"),16,320,18,muted(),rail())
  group3 = text(group2,Bool.pick(String,is_settings(s),"REFRESH INTERVAL","LIBRARY"),16,536,18,muted(),rail())
  navigation = draw_side(18n,group3,0,files,is_settings(s),scope)
  heading = text(navigation,list_heading(results,files),192,128,38,ink(),panel())
  range = text(heading,result_label(results),192,152,38,muted(),panel())
  prev = text(range,"Previous",192,G.list_pager_y(),16,Bool.pick(U32,result_available(results,False{}),accent(),muted()),panel())
  next = text(prev,"Next",360,G.list_pager_y(),16,Bool.pick(U32,result_available(results,True{}),accent(),muted()),panel())
  title = text(next,title,G.reader_x(),128,56,accent(),paper())
  copy = text(title,"Copy",U32.add(G.text_action_x(0),8),U32.add(G.text_actions_y(),8),10,accent(),paper())
  paste = text(copy,"Paste",U32.add(G.text_action_x(1),8),U32.add(G.text_actions_y(),8),10,accent(),paper())
  clear = text(paste,"Clear",U32.add(G.text_action_x(2),8),U32.add(G.text_actions_y(),8),10,accent(),paper())
  all = text(clear,"Select all",U32.add(G.text_action_x(3),8),U32.add(G.text_actions_y(),8),11,accent(),paper())
  +offset = minus(selected,U32.sub(G.list_rows(),1))
  items = draw_rows(U32.to_nat(G.list_rows()),all,List.drop(&2,String,rows,U32.to_nat(offset)),0,minus(selected,offset))
  body = draw_reader(U32.to_nat(G.reader_rows()),items,List.drop(&2,Line,lines,U32.to_nat(scroll)),U32.div(G.reader_y(),G.cell()),Bool.pick(U32,U32.is_eq(focus,2),U32.min(caret,anchor),0),Bool.pick(U32,U32.is_eq(focus,2),U32.max(caret,anchor),0))
  +summary = String.join(String.lines(status)," ")
  status1 = text(body,String.take(summary,174n),8,G.footer_y(),174,ink(),rail())
  status2 = text(status1,String.take(String.drop(summary,174n),148n),8,U32.add(G.footer_y(),16),148,ink(),rail())
  hint = text(status2,"Click status for details",1200,U32.add(G.footer_y(),16),25,accent(),rail())
  canvas.image(draw_status(U32.is_ge(focus,3),s,hint))

def view_dirty_capture(+s: State,+dirty: Bool,automatic: String,suspended: Bool) -> State & Image:
  State{content,input,+old,clean} = s
  match dirty:
    case True{}:
      +next = draw_automatic_capture(s,automatic,suspended)
      (State{content,input,next,False{}},next)
    case False{}: (State{content,input,old,False{}},old)

def draw_automatic(s: State,automatic: String) -> Image:
  draw_automatic_capture(s,automatic,False{})

def view_dirty_automatic(s: State,dirty: Bool,automatic: String) -> State & Image:
  view_dirty_capture(s,dirty,automatic,False{})

def view_capture(s: State,automatic: String,suspended: Bool) -> State & Image:
  State{content,input,image,dirty} = s
  view_dirty_capture(State{content,input,image,False{}},dirty,automatic,suspended)

def draw(s: State) -> Image:
  draw_automatic(s,"Pause")

def view_dirty(s: State,dirty: Bool) -> State & Image:
  view_dirty_automatic(s,dirty,"Pause")

def view_automatic(s: State,automatic: String) -> State & Image:
  State{content,input,image,dirty} = s
  view_dirty_automatic(State{content,input,image,False{}},dirty,automatic)

def view(s: State) -> State & Image:
  view_automatic(s,"Pause")

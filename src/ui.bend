# Native Juice Bend UI. Layout, text editing, selection and hit testing are Bend.
# Coordinates here are 16px cells; Unicode offsets count decoded Char values.
import Base
import ./font.bend as Font

type Line is Data:
  Line{start: U32, text: String}

type Content is Data:
  Content{query: String, rows: List<&2, String>, reader: String,
    lines: List<&2, Line>, title: String, status: String, scope: String, results: Results}

type Results is Data:
  Results{offset: U32, count: U32, has_more: Bool, ready: Bool}

type Edit is Data:
  Edit{focus: U32, caret: U32, anchor: U32, dragging: Bool, viewport: U32}

type Input is Data:
  Input{selected: U32, scroll: U32, edit: Edit, command: Bool, shift: Bool}

type State is Data:
  State{content: Content, input: Input, image: Image, dirty: Bool}

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
  Rebuild{}
  Versions{}
  OpenLatest{}
  Blame{}
  Filter{}
  Refresh{}
  Pause{}
  Settings{}
  Storage{}
  Previous{}
  Next{}
  ListPrevious{}
  ListNext{}
  Quit{}

# A compact application-specific cell canvas. Flat areas remain one Image node.
type Canvas is Data:
  Flat{color: U32}
  Tile{bits: Font.Glyph, foreground: U32, background: U32}
  Four{tl: Canvas, tr: Canvas, bl: Canvas, br: Canvas}

def length(+s: String) -> U32:
  U32.from_nat(String.length(s))

def minus(+a: U32, +b: U32) -> U32:
  Bool.pick(U32, U32.is_gt(a, b), U32.sub(a, b), 0)

def span(+s: String, +a: U32, +b: U32) -> String:
  String.take(String.drop(s, U32.to_nat(U32.min(a, b))),
    U32.to_nat(minus(U32.max(a, b), U32.min(a, b))))

def lines.go(+s: String, +at: U32, +start: U32,
  +col: U32, +acc: String, done: List<&2, Line>) -> List<&2, Line>:
  match s col:
    case SNil{} _:
      List.reverse(&2, Line, Line{start, String.reverse(acc)} <> done)
    case SCon{Chr{10}, tail} _:
      lines.go(tail, U32.add(at, 1), U32.add(at, 1), 0, "",
        Line{start, String.reverse(acc)} <> done)
    case SCon{c, tail} 48:
      lines.go(tail, U32.add(at, 1), at, 1, SCon{c, ""},
        Line{start, String.reverse(acc)} <> done)
    case SCon{c, tail} n:
      lines.go(tail, U32.add(at, 1), start, U32.add(n, 1),
        SCon{c, acc}, done)

def wrap(+s: String) -> List<&2, Line>:
  lines.go(s, 0, 0, 0, "", [])

def init() -> State:
  State{Content{"", [], "Choose a captured session to read its owned evidence.",
    wrap("Choose a captured session to read its owned evidence."),
    "Transcript", "Ready. Only explicitly enabled sources are scanned.", "all",Results{0,0,False{},False{}}},
    Input{0, 0, Edit{0, 0, 0, False{}, 0}, False{}, False{}}, Pix{16777215}, True{}}

def query(+s: State) -> String:
  State{Content{q, rows, reader, lines, title, status, scope,+results}, input, image, dirty} = s
  q

def selected(+s: State) -> U32:
  State{content, Input{n, scroll, edit, command, shift}, image, dirty} = s
  n

def scope(+s: State) -> String:
  State{Content{q, rows, reader, lines, title, status, scope,+results}, input, image, dirty} = s
  scope

def reader(+s: State) -> String:
  State{Content{q, rows, reader, lines, title, status, scope,+results}, input, image, dirty} = s
  reader

def set_status(+s: State, +status: String) -> State:
  State{Content{q, rows, reader, lines, title, old, scope,+results}, input, image, dirty} = s
  State{Content{q, rows, reader, lines, title, status, scope,results}, input, image, True{}}

def set_rows(+s: State, rows: List<&2, String>) -> State:
  State{Content{q, old, reader, lines, title, status, scope,results},
    Input{selected, scroll, edit, command, shift}, image, dirty} = s
  State{Content{q, rows, reader, lines, title, status, scope,results},
    Input{0, scroll, edit, command, shift}, image, True{}}

def set_results(+s: State, results: Results) -> State:
  State{Content{q,rows,reader,lines,title,status,scope,old},input,image,dirty} = s
  State{Content{q,rows,reader,lines,title,status,scope,results},input,image,True{}}

def result_label(results: Results) -> String:
  Results{+offset,+count,more,ready} = results
  match count ready:
    case _ False{}:
      "Results not loaded"
    case 0 True{}:
      Bool.pick(String,U32.is_eq(offset,0),"No results","No results after " ++ U32.show(offset))
    case _ True{}:
      U32.show(U32.add(offset,1)) ++ "-" ++ Nat.show(Nat.add(U32.to_nat(offset),U32.to_nat(count))) ++
        Bool.pick(String,more," + more"," / end")

def result_available(results: Results,forward: Bool) -> Bool:
  Results{+offset,count,more,ready} = results
  ready && Bool.pick(Bool,forward,more && U32.is_le(offset,4294967095),U32.is_gt(offset,0))

def result_action_if(+s: State,+forward: Bool,available: Bool) -> State & Action:
  match available:
    case True{}:
      (s,Bool.pick(Action,forward,ListNext{},ListPrevious{}))
    case False{}:
      (s,NoAction{})

def result_action(+s: State,+forward: Bool) -> State & Action:
  State{Content{q,rows,reader,lines,title,status,scope,results},input,image,dirty} = s
  result_action_if(s,forward,result_available(results,forward))

def set_reader(+s: State, +title: String, +reader: String) -> State:
  State{Content{q, rows, old, oldlines, oldtitle, status, scope,results},
    Input{selected, scroll, Edit{+focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  State{Content{q, rows, reader, wrap(reader), title, status, scope,results},
    Input{selected, 0, Edit{focus, Bool.pick(U32,U32.is_eq(focus,0),caret,0),
      Bool.pick(U32,U32.is_eq(focus,0),anchor,0),
      Bool.pick(Bool,U32.is_eq(focus,0),drag,False{}),Bool.pick(U32,U32.is_eq(focus,0),viewport,0)}, command, shift}, image, True{}}

def set_scope(+s: State, +scope: String) -> State:
  State{Content{q, rows, reader, lines, title, status, old,+results}, input, image, dirty} = s
  State{Content{q, rows, reader, lines, title, status, scope,results}, input, image, True{}}

def set_query(+s: State, +q: String) -> State:
  State{Content{old, rows, reader, lines, title, status, scope,results},
    Input{selected, scroll, edit, command, shift}, image, dirty} = s
  +n = length(q)
  State{Content{q, rows, reader, lines, title, status, scope,results},
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
  State{Content{+q, rows, reader, lines, title, status, scope,results},
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
  State{Content{q, rows, reader, lines, title, status, scope,results},
    Input{selected, scroll, Edit{+focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  +n = Bool.pick(U32, U32.is_eq(focus, 0), length(q), length(reader))
  set_edit(s, Edit{Bool.pick(U32, U32.is_eq(focus, 0), 0, 2), n, 0, False{}, 0})

def selection(+s: State) -> String:
  State{Content{q, rows, reader, lines, title, status, scope,results},
    Input{selected, scroll, Edit{+focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  span(Bool.pick(String, U32.is_eq(focus, 0), q, reader), caret, anchor)

def move_caret(+s: State, +right: Bool) -> State:
  State{Content{q, rows, reader, lines, title, status, scope,results},
    Input{selected, scroll, Edit{+focus, +caret, anchor, drag, viewport}, command, +shift}, image, dirty} = s
  +n = Bool.pick(U32, U32.is_eq(focus, 0), length(q), length(reader))
  +pos = Bool.pick(U32, right, U32.min(n, U32.add(caret, 1)), minus(caret, 1))
  set_edit(s, Edit{focus, pos, Bool.pick(U32, shift, anchor, pos), False{}, 0})

def scroll_by(+s: State, +down: Bool, +amount: U32) -> State:
  State{Content{q, rows, reader, +lines, title, status, scope,results},
    Input{selected, +scroll, edit, command, shift}, image, dirty} = s
  +limit = minus(U32.from_nat(List.length(&2, Line, lines)), 42)
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

def reader_at_line(+line: Line, +x: U32) -> U32:
  Line{start, text} = line
  U32.add(start, U32.min(length(text), minus(U32.div(x, 16), 38)))

def reader_at(+s: State, +x: U32, +y: U32) -> U32:
  State{Content{q, rows, reader, +lines, title, status, scope,results},
    Input{selected, scroll, edit, command, shift}, image, dirty} = s
  reader_at_line(line_at(lines, U32.min(minus(U32.from_nat(List.length(&2, Line, lines)), 1), U32.add(scroll, minus(U32.div(y, 16), 10)))), x)

def query_offset(s: State) -> U32:
  State{content, Input{selected, scroll, Edit{focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  Bool.pick(U32, U32.is_eq(focus, 0), Bool.pick(U32,drag,viewport,minus(caret,70)), 0)

def query_at(+s: State, col: U32) -> U32:
  U32.min(length(query(s)), U32.add(query_offset(s), U32.min(72, minus(col, 14))))

def drag_if(+s: State, +x: U32, +y: U32, +focus: U32, +anchor: U32, +dragging: Bool) -> State & Action:
  match dragging:
    case True{}:
      (set_edit(s, Edit{focus, Bool.pick(U32, U32.is_eq(focus, 0), query_at(s, U32.div(x, 16)), reader_at(s, x, y)), anchor, True{}, query_offset(s)}), NoAction{})
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
  State{Content{q, rows, reader, lines, title, status, scope,results},
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

def wheel(s: State, +x: U32, down: Bool) -> State & Action:
  wheel_in(s, down, (x >= 192 && x < 576 : U32))

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
      (scroll_by(s, False{}, 38), NoAction{})
    case 63277 _:
      (scroll_by(s, True{}, 38), NoAction{})
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

def sidebar_action(+s: State, +row: U32) -> State & Action:
  match row:
    case 11:
      (set_scope(s, "all"), Scope{"all"})
    case 14:
      (set_scope(s, "claude"), Scope{"claude"})
    case 17:
      (set_scope(s, "codex"), Scope{"codex"})
    case 20:
      (s, Filter{})
    case 23:
      (s, Settings{})
    case 25:
      (s, Storage{})
    case 30:
      copy_action(s,String.is_empty(selection(s)))
    case 33:
      paste_query(s)
    case 36:
      (set_query(s,""),Search{})
    case 39:
      (select_all(s),NoAction{})
    case 42:
      (s,Usage{})
    case 45:
      (s,Rebuild{})
    case 48:
      (s,Versions{})
    case 51:
      (s,OpenLatest{})
    case _:
      (s, NoAction{})

def list_row_click(+s: State,+index: U32,valid: Bool) -> State & Action:
  match valid:
    case True{}:
      (set_position(set_edit(s,Edit{1,0,0,False{},0}),index,0),Open{index})
    case False{}:
      (s,NoAction{})

def list_click(+s: State,+col: U32,+row: U32) -> State & Action:
  State{Content{q,rows,reader,lines,title,status,scope,results},input,image,dirty} = s
  match row:
    case 52:
      result_action(s,U32.is_ge(col,24))
    case _:
      +index = U32.add(minus(selected(s),13),U32.div(minus(row,10),3))
      list_row_click(s,index,U32.is_ge(row,10) && U32.is_lt(row,52) &&
        U32.is_lt(index,U32.from_nat(List.length(&2,String,rows))))

def mouse_body(+s: State, +x: U32, +y: U32, +col: U32, +row: U32,
  +sidebar: Bool, +list: Bool) -> State & Action:
  match sidebar list:
    case True{} _:
      sidebar_action(s, row)
    case False{} True{}:
      list_click(s,col,row)
    case False{} False{}:
      +pos = reader_at(s, x, y)
      (set_edit(s, Edit{2, pos, pos, True{}, 0}), NoAction{})

def top_action(+s: State, +group: U32) -> State & Action:
  match group:
    case 0:
      (s, Refresh{})
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

def query_click(+s: State, col: U32) -> State & Action:
  +pos = query_at(s, col)
  (set_edit(s, Edit{0, pos, pos, True{}, query_offset(s)}), NoAction{})

def mouse_top(+s: State, +col: U32, +row: U32) -> State & Action:
  match row:
    case 3:
      query_click(s, col)
    case 4:
      query_click(s, col)
    case 5:
      query_click(s, col)
    case 6:
      top_action(s, U32.div(col, 12))
    case _:
      (s, NoAction{})

def mouse_toolbar(+s: State, +x: U32, +y: U32, +col: U32, +row: U32, +toolbar: Bool) -> State & Action:
  match toolbar:
    case True{}:
      mouse_top(s, col, row)
    case False{}:
      mouse_body(s, x, y, col, row, (col < 12 : U32), (col < 36 : U32))

def mouse_zone(+s: State, +x: U32, +y: U32, +col: U32, +row: U32) -> State & Action:
  mouse_toolbar(s, x, y, col, row, (row < 8 : U32))

def mouse(+s: State, +x: U32, +y: U32, +down: Bool) -> State & Action:
  State{content, Input{selected, scroll, Edit{focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  match down:
    case False{}:
      (set_edit(s, Edit{focus, caret, anchor, False{}, 0}), NoAction{})
    case True{}:
      mouse_zone(s, x, y, U32.div(x, 16), U32.div(y, 16))

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

def event(+e: Event, +s: State) -> State & Action:
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

def write(+count: Nat, +c: Canvas, +text: String, +x: U32, +y: U32, +foreground: U32, +background: U32) -> Canvas:
  match count text:
    case 1n+n SCon{Chr{code}, rest}:
      write(n, canvas.set(7n, c, x, y, Tile{Font.glyph(code), foreground, background}), rest, U32.add(x, 1), y, foreground, background)
    case _ _:
      c

def fill.row(+width: Nat, +c: Canvas, +x: U32, +y: U32, +color: U32) -> Canvas:
  match width:
    case 0n:
      c
    case 1n+n:
      fill.row(n, canvas.set(7n, c, x, y, Flat{color}), U32.add(x, 1), y, color)

def fill(+rows: Nat, +c: Canvas, +x: U32, +y: U32, +width: Nat, +color: U32) -> Canvas:
  match rows:
    case 0n:
      c
    case 1n+n:
      fill(n, fill.row(width, c, x, y, color), x, U32.add(y, 1), width, color)

def glyph.draw(+d: Nat, +x: U32, +y: U32, +bits: Font.Glyph, +fg: U32, +bg: U32) -> Image:
  match d:
    case 0n:
      Pix{Bool.pick(U32, Font.pixel(bits, x, y), fg, bg)}
    case 1n+ +p:
      +h = U32.shln(1, p)
      Qua{glyph.draw(p, x, y, bits, fg, bg), glyph.draw(p, U32.add(x, h), y, bits, fg, bg),
        glyph.draw(p, x, U32.add(y, h), bits, fg, bg), glyph.draw(p, U32.add(x, h), U32.add(y, h), bits, fg, bg)}

def canvas.image(+c: Canvas) -> Image:
  match c:
    case Flat{color}:
      Pix{color}
    case Tile{bits, fg, bg}:
      glyph.draw(3n, 0, 0, bits, fg, bg)
    case Four{tl, tr, bl, br}:
      Qua{canvas.image(tl), canvas.image(tr), canvas.image(bl), canvas.image(br)}

def draw_rows(+fuel: Nat, +c: Canvas, rows: List<&2, String>, +at: U32, +selected: U32) -> Canvas:
  match fuel rows:
    case 1n+n +row <> rest:
      +y = U32.add(10, U32.mul(at, 3))
      +bg = Bool.pick(U32, U32.is_eq(at, selected), 14474716, 16119544)
      base = fill(2n, c, 12, y, 24n, bg)
      first = write(22n, base, String.take(row, 22n), 13, y, 2700600, bg)
      second = write(22n, first, String.drop(row, 22n), 13, U32.add(y, 1), 6516081, bg)
      draw_rows(n, second, rest, U32.add(at, 1), selected)
    case _ _:
      c

def draw_line(+count: Nat, +c: Canvas, +text: String, +x: U32, +y: U32, +at: U32, +low: U32, +high: U32) -> Canvas:
  match count text:
    case 1n+n SCon{Chr{code}, rest}:
      +bg = Bool.pick(U32, (at >= low && at < high : U32), 11526399, 16777215)
      next = canvas.set(7n, c, x, y, Tile{Font.glyph(code), 2700600, bg})
      draw_line(n, next, rest, U32.add(x, 1), y, U32.add(at, 1), low, high)
    case _ _:
      c

def draw_reader(+fuel: Nat, +c: Canvas, lines: List<&2, Line>, +y: U32, +low: U32, +high: U32) -> Canvas:
  match fuel lines:
    case 1n+n Line{start, text} <> rest:
      draw_reader(n, draw_line(48n, c, text, 38, y, start, low, high), rest, U32.add(y, 1), low, high)
    case _ _:
      c

def draw_query(+c: Canvas, +text: String, +x: U32, +y: U32, +at: U32,
  +low: U32, +high: U32, +count: Nat) -> Canvas:
  draw_line(count, c, text, x, y, at, low, high)

def draw(+s: State) -> Image:
  State{Content{+q, rows, reader, lines, title, status, +scope,+results},
    Input{+selected, scroll, Edit{+focus, +caret, +anchor, drag, viewport}, command, shift}, image, dirty} = s
  base = fill(8n, Flat{16777215}, 0, 0, 88n, 15988716)
  side = fill(46n, base, 0, 8, 12n, 15396591)
  list = fill(46n, side, 12, 8, 24n, 16119544)
  foot = fill(2n, list, 0, 54, 88n, 15396591)
  a = write(16n, foot, "JUICE BEND", 1, 1, 3960107, 15988716)
  b = write(60n, a, "Captured history / lexical search / evidence", 18, 1, 6516081, 15988716)
  c = write(10n, b, "Search", 1, 4, 6516081, 15988716)
  d = fill(3n, c, 13, 3, 74n, 16777215)
  e = draw_query(d, String.append(String.drop(q, U32.to_nat(query_offset(s))), " "), 14, 4, query_offset(s), Bool.pick(U32, U32.is_eq(focus, 0), U32.min(caret, anchor), 0),
    Bool.pick(U32, U32.is_eq(focus, 0), Bool.pick(U32, U32.is_eq(caret, anchor), U32.add(caret, 1), U32.max(caret, anchor)), 0), 72n)
  f = write(10n, e, "Refresh", 1, 6, 3960107, 15988716)
  g = write(10n, f, "Pause", 13, 6, 3960107, 15988716)
  blame = write(10n, g, "Blame", 25, 6, 3960107, 15988716)
  h = write(10n, blame, "Why", 38, 6, 3960107, 15988716)
  i = write(10n, h, "Export", 49, 6, 3960107, 15988716)
  j = write(10n, i, "Prev text", 61, 6, 3960107, 15988716)
  k = write(10n, j, "Next text", 73, 6, 3960107, 15988716)
  l = write(10n, k, "SOURCES", 1, 9, 6516081, 15396591)
  m = write(10n, l, "All", 1, 11, 3960107, 15396591)
  n = write(10n, m, "Claude", 1, 14, 3960107, 15396591)
  o = write(10n, n, "Codex", 1, 17, 3960107, 15396591)
  filters = write(10n, o, "Filter", 1, 20, 3960107, 15396591)
  p = write(10n, filters, "Settings", 1, 23, 3960107, 15396591)
  storage = write(10n,p,"Storage",1,25,3960107,15396591)
  q2 = write(10n, storage, String.append("Scope: ", scope), 1, 27, 6516081, 15396591)
  copy = write(10n, q2, "Copy text", 1, 30, 3960107, 15396591)
  paste = write(10n, copy, "Paste", 1, 33, 3960107, 15396591)
  clear = write(10n, paste, "Clear", 1, 36, 3960107, 15396591)
  select = write(10n, clear, "Select all", 1, 39, 3960107, 15396591)
  usage = write(10n, select, "Usage", 1, 42, 3960107, 15396591)
  rebuild = write(10n, usage, "Rebuild", 1, 45, 3960107, 15396591)
  versions = write(10n,rebuild,"Versions",1,48,3960107,15396591)
  latest = write(11n,versions,"Open latest",1,51,3960107,15396591)
  r = write(23n, latest, "SESSIONS / RESULTS", 13, 8, 6516081, 16119544)
  range = write(22n,r,result_label(results),13,9,6516081,16119544)
  previous = write(10n,range,"Prev list",13,52,Bool.pick(U32,result_available(results,False{}),3960107,10066329),16119544)
  next = write(10n,previous,"Next list",25,52,Bool.pick(U32,result_available(results,True{}),3960107,10066329),16119544)
  t = write(48n, next, title, 38, 8, 3960107, 16777215)
  u = draw_rows(14n, t, List.drop(&2, String, rows, U32.to_nat(minus(selected, 13))), 0, minus(selected, minus(selected, 13)))
  v = draw_reader(42n, u, List.drop(&2, Line, lines, U32.to_nat(scroll)), 10, Bool.pick(U32, U32.is_eq(focus, 2), U32.min(caret, anchor), 0), Bool.pick(U32, U32.is_eq(focus, 2), U32.max(caret, anchor), 0))
  w = write(86n, v, status, 1, 54, 3960107, 15396591)
  z = write(86n, w, "Cmd+F search | arrows navigate | drag select | Cmd+C copy | Cmd+E export", 1, 55, 6516081, 15396591)
  canvas.image(z)

def view_dirty(+s: State, +dirty: Bool) -> State & Image:
  State{content, input, +old, clean} = s
  match dirty:
    case True{}:
      +next = draw(s)
      (State{content, input, next, False{}}, next)
    case False{}:
      (State{content, input, old, False{}}, old)

def view(s: State) -> State & Image:
  State{content, input, image, dirty} = s
  view_dirty(State{content, input, image, False{}}, dirty)

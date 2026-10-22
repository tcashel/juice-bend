# Native Juice Bend UI. Layout, text editing, selection and hit testing are Bend.
# Coordinates use an 8px canvas grid; Unicode offsets count decoded Char values.
import Base
import ./font.bend as Font
import ./ui_geometry.bend as G
import ./ui_palette.bend as Palette
import ./bend_ui/canvas.bend as C
import ./bend_ui/label.bend as Chrome
import ./bend_ui/button.bend as Button
import ./bend_ui/region.bend as Region
import ./reader_document.bend as ReaderDoc
import ./reader_projection.bend as Projection
import ./reader_cards.bend as ReaderCards
import ./bend_ui/text_line.bend as Prose
import ./library_usage_view_types.bend as LibraryView
import ./library_usage_summary.bend as LibrarySummary

type Line is Data:
  Line{start: U32, text: String}

type Content is Data:
  Content{query: String, rows: List<&2, String>, reader: String,
    lines: List<&2, Line>, title: String, status: String, scope: String, results: Results, files: Bool, cards: List<&2,ReaderCards.Model>}

type Results is Data:
  Results{offset: U32, count: U32, has_more: Bool, ready: Bool}
  LibraryUsageResults{phase: U32,count: U32,summary: List<&2,LibraryView.Summary>}
  ChildResults{phase: U32,count: U32,has_more: Bool,has_previous: Bool}
  RelatedResults{page: U32, count: U32, has_more: Bool, has_previous: Bool}
  SettingsResults{offset: U32,total: U32,automatic: String,ready: Bool}
  BriefResults{phase: U32}
  AttachmentResults{phase: U32,exportable: Bool,previous: Bool,next: Bool}
  AttachmentCaptureResults{phase: U32,exportable: Bool,previous: Bool,next: Bool,capturable: Bool,previewable: Bool}
  AttachmentFoldersResults{phase: U32,choose: Bool,enable: Bool,disable: Bool,previous: Bool,next: Bool}
  QuotaResults{phase: U32,loaded: Bool,enabled: Bool,view: U32,offset: U32,count: U32,more: Bool}

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
  CopyStatus{text: String}
  Paste{}
  Export{}
  WholeExport{}
  ContainerExport{}
  AtifExport{}
  Why{}
  Usage{}
  LibraryUsage{}
  ChildResultsOpen{}
  Tools{}
  Related{}
  Attachments{}
  AttachmentExport{}
  AttachmentPreview{}
  AttachmentFolders{}
  AttachmentCapture{}
  AttachmentFolderAdd{}
  AttachmentFolderEnable{}
  AttachmentFolderDisable{}
  AttachmentFolderUse{}
  Back{}
  Rebuild{}
  Brief{}
  BriefPrepare{}
  BriefCopy{}
  BriefExport{}
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
  Connections{}
  QuotaEnable{}
  QuotaDisconnect{}
  QuotaHistory{}
  QuotaSetup{}
  QuotaCopySetup{}
  Storage{}
  Files{}
  RepoOpen{}
  RepoParent{}
  Previous{}
  Next{}
  ListPrevious{}
  ListNext{}
  Quit{}

def length(+s: String) -> U32:
  U32.from_nat(String.length(s))

def minus(+a: U32, +b: U32) -> U32:
  Bool.pick(U32, U32.is_gt(a, b), U32.sub(a, b), 0)

def span(+s: String, +a: U32, +b: U32) -> String:
  String.take(String.drop(s, U32.to_nat(U32.min(a, b))),
    U32.to_nat(minus(U32.max(a, b), U32.min(a, b))))

# Soft breaks retain their whitespace in the preceding line. Every displayed
# piece is an exact source slice, so pointer offsets and copy stay canonical.
def wrap_space(c: Char) -> Bool:
  Chr{+code} = c
  U32.is_eq(code,32) || U32.is_eq(code,9)

def lines.go(+s: String,+at: U32,+start: U32,+col: U32,+acc: String,done: List<&2,Line>,full: Bool,+word: U32) -> List<&2,Line>:
  match s full:
    case SNil{} _: List.reverse(&2,Line,Line{start,String.reverse(acc)} <> done)
    case SCon{Chr{10},tail} _:
      lines.go(tail,U32.add(at,1),U32.add(at,1),0,"",Line{start,String.reverse(acc)} <> done,False{},0)
    case SCon{+c,tail} True{}:
      +cut = Bool.pick(U32,wrap_space(c) || U32.is_eq(word,0),col,word)
      +text = String.reverse(acc)
      +next_col = U32.add(U32.sub(col,cut),1)
      lines.go(tail,U32.add(at,1),U32.add(start,cut),next_col,
        SCon{c,String.reverse(String.drop(text,U32.to_nat(cut)))},
        Line{start,String.take(text,U32.to_nat(cut))} <> done,
        U32.is_eq(next_col,G.reader_columns()),Bool.pick(U32,wrap_space(c),next_col,0))
    case SCon{+c,tail} False{}:
      lines.go(tail,U32.add(at,1),start,U32.add(col,1),SCon{c,acc},done,
        U32.is_eq(U32.add(col,1),G.reader_columns()),Bool.pick(U32,wrap_space(c),U32.add(col,1),word))

def wrap(+s: String) -> List<&2, Line>:
  lines.go(s, 0, 0, 0, "", [],False{},0)

def init() -> State:
  State{Content{"", [], "Choose a captured session to read its owned evidence.",
    wrap("Choose a captured session to read its owned evidence."),
    "Transcript", "Ready. Only explicitly enabled sources are scanned.", "all",Results{0,0,False{},False{}},False{}, []},
    Input{0, 0, Edit{0, 0, 0, False{}, 0}, False{}, False{}}, Pix{16777215}, True{}}

def bookmark(state: State) -> Bookmark:
  State{content,input,image,dirty} = state
  Bookmark{content,input}

def bookmark_cards(cards: List<&2,ReaderCards.Model>) -> List<&2,ReaderCards.Model>:
  match cards:
    case model <> []: [ReaderCards.stop_drag(model)]
    case _: []

def bookmark_content(content: Content) -> Content:
  Content{q,rows,reader,lines,title,status,scope,results,files,cards} = content
  Content{q,rows,reader,lines,title,status,scope,results,files,bookmark_cards(cards)}

def restore(state: State,bookmark: Bookmark) -> State:
  State{old,oldinput,image,dirty} = state
  Bookmark{content,Input{selected,scroll,Edit{focus,caret,anchor,drag,viewport},command,shift}} = bookmark
  State{bookmark_content(content),Input{selected,scroll,Edit{focus,caret,anchor,False{},viewport},False{},False{}},image,True{}}

def bookmark_selected(bookmark: Bookmark,selected: U32) -> Bookmark:
  Bookmark{content,Input{old,scroll,edit,command,shift}} = bookmark
  Bookmark{content,Input{selected,scroll,edit,command,shift}}

def is_files(s: State) -> Bool:
  State{Content{q,rows,reader,lines,title,status,scope,results,+files,cards},input,image,dirty} = s
  files

def set_files(s: State,files: Bool) -> State:
  State{Content{q,rows,reader,lines,title,status,scope,results,old,cards},input,image,dirty} = s
  State{Content{q,rows,reader,lines,title,status,scope,results,files,cards},input,image,True{}}

def is_settings(s: State) -> Bool:
  State{Content{q,rows,reader,lines,title,status,scope,results,files,cards},input,image,dirty} = s
  match results:
    case SettingsResults{+offset,+total,automatic,ready}: True{}
    case _: False{}

def is_brief(+s: State) -> Bool:
  State{Content{_,_,_,_,_,_,_,results,_,_},_,_,_} = s
  match results:
    case BriefResults{_}: True{}
    case _: False{}

def is_quota(s: State) -> Bool:
  State{Content{_,_,_,_,_,_,_,results,_,_},_,_,_} = s
  match results:
    case QuotaResults{_,_,_,_,_,_,_}: True{}
    case _: False{}

def is_attachments(s: State) -> Bool:
  State{Content{_,_,_,_,_,_,_,results,_,_},_,_,_} = s
  match results:
    case AttachmentResults{_,_,_,_}: True{}
    case AttachmentCaptureResults{_,_,_,_,_,_}: True{}
    case _: False{}

def library_phase(s: State) -> U32:
  State{Content{_,_,_,_,_,_,_,results,_,_},_,_,_} = s
  match results:
    case LibraryUsageResults{phase,_,_}: phase
    case _: 0

def is_library_usage(s: State) -> Bool:
  U32.is_ne(library_phase(s),0)

def library_summary(s: State) -> Maybe<&2,LibraryView.Summary>:
  State{Content{_,_,_,_,_,_,_,results,_,_},_,_,_} = s
  match results:
    case LibraryUsageResults{2,_,[value]}: Some{value}
    case _: None{}

def library_summary_overview(value: Maybe<&2,LibraryView.Summary>) -> Bool:
  match value:
    case Some{LibraryView.Summary{_,_,_,_,report}}: Bool.not(report)
    case _: False{}

def library_overview(s: State) -> Bool:
  library_summary_overview(library_summary(s))

def library_has_summary(s: State) -> Bool:
  Maybe.is_some(&2,LibraryView.Summary,library_summary(s))

def is_attachment_folders(s: State) -> Bool:
  State{Content{_,_,_,_,_,_,_,results,_,_},_,_,_} = s
  match results:
    case AttachmentFoldersResults{_,_,_,_,_,_}: True{}
    case _: False{}

def child_entry_visible(s: State) -> Bool:
  State{Content{_,_,_,_,+title,_,_,results,files,_},_,_,_} = s
  match results:
    case Results{_,_,_,_}:
      Bool.not(files) && (String.starts_with(title,"Transcript") || String.starts_with(title,"Tools") || String.starts_with(title,"Captured transcript") || String.starts_with(title,"claude | snapshot "))
    case _: False{}

def is_children(s: State) -> Bool:
  State{Content{_,_,_,_,_,_,_,results,_,_},_,_,_} = s
  match results:
    case ChildResults{_,_,_,_}: True{}
    case _: False{}

# Presentation context only. The coordinator still admits an actual capture
# independently before creating an attachment request.
def attachment_entry_visible(+s: State) -> Bool:
  Bool.not(is_children(s) || is_library_usage(s) || is_settings(s) || is_quota(s) || is_brief(s) || is_attachments(s) || is_attachment_folders(s) || is_files(s))

def reader_title_columns(+s: State) -> U32:
  Bool.pick(U32,attachment_entry_visible(s),G.reader_title_columns(),
    U32.sub(U32.div(U32.sub(G.text_actions_x(),G.reader_x()),G.cell()),1))

# These gates are shared by drawing and hit testing. Export eligibility comes
# from the verified selection model; presentation alone never reads a source.
def attachment_control(index: U32,phase: U32,exportable: Bool,previous: Bool,next: Bool) -> Bool:
  match index:
    case 0: True{}
    case 1: U32.is_eq(phase,2) && previous
    case 2: U32.is_eq(phase,2) && next
    case 3: U32.is_eq(phase,2) && exportable
    case 4: True{}
    case _: False{}

def external_attachment_control(index: U32,+phase: U32,exportable: Bool,previous: Bool,next: Bool,capturable: Bool,previewable: Bool) -> Bool:
  match index:
    case 5: U32.is_eq(phase,2)
    case 6: U32.is_eq(phase,2) && capturable
    case 7: U32.is_eq(phase,2) && previewable
    case index: attachment_control(index,phase,exportable,previous,next)

def folder_control(index: U32,+phase: U32,choose: Bool,enable: Bool,disable: Bool,previous: Bool,next: Bool) -> Bool:
  match index:
    case 0: True{}
    case 1: U32.is_eq(phase,2) && choose
    case 2: U32.is_eq(phase,2)
    case 3: U32.is_eq(phase,2) && enable
    case 4: U32.is_eq(phase,2) && disable
    case 5: U32.is_ne(phase,3)
    case 6: U32.is_eq(phase,2) && previous
    case 7: U32.is_eq(phase,2) && next
    case _: False{}

def attachment_available(results: Results,index: U32) -> Bool:
  match results:
    case AttachmentResults{phase,+exportable,previous,next}: external_attachment_control(index,phase,exportable,previous,next,False{},exportable)
    case AttachmentCaptureResults{phase,exportable,previous,next,capturable,previewable}: external_attachment_control(index,phase,exportable,previous,next,capturable,previewable)
    case AttachmentFoldersResults{phase,choose,enable,disable,previous,next}: folder_control(index,phase,choose,enable,disable,previous,next)
    case _: False{}

def quota_ready(phase: U32,loaded: Bool) -> Bool:
  U32.is_eq(phase,2) && loaded

# The same presentation gate controls pointer actions and their muted paint.
# Only an acknowledged local state can authorize enable/disconnect/setup.
def quota_control(index: U32,+phase: U32,loaded: Bool,+enabled: Bool,view: U32) -> Bool:
  match index:
    case 0: True{}
    case 1: U32.is_le(phase,3) && U32.is_ne(phase,1)
    case 2: quota_ready(phase,loaded) && Bool.not(enabled)
    case 3: quota_ready(phase,loaded) && enabled
    case 4: quota_ready(phase,loaded)
    case 5: quota_ready(phase,loaded) && enabled
    case 6: quota_ready(phase,loaded) && enabled && U32.is_eq(view,2)
    case _: False{}

def quota_available(results: Results,index: U32) -> Bool:
  match results:
    case QuotaResults{phase,loaded,enabled,view,_,_,_}: quota_control(index,phase,loaded,enabled,view)
    case _: False{}

def title(s: State) -> String:
  State{Content{q,rows,reader,lines,title,status,scope,results,+files,cards},input,image,dirty} = s
  title

def focus(s: State) -> U32:
  State{content,Input{selected,scroll,Edit{focus,caret,anchor,drag,viewport},command,shift},image,dirty} = s
  focus

def scroll(s: State) -> U32:
  State{content,Input{selected,scroll,edit,command,shift},image,dirty} = s
  scroll

def query(+s: State) -> String:
  State{Content{q, rows, reader, lines, title, status, scope,+results,+files,cards}, input, image, dirty} = s
  q

def selected(+s: State) -> U32:
  State{content, Input{n, scroll, edit, command, shift}, image, dirty} = s
  n

def scope(+s: State) -> String:
  State{Content{q, rows, reader, lines, title, status, scope,+results,+files,cards}, input, image, dirty} = s
  scope

def reader(+s: State) -> String:
  State{Content{q, rows, reader, lines, title, status, scope,+results,+files,cards}, input, image, dirty} = s
  reader

# Structured reader state is boxed in Content so navigation bookmarks carry
# immutable source, folds, visible mapping and selection as one accepted view.
def card_model(s: State) -> Maybe<&2,ReaderCards.Model>:
  State{Content{_,_,_,_,_,_,_,_,_,cards},_,_,_} = s
  match cards:
    case model <> []: Some{model}
    case _: None{}

def card_models_sync(edit: Edit,cards: List<&2,ReaderCards.Model>) -> List<&2,ReaderCards.Model>:
  Edit{focus,caret,anchor,drag,_} = edit
  match cards:
    case +model <> []:
      [Bool.pick(ReaderCards.Model,U32.is_eq(focus,2),ReaderCards.sync(model,anchor,caret,drag),ReaderCards.clear_focus(model))]
    case _: []

def content_sync(content: Content,edit: Edit) -> Content:
  Content{q,rows,reader,lines,title,status,scope,results,files,cards} = content
  Content{q,rows,reader,lines,title,status,scope,results,files,card_models_sync(edit,cards)}

def card_replace(s: State,+model: ReaderCards.Model) -> State:
  State{Content{q,rows,_,_,title,status,scope,results,files,_},input,image,_} = s
  +body = ReaderCards.text(model)
  State{Content{q,rows,body,wrap(body),title,status,scope,results,files,[model]},input,image,True{}}

def card_models_clear(cards: List<&2,ReaderCards.Model>) -> List<&2,ReaderCards.Model>:
  match cards:
    case model <> []: [ReaderCards.clear_focus(model)]
    case _: []

def card_clear(s: State) -> State:
  State{Content{q,rows,reader,lines,title,status,scope,results,files,cards},input,image,dirty} = s
  State{Content{q,rows,reader,lines,title,status,scope,results,files,card_models_clear(cards)},input,image,dirty}

def reader_count_mode(value: Maybe<&2,ReaderCards.Model>,fallback: String) -> U32:
  match value:
    case Some{model}: ReaderCards.count(model)
    case None{}: length(fallback)

def reader_count(+s: State) -> U32:
  reader_count_mode(card_model(s),reader(s))

def reader_row_count_mode(value: Maybe<&2,ReaderCards.Model>,fallback: List<&2,Line>) -> U32:
  match value:
    case Some{model}: ReaderCards.row_count(model)
    case None{}: U32.from_nat(List.length(&2,Line,fallback))

def reader_row_count(+s: State) -> U32:
  State{Content{_,_,_,lines,_,_,_,_,_,_},_,_,_} = s
  reader_row_count_mode(card_model(s),lines)

def card_selection_value(value: Maybe<&2,ReaderCards.Model>,expected: ReaderCards.Token) -> Maybe<&2,Projection.Selection>:
  match value:
    case Some{model}: ReaderCards.selection(model,expected)
    case None{}: None{}

def card_visible_selection(s: State,expected: ReaderCards.Token) -> Maybe<&2,Projection.Selection>:
  card_selection_value(card_model(s),expected)

def set_status(+s: State, +status: String) -> State:
  State{Content{q, rows, reader, lines, title, old, scope,+results,+files,cards}, input, image, dirty} = s
  State{Content{q, rows, reader, lines, title, status, scope,results,files,cards}, input, image, True{}}

def set_rows(+s: State, rows: List<&2, String>) -> State:
  State{Content{q, old, reader, lines, title, status, scope,results,files,cards},
    Input{selected, scroll, edit, command, shift}, image, dirty} = s
  State{Content{q, rows, reader, lines, title, status, scope,results,files,cards},
    Input{0, scroll, edit, command, shift}, image, True{}}

def set_results(+s: State, results: Results) -> State:
  State{Content{q,rows,reader,lines,title,status,scope,old,+files,cards},input,image,dirty} = s
  State{Content{q,rows,reader,lines,title,status,scope,results,files,cards},input,image,True{}}

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
    case ChildResults{phase,count,_,_}: U32.show(count) ++ Bool.pick(String,U32.is_eq(phase,0)," recorded results"," candidates on this page")
    case LibraryUsageResults{+phase,count,_}: Bool.pick(String,U32.is_eq(phase,2),U32.show(count) ++ " captured sources",Bool.pick(String,U32.is_eq(phase,1),"Reading retained captures","All-time recorded usage"))
    case AttachmentCaptureResults{phase,_,_,_,_,_}: Bool.pick(String,U32.is_eq(phase,2),"Choose a reference for details","Checking attachment evidence")
    case AttachmentFoldersResults{phase,_,_,_,_,_}: Bool.pick(String,U32.is_eq(phase,2),"Explicit capture folder policy","Updating folder policy")
    case AttachmentResults{phase,_,_,_}:
      match phase:
        case 1: "Loading captured references"
        case 2: "See record coverage in details"
        case 3: "Exporting selected inline bytes"
        case _: "Choose a captured record range"
    case QuotaResults{+phase,loaded,enabled,+view,offset,count,more}:
      Bool.pick(String,U32.is_eq(phase,1),"Loading local observations",Bool.pick(String,quota_ready(phase,loaded),
        Bool.pick(String,U32.is_eq(view,1),ordinary_result_label(offset,count,more,True{}),
          Bool.pick(String,U32.is_eq(view,2),"Review manual setup",Bool.pick(String,enabled,"Collection enabled locally","Collection off"))),"Refresh to verify local state"))
    case BriefResults{+phase}: Bool.pick(String,U32.is_eq(phase,0),"Choose explicit repository",Bool.pick(String,U32.is_eq(phase,2),"Review before sharing","Checking captured evidence"))
    case Results{offset,count,more,ready}: ordinary_result_label(offset,count,more,ready)
    case RelatedResults{page,count,more,previous}:
      "Page " ++ U32.show(page) ++ " | " ++ U32.show(count) ++ " links"
    case SettingsResults{+offset,+total,automatic,ready}:
      Bool.pick(String,ready,Bool.pick(String,U32.is_eq(total,0),"No registered folders",U32.show(U32.add(offset,1)) ++ "-" ++ U32.show(U32.min(U32.add(offset,14),total)) ++ "/" ++ U32.show(total)),"Inventory not loaded")

def result_available(results: Results,forward: Bool) -> Bool:
  match results:
    case ChildResults{_,_,more,previous}: Bool.pick(Bool,forward,more,previous)
    case LibraryUsageResults{_,_,_}: False{}
    case AttachmentResults{phase,_,previous,next}: U32.is_eq(phase,2) && Bool.pick(Bool,forward,next,previous)
    case AttachmentCaptureResults{phase,_,previous,next,_,_}: U32.is_eq(phase,2) && Bool.pick(Bool,forward,next,previous)
    case AttachmentFoldersResults{phase,_,_,_,previous,next}: U32.is_eq(phase,2) && Bool.pick(Bool,forward,next,previous)
    case QuotaResults{phase,loaded,enabled,view,+offset,count,more}:
      quota_ready(phase,loaded) && U32.is_eq(view,1) &&
        Bool.pick(Bool,forward,more && U32.is_le(offset,32728),U32.is_gt(offset,0))
    case BriefResults{_}: False{}
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
  State{Content{q,rows,reader,lines,title,status,scope,results,+files,cards},input,image,dirty} = s
  result_action_if(s,forward,result_available(results,forward))

def set_reader(+s: State, +title: String, +reader: String) -> State:
  State{Content{q, rows, old, oldlines, oldtitle, status, scope,results,files,cards},
    Input{selected, scroll, Edit{+focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  State{Content{q, rows, reader, wrap(reader), title, status, scope,results,files,[]},
    Input{selected, 0, Edit{focus, Bool.pick(U32,(U32.is_eq(focus,0) || U32.is_eq(focus,3)),caret,0),
      Bool.pick(U32,(U32.is_eq(focus,0) || U32.is_eq(focus,3)),anchor,0),
      Bool.pick(Bool,(U32.is_eq(focus,0) || U32.is_eq(focus,3)),drag,False{}),Bool.pick(U32,(U32.is_eq(focus,0) || U32.is_eq(focus,3)),viewport,0)}, command, shift}, image, True{}}

def set_scope(+s: State, +scope: String) -> State:
  State{Content{q, rows, reader, lines, title, status, old,+results,+files,cards}, input, image, dirty} = s
  State{Content{q, rows, reader, lines, title, status, scope,results,files,cards}, input, image, True{}}

def set_query(+s: State, +q: String) -> State:
  State{Content{old, rows, reader, lines, title, status, scope,results,files,cards},
    Input{selected, scroll, edit, command, shift}, image, dirty} = s
  +n = length(q)
  State{Content{q, rows, reader, lines, title, status, scope,results,files,cards},
    Input{selected, scroll, Edit{0, n, n, False{}, 0}, command, shift}, image, True{}}

def set_edit(+s: State, +edit: Edit) -> State:
  State{content, Input{selected, scroll, old, command, shift}, image, dirty} = s
  State{content_sync(content,edit), Input{selected, scroll, edit, command, shift}, image, True{}}

def set_position(+s: State, +selected: U32, +scroll: U32) -> State:
  State{content, Input{old, oldscroll, edit, command, shift}, image, dirty} = s
  State{content, Input{selected, scroll, edit, command, shift}, image, True{}}

def set_modifiers(+s: State, +command: Bool, +shift: Bool) -> State:
  State{content, Input{selected, scroll, edit, oldcmd, oldshift}, image, dirty} = s
  State{content, Input{selected, scroll, edit, command, shift}, image, dirty}

def card_update(s: State,model: ReaderCards.Model) -> State:
  State{Content{q,rows,reader,lines,title,status,scope,results,files,_},input,image,_} = s
  State{Content{q,rows,reader,lines,title,status,scope,results,files,[model]},input,image,True{}}

def card_attach(+s: State,model: ReaderCards.Model) -> State:
  State{_,Input{_,_,edit,_,_},_,_} = s
  set_edit(card_replace(s,model),edit)

def document_mode(s: State,title: String,+document: ReaderDoc.Document,page: String,structured: Bool) -> State:
  match structured:
    case False{}: set_reader(s,title,ReaderDoc.text(document))
    case True{}: card_attach(set_reader(s,title,ReaderDoc.text(document)),ReaderCards.open(document,page))

def set_document(s: State,title: String,+document: ReaderDoc.Document,page: String) -> State:
  document_mode(s,title,document,page,ReaderDoc.structured(document))

def card_keep_row(+s: State,row: Maybe<&2,U32>) -> State:
  State{_,Input{selected,+scroll,_,_,_},_,_} = s
  match row:
    case None{}: s
    case Some{+row}: set_position(s,selected,
      Bool.pick(U32,U32.is_lt(row,scroll),row,Bool.pick(U32,U32.is_ge(row,U32.add(scroll,G.reader_rows())),
        minus(U32.inc(row),G.reader_rows()),scroll)))

def card_keep_visible(s: State,model: ReaderCards.Model) -> State:
  card_keep_row(s,ReaderCards.focused_row(model))

def card_fold_changed(+s: State,+next: ReaderCards.Model,changed: Bool) -> State:
  match changed:
    case False{}: s
    case True{}:
      card_keep_visible(set_status(set_edit(card_replace(s,next),Edit{2,0,0,False{},0}),
        "Visible text updated. Selection cleared. Export captured page includes collapsed details."),next)

def card_fold_valid(+s: State,+model: ReaderCards.Model,expected: ReaderCards.Token,key: ReaderDoc.PartKey,valid: Bool) -> State:
  match valid:
    case False{}: s
    case True{}:
      +next = ReaderCards.toggle(model,expected,key)
      card_fold_changed(s,next,U32.is_ne(ReaderCards.revision(next),ReaderCards.revision(model)))

def card_fold_value(+s: State,+expected: ReaderCards.Token,key: ReaderDoc.PartKey,value: Maybe<&2,ReaderCards.Model>) -> State:
  match value:
    case None{}: s
    case Some{+model}: card_fold_valid(s,model,expected,key,ReaderCards.accepts(model,expected))

def card_fold(+s: State,expected: ReaderCards.Token,key: ReaderDoc.PartKey) -> State:
  card_fold_value(s,expected,key,card_model(s))

def card_focus_set(+s: State,+model: ReaderCards.Model,key: ReaderDoc.PartKey) -> State:
  +next = ReaderCards.with_focus(ReaderCards.sync(model,0,0,False{}),Some{key})
  card_keep_visible(set_edit(card_update(s,next),Edit{2,0,0,False{},0}),next)

def card_focus_value(+s: State,model: ReaderCards.Model,backward: Bool,key: Maybe<&2,ReaderDoc.PartKey>) -> State & Action:
  match key:
    case Some{key}: (card_focus_set(s,model,key),NoAction{})
    case None{}: (set_edit(card_clear(s),Edit{Bool.pick(U32,backward,2,0),0,0,False{},0}),NoAction{})

def card_focus_step(s: State,+model: ReaderCards.Model,+backward: Bool) -> State & Action:
  card_focus_value(s,model,backward,ReaderCards.focus_next(model,backward))

def card_tab_back(+s: State,model: ReaderCards.Model,focused: Maybe<&2,ReaderDoc.PartKey>) -> State & Action:
  match focused:
    case Some{_}: card_focus_step(s,model,True{})
    case None{}: (set_edit(s,Edit{1,0,0,False{},0}),NoAction{})

def card_tab_mode(+s: State,+model: ReaderCards.Model,+focus: U32,+backward: Bool) -> State & Action:
  match focus backward:
    case 2 False{}: card_focus_step(s,model,False{})
    case 2 True{}: card_tab_back(s,model,ReaderCards.focus(model))
    case 0 True{}: card_focus_step(s,ReaderCards.clear_focus(model),True{})
    case _ _:
      (set_edit(s,Edit{Bool.pick(U32,backward,minus(focus,1),U32.inc(focus)),0,0,False{},0}),NoAction{})

def card_key_focus(+s: State,+model: ReaderCards.Model,code: U32,command: Bool,key: Maybe<&2,ReaderDoc.PartKey>) -> Maybe<&1,State & Action>:
  match code command key:
    case 13 False{} Some{key}: Some{(card_fold(s,ReaderCards.token(model),key),NoAction{})}
    case 32 False{} Some{key}: Some{(card_fold(s,ReaderCards.token(model),key),NoAction{})}
    case 27 False{} Some{_}: Some{(card_clear(s),NoAction{})}
    case _ _ _: None{}

def card_key_code(+s: State,+model: ReaderCards.Model,+focus: U32,shift: Bool,code: U32,command: Bool) -> Maybe<&1,State & Action>:
  match code:
    case 9: Some{card_tab_mode(s,model,focus,shift)}
    case 25: Some{card_tab_mode(s,model,focus,True{})}
    case _: card_key_focus(s,model,code,command,Bool.pick(Maybe<&2,ReaderDoc.PartKey>,U32.is_eq(focus,2),ReaderCards.focus(model),None{}))

def card_key_value(+s: State,code: U32,command: Bool,value: Maybe<&2,ReaderCards.Model>) -> Maybe<&1,State & Action>:
  State{_,Input{_,_,Edit{focus,_,_,_,_},_,shift},_,_} = s
  match value:
    case None{}: None{}
    case Some{model}: card_key_code(s,model,focus,shift,code,command)

def card_key(+s: State,code: U32,command: Bool) -> Maybe<&1,State & Action>:
  card_key_value(s,code,command,card_model(s))


# Search edits are bounded to 512 committed Unicode characters.

def insert(+s: State, +text: String) -> State:
  State{Content{+q, rows, reader, lines, title, status, scope,results,files,cards},
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
  State{Content{q, rows, reader, lines, title, status, scope,results,files,cards},
    Input{selected, scroll, Edit{+focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  +n = Bool.pick(U32, U32.is_eq(focus, 0), length(q), reader_count(s))
  set_edit(card_clear(s), Edit{Bool.pick(U32, U32.is_eq(focus, 0), 0, 2), n, 0, False{}, 0})

def selection(+s: State) -> String:
  State{Content{q, rows, reader, lines, title, status, scope,results,files,cards},
    Input{selected, scroll, Edit{+focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  span(Bool.pick(String, U32.is_eq(focus, 0), q, reader), caret, anchor)

def move_caret(+s: State, +right: Bool) -> State:
  State{Content{q, rows, reader, lines, title, status, scope,results,files,cards},
    Input{selected, scroll, Edit{+focus, +caret, +anchor, drag, viewport}, command, +shift}, image, dirty} = s
  +n = Bool.pick(U32, U32.is_eq(focus, 0), length(q), reader_count(s))
  +step = Bool.pick(U32, right, U32.min(n, U32.add(caret, 1)), minus(caret, 1))
  +edge = Bool.pick(U32, right, U32.max(caret, anchor), U32.min(caret, anchor))
  # An unshifted arrow collapses a selection without taking an additional step.
  +pos = Bool.pick(U32, shift || U32.is_eq(caret, anchor), step, edge)
  set_edit(card_clear(s), Edit{focus, pos, Bool.pick(U32, shift, anchor, pos), False{}, 0})

def scroll_by(+s: State, +down: Bool, +amount: U32) -> State:
  State{Content{q, rows, reader, +lines, title, status, scope,results,files,cards},
    Input{selected, +scroll, edit, command, shift}, image, dirty} = s
  +limit = minus(reader_row_count(s), G.reader_rows())
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

def plain_reader_at(+s: State,+x: U32,+y: U32) -> U32:
  State{Content{q,rows,reader,+lines,title,status,scope,results,files,cards},Input{selected,scroll,edit,command,shift},image,dirty} = s
  reader_at_line(line_at(lines,U32.min(minus(U32.from_nat(List.length(&2,Line,lines)),1),U32.add(scroll,U32.min(U32.sub(G.reader_rows(),1),U32.div(minus(y,G.reader_y()),G.line_pitch()))))),x)

def card_hit(+model: ReaderCards.Model,scroll: U32,+x: U32,+y: U32) -> ReaderCards.Hit:
  Bool.pick(ReaderCards.Hit,G.rect(x,y,G.reader_x(),G.reader_y(),U32.add(G.reader_x(),U32.mul(G.reader_columns(),G.cell())),G.footer_y()),
    ReaderCards.hit_pixel(model,U32.add(scroll,U32.div(minus(y,G.reader_y()),G.line_pitch())),minus(x,G.reader_x())),ReaderCards.NoHit{})

def reader_at_hit(hit: ReaderCards.Hit,fallback: U32) -> U32:
  match hit:
    case ReaderCards.TextHit{position}: position
    case _: fallback

def reader_at_mode(+s: State,x: U32,y: U32,value: Maybe<&2,ReaderCards.Model>) -> U32:
  State{_,Input{_,scroll,Edit{_,caret,_,_,_},_,_},_,_} = s
  match value:
    case None{}: plain_reader_at(s,x,y)
    case Some{model}: reader_at_hit(card_hit(model,scroll,x,y),caret)

def reader_at(+s: State,x: U32,y: U32) -> U32:
  reader_at_mode(s,x,y,card_model(s))

def card_pointer_hit(+s: State,token: ReaderCards.Token,extend: Bool,press: Bool,hit: ReaderCards.Hit) -> State & Action:
  State{_,Input{_,_,Edit{_,_,anchor,_,_},_,_},_,_} = s
  match hit:
    case ReaderCards.TextHit{+position}:
      (set_edit(card_clear(s),Edit{2,position,Bool.pick(U32,extend,anchor,position),True{},0}),NoAction{})
    case ReaderCards.FoldHit{key}:
      (Bool.pick(State,press,card_fold(s,token,key),s),NoAction{})
    case _: (s,NoAction{})

def card_pointer_valid(+s: State,model: ReaderCards.Model,token: ReaderCards.Token,x: U32,y: U32,extend: Bool,press: Bool,valid: Bool) -> State & Action:
  State{_,Input{_,scroll,_,_,_},_,_} = s
  match valid:
    case False{}: (s,NoAction{})
    case True{}: card_pointer_hit(s,token,extend,press,card_hit(model,scroll,x,y))

def card_pointer_value(+s: State,+token: ReaderCards.Token,x: U32,y: U32,extend: Bool,press: Bool,value: Maybe<&2,ReaderCards.Model>) -> State & Action:
  match value:
    case None{}: (s,NoAction{})
    case Some{+model}: card_pointer_valid(s,model,token,x,y,extend,press,ReaderCards.accepts(model,token))

def card_pointer(+s: State,token: ReaderCards.Token,x: U32,y: U32,extend: Bool,press: Bool) -> State & Action:
  card_pointer_value(s,token,x,y,extend,press,card_model(s))

def query_offset(s: State) -> U32:
  State{content, Input{selected, scroll, Edit{focus, caret, anchor, drag, viewport}, command, shift}, image, dirty} = s
  Bool.pick(U32, U32.is_eq(focus, 0), Bool.pick(U32,drag,viewport,minus(caret,U32.sub(G.query_columns(),2))), 0)

def query_at(+s: State,col: U32) -> U32:
  U32.min(length(query(s)),U32.add(query_offset(s),U32.min(G.query_columns(),minus(col,U32.div(G.query_x(),G.cell())))))

def drag_plain(+s: State,+x: U32,+y: U32,+focus: U32,+anchor: U32) -> State & Action:
  (set_edit(s, Edit{focus, Bool.pick(U32, U32.is_eq(focus, 0), query_at(s, U32.div(x, G.cell())), reader_at(s, x, y)), anchor, True{}, query_offset(s)}), NoAction{})

def drag_card(+s: State,+x: U32,+y: U32,+focus: U32,+anchor: U32,value: Maybe<&2,ReaderCards.Model>) -> State & Action:
  match focus value:
    case 2 Some{+model}: card_pointer(s,ReaderCards.token(model),x,y,True{},False{})
    case _ _: drag_plain(s,x,y,focus,anchor)

def drag_if(+s: State, +x: U32, +y: U32, +focus: U32, +anchor: U32, +dragging: Bool) -> State & Action:
  match dragging:
    case True{}: drag_card(s,x,y,focus,anchor,card_model(s))
    case False{}: (s, NoAction{})

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
  State{Content{q, rows, reader, lines, title, status, scope,results,files,cards},
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

def wheel_reader(overview: Bool,s: State,down: Bool) -> State & Action:
  match overview:
    case True{}: (s,NoAction{})
    case False{}: (scroll_by(s,down,3),NoAction{})

def wheel_in(+s: State, down: Bool, list: Bool) -> State & Action:
  match list:
    case True{}:
      arrow(set_edit(s, Edit{1, 0, 0, False{}, 0}), down)
    case False{}:
      wheel_reader(library_overview(s),s,down)

def wheel(s: State,+x: U32,down: Bool) -> State & Action:
  wheel_in(s,down,(x >= G.sidebar_end() && x < G.list_end() : U32))

def attachment_action_ready(available: Bool,+s: State,index: U32) -> State & Action:
  match available:
    case False{}: (s,NoAction{})
    case True{}:
      match index:
        case 0: (s,Back{})
        case 1: (s,ListPrevious{})
        case 2: (s,ListNext{})
        case 3: (s,AttachmentExport{})
        case 4: (s,Copy{reader(s)})
        case 5: (s,AttachmentFolders{})
        case 6: (s,AttachmentCapture{})
        case 7: (s,AttachmentPreview{})
        case _: (s,NoAction{})

def folder_action_ready(available: Bool,+s: State,index: U32) -> State & Action:
  match available:
    case False{}: (s,NoAction{})
    case True{}:
      match index:
        case 0: (s,Back{})
        case 1: (s,AttachmentFolderUse{})
        case 2: (s,AttachmentFolderAdd{})
        case 3: (s,AttachmentFolderEnable{})
        case 4: (s,AttachmentFolderDisable{})
        case 5: (s,Refresh{})
        case 6: (s,ListPrevious{})
        case 7: (s,ListNext{})
        case _: (s,NoAction{})
def folder_action(+s: State,+index: U32) -> State & Action:
  State{Content{_,_,_,_,_,_,_,results,_,_},_,_,_} = s
  folder_action_ready(attachment_available(results,index),s,index)

def attachment_action(+s: State,+index: U32) -> State & Action:
  State{Content{_,_,_,_,_,_,_,results,_,_},_,_,_} = s
  attachment_action_ready(attachment_available(results,index),s,index)

def attachment_copy_selection(+s: State) -> State & Action:
  copy_action(s,Bool.not(U32.is_eq(focus(s),2)) || String.is_empty(selection(s)))

def attachment_select_all(s: State) -> State:
  select_all(set_edit(s,Edit{2,0,0,False{},0}))

def focus_list(+s: State) -> State:
  State{content,Input{selected,scroll,Edit{focus,caret,anchor,drag,viewport},command,shift},image,dirty} = s
  set_edit(s,Edit{1,caret,anchor,False{},0})

def library_show_report(+s: State,report: Bool) -> State:
  State{Content{_,_,_,_,_,_,_,results,_,_},_,_,_} = s
  match results:
    case LibraryUsageResults{2,count,[LibraryView.Summary{available,providers,notices,selected,_}]}:
      set_results(s,LibraryUsageResults{2,count,[LibraryView.Summary{available,providers,notices,selected,report}]})
    case _: s

def library_toggle_mode(available: Bool,+s: State) -> State:
  match available:
    case False{}: s
    case True{}: focus_list(library_show_report(s,library_overview(s)))

def library_toggle(+s: State) -> State:
  library_toggle_mode(library_has_summary(s),s)

def library_select_all(s: State) -> State:
  attachment_select_all(library_show_report(s,True{}))

def library_copy_mode(overview: Bool,+s: State) -> State & Action:
  match overview:
    case True{}: (s,Copy{reader(s)})
    case False{}: attachment_copy_selection(s)

def library_copy_selection(+s: State) -> State & Action:
  library_copy_mode(library_overview(s),s)

def library_text_action(+s: State,index: U32) -> State & Action:
  match index:
    case 0: library_copy_mode(library_has_summary(s),s)
    case 1: (library_toggle(s),NoAction{})
    case 3: (library_select_all(s),NoAction{})
    case _: (s,NoAction{})

def attachment_tab(+s: State) -> State & Action:
  (set_edit(s,Edit{Bool.pick(U32,U32.is_eq(focus(s),1),2,1),0,0,False{},0}),NoAction{})

def key_down_editable(+s: State, +code: U32, +command: Bool) -> State & Action:
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
      (scroll_by(s, False{}, G.reader_page_step()), NoAction{})
    case 63277 _:
      (scroll_by(s, True{}, G.reader_page_step()), NoAction{})
    case 9 _:
      tab(s)
    case 27 _:
      (set_edit(s, Edit{0, 0, 0, False{}, 0}), NoAction{})
    case _ _:
      (s, NoAction{})

def attachment_key(+s: State,+code: U32,+command: Bool) -> State & Action:
  match code command:
    case 101 True{}: attachment_action(s,3)
    case 97 True{}: (attachment_select_all(s),NoAction{})
    case 99 True{}: attachment_copy_selection(s)
    case 113 True{}: (s,Quit{})
    case 91 True{}: (s,Back{})
    case _ True{}: (s,NoAction{})
    case 13 False{}: (s,NoAction{})
    case 127 False{}: (s,NoAction{})
    case 8 False{}: (s,NoAction{})
    case 9 False{}: attachment_tab(s)
    case _ False{}: key_down_editable(s,code,False{})

def key_down_mode(s: State,code: U32,command: Bool,attachments: Bool) -> State & Action:
  match attachments:
    case True{}: attachment_key(s,code,command)
    case False{}: key_down_editable(s,code,command)

def library_page_key_mode(overview: Bool,s: State,code: U32) -> State & Action:
  match overview:
    case True{}: (s,NoAction{})
    case False{}: key_down_editable(s,code,False{})

def library_page_key(+s: State,code: U32) -> State & Action:
  library_page_key_mode(library_overview(s),s,code)

def library_key(+s: State,+code: U32,+command: Bool) -> State & Action:
  match code command:
    case 113 True{}: (s,Quit{})
    case 114 True{}: (s,Refresh{})
    case 101 True{}: (s,Export{})
    case 97 True{}: (library_select_all(s),NoAction{})
    case 99 True{}: library_copy_selection(s)
    case 91 True{}: (s,Back{})
    case _ True{}: (s,NoAction{})
    case 27 False{}: (s,Back{})
    case 13 False{}: (s,Submit{})
    case 127 False{}: (s,NoAction{})
    case 8 False{}: (s,NoAction{})
    case 9 False{}: attachment_tab(library_show_report(s,True{}))
    case 63276 False{}: library_page_key(s,code)
    case 63277 False{}: library_page_key(s,code)
    case _ False{}: key_down_editable(s,code,False{})

def key_library(+s: State,code: U32,command: Bool,library: Bool) -> State & Action:
  match library:
    case True{}: library_key(s,code,command)
    case False{}: key_down_mode(s,code,command,is_attachments(s))

def key_down_card(+s: State,code: U32,command: Bool,card: Maybe<&1,State & Action>) -> State & Action:
  match card:
    case Some{result}: result
    case None{}: key_library(s,code,command,is_library_usage(s))

def key_down(+s: State,+code: U32,+command: Bool) -> State & Action:
  key_down_card(s,code,command,card_key(s,code,command))

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

def history_action_mode(+s: State,+files: Bool,+usage: Bool) -> State & Action:
  match files usage:
    case True{} _: (s,Files{})
    case False{} True{}: (s,Back{})
    case False{} False{}: (focus_list(s),NoAction{})

def history_has_origin(+s: State) -> Bool:
  State{Content{_,_,_,_,_,_,_,results,_,_},_,_,_} = s
  match results:
    case RelatedResults{_,_,_,_}: True{}
    case LibraryUsageResults{_,_,_}: True{}
    case _: String.starts_with(title(s),"Usage |")

def history_action(+s: State) -> State & Action:
  history_action_mode(s,is_files(s),history_has_origin(s))

def files_destination_mode(+s: State,+files: Bool) -> State & Action:
  match files:
    case True{}: (focus_list(s),NoAction{})
    case False{}: (s,Files{})

def files_destination(+s: State) -> State & Action:
  files_destination_mode(s,is_files(s))

def sidebar_normal(+s: State,index: U32) -> State & Action:
  match index:
    case 0: files_destination(s)
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
    case 12: (s,Brief{})
    case 13: copy_action(s,String.is_empty(selection(s)))
    case 14: (s,WholeExport{})
    case 15: (set_query(s,""),Search{})
    case 16: (s,ContainerExport{})
    case 17: (s,Back{})
    case 18: history_action(s)
    case 19: (s,LibraryUsage{})
    case _: (s,NoAction{})

def sidebar_settings(+s: State,index: U32) -> State & Action:
  match index:
    case 0: (s,Settings{})
    case 1: (s,Pause{})
    case 2: (set_scope(s,"claude"),Scope{"claude"})
    case 3: (set_scope(s,"codex"),Scope{"codex"})
    case 4: (s,SettingsAddFolder{})
    case 5: (s,SettingsImportFile{})
    case 6: (s,Connections{})
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
    case 17: (s,Rebuild{})
    case _: (s,NoAction{})

def sidebar_mode(s: State,row: U32,settings: Bool) -> State & Action:
  match settings:
    case True{}: sidebar_settings(s,row)
    case False{}: sidebar_normal(s,row)

def sidebar_brief(+s: State,+row: U32) -> State & Action:
  match row:
    case 0: (s,Back{})
    case 1: (s,BriefPrepare{})
    case 2: (s,BriefCopy{})
    case 3: (s,BriefExport{})
    case 4: paste_query(s)
    case 5: (set_query(s,""),Search{})
    case 6: (select_all(s),NoAction{})
    case _: (s,NoAction{})

def sidebar_context(+s: State,+row: U32,+brief: Bool) -> State & Action:
  match brief:
    case True{}: sidebar_brief(s,row)
    case False{}: sidebar_mode(s,row,is_settings(s))

def quota_action_ready(available: Bool,s: State,index: U32) -> State & Action:
  match available:
    case False{}: (s,NoAction{})
    case True{}:
      match index:
        case 0: (s,Settings{})
        case 1: (s,Refresh{})
        case 2: (s,QuotaEnable{})
        case 3: (s,QuotaDisconnect{})
        case 4: (s,QuotaHistory{})
        case 5: (s,QuotaSetup{})
        case 6: (s,QuotaCopySetup{})
        case _: (s,NoAction{})

def quota_action(+s: State,+index: U32) -> State & Action:
  State{Content{_,_,_,_,_,_,_,results,_,_},_,_,_} = s
  quota_action_ready(quota_available(results,index),s,index)

def sidebar_quota(+s: State,row: U32,quota: Bool) -> State & Action:
  match quota:
    case True{}: quota_action(s,row)
    case False{}: sidebar_context(s,row,is_brief(s))

def sidebar_attachment(+s: State,row: U32,attachments: Bool) -> State & Action:
  match attachments:
    case True{}: attachment_action(s,Bool.pick(U32,U32.is_eq(row,6),6,99))
    case False{}: sidebar_quota(s,row,is_quota(s))

def sidebar_folders(+s: State,row: U32,folders: Bool) -> State & Action:
  match folders:
    case True{}: folder_action(s,Bool.pick(U32,U32.is_eq(row,5),5,99))
    case False{}: sidebar_attachment(s,row,is_attachments(s))
def atif_left() -> U32: 8
def atif_right() -> U32: 88
def archive_left() -> U32: 96
def archive_right() -> U32: 168

def split_export_pick(s: State,atif: Bool,archive: Bool) -> State & Action:
  match atif archive:
    case True{} _: (s,AtifExport{})
    case False{} True{}: (s,ContainerExport{})
    case False{} False{}: (s,NoAction{})

def split_export_click(s: State,+x: U32) -> State & Action:
  split_export_pick(s,(x >= atif_left() && x < atif_right() : U32),
    (x >= archive_left() && x < archive_right() : U32))

def sidebar_action(+s: State,row: U32) -> State & Action:
  sidebar_folders(s,row,is_attachment_folders(s))

def sidebar_click_ready(s: State,x: U32,row: U32,split: Bool) -> State & Action:
  match split:
    case True{}: split_export_click(s,x)
    case False{}: sidebar_action(s,row)

def sidebar_click(+s: State,x: U32,+row: U32) -> State & Action:
  sidebar_click_ready(s,x,row,U32.is_eq(row,16) &&
    Bool.not(is_settings(s) || is_brief(s) || is_quota(s) || is_attachments(s) || is_attachment_folders(s)))

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

def list_pager_action(+s: State,x: U32,hidden: Bool) -> State & Action:
  match hidden:
    case True{}: (s,NoAction{})
    case False{}: result_action(s,U32.is_ge(x,344))

def list_click.zone(+s: State,+x: U32,+y: U32,rows: List<&2,String>,files: Bool,pager: Bool) -> State & Action:
  match pager:
    case True{}: list_pager_action(s,x,is_attachments(s) || is_attachment_folders(s))
    case False{}: list_click.body(s,x,y,rows,G.rect(x,y,G.sidebar_end(),120,G.list_end(),152) && files)

def list_click(+s: State,+col: U32,+row: U32) -> State & Action:
  State{Content{q,rows,reader,lines,title,status,scope,results,+files,cards},input,image,dirty} = s
  +x = U32.mul(col,G.cell())
  +y = U32.mul(row,G.cell())
  list_click.zone(s,x,y,rows,files,U32.is_ge(y,G.list_pager_y()))

def text_action_editable(+s: State,index: U32) -> State & Action:
  match index:
    case 0: copy_action(s,String.is_empty(selection(s)))
    case 1: paste_query(s)
    case 2: (set_query(s,""),Search{})
    case 3: (select_all(s),NoAction{})
    case _: (s,NoAction{})

def text_action_attachment(attachments: Bool,+s: State,index: U32) -> State & Action:
  match attachments:
    case False{}: text_action_editable(s,index)
    case True{}:
      match index:
        case 0: attachment_copy_selection(s)
        case 3: (attachment_select_all(s),NoAction{})
        case _: (s,NoAction{})

def text_action_library(library: Bool,+s: State,index: U32) -> State & Action:
  match library:
    case True{}: library_text_action(s,index)
    case False{}: text_action_attachment(is_attachments(s),s,index)

def text_action(+s: State,index: U32) -> State & Action:
  text_action_library(is_library_usage(s),s,index)

def mouse_reader_mode(+s: State,+x: U32,+y: U32,value: Maybe<&2,ReaderCards.Model>) -> State & Action:
  State{_,Input{_,_,_,_,shift},_,_} = s
  match value:
    case Some{+model}: card_pointer(s,ReaderCards.token(model),x,y,shift,True{})
    case None{}:
      +pos = reader_at(s,x,y)
      (set_edit(s,Edit{2,pos,pos,True{},0}),NoAction{})

def mouse_reader_summary(overview: Bool,+s: State,x: U32,y: U32) -> State & Action:
  match overview:
    case True{}: (s,NoAction{})
    case False{}: mouse_reader_mode(s,x,y,card_model(s))

def mouse_reader(+s: State,+x: U32,+y: U32,inside: Bool) -> State & Action:
  match inside:
    case True{}: mouse_reader_summary(library_overview(s),s,x,y)
    case False{}: (s,NoAction{})

# Metric tiles are displays, not a second mapping into canonical report text.
def mouse_text(+s: State,+x: U32,+y: U32,actions: Bool) -> State & Action:
  match actions:
    case True{}: text_action(s,U32.div(U32.sub(x,G.text_actions_x()),G.text_action_width()))
    case False{}: mouse_reader(s,x,y,G.rect(x,y,G.list_end(),G.reader_y(),G.width(),G.footer_y()))

def mouse_attachment_entry(+s: State,+x: U32,+y: U32,inside: Bool) -> State & Action:
  match inside:
    case True{}: (s,Bool.pick(Action,attachment_entry_visible(s),Attachments{},NoAction{}))
    case False{}: mouse_text(s,x,y,G.rect(x,y,G.text_actions_x(),G.text_actions_y(),G.text_action_x(4),U32.add(G.text_actions_y(),G.control_height())))

def history_workspace(+s: State) -> Bool:
  Bool.not(is_settings(s) || is_brief(s) || is_quota(s) || is_attachments(s) || is_attachment_folders(s))

def provider_chips_visible(+s: State) -> Bool:
  State{Content{_,_,_,_,_,_,_,results,_,_},_,_,_} = s
  match results:
    case LibraryUsageResults{phase,_,_}: U32.is_le(phase,4)
    case Results{_,_,_,_}: history_workspace(s) && Bool.not(is_files(s))
    case _: False{}

def sidebar_index(+s: State,+y: U32) -> U32:
  +visual = G.side_index(y)
  Bool.pick(U32,is_quota(s) || is_attachments(s) || is_attachment_folders(s),visual,
    G.sidebar_action_index(visual,is_settings(s),is_brief(s)))

def provider_click_mode(+s: State,+x: U32,+y: U32,+index: U32,+available: Bool) -> State & Action:
  match available:
    case True{}: sidebar_normal(s,U32.add(index,1))
    case False{}: list_click(s,U32.div(x,G.cell()),U32.div(y,G.cell()))

def provider_click(+s: State,+x: U32,+y: U32) -> State & Action:
  +index = G.provider_index(x,y)
  provider_click_mode(s,x,y,index,U32.is_lt(index,3) && provider_chips_visible(s))

def mouse_body(+s: State,+x: U32,+y: U32,+col: U32,+row: U32,+sidebar: Bool,+list: Bool) -> State & Action:
  match sidebar list:
    case True{} _: sidebar_click(s,x,sidebar_index(s,y))
    case False{} True{}: provider_click(s,x,y)
    case False{} False{}: mouse_attachment_entry(s,x,y,G.attachment_entry_contains(x,y))

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

def top_brief(+s: State,+group: U32) -> State & Action:
  match group:
    case 0: (s,BriefPrepare{})
    case 1: (s,BriefCopy{})
    case 2: (s,BriefExport{})
    case 3: (s,Back{})
    case _: (s,NoAction{})

def top_context(+s: State,+group: U32,+brief: Bool) -> State & Action:
  match brief:
    case True{}: top_brief(s,group)
    case False{}: top_mode(s,group,is_settings(s))

def quota_top_action(s: State,group: U32) -> State & Action:
  match group:
    case 0: quota_action(s,1)
    case 1: quota_action(s,2)
    case 2: quota_action(s,3)
    case 3: quota_action(s,4)
    case 4: quota_action(s,5)
    case 5: result_action(s,False{})
    case 6: result_action(s,True{})
    case _: (s,NoAction{})

def top_quota(+s: State,group: U32,quota: Bool) -> State & Action:
  match quota:
    case True{}: quota_top_action(s,group)
    case False{}: top_context(s,group,is_brief(s))

def attachment_top_index(index: U32) -> U32:
  match index:
    case 0: 0
    case 1: 3
    case 2: 4
    case 3: 7
    case 4: 5
    case 5: 1
    case 6: 2
    case _: 99

def folder_top_index(index: U32) -> U32:
  match index:
    case 5: 6
    case 6: 7
    case index: index
def top_attachment_inner(+s: State,group: U32,attachments: Bool) -> State & Action:
  match attachments:
    case True{}: attachment_action(s,attachment_top_index(group))
    case False{}: top_quota(s,group,is_quota(s))

def top_folders(+s: State,group: U32,attachments: Bool,folders: Bool) -> State & Action:
  match folders:
    case True{}: folder_action(s,folder_top_index(group))
    case False{}: top_attachment_inner(s,group,attachments)
def top_attachment(+s: State,group: U32,attachments: Bool) -> State & Action:
  top_folders(s,group,attachments,is_attachment_folders(s))

def top_library_overview(+s: State,group: U32) -> State & Action:
  match group:
    case 0: (s,Refresh{})
    case 1: (s,Pause{})
    case 2: (s,Scope{"all"})
    case 3: (s,Scope{"claude"})
    case 4: (s,Scope{"codex"})
    case 5: (s,Back{})
    case 6: (s,Submit{})
    case _: (s,NoAction{})

def top_library_capture(+s: State,group: U32) -> State & Action:
  match group:
    case 0: (s,Back{})
    case 1: (s,Usage{})
    case 2: (s,Attachments{})
    case 3: (s,Why{})
    case 4: (s,Export{})
    case 5: (s,Previous{})
    case 6: (s,Next{})
    case _: (s,NoAction{})

def top_library(+s: State,group: U32,phase: U32) -> State & Action:
  match phase:
    case 0: top_attachment(s,group,is_attachments(s))
    case 5: (s,Bool.pick(Action,U32.is_eq(group,0),Back{},NoAction{}))
    case 6: top_library_capture(s,group)
    case _: top_library_overview(s,group)

def top_action(+s: State,group: U32) -> State & Action:
  top_library(s,group,library_phase(s))

# One availability/geometry descriptor drives both top-button paint and hits.
# Existing action functions remain the authority and keep their own gates.
def quota_top_available(results: Results,index: U32) -> Bool:
  match index:
    case 0: quota_available(results,1)
    case 1: quota_available(results,2)
    case 2: quota_available(results,3)
    case 3: quota_available(results,4)
    case 4: quota_available(results,5)
    case 5: result_available(results,False{})
    case 6: result_available(results,True{})
    case _: False{}


def toolbar_available(+results: Results,+index: U32) -> Bool:
  match results:
    case QuotaResults{_,_,_,_,_,_,_}: quota_top_available(results,index)
    case AttachmentResults{_,_,_,_}: attachment_available(results,attachment_top_index(index))
    case AttachmentCaptureResults{_,_,_,_,_,_}: attachment_available(results,attachment_top_index(index))
    case AttachmentFoldersResults{_,_,_,_,_,_}: attachment_available(results,folder_top_index(index))
    case BriefResults{_}: U32.is_lt(index,4)
    case LibraryUsageResults{5,_,_}: U32.is_eq(index,0)
    case _: True{}

def toolbar_region(results: Results,+index: U32) -> Region.ControlRegion:
  G.top_region(index,toolbar_available(results,index))

def toolbar_regions(+results: Results) -> List<&2,Region.ControlRegion>:
  [toolbar_region(results,0),toolbar_region(results,1),toolbar_region(results,2),
   toolbar_region(results,3),toolbar_region(results,4),toolbar_region(results,5),toolbar_region(results,6)]

def toolbar_hit(+s: State,x: U32,y: U32) -> Maybe<&2,U32>:
  State{Content{_,_,_,_,_,_,_,results,_,_},_,_,_} = s
  Region.hit(7n,toolbar_regions(results),x,y)

def toolbar_action(s: State,hit: Maybe<&2,U32>) -> State & Action:
  match hit:
    case None{}: (s,NoAction{})
    case Some{index}: top_action(s,index)

def query_click_editable(+s: State, col: U32) -> State & Action:
  +pos = query_at(s, col)
  (set_edit(s, Edit{0, pos, pos, True{}, query_offset(s)}), NoAction{})

def query_click_mode(s: State,col: U32,attachments: Bool) -> State & Action:
  match attachments:
    case True{}: (s,NoAction{})
    case False{}: query_click_editable(s,col)

def query_click(+s: State,col: U32) -> State & Action:
  query_click_mode(s,col,is_attachments(s) || is_library_usage(s))

def mouse_top.action(+s: State,x: U32,inside: Bool) -> State & Action:
  match inside:
    case True{}: toolbar_action(s,toolbar_hit(s,x,80))
    case False{}: (s,NoAction{})

def mouse_top.query(+s: State,+col: U32,+x: U32,+y: U32,inside: Bool) -> State & Action:
  match inside:
    case True{}: query_click(s,col)
    case False{}: mouse_top.action(s,x,(y >= 80 && y < 112 : U32))

def mouse_child_entry(s: State,col: U32,+x: U32,+y: U32,inside: Bool) -> State & Action:
  match inside:
    case True{}: (s,ChildResultsOpen{})
    case False{}: mouse_top.query(s,col,x,y,G.rect(x,y,G.query_left(),24,G.query_right(),64))

def mouse_top(+s: State,+col: U32,+row: U32) -> State & Action:
  +x = U32.mul(col,G.cell())
  +y = U32.mul(row,G.cell())
  mouse_child_entry(s,col,x,y,child_entry_visible(s) && G.rect(x,y,1008,0,1176,24))

# A UI-only inspector. Canonical evidence and its reader scroll stay untouched.
def status_text(s: State) -> String:
  State{Content{q,rows,reader,lines,title,status,scope,results,files,cards},input,image,dirty} = s
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
  (status_close(s),CopyStatus{status_text(s)})

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
      status_mouse_target(s,G.rect(x,y,G.status_close_x(),120,G.status_right(),152) || U32.is_ge(y,G.footer_y()),G.rect(x,y,G.status_copy_x(),120,U32.sub(G.status_close_x(),8),152))

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
    case 63276 True{} _: (status_scroll(s,False{},G.reader_page_step()),NoAction{})
    case 63277 True{} _: (status_scroll(s,True{},G.reader_page_step()),NoAction{})
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
  mouse_toolbar(s,x,y,col,row,U32.is_lt(y,G.header_height()))

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
  text_focused(s, text, U32.is_eq(focus, 0) && Bool.not(is_attachments(s) || is_library_usage(s)))

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

# Canvas operations delegate to the shared kit; no second rasterizer.
def canvas.set(d: Nat,c: C.Canvas,x: U32,y: U32,tile: C.Canvas) -> C.Canvas:
  C.canvas.set(d,c,x,y,tile)
def glyph.put(c: C.Canvas,bits: Font.Glyph,x: U32,y: U32,fg: U32,bg: U32) -> C.Canvas:
  C.glyph.put(c,bits,x,y,fg,bg)
def box(c: C.Canvas,x: U32,y: U32,width: U32,height: U32,color: U32) -> C.Canvas:
  C.box(c,x,y,width,height,color)
def blend(fg: U32,bg: U32,coverage: U32) -> U32:
  C.blend(fg,bg,coverage)
def canvas.image(c: C.Canvas) -> Image:
  C.canvas.image(c)
def chrome_text(c: C.Canvas,label: String,x: U32,y: U32,width: U32,face: U32,fg: U32,bg: U32) -> C.Canvas:
  Chrome.chrome_text(c,label,x,y,width,face,fg,bg)


def ink() -> U32: Palette.ink(Palette.Body{})
def muted() -> U32: Palette.ink(Palette.Secondary{})
def heading_ink() -> U32: Palette.ink(Palette.Heading{})
def accent() -> U32: Palette.ink(Palette.Action{})
def paper() -> U32: Palette.surface(Palette.Paper{})
def rail() -> U32: Palette.surface(Palette.Navigation{})
def panel() -> U32: Palette.surface(Palette.List{})
def selected_bg() -> U32: Palette.surface(Palette.Current{})
def selection_bg() -> U32: Palette.surface(Palette.Selection{})


# Tabs occupy one existing character cell. Only their painted glyph changes;
# canonical text, scalar offsets, selection and export retain the original tab.
def display_glyph(+code: U32) -> Font.Glyph:
  match code:
    case 9: Font.glyph(8594)
    case _: Font.glyph(code)

def write(+count: Nat,+c: C.Canvas,text: String,+x: U32,+y: U32,+foreground: U32,+background: U32) -> C.Canvas:
  match count text:
    case 1n+n SCon{Chr{code},rest}:
      write(n,glyph.put(c,display_glyph(code),x,y,foreground,background),rest,U32.add(x,1),y,foreground,background)
    case _ _: c

def selected_mark(c: C.Canvas,selected: Bool,x: U32,y: U32,height: U32) -> C.Canvas:
  match selected:
    case False{}: c
    case True{}: box(c,x,y,8,height,accent())

def text(c: C.Canvas,label: String,x: U32,y: U32,count: U32,fg: U32,bg: U32) -> C.Canvas:
  write(U32.to_nat(count),c,label,U32.div(x,G.cell()),U32.div(y,G.cell()),fg,bg)

def draw_line(+count: Nat,+c: C.Canvas,text: String,+x: U32,+y: U32,+at: U32,+low: U32,+high: U32) -> C.Canvas:
  match count text:
    case 1n+n SCon{Chr{code},rest}:
      +bg = Bool.pick(U32,(at >= low && at < high : U32),selection_bg(),paper())
      next = glyph.put(c,display_glyph(code),x,y,ink(),bg)
      draw_line(n,next,rest,U32.add(x,1),y,U32.add(at,1),low,high)
    case _ _: c

def draw_reader(+fuel: Nat,+c: C.Canvas,lines: List<&2,Line>,+y: U32,+low: U32,+high: U32) -> C.Canvas:
  match fuel lines:
    case 1n+n Line{start,text} <> rest:
      draw_reader(n,draw_line(U32.to_nat(G.reader_columns()),c,text,U32.div(G.reader_x(),G.cell()),y,start,low,high),rest,U32.add(y,U32.div(G.line_pitch(),G.cell())),low,high)
    case _ _: c

# Transcript card chrome is typed presentation. Message prose uses cached pixel
# insertion boundaries; code/tools/metadata retain the 8px scalar grid.
def card_background(style: U32) -> U32:
  match style:
    case 2: 15922675
    case 3: 16775125
    case 5: 16775125
    case 4: 15922929
    case 6: 15922929
    case _: paper()

def card_foreground(style: U32) -> U32:
  match style:
    case 1: muted()
    case 5: muted()
    case 6: muted()
    case _: ink()

def card_role_accent(role: String) -> U32:
  match role:
    case "user": 13213493
    case "assistant": 7640440
    case _: 5858909

def draw_card_role(c: C.Canvas,label: String,+role: String,+y: U32) -> C.Canvas:
  +bg = card_background(ReaderCards.role_style(role,False{}))
  base = box(c,528,y,656,G.line_pitch(),bg)
  marked = box(base,528,y,8,G.line_pitch(),card_role_accent(role))
  chrome_text(marked,label,536,y,640,1,heading_ink(),bg)

def draw_card_line(+fuel: Nat,+c: C.Canvas,text: String,+x: U32,+y: U32,+at: U32,+low: U32,+high: U32,+fg: U32,+bg: U32) -> C.Canvas:
  match fuel text:
    case 1n+n SCon{Chr{code},rest}:
      next = glyph.put(c,display_glyph(code),x,y,fg,Bool.pick(U32,(at >= low && at < high : U32),selection_bg(),bg))
      draw_card_line(n,next,rest,U32.inc(x),y,U32.inc(at),low,high,fg,bg)
    case _ _: c

def draw_card_section(c: C.Canvas,label: String,+y: U32,+key: Maybe<&2,ReaderDoc.PartKey>,closed: Bool,focused: Maybe<&2,ReaderDoc.PartKey>) -> C.Canvas:
  +selected = ReaderCards.is_focused(focused,key)
  +bg = Bool.pick(U32,selected,selected_bg(),15529703)
  base = box(c,528,y,656,G.line_pitch(),bg)
  +control = Maybe.is_some(&2,ReaderDoc.PartKey,key)
  labeled = chrome_text(base,label,536,y,Bool.pick(U32,control,536,640),Bool.pick(U32,control,0,1),heading_ink(),bg)
  chrome_text(labeled,Bool.pick(String,control,Bool.pick(String,closed,"Show +","Hide -"),""),1088,y,88,0,accent(),bg)

def draw_card_row(c: C.Canvas,row: ReaderCards.Row,+y: U32,low: U32,high: U32,focused: Maybe<&2,ReaderDoc.PartKey>) -> C.Canvas:
  match row:
    case ReaderCards.GapRow{}: box(c,528,y,656,G.line_pitch(),paper())
    case ReaderCards.RoleRow{label,role}: draw_card_role(c,label,role,y)
    case ReaderCards.SectionRow{label,key,closed}: draw_card_section(c,label,y,key,closed,focused)
    case ReaderCards.ProseRow{line,+style}:
      +bg = card_background(style)
      base = box(c,528,y,656,G.line_pitch(),bg)
      Prose.draw(base,line,G.reader_x(),y,G.reader_columns(),card_foreground(style),bg,selection_bg(),low,high)
    case ReaderCards.TextRow{start,text,count,+style}:
      +bg = card_background(style)
      base = box(c,528,y,656,G.line_pitch(),bg)
      draw_card_line(U32.to_nat(G.reader_columns()),base,text,U32.div(G.reader_x(),G.cell()),U32.div(y,G.cell()),start,low,high,card_foreground(style),bg)

def draw_card_rows(fuel: Nat,c: C.Canvas,rows: List<&2,ReaderCards.Row>,+y: U32,+low: U32,+high: U32,+focused: Maybe<&2,ReaderDoc.PartKey>) -> C.Canvas:
  match fuel rows:
    case 1n+n Con{row,rest}:
      draw_card_rows(n,draw_card_row(c,row,y,low,high,focused),rest,U32.add(y,G.line_pitch()),low,high,focused)
    case _ _: c

def draw_reader_value(c: C.Canvas,lines: List<&2,Line>,scroll: U32,low: U32,high: U32,value: Maybe<&2,ReaderCards.Model>) -> C.Canvas:
  match value:
    case None{}: draw_reader(U32.to_nat(G.reader_rows()),c,List.drop(&2,Line,lines,U32.to_nat(scroll)),U32.div(G.reader_y(),G.cell()),low,high)
    case Some{+model}: draw_card_rows(U32.to_nat(G.reader_rows()),c,List.drop(&2,ReaderCards.Row,ReaderCards.rows(model),U32.to_nat(scroll)),G.reader_y(),low,high,ReaderCards.focus(model))

def draw_library_summary_result(value: Result<&2,&2,C.Failure,C.Canvas>,fallback: C.Canvas) -> C.Canvas:
  match value:
    case Done{canvas}: canvas
    case Fail{_}: chrome_text(fallback,"Overview unavailable. Choose Report to inspect the complete evidence.",536,168,640,0,muted(),paper())

def draw_library_reader(+s: State,+c: C.Canvas,lines: List<&2,Line>,scroll: U32,low: U32,high: U32,value: Maybe<&2,LibraryView.Summary>) -> C.Canvas:
  match value:
    case Some{LibraryView.Summary{available,providers,notices,selected,False{}}}:
      draw_library_summary_result(LibrarySummary.draw(c,LibraryView.Summary{available,providers,notices,selected,False{}}),c)
    case _: draw_reader_value(c,lines,scroll,low,high,card_model(s))

def draw_reader_context(+s: State,c: C.Canvas,lines: List<&2,Line>,scroll: U32,low: U32,high: U32) -> C.Canvas:
  draw_library_reader(s,c,lines,scroll,low,high,library_summary(s))

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

# Explicit title/subtitle rows have separate visual lines. Inspect only a
# bounded display prefix: Usage rows have at most 80 + 1 + 240 scalars, plus
# two ellipses. Later lines never reach the single-line label painter. Keep
# the original wrapping path for rows without a separator in this prefix.
# This projection never changes canonical text or typed row identities.
def card_uncr_reversed(text: String) -> String:
  match text:
    case SCon{Chr{13},rest}: String.reverse(rest)
    case _: String.reverse(text)

def card_uncr(text: String) -> String:
  card_uncr_reversed(String.reverse(text))

def card_lines(+text: String,parts: List<&2,String>) -> Card:
  match parts:
    case first <> second <> _: Card{card_uncr(first),card_tail(card_uncr(second))}
    case _: card_mode(text,U32.is_gt(length(text),38))

def card(+text: String) -> Card:
  card_lines(text,String.lines(String.take(text,384n)))

def history_card(+row: String) -> Card:
  Bool.pick(Card,String.starts_with(row,"claude  "),Card{String.drop(row,8n),"Claude"},
    Bool.pick(Card,String.starts_with(row,"codex  "),Card{String.drop(row,7n),"Codex"},card(row)))

def display_card(row: String,session: Bool) -> Card:
  match session:
    case True{}: history_card(row)
    case False{}: card(row)

def card_draw(c: C.Canvas,card: Card,+y: U32,+bg: U32) -> C.Canvas:
  Card{first,second} = card
  line1 = chrome_text(c,first,200,U32.add(y,0),296,1,ink(),bg)
  chrome_text(line1,second,200,U32.add(y,24),296,0,muted(),bg)

def draw_rows(+fuel: Nat,+c: C.Canvas,rows: List<&2,String>,+at: U32,+selected: U32,+session: Bool) -> C.Canvas:
  match fuel rows:
    case 1n+n +row <> rest:
      +y = U32.add(G.list_y(),U32.mul(at,G.list_pitch()))
      +bg = Bool.pick(U32,U32.is_eq(at,selected),selected_bg(),panel())
      base = box(c,184,y,320,56,bg)
      marked = selected_mark(base,U32.is_eq(at,selected),184,y,56)
      second = card_draw(marked,display_card(row,session),y,bg)
      draw_rows(n,second,rest,U32.add(at,1),selected,session)
    case _ _: c

def list_heading(results: Results,files: Bool) -> String:
  match results:
    case ChildResults{phase,_,_,_}: Bool.pick(String,U32.is_eq(phase,0),"Recorded child results","Retained child candidates")
    case LibraryUsageResults{_,_,_}: "Captured sessions"
    case AttachmentResults{_,_,_,_}: "Captured attachments"
    case AttachmentCaptureResults{_,_,_,_,_,_}: "Captured attachments"
    case AttachmentFoldersResults{_,_,_,_,_,_}: "Capture folders"
    case QuotaResults{_,_,_,_,_,_,_}: "Local observations"
    case RelatedResults{page,count,more,previous}: "Related captures"
    case SettingsResults{offset,total,automatic,ready}: "Registered folders"
    case BriefResults{_}: "Frozen capture"
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
        case 6: "Connections"
        case 7: "Reload settings"
        case 8: "Enable selected"
        case 9: "Disable selected"
        case 10: "Refresh: 30 sec"
        case 11: "Refresh: 2 hours"
        case 12: "Refresh: 4 hours"
        case 13: "Refresh: 8 hours"
        case 14: "Refresh: 24 hours"
        case 15: "Clear input"
        case 16: "Select all"
        case 17: "Rebuild capture"
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
        case 12: "Prepare brief"
        case 13: "Copy selection"
        case 14: "Export full JSONL"
        case 15: "Clear search"
        case 16: "Export archive"
        case _: "Back"

def side_active(index: U32,scope: String) -> Bool:
  match index:
    case 1: String.eq(scope,"all")
    case 2: String.eq(scope,"claude")
    case 3: String.eq(scope,"codex")
    case _: False{}

def brief_side_label(+index: U32) -> String:
  match index:
    case 0: "Back to reader"
    case 1: "Prepare preview"
    case 2: "Copy brief"
    case 3: "Export brief"
    case 4: "Paste root"
    case 5: "Clear root"
    case 6: "Select all"
    case _: ""

def export_split(c: C.Canvas,+y: U32) -> C.Canvas:
  left = box(c,atif_left(),y,U32.sub(atif_right(),atif_left()),32,panel())
  named = text(left,"ATIF 1.8",U32.add(atif_left(),8),U32.add(y,8),8,accent(),panel())
  right = box(named,archive_left(),y,U32.sub(archive_right(),archive_left()),32,panel())
  text(right,"Archive",U32.add(archive_left(),8),U32.add(y,8),7,accent(),panel())

def side_row(c: C.Canvas,+y: U32,label: String,+bg: U32,split: Bool) -> C.Canvas:
  match split:
    case True{}: export_split(c,y)
    case False{}: text(box(c,8,y,160,32,bg),label,16,U32.add(y,8),18,ink(),bg)

def draw_side(fuel: Nat,c: C.Canvas,+index: U32,+files: Bool,+settings: Bool,+scope: String,+brief: Bool) -> C.Canvas:
  match fuel:
    case 0n: c
    case 1n+n:
      +y = G.sidebar_y(index)
      +logical = G.sidebar_action_index(index,settings,brief)
      +active = Bool.not(brief) && side_active(logical,scope) && (Bool.not(settings) || U32.is_ne(logical,1))
      +bg = Bool.pick(U32,active,selected_bg(),rail())
      label = side_row(c,y,Bool.pick(String,brief,brief_side_label(logical),side_label(settings,logical,files)),bg,
        U32.is_eq(logical,16) && Bool.not(settings || brief))
      draw_side(n,selected_mark(label,active,8,y,32),U32.add(index,1),files,settings,scope,brief)

def workspace_side_label(index: U32) -> String:
  match index:
    case 18: "History"
    case 0: "Repository files"
    case 6: "Session usage"
    case 19: "Library usage"
    case 10: "Settings"
    case 5: "Tools"
    case 7: "Related captures"
    case 8: "Saved versions"
    case 9: "Open latest"
    case 12: "Prepare brief"
    case 14: "Export full JSONL"
    case 11: "Storage"
    case 4: "Search filters"
    case 17: "Back"
    case _: ""

def workspace_side_active(+s: State,+index: U32) -> Bool:
  Bool.pick(Bool,is_library_usage(s),U32.is_eq(index,19),Bool.pick(Bool,is_files(s),U32.is_eq(index,0),
    Bool.pick(Bool,String.starts_with(title(s),"Usage |"),U32.is_eq(index,6),U32.is_eq(index,18))))

def workspace_export(+c: C.Canvas,+y: U32) -> C.Canvas:
  left = box(c,atif_left(),y,U32.sub(atif_right(),atif_left()),32,Palette.navigation_paper())
  named = chrome_text(left,"ATIF 1.8",16,y,72,0,Palette.navigation_ink(),Palette.navigation_paper())
  right = box(named,archive_left(),y,U32.sub(archive_right(),archive_left()),32,Palette.navigation_paper())
  chrome_text(right,"Archive",104,y,64,0,Palette.navigation_ink(),Palette.navigation_paper())

def workspace_side_item(+c: C.Canvas,+s: State,+index: U32,+y: U32,+logical: U32) -> C.Canvas:
  match logical:
    case 99:
      chrome_text(c,Bool.pick(String,U32.is_eq(index,4),"THIS CAPTURE","LIBRARY"),16,U32.add(y,8),144,0,Palette.navigation_muted(),Palette.navigation_paper())
    case 16: workspace_export(c,y)
    case _:
      +active = workspace_side_active(s,logical)
      +bg = Bool.pick(U32,active,Palette.navigation_current(),Palette.navigation_paper())
      +fg = Bool.pick(U32,active,Palette.navigation_current_ink(),Palette.navigation_ink())
      base = box(c,8,y,160,32,bg)
      chrome_text(base,workspace_side_label(logical),16,U32.add(y,0),144,Bool.pick(U32,U32.is_lt(index,4),1,0),fg,bg)

def draw_workspace_side(+fuel: Nat,+c: C.Canvas,+s: State,+index: U32) -> C.Canvas:
  match fuel:
    case 0n: c
    case 1n+n:
      next = workspace_side_item(c,s,index,G.sidebar_y(index),G.sidebar_action_index.normal(index))
      draw_workspace_side(n,next,s,U32.add(index,1))

def provider_label(index: U32) -> String:
  match index:
    case 0: "All sources"
    case 1: "Claude"
    case _: "Codex"

def provider_selected(+scope: String,+index: U32) -> Bool:
  String.eq(scope,Bool.pick(String,U32.is_eq(index,0),"all",Bool.pick(String,U32.is_eq(index,1),"claude","codex")))

def draw_providers(+fuel: Nat,+c: C.Canvas,+scope: String,+index: U32) -> C.Canvas:
  match fuel:
    case 0n: c
    case 1n+n:
      +active = provider_selected(scope,index)
      +bg = Bool.pick(U32,active,selected_bg(),panel())
      base = box(c,G.provider_x(index),G.provider_y(),G.provider_width(),24,bg)
      next = chrome_text(base,provider_label(index),U32.add(G.provider_x(index),8),G.provider_y(),U32.sub(G.provider_width(),16),Bool.pick(U32,active,1,0),ink(),bg)
      draw_providers(n,next,scope,U32.add(index,1))

def provider_list_heading(s: State) -> String:
  Bool.pick(String,is_library_usage(s),"Usage","History")

def draw_list_header_mode(+c: C.Canvas,+s: State,+results: Results,+files: Bool,+visible: Bool) -> C.Canvas:
  match visible:
    case True{}:
      heading = chrome_text(c,provider_list_heading(s),192,120,144,2,heading_ink(),panel())
      count = chrome_text(heading,result_label(results),344,128,160,0,muted(),panel())
      draw_providers(3n,count,scope(s),0)
    case False{}:
      heading = chrome_text(c,list_heading(results,files),192,120,304,1,heading_ink(),panel())
      chrome_text(heading,result_label(results),192,152,304,0,muted(),panel())

def draw_list_header(+c: C.Canvas,+s: State,+results: Results,+files: Bool) -> C.Canvas:
  draw_list_header_mode(c,s,results,files,provider_chips_visible(s))

def whole_usage(s: State) -> Bool:
  String.starts_with(title(s),"Usage | whole captured session")

def top_label(index: U32,files: Bool,settings: Bool,whole: Bool,automatic: String) -> String:
  match index:
    case 0: Bool.pick(String,files,"Open repository","Refresh")
    case 1: automatic
    case 2: Bool.pick(String,settings,"Add folder","Blame")
    case 3: Bool.pick(String,settings,"Import file","Why")
    case 4: Bool.pick(String,settings,"Enable selected",Bool.pick(String,files || whole,"Export evidence","Export page"))
    case 5: Bool.pick(String,settings,"Disable selected",Bool.pick(String,whole,"Whole session","Previous page"))
    case _: Bool.pick(String,settings,"Reload settings",Bool.pick(String,whole,"All records","Next page"))

def brief_top_label(+index: U32) -> String:
  match index:
    case 0: "Prepare preview"
    case 1: "Copy brief"
    case 2: "Export brief"
    case 3: "Back to reader"
    case _: ""

def toolbar_painted(value: Result<&2,&2,C.Failure,C.Canvas>) -> C.Canvas:
  match value:
    case Done{canvas}: canvas
    case Fail{_}: C.Flat{16711680}

def toolbar_button_named(empty: Bool,c: C.Canvas,region: Region.ControlRegion,label: String) -> C.Canvas:
  match empty:
    case True{}: c
    case False{}:
      toolbar_painted(Button.draw(c,Button.Button{region,label},
        Button.Style{Palette.ink(Palette.Action{}),Palette.ink(Palette.Secondary{}),
          Palette.button_paper(),Palette.button_disabled_paper(),Palette.button_edge(),
          Palette.button_focus()},False{}))

def toolbar_button(c: C.Canvas,region: Region.ControlRegion,+label: String) -> C.Canvas:
  toolbar_button_named(String.is_empty(label),c,region,label)

def draw_top(fuel: Nat,c: C.Canvas,+index: U32,+files: Bool,+settings: Bool,+whole: Bool,+automatic: String,+brief: Bool) -> C.Canvas:
  match fuel:
    case 0n: c
    case 1n+n:
      label = toolbar_button(c,G.top_region(index,Bool.not(brief) || U32.is_lt(index,4)),
        Bool.pick(String,brief,brief_top_label(index),top_label(index,files,settings,whole,automatic)))
      draw_top(n,label,U32.add(index,1),files,settings,whole,automatic,brief)

def quota_side_label(index: U32) -> String:
  match index:
    case 0: "Back to Settings"
    case 1: "Refresh local"
    case 2: "Enable"
    case 3: "Disconnect"
    case 4: "Sampled history"
    case 5: "Manual setup"
    case 6: "Copy setup"
    case _: ""

def quota_side_color(results: Results,index: U32) -> U32:
  Bool.pick(U32,quota_available(results,index),ink(),muted())

def draw_quota_side(fuel: Nat,c: C.Canvas,+index: U32,+results: Results) -> C.Canvas:
  match fuel:
    case 0n: c
    case 1n+n:
      +y = G.sidebar_y(index)
      base = box(c,8,y,160,32,rail())
      label = text(base,quota_side_label(index),16,U32.add(y,8),18,quota_side_color(results,index),rail())
      draw_quota_side(n,label,U32.add(index,1),results)

def draw_side_context(quota: Bool,c: C.Canvas,results: Results,files: Bool,settings: Bool,scope: String,brief: Bool) -> C.Canvas:
  match quota:
    case True{}: draw_quota_side(7n,c,0,results)
    case False{}: draw_side(U32.to_nat(G.sidebar_rows()),c,0,files,settings,scope,brief)

def quota_top_label(index: U32) -> String:
  match index:
    case 0: "Refresh local"
    case 1: "Enable"
    case 2: "Disconnect"
    case 3: "History"
    case 4: "Manual setup"
    case 5: "Previous samples"
    case 6: "Next samples"
    case _: ""

def quota_top_color(results: Results,index: U32) -> U32:
  Bool.pick(U32,quota_top_available(results,index),accent(),muted())

def draw_quota_top(fuel: Nat,c: C.Canvas,+index: U32,+results: Results) -> C.Canvas:
  match fuel:
    case 0n: c
    case 1n+n:
      label = toolbar_button(c,toolbar_region(results,index),quota_top_label(index))
      draw_quota_top(n,label,U32.add(index,1),results)

def draw_top_context(quota: Bool,c: C.Canvas,results: Results,files: Bool,settings: Bool,whole: Bool,automatic: String,brief: Bool) -> C.Canvas:
  match quota:
    case True{}: draw_quota_top(7n,c,0,results)
    case False{}: draw_top(7n,c,0,files,settings,whole,automatic,brief)

def attachment_side_label(index: U32) -> String:
  match index:
    case 0: "Back to reader"
    case 1: "Previous records"
    case 2: "Next records"
    case 3: "Export bytes"
    case 4: "Copy details"
    case 5: "Folders"
    case 6: "Capture file"
    case 7: "Open image"
    case _: ""

def folder_side_label(index: U32) -> String:
  match index:
    case 0: "Back to attachment"
    case 1: "Use folder"
    case 2: "Add folder"
    case 3: "Enable folder"
    case 4: "Disable folder"
    case 5: "Reload folders"
    case 6: "Previous folders"
    case 7: "Next folders"
    case _: ""
def folder_results(results: Results) -> Bool:
  match results:
    case AttachmentFoldersResults{_,_,_,_,_,_}: True{}
    case _: False{}
def attachment_label(results: Results,+index: U32) -> String:
  Bool.pick(String,folder_results(results),folder_side_label(index),attachment_side_label(index))
def attachment_top_result_index(results: Results,+index: U32) -> U32:
  Bool.pick(U32,folder_results(results),folder_top_index(index),attachment_top_index(index))

def attachment_side_color(results: Results,index: U32) -> U32:
  Bool.pick(U32,attachment_available(results,index),ink(),muted())

def attachment_top_label(index: U32) -> String:
  attachment_side_label(attachment_top_index(index))

def attachment_top_color(+results: Results,index: U32) -> U32:
  Bool.pick(U32,attachment_available(results,attachment_top_result_index(results,index)),accent(),muted())

# The toolbar owns repeated actions. The sidebar retains only the one action
# absent there, with the same existing target and availability gate.
def draw_attachment_side(c: C.Canvas,+results: Results) -> C.Canvas:
  +folders = folder_results(results)
  +index = Bool.pick(U32,folders,5,6)
  +y = G.sidebar_y(index)
  heading = text(c,Bool.pick(String,folders,"Capture folders","Attachments"),16,128,18,heading_ink(),rail())
  first = text(heading,Bool.pick(String,folders,"Choose which local","All references"),16,160,18,muted(),rail())
  second = text(first,Bool.pick(String,folders,"files can be saved","in these records."),16,184,18,muted(),rail())
  third = text(second,Bool.pick(String,folders,"Saved copies stay","No URLs are"),16,224,18,muted(),rail())
  fourth = text(third,Bool.pick(String,folders,"after disabling.","downloaded."),16,248,18,muted(),rail())
  base = box(fourth,8,y,160,32,rail())
  text(base,attachment_label(results,index),16,U32.add(y,8),18,attachment_side_color(results,index),rail())

def draw_attachment_top(fuel: Nat,c: C.Canvas,+index: U32,+results: Results) -> C.Canvas:
  match fuel:
    case 0n: c
    case 1n+n:
      label = toolbar_button(c,toolbar_region(results,index),attachment_label(results,attachment_top_result_index(results,index)))
      draw_attachment_top(n,label,U32.add(index,1),results)

def draw_attachment_side_context(attachments: Bool,quota: Bool,c: C.Canvas,results: Results,files: Bool,settings: Bool,scope: String,brief: Bool) -> C.Canvas:
  match attachments:
    case True{}: draw_attachment_side(c,results)
    case False{}: draw_side_context(quota,c,results,files,settings,scope,brief)

def draw_navigation_mode(+c: C.Canvas,+s: State,+results: Results,+files: Bool,+scope: String,+workspace: Bool) -> C.Canvas:
  match workspace:
    case True{}: draw_workspace_side(U32.to_nat(G.sidebar_rows()),c,s,0)
    case False{}: draw_attachment_side_context(is_attachments(s) || is_attachment_folders(s),is_quota(s),c,results,files,is_settings(s),scope,is_brief(s))

def draw_navigation(+c: C.Canvas,+s: State,+results: Results,+files: Bool,+scope: String) -> C.Canvas:
  draw_navigation_mode(c,s,results,files,scope,history_workspace(s))

def draw_attachment_top_context(attachments: Bool,quota: Bool,c: C.Canvas,results: Results,files: Bool,settings: Bool,whole: Bool,automatic: String,brief: Bool) -> C.Canvas:
  match attachments:
    case True{}: draw_attachment_top(7n,c,0,results)
    case False{}: draw_top_context(quota,c,results,files,settings,whole,automatic,brief)

def library_top_label(capture: Bool,index: U32) -> String:
  match capture:
    case True{}:
      match index:
        case 0: "Back to usage"
        case 1: "Session usage"
        case 2: "Attachments"
        case 3: "Why"
        case 4: "Export evidence"
        case 5: "Previous page"
        case _: "Next page"
    case False{}:
      match index:
        case 0: "Reload usage"
        case 1: "Cancel"
        case 2: "All providers"
        case 3: "Claude"
        case 4: "Codex"
        case 5: "Back"
        case _: "Open capture"

def draw_library_top(fuel: Nat,c: C.Canvas,+index: U32,+phase: U32) -> C.Canvas:
  match fuel:
    case 0n: c
    case 1n+rest:
      named = toolbar_button(c,G.top_region(index,U32.is_ne(phase,5) || U32.is_eq(index,0)),library_top_label(U32.is_ge(phase,5),index))
      draw_library_top(rest,named,U32.add(index,1),phase)

def draw_library_top_context(+s: State,c: C.Canvas,+results: Results,files: Bool,automatic: String,+phase: U32) -> C.Canvas:
  match phase:
    case 0: draw_attachment_top_context(is_attachments(s) || is_attachment_folders(s),is_quota(s),c,results,files,is_settings(s),whole_usage(s),automatic_label(results,automatic),is_brief(s))
    case _: draw_library_top(7n,c,0,phase)

def draw_attachment_entry(c: C.Canvas,visible: Bool) -> C.Canvas:
  match visible:
    case False{}: c
    case True{}:
      chrome_text(c,"Attachments",U32.add(G.attachment_entry_x(),8),G.text_actions_y(),U32.mul(G.attachment_entry_columns(),8),0,accent(),paper())

def query_label_normal(+s: State) -> String:
  Bool.pick(String,is_attachments(s),"Captured record scope",Bool.pick(String,is_quota(s),"Selected Juice Bend data directory",Bool.pick(String,is_brief(s),"Repository folder for this brief",
    Bool.pick(String,is_settings(s),"Source file or folder path",Bool.pick(String,is_files(s),"Repository folder path","Search captured history")))))

def query_label(+s: State) -> String:
  Bool.pick(String,is_library_usage(s),"Library usage · all time",Bool.pick(String,is_attachment_folders(s),"Explicit attachment capture folder path",query_label_normal(s)))

def draw_status(modal: Bool,+s: State,c: C.Canvas) -> C.Canvas:
  match modal:
    case False{}: c
    case True{}:
      State{content,Input{selected,scroll,Edit{focus,+caret,+anchor,drag,viewport},command,shift},image,dirty} = s
      base = box(c,G.list_end(),G.header_height(),U32.sub(G.width(),G.list_end()),G.body_height(),paper())
      label = text(base,"Current status · Scroll · Esc to return",G.reader_x(),128,G.status_heading_columns(),accent(),paper())
      copy = text(label,"Copy and close",U32.add(G.status_copy_x(),8),128,21,accent(),paper())
      close = text(copy,"Close",U32.add(G.status_close_x(),8),128,11,accent(),paper())
      draw_reader(U32.to_nat(G.reader_rows()),close,List.drop(&2,Line,wrap(status_text(s)),U32.to_nat(U32.min(viewport,minus(U32.from_nat(List.length(&2,Line,wrap(status_text(s)))),G.reader_rows())))),U32.div(G.reader_y(),G.cell()),0,0)

def capture_hint(suspended: Bool) -> String:
  Bool.pick(String,suspended,"Capture suspended","")

def draw_capture_hint(c: C.Canvas,+suspended: Bool) -> C.Canvas:
  first = text(c,capture_hint(suspended),G.capture_hint_x(),80,G.capture_hint_columns(),muted(),rail())
  text(first,Bool.pick(String,suspended,"Back to History",""),G.capture_hint_x(),96,G.capture_hint_columns(),muted(),rail())

def draw_capture_context(quota: Bool,c: C.Canvas,+suspended: Bool) -> C.Canvas:
  match quota:
    case False{}: draw_capture_hint(c,suspended)
    case True{}:
      first = text(c,capture_hint(suspended),G.capture_hint_x(),80,G.capture_hint_columns(),muted(),rail())
      text(first,"Local quota only",G.capture_hint_x(),96,G.capture_hint_columns(),muted(),rail())

def draw_scope_field(attachments: Bool,c: C.Canvas,s: State,q: String,+focus: U32,+caret: U32,+anchor: U32) -> C.Canvas:
  match attachments:
    case True{}: text(c,"All attachment references in these captured records · repository, role and time filters do not apply",G.query_x(),G.query_y(),G.query_columns(),muted(),paper())
    case False{}:
      +offset = query_offset(s)
      draw_line(U32.to_nat(G.query_columns()),c,String.append(String.drop(q,U32.to_nat(offset))," "),U32.div(G.query_x(),G.cell()),U32.div(G.query_y(),G.cell()),offset,Bool.pick(U32,U32.is_eq(focus,0),U32.min(caret,anchor),0),Bool.pick(U32,U32.is_eq(focus,0),Bool.pick(U32,U32.is_eq(caret,anchor),U32.add(caret,1),U32.max(caret,anchor)),0))

def draw_library_scope(+s: State,c: C.Canvas,q: String,focus: U32,caret: U32,anchor: U32,library: Bool) -> C.Canvas:
  match library:
    case True{}: text(c,"All time · recorded usage in retained captures · unknown counters remain unknown",G.query_x(),G.query_y(),G.query_columns(),muted(),paper())
    case False{}: draw_scope_field(is_attachments(s),c,s,q,focus,caret,anchor)

def draw_list_pager(hidden: Bool,c: C.Canvas,+results: Results) -> C.Canvas:
  match hidden:
    case True{}: c
    case False{}:
      prev = text(c,"Previous",192,G.list_pager_y(),16,Bool.pick(U32,result_available(results,False{}),accent(),muted()),panel())
      text(prev,"Next",360,G.list_pager_y(),16,Bool.pick(U32,result_available(results,True{}),accent(),muted()),panel())

def query_action_label(+s: State,paste: Bool) -> String:
  +path = is_files(s) || is_settings(s) || is_brief(s) || is_attachment_folders(s)
  Bool.pick(String,paste,Bool.pick(String,path,"Paste path","Paste query"),Bool.pick(String,path,"Clear path","Clear query"))

def draw_query_actions(+attachments: Bool,+c: C.Canvas,+s: State) -> C.Canvas:
  match attachments:
    case True{}: c
    case False{}:
      paste = chrome_text(c,query_action_label(s,True{}),U32.add(G.text_action_x(1),8),G.text_actions_y(),88,0,accent(),paper())
      chrome_text(paste,query_action_label(s,False{}),U32.add(G.text_action_x(2),8),G.text_actions_y(),88,0,accent(),paper())

def draw_library_mode(visible: Bool,+s: State,c: C.Canvas) -> C.Canvas:
  match visible:
    case False{}: c
    case True{}:
      chrome_text(c,Bool.pick(String,library_overview(s),"Report","Overview"),U32.add(G.text_action_x(1),8),G.text_actions_y(),88,0,accent(),paper())

def draw_child_entry(c: C.Canvas,visible: Bool) -> C.Canvas:
  match visible:
    case True{}: chrome_text(box(c,1008,0,168,24,panel()),"Child results",1016,0,152,0,accent(),panel())
    case False{}: c

def draw_canvas_capture(+s: State,automatic: String,suspended: Bool) -> C.Canvas:
  State{Content{+q,rows,reader,lines,title,status,+scope,+results,+files,cards},Input{+selected,scroll,Edit{+focus,+caret,+anchor,drag,viewport},command,shift},image,dirty} = s
  base = box(C.Flat{paper()},0,0,G.width(),G.header_height(),rail())
  side = box(base,0,0,G.sidebar_end(),G.footer_y(),Bool.pick(U32,history_workspace(s),Palette.navigation_paper(),rail()))
  list = box(side,G.sidebar_end(),G.header_height(),U32.sub(G.list_end(),G.sidebar_end()),G.body_height(),panel())
  foot = box(list,0,G.footer_y(),G.width(),40,rail())
  +brand_bg = Bool.pick(U32,history_workspace(s),Palette.navigation_paper(),rail())
  +brand_fg = Bool.pick(U32,history_workspace(s),Palette.navigation_ink(),heading_ink())
  brand = chrome_text(foot,"Juice Bend",16,16,144,2,brand_fg,brand_bg)
  tagline = chrome_text(brand,"Your captured work",16,48,144,0,Bool.pick(U32,history_workspace(s),Palette.navigation_muted(),muted()),brand_bg)
  input_label = chrome_text(tagline,query_label(s),192,0,480,0,muted(),rail())
  child_entry = draw_child_entry(input_label,child_entry_visible(s))
  query_bg = box(child_entry,G.query_left(),24,U32.sub(G.query_right(),G.query_left()),40,paper())
  query = draw_library_scope(s,query_bg,q,focus,caret,anchor,is_library_usage(s))
  top = draw_library_top_context(s,query,results,files,automatic,library_phase(s))
  capture = draw_capture_context(is_quota(s),top,suspended)
  navigation = draw_navigation(capture,s,results,files,scope)
  range = draw_list_header(navigation,s,results,files)
  next = draw_list_pager(is_attachments(s) || is_attachment_folders(s) || is_library_usage(s),range,results)
  title = chrome_text(next,Palette.heading(title),G.reader_x(),120,U32.mul(reader_title_columns(s),8),1,heading_ink(),paper())
  entry = draw_attachment_entry(title,attachment_entry_visible(s))
  copy = chrome_text(entry,Bool.pick(String,library_has_summary(s),"Copy report","Copy"),U32.add(G.text_action_x(0),8),G.text_actions_y(),80,0,accent(),paper())
  clear = draw_query_actions(is_attachments(s) || is_library_usage(s),copy,s)
  mode = draw_library_mode(library_has_summary(s),s,clear)
  all = chrome_text(mode,"Select all",U32.add(G.text_action_x(3),8),G.text_actions_y(),88,0,accent(),paper())
  +offset = minus(selected,U32.sub(G.list_rows(),1))
  items = draw_rows(U32.to_nat(G.list_rows()),all,List.drop(&2,String,rows,U32.to_nat(offset)),0,minus(selected,offset),provider_chips_visible(s))
  body = draw_reader_context(s,items,lines,scroll,Bool.pick(U32,U32.is_eq(focus,2),U32.min(caret,anchor),0),Bool.pick(U32,U32.is_eq(focus,2),U32.max(caret,anchor),0))
  +summary = String.join(String.lines(status)," ")
  status1 = text(body,String.take(summary,U32.to_nat(G.footer_columns())),8,G.footer_y(),G.footer_columns(),muted(),rail())
  status2 = text(status1,String.take(String.drop(summary,U32.to_nat(G.footer_columns())),U32.to_nat(G.footer_second_columns())),8,U32.add(G.footer_y(),16),G.footer_second_columns(),muted(),rail())
  hint = text(status2,"Click status for details",G.footer_hint_x(),U32.add(G.footer_y(),16),25,accent(),rail())
  draw_status(U32.is_ge(focus,3),s,hint)

def draw_automatic_capture(s: State,automatic: String,suspended: Bool) -> Image:
  canvas.image(draw_canvas_capture(s,automatic,suspended))

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

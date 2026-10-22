import Base
import ./providers.bend as Providers
import ./reader_document.bend as Reader

# One canonical transcript string supplies rendering, selection, copy and
# bounded export. These helpers only arrange already verified event fields.
type Page is Data:
  Page{visible: U32,body: String,details: String}

# Typed fragments are made from verified provider fields before concatenation.
# Reader cards may split MessageText into code spans; canonical formatting does
# not inspect user text for role/reference headings.
type Fragment is Data:
  Fragment{kind: Reader.PartKind,text: String,collapsible: Bool}

def fragment_text(fragments: List<&2,Fragment>) -> String:
  match fragments:
    case []: ""
    case Fragment{_,text,_} <> rest: text ++ fragment_text(rest)

def nonempty(value: String,fallback: String) -> String:
  match value:
    case "": fallback
    case _: value

def field(label: String,value: String) -> String:
  match value:
    case "": ""
    case _: label ++ ": " ++ value ++ "\n"

def warning(coverage: String) -> String:
  match coverage:
    case "complete": ""
    case "": " · coverage unavailable"
    case _: " · coverage: " ++ coverage

def reference(ordinal: String,index: U32) -> String:
  "[r" ++ ordinal ++ ":e" ++ U32.show(index) ++ "]"

# Exact captured timestamps remain in the details appendix. Keep missing-time
# and incomplete-coverage notices beside each event; neither is a zero/default.
def time_notice(time: String) -> String:
  match time:
    case "": " · time not captured"
    case _: ""

def fragments(reference: String,event: Providers.Record) -> List<&2,Fragment>:
  Providers.ProviderEvent{role,text,tool,callid,args,result,_,_,time,_,_,_,coverage} = event
  [Fragment{Reader.EventHeading{},"[" ++ nonempty(role,"event") ++ "] · " ++ reference ++
    time_notice(time) ++ warning(coverage) ++ "\n",False{}},
   Fragment{Reader.MessageText{},text ++ "\n",False{}},
   Fragment{Reader.ToolName{},field("Tool",tool) ++ field("Call ID",callid),False{}},
   Fragment{Reader.ToolArguments{},field("Arguments",args),True{}},
   Fragment{Reader.ToolResult{},field("Result",result),True{}},
   Fragment{Reader.MessageText{},"\n",False{}}]

def body(reference: String,event: Providers.Record) -> String:
  fragment_text(fragments(reference,event))

def details(reference: String,event: Providers.Record,identity: String) -> String:
  Providers.ProviderEvent{role,_,_,_,_,_,repo,session,time,model,usage,parent,coverage} = event
  reference ++ "\n" ++ field("Role",role) ++ field("Recorded time",time) ++
    field("Captured repository",repo) ++ field("Session reference",session) ++
    field("Recorded model",model) ++
    field("Recorded usage (source fact; mirrors are not additive)",usage) ++
    field("Parent reference",parent) ++ "Coverage: " ++ nonempty(coverage,"unavailable") ++
    "\n" ++ identity ++ "\n\n"

def entry(+reference: String,+event: Providers.Record,identity: String) -> Page:
  Page{1,body(reference,event),details(reference,event,identity)}

def join(left: Page,right: Page) -> Page:
  Page{a,body_a,details_a} = left
  Page{b,body_b,details_b} = right
  Page{U32.add(a,b),body_a ++ body_b,details_a ++ details_b}

def events(records: List<&2,Providers.Record>,+ordinal: String,+index: U32,+identity: String) -> Page:
  match records:
    case []: Page{0,"",""}
    case event <> rest:
      join(entry(reference(ordinal,index),event,identity),
        events(rest,ordinal,U32.inc(index),identity))

def record(records: List<&2,Providers.Record>,ordinal: String,identity: String) -> Page:
  match records:
    case []:
      Page{0,"",identity ++ "\nNo displayable transcript event in this captured record.\n\n"}
    case _:
      events(records,ordinal,0,identity)

def conversation(visible: U32,text: String) -> String:
  match visible:
    case 0: "No transcript events in this captured page.\n\n"
    case _: text

def heading(visible: U32,snapshot: String) -> String:
  "Captured page · " ++ U32.show(visible) ++ " events · snapshot " ++ snapshot ++ "\n\n"

def appendix(page_details: String) -> String:
  "Page details & exact references\n" ++ page_details ++ "\n\n"

def render(page: Page,snapshot: String,page_details: String) -> String:
  Page{+visible,text,details} = page
  heading(visible,snapshot) ++ conversation(visible,text) ++ appendix(page_details) ++ details

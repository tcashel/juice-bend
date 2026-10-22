import Base
import ./providers.bend as Providers

# One canonical transcript string supplies rendering, selection, copy and
# bounded export. These helpers only arrange already verified event fields.
type Page is Data:
  Page{visible: U32,body: String,details: String}

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

def body(reference: String,event: Providers.Record) -> String:
  Providers.ProviderEvent{role,text,tool,callid,args,result,_,_,time,_,_,_,coverage} = event
  "[" ++ nonempty(role,"event") ++ "] · " ++ reference ++
    time_notice(time) ++ warning(coverage) ++ "\n" ++ text ++ "\n" ++
    field("Tool",tool) ++ field("Call ID",callid) ++ field("Arguments",args) ++
    field("Result",result) ++ "\n"

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

def render(page: Page,snapshot: String,page_details: String) -> String:
  Page{+visible,text,details} = page
  "Captured page · " ++ U32.show(visible) ++ " events · snapshot " ++ snapshot ++ "\n\n" ++
    conversation(visible,text) ++ "Page details & exact references\n" ++
    page_details ++ "\n\n" ++ details

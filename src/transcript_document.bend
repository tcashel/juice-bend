import Base
import ./providers.bend as Providers
import ./transcript_format.bend as Format
import ./reader_document.bend as Reader
import ./reader_fences.bend as Fences

# Input records are supplied only after the existing capture/scope verification.
# Record ordinals and snapshots stay exact strings; no identity is reconstructed
# by parsing the rendered transcript. Existing CLI/export text stays canonical.
type IndexedEvent is Data:
  IndexedEvent{index: U32,value: Providers.Record}

type Input is Data:
  Record{ordinal: String,events: List<&2,IndexedEvent>,identity: String}

# Complete records can use this convenience constructor. Scoped reads instead
# supply IndexedEvent{original_index,value}; filtering never renumbers citations.
def index_all(events: List<&2,Providers.Record>,+index: U32) -> List<&2,IndexedEvent>:
  match events:
    case []: []
    case value <> rest: IndexedEvent{index,value} <> index_all(rest,U32.inc(index))

def record_all(ordinal: String,events: List<&2,Providers.Record>,identity: String) -> Input:
  Record{ordinal,index_all(events,0),identity}

type Chunk is Data:
  Chunk{key: Reader.PartKey,kind: Reader.PartKind,text: String,role: String,tool: String,collapsible: Bool}

type Prepared is Data:
  Prepared{visible: U32,body: List<&2,Chunk>,details: List<&2,Chunk>}

type Placed is Data:
  Placed{canonical: String,parts: List<&2,Reader.Part>}

def expand(fragments: List<&2,Format.Fragment>) -> List<&2,Format.Fragment>:
  match fragments:
    case []: []
    case Format.Fragment{Reader.MessageText{},text,_} <> rest:
      List.append(&2,Format.Fragment,Fences.split(text),expand(rest))
    case part <> rest: part <> expand(rest)

def keyed(fragments: List<&2,Format.Fragment>,+snapshot: String,+ordinal: String,+event: U32,+index: U32,+role: String,+tool: String) -> List<&2,Chunk>:
  match fragments:
    case []: []
    case Format.Fragment{_,"",_} <> rest:
      keyed(rest,snapshot,ordinal,event,index,role,tool)
    case Format.Fragment{kind,text,collapsible} <> rest:
      Chunk{Reader.PartKey{snapshot,ordinal,event,index},kind,text,role,tool,collapsible} <>
        keyed(rest,snapshot,ordinal,event,U32.inc(index),role,tool)

def entry(+snapshot: String,+ordinal: String,+index: U32,+event: Providers.Record,identity: String) -> Prepared:
  Providers.ProviderEvent{+role,_,+tool,_,_,_,_,_,_,_,_,_,_} = event
  +reference = Format.reference(ordinal,index)
  Prepared{1,keyed(expand(Format.fragments(reference,event)),snapshot,ordinal,index,0,role,tool),
    [Chunk{Reader.PartKey{snapshot,ordinal,index,4294967295},Reader.EvidenceDetails{},
      Format.details(reference,event,identity),role,tool,True{}}]}

def join(left: Prepared,right: Prepared) -> Prepared:
  Prepared{a,body_a,details_a} = left
  Prepared{b,body_b,details_b} = right
  Prepared{U32.add(a,b),List.append(&2,Chunk,body_a,body_b),List.append(&2,Chunk,details_a,details_b)}

def events(items: List<&2,IndexedEvent>,+snapshot: String,+ordinal: String,+identity: String) -> Prepared:
  match items:
    case []: Prepared{0,[],[]}
    case IndexedEvent{index,event} <> rest:
      join(entry(snapshot,ordinal,index,event,identity),events(rest,snapshot,ordinal,identity))

def record(input: Input,+snapshot: String) -> Prepared:
  Record{+ordinal,records,+identity} = input
  match records:
    case []:
      Prepared{0,[],[Chunk{Reader.PartKey{snapshot,ordinal,0,4294967295},Reader.EvidenceDetails{},
        identity ++ "\nNo displayable transcript event in this captured record.\n\n","","",True{}}]}
    case _: events(records,snapshot,ordinal,identity)

def records(inputs: List<&2,Input>,+snapshot: String) -> Prepared:
  match inputs:
    case []: Prepared{0,[],[]}
    case input <> rest: join(record(input,snapshot),records(rest,snapshot))

def placed(text: String,part: Reader.Part,tail: Placed) -> Placed:
  Placed{rest,parts} = tail
  Placed{text ++ rest,part <> parts}

def place(chunks: List<&2,Chunk>,+offset: U32) -> Placed:
  match chunks:
    case []: Placed{"",[]}
    case Chunk{_,_,"",_,_,_} <> rest: place(rest,offset)
    case Chunk{key,kind,+text,role,tool,collapsible} <> rest:
      +length = Reader.length(text)
      placed(text,Reader.Part{key,kind,Reader.Span{offset,length},role,tool,collapsible},
        place(rest,U32.add(offset,length)))

def conversation(visible: U32,body: List<&2,Chunk>,snapshot: String) -> List<&2,Chunk>:
  match visible:
    case 0:
      [Chunk{Reader.PartKey{snapshot,"",4294967295,2},Reader.PageNotice{},
        Format.conversation(0,""),"","",False{}}]
    case _: body

def admit(placed: Placed,revision: U32) -> Reader.Document:
  Placed{canonical,parts} = placed
  Reader.admit(canonical,revision,parts)

def page(prepared: Prepared,+snapshot: String,page_details: String,revision: U32) -> Reader.Document:
  Prepared{+visible,body,details} = prepared
  chunks : List<&2,Chunk> = Chunk{Reader.PartKey{snapshot,"",4294967295,0},Reader.PageNotice{},
    Format.heading(visible,snapshot),"","",False{}} <>
    List.append(&2,Chunk,conversation(visible,body,snapshot),
      Chunk{Reader.PartKey{snapshot,"",4294967295,1},Reader.PageNotice{},
        Format.appendix(page_details),"","",False{}} <> details)
  admit(place(chunks,0),revision)

def render(inputs: List<&2,Input>,+snapshot: String,page_details: String,revision: U32) -> Reader.Document:
  page(records(inputs,snapshot),snapshot,page_details,revision)

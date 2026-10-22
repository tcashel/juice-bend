import Base
import ./attachment_preview_external_packet.bend as Packet
import ./attachment_asset_types.bend as T
import ./attachment_asset_identity.bend as I
import ./attachment_inventory_output.bend as Output
import ./archive_meta.bend as Meta
import ./gui_attachments.bend as G
import ./json.bend as J

# A retained receipt alone is not the current user selection. Match the saved
# captured page and exact physical interval/reference/path before worker launch.
def header(value: T.Receipt) -> Meta.Header:
  T.Receipt{I.Resolved{capture,_,_,_,_,_,_,_,_},_,_,_,_,_,_} = value
  capture

def key_matches(key: G.OccurrenceKey,receipt: T.Receipt) -> Bool:
  G.OccurrenceKey{record,reference,path,offset,length,digest,_,_,_} = key
  T.Receipt{I.Resolved{_,actual_record,actual_offset,actual_length,actual_digest,actual_reference,actual_path,_,_},_,_,_,_,_,_} = receipt
  U32.is_eq(record,actual_record) && U32.is_eq(reference,actual_reference) && String.eq(path,actual_path) &&
    U32.is_eq(offset,actual_offset) && U32.is_eq(length,actual_length) && String.eq(digest,actual_digest)

def capture_matches(capture: J.Json,expected: Result<&2,&2,String,J.Json>) -> Bool:
  match expected:
    case Fail{_}: False{}
    case Done{value}: G.same_capture(capture,value)

def chosen(valid: Bool,value: Packet.External) -> Maybe<&2,Packet.External>:
  match valid:
    case True{}: Some{value}
    case False{}: None{}

def page(page: List<&2,G.Page>,key: Maybe<&2,G.OccurrenceKey>,+anchor: G.Anchor,+receipt: T.Receipt) -> Maybe<&2,Packet.External>:
  match page key:
    case G.Page{+capture,_,_,_,_,_,_} <> [] Some{+key}:
      G.Anchor{selected_snapshot,+start,count} = anchor
      T.Receipt{+occurrence,_,_,_,_,_,_} = receipt
      I.Resolved{Meta.Header{+snapshot,_,_,_,_,_,_,_,_,_,_},+record,_,_,_,_,_,_,_} = occurrence
      +expected : Packet.External = Packet.External{I.request(occurrence),receipt}
      chosen(Packet.expected_valid(expected) && G.anchor_valid(anchor) && String.eq(snapshot,selected_snapshot) &&
        U32.is_ge(record,start) && U32.is_lt(U32.sub(record,start),count) && G.capture_valid(capture,snapshot) &&
        capture_matches(capture,J.parse(Output.capture(header(receipt)))) && key_matches(key,receipt),expected)
    case _ _: None{}

def ready(ready: Bool,+model: G.Model,receipt: T.Receipt) -> Maybe<&2,Packet.External>:
  match ready:
    case False{}: None{}
    case True{}: page(G.page(model),G.key(G.selected(model)),G.anchor(model),receipt)

def selected(model: Maybe<&2,G.Model>,receipt: Maybe<&2,T.Receipt>) -> Maybe<&2,Packet.External>:
  match model receipt:
    case Some{+model} Some{receipt}: ready(U32.is_eq(G.phase(model),2),model,receipt)
    case _ _: None{}

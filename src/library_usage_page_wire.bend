import Base
import ./json.bend as J
import ./gui_settings.bend as Shape
import ./domain.bend as Domain
import ./session_usage.bend as S
import ./session_usage_claude.bend as Claude
import ./library_usage_wire.bend as Summary
import ./reader_document.bend as Reader
import ./reader_wire.bend as ReaderWire

# The caller admits a <=2 MiB raw response before JSON parsing. Required page
# identity and canonical text are authoritative; reader metadata is optional.
type Page is Data:
  Page{capture: S.Capture,start: U32,selected: U32,text: String,document: Reader.Document}

def check(valid: Bool) -> Result<&2,&2,String,Unit>:
  match valid:
    case True{}: Done{Unit{}}
    case False{}: Fail{"Library Usage capture page does not match the exact requested capture, range or text bounds."}

def canonical(value: J.Json) -> Result<&2,&2,String,String>:
  match value:
    case J.JString{+text}:
      do Result<&2,&2,String,String>:
        Unit <- check(Claude.fits_result(Claude.remaining(text,1048576)))
        return text
    case _: Fail{"Library Usage capture page is missing its canonical text string."}

def page_shape(+value: J.Json) -> Bool:
  Shape.exact_object(value,["snapshot","start","requested_records","selected_records","kind","byte_space","complete_export","text"]) ||
    Shape.exact_object(value,["snapshot","start","requested_records","selected_records","kind","byte_space","complete_export","text","reader_view"])

def page(+value: J.Json,+capture: S.Capture,+start: U32,revision: U32) -> Result<&2,&2,String,Page>:
  S.Capture{_,_,_,_,+snapshot,_,records} = capture
  do Result<&2,&2,String,Page>:
    Unit <- check(page_shape(value) && Shape.text_is(J.field(value,"snapshot"),snapshot) &&
      Shape.text_is(J.field(value,"kind"),"scoped_transcript_page") && Shape.text_is(J.field(value,"byte_space"),"logical_source_bytes") &&
      Shape.bool_is(J.field(value,"complete_export"),False{}) && Shape.number_is(J.field(value,"requested_records"),"40"))
    actual_start : U32 <- Summary.number(J.field(value,"start"),4294967295)
    +selected : U32 <- Summary.number(J.field(value,"selected_records"),40)
    Unit <- check(U32.is_eq(actual_start,start) && U32.is_eq(selected,Domain.bounded_count(start,40,records)))
    +text : String <- canonical(J.field(value,"text"))
    return Page{capture,start,selected,text,ReaderWire.decode_for(text,J.field(value,"reader_view"),revision,snapshot)}

def decode(+value: J.Json,+nonce: U32,+capture: S.Capture,start: U32,revision: U32) -> Result<&2,&2,String,Page>:
  do Result<&2,&2,String,Page>:
    Unit <- check(Shape.exact_object(value,["kind","version","nonce","capture","page"]) &&
      Shape.text_is(J.field(value,"kind"),"library_usage_capture") && Shape.number_is(J.field(value,"version"),"1"))
    actual_nonce : U32 <- Summary.number(J.field(value,"nonce"),4294967295)
    actual_capture : S.Capture <- Summary.parse_capture(J.field(value,"capture"))
    Unit <- check(U32.is_gt(nonce,0) && U32.is_eq(actual_nonce,nonce) && Summary.same_capture(actual_capture,capture))
    page(J.field(value,"page"),capture,start,revision)

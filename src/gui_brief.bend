# Native continuation-brief protocol. No capture, redaction or Git policy here.
import Base
import ./json.bend as Json
import ./query.bend as Query
import ./gui_files.bend as Files
import ./gui_relations.bend as Related
import ./gui_settings.bend as Shape
import ./domain.bend as Domain

type Anchor is Data:
  Anchor{snapshot: String,start: U32,count: U32,filters: Query.Filters}

type Preview is Data:
  Preview{commitment: String,text: String,bytes: U32}

type Choice is Data:
  Whole{}
  Selected{first: U32,last: U32}

type Model is Data:
  Model{anchor: Anchor,root: String,nonce: U32,phase: U32,preview: Maybe<&2,Preview>,choice: Choice}

def protocol() -> String: "juice-bend-brief-transport-v1"

def anchor(+model: Model) -> Anchor:
  Model{+anchor,_,_,_,_,_} = model
  anchor

def phase(+model: Model) -> U32:
  Model{_,_,_,+phase,_,_} = model
  phase

def nonce(+model: Model) -> String:
  Model{_,_,+nonce,_,_,_} = model
  U32.show(nonce)

def root(+model: Model) -> String:
  Model{_,+root,_,_,_,_} = model
  root

def valid_root(+root: String) -> Bool:
  String.starts_with(root,"/") && Bool.not(String.contains(root,"\0")) && Related.fits(root,4096)

def edit(+model: Model,+root: String) -> Model:
  Model{+anchor,_,+nonce,_,_,_} = model
  Model{anchor,root,U32.inc(nonce),0,None{},Whole{}}

def preparing(+model: Model) -> Model:
  Model{+anchor,+root,+nonce,_,_,_} = model
  Model{anchor,root,U32.inc(nonce),1,None{},Whole{}}

def checking(+model: Model,+export: Bool,+choice: Choice) -> Model:
  Model{+anchor,+root,+nonce,+phase,+preview,+oldchoice} = model
  Model{anchor,root,U32.inc(nonce),Bool.pick(U32,export,4,3),preview,choice}

def ready(+model: Model,+preview: Preview) -> Model:
  Model{+anchor,+root,+nonce,_,_,_} = model
  Model{anchor,root,nonce,2,Some{preview},Whole{}}

def preview_phase(+preview: Maybe<&2,Preview>) -> U32:
  match preview:
    case Some{_}: 2
    case None{}: 0

def failed(+model: Model) -> Model:
  Model{+anchor,+root,+nonce,+phase,+preview,+oldchoice} = model
  Model{anchor,root,nonce,preview_phase(preview),preview,Whole{}}

def input(+anchor: Anchor,+root: String) -> String:
  Anchor{+snapshot,+start,+count,Query.Filters{_,+provider,+repo,+role,+after}} = anchor
  "{\"snapshot\":" ++ Json.quote(snapshot) ++ ",\"start\":" ++ Json.quote(U32.show(start)) ++
    ",\"count\":" ++ Json.quote(U32.show(count)) ++ ",\"scope\":{\"provider\":" ++ Json.quote(provider) ++
    ",\"repository\":" ++ Json.quote(repo) ++ ",\"role\":" ++ Json.quote(role) ++ ",\"after\":" ++ Json.quote(after) ++
    "},\"repository\":" ++ Json.quote(root) ++ "}"

def check_fields(+phase: U32,+preview: Maybe<&2,Preview>) -> String:
  match phase preview:
    case 1 _: ""
    case _ Some{Preview{+commitment,+text,+bytes}}:
      ",\"commitment\":" ++ Json.quote(commitment) ++ ",\"text\":" ++ Json.quote(text)
    case _ _: ""

def body(+model: Model) -> String:
  Model{+anchor,+root,+nonce,+phase,+preview,+oldchoice} = model
  "{\"protocol\":" ++ Json.quote(protocol()) ++ ",\"input\":" ++ input(anchor,root) ++
    check_fields(phase,preview) ++ "}"

def args(+model: Model) -> List<&2,String>:
  [Bool.pick(String,U32.is_eq(phase(model),1),"brief-prepare","brief-check"),body(model)]

def hex_chars(+value: String) -> Bool:
  match value:
    case SNil{}: True{}
    case SCon{Chr{+cp},+rest}:
      ((cp >= 48 && cp <= 57 : U32) || (cp >= 97 && cp <= 102 : U32)) && hex_chars(rest)

def commitment(+value: String) -> Bool:
  Nat.is_eq(String.length(value),64n) && hex_chars(value)

def bytes(+value: String) -> U32:
  match value:
    case SNil{}: 0
    case SCon{Chr{+cp},+rest}: U32.add(U32.inc(Domain.encode_width(cp)),bytes(rest))

def uint_text(+value: Json.Json) -> Bool:
  Files.text_valid(value) && Files.number_valid(Json.JNumber{Json.text(value)})

def same_anchor(+value: Json.Json,+anchor: Anchor) -> Bool:
  Anchor{+snapshot,+start,+count,+filters} = anchor
  Shape.text_is(Json.field(value,"snapshot"),snapshot) && Shape.text_is(Json.field(value,"start"),U32.show(start)) &&
    Shape.text_is(Json.field(value,"count"),U32.show(count))

def schema(+value: Json.Json,+model: Model) -> Bool:
  Shape.exact_object(value,["protocol","kind","snapshot","start","count","commitment","text","utf8_bytes"]) &&
    Shape.text_is(Json.field(value,"protocol"),protocol()) &&
    Shape.text_is(Json.field(value,"kind"),Bool.pick(String,U32.is_eq(phase(model),1),"prepared","checked")) &&
    same_anchor(value,anchor(model)) && Files.text_valid(Json.field(value,"commitment")) && commitment(Json.get(value,"commitment")) &&
    Related.nonempty(Json.field(value,"text")) && uint_text(Json.field(value,"utf8_bytes")) &&
    String.eq(Json.get(value,"utf8_bytes"),U32.show(bytes(Json.get(value,"text"))))

def same_preview(+value: Json.Json,+preview: Maybe<&2,Preview>) -> Bool:
  match preview:
    case Some{Preview{+commitment,+text,+bytes}}:
      Shape.text_is(Json.field(value,"commitment"),commitment) && Shape.text_is(Json.field(value,"text"),text) &&
        Shape.text_is(Json.field(value,"utf8_bytes"),U32.show(bytes))
    case _: False{}

def matches(+value: Json.Json,+model: Model) -> Bool:
  Model{_,_,_,+phase,+preview,_} = model
  match phase:
    case 1: True{}
    case 3: same_preview(value,preview)
    case 4: same_preview(value,preview)
    case _: False{}

def decoded(+value: Json.Json,+valid: Bool) -> Result<&2,&2,String,Preview>:
  match valid:
    case True{}: Done{Preview{Json.get(value,"commitment"),Json.get(value,"text"),Files.number(Json.get(value,"utf8_bytes"))}}
    case False{}: Fail{"Brief reply did not match its frozen range, protocol, commitment or exact text. Nothing was copied or exported."}

def decode(+value: Json.Json,+model: Model) -> Result<&2,&2,String,Preview>:
  decoded(value,schema(value,model) && matches(value,model))

def preview_text(+preview: Preview) -> String:
  Preview{_,+text,_} = preview
  text

def shown(+value: String) -> String:
  match value:
    case "": "all"
    case +value: value

def description(+anchor: Anchor) -> String:
  Anchor{+snapshot,+start,+count,Query.Filters{_,+provider,+repo,+role,+after}} = anchor
  "Snapshot " ++ snapshot ++ " | captured records " ++ U32.show(start) ++ " + " ++ U32.show(count) ++
    "\nByte offsets: logical source bytes (decompressed for archives)" ++
    "\nProvider: " ++ shown(provider) ++ " | Role: " ++ shown(role) ++ " | After: " ++ shown(after) ++
    "\nFrozen repository filter: " ++ shown(repo)

def guidance(+anchor: Anchor) -> String:
  "PREPARE A CONTINUATION BRIEF\n\n" ++ description(anchor) ++
    "\n\nEnter a repository folder above, then choose Prepare preview.\nOnly this exact captured range and scope are considered.\nThe repository narrows evidence; it never broadens the frozen filters.\n\nThe preview contains recorded facts and explicit uncertainty, not a generated task or summary.\nRecognized credentials and local paths are withheld; unrecognized sensitive text may remain.\nReview the whole preview before sharing. Copy and Export recheck its exact evidence.\n\nBack restores your reader, search, list position and text selection."

# A prefix keeps exact transcript range distinct from existing Tools identity.
def metadata_base(+args: List<&2,String>) -> List<&2,String>:
  match args:
    case "transcript-range-v1" <> +snap <> +start <> +requested <> +selected <> +rest: rest
    case +args: args

def range_metadata(+value: Json.Json,+snap: String,+start: U32) -> Bool:
  Shape.exact_object(value,["snapshot","start","requested_records","selected_records","kind","byte_space","complete_export","text"]) &&
    Shape.text_is(Json.field(value,"byte_space"),"logical_source_bytes") &&
    Shape.boolean(Json.field(value,"complete_export")) && Bool.not(String.eq(Json.get(value,"complete_export"),"true")) &&
    Files.text_valid(Json.field(value,"text")) && Shape.text_is(Json.field(value,"kind"),"scoped_transcript_page") && Shape.text_is(Json.field(value,"snapshot"),snap) &&
    Shape.number_is(Json.field(value,"start"),U32.show(start)) && Shape.number_is(Json.field(value,"requested_records"),"40") &&
    Files.number_valid(Json.field(value,"selected_records")) && U32.is_le(Files.number(Json.get(value,"selected_records")),40)

def range_args(+value: Json.Json,+snap: String,+start: U32,+prior: List<&2,String>) -> List<&2,String>:
  List.append(&2,String,["transcript-range-v1",snap,U32.show(start),"40",Json.get(value,"selected_records")],metadata_base(prior))

def selected_count(+args: List<&2,String>,+snapshot: String,+start: U32) -> U32:
  match args:
    case "transcript-range-v1" <> +snap <> +first <> "40" <> +count <> +rest:
      Bool.pick(U32,String.eq(snap,snapshot) && String.eq(first,U32.show(start)) && Files.number_valid(Json.JNumber{count}) &&
        U32.is_le(Files.number(count),40),Files.number(count),0)
    case _: 0

def choice(+model: Model) -> Choice:
  Model{_,_,_,_,_,+choice} = model
  choice

def selected_text(+preview: Preview,+choice: Choice) -> String:
  Preview{_,+text,_} = preview
  match choice:
    case Whole{}: text
    case Selected{+first,+last}: String.take(String.drop(text,U32.to_nat(first)),U32.to_nat(U32.sub(last,first)))

import Base
import ./json.bend as Json
import ./request_evidence.bend as Request

# Display metadata only. These titles never become user requests, normalized
# events, attribution, source identity or canonical transcript text.
type Title is Data:
  Other{}
  Recorded{text: String}
  Unavailable{}

def optional_string(value: Request.Lookup) -> Bool:
  match value:
    case Request.Missing{}: True{}
    case Request.Found{Json.JString{_}}: True{}
    case _: False{}

def same_or_empty(+a: String,+b: String) -> Bool:
  String.is_empty(a) || String.is_empty(b) || String.eq(a,b)

def metadata(+raw: Json.Json,+session: String) -> Bool:
  optional_string(Request.field(raw,"cwd")) &&
    optional_string(Request.field(raw,"repository")) &&
    optional_string(Request.field(raw,"sessionId")) &&
    optional_string(Request.field(raw,"session_id")) &&
    optional_string(Request.field(raw,"timestamp")) &&
    same_or_empty(Json.get(raw,"cwd"),Json.get(raw,"repository")) &&
    same_or_empty(Json.get(raw,"sessionId"),Json.get(raw,"session_id")) &&
    same_or_empty(session,Json.get(raw,"sessionId")) &&
    same_or_empty(session,Json.get(raw,"session_id"))

def title_value(value: Request.Lookup) -> Title:
  match value:
    case Request.Found{Json.JString{text}}: Recorded{text}
    case _: Unavailable{}

def ready(yes: Bool,raw: Json.Json) -> Title:
  match yes:
    case True{}: title_value(Request.field(raw,"aiTitle"))
    case False{}: Unavailable{}

def kind(value: Request.Lookup,+raw: Json.Json,session: String) -> Title:
  match value:
    case Request.Found{Json.JString{"ai-title"}}: ready(metadata(raw,session),raw)
    case Request.Found{Json.JString{_}}: Other{}
    case _: Unavailable{}

def recorded(+raw: Json.Json,session: String) -> Title:
  kind(Request.field(raw,"type"),raw,session)

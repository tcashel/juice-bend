import Base
import ./json.bend as Json

# One physical record can yield ordered text/tool events. Session context is
# carried by capture orchestration; IDs never merge records or source locators.
type Record is Data:
  ProviderEvent{role: String, text: String, tool: String, call_id: String, arguments: String, result: String, repository: String, session: String, timestamp: String, model: String, usage: String, parent: String, coverage: String}

def fallback(first: String, second: String) -> String:
  match first:
    case "":
      second
    case _:
      first

def value_text(value: Json.Json) -> String:
  match value:
    case Json.JString{text}:
      text
    case Json.JNull{}:
      ""
    case _:
      Json.encode(value)

def json_optional(value: Json.Json) -> String:
  match value:
    case Json.JNull{}:
      ""
    case _:
      Json.encode(value)

def content_parts(items: List<&2, Json.Json>) -> List<&2, String>:
  match items:
    case Nil{}:
      []
    case Con{item, rest}:
      Json.get(item, "text") <> content_parts(rest)

def text_block(kind: String) -> Bool:
  match kind:
    case "text":
      True{}
    case "input_text":
      True{}
    case "output_text":
      True{}
    case "summary_text":
      True{}
    case _:
      False{}

def text_blocks(items: List<&2, Json.Json>) -> Bool:
  match items:
    case Nil{}:
      True{}
    case Con{item, rest}:
      Bool.and(text_block(Json.get(item, "type")), text_blocks(rest))

def content_coverage(value: Json.Json) -> String:
  match value:
    case Json.JString{text}:
      "complete"
    case Json.JArray{items}:
      Bool.pick(String, text_blocks(items), "complete", "partial_content")
    case _:
      "partial_content"

def content(value: Json.Json, separator: String) -> String:
  match value:
    case Json.JString{text}:
      text
    case Json.JArray{items}:
      String.join(content_parts(items), separator)
    case _:
      value_text(value)

def make(+root: Json.Json, role: String, text: String, tool: String, call: String, arguments: String, result: String, coverage: String) -> Record:
  +message = Json.field(root, "message")
  ProviderEvent{role, text, tool, call, arguments, result,
    fallback(Json.get(root, "cwd"), Json.get(root, "repository")),
    fallback(Json.get(root, "sessionId"), Json.get(root, "session_id")),
    Json.get(root, "timestamp"),
    fallback(Json.get(message, "model"), Json.get(root, "model")),
    json_optional(Json.field(message, "usage")),
    fallback(Json.get(root, "parentUuid"), Json.get(root, "parent_id")), coverage}

def claude_block_type(kind: String, +root: Json.Json, role: String, +block: Json.Json) -> Record:
  match kind:
    case "text":
      make(root, role, Json.get(block, "text"), "", "", "", "", "complete")
    case "thinking":
      make(root, "thinking", Json.get(block, "thinking"), "", "", "", "", "complete")
    case "tool_use":
      make(root, role, "", Json.get(block, "name"), Json.get(block, "id"), value_text(Json.field(block, "input")), "", "complete")
    case "tool_result":
      make(root, "tool", "", "", Json.get(block, "tool_use_id"), "", content(Json.field(block, "content"), "\n"), Bool.pick(String, String.eq(Json.get(block, "is_error"), "true"), "tool_error", content_coverage(Json.field(block, "content"))))
    case "image":
      make(root, "attachment", "[Image metadata retained; image rendering unavailable]", "", "", Json.encode(block), "", "unsupported_attachment")
    case "document":
      make(root, "attachment", "[Document metadata retained; attachment bytes are not fetched]", "", "", Json.encode(block), "", "unsupported_attachment")
    case _:
      make(root, "unsupported", "[Unsupported Claude content block]", "", "", Json.encode(block), "", "unsupported")

def claude_blocks(items: List<&2, Json.Json>, +root: Json.Json, +role: String) -> List<&2, Record>:
  match items:
    case Nil{}:
      []
    case Con{+item, rest}:
      claude_block_type(Json.get(item, "type"), root, role, item) <> claude_blocks(rest, root, role)

def claude_content(value: Json.Json, root: Json.Json, role: String) -> List<&2, Record>:
  match value:
    case Json.JString{text}:
      [make(root, role, text, "", "", "", "", "complete")]
    case Json.JArray{items}:
      claude_blocks(items, root, role)
    case _:
      [make(root, "unsupported", "[Claude record has no supported message content]", "", "", "", "", "unsupported")]

def claude_type(kind: String, +root: Json.Json) -> List<&2, Record>:
  match kind:
    case "assistant":
      claude_content(Json.field(Json.field(root, "message"), "content"), root, "assistant")
    case "user":
      claude_content(Json.field(Json.field(root, "message"), "content"), root, "user")
    case "summary":
      [make(root, "system", Json.get(root, "summary"), "", "", "", "", "complete")]
    case "system":
      [make(root, "system", fallback(Json.get(root, "content"), Json.get(root, "subtype")), "", "", "", "", "metadata")]
    case "file-history-snapshot":
      [make(root, "metadata", "[File history metadata retained]", "", "", "", "", "metadata")]
    case "progress":
      [make(root, "metadata", "[Progress metadata retained]", "", "", "", "", "metadata")]
    case "queue-operation":
      [make(root, "metadata", "[Queue metadata retained]", "", "", "", "", "metadata")]
    case _:
      [make(root, "unsupported", "[Unsupported Claude record type]", "", "", "", "", "unsupported")]

def codex_make(+root: Json.Json, +payload: Json.Json, role: String, text: String, tool: String, call: String, arguments: String, result: String, coverage: String) -> Record:
  ProviderEvent{role, text, tool, call, arguments, result,
    fallback(Json.get(payload, "cwd"), Json.get(root, "cwd")),
    fallback(Json.get(payload, "session_id"), Json.get(root, "session_id")),
    Json.get(root, "timestamp"), Json.get(payload, "model"),
    json_optional(Json.field(payload, "usage")),
    fallback(Json.get(payload, "parent_id"), Json.get(Json.field(payload, "source"), "parent_thread_id")), coverage}

def string_output_coverage(value: Json.Json) -> String:
  match value:
    case Json.JString{text}:
      "complete"
    case _:
      "partial_content"

def output_coverage(value: Json.Json) -> String:
  match value:
    case Json.JString{text}:
      "complete"
    case Json.JObject{fields}:
      string_output_coverage(Json.field(Json.JObject{fields}, "content"))
    case Json.JArray{items}:
      Bool.pick(String, text_blocks(items), "complete", "partial_content")
    case _:
      "partial_content"

def object_output(+value: Json.Json, content_value: Json.Json) -> String:
  match content_value:
    case Json.JString{text}:
      text
    case _:
      Json.encode(value)

def codex_output(value: Json.Json) -> String:
  match value:
    case Json.JString{text}:
      text
    case Json.JObject{+fields}:
      object_output(Json.JObject{fields}, Json.field(Json.JObject{fields}, "content"))
    case Json.JArray{items}:
      String.join(content_parts(items), "")
    case _:
      value_text(value)

def agent_relay(root: Json.Json, +payload: Json.Json, readable: Bool) -> List<&2, Record>:
  match readable:
    case True{}:
      [codex_make(root, payload, "system", content(Json.field(payload, "content"), "\n\n"), "", "", "", "", "complete")]
    case False{}:
      [codex_make(root, payload, "unsupported", "[Agent relay contains encrypted or unsupported content]", "", "", "", "", "partial_agent_relay")]

def codex_response(kind: String, root: Json.Json, +payload: Json.Json) -> List<&2, Record>:
  match kind:
    case "":
      [codex_make(root, payload, Json.get(payload, "role"), content(Json.field(payload, "content"), "\n\n"), "", "", "", "", content_coverage(Json.field(payload, "content")))]
    case "agent_message":
      agent_relay(root, payload, text_blocks(Json.items(Json.field(payload, "content"))))
    case "message":
      [codex_make(root, payload, Json.get(payload, "role"), content(Json.field(payload, "content"), "\n\n"), "", "", "", "", content_coverage(Json.field(payload, "content")))]
    case "function_call":
      [codex_make(root, payload, "assistant", "", Json.get(payload, "name"), Json.get(payload, "call_id"), value_text(Json.field(payload, "arguments")), "", "complete")]
    case "custom_tool_call":
      [codex_make(root, payload, "assistant", "", Json.get(payload, "name"), Json.get(payload, "call_id"), value_text(Json.field(payload, "input")), "", "complete")]
    case "function_call_output":
      [codex_make(root, payload, "tool", "", "", Json.get(payload, "call_id"), "", codex_output(Json.field(payload, "output")), output_coverage(Json.field(payload, "output")))]
    case "custom_tool_call_output":
      [codex_make(root, payload, "tool", "", "", Json.get(payload, "call_id"), "", codex_output(Json.field(payload, "output")), output_coverage(Json.field(payload, "output")))]
    case "reasoning":
      [codex_make(root, payload, "thinking", content(Json.field(payload, "summary"), "\n"), "", "", "", "", "partial_reasoning")]
    case _:
      [codex_make(root, payload, "unsupported", "[Unsupported Codex response item]", "", "", "", "", "unsupported")]

def with_session(event: Record, session_id: String) -> Record:
  match event:
    case ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage, parent, coverage}:
      ProviderEvent{role, text, tool, call, arguments, result, repository, session_id, timestamp, model, usage, parent, coverage}

def with_usage(event: Record, usage_value: String) -> Record:
  match event:
    case ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage, parent, coverage}:
      ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage_value, parent, coverage}

def codex_event(kind: String, root: Json.Json, +payload: Json.Json) -> List<&2, Record>:
  match kind:
    case "user_message":
      []
    case "agent_message":
      []
    case "agent_reasoning":
      []
    case "task_started":
      []
    case "task_complete":
      []
    case "turn_aborted":
      []
    case "token_count":
      [with_usage(codex_make(root, payload, "metadata", "[Recorded token usage]", "", "", "", "", "metadata"), json_optional(Json.field(payload, "info")))]
    case _:
      [codex_make(root, payload, "unsupported", "[Unsupported Codex event]", "", "", "", "", "unsupported")]

def codex_type(kind: String, +root: Json.Json, +payload: Json.Json) -> List<&2, Record>:
  match kind:
    case "session_meta":
      [with_session(codex_make(root, payload, "metadata", "[Session metadata]", "", "", "", "", "metadata"), Json.get(payload, "id"))]
    case "turn_context":
      [codex_make(root, payload, "metadata", "[Turn context]", "", "", "", "", "metadata_context")]
    case "event_msg":
      codex_event(Json.get(payload, "type"), root, payload)
    case "function_call":
      codex_response("function_call", root, payload)
    case "response_item":
      codex_response(Json.get(payload, "type"), root, payload)
    case "compacted":
      [codex_make(root, payload, "system", Json.get(payload, "message"), "", "", "", "", "partial_compaction")]
    case "message":
      codex_response("message", root, root)
    case _:
      [codex_make(root, payload, "unsupported", "[Unsupported Codex record type]", "", "", "", "", "unsupported")]

def normalized(provider: String, +root: Json.Json) -> List<&2, Record>:
  match provider:
    case "claude":
      claude_type(Json.get(root, "type"), root)
    case "codex":
      codex_type(Json.get(root, "type"), root, Json.field(root, "payload"))
    case _:
      [make(root, "unsupported", "[Unsupported provider]", "", "", "", "", "unsupported")]

def clear_repeated_usage(records: List<&2, Record>) -> List<&2, Record>:
  match records:
    case Nil{}:
      []
    case Con{record, rest}:
      with_usage(record, "") <> clear_repeated_usage(rest)

def usage_once(records: List<&2, Record>) -> List<&2, Record>:
  match records:
    case Nil{}:
      []
    case Con{first, rest}:
      first <> clear_repeated_usage(rest)

def parsed(provider: String, result: Result<&2, &2, String, Json.Json>) -> List<&2, Record>:
  match result:
    case Done{value}:
      usage_once(normalized(provider, value))
    case Fail{error}:
      [ProviderEvent{"error", error, "", "", "", "", "", "", "", "", "", "", "malformed"}]

def parse(provider: String, raw: String) -> List<&2, Record>:
  parsed(provider, Json.parse(raw))

def role(event: Record) -> String:
  match event:
    case ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage, parent, coverage}:
      role

def text(event: Record) -> String:
  match event:
    case ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage, parent, coverage}:
      text

def tool(event: Record) -> String:
  match event:
    case ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage, parent, coverage}:
      tool

def call_id(event: Record) -> String:
  match event:
    case ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage, parent, coverage}:
      call

def arguments(event: Record) -> String:
  match event:
    case ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage, parent, coverage}:
      arguments

def result(event: Record) -> String:
  match event:
    case ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage, parent, coverage}:
      result

def repository(event: Record) -> String:
  match event:
    case ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage, parent, coverage}:
      repository

def session(event: Record) -> String:
  match event:
    case ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage, parent, coverage}:
      session

def timestamp(event: Record) -> String:
  match event:
    case ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage, parent, coverage}:
      timestamp

def model(event: Record) -> String:
  match event:
    case ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage, parent, coverage}:
      model

def usage(event: Record) -> String:
  match event:
    case ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage, parent, coverage}:
      usage

def parent(event: Record) -> String:
  match event:
    case ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage, parent, coverage}:
      parent

def coverage(event: Record) -> String:
  match event:
    case ProviderEvent{role, text, tool, call, arguments, result, repository, session, timestamp, model, usage, parent, coverage}:
      coverage

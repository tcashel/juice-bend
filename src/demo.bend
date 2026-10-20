import Base
import ./store.bend as Store
import ./json.bend as Json

# Entirely synthetic; no source root discovery or private history access.
def checkpoint_records(remaining: Nat,+ordinal: U32) -> String:
  match remaining:
    case 0n:
      ""
    case 1n+rest:
      "{\"type\":\"assistant\",\"sessionId\":\"synthetic-claude\",\"cwd\":\"/synthetic/juice-bend-demo\",\"timestamp\":\"2026-10-20T12:00:00Z\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":" ++
      Json.quote("Checkpoint " ++ U32.show(ordinal) ++
        ": captured bytes belong to the library.\nSearch for preservation, inspect a record, and copy this Unicode text: Café é 中文 😀.\nA rewritten source starts a new generation; older accepted snapshots stay readable.") ++
      "}]}}\n" ++ checkpoint_records(rest,U32.add(ordinal,1))

def claude() -> String:
  "{\"type\":\"user\",\"sessionId\":\"synthetic-claude\",\"cwd\":\"/synthetic/juice-bend-demo\",\"timestamp\":\"2026-10-20T11:59:00Z\",\"message\":{\"role\":\"user\",\"content\":\"Preserve agent history and make lexical search available after original logs disappear.\"}}\n" ++
  "{\"type\":\"assistant\",\"sessionId\":\"synthetic-claude\",\"cwd\":\"/synthetic/juice-bend-demo\",\"timestamp\":\"2026-10-20T11:59:01Z\",\"message\":{\"role\":\"assistant\",\"model\":\"synthetic-model\",\"usage\":{\"input_tokens\":24,\"output_tokens\":42},\"content\":[{\"type\":\"text\",\"text\":\"## Preservation design\\nKeep original bytes in SQLite and bind each transcript to an accepted snapshot.\\n\\n```bend\\ndef identity(snapshot: String) -> String:\\n  snapshot\\n```\"},{\"type\":\"tool_use\",\"id\":\"synthetic-write-1\",\"name\":\"Write\",\"input\":{\"file_path\":\"/synthetic/juice-bend-demo/example.bend\",\"content\":\"def identity(snapshot: String) -> String:\\n  snapshot\\n\"}}]}}\n" ++
  "{\"type\":\"user\",\"sessionId\":\"synthetic-claude\",\"cwd\":\"/synthetic/juice-bend-demo\",\"timestamp\":\"2026-10-20T11:59:02Z\",\"message\":{\"role\":\"user\",\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"synthetic-write-1\",\"content\":\"Synthetic tool result: example.bend recorded. This tool was not executed.\"}]}}\n" ++
  "{\"type\":\"assistant\",\"sessionId\":\"synthetic-claude\",\"cwd\":\"/synthetic/juice-bend-demo\",\"timestamp\":\"2026-10-20T11:59:03Z\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"Selection and exports retain the underlying Unicode: Café é 中文 😀. Missing glyph boxes are a presentation limitation.\"}]}}\n" ++
  checkpoint_records(20n,1)

def codex() -> String:
  "{\"timestamp\":\"2026-10-20T13:00:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"synthetic-codex\",\"cwd\":\"/synthetic/juice-bend-demo\",\"originator\":\"synthetic-fixture\"}}\n" ++
  "{\"timestamp\":\"2026-10-20T13:00:01Z\",\"type\":\"turn_context\",\"payload\":{\"cwd\":\"/synthetic/juice-bend-demo\",\"model\":\"synthetic-model\"}}\n" ++
  "{\"timestamp\":\"2026-10-20T13:00:02Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":[{\"type\":\"input_text\",\"text\":\"Search paths, identifiers, commands, and recorded tool results without a model.\"}]}}\n" ++
  "{\"timestamp\":\"2026-10-20T13:00:03Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"function_call\",\"name\":\"exec_command\",\"call_id\":\"synthetic-command-1\",\"arguments\":\"{\\\"cmd\\\":\\\"printf captured_evidence\\\"}\"}}\n" ++
  "{\"timestamp\":\"2026-10-20T13:00:04Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"function_call_output\",\"call_id\":\"synthetic-command-1\",\"output\":\"captured_evidence\\nSynthetic fixture only; no command was executed.\"}}\n" ++
  "{\"timestamp\":\"2026-10-20T13:00:05Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"Lexical search uses retained captured evidence. Provenance must distinguish exact, content, probable, ambiguous, and missing evidence. Never infer authorship from a nearby timestamp alone.\"}]}}\n" ++
  "{\"timestamp\":\"2026-10-20T13:00:06Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":{\"input_tokens\":80,\"output_tokens\":36}}}}\n"

def prepare(+db: U32,+dir: String) -> IO(Unit):
  +claude_path = dir ++ "/juice-bend-synthetic-claude.jsonl"
  +codex_path = dir ++ "/juice-bend-synthetic-codex.jsonl"
  do IO<Unit>:
    Store.write_text(claude_path,"w",claude())
    Store.write_text(codex_path,"w",codex())
    claude_snapshot : String <- Store.import_file(db,"claude",claude_path)
    codex_snapshot : String <- Store.import_file(db,"codex",codex_path)
    return Unit{}

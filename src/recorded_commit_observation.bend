import Base
import ./recorded_commit_links.bend as Links

# Only potential commit observations reach this list. Unrelated tools were
# filtered by the recognizer; known failed/quiet/no-marker commands do not
# supply invented SHAs. A bounded or structurally unknowable candidate set is
# different and cannot support the overall unique-coverage label.
def uncertain(+state: String) -> Bool:
  String.eq(state,"output_bound") || String.eq(state,"unsupported_result") ||
    String.eq(state,"ambiguous_output") || String.eq(state,"ambiguous_pair") ||
    String.eq(state,"pair_order_conflict") || String.eq(state,"missing_result") ||
    String.eq(state,"completion_unknown") || String.eq(state,"incomplete") ||
    (String.starts_with(state,"unsupported_command:") &&
      Bool.not(String.eq(state,"unsupported_command: command_repository_mismatch")))

def reason(+value: Links.Evidence) -> String:
  Links.Evidence{state,_,_,_,_} = value
  Bool.pick(String,uncertain(state),"commit-looking observation has incomplete or ambiguous supported evidence","")

def collect(items: List<&2,Links.Evidence>) -> String:
  match items:
    case []: ""
    case head <> rest:
      +issue = reason(head)
      Bool.pick(String,String.is_empty(issue),collect(rest),issue)

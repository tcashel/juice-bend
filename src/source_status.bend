import Base
import ./json.bend as Json
import ./domain.bend as Domain

# A bounded, path-free suffix for the existing capture-batch report. This is
# root-pass progress, not full-library health or proof that capture succeeded.
def count_value(value: Maybe<&2,U32>) -> String:
  match value:
    case Some{number}: U32.show(number)
    case None{}: "unknown"

def summary_status(status: String,count: String) -> String:
  match status:
    case "scanning":
      " Discovery continues across refreshes; found " ++ count ++
        " files in this root pass. Previously queued files remain available until the pass completes."
    case "cancelled":
      " Source discovery was cancelled because its root settings or discovery pass changed. Refresh again to use the current settings."
    case "ok":
      " Discovery completed this root pass; found " ++ count ++ " files."
    case "failed":
      " Discovery failed; previously queued files and accepted captures remain available."
    case "none":
      " No source root is enabled for discovery."
    case "": ""
    case _:
      " Discovery status is unavailable; this batch does not establish root coverage."

def summary_discovery(+value: Json.Json) -> String:
  summary_status(Json.get(value,"status"),count_value(Domain.parse_u32(Json.get(value,"files"))))

def summary(value: Json.Json) -> String:
  summary_discovery(Json.field(value,"discovery"))

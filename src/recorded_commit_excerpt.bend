import Base
import ./evidence.bend as Evidence

# Revalidate the exact pinned event descriptors before displaying their bounded
# retained text. A missing/changed event cannot retain an exact-link claim.
def combine(call: Result<&2,&2,String,String>,output: Result<&2,&2,String,String>) -> Result<&2,&2,String,String>:
  match call output:
    case Fail{reason} _: Fail{"Retained call unavailable: " ++ reason}
    case Done{_} Fail{reason}: Fail{"Retained result unavailable: " ++ reason}
    case Done{call} Done{output}:
      Done{"Retained command call (verified excerpt; text/arguments/result each at most 2048 characters):\n" ++ call ++
        "Retained command result (same excerpt bounds):\n" ++ output}

def read(+db: U32,call: String,result: String) -> IO(Result<&2,&2,String,String>):
  do IO<Result<&2,&2,String,String>>:
    call_text : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,call)
    result_text : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,result)
    return combine(call_text,result_text)

import Base
import ../../src/attachment_worker_protocol.bend as P
import ../../src/attachment_worker.bend as Worker

# Frontend-only fixture for this isolated slice. The required native loader
# acceptance still runs the full application binary, not this small entry.
def copy(args: List<String>) -> List<&2,String>:
  match args:
    case []: []
    case value <> rest: value <> copy(rest)

def route(value: P.Route) -> IO(Unit):
  match value:
    case P.Worker{request}: Worker.run(request)
    case _: IO.die(Unit,64,"attachment_worker_arguments")

def argv(args: List<String>) -> IO(Unit):
  match args:
    case program <> rest: route(P.classify(program,copy(rest)))
    case []: IO.die(Unit,64,"attachment_worker_arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    argv(args)

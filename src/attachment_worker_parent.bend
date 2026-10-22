import Base
import ./attachment_worker_protocol.bend as P

# Exact attempt12 policy, now embedded as a constant; ROOT/WORKER are literal
# sandbox-exec parameters. Nothing from a log is evaluated as policy or commands.
# The DIRECTORY literal / exception grants no descendant directory or file.
def policy() -> String:
  "; Diagnostic candidate only. No system.sb/dyld-support.sb import and no\n; outside-root regular-file byte grant. Root-directory listing is the explicit bootstrap exception below.\n(version 1)\n(deny default)\n(debug deny)\n\n; sandbox-exec enters the policy before executing this exact trusted binary.\n(allow process-exec (literal (param \"WORKER\")))\n\n; Execution/mapping and metadata are deliberately separate from content reads.\n(allow file-map-executable\n  (literal (param \"WORKER\"))\n  (subpath \"/System/Library\")\n  (subpath \"/System/Volumes/Preboot/Cryptexes\")\n  (subpath \"/System/Cryptexes\")\n  (subpath \"/usr/lib\")\n  (subpath \"/Library/Apple/System/Library\")\n  (subpath \"/Library/Apple/usr/lib\"))\n\n(allow file-read-metadata file-test-existence\n  (literal \"/\")\n  (literal (param \"WORKER\"))\n  (path-ancestors (param \"WORKER\"))\n  (subpath (param \"ROOT\"))\n  (path-ancestors (param \"ROOT\"))\n  (subpath \"/System\")\n  (subpath \"/usr/lib\")\n  (subpath \"/Library/Apple\"))\n\n; The only regular-file content-read authority. It must not admit the executable above.\n(allow file-read-data\n  (require-all\n    (subpath (param \"ROOT\"))\n    (vnode-type REGULAR-FILE)))\n\n; No writes, child processes, network, broad mach lookup, or profile imports.\n\n; Explicit diagnostic bootstrap exception: only the root directory vnode.\n(allow file-read-data\n  (require-all\n    (literal \"/\")\n    (vnode-type DIRECTORY)))\n"

def arguments(value: P.Request) -> List<String>:
  P.Request{+program,+root,relative,nonce} = value
  ["-i","PATH=/usr/bin:/bin","LANG=C","LC_ALL=C","/usr/bin/sandbox-exec",
    "-p",policy(),"-D","ROOT=" ++ root,"-D","WORKER=" ++ program,
    program,"--attachment-worker-v1",root,relative,nonce]

# One directly supervised process; env and sandbox-exec must exec the worker.
# Process.run limits combined output and kills/reaps its direct child on timeout.
# This is not an unconditional wall-clock/RSS bound: spawn, packing and waitpid
# are outside the timed collection loop. Native lifecycle gates remain required.
def run_checked(valid: Bool,+request: P.Request) -> IO(Result<&2,&2,String,P.Payload>):
  match valid:
    case False{}: IO.pure(Result<&2,&2,String,P.Payload>,Fail{"attachment_worker_arguments"})
    case True{}:
      P.Request{_,_,_,nonce} = request
      do IO<Result<&2,&2,String,P.Payload>>:
        result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
          Process.run("/usr/bin/env",arguments(request),"",P.output_limit(),P.timeout_ms())
        return P.response(result,nonce)

# Callers supply an explicitly enabled, canonical root. This module deliberately
# has no SQL dependency and returns only a verified byte payload or static error.
def run(+request: P.Request) -> IO(Result<&2,&2,String,P.Payload>):
  run_checked(P.valid_request(request),request)

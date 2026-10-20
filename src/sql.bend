import Base

# The only first-party foreign boundary. Text is Unicode; raw captured bytes
# must use Blob. Integer decimal strings are exact signed 64-bit quantities.
type Cell is Data:
  Cell.Null{}
  Cell.Integer{value: String}
  Cell.Text{value: String}
  Cell.Blob{value: List<&2, U32>}
  Cell.Real{value: String}

# Tokens are checked registry identities, never pointers. Close invalidates the
# token permanently. Each connection permits one in-flight operation.
def open(path: String) -> IO(Result<&1, &1, U32 & String, U32>):
  import "../native/sqlite.c"

# Exactly one prepared statement. Empty bindings for DDL/transaction statements.
# Exceeding max_rows fails, never silently truncates. Bound SELECTs in SQL.
# SQLite error codes are returned with content-free engine descriptions.
# Ceilings: 4096 rows/bindings, 256 columns, 4 MiB aggregate input/output.
# Work executes off the loop with 250ms busy wait and 2s progress deadline.
# Caller owns BEGIN/COMMIT/ROLLBACK. A failed query does not roll back a caller
# transaction; avoid mutating RETURNING statements outside a transaction.
def query(token: U32, statement: String, bindings: List<&2, Cell>, max_rows: U32) ->
  IO(Result<&1, &1, U32 & String, List<&2, List<&2, Cell>>>):
  import "../native/sqlite.c"

def close(token: U32) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "../native/sqlite.c"

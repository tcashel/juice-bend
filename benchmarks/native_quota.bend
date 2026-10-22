import Base
import ./native_activity.bend as Safe
import ./native_settings.bend as Settings
import ./native_request_origin.bend as Origin
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/paths.bend as Paths
import ../src/json.bend as J
import ../src/claude_quota.bend as Q

# Synthetic candidate fixture only. No quota connection is enabled here; the
# actual native UI must perform that explicit action. Every write is below a
# newly-created canonical private /private/tmp/juice-bend-quota-fixture-UUID.
def root_shape(+root: String) -> Bool:
  +prefix = {"/private/tmp/juice-bend-quota-fixture-" : String}
  String.starts_with(root,prefix) && Origin.uuid(String.split(String.drop(root,String.length(prefix)),'-'))

def source(root: String) -> String:
  root ++ "/captures/origin.jsonl"

def feed(kind: U32) -> String:
  match kind:
    case 0: "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":0,\"resets_at\":null},\"seven_day\":null}}\n"
    case 1: "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":25.125,\"resets_at\":1700000000},\"seven_day\":{\"resets_at\":1700600000}}}\n"
    case 2: "{\"rate_limits\":{\"five_hour\":null,\"seven_day\":null}}\n"
    case _: "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":101}}}\n"

def known_zero(value: Result<&2,&2,Q.Failure,Q.Observation>) -> Bool:
  match value:
    case Done{Q.Observation{Some{Q.QuotaWindow{Some{0},None{}}},None{}}}: True{}
    case _: False{}

def feed_files(fuel: Nat,+root: String,+index: U32) -> IO(Unit):
  match fuel:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+n:
      +path = root ++ "/feed-" ++ U32.show(index) ++ ".json"
      do IO<Unit>:
        Safe.absent(path)
        Store.write_text(path,"w",feed(index))
        Safe.private_file(path,"600")
        Safe.exact_file(path,feed(index))
        feed_files(n,root,U32.inc(index))

def manifest(+root: String) -> String:
  "{\"fixture\":\"juice-bend-quota-fixture-v1\",\"root\":" ++ J.quote(root) ++
    ",\"data_dir\":" ++ J.quote(root ++ "/library") ++ ",\"origin_source\":" ++ J.quote(source(root)) ++
    ",\"origin_snapshot\":\"1\",\"origin_start\":40,\"origin_records\":42,\"origin_query\":\"settings-origin\",\"repository\":\"/synthetic/settings\"," ++
    "\"zero_feed\":" ++ J.quote(root ++ "/feed-0.json") ++ ",\"partial_feed\":" ++ J.quote(root ++ "/feed-1.json") ++
    ",\"unknown_feed\":" ++ J.quote(root ++ "/feed-2.json") ++ ",\"invalid_feed\":" ++ J.quote(root ++ "/feed-3.json") ++
    ",\"quota_enabled\":false,\"quota_database_created\":false}"

def create(+root: String) -> IO(Unit):
  do IO<Unit>:
    Store.checked(root_shape(root),"Quota native fixture requires a new canonical direct /private/tmp UUID child")
    canonical : String <- Paths.destination(root)
    Store.checked(String.eq(canonical,root),"Quota fixture parent is not canonical")
    Safe.directory(root)
    Safe.regular_path(root,True{})
    Safe.directory(root ++ "/captures")
    Safe.directory(root ++ "/library")
    Store.write_text(source(root),"w",Settings.origin())
    Safe.private_file(source(root),"600")
    Safe.exact_file(source(root),Settings.origin())
    +db : U32 <- Store.open(root ++ "/library/juice-bend.sqlite")
    snapshot : String <- Store.import_file(db,"claude",source(root))
    Store.checked(String.eq(snapshot,"1"),"Unexpected native origin capture identity")
    Settings.exact_capture(db,"1",Settings.origin())
    IO.try(Unit,Sql.close(db))
    Safe.absent(root ++ "/library/quota-observations.sqlite")
    Store.checked(known_zero(Q.parse(feed(0))),"Synthetic known-zero feed changed parser meaning")
    feed_files(4n,root,0)
    Store.write_text(root ++ "/.juice-bend-quota-fixture-v1","w",manifest(root) ++ "\n")
    Safe.private_file(root ++ "/.juice-bend-quota-fixture-v1","400")
    IO.print(manifest(root))

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case _ <> root <> []: create(root)
    case _: IO.die(Unit,2,"Expected one new /private/tmp/juice-bend-quota-fixture-UUID root")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)

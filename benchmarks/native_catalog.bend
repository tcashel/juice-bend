import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json

# Synthetic native-interaction fixture only. Run from a freshly allocated
# juice-bend-native-catalog.* directory; never from a real application library.
# All snapshots use the production importer, including 101 saved versions.
def record(session: String,text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":" ++ Json.quote(session) ++
    ",\"cwd\":\"/synthetic/native-catalog\",\"timestamp\":\"2026-10-20T12:00:00Z\"," ++
    "\"message\":{\"role\":\"user\",\"content\":" ++ Json.quote(text) ++ "}}\n"

def sessions(fuel: Nat,+db: U32,+root: String,+number: U32) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      +name = "session-" ++ U32.show(number)
      +path = root ++ "/" ++ name ++ ".jsonl"
      do IO<Unit>:
        Store.write_text(path,"w",record(name,"catalogneedle: synthetic session " ++ U32.show(number)))
        captured : String <- Store.import_file(db,"claude",path)
        sessions(rest,db,root,U32.add(number,1))

def versions(fuel: Nat,+db: U32,+path: String,+number: U32,latest: String) -> IO(String):
  match fuel:
    case 0n:
      IO.pure(String,latest)
    case 1n+rest:
      do IO<String>:
        Store.write_text(path,"a",record("versioned-session",
          "catalogneedle: version " ++ U32.show(number) ++ "; saved Unicode café 中文 🙂"))
        next : String <- Store.import_file(db,"claude",path)
        versions(rest,db,path,U32.add(number,1),next)

def empty_library(rows: List<&2,List<&2,Sql.Cell>>) -> IO(Unit):
  Store.checked(String.eq(Store.field(Store.first(rows),0n),"0"),
    "Native fixture refuses an existing nonempty library")

def prepare(+root: String) -> IO(Unit):
  do IO<Unit>:
    Store.checked(String.contains(root,"/juice-bend-native-catalog."),
      "Run only in a fresh juice-bend-native-catalog.* temporary directory")
    +db : U32 <- Store.open(root ++ "/juice-bend.sqlite")
    before : List<&2,List<&2,Sql.Cell>> <- Store.status(db)
    empty_library(before)
    sessions(205n,db,root,1)
    +path : String = root ++ "/versioned-session.jsonl"
    Store.write_text(path,"w","")
    +latest : String <- versions(101n,db,path,1,"")
    +counts : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT (SELECT count(*) FROM sources),(SELECT count(*) FROM snapshots WHERE accepted=1),(SELECT count(*) FROM search)",[],1)
    Store.checked(String.eq(Store.field(Store.first(counts),0n),"206") &&
      String.eq(Store.field(Store.first(counts),1n),"306") &&
      String.eq(Store.field(Store.first(counts),2n),"306"),"Native fixture count mismatch")
    IO.print("{\"fixture\":\"native-catalog-v1\",\"sources\":206,\"accepted_snapshots\":306," ++
      "\"current_search_events\":306,\"versioned_snapshots\":101,\"latest_snapshot\":" ++
      Json.quote(latest) ++ ",\"versioned_source\":" ++ Json.quote(path) ++ "}")
    IO.try(Unit,Sql.close(db))

def append_version(+root: String) -> IO(Unit):
  do IO<Unit>:
    Store.checked(String.contains(root,"/juice-bend-native-catalog."),
      "Append only in this synthetic catalog fixture directory")
    +db : U32 <- Store.open(root ++ "/juice-bend.sqlite")
    +before : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT (SELECT count(*) FROM sources),(SELECT count(*) FROM snapshots WHERE accepted=1),(SELECT count(*) FROM search)",[],1)
    Store.checked(String.eq(Store.field(Store.first(before),0n),"206") &&
      String.eq(Store.field(Store.first(before),1n),"306") &&
      String.eq(Store.field(Store.first(before),2n),"306"),"Require the unmodified native catalog fixture")
    latest : String <- versions(1n,db,root ++ "/versioned-session.jsonl",102,"")
    Store.checked(String.eq(latest,"307"),"Expected new synthetic snapshot 307")
    IO.print("{\"fixture\":\"native-catalog-v1\",\"appended_version\":102,\"latest_snapshot\":\"307\"}")
    IO.try(Unit,Sql.close(db))

def run(root: String,args: List<String>) -> IO(Unit):
  match args:
    case program <> "--append" <> []:
      append_version(root)
    case program <> []:
      prepare(root)
    case _:
      IO.die(Unit,2,"Usage: native-catalog [--append]")

def main() -> IO(Unit):
  do IO<Unit>:
    root : String <- IO.try(String,IO.get_env("PWD"))
    args : List<String> <- IO.args()
    run(root,args)

import Base
import ./store.bend as Store
import ./paths.bend as Paths
import ./archive_capture.bend as Archive

def selected(db: U32,provider: String,path: String,observer: Store.ImportObserver,archive: Bool) -> IO(String):
  match archive:
    case True{}: Archive.import_canonical(db,provider,path,observer)
    case False{}: Store.import_canonical(db,provider,path,observer)

def import_observed(db: U32,+provider: String,path: String,observer: Store.ImportObserver) -> IO(String):
  do IO<String>:
    Store.checked(String.eq(provider,"claude") || String.eq(provider,"codex"),
      "Provider must be claude or codex")
    +canonical : String <- Paths.resolve(path)
    selected(db,provider,canonical,observer,String.ends_with(canonical,".jsonl.zst"))

def import_file(db: U32,provider: String,path: String) -> IO(String):
  import_observed(db,provider,path,Store.Unobserved{})

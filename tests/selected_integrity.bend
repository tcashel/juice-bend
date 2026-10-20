import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/evidence.bend as Evidence

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def operation(+db: U32,+snapshot: String,ordinal: U32,mode: String) -> IO(String):
  match mode:
    case "page":
      Store.page(db,snapshot,ordinal,1)
    case "why":
      Evidence.why(db,snapshot,ordinal,1)
    case "refresh":
      do IO<String>:
        rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
          "SELECT s.locator FROM sources s JOIN generations g ON g.source=s.id JOIN snapshots p ON p.generation=g.id WHERE p.id=?",
          [Sql.Cell.Integer{snapshot}],1)
        Store.import_file(db,"claude",Store.field(Store.first(rows),0n))
    case _:
      IO.die(String,2,"Unknown isolated test operation")

def child(+path: String,snapshot: String,ordinal: U32,mode: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(path)
    content : String <- operation(db,snapshot,ordinal,mode)
    IO.print(content)
    IO.try(Unit,Sql.close(db))

def rejected(result: U32 & (String & String),name: String) -> IO(Unit):
  (code,(out,err)) = result
  assert(U32.is_ne(code,0) && String.contains(out ++ err,"integrity"),name)

def check_child(self: String,path: String,snapshot: String,ordinal: U32,
  +mode: String,name: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,[path,snapshot,U32.show(ordinal),mode],"",8192,10000))
    rejected(result,mode ++ " rejects " ++ name)

def check_both(+self: String,+path: String,+snapshot: String,+ordinal: U32,
  +name: String) -> IO(Unit):
  do IO<Unit>:
    check_child(self,path,snapshot,ordinal,"page",name)
    check_child(self,path,snapshot,ordinal,"why",name)

def mutation(+db: U32,+self: String,+path: String,+snapshot: String,
  ordinal: U32,name: String,change: String,restore: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,change,[])
    check_both(self,path,snapshot,ordinal,name)
    Store.exec(db,restore,[])

def suite(+self: String) -> IO(Unit):
  +prefix = {"{\"type\":\"user\",\"message\":{\"content\":\"prefix must stay unsupported\"}}" : String}
  +continuation = {"{\"type\":\"user\",\"message\":{\"content\":\"continuation must stay unsupported\"}}\n" : String}
  do IO<Unit>:
    +root : String <- IO.try(String,IO.get_env("PWD"))
    Store.checked(String.contains(root,"juice-bend-test-selected_integrity."),
      "Run this test using ./scripts/test in its isolated directory")
    +source : String = root ++ "/coverage.jsonl"
    +path : String = root ++ "/.build/selected.sqlite"
    Store.write_text(source,"w",
      prefix ++ String.repeat(" ",Nat.sub(262144n,String.length(prefix))) ++ continuation ++
      "{\"type\":\"user\",\"message\":{\"content\":\"ordinary complete record\"}}\n")
    +db : U32 <- Store.open(path)
    +snapshot : String <- Store.import_file(db,"claude",source)
    +fragment : String <- Store.page(db,snapshot,1,1)
    assert(String.contains(fragment,"oversized_record_fragment") &&
      Bool.not(String.contains(fragment,"continuation must stay unsupported")),
      "page starting inside an oversized physical line keeps continuation unsupported")
    +ordinary : String <- Store.page(db,snapshot,2,1)
    assert(String.contains(ordinary,"ordinary complete record"),
      "newline after oversized continuation resets coverage for following record")
    Store.exec(db,"UPDATE raw SET oversized=0 WHERE ordinal=1",[])
    check_both(self,path,snapshot,1,"continuation oversized flag changed to zero")
    check_child(self,path,snapshot,1,"refresh","corrupt retained continuation coverage")
    Store.exec(db,"UPDATE raw SET oversized=1 WHERE ordinal=1",[])
    mutation(db,self,path,snapshot,1,"predecessor complete flag contradicting bytes",
      "UPDATE raw SET complete=1 WHERE ordinal=0",
      "UPDATE raw SET complete=0 WHERE ordinal=0")
    Store.exec(db,"UPDATE raw SET digest='broken' WHERE ordinal=0",[])
    check_both(self,path,snapshot,1,"predecessor digest mismatch")
    # Restore the predecessor digest from its retained identity and bytes.
    +rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT generation,ordinal,offset,n,digest,bytes FROM raw WHERE ordinal=0",[],1)
    +row : List<&2,Sql.Cell> = Store.first(rows)
    Store.exec(db,"UPDATE raw SET digest=? WHERE ordinal=0",
      [Sql.Cell.Text{Store.raw_digest(Store.field(row,0n),0,0,262144,
        Store.blob(Store.cell(row,5n)))}])
    Store.exec(db,"UPDATE raw SET n=2,bytes=?,digest=? WHERE ordinal=0",
      [Sql.Cell.Blob{[97,32]},
       Sql.Cell.Text{Store.raw_digest(Store.field(row,0n),0,0,2,[97,32])}])
    check_both(self,path,snapshot,1,
      "short non-newline predecessor even with matching digest")
    Store.exec(db,"UPDATE raw SET n=262144,bytes=?,digest=? WHERE ordinal=0",
      [Store.cell(row,5n),
       Sql.Cell.Text{Store.raw_digest(Store.field(row,0n),0,0,262144,
         Store.blob(Store.cell(row,5n)))}])
    mutation(db,self,path,snapshot,1,"text value where raw blob is required",
      "UPDATE raw SET bytes=CAST(bytes AS TEXT) WHERE ordinal=1",
      "UPDATE raw SET bytes=CAST(bytes AS BLOB) WHERE ordinal=1")
    mutation(db,self,path,snapshot,2,"complete flag contradicting selected newline",
      "UPDATE raw SET complete=0 WHERE ordinal=2",
      "UPDATE raw SET complete=1 WHERE ordinal=2")
    mutation(db,self,path,snapshot,2,"ordinary record incorrectly marked oversized",
      "UPDATE raw SET oversized=1 WHERE ordinal=2",
      "UPDATE raw SET oversized=0 WHERE ordinal=2")
    mutation(db,self,path,snapshot,1,"map ordinal inconsistent with retained raw",
      "UPDATE records SET ordinal=99 WHERE ordinal=0",
      "UPDATE records SET ordinal=0 WHERE ordinal=99")
    Store.exec(db,"UPDATE raw SET oversized=0 WHERE ordinal=0",[])
    +derived : String <- Store.page(db,snapshot,1,1)
    assert(String.contains(derived,"oversized_record_fragment") &&
      Bool.not(String.contains(derived,"continuation must stay unsupported")),
      "continuation derives from predecessor bytes without trusting its oversized flag")
    Store.exec(db,"UPDATE raw SET oversized=1 WHERE ordinal=0",[])
    Store.exec(db,"UPDATE snapshots SET extent=extent+1 WHERE id=?",
      [Sql.Cell.Integer{snapshot}])
    check_both(self,path,snapshot,2,"last record failing exact snapshot extent")
    Store.exec(db,"UPDATE snapshots SET extent=extent-1 WHERE id=?",
      [Sql.Cell.Integer{snapshot}])
    +after : String <- Store.page(db,snapshot,0,3)
    assert(String.contains(after,"ordinary complete record") &&
      Bool.not(String.contains(after,"prefix must stay unsupported")) &&
      Bool.not(String.contains(after,"continuation must stay unsupported")),
      "restored captured snapshot renders only complete supported records")
    +exact : String = "{\"type\":\"user\",\"message\":{\"content\":\"exact bounded newline record\"}}"
    +exact_source : String = root ++ "/exact-boundary.jsonl"
    Store.write_text(exact_source,"w",
      exact ++ String.repeat(" ",Nat.sub(262143n,String.length(exact))) ++ "\n")
    +exact_snapshot : String <- Store.import_file(db,"claude",exact_source)
    +exact_page : String <- Store.page(db,exact_snapshot,0,1)
    assert(String.contains(exact_page,"exact bounded newline record") &&
      Bool.not(String.contains(exact_page,"oversized_record_fragment")),
      "exact 256 KiB record ending in newline remains complete")
    IO.try(Unit,Sql.close(db))

def args(args: List<String>) -> IO(Unit):
  match args:
    case self <> Nil{}:
      suite(self)
    case _ <> path <> snapshot <> ordinal <> mode <> Nil{}:
      child(path,snapshot,Store.number(ordinal),mode)
    case _:
      IO.die(Unit,2,"Invalid isolated selected-record test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    argv : List<String> <- IO.args()
    args(argv)

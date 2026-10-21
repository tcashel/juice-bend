import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./json.bend as Json
import ./provenance.bend as Provenance
import ./evidence.bend as Evidence
import ./maintenance.bend as Maintenance
import ./sources.bend as Sources
import ./domain.bend as Domain
import ./scoped_reader.bend as Scoped
import ./file_evidence.bend as FileEvidence
import ./usage.bend as Usage
import ./query.bend as Query
import ./catalog.bend as Catalog
import ./storage_inventory.bend as Inventory
import ./repository_cli.bend as Repository
import ./activity_cli.bend as Activity
import ./relations_cli.bend as Relations
import ./refresh_preferences_cli.bend as RefreshPreferences

type Page is Data:
  Page{offset: U32, rows: List<&2,List<&2,Sql.Cell>>, has_more: Bool}

# IDs and SQLite integers stay decimal strings in JSON, including values above
# JavaScript's exact integer range. The columns array defines each row.
def byte_values(bytes: List<&2,U32>) -> String:
  match bytes:
    case Nil{}:
      ""
    case Con{byte, Nil{}}:
      U32.show(byte)
    case Con{byte, rest}:
      U32.show(byte) ++ "," ++ byte_values(rest)

def cell_json(cell: Sql.Cell) -> String:
  match cell:
    case Sql.Cell.Null{}:
      "null"
    case Sql.Cell.Integer{value}:
      Json.quote(value)
    case Sql.Cell.Text{value}:
      Json.quote(value)
    case Sql.Cell.Real{value}:
      Json.quote(value)
    case Sql.Cell.Blob{bytes}:
      "{\"type\":\"blob\",\"bytes\":[" ++ byte_values(bytes) ++ "]}"

def cells_json(cells: List<&2,Sql.Cell>) -> String:
  match cells:
    case Nil{}:
      ""
    case Con{cell, Nil{}}:
      cell_json(cell)
    case Con{cell, rest}:
      cell_json(cell) ++ "," ++ cells_json(rest)

def rows_json(rows: List<&2,List<&2,Sql.Cell>>) -> String:
  match rows:
    case Nil{}:
      ""
    case Con{row, Nil{}}:
      "[" ++ cells_json(row) ++ "]"
    case Con{row, rest}:
      "[" ++ cells_json(row) ++ "]," ++ rows_json(rest)

def output_rows(columns: String, rows: List<&2,List<&2,Sql.Cell>>) -> IO(Unit):
  IO.print("{\"columns\":" ++ columns ++ ",\"rows\":[" ++ rows_json(rows) ++ "]}")

def failure(-A: Type, message: String) -> IO(A):
  IO.die(A,2,"{\"error\":" ++ Json.quote(message) ++ "}")

def checked(valid: Bool, message: String) -> IO(Unit):
  match valid:
    case True{}:
      IO.pure(Unit,Unit{})
    case False{}:
      failure(Unit,message)

def quantity(parsed: Maybe<&2,U32>, label: String) -> IO(U32):
  match parsed:
    case Some{n}:
      IO.pure(U32,n)
    case None{}:
      failure(U32,label ++ " must be an integer from 0 to 4294967295")

def snapshot_valid(+snapshot: String) -> Bool:
  Bool.and(Provenance.decimal_valid(snapshot),
    Bool.and(Bool.not(String.eq(snapshot,"0")),
      Bool.not(Cmp.is_gt(Provenance.decimal_compare(snapshot,"9223372036854775807")))))

def status(db: U32) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.status(db)
    output_rows("[\"sources\",\"generations\",\"accepted_snapshots\",\"raw_bytes\",\"projected_events\"]",rows)

def storage(db: U32) -> IO(Unit):
  do IO<Unit>:
    +report : Inventory.Report <- Inventory.read(db)
    IO.print("{\"kind\":\"storage_inventory\",\"inventory\":" ++ Inventory.to_json(report) ++
      ",\"text\":" ++ Json.quote(Inventory.summary(report)) ++ "}")

def list_rows(db: U32,history: Bool,filters: Query.Filters,limit: U32,offset: U32) ->
  IO(List<&2,List<&2,Sql.Cell>>):
  match history:
    case True{}:
      Query.Filters{query,provider,repo,role,after} = filters
      Store.history(db,provider,repo,limit,offset)
    case False{}:
      Query.Filters{query,provider,repo,role,after} = filters
      Store.search(db,query,provider,repo,role,after,limit,offset)

def list_more(db: U32,history: Bool,filters: Query.Filters,offset: U32,full: Bool) -> IO(Bool):
  match full:
    case False{}:
      IO.pure(Bool,False{})
    case True{}:
      do IO<Bool>:
        rows : List<&2,List<&2,Sql.Cell>> <- list_rows(db,history,filters,1,U32.add(offset,100))
        return Bool.not(List.is_empty(&2,List<&2,Sql.Cell>,rows))

# Both reads see the same SQLite snapshot. Separate page commands intentionally
# browse the current listing; captures can change its ordering between commands.
def list_page(+db: U32,+history: Bool,+filters: Query.Filters,+offset: U32) -> IO(Page):
  do IO<Page>:
    checked(U32.is_le(offset,4294967195),"offset must be from 0 to 4294967195")
    Store.exec(db,"BEGIN",[])
    +rows : List<&2,List<&2,Sql.Cell>> <- list_rows(db,history,filters,100,offset)
    more : Bool <- list_more(db,history,filters,offset,
      Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),100n))
    Store.exec(db,"COMMIT",[])
    return Page{offset,rows,more}

def output_page(columns: String,page: Page) -> IO(Unit):
  Page{offset,rows,more} = page
  IO.print("{\"columns\":" ++ columns ++ ",\"rows\":[" ++ rows_json(rows) ++
    "],\"offset\":" ++ U32.show(offset) ++ ",\"limit\":100,\"has_more\":" ++
    Bool.pick(String,more,"true","false") ++ "}")

def history_rows(+db: U32,provider: String,repo: String,offset: U32) -> IO(Unit):
  do IO<Unit>:
    page : Page <- list_page(db,True{},Query.Filters{"",provider,repo,"",""},offset)
    output_page("[\"source\",\"provider\",\"locator\",\"snapshot\",\"generation\",\"extent\",\"records\",\"excerpt\",\"repository\",\"first_event_ordinal\"]",page)

def history(+db: U32, args: List<String>) -> IO(Unit):
  match args:
    case Nil{}:
      history_rows(db,"","",0)
    case Con{provider,Con{repository,Nil{}}}:
      history_rows(db,provider,repository,0)
    case provider <> repository <> offset <> []:
      do IO<Unit>:
        from : U32 <- quantity(Provenance.parse_u32(offset),"offset")
        history_rows(db,provider,repository,from)
    case _:
      failure(Unit,"usage: history [PROVIDER REPOSITORY [OFFSET]]; at most 100 sessions per page")

def versions_more(db: U32,snapshot: String,offset: U32,full: Bool) -> IO(Bool):
  match full:
    case False{}:
      IO.pure(Bool,False{})
    case True{}:
      do IO<Bool>:
        rows : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,snapshot,1,U32.add(offset,100))
        return Bool.not(List.is_empty(&2,List<&2,Sql.Cell>,rows))

def versions_page(+db: U32,+snapshot: String,+offset: U32) -> IO(Page):
  do IO<Page>:
    checked(snapshot_valid(snapshot),"snapshot must be a positive canonical SQLite integer")
    checked(U32.is_le(offset,4294967195),"offset must be from 0 to 4294967195")
    Store.exec(db,"BEGIN",[])
    +rows : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(db,snapshot,100,offset)
    more : Bool <- versions_more(db,snapshot,offset,
      Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),100n))
    Store.exec(db,"COMMIT",[])
    return Page{offset,rows,more}

def versions_output(db: U32,snapshot: String,offset: String) -> IO(Unit):
  do IO<Unit>:
    from : U32 <- quantity(Provenance.parse_u32(offset),"offset")
    page : Page <- versions_page(db,snapshot,from)
    output_page("[\"snapshot\",\"generation\",\"extent\",\"records\",\"is_latest\"]",page)

def versions(db: U32,args: List<String>) -> IO(Unit):
  match args:
    case snapshot <> []:
      versions_output(db,snapshot,"0")
    case snapshot <> offset <> []:
      versions_output(db,snapshot,offset)
    case _:
      failure(Unit,"usage: versions SNAPSHOT [OFFSET]")

def latest(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    checked(snapshot_valid(snapshot),"snapshot must be a positive canonical SQLite integer")
    Store.exec(db,"BEGIN",[])
    target : String <- Catalog.latest(db,snapshot)
    Store.exec(db,"COMMIT",[])
    IO.print("{\"snapshot\":" ++ Json.quote(target) ++
      ",\"anchor_snapshot\":" ++ Json.quote(snapshot) ++ "}")

def import_source(db: U32, +provider: String, path: String) -> IO(Unit):
  do IO<Unit>:
    checked(Bool.or(String.eq(provider,"claude"),String.eq(provider,"codex")),
      "provider must be claude or codex")
    snapshot : String <- Store.import_file(db,provider,path)
    IO.print("{\"accepted_snapshot\":" ++ Json.quote(snapshot) ++ "}")

def search_rows(db: U32, query: String, provider: String, repository: String,
  role: String, after: String, offset: U32) -> IO(Unit):
  do IO<Unit>:
    page : Page <- list_page(db,False{},Query.Filters{query,provider,repository,role,after},offset)
    output_page("[\"snapshot\",\"record\",\"event\",\"provider\",\"role\",\"snippet\",\"repository\",\"session\",\"timestamp\",\"generation\"]",page)

def search(db: U32, args: List<String>) -> IO(Unit):
  match args:
    case Con{query,Nil{}}:
      search_rows(db,query,"","","","",0)
    case Con{query,Con{provider,Con{repository,Con{role,Con{after,Nil{}}}}}}:
      search_rows(db,query,provider,repository,role,after,0)
    case query <> provider <> repository <> role <> after <> offset <> []:
      do IO<Unit>:
        from : U32 <- quantity(Provenance.parse_u32(offset),"offset")
        search_rows(db,query,provider,repository,role,after,from)
    case _:
      failure(Unit,"usage: search QUERY [PROVIDER REPOSITORY ROLE AFTER [OFFSET]]; use empty strings for unfiltered fields")

def page_content(db: U32,snapshot: String,start: U32,count: U32,why: Bool) -> IO(String):
  match why:
    case True{}:
      Evidence.why(db,snapshot,start,count)
    case False{}:
      Store.page(db,snapshot,start,count)

def read_page(+db: U32,+snapshot: String,start: String,count: String,+why: Bool) -> IO(Unit):
  do IO<Unit>:
    checked(snapshot_valid(snapshot),"snapshot must be a positive canonical SQLite integer")
    +from : U32 <- quantity(Provenance.parse_u32(start),"start")
    +size : U32 <- quantity(Provenance.parse_u32(count),"count")
    checked(Bool.and(U32.is_gt(size,0),U32.is_le(size,100)),"count must be from 1 to 100")
    +content : String <- page_content(db,snapshot,from,size,why)
    checked(Bool.not(String.starts_with(content,"Why unavailable:")),content)
    IO.print("{\"snapshot\":" ++ Json.quote(snapshot) ++
      ",\"start\":" ++ U32.show(from) ++ ",\"requested_records\":" ++ U32.show(size) ++
      ",\"maximum_records\":" ++ Bool.pick(String,why,"20","100") ++
      ",\"verification\":\"selected_records_only\",\"complete_export\":false,\"kind\":" ++
      Json.quote(Bool.pick(String,why,"recorded_evidence","transcript_page")) ++
      ",\"rationale\":" ++ Bool.pick(String,why,
        "\"Captured statements only; no generated or inferred rationale.\"", "null") ++
      ",\"text\":" ++ Json.quote(content) ++ "}")

def session(db: U32,args: List<String>,why: Bool) -> IO(Unit):
  match args:
    case Con{snapshot,Con{start,Con{count,Nil{}}}}:
      read_page(db,snapshot,start,count,why)
    case _:
      failure(Unit,"usage: session SNAPSHOT START COUNT (or why SNAPSHOT [START COUNT])")

def scoped_content(db: U32,+snapshot: String,start: String,count: String,
  scope: Scoped.Scope,why: Bool) -> IO(String):
  do IO<String>:
    checked(snapshot_valid(snapshot),"snapshot must be a positive canonical SQLite integer")
    from : U32 <- quantity(Provenance.parse_u32(start),"start")
    +size : U32 <- quantity(Provenance.parse_u32(count),"count")
    checked(U32.is_gt(size,0) && U32.is_le(size,100),"count must be from 1 to 100")
    Scoped.page(db,snapshot,from,size,scope,why)

def read_scoped(db: U32,args: List<String>,+why: Bool) -> IO(Unit):
  match args:
    case +snapshot <> +start <> +count <> provider <> repo <> role <> after <> []:
      do IO<Unit>:
        +text : String <- scoped_content(db,snapshot,start,count,Scoped.Scope{provider,repo,role,after},why)
        checked(Bool.not(String.starts_with(text,"Why unavailable:")),text)
        IO.print("{\"snapshot\":" ++ Json.quote(snapshot) ++ ",\"start\":" ++ U32.show(Store.number(start)) ++
          ",\"requested_records\":" ++ U32.show(Store.number(count)) ++ ",\"kind\":" ++
          Json.quote(Bool.pick(String,why,"scoped_recorded_evidence","scoped_transcript_page")) ++
          ",\"complete_export\":false,\"text\":" ++ Json.quote(text) ++ "}")
    case _:
      failure(Unit,"usage: session-scope or why-scope SNAP START COUNT PROVIDER REPO ROLE AFTER")

def export_scoped(+db: U32,args: List<String>,+why: Bool) -> IO(Unit):
  match args:
    case +snapshot <> start <> count <> provider <> repo <> role <> after <> +path <> []:
      do IO<Unit>:
        +text : String <- scoped_content(db,snapshot,start,count,Scoped.Scope{provider,repo,role,after},why)
        checked(Bool.not(String.starts_with(text,"Why unavailable:")),text)
        Maintenance.write_text(db,path,"# Juice Bend scoped captured evidence\n\n" ++
          "This is a bounded physical-record range, not a complete transcript export.\n\n" ++ text)
        IO.print("{\"path\":" ++ Json.quote(path) ++ ",\"snapshot\":" ++ Json.quote(snapshot) ++
          ",\"kind\":" ++ Json.quote(Bool.pick(String,why,"scoped_recorded_evidence","scoped_transcript_page")) ++
          ",\"complete_export\":false}")
    case _:
      failure(Unit,"usage: export-range-scope or export-why-scope SNAP START COUNT PROVIDER REPO ROLE AFTER PATH")

def why(db: U32,args: List<String>) -> IO(Unit):
  match args:
    case Con{snapshot,Nil{}}:
      read_page(db,snapshot,"0","100",True{})
    case _:
      session(db,args,True{})

def export_range(+db: U32,+snapshot: String,start: String,count: String,+path: String,+why: Bool) -> IO(Unit):
  do IO<Unit>:
    checked(snapshot_valid(snapshot),"snapshot must be a positive canonical SQLite integer")
    +from : U32 <- quantity(Provenance.parse_u32(start),"start")
    +size : U32 <- quantity(Provenance.parse_u32(count),"count")
    checked(U32.is_gt(size,0) && U32.is_le(size,100),"count must be from 1 to 100")
    +content : String <- page_content(db,snapshot,from,size,why)
    checked(Bool.not(String.starts_with(content,"Why unavailable:")),content)
    Maintenance.write_text(db,path,"# Juice Bend bounded captured evidence\n\n" ++
      "Snapshot " ++ snapshot ++ ", starting at physical record " ++ U32.show(from) ++
      ". Requested records: " ++ U32.show(size) ++ ". Maximum records: " ++
      Bool.pick(String,why,"20","100") ++
      ". This is not a complete transcript export. Selected retained records " ++
      "were verified; other ranges were not checked.\n\n" ++ content)
    IO.print("{\"path\":" ++ Json.quote(path) ++ ",\"snapshot\":" ++
      Json.quote(snapshot) ++ ",\"start\":" ++ U32.show(from) ++
      ",\"maximum_records\":" ++ Bool.pick(String,why,"20","100") ++ ",\"complete_export\":false}")

def export_page(db: U32,snapshot: String,path: String) -> IO(Unit):
  export_range(db,snapshot,"0","100",path,False{})

def export_all(+db: U32,+snapshot: String,+path: String) -> IO(Unit):
  do IO<Unit>:
    checked(snapshot_valid(snapshot),"snapshot must be a positive canonical SQLite integer")
    Maintenance.export_raw(db,snapshot,path)
    IO.print("{\"path\":" ++ Json.quote(path) ++ ",\"snapshot\":" ++ Json.quote(snapshot) ++
      ",\"format\":\"retained_raw_bytes\",\"complete_export\":true,\"verification\":\"complete_accepted_extent\"}")

def maintain_action(db: U32,snapshot: String,rebuild: Bool) -> IO(Unit):
  match rebuild:
    case True{}:
      Maintenance.rebuild(db,snapshot)
    case False{}:
      Maintenance.verify(db,snapshot)

def maintain(+db: U32,+snapshot: String,rebuild: Bool) -> IO(Unit):
  do IO<Unit>:
    checked(snapshot_valid(snapshot),"snapshot must be a positive canonical SQLite integer")
    maintain_action(db,snapshot,rebuild)
    IO.print("{\"snapshot\":" ++ Json.quote(snapshot) ++
      ",\"verification\":\"complete_accepted_extent\",\"raw_bytes_unchanged\":true}")

def file_evidence(why: Bool,db: U32,repo: String,path: String,start: U32,count: U32) -> IO(String):
  match why:
    case True{}:
      FileEvidence.why(db,repo,path,start,count)
    case False{}:
      FileEvidence.blame(db,repo,path,start,count)

def file_text(db: U32,repo: String,path: String,start: String,end: String,why: Bool) -> IO(String):
  do IO<String>:
    +from : U32 <- quantity(Provenance.parse_u32(start),"start line")
    +through : U32 <- quantity(Provenance.parse_u32(end),"end line")
    checked(Bool.and(U32.is_gt(from,0),Bool.and(U32.is_ge(through,from),
      U32.is_lt(U32.sub(through,from),100))),"line range must contain 1 through 100 lines")
    +text : String <- file_evidence(why,db,repo,path,from,U32.add(U32.sub(through,from),1))
    checked(Bool.not(String.starts_with(text,"Blame unavailable:")),text)
    return text

def blame_text(db: U32,repo: String,path: String,start: String,end: String) -> IO(String):
  file_text(db,repo,path,start,end,False{})

def blame(db: U32,repo: String,path: String,start: String,end: String) -> IO(Unit):
  do IO<Unit>:
    text : String <- blame_text(db,repo,path,start,end)
    IO.print("{\"coverage\":\"bounded_generation_and_edit_candidates\",\"maximum_lines\":100,\"text\":" ++ Json.quote(text) ++ "}")

def why_file(db: U32,repo: String,path: String,start: String,end: String) -> IO(Unit):
  do IO<Unit>:
    text : String <- file_text(db,repo,path,start,end,True{})
    IO.print("{\"kind\":\"file_why\",\"maximum_lines\":100,\"text\":" ++ Json.quote(text) ++ "}")

def why_commit(db: U32,repo: String,sha: String) -> IO(Unit):
  do IO<Unit>:
    +text : String <- FileEvidence.commit_why(db,repo,sha)
    checked(Bool.not(String.starts_with(text,"Why unavailable:")),text)
    IO.print("{\"kind\":\"commit_why\",\"text\":" ++ Json.quote(text) ++ "}")

def usage_page(db: U32,+snapshot: String,start: String,count: String) -> IO(Unit):
  do IO<Unit>:
    checked(snapshot_valid(snapshot),"snapshot must be a positive canonical SQLite integer")
    +from : U32 <- quantity(Provenance.parse_u32(start),"start")
    +size : U32 <- quantity(Provenance.parse_u32(count),"count")
    checked(U32.is_gt(size,0) && U32.is_le(size,100),"count must be from 1 to 100")
    +text : String <- Usage.summary(db,snapshot,from,size)
    checked(Bool.not(String.starts_with(text,"Usage unavailable:")),text)
    IO.print("{\"kind\":\"recorded_usage\",\"snapshot\":" ++ Json.quote(snapshot) ++
      ",\"start\":" ++ U32.show(from) ++ ",\"requested_records\":" ++ U32.show(size) ++
      ",\"scope\":\"selected_physical_range\",\"text\":" ++ Json.quote(text) ++ "}")

def usage(db: U32,args: List<String>) -> IO(Unit):
  match args:
    case snapshot <> []:
      usage_page(db,snapshot,"0","100")
    case snapshot <> start <> []:
      usage_page(db,snapshot,start,"100")
    case snapshot <> start <> count <> []:
      usage_page(db,snapshot,start,count)
    case _:
      failure(Unit,"usage: usage SNAPSHOT [START [COUNT]]; maximum 100 physical records")

def export_blame(+db: U32,repo: String,path: String,start: String,end: String,+output: String) -> IO(Unit):
  do IO<Unit>:
    text : String <- blame_text(db,repo,path,start,end)
    Maintenance.write_text(db,output,text)
    IO.print("{\"path\":" ++ Json.quote(output) ++ ",\"kind\":\"blame_evidence\",\"maximum_lines\":100,\"complete_export\":false}")

def displayed_decoded(result: Result<&2,&2,String,String>) -> IO(String):
  match result:
    case Done{text}:
      IO.pure(String,text)
    case Fail{error}:
      failure(String,"Displayed evidence is not valid UTF-8: " ++ error)

def displayed_chunk(file: File,bytes: List<&2,U32>,+total: U32,
  chunks: List<&2,List<&2,U32>>,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(String)) -> IO(String):
  match bytes:
    case []:
      do IO<String>:
        File.close(file)
        displayed_decoded(Domain.decode(
          List.concat(&2,U32,List.reverse(&2,List<&2,U32>,chunks))))
    case byte <> rest:
      +part = {byte <> rest : List<&2,U32>}
      +size = U32.from_nat(List.length(&2,U32,part))
      do IO<String>:
        checked(U32.is_le(size,U32.sub(1048576,total)),
          "Displayed evidence exceeds 1048576 UTF-8 bytes")
        next(file,U32.add(total,size),part <> chunks)

def displayed_result(got: File & Result<&1,&1,U32 & String,List<&2,U32>>,
  total: U32,chunks: List<&2,List<&2,U32>>,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(String)) -> IO(String):
  (file,result) = got
  match result:
    case Fail{(code,error)}:
      do IO<String>:
        File.close(file)
        failure(String,"Cannot read displayed evidence: " ++ error)
    case Done{bytes}:
      displayed_chunk(file,bytes,total,chunks,next)

def displayed_read(fuel: Nat,+total: U32,chunks: List<&2,List<&2,U32>>,file: File) -> IO(String):
  match fuel:
    case 0n:
      do IO<String>:
        File.close(file)
        failure(String,"Displayed evidence read limit exceeded")
    case 1n+rest:
      do IO<String>:
        got : File & Result<&1,&1,U32 & String,List<&2,U32>> <-
          File.read_bytes(file,U32.min(4096,U32.add(U32.sub(1048576,total),1)))
        displayed_result(got,total,chunks,
          f => n => parts => displayed_read(rest,n,parts,f))

# This captures an already displayed result. It deliberately does not query
# mutable Git state or claim a new verification of the caller-supplied text.
def export_displayed(+db: U32,+path: String) -> IO(Unit):
  do IO<Unit>:
    input : File <- IO.try(File,File.open("/dev/stdin","r"))
    text : String <- displayed_read(1048577n,0,[],input)
    Maintenance.write_text(db,path,
      "# Juice Bend displayed evidence\n\n" ++
      "This export copies the displayed evidence and its captured citations. " ++
      "It does not re-resolve Git or perform a new evidence verification.\n\n" ++ text)
    IO.print("{\"path\":" ++ Json.quote(path) ++
      ",\"kind\":\"displayed_evidence\",\"verification\":\"not_reverified\"," ++
      "\"exact_displayed_text\":true,\"complete_export\":false}")

def citation_result(result: Result<&2,&2,String,String>) -> IO(Unit):
  match result:
    case Fail{error}:
      failure(Unit,error)
    case Done{text}:
      IO.print("{\"kind\":\"captured_citation\",\"text\":" ++ Json.quote(text) ++ "}")

def citation(db: U32,descriptor: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,descriptor)
    citation_result(result)

def sources(db: U32) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Sources.list(db)
    output_rows("[\"provider\",\"canonical_root\",\"enabled\"]",rows)

def source_register(db: U32,+provider: String,+path: String,enable: Bool) -> IO(Unit):
  match enable:
    case True{}:
      do IO<Unit>:
        Sources.add(db,provider,path)
        IO.print("{\"registered\":true,\"enabled\":true,\"provider\":" ++
          Json.quote(provider) ++ ",\"requested_root\":" ++ Json.quote(path) ++ "}")
    case False{}:
      do IO<Unit>:
        Sources.disable(db,provider,path)
        IO.print("{\"enabled\":false,\"provider\":" ++ Json.quote(provider) ++
          ",\"requested_root\":" ++ Json.quote(path) ++ "}")

def refresh_program(db: U32,data_dir: String,args: List<String>) -> IO(Unit):
  match args:
    case Con{program,_}:
      do IO<Unit>:
        report : String <- Sources.refresh_all(db,data_dir,program)
        IO.print(report)
    case Nil{}:
      failure(Unit,"native program path is unavailable for source refresh")

def refresh_all(db: U32,data_dir: String) -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    refresh_program(db,data_dir,args)

def help() -> IO(Unit):
  IO.print("{\"commands\":[\"status\",\"storage\",\"history [PROVIDER REPOSITORY [OFFSET]]\"," ++
    "\"versions SNAPSHOT [OFFSET]\",\"latest SNAPSHOT\"," ++
    "\"import PROVIDER PATH\",\"refresh PROVIDER PATH\",\"source-add PROVIDER ROOT\"," ++
    "\"source-disable PROVIDER ROOT\",\"sources\",\"refresh-all\"," ++
    "\"refresh-preferences\",\"refresh-preferences-set true|false SECONDS\"," ++
    "\"search QUERY [PROVIDER REPOSITORY ROLE AFTER [OFFSET]]\",\"session SNAPSHOT START COUNT\"," ++
    "\"why SNAPSHOT [START COUNT]\",\"session-scope SNAP START COUNT PROVIDER REPO ROLE AFTER\"," ++
    "\"why-scope SNAP START COUNT PROVIDER REPO ROLE AFTER\",\"blame REPOSITORY FILE START END\"," ++
    "\"activity-scope SNAPSHOT START COUNT PROVIDER REPOSITORY ROLE AFTER\"," ++
    "\"relations-scope SNAPSHOT LIMIT FILTER_PROVIDER FILTER_REPOSITORY FILTER_ROLE FILTER_AFTER\"," ++
    "\"relations-page PROVIDER SOURCE GENERATION SNAPSHOT EXTENT WATERMARK AFTER_SOURCE LIMIT FILTER_PROVIDER FILTER_REPOSITORY FILTER_ROLE FILTER_AFTER\"," ++
    "\"why-file REPOSITORY FILE START END\",\"why-commit REPOSITORY SHA\"," ++
    "\"repo-open REPO\",\"repo-tree REPO COMMIT PATH OFFSET\"," ++
    "\"repo-source REPO COMMIT PATH FIRST COUNT\",\"repo-blame REPO COMMIT PATH FIRST COUNT\"," ++
    "\"repo-why REPO COMMIT PATH FIRST COUNT\"," ++
    "\"usage SNAPSHOT [START [COUNT]]\"," ++
    "\"citation JSON\",\"export SNAPSHOT PATH\",\"export-range SNAPSHOT START COUNT PATH\"," ++
    "\"export-why SNAPSHOT START COUNT PATH\",\"export-blame REPOSITORY FILE START END PATH\"," ++
    "\"export-range-scope SNAP START COUNT PROVIDER REPO ROLE AFTER PATH\"," ++
    "\"export-why-scope SNAP START COUNT PROVIDER REPO ROLE AFTER PATH\"," ++
    "\"export-displayed PATH\",\"export-all SNAPSHOT PATH\",\"verify SNAPSHOT\",\"rebuild SNAPSHOT\"]," ++
    "\"limits\":{\"rows\":100,\"page_records\":100,\"why_records\":20,\"refresh_batch\":8,\"displayed_stdin_bytes\":1048576}," ++
    "\"refresh_all\":\"inspect failed and discovery.status in the report; a successful report can contain per-source failures\"," ++
    "\"export_all\":\"stream all retained raw bytes in the accepted snapshot\"}")

def command(db: U32,data_dir: String,cmd: String,args: List<String>) -> IO(Unit):
  match cmd:
    case "refresh-preferences":
      RefreshPreferences.command(db,"refresh-preferences",args)
    case "refresh-preferences-set":
      RefreshPreferences.command(db,"refresh-preferences-set",args)
    case "repo-open":
      Repository.command(db,"repo-open",args)
    case "repo-tree":
      Repository.command(db,"repo-tree",args)
    case "repo-source":
      Repository.command(db,"repo-source",args)
    case "repo-blame":
      Repository.command(db,"repo-blame",args)
    case "repo-why":
      Repository.command(db,"repo-why",args)
    case "storage":
      match args:
        case []:
          storage(db)
        case _:
          failure(Unit,"usage: storage")
    case "status":
      match args:
        case Nil{}:
          status(db)
        case _:
          failure(Unit,"usage: status")
    case "history":
      history(db,args)
    case "versions":
      versions(db,args)
    case "latest":
      match args:
        case snapshot <> []:
          latest(db,snapshot)
        case _:
          failure(Unit,"usage: latest SNAPSHOT")
    case "import":
      match args:
        case Con{provider,Con{path,Nil{}}}:
          import_source(db,provider,path)
        case _:
          failure(Unit,"usage: import PROVIDER PATH")
    case "refresh":
      match args:
        case Con{provider,Con{path,Nil{}}}:
          import_source(db,provider,path)
        case _:
          failure(Unit,"usage: refresh PROVIDER PATH")
    case "source-add":
      match args:
        case Con{provider,Con{path,Nil{}}}:
          source_register(db,provider,path,True{})
        case _:
          failure(Unit,"usage: source-add PROVIDER ROOT")
    case "source-disable":
      match args:
        case Con{provider,Con{path,Nil{}}}:
          source_register(db,provider,path,False{})
        case _:
          failure(Unit,"usage: source-disable PROVIDER ROOT")
    case "sources":
      match args:
        case Nil{}:
          sources(db)
        case _:
          failure(Unit,"usage: sources")
    case "refresh-all":
      match args:
        case Nil{}:
          refresh_all(db,data_dir)
        case _:
          failure(Unit,"usage: refresh-all")
    case "search":
      search(db,args)
    case "session":
      session(db,args,False{})
    case "session-scope":
      read_scoped(db,args,False{})
    case "why-scope":
      read_scoped(db,args,True{})
    case "activity-scope":
      Activity.command(db,args)
    case "relations-scope":
      Relations.command(db,"relations-scope",args)
    case "relations-page":
      Relations.command(db,"relations-page",args)
    case "export-range-scope":
      export_scoped(db,args,False{})
    case "export-why-scope":
      export_scoped(db,args,True{})
    case "why":
      why(db,args)
    case "usage":
      usage(db,args)
    case "citation":
      match args:
        case Con{descriptor,Nil{}}:
          citation(db,descriptor)
        case _:
          failure(Unit,"usage: citation JSON")
    case "export":
      match args:
        case Con{snapshot,Con{path,Nil{}}}:
          export_page(db,snapshot,path)
        case _:
          failure(Unit,"usage: export SNAPSHOT PATH")
    case "blame":
      match args:
        case Con{repo,Con{path,Con{start,Con{end,Nil{}}}}}:
          blame(db,repo,path,start,end)
        case _:
          failure(Unit,"usage: blame REPOSITORY FILE START END")
    case "why-file":
      match args:
        case repo <> path <> start <> end <> []:
          why_file(db,repo,path,start,end)
        case _:
          failure(Unit,"usage: why-file REPOSITORY FILE START END")
    case "why-commit":
      match args:
        case repo <> sha <> []:
          why_commit(db,repo,sha)
        case _:
          failure(Unit,"usage: why-commit REPOSITORY SHA")
    case "export-range":
      match args:
        case Con{snapshot,Con{start,Con{count,Con{path,Nil{}}}}}:
          export_range(db,snapshot,start,count,path,False{})
        case _:
          failure(Unit,"usage: export-range SNAPSHOT START COUNT PATH")
    case "export-why":
      match args:
        case Con{snapshot,Con{start,Con{count,Con{path,Nil{}}}}}:
          export_range(db,snapshot,start,count,path,True{})
        case _:
          failure(Unit,"usage: export-why SNAPSHOT START COUNT PATH")
    case "export-blame":
      match args:
        case Con{repo,Con{path,Con{start,Con{end,Con{output,Nil{}}}}}}:
          export_blame(db,repo,path,start,end,output)
        case _:
          failure(Unit,"usage: export-blame REPOSITORY FILE START END PATH")
    case "export-all":
      match args:
        case Con{snapshot,Con{path,Nil{}}}:
          export_all(db,snapshot,path)
        case _:
          failure(Unit,"usage: export-all SNAPSHOT PATH (destination must not exist)")
    case "export-displayed":
      match args:
        case Con{path,Nil{}}:
          export_displayed(db,path)
        case _:
          failure(Unit,"usage: export-displayed PATH; UTF-8 stdin maximum 1048576 bytes")
    case "verify":
      match args:
        case Con{snapshot,Nil{}}:
          maintain(db,snapshot,False{})
        case _:
          failure(Unit,"usage: verify SNAPSHOT")
    case "rebuild":
      match args:
        case Con{snapshot,Nil{}}:
          maintain(db,snapshot,True{})
        case _:
          failure(Unit,"usage: rebuild SNAPSHOT")
    case "help":
      help()
    case "--help":
      help()
    case _:
      failure(Unit,"unknown command; use help")

def run(db: U32,data_dir: String,args: List<String>) -> IO(Unit):
  match args:
    case Nil{}:
      failure(Unit,"no CLI command; the application entry point owns GUI launch")
    case Con{cmd,rest}:
      command(db,data_dir,cmd,rest)

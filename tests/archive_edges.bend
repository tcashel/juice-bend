import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/capture.bend as Capture
import ../src/archive_maintenance.bend as Archive
import ../src/archive_meta.bend as Meta
import ../src/domain.bend as Domain
import ./archive_maintenance.bend as Fixture
import ./archive_publication.bend as Check

def first() -> List<&2,U32>:
  List.append(&2,U32,Domain.encode("{\"type\":\"user\",\"message\":{\"content\":\"tailword caf"),[195])

def second() -> List<&2,U32>:
  169 <> Domain.encode("\"}}\n")

def complete() -> List<&2,U32>:
  Domain.encode("{\"type\":\"user\",\"message\":{\"content\":\"tailword café\"}}\n")

def tails() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/archive-edges-tail.sqlite")
    Fixture.write_bytes("tail.jsonl.zst",Fixture.raw_frame(first()))
    +old : String <- Capture.import_file(db,"claude","tail.jsonl.zst")
    +page : String <- Store.page(db,old,0,10)
    Check.equal_scalar(db,"SELECT complete FROM raw WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",
      [Sql.Cell.Integer{old}],"0","archive retains unfinished JSONL and UTF8 prefix without marking it complete")
    Fixture.write_bytes("tail.jsonl.zst",List.append(&2,U32,Fixture.raw_frame(first()),Fixture.raw_frame(second())))
    +current : String <- Capture.import_file(db,"claude","tail.jsonl.zst")
    Check.equal_scalar(db,"SELECT count(*) FROM snapshots a JOIN snapshots b ON a.generation=b.generation WHERE a.id=? AND b.id=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{current}],"1","frame append completing a UTF8/JSONL tail retains the original generation")
    logical : List<&2,List<&2,U32>> <- Archive.logical(db,current,True{})
    Check.assert(Archive.equal_chunks(logical,[complete()]),"cross-frame UTF8/JSONL completion is exact with one final tail flush")
    Check.equal_scalar(db,"SELECT records FROM snapshots WHERE id=?",[Sql.Cell.Integer{current}],"1",
      "split frame is one complete logical JSONL record")
    hits : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"tailword","claude","","","",10,0)
    Check.assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,hits),1n),"completed archived tail enters native lexical search")
    after : String <- Store.page(db,old,0,10)
    Check.assert(String.eq(page,after),"tail completion cannot mutate the pinned unfinished transcript")
    old_bytes : List<&2,List<&2,U32>> <- Archive.logical(db,old,True{})
    Check.assert(Archive.equal_chunks(old_bytes,[first()]),"pinned incomplete UTF8 bytes survive completion exactly")
    Archive.verify(db,current)
    IO.try(Unit,Sql.close(db))

def source_identity() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/archive-edges-identity.sqlite")
    Fixture.write_bytes("same.jsonl",complete())
    Fixture.write_bytes("same.jsonl.zst",Fixture.raw_frame(complete()))
    +plain : String <- Capture.import_file(db,"claude","same.jsonl")
    +archive : String <- Capture.import_file(db,"claude","same.jsonl.zst")
    Check.assert(Bool.not(String.eq(plain,archive)),"adjacent plain and compressed files keep distinct immutable identities")
    Check.equal_scalar(db,"SELECT count(*) FROM sources",[],"2","archive suffix is retained in canonical source identity")
    Check.equal_scalar(db,"SELECT count(DISTINCT source) FROM generations",[],"2","equal logical bytes do not merge source generations")
    Check.equal_scalar(db,"SELECT count(*) FROM generations WHERE encoding='identity'",[],"1","ordinary source retains identity encoding")
    Check.equal_scalar(db,"SELECT count(*) FROM generations WHERE encoding='zstd-jsonl-v1'",[],"1","archive source retains explicit compressed encoding")
    IO.try(Unit,Sql.close(db))

def skippable() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/archive-edges-skippable.sqlite")
    +container : List<&2,U32> = [80,42,77,24,3,0,0,0,4,5,6]
    Fixture.write_bytes("skip.jsonl.zst",container)
    +snapshot : String <- Capture.import_file(db,"claude","skip.jsonl.zst")
    Check.equal_scalar(db,"SELECT extent FROM snapshots WHERE id=?",[Sql.Cell.Integer{snapshot}],"0",
      "valid skippable-only container has zero logical extent")
    Check.equal_scalar(db,"SELECT count(*) FROM raw",[],"0","empty logical archive invents no record")
    Check.equal_scalar(db,"SELECT count(*) FROM search",[],"0","empty logical archive invents no searchable event")
    retained : List<&2,List<&2,U32>> <- Meta.container(db,snapshot,True{})
    Check.assert(Archive.equal_chunks(retained,[container]),"skippable-only physical evidence remains exact and owned")
    page : String <- Store.page(db,snapshot,0,0)
    Check.assert(String.contains(page,"0 retained logical source bytes"),"zero-record archive page validates origin and labels logical extent")
    Archive.verify(db,snapshot)
    IO.try(Unit,Sql.close(db))

def main() -> IO(Unit):
  do IO<Unit>:
    tails()
    source_identity()
    skippable()
    IO.print("Archive edge suite passed")

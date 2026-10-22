import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/scoped_reader.bend as Scoped
import ../src/domain.bend as Domain
import ../src/paths.bend as Paths
import ../benchmarks/native_attachments.bend as Fixture
import ../benchmarks/native_transcript_oracle.bend as Oracle

# Exercise the independent native-acceptance oracle against real retained reads.
# This is a portable renderer/evidence gate, not a macOS interaction receipt.
def main() -> IO(Unit):
  +fixture = Fixture.fixture()
  +extent = U32.show(U32.from_nat(List.length(&2,U32,Domain.encode(fixture))))
  do IO<Unit>:
    Store.write_text("transcript-oracle.jsonl","w",fixture)
    +source : String <- Paths.resolve("transcript-oracle.jsonl")
    +db : U32 <- Store.open(".build/transcript-oracle.sqlite")
    +snapshot : String <- Store.import_file(db,"claude",source)
    Store.checked(String.eq(snapshot,"1"),"Independent transcript oracle expects the first captured snapshot")
    +first : String <- Scoped.page(db,snapshot,0,40,Scoped.Scope{"claude","","",""},False{})
    Oracle.page_assertions("first",first,source,extent)
    IO.print("PASS independent first-page oracle preserves all payloads, references and coverage")
    +late : String <- Scoped.page(db,snapshot,40,40,Scoped.Scope{"claude","","",""},False{})
    Oracle.page_assertions("late",late,source,extent)
    IO.print("PASS independent late-page oracle keeps exact two-event range")
    +filtered : String <- Scoped.page(db,snapshot,40,40,Scoped.Scope{"claude","/synthetic/attachments","user","2026-10-20"},False{})
    Oracle.page_assertions("filtered",filtered,source,extent)
    IO.print("PASS independent role-filtered oracle excludes assistant and retains exact citation")
    Store.write_text("transcript-oracle.jsonl","w","source replaced")
    +retained : String <- Scoped.page(db,snapshot,0,40,Scoped.Scope{"claude","","",""},False{})
    Store.checked(String.eq(first,retained),"Source replacement changed retained oracle page")
    Oracle.page_assertions("first",retained,source,extent)
    IO.print("PASS independent oracle remains exact after source replacement")
    IO.try(Unit,Sql.close(db))

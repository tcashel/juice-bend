import Base
import ../src/file_evidence.bend as F
import ../src/provenance.bend as P

def check(ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS commit Why scopes trailer/body status and preserves message, excerpt and citation bytes")
    case False{}: IO.die(Unit,1,"FAIL commit Why trailer/body wording or preserved evidence bytes")

def main() -> IO(Unit):
  check(String.eq(F.commit_text("synthetic-sha","Synthetic message",
    P.NotIndexed{"no eligible captured identity in this repository"},"Captured request café 中文 🙂\nCitation: synthetic-citation\n"),
    "Juice Bend · commit Why\nRead-only Git commit synthetic-sha\nTrailer/body associations: not_indexed · no eligible captured identity in this repository" ++
      "\nTrailer/body coverage: unique eligible trailer/body associations only; no time-based guess or generated rationale. File content matching requires a selected file range.\n\n" ++
      "Captured request café 中文 🙂\nCitation: synthetic-citation\nRead-only Git commit message:\nSynthetic message\n") &&
    String.eq(F.commit_text("synthetic-sha","Synthetic message",P.Exact{"synthetic-citation"},""),
      "Juice Bend · commit Why\nRead-only Git commit synthetic-sha\nTrailer/body associations: exact\nCitation: synthetic-citation" ++
        "\nTrailer/body coverage: unique eligible trailer/body associations only; no time-based guess or generated rationale. File content matching requires a selected file range.\n\n" ++
        "Read-only Git commit message:\nSynthetic message\n"))

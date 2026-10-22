import Base
import ../src/git_diff.bend as Diff

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def header() -> String:
  "diff --git a/a.bend b/a.bend\nindex 1111111..2222222 100644\n--- a/a.bend\n+++ b/a.bend\n"

def lines_equal(a: List<&2,String>,b: List<&2,String>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case x <> xs y <> ys:
      String.eq(x,y) && lines_equal(xs,ys)
    case _ _:
      False{}

def one(result: Result<&2,&2,String,List<&2,Diff.Hunk>>,start: U32,count: U32,
  lines: List<&2,String>) -> Bool:
  match result:
    case Done{Diff.Hunk{actual,size,text} <> Nil{}}:
      U32.is_eq(actual,start) && U32.is_eq(size,count) && lines_equal(text,lines)
    case _:
      False{}

def rejected(result: Result<&2,&2,String,List<&2,Diff.Hunk>>) -> Bool:
  match result:
    case Fail{_}:
      True{}
    case _:
      False{}

def count(result: Result<&2,&2,String,List<&2,Diff.Hunk>>,expected: Nat) -> Bool:
  match result:
    case Done{hunks}:
      Nat.is_eq(List.length(&2,Diff.Hunk,hunks),expected)
    case _:
      False{}

def hunks(left: Nat,+index: U32) -> String:
  match left:
    case 0n:
      ""
    case 1n+rest:
      "@@ -0,0 +" ++ U32.show(index) ++ " @@\n+line\n" ++ hunks(rest,U32.add(index,1))

def bad(payload: String,name: String) -> IO(Unit):
  assert(rejected(Diff.parse(header() ++ payload)),name)

def main() -> IO(Unit):
  do IO<Unit>:
    assert(count(Diff.parse(""),0n),"empty patch has no attributed region")
    assert(one(Diff.parse(header() ++ "@@ -5 +9 @@ function text\n-old\n+new\n"),
      9,1,["new"]),"implicit single counts and section title")
    assert(one(Diff.parse(header() ++ "@@ -0,0 +1,2 @@\n+  café 🍋\n+\n"),
      1,2,["  café 🍋",""]),"root addition preserves Unicode indentation and blank line")
    assert(one(Diff.parse(header() ++ "@@ -1,2 +0,0 @@\n-first\n-second\n"),
      0,0,[]),"deletion hunk remains zero added lines")
    assert(one(Diff.parse(header() ++ "@@ -1 +1 @@\n-old\n\\ No newline at end of file\n+new\n\\ No newline at end of file\n"),
      1,1,["new"]),"no-newline markers excluded from counts and content")
    assert(one(Diff.parse(header() ++ "@@ -1 +1 @@\n--- old prefix\n+++ new prefix\n"),
      1,1,["++ new prefix"]),"header-looking payload stays inside its hunk")
    assert(count(Diff.parse(header() ++ "@@ -1 +1 @@\n-a\n+b\n@@ -9,0 +10 @@\n+c\n"),2n),
      "multiple disjoint hunks retained")
    assert(one(Diff.parse(header() ++ "@@ -0,0 +4294967295 @@\n+x\n"),4294967295,1,["x"]),
      "maximum line coordinate remains exact")
    assert(count(Diff.parse("diff --git a/a b/a\nold mode 100644\nnew mode 100755\n"),0n),
      "mode-only change has no text attribution")
    bad("@@ -1 +1,2 @@\n-a\n+b\n","truncated additions rejected")
    bad("@@ -1,2 +1 @@\n-a\n+b\n","truncated removals rejected")
    bad("@@ -1 +1 @@\n-a\n-b\n+c\n","extra removals rejected")
    bad("@@ -1 +1 @@\n-a\n+b\n+c\n","extra additions rejected")
    bad("@@ -1 +1 @@\n-a\n+b\n@@ -2 +1 @@\n-c\n+d\n","overlapping added regions rejected")
    bad("@@ +1 +1 @@\n-a\n+b\n","wrong old-range sign rejected")
    bad("@@ -1 +0 @@\n-a\n+b\n","zero start with nonempty range rejected")
    bad("@@ -1 +4294967295,2 @@\n-a\n+b\n+c\n","range endpoint overflow rejected")
    bad("@@ -1 +4294967296 @@\n-a\n+b\n","out-of-range decimal rejected")
    bad("@@ -01 +1 @@\n-a\n+b\n","noncanonical decimal rejected")
    bad("@@@ -1,1 -1,1 +1,1 @@@\n+x\n","combined diff rejected")
    bad("@@ -1 +1 @@\n context\n","unexpected context rejected in unified-zero parser")
    bad("\\ No newline at end of file\n","orphan marker rejected")
    bad("@@ -0,0 +1 @@\n+x\n\\ No newline at end of file\n\\ No newline at end of file\n",
      "duplicate marker rejected")
    bad("@@ -1 +1 @@\n-a\n+b","unterminated patch output rejected")
    bad("unexpected metadata\n","unknown metadata rejected")
    bad("@@ -0,0 +1 @@\n+\0\n","binary NUL rejected")
    assert(rejected(Diff.parse("diff --git a/a b/a\nBinary files a/a and b/a differ\n")),
      "binary file diff rejected")
    assert(rejected(Diff.parse("diff --git a/a b/a\nGIT binary patch\nliteral 1\n")),
      "binary patch rejected")
    assert(rejected(Diff.parse("@@ -1 +1 @@\n-a\n+b\n")),"missing file headers rejected")
    assert(rejected(Diff.parse("diff --git a/a b/a\n--- a/a\n")),"incomplete file header rejected")
    assert(rejected(Diff.parse(header() ++ "@@ -0,0 +1 @@\n+x\n" ++ header())),
      "multiple file sections rejected")
    assert(count(Diff.parse(header() ++ hunks(128n,1)),128n),"exact 128 hunk bound accepted")
    assert(rejected(Diff.parse(header() ++ hunks(129n,1))),"129 hunks rejected")
    assert(rejected(Diff.parse(header() ++ "@@ -0,0 +1 @@\n+" ++ String.repeat("🍋",262144n) ++ "\n")),
      "1 MiB limit counts UTF-8 bytes rather than scalar count")
    +prefix : String = header() ++ "@@ -0,0 +1 @@\n+"
    assert(count(Diff.parse(prefix ++ String.repeat("a",Nat.sub(1048575n,String.length(prefix))) ++ "\n"),1n),
      "exact 1 MiB patch accepted")
    assert(rejected(Diff.parse(String.repeat("a",1048577n) ++ "\n")),
      "oversized patch rejected")

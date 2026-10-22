import Base
import ../src/bend_ui/text_line.bend as L
import ../src/sans_font.bend as Sans

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def lines(result: Result<&2,&2,L.Failure,List<&2,L.Line>>) -> List<&2,L.Line>:
  match result:
    case Done{value}: value
    case Fail{_}: []

def failed(result: Result<&2,&2,L.Failure,List<&2,L.Line>>) -> Bool:
  match result:
    case Fail{_}: True{}
    case _: False{}

def first(lines: List<&2,L.Line>) -> L.Line:
  match lines:
    case []: L.Line{0,"",0,[],0}
    case line <> _: line

def joined(lines: List<&2,L.Line>) -> String:
  match lines:
    case []: ""
    case line <> rest: L.text(line) ++ joined(rest)

def exact(lines: List<&2,L.Line>,+original: String,+origin: U32,+width: U32) -> Bool:
  match lines:
    case []: True{}
    case L.Line{+start,+text,+count,+ends,+used} <> rest:
      String.eq(text,String.take(String.drop(original,U32.to_nat(U32.sub(start,origin))),U32.to_nat(count))) &&
        U32.is_eq(count,U32.from_nat(String.length(text))) && U32.is_eq(count,U32.from_nat(List.length(&2,U32,ends))) &&
        U32.is_le(used,width) && exact(rest,original,origin,width)

def boundaries(ends: List<&2,U32>,+line: L.Line,+at: U32,+previous: U32) -> Bool:
  match ends:
    case []: True{}
    case +edge <> rest:
      U32.is_gt(edge,previous) && U32.is_eq(L.hit(line,edge),U32.add(L.start(line),U32.inc(at))) &&
        boundaries(rest,line,U32.inc(at),edge)

def roundtrip(+line: L.Line) -> Bool:
  L.Line{_,_,_,ends,_} = line
  U32.is_eq(L.hit(line,0),L.start(line)) && boundaries(ends,line,0,0)

def wrapping() -> IO(Unit):
  +source : String = "Wide WWW then narrow iii; exact spaces stay. "
  +rows : List<&2,L.Line> = lines(L.wrap(source,17,86))
  +long : String = String.repeat("i",180n)
  +long_rows : List<&2,L.Line> = lines(L.wrap(long,0,640))
  +unicode : String = "café é 中文 🙂\tW"
  +unicode_line : L.Line = first(lines(L.wrap(unicode,91,640)))
  +blank : List<&2,L.Line> = lines(L.wrap("A\n\nB\n",7,640))
  do IO<Unit>:
    check(U32.is_gt(U32.from_nat(List.length(&2,L.Line,rows)),1) && exact(rows,source,17,86),"proportional wrap retains exact source slices within the pixel width")
    check(String.eq(joined(rows),source),"soft wrapping inserts or drops no whitespace or scalars")
    check(String.eq(joined(long_rows),long) && exact(long_rows,long,0,640),"long narrow-glyph body is never ellipsized or truncated at 128 scalars")
    check(U32.is_gt(L.count(first(long_rows)),128),"a valid prose row can exceed the label rasterizer's old 128-scalar limit")
    check(String.eq(L.text(unicode_line),unicode) && U32.is_eq(L.count(unicode_line),U32.from_nat(String.length(unicode))),"tabs combining marks CJK and emoji retain original scalar identity")
    check(roundtrip(unicode_line),"all Unicode and fallback scalar insertion edges round-trip through cached hit testing")
    check(U32.is_eq(U32.from_nat(List.length(&2,L.Line,blank)),3) && exact(blank,"A\n\nB\n",7,640),"blank lines consume original LF offsets without a phantom terminal row")
    check(String.eq(joined(blank),"AB"),"newline display suppression does not manufacture painted characters")
    check(List.is_empty(&2,L.Line,lines(L.wrap("",5,640))),"empty source creates no phantom prose row")
    check(failed(L.wrap("unmodified",0,0)) && failed(L.wrap("unmodified",0,2049)),"invalid widths fail explicitly before producing partial layout")
    check(failed(L.wrap("W",0,1)),"a glyph wider than its row returns explicit failure for complete mono fallback")
    check(failed(L.wrap("ab",4294967294,640)),"source offset overflow is refused")

def hits() -> IO(Unit):
  +line : L.Line = first(lines(L.wrap("iW i\t🙂",40,640)))
  +i : U32 = L.edge(line,1)
  +w : U32 = L.edge(line,2)
  +tab : L.Line = first(lines(L.wrap("\t",0,640)))
  +other : L.Line = first(lines(L.wrap("🙂",0,640)))
  do IO<Unit>:
    check(U32.is_lt(i,U32.sub(w,i)),"cached proportional boundaries distinguish narrow i from wide W")
    check(U32.is_eq(L.hit(line,i),41) && U32.is_eq(L.hit(line,w),42),"exact insertion boundaries map to exact visible scalar offsets")
    check(U32.is_eq(L.hit(line,0),40) && U32.is_eq(L.hit(line,9999),U32.add(40,L.count(line))),"pointer edges clamp to start and end of the cached line")
    check(U32.is_eq(L.hit(line,U32.sub(i,1)),41) && U32.is_eq(L.hit(line,U32.inc(i)),41),"pixel hit uses the nearest insertion edge across different advances")
    check(U32.is_eq(L.edge(line,9999),L.width(line)) && U32.is_eq(L.edge(line,0),0),"selection pixel edges clamp without changing scalar intervals")
    check(U32.is_eq(L.width(tab),Sans.advance(Sans.glyph(0,8594))),"tab's cached advance matches its painted arrow, while copy retains tab")
    check(U32.is_eq(L.width(other),Sans.advance(Sans.glyph(0,128578))),"unavailable glyph advance matches the actual replacement rendering")
    check(roundtrip(line),"mixed narrow wide whitespace tab and fallback boundaries all round-trip")

def main() -> IO(Unit):
  do IO<Unit>:
    wrapping()
    hits()

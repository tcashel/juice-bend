import Base
import ./font_unboxed_reference.bend as Old
import ../src/sans_font.bend as New

# Exhaustive public-accessor comparison with the byte-exact unboxed baseline.
# Only primitive coordinates cross helper boundaries: never retain two large
# baseline Glyph values together in a test continuation.
def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def same_word(+face: U32,+code: U32,+word: U32,+y: U32) -> Bool:
  U32.is_eq(Old.row_word(Old.glyph(face,code),word,y),New.row_word(New.glyph(face,code),word,y))

def same_pixel(+face: U32,+code: U32,+x: U32,+y: U32) -> Bool:
  U32.is_eq(Old.coverage(Old.glyph(face,code),x,y),New.coverage(New.glyph(face,code),x,y))

def same_advance(+face: U32,+code: U32) -> Bool:
  U32.is_eq(Old.advance(Old.glyph(face,code)),New.advance(New.glyph(face,code)))

def words(fuel: Nat,+face: U32,+code: U32,+at: U32) -> Bool:
  match fuel:
    case 0n: U32.is_eq(at,128)
    case 1n+rest: same_word(face,code,U32.mod(at,4),U32.div(at,4)) && words(rest,face,code,U32.add(at,1))

def pixels(fuel: Nat,+face: U32,+code: U32,+at: U32) -> Bool:
  match fuel:
    case 0n: U32.is_eq(at,1024)
    case 1n+rest: same_pixel(face,code,U32.mod(at,32),U32.div(at,32)) && pixels(rest,face,code,U32.add(at,1))

def zero_word(+face: U32,+code: U32,+word: U32,+y: U32) -> Bool:
  U32.is_eq(Old.row_word(Old.glyph(face,code),word,y),0) && U32.is_eq(New.row_word(New.glyph(face,code),word,y),0)

def zero_pixel(+face: U32,+code: U32,+x: U32,+y: U32) -> Bool:
  U32.is_eq(Old.coverage(Old.glyph(face,code),x,y),0) && U32.is_eq(New.coverage(New.glyph(face,code),x,y),0)

def invalid_rows(fuel: Nat,+face: U32,+code: U32,+at: U32) -> Bool:
  match fuel:
    case 0n: U32.is_eq(at,32)
    case 1n+rest:
      zero_word(face,code,4,at) && zero_word(face,code,4294967295,at) &&
      zero_pixel(face,code,32,at) && zero_pixel(face,code,4294967295,at) &&
      zero_pixel(face,code,at,32) && zero_pixel(face,code,at,4294967295) &&
      invalid_rows(rest,face,code,U32.add(at,1))

def invalid_words(fuel: Nat,+face: U32,+code: U32,+at: U32) -> Bool:
  match fuel:
    case 0n: U32.is_eq(at,4)
    case 1n+rest:
      zero_word(face,code,at,32) && zero_word(face,code,at,4294967295) &&
      invalid_words(rest,face,code,U32.add(at,1))

def extras() -> List<&2,U32>:
  [8211,8212,8216,8217,8220,8221,8226,8230,8592,8593,8594,8595,65533]

def special(codes: List<&2,U32>,+face: U32) -> Bool:
  match codes:
    case []: True{}
    case +code <> rest:
      same_advance(face,code) && words(128n,face,code,0) && pixels(1024n,face,code,0) &&
      invalid_rows(32n,face,code,0) && invalid_words(4n,face,code,0) && special(rest,face)

def range(fuel: Nat,+face: U32,+code: U32) -> Bool:
  match fuel:
    case 0n: True{}
    case 1n+rest:
      same_advance(face,code) && words(128n,face,code,0) && pixels(1024n,face,code,0) &&
      invalid_rows(32n,face,code,0) && invalid_words(4n,face,code,0) && range(rest,face,U32.add(code,1))

# Independently verify documented unknown-code fallback, not only old/new parity.
def fallback_word(+face: U32,+code: U32,+at: U32) -> Bool:
  U32.is_eq(New.row_word(New.glyph(face,code),U32.mod(at,4),U32.div(at,4)),
    New.row_word(New.glyph(face,65533),U32.mod(at,4),U32.div(at,4)))

def fallback_words(fuel: Nat,+face: U32,+code: U32,+at: U32) -> Bool:
  match fuel:
    case 0n: U32.is_eq(at,128)
    case 1n+rest: fallback_word(face,code,at) && fallback_words(rest,face,code,U32.add(at,1))

def unknowns(codes: List<&2,U32>,+face: U32) -> Bool:
  match codes:
    case []: True{}
    case +code <> rest:
      same_advance(face,code) && words(128n,face,code,0) && pixels(1024n,face,code,0) &&
      U32.is_eq(New.advance(New.glyph(face,code)),New.advance(New.glyph(face,65533))) &&
      fallback_words(128n,face,code,0) && unknowns(rest,face)

def unknown_codes() -> List<&2,U32>:
  [0,31,127,159,256,769,20013,128578,4294967295]

def fallback_face_words(fuel: Nat,+face: U32,+code: U32,+at: U32) -> Bool:
  match fuel:
    case 0n: U32.is_eq(at,128)
    case 1n+rest:
      same_word(face,code,U32.mod(at,4),U32.div(at,4)) &&
      U32.is_eq(New.row_word(New.glyph(face,code),U32.mod(at,4),U32.div(at,4)),
        New.row_word(New.glyph(0,code),U32.mod(at,4),U32.div(at,4))) &&
      fallback_face_words(rest,face,code,U32.add(at,1))

def fallback_face_code(+face: U32,+code: U32) -> Bool:
  same_advance(face,code) &&
  U32.is_eq(New.advance(New.glyph(face,code)),New.advance(New.glyph(0,code))) &&
  fallback_face_words(128n,face,code,0) && pixels(1024n,face,code,0)

def fallback_face_range(fuel: Nat,+face: U32,+code: U32) -> Bool:
  match fuel:
    case 0n: True{}
    case 1n+rest: fallback_face_code(face,code) && fallback_face_range(rest,face,U32.add(code,1))

def fallback_face_special(codes: List<&2,U32>,+face: U32) -> Bool:
  match codes:
    case []: True{}
    case code <> rest: fallback_face_code(face,code) && fallback_face_special(rest,face)

def metrics(+face: U32,+baseline: U32,+height: U32) -> Bool:
  U32.is_eq(Old.baseline(face),baseline) && U32.is_eq(New.baseline(face),baseline) &&
  U32.is_eq(Old.height(face),height) && U32.is_eq(New.height(face),height)

def face(+id: U32) -> IO(Unit):
  do IO<Unit>:
    require(range(95n,id,32),"face " ++ U32.show(id) ++ " ASCII: 95 advances, 12160 row words, 97280 pixels, invalid coordinate zeros")
    require(range(96n,id,160),"face " ++ U32.show(id) ++ " Latin1: 96 advances, 12288 row words, 98304 pixels, invalid coordinate zeros")
    require(special(extras(),id),"face " ++ U32.show(id) ++ " extra: 13 advances, 1664 row words, 13312 pixels, invalid coordinate zeros")
    require(unknowns(unknown_codes(),id),"face " ++ U32.show(id) ++ " nine unknown codes: exact U+FFFD advance, words and pixel parity")

def fallback_face(+id: U32) -> IO(Unit):
  do IO<Unit>:
    require(fallback_face_range(95n,id,32),"unknown face " ++ U32.show(id) ++ " ASCII is face0 with old/new pixel parity")
    require(fallback_face_range(96n,id,160),"unknown face " ++ U32.show(id) ++ " Latin1 is face0 with old/new pixel parity")
    require(fallback_face_special(extras(),id),"unknown face " ++ U32.show(id) ++ " extra is face0 with old/new pixel parity")
    require(unknowns(unknown_codes(),id),"unknown face " ++ U32.show(id) ++ " nine unknown code fallbacks")

def main() -> IO(Unit):
  do IO<Unit>:
    require(metrics(0,16,24),"regular14 metrics")
    require(metrics(1,16,24),"semibold14 metrics")
    require(metrics(2,24,32),"semibold22 metrics")
    require(metrics(3,16,24),"unknown face3 metrics fall back to regular14")
    require(metrics(4294967295,16,24),"maximum face metrics fall back to regular14")
    face(0)
    face(1)
    face(2)
    fallback_face(3)
    fallback_face(4294967295)

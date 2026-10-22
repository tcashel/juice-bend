# Static 4-bit glyph data derived from Inter 4.1; font data is SIL OFL 1.1.
# Copyright (c) 2016 The Inter Project Authors (https://github.com/rsms/inter).
# See ../assets/fonts/inter-ui/OFL.txt and manifest.json. No runtime font parser.
# Generated offline by ../scripts/sans-font-pack.py.
import Base

type Row is Data:
  Row{a: U32,b: U32,c: U32,d: U32}

type Rows8 is Data:
  Rows8{a: Row,b: Row,c: Row,d: Row,e: Row,f: Row,g: Row,h: Row}

type Glyph is Data:
  Glyph{advance: U32,blocks: List<&2,Rows8>}

def zero_row() -> Row:
  Row{0,0,0,0}

def zero_rows() -> Rows8:
  Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()}

def advance(bits: Glyph) -> U32:
  Glyph{width,_} = bits
  width

def row_word.select_word(row: Row,word: U32) -> U32:
  Row{a,b,c,d} = row
  match word:
    case 0: a
    case 1: b
    case 2: c
    case 3: d
    case _: 0

def row_word.select_row(rows: Rows8,y: U32) -> Row:
  Rows8{a,b,c,d,e,f,g,h} = rows
  match y:
    case 0: a
    case 1: b
    case 2: c
    case 3: d
    case 4: e
    case 5: f
    case 6: g
    case 7: h
    case _: zero_row()

# A recursive list is a boxed representation boundary. Generated glyphs carry
# exactly four Rows8 blocks; public out-of-bounds coordinates still return zero.
def row_word.block(blocks: List<&2,Rows8>,index: U32) -> Rows8:
  match blocks index:
    case Nil{} _: zero_rows()
    case Con{head,_} 0: head
    case Con{_,rest} n: row_word.block(rest,U32.sub(n,1))

def row_word.block_checked(blocks: List<&2,Rows8>,index: U32,valid: Bool) -> Rows8:
  match valid:
    case True{}: row_word.block(blocks,index)
    case False{}: zero_rows()

def row_word.select_block(bits: Glyph,+block: U32) -> Rows8:
  Glyph{_,blocks} = bits
  row_word.block_checked(blocks,block,U32.is_lt(block,4))

# Four little-nibble-x words per row. Out-of-range word or y returns zero.
def row_word(bits: Glyph,word: U32,+y: U32) -> U32:
  row_word.select_word(row_word.select_row(row_word.select_block(bits,U32.div(y,8)),U32.mod(y,8)),word)

# Returns a coverage level in 0..15. Coordinates outside 32 x 32 return zero.
def coverage(bits: Glyph,+x: U32,y: U32) -> U32:
  U32.and(U32.shrn(row_word(bits,U32.div(x,8),y),U32.to_nat(U32.mul(U32.mod(x,8),4))),15)

# Face 0 = regular 14 px; face 1 = semibold 14 px; face 2 = semibold 22 px.
# All glyph pixels have nonnegative x/y, with ink contained inside advance.
def baseline(face: U32) -> U32:
  match face:
    case 2: 24
    case _: 16

def height(face: U32) -> U32:
  match face:
    case 2: 32
    case _: 24



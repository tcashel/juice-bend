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


def face0.missing() -> Glyph:
  Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{251656960,0,0,0},Row{251263744,0,0,0},Row{251656960,0,0,0},Row{251239168,0,0,0}},Rows8{Row{251656960,0,0,0},Row{251263744,0,0,0},Row{245365504,0,0,0},Row{249420544,0,0,0},Row{245340928,0,0,0},Row{251656960,0,0,0},Row{244288256,0,0,0},Row{241404672,0,0,0}},Rows8{Row{251656960,0,0,0},Row{249096960,0,0,0},Row{251656960,0,0,0},Row{53686784,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}

def face0lllllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[zero_rows(),zero_rows(),zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lllllll(code: U32) -> Glyph:
  face0lllllll.choose(U32.is_eq(code,32))

def face0llllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2720,0,0,0},Row{2720,0,0,0},Row{2720,0,0,0}},Rows8{Row{2720,0,0,0},Row{2720,0,0,0},Row{2704,0,0,0},Row{2448,0,0,0},zero_row(),zero_row(),Row{2448,0,0,0},Row{2992,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llllllrl(code: U32) -> Glyph:
  face0llllllrl.choose(U32.is_eq(code,33))

def face0llllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2046848,0,0,0},Row{998272,0,0,0},Row{993904,0,0,0}},Rows8{Row{924000,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llllllrr(code: U32) -> Glyph:
  face0llllllrr.choose(U32.is_eq(code,34))

def face0llllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llllllrl(code)
    case False{}: face0llllllrr(code)

def face0llllllr(+code: U32) -> Glyph:
  face0llllllr.choose(code,U32.is_lt(code,34))

def face0llllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllllll(code)
    case False{}: face0llllllr(code)

def face0llllll(+code: U32) -> Glyph:
  face0llllll.choose(code,U32.is_lt(code,33))

def face0lllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2013323776,0,0,0},Row{1509995520,0,0,0},Row{1023448576,0,0,0}},Rows8{Row{4294967281,8,0,0},Row{776104992,1,0,0},Row{188755200,0,0,0},Row{157290240,0,0,0},Row{4026531834,0,0,0},Row{650259298,0,0,0},Row{47188080,0,0,0},Row{15795856,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lllllrl(code: U32) -> Glyph:
  face0lllllrl.choose(U32.is_eq(code,35))

def face0lllllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{786432,0,0,0},Row{435148544,0,0,0},Row{2657971824,0,0,0},Row{3289122768,0,0,0}},Rows8{Row{788688,0,0,0},Row{892768,0,0,0},Row{418362368,0,0,0},Row{2926379008,0,0,0},Row{4077649920,2,0,0},Row{4077651169,2,0,0},Row{3177012656,0,0,0},Row{451930384,0,0,0}},Rows8{Row{786432,0,0,0},Row{393216,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lllllrrl(code: U32) -> Glyph:
  face0lllllrrl.choose(U32.is_eq(code,36))

def face0lllllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{784640,2432,0,0},Row{7093568,467,0,0},Row{8915552,92,0,0}},Rows8{Row{1886063696,10,0,0},Row{3793615872,2,0,0},Row{1795170304,0,0,0},Row{207618048,28354,0,0},Row{65077248,128154,0,0},Row{9043968,184396,0,0},Row{868352,128138,0,0},Row{315648,28370,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lllllrrr(code: U32) -> Glyph:
  face0lllllrrr.choose(U32.is_eq(code,37))

def face0lllllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllllrrl(code)
    case False{}: face0lllllrrr(code)

def face0lllllrr(+code: U32) -> Glyph:
  face0lllllrr.choose(code,U32.is_lt(code,37))

def face0lllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllllrl(code)
    case False{}: face0lllllrr(code)

def face0lllllr(+code: U32) -> Glyph:
  face0lllllr.choose(code,U32.is_lt(code,36))

def face0lllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llllll(code)
    case False{}: face0lllllr(code)

def face0lllll(+code: U32) -> Glyph:
  face0lllll.choose(code,U32.is_lt(code,35))

def face0llllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{9365248,0,0,0},Row{98848576,0,0,0},Row{130026864,0,0,0}},Rows8{Row{48779056,0,0,0},Row{5175552,0,0,0},Row{785424,0,0,0},Row{4051577792,3,0,0},Row{4159963891,1,0,0},Row{2944401907,0,0,0},Row{3216259792,0,0,0},Row{3819891488,6,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llllrll(code: U32) -> Glyph:
  face0llllrll.choose(U32.is_eq(code,38))

def face0llllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2944,0,0,0},Row{2944,0,0,0},Row{2672,0,0,0}},Rows8{Row{2400,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llllrlrl(code: U32) -> Glyph:
  face0llllrlrl.choose(U32.is_eq(code,39))

def face0llllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{319744,0,0,0},Row{55040,0,0,0},Row{31744,0,0,0}},Rows8{Row{16144,0,0,0},Row{3648,0,0,0},Row{3424,0,0,0},Row{3184,0,0,0},Row{3184,0,0,0},Row{3408,0,0,0},Row{12064,0,0,0},Row{27904,0,0,0}},Rows8{Row{50944,0,0,0},Row{254208,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0llllrlrr(code: U32) -> Glyph:
  face0llllrlrr.choose(U32.is_eq(code,40))

def face0llllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llllrlrl(code)
    case False{}: face0llllrlrr(code)

def face0llllrlr(+code: U32) -> Glyph:
  face0llllrlr.choose(code,U32.is_lt(code,40))

def face0llllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llllrll(code)
    case False{}: face0llllrlr(code)

def face0llllrl(+code: U32) -> Glyph:
  face0llllrl.choose(code,U32.is_lt(code,39))

def face0llllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{754,0,0,0},Row{2224,0,0,0},Row{3424,0,0,0}},Rows8{Row{12064,0,0,0},Row{27904,0,0,0},Row{31744,0,0,0},Row{39424,0,0,0},Row{35328,0,0,0},Row{31744,0,0,0},Row{20240,0,0,0},Row{3664,0,0,0}},Rows8{Row{2480,0,0,0},Row{754,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0llllrrl(code: U32) -> Glyph:
  face0llllrrl.choose(U32.is_eq(code,41))

def face0llllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{57344,0,0,0},Row{27447969,0,0,0},Row{7204192,0,0,0}},Rows8{Row{6089808,0,0,0},Row{28496817,0,0,0},Row{57344,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llllrrrl(code: U32) -> Glyph:
  face0llllrrrl.choose(U32.is_eq(code,42))

def face0llllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{4063232,0,0,0},Row{4063232,0,0,0},Row{4063232,0,0,0},Row{4026531744,0,0,0},Row{576594464,0,0,0},Row{4063232,0,0,0},Row{4063232,0,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llllrrrr(code: U32) -> Glyph:
  face0llllrrrr.choose(U32.is_eq(code,43))

def face0llllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llllrrrl(code)
    case False{}: face0llllrrrr(code)

def face0llllrrr(+code: U32) -> Glyph:
  face0llllrrr.choose(code,U32.is_lt(code,43))

def face0llllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llllrrl(code)
    case False{}: face0llllrrr(code)

def face0llllrr(+code: U32) -> Glyph:
  face0llllrr.choose(code,U32.is_lt(code,42))

def face0llllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llllrl(code)
    case False{}: face0llllrr(code)

def face0llllr(+code: U32) -> Glyph:
  face0llllr.choose(code,U32.is_lt(code,41))

def face0llll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllll(code)
    case False{}: face0llllr(code)

def face0llll(+code: U32) -> Glyph:
  face0llll.choose(code,U32.is_lt(code,38))

def face0lllrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2960,0,0,0},Row{1968,0,0,0}},Rows8{Row{992,0,0,0},Row{225,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lllrlll(code: U32) -> Glyph:
  face0lllrlll.choose(U32.is_eq(code,44))

def face0lllrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),Row{8388592,0,0,0},Row{1188384,0,0,0},zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lllrllrl(code: U32) -> Glyph:
  face0lllrllrl.choose(U32.is_eq(code,45))

def face0lllrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2448,0,0,0},Row{2992,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lllrllrr(code: U32) -> Glyph:
  face0lllrllrr.choose(U32.is_eq(code,46))

def face0lllrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllrllrl(code)
    case False{}: face0lllrllrr(code)

def face0lllrllr(+code: U32) -> Glyph:
  face0lllrllr.choose(code,U32.is_lt(code,46))

def face0lllrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllrlll(code)
    case False{}: face0lllrllr(code)

def face0lllrll(+code: U32) -> Glyph:
  face0lllrll.choose(code,U32.is_lt(code,45))

def face0lllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{344064,0,0,0},Row{499712,0,0,0},Row{253952,0,0,0}},Rows8{Row{58112,0,0,0},Row{42752,0,0,0},Row{27392,0,0,0},Row{11776,0,0,0},Row{3392,0,0,0},Row{2432,0,0,0},Row{1728,0,0,0},Row{753,0,0,0}},Rows8{Row{212,0,0,0},Row{152,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lllrlrl(code: U32) -> Glyph:
  face0lllrlrl.choose(U32.is_eq(code,47))

def face0lllrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{63952128,0,0,0},Row{780300080,0,0,0},Row{2348812720,0,0,0}},Rows8{Row{3338667248,0,0,0},Row{3841983218,0,0,0},Row{4093641202,0,0,0},Row{3841983218,0,0,0},Row{3338667248,0,0,0},Row{2348812720,0,0,0},Row{780300096,0,0,0},Row{63952128,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lllrlrrl(code: U32) -> Glyph:
  face0lllrlrrl.choose(U32.is_eq(code,48))

def face0lllrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{522768,0,0,0},Row{515521,0,0,0},Row{508341,0,0,0}},Rows8{Row{507905,0,0,0},Row{507904,0,0,0},Row{507904,0,0,0},Row{507904,0,0,0},Row{507904,0,0,0},Row{507904,0,0,0},Row{507904,0,0,0},Row{507904,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lllrlrrr(code: U32) -> Glyph:
  face0lllrlrrr.choose(U32.is_eq(code,49))

def face0lllrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllrlrrl(code)
    case False{}: face0lllrlrrr(code)

def face0lllrlrr(+code: U32) -> Glyph:
  face0lllrlrr.choose(code,U32.is_lt(code,49))

def face0lllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllrlrl(code)
    case False{}: face0lllrlrr(code)

def face0lllrlr(+code: U32) -> Glyph:
  face0lllrlr.choose(code,U32.is_lt(code,48))

def face0lllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllrll(code)
    case False{}: face0lllrlr(code)

def face0lllrl(+code: U32) -> Glyph:
  face0lllrl.choose(code,U32.is_lt(code,47))

def face0lllrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{46061312,0,0,0},Row{228810352,0,0,0},Row{1308624832,0,0,0}},Rows8{Row{1577058608,0,0,0},Row{525336576,0,0,0},Row{132251648,0,0,0},Row{12390400,0,0,0},Row{1945600,0,0,0},Row{190720,0,0,0},Row{304242544,0,0,0},Row{2415919072,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lllrrll(code: U32) -> Glyph:
  face0lllrrll.choose(U32.is_eq(code,50))

def face0lllrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{63952640,0,0,0},Row{512974448,0,0,0},Row{1845495488,0,0,0}},Rows8{Row{1845493760,0,0,0},Row{511770624,0,0,0},Row{82812928,0,0,0},Row{1316167680,0,0,0},Row{3103784960,0,0,0},Row{3103785905,0,0,0},Row{1600277680,0,0,0},Row{114288912,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lllrrlrl(code: U32) -> Glyph:
  face0lllrrlrl.choose(U32.is_eq(code,51))

def face0lllrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{232849408,0,0,0},Row{234356736,0,0,0},Row{228466688,0,0,0}},Rows8{Row{225091584,0,0,0},Row{224588544,0,0,0},Row{224430848,0,0,0},Row{224403008,0,0,0},Row{224397248,0,0,0},Row{4294967283,4,0,0},Row{1032008496,1,0,0},Row{224395264,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lllrrlrr(code: U32) -> Glyph:
  face0lllrrlrr.choose(U32.is_eq(code,52))

def face0lllrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllrrlrl(code)
    case False{}: face0lllrrlrr(code)

def face0lllrrlr(+code: U32) -> Glyph:
  face0lllrrlr.choose(code,U32.is_lt(code,52))

def face0lllrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllrrll(code)
    case False{}: face0lllrrlr(code)

def face0lllrrl(+code: U32) -> Glyph:
  face0lllrrl.choose(code,U32.is_lt(code,51))

def face0lllrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{268435296,0,0,0},Row{35793792,0,0,0},Row{2464,0,0,0}},Rows8{Row{1968,0,0,0},Row{45013968,0,0,0},Row{230967696,0,0,0},Row{1594884096,0,0,0},Row{2080374784,0,0,0},Row{1578107825,0,0,0},Row{229854384,0,0,0},Row{45017360,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lllrrrll(code: U32) -> Glyph:
  face0lllrrrll.choose(U32.is_eq(code,53))

def face0lllrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{98550528,0,0,0},Row{1331854880,0,0,0},Row{2566916752,0,0,0}},Rows8{Row{1248,0,0,0},Row{97432817,0,0,0},Row{1334017522,0,0,0},Row{2852129010,0,0,0},Row{3338667249,0,0,0},Row{2852128704,0,0,0},Row{1333948240,0,0,0},Row{97502464,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lllrrrlr(code: U32) -> Glyph:
  face0lllrrrlr.choose(U32.is_eq(code,54))

def face0lllrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllrrrll(code)
    case False{}: face0lllrrrlr(code)

def face0lllrrrl(+code: U32) -> Glyph:
  face0lllrrrl.choose(code,U32.is_lt(code,54))

def face0lllrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1342177269,0,0,0},Row{794960417,0,0,0},Row{179306496,0,0,0}},Rows8{Row{66256896,0,0,0},Row{12189696,0,0,0},Row{5185536,0,0,0},Row{823296,0,0,0},Row{385280,0,0,0},Row{55040,0,0,0},Row{28160,0,0,0},Row{7776,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lllrrrrl(code: U32) -> Glyph:
  face0lllrrrrl.choose(U32.is_eq(code,55))

def face0lllrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{63952384,0,0,0},Row{512974432,0,0,0},Row{1845496240,0,0,0}},Rows8{Row{1560283312,0,0,0},Row{510672464,0,0,0},Row{100661760,0,0,0},Row{1065573760,0,0,0},Row{3103786225,0,0,0},Row{3355444210,0,0,0},Row{1851935920,0,0,0},Row{115337488,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lllrrrrr(code: U32) -> Glyph:
  face0lllrrrrr.choose(U32.is_eq(code,56))

def face0lllrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllrrrrl(code)
    case False{}: face0lllrrrrr(code)

def face0lllrrrr(+code: U32) -> Glyph:
  face0lllrrrr.choose(code,U32.is_lt(code,56))

def face0lllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllrrrl(code)
    case False{}: face0lllrrrr(code)

def face0lllrrr(+code: U32) -> Glyph:
  face0lllrrr.choose(code,U32.is_lt(code,55))

def face0lllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllrrl(code)
    case False{}: face0lllrrr(code)

def face0lllrr(+code: U32) -> Glyph:
  face0lllrr.choose(code,U32.is_lt(code,53))

def face0lllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lllrl(code)
    case False{}: face0lllrr(code)

def face0lllr(+code: U32) -> Glyph:
  face0lllr.choose(code,U32.is_lt(code,50))

def face0lll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llll(code)
    case False{}: face0lllr(code)

def face0lll(+code: U32) -> Glyph:
  face0lll.choose(code,U32.is_lt(code,44))

def face0llrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{46061312,0,0,0},Row{514023040,0,0,0},Row{2080376288,0,0,0}},Rows8{Row{3103785714,0,0,0},Row{3405776113,0,0,0},Row{3464506784,0,0,0},Row{3082811920,0,0,0},Row{2566983680,0,0,0},Row{1308624064,0,0,0},Row{212028816,0,0,0},Row{28240128,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrllll(code: U32) -> Glyph:
  face0llrllll.choose(U32.is_eq(code,57))

def face0llrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[zero_rows(),Rows8{Row{2448,0,0,0},Row{2992,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),Row{2448,0,0,0},Row{2992,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrlllrl(code: U32) -> Glyph:
  face0llrlllrl.choose(U32.is_eq(code,58))

def face0llrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[zero_rows(),Rows8{Row{2912,0,0,0},Row{7552,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),Row{2960,0,0,0},Row{1968,0,0,0}},Rows8{Row{992,0,0,0},Row{225,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0llrlllrr(code: U32) -> Glyph:
  face0llrlllrr.choose(U32.is_eq(code,59))

def face0llrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrlllrl(code)
    case False{}: face0llrlllrr(code)

def face0llrlllr(+code: U32) -> Glyph:
  face0llrlllr.choose(code,U32.is_lt(code,59))

def face0llrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrllll(code)
    case False{}: face0llrlllr(code)

def face0llrlll(+code: U32) -> Glyph:
  face0llrlll.choose(code,U32.is_lt(code,58))

def face0llrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{1375731712,0,0,0},Row{2408710144,0,0,0},Row{61837824,0,0,0},Row{241280,0,0,0},Row{171648,0,0,0},Row{61837824,0,0,0},Row{2140274688,0,0,0},Row{1375731712,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrllrl(code: U32) -> Glyph:
  face0llrllrl.choose(U32.is_eq(code,60))

def face0llrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{zero_row(),zero_row(),Row{2952789872,0,0,0},Row{572662288,0,0,0},zero_row(),Row{2952789872,0,0,0},Row{572662288,0,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrllrrl(code: U32) -> Glyph:
  face0llrllrrl.choose(U32.is_eq(code,61))

def face0llrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{816,0,0,0},Row{245568,0,0,0},Row{62820864,0,0,0},Row{3196125184,0,0,0},Row{3195076608,1,0,0},Row{79593728,0,0,0},Row{310848,0,0,0},Row{1072,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrllrrr(code: U32) -> Glyph:
  face0llrllrrr.choose(U32.is_eq(code,62))

def face0llrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrllrrl(code)
    case False{}: face0llrllrrr(code)

def face0llrllrr(+code: U32) -> Glyph:
  face0llrllrr.choose(code,U32.is_lt(code,62))

def face0llrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrllrl(code)
    case False{}: face0llrllrr(code)

def face0llrllr(+code: U32) -> Glyph:
  face0llrllr.choose(code,U32.is_lt(code,61))

def face0llrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrlll(code)
    case False{}: face0llrllr(code)

def face0llrll(+code: U32) -> Glyph:
  face0llrll.choose(code,U32.is_lt(code,60))

def face0llrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{6159424,0,0,0},Row{49756386,0,0,0},Row{114294981,0,0,0}},Rows8{Row{115343360,0,0,0},Row{32182272,0,0,0},Row{4046848,0,0,0},Row{193536,0,0,0},Row{37888,0,0,0},zero_row(),Row{116224,0,0,0},Row{124672,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrlrll(code: U32) -> Glyph:
  face0llrlrll.choose(U32.is_eq(code,63))

def face0llrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4006092800,124,0,0},Row{861660160,7366,0,0}},Rows8{Row{32288,47360,0,0},Row{3198225040,315515,0,0},Row{1672152288,557183,0,0},Row{2040305,680058,0,0},Row{864498,684153,0,0},Row{2036210,557179,0,0},Row{1654391776,316350,0,0},Row{3200387488,40643,0,0}},Rows8{Row{28464,0,0,0},Row{593159424,116,0,0},Row{4275642368,157,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0llrlrlrl(code: U32) -> Glyph:
  face0llrlrlrl.choose(U32.is_eq(code,64))

def face0llrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{12525568,0,0,0},Row{33386496,0,0,0},Row{114802688,0,0,0}},Rows8{Row{194245120,0,0,0},Row{524343040,0,0,0},Row{1845533696,0,0,0},Row{3389017888,0,0,0},Row{4294967152,2,0,0},Row{3811785408,7,0,0},Row{2415920370,12,0,0},Row{1073742055,47,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrlrlrr(code: U32) -> Glyph:
  face0llrlrlrr.choose(U32.is_eq(code,65))

def face0llrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrlrlrl(code)
    case False{}: face0llrlrlrr(code)

def face0llrlrlr(+code: U32) -> Glyph:
  face0llrlrlr.choose(code,U32.is_lt(code,65))

def face0llrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrlrll(code)
    case False{}: face0llrlrlr(code)

def face0llrlrl(+code: U32) -> Glyph:
  face0llrlrl.choose(code,U32.is_lt(code,64))

def face0llrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{435158976,0,0,0},Row{2638358976,0,0,0},Row{3841984704,0,0,0}},Rows8{Row{3573549248,0,0,0},Row{2367686848,0,0,0},Row{469761984,0,0,0},Row{3426888128,0,0,0},Row{4043311296,4,0,0},Row{3758098624,5,0,0},Row{3912378816,1,0,0},Row{1005584320,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrlrrll(code: U32) -> Glyph:
  face0llrlrrll.choose(U32.is_eq(code,66))

def face0llrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1828552960,0,0,0},Row{3861171216,8,0,0},Row{805313920,47,0,0}},Rows8{Row{1744,54,0,0},Row{1009,0,0,0},Row{754,0,0,0},Row{1009,0,0,0},Row{1744,54,0,0},Row{805313920,63,0,0},Row{3861171216,9,0,0},Row{1845330176,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrlrrlr(code: U32) -> Glyph:
  face0llrlrrlr.choose(U32.is_eq(code,67))

def face0llrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrlrrll(code)
    case False{}: face0llrlrrlr(code)

def face0llrlrrl(+code: U32) -> Glyph:
  face0llrlrrl.choose(code,U32.is_lt(code,67))

def face0llrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{434110400,0,0,0},Row{3678546368,1,0,0},Row{3221227712,10,0,0}},Rows8{Row{1342179520,30,0,0},Row{536873152,63,0,0},Row{2240,79,0,0},Row{536873152,63,0,0},Row{1342179520,30,0,0},Row{3221227712,9,0,0},Row{3678546368,1,0,0},Row{434110400,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrlrrrl(code: U32) -> Glyph:
  face0llrlrrrl.choose(U32.is_eq(code,68))

def face0llrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2147483584,0,0,0},Row{304228800,0,0,0},Row{2240,0,0,0}},Rows8{Row{2240,0,0,0},Row{2240,0,0,0},Row{805306304,0,0,0},Row{35793344,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{304228800,0,0,0},Row{2415919040,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrlrrrr(code: U32) -> Glyph:
  face0llrlrrrr.choose(U32.is_eq(code,69))

def face0llrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrlrrrl(code)
    case False{}: face0llrlrrrr(code)

def face0llrlrrr(+code: U32) -> Glyph:
  face0llrlrrr.choose(code,U32.is_lt(code,69))

def face0llrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrlrrl(code)
    case False{}: face0llrlrrr(code)

def face0llrlrr(+code: U32) -> Glyph:
  face0llrlrr.choose(code,U32.is_lt(code,68))

def face0llrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrlrl(code)
    case False{}: face0llrlrr(code)

def face0llrlr(+code: U32) -> Glyph:
  face0llrlr.choose(code,U32.is_lt(code,66))

def face0llrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrll(code)
    case False{}: face0llrlr(code)

def face0llrl(+code: U32) -> Glyph:
  face0llrl.choose(code,U32.is_lt(code,63))

def face0llrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1879048128,0,0,0},Row{304228800,0,0,0},Row{2240,0,0,0}},Rows8{Row{2240,0,0,0},Row{2240,0,0,0},Row{234880960,0,0,0},Row{35793344,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrrlll(code: U32) -> Glyph:
  face0llrrlll.choose(U32.is_eq(code,70))

def face0llrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1560117504,0,0,0},Row{4147432464,7,0,0},Row{1610620288,47,0,0}},Rows8{Row{1744,75,0,0},Row{1009,0,0,0},Row{754,0,0,0},Row{4283433969,143,0,0},Row{571475664,140,0,0},Row{536878464,95,0,0},Row{3575958544,11,0,0},Row{2113765632,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrrllrl(code: U32) -> Glyph:
  face0llrrllrl.choose(U32.is_eq(code,71))

def face0llrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0}},Rows8{Row{536873152,63,0,0},Row{536873152,63,0,0},Row{4294967232,63,0,0},Row{1109535168,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrrllrr(code: U32) -> Glyph:
  face0llrrllrr.choose(U32.is_eq(code,72))

def face0llrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrrllrl(code)
    case False{}: face0llrrllrr(code)

def face0llrrllr(+code: U32) -> Glyph:
  face0llrrllr.choose(code,U32.is_lt(code,72))

def face0llrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrrlll(code)
    case False{}: face0llrrllr(code)

def face0llrrll(+code: U32) -> Glyph:
  face0llrrll.choose(code,U32.is_lt(code,71))

def face0llrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0}},Rows8{Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrrlrl(code: U32) -> Glyph:
  face0llrrlrl.choose(U32.is_eq(code,73))

def face0llrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{209715200,0,0,0},Row{209715200,0,0,0},Row{209715200,0,0,0}},Rows8{Row{209715200,0,0,0},Row{209715200,0,0,0},Row{209715200,0,0,0},Row{209715200,0,0,0},Row{192938163,0,0,0},Row{178258419,0,0,0},Row{99957456,0,0,0},Row{7203616,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrrlrrl(code: U32) -> Glyph:
  face0llrrlrrl.choose(U32.is_eq(code,74))

def face0llrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3808430272,9,0,0},Row{3171944640,0,0,0},Row{482347200,0,0,0}},Rows8{Row{48892096,0,0,0},Row{4159680,0,0,0},Row{6290368,0,0,0},Row{32010176,0,0,0},Row{181406144,0,0,0},Row{1596983488,0,0,0},Row{3892316352,1,0,0},Row{3221227712,10,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrrlrrr(code: U32) -> Glyph:
  face0llrrlrrr.choose(U32.is_eq(code,75))

def face0llrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrrlrrl(code)
    case False{}: face0llrrlrrr(code)

def face0llrrlrr(+code: U32) -> Glyph:
  face0llrrlrr.choose(code,U32.is_lt(code,75))

def face0llrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrrlrl(code)
    case False{}: face0llrrlrr(code)

def face0llrrlr(+code: U32) -> Glyph:
  face0llrrlr.choose(code,U32.is_lt(code,74))

def face0llrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrrll(code)
    case False{}: face0llrrlr(code)

def face0llrrl(+code: U32) -> Glyph:
  face0llrrl.choose(code,U32.is_lt(code,73))

def face0llrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0}},Rows8{Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{322124224,0,0,0},Row{1342177216,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrrrll(code: U32) -> Glyph:
  face0llrrrll.choose(U32.is_eq(code,76))

def face0llrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{20416,28560,0,0},Row{40896,28640,0,0},Row{60352,28133,0,0}},Rows8{Row{387008,28058,0,0},Row{269133760,27983,0,0},Row{1612662720,27917,0,0},Row{2960000960,27912,0,0},Row{4055369664,27907,0,0},Row{3354593216,27904,0,0},Row{2126514112,27904,0,0},Row{527435712,27904,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrrrlrl(code: U32) -> Glyph:
  face0llrrrlrl.choose(U32.is_eq(code,77))

def face0llrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{11968,95,0,0},Row{44992,95,0,0},Row{260800,95,0,0}},Rows8{Row{829376,95,0,0},Row{7284928,95,0,0},Row{31983808,95,0,0},Row{164694208,95,0,0},Row{793774272,95,0,0},Row{2868906176,94,0,0},Row{4060088512,95,0,0},Row{2147485888,95,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrrrlrr(code: U32) -> Glyph:
  face0llrrrlrr.choose(U32.is_eq(code,78))

def face0llrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrrrlrl(code)
    case False{}: face0llrrrlrr(code)

def face0llrrrlr(+code: U32) -> Glyph:
  face0llrrrlr.choose(code,U32.is_lt(code,78))

def face0llrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrrrll(code)
    case False{}: face0llrrrlr(code)

def face0llrrrl(+code: U32) -> Glyph:
  face0llrrrl.choose(code,U32.is_lt(code,77))

def face0llrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1827504384,0,0,0},Row{3861171200,8,0,0},Row{805313920,63,0,0}},Rows8{Row{1744,155,0,0},Row{1009,199,0,0},Row{754,214,0,0},Row{1009,199,0,0},Row{1744,155,0,0},Row{805313920,63,0,0},Row{3861171216,8,0,0},Row{1828552960,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrrrrll(code: U32) -> Glyph:
  face0llrrrrll.choose(U32.is_eq(code,79))

def face0llrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{149946304,0,0,0},Row{2638358976,0,0,0},Row{4110420160,1,0,0}},Rows8{Row{4060088512,2,0,0},Row{4093642944,1,0,0},Row{3156216000,0,0,0},Row{469761984,0,0,0},Row{1190336,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrrrrlr(code: U32) -> Glyph:
  face0llrrrrlr.choose(U32.is_eq(code,80))

def face0llrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrrrrll(code)
    case False{}: face0llrrrrlr(code)

def face0llrrrrl(+code: U32) -> Glyph:
  face0llrrrrl.choose(code,U32.is_lt(code,80))

def face0llrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1827504384,0,0,0},Row{3880180736,8,0,0},Row{1073749376,63,0,0}},Rows8{Row{1744,155,0,0},Row{1009,199,0,0},Row{754,214,0,0},Row{1009,199,0,0},Row{56624848,155,0,0},Row{1583357312,79,0,0},Row{4249279504,9,0,0},Row{3992813824,6,0,0}},Rows8{Row{1073741824,46,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0llrrrrrl(code: U32) -> Glyph:
  face0llrrrrrl.choose(U32.is_eq(code,81))

def face0llrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{435158976,0,0,0},Row{2906794432,0,0,0},Row{4110420160,1,0,0}},Rows8{Row{4060088512,2,0,0},Row{4093642944,1,0,0},Row{3139438784,0,0,0},Row{754974656,0,0,0},Row{163719616,0,0,0},Row{1061161152,0,0,0},Row{3137341632,0,0,0},Row{4076865728,5,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0llrrrrrr(code: U32) -> Glyph:
  face0llrrrrrr.choose(U32.is_eq(code,82))

def face0llrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrrrrrl(code)
    case False{}: face0llrrrrrr(code)

def face0llrrrrr(+code: U32) -> Glyph:
  face0llrrrrr.choose(code,U32.is_lt(code,82))

def face0llrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrrrrl(code)
    case False{}: face0llrrrrr(code)

def face0llrrrr(+code: U32) -> Glyph:
  face0llrrrr.choose(code,U32.is_lt(code,81))

def face0llrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrrrl(code)
    case False{}: face0llrrrr(code)

def face0llrrr(+code: U32) -> Glyph:
  face0llrrr.choose(code,U32.is_lt(code,79))

def face0llrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrrl(code)
    case False{}: face0llrrr(code)

def face0llrr(+code: U32) -> Glyph:
  face0llrr.choose(code,U32.is_lt(code,76))

def face0llr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0llrl(code)
    case False{}: face0llrr(code)

def face0llr(+code: U32) -> Glyph:
  face0llr.choose(code,U32.is_lt(code,70))

def face0ll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lll(code)
    case False{}: face0llr(code)

def face0ll(+code: U32) -> Glyph:
  face0ll.choose(code,U32.is_lt(code,57))

def face0lrlllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{148887040,0,0,0},Row{2639421040,0,0,0},Row{3288336336,0,0,0}},Rows8{Row{2256,0,0,0},Row{1425248,0,0,0},Row{436192512,0,0,0},Row{3194028032,0,0,0},Row{4076863488,2,0,0},Row{4076864481,1,0,0},Row{2907921824,0,0,0},Row{417323024,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrlllll(code: U32) -> Glyph:
  face0lrlllll.choose(U32.is_eq(code,83))

def face0lrllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4294967285,6,0,0},Row{575619617,1,0,0},Row{4136960,0,0,0}},Rows8{Row{4136960,0,0,0},Row{4136960,0,0,0},Row{4136960,0,0,0},Row{4136960,0,0,0},Row{4136960,0,0,0},Row{4136960,0,0,0},Row{4136960,0,0,0},Row{4136960,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrllllrl(code: U32) -> Glyph:
  face0lrllllrl.choose(U32.is_eq(code,84))

def face0lrllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0}},Rows8{Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873392,47,0,0},Row{1879051648,14,0,0},Row{3877875216,6,0,0},Row{1559142912,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrllllrr(code: U32) -> Glyph:
  face0lrllllrr.choose(U32.is_eq(code,85))

def face0lrllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrllllrl(code)
    case False{}: face0lrllllrr(code)

def face0lrllllr(+code: U32) -> Glyph:
  face0lrllllr.choose(code,U32.is_lt(code,85))

def face0lrllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlllll(code)
    case False{}: face0lrllllr(code)

def face0lrllll(+code: U32) -> Glyph:
  face0lrllll.choose(code,U32.is_lt(code,84))

def face0lrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1073742039,47,0,0},Row{2147484658,12,0,0},Row{3489663168,7,0,0}},Rows8{Row{4076866928,2,0,0},Row{3355459360,0,0,0},Row{2097187840,0,0,0},Row{790681088,0,0,0},Row{208859392,0,0,0},Row{130527232,0,0,0},Row{50094080,0,0,0},Row{12521472,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrlllrl(code: U32) -> Glyph:
  face0lrlllrl.choose(U32.is_eq(code,86))

def face0lrlllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3187671240,6230016,0,0},Row{4281336308,2048000,0,0},Row{3949987057,815108,0,0}},Rows8{Row{3097495728,569351,0,0},Row{2229275520,319499,0,0},Row{1106448192,127758,0,0},Row{12992256,51007,0,0},Row{9075456,35435,0,0},Row{5089280,19879,0,0},Row{2089984,8164,0,0},Row{847872,3296,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrlllrrl(code: U32) -> Glyph:
  face0lrlllrrl.choose(U32.is_eq(code,87))

def face0lrlllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3221227234,10,0,0},Row{3875548784,1,0,0},Row{1847634944,0,0,0}},Rows8{Row{195359488,0,0,0},Row{49119232,0,0,0},Row{12525568,0,0,0},Row{83664896,0,0,0},Row{496170240,0,0,0},Row{2383449616,0,0,0},Row{4110421136,3,0,0},Row{2684355572,12,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrlllrrr(code: U32) -> Glyph:
  face0lrlllrrr.choose(U32.is_eq(code,88))

def face0lrlllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlllrrl(code)
    case False{}: face0lrlllrrr(code)

def face0lrlllrr(+code: U32) -> Glyph:
  face0lrlllrr.choose(code,U32.is_lt(code,88))

def face0lrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlllrl(code)
    case False{}: face0lrlllrr(code)

def face0lrlllr(+code: U32) -> Glyph:
  face0lrlllr.choose(code,U32.is_lt(code,87))

def face0lrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrllll(code)
    case False{}: face0lrlllr(code)

def face0lrlll(+code: U32) -> Glyph:
  face0lrlll.choose(code,U32.is_lt(code,86))

def face0lrllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2415919861,13,0,0},Row{4076866240,4,0,0},Row{3137359664,0,0,0}},Rows8{Row{792775168,0,0,0},Row{163963392,0,0,0},Row{32403456,0,0,0},Row{8261632,0,0,0},Row{7143424,0,0,0},Row{7143424,0,0,0},Row{7143424,0,0,0},Row{7143424,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrllrll(code: U32) -> Glyph:
  face0lrllrll.choose(U32.is_eq(code,89))

def face0lrllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4026531827,0,0,0},Row{2636259872,0,0,0},Row{510656512,0,0,0}},Rows8{Row{98697216,0,0,0},Row{12255232,0,0,0},Row{3100672,0,0,0},Row{577792,0,0,0},Row{55296,0,0,0},Row{20256,0,0,0},Row{572664752,0,0,0},Row{4294967282,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrllrlrl(code: U32) -> Glyph:
  face0lrllrlrl.choose(U32.is_eq(code,90))

def face0lrllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{327536,0,0,0},Row{76656,0,0,0},Row{2928,0,0,0}},Rows8{Row{2928,0,0,0},Row{2928,0,0,0},Row{2928,0,0,0},Row{2928,0,0,0},Row{2928,0,0,0},Row{2928,0,0,0},Row{2928,0,0,0},Row{2928,0,0,0}},Rows8{Row{2928,0,0,0},Row{327536,0,0,0},Row{74256,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lrllrlrr(code: U32) -> Glyph:
  face0lrllrlrr.choose(U32.is_eq(code,91))

def face0lrllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrllrlrl(code)
    case False{}: face0lrllrlrr(code)

def face0lrllrlr(+code: U32) -> Glyph:
  face0lrllrlr.choose(code,U32.is_lt(code,91))

def face0lrllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrllrll(code)
    case False{}: face0lrllrlr(code)

def face0lrllrl(+code: U32) -> Glyph:
  face0lrllrl.choose(code,U32.is_lt(code,90))

def face0lrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{69,0,0,0},Row{182,0,0,0},Row{226,0,0,0}},Rows8{Row{1248,0,0,0},Row{2208,0,0,0},Row{2912,0,0,0},Row{7968,0,0,0},Row{19712,0,0,0},Row{35072,0,0,0},Row{50432,0,0,0},Row{127232,0,0,0}},Rows8{Row{376832,0,0,0},Row{622592,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lrllrrl(code: U32) -> Glyph:
  face0lrllrrl.choose(U32.is_eq(code,92))

def face0lrllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{36850,0,0,0},Row{35360,0,0,0},Row{35072,0,0,0}},Rows8{Row{35072,0,0,0},Row{35072,0,0,0},Row{35072,0,0,0},Row{35072,0,0,0},Row{35072,0,0,0},Row{35072,0,0,0},Row{35072,0,0,0},Row{35072,0,0,0}},Rows8{Row{35072,0,0,0},Row{36850,0,0,0},Row{4640,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lrllrrrl(code: U32) -> Glyph:
  face0lrllrrrl.choose(U32.is_eq(code,93))

def face0lrllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{95232,0,0,0},Row{519168,0,0,0},Row{875840,0,0,0}},Rows8{Row{6096816,0,0,0},Row{12976611,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrllrrrr(code: U32) -> Glyph:
  face0lrllrrrr.choose(U32.is_eq(code,94))

def face0lrllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrllrrrl(code)
    case False{}: face0lrllrrrr(code)

def face0lrllrrr(+code: U32) -> Glyph:
  face0lrllrrr.choose(code,U32.is_lt(code,94))

def face0lrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrllrrl(code)
    case False{}: face0lrllrrr(code)

def face0lrllrr(+code: U32) -> Glyph:
  face0lrllrr.choose(code,U32.is_lt(code,93))

def face0lrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrllrl(code)
    case False{}: face0lrllrr(code)

def face0lrllr(+code: U32) -> Glyph:
  face0lrllr.choose(code,U32.is_lt(code,92))

def face0lrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlll(code)
    case False{}: face0lrllr(code)

def face0lrll(+code: U32) -> Glyph:
  face0lrll.choose(code,U32.is_lt(code,89))

def face0lrlrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),zero_rows(),Rows8{Row{117440511,0,0,0},Row{19014178,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lrlrlll(code: U32) -> Glyph:
  face0lrlrlll.choose(U32.is_eq(code,95))

def face0lrlrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{272,0,0,0},Row{2704,0,0,0},Row{11536,0,0,0},zero_row()},zero_rows(),zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrlrllrl(code: U32) -> Glyph:
  face0lrlrllrl.choose(U32.is_eq(code,96))

def face0lrlrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{27191840,0,0,0},Row{148126416,0,0,0},Row{192938016,0,0,0},Row{216765968,0,0,0},Row{210009042,0,0,0},Row{210764005,0,0,0},Row{216409843,0,0,0},Row{209383008,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrlrllrr(code: U32) -> Glyph:
  face0lrlrllrr.choose(U32.is_eq(code,97))

def face0lrlrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlrllrl(code)
    case False{}: face0lrlrllrr(code)

def face0lrlrllr(+code: U32) -> Glyph:
  face0lrlrllr.choose(code,U32.is_lt(code,97))

def face0lrlrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlrlll(code)
    case False{}: face0lrlrllr(code)

def face0lrlrll(+code: U32) -> Glyph:
  face0lrlrll.choose(code,U32.is_lt(code,96))

def face0lrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0}},Rows8{Row{98547424,0,0,0},Row{1064529376,0,0,0},Row{2852129248,0,0,0},Row{3338667488,0,0,0},Row{3338667488,0,0,0},Row{2868906464,0,0,0},Row{1064529376,0,0,0},Row{98547168,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrlrlrl(code: U32) -> Glyph:
  face0lrlrlrl.choose(U32.is_eq(code,98))

def face0lrlrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{46065664,0,0,0},Row{496192912,0,0,0},Row{369100273,0,0,0},Row{499,0,0,0},Row{500,0,0,0},Row{369100017,0,0,0},Row{512970128,0,0,0},Row{46065664,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrlrlrrl(code: U32) -> Glyph:
  face0lrlrlrrl.choose(U32.is_eq(code,99))

def face0lrlrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2332033024,0,0,0},Row{2332033024,0,0,0},Row{2332033024,0,0,0}},Rows8{Row{2339301648,0,0,0},Row{2393066912,0,0,0},Row{2383414513,0,0,0},Row{2348810740,0,0,0},Row{2348810740,0,0,0},Row{2383414513,0,0,0},Row{2394115488,0,0,0},Row{2339301648,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrlrlrrr(code: U32) -> Glyph:
  face0lrlrlrrr.choose(U32.is_eq(code,100))

def face0lrlrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlrlrrl(code)
    case False{}: face0lrlrlrrr(code)

def face0lrlrlrr(+code: U32) -> Glyph:
  face0lrlrlrr.choose(code,U32.is_lt(code,100))

def face0lrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlrlrl(code)
    case False{}: face0lrlrlrr(code)

def face0lrlrlr(+code: U32) -> Glyph:
  face0lrlrlr.choose(code,U32.is_lt(code,99))

def face0lrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlrll(code)
    case False{}: face0lrlrlr(code)

def face0lrlrl(+code: U32) -> Glyph:
  face0lrlrl.choose(code,U32.is_lt(code,98))

def face0lrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{45017088,0,0,0},Row{496192656,0,0,0},Row{1577059057,0,0,0},Row{2147483636,0,0,0},Row{304227316,0,0,0},Row{67110129,0,0,0},Row{797072784,0,0,0},Row{80664576,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrlrrll(code: U32) -> Glyph:
  face0lrlrrll.choose(U32.is_eq(code,101))

def face0lrlrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{845824,0,0,0},Row{151360,0,0,0},Row{3408,0,0,0}},Rows8{Row{720893,0,0,0},Row{77170,0,0,0},Row{3408,0,0,0},Row{3408,0,0,0},Row{3408,0,0,0},Row{3408,0,0,0},Row{3408,0,0,0},Row{3408,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrlrrlrl(code: U32) -> Glyph:
  face0lrlrrlrl.choose(U32.is_eq(code,102))

def face0lrlrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{2322524416,0,0,0},Row{2376289680,0,0,0},Row{2383414513,0,0,0},Row{2348810739,0,0,0},Row{2332033268,0,0,0},Row{2383414513,0,0,0},Row{2393066912,0,0,0},Row{2340350224,0,0,0}},Rows8{Row{2080374784,0,0,0},Row{1064516256,0,0,0},Row{80734752,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lrlrrlrr(code: U32) -> Glyph:
  face0lrlrrlrr.choose(U32.is_eq(code,103))

def face0lrlrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlrrlrl(code)
    case False{}: face0lrlrrlrr(code)

def face0lrlrrlr(+code: U32) -> Glyph:
  face0lrlrrlr.choose(code,U32.is_lt(code,103))

def face0lrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlrrll(code)
    case False{}: face0lrlrrlr(code)

def face0lrlrrl(+code: U32) -> Glyph:
  face0lrlrrl.choose(code,U32.is_lt(code,102))

def face0lrlrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0}},Rows8{Row{63878880,0,0,0},Row{228810208,0,0,0},Row{790628320,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrlrrrll(code: U32) -> Glyph:
  face0lrlrrrll.choose(U32.is_eq(code,104))

def face0lrlrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{3,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1489,0,0,0},Row{16,0,0,0},zero_row()},Rows8{Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrlrrrlr(code: U32) -> Glyph:
  face0lrlrrrlr.choose(U32.is_eq(code,105))

def face0lrlrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlrrrll(code)
    case False{}: face0lrlrrrlr(code)

def face0lrlrrrl(+code: U32) -> Glyph:
  face0lrlrrrl.choose(code,U32.is_lt(code,105))

def face0lrlrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{23824,0,0,0},Row{256,0,0,0},zero_row()},Rows8{Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0}},Rows8{Row{19968,0,0,0},Row{12112,0,0,0},Row{2019,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lrlrrrrl(code: U32) -> Glyph:
  face0lrlrrrrl.choose(U32.is_eq(code,106))

def face0lrlrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0}},Rows8{Row{196085216,0,0,0},Row{30016992,0,0,0},Row{1938912,0,0,0},Row{326880,0,0,0},Row{834784,0,0,0},Row{10294752,0,0,0},Row{99878368,0,0,0},Row{779093472,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrlrrrrr(code: U32) -> Glyph:
  face0lrlrrrrr.choose(U32.is_eq(code,107))

def face0lrlrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlrrrrl(code)
    case False{}: face0lrlrrrrr(code)

def face0lrlrrrr(+code: U32) -> Glyph:
  face0lrlrrrr.choose(code,U32.is_lt(code,107))

def face0lrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlrrrl(code)
    case False{}: face0lrlrrrr(code)

def face0lrlrrr(+code: U32) -> Glyph:
  face0lrlrrr.choose(code,U32.is_lt(code,106))

def face0lrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlrrl(code)
    case False{}: face0lrlrrr(code)

def face0lrlrr(+code: U32) -> Glyph:
  face0lrlrr.choose(code,U32.is_lt(code,104))

def face0lrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrlrl(code)
    case False{}: face0lrlrr(code)

def face0lrlr(+code: U32) -> Glyph:
  face0lrlr.choose(code,U32.is_lt(code,101))

def face0lrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrll(code)
    case False{}: face0lrlr(code)

def face0lrl(+code: U32) -> Glyph:
  face0lrl.choose(code,U32.is_lt(code,95))

def face0lrrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{3,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0}},Rows8{Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrllll(code: U32) -> Glyph:
  face0lrrllll.choose(U32.is_eq(code,108))

def face0lrrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[zero_rows(),Rows8{Row{2711533280,1246,0,0},Row{2111065312,3731,0,0},Row{209716960,12048,0,0},Row{191890912,16144,0,0},Row{191890912,16144,0,0},Row{191890912,16144,0,0},Row{191890912,16144,0,0},Row{191890912,16144,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrlllrl(code: U32) -> Glyph:
  face0lrrlllrl.choose(U32.is_eq(code,109))

def face0lrrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{63878624,0,0,0},Row{228809952,0,0,0},Row{790628320,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrlllrr(code: U32) -> Glyph:
  face0lrrlllrr.choose(U32.is_eq(code,110))

def face0lrrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrlllrl(code)
    case False{}: face0lrrlllrr(code)

def face0lrrlllr(+code: U32) -> Glyph:
  face0lrrlllr.choose(code,U32.is_lt(code,110))

def face0lrrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrllll(code)
    case False{}: face0lrrlllr(code)

def face0lrrlll(+code: U32) -> Glyph:
  face0lrrlll.choose(code,U32.is_lt(code,109))

def face0lrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{46065664,0,0,0},Row{512970128,0,0,0},Row{2097153521,0,0,0},Row{2852127219,0,0,0},Row{2852127220,0,0,0},Row{2097153265,0,0,0},Row{512970128,0,0,0},Row{46065664,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrllrl(code: U32) -> Glyph:
  face0lrrllrl.choose(U32.is_eq(code,111))

def face0lrrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{98547168,0,0,0},Row{1064529376,0,0,0},Row{2852129248,0,0,0},Row{3338667488,0,0,0},Row{3338667488,0,0,0},Row{2868906464,0,0,0},Row{1064529376,0,0,0},Row{98547424,0,0,0}},Rows8{Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lrrllrrl(code: U32) -> Glyph:
  face0lrrllrrl.choose(U32.is_eq(code,112))

def face0lrrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{2340350224,0,0,0},Row{2394115488,0,0,0},Row{2383414513,0,0,0},Row{2348810740,0,0,0},Row{2348810740,0,0,0},Row{2383414513,0,0,0},Row{2394115488,0,0,0},Row{2339301648,0,0,0}},Rows8{Row{2332033024,0,0,0},Row{2332033024,0,0,0},Row{2332033024,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lrrllrrr(code: U32) -> Glyph:
  face0lrrllrrr.choose(U32.is_eq(code,113))

def face0lrrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrllrrl(code)
    case False{}: face0lrrllrrr(code)

def face0lrrllrr(+code: U32) -> Glyph:
  face0lrrllrr.choose(code,U32.is_lt(code,113))

def face0lrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrllrl(code)
    case False{}: face0lrrllrr(code)

def face0lrrllr(+code: U32) -> Glyph:
  face0lrrllr.choose(code,U32.is_lt(code,112))

def face0lrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrlll(code)
    case False{}: face0lrrllr(code)

def face0lrrll(+code: U32) -> Glyph:
  face0lrrll.choose(code,U32.is_lt(code,111))

def face0lrrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[zero_rows(),Rows8{Row{968416,0,0,0},Row{155104,0,0,0},Row{1760,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrlrll(code: U32) -> Glyph:
  face0lrrlrll.choose(U32.is_eq(code,114))

def face0lrrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{Row{8321824,0,0,0},Row{98843344,0,0,0},Row{2098672,0,0,0},Row{1486720,0,0,0},Row{82539008,0,0,0},Row{178257968,0,0,0},Row{132393201,0,0,0},Row{9370688,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrlrlrl(code: U32) -> Glyph:
  face0lrrlrlrl.choose(U32.is_eq(code,115))

def face0lrrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2224,0,0,0},Row{2224,0,0,0}},Rows8{Row{131069,0,0,0},Row{10673,0,0,0},Row{2224,0,0,0},Row{2224,0,0,0},Row{2224,0,0,0},Row{2224,0,0,0},Row{11152,0,0,0},Row{261152,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrlrlrr(code: U32) -> Glyph:
  face0lrrlrlrr.choose(U32.is_eq(code,116))

def face0lrrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrlrlrl(code)
    case False{}: face0lrrlrlrr(code)

def face0lrrlrlr(+code: U32) -> Glyph:
  face0lrrlrlr.choose(code,U32.is_lt(code,116))

def face0lrrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrlrll(code)
    case False{}: face0lrrlrlr(code)

def face0lrrlrl(+code: U32) -> Glyph:
  face0lrrlrl.choose(code,U32.is_lt(code,115))

def face0lrrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1058014688,0,0,0},Row{1060112080,0,0,0},Row{1067666832,0,0,0},Row{1062071056,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrlrrll(code: U32) -> Glyph:
  face0lrrlrrll.choose(U32.is_eq(code,117))

def face0lrrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{1594884311,0,0,0},Row{240124913,0,0,0},Row{161483184,0,0,0},Row{66129488,0,0,0},Row{14044688,0,0,0},Row{8030464,0,0,0},Row{3068928,0,0,0},Row{774144,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrlrrlr(code: U32) -> Glyph:
  face0lrrlrrlr.choose(U32.is_eq(code,118))

def face0lrrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrlrrll(code)
    case False{}: face0lrrlrrlr(code)

def face0lrrlrrl(+code: U32) -> Glyph:
  face0lrrlrrl.choose(code,U32.is_lt(code,118))

def face0lrrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[zero_rows(),Rows8{Row{150012134,3440,0,0},Row{216335345,2224,0,0},Row{529008576,1248,0,0},Row{1280052096,228,0,0},Row{2282626608,168,0,0},Row{3020652032,107,0,0},Row{3758615040,30,0,0},Row{2952983808,12,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrlrrrl(code: U32) -> Glyph:
  face0lrrlrrrl.choose(U32.is_eq(code,119))

def face0lrrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{195036642,0,0,0},Row{49552752,0,0,0},Row{8162304,0,0,0},Row{848640,0,0,0},Row{848896,0,0,0},Row{9202960,0,0,0},Row{66260112,0,0,0},Row{226493428,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrlrrrr(code: U32) -> Glyph:
  face0lrrlrrrr.choose(U32.is_eq(code,120))

def face0lrrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrlrrrl(code)
    case False{}: face0lrrlrrrr(code)

def face0lrrlrrr(+code: U32) -> Glyph:
  face0lrrlrrr.choose(code,U32.is_lt(code,120))

def face0lrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrlrrl(code)
    case False{}: face0lrrlrrr(code)

def face0lrrlrr(+code: U32) -> Glyph:
  face0lrrlrr.choose(code,U32.is_lt(code,119))

def face0lrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrlrl(code)
    case False{}: face0lrrlrr(code)

def face0lrrlr(+code: U32) -> Glyph:
  face0lrrlr.choose(code,U32.is_lt(code,117))

def face0lrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrll(code)
    case False{}: face0lrrlr(code)

def face0lrrl(+code: U32) -> Glyph:
  face0lrrl.choose(code,U32.is_lt(code,114))

def face0lrrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{1594884311,0,0,0},Row{240124913,0,0,0},Row{162531760,0,0,0},Row{66129488,0,0,0},Row{14044688,0,0,0},Row{8096256,0,0,0},Row{3068928,0,0,0},Row{778240,0,0,0}},Rows8{Row{446464,0,0,0},Row{124704,0,0,0},Row{19936,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lrrrlll(code: U32) -> Glyph:
  face0lrrrlll.choose(U32.is_eq(code,121))

def face0lrrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{201326576,0,0,0},Row{99885600,0,0,0},Row{10223616,0,0,0},Row{1933312,0,0,0},Row{324608,0,0,0},Row{36368,0,0,0},Row{35794336,0,0,0},Row{234881010,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrrllrl(code: U32) -> Glyph:
  face0lrrrllrl.choose(U32.is_eq(code,122))

def face0lrrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3051520,0,0,0},Row{320768,0,0,0},Row{42752,0,0,0}},Rows8{Row{38912,0,0,0},Row{38912,0,0,0},Row{31744,0,0,0},Row{2800,0,0,0},Row{27952,0,0,0},Row{38912,0,0,0},Row{38912,0,0,0},Row{43008,0,0,0}},Rows8{Row{120320,0,0,0},Row{3125248,0,0,0},Row{65536,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lrrrllrr(code: U32) -> Glyph:
  face0lrrrllrr.choose(U32.is_eq(code,123))

def face0lrrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrrllrl(code)
    case False{}: face0lrrrllrr(code)

def face0lrrrllr(+code: U32) -> Glyph:
  face0lrrrllr.choose(code,U32.is_lt(code,123))

def face0lrrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrrlll(code)
    case False{}: face0lrrrllr(code)

def face0lrrrll(+code: U32) -> Glyph:
  face0lrrrll.choose(code,U32.is_lt(code,122))

def face0lrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),Row{1568,0,0,0},Row{3376,0,0,0},Row{3376,0,0,0},Row{3376,0,0,0},Row{3376,0,0,0},Row{3376,0,0,0},Row{3376,0,0,0}},Rows8{Row{3376,0,0,0},Row{3376,0,0,0},Row{3376,0,0,0},Row{3376,0,0,0},Row{3376,0,0,0},Row{3376,0,0,0},Row{3376,0,0,0},Row{3376,0,0,0}},Rows8{Row{3376,0,0,0},Row{3376,0,0,0},Row{3376,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lrrrlrl(code: U32) -> Glyph:
  face0lrrrlrl.choose(U32.is_eq(code,124))

def face0lrrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2274,0,0,0},Row{20032,0,0,0},Row{31232,0,0,0}},Rows8{Row{31232,0,0,0},Row{31232,0,0,0},Row{112640,0,0,0},Row{1028352,0,0,0},Row{316928,0,0,0},Row{35328,0,0,0},Row{31232,0,0,0},Row{31232,0,0,0}},Rows8{Row{23840,0,0,0},Row{3058,0,0,0},Row{16,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lrrrlrrl(code: U32) -> Glyph:
  face0lrrrlrrl.choose(U32.is_eq(code,125))

def face0lrrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{zero_row(),zero_row(),Row{2953108512,1,0,0},Row{3830340256,0,0,0},Row{2145649840,0,0,0},Row{17825792,0,0,0},zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrrlrrr(code: U32) -> Glyph:
  face0lrrrlrrr.choose(U32.is_eq(code,126))

def face0lrrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrrlrrl(code)
    case False{}: face0lrrrlrrr(code)

def face0lrrrlrr(+code: U32) -> Glyph:
  face0lrrrlrr.choose(code,U32.is_lt(code,126))

def face0lrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrrlrl(code)
    case False{}: face0lrrrlrr(code)

def face0lrrrlr(+code: U32) -> Glyph:
  face0lrrrlr.choose(code,U32.is_lt(code,125))

def face0lrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrrll(code)
    case False{}: face0lrrrlr(code)

def face0lrrrl(+code: U32) -> Glyph:
  face0lrrrl.choose(code,U32.is_lt(code,124))

def face0lrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[zero_rows(),zero_rows(),zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrrrll(code: U32) -> Glyph:
  face0lrrrrll.choose(U32.is_eq(code,160))

def face0lrrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[zero_rows(),Rows8{Row{2992,0,0,0},Row{2704,0,0,0},zero_row(),zero_row(),Row{2448,0,0,0},Row{2704,0,0,0},Row{2704,0,0,0},Row{2720,0,0,0}},Rows8{Row{2720,0,0,0},Row{2720,0,0,0},Row{2976,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lrrrrlrl(code: U32) -> Glyph:
  face0lrrrrlrl.choose(U32.is_eq(code,161))

def face0lrrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{540672,0,0,0},Row{6071040,0,0,0},Row{183291712,0,0,0}},Rows8{Row{490228176,0,0,0},Row{541427,0,0,0},Row{540916,0,0,0},Row{541171,0,0,0},Row{723011552,0,0,0},Row{214675296,0,0,0},Row{26068224,0,0,0},Row{540672,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrrrlrr(code: U32) -> Glyph:
  face0lrrrrlrr.choose(U32.is_eq(code,162))

def face0lrrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrrrlrl(code)
    case False{}: face0lrrrrlrr(code)

def face0lrrrrlr(+code: U32) -> Glyph:
  face0lrrrrlr.choose(code,U32.is_lt(code,162))

def face0lrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrrrll(code)
    case False{}: face0lrrrrlr(code)

def face0lrrrrl(+code: U32) -> Glyph:
  face0lrrrrl.choose(code,U32.is_lt(code,161))

def face0lrrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{115257856,0,0,0},Row{1582611456,0,0,0},Row{2264932144,0,0,0}},Rows8{Row{3648,0,0,0},Row{3904,0,0,0},Row{83886068,0,0,0},Row{19021649,0,0,0},Row{7968,0,0,0},Row{553656096,0,0,0},Row{3090365313,0,0,0},Row{1593835508,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrrrrll(code: U32) -> Glyph:
  face0lrrrrrll.choose(U32.is_eq(code,163))

def face0lrrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1256035776,45,0,0}},Rows8{Row{4197756800,10,0,0},Row{2684357504,9,0,0},Row{805307600,14,0,0},Row{268436208,31,0,0},Row{805307600,15,0,0},Row{2415921808,10,0,0},Row{4180914064,11,0,0},Row{1257153696,27,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrrrrlr(code: U32) -> Glyph:
  face0lrrrrrlr.choose(U32.is_eq(code,164))

def face0lrrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrrrrll(code)
    case False{}: face0lrrrrrlr(code)

def face0lrrrrrl(+code: U32) -> Glyph:
  face0lrrrrrl.choose(code,U32.is_lt(code,164))

def face0lrrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1327497417,0,0,0},Row{226493427,0,0,0},Row{131074480,0,0,0}},Rows8{Row{32771664,0,0,0},Row{10116352,0,0,0},Row{4179712,0,0,0},Row{184549360,0,0,0},Row{36291104,0,0,0},Row{184549360,0,0,0},Row{36291104,0,0,0},Row{573440,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0lrrrrrrl(code: U32) -> Glyph:
  face0lrrrrrrl.choose(U32.is_eq(code,165))

def face0lrrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1952,0,0,0},Row{1952,0,0,0},Row{1952,0,0,0}},Rows8{Row{1952,0,0,0},Row{1952,0,0,0},zero_row(),zero_row(),zero_row(),Row{1952,0,0,0},Row{1952,0,0,0},Row{1952,0,0,0}},Rows8{Row{1952,0,0,0},Row{1952,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0lrrrrrrr(code: U32) -> Glyph:
  face0lrrrrrrr.choose(U32.is_eq(code,166))

def face0lrrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrrrrrl(code)
    case False{}: face0lrrrrrrr(code)

def face0lrrrrrr(+code: U32) -> Glyph:
  face0lrrrrrr.choose(code,U32.is_lt(code,166))

def face0lrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrrrrl(code)
    case False{}: face0lrrrrrr(code)

def face0lrrrrr(+code: U32) -> Glyph:
  face0lrrrrr.choose(code,U32.is_lt(code,165))

def face0lrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrrrl(code)
    case False{}: face0lrrrrr(code)

def face0lrrrr(+code: U32) -> Glyph:
  face0lrrrr.choose(code,U32.is_lt(code,163))

def face0lrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrrl(code)
    case False{}: face0lrrrr(code)

def face0lrrr(+code: U32) -> Glyph:
  face0lrrr.choose(code,U32.is_lt(code,160))

def face0lrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrrl(code)
    case False{}: face0lrrr(code)

def face0lrr(+code: U32) -> Glyph:
  face0lrr.choose(code,U32.is_lt(code,121))

def face0lr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0lrl(code)
    case False{}: face0lrr(code)

def face0lr(+code: U32) -> Glyph:
  face0lr.choose(code,U32.is_lt(code,108))

def face0l.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0ll(code)
    case False{}: face0lr(code)

def face0l(+code: U32) -> Glyph:
  face0l.choose(code,U32.is_lt(code,83))

def face0rllllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{9365504,0,0,0},Row{97734224,0,0,0},Row{54528880,0,0,0}},Rows8{Row{32288,0,0,0},Row{2948720,0,0,0},Row{100484081,0,0,0},Row{244318689,0,0,0},Row{521153392,0,0,0},Row{161010944,0,0,0},Row{31002624,0,0,0},Row{113246496,0,0,0}},Rows8{Row{114432672,0,0,0},Row{11533344,0,0,0},Row{73728,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0rllllll(code: U32) -> Glyph:
  face0rllllll.choose(U32.is_eq(code,167))

def face0rlllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{64052480,0,0,0},Row{1048832,0,0,0},zero_row()},zero_rows(),zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlllllrl(code: U32) -> Glyph:
  face0rlllllrl.choose(U32.is_eq(code,168))

def face0rlllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3470266368,23,0,0},Row{1397482240,460,0,0},Row{36112,2992,0,0}},Rows8{Row{3200454000,15906,0,0},Row{2475562928,35341,0,0},Row{812480,39190,0,0},Row{751536,35331,0,0},Row{1885285504,24094,0,0},Row{3756355088,3475,0,0},Row{841544960,1002,0,0},Row{4294651904,42,0,0}},Rows8{Row{303038464,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0rlllllrr(code: U32) -> Glyph:
  face0rlllllrr.choose(U32.is_eq(code,169))

def face0rlllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlllllrl(code)
    case False{}: face0rlllllrr(code)

def face0rlllllr(+code: U32) -> Glyph:
  face0rlllllr.choose(code,U32.is_lt(code,169))

def face0rlllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllllll(code)
    case False{}: face0rlllllr(code)

def face0rlllll(+code: U32) -> Glyph:
  face0rlllll.choose(code,U32.is_lt(code,168))

def face0rllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1764992,0,0,0},Row{7078562,0,0,0},Row{9344816,0,0,0}},Rows8{Row{9066469,0,0,0},Row{9244855,0,0,0},Row{9162417,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rllllrl(code: U32) -> Glyph:
  face0rllllrl.choose(U32.is_eq(code,170))

def face0rllllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{1312280832,0,0,0},Row{131181312,0,0,0},Row{11214208,0,0,0},Row{3102194,0,0,0},Row{11214208,0,0,0},Row{131181312,0,0,0},Row{1312280832,0,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rllllrrl(code: U32) -> Glyph:
  face0rllllrrl.choose(U32.is_eq(code,171))

def face0rllllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),Row{1342177136,0,0,0},Row{1310859792,0,0,0},Row{1308622848,0,0,0},Row{301989888,0,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rllllrrr(code: U32) -> Glyph:
  face0rllllrrr.choose(U32.is_eq(code,172))

def face0rllllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllllrrl(code)
    case False{}: face0rllllrrr(code)

def face0rllllrr(+code: U32) -> Glyph:
  face0rllllrr.choose(code,U32.is_lt(code,172))

def face0rllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllllrl(code)
    case False{}: face0rllllrr(code)

def face0rllllr(+code: U32) -> Glyph:
  face0rllllr.choose(code,U32.is_lt(code,171))

def face0rllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlllll(code)
    case False{}: face0rllllr(code)

def face0rllll(+code: U32) -> Glyph:
  face0rllll.choose(code,U32.is_lt(code,170))

def face0rlllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{251656960,0,0,0},Row{251263744,0,0,0},Row{251656960,0,0,0},Row{251239168,0,0,0}},Rows8{Row{251656960,0,0,0},Row{251263744,0,0,0},Row{245365504,0,0,0},Row{249420544,0,0,0},Row{245340928,0,0,0},Row{251656960,0,0,0},Row{244288256,0,0,0},Row{241404672,0,0,0}},Rows8{Row{251656960,0,0,0},Row{249096960,0,0,0},Row{251656960,0,0,0},Row{53686784,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0rlllrll(code: U32) -> Glyph:
  face0rlllrll.choose(U32.is_eq(code,173))

def face0rlllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{115258112,0,0,0},Row{2891148880,0,0,0},Row{3251614673,4,0,0}},Rows8{Row{1673769140,9,0,0},Row{1625272484,9,0,0},Row{2999169761,5,0,0},Row{3392167280,0,0,0},Row{452978176,0,0,0},Row{1179648,0,0,0},zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlllrlrl(code: U32) -> Glyph:
  face0rlllrlrl.choose(U32.is_eq(code,174))

def face0rlllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4194176,0,0,0},Row{1188368,0,0,0},zero_row()},zero_rows(),zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlllrlrr(code: U32) -> Glyph:
  face0rlllrlrr.choose(U32.is_eq(code,175))

def face0rlllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlllrlrl(code)
    case False{}: face0rlllrlrr(code)

def face0rlllrlr(+code: U32) -> Glyph:
  face0rlllrlr.choose(code,U32.is_lt(code,175))

def face0rlllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlllrll(code)
    case False{}: face0rlllrlr(code)

def face0rlllrl(+code: U32) -> Glyph:
  face0rlllrl.choose(code,U32.is_lt(code,174))

def face0rlllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{453664,0,0,0},Row{4016080,0,0,0},Row{7930081,0,0,0}},Rows8{Row{6034656,0,0,0},Row{654912,0,0,0},Row{8448,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlllrrl(code: U32) -> Glyph:
  face0rlllrrl.choose(U32.is_eq(code,176))

def face0rlllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{4063232,0,0,0},Row{4063232,0,0,0},Row{3758096272,0,0,0},Row{576594448,0,0,0},Row{4063232,0,0,0},zero_row(),Row{3758096272,0,0,0},Row{572662288,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlllrrrl(code: U32) -> Glyph:
  face0rlllrrrl.choose(U32.is_eq(code,177))

def face0rlllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{585344,0,0,0},Row{4072130,0,0,0},Row{1982464,0,0,0},Row{386304,0,0,0}},Rows8{Row{20064,0,0,0},Row{7270130,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlllrrrr(code: U32) -> Glyph:
  face0rlllrrrr.choose(U32.is_eq(code,178))

def face0rlllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlllrrrl(code)
    case False{}: face0rlllrrrr(code)

def face0rlllrrr(+code: U32) -> Glyph:
  face0rlllrrr.choose(code,U32.is_lt(code,178))

def face0rlllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlllrrl(code)
    case False{}: face0rlllrrr(code)

def face0rlllrr(+code: U32) -> Glyph:
  face0rlllrr.choose(code,U32.is_lt(code,177))

def face0rlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlllrl(code)
    case False{}: face0rlllrr(code)

def face0rlllr(+code: U32) -> Glyph:
  face0rlllr.choose(code,U32.is_lt(code,176))

def face0rlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllll(code)
    case False{}: face0rlllr(code)

def face0rlll(+code: U32) -> Glyph:
  face0rlll.choose(code,U32.is_lt(code,173))

def face0rllrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{1764736,0,0,0},Row{5116273,0,0,0},Row{718592,0,0,0},Row{8130560,0,0,0}},Rows8{Row{8131250,0,0,0},Row{1764720,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rllrlll(code: U32) -> Glyph:
  face0rllrlll.choose(U32.is_eq(code,179))

def face0rllrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{15904,0,0,0},Row{1936,0,0,0},zero_row()},zero_rows(),zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rllrllrl(code: U32) -> Glyph:
  face0rllrllrl.choose(U32.is_eq(code,180))

def face0rllrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1059063520,0,0,0},Row{1604402656,0,0,0},Row{3883849952,2,0,0}},Rows8{Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0rllrllrr(code: U32) -> Glyph:
  face0rllrllrr.choose(U32.is_eq(code,181))

def face0rllrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllrllrl(code)
    case False{}: face0rllrllrr(code)

def face0rllrllr(+code: U32) -> Glyph:
  face0rllrllr.choose(code,U32.is_lt(code,181))

def face0rllrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllrlll(code)
    case False{}: face0rllrllr(code)

def face0rllrll(+code: U32) -> Glyph:
  face0rllrll.choose(code,U32.is_lt(code,180))

def face0rllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1073735952,0,0,0},Row{1060896688,0,0,0},Row{1058799602,0,0,0}},Rows8{Row{1058799603,0,0,0},Row{1058799601,0,0,0},Row{1058799520,0,0,0},Row{1058654208,0,0,0},Row{1058013184,0,0,0},Row{1058013184,0,0,0},Row{1058013184,0,0,0},Row{1058013184,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rllrlrl(code: U32) -> Glyph:
  face0rllrlrl.choose(U32.is_eq(code,182))

def face0rllrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[zero_rows(),Rows8{zero_row(),zero_row(),Row{2448,0,0,0},Row{2992,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rllrlrrl(code: U32) -> Glyph:
  face0rllrlrrl.choose(U32.is_eq(code,183))

def face0rllrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[zero_rows(),zero_rows(),Rows8{Row{1408,0,0,0},Row{27168,0,0,0},Row{15536,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0rllrlrrr(code: U32) -> Glyph:
  face0rllrlrrr.choose(U32.is_eq(code,184))

def face0rllrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllrlrrl(code)
    case False{}: face0rllrlrrr(code)

def face0rllrlrr(+code: U32) -> Glyph:
  face0rllrlrr.choose(code,U32.is_lt(code,184))

def face0rllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllrlrl(code)
    case False{}: face0rllrlrr(code)

def face0rllrlr(+code: U32) -> Glyph:
  face0rllrlr.choose(code,U32.is_lt(code,183))

def face0rllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllrll(code)
    case False{}: face0rllrlr(code)

def face0rllrl(+code: U32) -> Glyph:
  face0rllrl.choose(code,U32.is_lt(code,182))

def face0rllrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{28561,0,0,0},Row{27781,0,0,0},Row{27648,0,0,0},Row{27648,0,0,0}},Rows8{Row{27648,0,0,0},Row{27648,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rllrrll(code: U32) -> Glyph:
  face0rllrrll.choose(U32.is_eq(code,185))

def face0rllrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2944336,0,0,0},Row{14091506,0,0,0},Row{49348806,0,0,0}},Rows8{Row{49348806,0,0,0},Row{14091506,0,0,0},Row{2944336,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rllrrlrl(code: U32) -> Glyph:
  face0rllrrlrl.choose(U32.is_eq(code,186))

def face0rllrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{4081122,0,0,0},Row{30948944,0,0,0},Row{179427328,0,0,0},Row{1329127424,0,0,0},Row{179427328,0,0,0},Row{30948944,0,0,0},Row{4081122,0,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rllrrlrr(code: U32) -> Glyph:
  face0rllrrlrr.choose(U32.is_eq(code,187))

def face0rllrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllrrlrl(code)
    case False{}: face0rllrrlrr(code)

def face0rllrrlr(+code: U32) -> Glyph:
  face0rllrrlr.choose(code,U32.is_lt(code,187))

def face0rllrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllrrll(code)
    case False{}: face0rllrrlr(code)

def face0rllrrl(+code: U32) -> Glyph:
  face0rllrrl.choose(code,U32.is_lt(code,186))

def face0rllrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{268439490,46,0,0},Row{2684358519,7,0,0},Row{3556773664,0,0,0}},Rows8{Row{1024462624,0,0,0},Row{160436000,0,0,0},Row{30609184,116,0,0},Row{274464768,237,0,0},Row{2685038592,231,0,0},Row{3288523264,225,0,0},Row{3909118720,2558,0,0},Row{3168,225,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rllrrrll(code: U32) -> Glyph:
  face0rllrrrll.choose(U32.is_eq(code,188))

def face0rllrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{268439490,46,0,0},Row{2684358519,7,0,0},Row{3556773664,0,0,0}},Rows8{Row{1024462624,0,0,0},Row{160436000,0,0,0},Row{567480096,2028,0,0},Row{1885077504,8009,0,0},Row{684032,3120,0,0},Row{188928,978,0,0},Row{536898304,621,0,0},Row{2147486816,16383,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rllrrrlr(code: U32) -> Glyph:
  face0rllrrrlr.choose(U32.is_eq(code,189))

def face0rllrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllrrrll(code)
    case False{}: face0rllrrrlr(code)

def face0rllrrrl(+code: U32) -> Glyph:
  face0rllrrrl.choose(code,U32.is_lt(code,189))

def face0rllrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{183936,1233,0,0},Row{504673,152,0,0},Row{805498368,29,0,0}},Rows8{Row{3221922304,5,0,0},Row{2802553730,0,0,0},Row{774102688,6192,0,0},Row{112197632,8145,0,0},Row{12976128,7816,0,0},Row{809373696,7709,0,0},Row{1879613440,49134,0,0},Row{54272,7936,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rllrrrrl(code: U32) -> Glyph:
  face0rllrrrrl.choose(U32.is_eq(code,190))

def face0rllrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{Row{638976,0,0,0},Row{569344,0,0,0},zero_row(),Row{356352,0,0,0},Row{512000,0,0,0},Row{125712,0,0,0},Row{11712,0,0,0},Row{755,0,0,0}},Rows8{Row{111149300,0,0,0},Row{83245537,0,0,0},Row{7207984,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0rllrrrrr(code: U32) -> Glyph:
  face0rllrrrrr.choose(U32.is_eq(code,191))

def face0rllrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllrrrrl(code)
    case False{}: face0rllrrrrr(code)

def face0rllrrrr(+code: U32) -> Glyph:
  face0rllrrrr.choose(code,U32.is_lt(code,191))

def face0rllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllrrrl(code)
    case False{}: face0rllrrrr(code)

def face0rllrrr(+code: U32) -> Glyph:
  face0rllrrr.choose(code,U32.is_lt(code,190))

def face0rllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllrrl(code)
    case False{}: face0rllrrr(code)

def face0rllrr(+code: U32) -> Glyph:
  face0rllrr.choose(code,U32.is_lt(code,188))

def face0rllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rllrl(code)
    case False{}: face0rllrr(code)

def face0rllr(+code: U32) -> Glyph:
  face0rllr.choose(code,U32.is_lt(code,185))

def face0rll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlll(code)
    case False{}: face0rllr(code)

def face0rll(+code: U32) -> Glyph:
  face0rll.choose(code,U32.is_lt(code,179))

def face0rlrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),Row{69632,0,0,0},Row{692224,0,0,0},Row{2953216,0,0,0},zero_row(),Row{12525568,0,0,0},Row{33386496,0,0,0},Row{114802688,0,0,0}},Rows8{Row{194245120,0,0,0},Row{524343040,0,0,0},Row{1845533696,0,0,0},Row{3389017888,0,0,0},Row{4294967152,2,0,0},Row{3811785408,7,0,0},Row{2415920370,12,0,0},Row{1073742055,47,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrllll(code: U32) -> Glyph:
  face0rlrllll.choose(U32.is_eq(code,192))

def face0rlrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),Row{81854464,0,0,0},Row{9895936,0,0,0},zero_row(),Row{12525568,0,0,0},Row{33386496,0,0,0},Row{114802688,0,0,0}},Rows8{Row{194245120,0,0,0},Row{524343040,0,0,0},Row{1845533696,0,0,0},Row{3389017888,0,0,0},Row{4294967152,2,0,0},Row{3811785408,7,0,0},Row{2415920370,12,0,0},Row{1073742055,47,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrlllrl(code: U32) -> Glyph:
  face0rlrlllrl.choose(U32.is_eq(code,193))

def face0rlrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),Row{13512704,0,0,0},Row{160747776,0,0,0},zero_row(),Row{12525568,0,0,0},Row{33386496,0,0,0},Row{114802688,0,0,0}},Rows8{Row{194245120,0,0,0},Row{524343040,0,0,0},Row{1845533696,0,0,0},Row{3389017888,0,0,0},Row{4294967152,2,0,0},Row{3811785408,7,0,0},Row{2415920370,12,0,0},Row{1073742055,47,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrlllrr(code: U32) -> Glyph:
  face0rlrlllrr.choose(U32.is_eq(code,194))

def face0rlrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrlllrl(code)
    case False{}: face0rlrlllrr(code)

def face0rlrlllr(+code: U32) -> Glyph:
  face0rlrlllr.choose(code,U32.is_lt(code,194))

def face0rlrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrllll(code)
    case False{}: face0rlrlllr(code)

def face0rlrlll(+code: U32) -> Glyph:
  face0rlrlll.choose(code,U32.is_lt(code,193))

def face0rlrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),Row{189509632,0,0,0},Row{114602240,0,0,0},zero_row(),Row{12525568,0,0,0},Row{33386496,0,0,0},Row{114802688,0,0,0}},Rows8{Row{194245120,0,0,0},Row{524343040,0,0,0},Row{1845533696,0,0,0},Row{3389017888,0,0,0},Row{4294967152,2,0,0},Row{3811785408,7,0,0},Row{2415920370,12,0,0},Row{1073742055,47,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrllrl(code: U32) -> Glyph:
  face0rlrllrl.choose(U32.is_eq(code,195))

def face0rlrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),Row{223466496,0,0,0},Row{16781312,0,0,0},zero_row(),Row{12525568,0,0,0},Row{33386496,0,0,0},Row{114802688,0,0,0}},Rows8{Row{194245120,0,0,0},Row{524343040,0,0,0},Row{1845533696,0,0,0},Row{3389017888,0,0,0},Row{4294967152,2,0,0},Row{3811785408,7,0,0},Row{2415920370,12,0,0},Row{1073742055,47,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrllrrl(code: U32) -> Glyph:
  face0rlrllrrl.choose(U32.is_eq(code,196))

def face0rlrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),Row{29179904,0,0,0},Row{128307200,0,0,0},Row{142790656,0,0,0},Row{49242112,0,0,0},Row{13574144,0,0,0},Row{33386496,0,0,0},Row{114802688,0,0,0}},Rows8{Row{194245120,0,0,0},Row{524343040,0,0,0},Row{1845533696,0,0,0},Row{3389017888,0,0,0},Row{4294967152,2,0,0},Row{3811785408,7,0,0},Row{2415920370,12,0,0},Row{1073742055,47,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrllrrr(code: U32) -> Glyph:
  face0rlrllrrr.choose(U32.is_eq(code,197))

def face0rlrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrllrrl(code)
    case False{}: face0rlrllrrr(code)

def face0rlrllrr(+code: U32) -> Glyph:
  face0rlrllrr.choose(code,U32.is_lt(code,197))

def face0rlrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrllrl(code)
    case False{}: face0rlrllrr(code)

def face0rlrllr(+code: U32) -> Glyph:
  face0rlrllr.choose(code,U32.is_lt(code,196))

def face0rlrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrlll(code)
    case False{}: face0rlrllr(code)

def face0rlrll(+code: U32) -> Glyph:
  face0rlrll.choose(code,U32.is_lt(code,195))

def face0rlrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4259381248,983039,0,0},Row{4090888192,139810,0,0},Row{4085055488,0,0,0}},Rows8{Row{4078915584,0,0,0},Row{4077563904,0,0,0},Row{4077122304,655359,0,0},Row{4076915200,74275,0,0},Row{4294967072,0,0,0},Row{4112662144,0,0,0},Row{4076865505,139810,0,0},Row{4076863974,1048575,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrlrll(code: U32) -> Glyph:
  face0rlrlrll.choose(U32.is_eq(code,198))

def face0rlrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1828552960,0,0,0},Row{3861171216,8,0,0},Row{805313920,47,0,0}},Rows8{Row{1744,54,0,0},Row{1009,0,0,0},Row{754,0,0,0},Row{1009,0,0,0},Row{1744,54,0,0},Row{805313920,63,0,0},Row{3861171216,9,0,0},Row{1845330176,0,0,0}},Rows8{Row{45154304,0,0,0},Row{238026752,0,0,0},Row{147128320,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0rlrlrlrl(code: U32) -> Glyph:
  face0rlrlrlrl.choose(U32.is_eq(code,199))

def face0rlrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),Row{4352,0,0,0},Row{254464,0,0,0},Row{684032,0,0,0},zero_row(),Row{2147483584,0,0,0},Row{304228800,0,0,0},Row{2240,0,0,0}},Rows8{Row{2240,0,0,0},Row{2240,0,0,0},Row{805306304,0,0,0},Row{35793344,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{304228800,0,0,0},Row{2415919040,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrlrlrr(code: U32) -> Glyph:
  face0rlrlrlrr.choose(U32.is_eq(code,200))

def face0rlrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrlrlrl(code)
    case False{}: face0rlrlrlrr(code)

def face0rlrlrlr(+code: U32) -> Glyph:
  face0rlrlrlr.choose(code,U32.is_lt(code,200))

def face0rlrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrlrll(code)
    case False{}: face0rlrlrlr(code)

def face0rlrlrl(+code: U32) -> Glyph:
  face0rlrlrl.choose(code,U32.is_lt(code,199))

def face0rlrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),Row{13041664,0,0,0},Row{3997696,0,0,0},zero_row(),Row{2147483584,0,0,0},Row{304228800,0,0,0},Row{2240,0,0,0}},Rows8{Row{2240,0,0,0},Row{2240,0,0,0},Row{805306304,0,0,0},Row{35793344,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{304228800,0,0,0},Row{2415919040,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrlrrll(code: U32) -> Glyph:
  face0rlrlrrll.choose(U32.is_eq(code,201))

def face0rlrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),Row{6197248,0,0,0},Row{64145152,0,0,0},zero_row(),Row{2147483584,0,0,0},Row{304228800,0,0,0},Row{2240,0,0,0}},Rows8{Row{2240,0,0,0},Row{2240,0,0,0},Row{805306304,0,0,0},Row{35793344,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{304228800,0,0,0},Row{2415919040,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrlrrlr(code: U32) -> Glyph:
  face0rlrlrrlr.choose(U32.is_eq(code,202))

def face0rlrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrlrrll(code)
    case False{}: face0rlrlrrlr(code)

def face0rlrlrrl(+code: U32) -> Glyph:
  face0rlrlrrl.choose(code,U32.is_lt(code,202))

def face0rlrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),Row{113281536,0,0,0},Row{1048832,0,0,0},zero_row(),Row{2147483584,0,0,0},Row{304228800,0,0,0},Row{2240,0,0,0}},Rows8{Row{2240,0,0,0},Row{2240,0,0,0},Row{805306304,0,0,0},Row{35793344,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{304228800,0,0,0},Row{2415919040,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrlrrrl(code: U32) -> Glyph:
  face0rlrlrrrl.choose(U32.is_eq(code,203))

def face0rlrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),Row{17,0,0,0},Row{184,0,0,0},Row{977,0,0,0},zero_row(),Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0}},Rows8{Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrlrrrr(code: U32) -> Glyph:
  face0rlrlrrrr.choose(U32.is_eq(code,204))

def face0rlrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrlrrrl(code)
    case False{}: face0rlrlrrrr(code)

def face0rlrlrrr(+code: U32) -> Glyph:
  face0rlrlrrr.choose(code,U32.is_lt(code,204))

def face0rlrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrlrrl(code)
    case False{}: face0rlrlrrr(code)

def face0rlrlrr(+code: U32) -> Glyph:
  face0rlrlrr.choose(code,U32.is_lt(code,203))

def face0rlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrlrl(code)
    case False{}: face0rlrlrr(code)

def face0rlrlr(+code: U32) -> Glyph:
  face0rlrlr.choose(code,U32.is_lt(code,201))

def face0rlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrll(code)
    case False{}: face0rlrlr(code)

def face0rlrl(+code: U32) -> Glyph:
  face0rlrl.choose(code,U32.is_lt(code,198))

def face0rlrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),Row{24064,0,0,0},Row{2656,0,0,0},zero_row(),Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0}},Rows8{Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0},Row{2240,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrrlll(code: U32) -> Glyph:
  face0rlrrlll.choose(U32.is_eq(code,205))

def face0rlrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),Row{118320,0,0,0},Row{689361,0,0,0},zero_row(),Row{35840,0,0,0},Row{35840,0,0,0},Row{35840,0,0,0}},Rows8{Row{35840,0,0,0},Row{35840,0,0,0},Row{35840,0,0,0},Row{35840,0,0,0},Row{35840,0,0,0},Row{35840,0,0,0},Row{35840,0,0,0},Row{35840,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrrllrl(code: U32) -> Glyph:
  face0rlrrllrl.choose(U32.is_eq(code,206))

def face0rlrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),Row{873171,0,0,0},Row{65552,0,0,0},zero_row(),Row{35840,0,0,0},Row{35840,0,0,0},Row{35840,0,0,0}},Rows8{Row{35840,0,0,0},Row{35840,0,0,0},Row{35840,0,0,0},Row{35840,0,0,0},Row{35840,0,0,0},Row{35840,0,0,0},Row{35840,0,0,0},Row{35840,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrrllrr(code: U32) -> Glyph:
  face0rlrrllrr.choose(U32.is_eq(code,207))

def face0rlrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrrllrl(code)
    case False{}: face0rlrrllrr(code)

def face0rlrrllr(+code: U32) -> Glyph:
  face0rlrrllr.choose(code,U32.is_lt(code,207))

def face0rlrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrrlll(code)
    case False{}: face0rlrrllr(code)

def face0rlrrll(+code: U32) -> Glyph:
  face0rlrrll.choose(code,U32.is_lt(code,206))

def face0rlrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{988807056,0,0,0},Row{3912379280,3,0,0},Row{2415922064,12,0,0}},Rows8{Row{536873872,63,0,0},Row{2960,94,0,0},Row{7340029,108,0,0},Row{1191346,94,0,0},Row{536873872,63,0,0},Row{2684357520,12,0,0},Row{3930205072,3,0,0},Row{720371600,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrrlrl(code: U32) -> Glyph:
  face0rlrrlrl.choose(U32.is_eq(code,208))

def face0rlrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),Row{979193856,0,0,0},Row{211062784,0,0,0},zero_row(),Row{11968,95,0,0},Row{44992,95,0,0},Row{260800,95,0,0}},Rows8{Row{829376,95,0,0},Row{7284928,95,0,0},Row{31983808,95,0,0},Row{164694208,95,0,0},Row{793774272,95,0,0},Row{2868906176,94,0,0},Row{4060088512,95,0,0},Row{2147485888,95,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrrlrrl(code: U32) -> Glyph:
  face0rlrrlrrl.choose(U32.is_eq(code,209))

def face0rlrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),Row{69632,0,0,0},Row{4071424,0,0,0},Row{10944512,0,0,0},zero_row(),Row{1827504384,0,0,0},Row{3861171200,8,0,0},Row{805313920,63,0,0}},Rows8{Row{1744,155,0,0},Row{1009,199,0,0},Row{754,214,0,0},Row{1009,199,0,0},Row{1744,155,0,0},Row{805313920,63,0,0},Row{3861171216,8,0,0},Row{1828552960,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrrlrrr(code: U32) -> Glyph:
  face0rlrrlrrr.choose(U32.is_eq(code,210))

def face0rlrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrrlrrl(code)
    case False{}: face0rlrrlrrr(code)

def face0rlrrlrr(+code: U32) -> Glyph:
  face0rlrrlrr.choose(code,U32.is_lt(code,210))

def face0rlrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrrlrl(code)
    case False{}: face0rlrrlrr(code)

def face0rlrrlr(+code: U32) -> Glyph:
  face0rlrrlr.choose(code,U32.is_lt(code,209))

def face0rlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrrll(code)
    case False{}: face0rlrrlr(code)

def face0rlrrl(+code: U32) -> Glyph:
  face0rlrrl.choose(code,U32.is_lt(code,208))

def face0rlrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),Row{208666624,0,0,0},Row{63963136,0,0,0},zero_row(),Row{1827504384,0,0,0},Row{3861171200,8,0,0},Row{805313920,63,0,0}},Rows8{Row{1744,155,0,0},Row{1009,199,0,0},Row{754,214,0,0},Row{1009,199,0,0},Row{1744,155,0,0},Row{805313920,63,0,0},Row{3861171216,8,0,0},Row{1828552960,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrrrll(code: U32) -> Glyph:
  face0rlrrrll.choose(U32.is_eq(code,211))

def face0rlrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),Row{99221504,0,0,0},Row{1026256896,0,0,0},zero_row(),Row{1827504384,0,0,0},Row{3861171200,8,0,0},Row{805313920,63,0,0}},Rows8{Row{1744,155,0,0},Row{1009,199,0,0},Row{754,214,0,0},Row{1009,199,0,0},Row{1744,155,0,0},Row{805313920,63,0,0},Row{3861171216,8,0,0},Row{1828552960,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrrrlrl(code: U32) -> Glyph:
  face0rlrrrlrl.choose(U32.is_eq(code,212))

def face0rlrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),Row{1231896576,0,0,0},Row{479559680,0,0,0},zero_row(),Row{1827504384,0,0,0},Row{3861171200,8,0,0},Row{805313920,63,0,0}},Rows8{Row{1744,155,0,0},Row{1009,199,0,0},Row{754,214,0,0},Row{1009,199,0,0},Row{1744,155,0,0},Row{805313920,63,0,0},Row{3861171216,8,0,0},Row{1828552960,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrrrlrr(code: U32) -> Glyph:
  face0rlrrrlrr.choose(U32.is_eq(code,213))

def face0rlrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrrrlrl(code)
    case False{}: face0rlrrrlrr(code)

def face0rlrrrlr(+code: U32) -> Glyph:
  face0rlrrrlr.choose(code,U32.is_lt(code,213))

def face0rlrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrrrll(code)
    case False{}: face0rlrrrlr(code)

def face0rlrrrl(+code: U32) -> Glyph:
  face0rlrrrl.choose(code,U32.is_lt(code,212))

def face0rlrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),Row{1812504576,0,0,0},Row{16781312,0,0,0},zero_row(),Row{1827504384,0,0,0},Row{3861171200,8,0,0},Row{805313920,63,0,0}},Rows8{Row{1744,155,0,0},Row{1009,199,0,0},Row{754,214,0,0},Row{1009,199,0,0},Row{1744,155,0,0},Row{805313920,63,0,0},Row{3861171216,8,0,0},Row{1828552960,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrrrrll(code: U32) -> Glyph:
  face0rlrrrrll.choose(U32.is_eq(code,214))

def face0rlrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{256,0,0,0},Row{2566921552,0,0,0},Row{764598784,0,0,0},Row{48144384,0,0,0},Row{30380032,0,0,0},Row{480434432,0,0,0},Row{2583702864,0,0,0},Row{268435712,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrrrrlr(code: U32) -> Glyph:
  face0rlrrrrlr.choose(U32.is_eq(code,215))

def face0rlrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrrrrll(code)
    case False{}: face0rlrrrrlr(code)

def face0rlrrrrl(+code: U32) -> Glyph:
  face0rlrrrrl.choose(code,U32.is_lt(code,215))

def face0rlrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1827504384,4,0,0},Row{4129606656,47,0,0},Row{4043316608,63,0,0}},Rows8{Row{2835351248,155,0,0},Row{508560369,199,0,0},Row{98632434,214,0,0},Row{10159089,199,0,0},Row{1926864,155,0,0},Row{805568384,63,0,0},Row{3861184272,8,0,0},Row{1828560224,0,0,0}},Rows8{Row{256,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0rlrrrrrl(code: U32) -> Glyph:
  face0rlrrrrrl.choose(U32.is_eq(code,216))

def face0rlrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),Row{69632,0,0,0},Row{1978368,0,0,0},Row{8978432,0,0,0},zero_row(),Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0}},Rows8{Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873392,47,0,0},Row{1879051648,14,0,0},Row{3877875216,6,0,0},Row{1559142912,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rlrrrrrr(code: U32) -> Glyph:
  face0rlrrrrrr.choose(U32.is_eq(code,217))

def face0rlrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrrrrrl(code)
    case False{}: face0rlrrrrrr(code)

def face0rlrrrrr(+code: U32) -> Glyph:
  face0rlrrrrr.choose(code,U32.is_lt(code,217))

def face0rlrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrrrrl(code)
    case False{}: face0rlrrrrr(code)

def face0rlrrrr(+code: U32) -> Glyph:
  face0rlrrrr.choose(code,U32.is_lt(code,216))

def face0rlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrrrl(code)
    case False{}: face0rlrrrr(code)

def face0rlrrr(+code: U32) -> Glyph:
  face0rlrrr.choose(code,U32.is_lt(code,214))

def face0rlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrrl(code)
    case False{}: face0rlrrr(code)

def face0rlrr(+code: U32) -> Glyph:
  face0rlrr.choose(code,U32.is_lt(code,211))

def face0rlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rlrl(code)
    case False{}: face0rlrr(code)

def face0rlr(+code: U32) -> Glyph:
  face0rlr.choose(code,U32.is_lt(code,205))

def face0rl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rll(code)
    case False{}: face0rlr(code)

def face0rl(+code: U32) -> Glyph:
  face0rl.choose(code,U32.is_lt(code,192))

def face0rrlllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),Row{177209344,0,0,0},Row{31588352,0,0,0},zero_row(),Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0}},Rows8{Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873392,47,0,0},Row{1879051648,14,0,0},Row{3877875216,6,0,0},Row{1559142912,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlllll(code: U32) -> Glyph:
  face0rrlllll.choose(U32.is_eq(code,218))

def face0rrllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),Row{65732608,0,0,0},Row{758812672,0,0,0},zero_row(),Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0}},Rows8{Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873392,47,0,0},Row{1879051648,14,0,0},Row{3877875216,6,0,0},Row{1559142912,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrllllrl(code: U32) -> Glyph:
  face0rrllllrl.choose(U32.is_eq(code,219))

def face0rrllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),Row{1293336576,0,0,0},Row{16781312,0,0,0},zero_row(),Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0}},Rows8{Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873152,63,0,0},Row{536873392,47,0,0},Row{1879051648,14,0,0},Row{3877875216,6,0,0},Row{1559142912,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrllllrr(code: U32) -> Glyph:
  face0rrllllrr.choose(U32.is_eq(code,220))

def face0rrllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrllllrl(code)
    case False{}: face0rrllllrr(code)

def face0rrllllr(+code: U32) -> Glyph:
  face0rrllllr.choose(code,U32.is_lt(code,220))

def face0rrllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlllll(code)
    case False{}: face0rrllllr(code)

def face0rrllll(+code: U32) -> Glyph:
  face0rrllll.choose(code,U32.is_lt(code,219))

def face0rrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),Row{65077248,0,0,0},Row{8912896,0,0,0},zero_row(),Row{2415919861,13,0,0},Row{4076866240,4,0,0},Row{3137359664,0,0,0}},Rows8{Row{792775168,0,0,0},Row{163963392,0,0,0},Row{32403456,0,0,0},Row{8261632,0,0,0},Row{7143424,0,0,0},Row{7143424,0,0,0},Row{7143424,0,0,0},Row{7143424,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlllrl(code: U32) -> Glyph:
  face0rrlllrl.choose(U32.is_eq(code,221))

def face0rrlllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2000,0,0,0},Row{2000,0,0,0},Row{2000,0,0,0}},Rows8{Row{97451984,0,0,0},Row{1600334032,0,0,0},Row{2835351504,0,0,0},Row{3087009744,0,0,0},Row{1848641488,0,0,0},Row{149946320,0,0,0},Row{141520,0,0,0},Row{2000,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlllrrl(code: U32) -> Glyph:
  face0rrlllrrl.choose(U32.is_eq(code,222))

def face0rrlllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{46065664,0,0,0},Row{229858912,0,0,0},Row{1059063984,0,0,0}},Rows8{Row{790628288,0,0,0},Row{193988544,0,0,0},Row{82786240,0,0,0},Row{1583486912,0,0,0},Row{3087009728,0,0,0},Row{3338667968,0,0,0},Row{2118260672,0,0,0},Row{149899200,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlllrrr(code: U32) -> Glyph:
  face0rrlllrrr.choose(U32.is_eq(code,223))

def face0rrlllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlllrrl(code)
    case False{}: face0rrlllrrr(code)

def face0rrlllrr(+code: U32) -> Glyph:
  face0rrlllrr.choose(code,U32.is_lt(code,223))

def face0rrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlllrl(code)
    case False{}: face0rrlllrr(code)

def face0rrlllr(+code: U32) -> Glyph:
  face0rrlllr.choose(code,U32.is_lt(code,222))

def face0rrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrllll(code)
    case False{}: face0rrlllr(code)

def face0rrlll(+code: U32) -> Glyph:
  face0rrlll.choose(code,U32.is_lt(code,221))

def face0rrllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{4352,0,0,0},Row{43264,0,0,0},Row{188672,0,0,0},zero_row()},Rows8{Row{27191840,0,0,0},Row{148126416,0,0,0},Row{192938016,0,0,0},Row{216765968,0,0,0},Row{210009042,0,0,0},Row{210764005,0,0,0},Row{216409843,0,0,0},Row{209383008,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrllrll(code: U32) -> Glyph:
  face0rrllrll.choose(U32.is_eq(code,224))

def face0rrllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{5115904,0,0,0},Row{618496,0,0,0},zero_row()},Rows8{Row{27191840,0,0,0},Row{148126416,0,0,0},Row{192938016,0,0,0},Row{216765968,0,0,0},Row{210009042,0,0,0},Row{210764005,0,0,0},Row{216409843,0,0,0},Row{209383008,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrllrlrl(code: U32) -> Glyph:
  face0rrllrlrl.choose(U32.is_eq(code,225))

def face0rrllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{844544,0,0,0},Row{10046752,0,0,0},zero_row()},Rows8{Row{27191840,0,0,0},Row{148126416,0,0,0},Row{192938016,0,0,0},Row{216765968,0,0,0},Row{210009042,0,0,0},Row{210764005,0,0,0},Row{216409843,0,0,0},Row{209383008,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrllrlrr(code: U32) -> Glyph:
  face0rrllrlrr.choose(U32.is_eq(code,226))

def face0rrllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrllrlrl(code)
    case False{}: face0rrllrlrr(code)

def face0rrllrlr(+code: U32) -> Glyph:
  face0rrllrlr.choose(code,U32.is_lt(code,226))

def face0rrllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrllrll(code)
    case False{}: face0rrllrlr(code)

def face0rrllrl(+code: U32) -> Glyph:
  face0rrllrl.choose(code,U32.is_lt(code,225))

def face0rrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{11844352,0,0,0},Row{7162656,0,0,0},zero_row()},Rows8{Row{27191840,0,0,0},Row{148126416,0,0,0},Row{192938016,0,0,0},Row{216765968,0,0,0},Row{210009042,0,0,0},Row{210764005,0,0,0},Row{216409843,0,0,0},Row{209383008,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrllrrl(code: U32) -> Glyph:
  face0rrllrrl.choose(U32.is_eq(code,227))

def face0rrllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{12983616,0,0,0},Row{1048832,0,0,0},zero_row()},Rows8{Row{27191840,0,0,0},Row{148126416,0,0,0},Row{192938016,0,0,0},Row{216765968,0,0,0},Row{210009042,0,0,0},Row{210764005,0,0,0},Row{216409843,0,0,0},Row{209383008,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrllrrrl(code: U32) -> Glyph:
  face0rrllrrrl.choose(U32.is_eq(code,228))

def face0rrllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{1823744,0,0,0},Row{7953664,0,0,0},Row{8858880,0,0,0},Row{3077632,0,0,0}},Rows8{Row{27261472,0,0,0},Row{148126416,0,0,0},Row{192938016,0,0,0},Row{216765968,0,0,0},Row{210009042,0,0,0},Row{210764005,0,0,0},Row{216409843,0,0,0},Row{209383008,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrllrrrr(code: U32) -> Glyph:
  face0rrllrrrr.choose(U32.is_eq(code,229))

def face0rrllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrllrrrl(code)
    case False{}: face0rrllrrrr(code)

def face0rrllrrr(+code: U32) -> Glyph:
  face0rrllrrr.choose(code,U32.is_lt(code,229))

def face0rrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrllrrl(code)
    case False{}: face0rrllrrr(code)

def face0rrllrr(+code: U32) -> Glyph:
  face0rrllrr.choose(code,U32.is_lt(code,228))

def face0rrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrllrl(code)
    case False{}: face0rrllrr(code)

def face0rrllr(+code: U32) -> Glyph:
  face0rrllr.choose(code,U32.is_lt(code,227))

def face0rrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlll(code)
    case False{}: face0rrllr(code)

def face0rrll(+code: U32) -> Glyph:
  face0rrll.choose(code,U32.is_lt(code,224))

def face0rrlrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{2728323888,2270,0,0},Row{2663594448,40003,0,0},Row{208666624,127744,0,0},Row{4294961984,196607,0,0},Row{729954547,8738,0,0},Row{513802469,12800,0,0},Row{3186042611,47923,0,0},Row{2721836384,6894,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlrlll(code: U32) -> Glyph:
  face0rrlrlll.choose(U32.is_eq(code,230))

def face0rrlrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{46065664,0,0,0},Row{496192912,0,0,0},Row{369100273,0,0,0},Row{499,0,0,0},Row{500,0,0,0},Row{369100017,0,0,0},Row{512970128,0,0,0},Row{46065664,0,0,0}},Rows8{Row{1716224,0,0,0},Row{11866112,0,0,0},Row{8151040,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0rrlrllrl(code: U32) -> Glyph:
  face0rrlrllrl.choose(U32.is_eq(code,231))

def face0rrlrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{4352,0,0,0},Row{123904,0,0,0},Row{434176,0,0,0},zero_row()},Rows8{Row{45017088,0,0,0},Row{496192656,0,0,0},Row{1577059057,0,0,0},Row{2147483636,0,0,0},Row{304227316,0,0,0},Row{67110129,0,0,0},Row{797072784,0,0,0},Row{80664576,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlrllrr(code: U32) -> Glyph:
  face0rrlrllrr.choose(U32.is_eq(code,232))

def face0rrlrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlrllrl(code)
    case False{}: face0rrlrllrr(code)

def face0rrlrllr(+code: U32) -> Glyph:
  face0rrlrllr.choose(code,U32.is_lt(code,232))

def face0rrlrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlrlll(code)
    case False{}: face0rrlrllr(code)

def face0rrlrll(+code: U32) -> Glyph:
  face0rrlrll.choose(code,U32.is_lt(code,231))

def face0rrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{10092544,0,0,0},Row{1912832,0,0,0},zero_row()},Rows8{Row{45017088,0,0,0},Row{496192656,0,0,0},Row{1577059057,0,0,0},Row{2147483636,0,0,0},Row{304227316,0,0,0},Row{67110129,0,0,0},Row{797072784,0,0,0},Row{80664576,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlrlrl(code: U32) -> Glyph:
  face0rrlrlrl.choose(U32.is_eq(code,233))

def face0rrlrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3064064,0,0,0},Row{30771712,0,0,0},zero_row()},Rows8{Row{45017088,0,0,0},Row{496192656,0,0,0},Row{1577059057,0,0,0},Row{2147483636,0,0,0},Row{304227316,0,0,0},Row{67110129,0,0,0},Row{797072784,0,0,0},Row{80664576,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlrlrrl(code: U32) -> Glyph:
  face0rrlrlrrl.choose(U32.is_eq(code,234))

def face0rrlrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{64118016,0,0,0},Row{1048832,0,0,0},zero_row()},Rows8{Row{45017088,0,0,0},Row{496192656,0,0,0},Row{1577059057,0,0,0},Row{2147483636,0,0,0},Row{304227316,0,0,0},Row{67110129,0,0,0},Row{797072784,0,0,0},Row{80664576,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlrlrrr(code: U32) -> Glyph:
  face0rrlrlrrr.choose(U32.is_eq(code,235))

def face0rrlrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlrlrrl(code)
    case False{}: face0rrlrlrrr(code)

def face0rrlrlrr(+code: U32) -> Glyph:
  face0rrlrlrr.choose(code,U32.is_lt(code,235))

def face0rrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlrlrl(code)
    case False{}: face0rrlrlrr(code)

def face0rrlrlr(+code: U32) -> Glyph:
  face0rrlrlr.choose(code,U32.is_lt(code,234))

def face0rrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlrll(code)
    case False{}: face0rrlrlr(code)

def face0rrlrl(+code: U32) -> Glyph:
  face0rrlrl.choose(code,U32.is_lt(code,233))

def face0rrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{16,0,0,0},Row{2224,0,0,0},Row{7712,0,0,0},zero_row()},Rows8{Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlrrll(code: U32) -> Glyph:
  face0rrlrrll.choose(U32.is_eq(code,236))

def face0rrlrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{15904,0,0,0},Row{2192,0,0,0},zero_row()},Rows8{Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlrrlrl(code: U32) -> Glyph:
  face0rrlrrlrl.choose(U32.is_eq(code,237))

def face0rrlrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{44624,0,0,0},Row{504803,0,0,0},zero_row()},Rows8{Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlrrlrr(code: U32) -> Glyph:
  face0rrlrrlrr.choose(U32.is_eq(code,238))

def face0rrlrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlrrlrl(code)
    case False{}: face0rrlrrlrr(code)

def face0rrlrrlr(+code: U32) -> Glyph:
  face0rrlrrlr.choose(code,U32.is_lt(code,238))

def face0rrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlrrll(code)
    case False{}: face0rrlrrlr(code)

def face0rrlrrl(+code: U32) -> Glyph:
  face0rrlrrl.choose(code,U32.is_lt(code,237))

def face0rrlrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{749765,0,0,0},Row{65552,0,0,0},zero_row()},Rows8{Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0},Row{24064,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlrrrll(code: U32) -> Glyph:
  face0rrlrrrll.choose(U32.is_eq(code,239))

def face0rrlrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{17843456,0,0,0},Row{98227200,0,0,0},Row{9295360,0,0,0},Row{64033792,0,0,0}},Rows8{Row{194832640,0,0,0},Row{531910032,0,0,0},Row{1595933937,0,0,0},Row{1828717044,0,0,0},Row{1811939572,0,0,0},Row{1058014449,0,0,0},Row{196300176,0,0,0},Row{28239872,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlrrrlr(code: U32) -> Glyph:
  face0rrlrrrlr.choose(U32.is_eq(code,240))

def face0rrlrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlrrrll(code)
    case False{}: face0rrlrrrlr(code)

def face0rrlrrrl(+code: U32) -> Glyph:
  face0rrlrrrl.choose(code,U32.is_lt(code,240))

def face0rrlrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{29677056,0,0,0},Row{11221760,0,0,0},zero_row()},Rows8{Row{63878624,0,0,0},Row{228809952,0,0,0},Row{790628320,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlrrrrl(code: U32) -> Glyph:
  face0rrlrrrrl.choose(U32.is_eq(code,241))

def face0rrlrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{4352,0,0,0},Row{123904,0,0,0},Row{495616,0,0,0},zero_row()},Rows8{Row{46065664,0,0,0},Row{512970128,0,0,0},Row{2097153521,0,0,0},Row{2852127219,0,0,0},Row{2852127220,0,0,0},Row{2097153265,0,0,0},Row{512970128,0,0,0},Row{46065664,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrlrrrrr(code: U32) -> Glyph:
  face0rrlrrrrr.choose(U32.is_eq(code,242))

def face0rrlrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlrrrrl(code)
    case False{}: face0rrlrrrrr(code)

def face0rrlrrrr(+code: U32) -> Glyph:
  face0rrlrrrr.choose(code,U32.is_lt(code,242))

def face0rrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlrrrl(code)
    case False{}: face0rrlrrrr(code)

def face0rrlrrr(+code: U32) -> Glyph:
  face0rrlrrr.choose(code,U32.is_lt(code,241))

def face0rrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlrrl(code)
    case False{}: face0rrlrrr(code)

def face0rrlrr(+code: U32) -> Glyph:
  face0rrlrr.choose(code,U32.is_lt(code,239))

def face0rrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrlrl(code)
    case False{}: face0rrlrr(code)

def face0rrlr(+code: U32) -> Glyph:
  face0rrlr.choose(code,U32.is_lt(code,236))

def face0rrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrll(code)
    case False{}: face0rrlr(code)

def face0rrl(+code: U32) -> Glyph:
  face0rrl.choose(code,U32.is_lt(code,230))

def face0rrrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{11141120,0,0,0},Row{1908736,0,0,0},zero_row()},Rows8{Row{46065664,0,0,0},Row{512970128,0,0,0},Row{2097153521,0,0,0},Row{2852127219,0,0,0},Row{2852127220,0,0,0},Row{2097153265,0,0,0},Row{512970128,0,0,0},Row{46065664,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrllll(code: U32) -> Glyph:
  face0rrrllll.choose(U32.is_eq(code,243))

def face0rrrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4112384,0,0,0},Row{30710272,0,0,0},zero_row()},Rows8{Row{46065664,0,0,0},Row{512970128,0,0,0},Row{2097153521,0,0,0},Row{2852127219,0,0,0},Row{2852127220,0,0,0},Row{2097153265,0,0,0},Row{512970128,0,0,0},Row{46065664,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrlllrl(code: U32) -> Glyph:
  face0rrrlllrl.choose(U32.is_eq(code,244))

def face0rrrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{45471232,0,0,0},Row{12204800,0,0,0},zero_row()},Rows8{Row{46065664,0,0,0},Row{512970128,0,0,0},Row{2097153521,0,0,0},Row{2852127219,0,0,0},Row{2852127220,0,0,0},Row{2097153265,0,0,0},Row{512970128,0,0,0},Row{46065664,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrlllrr(code: U32) -> Glyph:
  face0rrrlllrr.choose(U32.is_eq(code,245))

def face0rrrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrlllrl(code)
    case False{}: face0rrrlllrr(code)

def face0rrrlllr(+code: U32) -> Glyph:
  face0rrrlllr.choose(code,U32.is_lt(code,245))

def face0rrrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrllll(code)
    case False{}: face0rrrlllr(code)

def face0rrrlll(+code: U32) -> Glyph:
  face0rrrlll.choose(code,U32.is_lt(code,244))

def face0rrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{80833536,0,0,0},Row{1048832,0,0,0},zero_row()},Rows8{Row{46065664,0,0,0},Row{512970128,0,0,0},Row{2097153521,0,0,0},Row{2852127219,0,0,0},Row{2852127220,0,0,0},Row{2097153265,0,0,0},Row{512970128,0,0,0},Row{46065664,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrllrl(code: U32) -> Glyph:
  face0rrrllrl.choose(U32.is_eq(code,246))

def face0rrrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{6168576,0,0,0},Row{4988928,0,0,0},zero_row(),Row{3489660800,0,0,0},Row{572662288,0,0,0},Row{4988928,0,0,0},Row{6168576,0,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrllrrl(code: U32) -> Glyph:
  face0rrrllrrl.choose(U32.is_eq(code,247))

def face0rrrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{2008999936,0,0,0},Row{1338199440,0,0,0},Row{2144470513,0,0,0},Row{2859209203,0,0,0},Row{2852696564,0,0,0},Row{2097196529,0,0,0},Row{512974832,0,0,0},Row{46066131,0,0,0}},Rows8{Row{16,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0rrrllrrr(code: U32) -> Glyph:
  face0rrrllrrr.choose(U32.is_eq(code,248))

def face0rrrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrllrrl(code)
    case False{}: face0rrrllrrr(code)

def face0rrrllrr(+code: U32) -> Glyph:
  face0rrrllrr.choose(code,U32.is_lt(code,248))

def face0rrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrllrl(code)
    case False{}: face0rrrllrr(code)

def face0rrrllr(+code: U32) -> Glyph:
  face0rrrllr.choose(code,U32.is_lt(code,247))

def face0rrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrlll(code)
    case False{}: face0rrrllr(code)

def face0rrrll(+code: U32) -> Glyph:
  face0rrrll.choose(code,U32.is_lt(code,246))

def face0rrrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{4352,0,0,0},Row{123904,0,0,0},Row{499712,0,0,0},zero_row()},Rows8{Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1058014688,0,0,0},Row{1060112080,0,0,0},Row{1067666832,0,0,0},Row{1062071056,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrlrll(code: U32) -> Glyph:
  face0rrrlrll.choose(U32.is_eq(code,249))

def face0rrrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{10092544,0,0,0},Row{1908736,0,0,0},zero_row()},Rows8{Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1058014688,0,0,0},Row{1060112080,0,0,0},Row{1067666832,0,0,0},Row{1062071056,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrlrlrl(code: U32) -> Glyph:
  face0rrrlrlrl.choose(U32.is_eq(code,250))

def face0rrrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4112640,0,0,0},Row{30706176,0,0,0},zero_row()},Rows8{Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1058014688,0,0,0},Row{1060112080,0,0,0},Row{1067666832,0,0,0},Row{1062071056,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrlrlrr(code: U32) -> Glyph:
  face0rrrlrlrr.choose(U32.is_eq(code,251))

def face0rrrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrlrlrl(code)
    case False{}: face0rrrlrlrr(code)

def face0rrrlrlr(+code: U32) -> Glyph:
  face0rrrlrlr.choose(code,U32.is_lt(code,251))

def face0rrrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrlrll(code)
    case False{}: face0rrrlrlr(code)

def face0rrrlrl(+code: U32) -> Glyph:
  face0rrrlrl.choose(code,U32.is_lt(code,250))

def face0rrrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{64052480,0,0,0},Row{1048832,0,0,0},zero_row()},Rows8{Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1056966112,0,0,0},Row{1058014688,0,0,0},Row{1060112080,0,0,0},Row{1067666832,0,0,0},Row{1062071056,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrlrrll(code: U32) -> Glyph:
  face0rrrlrrll.choose(U32.is_eq(code,252))

def face0rrrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{7143424,0,0,0},Row{741376,0,0,0},zero_row()},Rows8{Row{1594884311,0,0,0},Row{240124913,0,0,0},Row{162531760,0,0,0},Row{66129488,0,0,0},Row{14044688,0,0,0},Row{8096256,0,0,0},Row{3068928,0,0,0},Row{778240,0,0,0}},Rows8{Row{446464,0,0,0},Row{124704,0,0,0},Row{19936,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0rrrlrrlr(code: U32) -> Glyph:
  face0rrrlrrlr.choose(U32.is_eq(code,253))

def face0rrrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrlrrll(code)
    case False{}: face0rrrlrrlr(code)

def face0rrrlrrl(+code: U32) -> Glyph:
  face0rrrlrrl.choose(code,U32.is_lt(code,253))

def face0rrrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0}},Rows8{Row{98547424,0,0,0},Row{1064529376,0,0,0},Row{2852129248,0,0,0},Row{3338667488,0,0,0},Row{3338667488,0,0,0},Row{2868906464,0,0,0},Row{1064529376,0,0,0},Row{98547424,0,0,0}},Rows8{Row{1504,0,0,0},Row{1504,0,0,0},Row{1504,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0rrrlrrrl(code: U32) -> Glyph:
  face0rrrlrrrl.choose(U32.is_eq(code,254))

def face0rrrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{30682400,0,0,0},Row{1048832,0,0,0},zero_row()},Rows8{Row{1594884311,0,0,0},Row{240124913,0,0,0},Row{162531760,0,0,0},Row{66129488,0,0,0},Row{14044688,0,0,0},Row{8096256,0,0,0},Row{3068928,0,0,0},Row{778240,0,0,0}},Rows8{Row{446464,0,0,0},Row{124704,0,0,0},Row{19936,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0rrrlrrrr(code: U32) -> Glyph:
  face0rrrlrrrr.choose(U32.is_eq(code,255))

def face0rrrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrlrrrl(code)
    case False{}: face0rrrlrrrr(code)

def face0rrrlrrr(+code: U32) -> Glyph:
  face0rrrlrrr.choose(code,U32.is_lt(code,255))

def face0rrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrlrrl(code)
    case False{}: face0rrrlrrr(code)

def face0rrrlrr(+code: U32) -> Glyph:
  face0rrrlrr.choose(code,U32.is_lt(code,254))

def face0rrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrlrl(code)
    case False{}: face0rrrlrr(code)

def face0rrrlr(+code: U32) -> Glyph:
  face0rrrlr.choose(code,U32.is_lt(code,252))

def face0rrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrll(code)
    case False{}: face0rrrlr(code)

def face0rrrl(+code: U32) -> Glyph:
  face0rrrl.choose(code,U32.is_lt(code,249))

def face0rrrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),Row{268435455,0,0,0},Row{35791394,0,0,0},zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrrlll(code: U32) -> Glyph:
  face0rrrrlll.choose(U32.is_eq(code,8211))

def face0rrrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),Row{4294967295,16777215,0,0},Row{572662306,2236962,0,0},zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrrllrl(code: U32) -> Glyph:
  face0rrrrllrl.choose(U32.is_eq(code,8212))

def face0rrrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{7680,0,0,0},Row{3392,0,0,0},Row{2944,0,0,0}},Rows8{Row{2496,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrrllrr(code: U32) -> Glyph:
  face0rrrrllrr.choose(U32.is_eq(code,8216))

def face0rrrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrrllrl(code)
    case False{}: face0rrrrllrr(code)

def face0rrrrllr(+code: U32) -> Glyph:
  face0rrrrllr.choose(code,U32.is_lt(code,8216))

def face0rrrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrrlll(code)
    case False{}: face0rrrrllr(code)

def face0rrrrll(+code: U32) -> Glyph:
  face0rrrrll.choose(code,U32.is_lt(code,8212))

def face0rrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3680,0,0,0},Row{2944,0,0,0},Row{1696,0,0,0}},Rows8{Row{720,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrrlrl(code: U32) -> Glyph:
  face0rrrrlrl.choose(U32.is_eq(code,8217))

def face0rrrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{8855040,0,0,0},Row{7015744,0,0,0},Row{5114752,0,0,0}},Rows8{Row{2050496,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrrlrrl(code: U32) -> Glyph:
  face0rrrrlrrl.choose(U32.is_eq(code,8220))

def face0rrrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{8195680,0,0,0},Row{4131712,0,0,0},Row{927392,0,0,0}},Rows8{Row{676560,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrrlrrr(code: U32) -> Glyph:
  face0rrrrlrrr.choose(U32.is_eq(code,8221))

def face0rrrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrrlrrl(code)
    case False{}: face0rrrrlrrr(code)

def face0rrrrlrr(+code: U32) -> Glyph:
  face0rrrrlrr.choose(code,U32.is_lt(code,8221))

def face0rrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrrlrl(code)
    case False{}: face0rrrrlrr(code)

def face0rrrrlr(+code: U32) -> Glyph:
  face0rrrrlr.choose(code,U32.is_lt(code,8220))

def face0rrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrrll(code)
    case False{}: face0rrrrlr(code)

def face0rrrrl(+code: U32) -> Glyph:
  face0rrrrl.choose(code,U32.is_lt(code,8217))

def face0rrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{zero_row(),Row{4056320,0,0,0},Row{14679568,0,0,0},Row{33554224,0,0,0},Row{14679568,0,0,0},Row{4056320,0,0,0},zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrrrll(code: U32) -> Glyph:
  face0rrrrrll.choose(U32.is_eq(code,8226))

def face0rrrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{176163216,2688,0,0},Row{211815344,3232,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrrrlrl(code: U32) -> Glyph:
  face0rrrrrlrl.choose(U32.is_eq(code,8230))

def face0rrrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{76546048,0,0,0}},Rows8{Row{47775744,0,0,0},Row{2985984,0,0,0},Row{182272,0,0,0},Row{4294893408,40959,0,0},Row{572762880,4642,0,0},Row{1814528,0,0,0},Row{29036544,0,0,0},Row{95485952,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrrrlrr(code: U32) -> Glyph:
  face0rrrrrlrr.choose(U32.is_eq(code,8592))

def face0rrrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrrrlrl(code)
    case False{}: face0rrrrrlrr(code)

def face0rrrrrlr(+code: U32) -> Glyph:
  face0rrrrrlr.choose(code,U32.is_lt(code,8592))

def face0rrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrrrll(code)
    case False{}: face0rrrrrlr(code)

def face0rrrrrl(+code: U32) -> Glyph:
  face0rrrrrl.choose(code,U32.is_lt(code,8230))

def face0rrrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{38797312,0,0,0},Row{771031040,0,0,0},Row{3669901312,1,0,0}},Rows8{Row{2528437248,29,0,0},Row{112221760,458,0,0},Row{112199200,112,0,0},Row{112197632,0,0,0},Row{112197632,0,0,0},Row{112197632,0,0,0},Row{112197632,0,0,0},Row{112197632,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrrrrll(code: U32) -> Glyph:
  face0rrrrrrll.choose(U32.is_eq(code,8593))

def face0rrrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2969567232,2,0,0}},Rows8{Row{2415919104,45,0,0},Row{0,474,0,0},Row{0,7296,0,0},Row{4294967104,48863,0,0},Row{572662288,15714,0,0},Row{0,998,0,0},Row{1610612736,62,0,0},Row{3506438144,3,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrrrrlr(code: U32) -> Glyph:
  face0rrrrrrlr.choose(U32.is_eq(code,8594))

def face0rrrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrrrrll(code)
    case False{}: face0rrrrrrlr(code)

def face0rrrrrrl(+code: U32) -> Glyph:
  face0rrrrrrl.choose(code,U32.is_lt(code,8594))

def face0rrrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{112197632,0,0,0},Row{112197632,0,0,0},Row{112197632,0,0,0}},Rows8{Row{112197632,0,0,0},Row{112197632,0,0,0},Row{112199200,112,0,0},Row{112221760,458,0,0},Row{2528437248,29,0,0},Row{3669905408,2,0,0},Row{771031040,0,0,0},Row{38797312,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face0.missing()

def face0rrrrrrrl(code: U32) -> Glyph:
  face0rrrrrrrl.choose(U32.is_eq(code,8595))

def face0rrrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{251656960,0,0,0},Row{251263744,0,0,0},Row{251656960,0,0,0},Row{251239168,0,0,0}},Rows8{Row{251656960,0,0,0},Row{251263744,0,0,0},Row{245365504,0,0,0},Row{249420544,0,0,0},Row{245340928,0,0,0},Row{251656960,0,0,0},Row{244288256,0,0,0},Row{241404672,0,0,0}},Rows8{Row{251656960,0,0,0},Row{249096960,0,0,0},Row{251656960,0,0,0},Row{53686784,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face0.missing()

def face0rrrrrrrr(code: U32) -> Glyph:
  face0rrrrrrrr.choose(U32.is_eq(code,65533))

def face0rrrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrrrrrl(code)
    case False{}: face0rrrrrrrr(code)

def face0rrrrrrr(+code: U32) -> Glyph:
  face0rrrrrrr.choose(code,U32.is_lt(code,65533))

def face0rrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrrrrl(code)
    case False{}: face0rrrrrrr(code)

def face0rrrrrr(+code: U32) -> Glyph:
  face0rrrrrr.choose(code,U32.is_lt(code,8595))

def face0rrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrrrl(code)
    case False{}: face0rrrrrr(code)

def face0rrrrr(+code: U32) -> Glyph:
  face0rrrrr.choose(code,U32.is_lt(code,8593))

def face0rrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrrl(code)
    case False{}: face0rrrrr(code)

def face0rrrr(+code: U32) -> Glyph:
  face0rrrr.choose(code,U32.is_lt(code,8226))

def face0rrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrrl(code)
    case False{}: face0rrrr(code)

def face0rrr(+code: U32) -> Glyph:
  face0rrr.choose(code,U32.is_lt(code,8211))

def face0rr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rrl(code)
    case False{}: face0rrr(code)

def face0rr(+code: U32) -> Glyph:
  face0rr.choose(code,U32.is_lt(code,243))

def face0r.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0rl(code)
    case False{}: face0rr(code)

def face0r(+code: U32) -> Glyph:
  face0r.choose(code,U32.is_lt(code,218))

def face0.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face0l(code)
    case False{}: face0r(code)

def face0(+code: U32) -> Glyph:
  face0.choose(code,U32.is_lt(code,167))

def face1.missing() -> Glyph:
  Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),Row{35791360,0,0,0},Row{251591424,0,0,0},Row{251263744,0,0,0},Row{251587328,0,0,0},Row{251239168,0,0,0}},Rows8{Row{251591424,0,0,0},Row{250215168,0,0,0},Row{245365504,0,0,0},Row{249486080,0,0,0},Row{245340928,0,0,0},Row{251656960,0,0,0},Row{244820736,0,0,0},Row{245340928,0,0,0}},Rows8{Row{250608384,0,0,0},Row{250145536,0,0,0},Row{251656960,0,0,0},Row{89478144,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}

def face1lllllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[zero_rows(),zero_rows(),zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lllllll(code: U32) -> Glyph:
  face1lllllll.choose(U32.is_eq(code,32))

def face1llllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{16304,0,0,0},Row{16288,0,0,0},Row{12192,0,0,0}},Rows8{Row{12192,0,0,0},Row{12192,0,0,0},Row{12176,0,0,0},Row{8080,0,0,0},zero_row(),Row{256,0,0,0},Row{16304,0,0,0},Row{16016,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llllllrl(code: U32) -> Glyph:
  face1llllllrl.choose(U32.is_eq(code,33))

def face1llllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{14430096,0,0,0},Row{14360448,0,0,0},Row{13311856,0,0,0}},Rows8{Row{12193632,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llllllrr(code: U32) -> Glyph:
  face1llllllrr.choose(U32.is_eq(code,34))

def face1llllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llllllrl(code)
    case False{}: face1llllllrr(code)

def face1llllllr(+code: U32) -> Glyph:
  face1llllllr.choose(code,U32.is_lt(code,34))

def face1llllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllllll(code)
    case False{}: face1llllllr(code)

def face1llllll(+code: U32) -> Glyph:
  face1llllll.choose(code,U32.is_lt(code,33))

def face1lllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3120755456,0,0,0},Row{2617308416,0,0,0},Row{2113984512,0,0,0}},Rows8{Row{4294967281,11,0,0},Row{2409086577,5,0,0},Row{257977856,0,0,0},Row{764571457,1,0,0},Row{4294967291,2,0,0},Row{1524981396,0,0,0},Row{116395152,0,0,0},Row{66194096,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lllllrl(code: U32) -> Glyph:
  face1lllllrl.choose(U32.is_eq(code,35))

def face1lllllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{786432,0,0,0},Row{451925760,0,0,0},Row{3486441344,0,0,0},Row{4195098336,3,0,0}},Rows8{Row{286002672,0,0,0},Row{3071904,0,0,0},Row{1006631184,0,0,0},Row{4021096448,1,0,0},Row{4161536577,6,0,0},Row{4178316275,5,0,0},Row{4022259648,1,0,0},Row{1005578512,0,0,0}},Rows8{Row{786432,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lllllrrl(code: U32) -> Glyph:
  face1lllllrrl.choose(U32.is_eq(code,36))

def face1lllllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{784896,3184,0,0},Row{8293984,994,0,0},Row{11143824,139,0,0}},Rows8{Row{1619869056,29,0,0},Row{3777953312,4,0,0},Row{2852274432,512,0,0},Row{508559360,188369,0,0},Row{114360320,579303,0,0},Row{12124160,696505,0,0},Row{3026944,583910,0,0},Row{507904,114608,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lllllrrr(code: U32) -> Glyph:
  face1lllllrrr.choose(U32.is_eq(code,37))

def face1lllllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllllrrl(code)
    case False{}: face1lllllrrr(code)

def face1lllllrr(+code: U32) -> Glyph:
  face1lllllrr.choose(code,U32.is_lt(code,37))

def face1lllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllllrl(code)
    case False{}: face1lllllrr(code)

def face1lllllr(+code: U32) -> Glyph:
  face1lllllr.choose(code,U32.is_lt(code,36))

def face1lllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llllll(code)
    case False{}: face1lllllr(code)

def face1lllll(+code: U32) -> Glyph:
  face1lllll.choose(code,U32.is_lt(code,35))

def face1llllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{10413568,0,0,0},Row{133807936,0,0,0},Row{198193008,0,0,0}},Rows8{Row{150437728,0,0,0},Row{30408208,0,0,0},Row{2030352,0,0,0},Row{4052729776,8,0,0},Row{4193913076,6,0,0},Row{4022339573,1,0,0},Row{4025065185,1,0,0},Row{4121881392,11,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llllrll(code: U32) -> Glyph:
  face1llllrll.choose(U32.is_eq(code,38))

def face1llllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{12176,0,0,0},Row{8064,0,0,0},Row{8048,0,0,0}},Rows8{Row{3936,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llllrlrl(code: U32) -> Glyph:
  face1llllrlrl.choose(U32.is_eq(code,39))

def face1llllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{586496,0,0,0},Row{195072,0,0,0},Row{53008,0,0,0}},Rows8{Row{36672,0,0,0},Row{24448,0,0,0},Row{16272,0,0,0},Row{12208,0,0,0},Row{12192,0,0,0},Row{16272,0,0,0},Row{32608,0,0,0},Row{48928,0,0,0}},Rows8{Row{195328,0,0,0},Row{586496,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1llllrlrr(code: U32) -> Glyph:
  face1llllrlrr.choose(U32.is_eq(code,40))

def face1llllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llllrlrl(code)
    case False{}: face1llllrlrr(code)

def face1llllrlr(+code: U32) -> Glyph:
  face1llllrlr.choose(code,U32.is_lt(code,40))

def face1llllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llllrll(code)
    case False{}: face1llllrlr(code)

def face1llllrl(+code: U32) -> Glyph:
  face1llllrl.choose(code,U32.is_lt(code,39))

def face1llllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2036,0,0,0},Row{3536,0,0,0},Row{16256,0,0,0}},Rows8{Row{32592,0,0,0},Row{48912,0,0,0},Row{52992,0,0,0},Row{60672,0,0,0},Row{60928,0,0,0},Row{52992,0,0,0},Row{40768,0,0,0},Row{24448,0,0,0}},Rows8{Row{3792,0,0,0},Row{2036,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1llllrrl(code: U32) -> Glyph:
  face1llllrrl.choose(U32.is_eq(code,41))

def face1llllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{376832,0,0,0},Row{78034576,0,0,0},Row{45088080,0,0,0}},Rows8{Row{27262016,0,0,0},Row{79083424,0,0,0},Row{376832,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llllrrrl(code: U32) -> Glyph:
  face1llllrrrl.choose(U32.is_eq(code,42))

def face1llllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{8327168,0,0,0},Row{8327168,0,0,0},Row{579809824,0,0,0},Row{4294967216,2,0,0},Row{1437558080,1,0,0},Row{8327168,0,0,0},Row{8327168,0,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llllrrrr(code: U32) -> Glyph:
  face1llllrrrr.choose(U32.is_eq(code,43))

def face1llllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llllrrrl(code)
    case False{}: face1llllrrrr(code)

def face1llllrrr(+code: U32) -> Glyph:
  face1llllrrr.choose(code,U32.is_lt(code,43))

def face1llllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llllrrl(code)
    case False{}: face1llllrrr(code)

def face1llllrr(+code: U32) -> Glyph:
  face1llllrr.choose(code,U32.is_lt(code,42))

def face1llllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llllrl(code)
    case False{}: face1llllrr(code)

def face1llllr(+code: U32) -> Glyph:
  face1llllr.choose(code,U32.is_lt(code,41))

def face1llll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllll(code)
    case False{}: face1llllr(code)

def face1llll(+code: U32) -> Glyph:
  face1llll.choose(code,U32.is_lt(code,38))

def face1lllrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{12192,0,0,0}},Rows8{Row{3264,0,0,0},Row{2272,0,0,0},Row{1009,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lllrlll(code: U32) -> Glyph:
  face1lllrlll.choose(U32.is_eq(code,44))

def face1lllrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{zero_row(),zero_row(),Row{1188384,0,0,0},Row{9437168,0,0,0},Row{3495248,0,0,0},zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lllrllrl(code: U32) -> Glyph:
  face1lllrllrl.choose(U32.is_eq(code,45))

def face1lllrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{256,0,0,0},Row{16304,0,0,0},Row{11920,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lllrllrr(code: U32) -> Glyph:
  face1lllrllrr.choose(U32.is_eq(code,46))

def face1lllrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllrllrl(code)
    case False{}: face1lllrllrr(code)

def face1lllrllr(+code: U32) -> Glyph:
  face1lllrllr.choose(code,U32.is_lt(code,46))

def face1lllrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllrlll(code)
    case False{}: face1lllrllr(code)

def face1lllrll(+code: U32) -> Glyph:
  face1lllrll.choose(code,U32.is_lt(code,45))

def face1lllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{475136,0,0,0},Row{831488,0,0,0},Row{585984,0,0,0}},Rows8{Row{324608,0,0,0},Row{129024,0,0,0},Row{48128,0,0,0},Row{36624,0,0,0},Row{20304,0,0,0},Row{3728,0,0,0},Row{3024,0,0,0},Row{2034,0,0,0}},Rows8{Row{1014,0,0,0},Row{234,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lllrlrl(code: U32) -> Glyph:
  face1lllrlrl.choose(U32.is_eq(code,47))

def face1lllrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{132105472,0,0,0},Row{2143870784,0,0,0},Row{4244647872,1,0,0}},Rows8{Row{4160752881,5,0,0},Row{4127197684,7,0,0},Row{4110420212,8,0,0},Row{4127197684,7,0,0},Row{4160752881,5,0,0},Row{4244647872,1,0,0},Row{2412306240,0,0,0},Row{132105472,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lllrlrrl(code: U32) -> Glyph:
  face1lllrlrrl.choose(U32.is_eq(code,48))

def face1lllrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{981520,0,0,0},Row{982978,0,0,0},Row{976101,0,0,0}},Rows8{Row{974883,0,0,0},Row{974848,0,0,0},Row{974848,0,0,0},Row{974848,0,0,0},Row{974848,0,0,0},Row{974848,0,0,0},Row{974848,0,0,0},Row{974848,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lllrlrrr(code: U32) -> Glyph:
  face1lllrlrrr.choose(U32.is_eq(code,49))

def face1lllrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllrlrrl(code)
    case False{}: face1lllrlrrr(code)

def face1lllrlrr(+code: U32) -> Glyph:
  face1lllrlrr.choose(code,U32.is_lt(code,49))

def face1lllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllrlrl(code)
    case False{}: face1lllrlrr(code)

def face1lllrlr(+code: U32) -> Glyph:
  face1lllrlr.choose(code,U32.is_lt(code,48))

def face1lllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllrll(code)
    case False{}: face1lllrlr(code)

def face1lllrl(+code: U32) -> Glyph:
  face1lllrl.choose(code,U32.is_lt(code,47))

def face1lllrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{80730112,0,0,0},Row{1072218000,0,0,0},Row{2670726385,0,0,0}},Rows8{Row{2937062225,0,0,0},Row{2138046464,0,0,0},Row{502464512,0,0,0},Row{65937408,0,0,0},Row{5231104,0,0,0},Row{392464,0,0,0},Row{1735909312,0,0,0},Row{3758096369,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lllrrll(code: U32) -> Glyph:
  face1lllrrll.choose(U32.is_eq(code,50))

def face1lllrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{115332864,0,0,0},Row{1608044416,0,0,0},Row{3205500384,0,0,0}},Rows8{Row{3204448528,0,0,0},Row{1872957440,0,0,0},Row{150970368,0,0,0},Row{2946838528,0,0,0},Row{4227858432,2,0,0},Row{4227861218,2,0,0},Row{2949169088,0,0,0},Row{417323280,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lllrrlrl(code: U32) -> Glyph:
  face1lllrrlrl.choose(U32.is_eq(code,51))

def face1lllrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1609760768,0,0,0},Row{1610350592,0,0,0},Row{1607426048,0,0,0}},Rows8{Row{1601036544,0,0,0},Row{1600452608,0,0,0},Row{1600175904,0,0,0},Row{1600139168,0,0,0},Row{2948107763,5,0,0},Row{4294967284,10,0,0},Row{1600126976,0,0,0},Row{1600126976,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lllrrlrr(code: U32) -> Glyph:
  face1lllrrlrr.choose(U32.is_eq(code,52))

def face1lllrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllrrlrl(code)
    case False{}: face1lllrrlrr(code)

def face1lllrrlr(+code: U32) -> Glyph:
  face1lllrrlr.choose(code,U32.is_lt(code,52))

def face1lllrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllrrll(code)
    case False{}: face1lllrrlr(code)

def face1lllrrl(+code: U32) -> Glyph:
  face1lllrrl.choose(code,U32.is_lt(code,51))

def face1lllrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1610612624,0,0,0},Row{662142640,0,0,0},Row{3520,0,0,0}},Rows8{Row{1182928,0,0,0},Row{150986224,0,0,0},Row{1876328129,0,0,0},Row{3206545408,0,0,0},Row{3724541952,0,0,0},Row{2939161331,0,0,0},Row{1072213952,0,0,0},Row{80668944,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lllrrrll(code: U32) -> Glyph:
  face1lllrrrll.choose(U32.is_eq(code,53))

def face1lllrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{148812544,0,0,0},Row{2411257392,0,0,0},Row{4227870640,1,0,0}},Rows8{Row{1117169,0,0,0},Row{754952691,0,0,0},Row{3483746036,0,0,0},Row{4227866356,2,0,0},Row{4177529842,3,0,0},Row{4227866320,1,0,0},Row{2412306256,0,0,0},Row{132105472,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lllrrrlr(code: U32) -> Glyph:
  face1lllrrrlr.choose(U32.is_eq(code,54))

def face1lllrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllrrrll(code)
    case False{}: face1lllrrrlr(code)

def face1lllrrrl(+code: U32) -> Glyph:
  face1lllrrrl.choose(code,U32.is_lt(code,54))

def face1lllrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2415919095,0,0,0},Row{2142730099,0,0,0},Row{533725184,0,0,0}},Rows8{Row{167051264,0,0,0},Row{50069504,0,0,0},Row{11485184,0,0,0},Row{4169728,0,0,0},Row{848384,0,0,0},Row{391424,0,0,0},Row{57104,0,0,0},Row{28544,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lllrrrrl(code: U32) -> Glyph:
  face1lllrrrrl.choose(U32.is_eq(code,55))

def face1lllrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{115332864,0,0,0},Row{1875431280,0,0,0},Row{3473940176,0,0,0}},Rows8{Row{3456110288,0,0,0},Row{1871941472,0,0,0},Row{184547840,0,0,0},Row{2677448608,0,0,0},Row{4211084275,2,0,0},Row{4227861491,3,0,0},Row{3484991424,0,0,0},Row{417323280,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lllrrrrr(code: U32) -> Glyph:
  face1lllrrrrr.choose(U32.is_eq(code,56))

def face1lllrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllrrrrl(code)
    case False{}: face1lllrrrrr(code)

def face1lllrrrr(+code: U32) -> Glyph:
  face1lllrrrr.choose(code,U32.is_lt(code,56))

def face1lllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllrrrl(code)
    case False{}: face1lllrrrr(code)

def face1lllrrr(+code: U32) -> Glyph:
  face1lllrrr.choose(code,U32.is_lt(code,55))

def face1lllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllrrl(code)
    case False{}: face1lllrrr(code)

def face1lllrr(+code: U32) -> Glyph:
  face1lllrr.choose(code,U32.is_lt(code,53))

def face1lllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lllrl(code)
    case False{}: face1lllrr(code)

def face1lllr(+code: U32) -> Glyph:
  face1lllr.choose(code,U32.is_lt(code,50))

def face1lll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llll(code)
    case False{}: face1lllr(code)

def face1lll(+code: U32) -> Glyph:
  face1lll.choose(code,U32.is_lt(code,44))

def face1llrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{97507072,0,0,0},Row{1339608976,0,0,0},Row{3474984177,0,0,0}},Rows8{Row{4227860724,1,0,0},Row{4244638451,3,0,0},Row{4288905168,3,0,0},Row{4207935024,2,0,0},Row{3942859008,0,0,0},Row{2938112721,0,0,0},Row{787005344,0,0,0},Row{62842896,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrllll(code: U32) -> Glyph:
  face1llrllll.choose(U32.is_eq(code,57))

def face1llrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[zero_rows(),Rows8{Row{256,0,0,0},Row{16304,0,0,0},Row{11920,0,0,0},zero_row(),zero_row(),Row{256,0,0,0},Row{16304,0,0,0},Row{11920,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrlllrl(code: U32) -> Glyph:
  face1llrlllrl.choose(U32.is_eq(code,58))

def face1llrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[zero_rows(),Rows8{Row{256,0,0,0},Row{24448,0,0,0},Row{20080,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),Row{12192,0,0,0}},Rows8{Row{3264,0,0,0},Row{2272,0,0,0},Row{1009,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1llrlllrr(code: U32) -> Glyph:
  face1llrlllrr.choose(U32.is_eq(code,59))

def face1llrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrlllrl(code)
    case False{}: face1llrlllrr(code)

def face1llrlllr(+code: U32) -> Glyph:
  face1llrlllr.choose(code,U32.is_lt(code,59))

def face1llrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrllll(code)
    case False{}: face1llrlllr(code)

def face1llrlll(+code: U32) -> Glyph:
  face1llrlll.choose(code,U32.is_lt(code,58))

def face1llrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{2734686208,0,0,0},Row{4021551104,0,0,0},Row{418366976,0,0,0},Row{380864,0,0,0},Row{1499056,0,0,0},Row{686797824,0,0,0},Row{4020436992,0,0,0},Row{2181038080,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrllrl(code: U32) -> Glyph:
  face1llrllrl.choose(U32.is_eq(code,60))

def face1llrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{zero_row(),Row{572662288,0,0,0},Row{4294967184,0,0,0},Row{1431655728,0,0,0},Row{572662288,0,0,0},Row{4294967184,0,0,0},Row{1431655728,0,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrllrrl(code: U32) -> Glyph:
  face1llrllrrl.choose(U32.is_eq(code,61))

def face1llrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{5728,0,0,0},Row{1568624,0,0,0},Row{703575296,0,0,0},Row{4271046656,3,0,0},Row{4020502528,3,0,0},Row{401589760,0,0,0},Row{450432,0,0,0},Row{1360,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrllrrr(code: U32) -> Glyph:
  face1llrllrrr.choose(U32.is_eq(code,62))

def face1llrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrllrrl(code)
    case False{}: face1llrllrrr(code)

def face1llrllrr(+code: U32) -> Glyph:
  face1llrllrr.choose(code,U32.is_lt(code,62))

def face1llrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrllrl(code)
    case False{}: face1llrllrr(code)

def face1llrllr(+code: U32) -> Glyph:
  face1llrllr.choose(code,U32.is_lt(code,61))

def face1llrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrlll(code)
    case False{}: face1llrllr(code)

def face1llrll(+code: U32) -> Glyph:
  face1llrll.choose(code,U32.is_lt(code,60))

def face1llrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{9370672,0,0,0},Row{150703842,0,0,0},Row{232785654,0,0,0}},Rows8{Row{233897984,0,0,0},Row{133959680,0,0,0},Row{8376320,0,0,0},Row{586752,0,0,0},Row{242688,0,0,0},Row{8192,0,0,0},Row{521984,0,0,0},Row{386560,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrlrll(code: U32) -> Glyph:
  face1llrlrll.choose(U32.is_eq(code,63))

def face1llrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4006023168,653,0,0},Row{2294276864,20202,0,0},Row{253456,191248,0,0}},Rows8{Row{302006160,712993,0,0},Row{4290906848,2064619,0,0},Row{1995114226,4145390,0,0},Row{7279860,5189864,0,0},Row{5186804,4145383,0,0},Row{8328946,2056426,0,0},Row{2850687712,776702,0,0},Row{3467718544,183971,0,0}},Rows8{Row{253472,0,0,0},Row{2294277120,969,0,0},Row{4274458624,941,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1llrlrlrl(code: U32) -> Glyph:
  face1llrlrlrl.choose(U32.is_eq(code,64))

def face1llrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{117391360,0,0,0},Row{201297920,0,0,0},Row{533585920,0,0,0}},Rows8{Row{1871311872,0,0,0},Row{3209033728,0,0,0},Row{4261608704,1,0,0},Row{4194357040,5,0,0},Row{4294967168,10,0,0},Row{4169703376,31,0,0},Row{2684358131,95,0,0},Row{1342179575,175,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrlrlrr(code: U32) -> Glyph:
  face1llrlrlrr.choose(U32.is_eq(code,65))

def face1llrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrlrlrl(code)
    case False{}: face1llrlrlrr(code)

def face1llrlrlr(+code: U32) -> Glyph:
  face1llrlrlr.choose(code,U32.is_lt(code,65))

def face1llrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrlrll(code)
    case False{}: face1llrlrlr(code)

def face1llrlrl(+code: U32) -> Glyph:
  face1llrlrl.choose(code,U32.is_lt(code,64))

def face1llrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{720371696,0,0,0},Row{3483860720,0,0,0},Row{4211084784,2,0,0}},Rows8{Row{4194307568,2,0,0},Row{3210882544,0,0,0},Row{771751920,0,0,0},Row{4000669168,2,0,0},Row{4127198704,8,0,0},Row{4127198704,8,0,0},Row{4271341296,3,0,0},Row{1560281072,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrlrrll(code: U32) -> Glyph:
  face1llrlrrll.choose(U32.is_eq(code,66))

def face1llrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2113769728,0,0,0},Row{4236967184,11,0,0},Row{2684383120,95,0,0}},Rows8{Row{805309921,89,0,0},Row{2803,0,0,0},Row{2292,0,0,0},Row{2803,0,0,0},Row{536874481,89,0,0},Row{2684383120,95,0,0},Row{4236967184,10,0,0},Row{2113769728,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrlrrlr(code: U32) -> Glyph:
  face1llrlrrlr.choose(U32.is_eq(code,67))

def face1llrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrlrrll(code)
    case False{}: face1llrlrrlr(code)

def face1llrlrrl(+code: U32) -> Glyph:
  face1llrlrrl.choose(code,U32.is_lt(code,67))

def face1llrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{702545904,0,0,0},Row{4020797168,2,0,0},Row{4093644272,11,0,0}},Rows8{Row{2952793584,47,0,0},Row{2147487216,95,0,0},Row{1610616304,111,0,0},Row{2147487216,95,0,0},Row{2952793584,47,0,0},Row{4110421488,11,0,0},Row{4020797168,2,0,0},Row{702545904,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrlrrrl(code: U32) -> Glyph:
  face1llrlrrrl.choose(U32.is_eq(code,68))

def face1llrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2952790000,0,0,0},Row{1467449072,0,0,0},Row{3568,0,0,0}},Rows8{Row{3568,0,0,0},Row{304229872,0,0,0},Row{1342177264,0,0,0},Row{357916144,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{1467449072,0,0,0},Row{2952790000,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrlrrrr(code: U32) -> Glyph:
  face1llrlrrrr.choose(U32.is_eq(code,69))

def face1llrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrlrrrl(code)
    case False{}: face1llrlrrrr(code)

def face1llrlrrr(+code: U32) -> Glyph:
  face1llrlrrr.choose(code,U32.is_lt(code,69))

def face1llrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrlrrl(code)
    case False{}: face1llrlrrr(code)

def face1llrlrr(+code: U32) -> Glyph:
  face1llrlrr.choose(code,U32.is_lt(code,68))

def face1llrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrlrl(code)
    case False{}: face1llrlrr(code)

def face1llrlr(+code: U32) -> Glyph:
  face1llrlr.choose(code,U32.is_lt(code,66))

def face1llrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrll(code)
    case False{}: face1llrlr(code)

def face1llrl(+code: U32) -> Glyph:
  face1llrl.choose(code,U32.is_lt(code,63))

def face1llrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2415919088,0,0,0},Row{1199013616,0,0,0},Row{3568,0,0,0}},Rows8{Row{3568,0,0,0},Row{35794416,0,0,0},Row{536870896,0,0,0},Row{89480688,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrrlll(code: U32) -> Glyph:
  face1llrrlll.choose(U32.is_eq(code,70))

def face1llrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1828552960,0,0,0},Row{4236967184,9,0,0},Row{3221254032,79,0,0}},Rows8{Row{1073745377,108,0,0},Row{2547,0,0,0},Row{571476212,34,0,0},Row{4284484339,191,0,0},Row{1696599537,175,0,0},Row{1879076768,127,0,0},Row{4220189968,28,0,0},Row{2382205184,1,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrrllrl(code: U32) -> Glyph:
  face1llrrllrl.choose(U32.is_eq(code,71))

def face1llrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1610616304,111,0,0},Row{1610616304,111,0,0},Row{1610616304,111,0,0}},Rows8{Row{1610616304,111,0,0},Row{1914842608,111,0,0},Row{4294967280,111,0,0},Row{2505399792,111,0,0},Row{1610616304,111,0,0},Row{1610616304,111,0,0},Row{1610616304,111,0,0},Row{1610616304,111,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrrllrr(code: U32) -> Glyph:
  face1llrrllrr.choose(U32.is_eq(code,72))

def face1llrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrrllrl(code)
    case False{}: face1llrrllrr(code)

def face1llrrllr(+code: U32) -> Glyph:
  face1llrrllr.choose(code,U32.is_lt(code,72))

def face1llrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrrlll(code)
    case False{}: face1llrrllr(code)

def face1llrrll(+code: U32) -> Glyph:
  face1llrrll.choose(code,U32.is_lt(code,71))

def face1llrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0}},Rows8{Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrrlrl(code: U32) -> Glyph:
  face1llrrlrl.choose(U32.is_eq(code,73))

def face1llrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{531628032,0,0,0},Row{531628032,0,0,0},Row{531628032,0,0,0}},Rows8{Row{531628032,0,0,0},Row{531628032,0,0,0},Row{531628032,0,0,0},Row{531628032,0,0,0},Row{531629526,0,0,0},Row{248514549,0,0,0},Row{167481057,0,0,0},Row{27126576,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrrlrrl(code: U32) -> Glyph:
  face1llrrlrrl.choose(U32.is_eq(code,74))

def face1llrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4093644272,30,0,0},Row{4263513584,3,0,0},Row{1874922992,0,0,0}},Rows8{Row{167382512,0,0,0},Row{13594096,0,0,0},Row{31452912,0,0,0},Row{167370736,0,0,0},Row{1070673648,0,0,0},Row{3745517040,0,0,0},Row{4177530352,8,0,0},Row{3774877168,63,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrrlrrr(code: U32) -> Glyph:
  face1llrrlrrr.choose(U32.is_eq(code,75))

def face1llrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrrlrrl(code)
    case False{}: face1llrrlrrr(code)

def face1llrrlrr(+code: U32) -> Glyph:
  face1llrrlrr.choose(code,U32.is_lt(code,75))

def face1llrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrrlrl(code)
    case False{}: face1llrrlrr(code)

def face1llrrlr(+code: U32) -> Glyph:
  face1llrrlr.choose(code,U32.is_lt(code,74))

def face1llrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrrll(code)
    case False{}: face1llrrlr(code)

def face1llrrl(+code: U32) -> Glyph:
  face1llrrl.choose(code,U32.is_lt(code,73))

def face1llrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0}},Rows8{Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{966369008,0,0,0},Row{1610612720,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrrrll(code: U32) -> Glyph:
  face1llrrrll.choose(U32.is_eq(code,76))

def face1llrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{61424,57329,0,0},Row{327664,57334,0,0},Row{654832,57067,0,0}},Rows8{Row{269405424,56767,0,0},Row{1615826160,56943,0,0},Row{2963225840,56879,0,0},Row{4042067184,56844,0,0},Row{4143451376,56838,0,0},Row{4260564208,56833,0,0},Row{3218083056,56832,0,0},Row{1869614320,56832,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrrrlrl(code: U32) -> Glyph:
  face1llrrrlrl.choose(U32.is_eq(code,77))

def face1llrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1073770480,159,0,0},Row{1073868784,159,0,0},Row{1074331376,159,0,0}},Rows8{Row{1076874480,159,0,0},Row{1085230576,159,0,0},Row{1157303792,159,0,0},Row{1290931696,159,0,0},Row{2407534064,159,0,0},Row{3977252336,159,0,0},Row{4110421488,159,0,0},Row{2952793584,159,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrrrlrr(code: U32) -> Glyph:
  face1llrrrlrr.choose(U32.is_eq(code,78))

def face1llrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrrrlrl(code)
    case False{}: face1llrrrlrr(code)

def face1llrrrlr(+code: U32) -> Glyph:
  face1llrrrlr.choose(code,U32.is_lt(code,78))

def face1llrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrrrll(code)
    case False{}: face1llrrrlr(code)

def face1llrrrl(+code: U32) -> Glyph:
  face1llrrrl.choose(code,U32.is_lt(code,77))

def face1llrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2113765632,0,0,0},Row{4236967184,10,0,0},Row{2684383120,111,0,0}},Rows8{Row{536874465,207,0,0},Row{2803,238,0,0},Row{2292,508,0,0},Row{2803,238,0,0},Row{536874481,207,0,0},Row{2684383120,111,0,0},Row{4236967184,10,0,0},Row{2113769728,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrrrrll(code: U32) -> Glyph:
  face1llrrrrll.choose(U32.is_eq(code,79))

def face1llrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{435159024,0,0,0},Row{3484974832,0,0,0},Row{4211084784,4,0,0}},Rows8{Row{4143975920,6,0,0},Row{4177530352,5,0,0},Row{4016254448,1,0,0},Row{1325400048,0,0,0},Row{21323248,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrrrrlr(code: U32) -> Glyph:
  face1llrrrrlr.choose(U32.is_eq(code,80))

def face1llrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrrrrll(code)
    case False{}: face1llrrrrlr(code)

def face1llrrrrl(+code: U32) -> Glyph:
  face1llrrrrl.choose(code,U32.is_lt(code,80))

def face1llrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2113765632,0,0,0},Row{4273863952,10,0,0},Row{2969603984,111,0,0}},Rows8{Row{805309921,191,0,0},Row{2803,238,0,0},Row{2292,508,0,0},Row{2803,254,0,0},Row{663752177,207,0,0},Row{3746598800,111,0,0},Row{4290641168,11,0,0},Row{3724382464,29,0,0}},Rows8{Row{268435456,71,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1llrrrrrl(code: U32) -> Glyph:
  face1llrrrrrl.choose(U32.is_eq(code,81))

def face1llrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{451936240,0,0,0},Row{3484974832,0,0,0},Row{4211084784,3,0,0}},Rows8{Row{4143975920,6,0,0},Row{4177530352,5,0,0},Row{4267912688,1,0,0},Row{1593835504,0,0,0},Row{234249712,0,0,0},Row{1871711728,0,0,0},Row{3995078128,1,0,0},Row{4160753136,8,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1llrrrrrr(code: U32) -> Glyph:
  face1llrrrrrr.choose(U32.is_eq(code,82))

def face1llrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrrrrrl(code)
    case False{}: face1llrrrrrr(code)

def face1llrrrrr(+code: U32) -> Glyph:
  face1llrrrrr.choose(code,U32.is_lt(code,82))

def face1llrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrrrrl(code)
    case False{}: face1llrrrrr(code)

def face1llrrrr(+code: U32) -> Glyph:
  face1llrrrr.choose(code,U32.is_lt(code,81))

def face1llrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrrrl(code)
    case False{}: face1llrrrr(code)

def face1llrrr(+code: U32) -> Glyph:
  face1llrrr.choose(code,U32.is_lt(code,79))

def face1llrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrrl(code)
    case False{}: face1llrrr(code)

def face1llrr(+code: U32) -> Glyph:
  face1llrr.choose(code,U32.is_lt(code,76))

def face1llr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1llrl(code)
    case False{}: face1llrr(code)

def face1llr(+code: U32) -> Glyph:
  face1llr.choose(code,U32.is_lt(code,70))

def face1ll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lll(code)
    case False{}: face1llr(code)

def face1ll(+code: U32) -> Glyph:
  face1ll.choose(code,U32.is_lt(code,57))

def face1lrlllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{435148288,0,0,0},Row{3483946880,0,0,0},Row{4177530336,3,0,0}},Rows8{Row{7920,0,0,0},Row{5894064,0,0,0},Row{1593834000,0,0,0},Row{4290056192,2,0,0},Row{4160749873,6,0,0},Row{4160752371,5,0,0},Row{3752378288,1,0,0},Row{720361488,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrlllll(code: U32) -> Glyph:
  face1lrlllll.choose(U32.is_eq(code,83))

def face1lrllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4294967287,10,0,0},Row{2009044851,5,0,0},Row{9388032,0,0,0}},Rows8{Row{9388032,0,0,0},Row{9388032,0,0,0},Row{9388032,0,0,0},Row{9388032,0,0,0},Row{9388032,0,0,0},Row{9388032,0,0,0},Row{9388032,0,0,0},Row{9388032,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrllllrl(code: U32) -> Glyph:
  face1lrllllrl.choose(U32.is_eq(code,84))

def face1lrllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2147487216,79,0,0}},Rows8{Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2415922912,63,0,0},Row{3774894000,30,0,0},Row{4253679408,7,0,0},Row{1559143168,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrllllrr(code: U32) -> Glyph:
  face1lrllllrr.choose(U32.is_eq(code,85))

def face1lrllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrllllrl(code)
    case False{}: face1lrllllrr(code)

def face1lrllllr(+code: U32) -> Glyph:
  face1lrllllr.choose(code,U32.is_lt(code,85))

def face1lrllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlllll(code)
    case False{}: face1lrllllr(code)

def face1lrllll(+code: U32) -> Glyph:
  face1lrllll.choose(code,U32.is_lt(code,84))

def face1lrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1073743863,175,0,0},Row{2415922418,95,0,0},Row{3758108624,31,0,0}},Rows8{Row{4076896128,11,0,0},Row{4160798512,6,0,0},Row{4227988736,1,0,0},Row{3206936576,0,0,0},Row{1869280000,0,0,0},Row{530436096,0,0,0},Row{200245248,0,0,0},Row{134164480,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrlllrl(code: U32) -> Glyph:
  face1lrlllrl.choose(U32.is_eq(code,86))

def face1lrlllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4261414648,13574147,0,0},Row{4281338612,9396231,0,0},Row{4016049649,6262794,0,0}},Rows8{Row{3198164928,2080782,0,0},Row{2362466176,848175,0,0},Row{1223855936,586863,0,0},Row{351649552,391071,0,0},Row{33090560,129740,0,0},Row{13432832,52728,0,0},Row{9434112,36852,0,0},Row{6287616,24561,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrlllrrl(code: U32) -> Glyph:
  face1lrlllrrl.choose(U32.is_eq(code,87))

def face1lrlllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3506450145,47,0,0},Row{4160794464,8,0,0},Row{3743742976,1,0,0}},Rows8{Row{1336668928,0,0,0},Row{184520704,0,0,0},Row{83828736,0,0,0},Row{218079232,0,0,0},Row{2140861696,0,0,0},Row{3994218000,2,0,0},Row{4127227808,11,0,0},Row{2952793333,111,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrlllrrr(code: U32) -> Glyph:
  face1lrlllrrr.choose(U32.is_eq(code,88))

def face1lrlllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlllrrl(code)
    case False{}: face1lrlllrrr(code)

def face1lrlllrr(+code: U32) -> Glyph:
  face1lrlllrr.choose(code,U32.is_lt(code,88))

def face1lrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlllrl(code)
    case False{}: face1lrlllrr(code)

def face1lrlllr(+code: U32) -> Glyph:
  face1lrlllr.choose(code,U32.is_lt(code,87))

def face1lrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrllll(code)
    case False{}: face1lrlllr(code)

def face1lrlll(+code: U32) -> Glyph:
  face1lrlll.choose(code,U32.is_lt(code,86))

def face1lrllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2952793078,95,0,0},Row{4076883904,12,0,0},Row{4211134272,4,0,0}},Rows8{Row{3208968960,0,0,0},Row{1068233472,0,0,0},Row{184520704,0,0,0},Row{50274304,0,0,0},Row{15532032,0,0,0},Row{15532032,0,0,0},Row{15532032,0,0,0},Row{15532032,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrllrll(code: U32) -> Glyph:
  face1lrllrll.choose(U32.is_eq(code,89))

def face1lrllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4294967283,5,0,0},Row{4018632561,2,0,0},Row{2139095040,0,0,0}},Rows8{Row{217251840,0,0,0},Row{66846720,0,0,0},Row{10448896,0,0,0},Row{2023936,0,0,0},Row{391680,0,0,0},Row{44864,0,0,0},Row{2004324305,2,0,0},Row{4294967283,5,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrllrlrl(code: U32) -> Glyph:
  face1lrllrlrl.choose(U32.is_eq(code,90))

def face1lrllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{74272,0,0,0},Row{524192,0,0,0},Row{159648,0,0,0},Row{8096,0,0,0}},Rows8{Row{8096,0,0,0},Row{8096,0,0,0},Row{8096,0,0,0},Row{8096,0,0,0},Row{8096,0,0,0},Row{8096,0,0,0},Row{8096,0,0,0},Row{8096,0,0,0}},Rows8{Row{81824,0,0,0},Row{524192,0,0,0},Row{152880,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lrllrlrr(code: U32) -> Glyph:
  face1lrllrlrr.choose(U32.is_eq(code,91))

def face1lrllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrllrlrl(code)
    case False{}: face1lrllrlrr(code)

def face1lrllrlr(+code: U32) -> Glyph:
  face1lrllrlr.choose(code,U32.is_lt(code,91))

def face1lrllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrllrll(code)
    case False{}: face1lrllrlr(code)

def face1lrllrl(+code: U32) -> Glyph:
  face1lrllrl.choose(code,U32.is_lt(code,90))

def face1lrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{101,0,0,0},Row{504,0,0,0},Row{1524,0,0,0}},Rows8{Row{2528,0,0,0},Row{3504,0,0,0},Row{12144,0,0,0},Row{28464,0,0,0},Row{40448,0,0,0},Row{55808,0,0,0},Row{194048,0,0,0},Row{455168,0,0,0}},Rows8{Row{708608,0,0,0},Row{954368,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lrllrrl(code: U32) -> Glyph:
  face1lrllrrl.choose(U32.is_eq(code,92))

def face1lrllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{8737,0,0,0},Row{57332,0,0,0},Row{56657,0,0,0},Row{56320,0,0,0}},Rows8{Row{56320,0,0,0},Row{56320,0,0,0},Row{56320,0,0,0},Row{56320,0,0,0},Row{56320,0,0,0},Row{56320,0,0,0},Row{56320,0,0,0},Row{56320,0,0,0}},Rows8{Row{56609,0,0,0},Row{57332,0,0,0},Row{17745,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lrllrrrl(code: U32) -> Glyph:
  face1lrllrrrl.choose(U32.is_eq(code,93))

def face1lrllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{164864,0,0,0},Row{654592,0,0,0},Row{3108688,0,0,0}},Rows8{Row{9243072,0,0,0},Row{31917044,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrllrrrr(code: U32) -> Glyph:
  face1lrllrrrr.choose(U32.is_eq(code,94))

def face1lrllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrllrrrl(code)
    case False{}: face1lrllrrrr(code)

def face1lrllrrr(+code: U32) -> Glyph:
  face1lrllrrr.choose(code,U32.is_lt(code,94))

def face1lrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrllrrl(code)
    case False{}: face1lrllrrr(code)

def face1lrllrr(+code: U32) -> Glyph:
  face1lrllrr.choose(code,U32.is_lt(code,93))

def face1lrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrllrl(code)
    case False{}: face1lrllrr(code)

def face1lrllr(+code: U32) -> Glyph:
  face1lrllr.choose(code,U32.is_lt(code,92))

def face1lrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlll(code)
    case False{}: face1lrllr(code)

def face1lrll(+code: U32) -> Glyph:
  face1lrll.choose(code,U32.is_lt(code,89))

def face1lrlrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{19014178,0,0,0}},Rows8{Row{150994943,0,0,0},Row{55924053,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lrlrlll(code: U32) -> Glyph:
  face1lrlrlll.choose(U32.is_eq(code,95))

def face1lrlrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{544,0,0,0},Row{12160,0,0,0},Row{36096,0,0,0},zero_row()},zero_rows(),zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrlrllrl(code: U32) -> Glyph:
  face1lrlrllrl.choose(U32.is_eq(code,96))

def face1lrlrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{45017632,0,0,0},Row{217685713,0,0,0},Row{531628865,0,0,0},Row{536581648,0,0,0},Row{532061922,0,0,0},Row{532678135,0,0,0},Row{535530997,0,0,0},Row{530116224,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrlrllrr(code: U32) -> Glyph:
  face1lrlrllrr.choose(U32.is_eq(code,97))

def face1lrlrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlrllrl(code)
    case False{}: face1lrlrllrr(code)

def face1lrlrllr(+code: U32) -> Glyph:
  face1lrlrllr.choose(code,U32.is_lt(code,97))

def face1lrlrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlrlll(code)
    case False{}: face1lrlrllr(code)

def face1lrlrll(+code: U32) -> Glyph:
  face1lrlrll.choose(code,U32.is_lt(code,96))

def face1lrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0}},Rows8{Row{149781489,0,0,0},Row{2413350641,0,0,0},Row{3994033905,0,0,0},Row{4211084273,1,0,0},Row{4211084273,1,0,0},Row{3994033905,0,0,0},Row{2413350641,0,0,0},Row{149846769,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrlrlrl(code: U32) -> Glyph:
  face1lrlrlrl.choose(U32.is_eq(code,98))

def face1lrlrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{80668672,0,0,0},Row{803782560,0,0,0},Row{1244662770,0,0,0},Row{2037,0,0,0},Row{2037,0,0,0},Row{1261440242,0,0,0},Row{787005344,0,0,0},Row{80668688,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrlrlrrl(code: U32) -> Glyph:
  face1lrlrlrrl.choose(U32.is_eq(code,99))

def face1lrlrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3472883712,0,0,0},Row{3472883712,0,0,0},Row{3472883712,0,0,0}},Rows8{Row{3477989904,0,0,0},Row{3487088576,0,0,0},Row{3477081075,0,0,0},Row{3472885749,0,0,0},Row{3472885749,0,0,0},Row{3477081075,0,0,0},Row{3487088576,0,0,0},Row{3461212688,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrlrlrrr(code: U32) -> Glyph:
  face1lrlrlrrr.choose(U32.is_eq(code,100))

def face1lrlrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlrlrrl(code)
    case False{}: face1lrlrlrrr(code)

def face1lrlrlrr(+code: U32) -> Glyph:
  face1lrlrlrr.choose(code,U32.is_lt(code,100))

def face1lrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlrlrl(code)
    case False{}: face1lrlrlrr(code)

def face1lrlrlr(+code: U32) -> Glyph:
  face1lrlrlr.choose(code,U32.is_lt(code,99))

def face1lrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlrll(code)
    case False{}: face1lrlrlr(code)

def face1lrlrl(+code: U32) -> Glyph:
  face1lrlrl.choose(code,U32.is_lt(code,98))

def face1lrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{62842880,0,0,0},Row{785948576,0,0,0},Row{2404526578,0,0,0},Row{2952790005,0,0,0},Row{894786037,0,0,0},Row{639634162,0,0,0},Row{1339604896,0,0,0},Row{97511440,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrlrrll(code: U32) -> Glyph:
  face1lrlrrll.choose(U32.is_eq(code,101))

def face1lrlrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3074048,0,0,0},Row{577360,0,0,0},Row{24432,0,0,0}},Rows8{Row{1048573,0,0,0},Row{503734,0,0,0},Row{24432,0,0,0},Row{24432,0,0,0},Row{24432,0,0,0},Row{24432,0,0,0},Row{24432,0,0,0},Row{24432,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrlrrlrl(code: U32) -> Glyph:
  face1lrlrrlrl.choose(U32.is_eq(code,102))

def face1lrlrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{3461212688,0,0,0},Row{3487088560,0,0,0},Row{3477081330,0,0,0},Row{3472885749,0,0,0},Row{3472885749,0,0,0},Row{3477081075,0,0,0},Row{3487088576,0,0,0},Row{3461212960,0,0,0}},Rows8{Row{3205497360,0,0,0},Row{1875418832,0,0,0},Row{115337760,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lrlrrlrr(code: U32) -> Glyph:
  face1lrlrrlrr.choose(U32.is_eq(code,103))

def face1lrlrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlrrlrl(code)
    case False{}: face1lrlrrlrr(code)

def face1lrlrrlr(+code: U32) -> Glyph:
  face1lrlrrlr.choose(code,U32.is_lt(code,103))

def face1lrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlrrll(code)
    case False{}: face1lrlrrlr(code)

def face1lrlrrl(+code: U32) -> Glyph:
  face1lrlrrl.choose(code,U32.is_lt(code,102))

def face1lrlrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2801,0,0,0},Row{2801,0,0,0},Row{2801,0,0,0}},Rows8{Row{133069553,0,0,0},Row{1609088753,0,0,0},Row{2404388337,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrlrrrll(code: U32) -> Glyph:
  face1lrlrrrll.choose(U32.is_eq(code,104))

def face1lrlrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{16,0,0,0},Row{3057,0,0,0},Row{560,0,0,0},zero_row()},Rows8{Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrlrrrlr(code: U32) -> Glyph:
  face1lrlrrrlr.choose(U32.is_eq(code,105))

def face1lrlrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlrrrll(code)
    case False{}: face1lrlrrrlr(code)

def face1lrlrrrl(+code: U32) -> Glyph:
  face1lrlrrrl.choose(code,U32.is_lt(code,105))

def face1lrlrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{256,0,0,0},Row{48928,0,0,0},Row{8960,0,0,0},zero_row()},Rows8{Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0}},Rows8{Row{44832,0,0,0},Row{36770,0,0,0},Row{6884,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lrlrrrrl(code: U32) -> Glyph:
  face1lrlrrrrl.choose(U32.is_eq(code,106))

def face1lrlrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0}},Rows8{Row{1337986033,0,0,0},Row{117050353,0,0,0},Row{10456049,0,0,0},Row{982769,0,0,0},Row{7331825,0,0,0},Row{49159409,0,0,0},Row{217385969,0,0,0},Row{2408582129,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrlrrrrr(code: U32) -> Glyph:
  face1lrlrrrrr.choose(U32.is_eq(code,107))

def face1lrlrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlrrrrl(code)
    case False{}: face1lrlrrrrr(code)

def face1lrlrrrr(+code: U32) -> Glyph:
  face1lrlrrrr.choose(code,U32.is_lt(code,107))

def face1lrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlrrrl(code)
    case False{}: face1lrlrrrr(code)

def face1lrlrrr(+code: U32) -> Glyph:
  face1lrlrrr.choose(code,U32.is_lt(code,106))

def face1lrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlrrl(code)
    case False{}: face1lrlrrr(code)

def face1lrlrr(+code: U32) -> Glyph:
  face1lrlrr.choose(code,U32.is_lt(code,104))

def face1lrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrlrl(code)
    case False{}: face1lrlrr(code)

def face1lrlr(+code: U32) -> Glyph:
  face1lrlr.choose(code,U32.is_lt(code,101))

def face1lrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrll(code)
    case False{}: face1lrlr(code)

def face1lrl(+code: U32) -> Glyph:
  face1lrl.choose(code,U32.is_lt(code,95))

def face1lrrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0}},Rows8{Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrllll(code: U32) -> Glyph:
  face1lrrllll.choose(U32.is_eq(code,108))

def face1lrrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{1407093233,2541,0,0},Row{3707354609,28616,0,0},Row{1335889393,40752,0,0},Row{1065356273,44832,0,0},Row{1065356273,44832,0,0},Row{1065356273,44832,0,0},Row{1065356273,44832,0,0},Row{1065356273,44832,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrlllrl(code: U32) -> Glyph:
  face1lrrlllrl.choose(U32.is_eq(code,109))

def face1lrrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{133069297,0,0,0},Row{1609088497,0,0,0},Row{2404388337,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrlllrr(code: U32) -> Glyph:
  face1lrrlllrr.choose(U32.is_eq(code,110))

def face1lrrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrlllrl(code)
    case False{}: face1lrrlllrr(code)

def face1lrrlllr(+code: U32) -> Glyph:
  face1lrrlllr.choose(code,U32.is_lt(code,110))

def face1lrrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrllll(code)
    case False{}: face1lrrlllr(code)

def face1lrrlll(+code: U32) -> Glyph:
  face1lrrlll.choose(code,U32.is_lt(code,109))

def face1lrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{80668672,0,0,0},Row{1072218016,0,0,0},Row{2940210418,0,0,0},Row{3724544245,0,0,0},Row{3724543989,0,0,0},Row{2940210418,0,0,0},Row{1072218016,0,0,0},Row{80668688,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrllrl(code: U32) -> Glyph:
  face1lrrllrl.choose(U32.is_eq(code,111))

def face1lrrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{149781233,0,0,0},Row{2413350641,0,0,0},Row{3994033905,0,0,0},Row{4211084273,1,0,0},Row{4211084273,1,0,0},Row{3994033905,0,0,0},Row{2413350641,0,0,0},Row{149847025,0,0,0}},Rows8{Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lrrllrrl(code: U32) -> Glyph:
  face1lrrllrrl.choose(U32.is_eq(code,112))

def face1lrrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{3461212688,0,0,0},Row{3487088576,0,0,0},Row{3477081075,0,0,0},Row{3472885749,0,0,0},Row{3472885749,0,0,0},Row{3477081075,0,0,0},Row{3487088576,0,0,0},Row{3477989904,0,0,0}},Rows8{Row{3472883712,0,0,0},Row{3472883712,0,0,0},Row{3472883712,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lrrllrrr(code: U32) -> Glyph:
  face1lrrllrrr.choose(U32.is_eq(code,113))

def face1lrrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrllrrl(code)
    case False{}: face1lrrllrrr(code)

def face1lrrllrr(+code: U32) -> Glyph:
  face1lrrllrr.choose(code,U32.is_lt(code,113))

def face1lrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrllrl(code)
    case False{}: face1lrrllrr(code)

def face1lrrllr(+code: U32) -> Glyph:
  face1lrrllr.choose(code,U32.is_lt(code,112))

def face1lrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrlll(code)
    case False{}: face1lrrllr(code)

def face1lrrll(+code: U32) -> Glyph:
  face1lrrll.choose(code,U32.is_lt(code,111))

def face1lrrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[zero_rows(),Rows8{Row{5217009,0,0,0},Row{3722993,0,0,0},Row{3569,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrlrll(code: U32) -> Glyph:
  face1lrrlrll.choose(U32.is_eq(code,114))

def face1lrrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{27192112,0,0,0},Row{184131297,0,0,0},Row{72354802,0,0,0},Row{4837296,0,0,0},Row{184325376,0,0,0},Row{532677474,0,0,0},Row{234458866,0,0,0},Row{45018176,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrlrlrl(code: U32) -> Glyph:
  face1lrrlrlrl.choose(U32.is_eq(code,115))

def face1lrrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4032,0,0,0},Row{4032,0,0,0}},Rows8{Row{524285,0,0,0},Row{229334,0,0,0},Row{4032,0,0,0},Row{4032,0,0,0},Row{4032,0,0,0},Row{4032,0,0,0},Row{303008,0,0,0},Row{588832,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrlrlrr(code: U32) -> Glyph:
  face1lrrlrlrr.choose(U32.is_eq(code,116))

def face1lrrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrlrlrl(code)
    case False{}: face1lrrlrlrr(code)

def face1lrrlrlr(+code: U32) -> Glyph:
  face1lrrlrlr.choose(code,U32.is_lt(code,116))

def face1lrrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrlrll(code)
    case False{}: face1lrrlrlr(code)

def face1lrrlrl(+code: U32) -> Glyph:
  face1lrrlrl.choose(code,U32.is_lt(code,115))

def face1lrrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2673872368,0,0,0},Row{2681847728,0,0,0},Row{2672618272,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrlrrll(code: U32) -> Glyph:
  face1lrrlrrll.choose(U32.is_eq(code,117))

def face1lrrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{3473933816,0,0,0},Row{1868565235,0,0,0},Row{531631824,0,0,0},Row{200363888,0,0,0},Row{99983136,0,0,0},Row{32168960,0,0,0},Row{10417664,0,0,0},Row{5239040,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrlrrlr(code: U32) -> Glyph:
  face1lrrlrrlr.choose(U32.is_eq(code,118))

def face1lrrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrlrrll(code)
    case False{}: face1lrrlrrlr(code)

def face1lrrlrrl(+code: U32) -> Glyph:
  face1lrrlrrl.choose(code,U32.is_lt(code,118))

def face1lrrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[zero_rows(),Rows8{Row{233899256,24448,0,0},Row{536152308,8128,0,0},Row{1608060128,3057,0,0},Row{2375815088,2036,0,0},Row{3378466656,759,0,0},Row{4112494368,219,0,0},Row{4044160256,159,0,0},Row{3221813504,95,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrlrrrl(code: U32) -> Glyph:
  face1lrrlrrrl.choose(U32.is_eq(code,119))

def face1lrrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{1068502003,0,0,0},Row{167006096,0,0,0},Row{32296464,0,0,0},Row{7337472,0,0,0},Row{7337728,0,0,0},Row{48999968,0,0,0},Row{183709616,0,0,0},Row{1603274997,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrlrrrr(code: U32) -> Glyph:
  face1lrrlrrrr.choose(U32.is_eq(code,120))

def face1lrrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrlrrrl(code)
    case False{}: face1lrrlrrrr(code)

def face1lrrlrrr(+code: U32) -> Glyph:
  face1lrrlrrr.choose(code,U32.is_lt(code,120))

def face1lrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrlrrl(code)
    case False{}: face1lrrlrrr(code)

def face1lrrlrr(+code: U32) -> Glyph:
  face1lrrlrr.choose(code,U32.is_lt(code,119))

def face1lrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrlrl(code)
    case False{}: face1lrrlrr(code)

def face1lrrlr(+code: U32) -> Glyph:
  face1lrrlr.choose(code,U32.is_lt(code,117))

def face1lrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrll(code)
    case False{}: face1lrrlr(code)

def face1lrrl(+code: U32) -> Glyph:
  face1lrrl.choose(code,U32.is_lt(code,114))

def face1lrrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{3473933816,0,0,0},Row{1868565235,0,0,0},Row{531631824,0,0,0},Row{183586672,0,0,0},Row{100048672,0,0,0},Row{15391488,0,0,0},Row{10417664,0,0,0},Row{4190464,0,0,0}},Rows8{Row{909312,0,0,0},Row{522864,0,0,0},Row{40672,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lrrrlll(code: U32) -> Glyph:
  face1lrrrlll.choose(U32.is_eq(code,121))

def face1lrrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{251658225,0,0,0},Row{200963952,0,0,0},Row{49090560,0,0,0},Row{6266880,0,0,0},Row{652800,0,0,0},Row{122672,0,0,0},Row{393719761,0,0,0},Row{536870899,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrrllrl(code: U32) -> Glyph:
  face1lrrrllrl.choose(U32.is_eq(code,122))

def face1lrrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{10321920,0,0,0},Row{6091776,0,0,0},Row{259840,0,0,0}},Rows8{Row{194560,0,0,0},Row{194560,0,0,0},Row{60720,0,0,0},Row{15856,0,0,0},Row{52832,0,0,0},Row{194816,0,0,0},Row{194560,0,0,0},Row{194560,0,0,0}},Rows8{Row{2749952,0,0,0},Row{10469632,0,0,0},Row{3342336,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lrrrllrr(code: U32) -> Glyph:
  face1lrrrllrr.choose(U32.is_eq(code,123))

def face1lrrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrrllrl(code)
    case False{}: face1lrrrllrr(code)

def face1lrrrllr(+code: U32) -> Glyph:
  face1lrrrllr.choose(code,U32.is_lt(code,123))

def face1lrrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrrlll(code)
    case False{}: face1lrrrllr(code)

def face1lrrrll(+code: U32) -> Glyph:
  face1lrrrll.choose(code,U32.is_lt(code,122))

def face1lrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),Row{14368,0,0,0},Row{24400,0,0,0},Row{24400,0,0,0},Row{24400,0,0,0},Row{24400,0,0,0},Row{24400,0,0,0},Row{24400,0,0,0}},Rows8{Row{24400,0,0,0},Row{24400,0,0,0},Row{24400,0,0,0},Row{24400,0,0,0},Row{24400,0,0,0},Row{24400,0,0,0},Row{24400,0,0,0},Row{24400,0,0,0}},Rows8{Row{24400,0,0,0},Row{24400,0,0,0},Row{24400,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lrrrlrl(code: U32) -> Glyph:
  face1lrrrlrl.choose(U32.is_eq(code,124))

def face1lrrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{11236,0,0,0},Row{44962,0,0,0},Row{56576,0,0,0}},Rows8{Row{56064,0,0,0},Row{60160,0,0,0},Row{1505280,0,0,0},Row{7315456,0,0,0},Row{2750208,0,0,0},Row{60160,0,0,0},Row{56064,0,0,0},Row{56320,0,0,0}},Rows8{Row{48977,0,0,0},Row{20212,0,0,0},Row{321,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lrrrlrrl(code: U32) -> Glyph:
  face1lrrrlrrl.choose(U32.is_eq(code,125))

def face1lrrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{zero_row(),zero_row(),Row{3255364656,3,0,0},Row{4241469104,2,0,0},Row{2126710688,0,0,0},zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrrlrrr(code: U32) -> Glyph:
  face1lrrrlrrr.choose(U32.is_eq(code,126))

def face1lrrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrrlrrl(code)
    case False{}: face1lrrrlrrr(code)

def face1lrrrlrr(+code: U32) -> Glyph:
  face1lrrrlrr.choose(code,U32.is_lt(code,126))

def face1lrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrrlrl(code)
    case False{}: face1lrrrlrr(code)

def face1lrrrlr(+code: U32) -> Glyph:
  face1lrrrlr.choose(code,U32.is_lt(code,125))

def face1lrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrrll(code)
    case False{}: face1lrrrlr(code)

def face1lrrrl(+code: U32) -> Glyph:
  face1lrrrl.choose(code,U32.is_lt(code,124))

def face1lrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[zero_rows(),zero_rows(),zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrrrll(code: U32) -> Glyph:
  face1lrrrrll.choose(U32.is_eq(code,160))

def face1lrrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[zero_rows(),Rows8{Row{11920,0,0,0},Row{16304,0,0,0},Row{256,0,0,0},Row{8080,0,0,0},Row{12176,0,0,0},Row{12176,0,0,0},Row{12192,0,0,0},Row{16288,0,0,0}},Rows8{Row{16288,0,0,0},Row{16304,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lrrrrlrl(code: U32) -> Glyph:
  face1lrrrrlrl.choose(U32.is_eq(code,161))

def face1lrrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{602112,0,0,0},Row{7181056,0,0,0},Row{486539088,0,0,0}},Rows8{Row{1871273697,0,0,0},Row{35207668,0,0,0},Row{604150,0,0,0},Row{17381621,0,0,0},Row{1870220785,0,0,0},Row{503246704,0,0,0},Row{26129664,0,0,0},Row{602112,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrrrlrr(code: U32) -> Glyph:
  face1lrrrrlrr.choose(U32.is_eq(code,162))

def face1lrrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrrrlrl(code)
    case False{}: face1lrrrrlrr(code)

def face1lrrrrlr(+code: U32) -> Glyph:
  face1lrrrrlr.choose(code,U32.is_lt(code,162))

def face1lrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrrrll(code)
    case False{}: face1lrrrrlr(code)

def face1lrrrrl(+code: U32) -> Glyph:
  face1lrrrrl.choose(code,U32.is_lt(code,161))

def face1lrrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{149856768,0,0,0},Row{2679831808,0,0,0},Row{3674246976,0,0,0}},Rows8{Row{28496,0,0,0},Row{19038049,0,0,0},Row{83886069,0,0,0},Row{22388594,0,0,0},Row{32560,0,0,0},Row{1929408320,1,0,0},Row{4254703315,1,0,0},Row{2399141877,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrrrrll(code: U32) -> Glyph:
  face1lrrrrrll.choose(U32.is_eq(code,163))

def face1lrrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2162704,1,0,0},Row{1577031888,93,0,0}},Rows8{Row{4201111408,29,0,0},Row{2147491168,13,0,0},Row{268437424,62,0,0},Row{1488,93,0,0},Row{268437680,63,0,0},Row{2684366432,13,0,0},Row{4236898224,79,0,0},Row{738030736,58,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrrrrlr(code: U32) -> Glyph:
  face1lrrrrrlr.choose(U32.is_eq(code,164))

def face1lrrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrrrrll(code)
    case False{}: face1lrrrrrlr(code)

def face1lrrrrrl(+code: U32) -> Glyph:
  face1lrrrrrl.choose(code,U32.is_lt(code,164))

def face1lrrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2136999161,0,0,0},Row{801114867,0,0,0},Row{183639744,0,0,0}},Rows8{Row{83390304,0,0,0},Row{14532112,0,0,0},Row{44038688,0,0,0},Row{251658227,0,0,0},Row{125761393,0,0,0},Row{251658227,0,0,0},Row{90043729,0,0,0},Row{847872,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1lrrrrrrl(code: U32) -> Glyph:
  face1lrrrrrrl.choose(U32.is_eq(code,165))

def face1lrrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3984,0,0,0},Row{3984,0,0,0},Row{3984,0,0,0}},Rows8{Row{3984,0,0,0},Row{3984,0,0,0},zero_row(),zero_row(),zero_row(),Row{3984,0,0,0},Row{3984,0,0,0},Row{3984,0,0,0}},Rows8{Row{3984,0,0,0},Row{3984,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1lrrrrrrr(code: U32) -> Glyph:
  face1lrrrrrrr.choose(U32.is_eq(code,166))

def face1lrrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrrrrrl(code)
    case False{}: face1lrrrrrrr(code)

def face1lrrrrrr(+code: U32) -> Glyph:
  face1lrrrrrr.choose(code,U32.is_lt(code,166))

def face1lrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrrrrl(code)
    case False{}: face1lrrrrrr(code)

def face1lrrrrr(+code: U32) -> Glyph:
  face1lrrrrr.choose(code,U32.is_lt(code,165))

def face1lrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrrrl(code)
    case False{}: face1lrrrrr(code)

def face1lrrrr(+code: U32) -> Glyph:
  face1lrrrr.choose(code,U32.is_lt(code,163))

def face1lrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrrl(code)
    case False{}: face1lrrrr(code)

def face1lrrr(+code: U32) -> Glyph:
  face1lrrr.choose(code,U32.is_lt(code,160))

def face1lrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrrl(code)
    case False{}: face1lrrr(code)

def face1lrr(+code: U32) -> Glyph:
  face1lrr.choose(code,U32.is_lt(code,121))

def face1lr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1lrl(code)
    case False{}: face1lrr(code)

def face1lr(+code: U32) -> Glyph:
  face1lr.choose(code,U32.is_lt(code,108))

def face1l.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1ll(code)
    case False{}: face1lr(code)

def face1l(+code: U32) -> Glyph:
  face1l.choose(code,U32.is_lt(code,83))

def face1rllllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{10414608,0,0,0},Row{133799824,0,0,0},Row{74452400,0,0,0}},Rows8{Row{175968,0,0,0},Row{45083744,0,0,0},Row{501613555,0,0,0},Row{1061161202,0,0,0},Row{194502240,0,0,0},Row{65962240,0,0,0},Row{182518288,0,0,0},Row{183844304,0,0,0}},Rows8{Row{66059840,0,0,0},Row{1327360,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rllllll(code: U32) -> Glyph:
  face1rllllll.choose(U32.is_eq(code,167))

def face1rlllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{1048832,0,0,0},Row{166899472,0,0,0},Row{19927808,0,0,0},zero_row()},zero_rows(),zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlllllrl(code: U32) -> Glyph:
  face1rlllllrl.choose(U32.is_eq(code,168))

def face1rlllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{303038464,0,0,0},Row{4294721536,42,0,0},Row{2273179136,1006,0,0}},Rows8{Row{3756375840,7636,0,0},Row{3334352528,28493,0,0},Row{538925760,40471,0,0},Row{269380288,40196,0,0},Row{3013553808,28461,0,0},Row{4025917232,7860,0,0},Row{2003564544,1533,0,0},Row{4294860800,77,0,0}},Rows8{Row{892338176,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rlllllrr(code: U32) -> Glyph:
  face1rlllllrr.choose(U32.is_eq(code,169))

def face1rlllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlllllrl(code)
    case False{}: face1rlllllrr(code)

def face1rlllllr(+code: U32) -> Glyph:
  face1rlllllr.choose(code,U32.is_lt(code,169))

def face1rlllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllllll(code)
    case False{}: face1rlllllr(code)

def face1rlllll(+code: U32) -> Glyph:
  face1rlllll.choose(code,U32.is_lt(code,168))

def face1rllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1830528,0,0,0},Row{10302899,0,0,0},Row{12490544,0,0,0}},Rows8{Row{12343541,0,0,0},Row{12469224,0,0,0},Row{12304322,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rllllrl(code: U32) -> Glyph:
  face1rllllrl.choose(U32.is_eq(code,170))

def face1rllllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{3710771712,1,0,0},Row{1068755968,0,0,0},Row{133722000,0,0,0},Row{14626034,0,0,0},Row{133722000,0,0,0},Row{1068755968,0,0,0},Row{3710771712,1,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rllllrrl(code: U32) -> Glyph:
  face1rllllrrl.choose(U32.is_eq(code,171))

def face1rllllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{zero_row(),zero_row(),Row{304226832,0,0,0},Row{2415918976,0,0,0},Row{2404734256,0,0,0},Row{2399141888,0,0,0},Row{620756992,0,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rllllrrr(code: U32) -> Glyph:
  face1rllllrrr.choose(U32.is_eq(code,172))

def face1rllllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllllrrl(code)
    case False{}: face1rllllrrr(code)

def face1rllllrr(+code: U32) -> Glyph:
  face1rllllrr.choose(code,U32.is_lt(code,172))

def face1rllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllllrl(code)
    case False{}: face1rllllrr(code)

def face1rllllr(+code: U32) -> Glyph:
  face1rllllr.choose(code,U32.is_lt(code,171))

def face1rllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlllll(code)
    case False{}: face1rllllr(code)

def face1rllll(+code: U32) -> Glyph:
  face1rllll.choose(code,U32.is_lt(code,170))

def face1rlllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),Row{35791360,0,0,0},Row{251591424,0,0,0},Row{251263744,0,0,0},Row{251587328,0,0,0},Row{251239168,0,0,0}},Rows8{Row{251591424,0,0,0},Row{250215168,0,0,0},Row{245365504,0,0,0},Row{249486080,0,0,0},Row{245340928,0,0,0},Row{251656960,0,0,0},Row{244820736,0,0,0},Row{245340928,0,0,0}},Rows8{Row{250608384,0,0,0},Row{250145536,0,0,0},Row{251656960,0,0,0},Row{89478144,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rlllrll(code: U32) -> Glyph:
  face1rlllrll.choose(U32.is_eq(code,173))

def face1rlllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{1179648,0,0,0},Row{452978432,0,0,0},Row{3179851616,0,0,0},Row{3538928865,4,0,0}},Rows8{Row{1944633540,8,0,0},Row{1910489268,9,0,0},Row{3268920049,6,0,0},Row{3429072512,0,0,0},Row{738195712,0,0,0},Row{3481600,0,0,0},zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlllrlrl(code: U32) -> Glyph:
  face1rlllrlrl.choose(U32.is_eq(code,174))

def face1rlllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{139808,0,0,0},Row{3145664,0,0,0},Row{1398080,0,0,0},zero_row()},zero_rows(),zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlllrlrr(code: U32) -> Glyph:
  face1rlllrlrr.choose(U32.is_eq(code,175))

def face1rlllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlllrlrl(code)
    case False{}: face1rlllrlrr(code)

def face1rlllrlr(+code: U32) -> Glyph:
  face1rlllrlr.choose(code,U32.is_lt(code,175))

def face1rlllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlllrll(code)
    case False{}: face1rlllrlr(code)

def face1rlllrl(+code: U32) -> Glyph:
  face1rlllrl.choose(code,U32.is_lt(code,174))

def face1rlllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{8448,0,0,0},Row{654912,0,0,0},Row{6257376,0,0,0},Row{9110258,0,0,0}},Rows8{Row{7227633,0,0,0},Row{851808,0,0,0},Row{17152,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlllrrl(code: U32) -> Glyph:
  face1rlllrrl.choose(U32.is_eq(code,176))

def face1rlllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{8327168,0,0,0},Row{579809824,0,0,0},Row{4294967200,2,0,0},Row{1437558064,1,0,0},Row{8327168,0,0,0},Row{572662304,0,0,0},Row{4294967200,2,0,0},Row{1431655728,1,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlllrrrl(code: U32) -> Glyph:
  face1rlllrrrl.choose(U32.is_eq(code,177))

def face1rlllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{1764992,0,0,0},Row{7292355,0,0,0},Row{6242304,0,0,0},Row{652800,0,0,0}},Rows8{Row{1212288,0,0,0},Row{11534323,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlllrrrr(code: U32) -> Glyph:
  face1rlllrrrr.choose(U32.is_eq(code,178))

def face1rlllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlllrrrl(code)
    case False{}: face1rlllrrrr(code)

def face1rlllrrr(+code: U32) -> Glyph:
  face1rlllrrr.choose(code,U32.is_lt(code,178))

def face1rlllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlllrrl(code)
    case False{}: face1rlllrrr(code)

def face1rlllrr(+code: U32) -> Glyph:
  face1rlllrr.choose(code,U32.is_lt(code,177))

def face1rlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlllrl(code)
    case False{}: face1rlllrr(code)

def face1rlllr(+code: U32) -> Glyph:
  face1rlllr.choose(code,U32.is_lt(code,176))

def face1rlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllll(code)
    case False{}: face1rlllr(code)

def face1rlll(+code: U32) -> Glyph:
  face1rlll.choose(code,U32.is_lt(code,173))

def face1rllrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{2878832,0,0,0},Row{9319553,0,0,0},Row{2946816,0,0,0},Row{11354368,0,0,0}},Rows8{Row{12400339,0,0,0},Row{2878832,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rllrlll(code: U32) -> Glyph:
  face1rllrlll.choose(U32.is_eq(code,179))

def face1rllrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{8704,0,0,0},Row{28464,0,0,0},Row{3216,0,0,0},zero_row()},zero_rows(),zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rllrllrl(code: U32) -> Glyph:
  face1rllrllrl.choose(U32.is_eq(code,180))

def face1rllrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2671775217,0,0,0},Row{3755454449,3,0,0},Row{3883842545,8,0,0}},Rows8{Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rllrllrr(code: U32) -> Glyph:
  face1rllrllrr.choose(U32.is_eq(code,181))

def face1rllrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllrllrl(code)
    case False{}: face1rllrllrr(code)

def face1rllrllr(+code: U32) -> Glyph:
  face1rllrllr.choose(code,U32.is_lt(code,181))

def face1rllrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllrlll(code)
    case False{}: face1rllrllr(code)

def face1rllrll(+code: U32) -> Glyph:
  face1rllrll.choose(code,U32.is_lt(code,180))

def face1rllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1879042592,0,0,0},Row{1871511504,0,0,0},Row{1865023476,0,0,0}},Rows8{Row{1865023477,0,0,0},Row{1865023476,0,0,0},Row{1865023424,0,0,0},Row{1864947984,0,0,0},Row{1864368128,0,0,0},Row{1864368128,0,0,0},Row{1864368128,0,0,0},Row{1864368128,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rllrlrl(code: U32) -> Glyph:
  face1rllrlrl.choose(U32.is_eq(code,182))

def face1rllrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[zero_rows(),Rows8{zero_row(),Row{256,0,0,0},Row{16304,0,0,0},Row{11920,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rllrlrrl(code: U32) -> Glyph:
  face1rllrlrrl.choose(U32.is_eq(code,183))

def face1rllrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{512,0,0,0}},Rows8{Row{11056,0,0,0},Row{55056,0,0,0},Row{40304,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rllrlrrr(code: U32) -> Glyph:
  face1rllrlrrr.choose(U32.is_eq(code,184))

def face1rllrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllrlrrl(code)
    case False{}: face1rllrlrrr(code)

def face1rllrlrr(+code: U32) -> Glyph:
  face1rllrlrr.choose(code,U32.is_lt(code,184))

def face1rllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllrlrl(code)
    case False{}: face1rllrlrr(code)

def face1rllrlr(+code: U32) -> Glyph:
  face1rllrlr.choose(code,U32.is_lt(code,183))

def face1rllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllrll(code)
    case False{}: face1rllrlr(code)

def face1rllrl(+code: U32) -> Glyph:
  face1rllrl.choose(code,U32.is_lt(code,182))

def face1rllrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{49025,0,0,0},Row{48580,0,0,0},Row{47873,0,0,0},Row{47872,0,0,0}},Rows8{Row{47872,0,0,0},Row{47872,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rllrrll(code: U32) -> Glyph:
  face1rllrrll.choose(U32.is_eq(code,185))

def face1rllrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3997008,0,0,0},Row{32123122,0,0,0},Row{83034615,0,0,0}},Rows8{Row{83034615,0,0,0},Row{32123123,0,0,0},Row{3997008,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rllrrlrl(code: U32) -> Glyph:
  face1rllrrlrl.choose(U32.is_eq(code,186))

def face1rllrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{31337698,0,0,0},Row{183803728,0,0,0},Row{2138503168,0,0,0},Row{4246659328,1,0,0},Row{2138503168,0,0,0},Row{183803728,0,0,0},Row{31337698,0,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rllrrlrr(code: U32) -> Glyph:
  face1rllrrlrr.choose(U32.is_eq(code,187))

def face1rllrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllrrlrl(code)
    case False{}: face1rllrrlrr(code)

def face1rllrrlr(+code: U32) -> Glyph:
  face1rllrrlr.choose(code,U32.is_lt(code,187))

def face1rllrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllrrll(code)
    case False{}: face1rllrrlr(code)

def face1rllrrl(+code: U32) -> Glyph:
  face1rllrrl.choose(code,U32.is_lt(code,186))

def face1rllrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{268451778,109,0,0},Row{2147499911,12,0,0},Row{3808444192,2,0,0}},Rows8{Row{2348826400,0,0,0},Row{225460000,0,0,0},Row{81936160,2038,0,0},Row{278593536,2030,0,0},Row{1881038848,1979,0,0},Row{3775258880,1972,0,0},Row{4110461440,12286,0,0},Row{553659968,2242,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rllrrrll(code: U32) -> Glyph:
  face1rllrrrll.choose(U32.is_eq(code,188))

def face1rllrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{268451778,109,0,0},Row{2147499911,12,0,0},Row{3808444192,2,0,0}},Rows8{Row{2348826400,0,0,0},Row{225460000,32,0,0},Row{350371616,16124,0,0},Row{1620770816,32366,0,0},Row{1990656,15632,0,0},Row{385280,1730,0,0},Row{536914432,22477,0,0},Row{1342189120,40959,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rllrrrlr(code: U32) -> Glyph:
  face1rllrrrlr.choose(U32.is_eq(code,189))

def face1rllrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllrrrll(code)
    case False{}: face1rllrrrlr(code)

def face1rllrrrl(+code: U32) -> Glyph:
  face1rllrrrl.choose(code,U32.is_lt(code,189))

def face1rllrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{4352,0,0,0},Row{323504,1984,0,0},Row{645250,199,0,0},Row{537128704,62,0,0}},Rows8{Row{2953626880,9,0,0},Row{3591166148,1,0,0},Row{1309990560,36688,0,0},Row{178257920,36560,0,0},Row{31784960,35527,0,0},Row{275582976,35406,0,0},Row{1074499584,262127,0,0},Row{268624640,39714,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rllrrrrl(code: U32) -> Glyph:
  face1rllrrrrl.choose(U32.is_eq(code,190))

def face1rllrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{1945600,0,0,0},Row{3133440,0,0,0},Row{69632,0,0,0},Row{684032,0,0,0},Row{905216,0,0,0},Row{523024,0,0,0},Row{36800,0,0,0},Row{2804,0,0,0}},Rows8{Row{247466484,0,0,0},Row{184197089,0,0,0},Row{27192112,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rllrrrrr(code: U32) -> Glyph:
  face1rllrrrrr.choose(U32.is_eq(code,191))

def face1rllrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllrrrrl(code)
    case False{}: face1rllrrrrr(code)

def face1rllrrrr(+code: U32) -> Glyph:
  face1rllrrrr.choose(code,U32.is_lt(code,191))

def face1rllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllrrrl(code)
    case False{}: face1rllrrrr(code)

def face1rllrrr(+code: U32) -> Glyph:
  face1rllrrr.choose(code,U32.is_lt(code,190))

def face1rllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllrrl(code)
    case False{}: face1rllrrr(code)

def face1rllrr(+code: U32) -> Glyph:
  face1rllrr.choose(code,U32.is_lt(code,188))

def face1rllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rllrl(code)
    case False{}: face1rllrr(code)

def face1rllr(+code: U32) -> Glyph:
  face1rllr.choose(code,U32.is_lt(code,185))

def face1rll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlll(code)
    case False{}: face1rllr(code)

def face1rll(+code: U32) -> Glyph:
  face1rll.choose(code,U32.is_lt(code,179))

def face1rlrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),Row{139264,0,0,0},Row{3112960,0,0,0},Row{9240576,0,0,0},zero_row(),Row{117391360,0,0,0},Row{201297920,0,0,0},Row{533585920,0,0,0}},Rows8{Row{1871311872,0,0,0},Row{3209033728,0,0,0},Row{4261608704,1,0,0},Row{4194357040,5,0,0},Row{4294967168,10,0,0},Row{4169703376,31,0,0},Row{2684358131,95,0,0},Row{1342179575,175,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrllll(code: U32) -> Glyph:
  face1rlrllll.choose(U32.is_eq(code,192))

def face1rlrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),Row{35651584,0,0,0},Row{182452224,0,0,0},Row{31850496,0,0,0},zero_row(),Row{117391360,0,0,0},Row{201297920,0,0,0},Row{533585920,0,0,0}},Rows8{Row{1871311872,0,0,0},Row{3209033728,0,0,0},Row{4261608704,1,0,0},Row{4194357040,5,0,0},Row{4294967168,10,0,0},Row{4169703376,31,0,0},Row{2684358131,95,0,0},Row{1342179575,175,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrlllrl(code: U32) -> Glyph:
  face1rlrlllrl.choose(U32.is_eq(code,193))

def face1rlrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),Row{82718720,0,0,0},Row{1047060992,0,0,0},zero_row(),Row{117391360,0,0,0},Row{201297920,0,0,0},Row{533585920,0,0,0}},Rows8{Row{1871311872,0,0,0},Row{3209033728,0,0,0},Row{4261608704,1,0,0},Row{4194357040,5,0,0},Row{4294967168,10,0,0},Row{4169703376,31,0,0},Row{2684358131,95,0,0},Row{1342179575,175,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrlllrr(code: U32) -> Glyph:
  face1rlrlllrr.choose(U32.is_eq(code,194))

def face1rlrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrlllrl(code)
    case False{}: face1rlrlllrr(code)

def face1rlrlllr(+code: U32) -> Glyph:
  face1rlrlllr.choose(code,U32.is_lt(code,194))

def face1rlrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrllll(code)
    case False{}: face1rlrlllr(code)

def face1rlrlll(+code: U32) -> Glyph:
  face1rlrlll.choose(code,U32.is_lt(code,193))

def face1rlrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),Row{1262260224,0,0,0},Row{501604608,0,0,0},Row{16785408,0,0,0},Row{117391360,0,0,0},Row{201297920,0,0,0},Row{533585920,0,0,0}},Rows8{Row{1871311872,0,0,0},Row{3209033728,0,0,0},Row{4261608704,1,0,0},Row{4194357040,5,0,0},Row{4294967168,10,0,0},Row{4169703376,31,0,0},Row{2684358131,95,0,0},Row{1342179575,175,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrllrl(code: U32) -> Glyph:
  face1rlrllrl.choose(U32.is_eq(code,195))

def face1rlrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),Row{16781312,0,0,0},Row{1866986496,0,0,0},Row{335626240,0,0,0},zero_row(),Row{117391360,0,0,0},Row{201297920,0,0,0},Row{533585920,0,0,0}},Rows8{Row{1871311872,0,0,0},Row{3209033728,0,0,0},Row{4261608704,1,0,0},Row{4194357040,5,0,0},Row{4294967168,10,0,0},Row{4169703376,31,0,0},Row{2684358131,95,0,0},Row{1342179575,175,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrllrrl(code: U32) -> Glyph:
  face1rlrllrrl.choose(U32.is_eq(code,196))

def face1rlrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),Row{1114112,0,0,0},Row{134172672,0,0,0},Row{229355520,0,0,0},Row{167735296,0,0,0},Row{117391360,0,0,0},Row{201297920,0,0,0},Row{533585920,0,0,0}},Rows8{Row{1871311872,0,0,0},Row{3209033728,0,0,0},Row{4261608704,1,0,0},Row{4194357040,5,0,0},Row{4294967168,10,0,0},Row{4169703376,31,0,0},Row{2684358131,95,0,0},Row{1342179575,175,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrllrrr(code: U32) -> Glyph:
  face1rlrllrrr.choose(U32.is_eq(code,197))

def face1rlrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrllrrl(code)
    case False{}: face1rlrllrrr(code)

def face1rlrllrr(+code: U32) -> Glyph:
  face1rlrllrr.choose(code,U32.is_lt(code,197))

def face1rlrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrllrl(code)
    case False{}: face1rlrllrr(code)

def face1rlrllr(+code: U32) -> Glyph:
  face1rlrllr.choose(code,U32.is_lt(code,196))

def face1rlrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrlll(code)
    case False{}: face1rlrllr(code)

def face1rlrll(+code: U32) -> Glyph:
  face1rlrll.choose(code,U32.is_lt(code,195))

def face1rlrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4294246400,6291455,0,0},Row{4126867456,2586492,0,0},Row{4089389056,8,0,0}},Rows8{Row{4083122176,8,0,0},Row{4077838336,139817,0,0},Row{4077450752,1048575,0,0},Row{4112907264,349531,0,0},Row{4294967088,8,0,0},Row{4149579664,8,0,0},Row{4076871393,3635068,0,0},Row{4076865783,7340031,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrlrll(code: U32) -> Glyph:
  face1rlrlrll.choose(U32.is_eq(code,198))

def face1rlrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2113769728,0,0,0},Row{4236967184,11,0,0},Row{2684383120,95,0,0}},Rows8{Row{805309921,89,0,0},Row{2803,0,0,0},Row{2292,0,0,0},Row{2803,0,0,0},Row{536874481,89,0,0},Row{2684383120,95,0,0},Row{4236967184,10,0,0},Row{2113769728,0,0,0}},Rows8{Row{46268416,0,0,0},Row{241238016,0,0,0},Row{180748288,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rlrlrlrl(code: U32) -> Glyph:
  face1rlrlrlrl.choose(U32.is_eq(code,199))

def face1rlrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),Row{8448,0,0,0},Row{390144,0,0,0},Row{823296,0,0,0},zero_row(),Row{2952790000,0,0,0},Row{1467449072,0,0,0},Row{3568,0,0,0}},Rows8{Row{3568,0,0,0},Row{304229872,0,0,0},Row{1342177264,0,0,0},Row{357916144,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{1467449072,0,0,0},Row{2952790000,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrlrlrr(code: U32) -> Glyph:
  face1rlrlrlrr.choose(U32.is_eq(code,200))

def face1rlrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrlrlrl(code)
    case False{}: face1rlrlrlrr(code)

def face1rlrlrlr(+code: U32) -> Glyph:
  face1rlrlrlr.choose(code,U32.is_lt(code,200))

def face1rlrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrlrll(code)
    case False{}: face1rlrlrlr(code)

def face1rlrlrl(+code: U32) -> Glyph:
  face1rlrlrl.choose(code,U32.is_lt(code,199))

def face1rlrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),Row{18939904,0,0,0},Row{31064064,0,0,0},Row{5185536,0,0,0},zero_row(),Row{2952790000,0,0,0},Row{1467449072,0,0,0},Row{3568,0,0,0}},Rows8{Row{3568,0,0,0},Row{304229872,0,0,0},Row{1342177264,0,0,0},Row{357916144,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{1467449072,0,0,0},Row{2952790000,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrlrrll(code: U32) -> Glyph:
  face1rlrlrrll.choose(U32.is_eq(code,201))

def face1rlrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),Row{9421056,0,0,0},Row{132369152,0,0,0},zero_row(),Row{2952790000,0,0,0},Row{1467449072,0,0,0},Row{3568,0,0,0}},Rows8{Row{3568,0,0,0},Row{304229872,0,0,0},Row{1342177264,0,0,0},Row{357916144,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{1467449072,0,0,0},Row{2952790000,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrlrrlr(code: U32) -> Glyph:
  face1rlrlrrlr.choose(U32.is_eq(code,202))

def face1rlrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrlrrll(code)
    case False{}: face1rlrlrrlr(code)

def face1rlrlrrl(+code: U32) -> Glyph:
  face1rlrlrrl.choose(code,U32.is_lt(code,202))

def face1rlrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),Row{1048832,0,0,0},Row{183614976,0,0,0},Row{36709120,0,0,0},zero_row(),Row{2952790000,0,0,0},Row{1467449072,0,0,0},Row{3568,0,0,0}},Rows8{Row{3568,0,0,0},Row{304229872,0,0,0},Row{1342177264,0,0,0},Row{357916144,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{1467449072,0,0,0},Row{2952790000,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrlrrrl(code: U32) -> Glyph:
  face1rlrlrrrl.choose(U32.is_eq(code,203))

def face1rlrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),Row{544,0,0,0},Row{3744,0,0,0},Row{28176,0,0,0},zero_row(),Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0}},Rows8{Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrlrrrr(code: U32) -> Glyph:
  face1rlrlrrrr.choose(U32.is_eq(code,204))

def face1rlrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrlrrrl(code)
    case False{}: face1rlrlrrrr(code)

def face1rlrlrrr(+code: U32) -> Glyph:
  face1rlrlrrr.choose(code,U32.is_lt(code,204))

def face1rlrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrlrrl(code)
    case False{}: face1rlrlrrr(code)

def face1rlrlrr(+code: U32) -> Glyph:
  face1rlrlrr.choose(code,U32.is_lt(code,203))

def face1rlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrlrl(code)
    case False{}: face1rlrlrr(code)

def face1rlrlr(+code: U32) -> Glyph:
  face1rlrlr.choose(code,U32.is_lt(code,201))

def face1rlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrll(code)
    case False{}: face1rlrlr(code)

def face1rlrl(+code: U32) -> Glyph:
  face1rlrl.choose(code,U32.is_lt(code,198))

def face1rlrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),Row{8704,0,0,0},Row{36624,0,0,0},Row{3456,0,0,0},zero_row(),Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0}},Rows8{Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0},Row{3568,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrrlll(code: U32) -> Glyph:
  face1rlrrlll.choose(U32.is_eq(code,205))

def face1rlrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),Row{257600,0,0,0},Row{3049188,0,0,0},zero_row(),Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0}},Rows8{Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrrllrl(code: U32) -> Glyph:
  face1rlrrllrl.choose(U32.is_eq(code,206))

def face1rlrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),Row{65552,0,0,0},Row{5203446,0,0,0},Row{266305,0,0,0},zero_row(),Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0}},Rows8{Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0},Row{57088,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrrllrr(code: U32) -> Glyph:
  face1rlrrllrr.choose(U32.is_eq(code,207))

def face1rlrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrrllrl(code)
    case False{}: face1rlrrllrr(code)

def face1rlrrllr(+code: U32) -> Glyph:
  face1rlrrllr.choose(code,U32.is_lt(code,207))

def face1rlrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrrlll(code)
    case False{}: face1rlrrllr(code)

def face1rlrrll(+code: U32) -> Glyph:
  face1rlrrll.choose(code,U32.is_lt(code,206))

def face1rlrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1542455168,0,0,0},Row{4254572416,7,0,0},Row{3238023040,47,0,0}},Rows8{Row{1342197632,143,0,0},Row{269643698,191,0,0},Row{10485757,207,0,0},Row{540385236,191,0,0},Row{1342197632,143,0,0},Row{3238023040,47,0,0},Row{4254572416,7,0,0},Row{1542455168,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrrlrl(code: U32) -> Glyph:
  face1rlrrlrl.choose(U32.is_eq(code,208))

def face1rlrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),Row{2019385344,0,0,0},Row{1069993984,0,0,0},Row{16785408,0,0,0},Row{1073770480,159,0,0},Row{1073868784,159,0,0},Row{1074331376,159,0,0}},Rows8{Row{1076874480,159,0,0},Row{1085230576,159,0,0},Row{1157303792,159,0,0},Row{1290931696,159,0,0},Row{2407534064,159,0,0},Row{3977252336,159,0,0},Row{4110421488,159,0,0},Row{2952793584,159,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrrlrrl(code: U32) -> Glyph:
  face1rlrrlrrl.choose(U32.is_eq(code,209))

def face1rlrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),Row{135168,0,0,0},Row{7286784,0,0,0},Row{13172736,0,0,0},zero_row(),Row{2113765632,0,0,0},Row{4236967184,10,0,0},Row{2684383120,111,0,0}},Rows8{Row{536874465,207,0,0},Row{2803,238,0,0},Row{2292,508,0,0},Row{2803,238,0,0},Row{536874481,207,0,0},Row{2684383120,111,0,0},Row{4236967184,10,0,0},Row{2113769728,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrrlrrr(code: U32) -> Glyph:
  face1rlrrlrrr.choose(U32.is_eq(code,210))

def face1rlrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrrlrrl(code)
    case False{}: face1rlrrlrrr(code)

def face1rlrrlrr(+code: U32) -> Glyph:
  face1rlrrlrr.choose(code,U32.is_lt(code,210))

def face1rlrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrrlrl(code)
    case False{}: face1rlrrlrr(code)

def face1rlrrlr(+code: U32) -> Glyph:
  face1rlrrlr.choose(code,U32.is_lt(code,209))

def face1rlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrrll(code)
    case False{}: face1rlrrlr(code)

def face1rlrrl(+code: U32) -> Glyph:
  face1rlrrl.choose(code,U32.is_lt(code,208))

def face1rlrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),Row{303038464,0,0,0},Row{512753664,0,0,0},Row{99680256,0,0,0},zero_row(),Row{2113765632,0,0,0},Row{4236967184,10,0,0},Row{2684383120,111,0,0}},Rows8{Row{536874465,207,0,0},Row{2803,238,0,0},Row{2292,508,0,0},Row{2803,238,0,0},Row{536874481,207,0,0},Row{2684383120,111,0,0},Row{4236967184,10,0,0},Row{2113769728,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrrrll(code: U32) -> Glyph:
  face1rlrrrll.choose(U32.is_eq(code,211))

def face1rlrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),Row{167448576,0,0,0},Row{2386341888,0,0,0},zero_row(),Row{2113765632,0,0,0},Row{4236967184,10,0,0},Row{2684383120,111,0,0}},Rows8{Row{536874465,207,0,0},Row{2803,238,0,0},Row{2292,508,0,0},Row{2803,238,0,0},Row{536874481,207,0,0},Row{2684383120,111,0,0},Row{4236967184,10,0,0},Row{2113769728,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrrrlrl(code: U32) -> Glyph:
  face1rlrrrlrl.choose(U32.is_eq(code,212))

def face1rlrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),Row{2272088064,0,0,0},Row{1337442304,0,0,0},Row{16785408,0,0,0},Row{2113765632,0,0,0},Row{4236967184,10,0,0},Row{2684383120,111,0,0}},Rows8{Row{536874465,207,0,0},Row{2803,238,0,0},Row{2292,508,0,0},Row{2803,238,0,0},Row{536874481,207,0,0},Row{2684383120,111,0,0},Row{4236967184,10,0,0},Row{2113769728,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrrrlrr(code: U32) -> Glyph:
  face1rlrrrlrr.choose(U32.is_eq(code,213))

def face1rlrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrrrlrl(code)
    case False{}: face1rlrrrlrr(code)

def face1rlrrrlr(+code: U32) -> Glyph:
  face1rlrrrlr.choose(code,U32.is_lt(code,213))

def face1rlrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrrrll(code)
    case False{}: face1rlrrrlr(code)

def face1rlrrrl(+code: U32) -> Glyph:
  face1rlrrrl.choose(code,U32.is_lt(code,212))

def face1rlrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),Row{16781312,0,0,0},Row{3188449280,0,0,0},Row{587345920,0,0,0},zero_row(),Row{2113765632,0,0,0},Row{4236967184,10,0,0},Row{2684383120,111,0,0}},Rows8{Row{536874465,207,0,0},Row{2803,238,0,0},Row{2292,508,0,0},Row{2803,238,0,0},Row{536874481,207,0,0},Row{2684383120,111,0,0},Row{4236967184,10,0,0},Row{2113769728,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrrrrll(code: U32) -> Glyph:
  face1rlrrrrll.choose(U32.is_eq(code,214))

def face1rlrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{822084608,0,0,0},Row{3708841840,1,0,0},Row{1607990288,0,0,0},Row{100647168,0,0,0},Row{117424384,0,0,0},Row{1875311632,0,0,0},Row{3692060528,1,0,0},Row{553648896,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrrrrlr(code: U32) -> Glyph:
  face1rlrrrrlr.choose(U32.is_eq(code,215))

def face1rlrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrrrrll(code)
    case False{}: face1rlrrrrlr(code)

def face1rlrrrrl(+code: U32) -> Glyph:
  face1rlrrrrl.choose(code,U32.is_lt(code,215))

def face1rlrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2113765632,21,0,0},Row{4236967184,63,0,0},Row{4043337616,111,0,0}},Rows8{Row{3925872097,207,0,0},Row{776997619,238,0,0},Row{115476724,508,0,0},Row{11209459,238,0,0},Row{538869233,207,0,0},Row{2684682128,111,0,0},Row{4236967712,10,0,0},Row{2113773168,0,0,0}},Rows8{Row{512,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rlrrrrrl(code: U32) -> Glyph:
  face1rlrrrrrl.choose(U32.is_eq(code,216))

def face1rlrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),Row{139264,0,0,0},Row{3104768,0,0,0},Row{10223616,0,0,0},zero_row(),Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2147487216,79,0,0}},Rows8{Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2415922912,63,0,0},Row{3774894000,30,0,0},Row{4253679408,7,0,0},Row{1559143168,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rlrrrrrr(code: U32) -> Glyph:
  face1rlrrrrrr.choose(U32.is_eq(code,217))

def face1rlrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrrrrrl(code)
    case False{}: face1rlrrrrrr(code)

def face1rlrrrrr(+code: U32) -> Glyph:
  face1rlrrrrr.choose(code,U32.is_lt(code,217))

def face1rlrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrrrrl(code)
    case False{}: face1rlrrrrr(code)

def face1rlrrrr(+code: U32) -> Glyph:
  face1rlrrrr.choose(code,U32.is_lt(code,216))

def face1rlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrrrl(code)
    case False{}: face1rlrrrr(code)

def face1rlrrr(+code: U32) -> Glyph:
  face1rlrrr.choose(code,U32.is_lt(code,214))

def face1rlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrrl(code)
    case False{}: face1rlrrr(code)

def face1rlrr(+code: U32) -> Glyph:
  face1rlrr.choose(code,U32.is_lt(code,211))

def face1rlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rlrl(code)
    case False{}: face1rlrr(code)

def face1rlr(+code: U32) -> Glyph:
  face1rlr.choose(code,U32.is_lt(code,205))

def face1rl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rll(code)
    case False{}: face1rlr(code)

def face1rl(+code: U32) -> Glyph:
  face1rl.choose(code,U32.is_lt(code,192))

def face1rrlllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),Row{34603008,0,0,0},Row{198180864,0,0,0},Row{48496640,0,0,0},zero_row(),Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2147487216,79,0,0}},Rows8{Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2415922912,63,0,0},Row{3774894000,30,0,0},Row{4253679408,7,0,0},Row{1559143168,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlllll(code: U32) -> Glyph:
  face1rrlllll.choose(U32.is_eq(code,218))

def face1rrllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),Row{100540416,0,0,0},Row{1331286528,0,0,0},zero_row(),Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2147487216,79,0,0}},Rows8{Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2415922912,63,0,0},Row{3774894000,30,0,0},Row{4253679408,7,0,0},Row{1559143168,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrllllrl(code: U32) -> Glyph:
  face1rrllllrl.choose(U32.is_eq(code,219))

def face1rrllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),Row{16781312,0,0,0},Row{2402874112,0,0,0},Row{335626240,0,0,0},zero_row(),Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2147487216,79,0,0}},Rows8{Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2147487216,79,0,0},Row{2415922912,63,0,0},Row{3774894000,30,0,0},Row{4253679408,7,0,0},Row{1559143168,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrllllrr(code: U32) -> Glyph:
  face1rrllllrr.choose(U32.is_eq(code,220))

def face1rrllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrllllrl(code)
    case False{}: face1rrllllrr(code)

def face1rrllllr(+code: U32) -> Glyph:
  face1rrllllr.choose(code,U32.is_lt(code,220))

def face1rrllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlllll(code)
    case False{}: face1rrllllr(code)

def face1rrllll(+code: U32) -> Glyph:
  face1rrllll.choose(code,U32.is_lt(code,219))

def face1rrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),Row{35651584,0,0,0},Row{165740544,0,0,0},Row{30867456,0,0,0},zero_row(),Row{2952793078,95,0,0},Row{4076883904,12,0,0},Row{4211134272,4,0,0}},Rows8{Row{3208968960,0,0,0},Row{1068233472,0,0,0},Row{184520704,0,0,0},Row{50274304,0,0,0},Row{15532032,0,0,0},Row{15532032,0,0,0},Row{15532032,0,0,0},Row{15532032,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlllrl(code: U32) -> Glyph:
  face1rrlllrl.choose(U32.is_eq(code,221))

def face1rrlllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3312,0,0,0},Row{3312,0,0,0},Row{1191408,0,0,0}},Rows8{Row{738197488,0,0,0},Row{3481624048,0,0,0},Row{4194307312,1,0,0},Row{3729993200,0,0,0},Row{1308622832,0,0,0},Row{3497456,0,0,0},Row{3312,0,0,0},Row{3312,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlllrrl(code: U32) -> Glyph:
  face1rrlllrrl.choose(U32.is_eq(code,222))

def face1rrlllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{97511424,0,0,0},Row{1608044432,0,0,0},Row{2940210912,0,0,0}},Rows8{Row{2938113264,0,0,0},Row{1336085744,0,0,0},Row{721358064,0,0,0},Row{3732212976,1,0,0},Row{4160752880,5,0,0},Row{4160752880,5,0,0},Row{4019653872,1,0,0},Row{1023352048,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlllrrr(code: U32) -> Glyph:
  face1rrlllrrr.choose(U32.is_eq(code,223))

def face1rrlllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlllrrl(code)
    case False{}: face1rrlllrrr(code)

def face1rrlllrr(+code: U32) -> Glyph:
  face1rrlllrr.choose(code,U32.is_lt(code,223))

def face1rrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlllrl(code)
    case False{}: face1rrlllrr(code)

def face1rrlllr(+code: U32) -> Glyph:
  face1rrlllr.choose(code,U32.is_lt(code,222))

def face1rrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrllll(code)
    case False{}: face1rrlllr(code)

def face1rrlll(+code: U32) -> Glyph:
  face1rrlll.choose(code,U32.is_lt(code,221))

def face1rrllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{8704,0,0,0},Row{125184,0,0,0},Row{450816,0,0,0},zero_row()},Rows8{Row{45017632,0,0,0},Row{217685713,0,0,0},Row{531628865,0,0,0},Row{536581648,0,0,0},Row{532061922,0,0,0},Row{532678135,0,0,0},Row{535530997,0,0,0},Row{530116224,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrllrll(code: U32) -> Glyph:
  face1rrllrll.choose(U32.is_eq(code,224))

def face1rrllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{2228224,0,0,0},Row{9375744,0,0,0},Row{1929216,0,0,0},zero_row()},Rows8{Row{45017632,0,0,0},Row{217685713,0,0,0},Row{531628865,0,0,0},Row{536581648,0,0,0},Row{532061922,0,0,0},Row{532678135,0,0,0},Row{535530997,0,0,0},Row{530116224,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrllrlrl(code: U32) -> Glyph:
  face1rrllrlrl.choose(U32.is_eq(code,225))

def face1rrllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4121600,0,0,0},Row{48786992,0,0,0},zero_row()},Rows8{Row{45017632,0,0,0},Row{217685713,0,0,0},Row{531628865,0,0,0},Row{536581648,0,0,0},Row{532061922,0,0,0},Row{532678135,0,0,0},Row{535530997,0,0,0},Row{530116224,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrllrlrr(code: U32) -> Glyph:
  face1rrllrlrr.choose(U32.is_eq(code,226))

def face1rrllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrllrlrl(code)
    case False{}: face1rrllrlrr(code)

def face1rrllrlr(+code: U32) -> Glyph:
  face1rrllrlr.choose(code,U32.is_lt(code,226))

def face1rrllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrllrll(code)
    case False{}: face1rrllrlr(code)

def face1rrllrl(+code: U32) -> Glyph:
  face1rrllrl.choose(code,U32.is_lt(code,225))

def face1rrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{47368960,0,0,0},Row{13528368,0,0,0},Row{66064,0,0,0}},Rows8{Row{45017632,0,0,0},Row{217685713,0,0,0},Row{531628865,0,0,0},Row{536581648,0,0,0},Row{532061922,0,0,0},Row{532678135,0,0,0},Row{535530997,0,0,0},Row{530116224,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrllrrl(code: U32) -> Glyph:
  face1rrllrrl.choose(U32.is_eq(code,227))

def face1rrllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{1048832,0,0,0},Row{100032352,0,0,0},Row{4260864,0,0,0},zero_row()},Rows8{Row{45017632,0,0,0},Row{217685713,0,0,0},Row{531628865,0,0,0},Row{536581648,0,0,0},Row{532061922,0,0,0},Row{532678135,0,0,0},Row{535530997,0,0,0},Row{530116224,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrllrrrl(code: U32) -> Glyph:
  face1rrllrrrl.choose(U32.is_eq(code,228))

def face1rrllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{69632,0,0,0},Row{6288896,0,0,0},Row{12299264,0,0,0},Row{8386560,0,0,0}},Rows8{Row{45087520,0,0,0},Row{217685713,0,0,0},Row{531628865,0,0,0},Row{536581648,0,0,0},Row{532061922,0,0,0},Row{532678135,0,0,0},Row{535530997,0,0,0},Row{530116224,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrllrrrr(code: U32) -> Glyph:
  face1rrllrrrr.choose(U32.is_eq(code,229))

def face1rrllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrllrrrl(code)
    case False{}: face1rrllrrrr(code)

def face1rrllrrr(+code: U32) -> Glyph:
  face1rrllrrr.choose(code,U32.is_lt(code,229))

def face1rrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrllrrl(code)
    case False{}: face1rrllrrr(code)

def face1rrllrr(+code: U32) -> Glyph:
  face1rrllrr.choose(code,U32.is_lt(code,228))

def face1rrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrllrl(code)
    case False{}: face1rrllrr(code)

def face1rrllr(+code: U32) -> Glyph:
  face1rrllr.choose(code,U32.is_lt(code,227))

def face1rrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlll(code)
    case False{}: face1rrllr(code)

def face1rrll(+code: U32) -> Glyph:
  face1rrll.choose(code,U32.is_lt(code,224))

def face1rrlrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{2996759344,2271,0,0},Row{3757678305,40872,0,0},Row{1068638480,129826,0,0},Row{4294966896,262143,0,0},Row{1589996788,87381,0,0},Row{1070597623,26112,0,0},Row{4008414708,49064,0,0},Row{3275484784,6639,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlrlll(code: U32) -> Glyph:
  face1rrlrlll.choose(U32.is_eq(code,230))

def face1rrlrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{80668672,0,0,0},Row{803782560,0,0,0},Row{1244662770,0,0,0},Row{2037,0,0,0},Row{2037,0,0,0},Row{1261440242,0,0,0},Row{787005344,0,0,0},Row{80734224,0,0,0}},Rows8{Row{1781760,0,0,0},Row{14098432,0,0,0},Row{9269248,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rrlrllrl(code: U32) -> Glyph:
  face1rrlrllrl.choose(U32.is_eq(code,231))

def face1rrlrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{8704,0,0,0},Row{194048,0,0,0},Row{638976,0,0,0},zero_row()},Rows8{Row{62842880,0,0,0},Row{785948576,0,0,0},Row{2404526578,0,0,0},Row{2952790005,0,0,0},Row{894786037,0,0,0},Row{639634162,0,0,0},Row{1339604896,0,0,0},Row{97511440,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlrllrr(code: U32) -> Glyph:
  face1rrlrllrr.choose(U32.is_eq(code,232))

def face1rrlrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlrllrl(code)
    case False{}: face1rrlrllrr(code)

def face1rrlrllr(+code: U32) -> Glyph:
  face1rrlrllr.choose(code,U32.is_lt(code,232))

def face1rrlrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlrlll(code)
    case False{}: face1rrlrllr(code)

def face1rrlrll(+code: U32) -> Glyph:
  face1rrlrll.choose(code,U32.is_lt(code,231))

def face1rrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{2162688,0,0,0},Row{12386304,0,0,0},Row{3096576,0,0,0},zero_row()},Rows8{Row{62842880,0,0,0},Row{785948576,0,0,0},Row{2404526578,0,0,0},Row{2952790005,0,0,0},Row{894786037,0,0,0},Row{639634162,0,0,0},Row{1339604896,0,0,0},Row{97511440,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlrlrl(code: U32) -> Glyph:
  face1rrlrlrl.choose(U32.is_eq(code,233))

def face1rrlrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{6279680,0,0,0},Row{99917072,0,0,0},zero_row()},Rows8{Row{62842880,0,0,0},Row{785948576,0,0,0},Row{2404526578,0,0,0},Row{2952790005,0,0,0},Row{894786037,0,0,0},Row{639634162,0,0,0},Row{1339604896,0,0,0},Row{97511440,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlrlrrl(code: U32) -> Glyph:
  face1rrlrlrrl.choose(U32.is_eq(code,234))

def face1rrlrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{1048832,0,0,0},Row{150179632,0,0,0},Row{20976640,0,0,0},zero_row()},Rows8{Row{62842880,0,0,0},Row{785948576,0,0,0},Row{2404526578,0,0,0},Row{2952790005,0,0,0},Row{894786037,0,0,0},Row{639634162,0,0,0},Row{1339604896,0,0,0},Row{97511440,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlrlrrr(code: U32) -> Glyph:
  face1rrlrlrrr.choose(U32.is_eq(code,235))

def face1rrlrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlrlrrl(code)
    case False{}: face1rrlrlrrr(code)

def face1rrlrlrr(+code: U32) -> Glyph:
  face1rrlrlrr.choose(code,U32.is_lt(code,235))

def face1rrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlrlrl(code)
    case False{}: face1rrlrlrr(code)

def face1rrlrlr(+code: U32) -> Glyph:
  face1rrlrlr.choose(code,U32.is_lt(code,234))

def face1rrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlrll(code)
    case False{}: face1rrlrlr(code)

def face1rrlrl(+code: U32) -> Glyph:
  face1rrlrl.choose(code,U32.is_lt(code,233))

def face1rrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{5,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{288,0,0,0},Row{3248,0,0,0},Row{20256,0,0,0},zero_row()},Rows8{Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlrrll(code: U32) -> Glyph:
  face1rrlrrll.choose(U32.is_eq(code,236))

def face1rrlrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{8704,0,0,0},Row{28464,0,0,0},Row{3216,0,0,0},zero_row()},Rows8{Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlrrlrl(code: U32) -> Glyph:
  face1rrlrrlrl.choose(U32.is_eq(code,237))

def face1rrlrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{188256,0,0,0},Row{1938677,0,0,0},zero_row()},Rows8{Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlrrlrr(code: U32) -> Glyph:
  face1rrlrrlrr.choose(U32.is_eq(code,238))

def face1rrlrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlrrlrl(code)
    case False{}: face1rrlrrlrr(code)

def face1rrlrrlr(+code: U32) -> Glyph:
  face1rrlrrlr.choose(code,U32.is_lt(code,238))

def face1rrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlrrll(code)
    case False{}: face1rrlrrlr(code)

def face1rrlrrl(+code: U32) -> Glyph:
  face1rrlrrl.choose(code,U32.is_lt(code,237))

def face1rrlrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{65552,0,0,0},Row{4162552,0,0,0},Row{266305,0,0,0},zero_row()},Rows8{Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0},Row{48912,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlrrrll(code: U32) -> Glyph:
  face1rrlrrrll.choose(U32.is_eq(code,239))

def face1rrlrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{71330560,0,0,0},Row{63825664,0,0,0},Row{30263808,0,0,0}},Rows8{Row{182658304,0,0,0},Row{1068432688,0,0,0},Row{2413199312,0,0,0},Row{2939160820,0,0,0},Row{2936014581,0,0,0},Row{2133854707,0,0,0},Row{518565824,0,0,0},Row{62843152,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlrrrlr(code: U32) -> Glyph:
  face1rrlrrrlr.choose(U32.is_eq(code,240))

def face1rrlrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlrrrll(code)
    case False{}: face1rrlrrrlr(code)

def face1rrlrrrl(+code: U32) -> Glyph:
  face1rrlrrrl.choose(code,U32.is_lt(code,240))

def face1rrlrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{126211584,0,0,0},Row{66874624,0,0,0},Row{1049088,0,0,0}},Rows8{Row{133069297,0,0,0},Row{1609088497,0,0,0},Row{2404388337,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlrrrrl(code: U32) -> Glyph:
  face1rrlrrrrl.choose(U32.is_eq(code,241))

def face1rrlrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{8704,0,0,0},Row{324864,0,0,0},Row{761856,0,0,0},zero_row()},Rows8{Row{80668672,0,0,0},Row{1072218016,0,0,0},Row{2940210418,0,0,0},Row{3724544245,0,0,0},Row{3724543989,0,0,0},Row{2940210418,0,0,0},Row{1072218016,0,0,0},Row{80668688,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrlrrrrr(code: U32) -> Glyph:
  face1rrlrrrrr.choose(U32.is_eq(code,242))

def face1rrlrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlrrrrl(code)
    case False{}: face1rrlrrrrr(code)

def face1rrlrrrr(+code: U32) -> Glyph:
  face1rrlrrrr.choose(code,U32.is_lt(code,242))

def face1rrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlrrrl(code)
    case False{}: face1rrlrrrr(code)

def face1rrlrrr(+code: U32) -> Glyph:
  face1rrlrrr.choose(code,U32.is_lt(code,241))

def face1rrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlrrl(code)
    case False{}: face1rrlrrr(code)

def face1rrlrr(+code: U32) -> Glyph:
  face1rrlrr.choose(code,U32.is_lt(code,239))

def face1rrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrlrl(code)
    case False{}: face1rrlrr(code)

def face1rrlr(+code: U32) -> Glyph:
  face1rrlr.choose(code,U32.is_lt(code,236))

def face1rrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrll(code)
    case False{}: face1rrlr(code)

def face1rrl(+code: U32) -> Glyph:
  face1rrl.choose(code,U32.is_lt(code,230))

def face1rrrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{2162688,0,0,0},Row{13303808,0,0,0},Row{4141056,0,0,0},zero_row()},Rows8{Row{80668672,0,0,0},Row{1072218016,0,0,0},Row{2940210418,0,0,0},Row{3724544245,0,0,0},Row{3724543989,0,0,0},Row{2940210418,0,0,0},Row{1072218016,0,0,0},Row{80668688,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrllll(code: U32) -> Glyph:
  face1rrrllll.choose(U32.is_eq(code,243))

def face1rrrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{8376576,0,0,0},Row{115653648,0,0,0},zero_row()},Rows8{Row{80668672,0,0,0},Row{1072218016,0,0,0},Row{2940210418,0,0,0},Row{3724544245,0,0,0},Row{3724543989,0,0,0},Row{2940210418,0,0,0},Row{1072218016,0,0,0},Row{80668688,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrlllrl(code: U32) -> Glyph:
  face1rrrlllrl.choose(U32.is_eq(code,244))

def face1rrrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{110483200,0,0,0},Row{49110528,0,0,0},Row{1049088,0,0,0}},Rows8{Row{80668672,0,0,0},Row{1072218016,0,0,0},Row{2940210418,0,0,0},Row{3724544245,0,0,0},Row{3724543989,0,0,0},Row{2940210418,0,0,0},Row{1072218016,0,0,0},Row{80668688,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrlllrr(code: U32) -> Glyph:
  face1rrrlllrr.choose(U32.is_eq(code,245))

def face1rrrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrlllrl(code)
    case False{}: face1rrrlllrr(code)

def face1rrrlllr(+code: U32) -> Glyph:
  face1rrrlllr.choose(code,U32.is_lt(code,245))

def face1rrrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrllll(code)
    case False{}: face1rrrlllr(code)

def face1rrrlll(+code: U32) -> Glyph:
  face1rrrlll.choose(code,U32.is_lt(code,244))

def face1rrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{1048832,0,0,0},Row{166895392,0,0,0},Row{19927808,0,0,0},zero_row()},Rows8{Row{80668672,0,0,0},Row{1072218016,0,0,0},Row{2940210418,0,0,0},Row{3724544245,0,0,0},Row{3724543989,0,0,0},Row{2940210418,0,0,0},Row{1072218016,0,0,0},Row{80668688,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrllrl(code: U32) -> Glyph:
  face1rrrllrl.choose(U32.is_eq(code,246))

def face1rrrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{9318400,0,0,0},Row{11481088,0,0,0},Row{573841952,0,0,0},Row{4294967200,1,0,0},Row{1431655728,0,0,0},Row{65536,0,0,0},Row{11481088,0,0,0},Row{9318400,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrllrrl(code: U32) -> Glyph:
  face1rrrllrrl.choose(U32.is_eq(code,247))

def face1rrrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{2546919424,0,0,0},Row{2147008416,0,0,0},Row{2951810290,0,0,0},Row{3732605173,0,0,0},Row{3725175029,0,0,0},Row{2940256242,0,0,0},Row{1072218096,0,0,0},Row{80669411,0,0,0}},Rows8{Row{16,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rrrllrrr(code: U32) -> Glyph:
  face1rrrllrrr.choose(U32.is_eq(code,248))

def face1rrrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrllrrl(code)
    case False{}: face1rrrllrrr(code)

def face1rrrllrr(+code: U32) -> Glyph:
  face1rrrllrr.choose(code,U32.is_lt(code,248))

def face1rrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrllrl(code)
    case False{}: face1rrrllrr(code)

def face1rrrllr(+code: U32) -> Glyph:
  face1rrrllr.choose(code,U32.is_lt(code,247))

def face1rrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrlll(code)
    case False{}: face1rrrllr(code)

def face1rrrll(+code: U32) -> Glyph:
  face1rrrll.choose(code,U32.is_lt(code,246))

def face1rrrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{8704,0,0,0},Row{324864,0,0,0},Row{761856,0,0,0},zero_row()},Rows8{Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2673872368,0,0,0},Row{2681847728,0,0,0},Row{2672618272,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrlrll(code: U32) -> Glyph:
  face1rrrlrll.choose(U32.is_eq(code,249))

def face1rrrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{18939904,0,0,0},Row{14352384,0,0,0},Row{4141056,0,0,0},zero_row()},Rows8{Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2673872368,0,0,0},Row{2681847728,0,0,0},Row{2672618272,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrlrlrl(code: U32) -> Glyph:
  face1rrrlrlrl.choose(U32.is_eq(code,250))

def face1rrrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{8376576,0,0,0},Row{115588112,0,0,0},zero_row()},Rows8{Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2673872368,0,0,0},Row{2681847728,0,0,0},Row{2672618272,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrlrlrr(code: U32) -> Glyph:
  face1rrrlrlrr.choose(U32.is_eq(code,251))

def face1rrrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrlrlrl(code)
    case False{}: face1rrrlrlrr(code)

def face1rrrlrlr(+code: U32) -> Glyph:
  face1rrrlrlr.choose(code,U32.is_lt(code,251))

def face1rrrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrlrll(code)
    case False{}: face1rrrlrlr(code)

def face1rrrlrl(+code: U32) -> Glyph:
  face1rrrlrl.choose(code,U32.is_lt(code,250))

def face1rrrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{1048832,0,0,0},Row{166899472,0,0,0},Row{19927808,0,0,0},zero_row()},Rows8{Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2669677553,0,0,0},Row{2673872368,0,0,0},Row{2681847728,0,0,0},Row{2672618272,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrlrrll(code: U32) -> Glyph:
  face1rrrlrrll.choose(U32.is_eq(code,252))

def face1rrrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{2162688,0,0,0},Row{12386304,0,0,0},Row{3035136,0,0,0},zero_row()},Rows8{Row{3473933816,0,0,0},Row{1868565235,0,0,0},Row{531631824,0,0,0},Row{183586672,0,0,0},Row{100048672,0,0,0},Row{15391488,0,0,0},Row{10417664,0,0,0},Row{4190464,0,0,0}},Rows8{Row{909312,0,0,0},Row{522864,0,0,0},Row{40672,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rrrlrrlr(code: U32) -> Glyph:
  face1rrrlrrlr.choose(U32.is_eq(code,253))

def face1rrrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrlrrll(code)
    case False{}: face1rrrlrrlr(code)

def face1rrrlrrl(+code: U32) -> Glyph:
  face1rrrlrrl.choose(code,U32.is_lt(code,253))

def face1rrrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0}},Rows8{Row{149781489,0,0,0},Row{2413350641,0,0,0},Row{3994033905,0,0,0},Row{4211084273,1,0,0},Row{4211084273,1,0,0},Row{3994033905,0,0,0},Row{2413350641,0,0,0},Row{149847025,0,0,0}},Rows8{Row{3057,0,0,0},Row{3057,0,0,0},Row{3057,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rrrlrrrl(code: U32) -> Glyph:
  face1rrrlrrrl.choose(U32.is_eq(code,254))

def face1rrrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{1048832,0,0,0},Row{133463856,0,0,0},Row{20976640,0,0,0},zero_row()},Rows8{Row{3473933816,0,0,0},Row{1868565235,0,0,0},Row{531631824,0,0,0},Row{183586672,0,0,0},Row{100048672,0,0,0},Row{15391488,0,0,0},Row{10417664,0,0,0},Row{4190464,0,0,0}},Rows8{Row{909312,0,0,0},Row{522864,0,0,0},Row{40672,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rrrlrrrr(code: U32) -> Glyph:
  face1rrrlrrrr.choose(U32.is_eq(code,255))

def face1rrrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrlrrrl(code)
    case False{}: face1rrrlrrrr(code)

def face1rrrlrrr(+code: U32) -> Glyph:
  face1rrrlrrr.choose(code,U32.is_lt(code,255))

def face1rrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrlrrl(code)
    case False{}: face1rrrlrrr(code)

def face1rrrlrr(+code: U32) -> Glyph:
  face1rrrlrr.choose(code,U32.is_lt(code,254))

def face1rrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrlrl(code)
    case False{}: face1rrrlrr(code)

def face1rrrlr(+code: U32) -> Glyph:
  face1rrrlr.choose(code,U32.is_lt(code,252))

def face1rrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrll(code)
    case False{}: face1rrrlr(code)

def face1rrrl(+code: U32) -> Glyph:
  face1rrrl.choose(code,U32.is_lt(code,249))

def face1rrrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{zero_row(),zero_row(),Row{35791394,0,0,0},Row{268435455,0,0,0},Row{89478485,0,0,0},zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrrlll(code: U32) -> Glyph:
  face1rrrrlll.choose(U32.is_eq(code,8211))

def face1rrrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{zero_row(),zero_row(),Row{572662306,2236962,0,0},Row{4294967295,16777215,0,0},Row{1431655765,5592405,0,0},zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrrllrl(code: U32) -> Glyph:
  face1rrrrllrl.choose(U32.is_eq(code,8212))

def face1rrrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{32000,0,0,0},Row{24352,0,0,0},Row{16240,0,0,0}},Rows8{Row{8112,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrrllrr(code: U32) -> Glyph:
  face1rrrrllrr.choose(U32.is_eq(code,8216))

def face1rrrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrrllrl(code)
    case False{}: face1rrrrllrr(code)

def face1rrrrllr(+code: U32) -> Glyph:
  face1rrrrllr.choose(code,U32.is_lt(code,8216))

def face1rrrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrrlll(code)
    case False{}: face1rrrrllr(code)

def face1rrrrll(+code: U32) -> Glyph:
  face1rrrrll.choose(code,U32.is_lt(code,8212))

def face1rrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{4,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{28496,0,0,0},Row{12160,0,0,0}},Rows8{Row{3232,0,0,0},Row{2240,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrrlrl(code: U32) -> Glyph:
  face1rrrrlrl.choose(U32.is_eq(code,8217))

def face1rrrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{131104000,0,0,0},Row{99770144,0,0,0},Row{49758064,0,0,0}},Rows8{Row{16457648,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrrlrrl(code: U32) -> Glyph:
  face1rrrrlrrl.choose(U32.is_eq(code,8220))

def face1rrrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{100101968,0,0,0},Row{33107840,0,0,0}},Rows8{Row{12258464,0,0,0},Row{7145664,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrrlrrr(code: U32) -> Glyph:
  face1rrrrlrrr.choose(U32.is_eq(code,8221))

def face1rrrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrrlrrl(code)
    case False{}: face1rrrrlrrr(code)

def face1rrrrlrr(+code: U32) -> Glyph:
  face1rrrrlrr.choose(code,U32.is_lt(code,8221))

def face1rrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrrlrl(code)
    case False{}: face1rrrrlrr(code)

def face1rrrrlr(+code: U32) -> Glyph:
  face1rrrrlr.choose(code,U32.is_lt(code,8220))

def face1rrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrrll(code)
    case False{}: face1rrrrlr(code)

def face1rrrrl(+code: U32) -> Glyph:
  face1rrrrl.choose(code,U32.is_lt(code,8217))

def face1rrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{zero_row(),Row{715264,0,0,0},Row{9437040,0,0,0},Row{11534224,0,0,0},Row{9437040,0,0,0},Row{715264,0,0,0},zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrrrll(code: U32) -> Glyph:
  face1rrrrrll.choose(U32.is_eq(code,8226))

def face1rrrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{16777472,4096,0,0},Row{2940223408,195584,0,0},Row{2385522320,121344,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrrrlrl(code: U32) -> Glyph:
  face1rrrrrlrl.choose(U32.is_eq(code,8230))

def face1rrrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{33554432,0,0,0},Row{497025024,0,0,0}},Rows8{Row{116981760,0,0,0},Row{7311360,0,0,0},Row{572975104,4642,0,0},Row{4294967136,40959,0,0},Row{1431825152,13653,0,0},Row{5156864,0,0,0},Row{83562496,0,0,0},Row{514916352,0,0,0}},Rows8{Row{51380224,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rrrrrlrr(code: U32) -> Glyph:
  face1rrrrrlrr.choose(U32.is_eq(code,8592))

def face1rrrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrrrlrl(code)
    case False{}: face1rrrrrlrr(code)

def face1rrrrrlr(+code: U32) -> Glyph:
  face1rrrrrlr.choose(code,U32.is_lt(code,8592))

def face1rrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrrrll(code)
    case False{}: face1rrrrrlr(code)

def face1rrrrrl(+code: U32) -> Glyph:
  face1rrrrrl.choose(code,U32.is_lt(code,8230))

def face1rrrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{85983232,0,0,0},Row{1607598080,0,0,0},Row{4276953088,5,0,0}},Rows8{Row{2643316992,79,0,0},Row{243461136,1275,0,0},Row{243285584,2737,0,0},Row{243269888,16,0,0},Row{243269632,0,0,0},Row{243269632,0,0,0},Row{243269632,0,0,0},Row{243269632,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrrrrll(code: U32) -> Glyph:
  face1rrrrrrll.choose(U32.is_eq(code,8593))

def face1rrrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{536870912,0,0,0},Row{3623878656,2,0,0}},Rows8{Row{3791650816,45,0,0},Row{536870912,477,0,0},Row{572662288,7620,0,0},Row{4294967104,49151,0,0},Row{1431655696,16069,0,0},Row{268435456,1004,0,0},Row{3238002688,62,0,0},Row{3909091328,3,0,0}},Rows8{Row{822083584,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rrrrrrlr(code: U32) -> Glyph:
  face1rrrrrrlr.choose(U32.is_eq(code,8594))

def face1rrrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrrrrll(code)
    case False{}: face1rrrrrrlr(code)

def face1rrrrrrl(+code: U32) -> Glyph:
  face1rrrrrrl.choose(code,U32.is_lt(code,8594))

def face1rrrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{243269632,0,0,0},Row{243269632,0,0,0},Row{243269632,0,0,0}},Rows8{Row{243269632,0,0,0},Row{243269888,16,0,0},Row{243285584,2737,0,0},Row{243461392,1275,0,0},Row{2643316992,79,0,0},Row{4276953088,5,0,0},Row{1607598080,0,0,0},Row{85983232,0,0,0}},zero_rows(),zero_rows()]}
    case False{}: face1.missing()

def face1rrrrrrrl(code: U32) -> Glyph:
  face1rrrrrrrl.choose(U32.is_eq(code,8595))

def face1rrrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),Row{35791360,0,0,0},Row{251591424,0,0,0},Row{251263744,0,0,0},Row{251587328,0,0,0},Row{251239168,0,0,0}},Rows8{Row{251591424,0,0,0},Row{250215168,0,0,0},Row{245365504,0,0,0},Row{249486080,0,0,0},Row{245340928,0,0,0},Row{251656960,0,0,0},Row{244820736,0,0,0},Row{245340928,0,0,0}},Rows8{Row{250608384,0,0,0},Row{250145536,0,0,0},Row{251656960,0,0,0},Row{89478144,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face1.missing()

def face1rrrrrrrr(code: U32) -> Glyph:
  face1rrrrrrrr.choose(U32.is_eq(code,65533))

def face1rrrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrrrrrl(code)
    case False{}: face1rrrrrrrr(code)

def face1rrrrrrr(+code: U32) -> Glyph:
  face1rrrrrrr.choose(code,U32.is_lt(code,65533))

def face1rrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrrrrl(code)
    case False{}: face1rrrrrrr(code)

def face1rrrrrr(+code: U32) -> Glyph:
  face1rrrrrr.choose(code,U32.is_lt(code,8595))

def face1rrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrrrl(code)
    case False{}: face1rrrrrr(code)

def face1rrrrr(+code: U32) -> Glyph:
  face1rrrrr.choose(code,U32.is_lt(code,8593))

def face1rrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrrl(code)
    case False{}: face1rrrrr(code)

def face1rrrr(+code: U32) -> Glyph:
  face1rrrr.choose(code,U32.is_lt(code,8226))

def face1rrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrrl(code)
    case False{}: face1rrrr(code)

def face1rrr(+code: U32) -> Glyph:
  face1rrr.choose(code,U32.is_lt(code,8211))

def face1rr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rrl(code)
    case False{}: face1rrr(code)

def face1rr(+code: U32) -> Glyph:
  face1rr.choose(code,U32.is_lt(code,243))

def face1r.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1rl(code)
    case False{}: face1rr(code)

def face1r(+code: U32) -> Glyph:
  face1r.choose(code,U32.is_lt(code,218))

def face1.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face1l(code)
    case False{}: face1r(code)

def face1(+code: U32) -> Glyph:
  face1.choose(code,U32.is_lt(code,167))

def face2.missing() -> Glyph:
  Glyph{14,[Rows8{zero_row(),zero_row(),zero_row(),Row{3149615104,2747,0,0},Row{4294930432,3839,0,0},Row{9400320,3825,0,0},Row{2330947584,3838,0,0},Row{294612992,3826,0,0}},Rows8{Row{3135205376,3837,0,0},Row{2056220672,3839,0,0},Row{294612992,3826,0,0},Row{2866769920,3835,0,0},Row{1827631104,3836,0,0},Row{1905225728,3829,0,0},Row{3135205376,3828,0,0},Row{2900324352,3835,0,0}},Rows8{Row{982478848,3827,0,0},Row{3129962496,3828,0,0},Row{294612992,3826,0,0},Row{4294930432,3839,0,0},Row{1705996288,3829,0,0},Row{4237258752,3829,0,0},Row{1133473792,3826,0,0},Row{3168759808,3835,0,0}},Rows8{Row{1526689792,3836,0,0},Row{1100967936,3829,0,0},Row{3151982592,3835,0,0},Row{4294930432,3839,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}

def face2lllllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[zero_rows(),zero_rows(),zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2lllllll(code: U32) -> Glyph:
  face2lllllll.choose(U32.is_eq(code,32))

def face2llllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{Row{2096896,0,0,0},Row{1048064,0,0,0},Row{1048064,0,0,0},Row{1048064,0,0,0},Row{982528,0,0,0},Row{982272,0,0,0},Row{982272,0,0,0},Row{982272,0,0,0}},Rows8{Row{916736,0,0,0},Row{916480,0,0,0},Row{916480,0,0,0},zero_row(),zero_row(),Row{780800,0,0,0},Row{4194096,0,0,0},Row{780800,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llllllrl(code: U32) -> Glyph:
  face2llllllrl.choose(U32.is_eq(code,33))

def face2llllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[zero_rows(),Rows8{Row{4128177152,79,0,0},Row{4128111360,79,0,0},Row{4111333888,63,0,0},Row{4094490880,47,0,0},Row{4077648128,31,0,0},Row{4077582336,31,0,0},zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2llllllrr(code: U32) -> Glyph:
  face2llllllrr.choose(U32.is_eq(code,34))

def face2llllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llllllrl(code)
    case False{}: face2llllllrr(code)

def face2llllllr(+code: U32) -> Glyph:
  face2llllllr.choose(code,U32.is_lt(code,34))

def face2llllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllllll(code)
    case False{}: face2llllllr(code)

def face2llllll(+code: U32) -> Glyph:
  face2llllll.choose(code,U32.is_lt(code,33))

def face2lllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{167313408,261632,0,0},Row{117178368,130848,0,0},Row{66977792,57168,0,0},Row{33497088,44912,0,0},Row{4294967168,13631487,0,0},Row{4294967200,11534335,0,0},Row{1152365616,2387956,0,0},Row{7319552,8178,0,0}},Rows8{Row{5234688,3572,0,0},Row{1147139137,216312,0,0},Row{4294967287,851967,0,0},Row{4294967290,720895,0,0},Row{653312,1278,0,0},Row{268958464,511,0,0},Row{1074068736,239,0,0},Row{1610809104,191,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lllllrl(code: U32) -> Glyph:
  face2lllllrl.choose(U32.is_eq(code,35))

def face2lllllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3590324224,0,0,0},Row{3590324224,0,0,0}},Rows8{Row{4292349952,1742,0,0},Row{4294959872,49151,0,0},Row{3938450960,589800,0,0},Row{3591044944,982560,0,0},Row{3590782848,488704,0,0},Row{3592224608,0,0,0},Row{3706715664,1,0,0},Row{4294955776,1471,0,0}},Rows8{Row{4273274880,118783,0,0},Row{3858759680,786408,0,0},Row{3590324224,3144976,0,0},Row{3590372528,5241344,0,0},Row{3590717376,3144976,0,0},Row{3937402720,851927,0,0},Row{4294965504,192511,0,0},Row{4293611520,6350,0,0}},Rows8{Row{3590324224,0,0,0},Row{3590324224,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lllllrrl(code: U32) -> Glyph:
  face2lllllrrl.choose(U32.is_eq(code,36))

def face2lllllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{22,[zero_rows(),Rows8{Row{2113757184,3506438144,63,0},Row{4294964736,4177526790,8,0},Row{4182440704,3477078028,0,0},Row{4060347648,1070661645,0,0},Row{4182440704,133824524,0,0},Row{4294964736,12537862,0,0},Row{2113757184,3072256,0,0},Row{0,457472,0,0}},Rows8{Row{0,3288383328,1759,0},Row{0,4281343714,24575,0},Row{0,3214935547,53156,0},Row{1879048192,1337983151,61216,0},Row{4076863488,1337983005,61216,0},Row{4227858432,3214934020,53156,0},Row{2675965952,4282384384,24575,0},Row{502464512,3305111552,1759,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lllllrrr(code: U32) -> Glyph:
  face2lllllrrr.choose(U32.is_eq(code,37))

def face2lllllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllllrrl(code)
    case False{}: face2lllllrrr(code)

def face2lllllrr(+code: U32) -> Glyph:
  face2lllllrr.choose(code,U32.is_lt(code,37))

def face2lllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllllrl(code)
    case False{}: face2lllllrr(code)

def face2lllllr(+code: U32) -> Glyph:
  face2lllllr.choose(code,U32.is_lt(code,36))

def face2lllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llllll(code)
    case False{}: face2lllllr(code)

def face2lllll(+code: U32) -> Glyph:
  face2lllll.choose(code,U32.is_lt(code,35))

def face2llllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[zero_rows(),Rows8{Row{3755544576,25,0,0},Row{4294955264,479,0,0},Row{2493511424,1791,0,0},Row{981504,2301,0,0},Row{269416448,1534,0,0},Row{3531600640,191,0,0},Row{4278153216,26,0,0},Row{2952757248,0,0,0}},Rows8{Row{4294965760,7335941,0,0},Row{4247453568,6288190,0,0},Row{3808489440,3144159,0,0},Row{1342226416,917503,0,0},Row{126944,458744,0,0},Row{1970077568,458750,0,0},Row{4294966016,5242367,0,0},Row{3756810240,49275449,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llllrll(code: U32) -> Glyph:
  face2llllrll.choose(U32.is_eq(code,38))

def face2llllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{Row{982016,0,0,0},Row{916224,0,0,0},Row{915968,0,0,0},Row{850176,0,0,0},Row{784640,0,0,0},Row{718848,0,0,0},zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2llllrlrl(code: U32) -> Glyph:
  face2llllrlrl.choose(U32.is_eq(code,39))

def face2llllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1073217536,0,0,0}},Rows8{Row{217976832,0,0,0},Row{117403648,0,0,0},Row{33538048,0,0,0},Row{13627904,0,0,0},Row{9434624,0,0,0},Row{5241088,0,0,0},Row{2095872,0,0,0},Row{982272,0,0,0}},Rows8{Row{916992,0,0,0},Row{917248,0,0,0},Row{916992,0,0,0},Row{1047808,0,0,0},Row{3144192,0,0,0},Row{6289152,0,0,0},Row{11531008,0,0,0},Row{15716352,0,0,0}},Rows8{Row{100630528,0,0,0},Row{201199616,0,0,0},Row{804716544,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2llllrlrr(code: U32) -> Glyph:
  face2llllrlrr.choose(U32.is_eq(code,40))

def face2llllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llllrlrl(code)
    case False{}: face2llllrlrr(code)

def face2llllrlr(+code: U32) -> Glyph:
  face2llllrlr.choose(code,U32.is_lt(code,40))

def face2llllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llllrll(code)
    case False{}: face2llllrlr(code)

def face2llllrl(+code: U32) -> Glyph:
  face2llllrl.choose(code,U32.is_lt(code,39))

def face2llllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{49121,0,0,0}},Rows8{Row{262032,0,0,0},Row{720688,0,0,0},Row{2030592,0,0,0},Row{6289408,0,0,0},Row{9434112,0,0,0},Row{13627648,0,0,0},Row{15716352,0,0,0},Row{33533952,0,0,0}},Rows8{Row{50307072,0,0,0},Row{67084288,0,0,0},Row{50307072,0,0,0},Row{33538048,0,0,0},Row{14671872,0,0,0},Row{11530752,0,0,0},Row{7337728,0,0,0},Row{2095872,0,0,0}},Rows8{Row{720672,0,0,0},Row{262016,0,0,0},Row{45024,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2llllrrl(code: U32) -> Glyph:
  face2llllrrl.choose(U32.is_eq(code,41))

def face2llllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[zero_rows(),Rows8{Row{233832448,0,0,0},Row{216007680,49,0,0},Row{1272172048,477,0,0},Row{4278188320,415,0,0},Row{3757977600,2,0,0},Row{4294960912,126,0,0},Row{1809178400,494,0,0},Row{216012032,65,0,0}},Rows8{Row{233832448,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2llllrrrl(code: U32) -> Glyph:
  face2llllrrrl.choose(U32.is_eq(code,42))

def face2llllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{4227858432,9,0,0},Row{4227858432,9,0,0},Row{4227858432,9,0,0},Row{4227858432,9,0,0}},Rows8{Row{4249109504,214091,0,0},Row{4294967040,851967,0,0},Row{4294967040,851967,0,0},Row{4227858432,9,0,0},Row{4227858432,9,0,0},Row{4227858432,9,0,0},Row{4227858432,9,0,0},zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2llllrrrr(code: U32) -> Glyph:
  face2llllrrrr.choose(U32.is_eq(code,43))

def face2llllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llllrrrl(code)
    case False{}: face2llllrrrr(code)

def face2llllrrr(+code: U32) -> Glyph:
  face2llllrrr.choose(code,U32.is_lt(code,43))

def face2llllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llllrrl(code)
    case False{}: face2llllrrr(code)

def face2llllrr(+code: U32) -> Glyph:
  face2llllrr.choose(code,U32.is_lt(code,42))

def face2llllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llllrl(code)
    case False{}: face2llllrr(code)

def face2llllr(+code: U32) -> Glyph:
  face2llllr.choose(code,U32.is_lt(code,41))

def face2llll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllll(code)
    case False{}: face2llllr(code)

def face2llll(+code: U32) -> Glyph:
  face2llll.choose(code,U32.is_lt(code,38))

def face2lllrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2030592,0,0,0}},Rows8{Row{720384,0,0,0},Row{458528,0,0,0},Row{130880,0,0,0},Row{49008,0,0,0},Row{32656,0,0,0},zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lllrlll(code: U32) -> Glyph:
  face2lllrlll.choose(U32.is_eq(code,44))

def face2lllrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[zero_rows(),zero_rows(),Rows8{Row{1145324576,3,0,0},Row{4294967152,11,0,0},Row{4294967152,11,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2lllrllrl(code: U32) -> Glyph:
  face2lllrllrl.choose(U32.is_eq(code,45))

def face2lllrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{715264,0,0,0},Row{4194080,0,0,0},Row{715264,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lllrllrr(code: U32) -> Glyph:
  face2lllrllrr.choose(U32.is_eq(code,46))

def face2lllrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllrllrl(code)
    case False{}: face2lllrllrr(code)

def face2lllrllr(+code: U32) -> Glyph:
  face2lllrllr.choose(code,U32.is_lt(code,46))

def face2lllrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllrlll(code)
    case False{}: face2lllrllr(code)

def face2lllrll(+code: U32) -> Glyph:
  face2lllrll.choose(code,U32.is_lt(code,45))

def face2lllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3482320896,0,0,0}},Rows8{Row{2412773376,0,0,0},Row{1341259776,0,0,0},Row{536281088,0,0,0},Row{200998912,0,0,0},Row{134086656,0,0,0},Row{67059712,0,0,0},Row{15695872,0,0,0},Row{11517952,0,0,0}},Rows8{Row{7336192,0,0,0},Row{3142912,0,0,0},Row{915712,0,0,0},Row{654592,0,0,0},Row{392992,0,0,0},Row{130912,0,0,0},Row{49056,0,0,0},Row{32736,0,0,0}},Rows8{Row{16372,0,0,0},Row{3832,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lllrlrl(code: U32) -> Glyph:
  face2lllrlrl.choose(U32.is_eq(code,47))

def face2lllrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[zero_rows(),Rows8{Row{4273274880,669,0,0},Row{4294942720,16127,0,0},Row{1189083136,126969,0,0},Row{3079952,655232,0,0},Row{589664,982544,0,0},Row{327584,3144448,0,0},Row{131008,6289664,0,0},Row{65488,7337984,0,0}},Rows8{Row{65488,7337984,0,0},Row{131008,6289664,0,0},Row{327584,4193024,0,0},Row{589680,982544,0,0},Row{2031376,655232,0,0},Row{1189083136,126969,0,0},Row{4294942720,20223,0,0},Row{4273274880,669,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lllrlrrl(code: U32) -> Glyph:
  face2lllrlrrl.choose(U32.is_eq(code,48))

def face2lllrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{Row{3221110784,0,0,0},Row{3221223168,0,0,0},Row{3221159840,0,0,0},Row{3220414448,0,0,0},Row{3220309472,0,0,0},Row{3220307984,0,0,0},Row{3220307968,0,0,0},Row{3220307968,0,0,0}},Rows8{Row{3220307968,0,0,0},Row{3220307968,0,0,0},Row{3220307968,0,0,0},Row{3220307968,0,0,0},Row{3220307968,0,0,0},Row{3220307968,0,0,0},Row{3220307968,0,0,0},Row{3220307968,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lllrlrrr(code: U32) -> Glyph:
  face2lllrlrrr.choose(U32.is_eq(code,49))

def face2lllrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllrlrrl(code)
    case False{}: face2lllrlrrr(code)

def face2lllrlrr(+code: U32) -> Glyph:
  face2lllrlrr.choose(code,U32.is_lt(code,49))

def face2lllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllrlrl(code)
    case False{}: face2lllrlrr(code)

def face2lllrlr(+code: U32) -> Glyph:
  face2lllrlr.choose(code,U32.is_lt(code,48))

def face2lllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllrll(code)
    case False{}: face2lllrlr(code)

def face2lllrl(+code: U32) -> Glyph:
  face2lllrl.choose(code,U32.is_lt(code,47))

def face2lllrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{4023984128,107,0,0},Row{4294960128,3071,0,0},Row{1703935504,36860,0,0},Row{524128,61409,0,0},Row{192128,196512,0,0},Row{0,130992,0,0},Row{0,49139,0,0},Row{268435456,16381,0,0}},Rows8{Row{3238002688,2047,0,0},Row{4228907008,159,0,0},Row{4290838528,9,0,0},Row{2684096512,0,0,0},Row{184537344,0,0,0},Row{1154481424,83012,0,0},Row{4294967168,458751,0,0},Row{4294967168,458751,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lllrrll(code: U32) -> Glyph:
  face2lllrrll.choose(U32.is_eq(code,50))

def face2lllrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{4006088704,396,0,0},Row{4294959872,12031,0,0},Row{1436548624,53242,0,0},Row{589664,262064,0,0},Row{157232,327552,0,0},Row{0,131008,0,0},Row{1412431872,32763,0,0},Row{4289724416,1487,0,0}},Rows8{Row{4289724416,19711,0,0},Row{536870912,327654,0,0},Row{0,786256,0,0},Row{21824,917280,0,0},Row{458656,786272,0,0},Row{1435500352,327673,0,0},Row{4294964992,28671,0,0},Row{4007211008,669,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lllrrlrl(code: U32) -> Glyph:
  face2lllrrlrl.choose(U32.is_eq(code,51))

def face2lllrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[zero_rows(),Rows8{Row{1610612736,36863,0,0},Row{3774873600,36863,0,0},Row{4194304000,36863,0,0},Row{4282384384,36860,0,0},Row{4023451648,36852,0,0},Row{1610088448,36851,0,0},Row{201273344,36851,0,0},Row{49266688,36851,0,0}},Rows8{Row{8386048,36851,0,0},Row{851488,36851,0,0},Row{1431895968,3518455,0,0},Row{4294967248,10485759,0,0},Row{4294967248,10485759,0,0},Row{0,36852,0,0},Row{0,36852,0,0},Row{0,36852,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lllrrlrr(code: U32) -> Glyph:
  face2lllrrlrr.choose(U32.is_eq(code,52))

def face2lllrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllrrlrl(code)
    case False{}: face2lllrrlrr(code)

def face2lllrrlr(+code: U32) -> Glyph:
  face2lllrrlr.choose(code,U32.is_lt(code,52))

def face2lllrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllrrll(code)
    case False{}: face2lllrrlr(code)

def face2lllrrl(+code: U32) -> Glyph:
  face2lllrrl.choose(code,U32.is_lt(code,51))

def face2lllrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{4294966272,36863,0,0},Row{4294966528,36863,0,0},Row{1145765632,9284,0,0},Row{524064,0,0,0},Row{458544,0,0,0},Row{4002807632,125,0,0},Row{4294901600,7423,0,0},Row{1954414464,40958,0,0}},Rows8{Row{82176,131042,0,0},Row{0,327568,0,0},Row{0,393072,0,0},Row{35184,262032,0,0},Row{327584,61409,0,0},Row{1687093056,32765,0,0},Row{4294964992,2559,0,0},Row{4023988224,75,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lllrrrll(code: U32) -> Glyph:
  face2lllrrrll.choose(U32.is_eq(code,53))

def face2lllrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{4272160768,669,0,0},Row{4294930432,24319,0,0},Row{1189082368,192504,0,0},Row{3079424,589664,0,0},Row{524096,358160,0,0},Row{822345616,19,0,0},Row{4269866928,6639,0,0},Row{4294569920,53247,0,0}},Rows8{Row{311427024,524244,0,0},Row{655296,851760,0,0},Row{327600,982272,0,0},Row{393088,916992,0,0},Row{786224,720720,0,0},Row{1171257856,262136,0,0},Row{4294947072,24319,0,0},Row{4273340416,669,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lllrrrlr(code: U32) -> Glyph:
  face2lllrrrlr.choose(U32.is_eq(code,54))

def face2lllrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllrrrll(code)
    case False{}: face2lllrrrlr(code)

def face2lllrrrl(+code: U32) -> Glyph:
  face2lllrrrl.choose(code,U32.is_lt(code,54))

def face2lllrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{4294967282,53247,0,0},Row{4294967282,53247,0,0},Row{1145324608,49144,0,0},Row{0,20476,0,0},Row{1342177280,3071,0,0},Row{3221225472,1279,0,0},Row{4110417920,191,0,0},Row{4227858432,79,0,0}},Rows8{Row{4283432960,11,0,0},Row{4290772992,4,0,0},Row{3220439040,0,0,0},Row{1073479680,0,0,0},Row{201277440,0,0,0},Row{67092480,0,0,0},Row{12579840,0,0,0},Row{4193280,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lllrrrrl(code: U32) -> Glyph:
  face2lllrrrrl.choose(U32.is_eq(code,55))

def face2lllrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{4006088704,397,0,0},Row{4294959872,16127,0,0},Row{1437596928,57338,0,0},Row{786224,327600,0,0},Row{589632,393072,0,0},Row{851728,196528,0,0},Row{1438643968,36858,0,0},Row{4294791168,1519,0,0}},Rows8{Row{4294956032,24319,0,0},Row{291438384,327653,0,0},Row{393120,851776,0,0},Row{131024,982800,0,0},Row{458672,917328,0,0},Row{1436548944,458728,0,0},Row{4294965248,40959,0,0},Row{4007211008,925,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lllrrrrr(code: U32) -> Glyph:
  face2lllrrrrr.choose(U32.is_eq(code,56))

def face2lllrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllrrrrl(code)
    case False{}: face2lllrrrrr(code)

def face2lllrrrr(+code: U32) -> Glyph:
  face2lllrrrr.choose(code,U32.is_lt(code,56))

def face2lllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllrrrl(code)
    case False{}: face2lllrrrr(code)

def face2lllrrr(+code: U32) -> Glyph:
  face2lllrrr.choose(code,U32.is_lt(code,55))

def face2lllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllrrl(code)
    case False{}: face2lllrrr(code)

def face2lllrr(+code: U32) -> Glyph:
  face2lllrr.choose(code,U32.is_lt(code,53))

def face2lllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lllrl(code)
    case False{}: face2lllrr(code)

def face2lllr(+code: U32) -> Glyph:
  face2lllr.choose(code,U32.is_lt(code,50))

def face2lll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llll(code)
    case False{}: face2lllr(code)

def face2lll(+code: U32) -> Glyph:
  face2lll.choose(code,U32.is_lt(code,44))

def face2llrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{4007141376,108,0,0},Row{4294960128,7423,0,0},Row{1419771424,49147,0,0},Row{524160,327584,0,0},Row{65472,655152,0,0},Row{61392,851760,0,0},Row{327600,982912,0,0},Row{291438432,983032,0,0}},Rows8{Row{4294966016,916911,0,0},Row{4026433536,851464,0,0},Row{321978368,720656,0,0},Row{96080,458592,0,0},Row{589680,126929,0,0},Row{1687158288,28669,0,0},Row{4294960128,2303,0,0},Row{3755548672,75,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrllll(code: U32) -> Glyph:
  face2llrllll.choose(U32.is_eq(code,57))

def face2llrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{715264,0,0,0},Row{4194080,0,0,0},Row{715264,0,0,0}},Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{715264,0,0,0},Row{4194080,0,0,0},Row{715264,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrlllrl(code: U32) -> Glyph:
  face2llrlllrl.choose(U32.is_eq(code,58))

def face2llrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2942720,0,0,0},Row{7339520,0,0,0},Row{2942720,0,0,0}},Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2030592,0,0,0}},Rows8{Row{720384,0,0,0},Row{458528,0,0,0},Row{130880,0,0,0},Row{49008,0,0,0},Row{32656,0,0,0},zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2llrlllrr(code: U32) -> Glyph:
  face2llrlllrr.choose(U32.is_eq(code,59))

def face2llrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrlllrl(code)
    case False{}: face2llrlllrr(code)

def face2llrlllr(+code: U32) -> Glyph:
  face2llrlllr.choose(code,U32.is_lt(code,59))

def face2llrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrllll(code)
    case False{}: face2llrlllr(code)

def face2llrlll(+code: U32) -> Glyph:
  face2llrlll.choose(code,U32.is_lt(code,58))

def face2llrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),Row{0,131072,0,0},Row{0,583440,0,0},Row{536870912,589800,0,0},Row{4179623936,315391,0,0},Row{4294586368,943,0,0}},Rows8{Row{2399140880,2,0,0},Row{8388400,0,0,0},Row{973078304,0,0,0},Row{4294869248,92,0,0},Row{4252041216,97791,0,0},Row{1610612736,589821,0,0},Row{0,588880,0,0},Row{0,278528,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrllrl(code: U32) -> Glyph:
  face2llrllrl.choose(U32.is_eq(code,60))

def face2llrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1145324288,148548,0,0},Row{4294966272,655359,0,0},Row{4294966272,655359,0,0}},Rows8{zero_row(),zero_row(),Row{1145324288,148548,0,0},Row{4294966272,655359,0,0},Row{4294966272,655359,0,0},zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2llrllrrl(code: U32) -> Glyph:
  face2llrllrrl.choose(U32.is_eq(code,61))

def face2llrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),Row{768,0,0,0},Row{449024,0,0,0},Row{401603072,0,0,0},Row{4026520832,24,0,0},Row{4289986560,10751,0,0}},Rows8{Row{2449473536,720894,0,0},Row{0,1048465,0,0},Row{1073741824,983035,0,0},Row{4250992640,97791,0,0},Row{4294869504,108,0,0},Row{1560279552,0,0,0},Row{3865088,0,0,0},Row{9728,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrllrrr(code: U32) -> Glyph:
  face2llrllrrr.choose(U32.is_eq(code,62))

def face2llrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrllrrl(code)
    case False{}: face2llrllrrr(code)

def face2llrllrr(+code: U32) -> Glyph:
  face2llrllrr.choose(code,U32.is_lt(code,62))

def face2llrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrllrl(code)
    case False{}: face2llrllrr(code)

def face2llrllr(+code: U32) -> Glyph:
  face2llrllr.choose(code,U32.is_lt(code,61))

def face2llrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrlll(code)
    case False{}: face2llrllr(code)

def face2llrll(+code: U32) -> Glyph:
  face2llrll.choose(code,U32.is_lt(code,60))

def face2llrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[zero_rows(),Rows8{Row{3471671552,6,0,0},Row{4294966560,191,0,0},Row{3596353440,2047,0,0},Row{805363696,3327,0,0},Row{18289,3583,0,0},Row{1342177280,3071,0,0},Row{4127195136,1279,0,0},Row{4287627264,111,0,0}},Rows8{Row{3757441024,3,0,0},Row{804913152,0,0,0},Row{217841664,0,0,0},Row{72613888,0,0,0},zero_row(),Row{183177216,0,0,0},Row{805257216,0,0,0},Row{183177216,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrlrll(code: U32) -> Glyph:
  face2llrlrll.choose(U32.is_eq(code,63))

def face2llrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{22,[zero_rows(),Rows8{Row{1912602624,667811547,0,0},Row{4287692800,4294967295,26,0},Row{4026343424,4253435242,735,0},Row{419418368,1342177280,7678,0},Row{7337984,606085904,40930,0},Row{269156112,2676752378,196448,0},Row{3221421920,2684354559,523776,0},Row{4127252384,2683838831,719360,0}},Rows8{Row{4211126208,2680160264,849920,0},Row{4261453776,2675965956,915200,0},Row{4261449680,2675965955,849664,0},Row{4244680640,2678063109,719104,0},Row{4194357152,2682322955,588800,0},Row{4110614384,4026360991,262021,0},Row{2685009696,4268752895,45055,0},Row{6289664,3272007639,2270,0}},Rows8{Row{419418368,0,0,0},Row{4026347520,2825209194,0,0},Row{4288741376,4294967295,4,0},Row{1912602624,1506738139,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2llrlrlrl(code: U32) -> Glyph:
  face2llrlrlrl.choose(U32.is_eq(code,64))

def face2llrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[zero_rows(),Rows8{Row{4279238656,239,0,0},Row{4284481536,1279,0,0},Row{3752853504,2815,0,0},Row{2683437056,7931,0,0},Row{1610022912,28663,0,0},Row{536608768,49139,0,0},Row{218046464,131024,0,0},Row{134184960,524176,0,0}},Rows8{Row{50319360,851776,0,0},Row{1156576000,3145284,0,0},Row{4294965248,9437183,0,0},Row{4294966528,14680063,0,0},Row{851776,67096576,0,0},Row{524176,167739392,0,0},Row{196576,251604992,0,0},Row{57332,1610416128,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrlrlrr(code: U32) -> Glyph:
  face2llrlrlrr.choose(U32.is_eq(code,65))

def face2llrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrlrlrl(code)
    case False{}: face2llrlrlrr(code)

def face2llrlrlr(+code: U32) -> Glyph:
  face2llrlrlr.choose(code,U32.is_lt(code,65))

def face2llrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrlrll(code)
    case False{}: face2llrlrlr(code)

def face2llrlrl(+code: U32) -> Glyph:
  face2llrlrl.choose(code,U32.is_lt(code,64))

def face2llrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[zero_rows(),Rows8{Row{4294967136,1998,0,0},Row{4294967136,118783,0,0},Row{1145700192,589799,0,0},Row{524128,851760,0,0},Row{524128,917248,0,0},Row{524128,720704,0,0},Row{1145700192,188391,0,0},Row{4294967136,6911,0,0}},Rows8{Row{4294967136,253951,0,0},Row{524128,1965954,0,0},Row{524128,6289920,0,0},Row{524128,8386304,0,0},Row{524128,7338496,0,0},Row{1145700192,3145637,0,0},Row{4294967136,458751,0,0},Row{4294967136,14814,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrlrrll(code: U32) -> Glyph:
  face2llrlrrll.choose(U32.is_eq(code,66))

def face2llrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[zero_rows(),Rows8{Row{3680567296,27631,0,0},Row{4294778880,3014655,0,0},Row{1811931648,31456356,0,0},Row{9436160,167743488,0,0},Row{786224,251531264,0,0},Row{393104,339935232,0,0},Row{196528,0,0,0},Row{65488,0,0,0}},Rows8{Row{65488,0,0,0},Row{196528,0,0,0},Row{393104,339935232,0,0},Row{786224,251531264,0,0},Row{8387584,167743488,0,0},Row{1811931648,31456356,0,0},Row{4294782976,2949119,0,0},Row{3680567296,27615,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrlrrlr(code: U32) -> Glyph:
  face2llrlrrlr.choose(U32.is_eq(code,67))

def face2llrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrlrrll(code)
    case False{}: face2llrlrrlr(code)

def face2llrlrrl(+code: U32) -> Glyph:
  face2llrlrrl.choose(code,U32.is_lt(code,67))

def face2llrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[zero_rows(),Rows8{Row{4026531680,1453,0,0},Row{4294967136,184319,0,0},Row{1145700192,2031559,0,0},Row{524128,11532288,0,0},Row{524128,50315264,0,0},Row{524128,134176768,0,0},Row{524128,167714816,0,0},Row{524128,201265152,0,0}},Rows8{Row{524128,201265152,0,0},Row{524128,167718912,0,0},Row{524128,134176768,0,0},Row{524128,50315264,0,0},Row{524128,11532288,0,0},Row{1145700192,2031559,0,0},Row{4294967136,184319,0,0},Row{4026531680,1453,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrlrrrl(code: U32) -> Glyph:
  face2llrlrrrl.choose(U32.is_eq(code,68))

def face2llrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{4294967136,65535,0,0},Row{4294967136,65535,0,0},Row{1145700192,17476,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{4294967136,32767,0,0}},Rows8{Row{4294967136,32767,0,0},Row{1145700192,9284,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{1145700192,17476,0,0},Row{4294967136,131071,0,0},Row{4294967136,131071,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrlrrrr(code: U32) -> Glyph:
  face2llrlrrrr.choose(U32.is_eq(code,69))

def face2llrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrlrrrl(code)
    case False{}: face2llrlrrrr(code)

def face2llrlrrr(+code: U32) -> Glyph:
  face2llrlrrr.choose(code,U32.is_lt(code,69))

def face2llrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrlrrl(code)
    case False{}: face2llrlrrr(code)

def face2llrlrr(+code: U32) -> Glyph:
  face2llrlrr.choose(code,U32.is_lt(code,68))

def face2llrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrlrl(code)
    case False{}: face2llrlrr(code)

def face2llrlr(+code: U32) -> Glyph:
  face2llrlr.choose(code,U32.is_lt(code,66))

def face2llrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrll(code)
    case False{}: face2llrlr(code)

def face2llrl(+code: U32) -> Glyph:
  face2llrl.choose(code,U32.is_lt(code,63))

def face2llrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{4294967136,57343,0,0},Row{4294967136,57343,0,0},Row{1145700192,13380,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{4294967136,12287,0,0}},Rows8{Row{4294967136,12287,0,0},Row{1145700192,5188,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrrlll(code: U32) -> Glyph:
  face2llrrlll.choose(U32.is_eq(code,70))

def face2llrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[zero_rows(),Rows8{Row{3679453184,23519,0,0},Row{4294778880,2949119,0,0},Row{1828708864,31456356,0,0},Row{9435904,167747584,0,0},Row{851760,251596800,0,0},Row{458640,35717120,0,0},Row{196528,0,0,0},Row{65488,340018241,0,0}},Rows8{Row{65488,1610612723,0,0},Row{196528,1610612723,0,0},Row{393104,1073217536,0,0},Row{786240,536608768,0,0},Row{9436160,184508416,0,0},Row{1811931648,49281620,0,0},Row{4294782976,4063231,0,0},Row{3680567296,93167,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrrllrl(code: U32) -> Glyph:
  face2llrrllrl.choose(U32.is_eq(code,71))

def face2llrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[zero_rows(),Rows8{Row{524128,218042368,0,0},Row{524128,218042368,0,0},Row{524128,218042368,0,0},Row{524128,218042368,0,0},Row{524128,218042368,0,0},Row{524128,218042368,0,0},Row{1145700192,218059844,0,0},Row{4294967136,218103807,0,0}},Rows8{Row{4294967136,218103807,0,0},Row{524128,218042368,0,0},Row{524128,218042368,0,0},Row{524128,218042368,0,0},Row{524128,218042368,0,0},Row{524128,218042368,0,0},Row{524128,218042368,0,0},Row{524128,218042368,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrrllrr(code: U32) -> Glyph:
  face2llrrllrr.choose(U32.is_eq(code,72))

def face2llrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrrllrl(code)
    case False{}: face2llrrllrr(code)

def face2llrrllr(+code: U32) -> Glyph:
  face2llrrllr.choose(code,U32.is_lt(code,72))

def face2llrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrrlll(code)
    case False{}: face2llrrllr(code)

def face2llrrll(+code: U32) -> Glyph:
  face2llrrll.choose(code,U32.is_lt(code,71))

def face2llrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[zero_rows(),Rows8{Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0}},Rows8{Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrrlrl(code: U32) -> Glyph:
  face2llrrlrl.choose(U32.is_eq(code,73))

def face2llrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{0,12283,0,0},Row{0,12283,0,0},Row{0,12283,0,0},Row{0,12283,0,0},Row{0,12283,0,0},Row{0,12283,0,0},Row{0,12283,0,0},Row{0,12283,0,0}},Rows8{Row{0,12283,0,0},Row{0,12283,0,0},Row{31666,12283,0,0},Row{49138,12283,0,0},Row{268562416,3838,0,0},Row{3311206304,2815,0,0},Row{4294966560,479,0,0},Row{3757932800,24,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrrlrrl(code: U32) -> Glyph:
  face2llrrlrrl.choose(U32.is_eq(code,74))

def face2llrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[zero_rows(),Rows8{Row{524128,100660224,0,0},Row{524128,8388128,0,0},Row{524128,655313,0,0},Row{524128,49148,0,0},Row{2684878688,7423,0,0},Row{4161273696,479,0,0},Row{4283957088,62,0,0},Row{4293459808,29,0,0}},Rows8{Row{4294967136,175,0,0},Row{3555721056,1535,0,0},Row{1077870432,12031,0,0},Row{589664,49145,0,0},Row{524128,524241,0,0},Row{524128,4194096,0,0},Row{524128,13629440,0,0},Row{524128,150978560,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrrlrrr(code: U32) -> Glyph:
  face2llrrlrrr.choose(U32.is_eq(code,75))

def face2llrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrrlrrl(code)
    case False{}: face2llrrlrrr(code)

def face2llrrlrr(+code: U32) -> Glyph:
  face2llrrlrr.choose(code,U32.is_lt(code,75))

def face2llrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrrlrl(code)
    case False{}: face2llrrlrr(code)

def face2llrrlr(+code: U32) -> Glyph:
  face2llrrlr.choose(code,U32.is_lt(code,74))

def face2llrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrrll(code)
    case False{}: face2llrrlr(code)

def face2llrrl(+code: U32) -> Glyph:
  face2llrrl.choose(code,U32.is_lt(code,73))

def face2llrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[zero_rows(),Rows8{Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0}},Rows8{Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{1718288224,13926,0,0},Row{4294967136,36863,0,0},Row{4294967136,36863,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrrrll(code: U32) -> Glyph:
  face2llrrrll.choose(U32.is_eq(code,76))

def face2llrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{20,[zero_rows(),Rows8{Row{50331488,4227858432,2815,0},Row{134217568,4281335808,2815,0},Row{234880864,4286578688,2815,0},Row{1073545056,3487563776,2815,0},Row{2683895648,2415132672,2815,0},Row{4023844704,1341784064,2815,0},Row{4288085856,754847749,2815,0},Row{4282842976,939483146,2815,0}},Rows8{Row{4245094240,855617567,2815,0},Row{4161208160,818934111,2815,0},Row{4060544864,812643487,2815,0},Row{2953248608,807401695,2815,0},Row{1611071328,806026751,2815,0},Row{268894048,805634046,2815,0},Row{458592,805367802,2815,0},Row{458592,805343220,2815,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrrrlrl(code: U32) -> Glyph:
  face2llrrrlrl.choose(U32.is_eq(code,77))

def face2llrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{17,[zero_rows(),Rows8{Row{4194144,536608768,0,0},Row{13631328,536608768,0,0},Row{117440352,536608768,0,0},Row{788528992,536608768,0,0},Row{2952396640,536608768,0,0},Row{4290183008,536608772,0,0},Row{4281859936,536608797,0,0},Row{4161339232,536608911,0,0}},Rows8{Row{3507027808,536609791,0,0},Row{1342766944,536611839,0,0},Row{589664,536633338,0,0},Row{589664,536600545,0,0},Row{589664,536805216,0,0},Row{589664,536869632,0,0},Row{589664,536867328,0,0},Row{589664,536834048,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrrrlrr(code: U32) -> Glyph:
  face2llrrrlrr.choose(U32.is_eq(code,78))

def face2llrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrrrlrl(code)
    case False{}: face2llrrrlrr(code)

def face2llrrrlr(+code: U32) -> Glyph:
  face2llrrrlr.choose(code,U32.is_lt(code,78))

def face2llrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrrrll(code)
    case False{}: face2llrrrlr(code)

def face2llrrrl(+code: U32) -> Glyph:
  face2llrrrl.choose(code,U32.is_lt(code,77))

def face2llrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{17,[zero_rows(),Rows8{Row{3680501760,23519,0,0},Row{4294778880,2949119,0,0},Row{1811931648,31456356,0,0},Row{8387328,184520704,0,0},Row{786224,805109760,0,0},Row{393104,2146893824,0,0},Row{196528,2951938048,0,0},Row{65488,3220307968,0,0}},Rows8{Row{65488,3220307968,0,0},Row{196528,2951938048,0,0},Row{393104,2146893824,0,0},Row{786224,805109760,0,0},Row{8387584,184520704,0,0},Row{1811931648,31456356,0,0},Row{4294778880,2949119,0,0},Row{3680501760,23519,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrrrrll(code: U32) -> Glyph:
  face2llrrrrll.choose(U32.is_eq(code,79))

def face2llrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{4294967136,1726,0,0},Row{4294967136,49151,0,0},Row{1414135648,589799,0,0},Row{524128,982832,0,0},Row{524128,3144704,0,0},Row{524128,4193280,0,0},Row{524128,2096656,0,0},Row{268959584,720835,0,0}},Rows8{Row{4294967136,192511,0,0},Row{4294967136,6895,0,0},Row{1145700192,18,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrrrrlr(code: U32) -> Glyph:
  face2llrrrrlr.choose(U32.is_eq(code,80))

def face2llrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrrrrll(code)
    case False{}: face2llrrrrlr(code)

def face2llrrrrl(+code: U32) -> Glyph:
  face2llrrrrl.choose(code,U32.is_lt(code,80))

def face2llrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{17,[zero_rows(),Rows8{Row{3680501760,23519,0,0},Row{4294778880,2949119,0,0},Row{2936005120,31456937,0,0},Row{28310272,184533248,0,0},Row{917296,805179392,0,0},Row{458640,2146893824,0,0},Row{196528,2952003584,0,0},Row{65488,3220307968,0,0}},Rows8{Row{65488,3220307968,0,0},Row{196528,2952003584,0,0},Row{537329552,2146894455,0,0},Row{851760,805186811,0,0},Row{28310528,184545233,0,0},Row{2936005120,31457225,0,0},Row{4294778880,8388607,0,0},Row{3680501760,66042863,0,0}},Rows8{Row{0,771424256,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2llrrrrrl(code: U32) -> Glyph:
  face2llrrrrrl.choose(U32.is_eq(code,81))

def face2llrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{4294967136,1726,0,0},Row{4294967136,114687,0,0},Row{1145700192,589799,0,0},Row{524128,982832,0,0},Row{524128,4193280,0,0},Row{524128,4193024,0,0},Row{524128,2096656,0,0},Row{268959584,786355,0,0}},Rows8{Row{4294967136,258047,0,0},Row{4294967136,11263,0,0},Row{1951006560,3071,0,0},Row{524128,24573,0,0},Row{524128,57333,0,0},Row{524128,458672,0,0},Row{524128,2031408,0,0},Row{524128,9435648,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2llrrrrrr(code: U32) -> Glyph:
  face2llrrrrrr.choose(U32.is_eq(code,82))

def face2llrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrrrrrl(code)
    case False{}: face2llrrrrrr(code)

def face2llrrrrr(+code: U32) -> Glyph:
  face2llrrrrr.choose(code,U32.is_lt(code,82))

def face2llrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrrrrl(code)
    case False{}: face2llrrrrr(code)

def face2llrrrr(+code: U32) -> Glyph:
  face2llrrrr.choose(code,U32.is_lt(code,81))

def face2llrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrrrl(code)
    case False{}: face2llrrrr(code)

def face2llrrr(+code: U32) -> Glyph:
  face2llrrr.choose(code,U32.is_lt(code,79))

def face2llrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrrl(code)
    case False{}: face2llrrr(code)

def face2llrr(+code: U32) -> Glyph:
  face2llrr.choose(code,U32.is_lt(code,76))

def face2llr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2llrl(code)
    case False{}: face2llrr(code)

def face2llr(+code: U32) -> Glyph:
  face2llr.choose(code,U32.is_lt(code,70))

def face2ll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lll(code)
    case False{}: face2llr(code)

def face2ll(+code: U32) -> Glyph:
  face2ll.choose(code,U32.is_lt(code,57))

def face2lrlllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{4274458624,1453,0,0},Row{4294955776,45055,0,0},Row{1169161472,589783,0,0},Row{655184,982560,0,0},Row{458608,418816,0,0},Row{3014496,0,0,0},Row{1811938832,2,0,0},Row{4294956032,6095,0,0}},Rows8{Row{4290121728,188415,0,0},Row{1090519040,851945,0,0},Row{0,3144992,0,0},Row{43936,5241344,0,0},Row{393136,3144976,0,0},Row{1168113488,720855,0,0},Row{4294964992,118783,0,0},Row{4275646464,1726,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrlllll(code: U32) -> Glyph:
  face2lrlllll.choose(U32.is_eq(code,83))

def face2lrllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[zero_rows(),Rows8{Row{4294967282,10485759,0,0},Row{4294967282,10485759,0,0},Row{4284761152,2376780,0,0},Row{4281335808,11,0,0},Row{4281335808,11,0,0},Row{4281335808,11,0,0},Row{4281335808,11,0,0},Row{4281335808,11,0,0}},Rows8{Row{4281335808,11,0,0},Row{4281335808,11,0,0},Row{4281335808,11,0,0},Row{4281335808,11,0,0},Row{4281335808,11,0,0},Row{4281335808,11,0,0},Row{4281335808,11,0,0},Row{4281335808,11,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrllllrl(code: U32) -> Glyph:
  face2lrllllrl.choose(U32.is_eq(code,84))

def face2lrllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[zero_rows(),Rows8{Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0}},Rows8{Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{589648,150949888,0,0},Row{786240,134184960,0,0},Row{6290944,50323968,0,0},Row{1509946880,9436805,0,0},Row{4294930432,655359,0,0},Row{3984785408,18910,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrllllrr(code: U32) -> Glyph:
  face2lrllllrr.choose(U32.is_eq(code,85))

def face2lrllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrllllrl(code)
    case False{}: face2lrllllrr(code)

def face2lrllllr(+code: U32) -> Glyph:
  face2lrllllr.choose(code,U32.is_lt(code,85))

def face2lrllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlllll(code)
    case False{}: face2lrllllr(code)

def face2lrllll(+code: U32) -> Glyph:
  face2lrllll.choose(code,U32.is_lt(code,84))

def face2lrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[zero_rows(),Rows8{Row{57332,1610350592,0,0},Row{262112,251600896,0,0},Row{589712,167735296,0,0},Row{917296,83869696,0,0},Row{4193536,14676480,0,0},Row{9435136,9434880,0,0},Row{14676480,4193280,0,0},Row{67092480,917280,0,0}},Rows8{Row{167735296,589680,0,0},Row{234819584,196528,0,0},Row{804978688,53233,0,0},Row{2146828288,32757,0,0},Row{3219193856,12281,0,0},Row{4288675840,3069,0,0},Row{4283432960,1791,0,0},Row{4261412864,511,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrlllrl(code: U32) -> Glyph:
  face2lrlllrl.choose(U32.is_eq(code,86))

def face2lrlllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{22,[zero_rows(),Rows8{Row{49141,917344,13628672,0},Row{61425,3145632,8386560,0},Row{262080,7340000,4193280,0},Row{524160,10485747,982800,0},Row{786240,14659575,720704,0},Row{982528,50298363,458624,0},Row{4193024,117390078,196544,0},Row{813692672,184420095,57329,0}},Rows8{Row{1890579200,234554111,40948,0},Row{2699022336,804716767,24567,0},Row{3523186688,1609760927,8186,0},Row{4127150080,2413822047,3325,0},Row{4227796992,3214934047,2303,0},Row{4294705152,4284481548,1279,0},Row{4294443008,4280287240,239,0},Row{4294180864,4244635652,191,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrlllrrl(code: U32) -> Glyph:
  face2lrlllrrl.choose(U32.is_eq(code,87))

def face2lrlllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[zero_rows(),Rows8{Row{720800,150974464,0,0},Row{6290960,13628928,0,0},Row{32502784,4193824,0,0},Row{167743488,524192,0,0},Row{1073549312,53236,0,0},Row{3220439040,16380,0,0},Row{4287627264,2047,0,0},Row{4262461440,207,0,0}},Rows8{Row{4263510016,751,0,0},Row{4290772992,3071,0,0},Row{2683830272,32763,0,0},Row{520044544,262131,0,0},Row{100651264,851824,0,0},Row{10484224,9436160,0,0},Row{1965920,83882496,0,0},Row{327650,503279616,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrlllrrr(code: U32) -> Glyph:
  face2lrlllrrr.choose(U32.is_eq(code,88))

def face2lrlllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlllrrl(code)
    case False{}: face2lrlllrrr(code)

def face2lrlllrr(+code: U32) -> Glyph:
  face2lrlllrr.choose(code,U32.is_lt(code,88))

def face2lrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlllrl(code)
    case False{}: face2lrlllrr(code)

def face2lrlllr(+code: U32) -> Glyph:
  face2lrlllr.choose(code,U32.is_lt(code,87))

def face2lrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrllll(code)
    case False{}: face2lrlllr(code)

def face2lrlll(+code: U32) -> Glyph:
  face2lrlll.choose(code,U32.is_lt(code,86))

def face2lrllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[zero_rows(),Rows8{Row{262131,234844160,0,0},Row{786320,83878144,0,0},Row{5242384,11532288,0,0},Row{13628928,3079968,0,0},Row{117424128,524176,0,0},Row{520040448,57331,0,0},Row{2147024896,24570,0,0},Row{4024500224,3071,0,0}},Rows8{Row{4284481536,767,0,0},Row{4227858432,143,0,0},Row{4160749568,95,0,0},Row{4160749568,95,0,0},Row{4160749568,95,0,0},Row{4160749568,95,0,0},Row{4160749568,95,0,0},Row{4160749568,95,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrllrll(code: U32) -> Glyph:
  face2lrllrll.choose(U32.is_eq(code,89))

def face2lrllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{4294967216,2097151,0,0},Row{4294967216,2097151,0,0},Row{1145324592,589732,0,0},Row{0,53236,0,0},Row{268435456,16382,0,0},Row{2684354560,2047,0,0},Row{4127195136,207,0,0},Row{4263510016,46,0,0}},Rows8{Row{4289724416,6,0,0},Row{3220570112,0,0,0},Row{788406272,0,0,0},Row{100642816,0,0,0},Row{10483456,0,0,0},Row{1146027808,279620,0,0},Row{4294967200,3145727,0,0},Row{4294967216,3145727,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrllrlrl(code: U32) -> Glyph:
  face2lrllrlrl.choose(U32.is_eq(code,90))

def face2lrllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{268434688,0,0,0}},Rows8{Row{268434688,0,0,0},Row{72219904,0,0,0},Row{851200,0,0,0},Row{851200,0,0,0},Row{851200,0,0,0},Row{851200,0,0,0},Row{851200,0,0,0},Row{851200,0,0,0}},Rows8{Row{851200,0,0,0},Row{851200,0,0,0},Row{851200,0,0,0},Row{851200,0,0,0},Row{851200,0,0,0},Row{851200,0,0,0},Row{851200,0,0,0},Row{851200,0,0,0}},Rows8{Row{72219904,0,0,0},Row{268434688,0,0,0},Row{268434688,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lrllrlrr(code: U32) -> Glyph:
  face2lrllrlrr.choose(U32.is_eq(code,91))

def face2lrllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrllrlrl(code)
    case False{}: face2lrllrlrr(code)

def face2lrllrlr(+code: U32) -> Glyph:
  face2lrllrlr.choose(code,U32.is_lt(code,91))

def face2lrllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrllrll(code)
    case False{}: face2lrllrlr(code)

def face2lrllrl(+code: U32) -> Glyph:
  face2lrllrl.choose(code,U32.is_lt(code,90))

def face2lrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3832,0,0,0}},Rows8{Row{16372,0,0,0},Row{32736,0,0,0},Row{49056,0,0,0},Row{130912,0,0,0},Row{392992,0,0,0},Row{654592,0,0,0},Row{915712,0,0,0},Row{3142912,0,0,0}},Rows8{Row{7336192,0,0,0},Row{11517952,0,0,0},Row{15695872,0,0,0},Row{67059712,0,0,0},Row{134086656,0,0,0},Row{200998912,0,0,0},Row{536281088,0,0,0},Row{1341259776,0,0,0}},Rows8{Row{2412773376,0,0,0},Row{3750756352,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lrllrrl(code: U32) -> Glyph:
  face2lrllrrl.choose(U32.is_eq(code,92))

def face2lrllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{33554368,0,0,0}},Rows8{Row{33554368,0,0,0},Row{33530928,0,0,0},Row{33525760,0,0,0},Row{33525760,0,0,0},Row{33525760,0,0,0},Row{33525760,0,0,0},Row{33525760,0,0,0},Row{33525760,0,0,0}},Rows8{Row{33525760,0,0,0},Row{33525760,0,0,0},Row{33525760,0,0,0},Row{33525760,0,0,0},Row{33525760,0,0,0},Row{33525760,0,0,0},Row{33525760,0,0,0},Row{33525760,0,0,0}},Rows8{Row{33530928,0,0,0},Row{33554368,0,0,0},Row{33554368,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lrllrrrl(code: U32) -> Glyph:
  face2lrllrrrl.choose(U32.is_eq(code,93))

def face2lrllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[zero_rows(),Rows8{Row{201273344,0,0,0},Row{1073717248,0,0,0},Row{3213881856,0,0,0},Row{4263115008,3,0,0},Row{4177788432,10,0,0},Row{4060135296,47,0,0},Row{2952810465,159,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2lrllrrrr(code: U32) -> Glyph:
  face2lrllrrrr.choose(U32.is_eq(code,94))

def face2lrllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrllrrrl(code)
    case False{}: face2lrllrrrr(code)

def face2lrllrrr(+code: U32) -> Glyph:
  face2lrllrrr.choose(code,U32.is_lt(code,94))

def face2lrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrllrrl(code)
    case False{}: face2lrllrrr(code)

def face2lrllrr(+code: U32) -> Glyph:
  face2lrllrr.choose(code,U32.is_lt(code,93))

def face2lrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrllrl(code)
    case False{}: face2lrllrr(code)

def face2lrllr(+code: U32) -> Glyph:
  face2lrllr.choose(code,U32.is_lt(code,92))

def face2lrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlll(code)
    case False{}: face2lrllr(code)

def face2lrll(+code: U32) -> Glyph:
  face2lrll.choose(code,U32.is_lt(code,89))

def face2lrlrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[zero_rows(),zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1145324612,324,0,0}},Rows8{Row{4294967295,1535,0,0},Row{4294967295,1535,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lrlrlll(code: U32) -> Glyph:
  face2lrlrlll.choose(U32.is_eq(code,95))

def face2lrlrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{720144,0,0,0},Row{3142656,0,0,0},Row{11501568,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2lrlrllrl(code: U32) -> Glyph:
  face2lrlrllrl.choose(U32.is_eq(code,96))

def face2lrlrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{3739967488,41,0,0},Row{4294966032,1279,0,0},Row{2489122672,3583,0,0},Row{38704,8187,0,0}},Rows8{Row{822083584,12285,0,0},Row{4293624320,12287,0,0},Row{2060451680,12283,0,0},Row{188385,12282,0,0},Row{268476402,12286,0,0},Row{3595038705,12287,0,0},Row{4026531712,12281,0,0},Row{720357120,12280,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrlrllrr(code: U32) -> Glyph:
  face2lrlrllrr.choose(U32.is_eq(code,97))

def face2lrlrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlrllrl(code)
    case False{}: face2lrlrllrr(code)

def face2lrlrllr(+code: U32) -> Glyph:
  face2lrlrllr.choose(code,U32.is_lt(code,97))

def face2lrlrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlrlll(code)
    case False{}: face2lrlrllr(code)

def face2lrlrll(+code: U32) -> Glyph:
  face2lrlrll.choose(code,U32.is_lt(code,96))

def face2lrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{4232380288,942,0,0},Row{4294508416,20479,0,0},Row{1438646144,126970,0,0},Row{917376,458672,0,0}},Rows8{Row{524160,720720,0,0},Row{327552,786208,0,0},Row{327552,786208,0,0},Row{524160,655184,0,0},Row{917376,458672,0,0},Row{1438646144,126970,0,0},Row{4294442880,20223,0,0},Row{4232314752,942,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrlrlrl(code: U32) -> Glyph:
  face2lrlrlrl.choose(U32.is_eq(code,98))

def face2lrlrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{3755548672,75,0,0},Row{4294960384,2559,0,0},Row{1687158304,24573,0,0},Row{524176,40946,0,0}},Rows8{Row{131024,288,0,0},Row{57328,0,0,0},Row{57328,0,0,0},Row{131024,288,0,0},Row{524176,45026,0,0},Row{1687158304,28669,0,0},Row{4294960384,2815,0,0},Row{3755548672,75,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrlrlrrl(code: U32) -> Glyph:
  face2lrlrlrrl.choose(U32.is_eq(code,99))

def face2lrlrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{0,327552,0,0},Row{0,327552,0,0},Row{0,327552,0,0},Row{0,327552,0,0},Row{2934722560,327554,0,0},Row{4294965248,327581,0,0},Row{1687158592,327677,0,0},Row{524192,327666,0,0}},Rows8{Row{131040,327600,0,0},Row{57328,327552,0,0},Row{57328,327552,0,0},Row{131040,327600,0,0},Row{524192,327666,0,0},Row{1687158592,327677,0,0},Row{4294965248,327565,0,0},Row{2934722560,327538,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrlrlrrr(code: U32) -> Glyph:
  face2lrlrlrrr.choose(U32.is_eq(code,100))

def face2lrlrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlrlrrl(code)
    case False{}: face2lrlrlrrr(code)

def face2lrlrlrr(+code: U32) -> Glyph:
  face2lrlrlrr.choose(code,U32.is_lt(code,100))

def face2lrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlrlrl(code)
    case False{}: face2lrlrlrr(code)

def face2lrlrlr(+code: U32) -> Glyph:
  face2lrlrlr.choose(code,U32.is_lt(code,99))

def face2lrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlrll(code)
    case False{}: face2lrlrlr(code)

def face2lrlrl(+code: U32) -> Glyph:
  face2lrlrl.choose(code,U32.is_lt(code,98))

def face2lrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{3755548672,58,0,0},Row{4294960384,1791,0,0},Row{1686044192,16381,0,0},Row{262032,45026,0,0}},Rows8{Row{1145364432,61380,0,0},Row{4294967280,65535,0,0},Row{4294967280,131071,0,0},Row{57296,0,0,0},Row{327568,13680,0,0},Row{1418657312,40954,0,0},Row{4294960384,7423,0,0},Row{4007206912,364,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrlrrll(code: U32) -> Glyph:
  face2lrlrrll.choose(U32.is_eq(code,101))

def face2lrlrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1466105856,1,0,0}},Rows8{Row{4294934528,2,0,0},Row{3170890752,0,0,0},Row{6289408,0,0,0},Row{4192512,0,0,0},Row{3489660924,0,0,0},Row{3489660924,0,0,0},Row{879753795,0,0,0},Row{4192512,0,0,0}},Rows8{Row{4192512,0,0,0},Row{4192512,0,0,0},Row{4192512,0,0,0},Row{4192512,0,0,0},Row{4192512,0,0,0},Row{4192512,0,0,0},Row{4192512,0,0,0},Row{4192512,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrlrrlrl(code: U32) -> Glyph:
  face2lrlrrlrl.choose(U32.is_eq(code,102))

def face2lrlrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{2934652928,327538,0,0},Row{4294964992,327565,0,0},Row{1687158576,327677,0,0},Row{524176,327666,0,0}},Rows8{Row{131024,327584,0,0},Row{57328,327552,0,0},Row{57328,327552,0,0},Row{131040,327584,0,0},Row{524192,327666,0,0},Row{1703935808,327677,0,0},Row{4294965504,327565,0,0},Row{2934726656,327538,0,0}},Rows8{Row{4096,196512,0,0},Row{1415249216,53242,0,0},Row{4294966016,12031,0,0},Row{4024127488,396,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lrlrrlrr(code: U32) -> Glyph:
  face2lrlrrlrr.choose(U32.is_eq(code,103))

def face2lrlrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlrrlrl(code)
    case False{}: face2lrlrrlrr(code)

def face2lrlrrlr(+code: U32) -> Glyph:
  face2lrlrrlr.choose(code,U32.is_lt(code,103))

def face2lrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlrrll(code)
    case False{}: face2lrlrrlr(code)

def face2lrlrrl(+code: U32) -> Glyph:
  face2lrlrrl.choose(code,U32.is_lt(code,102))

def face2lrlrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{3947167616,942,0,0},Row{4294508416,12031,0,0},Row{1706033024,45053,0,0},Row{720768,57330,0,0}},Rows8{Row{393088,65488,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrlrrrll(code: U32) -> Glyph:
  face2lrlrrrll.choose(U32.is_eq(code,104))

def face2lrlrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{187968,0,0,0}},Rows8{Row{524208,0,0,0},Row{187968,0,0,0},zero_row(),zero_row(),Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0}},Rows8{Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrlrrrlr(code: U32) -> Glyph:
  face2lrlrrrlr.choose(U32.is_eq(code,105))

def face2lrlrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlrrrll(code)
    case False{}: face2lrlrrrlr(code)

def face2lrlrrrl(+code: U32) -> Glyph:
  face2lrlrrrl.choose(code,U32.is_lt(code,105))

def face2lrlrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2941952,0,0,0}},Rows8{Row{8387328,0,0,0},Row{2941952,0,0,0},zero_row(),zero_row(),Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0}},Rows8{Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0}},Rows8{Row{5241088,0,0,0},Row{3145298,0,0,0},Row{720887,0,0,0},Row{31975,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lrlrrrrl(code: U32) -> Glyph:
  face2lrlrrrrl.choose(U32.is_eq(code,106))

def face2lrlrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,40953,0,0},Row{2147811200,3071,0,0},Row{4127522688,463,0,0},Row{4282711936,45,0,0}},Rows8{Row{4024958848,2,0,0},Row{2952789888,0,0,0},Row{4294967168,5,0,0},Row{4284219264,46,0,0},Row{4161077120,207,0,0},Row{3221553024,2303,0,0},Row{537198464,20478,0,0},Row{327552,126965,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrlrrrrr(code: U32) -> Glyph:
  face2lrlrrrrr.choose(U32.is_eq(code,107))

def face2lrlrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlrrrrl(code)
    case False{}: face2lrlrrrrr(code)

def face2lrlrrrr(+code: U32) -> Glyph:
  face2lrlrrrr.choose(code,U32.is_lt(code,107))

def face2lrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlrrrl(code)
    case False{}: face2lrlrrrr(code)

def face2lrlrrr(+code: U32) -> Glyph:
  face2lrlrrr.choose(code,U32.is_lt(code,106))

def face2lrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlrrl(code)
    case False{}: face2lrlrrr(code)

def face2lrlrr(+code: U32) -> Glyph:
  face2lrlrr.choose(code,U32.is_lt(code,104))

def face2lrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrlrl(code)
    case False{}: face2lrlrr(code)

def face2lrlr(+code: U32) -> Glyph:
  face2lrlr.choose(code,U32.is_lt(code,101))

def face2lrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrll(code)
    case False{}: face2lrlr(code)

def face2lrl(+code: U32) -> Glyph:
  face2lrl.choose(code,U32.is_lt(code,95))

def face2lrrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[zero_rows(),Rows8{Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0}},Rows8{Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrllll(code: U32) -> Glyph:
  face2lrrllll.choose(U32.is_eq(code,108))

def face2lrrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{20,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{3964862336,3755409501,7,0},Row{4294442880,4294943743,159,0},Row{2223964032,4165467647,511,0},Row{589696,2684391418,1279,0}},Rows8{Row{393088,1879068663,1535,0},Row{327552,1879068663,1535,0},Row{327552,1879068663,1535,0},Row{327552,1879068663,1535,0},Row{327552,1879068663,1535,0},Row{327552,1879068663,1535,0},Row{327552,1879068663,1535,0},Row{327552,1879068663,1535,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrlllrl(code: U32) -> Glyph:
  face2lrrlllrl.choose(U32.is_eq(code,109))

def face2lrrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{3947036544,942,0,0},Row{4294377344,12031,0,0},Row{1705967488,45053,0,0},Row{720768,57330,0,0}},Rows8{Row{393088,65488,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrlllrr(code: U32) -> Glyph:
  face2lrrlllrr.choose(U32.is_eq(code,110))

def face2lrrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrlllrl(code)
    case False{}: face2lrrlllrr(code)

def face2lrrlllr(+code: U32) -> Glyph:
  face2lrrlllr.choose(code,U32.is_lt(code,110))

def face2lrrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrllll(code)
    case False{}: face2lrrlllr(code)

def face2lrrlll(+code: U32) -> Glyph:
  face2lrrlll.choose(code,U32.is_lt(code,109))

def face2lrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{4023984128,91,0,0},Row{4294960384,2559,0,0},Row{1687158304,32765,0,0},Row{524176,61410,0,0}},Rows8{Row{131024,327568,0,0},Row{57328,458592,0,0},Row{57328,458608,0,0},Row{131024,327568,0,0},Row{524176,61410,0,0},Row{1687158304,32765,0,0},Row{4294960384,2559,0,0},Row{4023984128,91,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrllrl(code: U32) -> Glyph:
  face2lrrllrl.choose(U32.is_eq(code,111))

def face2lrrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{4232314752,942,0,0},Row{4294442880,20479,0,0},Row{1438646144,126970,0,0},Row{917376,458672,0,0}},Rows8{Row{524160,720720,0,0},Row{327552,786208,0,0},Row{327552,786208,0,0},Row{524160,655184,0,0},Row{917376,458672,0,0},Row{1438646144,126970,0,0},Row{4294508416,20223,0,0},Row{4232380288,942,0,0}},Rows8{Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lrrllrrl(code: U32) -> Glyph:
  face2lrrllrrl.choose(U32.is_eq(code,112))

def face2lrrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{2934722560,327538,0,0},Row{4294965248,327565,0,0},Row{1687158592,327677,0,0},Row{524192,327666,0,0}},Rows8{Row{131040,327600,0,0},Row{57328,327552,0,0},Row{57328,327552,0,0},Row{131040,327600,0,0},Row{524192,327666,0,0},Row{1687158592,327677,0,0},Row{4294965248,327581,0,0},Row{2934722560,327554,0,0}},Rows8{Row{0,327552,0,0},Row{0,327552,0,0},Row{0,327552,0,0},Row{0,327552,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lrrllrrr(code: U32) -> Glyph:
  face2lrrllrrr.choose(U32.is_eq(code,113))

def face2lrrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrllrrl(code)
    case False{}: face2lrrllrrr(code)

def face2lrrllrr(+code: U32) -> Glyph:
  face2lrrllrr.choose(code,U32.is_lt(code,113))

def face2lrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrllrl(code)
    case False{}: face2lrrllrr(code)

def face2lrrllr(+code: U32) -> Glyph:
  face2lrrllr.choose(code,U32.is_lt(code,112))

def face2lrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrlll(code)
    case False{}: face2lrrllr(code)

def face2lrrll(+code: U32) -> Glyph:
  face2lrrll.choose(code,U32.is_lt(code,111))

def face2lrrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{4252237696,4,0,0},Row{4294573952,4,0,0},Row{1169162112,2,0,0},Row{786304,0,0,0}},Rows8{Row{393088,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrlrll(code: U32) -> Glyph:
  face2lrrlrll.choose(U32.is_eq(code,114))

def face2lrrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{3471601920,24,0,0},Row{4294966544,479,0,0},Row{2489122688,2559,0,0},Row{196512,1143,0,0}},Rows8{Row{3866480,0,0,0},Row{3472882448,39,0,0},Row{4292427776,1535,0,0},Row{1358954496,3838,0,0},Row{43632,12283,0,0},Row{2488991664,3839,0,0},Row{4294966832,1279,0,0},Row{3740041472,41,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrlrlrl(code: U32) -> Glyph:
  face2lrrlrlrl.choose(U32.is_eq(code,115))

def face2lrrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{zero_row(),Row{786192,0,0,0},Row{786192,0,0,0},Row{786192,0,0,0},Row{268435452,0,0,0},Row{268435452,0,0,0},Row{72154947,0,0,0},Row{786192,0,0,0}},Rows8{Row{786192,0,0,0},Row{786192,0,0,0},Row{786192,0,0,0},Row{786192,0,0,0},Row{786192,0,0,0},Row{73334272,0,0,0},Row{805304576,0,0,0},Row{1325236480,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrlrlrr(code: U32) -> Glyph:
  face2lrrlrlrr.choose(U32.is_eq(code,116))

def face2lrrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrlrlrl(code)
    case False{}: face2lrrlrlrr(code)

def face2lrrlrlr(+code: U32) -> Glyph:
  face2lrrlrlr.choose(code,U32.is_lt(code,116))

def face2lrrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrlrll(code)
    case False{}: face2lrrlrlr(code)

def face2lrrlrl(+code: U32) -> Glyph:
  face2lrrlrl.choose(code,U32.is_lt(code,115))

def face2lrrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0}},Rows8{Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{393088,65504,0,0},Row{720736,65524,0,0},Row{2259681072,65518,0,0},Row{4294965760,65450,0,0},Row{2382196736,65440,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrlrrll(code: U32) -> Glyph:
  face2lrrlrrll.choose(U32.is_eq(code,117))

def face2lrrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{40950,393104,0,0},Row{57313,61408,0,0},Row{327584,36852,0,0},Row{655168,16377,0,0}},Rows8{Row{982272,3326,0,0},Row{1078982656,2047,0,0},Row{2426401280,511,0,0},Row{3772760064,175,0,0},Row{4127154176,95,0,0},Row{4261351424,14,0,0},Row{4294574080,9,0,0},Row{4294180864,3,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrlrrlr(code: U32) -> Glyph:
  face2lrrlrrlr.choose(U32.is_eq(code,118))

def face2lrrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrlrrll(code)
    case False{}: face2lrrlrrlr(code)

def face2lrrlrrl(+code: U32) -> Glyph:
  face2lrrlrrl.choose(code,U32.is_lt(code,118))

def face2lrrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{18,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{805343222,4043312127,223,0},Row{1879101425,4110421759,143,0},Row{2952921024,4177543167,79,0},Row{3758423920,4244668383,14,0}},Rows8{Row{4094230320,4280336270,10,0},Row{4144823552,4283494219,5,0},Row{4212128000,4287889159,1,0},Row{4266652672,3217488643,0,0},Row{3751796992,2147153664,0,0},Row{2684334080,805302784,0,0},Row{1610571776,234868736,0,0},Row{536813568,150966272,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrlrrrl(code: U32) -> Glyph:
  face2lrrlrrrl.choose(U32.is_eq(code,119))

def face2lrrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{196561,32760,0,0},Row{537657152,3327,0,0},Row{2958031360,1023,0,0},Row{4107264256,159,0,0}},Rows8{Row{4261371904,29,0,0},Row{4294639616,4,0,0},Row{4294770688,5,0,0},Row{4244602880,30,0,0},Row{4088394496,175,0,0},Row{2419063808,1535,0,0},Row{268959600,7934,0,0},Row{57330,45046,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrlrrrr(code: U32) -> Glyph:
  face2lrrlrrrr.choose(U32.is_eq(code,120))

def face2lrrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrlrrrl(code)
    case False{}: face2lrrlrrrr(code)

def face2lrrlrrr(+code: U32) -> Glyph:
  face2lrrlrrr.choose(code,U32.is_lt(code,120))

def face2lrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrlrrl(code)
    case False{}: face2lrrlrrr(code)

def face2lrrlrr(+code: U32) -> Glyph:
  face2lrrlrr.choose(code,U32.is_lt(code,119))

def face2lrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrlrl(code)
    case False{}: face2lrrlrr(code)

def face2lrrlr(+code: U32) -> Glyph:
  face2lrrlr.choose(code,U32.is_lt(code,117))

def face2lrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrll(code)
    case False{}: face2lrrlr(code)

def face2lrrl(+code: U32) -> Glyph:
  face2lrrl.choose(code,U32.is_lt(code,114))

def face2lrrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{40950,393104,0,0},Row{61409,61408,0,0},Row{327568,36853,0,0},Row{655152,12282,0,0}},Rows8{Row{269417728,3071,0,0},Row{1616901888,1535,0,0},Row{2964320512,239,0,0},Row{4059013120,159,0,0},Row{4177477632,63,0,0},Row{4294770688,12,0,0},Row{4294443008,6,0,0},Row{4025614336,1,0,0}},Rows8{Row{2683568128,0,0,0},Row{805057536,0,0,0},Row{150994752,0,0,0},Row{7138928,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lrrrlll(code: U32) -> Glyph:
  face2lrrrlll.choose(U32.is_eq(code,121))

def face2lrrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{4294967168,3839,0,0},Row{4294967168,3839,0,0},Row{3292808224,2047,0,0},Row{4143972352,175,0,0}},Rows8{Row{4281335808,29,0,0},Row{4291887104,3,0,0},Row{2147155968,0,0,0},Row{201293824,0,0,0},Row{31454208,0,0,0},Row{1149238816,5188,0,0},Row{4294967200,12287,0,0},Row{4294967200,12287,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrrllrl(code: U32) -> Glyph:
  face2lrrrllrl.choose(U32.is_eq(code,122))

def face2lrrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1660944384,6,0,0}},Rows8{Row{4290838528,12,0,0},Row{4026138624,10,0,0},Row{503250944,0,0,0},Row{150933504,0,0,0},Row{134160384,0,0,0},Row{134160384,0,0,0},Row{134164480,0,0,0},Row{83862016,0,0,0}},Rows8{Row{7208816,0,0,0},Row{2817904,0,0,0},Row{49272096,0,0,0},Row{117391360,0,0,0},Row{134160384,0,0,0},Row{134160384,0,0,0},Row{134160384,0,0,0},Row{167710720,0,0,0}},Rows8{Row{1325203456,1,0,0},Row{4294377472,12,0,0},Row{4269801472,12,0,0},Row{536870912,3,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lrrrllrr(code: U32) -> Glyph:
  face2lrrrllrr.choose(U32.is_eq(code,123))

def face2lrrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrrllrl(code)
    case False{}: face2lrrrllrr(code)

def face2lrrrllr(+code: U32) -> Glyph:
  face2lrrrllr.choose(code,U32.is_lt(code,123))

def face2lrrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrrlll(code)
    case False{}: face2lrrrllr(code)

def face2lrrrll(+code: U32) -> Glyph:
  face2lrrrll.choose(code,U32.is_lt(code,122))

def face2lrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0}},Rows8{Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0}},Rows8{Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0}},Rows8{Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0},Row{5240064,0,0,0},zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lrrrlrl(code: U32) -> Glyph:
  face2lrrrlrl.choose(U32.is_eq(code,124))

def face2lrrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{13920,0,0,0}},Rows8{Row{1900480,0,0,0},Row{11533984,0,0,0},Row{16765184,0,0,0},Row{33521664,0,0,0},Row{50294784,0,0,0},Row{50294784,0,0,0},Row{67072000,0,0,0},Row{738144256,0,0,0}},Rows8{Row{4292214784,7,0,0},Row{4288872448,7,0,0},Row{1845370880,2,0,0},Row{100622336,0,0,0},Row{50294784,0,0,0},Row{50294784,0,0,0},Row{50294784,0,0,0},Row{33525760,0,0,0}},Rows8{Row{14672912,0,0,0},Row{8388544,0,0,0},Row{585664,0,0,0},Row{560,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lrrrlrrl(code: U32) -> Glyph:
  face2lrrrlrrl.choose(U32.is_eq(code,125))

def face2lrrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{21237760,0,0,0}},Rows8{Row{1862263808,2094080,0,0},Row{4294966528,982123,0,0},Row{4162256688,589823,0,0},Row{805349920,32251,0,0},zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2lrrrlrrr(code: U32) -> Glyph:
  face2lrrrlrrr.choose(U32.is_eq(code,126))

def face2lrrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrrlrrl(code)
    case False{}: face2lrrrlrrr(code)

def face2lrrrlrr(+code: U32) -> Glyph:
  face2lrrrlrr.choose(code,U32.is_lt(code,126))

def face2lrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrrlrl(code)
    case False{}: face2lrrrlrr(code)

def face2lrrrlr(+code: U32) -> Glyph:
  face2lrrrlr.choose(code,U32.is_lt(code,125))

def face2lrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrrll(code)
    case False{}: face2lrrrlr(code)

def face2lrrrl(+code: U32) -> Glyph:
  face2lrrrl.choose(code,U32.is_lt(code,124))

def face2lrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[zero_rows(),zero_rows(),zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2lrrrrll(code: U32) -> Glyph:
  face2lrrrrll.choose(U32.is_eq(code,160))

def face2lrrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{780800,0,0,0},Row{4194096,0,0,0},Row{780800,0,0,0},zero_row()},Rows8{zero_row(),Row{916480,0,0,0},Row{916480,0,0,0},Row{982016,0,0,0},Row{982272,0,0,0},Row{982272,0,0,0},Row{982272,0,0,0},Row{1048064,0,0,0}},Rows8{Row{1048064,0,0,0},Row{1048064,0,0,0},Row{1048064,0,0,0},Row{2096896,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lrrrrlrl(code: U32) -> Glyph:
  face2lrrrrlrl.choose(U32.is_eq(code,161))

def face2lrrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{1325400064,0,0,0},Row{1325400064,0,0,0},Row{4023984128,91,0,0},Row{4294964480,2559,0,0},Row{2408578592,28669,0,0},Row{1325924240,40674,0,0},Row{1325531088,32,0,0},Row{1325457392,0,0,0}},Rows8{Row{1325457392,0,0,0},Row{1325461472,16,0,0},Row{1325793184,36321,0,0},Row{1868496688,32763,0,0},Row{4294964992,3071,0,0},Row{4294725632,398,0,0},Row{1594884096,0,0,0},Row{1325400064,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrrrlrr(code: U32) -> Glyph:
  face2lrrrrlrr.choose(U32.is_eq(code,162))

def face2lrrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrrrlrl(code)
    case False{}: face2lrrrrlrr(code)

def face2lrrrrlr(+code: U32) -> Glyph:
  face2lrrrrlr.choose(code,U32.is_lt(code,162))

def face2lrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrrrll(code)
    case False{}: face2lrrrrlr(code)

def face2lrrrrl(+code: U32) -> Glyph:
  face2lrrrrl.choose(code,U32.is_lt(code,161))

def face2lrrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{4253155328,1214,0,0},Row{4294848512,32767,0,0},Row{2080362496,262120,0,0},Row{11531264,655168,0,0},Row{6288896,148992,0,0},Row{5240320,0,0,0},Row{6288896,0,0,0},Row{4294967264,223,0,0}},Rows8{Row{4294967264,223,0,0},Row{1150285632,52,0,0},Row{8385280,0,0,0},Row{8385024,0,0,0},Row{5239808,567296,0,0},Row{1718287728,786038,0,0},Row{4294967264,524287,0,0},Row{4294967264,36351,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrrrrll(code: U32) -> Glyph:
  face2lrrrrrll.choose(U32.is_eq(code,163))

def face2lrrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[zero_rows(),Rows8{zero_row(),zero_row(),Row{805311232,3145747,0,0},Row{4269911584,166935551,0,0},Row{4294901568,201261055,0,0},Row{366999040,30406961,0,0},Row{1832448,14639104,0,0},Row{130560,117047296,0,0}},Rows8{Row{48944,183828480,0,0},Row{44864,200474624,0,0},Row{53024,167116800,0,0},Row{261376,100401152,0,0},Row{3011840,13602816,0,0},Row{1508899600,100662644,0,0},Row{4294569808,234545151,0,0},Row{3930081536,60823503,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrrrrlr(code: U32) -> Glyph:
  face2lrrrrrlr.choose(U32.is_eq(code,164))

def face2lrrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrrrrll(code)
    case False{}: face2lrrrrrlr(code)

def face2lrrrrrl(+code: U32) -> Glyph:
  face2lrrrrrl.choose(code,U32.is_lt(code,164))

def face2lrrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{36855,57330,0,0},Row{126945,28664,0,0},Row{268894064,3582,0,0},Row{1611464208,1791,0,0},Row{3494901760,239,0,0},Row{4106219776,127,0,0},Row{4244606976,30,0,0},Row{4294927408,842,0,0}},Rows8{Row{4294967200,3583,0,0},Row{4294967200,3583,0,0},Row{2952152112,836,0,0},Row{4294967200,3583,0,0},Row{4294967200,3583,0,0},Row{2683568128,0,0,0},Row{2683568128,0,0,0},Row{2683568128,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2lrrrrrrl(code: U32) -> Glyph:
  face2lrrrrrrl.choose(U32.is_eq(code,165))

def face2lrrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{Row{785408,0,0,0},Row{785408,0,0,0},Row{785408,0,0,0},Row{785408,0,0,0},Row{785408,0,0,0},Row{785408,0,0,0},Row{785408,0,0,0},zero_row()},Rows8{zero_row(),zero_row(),zero_row(),Row{785408,0,0,0},Row{785408,0,0,0},Row{785408,0,0,0},Row{785408,0,0,0},Row{785408,0,0,0}},Rows8{Row{785408,0,0,0},Row{785408,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2lrrrrrrr(code: U32) -> Glyph:
  face2lrrrrrrr.choose(U32.is_eq(code,166))

def face2lrrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrrrrrl(code)
    case False{}: face2lrrrrrrr(code)

def face2lrrrrrr(+code: U32) -> Glyph:
  face2lrrrrrr.choose(code,U32.is_lt(code,166))

def face2lrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrrrrl(code)
    case False{}: face2lrrrrrr(code)

def face2lrrrrr(+code: U32) -> Glyph:
  face2lrrrrr.choose(code,U32.is_lt(code,165))

def face2lrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrrrl(code)
    case False{}: face2lrrrrr(code)

def face2lrrrr(+code: U32) -> Glyph:
  face2lrrrr.choose(code,U32.is_lt(code,163))

def face2lrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrrl(code)
    case False{}: face2lrrrr(code)

def face2lrrr(+code: U32) -> Glyph:
  face2lrrr.choose(code,U32.is_lt(code,160))

def face2lrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrrl(code)
    case False{}: face2lrrr(code)

def face2lrr(+code: U32) -> Glyph:
  face2lrr.choose(code,U32.is_lt(code,121))

def face2lr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2lrl(code)
    case False{}: face2lrr(code)

def face2lr(+code: U32) -> Glyph:
  face2lr.choose(code,U32.is_lt(code,108))

def face2l.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2ll(code)
    case False{}: face2lr(code)

def face2l(+code: U32) -> Glyph:
  face2l.choose(code,U32.is_lt(code,83))

def face2rllllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{3471523840,7,0,0},Row{4294964736,175,0,0},Row{2758737408,1279,0,0},Row{524048,1485,0,0},Row{720384,0,0,0},Row{80738304,0,0,0},Row{3489640704,5,0,0},Row{4289130048,719,0,0}},Rows8{Row{2717937600,3583,0,0},Row{36800,20468,0,0},Row{524160,24544,0,0},Row{401603344,7668,0,0},Row{4294795264,383,0,0},Row{4233101312,463,0,0},Row{1879048192,1791,0,0},Row{108320,2559,0,0}},Rows8{Row{1629159216,2047,0,0},Row{4294965760,751,0,0},Row{4294938880,59,0,0},Row{321978368,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2rllllll(code: U32) -> Glyph:
  face2rllllll.choose(U32.is_eq(code,167))

def face2rlllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{274563072,715,0,0}},Rows8{Row{1625288960,2303,0,0},Row{544120832,989,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2rlllllrl(code: U32) -> Glyph:
  face2rlllllrl.choose(U32.is_eq(code,168))

def face2rlllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{20,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{0,4913,0,0}},Rows8{Row{3321888768,25034751,0,0},Row{4291952640,1040187391,0,0},Row{2684231680,4294455572,3,0},Row{602918912,4247043818,30,0},Row{3813668352,3797942271,143,0},Row{4228578304,2179970397,239,0},Row{4013293328,867827714,1023,0},Row{3209887520,268435456,1279,0}},Rows8{Row{3745775392,310837248,1279,0},Row{4261871360,1106215210,767,0},Row{4111203072,2692743167,223,0},Row{1349514496,4110938109,111,0},Row{134197248,4284486448,12,0},Row{3757838336,3757864023,2,0},Row{4287692800,452984831,0,0},Row{2466250752,3792621,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlllllrr(code: U32) -> Glyph:
  face2rlllllrr.choose(U32.is_eq(code,169))

def face2rlllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlllllrl(code)
    case False{}: face2rlllllrr(code)

def face2rlllllr(+code: U32) -> Glyph:
  face2rlllllr.choose(code,U32.is_lt(code,169))

def face2rlllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllllll(code)
    case False{}: face2rlllllr(code)

def face2rlllll(+code: U32) -> Glyph:
  face2rlllll.choose(code,U32.is_lt(code,168))

def face2rllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[zero_rows(),Rows8{Row{1827587584,0,0,0},Row{4290510720,7,0,0},Row{4143987312,13,0,0},Row{4234485760,14,0,0},Row{4261412448,14,0,0},Row{4110581747,14,0,0},Row{4194307829,14,0,0},Row{4275757026,14,0,0}},Rows8{Row{4121881408,14,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2rllllrl(code: U32) -> Glyph:
  face2rllllrl.choose(U32.is_eq(code,170))

def face2rllllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{3756195840,786257,0,0},Row{788336640,118755,0,0},Row{620740608,12029,0,0},Row{3245341184,1279,0,0}},Rows8{Row{4194893696,111,0,0},Row{4228382608,79,0,0},Row{3512728320,1007,0,0},Row{602915072,11774,0,0},Row{788340736,118755,0,0},Row{3756195840,720721,0,0},zero_row(),zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2rllllrrl(code: U32) -> Glyph:
  face2rllllrrl.choose(U32.is_eq(code,171))

def face2rllllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1145324032,13380,0,0}},Rows8{Row{4294965760,53247,0,0},Row{4294965760,53247,0,0},Row{0,53136,0,0},Row{0,53136,0,0},Row{0,53136,0,0},zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2rllllrrr(code: U32) -> Glyph:
  face2rllllrrr.choose(U32.is_eq(code,172))

def face2rllllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllllrrl(code)
    case False{}: face2rllllrrr(code)

def face2rllllrr(+code: U32) -> Glyph:
  face2rllllrr.choose(code,U32.is_lt(code,172))

def face2rllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllllrl(code)
    case False{}: face2rllllrr(code)

def face2rllllr(+code: U32) -> Glyph:
  face2rllllr.choose(code,U32.is_lt(code,171))

def face2rllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlllll(code)
    case False{}: face2rllllr(code)

def face2rllll(+code: U32) -> Glyph:
  face2rllll.choose(code,U32.is_lt(code,170))

def face2rlllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[Rows8{zero_row(),zero_row(),zero_row(),Row{3149615104,2747,0,0},Row{4294930432,3839,0,0},Row{9400320,3825,0,0},Row{2330947584,3838,0,0},Row{294612992,3826,0,0}},Rows8{Row{3135205376,3837,0,0},Row{2056220672,3839,0,0},Row{294612992,3826,0,0},Row{2866769920,3835,0,0},Row{1827631104,3836,0,0},Row{1905225728,3829,0,0},Row{3135205376,3828,0,0},Row{2900324352,3835,0,0}},Rows8{Row{982478848,3827,0,0},Row{3129962496,3828,0,0},Row{294612992,3826,0,0},Row{4294930432,3839,0,0},Row{1705996288,3829,0,0},Row{4237258752,3829,0,0},Row{1133473792,3826,0,0},Row{3168759808,3835,0,0}},Rows8{Row{1526689792,3836,0,0},Row{1100967936,3829,0,0},Row{3151982592,3835,0,0},Row{4294930432,3839,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2rlllrll(code: U32) -> Glyph:
  face2rlllrll.choose(U32.is_eq(code,173))

def face2rlllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3414294528,107,0,0}},Rows8{Row{4294930432,15871,0,0},Row{309196544,192403,0,0},Row{122656,783616,0,0},Row{4292886416,4165693,0,0},Row{400559312,8335548,0,0},Row{132123360,9375932,0,0},Row{4292873168,8335423,0,0},Row{937439136,4161647,0,0}},Rows8{Row{76595008,844678,0,0},Row{3995904,327265,0,0},Row{3741294592,24319,0,0},Row{4273209344,653,0,0},zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2rlllrlrl(code: U32) -> Glyph:
  face2rlllrlrl.choose(U32.is_eq(code,174))

def face2rlllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1145324544,0,0,0}},Rows8{Row{4294967056,0,0,0},Row{4294967056,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2rlllrlrr(code: U32) -> Glyph:
  face2rlllrlrr.choose(U32.is_eq(code,175))

def face2rlllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlllrlrl(code)
    case False{}: face2rlllrlrr(code)

def face2rlllrlr(+code: U32) -> Glyph:
  face2rlllrlr.choose(code,U32.is_lt(code,175))

def face2rlllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlllrll(code)
    case False{}: face2rlllrlr(code)

def face2rlllrl(+code: U32) -> Glyph:
  face2rlllrl.choose(code,U32.is_lt(code,174))

def face2rlllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3342336,0,0,0}},Rows8{Row{1593824256,0,0,0},Row{4294966816,3,0,0},Row{4195532672,10,0,0},Row{4093665184,11,0,0},Row{4233486192,9,0,0},Row{4026531088,2,0,0},Row{720282112,0,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2rlllrrl(code: U32) -> Glyph:
  face2rlllrrl.choose(U32.is_eq(code,176))

def face2rlllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{4227858432,9,0,0},Row{4227858432,9,0,0},Row{4227858432,9,0,0},Row{4294966784,786431,0,0}},Rows8{Row{4294966784,786431,0,0},Row{4249109504,214091,0,0},Row{4227858432,9,0,0},Row{4227858432,9,0,0},zero_row(),Row{4294966784,786431,0,0},Row{4294966784,786431,0,0},Row{1145324544,214084,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlllrrrl(code: U32) -> Glyph:
  face2rlllrrrl.choose(U32.is_eq(code,177))

def face2rlllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1273939712,0,0,0},Row{4291489664,4,0,0}},Rows8{Row{4211100304,9,0,0},Row{4245684224,7,0,0},Row{4022468608,1,0,0},Row{771637248,0,0,0},Row{9434880,0,0,0},Row{2863529856,9,0,0},Row{4294967232,13,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2rlllrrrr(code: U32) -> Glyph:
  face2rlllrrrr.choose(U32.is_eq(code,178))

def face2rlllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlllrrrl(code)
    case False{}: face2rlllrrrr(code)

def face2rlllrrr(+code: U32) -> Glyph:
  face2rlllrrr.choose(code,U32.is_lt(code,178))

def face2rlllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlllrrl(code)
    case False{}: face2rlllrrr(code)

def face2rlllrr(+code: U32) -> Glyph:
  face2rlllrr.choose(code,U32.is_lt(code,177))

def face2rlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlllrl(code)
    case False{}: face2rlllrr(code)

def face2rlllr(+code: U32) -> Glyph:
  face2rlllr.choose(code,U32.is_lt(code,176))

def face2rlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllll(code)
    case False{}: face2rlllr(code)

def face2rlll(+code: U32) -> Glyph:
  face2rlll.choose(code,U32.is_lt(code,173))

def face2rllrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{10,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1559147520,0,0,0},Row{4290510672,5,0,0}},Rows8{Row{4160777072,11,0,0},Row{4229955584,9,0,0},Row{2399080448,0,0,0},Row{4273606656,9,0,0},Row{4127208784,47,0,0},Row{4272680864,13,0,0},Row{2382284544,1,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2rllrlll(code: U32) -> Glyph:
  face2rllrlll.choose(U32.is_eq(code,179))

def face2rllrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[zero_rows(),Rows8{Row{11526400,0,0,0},Row{1963776,0,0,0},Row{261632,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2rllrllrl(code: U32) -> Glyph:
  face2rllrllrl.choose(U32.is_eq(code,180))

def face2rllrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0}},Rows8{Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{393088,65488,0,0},Row{589696,65522,0,0},Row{1132461952,1376252,0,0},Row{4294836096,7339935,0,0},Row{3735420800,7333894,0,0}},Rows8{Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2rllrllrr(code: U32) -> Glyph:
  face2rllrllrr.choose(U32.is_eq(code,181))

def face2rllrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllrllrl(code)
    case False{}: face2rllrllrr(code)

def face2rllrllr(+code: U32) -> Glyph:
  face2rllrllr.choose(code,U32.is_lt(code,181))

def face2rllrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllrlll(code)
    case False{}: face2rllrllr(code)

def face2rllrll(+code: U32) -> Glyph:
  face2rllrll.choose(code,U32.is_lt(code,180))

def face2rllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{4293611520,40959,0,0},Row{4294965760,40959,0,0},Row{2147483488,40916,0,0},Row{1342177216,40896,0,0},Row{1342177264,40896,0,0},Row{1342177264,40896,0,0},Row{1342177216,40896,0,0},Row{1342177136,40896,0,0}},Rows8{Row{1342175744,40896,0,0},Row{1340891136,40896,0,0},Row{16777216,40896,0,0},Row{0,40896,0,0},Row{0,40896,0,0},Row{0,40896,0,0},Row{0,40896,0,0},Row{0,40896,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rllrlrl(code: U32) -> Glyph:
  face2rllrlrl.choose(U32.is_eq(code,182))

def face2rllrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{715264,0,0,0}},Rows8{Row{4194080,0,0,0},Row{715264,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2rllrlrrl(code: U32) -> Glyph:
  face2rllrlrrl.choose(U32.is_eq(code,183))

def face2rllrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{192768,0,0,0}},Rows8{Row{4912128,0,0,0},Row{33243392,0,0,0},Row{49872896,0,0,0},Row{11533056,0,0,0},Row{78336,0,0,0},zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2rllrlrrr(code: U32) -> Glyph:
  face2rllrlrrr.choose(U32.is_eq(code,184))

def face2rllrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllrlrrl(code)
    case False{}: face2rllrlrrr(code)

def face2rllrlrr(+code: U32) -> Glyph:
  face2rllrlrr.choose(code,U32.is_lt(code,184))

def face2rllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllrlrl(code)
    case False{}: face2rllrlrr(code)

def face2rllrlr(+code: U32) -> Glyph:
  face2rllrlr.choose(code,U32.is_lt(code,183))

def face2rllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllrll(code)
    case False{}: face2rllrlr(code)

def face2rllrl(+code: U32) -> Glyph:
  face2rllrl.choose(code,U32.is_lt(code,182))

def face2rllrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{14673408,0,0,0},Row{14679968,0,0,0}},Rows8{Row{14649808,0,0,0},Row{14643232,0,0,0},Row{14643200,0,0,0},Row{14643200,0,0,0},Row{14643200,0,0,0},Row{14643200,0,0,0},Row{14643200,0,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2rllrrll(code: U32) -> Glyph:
  face2rllrrll.choose(U32.is_eq(code,185))

def face2rllrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[zero_rows(),Rows8{Row{2382275072,1,0,0},Row{4272815664,29,0,0},Row{3506487232,143,0,0},Row{2147504114,223,0,0},Row{1610625011,239,0,0},Row{2147504114,223,0,0},Row{3506483136,143,0,0},Row{4272815664,29,0,0}},Rows8{Row{2382275328,1,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2rllrrlrl(code: U32) -> Glyph:
  face2rllrrlrl.choose(U32.is_eq(code,186))

def face2rllrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{4246011824,46,0,0},Row{3811507472,479,0,0},Row{1105191424,3071,0,0},Row{218054656,40951,0,0}},Rows8{Row{2952134656,524176,0,0},Row{3220504576,655232,0,0},Row{486486016,45046,0,0},Row{1121968640,7423,0,0},Row{3795778832,479,0,0},Row{4246011824,46,0,0},zero_row(),zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2rllrrlrr(code: U32) -> Glyph:
  face2rllrrlrr.choose(U32.is_eq(code,187))

def face2rllrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllrrlrl(code)
    case False{}: face2rllrrlrr(code)

def face2rllrrlr(+code: U32) -> Glyph:
  face2rllrrlr.choose(code,U32.is_lt(code,187))

def face2rllrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllrrll(code)
    case False{}: face2rllrrlr(code)

def face2rllrrl(+code: U32) -> Glyph:
  face2rllrrl.choose(code,U32.is_lt(code,186))

def face2rllrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{18,[zero_rows(),Rows8{Row{1047840,502464512,0,0},Row{1048289,83623936,0,0},Row{1045442,10452992,0,0},Row{1044753,1962752,0,0},Row{1044736,261392,0,0},Row{1044736,36752,0,0},Row{1044736,3316,0,0},Row{269480192,2283799549,4,0}},Rows8{Row{2685399296,4289724543,7,0},Row{4110417920,4277469195,7,0},Row{3994025984,4159508482,7,0},Row{1873805312,4134506496,7,0},Row{200671232,4128043776,7,0},Row{32382976,4294965248,143,0},Row{6270976,4239041792,92,0},Row{718592,4143972352,7,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rllrrrll(code: U32) -> Glyph:
  face2rllrrrll.choose(U32.is_eq(code,188))

def face2rllrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{19,[zero_rows(),Rows8{Row{1047840,502464512,0,0},Row{1048289,83623936,0,0},Row{1045442,10452992,0,0},Row{1044753,1962752,0,0},Row{1044736,261392,0,0},Row{1044736,36752,0,0},Row{1044736,3316,0,0},Row{269480192,4003595261,42,0}},Rows8{Row{2685399296,4277928063,223,0},Row{4110417920,281874443,510,0},Row{3994025984,536870914,207,0},Row{1873805312,3523215360,46,0},Row{200671232,3996123136,2,0},Row{32382976,1877278720,324,0},Row{6270976,4294901760,1279,0},Row{718592,4294901760,1279,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rllrrrlr(code: U32) -> Glyph:
  face2rllrrrlr.choose(U32.is_eq(code,189))

def face2rllrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllrrrll(code)
    case False{}: face2rllrrrlr(code)

def face2rllrrrl(+code: U32) -> Glyph:
  face2rllrrrl.choose(code,U32.is_lt(code,189))

def face2rllrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{20,[zero_rows(),Rows8{Row{63887360,4143972352,9,0},Row{520028032,3744464896,1,0},Row{1336945296,1337982976,0,0},Row{802226176,150470656,0,0},Row{99598336,14626816,0,0},Row{1605574656,4182272,0,0},Row{2947902112,522496,0,0},Row{1879048112,1073794880,392,0}},Rows8{Row{114223376,3791662817,767,0},Row{0,4194306042,766,0},Row{1342177280,2940207295,763,0},Row{3791650816,785449006,763,0},Row{4211081216,133693446,763,0},Row{2942304256,4294770688,16383,0},Row{518127616,2863202304,11006,0},Row{100401152,0,764,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rllrrrrl(code: U32) -> Glyph:
  face2rllrrrrl.choose(U32.is_eq(code,190))

def face2rllrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{12,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{2930769920,0,0,0},Row{4294115328,3,0,0},Row{2930769920,0,0,0},zero_row()},Rows8{Row{1161822208,0,0,0},Row{3217031168,0,0,0},Row{2951872512,0,0,0},Row{1610428416,0,0,0},Row{150992384,0,0,0},Row{6291280,0,0,0},Row{393136,0,0,0},Row{65504,1636,0,0}},Rows8{Row{196560,3837,0,0},Row{3042836352,2559,0,0},Row{4294966288,479,0,0},Row{3471601664,24,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2rllrrrrr(code: U32) -> Glyph:
  face2rllrrrrr.choose(U32.is_eq(code,191))

def face2rllrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllrrrrl(code)
    case False{}: face2rllrrrrr(code)

def face2rllrrrr(+code: U32) -> Glyph:
  face2rllrrrr.choose(code,U32.is_lt(code,191))

def face2rllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllrrrl(code)
    case False{}: face2rllrrrr(code)

def face2rllrrr(+code: U32) -> Glyph:
  face2rllrrr.choose(code,U32.is_lt(code,190))

def face2rllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllrrl(code)
    case False{}: face2rllrrr(code)

def face2rllrr(+code: U32) -> Glyph:
  face2rllrr.choose(code,U32.is_lt(code,188))

def face2rllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rllrl(code)
    case False{}: face2rllrr(code)

def face2rllr(+code: U32) -> Glyph:
  face2rllr.choose(code,U32.is_lt(code,185))

def face2rll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlll(code)
    case False{}: face2rllr(code)

def face2rll(+code: U32) -> Glyph:
  face2rll.choose(code,U32.is_lt(code,179))

def face2rlrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{3485466624,0,0,0},Row{4263510016,4,0,0},Row{4110417920,12,0,0},zero_row()},Rows8{Row{4279238656,239,0,0},Row{4284481536,1279,0,0},Row{3752853504,2815,0,0},Row{2683437056,7931,0,0},Row{1610022912,28663,0,0},Row{536608768,49139,0,0},Row{218046464,131024,0,0},Row{134184960,524176,0,0}},Rows8{Row{50319360,851776,0,0},Row{1156576000,3145284,0,0},Row{4294965248,9437183,0,0},Row{4294966528,14680063,0,0},Row{851776,67096576,0,0},Row{524176,167739392,0,0},Row{196576,251604992,0,0},Row{57332,1610416128,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrllll(code: U32) -> Glyph:
  face2rlrllll.choose(U32.is_eq(code,192))

def face2rlrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{0,3068,0,0},Row{1342177280,751,0,0},Row{3221225472,95,0,0},zero_row()},Rows8{Row{4279238656,239,0,0},Row{4284481536,1279,0,0},Row{3752853504,2815,0,0},Row{2683437056,7931,0,0},Row{1610022912,28663,0,0},Row{536608768,49139,0,0},Row{218046464,131024,0,0},Row{134184960,524176,0,0}},Rows8{Row{50319360,851776,0,0},Row{1156576000,3145284,0,0},Row{4294965248,9437183,0,0},Row{4294966528,14680063,0,0},Row{851776,67096576,0,0},Row{524176,167739392,0,0},Row{196576,251604992,0,0},Row{57332,1610416128,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrlllrl(code: U32) -> Glyph:
  face2rlrlllrl.choose(U32.is_eq(code,193))

def face2rlrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[Rows8{zero_row(),zero_row(),zero_row(),Row{4177526784,159,0,0},Row{3213885440,2300,0,0},Row{486080512,36817,0,0},zero_row(),zero_row()},Rows8{Row{4279238656,239,0,0},Row{4284481536,1279,0,0},Row{3752853504,2815,0,0},Row{2683437056,7931,0,0},Row{1610022912,28663,0,0},Row{536608768,49139,0,0},Row{218046464,131024,0,0},Row{134184960,524176,0,0}},Rows8{Row{50319360,851776,0,0},Row{1156576000,3145284,0,0},Row{4294965248,9437183,0,0},Row{4294966528,14680063,0,0},Row{851776,67096576,0,0},Row{524176,167739392,0,0},Row{196576,251604992,0,0},Row{57332,1610416128,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrlllrr(code: U32) -> Glyph:
  face2rlrlllrr.choose(U32.is_eq(code,194))

def face2rlrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrlllrl(code)
    case False{}: face2rlrlllrr(code)

def face2rlrlllr(+code: U32) -> Glyph:
  face2rlrlllr.choose(code,U32.is_lt(code,194))

def face2rlrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrllll(code)
    case False{}: face2rlrlllr(code)

def face2rlrlll(+code: U32) -> Glyph:
  face2rlrlll.choose(code,U32.is_lt(code,193))

def face2rlrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[Rows8{zero_row(),zero_row(),zero_row(),Row{1765801984,23072,0,0},Row{4294115328,20430,0,0},Row{1425473536,2540,0,0},zero_row(),zero_row()},Rows8{Row{4279238656,239,0,0},Row{4284481536,1279,0,0},Row{3752853504,2815,0,0},Row{2683437056,7931,0,0},Row{1610022912,28663,0,0},Row{536608768,49139,0,0},Row{218046464,131024,0,0},Row{134184960,524176,0,0}},Rows8{Row{50319360,851776,0,0},Row{1156576000,3145284,0,0},Row{4294965248,9437183,0,0},Row{4294966528,14680063,0,0},Row{851776,67096576,0,0},Row{524176,167739392,0,0},Row{196576,251604992,0,0},Row{57332,1610416128,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrllrl(code: U32) -> Glyph:
  face2rlrllrl.choose(U32.is_eq(code,195))

def face2rlrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[Rows8{zero_row(),zero_row(),zero_row(),Row{148176896,23952,0,0},Row{536608768,53234,0,0},Row{182845440,28320,0,0},zero_row(),zero_row()},Rows8{Row{4279238656,239,0,0},Row{4284481536,1279,0,0},Row{3752853504,2815,0,0},Row{2683437056,7931,0,0},Row{1610022912,28663,0,0},Row{536608768,49139,0,0},Row{218046464,131024,0,0},Row{134184960,524176,0,0}},Rows8{Row{50319360,851776,0,0},Row{1156576000,3145284,0,0},Row{4294965248,9437183,0,0},Row{4294966528,14680063,0,0},Row{851776,67096576,0,0},Row{524176,167739392,0,0},Row{196576,251604992,0,0},Row{57332,1610416128,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrllrrl(code: U32) -> Glyph:
  face2rlrllrrl.choose(U32.is_eq(code,196))

def face2rlrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[Rows8{zero_row(),zero_row(),Row{3910139904,414,0,0},Row{1603272704,2549,0,0},Row{198180864,3504,0,0},Row{782237696,2786,0,0},Row{4229955584,463,0,0},Row{268435456,1,0,0}},Rows8{Row{4279238656,239,0,0},Row{4284481536,1279,0,0},Row{3752853504,2815,0,0},Row{2683437056,7931,0,0},Row{1610022912,28663,0,0},Row{536608768,49139,0,0},Row{218046464,131024,0,0},Row{134184960,524176,0,0}},Rows8{Row{50319360,851776,0,0},Row{1156576000,3145284,0,0},Row{4294965248,9437183,0,0},Row{4294966528,14680063,0,0},Row{851776,67096576,0,0},Row{524176,167739392,0,0},Row{196576,251604992,0,0},Row{57332,1610416128,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrllrrr(code: U32) -> Glyph:
  face2rlrllrrr.choose(U32.is_eq(code,197))

def face2rlrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrllrrl(code)
    case False{}: face2rlrllrrr(code)

def face2rlrllrr(+code: U32) -> Glyph:
  face2rlrllrr.choose(code,U32.is_lt(code,197))

def face2rlrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrllrl(code)
    case False{}: face2rlrllrr(code)

def face2rlrllr(+code: U32) -> Glyph:
  face2rlrllr.choose(code,U32.is_lt(code,196))

def face2rlrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrlll(code)
    case False{}: face2rlrllr(code)

def face2rlrll(+code: U32) -> Glyph:
  face2rlrll.choose(code,U32.is_lt(code,195))

def face2rlrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{22,[zero_rows(),Rows8{Row{2147483648,4294967295,983039,0},Row{3774873600,4294966255,983039,0},Row{4127195136,1151333503,279620,0},Row{4244635648,8385566,0,0},Row{4283432960,8385545,0,0},Row{4289724416,8385539,0,0},Row{3220373504,8385536,0,0},Row{1610219520,4294964224,524287,0}},Rows8{Row{234823680,4294964224,524287,0},Row{1258258432,1151334212,148548,0},Row{4294959360,8388607,0,0},Row{4294964992,8388607,0,0},Row{4193536,8385536,0,0},Row{851792,1151333376,279620,0},Row{393152,4294964224,1048575,0},Row{61428,4294964224,1048575,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrlrll(code: U32) -> Glyph:
  face2rlrlrll.choose(U32.is_eq(code,198))

def face2rlrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[zero_rows(),Rows8{Row{3680567296,27631,0,0},Row{4294778880,3014655,0,0},Row{1811931648,31456356,0,0},Row{9436160,167743488,0,0},Row{786224,251531264,0,0},Row{393104,339935232,0,0},Row{196528,0,0,0},Row{65488,0,0,0}},Rows8{Row{65488,0,0,0},Row{196528,0,0,0},Row{393104,339935232,0,0},Row{786224,251531264,0,0},Row{8387584,167743488,0,0},Row{1811931648,31456356,0,0},Row{4294782976,2949119,0,0},Row{4217438208,27615,0,0}},Rows8{Row{1610612736,927,0,0},Row{536870912,3524,0,0},Row{0,4033,0,0},Row{3758096384,2303,0,0},Row{805306368,19,0,0},zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2rlrlrlrl(code: U32) -> Glyph:
  face2rlrlrlrl.choose(U32.is_eq(code,199))

def face2rlrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{184356864,0,0,0},Row{804519936,0,0,0},Row{2675965952,0,0,0},zero_row()},Rows8{Row{4294967136,65535,0,0},Row{4294967136,65535,0,0},Row{1145700192,17476,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{4294967136,32767,0,0}},Rows8{Row{4294967136,32767,0,0},Row{1145700192,9284,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{1145700192,17476,0,0},Row{4294967136,131071,0,0},Row{4294967136,131071,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrlrlrr(code: U32) -> Glyph:
  face2rlrlrlrr.choose(U32.is_eq(code,200))

def face2rlrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrlrlrl(code)
    case False{}: face2rlrlrlrr(code)

def face2rlrlrlr(+code: U32) -> Glyph:
  face2rlrlrlr.choose(code,U32.is_lt(code,200))

def face2rlrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrlrll(code)
    case False{}: face2rlrlrlr(code)

def face2rlrlrl(+code: U32) -> Glyph:
  face2rlrlrl.choose(code,U32.is_lt(code,199))

def face2rlrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{3774873600,159,0,0},Row{4143972352,29,0,0},Row{4262461440,3,0,0},zero_row()},Rows8{Row{4294967136,65535,0,0},Row{4294967136,65535,0,0},Row{1145700192,17476,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{4294967136,32767,0,0}},Rows8{Row{4294967136,32767,0,0},Row{1145700192,9284,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{1145700192,17476,0,0},Row{4294967136,131071,0,0},Row{4294967136,131071,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrlrrll(code: U32) -> Glyph:
  face2rlrlrrll.choose(U32.is_eq(code,201))

def face2rlrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),Row{4289789952,7,0,0},Row{3673886720,111,0,0},Row{549433600,1790,0,0},zero_row(),zero_row()},Rows8{Row{4294967136,65535,0,0},Row{4294967136,65535,0,0},Row{1145700192,17476,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{4294967136,32767,0,0}},Rows8{Row{4294967136,32767,0,0},Row{1145700192,9284,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{1145700192,17476,0,0},Row{4294967136,131071,0,0},Row{4294967136,131071,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrlrrlr(code: U32) -> Glyph:
  face2rlrlrrlr.choose(U32.is_eq(code,202))

def face2rlrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrlrrll(code)
    case False{}: face2rlrlrrlr(code)

def face2rlrlrrl(+code: U32) -> Glyph:
  face2rlrlrrl.choose(code,U32.is_lt(code,202))

def face2rlrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),Row{8220672,970,0,0},Row{1089462272,2815,0,0},Row{277774336,1260,0,0},zero_row(),zero_row()},Rows8{Row{4294967136,65535,0,0},Row{4294967136,65535,0,0},Row{1145700192,17476,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{4294967136,32767,0,0}},Rows8{Row{4294967136,32767,0,0},Row{1145700192,9284,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{1145700192,17476,0,0},Row{4294967136,131071,0,0},Row{4294967136,131071,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrlrrrl(code: U32) -> Glyph:
  face2rlrlrrrl.choose(U32.is_eq(code,203))

def face2rlrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{57264,0,0,0},Row{392736,0,0,0},Row{914688,0,0,0},zero_row()},Rows8{Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0}},Rows8{Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrlrrrr(code: U32) -> Glyph:
  face2rlrlrrrr.choose(U32.is_eq(code,204))

def face2rlrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrlrrrl(code)
    case False{}: face2rlrlrrrr(code)

def face2rlrlrrr(+code: U32) -> Glyph:
  face2rlrlrrr.choose(code,U32.is_lt(code,204))

def face2rlrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrlrrl(code)
    case False{}: face2rlrlrrr(code)

def face2rlrlrr(+code: U32) -> Glyph:
  face2rlrlrr.choose(code,U32.is_lt(code,203))

def face2rlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrlrl(code)
    case False{}: face2rlrlrr(code)

def face2rlrlr(+code: U32) -> Glyph:
  face2rlrlr.choose(code,U32.is_lt(code,201))

def face2rlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrll(code)
    case False{}: face2rlrlr(code)

def face2rlrl(+code: U32) -> Glyph:
  face2rlrl.choose(code,U32.is_lt(code,198))

def face2rlrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{13615104,0,0,0},Row{3077120,0,0,0},Row{457728,0,0,0},zero_row()},Rows8{Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0}},Rows8{Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0},Row{524128,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrrlll(code: U32) -> Glyph:
  face2rlrrlll.choose(U32.is_eq(code,205))

def face2rlrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),Row{11532544,0,0,0},Row{167497616,0,0,0},Row{2680233465,0,0,0},zero_row(),zero_row()},Rows8{Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0}},Rows8{Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrrllrl(code: U32) -> Glyph:
  face2rlrrllrl.choose(U32.is_eq(code,206))

def face2rlrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),Row{1568672212,0,0,0},Row{3757125627,0,0,0},Row{1855982565,0,0,0},zero_row(),zero_row()},Rows8{Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0}},Rows8{Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0},Row{8386048,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrrllrr(code: U32) -> Glyph:
  face2rlrrllrr.choose(U32.is_eq(code,207))

def face2rlrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrrllrl(code)
    case False{}: face2rlrrllrr(code)

def face2rlrrllr(+code: U32) -> Glyph:
  face2rlrrllr.choose(code,U32.is_lt(code,207))

def face2rlrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrrlll(code)
    case False{}: face2rlrrllr(code)

def face2rlrrll(+code: U32) -> Glyph:
  face2rlrrll.choose(code,U32.is_lt(code,206))

def face2rlrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{17,[zero_rows(),Rows8{Row{4294966016,14542,0,0},Row{4294966016,589823,0,0},Row{1147140864,10485381,0,0},Row{3144448,100647168,0,0},Row{3144448,201269248,0,0},Row{3144448,804978688,0,0},Row{1148190531,1341652995,0,0},Row{4294967292,1610022924,0,0}},Rows8{Row{4294967292,1610022924,0,0},Row{3144448,1341652992,0,0},Row{3144448,804978688,0,0},Row{3144448,201269248,0,0},Row{3144448,100647168,0,0},Row{1147140864,10485381,0,0},Row{4294966016,589823,0,0},Row{4294966016,14542,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrrlrl(code: U32) -> Glyph:
  face2rlrrlrl.choose(U32.is_eq(code,208))

def face2rlrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{17,[Rows8{zero_row(),zero_row(),zero_row(),Row{2300575744,34818,0,0},Row{4290772992,44991,0,0},Row{703660032,11497,0,0},zero_row(),zero_row()},Rows8{Row{4194144,536608768,0,0},Row{13631328,536608768,0,0},Row{117440352,536608768,0,0},Row{788528992,536608768,0,0},Row{2952396640,536608768,0,0},Row{4290183008,536608772,0,0},Row{4281859936,536608797,0,0},Row{4161339232,536608911,0,0}},Rows8{Row{3507027808,536609791,0,0},Row{1342766944,536611839,0,0},Row{589664,536633338,0,0},Row{589664,536600545,0,0},Row{589664,536805216,0,0},Row{589664,536869632,0,0},Row{589664,536867328,0,0},Row{589664,536834048,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrrlrrl(code: U32) -> Glyph:
  face2rlrrlrrl.choose(U32.is_eq(code,209))

def face2rlrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{17,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{4283432960,4,0,0},Row{4177526784,11,0,0},Row{3506438144,79,0,0},zero_row()},Rows8{Row{3680501760,23519,0,0},Row{4294778880,2949119,0,0},Row{1811931648,31456356,0,0},Row{8387328,184520704,0,0},Row{786224,805109760,0,0},Row{393104,2146893824,0,0},Row{196528,2951938048,0,0},Row{65488,3220307968,0,0}},Rows8{Row{65488,3220307968,0,0},Row{196528,2951938048,0,0},Row{393104,2146893824,0,0},Row{786224,805109760,0,0},Row{8387584,184520704,0,0},Row{1811931648,31456356,0,0},Row{4294778880,2949119,0,0},Row{3680501760,23519,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrrlrrr(code: U32) -> Glyph:
  face2rlrrlrrr.choose(U32.is_eq(code,210))

def face2rlrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrrlrrl(code)
    case False{}: face2rlrrlrrr(code)

def face2rlrrlrr(+code: U32) -> Glyph:
  face2rlrrlrr.choose(code,U32.is_lt(code,210))

def face2rlrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrrlrl(code)
    case False{}: face2rlrrlrr(code)

def face2rlrrlr(+code: U32) -> Glyph:
  face2rlrrlr.choose(code,U32.is_lt(code,209))

def face2rlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrrll(code)
    case False{}: face2rlrrlr(code)

def face2rlrrl(+code: U32) -> Glyph:
  face2rlrrl.choose(code,U32.is_lt(code,208))

def face2rlrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{17,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{0,20469,0,0},Row{0,2301,0,0},Row{1342177280,207,0,0},zero_row()},Rows8{Row{3680501760,23519,0,0},Row{4294778880,2949119,0,0},Row{1811931648,31456356,0,0},Row{8387328,184520704,0,0},Row{786224,805109760,0,0},Row{393104,2146893824,0,0},Row{196528,2951938048,0,0},Row{65488,3220307968,0,0}},Rows8{Row{65488,3220307968,0,0},Row{196528,2951938048,0,0},Row{393104,2146893824,0,0},Row{786224,805109760,0,0},Row{8387584,184520704,0,0},Row{1811931648,31456356,0,0},Row{4294778880,2949119,0,0},Row{3680501760,23519,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrrrll(code: U32) -> Glyph:
  face2rlrrrll.choose(U32.is_eq(code,211))

def face2rlrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{17,[Rows8{zero_row(),zero_row(),zero_row(),Row{3808428032,751,0,0},Row{4264558592,12024,0,0},Row{1877147648,188272,0,0},zero_row(),zero_row()},Rows8{Row{3680501760,23519,0,0},Row{4294778880,2949119,0,0},Row{1811931648,31456356,0,0},Row{8387328,184520704,0,0},Row{786224,805109760,0,0},Row{393104,2146893824,0,0},Row{196528,2951938048,0,0},Row{65488,3220307968,0,0}},Rows8{Row{65488,3220307968,0,0},Row{196528,2951938048,0,0},Row{393104,2146893824,0,0},Row{786224,805109760,0,0},Row{8387584,184520704,0,0},Row{1811931648,31456356,0,0},Row{4294778880,2949119,0,0},Row{3680501760,23519,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrrrlrl(code: U32) -> Glyph:
  face2rlrrrlrl.choose(U32.is_eq(code,212))

def face2rlrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{17,[Rows8{zero_row(),zero_row(),zero_row(),Row{2282749952,38659,0,0},Row{4289724416,49087,0,0},Row{737148928,15849,0,0},zero_row(),zero_row()},Rows8{Row{3680501760,23519,0,0},Row{4294778880,2949119,0,0},Row{1811931648,31456356,0,0},Row{8387328,184520704,0,0},Row{786224,805109760,0,0},Row{393104,2146893824,0,0},Row{196528,2951938048,0,0},Row{65488,3220307968,0,0}},Rows8{Row{65488,3220307968,0,0},Row{196528,2951938048,0,0},Row{393104,2146893824,0,0},Row{786224,805109760,0,0},Row{8387584,184520704,0,0},Row{1811931648,31456356,0,0},Row{4294778880,2949119,0,0},Row{3680501760,23519,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrrrlrr(code: U32) -> Glyph:
  face2rlrrrlrr.choose(U32.is_eq(code,213))

def face2rlrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrrrlrl(code)
    case False{}: face2rlrrrlrr(code)

def face2rlrrrlr(+code: U32) -> Glyph:
  face2rlrrrlr.choose(code,U32.is_lt(code,213))

def face2rlrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrrrll(code)
    case False{}: face2rlrrrlr(code)

def face2rlrrrl(+code: U32) -> Glyph:
  face2rlrrrl.choose(code,U32.is_lt(code,212))

def face2rlrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{17,[Rows8{zero_row(),zero_row(),zero_row(),Row{1018232832,44080,0,0},Row{2683633664,327584,0,0},Row{1052835840,118336,0,0},zero_row(),zero_row()},Rows8{Row{3680501760,23519,0,0},Row{4294778880,2949119,0,0},Row{1811931648,31456356,0,0},Row{8387328,184520704,0,0},Row{786224,805109760,0,0},Row{393104,2146893824,0,0},Row{196528,2951938048,0,0},Row{65488,3220307968,0,0}},Rows8{Row{65488,3220307968,0,0},Row{196528,2951938048,0,0},Row{393104,2146893824,0,0},Row{786224,805109760,0,0},Row{8387584,184520704,0,0},Row{1811931648,31456356,0,0},Row{4294778880,2949119,0,0},Row{3680501760,23519,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrrrrll(code: U32) -> Glyph:
  face2rlrrrrll.choose(U32.is_eq(code,214))

def face2rlrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{163840,25600,0,0},Row{3012608,458288,0,0},Row{48232192,393187,0,0},Row{1577021440,24574,0,0}},Rows8{Row{4294377472,1535,0,0},Row{4287627264,127,0,0},Row{4293066752,735,0,0},Row{2952671232,11775,0,0},Row{100655872,188407,0,0},Row{6290176,655216,0,0},Row{377088,46848,0,0},zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2rlrrrrlr(code: U32) -> Glyph:
  face2rlrrrrlr.choose(U32.is_eq(code,215))

def face2rlrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrrrrll(code)
    case False{}: face2rlrrrrlr(code)

def face2rlrrrrl(+code: U32) -> Glyph:
  face2rlrrrrl.choose(code,U32.is_lt(code,215))

def face2rlrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{17,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{0,6291456,0,0}},Rows8{Row{3680501760,183983071,0,0},Row{4294778880,67108863,0,0},Row{1811931648,33553508,0,0},Row{8387328,184547328,0,0},Row{786224,805236528,0,0},Row{393104,2146918353,0,0},Row{196528,2951940857,0,0},Row{1342242768,3220308447,0,0}},Rows8{Row{3774939088,3220308047,0,0},Row{4211277744,2951938056,0,0},Row{3479568272,2146893824,0,0},Row{1073676080,805109760,0,0},Row{134216704,184520704,0,0},Row{1811935744,31456356,0,0},Row{4294964224,2949119,0,0},Row{3680959232,23519,0,0}},Rows8{Row{24832,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2rlrrrrrl(code: U32) -> Glyph:
  face2rlrrrrrl.choose(U32.is_eq(code,216))

def face2rlrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{3752853504,0,0,0},Row{4245684224,6,0,0},Row{4093640704,13,0,0},zero_row()},Rows8{Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0}},Rows8{Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{589648,150949888,0,0},Row{786240,134184960,0,0},Row{6290944,50323968,0,0},Row{1509946880,9436805,0,0},Row{4294930432,655359,0,0},Row{3984785408,18910,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rlrrrrrr(code: U32) -> Glyph:
  face2rlrrrrrr.choose(U32.is_eq(code,217))

def face2rlrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrrrrrl(code)
    case False{}: face2rlrrrrrr(code)

def face2rlrrrrr(+code: U32) -> Glyph:
  face2rlrrrrr.choose(code,U32.is_lt(code,217))

def face2rlrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrrrrl(code)
    case False{}: face2rlrrrrr(code)

def face2rlrrrr(+code: U32) -> Glyph:
  face2rlrrrr.choose(code,U32.is_lt(code,216))

def face2rlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrrrl(code)
    case False{}: face2rlrrrr(code)

def face2rlrrr(+code: U32) -> Glyph:
  face2rlrrr.choose(code,U32.is_lt(code,214))

def face2rlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrrl(code)
    case False{}: face2rlrrr(code)

def face2rlrr(+code: U32) -> Glyph:
  face2rlrr.choose(code,U32.is_lt(code,211))

def face2rlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rlrl(code)
    case False{}: face2rlrr(code)

def face2rlr(+code: U32) -> Glyph:
  face2rlr.choose(code,U32.is_lt(code,205))

def face2rl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rll(code)
    case False{}: face2rlr(code)

def face2rl(+code: U32) -> Glyph:
  face2rl.choose(code,U32.is_lt(code,192))

def face2rrlllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{0,7675,0,0},Row{805306368,1023,0,0},Row{2952790016,111,0,0},zero_row()},Rows8{Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0}},Rows8{Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{589648,150949888,0,0},Row{786240,134184960,0,0},Row{6290944,50323968,0,0},Row{1509946880,9436805,0,0},Row{4294930432,655359,0,0},Row{3984785408,18910,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlllll(code: U32) -> Glyph:
  face2rrlllll.choose(U32.is_eq(code,218))

def face2rrllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[Rows8{zero_row(),zero_row(),zero_row(),Row{4160749568,175,0,0},Row{3481272320,2810,0,0},Row{788004864,44992,0,0},zero_row(),zero_row()},Rows8{Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0}},Rows8{Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{589648,150949888,0,0},Row{786240,134184960,0,0},Row{6290944,50323968,0,0},Row{1509946880,9436805,0,0},Row{4294930432,655359,0,0},Row{3984785408,18910,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrllllrl(code: U32) -> Glyph:
  face2rrllllrl.choose(U32.is_eq(code,219))

def face2rrllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[Rows8{zero_row(),zero_row(),zero_row(),Row{164888576,28016,0,0},Row{1073348608,57328,0,0},Row{199557120,32400,0,0},zero_row(),zero_row()},Rows8{Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{524128,167723008,0,0}},Rows8{Row{524128,167723008,0,0},Row{524128,167723008,0,0},Row{589648,150949888,0,0},Row{786240,134184960,0,0},Row{6290944,50323968,0,0},Row{1509946880,9436805,0,0},Row{4294930432,655359,0,0},Row{3984785408,18910,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrllllrr(code: U32) -> Glyph:
  face2rrllllrr.choose(U32.is_eq(code,220))

def face2rrllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrllllrl(code)
    case False{}: face2rrllllrr(code)

def face2rrllllr(+code: U32) -> Glyph:
  face2rrllllr.choose(code,U32.is_lt(code,220))

def face2rrllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlllll(code)
    case False{}: face2rrllllr(code)

def face2rrllll(+code: U32) -> Glyph:
  face2rrllll.choose(code,U32.is_lt(code,219))

def face2rrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{16,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{268435456,2558,0,0},Row{1879048192,479,0,0},Row{3774873600,63,0,0},zero_row()},Rows8{Row{262131,234844160,0,0},Row{786320,83878144,0,0},Row{5242384,11532288,0,0},Row{13628928,3079968,0,0},Row{117424128,524176,0,0},Row{520040448,57331,0,0},Row{2147024896,24570,0,0},Row{4024500224,3071,0,0}},Rows8{Row{4284481536,767,0,0},Row{4227858432,143,0,0},Row{4160749568,95,0,0},Row{4160749568,95,0,0},Row{4160749568,95,0,0},Row{4160749568,95,0,0},Row{4160749568,95,0,0},Row{4160749568,95,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlllrl(code: U32) -> Glyph:
  face2rrlllrl.choose(U32.is_eq(code,221))

def face2rrlllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{458608,0,0,0},Row{458608,0,0,0},Row{458608,0,0,0},Row{4026531696,653,0,0},Row{4294967152,24319,0,0},Row{1414135664,192505,0,0},Row{458608,589680,0,0},Row{458608,720656,0,0}},Rows8{Row{458608,720656,0,0},Row{458608,589664,0,0},Row{1414135664,192504,0,0},Row{4294967152,24319,0,0},Row{4026531696,669,0,0},Row{458608,0,0,0},Row{458608,0,0,0},Row{458608,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlllrrl(code: U32) -> Glyph:
  face2rrlllrrl.choose(U32.is_eq(code,222))

def face2rrlllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{4023984128,380,0,0},Row{4294964224,11775,0,0},Row{1437597200,49148,0,0},Row{786240,131041,0,0},Row{524128,130992,0,0},Row{458592,57313,0,0},Row{1392967520,20475,0,0},Row{4211539808,1263,0,0}},Rows8{Row{4211539808,114687,0,0},Row{458592,655266,0,0},Row{458592,1047808,0,0},Row{458592,3144448,0,0},Row{458592,2096656,0,0},Row{1124532064,786373,0,0},Row{4228317024,192511,0,0},Row{4228317024,6367,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlllrrr(code: U32) -> Glyph:
  face2rrlllrrr.choose(U32.is_eq(code,223))

def face2rrlllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlllrrl(code)
    case False{}: face2rrlllrrr(code)

def face2rrlllrr(+code: U32) -> Glyph:
  face2rrlllrr.choose(code,U32.is_lt(code,223))

def face2rrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlllrl(code)
    case False{}: face2rrlllrr(code)

def face2rrlllr(+code: U32) -> Glyph:
  face2rrlllr.choose(code,U32.is_lt(code,222))

def face2rrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrllll(code)
    case False{}: face2rrlllr(code)

def face2rrlll(+code: U32) -> Glyph:
  face2rrlll.choose(code,U32.is_lt(code,221))

def face2rrllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{32477184,0,0,0},Row{150802432,0,0,0},Row{519241728,0,0,0},zero_row(),Row{3739967488,41,0,0},Row{4294966032,1279,0,0},Row{2489122672,3583,0,0},Row{38704,8187,0,0}},Rows8{Row{822083584,12285,0,0},Row{4293624320,12287,0,0},Row{2060451680,12283,0,0},Row{188385,12282,0,0},Row{268476402,12286,0,0},Row{3595038705,12287,0,0},Row{4026531712,12281,0,0},Row{720357120,12280,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrllrll(code: U32) -> Glyph:
  face2rrllrll.choose(U32.is_eq(code,224))

def face2rrllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{4177526784,30,0,0},Row{4280287232,4,0,0},Row{2408579072,0,0,0},zero_row(),Row{3739967488,41,0,0},Row{4294966032,1279,0,0},Row{2489122672,3583,0,0},Row{38704,8187,0,0}},Rows8{Row{822083584,12285,0,0},Row{4293624320,12287,0,0},Row{2060451680,12283,0,0},Row{188385,12282,0,0},Row{268476402,12286,0,0},Row{3595038705,12287,0,0},Row{4026531712,12281,0,0},Row{720357120,12280,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrllrlrl(code: U32) -> Glyph:
  face2rrllrlrl.choose(U32.is_eq(code,225))

def face2rrllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{3489005568,1,0,0}},Rows8{Row{4192165888,27,0,0},Row{2688480768,191,0,0},zero_row(),zero_row(),Row{3739967488,41,0,0},Row{4294966032,1279,0,0},Row{2489122672,3583,0,0},Row{38704,8187,0,0}},Rows8{Row{822083584,12285,0,0},Row{4293624320,12287,0,0},Row{2060451680,12283,0,0},Row{188385,12282,0,0},Row{268476402,12286,0,0},Row{3595038705,12287,0,0},Row{4026531712,12281,0,0},Row{720357120,12280,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrllrlrr(code: U32) -> Glyph:
  face2rrllrlrr.choose(U32.is_eq(code,226))

def face2rrllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrllrlrl(code)
    case False{}: face2rrllrlrr(code)

def face2rrllrlr(+code: U32) -> Glyph:
  face2rrllrlr.choose(code,U32.is_lt(code,226))

def face2rrllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrllrll(code)
    case False{}: face2rrllrlr(code)

def face2rrllrl(+code: U32) -> Glyph:
  face2rrllrl.choose(code,U32.is_lt(code,225))

def face2rrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{24719360,121,0,0}},Rows8{Row{3472875776,143,0,0},Row{3929535488,27,0,0},zero_row(),zero_row(),Row{3739967488,41,0,0},Row{4294966032,1279,0,0},Row{2489122672,3583,0,0},Row{38704,8187,0,0}},Rows8{Row{822083584,12285,0,0},Row{4293624320,12287,0,0},Row{2060451680,12283,0,0},Row{188385,12282,0,0},Row{268476402,12286,0,0},Row{3595038705,12287,0,0},Row{4026531712,12281,0,0},Row{720357120,12280,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrllrrl(code: U32) -> Glyph:
  face2rrllrrl.choose(U32.is_eq(code,227))

def face2rrllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1612432128,125,0,0}},Rows8{Row{3495950336,255,0,0},Row{1880941312,158,0,0},zero_row(),zero_row(),Row{3739967488,41,0,0},Row{4294966032,1279,0,0},Row{2489122672,3583,0,0},Row{38704,8187,0,0}},Rows8{Row{822083584,12285,0,0},Row{4293624320,12287,0,0},Row{2060451680,12283,0,0},Row{188385,12282,0,0},Row{268476402,12286,0,0},Row{3595038705,12287,0,0},Row{4026531712,12281,0,0},Row{720357120,12280,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrllrrrl(code: U32) -> Glyph:
  face2rrllrrrl.choose(U32.is_eq(code,228))

def face2rrllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2933325824,2,0,0},Row{3565117440,12,0,0}},Rows8{Row{2148442112,31,0,0},Row{3243208704,14,0,0},Row{3757703168,3,0,0},Row{34603008,0,0,0},Row{3739967488,41,0,0},Row{4294966032,1279,0,0},Row{2489122672,3583,0,0},Row{38704,8187,0,0}},Rows8{Row{822083584,12285,0,0},Row{4293624320,12287,0,0},Row{2060451680,12283,0,0},Row{188385,12282,0,0},Row{268476402,12286,0,0},Row{3595038705,12287,0,0},Row{4026531712,12281,0,0},Row{720357120,12280,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrllrrrr(code: U32) -> Glyph:
  face2rrllrrrr.choose(U32.is_eq(code,229))

def face2rrllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrllrrrl(code)
    case False{}: face2rrllrrrr(code)

def face2rrllrrr(+code: U32) -> Glyph:
  face2rrllrrr.choose(code,U32.is_lt(code,229))

def face2rrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrllrrl(code)
    case False{}: face2rrllrrr(code)

def face2rrllrr(+code: U32) -> Glyph:
  face2rrllrr.choose(code,U32.is_lt(code,228))

def face2rrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrllrl(code)
    case False{}: face2rrllrr(code)

def face2rrllr(+code: U32) -> Glyph:
  face2rrllr.choose(code,U32.is_lt(code,227))

def face2rrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlll(code)
    case False{}: face2rrllr(code)

def face2rrll(+code: U32) -> Glyph:
  face2rrll.choose(code,U32.is_lt(code,224))

def face2rrlrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{20,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{3756744704,2935849239,4,0},Row{4294966032,4294966719,127,0},Row{2220621696,3595104255,1279,0},Row{29984,268460027,3070,0}},Rows8{Row{1144061952,1145327355,4091,0},Row{4294956544,4294967295,12287,0},Row{4294967168,4294967295,16383,0},Row{1437681,3578,0,0},Row{268476402,20477,1398,0},Row{3326603249,2774069247,2815,0},Row{4294967168,4294966844,463,0},Row{2096023040,3472720128,23,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlrlll(code: U32) -> Glyph:
  face2rrlrlll.choose(U32.is_eq(code,230))

def face2rrlrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{3755548672,75,0,0},Row{4294960384,2559,0,0},Row{1687158304,24573,0,0},Row{524176,40946,0,0}},Rows8{Row{131024,288,0,0},Row{57328,0,0,0},Row{57328,0,0,0},Row{131024,288,0,0},Row{524176,45026,0,0},Row{1687158304,28669,0,0},Row{4294960384,2815,0,0},Row{4292419584,75,0,0}},Rows8{Row{3206545408,5,0,0},Row{2484076544,63,0,0},Row{1879048192,79,0,0},Row{4287627264,28,0,0},Row{589299712,0,0,0},zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2rrlrllrl(code: U32) -> Glyph:
  face2rrlrllrl.choose(U32.is_eq(code,231))

def face2rrlrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{100614144,0,0,0},Row{234356736,0,0,0},Row{1606418432,0,0,0},zero_row(),Row{3755548672,58,0,0},Row{4294960384,1791,0,0},Row{1686044192,16381,0,0},Row{262032,45026,0,0}},Rows8{Row{1145364432,61380,0,0},Row{4294967280,65535,0,0},Row{4294967280,131071,0,0},Row{57296,0,0,0},Row{327568,13680,0,0},Row{1418657312,40954,0,0},Row{4294960384,7423,0,0},Row{4007206912,364,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlrllrr(code: U32) -> Glyph:
  face2rrlrllrr.choose(U32.is_eq(code,232))

def face2rrlrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlrllrl(code)
    case False{}: face2rrlrllrr(code)

def face2rrlrllr(+code: U32) -> Glyph:
  face2rrlrllr.choose(code,U32.is_lt(code,232))

def face2rrlrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlrlll(code)
    case False{}: face2rrlrllr(code)

def face2rrlrll(+code: U32) -> Glyph:
  face2rrlrll.choose(code,U32.is_lt(code,231))

def face2rrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{4093640704,95,0,0},Row{4227858432,9,0,0},Row{3745513472,1,0,0},zero_row(),Row{3755548672,58,0,0},Row{4294960384,1791,0,0},Row{1686044192,16381,0,0},Row{262032,45026,0,0}},Rows8{Row{1145364432,61380,0,0},Row{4294967280,65535,0,0},Row{4294967280,131071,0,0},Row{57296,0,0,0},Row{327568,13680,0,0},Row{1418657312,40954,0,0},Row{4294960384,7423,0,0},Row{4007206912,364,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlrlrl(code: U32) -> Glyph:
  face2rrlrlrl.choose(U32.is_eq(code,233))

def face2rrlrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4024565760,3,0,0}},Rows8{Row{4177403904,62,0,0},Row{1350558208,1007,0,0},zero_row(),zero_row(),Row{3755548672,58,0,0},Row{4294960384,1791,0,0},Row{1686044192,16381,0,0},Row{262032,45026,0,0}},Rows8{Row{1145364432,61380,0,0},Row{4294967280,65535,0,0},Row{4294967280,131071,0,0},Row{57296,0,0,0},Row{327568,13680,0,0},Row{1418657312,40954,0,0},Row{4294960384,7423,0,0},Row{4007206912,364,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlrlrrl(code: U32) -> Glyph:
  face2rrlrlrrl.choose(U32.is_eq(code,234))

def face2rrlrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{540844032,444,0,0}},Rows8{Row{2159014656,1535,0,0},Row{810467584,462,0,0},zero_row(),zero_row(),Row{3755548672,58,0,0},Row{4294960384,1791,0,0},Row{1686044192,16381,0,0},Row{262032,45026,0,0}},Rows8{Row{1145364432,61380,0,0},Row{4294967280,65535,0,0},Row{4294967280,131071,0,0},Row{57296,0,0,0},Row{327568,13680,0,0},Row{1418657312,40954,0,0},Row{4294960384,7423,0,0},Row{4007206912,364,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlrlrrr(code: U32) -> Glyph:
  face2rrlrlrrr.choose(U32.is_eq(code,235))

def face2rrlrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlrlrrl(code)
    case False{}: face2rrlrlrrr(code)

def face2rrlrlrr(+code: U32) -> Glyph:
  face2rrlrlrr.choose(code,U32.is_lt(code,235))

def face2rrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlrlrl(code)
    case False{}: face2rrlrlrr(code)

def face2rrlrlr(+code: U32) -> Glyph:
  face2rrlrlr.choose(code,U32.is_lt(code,234))

def face2rrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlrll(code)
    case False{}: face2rrlrlr(code)

def face2rrlrl(+code: U32) -> Glyph:
  face2rrlrl.choose(code,U32.is_lt(code,233))

def face2rrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{Row{45009,0,0,0},Row{261936,0,0,0},Row{718592,0,0,0},zero_row(),Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0}},Rows8{Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlrrll(code: U32) -> Glyph:
  face2rrlrrll.choose(U32.is_eq(code,236))

def face2rrlrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{7,[zero_rows(),Rows8{Row{11522048,0,0,0},Row{1963520,0,0,0},Row{326912,0,0,0},zero_row(),Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0}},Rows8{Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlrrlrl(code: U32) -> Glyph:
  face2rrlrrlrl.choose(U32.is_eq(code,237))

def face2rrlrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{9,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{134197248,0,0,0}},Rows8{Row{2145057536,0,0,0},Row{4263559088,6,0,0},zero_row(),zero_row(),Row{83853312,0,0,0},Row{83853312,0,0,0},Row{83853312,0,0,0},Row{83853312,0,0,0}},Rows8{Row{83853312,0,0,0},Row{83853312,0,0,0},Row{83853312,0,0,0},Row{83853312,0,0,0},Row{83853312,0,0,0},Row{83853312,0,0,0},Row{83853312,0,0,0},Row{83853312,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlrrlrr(code: U32) -> Glyph:
  face2rrlrrlrr.choose(U32.is_eq(code,238))

def face2rrlrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlrrlrl(code)
    case False{}: face2rrlrrlrr(code)

def face2rrlrrlr(+code: U32) -> Glyph:
  face2rrlrrlr.choose(code,U32.is_lt(code,238))

def face2rrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlrrll(code)
    case False{}: face2rrlrrlr(code)

def face2rrlrrl(+code: U32) -> Glyph:
  face2rrlrrl.choose(code,U32.is_lt(code,237))

def face2rrlrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{8,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1017120726,0,0,0}},Rows8{Row{2951942142,0,0,0},Row{1320225000,0,0,0},zero_row(),zero_row(),Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0}},Rows8{Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0},Row{5240832,0,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlrrrll(code: U32) -> Glyph:
  face2rrlrrrll.choose(U32.is_eq(code,239))

def face2rrlrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{2719744,80,0,0}},Rows8{Row{1493155840,1020,0,0},Row{4294377472,60,0,0},Row{4277948416,46,0,0},Row{3241857024,479,0,0},Row{573640704,2558,0,0},Row{3489632512,12280,0,0},Row{4294966016,40941,0,0},Row{826146656,57339,0,0}},Rows8{Row{196544,65505,0,0},Row{53216,130976,0,0},Row{45040,130944,0,0},Row{53216,61344,0,0},Row{327584,40946,0,0},Row{1954479920,16382,0,0},Row{4294964736,1791,0,0},Row{3755618304,58,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlrrrlr(code: U32) -> Glyph:
  face2rrlrrrlr.choose(U32.is_eq(code,240))

def face2rrlrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlrrrll(code)
    case False{}: face2rrlrrrlr(code)

def face2rrlrrrl(+code: U32) -> Glyph:
  face2rrlrrrl.choose(code,U32.is_lt(code,240))

def face2rrlrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{93782016,676,0,0}},Rows8{Row{3489624064,494,0,0},Row{3609112576,110,0,0},zero_row(),zero_row(),Row{3947036544,942,0,0},Row{4294377344,12031,0,0},Row{1705967488,45053,0,0},Row{720768,57330,0,0}},Rows8{Row{393088,65488,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlrrrrl(code: U32) -> Glyph:
  face2rrlrrrrl.choose(U32.is_eq(code,241))

def face2rrlrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{134094848,0,0,0},Row{519438336,0,0,0},Row{2141192192,0,0,0},zero_row(),Row{4023984128,91,0,0},Row{4294960384,2559,0,0},Row{1687158304,32765,0,0},Row{524176,61410,0,0}},Rows8{Row{131024,327568,0,0},Row{57328,458592,0,0},Row{57328,458608,0,0},Row{131024,327568,0,0},Row{524176,61410,0,0},Row{1687158304,32765,0,0},Row{4294960384,2559,0,0},Row{4023984128,91,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrlrrrrr(code: U32) -> Glyph:
  face2rrlrrrrr.choose(U32.is_eq(code,242))

def face2rrlrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlrrrrl(code)
    case False{}: face2rrlrrrrr(code)

def face2rrlrrrr(+code: U32) -> Glyph:
  face2rrlrrrr.choose(code,U32.is_lt(code,242))

def face2rrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlrrrl(code)
    case False{}: face2rrlrrrr(code)

def face2rrlrrr(+code: U32) -> Glyph:
  face2rrlrrr.choose(code,U32.is_lt(code,241))

def face2rrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlrrl(code)
    case False{}: face2rrlrrr(code)

def face2rrlrr(+code: U32) -> Glyph:
  face2rrlrr.choose(code,U32.is_lt(code,239))

def face2rrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrlrl(code)
    case False{}: face2rrlrr(code)

def face2rrlr(+code: U32) -> Glyph:
  face2rrlr.choose(code,U32.is_lt(code,236))

def face2rrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrll(code)
    case False{}: face2rrlr(code)

def face2rrl(+code: U32) -> Glyph:
  face2rrl.choose(code,U32.is_lt(code,230))

def face2rrrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{4060086272,127,0,0},Row{4177526784,11,0,0},Row{4011851776,1,0,0},zero_row(),Row{4023984128,91,0,0},Row{4294960384,2559,0,0},Row{1687158304,32765,0,0},Row{524176,61410,0,0}},Rows8{Row{131024,327568,0,0},Row{57328,458592,0,0},Row{57328,458608,0,0},Row{131024,327568,0,0},Row{524176,61410,0,0},Row{1687158304,32765,0,0},Row{4294960384,2559,0,0},Row{4023984128,91,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrrllll(code: U32) -> Glyph:
  face2rrrllll.choose(U32.is_eq(code,243))

def face2rrrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4291887104,5,0,0}},Rows8{Row{3925676032,79,0,0},Row{1084215552,1279,0,0},zero_row(),zero_row(),Row{4023984128,91,0,0},Row{4294960384,2559,0,0},Row{1687158304,32765,0,0},Row{524176,61410,0,0}},Rows8{Row{131024,327568,0,0},Row{57328,458592,0,0},Row{57328,458608,0,0},Row{131024,327568,0,0},Row{524176,61410,0,0},Row{1687158304,32765,0,0},Row{4294960384,2559,0,0},Row{4023984128,91,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrrlllrl(code: U32) -> Glyph:
  face2rrrlllrl.choose(U32.is_eq(code,244))

def face2rrrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{77004800,677,0,0}},Rows8{Row{3489624064,494,0,0},Row{3609116672,110,0,0},zero_row(),zero_row(),Row{4023984128,91,0,0},Row{4294960384,2559,0,0},Row{1687158304,32765,0,0},Row{524176,61410,0,0}},Rows8{Row{131024,327568,0,0},Row{57328,458592,0,0},Row{57328,458608,0,0},Row{131024,327568,0,0},Row{524176,61410,0,0},Row{1687158304,32765,0,0},Row{4294960384,2559,0,0},Row{4023984128,91,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrrlllrr(code: U32) -> Glyph:
  face2rrrlllrr.choose(U32.is_eq(code,245))

def face2rrrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrlllrl(code)
    case False{}: face2rrrlllrr(code)

def face2rrrlllr(+code: U32) -> Glyph:
  face2rrrlllr.choose(code,U32.is_lt(code,245))

def face2rrrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrllll(code)
    case False{}: face2rrrlllr(code)

def face2rrrlll(+code: U32) -> Glyph:
  face2rrrlll.choose(code,U32.is_lt(code,244))

def face2rrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{274567168,715,0,0}},Rows8{Row{1624240384,2047,0,0},Row{544120832,733,0,0},zero_row(),zero_row(),Row{4023984128,91,0,0},Row{4294960384,2559,0,0},Row{1687158304,32765,0,0},Row{524176,61410,0,0}},Rows8{Row{131024,327568,0,0},Row{57328,458592,0,0},Row{57328,458608,0,0},Row{131024,327568,0,0},Row{524176,61410,0,0},Row{1687158304,32765,0,0},Row{4294960384,2559,0,0},Row{4023984128,91,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrrllrl(code: U32) -> Glyph:
  face2rrrllrl.choose(U32.is_eq(code,246))

def face2rrrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{15,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),Row{3943694336,8,0,0},Row{4282384384,31,0,0},Row{3943694336,8,0,0},zero_row()},Rows8{zero_row(),Row{4294966528,786431,0,0},Row{4294966528,786431,0,0},Row{1145324288,214084,0,0},zero_row(),Row{3943694336,8,0,0},Row{4282384384,31,0,0},Row{3943694336,8,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrrllrrl(code: U32) -> Glyph:
  face2rrrllrrl.choose(U32.is_eq(code,247))

def face2rrrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),Row{0,16384,0,0},Row{4023984128,325723,0,0},Row{4294960384,40959,0,0},Row{1687158304,32767,0,0},Row{805830544,61439,0,0}},Rows8{Row{3523346384,327613,0,0},Row{3960528880,458595,0,0},Row{1336991728,458608,0,0},Row{117112784,327568,0,0},Row{9437072,61410,0,0},Row{1687158560,32765,0,0},Row{4294967104,2559,0,0},Row{4023991504,91,0,0}},Rows8{Row{544,0,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2rrrllrrr(code: U32) -> Glyph:
  face2rrrllrrr.choose(U32.is_eq(code,248))

def face2rrrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrllrrl(code)
    case False{}: face2rrrllrrr(code)

def face2rrrllrr(+code: U32) -> Glyph:
  face2rrrllrr.choose(code,U32.is_lt(code,248))

def face2rrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrllrl(code)
    case False{}: face2rrrllrr(code)

def face2rrrllr(+code: U32) -> Glyph:
  face2rrrllr.choose(code,U32.is_lt(code,247))

def face2rrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrlll(code)
    case False{}: face2rrrllr(code)

def face2rrrll(+code: U32) -> Glyph:
  face2rrrll.choose(code,U32.is_lt(code,246))

def face2rrrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{150872064,0,0,0},Row{519372800,0,0,0},Row{2408579072,0,0,0},zero_row(),Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0}},Rows8{Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{393088,65504,0,0},Row{720736,65524,0,0},Row{2259681072,65518,0,0},Row{4294965760,65450,0,0},Row{2382196736,65440,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrrlrll(code: U32) -> Glyph:
  face2rrrlrll.choose(U32.is_eq(code,249))

def face2rrrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{4060086272,143,0,0},Row{4177526784,12,0,0},Row{4011851776,2,0,0},zero_row(),Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0}},Rows8{Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{393088,65504,0,0},Row{720736,65524,0,0},Row{2259681072,65518,0,0},Row{4294965760,65450,0,0},Row{2382196736,65440,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrrlrlrl(code: U32) -> Glyph:
  face2rrrlrlrl.choose(U32.is_eq(code,250))

def face2rrrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{4290838528,5,0,0}},Rows8{Row{3925610496,95,0,0},Row{816824576,1534,0,0},zero_row(),zero_row(),Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0}},Rows8{Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{393088,65504,0,0},Row{720736,65524,0,0},Row{2259681072,65518,0,0},Row{4294965760,65450,0,0},Row{2382196736,65440,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrrlrlrr(code: U32) -> Glyph:
  face2rrrlrlrr.choose(U32.is_eq(code,251))

def face2rrrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrlrlrl(code)
    case False{}: face2rrrlrlrr(code)

def face2rrrlrlr(+code: U32) -> Glyph:
  face2rrrlrlr.choose(code,U32.is_lt(code,251))

def face2rrrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrlrll(code)
    case False{}: face2rrrlrlr(code)

def face2rrrlrl(+code: U32) -> Glyph:
  face2rrrlrl.choose(code,U32.is_lt(code,250))

def face2rrrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{274563072,715,0,0}},Rows8{Row{1625288960,2303,0,0},Row{544120832,989,0,0},zero_row(),zero_row(),Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0}},Rows8{Row{327552,65472,0,0},Row{327552,65472,0,0},Row{327552,65472,0,0},Row{393088,65504,0,0},Row{720736,65524,0,0},Row{2259681072,65518,0,0},Row{4294965760,65450,0,0},Row{2382196736,65440,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrrlrrll(code: U32) -> Glyph:
  face2rrrlrrll.choose(U32.is_eq(code,252))

def face2rrrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[zero_rows(),Rows8{Row{4110417920,79,0,0},Row{4227858432,8,0,0},Row{3478126592,0,0,0},zero_row(),Row{40950,393104,0,0},Row{61409,61408,0,0},Row{327568,36853,0,0},Row{655152,12282,0,0}},Rows8{Row{269417728,3071,0,0},Row{1616901888,1535,0,0},Row{2964320512,239,0,0},Row{4059013120,159,0,0},Row{4177477632,63,0,0},Row{4294770688,12,0,0},Row{4294443008,6,0,0},Row{4025614336,1,0,0}},Rows8{Row{2683568128,0,0,0},Row{805057536,0,0,0},Row{150994752,0,0,0},Row{7138928,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2rrrlrrlr(code: U32) -> Glyph:
  face2rrrlrrlr.choose(U32.is_eq(code,253))

def face2rrrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrlrrll(code)
    case False{}: face2rrrlrrlr(code)

def face2rrrlrrl(+code: U32) -> Glyph:
  face2rrrlrrl.choose(code,U32.is_lt(code,253))

def face2rrrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[zero_rows(),Rows8{Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{4232380288,942,0,0},Row{4294508416,20479,0,0},Row{1438646144,126970,0,0},Row{917376,458672,0,0}},Rows8{Row{524160,720720,0,0},Row{327552,786208,0,0},Row{327552,786208,0,0},Row{524160,655184,0,0},Row{917376,458672,0,0},Row{1438646144,126970,0,0},Row{4294508416,20223,0,0},Row{4232380288,942,0,0}},Rows8{Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},Row{327552,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2rrrlrrrl(code: U32) -> Glyph:
  face2rrrlrrrl.choose(U32.is_eq(code,254))

def face2rrrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{13,[Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{809279744,428,0,0}},Rows8{Row{2426401792,1279,0,0},Row{1078903040,462,0,0},zero_row(),zero_row(),Row{40950,393104,0,0},Row{61409,61408,0,0},Row{327568,36853,0,0},Row{655152,12282,0,0}},Rows8{Row{269417728,3071,0,0},Row{1616901888,1535,0,0},Row{2964320512,239,0,0},Row{4059013120,159,0,0},Row{4177477632,63,0,0},Row{4294770688,12,0,0},Row{4294443008,6,0,0},Row{4025614336,1,0,0}},Rows8{Row{2683568128,0,0,0},Row{805057536,0,0,0},Row{150994752,0,0,0},Row{7138928,0,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2rrrlrrrr(code: U32) -> Glyph:
  face2rrrlrrrr.choose(U32.is_eq(code,255))

def face2rrrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrlrrrl(code)
    case False{}: face2rrrlrrrr(code)

def face2rrrlrrr(+code: U32) -> Glyph:
  face2rrrlrrr.choose(code,U32.is_lt(code,255))

def face2rrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrlrrl(code)
    case False{}: face2rrrlrrr(code)

def face2rrrlrr(+code: U32) -> Glyph:
  face2rrrlrr.choose(code,U32.is_lt(code,254))

def face2rrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrlrl(code)
    case False{}: face2rrrlrr(code)

def face2rrrlr(+code: U32) -> Glyph:
  face2rrrlr.choose(code,U32.is_lt(code,252))

def face2rrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrll(code)
    case False{}: face2rrrlr(code)

def face2rrrl(+code: U32) -> Glyph:
  face2rrrl.choose(code,U32.is_lt(code,249))

def face2rrrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[zero_rows(),zero_rows(),Rows8{Row{1145324612,1092,0,0},Row{4294967295,4095,0,0},Row{4294967295,4095,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2rrrrlll(code: U32) -> Glyph:
  face2rrrrlll.choose(U32.is_eq(code,8211))

def face2rrrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{22,[zero_rows(),zero_rows(),Rows8{Row{1145324612,1145324612,4473924,0},Row{4294967295,4294967295,16777215,0},Row{4294967295,4294967295,16777215,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2rrrrllrl(code: U32) -> Glyph:
  face2rrrrllrl.choose(U32.is_eq(code,8212))

def face2rrrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[zero_rows(),Rows8{Row{9404416,0,0,0},Row{6279168,0,0,0},Row{4190720,0,0,0},Row{2094848,0,0,0},Row{916480,0,0,0},Row{786192,0,0,0},zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2rrrrllrr(code: U32) -> Glyph:
  face2rrrrllrr.choose(U32.is_eq(code,8216))

def face2rrrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrrllrl(code)
    case False{}: face2rrrrllrr(code)

def face2rrrrllr(+code: U32) -> Glyph:
  face2rrrrllr.choose(code,U32.is_lt(code,8216))

def face2rrrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrrlll(code)
    case False{}: face2rrrrllr(code)

def face2rrrrll(+code: U32) -> Glyph:
  face2rrrrll.choose(code,U32.is_lt(code,8212))

def face2rrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{6,[zero_rows(),Rows8{zero_row(),Row{8386048,0,0,0},Row{3143680,0,0,0},Row{850432,0,0,0},Row{523520,0,0,0},Row{261888,0,0,0},Row{57120,0,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2rrrrlrl(code: U32) -> Glyph:
  face2rrrrlrl.choose(U32.is_eq(code,8217))

def face2rrrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[zero_rows(),Rows8{Row{9404416,1021,0,0},Row{543150080,511,0,0},Row{1883238912,223,0,0},Row{3223320320,191,0,0},Row{4044225536,143,0,0},Row{4127981328,111,0,0},zero_row(),zero_row()},zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2rrrrlrrl(code: U32) -> Glyph:
  face2rrrrlrrl.choose(U32.is_eq(code,8220))

def face2rrrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[zero_rows(),Rows8{zero_row(),Row{3229611520,495,0,0},Row{3761240064,175,0,0},Row{4060936704,111,0,0},Row{4094164224,31,0,0},Row{4144234240,11,0,0},Row{4177583904,7,0,0},zero_row()},zero_rows(),zero_rows()]}
    case False{}: face2.missing()

def face2rrrrlrrr(code: U32) -> Glyph:
  face2rrrrlrrr.choose(U32.is_eq(code,8221))

def face2rrrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrrlrrl(code)
    case False{}: face2rrrrlrrr(code)

def face2rrrrlrr(+code: U32) -> Glyph:
  face2rrrrlrr.choose(code,U32.is_lt(code,8221))

def face2rrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrrlrl(code)
    case False{}: face2rrrrlrr(code)

def face2rrrrlr(+code: U32) -> Glyph:
  face2rrrrlr.choose(code,U32.is_lt(code,8220))

def face2rrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrrll(code)
    case False{}: face2rrrrlr(code)

def face2rrrrl(+code: U32) -> Glyph:
  face2rrrrl.choose(code,U32.is_lt(code,8217))

def face2rrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{11,[zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{1560035328,0,0,0},Row{4294964224,5,0,0}},Rows8{Row{4294966016,12,0,0},Row{4294966528,14,0,0},Row{4294966016,12,0,0},Row{4294964224,5,0,0},Row{1560035328,0,0,0},zero_row(),zero_row(),zero_row()},zero_rows()]}
    case False{}: face2.missing()

def face2rrrrrll(code: U32) -> Glyph:
  face2rrrrrll.choose(U32.is_eq(code,8226))

def face2rrrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{21,[zero_rows(),zero_rows(),Rows8{zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),Row{715264,44704,2794,0},Row{4194080,537133042,16383,0},Row{715264,44704,2794,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrrrrlrl(code: U32) -> Glyph:
  face2rrrrrlrl.choose(U32.is_eq(code,8230))

def face2rrrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{21,[zero_rows(),Rows8{zero_row(),Row{0,64,0,0},Row{0,3062,0,0},Row{1610612736,7423,0,0},Row{4127195136,447,0,0},Row{4284481536,27,0,0},Row{2683699200,0,0,0},Row{939487232,1145324612,324,0}},Rows8{Row{4294964736,4294967295,1279,0},Row{3991921664,4294967295,1279,0},Row{452870144,0,0,0},Row{3487760384,2,0,0},Row{4264558592,45,0,0},Row{3808428032,735,0,0},Row{805306368,7934,0,0},Row{0,2275,0,0}},Rows8{Row{0,16,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2rrrrrlrr(code: U32) -> Glyph:
  face2rrrrrlrr.choose(U32.is_eq(code,8592))

def face2rrrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrrrlrl(code)
    case False{}: face2rrrrrlrr(code)

def face2rrrrrlr(+code: U32) -> Glyph:
  face2rrrrrlr.choose(code,U32.is_lt(code,8592))

def face2rrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrrrll(code)
    case False{}: face2rrrrrlr(code)

def face2rrrrrl(+code: U32) -> Glyph:
  face2rrrrrl.choose(code,U32.is_lt(code,8230))

def face2rrrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{19,[zero_rows(),Rows8{Row{0,1473,0,0},Row{268435456,24572,0,0},Row{3238002688,393215,0,0},Row{4245684224,6290941,0,0},Row{3755081728,100633590,0,0},Row{1056776192,1610222838,0,0},Row{66048512,4289727991,6,0},Row{4126720,4212133367,29,0}},Rows8{Row{233472,2701135351,2,0},Row{0,3575,0,0},Row{0,3575,0,0},Row{0,3575,0,0},Row{0,3575,0,0},Row{0,3575,0,0},Row{0,3575,0,0},Row{0,3575,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrrrrrll(code: U32) -> Glyph:
  face2rrrrrrll.choose(U32.is_eq(code,8593))

def face2rrrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{21,[zero_rows(),Rows8{zero_row(),Row{0,16384,0,0},Row{0,457488,0,0},Row{0,7339024,0,0},Row{0,117420288,0,0},Row{0,1878724608,0,0},Row{0,4287627264,6,0},Row{1145323776,4147397700,127,0}},Rows8{Row{4294964224,4294967295,1791,0},Row{4294964224,4260364287,1263,0},Row{0,4195352576,78,0},Row{0,4022468608,3,0},Row{0,1056776192,0,0},Row{0,66048512,0,0},Row{0,4128272,0,0},Row{0,256000,0,0}},Rows8{Row{0,4096,0,0},zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2rrrrrrlr(code: U32) -> Glyph:
  face2rrrrrrlr.choose(U32.is_eq(code,8594))

def face2rrrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrrrrll(code)
    case False{}: face2rrrrrrlr(code)

def face2rrrrrrl(+code: U32) -> Glyph:
  face2rrrrrrl.choose(code,U32.is_lt(code,8594))

def face2rrrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{19,[zero_rows(),Rows8{Row{0,3575,0,0},Row{0,3575,0,0},Row{0,3575,0,0},Row{0,3575,0,0},Row{0,3575,0,0},Row{0,3575,0,0},Row{0,3575,0,0},Row{299008,2701135351,2,0}},Rows8{Row{5175296,4212133367,29,0},Row{82825728,4290842103,6,0},Row{1056776192,1610288374,0,0},Row{3755016192,100637686,0,0},Row{4245684224,6290941,0,0},Row{3506438144,393215,0,0},Row{268435456,24572,0,0},Row{0,1473,0,0}},zero_rows()]}
    case False{}: face2.missing()

def face2rrrrrrrl(code: U32) -> Glyph:
  face2rrrrrrrl.choose(U32.is_eq(code,8595))

def face2rrrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{14,[Rows8{zero_row(),zero_row(),zero_row(),Row{3149615104,2747,0,0},Row{4294930432,3839,0,0},Row{9400320,3825,0,0},Row{2330947584,3838,0,0},Row{294612992,3826,0,0}},Rows8{Row{3135205376,3837,0,0},Row{2056220672,3839,0,0},Row{294612992,3826,0,0},Row{2866769920,3835,0,0},Row{1827631104,3836,0,0},Row{1905225728,3829,0,0},Row{3135205376,3828,0,0},Row{2900324352,3835,0,0}},Rows8{Row{982478848,3827,0,0},Row{3129962496,3828,0,0},Row{294612992,3826,0,0},Row{4294930432,3839,0,0},Row{1705996288,3829,0,0},Row{4237258752,3829,0,0},Row{1133473792,3826,0,0},Row{3168759808,3835,0,0}},Rows8{Row{1526689792,3836,0,0},Row{1100967936,3829,0,0},Row{3151982592,3835,0,0},Row{4294930432,3839,0,0},zero_row(),zero_row(),zero_row(),zero_row()}]}
    case False{}: face2.missing()

def face2rrrrrrrr(code: U32) -> Glyph:
  face2rrrrrrrr.choose(U32.is_eq(code,65533))

def face2rrrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrrrrrl(code)
    case False{}: face2rrrrrrrr(code)

def face2rrrrrrr(+code: U32) -> Glyph:
  face2rrrrrrr.choose(code,U32.is_lt(code,65533))

def face2rrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrrrrl(code)
    case False{}: face2rrrrrrr(code)

def face2rrrrrr(+code: U32) -> Glyph:
  face2rrrrrr.choose(code,U32.is_lt(code,8595))

def face2rrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrrrl(code)
    case False{}: face2rrrrrr(code)

def face2rrrrr(+code: U32) -> Glyph:
  face2rrrrr.choose(code,U32.is_lt(code,8593))

def face2rrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrrl(code)
    case False{}: face2rrrrr(code)

def face2rrrr(+code: U32) -> Glyph:
  face2rrrr.choose(code,U32.is_lt(code,8226))

def face2rrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrrl(code)
    case False{}: face2rrrr(code)

def face2rrr(+code: U32) -> Glyph:
  face2rrr.choose(code,U32.is_lt(code,8211))

def face2rr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rrl(code)
    case False{}: face2rrr(code)

def face2rr(+code: U32) -> Glyph:
  face2rr.choose(code,U32.is_lt(code,243))

def face2r.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2rl(code)
    case False{}: face2rr(code)

def face2r(+code: U32) -> Glyph:
  face2r.choose(code,U32.is_lt(code,218))

def face2.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: face2l(code)
    case False{}: face2r(code)

def face2(+code: U32) -> Glyph:
  face2.choose(code,U32.is_lt(code,167))

def glyph(face: U32,code: U32) -> Glyph:
  match face:
    case 1: face1(code)
    case 2: face2(code)
    case _: face0(code)

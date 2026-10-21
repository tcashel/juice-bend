# Static glyph data derived from JetBrains Mono v2.304, SIL OFL 1.1.
# Copyright 2020 The JetBrains Mono Project Authors. See ../assets/fonts/jetbrains-mono/OFL.txt.
# Generated offline by ../scripts/font-pack. No runtime font parser.
import Base

type Half is Data:
  Half{a: U32,b: U32,c: U32,d: U32,e: U32,f: U32,g: U32,h: U32}

type Glyph is Data:
  Glyph{top: Half,bottom: Half}

def row(bits: Half,y: U32) -> U32:
  Half{a,b,c,d,e,f,g,h} = bits
  match y:
    case 0: a
    case 1: b
    case 2: c
    case 3: d
    case 4: e
    case 5: f
    case 6: g
    case _: h

def half(bits: Glyph,top: Bool) -> Half:
  Glyph{a,b} = bits
  match top:
    case True{}: a
    case False{}: b

def coverage(bits: Half,+x: U32,y: U32) -> U32:
  U32.and(U32.shrn(row(bits,y),U32.to_nat(U32.mul(x,4))),15)

def missing() -> Glyph:
  Glyph{Half{0,0,268435440,251658480,251658480,251658480,251658480,251658480},Half{251658480,251658480,251658480,251658480,268435440,0,0,0}}

def glyphlllllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,0,0,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphlllllll(code: U32) -> Glyph:
  glyphlllllll.choose(U32.is_eq(code,32))

def glyphllllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,638976,569344,569344,569344,499712,499712},Half{499712,0,69632,774144,0,0,0,0}}
    case False{}: missing()

def glyphllllllrl(code: U32) -> Glyph:
  glyphllllllrl.choose(U32.is_eq(code,33))

def glyphllllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,15089440,15019808,13971216,13905680,0,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphllllllrr(code: U32) -> Glyph:
  glyphllllllrr.choose(U32.is_eq(code,34))

def glyphllllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllllllrl(code)
    case False{}: glyphllllllrr(code)

def glyphllllllr(+code: U32) -> Glyph:
  glyphllllllr.choose(code,U32.is_lt(code,34))

def glyphllllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllllll(code)
    case False{}: glyphllllllr(code)

def glyphllllll(+code: U32) -> Glyph:
  glyphllllll.choose(code,U32.is_lt(code,33))

def glyphlllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,156275968,93345792,1610612721,333594144,13700368,11733808},Half{234881016,42543233,4850848,1900992,0,0,0,0}}
    case False{}: missing()

def glyphlllllrl(code: U32) -> Glyph:
  glyphlllllrl.choose(U32.is_eq(code,35))

def glyphlllllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{352256,4961280,82558528,176514976,354224,368256,6159120,100433920},Half{193290240,206922096,161900496,30404144,491520,352256,0,0}}
    case False{}: missing()

def glyphlllllrrl(code: U32) -> Glyph:
  glyphlllllrrl.choose(U32.is_eq(code,36))

def glyphlllllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,1241538277,173065836,29475916,5861366,737552,753385728},Half{2321442816,2500725552,2320368320,753270903,0,0,0,0}}
    case False{}: missing()

def glyphlllllrrr(code: U32) -> Glyph:
  glyphlllllrrr.choose(U32.is_eq(code,37))

def glyphlllllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllllrrl(code)
    case False{}: glyphlllllrrr(code)

def glyphlllllrr(+code: U32) -> Glyph:
  glyphlllllrr.choose(code,U32.is_lt(code,37))

def glyphlllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllllrl(code)
    case False{}: glyphlllllrr(code)

def glyphlllllr(+code: U32) -> Glyph:
  glyphlllllr.choose(code,U32.is_lt(code,36))

def glyphlllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllllll(code)
    case False{}: glyphlllllr(code)

def glyphlllll(+code: U32) -> Glyph:
  glyphlllll.choose(code,U32.is_lt(code,35))

def glyphllllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,4057616,14171248,7408240,15632,122529,2601227223},Half{197918842,100008058,494818262,2852445840,0,0,0,0}}
    case False{}: missing()

def glyphllllrll(code: U32) -> Glyph:
  glyphllllrll.choose(U32.is_eq(code,38))

def glyphllllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,569344,569344,569344,499712,0,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphllllrlrl(code: U32) -> Glyph:
  glyphllllrlrl.choose(U32.is_eq(code,39))

def glyphllllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,76677120,26099712,450816,54784,43008,39168,39168},Half{39168,43008,123904,700416,64688128,37748736,0,0}}
    case False{}: missing()

def glyphllllrlrr(code: U32) -> Glyph:
  glyphllllrlrr.choose(U32.is_eq(code,40))

def glyphllllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllllrlrl(code)
    case False{}: glyphllllrlrr(code)

def glyphllllrlr(+code: U32) -> Glyph:
  glyphllllrlr.choose(code,U32.is_lt(code,40))

def glyphllllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllllrll(code)
    case False{}: glyphllllrlr(code)

def glyphllllrl(+code: U32) -> Glyph:
  glyphllllrl.choose(code,U32.is_lt(code,39))

def glyphllllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,6240,186912,823296,3084288,6094848,7077888,7077888},Half{7077888,5046272,2043904,573696,40528,816,0,0}}
    case False{}: missing()

def glyphllllrrl(code: U32) -> Glyph:
  glyphllllrrl.choose(U32.is_eq(code,41))

def glyphllllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,499712,499712,744920501,400485762,1954304},Half{10124288,65145952,2097664,0,0,0,0,0}}
    case False{}: missing()

def glyphllllrrrl(code: U32) -> Glyph:
  glyphllllrrrl.choose(U32.is_eq(code,42))

def glyphllllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,499712,499712,499712,251658226},Half{36221472,499712,499712,0,0,0,0,0}}
    case False{}: missing()

def glyphllllrrrr(code: U32) -> Glyph:
  glyphllllrrrr.choose(U32.is_eq(code,43))

def glyphllllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllllrrrl(code)
    case False{}: glyphllllrrrr(code)

def glyphllllrrr(+code: U32) -> Glyph:
  glyphllllrrr.choose(code,U32.is_lt(code,43))

def glyphllllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllllrrl(code)
    case False{}: glyphllllrrr(code)

def glyphllllrr(+code: U32) -> Glyph:
  glyphllllrr.choose(code,U32.is_lt(code,42))

def glyphllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllllrl(code)
    case False{}: glyphllllrr(code)

def glyphllllr(+code: U32) -> Glyph:
  glyphllllr.choose(code,U32.is_lt(code,41))

def glyphllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllll(code)
    case False{}: glyphllllr(code)

def glyphllll(+code: U32) -> Glyph:
  glyphllll.choose(code,U32.is_lt(code,38))

def glyphlllrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,0,0,0},Half{0,0,0,761856,573440,323584,127744,0}}
    case False{}: missing()

def glyphlllrlll(code: U32) -> Glyph:
  glyphlllrlll.choose(U32.is_eq(code,44))

def glyphlllrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,0,0,15728432},Half{2236928,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphlllrllrl(code: U32) -> Glyph:
  glyphlllrllrl.choose(U32.is_eq(code,45))

def glyphlllrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,0,0,0},Half{0,69632,844032,774400,0,0,0,0}}
    case False{}: missing()

def glyphlllrllrr(code: U32) -> Glyph:
  glyphlllrllrr.choose(U32.is_eq(code,46))

def glyphlllrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllrllrl(code)
    case False{}: glyphlllrllrr(code)

def glyphlllrllr(+code: U32) -> Glyph:
  glyphlllrllr.choose(code,U32.is_lt(code,46))

def glyphlllrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllrlll(code)
    case False{}: glyphlllrllr(code)

def glyphlllrll(+code: U32) -> Glyph:
  glyphlllrll.choose(code,U32.is_lt(code,45))

def glyphlllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{104857600,128974848,49414144,13041664,8126464,3088384,815104,442368},Half{127488,46848,27904,7984,2944,1744,0,0}}
    case False{}: missing()

def glyphlllrlrl(code: U32) -> Glyph:
  glyphlllrlrl.choose(U32.is_eq(code,47))

def glyphlllrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,9366032,114572432,191890640,207619040,208184288,207688672},Half{207619040,191890640,131349648,9366032,0,0,0,0}}
    case False{}: missing()

def glyphlllrlrrl(code: U32) -> Glyph:
  glyphlllrlrrl.choose(U32.is_eq(code,48))

def glyphlllrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,976128,958064,934816,933888,933888,933888},Half{933888,933888,36594208,268435392,0,0,0,0}}
    case False{}: missing()

def glyphlllrlrrr(code: U32) -> Glyph:
  glyphlllrlrrr.choose(U32.is_eq(code,49))

def glyphlllrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllrlrrl(code)
    case False{}: glyphlllrlrrr(code)

def glyphlllrlrr(+code: U32) -> Glyph:
  glyphlllrlrr.choose(code,U32.is_lt(code,49))

def glyphlllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllrlrl(code)
    case False{}: glyphlllrlrr(code)

def glyphlllrlr(+code: U32) -> Glyph:
  glyphlllrlr.choose(code,U32.is_lt(code,48))

def glyphlllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllrll(code)
    case False{}: glyphlllrlr(code)

def glyphlllrl(+code: U32) -> Glyph:
  glyphlllrl.choose(code,U32.is_lt(code,47))

def glyphlllrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,9300496,115620752,176161744,160432128,81920000,10227712},Half{765952,113152,35798400,234880976,0,0,0,0}}
    case False{}: missing()

def glyphlllrrll(code: U32) -> Glyph:
  glyphlllrrll.choose(U32.is_eq(code,50))

def glyphlllrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,117440448,48636448,4075520,582144,30257920,130023424},Half{159383552,143655632,82131632,8252192,0,0,0,0}}
    case False{}: missing()

def glyphlllrrlrl(code: U32) -> Glyph:
  glyphlllrrlrl.choose(U32.is_eq(code,51))

def glyphlllrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,7147520,815104,320000,43520,113258288,113248448},Half{113246961,117440497,113455920,113246208,0,0,0,0}}
    case False{}: missing()

def glyphlllrrlrr(code: U32) -> Glyph:
  glyphlllrrlrr.choose(U32.is_eq(code,52))

def glyphlllrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllrrlrl(code)
    case False{}: glyphlllrrlrr(code)

def glyphlllrrlr(+code: U32) -> Glyph:
  glyphlllrrlr.choose(code,U32.is_lt(code,52))

def glyphlllrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllrrll(code)
    case False{}: glyphlllrrlr(code)

def glyphlllrrl(+code: U32) -> Glyph:
  glyphlllrrl.choose(code,U32.is_lt(code,51))

def glyphlllrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,100663216,19015600,1712,8257456,98902560,160432128},Half{175112224,160433376,82132128,8251920,0,0,0,0}}
    case False{}: missing()

def glyphlllrrrll(code: U32) -> Glyph:
  glyphlllrrrll.choose(U32.is_eq(code,53))

def glyphlllrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,872448,249856,34560,10411536,148052848,224395984},Half{239075570,207619057,115621040,8317456,0,0,0,0}}
    case False{}: missing()

def glyphlllrrrlr(code: U32) -> Glyph:
  glyphlllrrrlr.choose(U32.is_eq(code,54))

def glyphlllrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllrrrll(code)
    case False{}: glyphlllrrrlr(code)

def glyphlllrrrl(+code: U32) -> Glyph:
  glyphlllrrrl.choose(code,U32.is_lt(code,54))

def glyphlllrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,536870880,241313248,161481632,66125824,13041664,8126464},Half{2043904,692224,385024,58624,0,0,0,0}}
    case False{}: missing()

def glyphlllrrrrl(code: U32) -> Glyph:
  glyphlllrrrrl.choose(U32.is_eq(code,55))

def glyphlllrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,10414608,131349664,176162256,113384080,10484496,114572176},Half{223347441,223347441,148126656,10414608,0,0,0,0}}
    case False{}: missing()

def glyphlllrrrrr(code: U32) -> Glyph:
  glyphlllrrrrr.choose(U32.is_eq(code,56))

def glyphlllrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllrrrrl(code)
    case False{}: glyphlllrrrrr(code)

def glyphlllrrrr(+code: U32) -> Glyph:
  glyphlllrrrr.choose(code,U32.is_lt(code,56))

def glyphlllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllrrrl(code)
    case False{}: glyphlllrrrr(code)

def glyphlllrrr(+code: U32) -> Glyph:
  glyphlllrrr.choose(code,U32.is_lt(code,55))

def glyphlllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllrrl(code)
    case False{}: glyphlllrrr(code)

def glyphlllrr(+code: U32) -> Glyph:
  glyphlllrr.choose(code,U32.is_lt(code,53))

def glyphlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlllrl(code)
    case False{}: glyphlllrr(code)

def glyphlllr(+code: U32) -> Glyph:
  glyphlllr.choose(code,U32.is_lt(code,50))

def glyphlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllll(code)
    case False{}: glyphlllr(code)

def glyphlll(+code: U32) -> Glyph:
  glyphlll.choose(code,U32.is_lt(code,44))

def glyphllrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,9366032,148126640,223347441,239075826,179378640,83820096},Half{13180928,5185536,761856,258816,0,0,0,0}}
    case False{}: missing()

def glyphllrllll(code: U32) -> Glyph:
  glyphllrllll.choose(U32.is_eq(code,57))

def glyphllrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,774400,844032,0,0},Half{0,0,844032,774400,0,0,0,0}}
    case False{}: missing()

def glyphllrlllrl(code: U32) -> Glyph:
  glyphllrlllrl.choose(U32.is_eq(code,58))

def glyphllrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,774400,913920,69632,0},Half{0,0,0,700416,512000,258304,62464,0}}
    case False{}: missing()

def glyphllrlllrr(code: U32) -> Glyph:
  glyphllrlllrr.choose(U32.is_eq(code,59))

def glyphllrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrlllrl(code)
    case False{}: glyphllrlllrr(code)

def glyphllrlllr(+code: U32) -> Glyph:
  glyphllrlllr.choose(code,U32.is_lt(code,59))

def glyphllrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrllll(code)
    case False{}: glyphllrlllr(code)

def glyphllrlll(+code: U32) -> Glyph:
  glyphllrlll.choose(code,U32.is_lt(code,58))

def glyphllrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,102760448,116006912,1567264,6352},Half{171648,43942144,176226304,0,0,0,0,0}}
    case False{}: missing()

def glyphllrllrl(code: U32) -> Glyph:
  glyphllrllrl.choose(U32.is_eq(code,60))

def glyphllrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,184549328,35791392,0},Half{184549328,35791392,0,0,0,0,0,0}}
    case False{}: missing()

def glyphllrllrrl(code: U32) -> Glyph:
  glyphllrllrrl.choose(U32.is_eq(code,61))

def glyphllrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,368,102032,26120704,178388992},Half{99229696,1567280,6080,0,0,0,0,0}}
    case False{}: missing()

def glyphllrllrrr(code: U32) -> Glyph:
  glyphllrllrrr.choose(U32.is_eq(code,62))

def glyphllrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrllrrl(code)
    case False{}: glyphllrllrrr(code)

def glyphllrllrr(+code: U32) -> Glyph:
  glyphllrllrr.choose(code,U32.is_lt(code,62))

def glyphllrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrllrl(code)
    case False{}: glyphllrllrr(code)

def glyphllrllr(+code: U32) -> Glyph:
  glyphllrllr.choose(code,U32.is_lt(code,61))

def glyphllrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrlll(code)
    case False{}: glyphllrllr(code)

def glyphllrll(+code: U32) -> Glyph:
  glyphllrll.choose(code,U32.is_lt(code,60))

def glyphllrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,5046096,31990288,81788928,49610752,8385792,120064},Half{50432,0,4096,124928,0,0,0,0}}
    case False{}: missing()

def glyphllrlrll(code: U32) -> Glyph:
  glyphllrlrll.choose(U32.is_eq(code,63))

def glyphllrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,28240400,194202544,754975203,1287467189,1330229398,1275318422},Half{1275252886,1275252886,773238934,167653557,1049058,1199264,11528464,0}}
    case False{}: missing()

def glyphllrlrlrl(code: U32) -> Glyph:
  glyphllrlrlrl.choose(U32.is_eq(code,64))

def glyphllrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,847872,2085888,6067968,8936192,12852736,32574784},Half{83816304,143796144,206570464,522191075,0,0,0,0}}
    case False{}: missing()

def glyphllrlrlrr(code: U32) -> Glyph:
  glyphllrlrlrr.choose(U32.is_eq(code,65))

def glyphllrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrlrlrl(code)
    case False{}: glyphllrlrlrr(code)

def glyphllrlrlr(+code: U32) -> Glyph:
  glyphllrlrlr.choose(code,U32.is_lt(code,65))

def glyphllrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrlrll(code)
    case False{}: glyphllrlrlr(code)

def glyphllrlrl(+code: U32) -> Glyph:
  glyphllrlrl.choose(code,U32.is_lt(code,64))

def glyphllrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,10420160,131344320,159385024,96536000,10485696,97789888},Half{190842304,206570944,147007424,28245952,0,0,0,0}}
    case False{}: missing()

def glyphllrlrrll(code: U32) -> Glyph:
  glyphllrlrrll.choose(U32.is_eq(code,66))

def glyphllrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,10414336,131284336,157288112,1472,1472,1472},Half{1472,157288112,131284336,10414336,0,0,0,0}}
    case False{}: missing()

def glyphllrlrrlr(code: U32) -> Glyph:
  glyphllrlrrlr.choose(U32.is_eq(code,67))

def glyphllrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrlrrll(code)
    case False{}: glyphllrlrrlr(code)

def glyphllrlrrl(+code: U32) -> Glyph:
  glyphllrlrrl.choose(code,U32.is_lt(code,67))

def glyphllrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,7208896,82126784,160433600,176162240,176162240,176162240},Half{176162240,160433600,82126784,7208896,0,0,0,0}}
    case False{}: missing()

def glyphllrlrrrl(code: U32) -> Glyph:
  glyphllrlrrrl.choose(U32.is_eq(code,68))

def glyphllrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,218103728,19015856,1968,1968,100663216,19015856},Half{1968,1968,19015856,218103728,0,0,0,0}}
    case False{}: missing()

def glyphllrlrrrr(code: U32) -> Glyph:
  glyphllrlrrrr.choose(U32.is_eq(code,69))

def glyphllrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrlrrrl(code)
    case False{}: glyphllrlrrrr(code)

def glyphllrlrrr(+code: U32) -> Glyph:
  glyphllrlrrr.choose(code,U32.is_lt(code,69))

def glyphllrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrlrrl(code)
    case False{}: glyphllrlrrr(code)

def glyphllrlrr(+code: U32) -> Glyph:
  glyphllrlrr.choose(code,U32.is_lt(code,68))

def glyphllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrlrl(code)
    case False{}: glyphllrlrr(code)

def glyphllrlr(+code: U32) -> Glyph:
  glyphllrlr.choose(code,U32.is_lt(code,66))

def glyphllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrll(code)
    case False{}: glyphllrlr(code)

def glyphllrl(+code: U32) -> Glyph:
  glyphllrl.choose(code,U32.is_lt(code,63))

def glyphllrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,218103744,35792832,1728,1728,134217664,19015616},Half{1728,1728,1728,1728,0,0,0,0}}
    case False{}: missing()

def glyphllrrlll(code: U32) -> Glyph:
  glyphllrrlll.choose(U32.is_eq(code,70))

def glyphllrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,10414352,130235520,87033280,1488,201283024,193074640},Half{191890896,159385024,98843776,8317200,0,0,0,0}}
    case False{}: missing()

def glyphllrrllrl(code: U32) -> Glyph:
  glyphllrrllrl.choose(U32.is_eq(code,71))

def glyphllrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,160433856,160433856,160433856,160433856,167772096,161621952},Half{160433856,160433856,160433856,160433856,0,0,0,0}}
    case False{}: missing()

def glyphllrrllrr(code: U32) -> Glyph:
  glyphllrrllrr.choose(U32.is_eq(code,72))

def glyphllrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrrllrl(code)
    case False{}: glyphllrrllrr(code)

def glyphllrrllr(+code: U32) -> Glyph:
  glyphllrrllr.choose(code,U32.is_lt(code,72))

def glyphllrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrrlll(code)
    case False{}: glyphllrrllr(code)

def glyphllrrll(+code: U32) -> Glyph:
  glyphllrrll.choose(code,U32.is_lt(code,71))

def glyphllrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,134217632,19444240,569344,569344,569344,569344},Half{569344,569344,19444240,134217632,0,0,0,0}}
    case False{}: missing()

def glyphllrrlrl(code: U32) -> Glyph:
  glyphllrrlrl.choose(U32.is_eq(code,73))

def glyphllrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,128974848,128974848,128974848,128974848,128974848,128974848},Half{128974848,96469205,48703457,5041216,0,0,0,0}}
    case False{}: missing()

def glyphllrrlrrl(code: U32) -> Glyph:
  glyphllrrlrrl.choose(U32.is_eq(code,74))

def glyphllrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,224396736,114296256,14091712,6165952,982976,4143040},Half{11142592,49481152,162530752,524289472,0,0,0,0}}
    case False{}: missing()

def glyphllrrlrrr(code: U32) -> Glyph:
  glyphllrrlrrr.choose(U32.is_eq(code,75))

def glyphllrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrrlrrl(code)
    case False{}: glyphllrrlrrr(code)

def glyphllrrlrr(+code: U32) -> Glyph:
  glyphllrrlrr.choose(code,U32.is_lt(code,75))

def glyphllrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrrlrl(code)
    case False{}: glyphllrrlrr(code)

def glyphllrrlr(+code: U32) -> Glyph:
  glyphllrrlr.choose(code,U32.is_lt(code,74))

def glyphllrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrrll(code)
    case False{}: glyphllrrlr(code)

def glyphllrrl(+code: U32) -> Glyph:
  glyphllrrl.choose(code,U32.is_lt(code,73))

def glyphllrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,3408,3408,3408,3408,3408,3408},Half{3408,3408,35794256,805306192,0,0,0,0}}
    case False{}: missing()

def glyphllrrrll(code: U32) -> Glyph:
  glyphllrrrll.choose(U32.is_eq(code,76))

def glyphllrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,232852721,229907681,226056433,223126769,223007217,222585329},Half{222298609,222298609,222298609,222298609,0,0,0,0}}
    case False{}: missing()

def glyphllrrrlrl(code: U32) -> Glyph:
  glyphllrrrlrl.choose(U32.is_eq(code,77))

def glyphllrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,159387072,159403712,159423424,159442624,159696064,158954688},Half{159261888,163316928,166134976,166855872,0,0,0,0}}
    case False{}: missing()

def glyphllrrrlrr(code: U32) -> Glyph:
  glyphllrrrlrr.choose(U32.is_eq(code,78))

def glyphllrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrrrlrl(code)
    case False{}: glyphllrrrlrr(code)

def glyphllrrrlr(+code: U32) -> Glyph:
  glyphllrrrlr.choose(code,U32.is_lt(code,78))

def glyphllrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrrrll(code)
    case False{}: glyphllrrrlr(code)

def glyphllrrrl(+code: U32) -> Glyph:
  glyphllrrrl.choose(code,U32.is_lt(code,77))

def glyphllrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,8251664,98843776,160433600,176162256,176162256,176162256},Half{176162256,159385024,98843776,9366032,0,0,0,0}}
    case False{}: missing()

def glyphllrrrrll(code: U32) -> Glyph:
  glyphllrrrrll.choose(U32.is_eq(code,79))

def glyphllrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,45023168,196290496,522192320,522192320,227542464,65011648},Half{141248,1472,1472,1472,0,0,0,0}}
    case False{}: missing()

def glyphllrrrrlr(code: U32) -> Glyph:
  glyphllrrrrlr.choose(U32.is_eq(code,80))

def glyphllrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrrrrll(code)
    case False{}: glyphllrrrrlr(code)

def glyphllrrrrl(+code: U32) -> Glyph:
  glyphllrrrrl.choose(code,U32.is_lt(code,80))

def glyphllrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,9366032,114572432,191890640,207619040,207619040,207619040},Half{207619040,191890640,132398224,11528720,11141120,49479680,162529280,0}}
    case False{}: missing()

def glyphllrrrrrl(code: U32) -> Glyph:
  glyphllrrrrrl.choose(U32.is_eq(code,81))

def glyphllrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,28245952,179513280,239076800,195102144,48234432,6170560},Half{12060096,49415616,130024896,224396736,0,0,0,0}}
    case False{}: missing()

def glyphllrrrrrr(code: U32) -> Glyph:
  glyphllrrrrrr.choose(U32.is_eq(code,82))

def glyphllrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrrrrrl(code)
    case False{}: glyphllrrrrrr(code)

def glyphllrrrrr(+code: U32) -> Glyph:
  glyphllrrrrr.choose(code,U32.is_lt(code,82))

def glyphllrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrrrrl(code)
    case False{}: glyphllrrrrr(code)

def glyphllrrrr(+code: U32) -> Glyph:
  glyphllrrrr.choose(code,U32.is_lt(code,81))

def glyphllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrrrl(code)
    case False{}: glyphllrrrr(code)

def glyphllrrr(+code: U32) -> Glyph:
  glyphllrrr.choose(code,U32.is_lt(code,79))

def glyphllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrrl(code)
    case False{}: glyphllrrr(code)

def glyphllrr(+code: U32) -> Glyph:
  glyphllrr.choose(code,U32.is_lt(code,76))

def glyphllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphllrl(code)
    case False{}: glyphllrr(code)

def glyphllr(+code: U32) -> Glyph:
  glyphllr.choose(code,U32.is_lt(code,70))

def glyphll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlll(code)
    case False{}: glyphllr(code)

def glyphll(+code: U32) -> Glyph:
  glyphll.choose(code,U32.is_lt(code,57))

def glyphlrlllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,8317456,98843792,90179008,2720,3796256,82329600},Half{191889408,206570176,148126640,27191840,0,0,0,0}}
    case False{}: missing()

def glyphlrlllll(code: U32) -> Glyph:
  glyphlrlllll.choose(U32.is_eq(code,83))

def glyphlrllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,536870900,36221473,499712,499712,499712,499712},Half{499712,499712,499712,499712,0,0,0,0}}
    case False{}: missing()

def glyphlrllllrl(code: U32) -> Glyph:
  glyphlrllllrl.choose(U32.is_eq(code,84))

def glyphlrllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,159385024,159385024,159385024,159385024,159385024,159385024},Half{159385024,160433856,98843776,9366032,0,0,0,0}}
    case False{}: missing()

def glyphlrllllrr(code: U32) -> Glyph:
  glyphlrllllrr.choose(U32.is_eq(code,85))

def glyphlrllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrllllrl(code)
    case False{}: glyphlrllllrr(code)

def glyphlrllllr(+code: U32) -> Glyph:
  glyphlrllllr.choose(code,U32.is_lt(code,85))

def glyphlrllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlllll(code)
    case False{}: glyphlrllllr(code)

def glyphlrllll(+code: U32) -> Glyph:
  glyphlrllll.choose(code,U32.is_lt(code,84))

def glyphlrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,523239651,207619040,144705456,80743024,32575040,12922624},Half{8940288,6068224,2016256,848128,0,0,0,0}}
    case False{}: missing()

def glyphlrlllrl(code: U32) -> Glyph:
  glyphlrlllrl.choose(U32.is_eq(code,86))

def glyphlrlllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,2013905002,1779155065,1259126935,755802789,254510275,240740050},Half{210192624,180759504,149167808,133303968,0,0,0,0}}
    case False{}: missing()

def glyphlrlllrrl(code: U32) -> Glyph:
  glyphlrlllrrl.choose(U32.is_eq(code,87))

def glyphlrlllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,224396530,97520512,12996112,5093376,778496,909568},Half{7182592,31796768,130025888,508560099,0,0,0,0}}
    case False{}: missing()

def glyphlrlllrrr(code: U32) -> Glyph:
  glyphlrlllrrr.choose(U32.is_eq(code,88))

def glyphlrlllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlllrrl(code)
    case False{}: glyphlrlllrrr(code)

def glyphlrlllrr(+code: U32) -> Glyph:
  glyphlrlllrr.choose(code,U32.is_lt(code,88))

def glyphlrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlllrl(code)
    case False{}: glyphlrlllrr(code)

def glyphlrlllr(+code: U32) -> Glyph:
  glyphlrlllr.choose(code,U32.is_lt(code,87))

def glyphlrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrllll(code)
    case False{}: glyphlrlllr(code)

def glyphlrlll(+code: U32) -> Glyph:
  glyphlrlll.choose(code,U32.is_lt(code,86))

def glyphlrllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,773849317,176162512,65080416,11947536,5093376,909568},Half{569344,499712,499712,499712,0,0,0,0}}
    case False{}: missing()

def glyphlrllrll(code: U32) -> Glyph:
  glyphlrllrll.choose(U32.is_eq(code,89))

def glyphlrllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,150994880,114434592,14024704,6164480,753664,254464},Half{39424,7728,19016112,184549328,0,0,0,0}}
    case False{}: missing()

def glyphlrllrlrl(code: U32) -> Glyph:
  glyphlrllrlrl.choose(U32.is_eq(code,90))

def glyphlrllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{13628672,2282752,50432,50432,50432,50432,50432,50432},Half{50432,50432,50432,50432,13628672,2236672,0,0}}
    case False{}: missing()

def glyphlrllrlrr(code: U32) -> Glyph:
  glyphlrllrlrr.choose(U32.is_eq(code,91))

def glyphlrllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrllrlrl(code)
    case False{}: glyphlrllrlrr(code)

def glyphlrllrlr(+code: U32) -> Glyph:
  glyphlrllrlr.choose(code,U32.is_lt(code,91))

def glyphlrllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrllrll(code)
    case False{}: glyphlrllrlr(code)

def glyphlrllrl(+code: U32) -> Glyph:
  glyphlrllrl.choose(code,U32.is_lt(code,90))

def glyphlrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{624,2208,3408,15888,39424,58624,319488,630784},Half{933888,5111808,10027008,14942208,98566144,177209344,0,0}}
    case False{}: missing()

def glyphlrllrrl(code: U32) -> Glyph:
  glyphlrllrrl.choose(U32.is_eq(code,92))

def glyphlrllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{3145488,3092992,3080192,3080192,3080192,3080192,3080192,3080192},Half{3080192,3080192,3080192,3080192,3145488,139776,0,0}}
    case False{}: missing()

def glyphlrllrrrl(code: U32) -> Glyph:
  glyphlrllrrrl.choose(U32.is_eq(code,93))

def glyphlrllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,286720,905472,4884224,11873536,47188816,141558960,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphlrllrrrr(code: U32) -> Glyph:
  glyphlrllrrrr.choose(U32.is_eq(code,94))

def glyphlrllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrllrrrl(code)
    case False{}: glyphlrllrrrr(code)

def glyphlrllrrr(+code: U32) -> Glyph:
  glyphlrllrrr.choose(code,U32.is_lt(code,94))

def glyphlrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrllrrl(code)
    case False{}: glyphlrllrrr(code)

def glyphlrllrr(+code: U32) -> Glyph:
  glyphlrllrr.choose(code,U32.is_lt(code,93))

def glyphlrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrllrl(code)
    case False{}: glyphlrllrr(code)

def glyphlrllr(+code: U32) -> Glyph:
  glyphlrllr.choose(code,U32.is_lt(code,92))

def glyphlrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlll(code)
    case False{}: glyphlrllr(code)

def glyphlrll(+code: U32) -> Glyph:
  glyphlrll.choose(code,U32.is_lt(code,89))

def glyphlrlrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,0,0,0},Half{0,0,0,0,268435443,35791392,0,0}}
    case False{}: missing()

def glyphlrlrlll(code: U32) -> Glyph:
  glyphlrlrlll.choose(U32.is_eq(code,95))

def glyphlrlrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,47104,503808,0,0,0,0,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphlrlrllrl(code: U32) -> Glyph:
  glyphlrlrllrl.choose(U32.is_eq(code,96))

def glyphlrlrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,9366032,114572176,160432128,167771440},Half{160577760,160432881,164964576,161148224,0,0,0,0}}
    case False{}: missing()

def glyphlrlrllrr(code: U32) -> Glyph:
  glyphlrlrllrr.choose(U32.is_eq(code,97))

def glyphlrlrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlrllrl(code)
    case False{}: glyphlrlrllrr(code)

def glyphlrlrllr(+code: U32) -> Glyph:
  glyphlrlrllr.choose(code,U32.is_lt(code,97))

def glyphlrlrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlrlll(code)
    case False{}: glyphlrlrllr(code)

def glyphlrlrll(+code: U32) -> Glyph:
  glyphlrlrll.choose(code,U32.is_lt(code,96))

def glyphlrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,1472,1472,10405824,114572480,159385280,176162240},Half{176162240,159385280,115621056,10405824,0,0,0,0}}
    case False{}: missing()

def glyphlrlrlrl(code: U32) -> Glyph:
  glyphlrlrlrl.choose(U32.is_eq(code,98))

def glyphlrlrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,10414336,131284352,121636544,1488},Half{1488,139462336,131284352,10414336,0,0,0,0}}
    case False{}: missing()

def glyphlrlrlrrl(code: U32) -> Glyph:
  glyphlrlrlrrl.choose(U32.is_eq(code,99))

def glyphlrlrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,159383552,159383552,161213200,164969616,160433600,159384784},Half{159384784,160433600,164969616,161213200,0,0,0,0}}
    case False{}: missing()

def glyphlrlrlrrr(code: U32) -> Glyph:
  glyphlrlrlrrr.choose(U32.is_eq(code,100))

def glyphlrlrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlrlrrl(code)
    case False{}: glyphlrlrlrrr(code)

def glyphlrlrlrr(+code: U32) -> Glyph:
  glyphlrlrlrr.choose(code,U32.is_lt(code,100))

def glyphlrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlrlrl(code)
    case False{}: glyphlrlrlrr(code)

def glyphlrlrlr(+code: U32) -> Glyph:
  glyphlrlrlr.choose(code,U32.is_lt(code,99))

def glyphlrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlrll(code)
    case False{}: glyphlrlrlr(code)

def glyphlrlrl(+code: U32) -> Glyph:
  glyphlrlrl.choose(code,U32.is_lt(code,98))

def glyphlrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,9365776,114572160,175113408,201326560},Half{35792352,17827264,114572416,9365776,0,0,0,0}}
    case False{}: missing()

def glyphlrlrrll(code: U32) -> Glyph:
  glyphlrlrrll.choose(U32.is_eq(code,101))

def glyphlrlrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,234786816,35975680,62208,234881012,35845409,62208},Half{62208,62208,62208,62208,0,0,0,0}}
    case False{}: missing()

def glyphlrlrrlrl(code: U32) -> Glyph:
  glyphlrlrrlrl.choose(U32.is_eq(code,102))

def glyphlrlrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,161212944,164969856,161482432,159385040},Half{159385040,161482432,165878928,162397472,143663104,97722880,9371136,0}}
    case False{}: missing()

def glyphlrlrrlrr(code: U32) -> Glyph:
  glyphlrlrrlrr.choose(U32.is_eq(code,103))

def glyphlrlrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlrrlrl(code)
    case False{}: glyphlrlrrlrr(code)

def glyphlrlrrlr(+code: U32) -> Glyph:
  glyphlrlrrlr.choose(code,U32.is_lt(code,103))

def glyphlrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlrrll(code)
    case False{}: glyphlrlrrlr(code)

def glyphlrlrrl(+code: U32) -> Glyph:
  glyphlrlrrl.choose(code,U32.is_lt(code,102))

def glyphlrlrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,1472,1472,10405824,115621056,160434112,159385024},Half{159385024,159385024,159385024,159385024,0,0,0,0}}
    case False{}: missing()

def glyphlrlrrrll(code: U32) -> Glyph:
  glyphlrlrrrll.choose(U32.is_eq(code,104))

def glyphlrlrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,618496,823296,0,851872,815632,806912,806912},Half{806912,806912,36532768,1073741776,0,0,0,0}}
    case False{}: missing()

def glyphlrlrrrlr(code: U32) -> Glyph:
  glyphlrlrrrlr.choose(U32.is_eq(code,105))

def glyphlrlrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlrrrll(code)
    case False{}: glyphlrlrrrlr(code)

def glyphlrlrrrl(+code: U32) -> Glyph:
  glyphlrlrrrl.choose(code,U32.is_lt(code,105))

def glyphlrlrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,7929856,11206656,0,11534288,11084320,11010048,11010048},Half{11010048,11010048,11010048,11010048,8978432,5132832,450496,0}}
    case False{}: missing()

def glyphlrlrrrrl(code: U32) -> Glyph:
  glyphlrlrrrrl.choose(U32.is_eq(code,106))

def glyphlrlrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,1968,1968,209717168,66258864,9177008,2031536},Half{7223472,14092208,131073968,508561328,0,0,0,0}}
    case False{}: missing()

def glyphlrlrrrrr(code: U32) -> Glyph:
  glyphlrlrrrrr.choose(U32.is_eq(code,107))

def glyphlrlrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlrrrrl(code)
    case False{}: glyphlrlrrrrr(code)

def glyphlrlrrrr(+code: U32) -> Glyph:
  glyphlrlrrrr.choose(code,U32.is_lt(code,107))

def glyphlrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlrrrl(code)
    case False{}: glyphlrlrrrr(code)

def glyphlrlrrr(+code: U32) -> Glyph:
  glyphlrlrrr.choose(code,U32.is_lt(code,106))

def glyphlrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlrrl(code)
    case False{}: glyphlrlrrr(code)

def glyphlrlrr(+code: U32) -> Glyph:
  glyphlrlrr.choose(code,U32.is_lt(code,104))

def glyphlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrlrl(code)
    case False{}: glyphlrlrr(code)

def glyphlrlr(+code: U32) -> Glyph:
  glyphlrlr.choose(code,U32.is_lt(code,101))

def glyphlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrll(code)
    case False{}: glyphlrlr(code)

def glyphlrl(+code: U32) -> Glyph:
  glyphlrl.choose(code,U32.is_lt(code,95))

def glyphlrrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,65529,62497,61952,61952,61952,61952},Half{61952,61952,36040960,805199872,0,0,0,0}}
    case False{}: missing()

def glyphlrrllll(code: U32) -> Glyph:
  glyphlrrllll.choose(U32.is_eq(code,108))

def glyphlrrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,132500419,241812451,253137107,253137107},Half{253137107,253137107,253137107,253137107,0,0,0,0}}
    case False{}: missing()

def glyphlrrlllrl(code: U32) -> Glyph:
  glyphlrrlllrl.choose(U32.is_eq(code,109))

def glyphlrrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,10405824,115621056,160434112,159385024},Half{159385024,159385024,159385024,159385024,0,0,0,0}}
    case False{}: missing()

def glyphlrrlllrr(code: U32) -> Glyph:
  glyphlrrlllrr.choose(U32.is_eq(code,110))

def glyphlrrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrlllrl(code)
    case False{}: glyphlrrlllrr(code)

def glyphlrrlllr(+code: U32) -> Glyph:
  glyphlrrlllr.choose(code,U32.is_lt(code,110))

def glyphlrrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrllll(code)
    case False{}: glyphlrrlllr(code)

def glyphlrrlll(+code: U32) -> Glyph:
  glyphlrrlll.choose(code,U32.is_lt(code,109))

def glyphlrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,8251664,98843776,159385024,191890656},Half{191890656,159385024,98843776,8251664,0,0,0,0}}
    case False{}: missing()

def glyphlrrllrl(code: U32) -> Glyph:
  glyphlrrllrl.choose(U32.is_eq(code,111))

def glyphlrrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,10405824,114572480,159385280,176162240},Half{176162240,159385280,115621056,10405824,1472,1472,1472,0}}
    case False{}: missing()

def glyphlrrllrrl(code: U32) -> Glyph:
  glyphlrrllrrl.choose(U32.is_eq(code,112))

def glyphlrrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,161213200,164969616,160433600,159384784},Half{159384784,160433600,164969616,161213200,159383552,159383552,159383552,0}}
    case False{}: missing()

def glyphlrrllrrr(code: U32) -> Glyph:
  glyphlrrllrrr.choose(U32.is_eq(code,113))

def glyphlrrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrllrrl(code)
    case False{}: glyphlrrllrrr(code)

def glyphlrrllrr(+code: U32) -> Glyph:
  glyphlrrllrr.choose(code,U32.is_lt(code,113))

def glyphlrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrllrl(code)
    case False{}: glyphlrrllrr(code)

def glyphlrrllr(+code: U32) -> Glyph:
  glyphlrrllr.choose(code,U32.is_lt(code,112))

def glyphlrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrlll(code)
    case False{}: glyphlrrllr(code)

def glyphlrrll(+code: U32) -> Glyph:
  glyphlrrll.choose(code,U32.is_lt(code,111))

def glyphlrrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,47098496,179527040,223349376,119540096},Half{2432,2432,2432,2432,0,0,0,0}}
    case False{}: missing()

def glyphlrrlrll(code: U32) -> Glyph:
  glyphlrrlrll.choose(U32.is_eq(code,114))

def glyphlrrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,10418976,131279520,17827760,5951328},Half{115892736,176161088,147008176,28245024,0,0,0,0}}
    case False{}: missing()

def glyphlrrlrlrl(code: U32) -> Glyph:
  glyphlrrlrlrl.choose(U32.is_eq(code,115))

def glyphlrrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,50432,50432,218103798,35837473,50432,50432},Half{50432,50432,35975936,184520704,0,0,0,0}}
    case False{}: missing()

def glyphlrrlrlrr(code: U32) -> Glyph:
  glyphlrrlrlrr.choose(U32.is_eq(code,116))

def glyphlrrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrlrlrl(code)
    case False{}: glyphlrrlrlrr(code)

def glyphlrrlrlr(+code: U32) -> Glyph:
  glyphlrrlrlr.choose(code,U32.is_lt(code,116))

def glyphlrrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrlrll(code)
    case False{}: glyphlrrlrlr(code)

def glyphlrrlrl(+code: U32) -> Glyph:
  glyphlrrlrl.choose(code,U32.is_lt(code,115))

def glyphlrrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,159385024,159385024,159385024,159385024},Half{159385024,143656624,82132336,8251648,0,0,0,0}}
    case False{}: missing()

def glyphlrrlrrll(code: U32) -> Glyph:
  glyphlrrlrrll.choose(U32.is_eq(code,117))

def glyphlrrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,239076082,177211088,97520256,32640576},Half{12013056,7047424,3065088,848128,0,0,0,0}}
    case False{}: missing()

def glyphlrrlrrlr(code: U32) -> Glyph:
  glyphlrrlrrlr.choose(U32.is_eq(code,118))

def glyphlrrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrlrrll(code)
    case False{}: glyphlrrlrrlr(code)

def glyphlrrlrrl(+code: U32) -> Glyph:
  glyphlrrlrrl.choose(code,U32.is_lt(code,118))

def glyphlrrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,1493745784,722190486,218935731,219972817},Half{190473952,145181376,115678880,83037808,0,0,0,0}}
    case False{}: missing()

def glyphlrrlrrrl(code: U32) -> Glyph:
  glyphlrrlrrrl.choose(U32.is_eq(code,119))

def glyphlrrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,178259920,48438848,8165888,909824},Half{2024192,10124288,66198880,209716705,0,0,0,0}}
    case False{}: missing()

def glyphlrrlrrrr(code: U32) -> Glyph:
  glyphlrrlrrrr.choose(U32.is_eq(code,120))

def glyphlrrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrlrrrl(code)
    case False{}: glyphlrrlrrrr(code)

def glyphlrrlrrr(+code: U32) -> Glyph:
  glyphlrrlrrr.choose(code,U32.is_lt(code,120))

def glyphlrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrlrrl(code)
    case False{}: glyphlrrlrrr(code)

def glyphlrrlrr(+code: U32) -> Glyph:
  glyphlrrlrr.choose(code,U32.is_lt(code,119))

def glyphlrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrlrl(code)
    case False{}: glyphlrrlrr(code)

def glyphlrrlr(+code: U32) -> Glyph:
  glyphlrrlr.choose(code,U32.is_lt(code,117))

def glyphlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrll(code)
    case False{}: glyphlrrlr(code)

def glyphlrrl(+code: U32) -> Glyph:
  glyphlrrl.choose(code,U32.is_lt(code,114))

def glyphlrrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,239076082,160434112,80743536,14888736},Half{11041792,6075904,979200,700416,380928,127744,43008,0}}
    case False{}: missing()

def glyphlrrrlll(code: U32) -> Glyph:
  glyphlrrrlll.choose(U32.is_eq(code,121))

def glyphlrrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,134217648,83108368,10223616,1867776},Half{254976,27920,19016592,167772096,0,0,0,0}}
    case False{}: missing()

def glyphlrrrllrl(code: U32) -> Glyph:
  glyphlrrrllrl.choose(U32.is_eq(code,122))

def glyphlrrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{148373504,21905408,811008,872448,933888,811008,188400,754464},Half{933888,872448,811008,1921024,150667264,17825792,0,0}}
    case False{}: missing()

def glyphlrrrllrr(code: U32) -> Glyph:
  glyphlrrrllrr.choose(U32.is_eq(code,123))

def glyphlrrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrrllrl(code)
    case False{}: glyphlrrrllrr(code)

def glyphlrrrllr(+code: U32) -> Glyph:
  glyphlrrrllr.choose(code,U32.is_lt(code,123))

def glyphlrrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrrlll(code)
    case False{}: glyphlrrrllr(code)

def glyphlrrrll(+code: U32) -> Glyph:
  glyphlrrrll.choose(code,U32.is_lt(code,122))

def glyphlrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{282624,499712,499712,499712,499712,499712,499712,499712},Half{499712,499712,499712,499712,499712,499712,0,0}}
    case False{}: missing()

def glyphlrrrlrl(code: U32) -> Glyph:
  glyphlrrrlrl.choose(U32.is_eq(code,124))

def glyphlrrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{32176,193824,258048,127488,58368,189184,218071040,36037120},Half{58368,127488,258048,258560,40880,288,0,0}}
    case False{}: missing()

def glyphlrrrlrrl(code: U32) -> Glyph:
  glyphlrrrlrrl.choose(U32.is_eq(code,125))

def glyphlrrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,221289824,223856112,117252337},Half{1048608,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphlrrrlrrr(code: U32) -> Glyph:
  glyphlrrrlrrr.choose(U32.is_eq(code,126))

def glyphlrrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrrlrrl(code)
    case False{}: glyphlrrrlrrr(code)

def glyphlrrrlrr(+code: U32) -> Glyph:
  glyphlrrrlrr.choose(code,U32.is_lt(code,126))

def glyphlrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrrlrl(code)
    case False{}: glyphlrrrlrr(code)

def glyphlrrrlr(+code: U32) -> Glyph:
  glyphlrrrlr.choose(code,U32.is_lt(code,125))

def glyphlrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrrll(code)
    case False{}: glyphlrrrlr(code)

def glyphlrrrl(+code: U32) -> Glyph:
  glyphlrrrl.choose(code,U32.is_lt(code,124))

def glyphlrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,0,0,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphlrrrrll(code: U32) -> Glyph:
  glyphlrrrrll.choose(U32.is_eq(code,160))

def glyphlrrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,708608,69632,0,0},Half{499712,499712,499712,569344,569344,569344,638976,0}}
    case False{}: missing()

def glyphlrrrrlrl(code: U32) -> Glyph:
  glyphlrrrrlrl.choose(U32.is_eq(code,161))

def glyphlrrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,356352,356352,28310032,147299456,121992896,357840},Half{357840,121992640,147229840,29358864,421888,356352,0,0}}
    case False{}: missing()

def glyphlrrrrlrr(code: U32) -> Glyph:
  glyphlrrrrlrr.choose(U32.is_eq(code,162))

def glyphlrrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrrrlrl(code)
    case False{}: glyphlrrrrlrr(code)

def glyphlrrrrlr(+code: U32) -> Glyph:
  glyphlrrrrlr.choose(code,U32.is_lt(code,162))

def glyphlrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrrrll(code)
    case False{}: glyphlrrrrlr(code)

def glyphlrrrrl(+code: U32) -> Glyph:
  glyphlrrrrl.choose(code,U32.is_lt(code,161))

def glyphlrrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,27192096,148126384,52430528,3168,11534320,2267680},Half{31488,16176,35793360,251658224,0,0,0,0}}
    case False{}: missing()

def glyphlrrrrrll(code: U32) -> Glyph:
  glyphlrrrrrll.choose(U32.is_eq(code,163))

def glyphlrrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,117440641,498985954,98909552,125830560,141558960},Half{80878448,199228881,437325986,0,0,0,0,0}}
    case False{}: missing()

def glyphlrrrrrlr(code: U32) -> Glyph:
  glyphlrrrrrlr.choose(U32.is_eq(code,164))

def glyphlrrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrrrrll(code)
    case False{}: glyphlrrrrrlr(code)

def glyphlrrrrrl(+code: U32) -> Glyph:
  glyphlrrrrrl.choose(code,U32.is_lt(code,164))

def glyphlrrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,773849317,160433856,48303440,11033856,4113920,268435443},Half{36221472,268435443,36221472,499712,0,0,0,0}}
    case False{}: missing()

def glyphlrrrrrrl(code: U32) -> Glyph:
  glyphlrrrrrrl.choose(U32.is_eq(code,165))

def glyphlrrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,499712,499712,499712,499712,499712,0,0},Half{0,499712,499712,499712,499712,499712,0,0}}
    case False{}: missing()

def glyphlrrrrrrr(code: U32) -> Glyph:
  glyphlrrrrrrr.choose(U32.is_eq(code,166))

def glyphlrrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrrrrrl(code)
    case False{}: glyphlrrrrrrr(code)

def glyphlrrrrrr(+code: U32) -> Glyph:
  glyphlrrrrrr.choose(code,U32.is_lt(code,166))

def glyphlrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrrrrl(code)
    case False{}: glyphlrrrrrr(code)

def glyphlrrrrr(+code: U32) -> Glyph:
  glyphlrrrrr.choose(code,U32.is_lt(code,165))

def glyphlrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrrrl(code)
    case False{}: glyphlrrrrr(code)

def glyphlrrrr(+code: U32) -> Glyph:
  glyphlrrrr.choose(code,U32.is_lt(code,163))

def glyphlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrrl(code)
    case False{}: glyphlrrrr(code)

def glyphlrrr(+code: U32) -> Glyph:
  glyphlrrr.choose(code,U32.is_lt(code,160))

def glyphlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrrl(code)
    case False{}: glyphlrrr(code)

def glyphlrr(+code: U32) -> Glyph:
  glyphlrr.choose(code,U32.is_lt(code,121))

def glyphlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphlrl(code)
    case False{}: glyphlrr(code)

def glyphlr(+code: U32) -> Glyph:
  glyphlr.choose(code,U32.is_lt(code,108))

def glyphl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphll(code)
    case False{}: glyphlr(code)

def glyphl(+code: U32) -> Glyph:
  glyphl.choose(code,U32.is_lt(code,83))

def glyphrllllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,28244768,147008416,17827520,89488,29211664,144705424},Half{191891152,149397152,13630752,132591616,191889424,178259920,48234064,139264}}
    case False{}: missing()

def glyphrllllll(code: U32) -> Glyph:
  glyphrllllll.choose(U32.is_eq(code,167))

def glyphrlllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,11737888,30748208,0,0,0,0,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrlllllrl(code: U32) -> Glyph:
  glyphrlllllrl.choose(U32.is_eq(code,168))

def glyphrlllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,8108048,157287600,439210868,945117526,939539014,946166358},Half{440333684,157357232,8108048,0,0,0,0,0}}
    case False{}: missing()

def glyphrlllllrr(code: U32) -> Glyph:
  glyphrlllllrr.choose(U32.is_eq(code,169))

def glyphrlllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlllllrl(code)
    case False{}: glyphrlllllrr(code)

def glyphrlllllr(+code: U32) -> Glyph:
  glyphrlllllr.choose(code,U32.is_lt(code,169))

def glyphrlllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllllll(code)
    case False{}: glyphrlllllr(code)

def glyphrlllll(+code: U32) -> Glyph:
  glyphrlllll.choose(code,U32.is_lt(code,168))

def glyphrllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,2864128,8246528,7674368,6870272,0,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrllllrl(code: U32) -> Glyph:
  glyphrllllrl.choose(U32.is_eq(code,170))

def glyphrllllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,492951296,65158704,8128209,938198},Half{9177041,81935920,492951296,0,0,0,0,0}}
    case False{}: missing()

def glyphrllllrrl(code: U32) -> Glyph:
  glyphrllllrrl.choose(U32.is_eq(code,171))

def glyphrllllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,0,134217632,144843296},Half{143654912,17825792,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrllllrrr(code: U32) -> Glyph:
  glyphrllllrrr.choose(U32.is_eq(code,172))

def glyphrllllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllllrrl(code)
    case False{}: glyphrllllrrr(code)

def glyphrllllrr(+code: U32) -> Glyph:
  glyphrllllrr.choose(code,U32.is_lt(code,172))

def glyphrllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllllrl(code)
    case False{}: glyphrllllrr(code)

def glyphrllllr(+code: U32) -> Glyph:
  glyphrllllr.choose(code,U32.is_lt(code,171))

def glyphrllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlllll(code)
    case False{}: glyphrllllr(code)

def glyphrllll(+code: U32) -> Glyph:
  glyphrllll.choose(code,U32.is_lt(code,170))

def glyphrlllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,0,0,15728432},Half{2236928,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrlllrll(code: U32) -> Glyph:
  glyphrlllrll.choose(U32.is_eq(code,173))

def glyphrlllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,26077728,178534592,472774804,946432086,942602310,940337238,710293365},Half{193005009,46136624,73728,0,0,0,0,0}}
    case False{}: missing()

def glyphrlllrlrl(code: U32) -> Glyph:
  glyphrlllrlrl.choose(U32.is_eq(code,174))

def glyphrlllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,15728432,2236928,0,0,0,0,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrlllrlrr(code: U32) -> Glyph:
  glyphrlllrlrr.choose(U32.is_eq(code,175))

def glyphrlllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlllrlrl(code)
    case False{}: glyphrlllrlrr(code)

def glyphrlllrlr(+code: U32) -> Glyph:
  glyphrlllrlr.choose(code,U32.is_lt(code,175))

def glyphrlllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlllrll(code)
    case False{}: glyphrlllrlr(code)

def glyphrlllrl(+code: U32) -> Glyph:
  glyphrlllrl.choose(code,U32.is_lt(code,174))

def glyphrlllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,3986688,11947264,12791040,6289152,69632,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrlllrrl(code: U32) -> Glyph:
  glyphrlllrrl.choose(U32.is_eq(code,176))

def glyphrlllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,499712,499712,499712,251658226},Half{36221472,499712,499712,234881009,0,0,0,0}}
    case False{}: missing()

def glyphrlllrrrl(code: U32) -> Glyph:
  glyphrlllrrrl.choose(U32.is_eq(code,177))

def glyphrlllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,5031168,13769728,11796480,1855488,112128,13426432,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrlllrrrr(code: U32) -> Glyph:
  glyphrlllrrrr.choose(U32.is_eq(code,178))

def glyphrlllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlllrrrl(code)
    case False{}: glyphrlllrrrr(code)

def glyphrlllrrr(+code: U32) -> Glyph:
  glyphrlllrrr.choose(code,U32.is_lt(code,178))

def glyphrlllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlllrrl(code)
    case False{}: glyphrlllrrr(code)

def glyphrlllrr(+code: U32) -> Glyph:
  glyphrlllrr.choose(code,U32.is_lt(code,177))

def glyphrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlllrl(code)
    case False{}: glyphrlllrr(code)

def glyphrlllr(+code: U32) -> Glyph:
  glyphrlllr.choose(code,U32.is_lt(code,176))

def glyphrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllll(code)
    case False{}: glyphrlllr(code)

def glyphrlll(+code: U32) -> Glyph:
  glyphrlll.choose(code,U32.is_lt(code,173))

def glyphrllrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,13486848,3874816,5017600,13762560,13765648,6149888,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrllrlll(code: U32) -> Glyph:
  glyphrllrlll.choose(U32.is_eq(code,179))

def glyphrllrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,5050368,565248,0,0,0,0,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrllrllrl(code: U32) -> Glyph:
  glyphrllrllrl.choose(U32.is_eq(code,180))

def glyphrllrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,160433856,160433856,160433856,160433856},Half{160433856,161482688,164969664,162392768,1728,1728,1728,0}}
    case False{}: missing()

def glyphrllrllrr(code: U32) -> Glyph:
  glyphrllrllrr.choose(U32.is_eq(code,181))

def glyphrllrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllrllrl(code)
    case False{}: glyphrllrllrr(code)

def glyphrllrllr(+code: U32) -> Glyph:
  glyphrllrllr.choose(code,U32.is_lt(code,181))

def glyphrllrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllrlll(code)
    case False{}: glyphrllrllr(code)

def glyphrllrll(+code: U32) -> Glyph:
  glyphrllrll.choose(code,U32.is_lt(code,180))

def glyphrllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,141950272,141950944,141950962,141950962,141950944,141950272},Half{141926400,141926400,141926400,141926400,141926400,141926400,141926400,0}}
    case False{}: missing()

def glyphrllrlrl(code: U32) -> Glyph:
  glyphrllrlrl.choose(U32.is_eq(code,182))

def glyphrllrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,69632,844032,774400},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrllrlrrl(code: U32) -> Glyph:
  glyphrllrlrrl.choose(U32.is_eq(code,183))

def glyphrllrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,0,0,0},Half{0,0,0,0,114688,2965504,3077376,73984}}
    case False{}: missing()

def glyphrllrlrrr(code: U32) -> Glyph:
  glyphrllrlrrr.choose(U32.is_eq(code,184))

def glyphrllrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllrlrrl(code)
    case False{}: glyphrllrlrrr(code)

def glyphrllrlrr(+code: U32) -> Glyph:
  glyphrllrlrr.choose(code,U32.is_lt(code,184))

def glyphrllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllrlrl(code)
    case False{}: glyphrllrlrr(code)

def glyphrllrlr(+code: U32) -> Glyph:
  glyphrllrlr.choose(code,U32.is_lt(code,183))

def glyphrllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllrll(code)
    case False{}: glyphrllrlr(code)

def glyphrllrl(+code: U32) -> Glyph:
  glyphrllrl.choose(code,U32.is_lt(code,182))

def glyphrllrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,775424,739840,733184,733184,733184,64937232,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrllrrll(code: U32) -> Glyph:
  glyphrllrrll.choose(U32.is_eq(code,185))

def glyphrllrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,1819392,6629632,6629632,1819392,0,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrllrrlrl(code: U32) -> Glyph:
  glyphrllrrlrl.choose(U32.is_eq(code,186))

def glyphrllrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,5120995,30809456,178297600,1059255040},Half{195074816,31858032,5120995,0,0,0,0,0}}
    case False{}: missing()

def glyphrllrrlrr(code: U32) -> Glyph:
  glyphrllrrlrr.choose(U32.is_eq(code,187))

def glyphrllrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllrrlrl(code)
    case False{}: glyphrllrrlrr(code)

def glyphrllrrlr(+code: U32) -> Glyph:
  glyphrllrrlr.choose(code,U32.is_lt(code,187))

def glyphrllrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllrrll(code)
    case False{}: glyphrllrrlr(code)

def glyphrllrrl(+code: U32) -> Glyph:
  glyphrllrrl.choose(code,U32.is_lt(code,186))

def glyphrllrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,1140852048,773852036,128977680,14027536,5164215,630784,58844160},Half{10771712,186387312,247202529,201326714,0,0,0,0}}
    case False{}: missing()

def glyphrllrrrll(code: U32) -> Glyph:
  glyphrllrrrll.choose(U32.is_eq(code,188))

def glyphrllrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,855639088,1024461715,162532113,30870288,6291449,758305,468181504},Half{1246460672,437259344,43320273,1876820120,304218114,0,0,0}}
    case False{}: missing()

def glyphrllrrrlr(code: U32) -> Glyph:
  glyphrllrrrlr.choose(U32.is_eq(code,189))

def glyphrllrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllrrrll(code)
    case False{}: glyphrllrrrlr(code)

def glyphrllrrrl(+code: U32) -> Glyph:
  glyphrllrrrl.choose(code,U32.is_lt(code,189))

def glyphrllrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,1744858292,221256208,96484704,10917120,2968501,495616,59822848},Half{10767360,186387040,247202513,201326714,0,0,0,0}}
    case False{}: missing()

def glyphrllrrrrl(code: U32) -> Glyph:
  glyphrllrrrrl.choose(U32.is_eq(code,190))

def glyphrllrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,6242304,65536,0,2953216},Half{3084288,3134976,163632,2928,2928,2260768,50320640,0}}
    case False{}: missing()

def glyphrllrrrrr(code: U32) -> Glyph:
  glyphrllrrrrr.choose(U32.is_eq(code,191))

def glyphrllrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllrrrrl(code)
    case False{}: glyphrllrrrrr(code)

def glyphrllrrrr(+code: U32) -> Glyph:
  glyphrllrrrr.choose(code,U32.is_lt(code,191))

def glyphrllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllrrrl(code)
    case False{}: glyphrllrrrr(code)

def glyphrllrrr(+code: U32) -> Glyph:
  glyphrllrrr.choose(code,U32.is_lt(code,190))

def glyphrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllrrl(code)
    case False{}: glyphrllrrr(code)

def glyphrllrr(+code: U32) -> Glyph:
  glyphrllrr.choose(code,U32.is_lt(code,188))

def glyphrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrllrl(code)
    case False{}: glyphrllrr(code)

def glyphrllr(+code: U32) -> Glyph:
  glyphrllr.choose(code,U32.is_lt(code,185))

def glyphrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlll(code)
    case False{}: glyphrllr(code)

def glyphrll(+code: U32) -> Glyph:
  glyphrll.choose(code,U32.is_lt(code,179))

def glyphrlrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,847872,2085888,6067968,8936192,12852736,32574784},Half{83816304,143796144,206570464,522191075,0,0,0,0}}
    case False{}: missing()

def glyphrlrllll(code: U32) -> Glyph:
  glyphrlrllll.choose(U32.is_eq(code,192))

def glyphrlrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,847872,2085888,6067968,8936192,12852736,32574784},Half{83816304,143796144,206570464,522191075,0,0,0,0}}
    case False{}: missing()

def glyphrlrlllrl(code: U32) -> Glyph:
  glyphrlrlllrl.choose(U32.is_eq(code,193))

def glyphrlrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,847872,2085888,6067968,8936192,12852736,32574784},Half{83816304,143796144,206570464,522191075,0,0,0,0}}
    case False{}: missing()

def glyphrlrlllrr(code: U32) -> Glyph:
  glyphrlrlllrr.choose(U32.is_eq(code,194))

def glyphrlrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrlllrl(code)
    case False{}: glyphrlrlllrr(code)

def glyphrlrlllr(+code: U32) -> Glyph:
  glyphrlrlllr.choose(code,U32.is_lt(code,194))

def glyphrlrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrllll(code)
    case False{}: glyphrlrlllr(code)

def glyphrlrlll(+code: U32) -> Glyph:
  glyphrlrlll.choose(code,U32.is_lt(code,193))

def glyphrlrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,847872,2085888,6067968,8936192,12852736,32574784},Half{83816304,143796144,206570464,522191075,0,0,0,0}}
    case False{}: missing()

def glyphrlrllrl(code: U32) -> Glyph:
  glyphrlrllrl.choose(U32.is_eq(code,195))

def glyphrlrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,847872,2085888,6067968,8936192,12852736,32574784},Half{83816304,143796144,206570464,522191075,0,0,0,0}}
    case False{}: missing()

def glyphrlrllrrl(code: U32) -> Glyph:
  glyphrlrllrrl.choose(U32.is_eq(code,196))

def glyphrlrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{4125952,69632,847872,2085888,6067968,8936192,12852736,32574784},Half{83816304,143796144,206570464,522191075,0,0,0,0}}
    case False{}: missing()

def glyphrlrllrrr(code: U32) -> Glyph:
  glyphrlrllrrr.choose(U32.is_eq(code,197))

def glyphrlrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrllrrl(code)
    case False{}: glyphrlrllrrr(code)

def glyphrlrllrr(+code: U32) -> Glyph:
  glyphrlrllrr.choose(code,U32.is_lt(code,197))

def glyphrlrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrllrl(code)
    case False{}: glyphrlrllrr(code)

def glyphrlrllr(+code: U32) -> Glyph:
  glyphrlrllr.choose(code,U32.is_lt(code,196))

def glyphrlrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrlll(code)
    case False{}: glyphrlrllr(code)

def glyphrlrll(+code: U32) -> Glyph:
  glyphrlrll.choose(code,U32.is_lt(code,195))

def glyphrlrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,1879047168,305090304,2039344,2038624,536811920,37689008},Half{2097120,2044914,305074389,1878986920,0,0,0,0}}
    case False{}: missing()

def glyphrlrlrll(code: U32) -> Glyph:
  glyphrlrlrll.choose(U32.is_eq(code,198))

def glyphrlrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,10414336,131284336,157288112,1472,1472,1472},Half{1472,157288112,131284352,10418448,442368,5054464,3011584,0}}
    case False{}: missing()

def glyphrlrlrlrl(code: U32) -> Glyph:
  glyphrlrlrlrl.choose(U32.is_eq(code,199))

def glyphrlrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,218103728,19015856,1968,1968,100663216,19015856},Half{1968,1968,19015856,218103728,0,0,0,0}}
    case False{}: missing()

def glyphrlrlrlrr(code: U32) -> Glyph:
  glyphrlrlrlrr.choose(U32.is_eq(code,200))

def glyphrlrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrlrlrl(code)
    case False{}: glyphrlrlrlrr(code)

def glyphrlrlrlr(+code: U32) -> Glyph:
  glyphrlrlrlr.choose(code,U32.is_lt(code,200))

def glyphrlrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrlrll(code)
    case False{}: glyphrlrlrlr(code)

def glyphrlrlrl(+code: U32) -> Glyph:
  glyphrlrlrl.choose(code,U32.is_lt(code,199))

def glyphrlrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,218103728,19015856,1968,1968,100663216,19015856},Half{1968,1968,19015856,218103728,0,0,0,0}}
    case False{}: missing()

def glyphrlrlrrll(code: U32) -> Glyph:
  glyphrlrlrrll.choose(U32.is_eq(code,201))

def glyphrlrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,218103728,19015856,1968,1968,100663216,19015856},Half{1968,1968,19015856,218103728,0,0,0,0}}
    case False{}: missing()

def glyphrlrlrrlr(code: U32) -> Glyph:
  glyphrlrlrrlr.choose(U32.is_eq(code,202))

def glyphrlrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrlrrll(code)
    case False{}: glyphrlrlrrlr(code)

def glyphrlrlrrl(+code: U32) -> Glyph:
  glyphrlrlrrl.choose(code,U32.is_lt(code,202))

def glyphrlrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,218103728,19015856,1968,1968,100663216,19015856},Half{1968,1968,19015856,218103728,0,0,0,0}}
    case False{}: missing()

def glyphrlrlrrrl(code: U32) -> Glyph:
  glyphrlrlrrrl.choose(U32.is_eq(code,203))

def glyphrlrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,134217632,19444240,569344,569344,569344,569344},Half{569344,569344,19444240,134217632,0,0,0,0}}
    case False{}: missing()

def glyphrlrlrrrr(code: U32) -> Glyph:
  glyphrlrlrrrr.choose(U32.is_eq(code,204))

def glyphrlrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrlrrrl(code)
    case False{}: glyphrlrlrrrr(code)

def glyphrlrlrrr(+code: U32) -> Glyph:
  glyphrlrlrrr.choose(code,U32.is_lt(code,204))

def glyphrlrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrlrrl(code)
    case False{}: glyphrlrlrrr(code)

def glyphrlrlrr(+code: U32) -> Glyph:
  glyphrlrlrr.choose(code,U32.is_lt(code,203))

def glyphrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrlrl(code)
    case False{}: glyphrlrlrr(code)

def glyphrlrlr(+code: U32) -> Glyph:
  glyphrlrlr.choose(code,U32.is_lt(code,201))

def glyphrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrll(code)
    case False{}: glyphrlrlr(code)

def glyphrlrl(+code: U32) -> Glyph:
  glyphrlrl.choose(code,U32.is_lt(code,198))

def glyphrlrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,134217632,19444240,569344,569344,569344,569344},Half{569344,569344,19444240,134217632,0,0,0,0}}
    case False{}: missing()

def glyphrlrrlll(code: U32) -> Glyph:
  glyphrlrrlll.choose(U32.is_eq(code,205))

def glyphrlrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,134217632,19444240,569344,569344,569344,569344},Half{569344,569344,19444240,134217632,0,0,0,0}}
    case False{}: missing()

def glyphrlrrllrl(code: U32) -> Glyph:
  glyphrlrrllrl.choose(U32.is_eq(code,206))

def glyphrlrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,134217632,19444240,569344,569344,569344,569344},Half{569344,569344,19444240,134217632,0,0,0,0}}
    case False{}: missing()

def glyphrlrrllrr(code: U32) -> Glyph:
  glyphrlrrllrr.choose(U32.is_eq(code,207))

def glyphrlrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrrllrl(code)
    case False{}: glyphrlrrllrr(code)

def glyphrlrrllr(+code: U32) -> Glyph:
  glyphrlrrllr.choose(code,U32.is_lt(code,207))

def glyphrlrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrrlll(code)
    case False{}: glyphrlrrllr(code)

def glyphrlrrll(+code: U32) -> Glyph:
  glyphrlrrll.choose(code,U32.is_lt(code,206))

def glyphrlrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,7208896,82126784,160433600,176162240,176209917,176170946},Half{176162240,160433600,82126784,7208896,0,0,0,0}}
    case False{}: missing()

def glyphrlrrlrl(code: U32) -> Glyph:
  glyphrlrrlrl.choose(U32.is_eq(code,208))

def glyphrlrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,159387072,159403712,159423424,159442624,159696064,158954688},Half{159261888,163316928,166134976,166855872,0,0,0,0}}
    case False{}: missing()

def glyphrlrrlrrl(code: U32) -> Glyph:
  glyphrlrrlrrl.choose(U32.is_eq(code,209))

def glyphrlrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,8251664,98843776,160433600,176162256,176162256,176162256},Half{176162256,159385024,98843776,9366032,0,0,0,0}}
    case False{}: missing()

def glyphrlrrlrrr(code: U32) -> Glyph:
  glyphrlrrlrrr.choose(U32.is_eq(code,210))

def glyphrlrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrrlrrl(code)
    case False{}: glyphrlrrlrrr(code)

def glyphrlrrlrr(+code: U32) -> Glyph:
  glyphrlrrlrr.choose(code,U32.is_lt(code,210))

def glyphrlrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrrlrl(code)
    case False{}: glyphrlrrlrr(code)

def glyphrlrrlr(+code: U32) -> Glyph:
  glyphrlrrlr.choose(code,U32.is_lt(code,209))

def glyphrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrrll(code)
    case False{}: glyphrlrrlr(code)

def glyphrlrrl(+code: U32) -> Glyph:
  glyphrlrrl.choose(code,U32.is_lt(code,208))

def glyphrlrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,8251664,98843776,160433600,176162256,176162256,176162256},Half{176162256,159385024,98843776,9366032,0,0,0,0}}
    case False{}: missing()

def glyphrlrrrll(code: U32) -> Glyph:
  glyphrlrrrll.choose(U32.is_eq(code,211))

def glyphrlrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,8251664,98843776,160433600,176162256,176162256,176162256},Half{176162256,159385024,98843776,9366032,0,0,0,0}}
    case False{}: missing()

def glyphrlrrrlrl(code: U32) -> Glyph:
  glyphrlrrrlrl.choose(U32.is_eq(code,212))

def glyphrlrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,8251664,98843776,160433600,176162256,176162256,176162256},Half{176162256,159385024,98843776,9366032,0,0,0,0}}
    case False{}: missing()

def glyphrlrrrlrr(code: U32) -> Glyph:
  glyphrlrrrlrr.choose(U32.is_eq(code,213))

def glyphrlrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrrrlrl(code)
    case False{}: glyphrlrrrlrr(code)

def glyphrlrrrlr(+code: U32) -> Glyph:
  glyphrlrrrlr.choose(code,U32.is_lt(code,213))

def glyphrlrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrrrll(code)
    case False{}: glyphrlrrrlr(code)

def glyphrlrrrl(+code: U32) -> Glyph:
  glyphrlrrrl.choose(code,U32.is_lt(code,212))

def glyphrlrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,8251664,98843776,160433600,176162256,176162256,176162256},Half{176162256,159385024,98843776,9366032,0,0,0,0}}
    case False{}: missing()

def glyphrlrrrrll(code: U32) -> Glyph:
  glyphrlrrrrll.choose(U32.is_eq(code,214))

def glyphrlrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,41944384,12148000,844288},Half{6142208,47324000,1048576,0,0,0,0,0}}
    case False{}: missing()

def glyphrlrrrrlr(code: U32) -> Glyph:
  glyphrlrrrrlr.choose(U32.is_eq(code,215))

def glyphrlrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrrrrll(code)
    case False{}: glyphrlrrrrlr(code)

def glyphrlrrrrl(+code: U32) -> Glyph:
  glyphrlrrrrl.choose(code,U32.is_lt(code,215))

def glyphrlrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,781117968,166018176,166856128,182126032,176965072,176473552},Half{176204752,159395776,98844064,9366241,83,0,0,0}}
    case False{}: missing()

def glyphrlrrrrrl(code: U32) -> Glyph:
  glyphrlrrrrrl.choose(U32.is_eq(code,216))

def glyphrlrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,159385024,159385024,159385024,159385024,159385024,159385024},Half{159385024,160433856,98843776,9366032,0,0,0,0}}
    case False{}: missing()

def glyphrlrrrrrr(code: U32) -> Glyph:
  glyphrlrrrrrr.choose(U32.is_eq(code,217))

def glyphrlrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrrrrrl(code)
    case False{}: glyphrlrrrrrr(code)

def glyphrlrrrrr(+code: U32) -> Glyph:
  glyphrlrrrrr.choose(code,U32.is_lt(code,217))

def glyphrlrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrrrrl(code)
    case False{}: glyphrlrrrrr(code)

def glyphrlrrrr(+code: U32) -> Glyph:
  glyphrlrrrr.choose(code,U32.is_lt(code,216))

def glyphrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrrrl(code)
    case False{}: glyphrlrrrr(code)

def glyphrlrrr(+code: U32) -> Glyph:
  glyphrlrrr.choose(code,U32.is_lt(code,214))

def glyphrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrrl(code)
    case False{}: glyphrlrrr(code)

def glyphrlrr(+code: U32) -> Glyph:
  glyphrlrr.choose(code,U32.is_lt(code,211))

def glyphrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrlrl(code)
    case False{}: glyphrlrr(code)

def glyphrlr(+code: U32) -> Glyph:
  glyphrlr.choose(code,U32.is_lt(code,205))

def glyphrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrll(code)
    case False{}: glyphrlr(code)

def glyphrl(+code: U32) -> Glyph:
  glyphrl.choose(code,U32.is_lt(code,192))

def glyphrrlllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,159385024,159385024,159385024,159385024,159385024,159385024},Half{159385024,160433856,98843776,9366032,0,0,0,0}}
    case False{}: missing()

def glyphrrlllll(code: U32) -> Glyph:
  glyphrrlllll.choose(U32.is_eq(code,218))

def glyphrrllllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,159385024,159385024,159385024,159385024,159385024,159385024},Half{159385024,160433856,98843776,9366032,0,0,0,0}}
    case False{}: missing()

def glyphrrllllrl(code: U32) -> Glyph:
  glyphrrllllrl.choose(U32.is_eq(code,219))

def glyphrrllllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,159385024,159385024,159385024,159385024,159385024,159385024},Half{159385024,160433856,98843776,9366032,0,0,0,0}}
    case False{}: missing()

def glyphrrllllrr(code: U32) -> Glyph:
  glyphrrllllrr.choose(U32.is_eq(code,220))

def glyphrrllllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrllllrl(code)
    case False{}: glyphrrllllrr(code)

def glyphrrllllr(+code: U32) -> Glyph:
  glyphrrllllr.choose(code,U32.is_lt(code,220))

def glyphrrllll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlllll(code)
    case False{}: glyphrrllllr(code)

def glyphrrllll(+code: U32) -> Glyph:
  glyphrrllll.choose(code,U32.is_lt(code,219))

def glyphrrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,773849317,176162512,65080416,11947536,5093376,909568},Half{569344,499712,499712,499712,0,0,0,0}}
    case False{}: missing()

def glyphrrlllrl(code: U32) -> Glyph:
  glyphrrlllrl.choose(U32.is_eq(code,221))

def glyphrrlllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,1472,1472,62848960,227747776,790627776,242222528},Half{82837440,141248,1472,1472,0,0,0,0}}
    case False{}: missing()

def glyphrrlllrrl(code: U32) -> Glyph:
  glyphrrlllrrl.choose(U32.is_eq(code,222))

def glyphrrlllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,10414336,131349888,159385264,96601536,10462656,131343808},Half{223348160,240125376,164894144,28222912,0,0,0,0}}
    case False{}: missing()

def glyphrrlllrrr(code: U32) -> Glyph:
  glyphrrlllrrr.choose(U32.is_eq(code,223))

def glyphrrlllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlllrrl(code)
    case False{}: glyphrrlllrrr(code)

def glyphrrlllrr(+code: U32) -> Glyph:
  glyphrrlllrr.choose(code,U32.is_lt(code,223))

def glyphrrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlllrl(code)
    case False{}: glyphrrlllrr(code)

def glyphrrlllr(+code: U32) -> Glyph:
  glyphrrlllr.choose(code,U32.is_lt(code,222))

def glyphrrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrllll(code)
    case False{}: glyphrrlllr(code)

def glyphrrlll(+code: U32) -> Glyph:
  glyphrrlll.choose(code,U32.is_lt(code,221))

def glyphrrllrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,43264,442368,0,9366032,114572176,160432128,167771440},Half{160577760,160432881,164964576,161148224,0,0,0,0}}
    case False{}: missing()

def glyphrrllrll(code: U32) -> Glyph:
  glyphrrllrll.choose(U32.is_eq(code,224))

def glyphrrllrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,8060928,749568,0,9366032,114572176,160432128,167771440},Half{160577760,160432881,164964576,161148224,0,0,0,0}}
    case False{}: missing()

def glyphrrllrlrl(code: U32) -> Glyph:
  glyphrrllrlrl.choose(U32.is_eq(code,225))

def glyphrrllrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,1958400,29846800,0,9366032,114572176,160432128,167771440},Half{160577760,160432881,164964576,161148224,0,0,0,0}}
    case False{}: missing()

def glyphrrllrlrr(code: U32) -> Glyph:
  glyphrrllrlrr.choose(U32.is_eq(code,226))

def glyphrrllrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrllrlrl(code)
    case False{}: glyphrrllrlrr(code)

def glyphrrllrlr(+code: U32) -> Glyph:
  glyphrrllrlr.choose(code,U32.is_lt(code,226))

def glyphrrllrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrllrll(code)
    case False{}: glyphrrllrlr(code)

def glyphrrllrl(+code: U32) -> Glyph:
  glyphrrllrl.choose(code,U32.is_lt(code,225))

def glyphrrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,12765952,11287056,0,9366032,114572176,160432128,167771440},Half{160577760,160432881,164964576,161148224,0,0,0,0}}
    case False{}: missing()

def glyphrrllrrl(code: U32) -> Glyph:
  glyphrrllrrl.choose(U32.is_eq(code,227))

def glyphrrllrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,28519200,31735328,0,9366032,114572176,160432128,167771440},Half{160577760,160432881,164964576,161148224,0,0,0,0}}
    case False{}: missing()

def glyphrrllrrrl(code: U32) -> Glyph:
  glyphrrllrrrl.choose(U32.is_eq(code,228))

def glyphrrllrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{2937600,7895040,4125696,69632,9366032,114572176,160432128,167771440},Half{160577760,160432881,164964576,161148224,0,0,0,0}}
    case False{}: missing()

def glyphrrllrrrr(code: U32) -> Glyph:
  glyphrrllrrrr.choose(U32.is_eq(code,229))

def glyphrrllrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrllrrrl(code)
    case False{}: glyphrrllrrrr(code)

def glyphrrllrrr(+code: U32) -> Glyph:
  glyphrrllrrr.choose(code,U32.is_lt(code,229))

def glyphrrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrllrrl(code)
    case False{}: glyphrrllrrr(code)

def glyphrrllrr(+code: U32) -> Glyph:
  glyphrrllrr.choose(code,U32.is_lt(code,228))

def glyphrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrllrl(code)
    case False{}: glyphrrllrr(code)

def glyphrrllr(+code: U32) -> Glyph:
  glyphrrllr.choose(code,U32.is_lt(code,227))

def glyphrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlll(code)
    case False{}: glyphrrllr(code)

def glyphrrll(+code: U32) -> Glyph:
  glyphrrll.choose(code,U32.is_lt(code,224))

def glyphrrlrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,166301344,1042989524,1527222288,1609498272},Half{304648902,17272968,1311490502,166297265,0,0,0,0}}
    case False{}: missing()

def glyphrrlrlll(code: U32) -> Glyph:
  glyphrrlrlll.choose(U32.is_eq(code,230))

def glyphrrlrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,10414336,131284352,121636544,1488},Half{1488,139462336,131284352,10418432,442368,5054720,3011584,0}}
    case False{}: missing()

def glyphrrlrllrl(code: U32) -> Glyph:
  glyphrrlrllrl.choose(U32.is_eq(code,231))

def glyphrrlrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,43520,381184,0,9365776,114572160,175113408,201326560},Half{35792352,17827264,114572416,9365776,0,0,0,0}}
    case False{}: missing()

def glyphrrlrllrr(code: U32) -> Glyph:
  glyphrrlrllrr.choose(U32.is_eq(code,232))

def glyphrrlrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlrllrl(code)
    case False{}: glyphrrlrllrr(code)

def glyphrrlrllr(+code: U32) -> Glyph:
  glyphrrlrllr.choose(code,U32.is_lt(code,232))

def glyphrrlrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlrlll(code)
    case False{}: glyphrrlrllr(code)

def glyphrrlrll(+code: U32) -> Glyph:
  glyphrrlrll.choose(code,U32.is_lt(code,231))

def glyphrrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,7077888,753664,0,9365776,114572160,175113408,201326560},Half{35792352,17827264,114572416,9365776,0,0,0,0}}
    case False{}: missing()

def glyphrrlrlrl(code: U32) -> Glyph:
  glyphrrlrlrl.choose(U32.is_eq(code,233))

def glyphrrlrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,1893120,12082464,0,9365776,114572160,175113408,201326560},Half{35792352,17827264,114572416,9365776,0,0,0,0}}
    case False{}: missing()

def glyphrrlrlrrl(code: U32) -> Glyph:
  glyphrrlrlrrl.choose(U32.is_eq(code,234))

def glyphrrlrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,11737888,30748208,0,9365776,114572160,175113408,201326560},Half{35792352,17827264,114572416,9365776,0,0,0,0}}
    case False{}: missing()

def glyphrrlrlrrr(code: U32) -> Glyph:
  glyphrrlrlrrr.choose(U32.is_eq(code,235))

def glyphrrlrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlrlrrl(code)
    case False{}: glyphrrlrlrrr(code)

def glyphrrlrlrr(+code: U32) -> Glyph:
  glyphrrlrlrr.choose(code,U32.is_lt(code,235))

def glyphrrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlrlrl(code)
    case False{}: glyphrrlrlrr(code)

def glyphrrlrlr(+code: U32) -> Glyph:
  glyphrrlrlr.choose(code,U32.is_lt(code,234))

def glyphrrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlrll(code)
    case False{}: glyphrrlrlr(code)

def glyphrrlrl(+code: U32) -> Glyph:
  glyphrrlrl.choose(code,U32.is_lt(code,233))

def glyphrrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,50944,569344,0,851872,815632,806912,806912},Half{806912,806912,36532768,1073741776,0,0,0,0}}
    case False{}: missing()

def glyphrrlrrll(code: U32) -> Glyph:
  glyphrrlrrll.choose(U32.is_eq(code,236))

def glyphrrlrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,10027008,1921024,0,851872,815632,806912,806912},Half{806912,806912,36532768,1073741776,0,0,0,0}}
    case False{}: missing()

def glyphrrlrrlrl(code: U32) -> Glyph:
  glyphrrlrrlrl.choose(U32.is_eq(code,237))

def glyphrrlrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,3068160,47549440,0,851872,815632,806912,806912},Half{806912,806912,36532768,1073741776,0,0,0,0}}
    case False{}: missing()

def glyphrrlrrlrr(code: U32) -> Glyph:
  glyphrrlrrlrr.choose(U32.is_eq(code,238))

def glyphrrlrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlrrlrl(code)
    case False{}: glyphrrlrrlrr(code)

def glyphrrlrrlr(+code: U32) -> Glyph:
  glyphrrlrrlr.choose(code,U32.is_lt(code,238))

def glyphrrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlrrll(code)
    case False{}: glyphrrlrrlr(code)

def glyphrrlrrl(+code: U32) -> Glyph:
  glyphrrlrrl.choose(code,U32.is_lt(code,237))

def glyphrrlrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,45169408,65166608,0,851872,815632,806912,806912},Half{806912,806912,36532768,1073741776,0,0,0,0}}
    case False{}: missing()

def glyphrrlrrrll(code: U32) -> Glyph:
  glyphrrlrrrll.choose(U32.is_eq(code,239))

def glyphrrlrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,12961792,5109248,3042160,12058640,82570016,181681328},Half{224396273,207619057,131349424,9366032,0,0,0,0}}
    case False{}: missing()

def glyphrrlrrrlr(code: U32) -> Glyph:
  glyphrrlrrrlr.choose(U32.is_eq(code,240))

def glyphrrlrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlrrrll(code)
    case False{}: glyphrrlrrrlr(code)

def glyphrrlrrrl(+code: U32) -> Glyph:
  glyphrrlrrrl.choose(code,U32.is_lt(code,240))

def glyphrrlrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,12765952,11287056,0,10405824,115621056,160434112,159385024},Half{159385024,159385024,159385024,159385024,0,0,0,0}}
    case False{}: missing()

def glyphrrlrrrrl(code: U32) -> Glyph:
  glyphrrlrrrrl.choose(U32.is_eq(code,241))

def glyphrrlrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,43520,381184,0,8251664,98843776,159385024,191890656},Half{191890656,159385024,98843776,8251664,0,0,0,0}}
    case False{}: missing()

def glyphrrlrrrrr(code: U32) -> Glyph:
  glyphrrlrrrrr.choose(U32.is_eq(code,242))

def glyphrrlrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlrrrrl(code)
    case False{}: glyphrrlrrrrr(code)

def glyphrrlrrrr(+code: U32) -> Glyph:
  glyphrrlrrrr.choose(code,U32.is_lt(code,242))

def glyphrrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlrrrl(code)
    case False{}: glyphrrlrrrr(code)

def glyphrrlrrr(+code: U32) -> Glyph:
  glyphrrlrrr.choose(code,U32.is_lt(code,241))

def glyphrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlrrl(code)
    case False{}: glyphrrlrrr(code)

def glyphrrlrr(+code: U32) -> Glyph:
  glyphrrlrr.choose(code,U32.is_lt(code,239))

def glyphrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrlrl(code)
    case False{}: glyphrrlrr(code)

def glyphrrlr(+code: U32) -> Glyph:
  glyphrrlr.choose(code,U32.is_lt(code,236))

def glyphrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrll(code)
    case False{}: glyphrrlr(code)

def glyphrrl(+code: U32) -> Glyph:
  glyphrrl.choose(code,U32.is_lt(code,230))

def glyphrrrllll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,7077888,753664,0,8251664,98843776,159385024,191890656},Half{191890656,159385024,98843776,8251664,0,0,0,0}}
    case False{}: missing()

def glyphrrrllll(code: U32) -> Glyph:
  glyphrrrllll.choose(U32.is_eq(code,243))

def glyphrrrlllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,1893120,12082464,0,8251664,98843776,159385024,191890656},Half{191890656,159385024,98843776,8251664,0,0,0,0}}
    case False{}: missing()

def glyphrrrlllrl(code: U32) -> Glyph:
  glyphrrrlllrl.choose(U32.is_eq(code,244))

def glyphrrrlllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,12761856,10238496,0,8251664,98843776,159385024,191890656},Half{191890656,159385024,98843776,8251664,0,0,0,0}}
    case False{}: missing()

def glyphrrrlllrr(code: U32) -> Glyph:
  glyphrrrlllrr.choose(U32.is_eq(code,245))

def glyphrrrlllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrlllrl(code)
    case False{}: glyphrrrlllrr(code)

def glyphrrrlllr(+code: U32) -> Glyph:
  glyphrrrlllr.choose(code,U32.is_lt(code,245))

def glyphrrrlll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrllll(code)
    case False{}: glyphrrrlllr(code)

def glyphrrrlll(+code: U32) -> Glyph:
  glyphrrrlll.choose(code,U32.is_lt(code,244))

def glyphrrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,11737888,30748208,0,8251664,98843776,159385024,191890656},Half{191890656,159385024,98843776,8251664,0,0,0,0}}
    case False{}: missing()

def glyphrrrllrl(code: U32) -> Glyph:
  glyphrrrllrl.choose(U32.is_eq(code,246))

def glyphrrrllrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,774400,909568,69632,134217632,19014176},Half{69632,909568,774400,0,0,0,0,0}}
    case False{}: missing()

def glyphrrrllrrl(code: U32) -> Glyph:
  glyphrrrllrrl.choose(U32.is_eq(code,247))

def glyphrrrllrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,385875968,197060880,116800640,165348800,175928528},Half{175302608,159416256,98844304,8317665,83,0,0,0}}
    case False{}: missing()

def glyphrrrllrrr(code: U32) -> Glyph:
  glyphrrrllrrr.choose(U32.is_eq(code,248))

def glyphrrrllrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrllrrl(code)
    case False{}: glyphrrrllrrr(code)

def glyphrrrllrr(+code: U32) -> Glyph:
  glyphrrrllrr.choose(code,U32.is_lt(code,248))

def glyphrrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrllrl(code)
    case False{}: glyphrrrllrr(code)

def glyphrrrllr(+code: U32) -> Glyph:
  glyphrrrllr.choose(code,U32.is_lt(code,247))

def glyphrrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrlll(code)
    case False{}: glyphrrrllr(code)

def glyphrrrll(+code: U32) -> Glyph:
  glyphrrrll.choose(code,U32.is_lt(code,246))

def glyphrrrlrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,43520,381184,0,159385024,159385024,159385024,159385024},Half{159385024,143656624,82132336,8251648,0,0,0,0}}
    case False{}: missing()

def glyphrrrlrll(code: U32) -> Glyph:
  glyphrrrlrll.choose(U32.is_eq(code,249))

def glyphrrrlrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,7077888,753664,0,159385024,159385024,159385024,159385024},Half{159385024,143656624,82132336,8251648,0,0,0,0}}
    case False{}: missing()

def glyphrrrlrlrl(code: U32) -> Glyph:
  glyphrrrlrlrl.choose(U32.is_eq(code,250))

def glyphrrrlrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,1893120,12082464,0,159385024,159385024,159385024,159385024},Half{159385024,143656624,82132336,8251648,0,0,0,0}}
    case False{}: missing()

def glyphrrrlrlrr(code: U32) -> Glyph:
  glyphrrrlrlrr.choose(U32.is_eq(code,251))

def glyphrrrlrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrlrlrl(code)
    case False{}: glyphrrrlrlrr(code)

def glyphrrrlrlr(+code: U32) -> Glyph:
  glyphrrrlrlr.choose(code,U32.is_lt(code,251))

def glyphrrrlrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrlrll(code)
    case False{}: glyphrrrlrlr(code)

def glyphrrrlrl(+code: U32) -> Glyph:
  glyphrrrlrl.choose(code,U32.is_lt(code,250))

def glyphrrrlrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,11737888,30748208,0,159385024,159385024,159385024,159385024},Half{159385024,143656624,82132336,8251648,0,0,0,0}}
    case False{}: missing()

def glyphrrrlrrll(code: U32) -> Glyph:
  glyphrrrlrrll.choose(U32.is_eq(code,252))

def glyphrrrlrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,7077888,753664,0,239076082,160434112,80743536,14888736},Half{11041792,6075904,979200,700416,380928,127744,43008,0}}
    case False{}: missing()

def glyphrrrlrrlr(code: U32) -> Glyph:
  glyphrrrlrrlr.choose(U32.is_eq(code,253))

def glyphrrrlrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrlrrll(code)
    case False{}: glyphrrrlrrlr(code)

def glyphrrrlrrl(+code: U32) -> Glyph:
  glyphrrrlrrl.choose(code,U32.is_lt(code,253))

def glyphrrrlrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,1232,1232,10405840,98843600,143656400,159384784},Half{159384784,143656400,98843600,10409936,1232,1232,1232,0}}
    case False{}: missing()

def glyphrrrlrrrl(code: U32) -> Glyph:
  glyphrrrlrrrl.choose(U32.is_eq(code,254))

def glyphrrrlrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,11737888,30748208,0,239076082,160434112,80743536,14888736},Half{11041792,6075904,979200,700416,380928,127744,43008,0}}
    case False{}: missing()

def glyphrrrlrrrr(code: U32) -> Glyph:
  glyphrrrlrrrr.choose(U32.is_eq(code,255))

def glyphrrrlrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrlrrrl(code)
    case False{}: glyphrrrlrrrr(code)

def glyphrrrlrrr(+code: U32) -> Glyph:
  glyphrrrlrrr.choose(code,U32.is_lt(code,255))

def glyphrrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrlrrl(code)
    case False{}: glyphrrrlrrr(code)

def glyphrrrlrr(+code: U32) -> Glyph:
  glyphrrrlrr.choose(code,U32.is_lt(code,254))

def glyphrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrlrl(code)
    case False{}: glyphrrrlrr(code)

def glyphrrrlr(+code: U32) -> Glyph:
  glyphrrrlr.choose(code,U32.is_lt(code,252))

def glyphrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrll(code)
    case False{}: glyphrrrlr(code)

def glyphrrrl(+code: U32) -> Glyph:
  glyphrrrl.choose(code,U32.is_lt(code,249))

def glyphrrrrlll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,0,0,201326560},Half{35791392,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrrrrlll(code: U32) -> Glyph:
  glyphrrrrlll.choose(U32.is_eq(code,8211))

def glyphrrrrllrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,0,0,3489660927},Half{572662306,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrrrrllrl(code: U32) -> Glyph:
  glyphrrrrllrl.choose(U32.is_eq(code,8212))

def glyphrrrrllrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,757760,319744,62208,319744,0,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrrrrllrr(code: U32) -> Glyph:
  glyphrrrrllrr.choose(U32.is_eq(code,8216))

def glyphrrrrllr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrrllrl(code)
    case False{}: glyphrrrrllrr(code)

def glyphrrrrllr(+code: U32) -> Glyph:
  glyphrrrrllr.choose(code,U32.is_lt(code,8216))

def glyphrrrrll.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrrlll(code)
    case False{}: glyphrrrrllr(code)

def glyphrrrrll(+code: U32) -> Glyph:
  glyphrrrrll.choose(code,U32.is_lt(code,8212))

def glyphrrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,819200,995328,815104,446464,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrrrrlrl(code: U32) -> Glyph:
  glyphrrrrlrl.choose(U32.is_eq(code,8217))

def glyphrrrrlrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,66215424,12062048,8063632,12066128,0,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrrrrlrrl(code: U32) -> Glyph:
  glyphrrrrlrrl.choose(U32.is_eq(code,8220))

def glyphrrrrlrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,48385552,114330368,66215440,12062048,0},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrrrrlrrr(code: U32) -> Glyph:
  glyphrrrrlrrr.choose(U32.is_eq(code,8221))

def glyphrrrrlrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrrlrrl(code)
    case False{}: glyphrrrrlrrr(code)

def glyphrrrrlrr(+code: U32) -> Glyph:
  glyphrrrrlrr.choose(code,U32.is_lt(code,8221))

def glyphrrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrrlrl(code)
    case False{}: glyphrrrrlrr(code)

def glyphrrrrlr(+code: U32) -> Glyph:
  glyphrrrrlr.choose(code,U32.is_lt(code,8220))

def glyphrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrrll(code)
    case False{}: glyphrrrrlr(code)

def glyphrrrrl(+code: U32) -> Glyph:
  glyphrrrrl.choose(code,U32.is_lt(code,8217))

def glyphrrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,3007488,7338240,3007488},Half{0,0,0,0,0,0,0,0}}
    case False{}: missing()

def glyphrrrrrll(code: U32) -> Glyph:
  glyphrrrrrll.choose(U32.is_eq(code,8226))

def glyphrrrrrlrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,0,0,0,0},Half{0,170225841,256422387,203854034,0,0,0,0}}
    case False{}: missing()

def glyphrrrrrlrl(code: U32) -> Glyph:
  glyphrrrrrlrl.choose(U32.is_eq(code,8230))

def glyphrrrrrlrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,0,115968,15920,1489,2398023418},Half{304227811,11856,116736,4096,0,0,0,0}}
    case False{}: missing()

def glyphrrrrrlrr(code: U32) -> Glyph:
  glyphrrrrrlrr.choose(U32.is_eq(code,8592))

def glyphrrrrrlr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrrrlrl(code)
    case False{}: glyphrrrrrlrr(code)

def glyphrrrrrlr(+code: U32) -> Glyph:
  glyphrrrrrlr.choose(code,U32.is_lt(code,8592))

def glyphrrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrrrll(code)
    case False{}: glyphrrrrrlr(code)

def glyphrrrrrl(+code: U32) -> Glyph:
  glyphrrrrrl.choose(code,U32.is_lt(code,8230))

def glyphrrrrrrll.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,147456,5174784,99204480,1026986438,570855444,430080},Half{430080,430080,430080,430080,0,0,0,0}}
    case False{}: missing()

def glyphrrrrrrll(code: U32) -> Glyph:
  glyphrrrrrrll.choose(U32.is_eq(code,8593))

def glyphrrrrrrlr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,135168,6168576,48562176,494927872,2143009720},Half{479199232,30801920,3944448,0,0,0,0,0}}
    case False{}: missing()

def glyphrrrrrrlr(code: U32) -> Glyph:
  glyphrrrrrrlr.choose(U32.is_eq(code,8594))

def glyphrrrrrrl.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrrrrll(code)
    case False{}: glyphrrrrrrlr(code)

def glyphrrrrrrl(+code: U32) -> Glyph:
  glyphrrrrrrl.choose(code,U32.is_lt(code,8594))

def glyphrrrrrrrl.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,0,430080,430080,430080,430080,430080},Half{570855444,1026986438,99204480,5174784,147456,0,0,0}}
    case False{}: missing()

def glyphrrrrrrrl(code: U32) -> Glyph:
  glyphrrrrrrrl.choose(U32.is_eq(code,8595))

def glyphrrrrrrrr.choose(valid: Bool) -> Glyph:
  match valid:
    case True{}: Glyph{Half{0,0,69632,1958656,13630752,182058945,2142830586,3757608959},Half{1879048185,150835120,11533328,770560,0,0,0,0}}
    case False{}: missing()

def glyphrrrrrrrr(code: U32) -> Glyph:
  glyphrrrrrrrr.choose(U32.is_eq(code,65533))

def glyphrrrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrrrrrl(code)
    case False{}: glyphrrrrrrrr(code)

def glyphrrrrrrr(+code: U32) -> Glyph:
  glyphrrrrrrr.choose(code,U32.is_lt(code,65533))

def glyphrrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrrrrl(code)
    case False{}: glyphrrrrrrr(code)

def glyphrrrrrr(+code: U32) -> Glyph:
  glyphrrrrrr.choose(code,U32.is_lt(code,8595))

def glyphrrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrrrl(code)
    case False{}: glyphrrrrrr(code)

def glyphrrrrr(+code: U32) -> Glyph:
  glyphrrrrr.choose(code,U32.is_lt(code,8593))

def glyphrrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrrl(code)
    case False{}: glyphrrrrr(code)

def glyphrrrr(+code: U32) -> Glyph:
  glyphrrrr.choose(code,U32.is_lt(code,8226))

def glyphrrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrrl(code)
    case False{}: glyphrrrr(code)

def glyphrrr(+code: U32) -> Glyph:
  glyphrrr.choose(code,U32.is_lt(code,8211))

def glyphrr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrrl(code)
    case False{}: glyphrrr(code)

def glyphrr(+code: U32) -> Glyph:
  glyphrr.choose(code,U32.is_lt(code,243))

def glyphr.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphrl(code)
    case False{}: glyphrr(code)

def glyphr(+code: U32) -> Glyph:
  glyphr.choose(code,U32.is_lt(code,218))

def glyph.choose(code: U32,left: Bool) -> Glyph:
  match left:
    case True{}: glyphl(code)
    case False{}: glyphr(code)

def glyph(+code: U32) -> Glyph:
  glyph.choose(code,U32.is_lt(code,167))


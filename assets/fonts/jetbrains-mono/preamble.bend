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


# Juice Bend 5x7 glyphs. Hand-authored project asset; no system font copied.
# Unsupported Unicode is rendered as an outlined box, but text stays intact.
import Base

type Glyph is Data:
  Glyph{top: U32, bottom: U32}

def glyph(code: U32) -> Glyph:
  match code:
    case 32:
      Glyph{0, 0}
    case 33:
      Glyph{135300, 4100}
    case 34:
      Glyph{10570, 0}
    case 35:
      Glyph{359754, 10591}
    case 36:
      Glyph{479716, 5061}
    case 37:
      Glyph{267097, 214}
    case 38:
      Glyph{283212, 13909}
    case 39:
      Glyph{8324, 0}
    case 40:
      Glyph{270466, 2184}
    case 41:
      Glyph{67720, 8322}
    case 42:
      Glyph{1030816, 686}
    case 43:
      Glyph{1020032, 132}
    case 44:
      Glyph{0, 8320}
    case 45:
      Glyph{1015808, 0}
    case 46:
      Glyph{0, 4096}
    case 47:
      Glyph{133185, 16648}
    case 48:
      Glyph{708142, 14905}
    case 49:
      Glyph{135556, 14468}
    case 50:
      Glyph{67118, 32004}
    case 51:
      Glyph{459838, 30753}
    case 52:
      Glyph{600258, 2143}
    case 53:
      Glyph{999967, 30753}
    case 54:
      Glyph{999950, 14897}
    case 55:
      Glyph{133183, 8456}
    case 56:
      Glyph{476718, 14897}
    case 57:
      Glyph{509486, 14369}
    case 58:
      Glyph{128, 4}
    case 59:
      Glyph{128, 8324}
    case 60:
      Glyph{532610, 2184}
    case 61:
      Glyph{31744, 31}
    case 62:
      Glyph{34952, 8322}
    case 63:
      Glyph{67118, 4100}
    case 64:
      Glyph{712238, 15895}
    case 65:
      Glyph{1033774, 17969}
    case 66:
      Glyph{1001022, 31281}
    case 67:
      Glyph{541199, 15888}
    case 68:
      Glyph{575038, 31281}
    case 69:
      Glyph{999967, 32272}
    case 70:
      Glyph{999967, 16912}
    case 71:
      Glyph{770575, 15921}
    case 72:
      Glyph{1033777, 17969}
    case 73:
      Glyph{135310, 14468}
    case 74:
      Glyph{33825, 14897}
    case 75:
      Glyph{807505, 18004}
    case 76:
      Glyph{541200, 32272}
    case 77:
      Glyph{710513, 17969}
    case 78:
      Glyph{714545, 18035}
    case 79:
      Glyph{575022, 14897}
    case 80:
      Glyph{1001022, 16912}
    case 81:
      Glyph{575022, 13909}
    case 82:
      Glyph{1001022, 18004}
    case 83:
      Glyph{475663, 30753}
    case 84:
      Glyph{135327, 4228}
    case 85:
      Glyph{575025, 14897}
    case 86:
      Glyph{575025, 4433}
    case 87:
      Glyph{706097, 18293}
    case 88:
      Glyph{141873, 17962}
    case 89:
      Glyph{141873, 4228}
    case 90:
      Glyph{133183, 32264}
    case 91:
      Glyph{270606, 14600}
    case 92:
      Glyph{139536, 1090}
    case 93:
      Glyph{67662, 14402}
    case 94:
      Glyph{17732, 0}
    case 95:
      Glyph{0, 31744}
    case 96:
      Glyph{2184, 0}
    case 97:
      Glyph{47104, 15919}
    case 98:
      Glyph{588304, 31281}
    case 99:
      Glyph{539648, 15888}
    case 100:
      Glyph{572449, 15921}
    case 101:
      Glyph{571392, 15903}
    case 102:
      Glyph{925990, 8456}
    case 103:
      Glyph{574944, 14383}
    case 104:
      Glyph{588304, 17969}
    case 105:
      Glyph{143364, 14468}
    case 106:
      Glyph{71682, 12866}
    case 107:
      Glyph{674320, 19096}
    case 108:
      Glyph{135308, 14468}
    case 109:
      Glyph{714752, 22197}
    case 110:
      Glyph{587776, 17969}
    case 111:
      Glyph{571392, 14897}
    case 112:
      Glyph{575424, 16926}
    case 113:
      Glyph{574944, 1071}
    case 114:
      Glyph{809984, 16912}
    case 115:
      Glyph{539648, 30766}
    case 116:
      Glyph{291080, 6440}
    case 117:
      Glyph{574464, 13937}
    case 118:
      Glyph{574464, 4433}
    case 119:
      Glyph{574464, 10933}
    case 120:
      Glyph{345088, 17732}
    case 121:
      Glyph{575008, 14383}
    case 122:
      Glyph{97280, 32004}
    case 123:
      Glyph{266370, 2180}
    case 124:
      Glyph{135300, 4228}
    case 125:
      Glyph{69768, 8324}
    case 126:
      Glyph{730112, 0}
    case _:
      Glyph{574015, 32305}

def row.choose(bits: Glyph, +y: U32, first: Bool) -> U32:
  Glyph{a, b} = bits
  match first:
    case True{}:
      U32.and(U32.shrn(a, U32.to_nat(U32.mul(y, 5))), 31)
    case False{}:
      U32.and(U32.shrn(b, U32.to_nat(U32.mul(U32.sub(y, 4), 5))), 31)

def row(bits: Glyph, +y: U32) -> U32:
  row.choose(bits, y, U32.is_lt(y, 4))

def pixel.choose(bits: Glyph, x: U32, y: U32, inside: Bool) -> Bool:
  match inside:
    case True{}:
      U32.is_ne(U32.and(U32.shrn(row(bits, y), U32.to_nat(U32.sub(5, x))), 1), 0)
    case False{}:
      False{}

def pixel(bits: Glyph, +x: U32, +y: U32) -> Bool:
  pixel.choose(bits, x, y, (x > 0 && x < 6 && y < 7 : U32))

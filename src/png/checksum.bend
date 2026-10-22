import Base

# PNG CRC32, reflected polynomial 0xedb88320, and RFC1950 Adler32. The
# enclosing decoder admits octets before these pure arithmetic helpers.
def crc_bits(fuel: Nat,+value: U32) -> U32:
  match fuel:
    case 0n: value
    case 1n+rest:
      crc_bits(rest,U32.xor(U32.shr(value),Bool.pick(U32,U32.is_eq(U32.and(value,1),1),3988292384,0)))

def crc_step(bytes: List<&2,U32>,value: U32) -> U32:
  match bytes:
    case []: value
    case byte <> rest: crc_step(rest,crc_bits(8n,U32.xor(value,byte)))

def crc(bytes: List<&2,U32>) -> U32:
  U32.xor(crc_step(bytes,4294967295),4294967295)

def adler_step(bytes: List<&2,U32>,one: U32,two: U32) -> U32:
  match bytes:
    case []: U32.or(U32.shln(two,16n),one)
    case byte <> rest:
      +next : U32 = U32.mod(U32.add(one,byte),65521)
      adler_step(rest,next,U32.mod(U32.add(two,next),65521))

def adler(bytes: List<&2,U32>) -> U32:
  adler_step(bytes,1,0)

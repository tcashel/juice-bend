import Base
import ./attachment_refs.bend as Ref
import ./domain.bend as Domain

# Raw octets remain separate from human-readable attachment inventory metadata.
type Bytes is Data:
  Bytes{bytes: List<&2,U32>,count: U32,digest: String}

def finish(+bytes: List<&2,U32>,+expected: U32) -> Result<&2,&2,String,Bytes>:
  Bool.pick(Result<&2,&2,String,Bytes>,Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(expected)),
    Done{Bytes{bytes,expected,Domain.digest(bytes)}},Fail{"decoded_length_mismatch"})

# Called only after canonical alphabet, length, final padding and pad bits pass.
# Bytes accumulate in reverse order; no UTF8 conversion is involved.
def emit(+a: U32,+b: U32,+c: U32,d: U32,c_pad: Bool,d_pad: Bool,+acc: List<&2,U32>) -> List<&2,U32>:
  +first = U32.or(U32.shln(a,2n),U32.shrn(b,4n))
  +second = U32.or(U32.shln(U32.and(b,15),4n),U32.shrn(c,2n))
  +third = U32.or(U32.shln(U32.and(c,3),6n),d)
  Bool.pick(List<&2,U32>,c_pad,first <> acc,
    Bool.pick(List<&2,U32>,d_pad,second <> first <> acc,third <> second <> first <> acc))

def octets(text: String,acc: List<&2,U32>) -> List<&2,U32>:
  match text:
    case SCon{Chr{a},SCon{Chr{b},SCon{Chr{+c},SCon{Chr{+d},rest}}}}:
      octets(rest,emit(Ref.sextet(a),Ref.sextet(b),Ref.sextet(c),Ref.sextet(d),
        U32.is_eq(c,61),U32.is_eq(d,61),acc))
    case _: List.reverse(&2,U32,acc)

def checked(check: Ref.InlineCheck,text: String) -> Result<&2,&2,String,Bytes>:
  match check:
    case Ref.InvalidBase64{reason}: Fail{reason}
    case Ref.ValidBase64{_,count}: finish(octets(text,[]),count)

# Canonical standard base64 only, at most 1MiB encoded / 786432 decoded bytes.
# The retained-record resolver imposes its narrower 256KiB raw admission first.
def decode(+text: String) -> Result<&2,&2,String,Bytes>:
  checked(Ref.base64(text),text)

def octet_range(bytes: List<&2,U32>) -> Bool:
  match bytes:
    case []: True{}
    case byte <> rest: U32.is_le(byte,255) && octet_range(rest)

def valid(value: Bytes) -> Bool:
  Bytes{+bytes,+count,digest} = value
  U32.is_le(count,786432) && Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(count)) &&
    octet_range(bytes) && String.eq(Domain.digest(bytes),digest)

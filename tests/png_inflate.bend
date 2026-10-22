import Base
import ../src/attachment_image_types.bend as T
import ../src/png/inflate.bend as Inflate
import ../src/png/inflate_huffman.bend as H
import ../src/png/inflate_tables.bend as Tables

# Independent synthetic constants: manually packed RFC1950/1951 streams,
# cross-checked with system zlib 1.2.13. The maintained checks and fixture
# composition below are Bend; no external compressor or decoder is used.
# Recipes are alongside each constant. Expected output is independent of Inflate.

def bytes_equal(left: List<&2,U32>,right: List<&2,U32>) -> Bool:
  match left right:
    case Nil{} Nil{}: True{}
    case Con{a,tail} Con{b,rest}: U32.is_eq(a,b) && bytes_equal(tail,rest)
    case _ _: False{}

def check(label: String,valid: Bool) -> IO(Unit):
  match valid:
    case True{}: IO.print(String.append("PASS ",label))
    case False{}:
      do IO<Unit>:
        IO.print(String.append("FAIL ",label))
        IO.die(Unit,1,"PNG inflater assertion failed")

def accepted(result: Result<&2,&2,T.Failure,List<&2,U32>>,expected: List<&2,U32>) -> Bool:
  match result:
    case Done{actual}: bytes_equal(actual,expected)
    case Fail{_}: False{}

def rejected(result: Result<&2,&2,T.Failure,List<&2,U32>>) -> Bool:
  match result:
    case Done{_}: False{}
    case Fail{_}: True{}

def rejected_kind(result: Result<&2,&2,T.Failure,List<&2,U32>>,kind: String) -> Bool:
  match result:
    case Done{_}: False{}
    case Fail{T.Failure{actual,_}}: String.eq(T.label(actual),kind)

# BFINAL=1 BTYPE=00; LEN=256 NLEN=65279; literal octets 0 through 255; Adler32 of those octets.
def stored_all_256_octets() -> List<&2,U32>:
  [120,1,1,0,1,255,254,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255,173,246,127,129]

# BFINAL=1 BTYPE=01; canonical fixed codes for literals 0..255 then EOB256.
def fixed_all_256_octets() -> List<&2,U32>:
  [120,1,99,96,100,98,102,97,101,99,231,224,228,226,230,225,229,227,23,16,20,18,22,17,21,19,151,144,148,146,150,145,149,147,87,80,84,82,86,81,85,83,215,208,212,210,214,209,213,211,55,48,52,50,54,49,53,51,183,176,180,178,182,177,181,179,119,112,116,114,118,113,117,115,247,240,244,242,246,241,245,243,15,8,12,10,14,9,13,11,143,136,140,138,142,137,141,139,79,72,76,74,78,73,77,75,207,200,204,202,206,201,205,203,47,40,44,42,46,41,45,43,175,168,172,170,174,169,173,171,111,104,108,106,110,105,109,107,239,232,236,234,238,233,237,235,159,48,113,210,228,41,83,167,77,159,49,115,214,236,57,115,231,205,95,176,112,209,226,37,75,151,45,95,177,114,213,234,53,107,215,173,223,176,113,211,230,45,91,183,109,223,177,115,215,238,61,123,247,237,63,112,240,208,225,35,71,143,29,63,113,242,212,233,51,103,207,157,191,112,241,210,229,43,87,175,93,191,113,243,214,237,59,119,239,221,127,240,240,209,227,39,79,159,61,127,241,242,213,235,55,111,223,189,255,240,241,211,231,47,95,191,125,255,241,243,215,239,63,127,255,253,7,0,173,246,127,129]

# Nonfinal stored A; final fixed length257=3, distance0=1, EOB; expected four A octets.
def stored_then_fixed_history_overlap() -> List<&2,U32>:
  [120,1,0,1,0,254,255,65,3,2,0,2,142,1,5]

# Fixed literal65; length symbol285 (258); distance symbol0 (1); EOB256.
def fixed_overlap_258() -> List<&2,U32>:
  [120,1,115,28,5,0,103,248,65,196]

# HLIT=257 HDIST=1; repeat18 138 zeros, repeat18 118 zeros, length1 for EOB256, distance length0; emit EOB bit0.
def dynamic_eob_only_no_distance() -> List<&2,U32>:
  [120,1,5,224,219,146,36,73,146,44,203,254,255,95,35,0,0,0,0,1]

# LL65 and LL256 length1, all others0; D0 length0. Three literal65 codes, EOB.
def dynamic_literal_only_no_distance() -> List<&2,U32>:
  [120,1,5,224,219,146,36,73,146,44,203,126,27,254,255,79,33,32,1,137,0,196]

# LL65=1, LL256=2, LL257=2; D0=1. Literal65 then length3 distance1 then EOB.
def dynamic_one_bit_distance_overlap() -> List<&2,U32>:
  [120,1,13,224,219,146,36,73,146,44,203,126,27,254,255,79,17,161,5,2,142,1,5]

# HLIT257 HDIST4; repeat18 138 zeros, repeat18 108 zeros, repeat17 7 zeros =253; literal length2; repeat16 6 copies covers LL254..256 and D0..2; literal length2 for D3. Emit LL253,254,255,EOB256.
def dynamic_repeat_16_17_18_cross_boundary() -> List<&2,U32>:
  [120,1,5,227,219,146,36,73,146,44,203,254,255,15,63,210,157,176,1,5,245,2,251]

# stored_all_256_octets with first NLEN byte XOR1.
def stored_bad_len_nlen() -> List<&2,U32>:
  [120,1,1,0,1,254,254,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255,173,246,127,129]

# Fixed tree; emit symbol286 then EOB256.
def fixed_reserved_literal_286() -> List<&2,U32>:
  [120,1,27,3,0,0,0,0,1]

# Fixed A, length3, reserved distance30, EOB.
def fixed_reserved_distance_30() -> List<&2,U32>:
  [120,1,115,4,62,0,2,142,1,5]

# Fixed length3 distance1 without any prior literal; EOB.
def fixed_prehistory_distance() -> List<&2,U32>:
  [120,1,3,2,0,1,137,0,196]

# CMF=0x08 with correct FCHECK; fixed literals 0..255,0; length3, distance symbol16 plus seven zero extra bits=257; EOB.
def declared_window_256_distance_257() -> List<&2,U32>:
  [8,29,99,96,100,98,102,97,101,99,231,224,228,226,230,225,229,227,23,16,20,18,22,17,21,19,151,144,148,146,150,145,149,147,87,80,84,82,86,81,85,83,215,208,212,210,214,209,213,211,55,48,52,50,54,49,53,51,183,176,180,178,182,177,181,179,119,112,116,114,118,113,117,115,247,240,244,242,246,241,245,243,15,8,12,10,14,9,13,11,143,136,140,138,142,137,141,139,79,72,76,74,78,73,77,75,207,200,204,202,206,201,205,203,47,40,44,42,46,41,45,43,175,168,172,170,174,169,173,171,111,104,108,106,110,105,109,107,239,232,236,234,238,233,237,235,159,48,113,210,228,41,83,167,77,159,49,115,214,236,57,115,231,205,95,176,112,209,226,37,75,151,45,95,177,114,213,234,53,107,215,173,223,176,113,211,230,45,91,183,109,223,177,115,215,238,61,123,247,237,63,112,240,208,225,35,71,143,29,63,113,242,212,233,51,103,207,157,191,112,241,210,229,43,87,175,93,191,113,243,214,237,59,119,239,221,127,240,240,209,227,39,79,159,61,127,241,242,213,235,55,111,223,189,255,240,241,211,231,47,95,191,125,255,241,243,215,239,63,127,255,253,103,0,6,0,0,172,28,127,132]

# Same raw DEFLATE and Adler as preceding case; only CMF/FCHECK select512-byte window.
def declared_window_512_distance_257() -> List<&2,U32>:
  [24,25,99,96,100,98,102,97,101,99,231,224,228,226,230,225,229,227,23,16,20,18,22,17,21,19,151,144,148,146,150,145,149,147,87,80,84,82,86,81,85,83,215,208,212,210,214,209,213,211,55,48,52,50,54,49,53,51,183,176,180,178,182,177,181,179,119,112,116,114,118,113,117,115,247,240,244,242,246,241,245,243,15,8,12,10,14,9,13,11,143,136,140,138,142,137,141,139,79,72,76,74,78,73,77,75,207,200,204,202,206,201,205,203,47,40,44,42,46,41,45,43,175,168,172,170,174,169,173,171,111,104,108,106,110,105,109,107,239,232,236,234,238,233,237,235,159,48,113,210,228,41,83,167,77,159,49,115,214,236,57,115,231,205,95,176,112,209,226,37,75,151,45,95,177,114,213,234,53,107,215,173,223,176,113,211,230,45,91,183,109,223,177,115,215,238,61,123,247,237,63,112,240,208,225,35,71,143,29,63,113,242,212,233,51,103,207,157,191,112,241,210,229,43,87,175,93,191,113,243,214,237,59,119,239,221,127,240,240,209,227,39,79,159,61,127,241,242,213,235,55,111,223,189,255,240,241,211,231,47,95,191,125,255,241,243,215,239,63,127,255,253,103,0,6,0,0,172,28,127,132]

# Header for257 LL+1 D lengths; first encoded code-length symbol16 with extra0.
def dynamic_repeat16_without_previous() -> List<&2,U32>:
  [120,1,5,224,219,146,36,73,146,44,203,94,0,0,0,0,1]

# Two repeat18 tokens each138 zero lengths produce276 entries.
def dynamic_repeat18_overrun() -> List<&2,U32>:
  [120,1,5,224,219,146,36,73,146,44,203,254,255,255,3,0,0,0,1]

# 138+119 zeros=257 lengths followed by repeat17 three zeros, exceeding258.
def dynamic_repeat17_overrun() -> List<&2,U32>:
  [120,1,5,224,219,146,36,73,146,44,203,254,255,103,63,0,0,0,0,1]

# 256 zeros then length1 gives257 entries; repeat16 three copies exceeds258.
def dynamic_repeat16_overrun() -> List<&2,U32>:
  [120,1,5,224,219,146,36,73,146,44,203,254,255,95,227,5,0,0,0,1]

# CL0,CL1,CL18 each length1; all other code-length symbols absent; no payload needed.
def dynamic_code_length_oversubscribed() -> List<&2,U32>:
  [120,1,5,224,129,4,0,0,0,0,16,0,0,0,0,1]

# Only CL0 has length1; all other code-length symbols absent.
def dynamic_code_length_incomplete() -> List<&2,U32>:
  [120,1,5,224,1,4,0,0,0,0,0,0,0,0,0,1]

# LL0,LL1,LL256 length1; D0 length0; every length encoded literally by complete CL tree.
def dynamic_literal_tree_oversubscribed() -> List<&2,U32>:
  [120,1,5,224,219,146,36,73,146,44,203,34,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,32,0,0,0,0,1]

# LL65,LL256 length2; others0; D0 length0.
def dynamic_literal_tree_incomplete() -> List<&2,U32>:
  [120,1,5,224,219,146,36,73,146,44,203,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,16,0,0,0,0,1]

# Complete two-one-bit tree on literals65,66 but LL256 length0.
def dynamic_missing_eob() -> List<&2,U32>:
  [120,1,5,224,219,146,36,73,146,44,203,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,34,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1]

# Valid complete LL65/256/257 tree; distance0,1,2 each length1.
def dynamic_distance_tree_oversubscribed() -> List<&2,U32>:
  [120,1,13,226,219,146,36,73,146,44,203,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,16,33,34,0,0,0,1]

# Valid complete LL65/256/257 tree; only D0 with length2.
def dynamic_distance_tree_incomplete() -> List<&2,U32>:
  [120,1,13,224,219,146,36,73,146,44,203,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,16,17,0,0,0,1]

# Valid LL65/256/257 tree; D0 length0; literal65 then length257=3.
def dynamic_absent_distance_used() -> List<&2,U32>:
  [120,1,13,224,219,146,36,73,146,44,203,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,16,129,1,2,142,1,5]

# BFINAL1 BTYPE2 HLIT31 HDIST0 HCLEN0, then zero byte alignment.
def dynamic_reserved_hlit_count() -> List<&2,U32>:
  [120,1,253,0,0,0,0,0,1]

# BFINAL1 BTYPE3, padded with zero bits.
def reserved_block_type() -> List<&2,U32>:
  [120,1,7,0,0,0,1]

# Fixed literal65 followed by EOB256.
def fixed_one_literal() -> List<&2,U32>:
  [120,1,115,4,0,0,66,0,66]

# fixed_one_literal with last Adler octet XOR1.
def wrong_adler32() -> List<&2,U32>:
  [120,1,115,4,0,0,66,0,67]

# fixed_one_literal followed by one zero octet.
def trailing_octet() -> List<&2,U32>:
  [120,1,115,4,0,0,66,0,66,0]

# fixed_one_literal concatenated with itself; first stream output A, unused second stream.
def trailing_second_zlib_stream() -> List<&2,U32>:
  [120,1,115,4,0,0,66,0,66,120,1,115,4,0,0,66,0,66]

# fixed_one_literal with final Adler octet removed.
def truncated_adler32() -> List<&2,U32>:
  [120,1,115,4,0,0,66,0]

# First three octets of fixed_one_literal only; wrapper header plus first DEFLATE octet.
def truncated_deflate_eob() -> List<&2,U32>:
  [120,1,115]

# fixed_one_literal with FLG bit0 flipped.
def invalid_fcheck() -> List<&2,U32>:
  [120,0,115,4,0,0,66,0,66]

# CMF0x77 with valid FCHECK then fixed_one_literal raw/trailer.
def unsupported_compression_method() -> List<&2,U32>:
  [119,9,115,4,0,0,66,0,66]

# CMF0x88 with valid FCHECK then fixed_one_literal raw/trailer.
def invalid_cinfo8() -> List<&2,U32>:
  [136,28,115,4,0,0,66,0,66]

# FDICT flag set, correct FCHECK, DICTID00000001, then fixed A stream.
def preset_dictionary() -> List<&2,U32>:
  [120,32,0,0,0,1,115,4,0,0,66,0,66]

# Identical to fixed_one_literal, but caller expected_count=2.
def expected_output_underflow() -> List<&2,U32>:
  [120,1,115,4,0,0,66,0,66]

# Identical to fixed_one_literal, but caller expected_count=0.
def expected_output_overflow() -> List<&2,U32>:
  [120,1,115,4,0,0,66,0,66]

# Literal empty stored-block framing is independent of the implementation.
# The last block is final, followed by Adler32(empty)=1.
def empty_blocks(fuel: Nat) -> List<&2,U32>:
  match fuel:
    case 0n: [1,0,0,255,255,0,0,0,1]
    case 1n+rest: List.append(&2,U32,[0,0,0,255,255],empty_blocks(rest))

def zeroes(count: Nat,tail: List<&2,U32>) -> List<&2,U32>:
  match count:
    case 0n: tail
    case 1n+rest: zeroes(rest,Con{0,tail})

def prefixes(fuel: Nat,+full: List<&2,U32>,+count: U32) -> Bool:
  match fuel:
    case 0n: True{}
    case 1n+rest:
      rejected(Inflate.decode(List.take(&2,U32,full,U32.to_nat(count)),1)) && prefixes(rest,full,U32.inc(count))

# CINFO0 with correct FCHECK; fixed literals0..255,0 (257 bytes, next window position1); length3, distance symbol15 plus extra63=256; EOB. Exact suffix is1,2,3.
def declared_window_256_valid_wrapped_distance_256() -> List<&2,U32>:
  [8,29,99,96,100,98,102,97,101,99,231,224,228,226,230,225,229,227,23,16,20,18,22,17,21,19,151,144,148,146,150,145,149,147,87,80,84,82,86,81,85,83,215,208,212,210,214,209,213,211,55,48,52,50,54,49,53,51,183,176,180,178,182,177,181,179,119,112,116,114,118,113,117,115,247,240,244,242,246,241,245,243,15,8,12,10,14,9,13,11,143,136,140,138,142,137,141,139,79,72,76,74,78,73,77,75,207,200,204,202,206,201,205,203,47,40,44,42,46,41,45,43,175,168,172,170,174,169,173,171,111,104,108,106,110,105,109,107,239,232,236,234,238,233,237,235,159,48,113,210,228,41,83,167,77,159,49,115,214,236,57,115,231,205,95,176,112,209,226,37,75,151,45,95,177,114,213,234,53,107,215,173,223,176,113,211,230,45,91,183,109,223,177,115,215,238,61,123,247,237,63,112,240,208,225,35,71,143,29,63,113,242,212,233,51,103,207,157,191,112,241,210,229,43,87,175,93,191,113,243,214,237,59,119,239,221,127,240,240,209,227,39,79,159,61,127,241,242,213,235,55,111,223,189,255,240,241,211,231,47,95,191,125,255,241,243,215,239,63,127,255,253,103,0,250,31,0,172,34,127,135]

def main() -> IO(Unit):
  do IO<Unit>:
    check("stored_all_256_octets",accepted(Inflate.decode(stored_all_256_octets(),256),[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255]))
    check("fixed_all_256_octets",accepted(Inflate.decode(fixed_all_256_octets(),256),[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255]))
    check("stored_then_fixed_history_overlap",accepted(Inflate.decode(stored_then_fixed_history_overlap(),4),[65,65,65,65]))
    check("fixed_overlap_258",accepted(Inflate.decode(fixed_overlap_258(),259),[65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65]))
    check("dynamic_eob_only_no_distance",accepted(Inflate.decode(dynamic_eob_only_no_distance(),0),[]))
    check("dynamic_literal_only_no_distance",accepted(Inflate.decode(dynamic_literal_only_no_distance(),3),[65,65,65]))
    check("dynamic_one_bit_distance_overlap",accepted(Inflate.decode(dynamic_one_bit_distance_overlap(),4),[65,65,65,65]))
    check("dynamic_repeat_16_17_18_cross_boundary",accepted(Inflate.decode(dynamic_repeat_16_17_18_cross_boundary(),3),[253,254,255]))
    check("stored_bad_len_nlen",rejected_kind(Inflate.decode(stored_bad_len_nlen(),256),"invalid_png_compressed_data"))
    check("fixed_reserved_literal_286",rejected_kind(Inflate.decode(fixed_reserved_literal_286(),0),"invalid_png_compressed_data"))
    check("fixed_reserved_distance_30",rejected_kind(Inflate.decode(fixed_reserved_distance_30(),4),"invalid_png_compressed_data"))
    check("fixed_prehistory_distance",rejected_kind(Inflate.decode(fixed_prehistory_distance(),3),"invalid_png_compressed_data"))
    check("declared_window_256_distance_257",rejected_kind(Inflate.decode(declared_window_256_distance_257(),260),"invalid_png_compressed_data"))
    check("declared_window_512_distance_257",accepted(Inflate.decode(declared_window_512_distance_257(),260),[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255,0,0,1,2]))
    check("dynamic_repeat16_without_previous",rejected_kind(Inflate.decode(dynamic_repeat16_without_previous(),0),"invalid_png_compressed_data"))
    check("dynamic_repeat18_overrun",rejected_kind(Inflate.decode(dynamic_repeat18_overrun(),0),"invalid_png_compressed_data"))
    check("dynamic_repeat17_overrun",rejected_kind(Inflate.decode(dynamic_repeat17_overrun(),0),"invalid_png_compressed_data"))
    check("dynamic_repeat16_overrun",rejected_kind(Inflate.decode(dynamic_repeat16_overrun(),0),"invalid_png_compressed_data"))
    check("dynamic_code_length_oversubscribed",rejected_kind(Inflate.decode(dynamic_code_length_oversubscribed(),0),"invalid_png_compressed_data"))
    check("dynamic_code_length_incomplete",rejected_kind(Inflate.decode(dynamic_code_length_incomplete(),0),"invalid_png_compressed_data"))
    check("dynamic_literal_tree_oversubscribed",rejected_kind(Inflate.decode(dynamic_literal_tree_oversubscribed(),0),"invalid_png_compressed_data"))
    check("dynamic_literal_tree_incomplete",rejected_kind(Inflate.decode(dynamic_literal_tree_incomplete(),0),"invalid_png_compressed_data"))
    check("dynamic_missing_eob",rejected_kind(Inflate.decode(dynamic_missing_eob(),0),"invalid_png_compressed_data"))
    check("dynamic_distance_tree_oversubscribed",rejected_kind(Inflate.decode(dynamic_distance_tree_oversubscribed(),0),"invalid_png_compressed_data"))
    check("dynamic_distance_tree_incomplete",rejected_kind(Inflate.decode(dynamic_distance_tree_incomplete(),0),"invalid_png_compressed_data"))
    check("dynamic_absent_distance_used",rejected_kind(Inflate.decode(dynamic_absent_distance_used(),4),"invalid_png_compressed_data"))
    check("dynamic_reserved_hlit_count",rejected_kind(Inflate.decode(dynamic_reserved_hlit_count(),0),"invalid_png_compressed_data"))
    check("reserved_block_type",rejected_kind(Inflate.decode(reserved_block_type(),0),"invalid_png_compressed_data"))
    check("fixed_one_literal",accepted(Inflate.decode(fixed_one_literal(),1),[65]))
    check("wrong_adler32",rejected_kind(Inflate.decode(wrong_adler32(),1),"invalid_png_compressed_data"))
    check("trailing_octet",rejected_kind(Inflate.decode(trailing_octet(),1),"invalid_png_compressed_data"))
    check("trailing_second_zlib_stream",rejected_kind(Inflate.decode(trailing_second_zlib_stream(),1),"invalid_png_compressed_data"))
    check("truncated_adler32",rejected_kind(Inflate.decode(truncated_adler32(),1),"invalid_png_compressed_data"))
    check("truncated_deflate_eob",rejected_kind(Inflate.decode(truncated_deflate_eob(),1),"invalid_png_compressed_data"))
    check("invalid_fcheck",rejected_kind(Inflate.decode(invalid_fcheck(),1),"invalid_png_compressed_data"))
    check("unsupported_compression_method",rejected_kind(Inflate.decode(unsupported_compression_method(),1),"invalid_png_compressed_data"))
    check("invalid_cinfo8",rejected_kind(Inflate.decode(invalid_cinfo8(),1),"invalid_png_compressed_data"))
    check("preset_dictionary",rejected_kind(Inflate.decode(preset_dictionary(),1),"invalid_png_compressed_data"))
    check("expected_output_underflow",rejected_kind(Inflate.decode(expected_output_underflow(),2),"invalid_png_compressed_data"))
    check("expected_output_overflow",rejected_kind(Inflate.decode(expected_output_overflow(),0),"invalid_png_compressed_data"))
    check("every fixed stream truncation fails",prefixes(9n,fixed_one_literal(),0))
    check("non-octet rejected before parsing",rejected_kind(Inflate.decode([120,1,256],0),"invalid_input"))
    check("output admission cap",rejected_kind(Inflate.decode([],4196353),"image_resource_limit"))
    check("input admission cap",rejected_kind(Inflate.decode(zeroes(1048577n,Nil{}),0),"image_resource_limit"))
    check("4096 empty stored blocks accepted",accepted(Inflate.decode(Con{120,Con{1,empty_blocks(4095n)}},0),Nil{}))
    check("4097 empty stored blocks refused",rejected_kind(Inflate.decode(Con{120,Con{1,empty_blocks(4096n)}},0),"image_resource_limit"))
    check("declared_window_256_valid_wrapped_distance_256",accepted(Inflate.decode(declared_window_256_valid_wrapped_distance_256(),260),[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255,0,1,2,3]))
    IO.print("PNG zlib/DEFLATE tests passed")

import Base
import ./bits_tests.bend as Bits
import ./fse_tests.bend as FSE
import ./huffman_tests.bend as Huffman

def main() -> IO(Unit):
  do IO<Unit>:
    Bits.main()
    FSE.main()
    Huffman.main()

import Base
import ./zstd/entropy_tests.bend as Entropy
import ./zstd/decoder_tests.bend as Decoder

def main() -> IO(Unit):
  do IO<Unit>:
    Entropy.main()
    Decoder.main()
    IO.print("Staged portable Zstandard suites passed")

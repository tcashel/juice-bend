import Base
import ./xxh64_tests.bend as Checksum
import ./output_tests.bend as Output
import ./block_tests.bend as Block
import ./frame_tests.bend as Frame
import ./multiblock_tests.bend as Multiblock

def main() -> IO(Unit):
  do IO<Unit>:
    Checksum.main()
    Output.main()
    Block.main()
    Frame.main()
    Multiblock.main()

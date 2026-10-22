import Base
import ../../src/zstd/frame.bend as Frame
import ./frame_tests.bend as FrameTests
import ./multiblock_vectors.bend as Vectors
import ./block_tests.bend as BlockTests
import ./bits_tests.bend as Test

# Expected bytes are independently rebuilt in Bend from the synthetic record
# grammar. The frozen frame manifest records externally verified block sizes,
# treeless Huffman and all three FSE repeat modes in blocks 2 and 4.
def main() -> IO(Unit):
  do IO<Unit>:
    FrameTests.run(Vectors.records(),BlockTests.records(2000n,0),"five compressed blocks preserve Huffman/FSE tables and history")
    FrameTests.run(Vectors.records_check(),BlockTests.records(2000n,0),"checksum covers all five compressed blocks")
    FrameTests.run(Vectors.records_raw_bridge(),BlockTests.records(2000n,0),"raw block between compressed blocks preserves Huffman/FSE history")
    Test.require(FrameTests.failed(Frame.decode(Vectors.records(),Frame.Limits{1048576,1048576,8388608,32,4})),"multiple-block frame enforces configured block count")

import Base
import ../src/domain.bend as Domain

# Run the native executable with one literal argument: 0. The seed comes from
# IO.args so the compiler cannot precompute the pure hash chains. Each digest
# feeds the next message. Expected corpus/final hashes were independently
# computed with Python hashlib.sha256; no alternative SHA implementation lives
# in this benchmark. Generation and corpus checks precede all timers.

def checked(ok: Bool,message: String) -> IO(Unit):
  match ok:
    case True{}: IO.pure(Unit,Unit{})
    case False{}: IO.die(Unit,1,message)

def corpus(fuel: Nat,+index: U32,+multiply: U32,+add: U32,+modulus: U32,
  +base: U32,acc: List<&2,U32>) -> List<&2,U32>:
  match fuel:
    case 0n: List.reverse(&2,U32,acc)
    case 1n+rest:
      corpus(rest,U32.add(index,1),multiply,add,modulus,base,
        (U32.mod(U32.add(U32.mul(index,multiply),add),modulus) + base : U32) <> acc)

def byte_chain(fuel: Nat,+payload: List<&2,U32>,previous: String) -> String:
  match fuel:
    case 0n: previous
    case 1n+rest:
      byte_chain(rest,payload,
        Domain.digest(List.append(&2,U32,Domain.encode(previous),payload)))

def text_chain(fuel: Nat,+payload: String,previous: String) -> String:
  match fuel:
    case 0n: previous
    case 1n+rest:
      text_chain(rest,payload,Domain.digest(Domain.encode(previous ++ payload)))

def decoded(value: Result<&2,&2,String,String>) -> IO(String):
  match value:
    case Done{text}: IO.pure(String,text)
    case Fail{error}: IO.die(String,1,"Benchmark corpus UTF8 error: " ++ error)

def report(name: String,count: U32,size: U32,start: Nat,end: Nat) -> IO(Unit):
  IO.print("{\"operation\":\"" ++ name ++ "\",\"iterations\":" ++ U32.show(count) ++
    ",\"message_bytes\":" ++ U32.show(size) ++ ",\"duration_ms\":" ++
    Nat.show(Nat.sub(end,start)) ++ "}")

def checksum(name: String,got: String) -> IO(Unit):
  IO.print("{\"operation\":\"" ++ name ++ "\",\"final_sha256\":\"" ++ got ++ "\"}")

def measure_bytes(+name: String,+count: U32,size: U32,payload: List<&2,U32>,
  seed: String,expected: String) -> IO(Unit):
  do IO<Unit>:
    start : Nat <- IO.now()
    +got : String = byte_chain(U32.to_nat(count),payload,seed)
    # Printing the dependent result before the end timestamp forces the full
    # chain into the interval. This one checksum line's output cost is included.
    checksum(name,got)
    end : Nat <- IO.now()
    checked(String.eq(got,expected),"SHA benchmark byte-chain mismatch")
    report(name,count,size,start,end)

def measure_text(payload: String,seed: String) -> IO(Unit):
  do IO<Unit>:
    start : Nat <- IO.now()
    +got : String = text_chain(10000n,payload,seed)
    checksum("utf8_chain_512",got)
    end : Nat <- IO.now()
    checked(String.eq(got,"065f8e9551fd243d2d8c1e092dcb68e0889845783262e829970d08a34cd98b2c"),
      "SHA benchmark text-chain mismatch")
    report("utf8_chain_512",10000,512,start,end)

def run(+seed: String) -> IO(Unit):
  +small = corpus(448n,0,17,23,95,32,[])
  +large = corpus(262080n,0,73,19,256,0,[])
  do IO<Unit>:
    checked(String.eq(Domain.digest(small),
      "b8bc4419bbed166ecf22c78dc7503299efad323d446e0f3f50b5652625091286"),
      "SHA benchmark small corpus mismatch")
    checked(String.eq(Domain.digest(large),
      "ebadb917ec3eb4e49ca3c18a4bbb9d0691933b12143e14baa8f7cc37a9c724e6"),
      "SHA benchmark large corpus mismatch")
    text : String <- decoded(Domain.decode(small))
    IO.print("{\"benchmark\":\"sha256-chains-v1\",\"seed\":\"64 ASCII zeroes\",\"generation_and_corpus_checks\":\"outside_timers\",\"checksum_output\":\"inside_timers\"}")
    measure_bytes("byte_chain_512",10000,512,small,seed,
      "065f8e9551fd243d2d8c1e092dcb68e0889845783262e829970d08a34cd98b2c")
    measure_text(text,seed)
    measure_bytes("byte_chain_262144",16,262144,large,seed,
      "18926dfa939ab08b83a305a816f30ba07205704af6cc2672d209a318bf0ce999")
    IO.print("{\"benchmark_complete\":true}")

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case +seed <> []:
      do IO<Unit>:
        checked(String.eq(seed,"0"),"SHA benchmark requires literal argument 0")
        run(String.repeat(seed,64n))
    case _:
      IO.die(Unit,2,"Usage: hash-benchmark 0")

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> rest: arguments(rest)
    case []: arguments([])

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)

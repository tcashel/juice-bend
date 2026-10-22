import Base
import ./pair.bend as DataPair

# These helpers do not reinterpret bytes as Unicode or wrap an array index.
def octet_valid(byte: U32,tail: List<&2,U32>,valid: Bool) -> Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>:
  match valid:
    case False{}: Fail{"input is not an octet"}
    case True{}: Done{(byte,tail)}

def octet(bytes: List<&2,U32>) -> Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>:
  match bytes:
    case Nil{}: Fail{"truncated byte field"}
    case Con{+byte,tail}: octet_valid(byte,tail,U32.is_le(byte,255))

def octet_then(-A: Data,result: Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>,next: U32 -> List<&2,U32> -> Result<&2,&2,String,A>) -> Result<&2,&2,String,A>:
  match result:
    case Fail{error}: Fail{error}
    case Done{(byte,tail)}: next(byte,tail)

def take_loop(fuel: Nat,bytes: List<&2,U32>,rev: List<&2,U32>) ->
  Result<&2,&2,String,DataPair.Duo(List<&2,U32>,List<&2,U32>)>:
  match fuel:
    case 0n: Done{(List.reverse(&2,U32,rev),bytes)}
    case 1n+rest:
      octet_then(DataPair.Duo(List<&2,U32>,List<&2,U32>),octet(bytes),byte => tail =>
        take_loop(rest,tail,Con{byte,rev}))

def take(bytes: List<&2,U32>,count: U32) -> Result<&2,&2,String,DataPair.Duo(List<&2,U32>,List<&2,U32>)>:
  take_loop(U32.to_nat(count),bytes,Nil{})

def little_loop(fuel: Nat,bytes: List<&2,U32>,+shift: Nat,value: U32) ->
  Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>:
  match fuel:
    case 0n: Done{(value,bytes)}
    case 1n+rest:
      octet_then(DataPair.Duo(U32,List<&2,U32>),octet(bytes),byte => tail =>
        little_loop(rest,tail,Nat.add(shift,8n),U32.or(value,U32.shln(byte,shift))))

def little_allowed(bytes: List<&2,U32>,width: U32,allowed: Bool) ->
  Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>:
  match allowed:
    case False{}: Fail{"little-endian field wider than four bytes"}
    case True{}: little_loop(U32.to_nat(width),bytes,0n,0)

def little(bytes: List<&2,U32>,+width: U32) -> Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>:
  little_allowed(bytes,width,U32.is_le(width,4))

def repeat(fuel: Nat,+byte: U32,rev: List<&2,U32>) -> List<&2,U32>:
  match fuel:
    case 0n: rev
    case 1n+rest: repeat(rest,byte,Con{byte,rev})

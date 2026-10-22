import Base

type Failure is Data:
  Failure{kind: String,detail: String}

type Component is Data:
  Component{id: U32,h: U32,v: U32,quant: U32}
type ScanComponent is Data:
  ScanComponent{component: Component,dc: U32,ac: U32}
type Quantizer is Data:
  Quantizer{id: U32,values: List<&2,U32>}
type Huffman is Data:
  Huffman{counts: List<&2,U32>,symbols: List<&2,U32>}
type Table is Data:
  Table{kind: U32,id: U32,huffman: Huffman}
type Frame is Data:
  Frame{width: U32,height: U32,components: List<&2,Component>,hmax: U32,vmax: U32,columns: U32,rows: U32}
type ColorMode is Data:
  Gray{}
  YCbCr{}
  RGB{}
type Document is Data:
  Document{frame: Frame,scan: List<&2,ScanComponent>,quants: List<&2,Quantizer>,tables: List<&2,Table>,restart: U32,entropy: List<&2,U32>,color: ColorMode,notice: Bool}

def max_input() -> U32: 1048576
def max_dimension() -> U32: 2048
def max_pixels() -> U32: 1048576
def max_segments() -> U32: 4096

def require(okay: Bool,kind: String,detail: String) -> Result<&2,&2,Failure,Unit>:
  Bool.pick(Result<&2,&2,Failure,Unit>,okay,Done{Unit{}},Fail{Failure{kind,detail}})

def widen(-A: Data,value: Result<&2,&2,Failure,A>) -> Result<&2,&1,Failure,A>:
  match value:
    case Fail{error}: Fail{error}
    case Done{item}: Done{item}

def branch(-A: Type,okay: Bool,yes: Unit -> A,no: Unit -> A) -> A:
  match okay:
    case True{}: yes(Unit{})
    case False{}: no(Unit{})

def depth(+count: U32) -> Nat:
  Bool.pick(Nat,U32.is_le(count,1),0n,1n+U32.log2(U32.sub(count,1)))

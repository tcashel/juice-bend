import Base

# Scalar spans describe the unchanged canonical string, never captured byte
# offsets. Oversized or malformed descriptor tables retain the entire Plain
# string. These UI-only limits match the existing bounded page transport.
type PartKey is Data:
  PartKey{snapshot: String,record: String,event: U32,part: U32}

type Span is Data:
  Span{start: U32,length: U32}

type PartKind is Data:
  PageNotice{}
  EventHeading{}
  MessageText{}
  FencedCode{}
  ToolName{}
  ToolArguments{}
  ToolResult{}
  EvidenceDetails{}

type Part is Data:
  Part{key: PartKey,kind: PartKind,source: Span,role: String,tool: String,collapsible: Bool}

type Document is Data:
  Plain{canonical: String,revision: U32}
  Structured{canonical: String,revision: U32,parts: List<&2,Part>}

def scalar_limit() -> U32: 1048576
def part_limit() -> Nat: 2048n

# Saturation only handles a string beyond the representable U32 scalar space;
# normal Plain pages above scalar_limit remain exact and are not truncated.
def length.go(value: String,+count: U32) -> U32:
  match value:
    case SNil{}: count
    case SCon{_,rest}:
      length.go(rest,U32.add(count,Bool.to_u32(U32.is_lt(count,4294967295))))

def length(value: String) -> U32: length.go(value,0)

def text(document: Document) -> String:
  match document:
    case Plain{canonical,_}: canonical
    case Structured{canonical,_,_}: canonical

def revision(document: Document) -> U32:
  match document:
    case Plain{_,value}: value
    case Structured{_,value,_}: value

def parts(document: Document) -> List<&2,Part>:
  match document:
    case Plain{_,_}: []
    case Structured{_,_,value}: value

def structured(document: Document) -> Bool:
  match document:
    case Plain{_,_}: False{}
    case Structured{_,_,_}: True{}

def key_equal(left: PartKey,right: PartKey) -> Bool:
  PartKey{a,b,c,d} = left
  PartKey{x,y,z,w} = right
  String.eq(a,x) && String.eq(b,y) && U32.is_eq(c,z) && U32.is_eq(d,w)

def has_key(keys: List<&2,PartKey>,+key: PartKey) -> Bool:
  match keys:
    case []: False{}
    case first <> rest: key_equal(first,key) || has_key(rest,key)

def part_key(part: Part) -> PartKey:
  Part{key,_,_,_,_,_} = part
  key

def part_span(part: Part) -> Span:
  Part{_,_,source,_,_,_} = part
  source

def part_collapsible(part: Part) -> Bool:
  Part{_,_,_,_,_,value} = part
  value

def kind_collapsible(kind: PartKind) -> Bool:
  match kind:
    case ToolArguments{}: True{}
    case ToolResult{}: True{}
    case EvidenceDetails{}: True{}
    case _: False{}

def span_valid.inside(+span: Span,+total: U32,inside: Bool) -> Bool:
  Span{start,count} = span
  match inside:
    case False{}: False{}
    case True{}: U32.is_le(count,U32.sub(total,start))

def span_valid(+span: Span,+total: U32) -> Bool:
  Span{start,_} = span
  span_valid.inside(span,total,U32.is_le(start,total))

def slice.valid(value: String,span: Span,valid: Bool) -> String:
  Span{start,count} = span
  match valid:
    case False{}: ""
    case True{}: String.take(String.drop(value,U32.to_nat(start)),U32.to_nat(count))

def slice(+value: String,+span: Span) -> String:
  slice.valid(value,span,span_valid(span,length(value)))

def next.valid(span: Span,valid: Bool) -> Maybe<&2,U32>:
  Span{start,count} = span
  match valid:
    case False{}: None{}
    case True{}: Some{U32.add(start,count)}

def next(+part: Part,+total: U32,+cursor: U32,seen: List<&2,PartKey>) -> Maybe<&2,U32>:
  Part{key,+kind,+source,_,_,collapsible} = part
  Span{start,count} = source
  next.valid(source,span_valid(source,total) && U32.is_gt(count,0) &&
    U32.is_eq(start,cursor) && Bool.not(has_key(seen,key)) &&
    (Bool.not(collapsible) || kind_collapsible(kind)))

def validate(fuel: Nat,remaining: List<&2,Part>,+total: U32,cursor: Maybe<&2,U32>,+seen: List<&2,PartKey>) -> Bool:
  match fuel remaining cursor:
    case _ Nil{} Some{at}: U32.is_eq(at,total)
    case 1n+n Con{+part,rest} Some{at}:
      validate(n,rest,total,next(part,total,at,seen),part_key(part) <> seen)
    case _ _ _: False{}

def admit.valid(canonical: String,revision: U32,parts: List<&2,Part>,valid: Bool) -> Document:
  match valid:
    case True{}: Structured{canonical,revision,parts}
    case False{}: Plain{canonical,revision}

def admit.bounded(+canonical: String,+revision: U32,+parts: List<&2,Part>,+total: U32,bounded: Bool) -> Document:
  match bounded:
    case False{}: Plain{canonical,revision}
    case True{}: admit.valid(canonical,revision,parts,validate(part_limit(),parts,total,Some{0},[]))

def admit(+canonical: String,revision: U32,parts: List<&2,Part>) -> Document:
  +total = length(canonical)
  admit.bounded(canonical,revision,parts,total,U32.is_le(total,scalar_limit()))

# Constructors are public Bend data, so re-admit a caller-supplied Structured
# value before using descriptors. Plain is always the complete original text.
def normalize(document: Document) -> Document:
  match document:
    case Plain{canonical,revision}: Plain{canonical,revision}
    case Structured{canonical,revision,parts}: admit(canonical,revision,parts)

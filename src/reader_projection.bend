import Base
import ./reader_document.bend as Doc

# Projection coordinates are visible Unicode scalars. A source Span always
# refers to canonical Unicode scalars; neither coordinate is a raw byte offset.
type Piece is Data:
  Piece{visible: Doc.Span,source: Doc.Span,key: Doc.PartKey}

type Projection is Data:
  Projection{text: String,pieces: List<&2,Piece>,revision: U32}

type Selection is Data:
  Selection{text: String,spans: List<&2,Doc.Span>}

# Box View at the application boundary. Folding and selection never replace
# the admitted document, retrieve another capture, or alter its identity.
type View is Data:
  View{document: Doc.Document,collapsed: List<&2,Doc.PartKey>,projection: Projection,
    anchor: U32,caret: U32,drag: Bool}

def text(value: Projection) -> String:
  Projection{body,_,_} = value
  body

def pieces(value: Projection) -> List<&2,Piece>:
  Projection{_,table,_} = value
  table

def revision(value: Projection) -> U32:
  Projection{_,_,number} = value
  number

def selection_text(value: Selection) -> String:
  Selection{text,_} = value
  text

def selection_spans(value: Selection) -> List<&2,Doc.Span>:
  Selection{_,spans} = value
  spans

def find.choose(part: Doc.Part,rest: Maybe<&2,Doc.Part>,same: Bool) -> Maybe<&2,Doc.Part>:
  match same:
    case True{}: Some{part}
    case False{}: rest

def find(parts: List<&2,Doc.Part>,+key: Doc.PartKey) -> Maybe<&2,Doc.Part>:
  match parts:
    case []: None{}
    case +part <> rest: find.choose(part,find(rest,key),Doc.key_equal(Doc.part_key(part),key))

def collapsible(part: Maybe<&2,Doc.Part>) -> Bool:
  match part:
    case None{}: False{}
    case Some{part}: Doc.part_collapsible(part)

def folds_valid(fuel: Nat,keys: List<&2,Doc.PartKey>,+parts: List<&2,Doc.Part>,+seen: List<&2,Doc.PartKey>) -> Bool:
  match fuel keys:
    case _ Nil{}: True{}
    case 1n+n Con{+key,rest}:
      Bool.not(Doc.has_key(seen,key)) && collapsible(find(parts,key)) && folds_valid(n,rest,parts,key <> seen)
    case 0n _: False{}

def plain.pieces(count: U32) -> List<&2,Piece>:
  match count:
    case 0: []
    case +count: [Piece{Doc.Span{0,count},Doc.Span{0,count},Doc.PartKey{"","",4294967295,4294967295}}]

def plain(+document: Doc.Document,revision: U32) -> Projection:
  +canonical = Doc.text(document)
  Projection{canonical,plain.pieces(Doc.length(canonical)),revision}

# The admitted ordered table partitions canonical once. Walking its remaining
# suffix avoids rescanning the whole canonical prefix for every visible part.
def build.prepend(part: Doc.Part,chunk: String,cursor: U32,rest: Projection,hidden: Bool) -> Projection:
  Doc.Part{key,_,+source,_,_,_} = part
  Doc.Span{_,count} = source
  Projection{text,pieces,revision} = rest
  match hidden:
    case True{}: Projection{text,pieces,revision}
    case False{}: Projection{chunk ++ text,Piece{Doc.Span{cursor,count},source,key} <> pieces,revision}

def build.parts(parts: List<&2,Doc.Part>,+canonical: String,+collapsed: List<&2,Doc.PartKey>,+cursor: U32,+revision: U32) -> Projection:
  match parts:
    case []: Projection{"",[],revision}
    case +part <> rest:
      Doc.Part{key,_,Doc.Span{_,+count},_,_,can_fold} = part
      +hidden = can_fold && Doc.has_key(collapsed,key)
      build.prepend(part,String.take(canonical,U32.to_nat(count)),cursor,
        build.parts(rest,String.drop(canonical,U32.to_nat(count)),collapsed,
          U32.add(cursor,Bool.pick(U32,hidden,0,count)),revision),hidden)

def build.valid(+document: Doc.Document,collapsed: List<&2,Doc.PartKey>,revision: U32,valid: Bool) -> Projection:
  match valid:
    case False{}: plain(document,revision)
    case True{}: build.parts(Doc.parts(document),Doc.text(document),collapsed,0,revision)

def build.at(+document: Doc.Document,+collapsed: List<&2,Doc.PartKey>,revision: U32) -> Projection:
  build.valid(document,collapsed,revision,Doc.structured(document) && folds_valid(Doc.part_limit(),collapsed,Doc.parts(document),[]))

def build.normal(+document: Doc.Document,collapsed: List<&2,Doc.PartKey>) -> Projection:
  build.at(document,collapsed,Doc.revision(document))

def build(document: Doc.Document,collapsed: List<&2,Doc.PartKey>) -> Projection:
  build.normal(Doc.normalize(document),collapsed)

def within.checked(source: Doc.Span,part: Doc.Span,valid: Bool) -> Bool:
  Doc.Span{start,count} = source
  Doc.Span{left,length} = part
  match valid:
    case False{}: False{}
    case True{}: Doc.span_valid(Doc.Span{U32.sub(start,left),count},length)

def within(+source: Doc.Span,part: Maybe<&2,Doc.Part>) -> Bool:
  Doc.Span{start,_} = source
  match part:
    case None{}: False{}
    case Some{Doc.Part{_,_,+range,_,_,_}}:
      Doc.Span{left,_} = range
      within.checked(source,range,U32.is_ge(start,left))

# Call only after range validation; no addition occurs before its checked end.
def cut(value: String,span: Doc.Span) -> String:
  Doc.Span{start,count} = span
  String.take(String.drop(value,U32.to_nat(start)),U32.to_nat(count))

def piece.end(piece: Piece,valid: Bool) -> Maybe<&2,U32>:
  Piece{Doc.Span{start,count},_,_} = piece
  match valid:
    case False{}: None{}
    case True{}: Some{U32.add(start,count)}

def piece.equal(+piece: Piece,visible: String,canonical: String,valid: Bool) -> Maybe<&2,U32>:
  Piece{+shown,+source,_} = piece
  match valid:
    case False{}: None{}
    case True{}: piece.end(piece,String.eq(cut(visible,shown),cut(canonical,source)))

def piece.check(+piece: Piece,visible: String,canonical: String,parts: List<&2,Doc.Part>,visible_count: U32,canonical_count: U32,cursor: U32) -> Maybe<&2,U32>:
  Piece{+shown,+source,key} = piece
  Doc.Span{start,+count} = shown
  Doc.Span{_,source_count} = source
  piece.equal(piece,visible,canonical,Doc.span_valid(shown,visible_count) &&
    Doc.span_valid(source,canonical_count) && U32.is_gt(count,0) &&
    U32.is_eq(count,source_count) && U32.is_eq(start,cursor) && within(source,find(parts,key)))

def validate(fuel: Nat,pieces: List<&2,Piece>,+visible: String,+canonical: String,+parts: List<&2,Doc.Part>,+visible_count: U32,+canonical_count: U32,cursor: Maybe<&2,U32>) -> Bool:
  match fuel pieces cursor:
    case _ Nil{} Some{at}: U32.is_eq(at,visible_count)
    case 1n+n Con{piece,rest} Some{at}:
      validate(n,rest,visible,canonical,parts,visible_count,canonical_count,
        piece.check(piece,visible,canonical,parts,visible_count,canonical_count,at))
    case _ _ _: False{}

def source_sum.add(count: U32,used: U32,valid: Bool) -> Maybe<&2,U32>:
  match valid:
    case False{}: None{}
    case True{}: Some{U32.add(count,used)}

def source_sum.next(piece: Piece,+key: Doc.PartKey,+limit: U32,+used: U32) -> Maybe<&2,U32>:
  Piece{_,Doc.Span{_,+count},actual} = piece
  +add = Bool.pick(U32,Doc.key_equal(actual,key),count,0)
  source_sum.add(add,used,U32.is_le(add,U32.sub(limit,used)))

def source_sum(pieces: List<&2,Piece>,+key: Doc.PartKey,+limit: U32,used: Maybe<&2,U32>) -> Maybe<&2,U32>:
  match pieces used:
    case Nil{} value: value
    case Con{piece,rest} Some{at}: source_sum(rest,key,limit,source_sum.next(piece,key,limit,at))
    case _ None{}: None{}

def source_next.choose(source: Doc.Span,rest: Maybe<&2,U32>,same: Bool) -> Maybe<&2,U32>:
  Doc.Span{start,count} = source
  match same:
    case False{}: rest
    case True{}: Some{U32.add(start,count)}

def source_next(pieces: List<&2,Piece>,+key: Doc.PartKey,+cursor: U32) -> Maybe<&2,U32>:
  match pieces:
    case []: None{}
    case Piece{_,+source,actual} <> rest:
      Doc.Span{start,_} = source
      source_next.choose(source,source_next(rest,key,cursor),Doc.key_equal(actual,key) && U32.is_eq(start,cursor))

def coverage.finish(done: Bool,rest: Unit -> Bool) -> Bool:
  match done:
    case True{}: True{}
    case False{}: rest(Unit{})

def coverage.walk(fuel: Nat,+pieces: List<&2,Piece>,+key: Doc.PartKey,cursor: Maybe<&2,U32>,+end: U32) -> Bool:
  match fuel cursor:
    case _ None{}: False{}
    case 0n Some{at}: U32.is_eq(at,end)
    case 1n+n Some{+at}:
      coverage.finish(U32.is_eq(at,end),_ => coverage.walk(n,pieces,key,source_next(pieces,key,at),end))

def coverage.part(part: Doc.Part,pieces: List<&2,Piece>,sum: Maybe<&2,U32>) -> Bool:
  Doc.Part{key,_,Doc.Span{+start,+count},_,_,can_fold} = part
  match sum:
    case None{}: False{}
    case Some{0}: can_fold
    case Some{actual}:
      U32.is_eq(actual,count) && coverage.walk(Doc.part_limit(),pieces,key,Some{start},U32.add(start,count))

def coverage.parts(parts: List<&2,Doc.Part>,+pieces: List<&2,Piece>) -> Bool:
  match parts:
    case []: True{}
    case +part <> rest:
      Doc.Part{key,_,Doc.Span{_,count},_,_,_} = part
      coverage.part(part,pieces,source_sum(pieces,key,count,Some{0})) && coverage.parts(rest,pieces)

def admit.valid(+document: Doc.Document,text: String,pieces: List<&2,Piece>,revision: U32,valid: Bool) -> Projection:
  match valid:
    case False{}: plain(document,Doc.revision(document))
    case True{}: Projection{text,pieces,revision}

def admit.covered(+document: Doc.Document,+text: String,+pieces: List<&2,Piece>,+revision: U32,valid: Bool) -> Projection:
  match valid:
    case False{}: plain(document,Doc.revision(document))
    case True{}: admit.valid(document,text,pieces,revision,coverage.parts(Doc.parts(document),pieces))

def admit.bounded(+document: Doc.Document,+text: String,+pieces: List<&2,Piece>,+revision: U32,+count: U32,bounded: Bool) -> Projection:
  match bounded:
    case False{}: plain(document,Doc.revision(document))
    case True{}: admit.covered(document,text,pieces,revision,
      validate(Doc.part_limit(),pieces,text,Doc.text(document),Doc.parts(document),count,Doc.length(Doc.text(document)),Some{0}))

def admit.normal(+document: Doc.Document,+text: String,pieces: List<&2,Piece>,+revision: U32) -> Projection:
  +count = Doc.length(text)
  admit.bounded(document,text,pieces,revision,count,Doc.structured(document) &&
    U32.is_eq(revision,Doc.revision(document)) && U32.is_le(count,Doc.scalar_limit()))

# An external projection is admitted against the document's initial revision.
# Internal folds mint later projection revisions without changing Document.
def admit(document: Doc.Document,text: String,pieces: List<&2,Piece>,revision: U32) -> Projection:
  admit.normal(Doc.normalize(document),text,pieces,revision)

def mapping.next(+piece: Piece,+total: U32,cursor: U32) -> Maybe<&2,U32>:
  Piece{+visible,+source,_} = piece
  Doc.Span{start,+count} = visible
  Doc.Span{_,source_count} = source
  piece.end(piece,Doc.span_valid(visible,total) && Doc.span_valid(source,4294967295) &&
    U32.is_eq(count,source_count) && U32.is_gt(count,0) && U32.is_eq(start,cursor))

def mapping.valid(fuel: Nat,pieces: List<&2,Piece>,+total: U32,cursor: Maybe<&2,U32>) -> Bool:
  match fuel pieces cursor:
    case _ Nil{} Some{at}: U32.is_eq(at,total)
    case 1n+n Con{piece,rest} Some{at}: mapping.valid(n,rest,total,mapping.next(piece,total,at))
    case _ _ _: False{}

def intersect.valid(source: Doc.Span,visible: Doc.Span,+low: U32,high: U32,valid: Bool) -> List<&2,Doc.Span>:
  Doc.Span{start,_} = source
  Doc.Span{visible_start,_} = visible
  match valid:
    case False{}: []
    case True{}: [Doc.Span{U32.add(start,U32.sub(low,visible_start)),U32.sub(high,low)}]

def intersect(piece: Piece,low: U32,high: U32) -> List<&2,Doc.Span>:
  Piece{+visible,source,_} = piece
  Doc.Span{+start,count} = visible
  +left = U32.max(low,start)
  +right = U32.min(high,U32.add(start,count))
  intersect.valid(source,visible,left,right,U32.is_lt(left,right))

def intersections(pieces: List<&2,Piece>,+low: U32,+high: U32) -> List<&2,Doc.Span>:
  match pieces:
    case []: []
    case piece <> rest: List.append(&2,Doc.Span,intersect(piece,low,high),intersections(rest,low,high))

def select.valid(value: Projection,+anchor: U32,+caret: U32,valid: Bool) -> Maybe<&2,Selection>:
  Projection{text,pieces,_} = value
  match valid:
    case False{}: None{}
    case True{}:
      +low = U32.min(anchor,caret)
      +high = U32.max(anchor,caret)
      Some{Selection{cut(text,Doc.Span{low,U32.sub(high,low)}),intersections(pieces,low,high)}}

def select(+value: Projection,expected_revision: U32,+anchor: U32,+caret: U32) -> Maybe<&2,Selection>:
  +count = Doc.length(text(value))
  select.valid(value,anchor,caret,U32.is_eq(revision(value),expected_revision) &&
    U32.is_le(anchor,count) && U32.is_le(caret,count) && mapping.valid(Doc.part_limit(),pieces(value),count,Some{0}))

def open.normal(+document: Doc.Document) -> View:
  View{document,[],build.at(document,[],Doc.revision(document)),0,0,False{}}

def open(document: Doc.Document) -> View: open.normal(Doc.normalize(document))

def projection(view: View) -> Projection:
  View{_,_,value,_,_,_} = view
  value

def selection(view: View,expected_revision: U32) -> Maybe<&2,Selection>:
  View{_,_,value,anchor,caret,_} = view
  select(value,expected_revision,anchor,caret)

def point.valid(view: View,+caret: U32,extend: Bool,drag: Bool,valid: Bool) -> View:
  View{document,collapsed,projection,anchor,old,old_drag} = view
  match valid:
    case False{}: View{document,collapsed,projection,anchor,old,old_drag}
    case True{}: View{document,collapsed,projection,Bool.pick(U32,extend,anchor,caret),caret,drag}

def point(+view: View,expected_revision: U32,+caret: U32,extend: Bool,drag: Bool) -> View:
  +value = projection(view)
  point.valid(view,caret,extend,drag,U32.is_eq(revision(value),expected_revision) && U32.is_le(caret,Doc.length(text(value))))

def remove.keep(key: Doc.PartKey,rest: List<&2,Doc.PartKey>,same: Bool) -> List<&2,Doc.PartKey>:
  match same:
    case True{}: rest
    case False{}: key <> rest

def remove(keys: List<&2,Doc.PartKey>,+target: Doc.PartKey) -> List<&2,Doc.PartKey>:
  match keys:
    case []: []
    case +key <> rest: remove.keep(key,remove(rest,target),Doc.key_equal(key,target))

def toggle.keys(+keys: List<&2,Doc.PartKey>,+key: Doc.PartKey,contains: Bool) -> List<&2,Doc.PartKey>:
  match contains:
    case True{}: remove(keys,key)
    case False{}: key <> keys

def toggle.valid(view: View,+key: Doc.PartKey,valid: Bool) -> View:
  View{+document,+collapsed,+projection,anchor,caret,drag} = view
  match valid:
    case False{}: View{document,collapsed,projection,anchor,caret,drag}
    case True{}:
      +next = toggle.keys(collapsed,key,Doc.has_key(collapsed,key))
      View{document,next,build.at(document,next,U32.inc(revision(projection))),0,0,False{}}

def toggle(+view: View,expected_revision: U32,+key: Doc.PartKey) -> View:
  View{+document,_,+projection,_,_,_} = view
  toggle.valid(view,key,U32.is_eq(revision(projection),expected_revision) &&
    U32.is_lt(revision(projection),4294967295) && collapsible(find(Doc.parts(document),key)))

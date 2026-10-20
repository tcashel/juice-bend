import Base
import ./domain.bend as Domain

# Pure parser for one file's Git --unified=0 patch. A bounded Git process and
# literal file/revision selection belong to the caller. No Git output executes.
type Hunk is Data:
  Hunk{start: U32,count: U32,lines: List<&2,String>}

type Range is Data:
  Range{start: U32,count: U32}

type Open is Data:
  Open{start: U32,count: U32,old_left: U32,new_left: U32,
    lines: List<&2,String>,marker_allowed: Bool}

type State is Data:
  State{open: Maybe<&2,Open>,hunks: List<&2,Hunk>,file: Bool,
    old_header: Bool,new_header: Bool,count: U32}

def byte_budget(text: String,+budget: Nat) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{Chr{+cp},rest}:
      +width = U32.to_nat(U32.add(Domain.encode_width(cp),1))
      Domain.scalar(cp) && U32.is_ne(cp,0) && Nat.is_le(width,budget) &&
        byte_budget(rest,Nat.sub(budget,width))

def range_numbers(start: Maybe<&2,U32>,count: Maybe<&2,U32>) ->
  Result<&2,&2,String,Range>:
  match start count:
    case Some{+s} Some{+n}:
      Bool.pick(Result<&2,&2,String,Range>,
        (U32.is_eq(n,0) || U32.is_ne(s,0)) &&
          Nat.is_le(Nat.add(U32.to_nat(s),U32.to_nat(n)),Nat.add(4294967295n,1n)),
        Done{Range{s,n}},Fail{"Git hunk range overflows or starts at zero"})
    case _ _:
      Fail{"Git hunk requires canonical unsigned decimal ranges"}

def range_parts(parts: List<&2,String>) -> Result<&2,&2,String,Range>:
  match parts:
    case start <> Nil{}:
      range_numbers(Domain.parse_u32(start),Some{1})
    case start <> count <> Nil{}:
      range_numbers(Domain.parse_u32(start),Domain.parse_u32(count))
    case _:
      Fail{"Malformed Git hunk range"}

def range(token: String) -> Result<&2,&2,String,Range>:
  range_parts(String.split(String.drop(token,1n),','))

def finish_open(state: State) -> Result<&2,&2,String,State>:
  State{open,hunks,file,old_header,new_header,count} = state
  match open:
    case None{}:
      Done{State{None{},hunks,file,old_header,new_header,count}}
    case Some{Open{start,size,0,0,lines,_}}:
      Done{State{None{},Hunk{start,size,List.reverse(&2,String,lines)} <> hunks,
        file,old_header,new_header,count}}
    case _:
      Fail{"Truncated Git hunk: declared line counts do not match payload"}

def ordered(hunks: List<&2,Hunk>,start: U32) -> Bool:
  match hunks:
    case []:
      True{}
    case Hunk{prior,count,_} <> _:
      Nat.is_ge(U32.to_nat(start),Nat.add(U32.to_nat(prior),U32.to_nat(count)))

def open_ranges(state: State,old: Range,new: Range) -> Result<&2,&2,String,State>:
  State{_,+hunks,+file,+old_header,+new_header,+count} = state
  Range{_,old_count} = old
  Range{+start,+new_count} = new
  Bool.pick(Result<&2,&2,String,State>,
    file && old_header && new_header && U32.is_lt(count,128) && ordered(hunks,start),
    Done{State{Some{Open{start,new_count,old_count,new_count,[],False{}}},
      hunks,file,old_header,new_header,U32.add(count,1)}},
    Fail{"Git hunk missing headers, overlapping, or exceeds 128 hunks"})

def header_tokens(state: State,tokens: List<&2,String>) ->
  Result<&2,&2,String,State>:
  match tokens:
    case "@@" <> +old <> +new <> "@@" <> _:
      do Result<&2,&2,String,State>:
        Unit <- Bool.pick(Result<&2,&2,String,Unit>,
          String.starts_with(old,"-") && String.starts_with(new,"+"),
          Done{Unit{}},Fail{"Malformed Git hunk range signs"})
        a : Range <- range(old)
        b : Range <- range(new)
        open_ranges(state,a,b)
    case _:
      Fail{"Malformed Git unified hunk header"}

def header(state: State,line: String) -> Result<&2,&2,String,State>:
  do Result<&2,&2,String,State>:
    ready : State <- finish_open(state)
    header_tokens(ready,String.split(line,' '))

def data_line(open: Open,line: String,kind: U32) -> Result<&2,&2,String,Open>:
  Open{start,count,+old_left,+new_left,lines,marker} = open
  match kind:
    case 1:
      Bool.pick(Result<&2,&2,String,Open>,U32.is_ne(new_left,0),
        Done{Open{start,count,old_left,U32.sub(new_left,1),
          String.drop(line,1n) <> lines,True{}}},
        Fail{"Git hunk has more added lines than declared"})
    case 2:
      Bool.pick(Result<&2,&2,String,Open>,U32.is_ne(old_left,0),
        Done{Open{start,count,U32.sub(old_left,1),new_left,lines,True{}}},
        Fail{"Git hunk has more removed lines than declared"})
    case 3:
      Bool.pick(Result<&2,&2,String,Open>,marker,
        Done{Open{start,count,old_left,new_left,lines,False{}}},
        Fail{"Orphan or duplicate Git no-newline marker"})
    case _:
      Fail{"Unsupported context or malformed Git hunk payload"}

def data(state: State,line: String,kind: U32) -> Result<&2,&2,String,State>:
  State{open,hunks,file,old_header,new_header,count} = state
  match open:
    case None{}:
      Fail{"Git payload appears outside a hunk"}
    case Some{current}:
      do Result<&2,&2,String,State>:
        next : Open <- data_line(current,line,kind)
        return State{Some{next},hunks,file,old_header,new_header,count}

def metadata_allowed(+line: String) -> Bool:
  String.starts_with(line,"index ") || String.starts_with(line,"new file mode ") ||
    String.starts_with(line,"deleted file mode ") || String.starts_with(line,"old mode ") ||
    String.starts_with(line,"new mode ") || String.starts_with(line,"similarity index ") ||
    String.starts_with(line,"dissimilarity index ") || String.starts_with(line,"rename from ") ||
    String.starts_with(line,"rename to ") || String.starts_with(line,"copy from ") ||
    String.starts_with(line,"copy to ")

def metadata(state: State,line: String,kind: U32) -> Result<&2,&2,String,State>:
  State{open,hunks,+file,+old,+new,+count} = state
  match kind:
    case 1:
      Bool.pick(Result<&2,&2,String,State>,Bool.not(file),
        Done{State{open,hunks,True{},False{},False{},count}},
        Fail{"Multiple Git file sections are unsupported"})
    case 2:
      Bool.pick(Result<&2,&2,String,State>,file && Bool.not(old) && U32.is_eq(count,0),
        Done{State{open,hunks,file,True{},new,count}},
        Fail{"Malformed Git old-file header"})
    case 3:
      Bool.pick(Result<&2,&2,String,State>,file && old && Bool.not(new) && U32.is_eq(count,0),
        Done{State{open,hunks,file,old,True{},count}},
        Fail{"Malformed Git new-file header"})
    case _:
      Bool.pick(Result<&2,&2,String,State>,
        file && Bool.not(old) && Bool.not(new) && U32.is_eq(count,0) && metadata_allowed(line),
        Done{State{open,hunks,file,old,new,count}},
        Fail{"Unknown or misplaced Git patch metadata"})

def line_kind(+line: String) -> U32:
  Bool.pick(U32,String.starts_with(line,"diff --git "),1,
    Bool.pick(U32,String.starts_with(line,"--- "),2,
      Bool.pick(U32,String.starts_with(line,"+++ "),3,
        Bool.pick(U32,String.starts_with(line,"@@ "),4,
          Bool.pick(U32,String.eq(line,"\\ No newline at end of file"),5,
            Bool.pick(U32,String.starts_with(line,"+"),6,
              Bool.pick(U32,String.starts_with(line,"-"),7,8)))))))

def step_kind(state: State,line: String,kind: U32) -> Result<&2,&2,String,State>:
  match kind:
    case 4:
      header(state,line)
    case 5:
      data(state,line,3)
    case 6:
      data(state,line,1)
    case 7:
      data(state,line,2)
    case _:
      metadata(state,line,kind)

def step(+state: State,+line: String) -> Result<&2,&2,String,State>:
  State{open,_,_,_,_,_} = state
  match open:
    # Within a hunk, +++/--- are payload. Only @@ starts the next hunk.
    case Some{_}:
      Bool.pick(Result<&2,&2,String,State>,String.starts_with(line,"@@ "),
        header(state,line),
        data(state,line,Bool.pick(U32,String.eq(line,"\\ No newline at end of file"),3,
          Bool.pick(U32,String.starts_with(line,"+"),1,
            Bool.pick(U32,String.starts_with(line,"-"),2,0)))))
    case None{}:
      step_kind(state,line,line_kind(line))

def finish_ready(state: State) -> Result<&2,&2,String,List<&2,Hunk>>:
  State{_,hunks,_,old,new,_} = state
  do Result<&2,&2,String,List<&2,Hunk>>:
    Unit <- Bool.pick(Result<&2,&2,String,Unit>,U32.is_eq(Bool.to_u32(old),Bool.to_u32(new)),
      Done{Unit{}},Fail{"Incomplete Git file headers"})
    return List.reverse(&2,Hunk,hunks)

def finish(state: State) -> Result<&2,&2,String,List<&2,Hunk>>:
  do Result<&2,&2,String,List<&2,Hunk>>:
    ready : State <- finish_open(state)
    finish_ready(ready)

def walk(lines: List<&2,String>,state: State) -> Result<&2,&2,String,List<&2,Hunk>>:
  match lines:
    case []:
      finish(state)
    case "" <> Nil{}:
      finish(state)
    case line <> rest:
      do Result<&2,&2,String,List<&2,Hunk>>:
        next : State <- step(state,line)
        walk(rest,next)

def parse_bounded(text: String,valid: Bool) -> Result<&2,&2,String,List<&2,Hunk>>:
  match valid:
    case False{}:
      Fail{"Git patch exceeds 1 MiB, contains invalid text, or ends mid-line"}
    case True{}:
      walk(String.lines(text),State{None{},[],False{},False{},False{},0})

def parse(+text: String) -> Result<&2,&2,String,List<&2,Hunk>>:
  parse_bounded(text,byte_budget(text,1048576n) &&
    (String.is_empty(text) || String.ends_with(text,"\n")))

import Base
import ./reader_document.bend as Reader
import ./transcript_format.bend as Format

# Deliberately small, lossless fence recognition. Only a three-backtick fence
# at a physical line start is recognized. No HTML, links, execution, or role
# parsing. Unsupported/unclosed fences stay literal message text.
def line_go(text: String,rev: String) -> String & String:
  match text:
    case SNil{}: (String.reverse(rev),"")
    case SCon{Chr{10},rest}: (String.reverse(SCon{Chr{10},rev}),rest)
    case SCon{head,rest}: line_go(rest,SCon{head,rev})

def line(text: String) -> String & String:
  line_go(text,"")

def closes(+text: String) -> Bool:
  String.eq(text,"```") || String.eq(text,"```\n") || String.eq(text,"```\r\n")

def opens(+text: String) -> Bool:
  String.starts_with(text,"```") && Bool.not(String.starts_with(text,"````"))

def joined(lines: List<&2,String>) -> String:
  String.join(List.reverse(&2,String,lines),"")

def emit(text: String,kind: Reader.PartKind,parts: List<&2,Format.Fragment>) -> List<&2,Format.Fragment>:
  match text:
    case "": parts
    case _: Format.Fragment{kind,text,False{}} <> parts

def finish(code: Bool,plain: List<&2,String>,pending: List<&2,String>,parts: List<&2,Format.Fragment>) -> List<&2,Format.Fragment>:
  match code:
    case False{}: List.reverse(&2,Format.Fragment,emit(joined(plain),Reader.MessageText{},parts))
    case True{}: List.reverse(&2,Format.Fragment,emit(joined(pending),Reader.MessageText{},parts))

def closed(done: Bool,text: String,line: String,plain: List<&2,String>,pending: List<&2,String>,parts: List<&2,Format.Fragment>,
  next: String -> Bool -> List<&2,String> -> List<&2,String> -> List<&2,Format.Fragment> -> Maybe<&2,List<&2,Format.Fragment>>) -> Maybe<&2,List<&2,Format.Fragment>>:
  match done:
    case True{}:
      next(text,False{},plain,[],emit(joined(line <> pending),Reader.FencedCode{},parts))
    case False{}:
      next(text,True{},plain,line <> pending,parts)

def opened(start: Bool,text: String,line: String,plain: List<&2,String>,parts: List<&2,Format.Fragment>,
  next: String -> Bool -> List<&2,String> -> List<&2,String> -> List<&2,Format.Fragment> -> Maybe<&2,List<&2,Format.Fragment>>) -> Maybe<&2,List<&2,Format.Fragment>>:
  match start:
    case True{}:
      next(text,True{},[],[line],emit(joined(plain),Reader.MessageText{},parts))
    case False{}:
      next(text,False{},line <> plain,[],parts)

def step(code: Bool,text: String,+line: String,plain: List<&2,String>,pending: List<&2,String>,parts: List<&2,Format.Fragment>,
  next: String -> Bool -> List<&2,String> -> List<&2,String> -> List<&2,Format.Fragment> -> Maybe<&2,List<&2,Format.Fragment>>) -> Maybe<&2,List<&2,Format.Fragment>>:
  match code:
    case True{}: closed(closes(line),text,line,plain,pending,parts,next)
    case False{}: opened(opens(line),text,line,plain,parts,next)

def split_step(pair: String & String,code: Bool,plain: List<&2,String>,pending: List<&2,String>,parts: List<&2,Format.Fragment>,
  next: String -> Bool -> List<&2,String> -> List<&2,String> -> List<&2,Format.Fragment> -> Maybe<&2,List<&2,Format.Fragment>>) -> Maybe<&2,List<&2,Format.Fragment>>:
  (current,rest) = pair
  step(code,rest,current,plain,pending,parts,next)

def scan(fuel: Nat,text: String,code: Bool,plain: List<&2,String>,pending: List<&2,String>,parts: List<&2,Format.Fragment>) -> Maybe<&2,List<&2,Format.Fragment>>:
  match fuel text:
    case _ "": Some{finish(code,plain,pending,parts)}
    case 0n _: None{}
    case 1n+left _:
      split_step(line(text),code,plain,pending,parts,
        tail => active => prose => block => output => scan(left,tail,active,prose,block,output))

def fallback(result: Maybe<&2,List<&2,Format.Fragment>>,text: String) -> List<&2,Format.Fragment>:
  match result:
    case Some{parts}: parts
    case None{}: [Format.Fragment{Reader.MessageText{},text,False{}}]

def split(+text: String) -> List<&2,Format.Fragment>:
  fallback(scan(8192n,text,False{},[],[],[]),text)

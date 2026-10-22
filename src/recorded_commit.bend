import Base
import ./json.bend as Json
import ./request_evidence.bend as Typed

# Strict, bounded recognition of recorded data. Nothing here executes a command.
# Operators and substitutions are rejected except an optional `git add ... &&`
# prefix. Quotes only delimit literal arguments; environment expansion is not
# evaluated or guessed. Unsupported syntax is coverage, never commit evidence.
type Command is Data:
  Command{quiet: Bool, directory: String}

type Arguments is Data:
  Arguments{text: String,directory: String}

type Token is Data:
  Word{text: String}
  And{}

type Lexer is Data:
  Lexer{quote: U32, active: Bool, word: String, done: List<&2,Token>}

type Marker is Data:
  Marker{sha: String,branch: String,subject: String}

def flush(active: Bool,word: String,+done: List<&2,Token>) -> List<&2,Token>:
  Bool.pick(List<&2,Token>,active,Word{String.reverse(word)} <> done,done)

def forbidden(+c: Char) -> Bool:
  Char.is_eq(c,'$') || Char.is_eq(c,'`') || Char.is_eq(c,'\\') || Char.is_eq(c,'\0') ||
    Char.is_eq(c,'\r') || Char.is_eq(c,'\n')

def lex_end(state: Lexer) -> Result<&2,&2,String,List<&2,Token>>:
  Lexer{quote,active,word,done} = state
  Bool.pick(Result<&2,&2,String,List<&2,Token>>,U32.is_eq(quote,0),
    Done{List.reverse(&2,Token,flush(active,word,done))},Fail{"unclosed command quote"})

# Classify character values with equality rather than nested primitive patterns.
# This keeps the exact grammar without expanding a quote-by-Char match matrix.
def lex_class(+c: Char) -> U32:
  Bool.pick(U32,Char.is_eq(c,' ') || Char.is_eq(c,'\t'),1,
    Bool.pick(U32,Char.is_eq(c,'\''),2,
      Bool.pick(U32,Char.is_eq(c,'"'),3,
        Bool.pick(U32,Char.is_eq(c,'&'),4,
          Bool.pick(U32,Char.is_eq(c,';') || Char.is_eq(c,'|'),5,
            Bool.pick(U32,Char.is_eq(c,'>') || Char.is_eq(c,'<'),6,
              Bool.pick(U32,Char.is_eq(c,'(') || Char.is_eq(c,')'),7,
                Bool.pick(U32,Char.is_eq(c,'#'),8,0))))))))

def lex_ampersand(valid: Bool,tail: String,active: Bool,word: String,done: List<&2,Token>,
  next: String -> Lexer -> Result<&2,&2,String,List<&2,Token>>) -> Result<&2,&2,String,List<&2,Token>>:
  match valid:
    case False{}: Fail{"unsupported command operator"}
    case True{}: next(tail,Lexer{0,False{},"",And{} <> flush(active,word,done)})

def lex_and(rest: String,active: Bool,word: String,done: List<&2,Token>,
  next: String -> Lexer -> Result<&2,&2,String,List<&2,Token>>) -> Result<&2,&2,String,List<&2,Token>>:
  match rest:
    case SNil{}: Fail{"unsupported command operator"}
    case SCon{c,tail}: lex_ampersand(Char.is_eq(c,'&'),tail,active,word,done,next)

def lex_plain(kind: U32,c: Char,rest: String,active: Bool,word: String,done: List<&2,Token>,
  next: String -> Lexer -> Result<&2,&2,String,List<&2,Token>>) -> Result<&2,&2,String,List<&2,Token>>:
  match kind:
    case 1: next(rest,Lexer{0,False{},"",flush(active,word,done)})
    case 2: next(rest,Lexer{1,True{},word,done})
    case 3: next(rest,Lexer{2,True{},word,done})
    case 4: lex_and(rest,active,word,done,next)
    case 5: Fail{"unsupported command operator"}
    case 6: Fail{"unsupported command redirection"}
    case 7: Fail{"unsupported command grouping"}
    case 8: Fail{"unsupported command comment"}
    case _: next(rest,Lexer{0,True{},SCon{c,word},done})

def lex_char(state: Lexer,+c: Char,rest: String,next: String -> Lexer -> Result<&2,&2,String,List<&2,Token>>) ->
  Result<&2,&2,String,List<&2,Token>>:
  Lexer{quote,active,+word,+done} = state
  match quote:
    case 1:
      next(rest,Bool.pick(Lexer,Char.is_eq(c,'\''),Lexer{0,True{},word,done},Lexer{1,True{},SCon{c,word},done}))
    case 2:
      next(rest,Bool.pick(Lexer,Char.is_eq(c,'"'),Lexer{0,True{},word,done},Lexer{2,True{},SCon{c,word},done}))
    case _: lex_plain(lex_class(c),c,rest,active,word,done,next)

def lex_checked(ok: Bool,c: Char,rest: String,state: Lexer,
  next: String -> Lexer -> Result<&2,&2,String,List<&2,Token>>) -> Result<&2,&2,String,List<&2,Token>>:
  match ok:
    case False{}: Fail{"command expansion, escape or control character is unsupported"}
    case True{}: lex_char(state,c,rest,next)

def lex(fuel: Nat,text: String,state: Lexer) -> Result<&2,&2,String,List<&2,Token>>:
  match fuel text:
    case _ SNil{}: lex_end(state)
    case 0n _: Fail{"command exceeds 16384 decoded characters"}
    case 1n+n SCon{+c,rest}:
      lex_checked(Bool.not(forbidden(c)),c,rest,state,tail => s => lex(n,tail,s))

def member(+wanted: String,items: List<&2,String>) -> Bool:
  match items:
    case []: False{}
    case head <> rest: String.eq(wanted,head) || member(wanted,rest)

def words(tokens: List<&2,Token>) -> Result<&2,&2,String,List<&2,String>>:
  match tokens:
    case []: Done{[]}
    case Word{text} <> rest:
      do Result<&2,&2,String,List<&2,String>>:
        tail : List<&2,String> <- words(rest)
        return text <> tail
    case _: Fail{"more than one command or unsupported command chain"}

def flag_value(+flag: String) -> Bool:
  member(flag,["-m","--message","-F","--file","-C","--reuse-message","-c","--reedit-message","--author","--date","--fixup","--squash"])

def plain_flag(+flag: String) -> Bool:
  member(flag,["-a","--all","-q","--quiet","--amend","--no-edit","--allow-empty","--allow-empty-message","--no-verify","-n","--no-gpg-sign","--signoff","-s","--reset-author","--only","-o","--include","-i","--no-post-rewrite"])

def option(value: Bool,plain: Bool,rest: List<&2,String>,+head: String,quiet: Bool,
  next: List<&2,String> -> Bool -> Result<&2,&2,String,Bool>) -> Result<&2,&2,String,Bool>:
  match value plain:
    case True{} _:
      match rest:
        case _ <> tail: next(tail,quiet)
        case _: Fail{"commit option value missing"}
    case False{} True{}:
      next(rest,quiet || String.eq(head,"-q") || String.eq(head,"--quiet"))
    case _ _: Fail{"unsupported commit argument; use explicit literal options and -- before paths"}

def options(fuel: Nat,items: List<&2,String>,+quiet: Bool,paths: Bool) -> Result<&2,&2,String,Bool>:
  match fuel items paths:
    case _ Nil{} _: Done{quiet}
    case 0n _ _: Fail{"commit argument count exceeds 256"}
    case 1n+n Con{_,rest} True{}: options(n,rest,quiet,True{})
    case 1n+n Con{"--",rest} False{}: options(n,rest,quiet,True{})
    case 1n+n Con{+head,rest} False{}:
      option(flag_value(head),plain_flag(head),rest,head,quiet,tail => q => options(n,tail,q,False{}))

def invocation(items: List<&2,String>,directory: String) -> Result<&2,&2,String,Command>:
  match items:
    case "commit" <> rest:
      do Result<&2,&2,String,Command>:
        quiet : Bool <- options(256n,rest,False{},False{})
        return Command{quiet,directory}
    case _:
      Fail{"recorded command is not a supported git commit"}

def git_args(items: List<&2,String>) -> Result<&2,&2,String,Command>:
  match items:
    case "-C" <> directory <> rest: invocation(rest,directory)
    case rest: invocation(rest,"")

def git_words(items: List<&2,String>) -> Result<&2,&2,String,Command>:
  match items:
    case "git" <> rest: git_args(rest)
    case "/usr/bin/git" <> rest: git_args(rest)
    case _: Fail{"unsupported executable or shell wrapper"}

def add_prefix(items: List<&2,Token>) -> Bool:
  match items:
    case Word{"git"} <> Word{"add"} <> _: True{}
    case Word{"/usr/bin/git"} <> Word{"add"} <> _: True{}
    case _: False{}

def prefix(valid: Bool,rest: List<&2,Token>) -> Result<&2,&2,String,Command>:
  match valid:
    case False{}: Fail{"only a single git add prefix is supported"}
    case True{}:
      do Result<&2,&2,String,Command>:
        args : List<&2,String> <- words(rest)
        git_words(args)

def segments(items: List<&2,Token>,done: List<&2,Token>) -> Result<&2,&2,String,Command>:
  match items:
    case []:
      do Result<&2,&2,String,Command>:
        args : List<&2,String> <- words(List.reverse(&2,Token,done))
        git_words(args)
    case And{} <> rest:
      prefix(add_prefix(List.reverse(&2,Token,done)),rest)
    case head <> rest: segments(rest,head <> done)

def command(text: String) -> Result<&2,&2,String,Command>:
  do Result<&2,&2,String,Command>:
    tokens : List<&2,Token> <- lex(16384n,text,Lexer{0,False{},"",[]})
    segments(tokens,[])

def hex_char(+c: Char) -> Bool:
  Char.is_digit(c) || (U32.is_ge(Char.to_u32(Char.to_lower(c)),97) &&
    U32.is_le(Char.to_u32(Char.to_lower(c)),102))

def hex(text: String) -> Bool:
  match text:
    case SNil{}: True{}
    case SCon{c,rest}: hex_char(c) && hex(rest)

def object_name(+text: String) -> Bool:
  Nat.is_ge(String.length(text),7n) && Nat.is_le(String.length(text),40n) && hex(text)

def marker_valid(+branch: String,+sha: String,+subject: String) -> Maybe<&2,Marker>:
  Bool.pick(Maybe<&2,Marker>,object_name(sha) && Bool.not(String.is_empty(branch)) &&
    Bool.not(String.is_empty(subject)),Some{Marker{String.to_lower(sha),branch,subject}},None{})

def marker_three(valid: Bool,branch: String,sha: String,subject: String) -> Maybe<&2,Marker>:
  match valid:
    case False{}: None{}
    case True{}: marker_valid(branch,sha,subject)

def marker_parts(+first: String,+tag: String,sha: String,subject: String) -> Maybe<&2,Marker>:
  marker_three(String.eq(tag,"(root-commit)") ||
    (String.eq(first,"detached") && String.eq(tag,"HEAD")),
    Bool.pick(String,String.eq(tag,"(root-commit)"),first,"detached HEAD"),sha,subject)

def marker_fields(fields: List<&2,String>,subject: String) -> Maybe<&2,Marker>:
  # Avoid expanding nested literal String patterns in the pinned compiler.
  # Arity stays structural; every accepted tag remains an exact comparison.
  match fields:
    case branch <> sha <> Nil{}: marker_valid(branch,sha,subject)
    case first <> tag <> sha <> Nil{}: marker_parts(first,tag,sha,subject)
    case _: None{}

def closing(text: String,reverse: String) -> Maybe<&2,Marker>:
  match text:
    case SCon{']',SCon{' ',subject}}:
      marker_fields(String.split(String.reverse(reverse),' '),subject)
    case SCon{']',_}: None{}
    case SCon{c,rest}: closing(rest,SCon{c,reverse})
    case SNil{}: None{}

def marker(line: String) -> Maybe<&2,Marker>:
  match line:
    case SCon{'[',rest}: closing(String.trim_end(rest),"")
    case _: None{}

def add_marker(item: Maybe<&2,Marker>,rest: List<&2,Marker>) -> List<&2,Marker>:
  match item:
    case None{}: rest
    case Some{value}: value <> rest

def markers(lines: List<&2,String>,fuel: Nat) -> List<&2,Marker>:
  match lines fuel:
    case Nil{} _: []
    case _ 0n: []
    case Con{line,rest} 1n+n: add_marker(marker(line),markers(rest,n))

def typed_string_value(value: Maybe<&2,String>) -> Result<&2,&2,String,String>:
  match value:
    case Some{text}: Done{text}
    case None{}: Fail{"missing, duplicate or wrongly typed tool field"}

def typed_string(raw: Json.Json,key: String) -> Result<&2,&2,String,String>:
  typed_string_value(Typed.string(Typed.field(raw,key)))

def optional_string_value(value: Typed.Lookup) -> Result<&2,&2,String,String>:
  match value:
    case Typed.Missing{}: Done{""}
    case Typed.Found{Json.JString{text}}: Done{text}
    case _: Fail{"duplicate or wrongly typed optional tool field"}

def optional_string(raw: Json.Json,key: String) -> Result<&2,&2,String,String>:
  optional_string_value(Typed.field(raw,key))

def parse(text: String) -> Result<&2,&2,String,Json.Json>:
  Json.parse(text)

def exec_arguments(+raw: Json.Json) -> Result<&2,&2,String,Arguments>:
  do Result<&2,&2,String,Arguments>:
    text : String <- typed_string(raw,"cmd")
    directory : String <- optional_string(raw,"workdir")
    return Arguments{text,directory}
def arguments_kind(bash: Bool,exec: Bool,raw: Json.Json) -> Result<&2,&2,String,Arguments>:
  match bash exec:
    case True{} _:
      do Result<&2,&2,String,Arguments>:
        text : String <- typed_string(raw,"command")
        return Arguments{text,""}
    case False{} True{}: exec_arguments(raw)
    case False{} False{}: Fail{"unsupported command tool shape"}

def arguments(+tool: String,raw: Json.Json) -> Result<&2,&2,String,Arguments>:
  arguments_kind(String.eq(tool,"Bash"),String.eq(tool,"exec_command") ||
    String.eq(tool,"functions.exec_command"),raw)

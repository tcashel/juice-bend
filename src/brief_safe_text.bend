import Base

# Isolated continuation-brief text policy v1. Caller admits valid Unicode scalar
# text <=512 KiB UTF8 and bounded canonical root/source descriptors. No I/O.
# Credential/path counts name transformed fields (0 or1), not detected secrets.
# Whole-field withholding wins; controls in a withheld field are not emitted.
# This closed conservative policy does not establish that output is secret-free.
type Transform is Data:
  Transform{value: String,credential_fields: U32,path_fields: U32,control_scalars: U32}

type Replacement is Data:
  Replacement{remaining: String,value: String,matched: U32}

def policy() -> String:
  "brief-safe-text-v1"

def ascii_word(c: Char) -> Bool:
  Chr{+cp} = c
  (cp >= 48 && cp <= 57 : U32) || (cp >= 65 && cp <= 90 : U32) ||
    (cp >= 97 && cp <= 122 : U32) || U32.is_eq(cp,95) || U32.is_eq(cp,45)

def space(c: Char) -> Bool:
  Chr{+cp} = c
  (cp >= 9 && cp <= 13 : U32) || U32.is_eq(cp,32) || U32.is_eq(cp,133) ||
    U32.is_eq(cp,160) || U32.is_eq(cp,5760) || (cp >= 8192 && cp <= 8202 : U32) ||
    U32.is_eq(cp,8232) || U32.is_eq(cp,8233) || U32.is_eq(cp,8239) ||
    U32.is_eq(cp,8287) || U32.is_eq(cp,12288)

def delimiter(+c: Char) -> Bool:
  space(c) || Char.is_eq(c,'"') || Char.is_eq(c,'\'') || Char.is_eq(c,'`') ||
    Char.is_eq(c,'(') || Char.is_eq(c,')') || Char.is_eq(c,'[') || Char.is_eq(c,']') ||
    Char.is_eq(c,'{') || Char.is_eq(c,'}') || Char.is_eq(c,'<') || Char.is_eq(c,'>') ||
    Char.is_eq(c,',') || Char.is_eq(c,';') || Char.is_eq(c,'=') || Char.is_eq(c,':')

def prefix_next(equal: Bool,next: Unit -> Maybe<&2,String>) -> Maybe<&2,String>:
  match equal:
    case True{}: next(Unit{})
    case False{}: None{}

def after(+fold: Bool,prefix: String,text: String) -> Maybe<&2,String>:
  match prefix text:
    case SNil{} _: Some{text}
    case _ SNil{}: None{}
    case SCon{+p,pt} SCon{+c,ct}:
      prefix_next(Bool.pick(Bool,fold,Char.is_eq(Char.to_lower(p),Char.to_lower(c)),Char.is_eq(p,c)),
        _ => after(fold,pt,ct))

def exists(value: Maybe<&2,String>) -> Bool:
  match value:
    case Some{_}: True{}
    case None{}: False{}

def starts(text: String,prefix: String) -> Bool:
  exists(after(True{},prefix,text))

def token_after(value: Maybe<&2,String>) -> Bool:
  match value:
    case Some{SCon{c,_}}: ascii_word(c)
    case _: False{}

def value_start(text: String) -> Bool:
  match text:
    case SNil{}: False{}
    case SCon{+c,_}: Bool.not(space(c) || Char.is_eq(c,'"') || Char.is_eq(c,'\'') ||
      Char.is_eq(c,',') || Char.is_eq(c,'}') || Char.is_eq(c,']'))

def conditional(flag: Bool,yes: Unit -> Bool,no: Unit -> Bool) -> Bool:
  match flag:
    case True{}: yes(Unit{})
    case False{}: no(Unit{})

def quoted_value(text: String,quote: Char) -> Bool:
  match text:
    case SNil{}: False{}
    case SCon{c,_}: Bool.not(Char.is_eq(c,quote))

# At most32 whitespace/quote characters around a recorded key separator.
# Exceeding the tiny grammar is conservatively credential-shaped too.
def assigned_value(fuel: Nat,+text: String) -> Bool:
  match fuel text:
    case 0n _: True{}
    case _ SNil{}: False{}
    case 1n+n SCon{+c,+rest}:
      match c:
        case '"': quoted_value(rest,'"')
        case '\'': quoted_value(rest,'\'')
        case _: conditional(space(c),_ => assigned_value(n,rest),_ => value_start(text))

def assignment(fuel: Nat,text: String) -> Bool:
  match fuel text:
    case 0n _: True{}
    case _ SNil{}: False{}
    case 1n+n SCon{+c,rest}:
      match c:
        case ':': assigned_value(32n,rest)
        case '=': assigned_value(32n,rest)
        case '"': assignment(n,rest)
        case '\'': assignment(n,rest)
        case _: conditional(space(c),_ => assignment(n,rest),_ => False{})

def assigned(found: Maybe<&2,String>) -> Bool:
  match found:
    case Some{rest}: assignment(32n,rest)
    case None{}: False{}

def bearer_rest(found: Maybe<&2,String>) -> Bool:
  match found:
    case Some{SCon{+c,rest}}:
      conditional(space(c),_ => assigned_value(32n,rest),_ => False{})
    case _: False{}

def private_key(+text: String) -> Bool:
  starts(text,"-----BEGIN PRIVATE KEY-----") || starts(text,"-----BEGIN RSA PRIVATE KEY-----") ||
    starts(text,"-----BEGIN EC PRIVATE KEY-----") || starts(text,"-----BEGIN DSA PRIVATE KEY-----") ||
    starts(text,"-----BEGIN OPENSSH PRIVATE KEY-----") || starts(text,"-----BEGIN ENCRYPTED PRIVATE KEY-----")

def token_key(+text: String) -> Bool:
  token_after(after(True{},"sk-",text)) || token_after(after(True{},"ghp_",text)) ||
    token_after(after(True{},"github_pat_",text)) || token_after(after(True{},"xoxb-",text)) ||
    token_after(after(True{},"xoxa-",text)) || token_after(after(True{},"xoxp-",text)) ||
    token_after(after(True{},"xoxr-",text)) || token_after(after(True{},"xoxs-",text))

def named_key(+text: String) -> Bool:
  assigned(after(True{},"secret",text)) || assigned(after(True{},"password",text)) ||
    assigned(after(True{},"api_key",text)) || assigned(after(True{},"api-key",text)) ||
    assigned(after(True{},"access_token",text)) || assigned(after(True{},"access-token",text)) ||
    assigned(after(True{},"authorization",text)) || bearer_rest(after(True{},"bearer",text))

def userinfo(text: String) -> Bool:
  match text:
    case SNil{}: False{}
    case SCon{+c,rest}:
      match c:
        case '@': True{}
        case _: conditional(space(c) || Char.is_eq(c,'/') || Char.is_eq(c,'?') ||
          Char.is_eq(c,'#') || Char.is_eq(c,'"') || Char.is_eq(c,'\'') || Char.is_eq(c,'`') ||
          Char.is_eq(c,'<') || Char.is_eq(c,'>'),_ => False{},_ => userinfo(rest))

def url_credentials(found: Maybe<&2,String>) -> Bool:
  match found:
    case Some{rest}: userinfo(rest)
    case None{}: False{}

def credential_here(+text: String,previous: Char) -> Bool:
  private_key(text) || url_credentials(after(False{},"://",text)) ||
    (Bool.not(ascii_word(previous)) && (token_key(text) || named_key(text)))

def credential_step(found: Bool,next: Unit -> Bool) -> Bool:
  match found:
    case True{}: True{}
    case False{}: next(Unit{})

def credential(+text: String,previous: Char) -> Bool:
  match text:
    case SNil{}: False{}
    case SCon{+c,+rest}:
      credential_step(credential_here(text,previous),_ => credential(rest,c))

# Controls are displayed as literal lowercase backslash-uXXXX; the caller then
# JSON-quotes the complete field. Ordinary visible Unicode/Markdown is unchanged.
def control(c: Char) -> Bool:
  Chr{+cp} = c
  U32.is_lt(cp,32) || (cp >= 127 && cp <= 159 : U32) || U32.is_eq(cp,173) ||
    U32.is_eq(cp,847) || U32.is_eq(cp,1564) || U32.is_eq(cp,6158) ||
    (cp >= 8203 && cp <= 8207 : U32) || (cp >= 8232 && cp <= 8238 : U32) ||
    (cp >= 8288 && cp <= 8303 : U32) || U32.is_eq(cp,65279)

def path_boundary(+c: Char) -> Bool:
  delimiter(c) || control(c)

def hex(+n: U32) -> Char:
  Chr{Bool.pick(U32,U32.is_lt(n,10),U32.add(n,48),U32.add(n,87))}

def escaped(c: Char) -> String:
  Chr{+cp} = c
  "\\u" ++ SCon{hex(U32.mod(U32.div(cp,4096),16)),SCon{hex(U32.mod(U32.div(cp,256),16)),
    SCon{hex(U32.mod(U32.div(cp,16),16)),SCon{hex(U32.mod(cp,16)),SNil{}}}}}

def push(text: String,acc: String) -> String:
  match text:
    case SNil{}: acc
    case SCon{c,rest}: push(rest,SCon{c,acc})

def path_end(text: String) -> Bool:
  match text:
    case SNil{}: True{}
    case SCon{c,_}: path_boundary(c)

def root_end(text: String) -> Bool:
  match text:
    case SCon{'/',_}: True{}
    case other: path_end(other)

def source_match(found: Maybe<&2,String>,length: U32) -> Maybe<&2,Replacement>:
  match found:
    case None{}: None{}
    case Some{+rest}:
      Bool.pick(Maybe<&2,Replacement>,path_end(rest),Some{Replacement{rest,"[source]",length}},None{})

def root_match(found: Maybe<&2,String>,length: U32) -> Maybe<&2,Replacement>:
  match found:
    case None{}: None{}
    case Some{+rest}:
      Bool.pick(Maybe<&2,Replacement>,root_end(rest),Some{Replacement{rest,"[repository]",length}},None{})

def root_candidate(+root: String,text: String) -> Maybe<&2,Replacement>:
  match root:
    case "": None{}
    case "/": None{}
    case _: root_match(after(False{},root,text),U32.from_nat(String.length(root)))

def longer(best: Maybe<&2,Replacement>,candidate: Maybe<&2,Replacement>) -> Maybe<&2,Replacement>:
  match best candidate:
    case None{} value: value
    case value None{}: value
    case Some{Replacement{+a,+b,+n}} Some{Replacement{+x,+y,+m}}:
      Bool.pick(Maybe<&2,Replacement>,U32.is_gt(m,n),Some{Replacement{x,y,m}},Some{Replacement{a,b,n}})

def roots(values: List<&2,String>,+text: String,best: Maybe<&2,Replacement>) -> Maybe<&2,Replacement>:
  match values:
    case []: best
    case root <> rest: roots(rest,text,longer(best,root_candidate(root,text)))

def replacement_source(value: Maybe<&2,Replacement>,values: List<&2,String>,text: String) -> Maybe<&2,Replacement>:
  match value:
    case Some{value}: Some{value}
    case None{}: roots(values,text,None{})

def source_candidate(+source: String,text: String) -> Maybe<&2,Replacement>:
  match source:
    case "": None{}
    case _: source_match(after(False{},source,text),U32.from_nat(String.length(source)))

def replacement(values: List<&2,String>,source: String,+text: String) -> Maybe<&2,Replacement>:
  replacement_source(source_candidate(source,text),values,text)

# Absolute tokens that are not a proven known prefix are never guessed safe.
# Escaped slash/UNC/percent forms are intentionally conservative whole-field cases.
def escaped_path(+text: String) -> Bool:
  starts(text,"\\/") || starts(text,"\\\\") || starts(text,"\\u002f") || starts(text,"\\u005c") ||
    starts(text,"%2f") || starts(text,"%5c")

def home_user(fuel: Nat,text: String) -> Bool:
  match fuel text:
    case 0n _: True{}
    case _ SNil{}: False{}
    case 1n+n SCon{+c,rest}:
      match c:
        case '/': True{}
        case _: conditional(ascii_word(c),_ => home_user(n,rest),_ => False{})

def home_path(text: String) -> Bool:
  match text:
    case SCon{'~',rest}: home_user(64n,rest)
    case +other: starts(other,"$HOME/") || starts(other,"${HOME}/")

def drive_path(text: String) -> Bool:
  match text:
    case SCon{Chr{+cp},SCon{':',SCon{+slash,_}}}:
      ((cp >= 65 && cp <= 90 : U32) || (cp >= 97 && cp <= 122 : U32)) &&
        (Char.is_eq(slash,'/') || Char.is_eq(slash,'\\'))
    case _: False{}

def parent_end(found: Maybe<&2,String>) -> Bool:
  match found:
    case Some{SCon{'/',_}}: True{}
    case Some{rest}: path_end(rest)
    case None{}: False{}

def parent_tail(+text: String) -> Bool:
  parent_end(after(False{},"/..",text)) || parent_end(after(False{},"/.",text))

def unsafe_tail(+text: String) -> Bool:
  match text:
    case SNil{}: False{}
    case SCon{+c,rest}:
      conditional(Char.is_eq(c,'\\') || escaped_path(text) || parent_tail(text),_ => True{},
        _ => conditional(delimiter(c),_ => False{},_ => unsafe_tail(rest)))

def tag_letter(c: Char) -> Bool:
  Chr{+cp} = c
  (cp >= 65 && cp <= 90 : U32) || (cp >= 97 && cp <= 122 : U32)

def tag_tail(fuel: Nat,text: String) -> Bool:
  match fuel text:
    case 0n _: False{}
    case _ SNil{}: False{}
    case 1n+n SCon{+c,rest}:
      match c:
        case '>': True{}
        case _: conditional(ascii_word(c) || Char.is_eq(c,':'),_ => tag_tail(n,rest),_ => False{})

def closing_tag(text: String) -> Bool:
  match text:
    case SNil{}: False{}
    case SCon{c,rest}: conditional(tag_letter(c),_ => tag_tail(64n,rest),_ => False{})

# A complete simple closing markup tag is literal text, not an absolute path.
# Nested slashes/attributes/open tags never receive this small lexical exception.
def slash_path(text: String,+previous: Char) -> Bool:
  match text:
    case SCon{'/',+rest}:
      match rest:
        case SNil{}: False{}
        case SCon{+next,_}:
          path_boundary(previous) && Bool.not(path_boundary(next)) &&
            Bool.not(Char.is_eq(previous,':') && Char.is_eq(next,'/')) &&
            Bool.not(Char.is_eq(previous,'<') && closing_tag(rest))
    case _: False{}

def local_marker(+text: String,+previous: Char) -> Bool:
  escaped_path(text) || (path_boundary(previous) && (home_path(text) || drive_path(text) || starts(text,"file://")))

def path_withheld() -> Transform:
  Transform{"[local-path field withheld]",0,1,0}

type Cursor is Data:
  Cursor{text: String,previous: Char,acc: String,controls: U32,paths: Bool}

type Step is Data:
  Next{cursor: Cursor}
  Withheld{}

def step_control(yes: Bool,+c: Char,rest: String,acc: String,controls: U32,paths: Bool) -> Step:
  match yes:
    case True{}: Next{Cursor{rest,c,push(escaped(c),acc),U32.inc(controls),paths}}
    case False{}: Next{Cursor{rest,c,SCon{c,acc},controls,paths}}

def step_tail(bad: Bool,rest: String,value: String,acc: String,controls: U32) -> Step:
  match bad:
    case True{}: Withheld{}
    case False{}: Next{Cursor{rest,'x',push(value,acc),controls,True{}}}

def step_replacement(found: Maybe<&2,Replacement>,acc: String,controls: U32) -> Step:
  match found:
    case None{}: Withheld{}
    case Some{Replacement{+rest,value,matched}}: step_tail(unsafe_tail(rest),rest,value,acc,controls)

def step_path(path: Bool,text: String,values: List<&2,String>,source: String,+c: Char,rest: String,acc: String,controls: U32,paths: Bool) -> Step:
  match path:
    case True{}: step_replacement(replacement(values,source,text),acc,controls)
    case False{}: step_control(control(c),c,rest,acc,controls,paths)

def step_marker(bad: Bool,+text: String,values: List<&2,String>,source: String,+previous: Char,c: Char,rest: String,acc: String,controls: U32,paths: Bool) -> Step:
  match bad:
    case True{}: Withheld{}
    case False{}: step_path(slash_path(text,previous),text,values,source,c,rest,acc,controls,paths)

def resume(step: Step,next: Cursor -> Transform) -> Transform:
  match step:
    case Withheld{}: path_withheld()
    case Next{cursor}: next(cursor)

# Scalar traversal accumulates output in reverse; no repeated growing append.
# Fixed scalar fuel covers every admitted <=512KiB UTF8 input; each step consumes
# at least one scalar. Fuel exhaustion is an explicit unreachable-admission marker.
# Prefix comparisons are bounded by caller-owned descriptors and matched roots
# consume their bytes. Known source takes precedence; longest root wins.
def exhausted(cursor: Cursor) -> Transform:
  Cursor{+text,+previous,acc,controls,paths} = cursor
  match text:
    case SNil{}: Transform{String.reverse(acc),0,Bool.pick(U32,paths,1,0),controls}
    case _: Transform{"[inspection limit field withheld]",0,0,0}

def walk(fuel: Nat,cursor: Cursor,+values: List<&2,String>,+source: String) -> Transform:
  match fuel:
    case 0n: exhausted(cursor)
    case 1n+n:
      Cursor{+text,+previous,acc,controls,paths} = cursor
      match text:
        case SNil{}: Transform{String.reverse(acc),0,Bool.pick(U32,paths,1,0),controls}
        case SCon{+c,rest}:
          resume(step_marker(local_marker(text,previous),text,values,source,previous,c,rest,acc,controls,paths),
            next => walk(n,next,values,source))

def classified(secret: Bool,text: String,values: List<&2,String>,source: String) -> Transform:
  match secret:
    case True{}: Transform{"[credential-shaped field withheld]",1,0,0}
    case False{}: walk(524288n,Cursor{text,' ',"",0,False{}},values,source)

def transform(+text: String,roots: List<&2,String>,source: String) -> Transform:
  classified(credential(text,' '),text,roots,source)

import Base

# Bounded JSON parser. Original byte preservation is the capture layer's job.
# Numbers stay lexical; there is deliberately no F32 conversion.
type Field is Data:
  JField{key: String, value: Json}

type Json is Data:
  JNull{}
  JBool{value: Bool}
  JNumber{lexeme: String}
  JString{value: String}
  JArray{items: List<&2, Json>}
  JObject{fields: List<&2, Field>}

type Token is Data:
  JTValue{value: Json}
  JTOpenArray{}
  JTCloseArray{}
  JTOpenObject{}
  JTCloseObject{}
  JTColon{}
  JTComma{}

type Lexer is Data:
  JLBase{tokens: List<&2, Token>}
  JLString{rev: String, tokens: List<&2, Token>}
  JLEscape{rev: String, tokens: List<&2, Token>}
  JLUnicode{left: Nat, value: U32, high: U32, rev: String, tokens: List<&2, Token>}
  JLSurrogateSlash{high: U32, rev: String, tokens: List<&2, Token>}
  JLSurrogateU{high: U32, rev: String, tokens: List<&2, Token>}
  JLAtom{rev: String, tokens: List<&2, Token>}

def is_space(+c: U32) -> Bool:
  Bool.or(U32.is_eq(c, 32), Bool.or(U32.is_eq(c, 9), Bool.or(U32.is_eq(c, 10), U32.is_eq(c, 13))))

def is_digit(+c: U32) -> Bool:
  Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57))

def digit_state(c: U32, yes: U32) -> U32:
  Bool.pick(U32, is_digit(c), yes, 99)

def number_step(state: U32, +c: U32) -> U32:
  match state:
    case 0:
      Bool.pick(U32, U32.is_eq(c, 45), 1, Bool.pick(U32, U32.is_eq(c, 48), 2, Bool.pick(U32, Bool.and(U32.is_ge(c, 49), U32.is_le(c, 57)), 3, 99)))
    case 1:
      Bool.pick(U32, U32.is_eq(c, 48), 2, Bool.pick(U32, Bool.and(U32.is_ge(c, 49), U32.is_le(c, 57)), 3, 99))
    case 2:
      Bool.pick(U32, U32.is_eq(c, 46), 4, Bool.pick(U32, Bool.or(U32.is_eq(c, 101), U32.is_eq(c, 69)), 6, 99))
    case 3:
      Bool.pick(U32, is_digit(c), 3, Bool.pick(U32, U32.is_eq(c, 46), 4, Bool.pick(U32, Bool.or(U32.is_eq(c, 101), U32.is_eq(c, 69)), 6, 99)))
    case 4:
      digit_state(c, 5)
    case 5:
      Bool.pick(U32, is_digit(c), 5, Bool.pick(U32, Bool.or(U32.is_eq(c, 101), U32.is_eq(c, 69)), 6, 99))
    case 6:
      Bool.pick(U32, Bool.or(U32.is_eq(c, 43), U32.is_eq(c, 45)), 7, digit_state(c, 8))
    case 7:
      digit_state(c, 8)
    case 8:
      digit_state(c, 8)
    case _:
      99

def number_valid(s: String, +state: U32) -> Bool:
  match s:
    case SNil{}:
      Bool.or(U32.is_eq(state, 2), Bool.or(U32.is_eq(state, 3), Bool.or(U32.is_eq(state, 5), U32.is_eq(state, 8))))
    case SCon{Chr{c}, t}:
      number_valid(t, number_step(state, c))

def number_token(s: String, valid: Bool) -> Result<&2, &2, String, Token>:
  match valid:
    case True{}:
      Done{JTValue{JNumber{s}}}
    case False{}:
      Fail{"invalid JSON literal or number"}

def atom(+s: String) -> Result<&2, &2, String, Token>:
  match s:
    case "null":
      Done{JTValue{JNull{}}}
    case "true":
      Done{JTValue{JBool{True{}}}}
    case "false":
      Done{JTValue{JBool{False{}}}}
    case _:
      number_token(s, number_valid(s, 0))

def base_other(c: U32, tokens: List<&2, Token>, space: Bool) -> Result<&2, &2, String, Lexer>:
  match space:
    case True{}:
      Done{JLBase{tokens}}
    case False{}:
      Done{JLAtom{SCon{Chr{c}, SNil{}}, tokens}}

def base(+c: U32, tokens: List<&2, Token>) -> Result<&2, &2, String, Lexer>:
  match c:
    case 34:
      Done{JLString{"", tokens}}
    case 91:
      Done{JLBase{JTOpenArray{} <> tokens}}
    case 93:
      Done{JLBase{JTCloseArray{} <> tokens}}
    case 123:
      Done{JLBase{JTOpenObject{} <> tokens}}
    case 125:
      Done{JLBase{JTCloseObject{} <> tokens}}
    case 58:
      Done{JLBase{JTColon{} <> tokens}}
    case 44:
      Done{JLBase{JTComma{} <> tokens}}
    case _:
      base_other(c, tokens, is_space(c))

def scalar(+c: U32) -> Bool:
  Bool.and(U32.is_le(c, 1114111), Bool.not(Bool.and(U32.is_ge(c, 55296), U32.is_le(c, 57343))))

def string_other(c: U32, rev: String, tokens: List<&2, Token>, valid: Bool) -> Result<&2, &2, String, Lexer>:
  match valid:
    case True{}:
      Done{JLString{SCon{Chr{c}, rev}, tokens}}
    case False{}:
      Fail{"unescaped control or invalid Unicode scalar in JSON string"}

def string_step(+c: U32, rev: String, tokens: List<&2, Token>) -> Result<&2, &2, String, Lexer>:
  match c:
    case 34:
      Done{JLBase{JTValue{JString{String.reverse(rev)}} <> tokens}}
    case 92:
      Done{JLEscape{rev, tokens}}
    case _:
      string_other(c, rev, tokens, Bool.and(U32.is_ge(c, 32), scalar(c)))

def escape(c: U32, rev: String, tokens: List<&2, Token>) -> Result<&2, &2, String, Lexer>:
  match c:
    case 34:
      Done{JLString{SCon{Chr{34}, rev}, tokens}}
    case 92:
      Done{JLString{SCon{Chr{92}, rev}, tokens}}
    case 47:
      Done{JLString{SCon{Chr{47}, rev}, tokens}}
    case 98:
      Done{JLString{SCon{Chr{8}, rev}, tokens}}
    case 102:
      Done{JLString{SCon{Chr{12}, rev}, tokens}}
    case 110:
      Done{JLString{SCon{Chr{10}, rev}, tokens}}
    case 114:
      Done{JLString{SCon{Chr{13}, rev}, tokens}}
    case 116:
      Done{JLString{SCon{Chr{9}, rev}, tokens}}
    case 117:
      Done{JLUnicode{4n, 0, 0, rev, tokens}}
    case _:
      Fail{"invalid JSON escape"}

def hex(+c: U32) -> U32:
  Bool.pick(U32, is_digit(c), U32.sub(c, 48), Bool.pick(U32, Bool.and(U32.is_ge(c, 65), U32.is_le(c, 70)), U32.sub(c, 55), Bool.pick(U32, Bool.and(U32.is_ge(c, 97), U32.is_le(c, 102)), U32.sub(c, 87), 99)))

def unicode_low(value: U32, high: U32, rev: String, tokens: List<&2, Token>, valid: Bool) -> Result<&2, &2, String, Lexer>:
  match valid:
    case True{}:
      Done{JLString{SCon{Chr{U32.add(65536, U32.add(U32.mul(U32.sub(high, 55296), 1024), U32.sub(value, 56320)))}, rev}, tokens}}
    case False{}:
      Fail{"high surrogate requires a low surrogate"}

def unicode_single(value: U32, rev: String, tokens: List<&2, Token>, high: Bool) -> Result<&2, &2, String, Lexer>:
  match high:
    case True{}:
      Done{JLSurrogateSlash{value, rev, tokens}}
    case False{}:
      +v = value
      string_other(v, rev, tokens, scalar(v))

def unicode_done(+value: U32, high: U32, rev: String, tokens: List<&2, Token>) -> Result<&2, &2, String, Lexer>:
  match high:
    case 0:
      unicode_single(value, rev, tokens, Bool.and(U32.is_ge(value, 55296), U32.is_le(value, 56319)))
    case _:
      unicode_low(value, high, rev, tokens, Bool.and(U32.is_ge(value, 56320), U32.is_le(value, 57343)))

def unicode_remaining(left: Nat, value: U32, high: U32, rev: String, tokens: List<&2, Token>) -> Result<&2, &2, String, Lexer>:
  match left:
    case 0n:
      unicode_done(value, high, rev, tokens)
    case 1n+p:
      Done{JLUnicode{1n+p, value, high, rev, tokens}}

def unicode_digit(left: Nat, value: U32, high: U32, rev: String, tokens: List<&2, Token>, digit: U32) -> Result<&2, &2, String, Lexer>:
  match left digit:
    case 0n _:
      Fail{"internal Unicode parser state"}
    case 1n+p 99:
      Fail{"invalid hexadecimal JSON escape"}
    case 1n+p _:
      unicode_remaining(p, U32.add(U32.mul(value, 16), digit), high, rev, tokens)

def delimiter(+c: U32) -> Bool:
  Bool.or(is_space(c), Bool.or(U32.is_eq(c, 44), Bool.or(U32.is_eq(c, 93), Bool.or(U32.is_eq(c, 125), Bool.or(U32.is_eq(c, 58), Bool.or(U32.is_eq(c, 91), Bool.or(U32.is_eq(c, 123), U32.is_eq(c, 34))))))))

def atom_step(c: U32, rev: String, tokens: List<&2, Token>, delimiter: Bool) -> Result<&2, &2, String, Lexer>:
  match delimiter:
    case False{}:
      Done{JLAtom{SCon{Chr{c}, rev}, tokens}}
    case True{}:
      do Result<&2, &2, String, Lexer>:
        token : Token <- atom(String.reverse(rev))
        base(c, token <> tokens)

def lex_step(state: Lexer, +c: U32) -> Result<&2, &2, String, Lexer>:
  match state:
    case JLBase{tokens}:
      base(c, tokens)
    case JLString{rev, tokens}:
      string_step(c, rev, tokens)
    case JLEscape{rev, tokens}:
      escape(c, rev, tokens)
    case JLUnicode{left, value, high, rev, tokens}:
      unicode_digit(left, value, high, rev, tokens, hex(c))
    case JLSurrogateSlash{high, rev, tokens}:
      Bool.pick(Result<&2, &2, String, Lexer>, U32.is_eq(c, 92), Done{JLSurrogateU{high, rev, tokens}}, Fail{"high surrogate requires escaped low surrogate"})
    case JLSurrogateU{high, rev, tokens}:
      Bool.pick(Result<&2, &2, String, Lexer>, U32.is_eq(c, 117), Done{JLUnicode{4n, 0, high, rev, tokens}}, Fail{"high surrogate requires Unicode escape"})
    case JLAtom{rev, tokens}:
      atom_step(c, rev, tokens, delimiter(c))

def lex_end(state: Lexer) -> Result<&2, &2, String, List<&2, Token>>:
  match state:
    case JLBase{tokens}:
      Done{List.reverse(&2, Token, tokens)}
    case JLAtom{rev, tokens}:
      do Result<&2, &2, String, List<&2, Token>>:
        token : Token <- atom(String.reverse(rev))
        return List.reverse(&2, Token, token <> tokens)
    case _:
      Fail{"incomplete JSON string or escape"}

def lex(s: String, state: Lexer, budget: Nat) -> Result<&2, &2, String, List<&2, Token>>:
  match s budget:
    case SNil{} _:
      lex_end(state)
    case SCon{h, t} 0n:
      Fail{"JSON record exceeds 1048576 decoded characters"}
    case SCon{Chr{c}, t} 1n+p:
      do Result<&2, &2, String, List<&2, Token>>:
        next : Lexer <- lex_step(state, c)
        lex(t, next, p)

type Frame is Data:
  JFRoot{}
  JFResult{value: Json}
  JFArray{values: List<&2, Json>, phase: U32}
  JFObject{fields: List<&2, Field>, seen: Map<&2, Unit>, key: String, phase: U32}

def attach_array(values: List<&2, Json>, phase: U32, value: Json, rest: List<&2, Frame>) -> Result<&2, &2, String, List<&2, Frame>>:
  match phase:
    case 0:
      Done{JFArray{value <> values, 2} <> rest}
    case 1:
      Done{JFArray{value <> values, 2} <> rest}
    case _:
      Fail{"expected comma or array end"}

def object_key_checked(fields: List<&2, Field>, +key: String, rest: List<&2, Frame>, seen: Map<&2, Unit>, duplicate: Bool) -> Result<&2, &2, String, List<&2, Frame>>:
  match duplicate:
    case True{}:
      Fail{"duplicate JSON object key"}
    case False{}:
      Done{JFObject{fields, Map.set(&2, Unit, seen, key, Unit{}), key, 2} <> rest}

def object_key(fields: List<&2, Field>, key: String, rest: List<&2, Frame>, checked: Map<&2, Unit> & Bool) -> Result<&2, &2, String, List<&2, Frame>>:
  match checked:
    case Tuple{seen, duplicate}:
      object_key_checked(fields, key, rest, seen, duplicate)

def attach_object(fields: List<&2, Field>, seen: Map<&2, Unit>, key: String, phase: U32, value: Json, rest: List<&2, Frame>) -> Result<&2, &2, String, List<&2, Frame>>:
  match phase value:
    case 0 JString{+text}:
      object_key(fields, text, rest, Map.has(&2, Unit, seen, text))
    case 1 JString{+text}:
      object_key(fields, text, rest, Map.has(&2, Unit, seen, text))
    case 3 _:
      Done{JFObject{JField{key, value} <> fields, seen, "", 4} <> rest}
    case _ _:
      Fail{"expected object key, colon, comma or end"}

def attach(stack: List<&2, Frame>, value: Json) -> Result<&2, &2, String, List<&2, Frame>>:
  match stack:
    case Nil{}:
      Fail{"invalid JSON parser stack"}
    case Con{JFRoot{}, rest}:
      Done{JFResult{value} <> rest}
    case Con{JFResult{old}, rest}:
      Fail{"trailing JSON content"}
    case Con{JFArray{values, phase}, rest}:
      attach_array(values, phase, value, rest)
    case Con{JFObject{fields, seen, key, phase}, rest}:
      attach_object(fields, seen, key, phase, value, rest)

def expect(stack: List<&2, Frame>) -> Bool:
  match stack:
    case Con{JFRoot{}, rest}:
      True{}
    case Con{JFArray{values, +phase}, rest}:
      Bool.or(U32.is_eq(phase, 0), U32.is_eq(phase, 1))
    case Con{JFObject{fields, seen, key, phase}, rest}:
      U32.is_eq(phase, 3)
    case _:
      False{}

def push_allowed(stack: List<&2, Frame>, frame: Frame, allowed: Bool) -> Result<&2, &2, String, List<&2, Frame>>:
  match allowed:
    case True{}:
      Done{frame <> stack}
    case False{}:
      Fail{"unexpected container or JSON depth exceeds 64"}

def push(+stack: List<&2, Frame>, frame: Frame) -> Result<&2, &2, String, List<&2, Frame>>:
  push_allowed(stack, frame, Bool.and(expect(stack), Nat.is_le(List.length(&2, Frame, stack), 64n)))

def close_array(stack: List<&2, Frame>) -> Result<&2, &2, String, List<&2, Frame>>:
  match stack:
    case Con{JFArray{values, 0}, rest}:
      attach(rest, JArray{List.reverse(&2, Json, values)})
    case Con{JFArray{values, 2}, rest}:
      attach(rest, JArray{List.reverse(&2, Json, values)})
    case _:
      Fail{"unexpected array end or trailing comma"}

def close_object(stack: List<&2, Frame>) -> Result<&2, &2, String, List<&2, Frame>>:
  match stack:
    case Con{JFObject{fields, seen, key, 0}, rest}:
      attach(rest, JObject{List.reverse(&2, Field, fields)})
    case Con{JFObject{fields, seen, key, 4}, rest}:
      attach(rest, JObject{List.reverse(&2, Field, fields)})
    case _:
      Fail{"unexpected object end or trailing comma"}

def colon(stack: List<&2, Frame>) -> Result<&2, &2, String, List<&2, Frame>>:
  match stack:
    case Con{JFObject{fields, seen, key, 2}, rest}:
      Done{JFObject{fields, seen, key, 3} <> rest}
    case _:
      Fail{"unexpected colon"}

def comma(stack: List<&2, Frame>) -> Result<&2, &2, String, List<&2, Frame>>:
  match stack:
    case Con{JFArray{values, 2}, rest}:
      Done{JFArray{values, 1} <> rest}
    case Con{JFObject{fields, seen, key, 4}, rest}:
      Done{JFObject{fields, seen, key, 1} <> rest}
    case _:
      Fail{"unexpected comma"}

def consume(token: Token, stack: List<&2, Frame>) -> Result<&2, &2, String, List<&2, Frame>>:
  match token:
    case JTValue{value}:
      attach(stack, value)
    case JTOpenArray{}:
      push(stack, JFArray{[], 0})
    case JTOpenObject{}:
      push(stack, JFObject{[], Map.new(&2, Unit), "", 0})
    case JTCloseArray{}:
      close_array(stack)
    case JTCloseObject{}:
      close_object(stack)
    case JTColon{}:
      colon(stack)
    case JTComma{}:
      comma(stack)

def tree_end(stack: List<&2, Frame>) -> Result<&2, &2, String, Json>:
  match stack:
    case Con{JFResult{value}, Nil{}}:
      Done{value}
    case _:
      Fail{"empty or incomplete JSON"}

def tree(tokens: List<&2, Token>, stack: List<&2, Frame>) -> Result<&2, &2, String, Json>:
  match tokens:
    case Nil{}:
      tree_end(stack)
    case Con{token, rest}:
      do Result<&2, &2, String, Json>:
        next : List<&2, Frame> <- consume(token, stack)
        tree(rest, next)

def parse(raw: String) -> Result<&2, &2, String, Json>:
  do Result<&2, &2, String, Json>:
    tokens : List<&2, Token> <- lex(raw, JLBase{[]}, 1048576n)
    tree(tokens, [JFRoot{}])

# Parsing rejects duplicate object keys; field lookup sees unambiguous objects.
def field_scan(fields: List<&2, Field>, +name: String, found: Maybe<&2, Json>) -> Maybe<&2, Json>:
  match fields:
    case Nil{}:
      found
    case Con{JField{key, value}, rest}:
      field_scan(rest, name, Bool.pick(Maybe<&2, Json>, String.eq(key, name), Some{value}, found))

def field_result(value: Maybe<&2, Json>) -> Json:
  match value:
    case Some{value}:
      value
    case None{}:
      JNull{}

def field(value: Json, name: String) -> Json:
  match value:
    case JObject{fields}:
      field_result(field_scan(fields, name, None{}))
    case _:
      JNull{}

def text(value: Json) -> String:
  match value:
    case JString{text}:
      text
    case JNumber{text}:
      text
    case JBool{True{}}:
      "true"
    case JBool{False{}}:
      "false"
    case _:
      ""

def get(value: Json, name: String) -> String:
  text(field(value, name))

def items(value: Json) -> List<&2, Json>:
  match value:
    case JArray{items}:
      items
    case _:
      []

def hex_char(+n: U32) -> Char:
  Chr{Bool.pick(U32, U32.is_lt(n, 10), U32.add(n, 48), U32.add(n, 87))}

def escape_char(+c: U32) -> String:
  match c:
    case 34:
      "\\\""
    case 92:
      "\\\\"
    case _:
      Bool.pick(String, U32.is_lt(c, 32), "\\u00" ++ SCon{hex_char(U32.div(c, 16)), SCon{hex_char(U32.mod(c, 16)), SNil{}}}, SCon{Chr{c}, SNil{}})

def escape_string(text: String) -> String:
  match text:
    case SNil{}:
      ""
    case SCon{Chr{c}, rest}:
      escape_char(c) ++ escape_string(rest)

def quote(text: String) -> String:
  "\"" ++ escape_string(text) ++ "\""

# Iterative encoder traverses a work list, avoiding mutually recursive helpers.
type Encode is Data:
  JEValue{value: Json}
  JEText{text: String}

def array_work(items: List<&2, Json>) -> List<&2, Encode>:
  match items:
    case Nil{}:
      []
    case Con{item, Nil{}}:
      [JEValue{item}]
    case Con{item, rest}:
      JEValue{item} <> JEText{","} <> array_work(rest)

def object_work(fields: List<&2, Field>) -> List<&2, Encode>:
  match fields:
    case Nil{}:
      []
    case Con{JField{key, value}, Nil{}}:
      [JEText{quote(key)}, JEText{":"}, JEValue{value}]
    case Con{JField{key, value}, rest}:
      JEText{quote(key)} <> JEText{":"} <> JEValue{value} <> JEText{","} <> object_work(rest)

def expand(value: Json) -> List<&2, Encode>:
  match value:
    case JNull{}:
      [JEText{"null"}]
    case JBool{True{}}:
      [JEText{"true"}]
    case JBool{False{}}:
      [JEText{"false"}]
    case JNumber{lexeme}:
      [JEText{lexeme}]
    case JString{text}:
      [JEText{quote(text)}]
    case JArray{items}:
      JEText{"["} <> List.append(&2, Encode, array_work(items), [JEText{"]"}])
    case JObject{fields}:
      JEText{"{"} <> List.append(&2, Encode, object_work(fields), [JEText{"}"}])

def encode_loop(fuel: Nat, work: List<&2, Encode>, acc: List<&2, String>) -> Result<&2, &2, String, String>:
  match fuel work:
    case _ Nil{}:
      Done{String.concat(List.reverse(&2, String, acc))}
    case 0n _:
      Fail{"JSON encoding traversal limit exceeded"}
    case 1n+p Con{JEText{text}, rest}:
      encode_loop(p, rest, text <> acc)
    case 1n+p Con{JEValue{value}, rest}:
      encode_loop(p, List.append(&2, Encode, expand(value), rest), acc)

# This budget exceeds the traversal count of every value accepted by parse.
# Call encode_checked for larger application-constructed trees.
def encode_checked(value: Json) -> Result<&2, &2, String, String>:
  encode_loop(8388608n, [JEValue{value}], [])

def encoded_text(result: Result<&2, &2, String, String>) -> String:
  match result:
    case Done{text}:
      text
    case Fail{error}:
      "{\"error\":" ++ quote(error) ++ "}"

def encode(value: Json) -> String:
  encoded_text(encode_checked(value))

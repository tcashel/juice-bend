import Base
import ./json.bend as Json

# Classifies references only. No effect, lookup, file read, decoder, network,
# filesystem authorization, or claim about external availability occurs here.
type InlineCheck is Data:
  ValidBase64{encoded_chars: U32,decoded_bytes: U32}
  InvalidBase64{reason: String}

type Reference is Data:
  LocalPath{original: String}
  LocalFileURL{original: String}
  RemoteURL{original: String}
  InlineData{media_type: String,encoding: String,check: InlineCheck}
  UnsupportedReference{reason: String}

def utf8_width(+cp: U32) -> U32:
  Bool.pick(U32,U32.is_lt(cp,128),1,
    Bool.pick(U32,U32.is_lt(cp,2048),2,Bool.pick(U32,U32.is_lt(cp,65536),3,4)))

def bounded_next(ok: Bool,left: U32,next: U32 -> Bool) -> Bool:
  match ok:
    case False{}: False{}
    case True{}: next(left)

def bounded(text: String,+left: U32) -> Bool:
  match text:
    case SNil{}: True{}
    case SCon{Chr{+cp},rest}:
      +width = utf8_width(cp)
      bounded_next(U32.is_ne(cp,0) && U32.is_le(cp,1114111) &&
        Bool.not(U32.is_ge(cp,55296) && U32.is_le(cp,57343)) && U32.is_le(width,left),
        U32.sub(left,width),remaining => bounded(rest,remaining))

def sextet(+cp: U32) -> U32:
  Bool.pick(U32,U32.is_ge(cp,65) && U32.is_le(cp,90),U32.sub(cp,65),
    Bool.pick(U32,U32.is_ge(cp,97) && U32.is_le(cp,122),U32.add(U32.sub(cp,97),26),
      Bool.pick(U32,U32.is_ge(cp,48) && U32.is_le(cp,57),U32.add(U32.sub(cp,48),52),
        Bool.pick(U32,U32.is_eq(cp,43),62,Bool.pick(U32,U32.is_eq(cp,47),63,99)))))

def padded(valid: Bool,encoded: U32,decoded: U32) -> InlineCheck:
  Bool.pick(InlineCheck,valid,ValidBase64{encoded,decoded},
    InvalidBase64{"invalid_base64_padding"})

def quad_plain(valid: Bool,tail: String,encoded: U32,decoded: U32,
  next: String -> U32 -> U32 -> InlineCheck) -> InlineCheck:
  match valid:
    case False{}: InvalidBase64{"invalid_base64_alphabet"}
    case True{}: next(tail,encoded,U32.add(decoded,3))

def quad_padding(c_pad: Bool,d_pad: Bool,b: U32,c: U32,d: U32,tail: String,encoded: U32,decoded: U32,
  next: String -> U32 -> U32 -> InlineCheck) -> InlineCheck:
  match c_pad d_pad:
    case True{} True{}:
      padded(String.is_empty(tail) && U32.is_eq(U32.and(b,15),0),encoded,U32.add(decoded,1))
    case True{} False{}: InvalidBase64{"invalid_base64_padding"}
    case False{} True{}:
      +v = sextet(c)
      padded(String.is_empty(tail) && U32.is_lt(v,64) && U32.is_eq(U32.and(v,3),0),encoded,U32.add(decoded,2))
    case False{} False{}:
      quad_plain(U32.is_lt(sextet(c),64) && U32.is_lt(sextet(d),64),tail,encoded,decoded,next)

def quad(valid: Bool,b: U32,+c: U32,+d: U32,tail: String,encoded: U32,decoded: U32,
  next: String -> U32 -> U32 -> InlineCheck) -> InlineCheck:
  match valid:
    case False{}: InvalidBase64{"invalid_base64_alphabet"}
    case True{}:
      quad_padding(U32.is_eq(c,61),U32.is_eq(d,61),b,c,d,tail,encoded,decoded,next)

def base64_scan(fuel: Nat,text: String,encoded: U32,decoded: U32) -> InlineCheck:
  match fuel text:
    case _ SNil{}: ValidBase64{encoded,decoded}
    case 0n _: InvalidBase64{"inline_encoding_limit"}
    case 1n+left SCon{Chr{a},SCon{Chr{+b},SCon{Chr{c},SCon{Chr{d},tail}}}}:
      quad(U32.is_lt(sextet(a),64) && U32.is_lt(sextet(b),64),sextet(b),c,d,tail,U32.add(encoded,4),decoded,
        rest => size => count => base64_scan(left,rest,size,count))
    case _ _: InvalidBase64{"invalid_base64_length"}

def base64(text: String) -> InlineCheck:
  base64_scan(262144n,text,0,0)

def media_char(+cp: U32) -> Bool:
  (U32.is_ge(cp,65) && U32.is_le(cp,90)) ||
    (U32.is_ge(cp,97) && U32.is_le(cp,122)) ||
    (U32.is_ge(cp,48) && U32.is_le(cp,57)) ||
    U32.is_eq(cp,47) || U32.is_eq(cp,45) || U32.is_eq(cp,43) ||
    U32.is_eq(cp,46) || U32.is_eq(cp,95)

def media_chars(text: String) -> Bool:
  match text:
    case SNil{}: True{}
    case SCon{Chr{cp},rest}: media_char(cp) && media_chars(rest)

def media_type(+text: String) -> Bool:
  bounded(text,127) && media_chars(text) &&
    Bool.not(String.starts_with(text,"/")) && Bool.not(String.ends_with(text,"/")) &&
    (String.is_empty(text) || Nat.is_eq(List.length(&2,String,String.split(text,'/')),2n))

def inline(+media: String,data: Json.Json) -> Reference:
  match data:
    case Json.JString{text}:
      Bool.pick(Reference,media_type(media),InlineData{media,"base64",base64(text)},
        UnsupportedReference{"invalid_media_type"})
    case _:
      UnsupportedReference{"inline_data_not_string"}

def data_parts(parts: List<&2,String>,data: String) -> Reference:
  match parts:
    case [media "base64"]:
      inline(media,Json.JString{data})
    case _:
      UnsupportedReference{"unsupported_data_url_encoding"}

def data_header(header: String,data: String) -> Reference:
  data_parts(String.split(header,';'),data)

def data_url_scan(fuel: Nat,text: String,reverse_header: String) -> Reference:
  match fuel text:
    case _ SNil{}: UnsupportedReference{"data_url_missing_comma"}
    case 0n _: UnsupportedReference{"data_url_header_limit"}
    case 1n+left SCon{',',rest}: data_header(String.reverse(reverse_header),rest)
    case 1n+left SCon{c,rest}: data_url_scan(left,rest,SCon{c,reverse_header})

def url_known_checked(is_data: Bool,+text: String) -> Reference:
  match is_data:
    case True{}: data_url_scan(256n,String.drop(text,5n),"")
    case False{}:
      Bool.pick(Reference,String.starts_with(text,"/"),LocalPath{text},
        Bool.pick(Reference,String.starts_with(text,"file:///") || String.starts_with(text,"file://localhost/"),LocalFileURL{text},
          Bool.pick(Reference,(String.starts_with(text,"https://") && Nat.is_gt(String.length(text),8n)) ||
            (String.starts_with(text,"http://") && Nat.is_gt(String.length(text),7n)),RemoteURL{text},
            UnsupportedReference{"unsupported_reference_scheme_or_relative_path"})))

def url_known(+text: String) -> Reference:
  url_known_checked(String.starts_with(text,"data:"),text)

def url_string(is_data: Bool,+text: String) -> Reference:
  match is_data:
    case True{}: url_known(text)
    case False{}:
      Bool.pick(Reference,bounded(text,4096),url_known(text),UnsupportedReference{"reference_text_limit_or_invalid_scalar"})

def url(value: Json.Json) -> Reference:
  match value:
    case Json.JString{+text}:
      url_string(String.starts_with(text,"data:"),text)
    case _: UnsupportedReference{"reference_not_string"}

def source_inline(media: Json.Json,data: Json.Json) -> Reference:
  match media:
    case Json.JNull{}: inline("",data)
    case Json.JString{media}: inline(media,data)
    case _: UnsupportedReference{"media_type_not_string"}

def local_only(reference: Reference) -> Reference:
  match reference:
    case LocalPath{path}: LocalPath{path}
    case LocalFileURL{path}: LocalFileURL{path}
    case _: UnsupportedReference{"file_source_not_local_path"}

def source_type(kind: String,+source: Json.Json) -> Reference:
  match kind:
    case "base64":
      source_inline(Json.field(source,"media_type"),Json.field(source,"data"))
    case "file":
      local_only(url(Json.field(source,"path")))
    case "url": url(Json.field(source,"url"))
    case _: UnsupportedReference{"unsupported_attachment_source_type"}

def source(value: Json.Json) -> Reference:
  match value:
    case Json.JObject{+fields}:
      source_type(Json.get(Json.JObject{fields},"type"),Json.JObject{fields})
    case _: UnsupportedReference{"attachment_source_not_object"}

# This compact human-readable description never copies paths, URLs or encoded
# data. Exact bounded local/remote references remain typed data for later policy.
def summary(value: Reference) -> String:
  match value:
    case LocalPath{_}: "Local file reference; external bytes not captured"
    case LocalFileURL{_}: "Local file URL; external bytes not captured"
    case RemoteURL{_}: "Remote reference; never fetched"
    case InlineData{_,_,ValidBase64{_,count}}:
      "Inline bytes retained in raw record; valid base64, " ++ U32.show(count) ++ " decoded bytes"
    case InlineData{_,_,InvalidBase64{reason}}:
      "Inline data retained in raw record; " ++ reason
    case UnsupportedReference{reason}: "Unsupported attachment reference: " ++ reason

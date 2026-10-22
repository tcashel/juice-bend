import Base
import ../src/atif_command.bend as C
import ../src/atif_types.bend as T
import ../src/json.bend as J
import ../src/attachment_refs.bend as Ref

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def accepted(value: Result<&2,&2,String,C.Command>) -> Bool:
  match value:
    case Done{_}: True{}
    case Fail{_}: False{}

def decoded(value: Result<&2,&2,String,J.Json>) -> J.Json:
  match value:
    case Done{json}: json
    case Fail{_}: J.JNull{}

def ack(value: Result<&2,&2,String,String>) -> J.Json:
  match value:
    case Done{text}: decoded(J.parse(text))
    case Fail{_}: J.JNull{}

def refused(value: Result<&2,&2,String,String>) -> Bool:
  match value:
    case Done{_}: False{}
    case Fail{_}: True{}

def repeat(n: Nat,+s: String) -> String:
  match n:
    case 0n: ""
    case 1n+p: s ++ repeat(p,s)

def request() -> C.Command: C.Command{"9007199254740993","/tmp/café 中文 🙂.atif.json"}
def receipt() -> T.Receipt: T.Receipt{"9007199254740993","/private/tmp/café 中文 🙂.atif.json",100,101,99,8000}

def main() -> IO(Unit):
  +value = ack(C.acknowledge(request(),"/private/tmp/café 中文 🙂.atif.json",receipt()))
  do IO<Unit>:
    require(accepted(C.parse(["9223372036854775807","output.atif.json"])),"command accepts exact signed64 identity and explicit relative destination")
    require(accepted(C.parse(["7","/tmp/café 中文 🙂.atif.json"])),"command retains Unicode path as literal data")
    require(Bool.not(accepted(C.parse(["7","out","extra"]))) && Bool.not(accepted(C.parse(["7"]))),"command rejects missing and trailing arguments")
    require(Bool.not(accepted(C.parse(["0","out"]))) && Bool.not(accepted(C.parse(["07","out"]))) && Bool.not(accepted(C.parse(["9223372036854775808","out"]))),"zero noncanonical and overflow identities are refused")
    require(Bool.not(accepted(C.parse([repeat(100n,"1"),"out"]))),"oversized identity is bounded before decimal parsing")
    require(Bool.not(C.path("")) && Bool.not(C.path("/tmp/")) && Bool.not(C.path(".")) && Bool.not(C.path("/tmp/..")),"empty and directory-only destinations are refused")
    require(Bool.not(C.path("/tmp/a\0b")) && Bool.not(C.path(SCon{Chr{55296},SNil{}})),"NUL and invalid Unicode destinations are refused")
    require(C.path("/tmp/" ++ repeat(244n,"x")) && Bool.not(C.path("/tmp/" ++ repeat(245n,"x"))),"leaf reserves exactly eleven bytes for private staging suffix")
    require(C.path("/tmp/" ++ repeat(122n,"é")) && Bool.not(C.path("/tmp/" ++ repeat(123n,"é"))),"filename cap counts UTF8 bytes rather than characters")
    require(Bool.not(C.path(repeat(4097n,"/"))),"overlong destination is bounded before splitting")
    require(C.preflight(request(),"/private/tmp/café 中文 🙂.atif.json") && Bool.not(C.preflight(request(),"relative.atif.json")),"canonical destination is absolute and admitted before export")
    require(String.eq(J.get(value,"snapshot"),"9007199254740993") && String.eq(J.get(value,"requested_path"),"/tmp/café 中文 🙂.atif.json") && String.eq(J.get(value,"path"),"/private/tmp/café 中文 🙂.atif.json"),"serialized receipt retains exact snapshot requested path and canonical output independently")
    require(String.eq(J.get(value,"schema_version"),"ATIF-v1.8") && String.eq(J.get(value,"scope"),"complete_retained_snapshot") && String.eq(J.get(value,"content"),"text_only"),"acknowledgment distinguishes complete retained scope and text-only format")
    require(C.received_counts(value),"actual serialized receipt carries typed internally consistent bounded counts")
    require(refused(C.acknowledge(request(),"/private/tmp/elsewhere",receipt())),"different actual destination cannot acknowledge the requested export")
    require(refused(C.acknowledge(C.Command{"7","out"},"/private/tmp/café 中文 🙂.atif.json",receipt())),"different snapshot cannot acknowledge the requested export")
    require(Bool.not(C.counts(2,1,1,1)) && Bool.not(C.counts(1,1,2,1)) && Bool.not(C.counts(1,1,0,1)) && Bool.not(C.counts(1,1,1,0)),"impossible empty or inconsistent complete export counts are refused")
    require(Bool.not(C.counts(1000001,1000001,1,1)) && Bool.not(C.counts(1,2000001,1,1)) && Bool.not(C.counts(1,1,1,2147483649)),"receipt counts cannot exceed frozen backend envelope")
    require(C.counts(1000000,2000000,2000000,2147483648),"exact backend upper bounds remain representable")
    require(Bool.not(refused(C.encoded(repeat(16383n,"🙂") ++ "xyz"))) && refused(C.encoded(repeat(16384n,"🙂"))),"acknowledgment output cap accepts65535UTF8bytes and refuses65536")
    require(Bool.not(Maybe.is_some(&2,U32,C.number(J.JNumber{"01"}))) && Bool.not(Maybe.is_some(&2,U32,C.number(J.JNumber{"4294967296"}))) && Bool.not(Maybe.is_some(&2,U32,C.number(J.JString{"1"}))),"received counts reject noncanonical overflow and wrong JSON types")

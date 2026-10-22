import Base
import ./atif_types.bend as T
import ./attachment_refs.bend as Ref
import ./archive_meta.bend as Meta
import ./domain.bend as Domain
import ./json.bend as Json

type Command is Data:
  Command{snapshot: String,destination: String}

def usage() -> String:
  "usage: export-atif SNAPSHOT DEST (complete retained capture, text-only ATIF1.8; destination must not exist)"

def leaf(parts: List<&2,String>,last: String) -> String:
  match parts:
    case []: last
    case part <> rest: leaf(rest,part)

def leaf_valid(+name: String) -> Bool:
  Bool.not(String.is_empty(name)) && Bool.not(String.eq(name,".")) &&
    Bool.not(String.eq(name,"..")) && Ref.bounded(name,244)

def path_bounded(valid: Bool,path: String) -> Bool:
  match valid:
    case False{}: False{}
    case True{}: leaf_valid(leaf(String.split(path,'/'),""))

# The 11-byte temporary suffix is reserved before any publication side effect.
def path(+value: String) -> Bool:
  path_bounded(Ref.bounded(value,4096),value)

def identity_bounded(valid: Bool,value: String) -> Bool:
  match valid:
    case False{}: False{}
    case True{}: Meta.identity(value)

def identity(+value: String) -> Bool:
  identity_bounded(Ref.bounded(value,19),value)

def admit(valid: Bool,value: Command) -> Result<&2,&2,String,Command>:
  Bool.pick(Result<&2,&2,String,Command>,valid,Done{value},Fail{usage()})

def parse(args: List<String>) -> Result<&2,&2,String,Command>:
  match args:
    case +snapshot <> +destination <> []:
      admit(identity(snapshot) && path(destination),Command{snapshot,destination})
    case _: Fail{usage()}

def preflight(value: Command,+canonical: String) -> Bool:
  Command{snapshot,destination} = value
  identity(snapshot) && path(destination) && path(canonical) && String.starts_with(canonical,"/")

def counts(+records: U32,+events: U32,+steps: U32,+bytes: U32) -> Bool:
  U32.is_gt(records,0) && U32.is_le(records,1000000) &&
    U32.is_ge(events,records) && U32.is_le(events,2000000) &&
    U32.is_gt(steps,0) && U32.is_le(steps,events) &&
    U32.is_gt(bytes,0) && U32.is_le(bytes,2147483648)

def fields(value: Command,receipt: T.Receipt) -> String:
  Command{_,requested} = value
  T.Receipt{snapshot,destination,records,events,steps,bytes} = receipt
  "{\"kind\":\"atif_export\",\"schema_version\":\"ATIF-v1.8\",\"snapshot\":" ++ Json.quote(snapshot) ++
    ",\"requested_path\":" ++ Json.quote(requested) ++ ",\"path\":" ++ Json.quote(destination) ++
    ",\"records\":" ++ U32.show(records) ++ ",\"events\":" ++ U32.show(events) ++
    ",\"steps\":" ++ U32.show(steps) ++ ",\"bytes\":" ++ U32.show(bytes) ++
    ",\"complete_export\":true,\"scope\":\"complete_retained_snapshot\",\"content\":\"text_only\",\"verification\":\"complete_accepted_extent\"}"

def encoded(+text: String) -> Result<&2,&2,String,String>:
  Bool.pick(Result<&2,&2,String,String>,Ref.bounded(text,65535),Done{text},Fail{"ATIF acknowledgment exceeded its bound; publication is not confirmed"})

def acknowledged(valid: Bool,value: Command,receipt: T.Receipt) -> Result<&2,&2,String,String>:
  match valid:
    case False{}: Fail{"ATIF receipt did not match the exact requested capture and canonical destination; publication is not confirmed"}
    case True{}: encoded(fields(value,receipt))

def acknowledge(+value: Command,+canonical: String,+receipt: T.Receipt) -> Result<&2,&2,String,String>:
  Command{snapshot,_} = value
  T.Receipt{actual,destination,records,events,steps,bytes} = receipt
  acknowledged(preflight(value,canonical) && String.eq(snapshot,actual) &&
    String.eq(canonical,destination) && counts(records,events,steps,bytes),value,receipt)

def number_bounded(valid: Bool,text: String) -> Maybe<&2,U32>:
  match valid:
    case False{}: None{}
    case True{}: Domain.parse_u32(text)

def number(value: Json.Json) -> Maybe<&2,U32>:
  match value:
    case Json.JNumber{+text}: number_bounded(Ref.bounded(text,10),text)
    case _: None{}

def count_fields(records: Maybe<&2,U32>,events: Maybe<&2,U32>,steps: Maybe<&2,U32>,bytes: Maybe<&2,U32>) -> Bool:
  match records events steps bytes:
    case Some{records} Some{events} Some{steps} Some{bytes}: counts(records,events,steps,bytes)
    case _ _ _ _: False{}

def received_counts(+value: Json.Json) -> Bool:
  count_fields(number(Json.field(value,"records")),number(Json.field(value,"events")),
    number(Json.field(value,"steps")),number(Json.field(value,"bytes")))

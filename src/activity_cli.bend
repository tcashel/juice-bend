import Base
import ./activity_reader.bend as Reader
import ./tool_activity.bend as Activity
import ./scoped_reader.bend as Scoped
import ./provenance.bend as P
import ./domain.bend as Domain
import ./json.bend as Json

def failure(-A: Type,code: String,message: String) -> IO(A):
  IO.die(A,2,"{\"error\":" ++ Json.quote(message) ++ ",\"code\":" ++ Json.quote(code) ++ "}")

def require(-A: Kind(&2),result: Result<&2,&2,String,A>,code: String) -> IO(A):
  match result:
    case Done{value}:
      IO.pure(A,value)
    case Fail{message}:
      failure(A,code,message)

def number(value: Maybe<&2,U32>,label: String) -> IO(U32):
  match value:
    case Some{value}:
      IO.pure(U32,value)
    case None{}:
      failure(U32,"invalid_number",label ++ " must be an integer from 0 to 4294967295")

# A next cursor always names another physical record in the same snapshot.
# Defensive bounds keep even a malformed Page from wrapping its U32 cursor.
def next(+total: U32,+start: U32,+selected: U32) -> Maybe<&2,U32>:
  Bool.pick(Maybe<&2,U32>,U32.is_gt(selected,0) && U32.is_le(start,total) &&
    U32.is_lt(selected,U32.sub(total,start)),Some{U32.add(start,selected)},None{})

def next_json(value: Maybe<&2,U32>) -> String:
  match value:
    case None{}:
      "null"
    case Some{value}:
      U32.show(value)

def page_valid(page: Reader.Page) -> Bool:
  Reader.Page{+provider,_,_,_,_,+total,+start,+requested,+selected,verified,+scope,_} = page
  U32.is_gt(requested,0) && U32.is_le(requested,100) &&
    U32.is_eq(selected,Domain.bounded_count(start,requested,total)) &&
    U32.is_eq(verified,Bool.pick(U32,Scoped.provider_allowed(scope,provider),selected,0))

def json(page: Reader.Page,text: String) -> String:
  Reader.Page{provider,source,generation,snapshot,extent,+total,+start,requested,
    +selected,verified,scope,_} = page
  "{\"kind\":\"recorded_activity\",\"provider\":" ++ Json.quote(provider) ++
    ",\"source\":" ++ Json.quote(source) ++ ",\"generation\":" ++ Json.quote(generation) ++
    ",\"snapshot\":" ++ Json.quote(snapshot) ++ ",\"extent\":" ++ Json.quote(U32.show(extent)) ++
    ",\"total_records\":" ++ U32.show(total) ++ ",\"start\":" ++ U32.show(start) ++
    ",\"requested_count\":" ++ U32.show(requested) ++ ",\"selected_count\":" ++ U32.show(selected) ++
    ",\"verified_count\":" ++ U32.show(verified) ++ ",\"next\":" ++ next_json(next(total,start,selected)) ++
    ",\"scope\":" ++ Reader.scope_text(scope) ++ ",\"text\":" ++ Json.quote(text) ++ "}"

def bounded(text: String,remaining: Maybe<&2,U32>) -> Result<&2,&2,String,String>:
  match remaining:
    case None{}:
      Fail{"Escaped recorded activity exceeds the 1048576-byte worker bound; choose a smaller physical range. No payload was truncated"}
    case Some{_}:
      Done{text}

def encoded(valid: Bool,page: Reader.Page,text: String) -> Result<&2,&2,String,String>:
  match valid:
    case False{}:
      Fail{"Recorded activity page metadata violates its immutable range contract"}
    case True{}:
      +output = json(page,text)
      bounded(output,Activity.consume(output,1048575))

# Budget the complete escaped JSON plus IO.print's trailing newline, not merely
# its text field. No partial success JSON is emitted on any Result failure.
def encode(+page: Reader.Page,text: String) -> Result<&2,&2,String,String>:
  encoded(page_valid(page),page,text)

def selected(db: U32,snapshot: String,start: String,count: String,scope: Scoped.Scope) -> IO(Unit):
  do IO<Unit>:
    from : U32 <- number(P.parse_u32(start),"start")
    size : U32 <- number(P.parse_u32(count),"count")
    # Reader owns BEGIN DEFERRED and ordinary rollback. An outer transaction
    # here would reject every valid request and violate caller ownership.
    result : Result<&2,&2,String,Reader.Page> <- Reader.read(db,snapshot,from,size,scope)
    +page : Reader.Page <- require(Reader.Page,result,"activity_unavailable")
    text : String <- require(String,Reader.render(page),"activity_unavailable")
    output : String <- require(String,encode(page,text),"output_too_large")
    IO.print(output)

def command(db: U32,args: List<String>) -> IO(Unit):
  match args:
    case snapshot <> start <> count <> provider <> repository <> role <> after <> []:
      selected(db,snapshot,start,count,Scoped.Scope{provider,repository,role,after})
    case _:
      failure(Unit,"usage","usage: activity-scope SNAPSHOT START COUNT PROVIDER REPOSITORY ROLE AFTER; COUNT is 1..100")

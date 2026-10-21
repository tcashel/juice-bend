import Base
import ./json.bend as Json
import ./sql.bend as Sql

# The GUI talks only to this same native Bend executable, through literal argv.
# A storage error or abrupt worker exit becomes data for the GUI, never IO.die.
# Process.run parks off the event loop; callers still need stale-job identities
# when issuing asynchronous requests. Output and parser inputs are both <=1MiB.

def diagnostic(out: String,+err: String) -> String:
  String.take(Bool.pick(String,String.is_empty(err),out,err),2048n)

def parse_output(result: Result<&2,&2,String,Json.Json>) -> Result<&2,&2,String,Json.Json>:
  match result:
    case Fail{message}:
      Fail{"Local worker returned invalid JSON: " ++ message}
    case Done{value}:
      Done{value}

def exited(code: U32,out: String,err: String) -> Result<&2,&2,String,Json.Json>:
  match code:
    case 0:
      parse_output(Json.parse(out))
    case _:
      Fail{"Local worker exited " ++ U32.show(code) ++ ": " ++ diagnostic(out,err)}

def completed(result: Result<&1,&1,U32 & String,U32 & (String & String)>) ->
  Result<&2,&2,String,Json.Json>:
  match result:
    case Fail{(code,message)}:
      Fail{"Local worker could not complete (" ++ U32.show(code) ++ "): " ++
        String.take(message,2048n)}
    case Done{(code,(out,err))}:
      exited(code,out,err)

# Whole-capture usage verifies bounded retained raw bytes and can outlast a
# paged read. Keep the longer deadline confined to this exact command shape.
# Process.run has no cancellation handle; GUI Back invalidates its reply while
# retaining the single in-flight worker until completion or this deadline.
def two_args(+command: String,snapshot: String) -> List<String> & U32:
  ([command,snapshot],Bool.pick(U32,String.eq(command,"session-usage"),120000,10000))

def timed_args(args: List<String>) -> List<String> & U32:
  match args:
    case Con{command,Con{snapshot,Nil{}}}:
      two_args(command,snapshot)
    case other:
      (other,10000)

def timeout_value(pair: List<String> & U32) -> U32:
  (_,timeout) = pair
  timeout

def timeout_ms(args: List<String>) -> U32:
  timeout_value(timed_args(args))

def call_timed(program: String,data_dir: String,pair: List<String> & U32,valid: Bool) ->
  IO(Result<&2,&2,String,Json.Json>):
  (args,timeout) = pair
  match valid:
    case False{}:
      IO.pure(Result<&2,&2,String,Json.Json>,
        Fail{"Local worker requires an executable, an explicit data directory and a command"})
    case True{}:
      do IO<Result<&2,&2,String,Json.Json>>:
        result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
          Process.run(program,"--data-dir" <> data_dir <> args,"",1048576,timeout)
        return completed(result)

def call_checked(program: String,data_dir: String,args: List<String>,valid: Bool) ->
  IO(Result<&2,&2,String,Json.Json>):
  call_timed(program,data_dir,timed_args(args),valid)

def call(+program: String,+data_dir: String,args: List<String>) ->
  IO(Result<&2,&2,String,Json.Json>):
  match args:
    case Nil{}:
      IO.pure(Result<&2,&2,String,Json.Json>,Fail{"Local worker requires a CLI command"})
    case Con{head,tail}:
      call_checked(program,data_dir,head <> tail,
        Bool.not(String.is_empty(program)) && Bool.not(String.is_empty(data_dir)))

def cell(value: Json.Json) -> Result<&2,&2,String,Sql.Cell>:
  match value:
    case Json.JNull{}:
      Done{Sql.Cell.Null{}}
    case Json.JString{value}:
      Done{Sql.Cell.Text{value}}
    case _:
      Fail{"Local worker row contains a cell other than string or null"}

def cells(values: List<&2,Json.Json>,budget: Nat) -> Result<&2,&2,String,List<&2,Sql.Cell>>:
  match values budget:
    case Nil{} _:
      Done{[]}
    case Con{head,tail} 0n:
      Fail{"Local worker row exceeds 256 columns"}
    case Con{head,tail} 1n+rest:
      do Result<&2,&2,String,List<&2,Sql.Cell>>:
        value : Sql.Cell <- cell(head)
        values : List<&2,Sql.Cell> <- cells(tail,rest)
        return value <> values

def row(value: Json.Json) -> Result<&2,&2,String,List<&2,Sql.Cell>>:
  match value:
    case Json.JArray{values}:
      cells(values,256n)
    case _:
      Fail{"Local worker rows must contain arrays"}

def row_list(values: List<&2,Json.Json>,budget: Nat) ->
  Result<&2,&2,String,List<&2,List<&2,Sql.Cell>>>:
  match values budget:
    case Nil{} _:
      Done{[]}
    case Con{head,tail} 0n:
      Fail{"Local worker response exceeds 4096 rows"}
    case Con{head,tail} 1n+rest:
      do Result<&2,&2,String,List<&2,List<&2,Sql.Cell>>>:
        value : List<&2,Sql.Cell> <- row(head)
        values : List<&2,List<&2,Sql.Cell>> <- row_list(tail,rest)
        return value <> values

def rows_value(value: Json.Json) -> Result<&2,&2,String,List<&2,List<&2,Sql.Cell>>>:
  match value:
    case Json.JArray{items}:
      row_list(items,4096n)
    case _:
      Fail{"Local worker JSON is missing an array named rows"}

def rows_result(result: Result<&2,&2,String,Json.Json>) ->
  Result<&2,&2,String,List<&2,List<&2,Sql.Cell>>>:
  match result:
    case Fail{message}:
      Fail{message}
    case Done{value}:
      rows_value(Json.field(value,"rows"))

def rows(program: String,data_dir: String,args: List<String>) ->
  IO(Result<&2,&2,String,List<&2,List<&2,Sql.Cell>>>):
  do IO<Result<&2,&2,String,List<&2,List<&2,Sql.Cell>>>>:
    result : Result<&2,&2,String,Json.Json> <- call(program,data_dir,args)
    return rows_result(result)

def text_value(value: Json.Json) -> Result<&2,&2,String,String>:
  match value:
    case Json.JString{text}:
      Done{text}
    case _:
      Fail{"Local worker JSON is missing a string named text"}

def text_result(result: Result<&2,&2,String,Json.Json>) -> Result<&2,&2,String,String>:
  match result:
    case Fail{message}:
      Fail{message}
    case Done{value}:
      text_value(Json.field(value,"text"))

def text_call(program: String,data_dir: String,command: String,snapshot: String,
  start: U32,count: U32) -> IO(Result<&2,&2,String,String>):
  do IO<Result<&2,&2,String,String>>:
    result : Result<&2,&2,String,Json.Json> <-
      call(program,data_dir,[command,snapshot,U32.show(start),U32.show(count)])
    return text_result(result)

def page(program: String,data_dir: String,snapshot: String,start: U32,count: U32) ->
  IO(Result<&2,&2,String,String>):
  text_call(program,data_dir,"session",snapshot,start,count)

def why(program: String,data_dir: String,snapshot: String,start: U32,count: U32) ->
  IO(Result<&2,&2,String,String>):
  text_call(program,data_dir,"why",snapshot,start,count)

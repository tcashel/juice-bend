import Base
import ./domain.bend as D
import ./attachment_refs.bend as Ref

# This allowlist supplies filesystem primitives only. Request/identity/cleanup
# policy is Bend-owned. Never accept an output path from a provider or child.
type Request is Data:
  Request{root: String,nonce: String,identity: String}
type Context is Data:
  Context{system: String,owner: String}

def prefix() -> String: "/.image-preview-"
def leaf() -> String: "/pixels.wire"
def directory(value: Request) -> String:
  Request{root,nonce,_} = value
  root ++ prefix() ++ nonce
def output(value: Request) -> String: directory(value) ++ leaf()

def digits(fuel: Nat,text: String) -> Bool:
  match fuel text:
    case _ SNil{}: True{}
    case 1n+left SCon{Chr{+cp},rest}: U32.is_ge(cp,48) && U32.is_le(cp,57) && digits(left,rest)
    case _ _: False{}
def number(+text: String) -> Bool:
  Bool.not(String.is_empty(text)) && digits(20n,text) && (String.eq(text,"0") || Bool.not(String.starts_with(text,"0")))
def hex(fuel: Nat,text: String) -> Bool:
  match fuel text:
    case 0n SNil{}: True{}
    case 1n+left SCon{Chr{+cp},rest}:
      ((U32.is_ge(cp,48) && U32.is_le(cp,57)) || (U32.is_ge(cp,97) && U32.is_le(cp,102))) && hex(left,rest)
    case _ _: False{}
def nonce(value: String) -> Bool: hex(32n,value)
def root_valid(+root: String) -> Bool:
  String.starts_with(root,"/") && Ref.bounded(root,3900) && Bool.not(String.contains(root,"\0") || String.contains(root,"\n") || String.contains(root,"\r")) &&
    Bool.not(String.ends_with(root,"/"))
def identity_parts(parts: List<&2,String>,owner: String) -> Bool:
  match parts:
    case [device,inode,+uid,"700"]: number(device) && number(inode) && number(uid) && String.eq(uid,owner)
    case _: False{}
def identity(+text: String,owner: String) -> Bool:
  Ref.bounded(text,80) && identity_parts(String.split(text,':'),owner)
def request_valid(value: Request) -> Bool:
  Request{root,key,+identity} = value
  root_valid(root) && nonce(key) && Ref.bounded(identity,80) && Bool.not(String.contains(identity,"\0") || String.contains(identity,"\n"))

def command_result(value: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Result<&2,&2,String,String>:
  match value:
    case Done{(0,(out,error))}:
      Bool.pick(Result<&2,&2,String,String>,String.is_empty(error),Done{out},Fail{"image_spool_primitive_failed"})
    case _: Fail{"image_spool_primitive_failed"}
def command(program: String,args: List<String>) -> IO(Result<&2,&2,String,String>):
  do IO<Result<&2,&2,String,String>>:
    value : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run(program,args,"",8192,2000)
    return command_result(value)
def line(value: Result<&2,&2,String,String>) -> Result<&2,&2,String,String>:
  match value:
    case Fail{error}: Fail{error}
    case Done{+text}:
      +body = String.take(text,Nat.sub(String.length(text),1n))
      Bool.pick(Result<&2,&2,String,String>,String.ends_with(text,"\n") && Bool.not(String.contains(body,"\n") || String.contains(body,"\r") || String.contains(body,"\0")),Done{body},Fail{"image_spool_primitive_line"})
def require(valid: Bool,message: String) -> Result<&2,&2,String,Unit>:
  Bool.pick(Result<&2,&2,String,Unit>,valid,Done{Unit{}},Fail{message})

def context_values(system: Result<&2,&2,String,String>,owner: Result<&2,&2,String,String>) -> Result<&2,&2,String,Context>:
  do Result<&2,&2,String,Context>:
    +system : String <- line(system)
    +owner : String <- line(owner)
    _ : Unit <- require((String.eq(system,"Darwin") || String.eq(system,"Linux")) && number(owner),"image_spool_platform")
    Done{Context{system,owner}}
def context() -> IO(Result<&2,&2,String,Context>):
  do IO<Result<&2,&2,String,Context>>:
    system : Result<&2,&2,String,String> <- command("/usr/bin/uname",["-s"])
    owner : Result<&2,&2,String,String> <- command("/usr/bin/id",["-u"])
    return context_values(system,owner)

def stat(context: Context,path: String) -> IO(Result<&2,&2,String,String>):
  Context{system,_} = context
  match system:
    case "Darwin": command("/usr/bin/stat",["-f","%d:%i:%u:%Lp",path])
    case "Linux": command("/usr/bin/stat",["-c","%d:%i:%u:%a","--",path])
    case _: IO.pure(Result<&2,&2,String,String>,Fail{"image_spool_platform"})
def test_result(value: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Result<&2,&2,String,Bool>:
  match value:
    case Done{(+code,(out,error))}:
      Bool.pick(Result<&2,&2,String,Bool>,U32.is_le(code,1) && String.is_empty(out) && String.is_empty(error),Done{U32.is_eq(code,0)},Fail{"image_spool_primitive_failed"})
    case _: Fail{"image_spool_primitive_failed"}
def test(flag: String,path: String) -> IO(Result<&2,&2,String,Bool>):
  do IO<Result<&2,&2,String,Bool>>:
    value : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/bin/test",[flag,path],"",1024,2000)
    return test_result(value)

def checked_values(request: Request,context: Context,is_dir: Result<&2,&2,String,Bool>,link: Result<&2,&2,String,Bool>,canonical: Result<&2,&2,String,String>,observed: Result<&2,&2,String,String>) -> Result<&2,&2,String,Request>:
  Request{+root,+key,+wanted} = request
  Context{_,owner} = context
  do Result<&2,&2,String,Request>:
    actual_dir : Bool <- is_dir
    actual_link : Bool <- link
    path : String <- line(canonical)
    +actual : String <- line(observed)
    _ : Unit <- require(actual_dir && Bool.not(actual_link) && String.eq(path,root ++ prefix() ++ key) && identity(actual,owner),"image_spool_directory_authority")
    _ : Unit <- require(String.is_empty(wanted) || String.eq(wanted,actual),"image_spool_directory_changed")
    Done{Request{root,key,actual}}
def check_context(value: Result<&2,&2,String,Context>,+request: Request) -> IO(Result<&2,&2,String,Request>):
  match value:
    case Fail{message}: IO.pure(Result<&2,&2,String,Request>,Fail{message})
    case Done{+context}:
      +path = directory(request)
      do IO<Result<&2,&2,String,Request>>:
        dir : Result<&2,&2,String,Bool> <- test("-d",path)
        link : Result<&2,&2,String,Bool> <- test("-L",path)
        canonical : Result<&2,&2,String,String> <- command("/bin/realpath",["--",path])
        observed : Result<&2,&2,String,String> <- stat(context,path)
        return checked_values(request,context,dir,link,canonical,observed)
def check_valid(valid: Bool,request: Request) -> IO(Result<&2,&2,String,Request>):
  match valid:
    case False{}: IO.pure(Result<&2,&2,String,Request>,Fail{"image_spool_invalid_request"})
    case True{}:
      do IO<Result<&2,&2,String,Request>>:
        value : Result<&2,&2,String,Context> <- context()
        check_context(value,request)
def check(+request: Request) -> IO(Result<&2,&2,String,Request>): check_valid(request_valid(request),request)

def empty_values(exists: Result<&2,&2,String,Bool>,link: Result<&2,&2,String,Bool>) -> Result<&2,&2,String,Unit>:
  do Result<&2,&2,String,Unit>:
    exists : Bool <- exists
    link : Bool <- link
    require(Bool.not(exists || link),"image_spool_output_exists")
def empty(request: Request) -> IO(Result<&2,&2,String,Unit>):
  +path = output(request)
  do IO<Result<&2,&2,String,Unit>>:
    exists : Result<&2,&2,String,Bool> <- test("-e",path)
    link : Result<&2,&2,String,Bool> <- test("-L",path)
    return empty_values(exists,link)

def random_values(a: Result<&1,&1,U32 & String,U32>,b: Result<&1,&1,U32 & String,U32>,c: Result<&1,&1,U32 & String,U32>,d: Result<&1,&1,U32 & String,U32>) -> Result<&2,&2,String,String>:
  match a b c d:
    case Done{a} Done{b} Done{c} Done{d}: Done{D.hex_word(a) ++ D.hex_word(b) ++ D.hex_word(c) ++ D.hex_word(d)}
    case _ _ _ _: Fail{"image_spool_random_failed"}
def random() -> IO(Result<&2,&2,String,String>):
  do IO<Result<&2,&2,String,String>>:
    a : Result<&1,&1,U32 & String,U32> <- IO.random_u32()
    b : Result<&1,&1,U32 & String,U32> <- IO.random_u32()
    c : Result<&1,&1,U32 & String,U32> <- IO.random_u32()
    d : Result<&1,&1,U32 & String,U32> <- IO.random_u32()
    return random_values(a,b,c,d)
def created(result: Result<&2,&2,String,String>,request: Request) -> IO(Result<&2,&2,String,Request>):
  match result:
    case Fail{_}: IO.pure(Result<&2,&2,String,Request>,Fail{"image_spool_create_failed"})
    case Done{_}: check(request)
def create_nonce(value: Result<&2,&2,String,String>,root: String) -> IO(Result<&2,&2,String,Request>):
  match value:
    case Fail{message}: IO.pure(Result<&2,&2,String,Request>,Fail{message})
    case Done{nonce}:
      +request : Request = Request{root,nonce,""}
      do IO<Result<&2,&2,String,Request>>:
        result : Result<&2,&2,String,String> <- command("/bin/mkdir",["-m","700",directory(request)])
        created(result,request)
def create_valid(valid: Bool,root: String) -> IO(Result<&2,&2,String,Request>):
  match valid:
    case False{}: IO.pure(Result<&2,&2,String,Request>,Fail{"image_spool_invalid_root"})
    case True{}:
      do IO<Result<&2,&2,String,Request>>:
        value : Result<&2,&2,String,String> <- random()
        create_nonce(value,root)

def create_root(value: Result<&2,&2,String,String>) -> IO(Result<&2,&2,String,Request>):
  match value:
    case Fail{message}: IO.pure(Result<&2,&2,String,Request>,Fail{message})
    case Done{+root}:
      create_valid(root_valid(root),root)

def create_requested(valid: Bool,root: String) -> IO(Result<&2,&2,String,Request>):
  match valid:
    case False{}: IO.pure(Result<&2,&2,String,Request>,Fail{"image_spool_invalid_root"})
    case True{}:
      do IO<Result<&2,&2,String,Request>>:
        value : Result<&2,&2,String,String> <- command("/bin/realpath",["--",root])
        create_root(line(value))
def create(+root: String) -> IO(Result<&2,&2,String,Request>): create_requested(root_valid(root),root)

def file_owner(parts: List<&2,String>,owner: String) -> Bool:
  match parts:
    case [device,inode,+uid,mode]: number(device) && number(inode) && number(uid) && String.eq(uid,owner) && number(mode)
    case _: False{}
def readable_values(context: Context,regular: Result<&2,&2,String,Bool>,link: Result<&2,&2,String,Bool>,observed: Result<&2,&2,String,String>) -> Result<&2,&2,String,Unit>:
  Context{_,owner} = context
  do Result<&2,&2,String,Unit>:
    regular : Bool <- regular
    link : Bool <- link
    actual : String <- line(observed)
    require(regular && Bool.not(link) && file_owner(String.split(actual,':'),owner),"image_spool_file_authority")
def readable_context(value: Result<&2,&2,String,Context>,request: Request) -> IO(Result<&2,&2,String,Unit>):
  match value:
    case Fail{message}: IO.pure(Result<&2,&2,String,Unit>,Fail{message})
    case Done{+context}:
      +path = output(request)
      do IO<Result<&2,&2,String,Unit>>:
        regular : Result<&2,&2,String,Bool> <- test("-f",path)
        link : Result<&2,&2,String,Bool> <- test("-L",path)
        observed : Result<&2,&2,String,String> <- stat(context,path)
        return readable_values(context,regular,link,observed)
def readable_checked(value: Result<&2,&2,String,Request>) -> IO(Result<&2,&2,String,Unit>):
  match value:
    case Fail{message}: IO.pure(Result<&2,&2,String,Unit>,Fail{message})
    case Done{request}:
      do IO<Result<&2,&2,String,Unit>>:
        value : Result<&2,&2,String,Context> <- context()
        readable_context(value,request)
def readable(request: Request) -> IO(Result<&2,&2,String,Unit>):
  do IO<Result<&2,&2,String,Unit>>:
    value : Result<&2,&2,String,Request> <- check(request)
    readable_checked(value)

def cleanup_result(value: Result<&2,&2,String,String>) -> Result<&2,&2,String,Unit>:
  match value:
    case Done{_}: Done{Unit{}}
    case Fail{_}: Fail{"image_spool_cleanup_failed"}

def removed(result: Result<&2,&2,String,String>,request: Request) -> IO(Result<&2,&2,String,Unit>):
  match result:
    case Fail{message}: IO.pure(Result<&2,&2,String,Unit>,Fail{message})
    case Done{_}:
      do IO<Result<&2,&2,String,Unit>>:
        value : Result<&2,&2,String,String> <- command("/bin/rmdir",["--",directory(request)])
        return cleanup_result(value)

def cleanup_checked(value: Result<&2,&2,String,Request>) -> IO(Result<&2,&2,String,Unit>):
  match value:
    case Fail{message}: IO.pure(Result<&2,&2,String,Unit>,Fail{message})
    case Done{+request}:
      do IO<Result<&2,&2,String,Unit>>:
        result : Result<&2,&2,String,String> <- command("/bin/rm",["-f","--",output(request)])
        removed(result,request)

# Call only after Process.run returned: its direct child has been reaped. Never
# recursively remove a directory or sweep an unknown request after a crash.
def cleanup(request: Request) -> IO(Result<&2,&2,String,Unit>):
  do IO<Result<&2,&2,String,Unit>>:
    value : Result<&2,&2,String,Request> <- check(request)
    cleanup_checked(value)

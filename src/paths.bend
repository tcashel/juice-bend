import Base

# Canonicalization is an OS primitive; all acceptance and identity policy stays
# in Bend. argv is literal, output/time are bounded, and no shell is involved.
def canonical_checked(canonical: String,valid: Bool) -> IO(String):
  match valid:
    case True{}:
      IO.pure(String,canonical)
    case False{}:
      IO.die(String,1,"Path canonicalization returned invalid output")

def canonical_output(code: U32,+out: String) -> IO(String):
  match code:
    case 0:
      +canonical = String.take(out,Nat.sub(String.length(out),1n))
      canonical_checked(canonical,String.ends_with(out,"\n") &&
        String.starts_with(canonical,"/") && Bool.not(String.contains(canonical,"\0")))
    case _:
      IO.die(String,1,"Path does not exist or cannot be canonicalized")

def resolve_result(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(String):
  match result:
    case Fail{(code,_)}:
      IO.die(String,code,"Path canonicalization could not complete")
    case Done{(code,(out,_))}:
      canonical_output(code,out)

def resolve_valid(path: String,valid: Bool) -> IO(String):
  match valid:
    case False{}:
      IO.die(String,2,"Path must be nonempty and contain no NUL")
    case True{}:
      do IO<String>:
        result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
          Process.run("/bin/realpath",["--",path],"",8192,2000)
        resolve_result(result)

def resolve(+path: String) -> IO(String):
  resolve_valid(path,Bool.not(String.is_empty(path)) && Bool.not(String.contains(path,"\0")))

def valid_leaf(invalid: Bool) -> IO(Unit):
  match invalid:
    case False{}:
      IO.pure(Unit,Unit{})
    case True{}:
      IO.die(Unit,2,"Export destination needs a non-directory filename")

def destination_parts(parts: List<&2,String>,absolute: Bool) -> IO(String):
  match parts:
    case Nil{}:
      IO.die(String,2,"Export destination needs a filename")
    case Con{+leaf,rest}:
      +parent = String.join(List.reverse(&2,String,rest),"/")
      do IO<String>:
        valid_leaf(String.is_empty(leaf) || String.eq(leaf,".") || String.eq(leaf,".."))
        +canonical : String <- resolve(Bool.pick(String,String.is_empty(parent),
          Bool.pick(String,absolute,"/","."),parent))
        return canonical ++ Bool.pick(String,String.eq(canonical,"/"),"","/") ++ leaf

def destination(+path: String) -> IO(String):
  do IO<String>:
    valid_leaf(String.is_empty(path) || String.contains(path,"\0"))
    destination_parts(List.reverse(&2,String,String.split(path,'/')),String.starts_with(path,"/"))

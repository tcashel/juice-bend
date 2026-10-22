import Base
import ./claude_quota.bend as Q

# OS commands below are literal bounded filesystem primitives. Selection,
# ownership, mode, ACL, identity and publication policy remain in Bend.
type Platform is Data:
  Darwin{}
  Linux{}

type Metadata is Data:
  Metadata{mode: String,uid: String,links: String,device: String,inode: String}

type Root is Data:
  Root{platform: Platform,uid: String,path: String,identity: Metadata}

type Reply is Data:
  Reply{code: U32,out: String,err: String}

def fail(-A: Data,code: String,message: String) -> Result<&2,&2,Q.Failure,A>:
  Fail{Q.Failure{code,message}}

def pure(-A: Data,value: Result<&2,&2,Q.Failure,A>) -> IO(Result<&2,&2,Q.Failure,A>):
  IO.pure(Result<&2,&2,Q.Failure,A>,value)

def bind(-A: Data,-B: Data,value: Result<&2,&2,Q.Failure,A>,next: A -> IO(Result<&2,&2,Q.Failure,B>)) -> IO(Result<&2,&2,Q.Failure,B>):
  match value:
    case Fail{problem}: pure(B,Fail{problem})
    case Done{value}: next(value)

def gate(-A: Data,ok: Bool,value: A,code: String,message: String) -> Result<&2,&2,Q.Failure,A>:
  match ok:
    case True{}: Done{value}
    case False{}: fail(A,code,message)

def process(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Result<&2,&2,Q.Failure,Reply>:
  match result:
    case Fail{_}: fail(Reply,"quota_path_io","Quota filesystem inspection could not complete")
    case Done{(code,(out,err))}: Done{Reply{code,out,err}}

def command(program: String,args: List<String>) -> IO(Result<&2,&2,Q.Failure,Reply>):
  do IO<Result<&2,&2,Q.Failure,Reply>>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run(program,args,"",16384,2000)
    return process(result)

def platform_reply(reply: Reply) -> Result<&2,&2,Q.Failure,Platform>:
  match reply:
    case Reply{0,"Darwin\n",""}: Done{Darwin{}}
    case Reply{0,"Linux\n",""}: Done{Linux{}}
    case _: fail(Platform,"quota_platform","Quota private storage requires verified Darwin or Linux filesystem primitives")

def platform() -> IO(Result<&2,&2,Q.Failure,Platform>):
  do IO<Result<&2,&2,Q.Failure,Platform>>:
    result : Result<&2,&2,Q.Failure,Reply> <- command("/usr/bin/uname",["-s"])
    bind(Reply,Platform,result,r => pure(Platform,platform_reply(r)))

def digits(value: String) -> Bool:
  match value:
    case "": True{}
    case SCon{Chr{+c},rest}: U32.is_ge(c,48) && U32.is_le(c,57) && digits(rest)

def canonical(value: String) -> Bool:
  match value:
    case "": False{}
    case "0": True{}
    case SCon{'0',_}: False{}
    case other: digits(other)

def decimal(+value: String,+maximum: String) -> Bool:
  canonical(value) && (Nat.is_lt(String.length(value),String.length(maximum)) ||
    (Nat.is_eq(String.length(value),String.length(maximum)) && String.is_le(value,maximum)))

def line(parts: List<&2,String>) -> Result<&2,&2,Q.Failure,String>:
  match parts:
    case [value,""]: Done{value}
    case _: fail(String,"quota_path_io","Filesystem primitive returned an invalid record")

def uid_value(+value: String) -> Result<&2,&2,Q.Failure,String>:
  gate(String,decimal(value,"4294967295"),value,"quota_owner","Cannot establish the effective filesystem owner")

def uid_line(value: Result<&2,&2,Q.Failure,String>) -> Result<&2,&2,Q.Failure,String>:
  match value:
    case Fail{problem}: Fail{problem}
    case Done{value}: uid_value(value)

def uid_reply(reply: Reply) -> Result<&2,&2,Q.Failure,String>:
  match reply:
    case Reply{0,out,""}: uid_line(line(String.split(out,'\n')))
    case _: fail(String,"quota_owner","Cannot establish the effective filesystem owner")

def uid() -> IO(Result<&2,&2,Q.Failure,String>):
  do IO<Result<&2,&2,Q.Failure,String>>:
    result : Result<&2,&2,Q.Failure,Reply> <- command("/usr/bin/id",["-u"])
    bind(Reply,String,result,r => pure(String,uid_reply(r)))

def metadata_parts(parts: List<&2,String>) -> Result<&2,&2,Q.Failure,Metadata>:
  match parts:
    case [mode,+uid,+links,+device,+inode]:
      gate(Metadata,decimal(uid,"4294967295") && decimal(links,"18446744073709551615") &&
        decimal(device,"18446744073709551615") && decimal(inode,"18446744073709551615") &&
        Bool.not(String.eq(links,"0")) && Bool.not(String.eq(inode,"0")),Metadata{mode,uid,links,device,inode},
        "quota_metadata","Quota filesystem metadata is invalid")
    case _: fail(Metadata,"quota_metadata","Quota filesystem metadata has an invalid shape")

def metadata_line(value: Result<&2,&2,Q.Failure,String>) -> Result<&2,&2,Q.Failure,Maybe<&2,Metadata>>:
  match value:
    case Fail{problem}: Fail{problem}
    case Done{value}:
      Result.map(&2,&2,Q.Failure,Metadata,Maybe<&2,Metadata>,m => Some{m},metadata_parts(String.split(value,':')))

# LC_ALL=C makes the missing-path diagnostic stable; all other failures stay
# errors. No filename or stderr is returned to the caller or persisted.
def stat_failed(ok: Bool) -> Result<&2,&2,Q.Failure,Maybe<&2,Metadata>>:
  match ok:
    case True{}: Done{None{}}
    case False{}: fail(Maybe<&2,Metadata>,"quota_stat","Cannot safely inspect quota storage metadata")

def stat_reply(reply: Reply) -> Result<&2,&2,Q.Failure,Maybe<&2,Metadata>>:
  match reply:
    case Reply{0,out,""}: metadata_line(line(String.split(out,'\n')))
    case Reply{code,out,err}:
      stat_failed(U32.is_eq(code,1) && String.is_empty(out) && String.ends_with(err,": No such file or directory\n"))

def stat_call(platform: Platform,path: String) -> IO(Result<&2,&2,Q.Failure,Reply>):
  match platform:
    case Darwin{}: command("/usr/bin/env",["LC_ALL=C","/usr/bin/stat","-f","%Op:%u:%l:%d:%i","--",path])
    case Linux{}: command("/usr/bin/env",["LC_ALL=C","/usr/bin/stat","-c","%f:%u:%h:%d:%i","--",path])

def stat(platform: Platform,path: String) -> IO(Result<&2,&2,Q.Failure,Maybe<&2,Metadata>>):
  do IO<Result<&2,&2,Q.Failure,Maybe<&2,Metadata>>>:
    result : Result<&2,&2,Q.Failure,Reply> <- stat_call(platform,path)
    bind(Reply,Maybe<&2,Metadata>,result,r => pure(Maybe<&2,Metadata>,stat_reply(r)))

def directory_mode(platform: Platform,mode: String) -> Bool:
  match platform:
    case Darwin{}: String.eq(mode,"40700")
    case Linux{}: String.eq(mode,"41c0")

def file_mode(platform: Platform,mode: String) -> Bool:
  match platform:
    case Darwin{}: String.eq(mode,"100600")
    case Linux{}: String.eq(mode,"8180")

def directory(platform: Platform,uid: String,metadata: Metadata) -> Bool:
  Metadata{mode,owner,_,_,_} = metadata
  directory_mode(platform,mode) && String.eq(uid,owner)

def regular(platform: Platform,uid: String,metadata: Metadata) -> Bool:
  Metadata{mode,owner,links,_,_} = metadata
  file_mode(platform,mode) && String.eq(uid,owner) && String.eq(links,"1")

def same(a: Metadata,b: Metadata) -> Bool:
  Metadata{am,au,al,ad,ai} = a
  Metadata{bm,bu,bl,bd,bi} = b
  String.eq(am,bm) && String.eq(au,bu) && String.eq(al,bl) && String.eq(ad,bd) && String.eq(ai,bi)

# Directory link counts can change as owned children are published (APFS too).
# Owner, exact permissions, device and inode remain the root identity.
def same_directory(a: Metadata,b: Metadata) -> Bool:
  Metadata{am,au,_,ad,ai} = a
  Metadata{bm,bu,_,bd,bi} = b
  String.eq(am,bm) && String.eq(au,bu) && String.eq(ad,bd) && String.eq(ai,bi)

def acl_lines(lines: List<&2,String>) -> Bool:
  match lines:
    case [line,""]: Bool.not(String.is_empty(line))
    case _: False{}

def acl_reply(reply: Reply) -> Result<&2,&2,Q.Failure,Unit>:
  match reply:
    case Reply{0,out,""}: gate(Unit,acl_lines(String.split(out,'\n')),Unit{},"quota_acl","Quota storage must not grant access through a macOS ACL")
    case _: fail(Unit,"quota_acl","Quota storage ACL metadata could not be inspected")

# On Linux the zero group permission mask blocks named POSIX ACL grants to
# other users. macOS ACLs do not share that rule; reject any printed ACL entry.
def acl(platform: Platform,path: String) -> IO(Result<&2,&2,Q.Failure,Unit>):
  match platform:
    case Linux{}: pure(Unit,Done{Unit{}})
    case Darwin{}:
      do IO<Result<&2,&2,Q.Failure,Unit>>:
        result : Result<&2,&2,Q.Failure,Reply> <- command("/usr/bin/env",["LC_ALL=C","/bin/ls","-lde","--",path])
        bind(Reply,Unit,result,r => pure(Unit,acl_reply(r)))

def chars(value: String,fuel: Nat) -> Bool:
  match value fuel:
    case "" _: True{}
    case _ 0n: False{}
    case SCon{Chr{+c},rest} 1n+n:
      U32.is_ge(c,32) && U32.is_ne(c,127) && U32.is_le(c,1114111) &&
        Bool.not(U32.is_ge(c,55296) && U32.is_le(c,57343)) && chars(rest,n)

def path(+value: String) -> Bool:
  String.starts_with(value,"/") && chars(value,4096n)

def uid_line_path(value: Result<&2,&2,Q.Failure,String>) -> Result<&2,&2,Q.Failure,String>:
  match value:
    case Fail{problem}: Fail{problem}
    case Done{+value}: gate(String,path(value),value,"quota_root","Canonical quota data root is invalid")

def resolved(reply: Reply) -> Result<&2,&2,Q.Failure,String>:
  match reply:
    case Reply{0,out,""}: uid_line_path(line(String.split(out,'\n')))
    case _: fail(String,"quota_root","Quota data root must be an existing absolute private directory")

def resolve(path: String) -> IO(Result<&2,&2,Q.Failure,String>):
  do IO<Result<&2,&2,Q.Failure,String>>:
    result : Result<&2,&2,Q.Failure,Reply> <- command("/bin/realpath",["--",path])
    bind(Reply,String,result,r => pure(String,resolved(r)))

def root_metadata(platform: Platform,uid: String,value: Maybe<&2,Metadata>) -> Result<&2,&2,Q.Failure,Metadata>:
  match value:
    case None{}: fail(Metadata,"quota_root","Select an existing private Juice Bend data directory before enabling quota")
    case Some{+metadata}: gate(Metadata,directory(platform,uid,metadata),metadata,"quota_root","Quota data root must be owned by this user with exact 0700 directory permissions")

def root_same(value: Maybe<&2,Metadata>,+root: Root) -> Result<&2,&2,Q.Failure,Root>:
  match value:
    case None{}: fail(Root,"quota_root_changed","Quota data root disappeared during inspection")
    case Some{metadata}:
      Root{_,_,_,expected} = root
      gate(Root,same_directory(metadata,expected),root,"quota_root_changed","Quota data root identity or permissions changed")

def recheck(+root: Root) -> IO(Result<&2,&2,Q.Failure,Root>):
  Root{+platform,_,+path,_} = root
  do IO<Result<&2,&2,Q.Failure,Root>>:
    result : Result<&2,&2,Q.Failure,Maybe<&2,Metadata>> <- stat(platform,path)
    bind(Maybe<&2,Metadata>,Root,result,m => pure(Root,root_same(m,root)))

def root_canonical(+platform: Platform,+uid: String,metadata: Metadata,+canonical: String) -> IO(Result<&2,&2,Q.Failure,Root>):
  +root : Root = Root{platform,uid,canonical,metadata}
  do IO<Result<&2,&2,Q.Failure,Root>>:
    checked : Result<&2,&2,Q.Failure,Unit> <- acl(platform,canonical)
    bind(Unit,Root,checked,_ => recheck(root))

def root_inspected(+platform: Platform,+uid: String,+path: String,value: Maybe<&2,Metadata>) -> IO(Result<&2,&2,Q.Failure,Root>):
  bind(Metadata,Root,root_metadata(platform,uid,value),metadata =>
    do IO<Result<&2,&2,Q.Failure,Root>>:
      result : Result<&2,&2,Q.Failure,String> <- resolve(path)
      bind(String,Root,result,canonical => root_canonical(platform,uid,metadata,canonical)))

def root_owner(+platform: Platform,+path: String,+uid: String) -> IO(Result<&2,&2,Q.Failure,Root>):
  do IO<Result<&2,&2,Q.Failure,Root>>:
    result : Result<&2,&2,Q.Failure,Maybe<&2,Metadata>> <- stat(platform,path)
    bind(Maybe<&2,Metadata>,Root,result,m => root_inspected(platform,uid,path,m))

def root_platform(platform: Platform,path: String) -> IO(Result<&2,&2,Q.Failure,Root>):
  do IO<Result<&2,&2,Q.Failure,Root>>:
    owner : Result<&2,&2,Q.Failure,String> <- uid()
    bind(String,Root,owner,u => root_owner(platform,path,u))

def root_terminal(parts: List<&2,String>) -> Bool:
  match parts:
    case []: False{}
    case [""]: False{}
    case ["."]: False{}
    case [".."]: False{}
    case [_]: True{}
    case _ <> rest: root_terminal(rest)

def root_valid(valid: Bool,path: String) -> IO(Result<&2,&2,Q.Failure,Root>):
  match valid:
    case False{}: pure(Root,fail(Root,"quota_root","Quota requires an explicit absolute data root without control characters"))
    case True{}:
      do IO<Result<&2,&2,Q.Failure,Root>>:
        host : Result<&2,&2,Q.Failure,Platform> <- platform()
        bind(Platform,Root,host,h => root_platform(h,path))

def inspect_root(+selected: String) -> IO(Result<&2,&2,Q.Failure,Root>):
  root_valid(path(selected) && root_terminal(String.split(selected,'/')),selected)

def main(root: Root) -> String:
  Root{_,_,path,_} = root
  path ++ "/quota-observations.sqlite"

def private_metadata(value: Maybe<&2,Metadata>,root: Root) -> Result<&2,&2,Q.Failure,Maybe<&2,Metadata>>:
  match value:
    case None{}: Done{None{}}
    case Some{+metadata}:
      Root{platform,uid,_,_} = root
      gate(Maybe<&2,Metadata>,regular(platform,uid,metadata),Some{metadata},"quota_file","Quota database and sidecars must be private 0600 regular single-link files owned by this user")

def private_acl(value: Maybe<&2,Metadata>,root: Root,path: String) -> IO(Result<&2,&2,Q.Failure,Maybe<&2,Metadata>>):
  match value:
    case None{}: pure(Maybe<&2,Metadata>,Done{None{}})
    case Some{metadata}:
      Root{platform,_,_,_} = root
      do IO<Result<&2,&2,Q.Failure,Maybe<&2,Metadata>>>:
        checked : Result<&2,&2,Q.Failure,Unit> <- acl(platform,path)
        bind(Unit,Maybe<&2,Metadata>,checked,_ => pure(Maybe<&2,Metadata>,Done{Some{metadata}}))

def inspect_file(+root: Root,+path: String) -> IO(Result<&2,&2,Q.Failure,Maybe<&2,Metadata>>):
  Root{platform,_,_,_} = root
  do IO<Result<&2,&2,Q.Failure,Maybe<&2,Metadata>>>:
    result : Result<&2,&2,Q.Failure,Maybe<&2,Metadata>> <- stat(platform,path)
    bind(Maybe<&2,Metadata>,Maybe<&2,Metadata>,result,value =>
      bind(Maybe<&2,Metadata>,Maybe<&2,Metadata>,private_metadata(value,root),m => private_acl(m,root,path)))

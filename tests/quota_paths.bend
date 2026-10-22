import Base
import ../src/quota_paths.bend as Paths
import ../src/claude_quota.bend as Q

def assert(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def unwrap(-A: Data,value: Result<&2,&2,Q.Failure,A>) -> IO(A):
  match value:
    case Done{value}: IO.pure(A,value)
    case Fail{Q.Failure{code,_}}: IO.die(A,1,"FAIL quota path fixture operation: " ++ code)

def succeeds(-A: Data,value: Result<&2,&2,Q.Failure,A>) -> Bool:
  match value:
    case Done{_}: True{}
    case Fail{_}: False{}

def failed(-A: Data,value: Result<&2,&2,Q.Failure,A>,wanted: String) -> Bool:
  match value:
    case Done{_}: False{}
    case Fail{Q.Failure{code,message}}:
      String.eq(code,wanted) && Bool.not(String.contains(message,"SYNTHETIC_SECRET"))

def process_output(value: U32 & (String & String)) -> IO(String):
  match value:
    case (0,(out,"")): IO.pure(String,out)
    case _: IO.die(String,1,"FAIL synthetic filesystem fixture command")

def output(program: String,args: List<String>) -> IO(String):
  do IO<String>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(program,args,"",16384,2000))
    process_output(result)

def command(program: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    out : String <- output(program,args)
    return Unit{}

def temporary(args: List<String>) -> IO(String):
  do IO<String>:
    out : String <- output("/usr/bin/mktemp",args)
    path : String <- unwrap(String,Paths.line(String.split(out,'\n')))
    canonical : Result<&2,&2,Q.Failure,String> <- Paths.resolve(path)
    unwrap(String,canonical)

def root_path(root: Paths.Root) -> String:
  Paths.Root{_,_,path,_} = root
  path

def platform(root: Paths.Root) -> Paths.Platform:
  Paths.Root{host,_,_,_} = root
  host

def present(value: Result<&2,&2,Q.Failure,Maybe<&2,Paths.Metadata>>) -> Bool:
  match value:
    case Done{Some{_}}: True{}
    case _: False{}

def absent(value: Result<&2,&2,Q.Failure,Maybe<&2,Paths.Metadata>>) -> Bool:
  match value:
    case Done{None{}}: True{}
    case _: False{}

def root_refused(path: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,Q.Failure,Paths.Root> <- Paths.inspect_root(path)
    assert(failed(Paths.Root,result,"quota_root"),label)

def file_refused(root: Paths.Root,path: String,code: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,Q.Failure,Maybe<&2,Paths.Metadata>> <- Paths.inspect_file(root,path)
    assert(failed(Maybe<&2,Paths.Metadata>,result,code),label)

def pure_checks() -> IO(Unit):
  do IO<Unit>:
    assert(Paths.directory(Paths.Darwin{},"501",Paths.Metadata{"40700","501","2","1","2"}) &&
      Paths.directory(Paths.Linux{},"501",Paths.Metadata{"41c0","501","2","1","2"}),"platform directory modes accept exact0700 owned directories")
    assert(Bool.not(Paths.directory(Paths.Darwin{},"501",Paths.Metadata{"40755","501","2","1","2"})) &&
      Bool.not(Paths.directory(Paths.Linux{},"501",Paths.Metadata{"41c0","502","2","1","2"})),"root permissions and owner must both match")
    assert(Paths.regular(Paths.Darwin{},"501",Paths.Metadata{"100600","501","1","1","2"}) &&
      Paths.regular(Paths.Linux{},"501",Paths.Metadata{"8180","501","1","1","2"}),"platform file modes accept exact0600 owned single-link files")
    assert(Bool.not(Paths.regular(Paths.Darwin{},"501",Paths.Metadata{"100600","501","2","1","2"})) &&
      Bool.not(Paths.regular(Paths.Darwin{},"501",Paths.Metadata{"100600","502","1","1","2"})),"file hardlink count and owner cannot be bypassed")
    assert(Bool.not(Paths.regular(Paths.Darwin{},"501",Paths.Metadata{"100644","501","1","1","2"})) &&
      Bool.not(Paths.regular(Paths.Darwin{},"501",Paths.Metadata{"120777","501","1","1","2"})) &&
      Bool.not(Paths.regular(Paths.Linux{},"501",Paths.Metadata{"1180","501","1","1","2"})),"public file modes symlinks and FIFOs are not regular private files")
    assert(succeeds(Paths.Metadata,Paths.metadata_parts(["100600","501","1","18446744073709551615","18446744073709551615"])),"device and inode identities retain exact unsigned64 decimal text")
    assert(failed(Paths.Metadata,Paths.metadata_parts(["100600","0501","1","1","2"]),"quota_metadata") &&
      failed(Paths.Metadata,Paths.metadata_parts(["100600","501","1","1","18446744073709551616"]),"quota_metadata") &&
      failed(Paths.Metadata,Paths.metadata_parts(["100600","501","0","1","2"]),"quota_metadata"),"metadata refuses noncanonical overflow and zero-link values")
    assert(Bool.not(Paths.same(Paths.Metadata{"100600","501","1","1","9007199254740992"},
      Paths.Metadata{"100600","501","1","1","9007199254740993"})),"distinct large inode identities are never rounded together")
    assert(Paths.same_directory(Paths.Metadata{"40700","501","2","1","42"},Paths.Metadata{"40700","501","7","1","42"}) &&
      Bool.not(Paths.same(Paths.Metadata{"100600","501","1","1","42"},Paths.Metadata{"100600","501","2","1","42"})),"directory entry count may change while file hardlink identity remains strict")
    assert(Bool.not(Paths.same_directory(Paths.Metadata{"40700","501","2","1","42"},Paths.Metadata{"40700","501","2","1","43"})) &&
      Bool.not(Paths.same_directory(Paths.Metadata{"40700","501","2","1","42"},Paths.Metadata{"40755","501","2","1","42"})),"directory inode and permissions remain identity-critical")
    assert(succeeds(Unit,Paths.acl_reply(Paths.Reply{0,"private metadata line\n",""})) &&
      failed(Unit,Paths.acl_reply(Paths.Reply{0,"private metadata line\n 0: user:SYNTHETIC_SECRET allow read\n",""}),"quota_acl"),"ACL parser accepts no-entry output and refuses any printed macOS grant")
    assert(failed(Unit,Paths.acl_reply(Paths.Reply{0,"",""}),"quota_acl") &&
      failed(Unit,Paths.acl_reply(Paths.Reply{1,"","SYNTHETIC_SECRET"}),"quota_acl"),"missing or failed ACL inspection is not accepted")
    assert(absent(Paths.stat_reply(Paths.Reply{1,"","stat: /SYNTHETIC_SECRET: No such file or directory\n"})),"only exact missing-path diagnostic becomes absence without leaking path")
    assert(failed(Maybe<&2,Paths.Metadata>,Paths.stat_reply(Paths.Reply{1,"","stat: /SYNTHETIC_SECRET: Permission denied\n"}),"quota_stat") &&
      failed(Maybe<&2,Paths.Metadata>,Paths.stat_reply(Paths.Reply{1,"unexpected","stat: /x: No such file or directory\n"}),"quota_stat"),"permission errors and unexpected output do not become absence")
    assert(Paths.path("/synthetic/café é 中文 🙂") && Paths.path("/" ++ String.repeat("x",4095n)),"absolute Unicode paths and exact4096-scalar boundary are supported")
    assert(Bool.not(Paths.path("relative")) && Bool.not(Paths.path("")) && Bool.not(Paths.path("/x\n")) &&
      Bool.not(Paths.path("/x\0")) && Bool.not(Paths.path("/" ++ String.repeat("x",4096n))) &&
      Bool.not(Paths.path(SCon{'/',SCon{Chr{55296},SNil{}}})),"relative control invalid-scalar and oversized roots are refused")

def actual_acl(host: Paths.Platform,+root: Paths.Root,+file: String) -> IO(Unit):
  match host:
    case Paths.Linux{}: IO.print("SKIP actual macOS ACL probe on Linux")
    case Paths.Darwin{}:
      do IO<Unit>:
        command("/bin/chmod",["+a","everyone allow read",file])
        file_refused(root,file,"quota_acl","actual macOS ACL grant is refused even with private POSIX mode")
        command("/bin/chmod",["-N",file])
        restored : Result<&2,&2,Q.Failure,Maybe<&2,Paths.Metadata>> <- Paths.inspect_file(root,file)
        assert(present(restored),"removing only the fixture ACL restores private-file admission")

def file_checks(+root: Paths.Root,+directory: String) -> IO(Unit):
  do IO<Unit>:
    +file : String <- temporary([directory ++ "/quota.XXXXXX"])
    first : Result<&2,&2,Q.Failure,Maybe<&2,Paths.Metadata>> <- Paths.inspect_file(root,file)
    assert(present(first),"actual mktemp file is owned0600 regular and single-link")
    stable : Result<&2,&2,Q.Failure,Paths.Root> <- Paths.recheck(root)
    assert(succeeds(Paths.Root,stable),"creating a file does not invalidate root identity when directory link count changes")
    missing : Result<&2,&2,Q.Failure,Maybe<&2,Paths.Metadata>> <- Paths.inspect_file(root,directory ++ "/absent")
    assert(absent(missing),"missing optional sibling is represented as absent")
    command("/bin/chmod",["644",file])
    file_refused(root,file,"quota_file","actual0644 file is refused before opening")
    command("/bin/chmod",["600",file])
    command("/bin/ln",[file,directory ++ "/hardlink"])
    file_refused(root,file,"quota_file","original file with second hardlink is refused")
    file_refused(root,directory ++ "/hardlink","quota_file","hardlink alias is refused")
    command("/bin/rm",["--",directory ++ "/hardlink"])
    command("/bin/ln",["-s",file,directory ++ "/symbolic"])
    command("/bin/ln",["-s",directory ++ "/never-created",directory ++ "/dangling"])
    file_refused(root,directory ++ "/symbolic","quota_file","actual leaf symlink is inspected without following its target")
    file_refused(root,directory ++ "/dangling","quota_file","actual dangling symlink is not confused with missing file")
    untouched : Result<&2,&2,Q.Failure,Maybe<&2,Paths.Metadata>> <- Paths.inspect_file(root,directory ++ "/never-created")
    assert(absent(untouched),"dangling target remains absent after inspection")
    command("/usr/bin/mkfifo",["-m","600",directory ++ "/pipe"])
    file_refused(root,directory ++ "/pipe","quota_file","FIFO is refused through metadata without opening or blocking")
    root_refused(file,"regular file cannot be selected as the quota root")
    root_refused(directory ++ "/pipe","FIFO cannot be selected as the quota root")
    root_refused(directory ++ "/dangling","dangling symlink cannot be selected as the quota root")
    actual_acl(platform(root),root,file)

def changed_only_inode(a: Paths.Root,b: Paths.Root) -> Bool:
  Paths.Root{_,_,_,Paths.Metadata{am,au,al,ad,ai}} = a
  Paths.Root{_,_,_,Paths.Metadata{bm,bu,bl,bd,bi}} = b
  String.eq(am,bm) && String.eq(au,bu) && String.eq(al,bl) && String.eq(ad,bd) && Bool.not(String.eq(ai,bi))

def replacement(+directory: String) -> IO(Unit):
  do IO<Unit>:
    command("/bin/mkdir",["-m","700",directory])
    old_result : Result<&2,&2,Q.Failure,Paths.Root> <- Paths.inspect_root(directory)
    +old : Paths.Root <- unwrap(Paths.Root,old_result)
    command("/bin/mv",[directory,directory ++ "-retired"])
    command("/bin/mkdir",["-m","700",directory])
    new_result : Result<&2,&2,Q.Failure,Paths.Root> <- Paths.inspect_root(directory)
    fresh : Paths.Root <- unwrap(Paths.Root,new_result)
    assert(changed_only_inode(old,fresh),"replacement keeps mode owner link count and device while changing root inode")
    checked : Result<&2,&2,Q.Failure,Paths.Root> <- Paths.recheck(old)
    assert(failed(Paths.Root,checked,"quota_root_changed"),"saved root identity refuses a replacement directory")

def filesystem() -> IO(Unit):
  do IO<Unit>:
    +sandbox : String <- temporary(["-d",".build/quota-paths-XXXXXX"])
    +directory : String = sandbox ++ "/private"
    command("/bin/mkdir",["-m","700",directory])
    result : Result<&2,&2,Q.Failure,Paths.Root> <- Paths.inspect_root(directory)
    +root : Paths.Root <- unwrap(Paths.Root,result)
    assert(String.eq(root_path(root),directory),"explicit owned0700 root is accepted with canonical identity")
    command("/bin/chmod",["755",directory])
    root_refused(directory,"actual0755 data root is refused")
    command("/bin/chmod",["700",directory])
    file_checks(root,directory)
    command("/bin/mkdir",["-m","700",directory ++ "/child"])
    command("/bin/ln",["-s","private",sandbox ++ "/alias"])
    root_refused(sandbox ++ "/alias","leaf directory symlink cannot become a selected root")
    root_refused(sandbox ++ "/alias/","trailing slash cannot hide a selected root symlink")
    root_refused(sandbox ++ "/alias/.","final dot cannot hide a selected root symlink")
    root_refused(sandbox ++ "/alias/..","final dotdot cannot redirect selected root identity")
    aliased : Result<&2,&2,Q.Failure,Paths.Root> <- Paths.inspect_root(sandbox ++ "/alias/child")
    canonical : Paths.Root <- unwrap(Paths.Root,aliased)
    assert(String.eq(root_path(canonical),directory ++ "/child"),"intermediate alias resolves to the verified canonical directory identity")
    root_refused(sandbox ++ "/absent-root","missing root is refused without provisioning")
    replacement(sandbox ++ "/replacement")

def main() -> IO(Unit):
  do IO<Unit>:
    pure_checks()
    filesystem()

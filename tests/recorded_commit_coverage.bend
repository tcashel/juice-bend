import Base
import ../src/recorded_commit_coverage.bend as C
import ../src/actors.bend as Actors

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def actor(+id: String,repo: String,parent: String,request: String,blocked: String) -> Actors.Actor:
  Actors.Actor{"claude","synthetic",id,id,repo,parent,request,"citation",blocked}

def inspect(+item: Actors.Actor,count: U32,all: List<&2,Actors.Actor>) -> String:
  C.chain(8n,item,all,"/synthetic/repo",[C.Count{Actors.snapshot(item),count}])

def ancestry(fuel: Nat,+index: U32) -> List<&2,Actors.Actor>:
  match fuel:
    case 0n: []
    case 1n+ +n:
      actor(U32.show(index),"/synthetic/repo",Bool.pick(String,Nat.is_eq(n,0n),"",U32.show(U32.inc(index))),"eligible","") <>
        ancestry(n,U32.inc(index))

def chain(items: List<&2,Actors.Actor>) -> String:
  match items:
    case []: "empty fixture"
    case +head <> +rest: C.chain(8n,head,head <> rest,"/synthetic/repo",[])

def main() -> IO(Unit):
  do IO<Unit>:
    assert(String.contains(inspect(actor("late","/synthetic/repo","","",""),19,[]),"first 16"),"late request marks eligibility coverage incomplete")
    assert(String.is_empty(inspect(actor("short","/synthetic/repo","","",""),16,[])),"complete short snapshot without request does not imply hidden request")
    assert(String.is_empty(inspect(actor("excluded","/synthetic/repo","","","explicit excluded origin"),19,[])),"explicit excluded origin remains excluded")
    assert(String.is_empty(inspect(actor("internal","/synthetic/repo","","","synthetic marker or source namespace"),19,[])),"internal marker remains excluded")
    assert(String.is_empty(inspect(actor("other","/synthetic/other","","",""),19,[])),"known other repository does not weaken selected coverage")
    assert(String.contains(inspect(actor("unknown","","","",""),19,[]),"first 16"),"unknown repository after bounded context scan is honest incompleteness")
    assert(String.is_empty(inspect(actor("eligible","/synthetic/repo","","request",""),19,[])),"established eligible context is not rejected merely for long snapshot")
    assert(String.is_empty(chain(ancestry(8n,1))),"eight-actor eligible chain fits inherited bound")
    assert(String.contains(chain(ancestry(9n,1)),"8-actor"),"nine-actor eligible chain marks ancestry bound")
    assert(String.contains(inspect(actor("child","/synthetic/repo","absent","request",""),3,[]),"parent absent or ambiguous"),"missing parent differs from ancestry exhaustion")

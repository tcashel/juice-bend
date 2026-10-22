import Base
import ../src/quota_route.bend as R

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def root(value: Maybe<&2,String>) -> String:
  match value:
    case None{}: "default"
    case Some{value}: value

def describe(route: R.Route) -> String:
  match route:
    case R.Quota{root,args}: "quota|" ++ root ++ "|" ++ String.join(args,"|")
    case R.Capture{dir,args}: "capture|" ++ root(dir) ++ "|" ++ String.join(args,"|")
    case R.Rejected{}: "reject"

def route(args: List<&2,String>) -> String:
  describe(R.classify(args))

def main() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(route(["--data-dir","/synthetic/private","quota","status"]),"quota|/synthetic/private|status"),"exact explicit quota prefix bypasses capture initialization")
    require(String.eq(route(["--data-dir","/synthetic/private","quota"]),"quota|/synthetic/private|"),"missing quota operation stays in safe quota entry")
    require(String.eq(route(["quota","status"]),"reject"),"bare namespace cannot use default HOME")
    require(String.eq(route(["enable"]),"reject"),"missing quota prefix enable cannot create default capture storage")
    require(String.eq(route(["--data-dir","/synthetic/private","disconnect"]),"reject"),"missing namespace disconnect cannot initialize capture storage")
    require(String.eq(route(["observe-claude","1"]),"reject"),"bare passive receiver cannot access default HOME")
    require(String.eq(route(["statusline-claude","1"]),"reject"),"bare footer receiver cannot access default HOME")
    require(String.eq(route(["--quota","status"]),"reject"),"incorrect namespace flag is rejected before HOME")
    require(String.eq(route(["--data-dir"]),"reject"),"missing explicit root is rejected before HOME")
    require(String.eq(route(["--data-dir","quota","status"]),"capture|quota|status"),"ordinary capture root literally quota is not guessed to be a missing root")
    require(String.eq(route(["status"]),"capture|default|status"),"existing capture status retains its namespace")
    require(String.eq(route(["history","claude"]),"capture|default|history|claude"),"existing capture history retains its namespace")
    require(String.eq(route(["search","quota"]),"capture|default|search|quota"),"lexical quota keyword remains data")
    require(String.eq(route(["--data-dir","/synthetic/private","search","enable"]),"capture|/synthetic/private|search|enable"),"quota-only verb as search operand remains data")
    require(String.eq(route(["export","1","quota"]),"capture|default|export|1|quota"),"export operand quota remains a path")
    require(String.eq(route(["export-displayed","quota"]),"capture|default|export-displayed|quota"),"displayed export operand quota remains data")
    require(String.eq(route(["--data-dir","/synthetic/中文 café","quota","history","40"]),"quota|/synthetic/中文 café|history|40"),"explicit Unicode data root and history offset remain literal arguments")

import Base
import ../src/source_status.bend as Status
import ../src/json.bend as Json

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def report(status: String,count: Json.Json) -> Json.Json:
  Json.JObject{[Json.JField{"discovery",Json.JObject{[
    Json.JField{"status",Json.JString{status}},Json.JField{"files",count},
    Json.JField{"root",Json.JString{"/private/source/path"}},
    Json.JField{"error",Json.JString{"untrusted body must not appear"}}]}}]}

def scanning(+text: String) -> IO(Unit):
  do IO<Unit>:
    assert(String.contains(text,"continues across refreshes") && String.contains(text,"2126 files"),"scanning exposes bounded root-pass progress and its exact count")
    assert(String.contains(text,"Previously queued files remain available"),"scanning explains retained queue semantics")
    assert(Bool.not(String.contains(text,"completed")),"scanning never claims discovery completion")
    assert(Bool.not(String.contains(text,"/private/")) && Bool.not(String.contains(text,"untrusted body")),"summary never reflects source paths or free-form errors")

def main() -> IO(Unit):
  do IO<Unit>:
    scanning(Status.summary(report("scanning",Json.JNumber{"2126"})))
    assert(String.contains(Status.summary(report("cancelled",Json.JNumber{"0"})),"cancelled because its root settings or discovery pass changed"),"cancelled traversal has a distinct visible explanation")
    assert(String.contains(Status.summary(report("ok",Json.JNumber{"42"})),"completed this root pass; found 42 files"),"completion is explicitly limited to one root pass")
    assert(String.contains(Status.summary(report("failed",Json.JNumber{"0"})),"previously queued files and accepted captures remain available"),"failure preserves the ownership distinction")
    assert(String.contains(Status.summary(report("none",Json.JNumber{"0"})),"No source root is enabled"),"no-root state is explicit")
    assert(String.eq(Status.summary(Json.JObject{[]}),""),"standalone import replies acquire no discovery claim")
    assert(String.contains(Status.summary(report("future",Json.JNumber{"1"})),"does not establish root coverage"),"unknown future status is not shown as completed")
    assert(String.contains(Status.summary(report("scanning",Json.JNumber{"4294967295"})),"4294967295 files"),"largest exact U32 count is displayed without a float")
    assert(String.contains(Status.summary(report("scanning",Json.JNumber{"4294967296"})),"unknown files"),"overflow count becomes unknown instead of zero or wrapping")
    assert(String.contains(Status.summary(report("scanning",Json.JNumber{"-1"})),"unknown files"),"negative discovery count is rejected")
    assert(String.contains(Status.summary(report("scanning",Json.JNull{})),"unknown files"),"missing count remains unknown")
    assert(String.contains(Status.summary(report("scanning",Json.JString{"private count text"})),"unknown files"),"untrusted count text cannot enter the status summary")
    IO.print("Source status suite passed")

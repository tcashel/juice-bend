import Base
import ../src/gui_settings.bend as Settings
import ../src/refresh_preferences.bend as Refresh
import ../src/json.bend as Json

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def prefs(enabled: Json.Json,seconds: Json.Json,milliseconds: Json.Json) -> Json.Json:
  Json.JObject{[Json.JField{"kind",Json.JString{"refresh_preferences"}},
    Json.JField{"enabled",enabled},Json.JField{"interval_seconds",seconds},
    Json.JField{"interval_milliseconds",milliseconds}]}

def valid_prefs(enabled: Bool,seconds: String,milliseconds: String) -> Json.Json:
  prefs(Json.JBool{enabled},Json.JNumber{seconds},Json.JNumber{milliseconds})

def prefs_equal(result: Result<&2,&2,String,Refresh.Preferences>,expected: Refresh.Preferences) -> Bool:
  match result:
    case Done{actual}: Refresh.same(actual,expected)
    case Fail{_}: False{}

def prefs_bad(result: Result<&2,&2,String,Refresh.Preferences>) -> Bool:
  match result:
    case Done{_}: False{}
    case Fail{message}: Bool.not(String.is_empty(message))

def changed(+value: Json.Json,key: String,replacement: Json.Json) -> Json.Json:
  match value:
    case Json.JObject{fields}: Json.JObject{Json.JField{key,replacement} <> fields}
    case _: value

def preference_protocol() -> IO(Unit):
  +good = valid_prefs(True{},"30","30000")
  do IO<Unit>:
    assert(prefs_equal(Settings.prefs_decode(good),Refresh.Preferences{True{},Refresh.Live30{}}),"typed live preferences decode")
    assert(prefs_equal(Settings.prefs_decode(valid_prefs(False{},"7200","7200000")),Refresh.Preferences{False{},Refresh.Hours2{}}),"disabled two-hour complete pair decodes")
    assert(prefs_equal(Settings.prefs_decode(valid_prefs(True{},"14400","14400000")),Refresh.Preferences{True{},Refresh.Hours4{}}),"four-hour interval decodes")
    assert(prefs_equal(Settings.prefs_decode(valid_prefs(True{},"28800","28800000")),Refresh.Preferences{True{},Refresh.Hours8{}}),"eight-hour interval decodes")
    assert(prefs_equal(Settings.prefs_decode(valid_prefs(True{},"86400","86400000")),Refresh.Preferences{True{},Refresh.Daily{}}),"daily interval decodes")
    assert(prefs_bad(Settings.prefs_decode(prefs(Json.JString{"true"},Json.JNumber{"30"},Json.JNumber{"30000"}))),"string enabled is never coerced to boolean")
    assert(prefs_bad(Settings.prefs_decode(prefs(Json.JBool{True{}},Json.JString{"30"},Json.JNumber{"30000"}))),"string seconds is never coerced to number")
    assert(prefs_bad(Settings.prefs_decode(prefs(Json.JBool{True{}},Json.JNumber{"30"},Json.JString{"30000"}))),"string milliseconds is never coerced to number")
    assert(prefs_bad(Settings.prefs_decode(valid_prefs(True{},"030","30000"))),"noncanonical interval lexeme is rejected")
    assert(prefs_bad(Settings.prefs_decode(valid_prefs(True{},"30.0","30000"))),"fractional-looking interval lexeme is rejected")
    assert(prefs_bad(Settings.prefs_decode(valid_prefs(True{},"60","60000"))),"unsupported interval is rejected")
    assert(prefs_bad(Settings.prefs_decode(valid_prefs(True{},"30","29999"))),"milliseconds must agree exactly with seconds")
    assert(prefs_bad(Settings.prefs_decode(valid_prefs(True{},"30","3e4"))),"milliseconds exponent spelling is not canonical")
    assert(prefs_bad(Settings.prefs_decode(changed(good,"kind",Json.JString{"refresh_preferences"}))),"duplicate acknowledgement key is rejected even in a constructed JSON value")
    assert(prefs_bad(Settings.prefs_decode(changed(good,"extra",Json.JNull{}))),"unknown acknowledgement fields are rejected")
    assert(prefs_bad(Settings.prefs_decode(Json.JObject{[]})),"missing preference fields cannot become defaults in the GUI")
    assert(prefs_bad(Settings.prefs_decode(Json.JArray{[]})),"preference array cannot masquerade as an acknowledgement")

def row(provider: String,path: String,enabled: String) -> Json.Json:
  Json.JArray{[Json.JString{provider},Json.JString{path},Json.JString{enabled}]}

def inventory(rows: List<&2,Json.Json>) -> Json.Json:
  Json.JObject{[Json.JField{"columns",Json.JArray{[Json.JString{"provider"},Json.JString{"canonical_root"},Json.JString{"enabled"}]}},
    Json.JField{"rows",Json.JArray{rows}}]}

def inventory_rows(count: Nat,+at: U32) -> List<&2,Json.Json>:
  match count:
    case 0n: []
    case 1n+rest: row("claude","/synthetic/source-" ++ U32.show(at),"1") <> inventory_rows(rest,U32.add(at,1))

def source_count(result: Result<&2,&2,String,List<&2,Settings.Source>>) -> Nat:
  match result:
    case Done{rows}: List.length(&2,Settings.Source,rows)
    case Fail{_}: 99n

def sources_bad(result: Result<&2,&2,String,List<&2,Settings.Source>>) -> Bool:
  match result:
    case Done{_}: False{}
    case Fail{message}: Bool.not(String.is_empty(message))

def source_protocol() -> IO(Unit):
  do IO<Unit>:
    assert(Nat.is_eq(source_count(Settings.sources_decode(inventory([]))),0n),"empty registered-source inventory is valid")
    assert(Nat.is_eq(source_count(Settings.sources_decode(inventory(inventory_rows(32n,1)))),32n),"exactly thirty-two canonical source rows are accepted")
    assert(sources_bad(Settings.sources_decode(inventory(inventory_rows(33n,1)))),"thirty-three rows fail without accepting a partial inventory")
    assert(sources_bad(Settings.sources_decode(inventory([row("claude","/synthetic/a","1"),row("claude","/synthetic/a","0")]))),"duplicate identity is rejected even with differing enabled flags")
    assert(Nat.is_eq(source_count(Settings.sources_decode(inventory([row("claude","/synthetic/a","1"),row("codex","/synthetic/a","0")]))),2n),"provider domains may independently register the same path")
    assert(sources_bad(Settings.sources_decode(inventory([row("unknown","/synthetic/a","1")]))),"unknown source provider is rejected")
    assert(sources_bad(Settings.sources_decode(inventory([row("claude","relative/a","1")]))),"relative inventory root is rejected")
    assert(sources_bad(Settings.sources_decode(inventory([row("claude","/synthetic/a","true")]))),"source enabled state requires exact zero or one")
    assert(sources_bad(Settings.sources_decode(inventory([Json.JArray{[Json.JString{"claude"},Json.JString{"/synthetic/a"},Json.JBool{True{}}]}]))),"source enabled JSON boolean does not replace the CLI string protocol")
    assert(sources_bad(Settings.sources_decode(inventory([Json.JArray{[Json.JString{"claude"},Json.JString{"/synthetic/a"}]}]))),"short source row is rejected")
    assert(sources_bad(Settings.sources_decode(inventory([Json.JArray{[Json.JString{"claude"},Json.JString{"/synthetic/a"},Json.JString{"1"},Json.JString{"extra"}]}]))),"long source row is rejected")
    assert(sources_bad(Settings.sources_decode(Json.JObject{[Json.JField{"columns",Json.JArray{[Json.JString{"provider"},Json.JString{"enabled"},Json.JString{"canonical_root"}]}},Json.JField{"rows",Json.JArray{[]}}]})),"reordered source columns are rejected")
    assert(Settings.canonical("/") && Settings.canonical("/synthetic/path with spaces/中文"),"bounded absolute roots retain literal spaces and Unicode")
    assert(Settings.canonical("/" ++ String.repeat("x",4095n)),"exact 4096-character root is accepted")
    assert(Bool.not(Settings.canonical("/" ++ String.repeat("x",4096n))),"4097-character root is rejected")
    assert(Bool.not(Settings.canonical("/synthetic/a\0b")),"NUL root is rejected")
    assert(Bool.not(Settings.canonical("/synthetic/../b")) && Bool.not(Settings.canonical("/synthetic/./b")),"dot components cannot be labelled canonical")
    assert(Bool.not(Settings.canonical("//synthetic")) && Bool.not(Settings.canonical("/synthetic/")),"empty canonical components are rejected")

def added(provider: String,path: String,enabled: Json.Json) -> Json.Json:
  Json.JObject{[Json.JField{"registered",Json.JBool{True{}}},Json.JField{"enabled",enabled},
    Json.JField{"provider",Json.JString{provider}},Json.JField{"requested_root",Json.JString{path}}]}

def disabled(provider: String,path: String,enabled: Json.Json) -> Json.Json:
  Json.JObject{[Json.JField{"enabled",enabled},Json.JField{"provider",Json.JString{provider}},
    Json.JField{"requested_root",Json.JString{path}}]}

def acknowledgements() -> IO(Unit):
  +args = {["source-add","claude","/synthetic/a"] : List<&2,String>}
  do IO<Unit>:
    assert(Settings.source_ack(args,added("claude","/synthetic/a",Json.JBool{True{}})),"add acknowledgement binds exact provider and requested path")
    assert(Settings.source_ack(["source-disable","codex","/synthetic/a"],disabled("codex","/synthetic/a",Json.JBool{False{}})),"disable acknowledgement binds exact identity and typed false")
    assert(Bool.not(Settings.source_ack(args,added("codex","/synthetic/a",Json.JBool{True{}}))),"acknowledgement cannot switch provider")
    assert(Bool.not(Settings.source_ack(args,added("claude","/synthetic/b",Json.JBool{True{}}))),"acknowledgement cannot switch path")
    assert(Bool.not(Settings.source_ack(args,added("claude","/synthetic/a",Json.JString{"true"}))),"acknowledgement cannot coerce enabled text")
    assert(Bool.not(Settings.source_ack(args,disabled("claude","/synthetic/a",Json.JBool{True{}}))),"add acknowledgement requires registered true")
    assert(Bool.not(Settings.source_ack(["source-disable","claude","/synthetic/a"],disabled("claude","/synthetic/a",Json.JBool{True{}}))),"disable acknowledgement requires false")
    assert(Bool.not(Settings.source_ack(["import","claude","/synthetic/a"],added("claude","/synthetic/a",Json.JBool{True{}}))),"import result is not a source-registration acknowledgement")

def pending_is(result: Maybe<&2,Refresh.Preferences>,expected: Refresh.Preferences) -> Bool:
  match result:
    case None{}: False{}
    case Some{value}: Refresh.same(value,expected)

def no_deadline(result: Result<&2,&2,String,Maybe<&2,Nat>>) -> Bool:
  match result:
    case Done{None{}}: True{}
    case _: False{}

def deadline_is(result: Result<&2,&2,String,Maybe<&2,Nat>>,expected: Nat) -> Bool:
  match result:
    case Done{Some{actual}}: Nat.is_eq(actual,expected)
    case _: False{}

def deadline_bad(result: Result<&2,&2,String,Maybe<&2,Nat>>) -> Bool:
  match result:
    case Fail{message}: Bool.not(String.is_empty(message))
    case _: False{}

def selected_is(result: Maybe<&2,Settings.Source>,wanted: Settings.Source,enabled: Bool) -> Bool:
  match result:
    case Some{+value}:
      Settings.Source{provider,path,actual} = value
      Settings.same(value,wanted) && Bool.not(Bool.xor(actual,enabled))
    case None{}: False{}

def model() -> IO(Unit):
  +a = {Refresh.Preferences{False{},Refresh.Hours2{}} : Refresh.Preferences}
  +b = {Refresh.Preferences{True{},Refresh.Daily{}} : Refresh.Preferences}
  +ready = Settings.loaded(Settings.initial(),Refresh.defaults())
  +queued = Settings.desire(ready,a)
  +writing = Settings.loading(queued)
  +newer = Settings.desire(writing,b)
  +ack_a = Settings.saved(newer,a,a)
  +ack_b = Settings.saved(Settings.loading(ack_a),b,b)
  +wrong = Settings.saved(writing,a,Refresh.Preferences{False{},Refresh.Hours4{}})
  +source = {Settings.Source{"claude","/synthetic/a",True{}} : Settings.Source}
  +inventory = Settings.select(Settings.with_sources(ready,[source]),0)
  +reload = Settings.with_sources(inventory,[Settings.Source{"claude","/synthetic/a",False{}}])
  +failure = Settings.failed(Settings.desire(inventory,a),String.repeat("x",3000n))
  do IO<Unit>:
    assert(Bool.not(Settings.available(Settings.initial())) && no_deadline(Settings.deadline(Settings.initial(),1000n)),"unloaded defaults never start automatic refresh")
    assert(Settings.available(ready) && Bool.not(Settings.sources_loaded(ready)),"preference readiness is independent of source inventory load")
    assert(Bool.not(Settings.available(queued)) && Bool.not(Settings.paused(queued)) && Refresh.same(Settings.preferences(queued),Refresh.defaults()),"queued preference pair does not mutate acknowledged enabled state")
    assert(U32.is_eq(Settings.phase(writing),1) && pending_is(Settings.pending(writing),a),"writer start retains the complete pending pair")
    assert(Settings.paused(ack_a) && pending_is(Settings.pending(ack_a),b) && Bool.not(Settings.available(ack_a)),"older acknowledgement retains newer desired pair and suppresses auto starts")
    assert(Settings.available(ack_b) && Bool.not(Settings.paused(ack_b)) && Refresh.same(Settings.preferences(ack_b),b),"matching latest acknowledgement clears pending preference intent")
    assert(U32.is_eq(Settings.phase(wrong),3) && Refresh.same(Settings.preferences(wrong),Refresh.defaults()) && Bool.not(Settings.available(wrong)),"mismatched acknowledgement fails without changing last acknowledged pair")
    assert(pending_is(Settings.pending(Settings.loaded(Settings.desire(Settings.initial(),a),Refresh.defaults())),a),"startup preference load retains a queued explicit choice")
    assert(Settings.sources_loaded(Settings.loaded(inventory,a)),"preference acknowledgement retains source inventory load status")
    assert(selected_is(Settings.selected(reload),source,False{}),"source reload reselects exact identity and updates its enabled state")
    assert(Bool.not(Settings.sources_loaded(Settings.initial())),"initial source inventory is explicitly unloaded")
    assert(Nat.is_eq(String.length(Settings.last(failure)),2048n) && U32.is_eq(Settings.phase(failure),3),"failure diagnostics have a 2048-character bound")
    assert(selected_is(Settings.selected(failure),source,True{}) && Settings.sources_loaded(failure) && Settings.no_pending(Settings.pending(failure)),"preference failure retains sources and selection while clearing pending intent")
    assert(deadline_is(Settings.deadline(ack_b,1000n),86401000n),"daily schedule uses exact acknowledged monotonic milliseconds")
    assert(no_deadline(Settings.deadline(ack_a,1000n)) && no_deadline(Settings.deadline(writing,1000n)),"pending or unacknowledged preference work never arms refresh")
    assert(no_deadline(Settings.deadline(Settings.loaded(Settings.initial(),a),1000n)),"acknowledged disabled refresh has no deadline")
    assert(deadline_bad(Settings.deadline(ack_b,Refresh.native_limit())),"native Nat deadline overflow is an explicit failure")
    assert(String.contains(Settings.capture_label(),"bounded batches"),"capture completion label states bounded batch scope")

def main() -> IO(Unit):
  do IO<Unit>:
    preference_protocol()
    source_protocol()
    acknowledgements()
    model()
    IO.print("Settings model suite passed; pure protocol and transition coverage")

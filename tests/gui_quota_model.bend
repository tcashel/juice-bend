import Base
import ../src/gui_quota.bend as G
import ../src/quota_store.bend as S
import ../src/quota_cli.bend as C
import ../src/json.bend as J

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def parsed(result: Result<&2,&2,String,J.Json>) -> J.Json:
  match result:
    case Done{value}: value
    case Fail{_}: J.JNull{}

def value(text: String) -> J.Json:
  parsed(J.parse(text))

def accepted(result: Result<&2,&2,String,S.View>) -> Bool:
  match result:
    case Done{_}: True{}
    case Fail{_}: False{}

def response(operation: G.Operation,minimum: Nat,raw: String) -> Bool:
  accepted(G.decode(value(raw),operation,minimum))

def duplicate(value: J.Json) -> J.Json:
  match value:
    case J.JObject{fields}: J.JObject{J.JField{"epoch",J.JString{"1"}} <> fields}
    case other: other

def transport(result: Result<&2,&2,String,J.Json>) -> Bool:
  match result:
    case Done{_}: True{}
    case Fail{_}: False{}

def synthetic_samples(n: Nat) -> List<&2,J.Json>:
  match n:
    case 0n: []
    case 1n+ +rest: J.JObject{[J.JField{"sequence",J.JString{Nat.show(1n+rest)}},
      J.JField{"epoch",J.JString{"1"}},J.JField{"received_at",J.JString{"100"}},
      J.JField{"parser",J.JString{S.policy()}},J.JField{"five_hour",J.JObject{[
        J.JField{"used_millionths",J.JNumber{"0"}},J.JField{"resets_at",J.JNull{}}]}},J.JField{"seven_day",J.JNull{}}]} <> synthetic_samples(rest)

def history_page(n: Nat,more: Bool) -> J.Json:
  J.JObject{[J.JField{"kind",J.JString{C.protocol()}},J.JField{"outcome",J.JString{"history"}},
    J.JField{"enabled",J.JBool{False{}}},J.JField{"epoch",J.JString{"2"}},
    J.JField{"samples",J.JArray{synthetic_samples(n)}},J.JField{"more",J.JBool{more}}]}

def protocol_0() -> IO(Unit):
  do IO<Unit>:
    assert(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}"),"known zero and unknown reset remain a valid partial observation")
    assert(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":false,\"epoch\":\"0\",\"samples\":[],\"more\":false}"),"absent store is acknowledged off epoch zero")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false,\"extra\":null}")),"reject malformed complete envelope extraNone")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":1,\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject malformed complete envelope epoch1")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"01\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject malformed complete envelope epoch01")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"281474976710656\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject malformed complete envelope epoch281474976710656")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":\"true\",\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject malformed complete envelope enabledtrue")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":0}")),"reject malformed complete envelope more0")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":{},\"more\":false}")),"reject malformed complete envelope samples{}")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"enabled\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject malformed complete envelope outcomeenabled")

def protocol_1() -> IO(Unit):
  do IO<Unit>:
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"other\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject malformed complete envelope kindother")
    assert(Bool.not(response(G.Status{},0n,"{\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject missing kind")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject missing outcome")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject missing enabled")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject missing epoch")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"more\":false}")),"reject missing samples")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}]}")),"reject missing more")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"0\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject malformed sample sequence0")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":1,\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject malformed sample sequence1")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"2\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject malformed sample epoch2")

def protocol_2() -> IO(Unit):
  do IO<Unit>:
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"0\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject malformed sample epoch0")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":100,\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject malformed sample received_at100")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"253402300800\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject malformed sample received_at253402300800")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"future\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject malformed sample parserfuture")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null,\"extra\":\"x\"}],\"more\":false}")),"reject malformed sample extrax")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":-1,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject used syntax/range -1")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":100000001,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject used syntax/range 100000001")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":\"0\",\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject used syntax/range 0")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":1.2,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"reject used syntax/range 1.2")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":1},\"seven_day\":null}],\"more\":false}")),"reject reset syntax/range 1")

def protocol_3() -> IO(Unit):
  do IO<Unit>:
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":\"01\"},\"seven_day\":null}],\"more\":false}")),"reject reset syntax/range 01")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":\"253402300800\"},\"seven_day\":null}],\"more\":false}")),"reject reset syntax/range 253402300800")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":null,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"empty observation is not feed evidence")
    assert(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":\"0\"},\"seven_day\":null}],\"more\":false}"),"zero reset is known rather than null")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null},{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"status cannot return multiple samples")
    assert(Bool.not(response(G.Status{},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":true}")),"status cannot claim history continuation")
    assert(response(G.Enable{},1n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"enabled\",\"enabled\":true,\"epoch\":\"2\",\"samples\":[],\"more\":false}"),"enable acknowledges a strictly newer epoch")
    assert(Bool.not(response(G.Enable{},1n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"enabled\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[],\"more\":false}")),"enable cannot reuse current epoch")
    assert(response(G.Disconnect{},1n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"disconnected\",\"enabled\":false,\"epoch\":\"1\",\"samples\":[],\"more\":false}"),"disconnect retains exact acknowledged epoch")
    assert(Bool.not(response(G.Disconnect{},1n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"disconnected\",\"enabled\":false,\"epoch\":\"2\",\"samples\":[],\"more\":false}")),"disconnect cannot acknowledge a different epoch")

def protocol_4() -> IO(Unit):
  do IO<Unit>:
    assert(response(G.History{0},1n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"history\",\"enabled\":false,\"epoch\":\"2\",\"samples\":[{\"sequence\":\"3\",\"epoch\":\"2\",\"received_at\":\"50\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null},{\"sequence\":\"2\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}"),"history accepts clock reversal and retained old epoch ordered by sequence")
    assert(Bool.not(response(G.History{0},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"history\",\"enabled\":false,\"epoch\":\"2\",\"samples\":[{\"sequence\":\"2\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null},{\"sequence\":\"3\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"history rejects ascending sequence")
    assert(Bool.not(response(G.History{0},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"history\",\"enabled\":false,\"epoch\":\"2\",\"samples\":[{\"sequence\":\"3\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null},{\"sequence\":\"3\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),"history rejects duplicate sequence")
    assert(accepted(G.decode(history_page(40n,True{}),G.History{0},0n)),"full forty sample page may advertise continuation")
    assert(Bool.not(response(G.History{0},0n,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"history\",\"enabled\":false,\"epoch\":\"2\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":true}")),"short history page cannot advertise continuation")
    assert(Bool.not(accepted(G.decode(history_page(41n,False{}),G.History{0},0n))),"history cannot exceed forty samples")
    assert(Bool.not(accepted(G.decode(duplicate(value("{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")),G.Status{},0n))),"duplicate keys reject even constructed values")

def protocol() -> IO(Unit):
  do IO<Unit>:
    assert(Bool.not(accepted(G.decode(history_page(40n,False{}),G.History{32760},0n))),"history page cannot cross hard retained-row capacity")
    assert(Bool.not(accepted(G.decode(history_page(40n,True{}),G.History{32728},0n))),"last capacity page cannot advertise more")
    protocol_0()
    protocol_1()
    protocol_2()
    protocol_3()
    protocol_4()

def fixture_origin() -> G.Model:
  G.initial("/synthetic/private")

def fixture_status() -> G.Request:
  {G.Request{"1","/synthetic/private",G.Status{},0n} : G.Request}

def fixture_loading() -> G.Model:
  G.begin(fixture_origin(),fixture_status())

def fixture_off() -> G.Model:
  G.apply(fixture_loading(),fixture_status(),Done{value("{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":false,\"epoch\":\"0\",\"samples\":[],\"more\":false}")})

def fixture_enable() -> G.Request:
  {G.Request{"2","/synthetic/private",G.Enable{},0n} : G.Request}

def fixture_on() -> G.Model:
  G.apply(G.begin(fixture_off(),fixture_enable()),fixture_enable(),Done{value("{\"kind\":\"claude_quota_v1\",\"outcome\":\"enabled\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[],\"more\":false}")})

def fixture_setup() -> G.Model:
  G.setup_view(fixture_on())

def fixture_edit() -> G.Model:
  G.edit(fixture_setup(),"/synthetic/other")

def fixture_away_back() -> G.Model:
  G.edit(fixture_edit(),"/synthetic/private")

def fixture_late() -> G.Model:
  G.apply(fixture_away_back(),fixture_enable(),Done{value("{\"kind\":\"claude_quota_v1\",\"outcome\":\"enabled\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[],\"more\":false}")})

def fixture_refresh() -> G.Request:
  {G.Request{"3","/synthetic/private",G.Status{},1n} : G.Request}

def fixture_observed() -> G.Model:
  G.apply(G.begin(fixture_on(),fixture_refresh()),fixture_refresh(),Done{value("{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}")})

def fixture_disconnect() -> G.Request:
  {G.Request{"4","/synthetic/private",G.Disconnect{},1n} : G.Request}

def fixture_stopped() -> G.Model:
  G.apply(G.begin(fixture_observed(),fixture_disconnect()),fixture_disconnect(),Done{value("{\"kind\":\"claude_quota_v1\",\"outcome\":\"disconnected\",\"enabled\":false,\"epoch\":\"1\",\"samples\":[],\"more\":false}")})

def lifecycle() -> IO(Unit):
  do IO<Unit>:
    assert(G.can_enable(fixture_off()),"Off acknowledgement permits explicit enable")
    assert(Bool.not(G.can_enable(fixture_loading())),"pending status cannot enable")
    assert(G.can_disconnect(fixture_on()) && Bool.not(G.can_copy(fixture_on())),"enable acknowledgement alone does not authorize setup copying")
    assert(G.can_copy(fixture_setup()),"reviewed enabled setup can be copied")
    assert(Bool.not(G.can_copy(fixture_edit())) && Bool.not(G.acknowledged(fixture_edit())),"root edit retires acknowledgement and setup")
    assert(Bool.not(G.can_copy(fixture_late())) && U32.is_eq(G.phase(fixture_late()),0),"root away and back cannot revive old reply")
    assert(Bool.not(G.can_disconnect(fixture_stopped())) && G.can_enable(fixture_stopped()),"disconnect yields off state")
    assert(String.contains(G.body(fixture_stopped(),"/synthetic/app"),"Receipt order: 1"),"disconnect retains prior observation as saved history")
    assert(String.contains(G.body(fixture_observed(),"/synthetic/app"),"0.000000% used"),"known zero renders explicitly")
    assert(String.contains(G.body(fixture_observed(),"/synthetic/app"),"Reset: unknown"),"unknown reset never becomes zero")
    assert(U32.is_eq(G.phase(G.begin(fixture_origin(),G.Request{"0","/synthetic/private",G.Status{},0n})),0),"zero request token never queues")
    assert(U32.is_eq(G.phase(G.begin(fixture_origin(),G.Request{"1","/synthetic/other",G.Status{},0n})),0),"request root binds exact model root")
    assert(U32.is_eq(G.phase(G.apply(G.begin(fixture_on(),fixture_refresh()),fixture_status(),Done{value("{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":false,\"epoch\":\"0\",\"samples\":[],\"more\":false}")})),1),"different token and minimum cannot consume pending request")
    assert(U32.is_eq(G.phase(G.apply(G.begin(fixture_on(),fixture_refresh()),fixture_refresh(),Fail{"private diagnostics"})),3),"worker failure retires pending state")
    assert(Bool.not(String.contains(G.body(G.failed(fixture_on(),"Unavailable"),"/synthetic/app"),"private diagnostics")),"raw worker diagnostics do not become body evidence")

def channels() -> IO(Unit):
  do IO<Unit>:
    assert(transport(G.transport_exit(0,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}","")),"success on clean stdout accepted")
    assert(transport(G.transport_exit(2,"","{\"kind\":\"claude_quota_v1\",\"outcome\":\"error\",\"code\":\"quota_root\",\"message\":\"private supplied detail\"}")),"closed error on stderr accepted")
    assert(Bool.not(transport(G.transport_exit(0,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"error\",\"code\":\"quota_root\",\"message\":\"private supplied detail\"}",""))),"error cannot masquerade as successful channel")
    assert(Bool.not(transport(G.transport_exit(2,"","{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}"))),"success cannot masquerade as failed channel")
    assert(Bool.not(transport(G.transport_exit(0,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"1\",\"samples\":[{\"sequence\":\"1\",\"epoch\":\"1\",\"received_at\":\"100\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":null}],\"more\":false}","unexpected"))),"mixed diagnostic channel refuses whole reply")
    assert(Bool.not(transport(G.transport_exit(0,String.repeat("x",131073n),""))),"oversized child output refuses before parse")

def main() -> IO(Unit):
  do IO<Unit>:
    protocol()
    lifecycle()
    channels()

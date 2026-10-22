import Base
import ../src/gui_quota.bend as G
import ../src/claude_quota.bend as Q
import ../src/quota_store.bend as S
import ../src/quota_cli.bend as C
import ../src/ui.bend as UI


def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def date_value(value: Maybe<&2,Nat>,+expected: String) -> IO(Unit):
  match value:
    case None{}: IO.die(Unit,1,"FAIL independent date vector is outside admitted integer range")
    case Some{seconds}: require(String.eq(G.utc(seconds),expected),"exact UTC " ++ expected)

def date(seconds: String,expected: String) -> IO(Unit):
  date_value(S.natural(seconds,G.time_max()),expected)

# Independent fixed vectors from Gregorian UTC timestamps, including both
# seconds around midnight, leap centuries, a nonleap century and both bounds.
def dates() -> IO(Unit):
  do IO<Unit>:
    date("0","1970-01-01 00:00:00 UTC")
    date("86399","1970-01-01 23:59:59 UTC")
    date("86400","1970-01-02 00:00:00 UTC")
    date("2678399","1970-01-31 23:59:59 UTC")
    date("2678400","1970-02-01 00:00:00 UTC")
    date("5097599","1970-02-28 23:59:59 UTC")
    date("5097600","1970-03-01 00:00:00 UTC")
    date("946684799","1999-12-31 23:59:59 UTC")
    date("946684800","2000-01-01 00:00:00 UTC")
    date("951782399","2000-02-28 23:59:59 UTC")
    date("951782400","2000-02-29 00:00:00 UTC")
    date("951868799","2000-02-29 23:59:59 UTC")
    date("951868800","2000-03-01 00:00:00 UTC")
    date("2147483647","2038-01-19 03:14:07 UTC")
    date("2147483648","2038-01-19 03:14:08 UTC")
    date("4107542399","2100-02-28 23:59:59 UTC")
    date("4107542400","2100-03-01 00:00:00 UTC")
    date("13574563199","2400-02-28 23:59:59 UTC")
    date("13574563200","2400-02-29 00:00:00 UTC")
    date("13574649600","2400-03-01 00:00:00 UTC")
    date("253402300799","9999-12-31 23:59:59 UTC")
    require(String.eq(G.utc(Nat.add(G.time_max(),1n)),"outside supported UTC range"),"out-of-range internal date never wraps to a plausible date")

def percent(n: U32,+expected: String) -> IO(Unit):
  require(String.eq(G.percentage(Some{n}),expected),"lossless percentage " ++ expected)

def percentages() -> IO(Unit):
  do IO<Unit>:
    percent(0,"0% used")
    percent(1,"0.000001% used")
    percent(10,"0.00001% used")
    percent(100000,"0.1% used")
    percent(1000000,"1% used")
    percent(25125000,"25.125% used")
    percent(99999999,"99.999999% used")
    percent(100000000,"100% used")
    require(String.eq(G.percentage(None{}),"unknown"),"unknown percentage is distinct from known zero")
    require(String.eq(G.reset_text(None{}),"unknown"),"unknown reset is not Unix zero")
    require(String.eq(G.reset_text(Some{0n}),"1970-01-01 00:00:00 UTC"),"known zero reset retains its exact date")

def sample() -> S.Sample:
  S.Sample{2n,1n,1792611627n,Q.Observation{
    Some{Q.QuotaWindow{Some{25125000},Some{1700000000n}}},
    Some{Q.QuotaWindow{None{},Some{1700600000n}}}}}

def model(on: Bool,current: Maybe<&2,S.Sample>,view: U32) -> G.Model:
  G.Model{"/synthetic/private",2,Some{S.State{1n,on}},current,[sample()],0,False{},view,0,None{},""}

def observed() -> G.Model:
  model(True{},Some{sample()},0)

def body() -> String:
  G.body(observed(),"/synthetic/juice-bend")

def leading(text: String) -> String:
  String.take(text,210n)

def presentation() -> IO(Unit):
  do IO<Unit>:
    require(String.starts_with(body(),"Claude Code quota\n\nOn | Latest local observation\n\nFive-hour: 25.125% used\nReset: 2023-11-14 22:13:20 UTC\n\nSeven-day: unknown\nReset: 2023-11-21 20:53:20 UTC\n"),"useful two-window state and readable exact resets lead the reader")
    require(String.contains(body(),"Received locally: 2026-10-21 19:40:27 UTC"),"local receipt has a readable UTC date with no relative freshness claim")
    require(String.contains(body(),"Local receipt time does not establish provider freshness."),"receipt and provider freshness remain explicitly distinct")
    require(Bool.not(String.contains(leading(body()),"epoch")) && Bool.not(String.contains(leading(body()),"sequence")),"technical identity fields do not dominate the summary")
    require(String.contains(body(),"Details | Recorded fields\nLocal collection: on\nConnection epoch: 1\nParser policy: claude-statusline-v1\nReceipt sequence: 2\nObservation epoch: 1\nReceived Unix seconds: 1792611627\n"),"appendix preserves exact state identity parser and receipt integer")
    require(String.contains(body(),"Five-hour supplied: yes\nFive-hour used millionths: 25125000\nFive-hour reset Unix seconds: 1700000000\nSeven-day supplied: yes\nSeven-day used millionths: unknown\nSeven-day reset Unix seconds: 1700600000\n"),"appendix preserves every raw window value and null distinction")
    require(String.contains(body(),"32,768") && String.contains(body(),"five-minute slot") && String.contains(body(),"clock changes can reverse") && String.contains(body(),"not provider events"),"sampling limit and clock/ordering limitations remain in full evidence")
    require(String.contains(body(),"explicit local opt-in") && String.contains(body(),"Enable creates a dedicated private quota store in the selected Juice Bend data directory."),"details preserve the explicit opt-in and private selected-store creation disclosure")
    require(String.contains(body(),"Account, plan and billed spend are not identified.") && String.contains(body(),"API-equivalent estimates"),"quota remains separate from account identity and conversation estimates")
    require(String.starts_with(G.body(model(False{},None{},0),"/synthetic/app"),"Claude Code quota\n\nOff\nChoose Enable, then review Manual setup.\n"),"empty Off state leads with the explicit next action")
    require(String.contains(G.body(model(True{},None{},0),"/synthetic/app"),"On | Waiting for quota observations\nReview Manual setup"),"locally enabled awaiting-feed state does not claim a received feed")
    require(String.contains(G.body(model(False{},Some{sample()},0),"/synthetic/app"),"Off | Saved observation"),"disconnect labels retained values as saved observations")
    require(String.starts_with(G.body(G.initial("/synthetic/private"),"/synthetic/app"),"Claude Code quota\n\nState unknown\nChoose Refresh"),"unacknowledged state never appears as Off")
    require(String.contains(G.body(G.failed(observed(),"diagnostic withheld"),"/synthetic/app"),"A change may have committed.") && String.contains(G.body(G.failed(observed(),"diagnostic withheld"),"/synthetic/app"),"last acknowledgement"),"unavailable UI keeps conservative uncertain-write and old-acknowledgement disclosure")
    require(String.contains(G.window_text(None{},"Five-hour"),"not supplied") && String.contains(G.window_details(None{},"Five-hour"),"supplied: no"),"absent window remains distinct from present unknown fields")
    require(String.eq(G.window_details(Some{Q.QuotaWindow{None{},None{}}},"Five-hour"),"Five-hour supplied: yes\nFive-hour used millionths: unknown\nFive-hour reset Unix seconds: unknown\n"),"present all-null window retains presence and unknown fields")
    require(String.starts_with(G.body(model(False{},Some{sample()},1),"/synthetic/app"),"Saved quota observation\n\nFive-hour: 25.125% used"),"history begins with saved useful values rather than technical receipt identity")

def setup_result(value: C.result_type()) -> String:
  match value:
    case Done{fragment}: fragment
    case Fail{_}: ""

def setup_body() -> String:
  G.body(G.setup_view(observed()),"/synthetic/café 中文 🙂/juice-bend")

def copied(value: UI.State & UI.Action) -> String:
  (state,action) = value
  match action:
    case UI.Copy{text}: text
    case _: ""

def copy_text(+text: String) -> String:
  +state = UI.select_all(UI.set_edit(UI.set_reader(UI.init(),"Quota",text),UI.Edit{2,0,0,False{},0}))
  copied(UI.event(Key{99,True{}},UI.set_modifiers(state,True{},False{})))

def text_integrity() -> IO(Unit):
  do IO<Unit>:
    require(String.contains(setup_body(),setup_result(C.setup("/synthetic/café 中文 🙂/juice-bend","/synthetic/private",1n))),"setup preserves the exact original literal JSON fragment including Unicode")
    require(String.contains(setup_body(),"keyboard shortcut hints") && String.contains(setup_body(),"nothing is installed automatically") && String.contains(setup_body(),"does not authenticate an account or prove a feed was received"),"shortened setup retains replacement and installation/authentication/feed caveats")
    require(String.eq(copy_text(body()),body()),"native UI scalar SelectAll Copy preserves the complete summary and raw appendix")
    require(String.eq(copy_text(setup_body()),setup_body()),"native UI scalar SelectAll Copy preserves the full Unicode manual-setup text")
    require(String.eq(G.sample_title(sample()),"2026-10-21 19:40:27 UTC | #2"),"history card is one readable exact receipt-time label")
    require(Bool.not(String.contains(G.sample_title(sample()),"\n")) && Bool.not(String.contains(G.sample_title(sample()),"\r")) && Bool.not(String.contains(G.sample_title(sample()),"\t")),"history row contains no control glyph masquerading as a line break")
    require(String.eq(G.sample_title(S.Sample{S.cap(),1n,G.time_max(),Q.Observation{None{},None{}}}),"9999-12-31 23:59:59 UTC | #281474976710655"),"largest exact receipt identity remains in row text without numeric rounding")

def main() -> IO(Unit):
  do IO<Unit>:
    dates()
    percentages()
    presentation()
    text_integrity()

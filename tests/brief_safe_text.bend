import Base
import ../src/brief_safe_text.bend as Safe
import ../src/json.bend as Json

# Independent exact output/count oracles. No database, real source path,
# credentials, provider process, clipboard or filesystem writes occur here.
def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def equal(result: Safe.Transform,text: String,credentials: U32,paths: U32,controls: U32) -> Bool:
  Safe.Transform{actual,c,p,k} = result
  String.eq(actual,text) && U32.is_eq(c,credentials) && U32.is_eq(p,paths) && U32.is_eq(k,controls)

def expect(text: String,roots: List<&2,String>,source: String,wanted: String,c: U32,p: U32,k: U32,label: String) -> IO(Unit):
  check(equal(Safe.transform(text,roots,source),wanted,c,p,k),label)

def unchanged(+text: String,label: String) -> IO(Unit):
  expect(text,["/synthetic/repo"],"/synthetic/captures/session.jsonl",text,0,0,0,label)

def credential(text: String,label: String) -> IO(Unit):
  expect(text,["/synthetic/repo"],"/synthetic/captures/session.jsonl","[credential-shaped field withheld]",1,0,0,label)

def local(text: String,label: String) -> IO(Unit):
  expect(text,["/synthetic/repo"],"/synthetic/captures/session.jsonl","[local-path field withheld]",0,1,0,label)

def ordinary() -> IO(Unit):
  do IO<Unit>:
    unchanged("","empty field remains empty")
    unchanged("Fix café 中 🙂 é and verify the results.","visible Unicode and combining sequence stay exact")
    unchanged("# heading **bold** `echo harmless` <script>literal</script>","Markdown HTML and command-looking text remain inert exact data")
    unchanged("src/file.bend and a/b plus x / y", "relative paths and spaced division remain exact")
    unchanged("https://example.invalid/path?q=value#anchor", "ordinary URL without userinfo remains exact")
    unchanged("secret password api_key access_token authorization", "bare key names without values are not credential fields")
    unchanged("passwordish=value and secretary=value", "credential key lookalikes do not match")
    unchanged("desk-token and mygithub_pat_marker", "token family inside an ordinary word is not a prefix match")
    unchanged("-----BEGIN PUBLIC KEY----- harmless", "public key header is not private-key family")
    unchanged("sk- ghp_ github_pat_ xoxb-", "credential prefixes without a following token remain exact")
    unchanged("password=\"\"", "structurally empty quoted credential value carries no withheld content")
    unchanged("/", "standalone slash is not guessed to be a local pathname")

def credential_cases() -> IO(Unit):
  do IO<Unit>:
    credential("before sk-synthetic_123 after", "sk credential family withholds the entire field")
    credential("ghp_synthetic123", "GitHub classic token family")
    credential("github_pat_synthetic123", "GitHub fine-grained token family")
    credential("xoxb-synthetic", "Slack bot family")
    credential("xoxa-synthetic", "Slack app family")
    credential("xoxp-synthetic", "Slack user family")
    credential("xoxr-synthetic", "Slack refresh family")
    credential("xoxs-synthetic", "Slack session family")
    credential("Authorization: Bearer synthetic-token", "Authorization assignment family")
    credential("bearer synthetic-token", "case-insensitive Bearer family")
    credential("{\"password\":\"synthetic-value\"}", "JSON password assignment is recognized without parsing commands")
    credential("{\"password\":\",synthetic-value\"}", "quoted password beginning with comma is still a nonempty credential")
    credential("{\"password\":\"}synthetic-value\"}", "quoted password beginning with brace is withheld")
    credential("{\"password\":\"]synthetic-value\"}", "quoted password beginning with bracket is withheld")
    credential("password=\" \"", "quoted whitespace credential value is nonempty")
    credential("SECRET = synthetic-value", "case-insensitive environment secret assignment")
    credential("api_key='synthetic-value'", "quoted api_key assignment")
    credential("access_token: synthetic-value", "access_token assignment")
    credential("api-key: synthetic-value", "hyphenated api-key assignment")
    credential("access-token=synthetic-value", "hyphenated access-token assignment")
    credential("https://user:synthetic@example.invalid/path", "URL userinfo withholds the complete field")
    credential("ssh://user@example.invalid/repo", "even username-only URL userinfo is conservatively withheld")
    credential("prefix -----BEGIN PRIVATE KEY----- synthetic", "generic private key header")
    credential("-----BEGIN RSA PRIVATE KEY----- synthetic", "RSA private key header")
    credential("-----BEGIN EC PRIVATE KEY----- synthetic", "EC private key header")
    credential("-----BEGIN DSA PRIVATE KEY----- synthetic", "DSA private key header")
    credential("-----BEGIN OPENSSH PRIVATE KEY----- synthetic", "OpenSSH private key header")
    credential("-----BEGIN ENCRYPTED PRIVATE KEY----- synthetic", "encrypted private key header")
    credential("sk-synthetic /private/other\u{202e}", "credential withholding wins without leaking path or control content")
    credential("secret" ++ String.repeat(" ",33n) ++ "unknown", "over-budget assignment padding is conservatively withheld")

def known_paths() -> IO(Unit):
  do IO<Unit>:
    expect("read /synthetic/repo/src/main.bend",["/synthetic/repo"],"/synthetic/log.jsonl",
      "read [repository]/src/main.bend",0,1,0,"known root token becomes repository alias with exact relative suffix")
    expect("/synthetic/repo",["/synthetic/repo"],"/synthetic/log.jsonl",
      "[repository]",0,1,0,"exact known root has an alias")
    expect("\"/synthetic/repo/a\" and `/synthetic/repo/b`",["/synthetic/repo"],"/synthetic/log.jsonl",
      "\"[repository]/a\" and `[repository]/b`",0,1,0,"multiple known path replacements count one transformed field")
    expect("[/synthetic/captures/session.jsonl]",["/synthetic"],"/synthetic/captures/session.jsonl",
      "[[source]]",0,1,0,"exact source wins over a containing repository prefix")
    expect("/synthetic/captures/session.jsonl:42",[],"/synthetic/captures/session.jsonl",
      "[source]:42",0,1,0,"source alias preserves a separate line number")
    expect("/synthetic/repo/worktree/a",["/synthetic/repo","/synthetic/repo/worktree"],"/synthetic/log",
      "[repository]/a",0,1,0,"longest known worktree root wins")
    expect("/synthetic/repo/worktree/a",["/synthetic/repo/worktree","/synthetic/repo"],"/synthetic/log",
      "[repository]/a",0,1,0,"root order cannot change longest-match output")
    expect("open '/synthetic/repo café/中🙂.bend'",["/synthetic/repo café"],"/synthetic/log",
      "open '[repository]/中🙂.bend'",0,1,0,"explicit Unicode space-containing root matches literally")
    expect("/synthetic/repo/sub/file",["","/","/synthetic/repo"],"",
      "[repository]/sub/file",0,1,0,"empty and filesystem-root descriptors cannot swallow arbitrary paths")
    expect("/synthetic/capture path/file.jsonl",[],"/synthetic/capture path/file.jsonl",
      "[source]",0,1,0,"exact source descriptor may contain a space")

def unknown_paths() -> IO(Unit):
  do IO<Unit>:
    local("read /private/other/file", "unrecognized absolute path withholds its whole field")
    local("/synthetic/repository/file", "known-root prefix collision cannot be aliased")
    local("/synthetic/repo/../outside", "parent traversal after known root is withheld")
    local("/synthetic/repo/.. and more", "terminal parent component before delimiter is withheld")
    local("/synthetic/repo/./file", "ambiguous dot segment is withheld")
    local("/synthetic/captures/session.jsonl.backup", "source prefix collision cannot disclose a sibling locator")
    local("~/private/file", "home path is withheld")
    local("~someone/private/file", "named home path is withheld")
    local("$HOME/private/file", "HOME expansion path is withheld")
    local("${HOME}/private/file", "braced HOME expansion path is withheld")
    local("C:\\private\\file", "Windows drive path is withheld")
    local("C:/private/file", "forward-slash Windows drive path is withheld")
    local("\\\\host\\share", "UNC path is withheld")
    local("\\/private\\/file", "escaped slash path is withheld")
    local("\\u002fprivate\\u002ffile", "escaped Unicode slash path is withheld")
    local("%2Fprivate%2Ffile", "percent-encoded slash path is withheld")
    local("file:///synthetic/repo/a", "file URL is conservatively withheld rather than reinterpreted")
    local("/synthetic/repo/a then /unknown/other", "a later unknown path withholds earlier safe aliases too")
    local("\u{202e}/unknown/path", "bidi immediately before absolute path cannot evade withholding")
    local("\u{200b}/unknown/path", "zero-width immediately before absolute path cannot evade withholding")
    local("</private/path>", "closing markup with nested slash does not exempt an absolute path")
    local("before\u{200b} /unknown/path", "whole-path withholding does not count controls that never render")

def controls() -> IO(Unit):
  do IO<Unit>:
    expect("A\0B\nC\tD\rE",[],"","A\\u0000B\\u000aC\\u0009D\\u000dE",0,0,4,
      "C0 controls become visible literal escapes with exact counts")
    expect("x\u{007f}\u{0085}\u{00ad}\u{034f}y",[],"","x\\u007f\\u0085\\u00ad\\u034fy",0,0,4,
      "delete next-line soft-hyphen and grapheme joiner remain visible")
    expect("\u{061c}\u{180e}\u{200b}\u{200c}\u{200d}\u{200e}\u{200f}",[],"",
      "\\u061c\\u180e\\u200b\\u200c\\u200d\\u200e\\u200f",0,0,7,"directional and zero-width controls are escaped")
    expect("\u{2028}\u{2029}\u{202a}\u{202b}\u{202c}\u{202d}\u{202e}",[],"",
      "\\u2028\\u2029\\u202a\\u202b\\u202c\\u202d\\u202e",0,0,7,"line separators and bidi embeddings are visible")
    expect("\u{2060}\u{2066}\u{2067}\u{2068}\u{2069}\u{206f}\u{feff}",[],"",
      "\\u2060\\u2066\\u2067\\u2068\\u2069\\u206f\\ufeff",0,0,7,"word joiners isolates and BOM are visible")
    expect("/synthetic/repo/é\u{202e}.txt",["/synthetic/repo"],"/synthetic/log",
      "[repository]/é\\u202e.txt",0,1,1,"path and control transformations are independently counted")
    check(String.eq(Json.quote("literal \\u202e"),"\"literal \\\\u202e\""),
      "caller JSON quoting preserves visible escape text rather than activating the control")

def large() -> IO(Unit):
  +ascii = String.repeat("a",524288n)
  +unicode = String.repeat("🙂",131072n)
  do IO<Unit>:
    check(equal(Safe.transform(ascii,[],""),ascii,0,0,0),"512KiB ASCII admission stays exact without growing append")
    check(equal(Safe.transform(unicode,[],""),unicode,0,0,0),"512KiB multibyte admission stays exact")
    credential(String.repeat("a",262144n) ++ " sk-synthetic", "credential family at a long field tail still withholds all preceding content")
    local(String.repeat("a",262144n) ++ " /unknown/path", "unknown path at a long field tail cannot leave a partial field")

def main() -> IO(Unit):
  do IO<Unit>:
    ordinary()
    credential_cases()
    known_paths()
    unknown_paths()
    controls()
    large()

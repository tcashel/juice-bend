import Base

# Presentation roles only. These colors never classify retained text or grant
# an action; the existing typed state and admission policy remain authoritative.
type Ink is Data:
  Body{}
  Secondary{}
  Heading{}
  Action{}
  Brand{}

type Surface is Data:
  Paper{}
  Navigation{}
  List{}
  Current{}
  Selection{}

def ink(role: Ink) -> U32:
  match role:
    case Body{}: 2438444
    case Secondary{}: 5858909
    case Heading{}: 1588778
    case Action{}: 2909508
    case Brand{}: 12406048

def surface(role: Surface) -> U32:
  match role:
    case Paper{}: 16777215
    case Navigation{}: 15921900
    case List{}: 16448246
    case Current{}: 16774082
    case Selection{}: 13953013

# Only application title chrome is shortened. The full title, captured page,
# selection and export strings are retained by UI.State exactly as received.
def heading(+title: String) -> String:
  Bool.pick(String,String.starts_with(title,"Transcript | pinned snapshot "),"Transcript",
    Bool.pick(String,String.starts_with(title,"Why | pinned snapshot "),"Why this request",Bool.pick(String,String.starts_with(title,"claude | snapshot "),"Claude transcript",Bool.pick(String,String.starts_with(title,"codex | snapshot "),"Codex transcript",title))))

def fit_heading(+title: String,+columns: U32) -> String:
  match columns:
    case 0: ""
    case _:
      Bool.pick(String,U32.is_gt(U32.from_nat(String.length(title)),columns),
        String.take(title,U32.to_nat(U32.sub(columns,1))) ++ "…",title)

# Persistent destination navigation is separate from neutral toolbar/footer.
def navigation_paper() -> U32: 2575118
def navigation_ink() -> U32: 16447968
def navigation_muted() -> U32: 12571048
def navigation_current() -> U32: 16771970
def navigation_current_ink() -> U32: 2575118

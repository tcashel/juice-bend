import Base
import ../src/main.bend as Main

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def main() -> IO(Unit):
  do IO<Unit>:
    require(U32.is_eq(Main.preview_kind("attachment-preview-inline-v1"),0),"legacy inline route is unchanged")
    require(U32.is_eq(Main.preview_kind("attachment-preview-retained-v1"),1),"legacy retained route is unchanged")
    require(U32.is_eq(Main.preview_kind("attachment-preview-image-inline-v1"),3),"image inline route is unchanged")
    require(U32.is_eq(Main.preview_kind("attachment-preview-image-retained-v1"),4),"image retained route is unchanged")
    require(U32.is_eq(Main.preview_kind("library-usage-v1"),5),"library overview keeps tag5")
    require(U32.is_eq(Main.preview_kind("library-usage-capture-v1"),6),"library capture keeps tag6")
    require(U32.is_eq(Main.preview_kind("attachment-preview-image-inline-spool-v1"),7),"spool inline uses distinct tag7")
    require(U32.is_eq(Main.preview_kind("attachment-preview-image-retained-spool-v1"),8),"spool retained uses distinct tag8")
    require(U32.is_eq(Main.preview_kind("search"),2),"ordinary command falls through")
    require(Main.image_spool_explicit_root(["attachment-preview-image-inline-spool-v1"]),"spool inline requires explicit root")
    require(Main.image_spool_explicit_root(["attachment-preview-image-retained-spool-v1"]),"spool retained requires explicit root")
    require(Bool.not(Main.image_spool_explicit_root([])),"empty launch retains ordinary root behavior")
    require(Bool.not(Main.image_spool_explicit_root(["search","attachment-preview-image-inline-spool-v1"])),"spool command text in operand is data")
    require(Main.library_explicit_root(["library-usage-v1"]),"library overview explicit-root policy remains")
    require(Main.library_explicit_root(["library-usage-capture-v1"]),"library capture explicit-root policy remains")
    require(Bool.not(Main.library_explicit_root(["search","library-usage-v1"])),"library command text in operand is data")

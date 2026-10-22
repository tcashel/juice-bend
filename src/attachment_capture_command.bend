import Base
import ./attachment_asset_identity.bend as I
import ./attachment_root_rules.bend as R
import ./attachment_refs.bend as Ref
import ./attachment_cli.bend as Inline
import ./attachment_inventory.bend as E
import ./domain.bend as D

type Command is Data:
  Roots{after: String,count: U32}
  AddRoot{path: String}
  EnableRoot{identity: String}
  DisableRoot{identity: String}
  Capture{request: I.Request,root: String,revision: String}
  Inspect{request: I.Request}
  Export{request: I.Request,destination: String}

def result() -> Data: Result<&2,&2,E.Failure,Command>
def usage() -> E.Failure:
  E.Failure{"attachment_capture_usage","Expected bounded canonical attachment root, capture, retained inspection, or retained export arguments"}
def accept(valid: Bool,value: Command) -> result():
  match valid:
    case True{}: Done{value}
    case False{}: Fail{usage()}
def roots(after: String,count: Maybe<&2,U32>) -> result():
  match count:
    case Some{+count}: accept(U32.is_gt(count,0) && U32.is_le(count,40),Roots{after,count})
    case _: Fail{usage()}
def roots_checked(valid: Bool,after: String,count: String) -> result():
  match valid:
    case True{}: roots(after,D.parse_u32(count))
    case False{}: Fail{usage()}
def occurrence(snapshot: String,record: Maybe<&2,U32>,reference: Maybe<&2,U32>,path: String,
  next: I.Request -> result()) -> result():
  match record reference:
    case Some{record} Some{reference}:
      next(I.Request{snapshot,record,reference,path})
    case _ _: Fail{usage()}
def identity_checked(valid: Bool,snapshot: String,record: String,reference: String,path: String,next: I.Request -> result()) -> result():
  match valid:
    case True{}: occurrence(snapshot,D.parse_u32(record),D.parse_u32(reference),path,next)
    case False{}: Fail{usage()}
def identity(+snapshot: String,+record: String,+reference: String,+path: String,next: I.Request -> result()) -> result():
  identity_checked(R.identity(snapshot) && Ref.bounded(record,10) && Ref.bounded(reference,2) && Inline.structural_path(path),
    snapshot,record,reference,path,next)
def export_path(+path: String) -> Bool:
  R.path(path) && Inline.filename(path)
def known(value: String) -> Bool:
  match value:
    case "attachment-roots": True{}
    case "attachment-root-add": True{}
    case "attachment-root-enable": True{}
    case "attachment-root-disable": True{}
    case "capture-attachment": True{}
    case "captured-attachment": True{}
    case "export-captured-attachment": True{}
    case _: False{}
def parse(command: String,args: List<String>) -> result():
  match command args:
    case "attachment-roots" +after <> +count <> []:
      roots_checked((String.eq(after,"0") || R.identity(after)) && Ref.bounded(count,2),after,count)
    case "attachment-root-add" +path <> []: accept(R.path(path),AddRoot{path})
    case "attachment-root-enable" +id <> []: accept(R.identity(id),EnableRoot{id})
    case "attachment-root-disable" +id <> []: accept(R.identity(id),DisableRoot{id})
    case "capture-attachment" snapshot <> record <> reference <> path <> +root <> +revision <> []:
      identity(snapshot,record,reference,path,+request => accept(I.request_valid(request) && R.identity(root) && R.identity(revision),Capture{request,root,revision}))
    case "captured-attachment" snapshot <> record <> reference <> path <> []:
      identity(snapshot,record,reference,path,+request => accept(I.request_valid(request),Inspect{request}))
    case "export-captured-attachment" snapshot <> record <> reference <> path <> +destination <> []:
      identity(snapshot,record,reference,path,+request => accept(I.request_valid(request) && export_path(destination),Export{request,destination}))
    case _ _: Fail{usage()}

import Base
import ../src/attachment_assets.bend as Assets
import ../src/attachment_asset_identity.bend as Identity
import ../src/attachment_asset_types.bend as Types
import ../src/attachment_worker_protocol.bend as Worker
import ../src/archive_meta.bend as Meta
import ../src/domain.bend as Domain

# Frontend-only gate; this entry is never executed against an invalid handle.
def refuse(db: U32,root: Types.RootEvidence) -> IO(Types.unit_result()):
  IO.pure(Types.unit_result(),Fail{Types.failure("test_refusal","frontend only")})

def value() -> Types.Admission:
  Types.Admission{Identity.Resolved{Meta.Header{"1","1","1","claude","/synthetic/file",20,1,20,1,True{},"identity"},
    0,0,20,Domain.digest([]),0,"/message/content/0/source/path","image",Identity.LocalPath{"/synthetic/image"}},
    Types.RootEvidence{"1","/synthetic","1",True{}},"0",Worker.Payload{0,Domain.digest([]),[]}}

def main() -> IO(Unit):
  do IO<Unit>:
    initialized : Types.answer() <- Assets.initialize(0)
    published : Types.answer() <- Assets.publish(0,value(),d => r => refuse(d,r))
    read : Types.answer() <- Assets.read(0,Identity.Request{"1",0,0,"/message/content/0/source/path"})
    exported : Types.answer() <- Assets.export(0,Identity.Request{"1",0,0,"/message/content/0/source/path"},"/synthetic/out")
    IO.print("frontend only")

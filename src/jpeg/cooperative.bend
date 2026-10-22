import Base
import ./types.bend as T
import ./raster.bend as Raster
import ../attachment_image_types.bend as Image
import ../attachment_image_cancel.bend as Cancel

# The renderer shares preparation, allocation, every MCU transition and final
# validation with the pure decoder. A checkpoint never changes pixel arithmetic
# or accepts a partial raster. Cancel.check closes its control read before it
# either returns or terminates this supervised child.
def stepped(value: Result<&2,&1,T.Failure,Raster.Advanced>,next: Raster.Mcu -> Array<U32> -> IO(Result<&2,&1,T.Failure,Image.Raster>)) -> IO(Result<&2,&1,T.Failure,Image.Raster>):
  match value:
    case Fail{error}: IO.pure(Result<&2,&1,T.Failure,Image.Raster>,Fail{error})
    case Done{advanced}: Raster.unpack(IO(Result<&2,&1,T.Failure,Image.Raster>),advanced,next)

# Admitted baseline sampling has at most six 8x8 blocks and 256 pixel writes per
# MCU. Restart/EOI marker-fill scanning can still traverse the admitted one-MiB
# tail synchronously; this slice does not claim a wall-clock cancellation bound.
def mcus(fuel: Nat,mcu: Raster.Mcu,pixels: Array<U32>,+index: U32,+frame: T.Frame,+jobs: List<&2,Raster.Job>,+interval: U32,+color: T.ColorMode,+notice: Bool,+mode: Cancel.Mode) -> IO(Result<&2,&1,T.Failure,Image.Raster>):
  match fuel:
    case 0n:
      do IO<Result<&2,&1,T.Failure,Image.Raster>>:
        _ : Unit <- Cancel.check(mode)
        return Raster.finish(mcu,pixels,frame,notice)
    case 1n+rest:
      do IO<Result<&2,&1,T.Failure,Image.Raster>>:
        _ : Unit <- Cancel.check(mode)
        stepped(Raster.step(mcu,pixels,index,frame,jobs,interval,color),after => updated =>
          mcus(rest,after,updated,U32.inc(index),frame,jobs,interval,color,notice,mode))

def prepared(value: Result<&2,&2,T.Failure,Raster.Prepared>,+mode: Cancel.Mode) -> IO(Result<&2,&1,T.Failure,Image.Raster>):
  match value:
    case Fail{error}: IO.pure(Result<&2,&1,T.Failure,Image.Raster>,Fail{error})
    case Done{Raster.Prepared{+frame,jobs,interval,entropy,color,notice}}:
      T.Frame{_,_,_,_,_,columns,rows} = frame
      do IO<Result<&2,&1,T.Failure,Image.Raster>>:
        # Array.new remains one synchronous allocation/fill of at most1,048,576
        # pixels. Check immediately before entering it and before the first MCU.
        _ : Unit <- Cancel.check(mode)
        Raster.unpack(IO(Result<&2,&1,T.Failure,Image.Raster>),Raster.initial(frame,entropy),mcu => pixels =>
          mcus(U32.to_nat(U32.mul(columns,rows)),mcu,pixels,0,frame,jobs,interval,color,notice,mode))

def render(document: T.Document,+mode: Cancel.Mode) -> IO(Result<&2,&1,T.Failure,Image.Raster>):
  do IO<Result<&2,&1,T.Failure,Image.Raster>>:
    _ : Unit <- Cancel.check(mode)
    prepared(Raster.prepare(document),mode)

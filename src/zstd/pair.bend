import Base

# Base's ordinary A & B is affine. A pair of reusable decoder values needs
# explicit reusable Sigma quantities, rather than assuming its fields lift it.
def Duo(-A: Data,-B: Data) -> Data:
  Sigma<&2,&2,A,_ => B>

def first(-A: Data,-B: Data,value: Duo(A,B)) -> A:
  (left,_) = value
  left

def second(-A: Data,-B: Data,value: Duo(A,B)) -> B:
  (_,right) = value
  right

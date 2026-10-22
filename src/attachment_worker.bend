import Base
import ./attachment_worker_protocol.bend as P
import ./domain.bend as Domain

# This module has no HOME, SQLite, GUI, canonicalization or subprocess effects.
# REGULAR-FILE admission is the parent-installed OS policy, not a size heuristic.
def read_type() -> Type:
  File & Result<&2,&2,String,List<&2,U32>>

def chunk_step(step: P.ReadStep,file: File,bytes: List<&2,U32>,chunks: List<&2,List<&2,U32>>,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(read_type())) -> IO(read_type()):
  match step:
    case P.Unstable{}: IO.pure(read_type(),(file,Fail{"attachment_worker_unstable"}))
    case P.Complete{}:
      IO.pure(read_type(),(file,Done{List.concat(&2,U32,List.reverse(&2,List<&2,U32>,chunks))}))
    case P.Progress{offset}: next(file,offset,bytes <> chunks)

def chunk_result(result: File & Result<&1,&1,U32 & String,List<&2,U32>>,expected: U32,offset: U32,
  chunks: List<&2,List<&2,U32>>,next: File -> U32 -> List<&2,List<&2,U32>> -> IO(read_type())) -> IO(read_type()):
  (file,answer) = result
  match answer:
    case Fail{_}: IO.pure(read_type(),(file,Fail{"attachment_worker_read_error"}))
    case Done{+bytes}: chunk_step(P.read_step(expected,offset,U32.from_nat(List.length(&2,U32,bytes))),file,bytes,chunks,next)

def read_planned(plan: Result<&2,&2,String,P.ReadPermit>,file: File,expected: U32,+offset: U32,
  chunks: List<&2,List<&2,U32>>,next: File -> U32 -> List<&2,List<&2,U32>> -> IO(read_type())) -> IO(read_type()):
  match plan:
    case Fail{reason}: IO.pure(read_type(),(file,Fail{reason}))
    case Done{P.ReadPermit{_,maximum}}:
      do IO<read_type()>:
        result : File & Result<&1,&1,U32 & String,List<&2,U32>> <-
          File.read_at(file,offset,maximum)
        chunk_result(result,expected,offset,chunks,next)

def read_pass(fuel: Nat,file: File,+expected: U32,+offset: U32,chunks: List<&2,List<&2,U32>>) -> IO(read_type()):
  match fuel:
    case 0n: IO.pure(read_type(),(file,Fail{"attachment_worker_read_limit"}))
    case 1n+left:
      read_planned(P.read_plan(1n,expected,offset),file,expected,offset,chunks,
        next_file => next_offset => next_chunks => read_pass(left,next_file,expected,next_offset,next_chunks))

def emit(result: Result<&2,&2,String,String>) -> IO(Unit):
  match result:
    case Fail{_}: IO.die(Unit,77,"attachment_worker_protocol_error")
    case Done{text}: IO.write(text)

def failure(file: File,code: U32,reason: String) -> IO(Unit):
  do IO<Unit>:
    File.close(file)
    IO.die(Unit,code,reason)

def finished(valid: Bool,file: File,nonce: String,bytes: List<&2,U32>) -> IO(Unit):
  match valid:
    case False{}: failure(file,76,"attachment_worker_unstable")
    case True{}:
      do IO<Unit>:
        File.close(file)
        emit(P.wire(nonce,bytes))

def final_size(result: File & Result<&1,&1,U32 & String,U32>,expected: U32,nonce: String,
  +first: List<&2,U32>,second: List<&2,U32>) -> IO(Unit):
  (file,answer) = result
  match answer:
    case Fail{_}: failure(file,77,"attachment_worker_read_error")
    case Done{size}: finished(U32.is_eq(size,expected) && Domain.bytes_equal(first,second),file,nonce,first)

def second_read(result: read_type(),expected: U32,nonce: String,first: List<&2,U32>) -> IO(Unit):
  (file,answer) = result
  match answer:
    case Fail{reason}: failure(file,76,reason)
    case Done{second}:
      do IO<Unit>:
        size : File & Result<&1,&1,U32 & String,U32> <- File.size(file)
        final_size(size,expected,nonce,first,second)

def second_begin(valid: Bool,file: File,+expected: U32,nonce: String,first: List<&2,U32>) -> IO(Unit):
  match valid:
    case False{}: failure(file,76,"attachment_worker_unstable")
    case True{}:
      do IO<Unit>:
        result : read_type() <- read_pass(4096n,file,expected,0,[])
        second_read(result,expected,nonce,first)

def middle_size(result: File & Result<&1,&1,U32 & String,U32>,+expected: U32,nonce: String,first: List<&2,U32>) -> IO(Unit):
  (file,answer) = result
  match answer:
    case Fail{_}: failure(file,77,"attachment_worker_read_error")
    case Done{size}: second_begin(U32.is_eq(size,expected),file,expected,nonce,first)

def first_read(result: read_type(),expected: U32,nonce: String) -> IO(Unit):
  (file,answer) = result
  match answer:
    case Fail{reason}: failure(file,76,reason)
    case Done{bytes}:
      do IO<Unit>:
        size : File & Result<&1,&1,U32 & String,U32> <- File.size(file)
        middle_size(size,expected,nonce,bytes)

def first_begin(valid: Bool,file: File,+expected: U32,nonce: String) -> IO(Unit):
  match valid:
    case False{}: failure(file,75,"attachment_worker_size_limit")
    case True{}:
      do IO<Unit>:
        result : read_type() <- read_pass(4096n,file,expected,0,[])
        first_read(result,expected,nonce)

def initial_size(result: File & Result<&1,&1,U32 & String,U32>,nonce: String) -> IO(Unit):
  (file,answer) = result
  match answer:
    case Fail{_}: failure(file,77,"attachment_worker_read_error")
    case Done{+size}: first_begin(U32.is_le(size,P.byte_limit()),file,size,nonce)

def open_failed(code: U32) -> IO(Unit):
  match code:
    case 2: IO.die(Unit,73,"attachment_worker_missing")
    case 1: IO.die(Unit,74,"attachment_worker_blocked")
    case 13: IO.die(Unit,74,"attachment_worker_blocked")
    case _: IO.die(Unit,77,"attachment_worker_open_error")

def opened(result: Result<&1,&1,U32 & String,File>,nonce: String) -> IO(Unit):
  match result:
    case Fail{(code,_)}: open_failed(code)
    case Done{file}:
      do IO<Unit>:
        size : File & Result<&1,&1,U32 & String,U32> <- File.size(file)
        initial_size(size,nonce)

def confined(valid: Bool,+request: P.Request) -> IO(Unit):
  match valid:
    case False{}: IO.die(Unit,78,"attachment_worker_confinement_required")
    case True{}:
      P.Request{_,_,_,nonce} = request
      do IO<Unit>:
        result : Result<&1,&1,U32 & String,File> <- File.open(P.target(request),"r")
        opened(result,nonce)

# The same executable must be outside ROOT and deny ordinary read access. This
# sanity-checks accidental direct launches before opening the target. An
# otherwise unreadable executable can also deny an unconfined open: this is not
# independent proof of confinement. The trusted parent's exact policy is authority.
def self_checked(result: Result<&1,&1,U32 & String,File>,request: P.Request) -> IO(Unit):
  match result:
    case Fail{(+code,_)}: confined(U32.is_eq(code,1) || U32.is_eq(code,13),request)
    case Done{file}: failure(file,78,"attachment_worker_confinement_required")

def run_checked(valid: Bool,+request: P.Request) -> IO(Unit):
  match valid:
    case False{}: IO.die(Unit,64,"attachment_worker_arguments")
    case True{}:
      P.Request{program,_,_,_} = request
      do IO<Unit>:
        result : Result<&1,&1,U32 & String,File> <- File.open(program,"r")
        self_checked(result,request)

def run(+request: P.Request) -> IO(Unit):
  run_checked(P.valid_request(request),request)

import Base
import ./sql.bend as Sql
import ./domain.bend as Domain
import ./archive_profile.bend as Profile

# The compressed container is snapshot-owned evidence distinct from logical
# JSONL raw rows. This module never reads a source file or decodes Zstandard.
type Origin is Data:
  Origin{snapshot: String,source: String,generation: String,provider: String,
    locator: String,logical_extent: U32,records: U32,compressed_extent: U32,
    chunks: U32,compressed_sha: String,logical_sha: String}

type Header is Data:
  Header{snapshot: String,source: String,generation: String,provider: String,
    locator: String,extent: U32,records: U32,checkpoint: U32,
    checkpoint_ordinal: U32,accepted: Bool,encoding: String}

type Metadata is Data:
  Metadata{extent: U32,chunks: U32,compressed_sha: String,logical_sha: String}

type Chunk is Data:
  Chunk{ordinal: U32,offset: U32,length: U32,bytes: List<&2,U32>}

def encoding() -> String:
  "zstd-jsonl-v1"

def profile() -> String:
  "archive-batch-v1"

def format() -> String:
  "archive-origin-v1"

def input_limit() -> U32:
  1048576

def output_limit() -> U32:
  4194304

def chunk_limit() -> U32:
  65536

def chunk_count_limit() -> U32:
  16

def q(db: U32,sql: String,args: List<&2,Sql.Cell>,limit: U32) -> IO(List<&2,List<&2,Sql.Cell>>):
  IO.try(List<&2,List<&2,Sql.Cell>>,Sql.query(db,sql,args,limit))

def exec(db: U32,sql: String,args: List<&2,Sql.Cell>) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- q(db,sql,args,0)
    return Unit{}

def checked(valid: Bool,message: String) -> IO(Unit):
  match valid:
    case True{}:
      IO.pure(Unit,Unit{})
    case False{}:
      IO.die(Unit,1,message)

def migrate_locked(+db: U32,version: List<&2,List<&2,Sql.Cell>>) -> IO(Unit):
  match version:
    case [[Sql.Cell.Integer{"3"}]]:
      exec(db,"COMMIT",[])
    case [[Sql.Cell.Integer{"2"}]]:
      do IO<Unit>:
        exec(db,"ALTER TABLE generations ADD COLUMN encoding TEXT NOT NULL DEFAULT 'identity'",[])
        exec(db,"CREATE TABLE archive_captures(snapshot INTEGER PRIMARY KEY REFERENCES snapshots(id),version TEXT NOT NULL,profile TEXT NOT NULL,compressed_extent INTEGER NOT NULL,chunks INTEGER NOT NULL,compressed_sha TEXT NOT NULL,logical_sha TEXT NOT NULL,commitment TEXT NOT NULL)",[])
        exec(db,"CREATE TABLE archive_chunks(snapshot INTEGER NOT NULL REFERENCES snapshots(id),ordinal INTEGER NOT NULL,offset INTEGER NOT NULL,n INTEGER NOT NULL,digest TEXT NOT NULL,bytes BLOB NOT NULL,PRIMARY KEY(snapshot,ordinal),CHECK(n=length(bytes))) WITHOUT ROWID",[])
        exec(db,"PRAGMA user_version=3",[])
        exec(db,"COMMIT",[])
    case _:
      IO.die(Unit,1,"Archive migration requires library schema 2 or 3")

def migrate_version(+db: U32,version: List<&2,List<&2,Sql.Cell>>) -> IO(Unit):
  match version:
    case [[Sql.Cell.Integer{"3"}]]:
      IO.pure(Unit,Unit{})
    case [[Sql.Cell.Integer{"2"}]]:
      do IO<Unit>:
        exec(db,"BEGIN IMMEDIATE",[])
        locked : List<&2,List<&2,Sql.Cell>> <- q(db,"PRAGMA user_version",[],1)
        migrate_locked(db,locked)
    case _:
      IO.die(Unit,1,"Archive migration requires library schema 2 or 3")

def migrate(+db: U32) -> IO(Unit):
  do IO<Unit>:
    version : List<&2,List<&2,Sql.Cell>> <- q(db,"PRAGMA user_version",[],1)
    migrate_version(db,version)

def digits(text: String) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{Chr{+code},rest}:
      U32.is_ge(code,48) && U32.is_le(code,57) && digits(rest)

def positive(text: String) -> Bool:
  match text:
    case SCon{Chr{+code},rest}:
      U32.is_ge(code,49) && U32.is_le(code,57) && digits(rest)
    case SNil{}:
      False{}

# SQLite keys remain exact decimal strings; no Nat/U32/floating conversion.
def identity(+text: String) -> Bool:
  positive(text) && (Nat.is_lt(String.length(text),19n) ||
    (Nat.is_eq(String.length(text),19n) &&
      Bool.not(Cmp.is_gt(String.order(text,"9223372036854775807")))))

def hex_digits(text: String) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{Chr{+code},rest}:
      ((U32.is_ge(code,48) && U32.is_le(code,57)) ||
        (U32.is_ge(code,97) && U32.is_le(code,102))) && hex_digits(rest)

def digest_valid(+text: String) -> Bool:
  Nat.is_eq(String.length(text),64n) && hex_digits(text)

def octets(bytes: List<&2,U32>) -> Bool:
  match bytes:
    case []:
      True{}
    case byte <> rest:
      U32.is_le(byte,255) && octets(rest)

def initial_hash() -> Domain.HashContext:
  Domain.HashContext{Domain.hash_initial(),[],0,0}

def hash_chunks(chunks: List<&2,List<&2,U32>>,hash: Domain.HashContext) -> Domain.HashContext:
  match chunks:
    case []:
      hash
    case bytes <> rest:
      hash_chunks(rest,Domain.hash_bytes(bytes,hash))

# Caller bounds the byte stream before using SHA's U32 message length.
def digest_chunks(chunks: List<&2,List<&2,U32>>) -> String:
  Domain.hash_finish(hash_chunks(chunks,initial_hash()))

# Fixed-order fields use their UTF-8 byte length, not scalar length. Embedded
# NUL, separators and Unicode remain unambiguous values, never delimiters.
def framed(+text: String) -> List<&2,U32>:
  +bytes = Domain.encode(text)
  List.append(&2,U32,Domain.encode(Nat.show(List.length(&2,U32,bytes)) ++ ":"),bytes)

def hash_fields(fields: List<&2,String>,hash: Domain.HashContext) -> Domain.HashContext:
  match fields:
    case []:
      hash
    case field <> rest:
      hash_fields(rest,Domain.hash_bytes(framed(field),hash))

def origin_digest_for(+policy: Profile.Profile,h: Header,m: Metadata) -> String:
  Header{snapshot,source,generation,provider,locator,extent,records,checkpoint,ordinal,_,codec} = h
  Metadata{compressed,chunks,compressed_sha,logical_sha} = m
  Domain.hash_finish(hash_fields([format(),snapshot,source,generation,provider,locator,
    codec,U32.show(extent),U32.show(records),U32.show(checkpoint),U32.show(ordinal),
    U32.show(compressed),U32.show(chunks),compressed_sha,logical_sha,Profile.name(policy),
    U32.show(Profile.input(policy)),U32.show(Profile.output(policy)),"8388608","64","4096",
    U32.show(Profile.chunks(policy))],initial_hash()))

def origin_digest(h: Header,m: Metadata) -> String:
  origin_digest_for(Profile.batch(),h,m)

def chunk_digest(snapshot: String,ordinal: U32,offset: U32,length: U32,bytes: List<&2,U32>) -> String:
  Domain.hash_finish(Domain.hash_bytes(bytes,hash_fields(["archive-chunk-v1",snapshot,
    U32.show(ordinal),U32.show(offset),U32.show(length)],initial_hash())))

def header_valid(h: Header) -> Bool:
  Header{snapshot,source,generation,+provider,+locator,+extent,+records,+checkpoint,+ordinal,published,codec} = h
  identity(snapshot) && identity(source) && identity(generation) &&
    Domain.scalar_string(provider) && Domain.scalar_string(locator) && Domain.scalar_string(codec) &&
    U32.is_le(checkpoint,extent) && U32.is_le(ordinal,records) &&
    (U32.is_ne(ordinal,0) || U32.is_eq(checkpoint,0)) &&
    (Bool.not(published) || U32.is_ne(records,0) || (U32.is_eq(extent,0) && U32.is_eq(checkpoint,0))) &&
    Nat.is_le(String.length(provider),128n) && Nat.is_le(String.length(locator),4096n)

def header_result(h: Header,valid: Bool) -> Maybe<&2,Header>:
  match valid:
    case True{}:
      Some{h}
    case False{}:
      None{}

def header_numbers(snapshot: String,source: String,generation: String,provider: String,
  locator: String,extent: Maybe<&2,U32>,records: Maybe<&2,U32>,checkpoint: Maybe<&2,U32>,
  ordinal: Maybe<&2,U32>,+accepted: String,codec: String) -> Maybe<&2,Header>:
  match extent records checkpoint ordinal:
    case Some{e} Some{r} Some{c} Some{o}:
      +h = {Header{snapshot,source,generation,provider,locator,e,r,c,o,String.eq(accepted,"1"),codec} : Header}
      header_result(h,(String.eq(accepted,"0") || String.eq(accepted,"1")) && header_valid(h))
    case _ _ _ _:
      None{}

def decode_header(cells: List<&2,Sql.Cell>) -> Maybe<&2,Header>:
  match cells:
    case [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{source},Sql.Cell.Integer{generation},
      Sql.Cell.Text{provider},Sql.Cell.Text{locator},Sql.Cell.Integer{extent},
      Sql.Cell.Integer{records},Sql.Cell.Integer{checkpoint},Sql.Cell.Integer{ordinal},
      Sql.Cell.Integer{accepted},Sql.Cell.Text{codec}]:
      header_numbers(snapshot,source,generation,provider,locator,Domain.parse_u32(extent),
        Domain.parse_u32(records),Domain.parse_u32(checkpoint),Domain.parse_u32(ordinal),accepted,codec)
    case _:
      None{}

def require_header(result: Maybe<&2,Header>,snapshot: String,accepted: Bool) -> IO(Header):
  match result:
    case None{}:
      IO.die(Header,1,"Archive snapshot identity, numeric metadata or SQLite types are corrupt")
    case Some{+h}:
      Header{actual,_,_,_,_,_,_,_,_,published,_} = h
      do IO<Header>:
        checked(String.eq(actual,snapshot) && (Bool.not(accepted) || published),
          "Archive snapshot is missing or not accepted")
        return h

def header_rows(rows: List<&2,List<&2,Sql.Cell>>,snapshot: String,accepted: Bool) -> IO(Header):
  match rows:
    case [row]:
      require_header(decode_header(row),snapshot,accepted)
    case _:
      IO.die(Header,1,"Archive snapshot identity is missing or ambiguous")

def header(+db: U32,+snapshot: String,accepted: Bool) -> IO(Header):
  do IO<Header>:
    checked(identity(snapshot),"Snapshot must be a canonical positive signed64 identity")
    rows : List<&2,List<&2,Sql.Cell>> <- q(db,
      "SELECT p.id,g.source,p.generation,s.provider,s.locator,p.extent,p.records,p.checkpoint,p.checkpoint_ordinal,p.accepted,g.encoding FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=?",
      [Sql.Cell.Integer{snapshot}],1)
    header_rows(rows,snapshot,accepted)

def metadata_valid_for(+policy: Profile.Profile,h: Header,m: Metadata) -> Bool:
  Header{_,_,_,_,_,+logical,+records,_,_,_,_} = h
  Metadata{+extent,+chunks,compressed_sha,logical_sha} = m
  U32.is_gt(extent,0) && U32.is_le(extent,Profile.input(policy)) &&
    U32.is_gt(chunks,0) && U32.is_le(chunks,extent) && U32.is_le(chunks,Profile.chunks(policy)) &&
    U32.is_le(logical,Profile.output(policy)) && U32.is_le(records,logical) &&
    (U32.is_ne(logical,0) || U32.is_eq(records,0)) &&
    (U32.is_ne(records,0) || U32.is_eq(logical,0)) &&
    digest_valid(compressed_sha) && digest_valid(logical_sha)

def metadata_valid(h: Header,m: Metadata) -> Bool:
  metadata_valid_for(Profile.batch(),h,m)

def metadata_result(m: Metadata,valid: Bool) -> Maybe<&2,Metadata>:
  match valid:
    case True{}:
      Some{m}
    case False{}:
      None{}

def metadata_profile(+h: Header,+snapshot: String,version: String,policy: Maybe<&2,Profile.Profile>,
  extent: Maybe<&2,U32>,chunks: Maybe<&2,U32>,compressed_sha: String,logical_sha: String,
  +commitment: String) -> Maybe<&2,Metadata>:
  Header{actual,_,_,_,_,_,_,_,_,_,codec} = h
  match policy extent chunks:
    case Some{+limits} Some{e} Some{c}:
      +m = {Metadata{e,c,compressed_sha,logical_sha} : Metadata}
      metadata_result(m,identity(snapshot) && String.eq(actual,snapshot) &&
        String.eq(codec,encoding()) && String.eq(version,format()) &&
        metadata_valid_for(limits,h,m) && digest_valid(commitment) &&
        String.eq(commitment,origin_digest_for(limits,h,m)))
    case _ _ _: None{}

def metadata_numbers(h: Header,snapshot: String,version: String,limits: String,
  extent: Maybe<&2,U32>,chunks: Maybe<&2,U32>,compressed_sha: String,logical_sha: String,
  commitment: String) -> Maybe<&2,Metadata>:
  metadata_profile(h,snapshot,version,Profile.read(limits),extent,chunks,compressed_sha,logical_sha,commitment)

def decode_metadata(h: Header,cells: List<&2,Sql.Cell>) -> Maybe<&2,Metadata>:
  match cells:
    case [Sql.Cell.Integer{snapshot},Sql.Cell.Text{version},Sql.Cell.Text{limits},
      Sql.Cell.Integer{extent},Sql.Cell.Integer{chunks},Sql.Cell.Text{compressed_sha},
      Sql.Cell.Text{logical_sha},Sql.Cell.Text{commitment}]:
      metadata_numbers(h,snapshot,version,limits,Domain.parse_u32(extent),Domain.parse_u32(chunks),
        compressed_sha,logical_sha,commitment)
    case _:
      None{}

def origin(h: Header,m: Metadata) -> Origin:
  Header{snapshot,source,generation,provider,locator,extent,records,_,_,_,_} = h
  Metadata{compressed,chunks,compressed_sha,logical_sha} = m
  Origin{snapshot,source,generation,provider,locator,extent,records,compressed,chunks,compressed_sha,logical_sha}

def read_metadata(h: Header,result: Maybe<&2,Metadata>) -> IO(Maybe<&2,Origin>):
  match result:
    case None{}:
      IO.die(Maybe<&2,Origin>,1,"Archive origin, required format, limits or commitment are corrupt")
    case Some{m}:
      IO.pure(Maybe<&2,Origin>,Some{origin(h,m)})

def read_rows(+h: Header,rows: List<&2,List<&2,Sql.Cell>>) -> IO(Maybe<&2,Origin>):
  match rows:
    case [row]:
      read_metadata(h,decode_metadata(h,row))
    case _:
      IO.die(Maybe<&2,Origin>,1,"Archive generation is missing its immutable origin metadata")

def absent(rows: List<&2,List<&2,Sql.Cell>>) -> Bool:
  match rows:
    case [[Sql.Cell.Integer{"0"},Sql.Cell.Integer{"0"}]]:
      True{}
    case _:
      False{}

def empty_archive(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- q(db,
      "SELECT EXISTS(SELECT 1 FROM archive_captures WHERE snapshot=?),EXISTS(SELECT 1 FROM archive_chunks WHERE snapshot=?)",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{snapshot}],1)
    checked(absent(rows),"Snapshot already has compressed archive metadata or chunks")

def read_encoding(+db: U32,+h: Header,codec: String) -> IO(Maybe<&2,Origin>):
  Header{snapshot,_,_,_,_,_,_,_,_,_,_} = h
  match codec:
    case "identity":
      do IO<Maybe<&2,Origin>>:
        empty_archive(db,snapshot)
        return None{}
    case "zstd-jsonl-v1":
      do IO<Maybe<&2,Origin>>:
        rows : List<&2,List<&2,Sql.Cell>> <- q(db,
          "SELECT snapshot,version,profile,compressed_extent,chunks,compressed_sha,logical_sha,commitment FROM archive_captures WHERE snapshot=?",
          [Sql.Cell.Integer{snapshot}],1)
        read_rows(h,rows)
    case _:
      IO.die(Maybe<&2,Origin>,1,"Unsupported generation encoding")

def header_encoding(h: Header) -> String:
  Header{_,_,_,_,_,_,_,_,_,_,codec} = h
  codec

def read(+db: U32,snapshot: String,accepted: Bool) -> IO(Maybe<&2,Origin>):
  do IO<Maybe<&2,Origin>>:
    +h : Header <- header(db,snapshot,accepted)
    read_encoding(db,h,header_encoding(h))

def staging(h: Header) -> Bool:
  Header{_,_,_,_,_,extent,_,_,_,accepted,codec} = h
  Bool.not(accepted) && String.eq(codec,encoding()) && U32.is_le(extent,output_limit())

def chunks_valid_walk(chunks: List<&2,List<&2,U32>>,+offset: U32,remaining: Nat) -> Bool:
  match chunks remaining:
    case [] _:
      U32.is_gt(offset,0)
    case _ 0n:
      False{}
    case +bytes <> rest 1n+left:
      +n = List.length(&2,U32,bytes)
      Nat.is_gt(n,0n) && Nat.is_le(n,U32.to_nat(chunk_limit())) &&
        Nat.is_le(n,U32.to_nat(U32.sub(input_limit(),offset))) && octets(bytes) &&
        chunks_valid_walk(rest,U32.add(offset,U32.from_nat(n)),left)

def chunks_valid(chunks: List<&2,List<&2,U32>>,offset: U32) -> Bool:
  chunks_valid_walk(chunks,offset,U32.to_nat(chunk_count_limit()))

def stage_walk(chunks: List<&2,List<&2,U32>>,+db: U32,+snapshot: String,+ordinal: U32,+offset: U32) -> IO(Unit):
  match chunks:
    case []:
      IO.pure(Unit,Unit{})
    case +bytes <> rest:
      +n = U32.from_nat(List.length(&2,U32,bytes))
      do IO<Unit>:
        exec(db,"INSERT INTO archive_chunks(snapshot,ordinal,offset,n,digest,bytes) VALUES(?,?,?,?,?,?)",
          [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(ordinal)},Sql.Cell.Integer{U32.show(offset)},
           Sql.Cell.Integer{U32.show(n)},Sql.Cell.Text{chunk_digest(snapshot,ordinal,offset,n,bytes)},Sql.Cell.Blob{bytes}])
        stage_walk(rest,db,snapshot,U32.inc(ordinal),U32.add(offset,n))

def stage(+db: U32,+snapshot: String,+chunks: List<&2,List<&2,U32>>) -> IO(Unit):
  do IO<Unit>:
    h : Header <- header(db,snapshot,False{})
    checked(staging(h),"Container staging requires an unaccepted archive snapshot")
    checked(chunks_valid(chunks,0),"Compressed chunks exceed archive limits or contain non-octets")
    empty_archive(db,snapshot)
    stage_walk(chunks,db,snapshot,0,0)

def chunk_result(chunk: Chunk,valid: Bool) -> Maybe<&2,Chunk>:
  match valid:
    case True{}:
      Some{chunk}
    case False{}:
      None{}

def chunk_numbers_for(+policy: Profile.Profile,+snapshot: String,+actual: String,ordinal: Maybe<&2,U32>,offset: Maybe<&2,U32>,
  length: Maybe<&2,U32>,+digest: String,+bytes: List<&2,U32>) -> Maybe<&2,Chunk>:
  match ordinal offset length:
    case Some{+o} Some{+p} Some{+n}:
      chunk_result(Chunk{o,p,n,bytes},identity(actual) && String.eq(snapshot,actual) &&
        U32.is_gt(n,0) && U32.is_le(n,chunk_limit()) && U32.is_le(p,Profile.input(policy)) &&
        U32.is_le(n,U32.sub(Profile.input(policy),p)) &&
        Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(n)) && octets(bytes) &&
        digest_valid(digest) && String.eq(digest,chunk_digest(snapshot,o,p,n,bytes)))
    case _ _ _:
      None{}

def chunk_numbers(snapshot: String,actual: String,ordinal: Maybe<&2,U32>,offset: Maybe<&2,U32>,
  length: Maybe<&2,U32>,digest: String,bytes: List<&2,U32>) -> Maybe<&2,Chunk>:
  chunk_numbers_for(Profile.batch(),snapshot,actual,ordinal,offset,length,digest,bytes)

def decode_chunk(snapshot: String,row: List<&2,Sql.Cell>) -> Maybe<&2,Chunk>:
  match row:
    case [Sql.Cell.Integer{actual},Sql.Cell.Integer{ordinal},Sql.Cell.Integer{offset},
      Sql.Cell.Integer{length},Sql.Cell.Text{digest},Sql.Cell.Blob{bytes}]:
      chunk_numbers(snapshot,actual,Domain.parse_u32(ordinal),Domain.parse_u32(offset),
        Domain.parse_u32(length),digest,bytes)
    case _:
      None{}

def required_chunk(result: Maybe<&2,Chunk>,ordinal: U32,offset: U32) -> IO(Chunk):
  match result:
    case None{}:
      IO.die(Chunk,1,"Archive chunk types, bytes or digest are corrupt")
    case Some{+chunk}:
      Chunk{actual,position,_,_} = chunk
      do IO<Chunk>:
        checked(U32.is_eq(actual,ordinal) && U32.is_eq(position,offset),
          "Archive chunks are missing, reordered or noncontiguous")
        return chunk

def chunk_row(rows: List<&2,List<&2,Sql.Cell>>,snapshot: String,ordinal: U32,offset: U32) -> IO(Chunk):
  match rows:
    case [row]:
      required_chunk(decode_chunk(snapshot,row),ordinal,offset)
    case _:
      IO.die(Chunk,1,"Archive chunk is missing or ambiguous")

def count_result(count: Maybe<&2,U32>) -> IO(U32):
  match count:
    case Some{+n}:
      do IO<U32>:
        checked(U32.is_gt(n,0) && U32.is_le(n,chunk_count_limit()),"Archive chunk count exceeds profile")
        return n
    case None{}:
      IO.die(U32,1,"Archive chunk count is not canonical bounded decimal")

def actual_count(rows: List<&2,List<&2,Sql.Cell>>) -> IO(U32):
  match rows:
    case [[Sql.Cell.Integer{count}]]:
      count_result(Domain.parse_u32(count))
    case _:
      IO.die(U32,1,"Archive chunk count has invalid SQLite type")

def chunk_count(db: U32,snapshot: String) -> IO(U32):
  do IO<U32>:
    rows : List<&2,List<&2,Sql.Cell>> <- q(db,"SELECT count(*) FROM archive_chunks WHERE snapshot=?",
      [Sql.Cell.Integer{snapshot}],1)
    actual_count(rows)

def collected(chunk: Chunk,+extent: U32,hash: Domain.HashContext,chunks: List<&2,List<&2,U32>>,
  next: U32 -> U32 -> Domain.HashContext -> List<&2,List<&2,U32>> -> IO(List<&2,List<&2,U32>>)) -> IO(List<&2,List<&2,U32>>):
  Chunk{ordinal,+offset,+n,+bytes} = chunk
  do IO<List<&2,List<&2,U32>>>:
    checked(U32.is_le(offset,extent) && U32.is_le(n,U32.sub(extent,offset)),
      "Archive chunks exceed the sealed compressed extent")
    next(U32.inc(ordinal),U32.add(offset,n),Domain.hash_bytes(bytes,hash),bytes <> chunks)

# Admission bounds only the BLOB transferred from SQLite into Bend, including
# corrupt rows. Original metadata and all validity decisions remain in Bend;
# NULL from this projection is rejected by decode_chunk, never accepted data.
def chunk_rows(db: U32,snapshot: String,ordinal: U32) -> IO(List<&2,List<&2,Sql.Cell>>):
  q(db,
    "SELECT snapshot,ordinal,offset,n,digest,CASE WHEN typeof(n)='integer' AND n BETWEEN 1 AND ? AND typeof(bytes)='blob' AND length(bytes)=n THEN bytes ELSE NULL END FROM archive_chunks WHERE snapshot=? AND ordinal=?",
    [Sql.Cell.Integer{U32.show(chunk_limit())},Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(ordinal)}],1)

# Positive chunk lengths, a 1 MiB extent and 16-chunk limit bound the scan.
def collect(fuel: Nat,+db: U32,+snapshot: String,+extent: U32,+expected_sha: String,
  +ordinal: U32,+offset: U32,hash: Domain.HashContext,chunks: List<&2,List<&2,U32>>) -> IO(List<&2,List<&2,U32>>):
  match fuel:
    case 0n:
      do IO<List<&2,List<&2,U32>>>:
        checked(U32.is_eq(offset,extent) && String.eq(Domain.hash_finish(hash),expected_sha),
          "Archive whole-container extent or SHA256 does not match its origin")
        return List.reverse(&2,List<&2,U32>,chunks)
    case 1n+rest:
      do IO<List<&2,List<&2,U32>>>:
        rows : List<&2,List<&2,Sql.Cell>> <- chunk_rows(db,snapshot,ordinal)
        chunk : Chunk <- chunk_row(rows,snapshot,ordinal,offset)
        collected(chunk,extent,hash,chunks,
          o => p => state => found => collect(rest,db,snapshot,extent,expected_sha,o,p,state,found))

def scan(+db: U32,+snapshot: String,+extent: U32,+count: U32,+sha: String) -> IO(List<&2,List<&2,U32>>):
  do IO<List<&2,List<&2,U32>>>:
    actual : U32 <- chunk_count(db,snapshot)
    checked(U32.is_gt(extent,0) && U32.is_le(extent,input_limit()) && U32.is_eq(count,actual) &&
      U32.is_le(count,extent) && digest_valid(sha),"Archive count, extent or SHA256 is invalid")
    collect(U32.to_nat(count),db,snapshot,extent,sha,0,0,initial_hash(),[])

def seal(+db: U32,+snapshot: String,+compressed_extent: U32,+compressed_sha: String,+logical_sha: String) -> IO(Unit):
  do IO<Unit>:
    +h : Header <- header(db,snapshot,False{})
    checked(staging(h),"Archive origin sealing requires an unaccepted archive snapshot")
    +count : U32 <- chunk_count(db,snapshot)
    +m : Metadata = Metadata{compressed_extent,count,compressed_sha,logical_sha}
    checked(metadata_valid(h,m),"Archive origin quantities or hashes exceed profile")
    chunks : List<&2,List<&2,U32>> <- scan(db,snapshot,compressed_extent,count,compressed_sha)
    exec(db,"INSERT INTO archive_captures(snapshot,version,profile,compressed_extent,chunks,compressed_sha,logical_sha,commitment) VALUES(?,?,?,?,?,?,?,?)",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Text{format()},Sql.Cell.Text{profile()},
       Sql.Cell.Integer{U32.show(compressed_extent)},Sql.Cell.Integer{U32.show(count)},
       Sql.Cell.Text{compressed_sha},Sql.Cell.Text{logical_sha},Sql.Cell.Text{origin_digest(h,m)}])

def container_origin(db: U32,result: Maybe<&2,Origin>) -> IO(List<&2,List<&2,U32>>):
  match result:
    case None{}:
      IO.die(List<&2,List<&2,U32>>,1,"Selected snapshot is not a compressed archive")
    case Some{Origin{snapshot,_,_,_,_,_,_,extent,count,sha,_}}:
      scan(db,snapshot,extent,count,sha)

def container(+db: U32,snapshot: String,accepted: Bool) -> IO(List<&2,List<&2,U32>>):
  do IO<List<&2,List<&2,U32>>>:
    result : Maybe<&2,Origin> <- read(db,snapshot,accepted)
    container_origin(db,result)

# Streaming readers carry one chunk and incremental commitment state only.
# They also serve publication and export, so no accepted stream profile needs
# the legacy all-chunks convenience API above.
type Reader is Data:
  Reader{snapshot: String,policy: Profile.Profile,extent: U32,chunks: U32,
    digest: String,ordinal: U32,offset: U32,hash: Domain.HashContext}

type Read is Data:
  Read{reader: Reader,bytes: Maybe<&2,List<&2,U32>>}

type Open is Data:
  Open{origin: Origin,reader: Reader}

def required_profile(value: Maybe<&2,Profile.Profile>) -> IO(Profile.Profile):
  match value:
    case None{}: IO.die(Profile.Profile,1,"Archive profile is unknown; capture refused")
    case Some{policy}: IO.pure(Profile.Profile,policy)

def profile_row(rows: List<&2,List<&2,Sql.Cell>>) -> IO(Profile.Profile):
  match rows:
    case [[Sql.Cell.Text{name}]]: required_profile(Profile.read(name))
    case _: IO.die(Profile.Profile,1,"Archive profile is missing, ambiguous or has invalid SQLite type")

def read_profile(db: U32,snapshot: String) -> IO(Profile.Profile):
  do IO<Profile.Profile>:
    rows : List<&2,List<&2,Sql.Cell>> <- q(db,"SELECT profile FROM archive_captures WHERE snapshot=?",
      [Sql.Cell.Integer{snapshot}],1)
    profile_row(rows)

def count_for(policy: Profile.Profile,value: Maybe<&2,U32>) -> IO(U32):
  match value:
    case None{}: IO.die(U32,1,"Archive chunk count is not canonical bounded decimal")
    case Some{+count}:
      do IO<U32>:
        checked(U32.is_gt(count,0) && U32.is_le(count,Profile.chunks(policy)),"Archive chunk count exceeds profile")
        return count

def count_rows_for(policy: Profile.Profile,rows: List<&2,List<&2,Sql.Cell>>) -> IO(U32):
  match rows:
    case [[Sql.Cell.Integer{value}]]: count_for(policy,Domain.parse_u32(value))
    case _: IO.die(U32,1,"Archive chunk count has invalid SQLite type")

def chunk_count_for(db: U32,snapshot: String,policy: Profile.Profile) -> IO(U32):
  do IO<U32>:
    rows : List<&2,List<&2,Sql.Cell>> <- q(db,"SELECT count(*) FROM archive_chunks WHERE snapshot=?",
      [Sql.Cell.Integer{snapshot}],1)
    count_rows_for(policy,rows)

def reader(+db: U32,+snapshot: String,+policy: Profile.Profile,+extent: U32,+chunks: U32,+digest: String) -> IO(Reader):
  do IO<Reader>:
    actual : U32 <- chunk_count_for(db,snapshot,policy)
    checked(identity(snapshot) && U32.is_gt(extent,0) && U32.is_le(extent,Profile.input(policy)) &&
      U32.is_eq(actual,chunks) && U32.is_le(chunks,extent) && digest_valid(digest),
      "Archive count, extent or SHA256 is invalid")
    return Reader{snapshot,policy,extent,chunks,digest,0,0,initial_hash()}

def open_origin(+db: U32,value: Maybe<&2,Origin>) -> IO(Open):
  match value:
    case None{}: IO.die(Open,1,"Selected snapshot is not a compressed archive")
    case Some{+origin}:
      Origin{+snapshot,_,_,_,_,_,_,extent,chunks,sha,_} = origin
      do IO<Open>:
        policy : Profile.Profile <- read_profile(db,snapshot)
        stream : Reader <- reader(db,snapshot,policy,extent,chunks,sha)
        return Open{origin,stream}

def open_reader(+db: U32,snapshot: String,accepted: Bool) -> IO(Open):
  do IO<Open>:
    value : Maybe<&2,Origin> <- read(db,snapshot,accepted)
    open_origin(db,value)

def decode_chunk_for(policy: Profile.Profile,snapshot: String,row: List<&2,Sql.Cell>) -> Maybe<&2,Chunk>:
  match row:
    case [Sql.Cell.Integer{actual},Sql.Cell.Integer{ordinal},Sql.Cell.Integer{offset},
      Sql.Cell.Integer{length},Sql.Cell.Text{digest},Sql.Cell.Blob{bytes}]:
      chunk_numbers_for(policy,snapshot,actual,Domain.parse_u32(ordinal),Domain.parse_u32(offset),
        Domain.parse_u32(length),digest,bytes)
    case _: None{}

def chunk_row_for(policy: Profile.Profile,rows: List<&2,List<&2,Sql.Cell>>,snapshot: String,ordinal: U32,offset: U32) -> IO(Chunk):
  match rows:
    case [row]: required_chunk(decode_chunk_for(policy,snapshot,row),ordinal,offset)
    case _: IO.die(Chunk,1,"Archive chunk is missing or ambiguous")

def reader_chunk(stream: Reader,chunk: Chunk) -> IO(Read):
  Reader{snapshot,policy,+extent,chunks,digest,_,_,hash} = stream
  Chunk{ordinal,+offset,+length,+bytes} = chunk
  do IO<Read>:
    checked(U32.is_le(offset,extent) && U32.is_le(length,U32.sub(extent,offset)),
      "Archive chunks exceed the sealed compressed extent")
    return Read{Reader{snapshot,policy,extent,chunks,digest,U32.inc(ordinal),U32.add(offset,length),
      Domain.hash_bytes(bytes,hash)},Some{bytes}}

def reader_step(finished: Bool,+db: U32,+stream: Reader) -> IO(Read):
  match finished:
    case True{}:
      Reader{snapshot,policy,+extent,chunks,+digest,ordinal,+offset,+hash} = stream
      do IO<Read>:
        checked(U32.is_eq(offset,extent) && String.eq(Domain.hash_finish(hash),digest),
          "Archive whole-container extent or SHA256 does not match its origin")
        return Read{Reader{snapshot,policy,extent,chunks,digest,ordinal,offset,hash},None{}}
    case False{}:
      Reader{+snapshot,+policy,_,+chunks,_,+ordinal,+offset,_} = stream
      do IO<Read>:
        checked(U32.is_lt(ordinal,chunks),"Archive reader exceeded its declared chunk count")
        rows : List<&2,List<&2,Sql.Cell>> <- chunk_rows(db,snapshot,ordinal)
        chunk : Chunk <- chunk_row_for(policy,rows,snapshot,ordinal,offset)
        reader_chunk(stream,chunk)

def next(db: U32,+stream: Reader) -> IO(Read):
  Reader{_,_,_,chunks,_,ordinal,_,_} = stream
  reader_step(U32.is_eq(ordinal,chunks),db,stream)

def drain_step(result: Read,next: Reader -> IO(Unit)) -> IO(Unit):
  Read{stream,bytes} = result
  match bytes:
    case None{}: IO.pure(Unit,Unit{})
    case Some{_}: next(stream)

def drain(fuel: Nat,+db: U32,stream: Reader) -> IO(Unit):
  match fuel:
    case 0n: IO.die(Unit,1,"Archive validation exhausted bounded chunk count")
    case 1n+rest:
      do IO<Unit>:
        result : Read <- next(db,stream)
        drain_step(result,s => drain(rest,db,s))

def validate_reader(db: U32,+stream: Reader) -> IO(Unit):
  Reader{_,_,_,chunks,_,_,_,_} = stream
  drain(U32.to_nat(U32.inc(chunks)),db,stream)

def staging_for(policy: Profile.Profile,h: Header) -> Bool:
  Header{_,_,_,_,_,extent,_,_,_,accepted,codec} = h
  Bool.not(accepted) && String.eq(codec,encoding()) && U32.is_le(extent,Profile.output(policy))

def stage_one(+db: U32,+snapshot: String,+policy: Profile.Profile,+ordinal: U32,+offset: U32,+bytes: List<&2,U32>) -> IO(Unit):
  +size = List.length(&2,U32,bytes)
  +length = U32.from_nat(size)
  do IO<Unit>:
    h : Header <- header(db,snapshot,False{})
    checked(staging_for(policy,h),"Container staging requires an unaccepted archive snapshot")
    checked(Nat.is_gt(size,0n) && Nat.is_le(size,U32.to_nat(chunk_limit())) &&
      U32.is_lt(ordinal,Profile.chunks(policy)) && U32.is_le(offset,Profile.input(policy)) &&
      U32.is_gt(length,0) && U32.is_le(length,chunk_limit()) &&
      U32.is_le(length,U32.sub(Profile.input(policy),offset)) && octets(bytes),
      "Compressed chunk exceeds archive profile or contains non-octets")
    exec(db,"INSERT INTO archive_chunks(snapshot,ordinal,offset,n,digest,bytes) VALUES(?,?,?,?,?,?)",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(ordinal)},Sql.Cell.Integer{U32.show(offset)},
       Sql.Cell.Integer{U32.show(length)},Sql.Cell.Text{chunk_digest(snapshot,ordinal,offset,length,bytes)},Sql.Cell.Blob{bytes}])

def seal_for(+db: U32,+snapshot: String,+policy: Profile.Profile,+compressed_extent: U32,+compressed_sha: String,+logical_sha: String) -> IO(Unit):
  do IO<Unit>:
    +h : Header <- header(db,snapshot,False{})
    checked(staging_for(policy,h),"Archive origin sealing requires an unaccepted archive snapshot")
    +count : U32 <- chunk_count_for(db,snapshot,policy)
    +m : Metadata = Metadata{compressed_extent,count,compressed_sha,logical_sha}
    checked(metadata_valid_for(policy,h,m),"Archive origin quantities or hashes exceed profile")
    stream : Reader <- reader(db,snapshot,policy,compressed_extent,count,compressed_sha)
    validate_reader(db,stream)
    exec(db,"INSERT INTO archive_captures(snapshot,version,profile,compressed_extent,chunks,compressed_sha,logical_sha,commitment) VALUES(?,?,?,?,?,?,?,?)",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Text{format()},Sql.Cell.Text{Profile.name(policy)},
       Sql.Cell.Integer{U32.show(compressed_extent)},Sql.Cell.Integer{U32.show(count)},
       Sql.Cell.Text{compressed_sha},Sql.Cell.Text{logical_sha},Sql.Cell.Text{origin_digest_for(policy,h,m)}])

import Base
import ./zstd/frame.bend as Frame

# Profiles bind exact admission limits into immutable origin commitments.
# Candidate stream caps are bounds, not demonstrated performance claims.
type Profile is Data:
  Profile{name: String,input: U32,output: U32,chunks: U32}

def batch() -> Profile:
  Profile{"archive-batch-v1",1048576,4194304,16}

def streaming() -> Profile:
  Profile{"archive-stream-v2",67108864,268435456,1024}

def read(name: String) -> Maybe<&2,Profile>:
  match name:
    case "archive-batch-v1": Some{batch()}
    case "archive-stream-v2": Some{streaming()}
    case _: None{}

def decoder(profile: Profile) -> Frame.Limits:
  Profile{_,input,output,_} = profile
  Frame.Limits{input,output,8388608,64,4096}

def name(profile: Profile) -> String:
  Profile{name,_,_,_} = profile
  name

def input(profile: Profile) -> U32:
  Profile{_,value,_,_} = profile
  value

def output(profile: Profile) -> U32:
  Profile{_,_,value,_} = profile
  value

def chunks(profile: Profile) -> U32:
  Profile{_,_,_,value} = profile
  value

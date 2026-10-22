# Pure Settings protocol/model. No GUI, filesystem or database effects.
import Base
import ./json.bend as Json
import ./domain.bend as Domain
import ./refresh_preferences.bend as Refresh

type Source is Data:
  Source{provider: String,path: String,enabled: Bool}

# phase: 0 unloaded, 1 preference IO pending, 2 acknowledged, 3 error.
# loaded describes the source inventory, independently of preference phase.
# prefs is acknowledged state; desired is the latest complete pending pair.
type Model is Data:
  Model{phase: U32,prefs: Refresh.Preferences,desired: Maybe<&2,Refresh.Preferences>,
    sources: List<&2,Source>,loaded: Bool,selected: Maybe<&2,Source>,offset: U32,last: String}

def remove_key(keys: List<&2,String>,+key: String) -> List<&2,String>:
  match keys:
    case []: []
    case +first <> +rest:
      Bool.pick(List<&2,String>,String.eq(first,key),rest,first <> remove_key(rest,key))

def has_key(keys: List<&2,String>,+key: String) -> Bool:
  match keys:
    case []: False{}
    case first <> rest: String.eq(first,key) || has_key(rest,key)

def fields_match(fields: List<&2,Json.Field>,+keys: List<&2,String>,budget: Nat) -> Bool:
  match fields budget:
    case [] _: List.is_empty(&2,String,keys)
    case field <> rest 0n: False{}
    case Json.JField{+key,value} <> rest 1n+remaining:
      has_key(keys,key) && fields_match(rest,remove_key(keys,key),remaining)

def exact_object(value: Json.Json,+keys: List<&2,String>) -> Bool:
  match value:
    case Json.JObject{fields}: fields_match(fields,keys,List.length(&2,String,keys))
    case _: False{}

def text_is(value: Json.Json,expected: String) -> Bool:
  match value:
    case Json.JString{text}: String.eq(text,expected)
    case _: False{}

def bool_is(value: Json.Json,expected: Bool) -> Bool:
  match value:
    case Json.JBool{actual}: Bool.not(Bool.xor(actual,expected))
    case _: False{}

def boolean(value: Json.Json) -> Bool:
  match value:
    case Json.JBool{_}: True{}
    case _: False{}

def number(value: Json.Json) -> Bool:
  match value:
    case Json.JNumber{_}: True{}
    case _: False{}

def number_is(value: Json.Json,expected: String) -> Bool:
  match value:
    case Json.JNumber{text}: String.eq(text,expected)
    case _: False{}

def prefs_shape(+value: Json.Json) -> Bool:
  exact_object(value,["kind","enabled","interval_seconds","interval_milliseconds"]) &&
    text_is(Json.field(value,"kind"),"refresh_preferences") &&
    boolean(Json.field(value,"enabled")) && number(Json.field(value,"interval_seconds")) &&
    number(Json.field(value,"interval_milliseconds"))

def prefs_milliseconds(preferences: Refresh.Preferences,valid: Bool) -> Result<&2,&2,String,Refresh.Preferences>:
  match valid:
    case True{}: Done{preferences}
    case False{}: Fail{"Refresh preference acknowledgement has inconsistent milliseconds."}

def prefs_parsed(value: Json.Json,result: Result<&2,&2,Refresh.Failure,Refresh.Preferences>) ->
  Result<&2,&2,String,Refresh.Preferences>:
  match result:
    case Fail{Refresh.Failure{code,message}}:
      Fail{"Refresh preference acknowledgement contains an unsupported boolean or interval."}
    case Done{+preferences}:
      Refresh.Preferences{enabled,interval} = preferences
      prefs_milliseconds(preferences,number_is(Json.field(value,"interval_milliseconds"),Nat.show(Refresh.milliseconds(interval))))

def prefs_checked(+value: Json.Json,valid: Bool) -> Result<&2,&2,String,Refresh.Preferences>:
  match valid:
    case False{}: Fail{"Refresh preference acknowledgement has an invalid shape or field type."}
    case True{}: prefs_parsed(value,Refresh.parse(Json.get(value,"enabled"),Json.get(value,"interval_seconds")))

def prefs_decode(+value: Json.Json) -> Result<&2,&2,String,Refresh.Preferences>:
  prefs_checked(value,prefs_shape(value))

def path_chars(value: String,fuel: Nat) -> Bool:
  match value fuel:
    case SNil{} _: True{}
    case SCon{c,rest} 0n: False{}
    case SCon{Chr{+code},rest} 1n+budget:
      U32.is_ne(code,0) && Domain.scalar(code) && path_chars(rest,budget)

def absolute(+path: String) -> Bool:
  String.starts_with(path,"/") && path_chars(path,4096n)

def components(parts: List<&2,String>) -> Bool:
  match parts:
    case []: True{}
    case +part <> rest:
      Bool.not(String.is_empty(part)) && Bool.not(String.eq(part,".")) &&
        Bool.not(String.eq(part,"..")) && components(rest)

# Lexical validation of a backend-returned canonical path; no filesystem claim.
def canonical(+path: String) -> Bool:
  absolute(path) && (String.eq(path,"/") || components(String.split(String.drop(path,1n),'/')))

def provider(+value: String) -> Bool:
  String.eq(value,"claude") || String.eq(value,"codex")

def source_valid(provider_name: String,path: String,enabled: String,valid: Bool) -> Result<&2,&2,String,Source>:
  match valid:
    case True{}: Done{Source{provider_name,path,String.eq(enabled,"1")}}
    case False{}: Fail{"Source inventory row has an invalid provider, canonical path or enabled state."}

def source_row(value: Json.Json) -> Result<&2,&2,String,Source>:
  match value:
    case Json.JArray{[Json.JString{+name},Json.JString{+path},Json.JString{+enabled}]}:
      source_valid(name,path,enabled,provider(name) && canonical(path) &&
        (String.eq(enabled,"0") || String.eq(enabled,"1")))
    case _: Fail{"Source inventory rows must contain exactly three strings."}

def same(a: Source,b: Source) -> Bool:
  Source{ap,as,ae} = a
  Source{bp,bs,be} = b
  String.eq(ap,bp) && String.eq(as,bs)

def contains(rows: List<&2,Source>,+source: Source) -> Bool:
  match rows:
    case []: False{}
    case first <> rest: same(first,source) || contains(rest,source)

def unique(valid: Bool) -> Result<&2,&2,String,Unit>:
  match valid:
    case True{}: Done{Unit{}}
    case False{}: Fail{"Source inventory repeats the same provider and canonical root."}

def source_rows(rows: List<&2,Json.Json>,budget: Nat,+seen: List<&2,Source>) -> Result<&2,&2,String,List<&2,Source>>:
  match rows budget:
    case [] _: Done{[]}
    case row <> rest 0n: Fail{"Source inventory exceeds its 32-root display bound; no partial list was accepted."}
    case row <> rest 1n+remaining:
      do Result<&2,&2,String,List<&2,Source>>:
        +source : Source <- source_row(row)
        Unit <- unique(Bool.not(contains(seen,source)))
        tail : List<&2,Source> <- source_rows(rest,remaining,source <> seen)
        return source <> tail

def columns(value: Json.Json) -> Bool:
  match value:
    case Json.JArray{[Json.JString{"provider"},Json.JString{"canonical_root"},Json.JString{"enabled"}]}: True{}
    case _: False{}

def sources_value(value: Json.Json) -> Result<&2,&2,String,List<&2,Source>>:
  match value:
    case Json.JArray{rows}: source_rows(rows,32n,[])
    case _: Fail{"Source inventory is missing its rows array."}

def sources_checked(+value: Json.Json,valid: Bool) -> Result<&2,&2,String,List<&2,Source>>:
  match valid:
    case True{}: sources_value(Json.field(value,"rows"))
    case False{}: Fail{"Source inventory has an invalid envelope or columns."}

def sources_decode(+value: Json.Json) -> Result<&2,&2,String,List<&2,Source>>:
  sources_checked(value,exact_object(value,["columns","rows"]) && columns(Json.field(value,"columns")))

def ack_for(+value: Json.Json,+name: String,+path: String,+enable: Bool) -> Bool:
  provider(name) && absolute(path) &&
    exact_object(value,Bool.pick(List<&2,String>,enable,["registered","enabled","provider","requested_root"],
      ["enabled","provider","requested_root"])) &&
    text_is(Json.field(value,"provider"),name) && text_is(Json.field(value,"requested_root"),path) &&
    bool_is(Json.field(value,"enabled"),enable) && (Bool.not(enable) || bool_is(Json.field(value,"registered"),True{}))

def source_ack(args: List<&2,String>,value: Json.Json) -> Bool:
  match args:
    case "source-add" <> name <> path <> []: ack_for(value,name,path,True{})
    case "source-disable" <> name <> path <> []: ack_for(value,name,path,False{})
    case _: False{}

def initial() -> Model:
  Model{0,Refresh.defaults(),None{},[],False{},None{},0,"Refresh preferences have not loaded."}

def phase(model: Model) -> U32:
  Model{phase,prefs,desired,sources,loaded,selected,offset,last} = model
  phase

def preferences(model: Model) -> Refresh.Preferences:
  Model{phase,prefs,desired,sources,loaded,selected,offset,last} = model
  prefs

def pending(model: Model) -> Maybe<&2,Refresh.Preferences>:
  Model{phase,prefs,desired,sources,loaded,selected,offset,last} = model
  desired

def sources(model: Model) -> List<&2,Source>:
  Model{phase,prefs,desired,sources,loaded,selected,offset,last} = model
  sources

def sources_loaded(model: Model) -> Bool:
  Model{phase,prefs,desired,sources,loaded,selected,offset,last} = model
  loaded

def selected(model: Model) -> Maybe<&2,Source>:
  Model{phase,prefs,desired,sources,loaded,selected,offset,last} = model
  selected

def last(model: Model) -> String:
  Model{phase,prefs,desired,sources,loaded,selected,offset,last} = model
  last

def offset(model: Model) -> U32:
  Model{phase,prefs,desired,sources,loaded,selected,offset,last} = model
  offset

def loading(model: Model) -> Model:
  Model{phase,prefs,desired,sources,loaded,selected,offset,last} = model
  Model{1,prefs,desired,sources,loaded,selected,offset,"Refresh preference request is pending."}

def loaded(model: Model,prefs: Refresh.Preferences) -> Model:
  Model{phase,old,desired,sources,loaded,selected,offset,last} = model
  Model{2,prefs,desired,sources,loaded,selected,offset,"Refresh preferences loaded."}

def desire(model: Model,prefs: Refresh.Preferences) -> Model:
  Model{phase,old,desired,sources,loaded,selected,offset,last} = model
  Model{phase,old,Some{prefs},sources,loaded,selected,offset,"Refresh preference change queued; acknowledged settings are retained."}

def acknowledged(desired: Maybe<&2,Refresh.Preferences>,+saved: Refresh.Preferences) -> Maybe<&2,Refresh.Preferences>:
  match desired:
    case None{}: None{}
    case Some{+value}: Bool.pick(Maybe<&2,Refresh.Preferences>,Refresh.same(value,saved),None{},Some{value})

def failed(model: Model,message: String) -> Model:
  Model{phase,prefs,desired,sources,loaded,selected,offset,last} = model
  Model{3,prefs,None{},sources,loaded,selected,offset,String.take(message,2048n)}

def saved_checked(+model: Model,+prefs: Refresh.Preferences,valid: Bool) -> Model:
  Model{phase,old,desired,sources,loaded,selected,offset,last} = model
  match valid:
    case False{}: failed(model,"Refresh preference acknowledgement did not match the complete requested pair.")
    case True{}:
      Model{2,prefs,acknowledged(desired,prefs),sources,loaded,selected,offset,"Refresh preferences saved."}

def saved(model: Model,+requested: Refresh.Preferences,+ack: Refresh.Preferences) -> Model:
  saved_checked(model,ack,Refresh.same(requested,ack))

def find(rows: List<&2,Source>,+wanted: Source) -> Maybe<&2,Source>:
  match rows:
    case []: None{}
    case +first <> rest:
      Bool.pick(Maybe<&2,Source>,same(first,wanted),Some{first},find(rest,wanted))

def reselect(selected: Maybe<&2,Source>,rows: List<&2,Source>) -> Maybe<&2,Source>:
  match selected:
    case None{}: None{}
    case Some{source}: find(rows,source)

def with_sources(model: Model,+sources: List<&2,Source>) -> Model:
  Model{phase,prefs,desired,old,loaded,selected,offset,last} = model
  Model{phase,prefs,desired,sources,True{},reselect(selected,sources),0,last}

def source_at(rows: List<&2,Source>,index: Nat) -> Maybe<&2,Source>:
  match rows index:
    case [] _: None{}
    case first <> rest 0n: Some{first}
    case first <> rest 1n+previous: source_at(rest,previous)

def select(model: Model,index: U32) -> Model:
  Model{phase,prefs,desired,+sources,loaded,selected,offset,last} = model
  Model{phase,prefs,desired,sources,loaded,source_at(sources,U32.to_nat(index)),offset,last}

def no_pending(value: Maybe<&2,Refresh.Preferences>) -> Bool:
  match value:
    case None{}: True{}
    case Some{_}: False{}

def available(model: Model) -> Bool:
  Model{phase,prefs,desired,sources,loaded,selected,offset,last} = model
  U32.is_eq(phase,2) && no_pending(desired)

def paused(model: Model) -> Bool:
  Model{phase,Refresh.Preferences{enabled,interval},desired,sources,loaded,selected,offset,last} = model
  Bool.not(enabled)

def deadline_result(result: Result<&2,&2,Refresh.Failure,Maybe<&2,Nat>>) -> Result<&2,&2,String,Maybe<&2,Nat>>:
  match result:
    case Done{deadline}: Done{deadline}
    case Fail{Refresh.Failure{code,message}}: Fail{String.take(message,2048n)}

def deadline_ready(model: Model,now: Nat,valid: Bool) -> Result<&2,&2,String,Maybe<&2,Nat>>:
  match valid:
    case False{}: Done{None{}}
    case True{}: deadline_result(Refresh.deadline(preferences(model),now))

def deadline(+model: Model,now: Nat) -> Result<&2,&2,String,Maybe<&2,Nat>>:
  deadline_ready(model,now,available(model))

def interval_label(prefs: Refresh.Preferences) -> String:
  Refresh.Preferences{enabled,interval} = prefs
  match interval:
    case Refresh.Live30{}: "Live (30 seconds)"
    case Refresh.Hours2{}: "Every 2 hours"
    case Refresh.Hours4{}: "Every 4 hours"
    case Refresh.Hours8{}: "Every 8 hours"
    case Refresh.Daily{}: "Daily"

def capture_label() -> String:
  "Refresh processes bounded batches; success does not establish that every registered file was captured."

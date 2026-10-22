import Base
import ./actors.bend as Actors

# Separate coverage from eligibility: this module never admits an actor or
# invents a request. It only explains when the inherited bounded admission scan
# cannot establish the candidate set for the selected repository.
type Count is Data:
  Count{snapshot: String,records: U32}

def records(items: List<&2,Count>,+snapshot: String) -> Maybe<&2,U32>:
  match items:
    case []: None{}
    case Count{key,count} <> rest:
      Bool.pick(Maybe<&2,U32>,String.eq(key,snapshot),Some{count},records(rest,snapshot))

def context_bound(value: Maybe<&2,U32>) -> String:
  match value:
    case None{}: "request eligibility snapshot count unavailable"
    case Some{count}:
      Bool.pick(String,U32.is_gt(count,16),
        "request eligibility not established within first 16 retained records","")

def unresolved(eligible: Bool,actor: Actors.Actor,counts: List<&2,Count>) -> String:
  match eligible:
    case True{}: ""
    case False{}: context_bound(records(counts,Actors.snapshot(actor)))

def parent(value: Maybe<&2,Actors.Actor>,next: Actors.Actor -> String) -> String:
  match value:
    case None{}: "request eligibility unresolved: parent absent or ambiguous in inspected snapshots"
    case Some{actor}: next(actor)

def step(eligible: Bool,has_parent: Bool,+actor: Actors.Actor,+all: List<&2,Actors.Actor>,
  +repo: String,counts: List<&2,Count>,next: Actors.Actor -> String) -> String:
  match eligible has_parent:
    case False{} _: unresolved(False{},actor,counts)
    case True{} False{}: ""
    case True{} True{}: parent(Actors.parent_actor(actor,all,repo),next)

def eligible_end(eligible: Bool,actor: Actors.Actor,counts: List<&2,Count>) -> String:
  match eligible:
    case False{}: unresolved(False{},actor,counts)
    case True{}: "request eligibility ancestry exceeds the 8-actor inspection bound"

def included(+actor: Actors.Actor,+repo: String) -> Bool:
  Actors.Actor{_,_,_,_,+location,_,_,_,blocked} = actor
  String.is_empty(blocked) && (String.is_empty(location) || Actors.scope(repo,actor))

def admitted(in_scope: Bool,eligible: Bool,has_parent: Bool,actor: Actors.Actor,all: List<&2,Actors.Actor>,
  repo: String,counts: List<&2,Count>,next: Actors.Actor -> String) -> String:
  match in_scope:
    case False{}: ""
    case True{}: step(eligible,has_parent,actor,all,repo,counts,next)

def end(in_scope: Bool,eligible: Bool,actor: Actors.Actor,counts: List<&2,Count>) -> String:
  match in_scope:
    case False{}: ""
    case True{}: eligible_end(eligible,actor,counts)

def chain(fuel: Nat,+actor: Actors.Actor,+all: List<&2,Actors.Actor>,+repo: String,+counts: List<&2,Count>) -> String:
  match fuel:
    case 0n: end(included(actor,repo),Actors.own_eligible(actor),actor,counts)
    case 1n+n:
      admitted(included(actor,repo),Actors.own_eligible(actor),Bool.not(String.is_empty(Actors.parent(actor))),
        actor,all,repo,counts,p => chain(n,p,all,repo,counts))

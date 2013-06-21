(** Abstract domain that keeps track of CPU cache configurations *)

open AD.DataStructures

type cache_strategy = 
  | LRU  (** least-recently used *)
  | FIFO (** first in, first out *)
  | PLRU (** tree-based pseudo LRU *)
type cache_param = int * int * int * cache_strategy (** total size, line size, associativity.*)(* TODO use a record *)

module type S = sig
  include AD.S
  val init : cache_param -> t
  (** initialize an empty cache
   takes arguments cache_size (in bytes), 
  line_size (in bytes) and associativity *)
  val touch : t -> int64 -> t
  (** reads or writes an address into cache *)

  (** Same as touch, but returns more precise informations about hit and misses *)
  (** @return, the first set overapproximates hit cases, the second one misses *)
  val touch_hm : t -> int64 -> (t add_bottom*t add_bottom)
  (** Used to keep track of time, if neccessary *)
  val elapse : t -> int -> t
  val count_cache_states : t -> Big_int.big_int
end


(** Creates cache domain from given value domain *)
module Make : functor (A : AgeAD.S) -> S


open Signatures

module SimpleVAD (V: VALUE_ABSTRACT_DOMAIN) : SIMPLE_VALUE_AD = struct
  
  type t = 
  {
    val_ad: V.t;
    maxval : int (*all values bigger than maxval are assumed to be maxval *)
  }
    
  
  let init_with_max v2s maxval = {val_ad = V.init v2s; maxval = maxval}

  let join e1 e2 = 
    assert (e1.maxval = e2.maxval);
    {e1 with val_ad = (V.join e1.val_ad e2.val_ad)}
  
  let flatten (d1,d2,d3,d4) =
    let result = List.fold_left (lift_combine V.join) Bot [d1;d2;d3;d4] in
    match result with
      Bot -> failwith "SValAD.flatten: bottom"
    | Nb a -> a

  (* computes comparison of x1 and x2, see vguard bellow *)
  (* the first result is x1<x2, the second one x1=x2 and the last one x1>x2 *)
  let vcomp venv x1 x2 =
   let _,tf,ft,ff= V.flagop venv X86Types.Sub x1 x2 in
    (* Since we only have positive values, when the carry flag is set, it means venv is strictly smaller than x2 *)
    (* The case where there is a carry and the result is zero should not be 
possible, so it approximates Bottom *)
   tf,ft,ff

  (* Compute x<c in V, where x is a variable and c an int. Should be extended to the case where c is a var *)
  (* the first result is x<c, the second one x=c and the last one x>c *)
  let vguard venv x c = vcomp venv (VarOp x) (Cons(Int64.of_int c))

  let inc_var env v = 
    let young,nyoung,_ = vguard env.val_ad v env.maxval in
(* we assume the cases bigger than maxval are irrelevent and we never increase values above maxval *)
    let new_valad = 
      match young with
      | Bot -> env.val_ad
      | Nb yenv ->
        let yenv = flatten (V.update_var yenv v NoMask (Cons 1L) NoMask (Op X86Types.Add)) in
        match nyoung with
        | Bot -> yenv
        | Nb nyenv -> V.join yenv nyenv
    in {env with val_ad = new_valad}
      
    
  let add env v c =
    {env with val_ad = flatten (V.update_var env.val_ad v NoMask (Cons(Int64.of_int c)) NoMask (Op X86Types.Add))}
  
  let get_keys map = let keys,_ = List.split (ValMap.bindings map)
                     in keys
                     
                 
  let set_var env v a = 
      if a > env.maxval then
        failwith "simpleValAD: set_var cannot set to values greater than the maximal value"
      else
        let val_ad = if not (V.is_var env.val_ad v) then 
                    V.new_var env.val_ad v
                  else env.val_ad
        in let val_ad = flatten(V.update_var val_ad v NoMask (Cons(Int64.of_int a)) NoMask Move) in
        {env with val_ad = val_ad}
  
  
  let list_max l = List.fold_left (fun m x -> if x > m then x else m ) 0L l
 
  (* updates an env according to the value env *)
  let vNewEnv env = function
    Bot -> Bot
  | Nb venv -> Nb{env with val_ad = venv}

  (* the first result is approximates the cases when x1 < x2 and
     the second one when x1 > x2 *)
  let comp env x1 x2 = 
    let smaller, eq, bigger = vcomp env.val_ad (VarOp x1) (VarOp x2) in
    vNewEnv env smaller, vNewEnv env bigger
  
  let print_delta env1 fmt env2 = V.print_delta env1.val_ad fmt env2.val_ad
  let print fmt env = V.print fmt env.val_ad
  let subseteq env1 env2= 
    assert (env1.maxval = env2.maxval);
    (V.subseteq env1.val_ad env2.val_ad)
  let widen env1 env2 = 
    assert (env1.maxval = env2.maxval);
    {env1 with val_ad = (V.widen env1.val_ad env2.val_ad)}
  let get_var env v = 
    let res = (V.get_var env.val_ad v) in
    match res with 
    | Tp -> Tp
    | Nt a -> Nt (ValMap.map (fun vad -> {env with val_ad = vad}) a)

  let is_var env a = V.is_var env.val_ad a
  
  let get_values env v = let l = match V.get_var env.val_ad v with 
     Tp -> []  | Nt x -> ValMap.bindings x in 
     List.map (fun (k,v) -> Int64.to_int k) l
end

module SimpleValAD = SimpleVAD (ValAD.ValAD)

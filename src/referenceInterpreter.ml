open Grammar
open Cst

(* Set up all of the information required by the LR engine. Everything is
   read directly from [Grammar] and [Lr1]. *)

module T = struct

  type state =
      Lr1.node
   
  type token =
      Terminal.t

  type terminal =
      Terminal.t

  type semantic_value =
      cst

  let token2terminal (token : token) : terminal =
    token

  let token2value (token : token) : semantic_value =
    CstTerminal token

  let error_terminal =
    Terminal.error

  let error_value =
    CstError

  type production =
      Production.index

  let default_reduction (s : state) defred nodefred env =
    match Invariant.has_default_reduction s with
    | Some (prod, _) ->
	defred env prod
    | None ->
	nodefred env

  let action (s : state) (tok : terminal) value shift reduce fail env =

    (* Check whether [s] has an outgoing shift transition along [tok]. *)

    try

      let s' : state = SymbolMap.find (Symbol.T tok) (Lr1.transitions s) in

      (* There is such a transition. Return either [ShiftDiscard] or
	 [ShiftNoDiscard], depending on the existence of a default
	 reduction on [#] at [s']. *)

      match Invariant.has_default_reduction s' with
      | Some (_, toks) when TerminalSet.mem Terminal.sharp toks ->
	  shift env false tok value s'
      | _ ->
	  shift env true tok value s'
	  
    (* There is no such transition. Look for a reduction. *)

    with Not_found ->
      try

	let prod = Misc.single (TerminalMap.find tok (Lr1.reductions s)) in
	reduce env prod

      (* There is no reduction either. Fail. *)

      with Not_found ->
	fail env

  let goto (s : state) (prod : production) : state =
    try
      SymbolMap.find (Symbol.N (Production.nt prod)) (Lr1.transitions s)
    with Not_found ->
      assert false

  open MenhirLib.EngineTypes

  exception Error

  (* By convention, a semantic action returns a new stack. It does not
     affect [env]. *)

  let is_start =
    Production.is_start

  type semantic_action =
      (state, semantic_value, token) env -> (state, semantic_value) stack

  let semantic_action (prod : production) : semantic_action =
    fun env ->
      assert (not (Production.is_start prod));

      (* Reduce. Pop a suffix of the stack, and use it to construct a
	 new concrete syntax tree node. *)

      let n = Production.length prod in

      let values : semantic_value array =
        Array.make n CstError (* dummy *)
      and startp =
        ref Lexing.dummy_pos
      and endp=
        ref Lexing.dummy_pos
      and current =
        ref env.current
      and stack =
        ref env.stack
      in

      (* We now enter a loop to pop [k] stack cells and (after that) push
         a new cell onto the stack. *)

      (* This loop does not update [env.current]. Instead, the state in
         the newly pushed stack cell will be used (by our caller) as a
         basis for a goto transition, and [env.current] will be updated
         (if necessary) then. *)

      for k = n downto 1 do

        (* Fetch a semantic value. *)

        values.(k - 1) <- !stack.semv;

        (* Pop one cell. The stack must be non-empty. As we pop a cell,
           change the automaton's current state to the one stored within
           the cell. (It is sufficient to do this only when [k] is 1,
           since the last write overwrites any and all previous writes.)
           If this is the first (last) cell that we pop, update [endp]
           ([startp]). *)

        let next = !stack.next in
        assert (!stack != next);
        if k = n then begin
          endp := !stack.endp
        end;
        if k = 1 then begin
          current := !stack.state;
          startp := !stack.startp
        end;
        stack := next

      done;

      (* Done popping. *)

      (* Construct and push a new stack cell. The associated semantic
         value is a new concrete syntax tree. *)

      {
        state = !current;
        semv = CstNonTerminal (prod, values);
        startp = !startp;
        endp = !endp;
        next = !stack
      }

  (* The logging functions that follow are called only if [log] is [true]. *)

  module Log = struct

    open Printf

    let state s =
      fprintf stderr "State %d:" (Lr1.number s);
      prerr_newline()

    let shift tok s' =
      fprintf stderr "Shifting (%s) to state %d" (Terminal.print tok) (Lr1.number s');
      prerr_newline()

    let reduce_or_accept prod =
      match Production.classify prod with
      | Some _ ->
         fprintf stderr "Accepting";
         prerr_newline()
      | None ->
         fprintf stderr "Reducing production %s" (Production.print prod);
         prerr_newline()

    let lookahead_token tok startp endp =
      fprintf stderr "Lookahead token is now %s (%d-%d)"
        (Terminal.print tok)
        startp.Lexing.pos_cnum
        endp.Lexing.pos_cnum;
      prerr_newline()

    let initiating_error_handling () =
      fprintf stderr "Initiating error handling";
      prerr_newline()

    let resuming_error_handling () =
      fprintf stderr "Resuming error handling";
      prerr_newline()

    let handling_error s =
      fprintf stderr "Handling error in state %d" (Lr1.number s);
      prerr_newline()

  end

end

(* Define a palatable user entry point. *)

let interpret log nt lexer lexbuf =

  (* Instantiate the LR engine. *)

  let module E =
    MenhirLib.Engine.Make (struct
      include T
      let log = log
    end)
  in

  (* Run it. *)

  try
    Some (E.entry (Lr1.entry_nt nt) lexer lexbuf)
  with T.Error ->
    None

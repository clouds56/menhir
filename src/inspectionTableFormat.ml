(* This signature defines the format of the tables that are produced (in
   addition to the tables described in [TableFormat]) when the command line
   switch [--inspection] is enabled. It is used as an argument to
   [InspectionTableInterpreter.Make]. *)

module type TABLES = sig

  (* The type ['a lr1state] describes an LR(1) state and will be defined
     internally as [int]. The types ['a symbol] and [xsymbol] are (generated)
     algebraic data types. These types must appear here because they serve to
     describe the argument and/or result of [InspectionTableInterpreter.Make]. *)

  type 'a lr1state

  type 'a terminal
  type 'a nonterminal

  type 'a symbol =
    | T : 'a terminal -> 'a symbol
    | N : 'a nonterminal -> 'a symbol

  type xsymbol = 
    | X : 'a symbol -> xsymbol

  (* Some of the tables that follow use encodings of (terminal and
     nonterminal) symbols as integers. So, we need functions that
     map the integer encoding of a symbol to its algebraic encoding. *)

  val    terminal: int -> xsymbol
  val nonterminal: int -> xsymbol

  (* The left-hand side of every production. (Same as in [TableFormat.TABLES].) *)

  val lhs: PackedIntArray.t

  (* The right-hand side of every production. This a linearized array
     of arrays of integers, whose [data] and [entry] components have
     been packed. The encoding of symbols as integers in described in
     [TableBackend]. *)

  val rhs: PackedIntArray.t * PackedIntArray.t

  (* A mapping of every (non-initial) state to its LR(0) core. *)

  val lr0_core: PackedIntArray.t

  (* A mapping of every LR(0) state to its set of LR(0) items. Each item is
     represented in its packed form (see [Item]) as an integer. Thus the
     mapping is an array of arrays of integers, which is linearized and
     packed, like [rhs]. *)

  val lr0_items: PackedIntArray.t * PackedIntArray.t

  (* A mapping of every LR(0) state to its incoming symbol, if it has one. *)

  val lr0_incoming: PackedIntArray.t

end


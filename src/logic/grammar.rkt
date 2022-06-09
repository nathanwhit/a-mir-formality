#lang racket
(require redex/reduction-semantics racket/set)
(provide formality-logic
         RootUniverse
         true-goal
         false-goal
         )

(define-language formality-logic
  ;; The "hook" is a bit of a hack that allows the environment
  ;; to (on demand) get access to clauses and invariants from the
  ;; program without actually knowing the full representation
  ;; of the program itself. See hook.rkt for more details.
  (Hook ::= (Hook: any))

  ;; Parameters to the logic:
  (Parameter ::= Term)     ; Value of a variable
  (ParameterKind ::= Term) ; Kinds for variables (e.g., type/lifetimes)
  (Predicate ::= Term)     ; Kinds of predicates we can prove
  (VarInequality ::= Term) ; Variable relationships inferred and stored in the environment
  (InequalityOp ::= Term)  ; Relations between terms beyond `==`

  ;; Env: Typing environment
  ;;
  ;; * Hook -- the "hook" that lets us get program information
  ;; * Universe -- the largest universe yet defined
  ;; * VarBinders -- maps variable names to quantifier-kinds/universes
  ;;   * When bound variables are instantiated, their names
  ;;     are added to this list.
  ;;   * When equating (existential) variables,
  ;;     we modify the universe that it is mapped to here
  ;; * Hypotheses -- facts believed to be true, introduced by
  ;;   where clauses
  (Envs ::= (Env ...))
  (Env ::= (Hook Universe VarBinders Substitution VarInequalities Hypotheses))

  ;; Maps variables to their values; those values are not core to the
  ;; logic, though.
  (Substitution ::= ((VarId Parameter) ...))
  (Substitution-or-error ::= Substitution Error)

  ;; VarBinder -- maps a `VarId` to a kind (ty/lifetime/etc), quantifier kind (forall/exists),
  ;; and universe
  (VarBinders ::= (VarBinder ...))
  (VarBinder ::= (VarId ParameterKind Quantifier Universe))

  ;; VarInequality -- for variables that don't have a known
  ;; value (which would appear in the substitution), we may
  ;; have an *inequality*. These are opaque to the logic layer,
  ;; they get manipulated by the type layer in the various
  ;; hook functions.
  (VarInequalities ::= (VarInequality ...))

  ;; KindedVarId: declares a bound parameter and
  ;; its kind (type, lifetime, etc).
  (KindedVarIds ::= (KindedVarId ...))
  (KindedVarId ::= (ParameterKind VarId))

  ;; `Parameters` -- parameters
  (Parameters ::= (Parameter ...))

  ;; `Predicate` -- the atomic items that we can prove
  (Predicates ::= (Predicate ...))

  ;; ANCHOR:GoalsAndHypotheses
  ;; `Goal` -- things we can prove. These consists of predicates
  ;; joined by various forms of logical operators that are built
  ;; into the proving system (see `cosld-solve.rkt`).
  ;;
  ;; `AtomicGoal` -- goals whose meaning is defined by the
  ;; upper layers and is opaque to this layer. We break them into
  ;; two categories, predicates and relations, which affects how
  ;; the upper layers convey their meaning to us:
  ;;
  ;; * For *predicates* the upper layer gives us a set of `Clause`
  ;;   instances we can use to prove them true.
  ;;
  ;; * For *relations* the upper layer directly manipulates the
  ;;   environment using a callback function and gives us a set of
  ;;   subsequent goals. This is used for things like subtyping that use a
  ;;   very custom search strategy to avoid getting "lost in the solver" and to implement
  ;;   inference.
  ;;
  ;; `BuiltinGoal` -- defines logical connectives that the solver layer
  ;; directly manages.
  (Goals = (Goal ...))
  (Goal ::= AtomicGoal BuiltinGoal)
  (AtomicGoal ::=
              Predicate
              Relation)
  (BuiltinGoal ::=
               (&& Goals)
               (|| Goals)
               (implies Hypotheses Goal)
               (Quantifier KindedVarIds Goal)
               )

  ;; `Clause`, `Hypothesis` -- axioms. These are both built-in and derived from
  ;; user-defined items like `trait` and `impl`.
  (Hypotheses Clauses ::= (Clause ...))
  (Hypothesis Clause ::=
              AtomicGoal
              (implies Goals AtomicGoal)
              (∀ KindedVarIds Clause)
              )
  ;; ANCHOR_END:GoalsAndHypotheses

  ;; A `FlatHypothesis` is a flattened form of hypotheses; it is equally expressive
  ;; with the recursive structure. Useful for matching.
  (FlatHypotheses ::= (FlatHypothesis ...))
  (FlatHypothesis ::= (∀ KindedVarIds FlatImplicationHypothesis))
  (FlatImplicationHypotheses ::= (FlatImplicationHypothesis ...))
  (FlatImplicationHypothesis ::= (implies Goals AtomicGoal))

  ;; `Invariants` -- things which must be true or the type system has some bugs.
  ;; A rather restricted form of clause.
  (Invariants ::= (Invariant ...))
  (Invariant ::=
             (∀ KindedVarIds Invariant)
             (implies (Predicate) Invariant)
             AtomicGoal
             )

  ;; `Invariants` -- things which must be true or the type system has some bugs.
  ;; A rather restricted form of clause.
  (FlatInvariants ::= (FlatInvariant ...))
  (FlatInvariant ::= (∀ KindedVarIds FlatInvariantImplication))
  (FlatInvariantImplication ::= (implies (Predicate) AtomicGoal))

  ;; Different ways to relate parameters
  (Relations ::= (Relation ...))
  (Relation ::= (Parameter RelationOp Parameter))
  (RelationOp ::= == InequalityOp)

  ;; `Quantifier` -- the two kinds of quantifiers.
  (Quantifier ::= ∀ ∃)

  ;; `Universe` -- the root universe `RootUniverse` consists of all user-defined names.
  ;; Each time we enter into a `∀` quantifier, we introduce a new universe
  ;; that extends the previous one to add new names that didn't exist in the old
  ;; universe (e.g., the placeholders for the universally quantified variables).
  ;; See the paper XXX
  (Universes ::= (Universe ...))
  (Universe ::= (universe number))
  (UniversePairs ::= (UniversePair ...))
  (UniversePair ::= (Universe Universe))

  ;; Identifiers -- these are all equivalent, but we give them fresh names to help
  ;; clarify their purpose
  (VarIds ::= (VarId ...))
  (VarId AnyId ::= variable-not-otherwise-mentioned)

  ; Term -- preferred name to any that reads better :)
  (Terms ::= (Term ...))
  (Term ::= any)
  (TermPair ::= (Term Term))
  (TermPairs ::= (TermPair ...))

  ; Internal data structure used during cosld proving
  (Prove/Stacks ::= (Predicates Predicates))
  (Prove/Coinductive ::= + -)

  (CanonicalTerm ::= (canonicalized VarBinders Term))
  (CanonicalGoal ::= (canonicalized VarBinders (implies Hypotheses Goal)))

  #:binding-forms
  (∀ ((ParameterKind VarId) ...) any #:refers-to (shadow VarId ...))
  (∃ ((ParameterKind VarId) ...) any #:refers-to (shadow VarId ...))
  (canonicalized ((VarId ParameterKind Quantifier Universe) ...) any #:refers-to (shadow VarId ...))
  )

(define-term
  RootUniverse
  (universe 0)
  )

(define-term
  true-goal
  (&& ())
  )

(define-term
  false-goal
  (|| ())
  )
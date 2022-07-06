#lang racket
(require redex/reduction-semantics
         "grammar-extended.rkt"
         "type-check-goal.rkt"
         "../decl/decl-ok.rkt"
         "../decl/env.rkt"
         "../decl/grammar.rkt"
         "../logic/cosld-solve.rkt"
         )
(provide prove-goal
         prove-goal-in-env
         prove-crate-item-ok
         )


(define-judgment-form
  formality-mir-extended

  #:mode (prove-crate-item-ok I I)
  #:contract (prove-crate-item-ok DeclProgram CrateItemDecl)

  [(where/error Goal_ok (crate-item-ok-goal (crate-decls DeclProgram) CrateItemDecl))
   (where/error [Goal_lang-ok ...] (lang-item-ok-goals (crate-decls DeclProgram) CrateItemDecl))
   (prove-goal DeclProgram Goal_ok)
   (prove-goal DeclProgram Goal_lang-ok) ...
   ----------------------------------------
   (prove-crate-item-ok DeclProgram CrateItemDecl)
   ]
  )

(define-judgment-form
  formality-mir-extended

  #:mode (prove-goal I I)
  #:contract (prove-goal DeclProgram Goal)

  [(where/error Env (env-for-decl-program DeclProgram))
   (logic:prove-top-level-goal/cosld Env Goal Env_1)
   ----------------------------------------
   (prove-goal DeclProgram Goal)
   ]
  )

(define-judgment-form
  formality-mir-extended

  #:mode (prove-goal-in-env I I O)
  #:contract (prove-goal-in-env Env Goal Env_out)

  [(logic:prove-top-level-goal/cosld Env Goal Env_out)
   ----------------------------------------
   (prove-goal-in-env Env Goal Env_out)
   ]
  )
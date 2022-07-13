#lang racket
(require redex/reduction-semantics
         "../../util.rkt"
         "../grammar.rkt"
         "../prove.rkt"
         )



(module+ test
  (redex-let*
   formality-rust
   [

    (Rust/Program (term ([(crate TheCrate {
                                           ((auto) trait MySend[] where [] { })
                                           (struct Ptr[(type T)] where [] { (data : T) })
                                           (struct Foo[] where [] { })
                                           (struct ContainsFoo[] where [] { (f : (Foo < >)) })
                                           (struct UnsendTy[] where [] { })
                                           (impl[] ! MySend[] for (UnsendTy < >) where [] { })
                                           (struct ContainsUnsendTy[] where [] { (f : (UnsendTy < >)) })
                                           })]
                         TheCrate)))
    ]

   (;; can prove forall<T> { if (T: MySend) { Ptr<T> : MySend } }
    traced '()
           (test-equal
            (term (rust:can-prove-goal-in-program
                   Rust/Program
                   (∀ ((type T)) (implies ((is-implemented (MySend (T))) (has-impl (MySend (T)))) (is-implemented (MySend ((rigid-ty Ptr (T))) ))) )
                   ))
            #t
            )
           )

   (;; cannot prove forall<T> { Ptr<T> : MySend }
    traced '()
           (test-equal
            (term (rust:can-prove-goal-in-program
                   Rust/Program
                   (∀ ((type T)) (is-implemented (MySend ((rigid-ty Ptr (T))) )) )
                   ))
            #f
            )
           )

   (;; can prove Foo : MySend
    traced '()
           (test-equal
            (term (rust:can-prove-goal-in-program
                   Rust/Program
                   (is-implemented (MySend ((rigid-ty Foo []))))
                   ))
            #t
            )
           )

   (;; can prove ContainsFoo : MySend
    traced '()
           (test-equal
            (term (rust:can-prove-goal-in-program
                   Rust/Program
                   (is-implemented (MySend ((rigid-ty ContainsFoo []))))
                   ))
            #t
            )
           )

   (;; cannot prove UnsendTy : MySend
    traced '()
           (test-equal
            (term (rust:can-prove-goal-in-program
                   Rust/Program
                   (is-implemented (MySend ((rigid-ty UnsendTy []))))
                   ))
            #f
            )
           )

   (;; cannot prove ContainsUnsendTy : MySend
    traced '()
           (test-equal
            (term (rust:can-prove-goal-in-program
                   Rust/Program
                   (is-implemented (MySend ((rigid-ty ContainsUnsendTy []))))
                   ))
            #f
            )
           )
   )
  )
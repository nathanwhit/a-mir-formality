#lang racket
(require redex/reduction-semantics
         "../grammar.rkt"
         "../../logic/substitution.rkt"
         )

(provide is-auto-trait
         auto-trait-decl-rules
         )

(define-metafunction formality-decl
  is-auto-trait : CrateDecls TraitId -> boolean

  [(is-auto-trait CrateDecls TraitId)
   #t
   (where ((_ ... auto _ ...) trait TraitId KindedVarIds where _ _) (trait-with-id CrateDecls TraitId))
   ]

  [(is-auto-trait CrateDecls TraitId)
   #f]
  )

(define-metafunction formality-decl
  has-explicit-impl : CrateDecls TraitId Ty -> boolean

  [(has-explicit-impl CrateDecls TraitId_t Ty_self)
   #t
   (where (rigid-ty AdtId _) Ty_self)
   (where (_ ... CrateDecl_c _ ...) CrateDecls)
   (where (crate _ (_ ... (TraitImplPolarity _ (TraitId_t ((rigid-ty AdtId _))) where _ _) _ ...)) CrateDecl_c)
   ]

  [(has-explicit-impl CrateDecls TraitId Ty)
   #f
   ]
  )

(define-metafunction formality-decl
  constituent-types : CrateDecls (rigid-ty AdtId Parameters) -> (Ty ...)

  [(constituent-types CrateDecls (rigid-ty AdtId Parameters))
   (Ty_field ... ...)
   (where/error (AdtKind AdtId KindedVarIds where _ AdtVariants) (adt-with-id CrateDecls AdtId))
   (where/error Substitution (create-substitution KindedVarIds Parameters))
   (where/error AdtVariants_substituted (apply-substitution Substitution AdtVariants))
   (where/error ((VariantId FieldDecls) ...) AdtVariants_substituted)
   (where/error (((_ Ty_field) ...) ...) (FieldDecls ...))
   ]
  )

(define-metafunction formality-decl
  auto-trait-decl-rules : CrateDecls TraitId Ty -> Clauses

  [(auto-trait-decl-rules CrateDecls TraitId (rigid-ty AdtId Parameters))
   ()
   (side-condition (term (has-explicit-impl CrateDecls TraitId (rigid-ty AdtId Parameters))))
   ]

  [(auto-trait-decl-rules CrateDecls TraitId (rigid-ty AdtId Parameters))
   (Clause)
   (where/error (AdtKind AdtId KindedVarIds where _ _) (adt-with-id CrateDecls AdtId))
   (where/error Ty_adt (rigid-ty AdtId Parameters))
   (where/error (Ty_field ...) (constituent-types CrateDecls Ty_adt))
   (where/error Clause (implies
                        ((has-impl (TraitId (Ty_field))) ...)
                        (has-impl (TraitId (Ty_adt)))))
   ]

  [(auto-trait-decl-rules CrateDecls TraitId Ty)
   ()
   ]
  )
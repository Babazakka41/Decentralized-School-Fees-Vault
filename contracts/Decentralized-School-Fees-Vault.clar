(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1))
(define-constant ERR_INVALID_AMOUNT (err u2))
(define-constant ERR_INVALID_DATE (err u3))
(define-constant ERR_VAULT_NOT_FOUND (err u4))
(define-constant ERR_FUNDS_LOCKED (err u5))
(define-constant ERR_INSUFFICIENT_BALANCE (err u6))
(define-constant ERR_ALREADY_RELEASED (err u7))
(define-constant ERR_INVALID_SCHOOL (err u8))
(define-constant ERR_VAULT_EXISTS (err u9))
(define-constant ERR_INVALID_DISCOUNT (err u10))

(define-data-var vault-counter uint u0)
(define-data-var total-locked uint u0)
(define-data-var total-released uint u0)

(define-map vaults
    { vault-id: uint }
    {
        parent: principal,
        student-name: (string-ascii 100),
        school: principal,
        amount: uint,
        release-block: uint,
        created-block: uint,
        released: bool,
        term: (string-ascii 50),
    }
)

(define-map parent-vaults
    {
        parent: principal,
        vault-id: uint,
    }
    { exists: bool }
)

(define-map school-vaults
    {
        school: principal,
        vault-id: uint,
    }
    { exists: bool }
)

(define-map school-info
    { school: principal }
    {
        name: (string-ascii 100),
        verified: bool,
        total-collected: uint,
    }
)

(define-map parent-stats
    { parent: principal }
    {
        total-deposited: uint,
        total-withdrawn: uint,
        active-vaults: uint,
    }
)

(define-map school-discounts
    { school: principal }
    {
        early-payment-discount: uint,
        multi-child-discount: uint,
        loyalty-discount: uint,
        min-blocks-early: uint,
    }
)

(define-map parent-discount-eligibility
    {
        parent: principal,
        school: principal,
    }
    {
        children-count: uint,
        total-paid: uint,
        loyalty-tier: uint,
    }
)

(define-read-only (get-vault (vault-id uint))
    (map-get? vaults { vault-id: vault-id })
)

(define-read-only (get-school-info (school principal))
    (map-get? school-info { school: school })
)

(define-read-only (get-parent-stats (parent principal))
    (map-get? parent-stats { parent: parent })
)

(define-read-only (get-school-discounts (school principal))
    (map-get? school-discounts { school: school })
)

(define-read-only (get-parent-discount-eligibility
        (parent principal)
        (school principal)
    )
    (map-get? parent-discount-eligibility {
        parent: parent,
        school: school,
    })
)

(define-read-only (get-contract-stats)
    {
        total-locked: (var-get total-locked),
        total-released: (var-get total-released),
        total-vaults: (var-get vault-counter),
    }
)

(define-read-only (is-vault-releasable (vault-id uint))
    (match (map-get? vaults { vault-id: vault-id })
        vault-data (and
            (>= burn-block-height (get release-block vault-data))
            (not (get released vault-data))
        )
        false
    )
)

(define-read-only (get-blocks-until-release (vault-id uint))
    (match (map-get? vaults { vault-id: vault-id })
        vault-data (if (>= burn-block-height (get release-block vault-data))
            u0
            (- (get release-block vault-data) burn-block-height)
        )
        u0
    )
)

(define-read-only (get-vault-status (vault-id uint))
    (match (map-get? vaults { vault-id: vault-id })
        vault-data (if (get released vault-data)
            "released"
            (if (>= burn-block-height (get release-block vault-data))
                "releasable"
                "locked"
            )
        )
        "not-found"
    )
)

(define-read-only (calculate-discount-amount
        (original-amount uint)
        (parent principal)
        (school principal)
        (blocks-until-release uint)
    )
    (let (
            (discount-config (default-to {
                early-payment-discount: u0,
                multi-child-discount: u0,
                loyalty-discount: u0,
                min-blocks-early: u0,
            }
                (map-get? school-discounts { school: school })
            ))
            (parent-eligibility (default-to {
                children-count: u1,
                total-paid: u0,
                loyalty-tier: u0,
            }
                (map-get? parent-discount-eligibility {
                    parent: parent,
                    school: school,
                })
            ))
            (early-payment-eligible (>= blocks-until-release (get min-blocks-early discount-config)))
            (multi-child-eligible (> (get children-count parent-eligibility) u1))
            (loyalty-eligible (> (get loyalty-tier parent-eligibility) u0))
            (total-discount-rate (+
                (if early-payment-eligible
                    (get early-payment-discount discount-config)
                    u0
                )
                (if multi-child-eligible
                    (get multi-child-discount discount-config)
                    u0
                )
                (if loyalty-eligible
                    (get loyalty-discount discount-config)
                    u0
                )))
            (capped-discount-rate (if (> total-discount-rate u50)
                u50
                total-discount-rate
            ))
            (discount-amount (/ (* original-amount capped-discount-rate) u100))
        )
        {
            discounted-amount: (- original-amount discount-amount),
            discount-amount: discount-amount,
            discount-rate: capped-discount-rate,
        }
    )
)

(define-private (update-parent-stats
        (parent principal)
        (amount uint)
        (increment bool)
    )
    (let ((current-stats (default-to {
            total-deposited: u0,
            total-withdrawn: u0,
            active-vaults: u0,
        }
            (map-get? parent-stats { parent: parent })
        )))
        (map-set parent-stats { parent: parent }
            (if increment
                {
                    total-deposited: (+ (get total-deposited current-stats) amount),
                    total-withdrawn: (get total-withdrawn current-stats),
                    active-vaults: (+ (get active-vaults current-stats) u1),
                }
                {
                    total-deposited: (get total-deposited current-stats),
                    total-withdrawn: (+ (get total-withdrawn current-stats) amount),
                    active-vaults: (- (get active-vaults current-stats) u1),
                }
            ))
    )
)

(define-private (update-school-stats
        (school principal)
        (amount uint)
    )
    (let ((current-info (default-to {
            name: "",
            verified: false,
            total-collected: u0,
        }
            (map-get? school-info { school: school })
        )))
        (map-set school-info { school: school } {
            name: (get name current-info),
            verified: (get verified current-info),
            total-collected: (+ (get total-collected current-info) amount),
        })
    )
)

(define-public (register-school (name (string-ascii 100)))
    (let ((school tx-sender))
        (if (is-some (map-get? school-info { school: school }))
            ERR_VAULT_EXISTS
            (begin
                (map-set school-info { school: school } {
                    name: name,
                    verified: false,
                    total-collected: u0,
                })
                (ok true)
            )
        )
    )
)

(define-public (verify-school (school principal))
    (if (is-eq tx-sender CONTRACT_OWNER)
        (match (map-get? school-info { school: school })
            school-data (begin
                (map-set school-info { school: school } {
                    name: (get name school-data),
                    verified: true,
                    total-collected: (get total-collected school-data),
                })
                (ok true)
            )
            ERR_INVALID_SCHOOL
        )
        ERR_UNAUTHORIZED
    )
)

(define-public (set-school-discounts
        (early-payment-discount uint)
        (multi-child-discount uint)
        (loyalty-discount uint)
        (min-blocks-early uint)
    )
    (let ((school tx-sender))
        (if (is-some (map-get? school-info { school: school }))
            (if (and
                    (<= early-payment-discount u50)
                    (<= multi-child-discount u50)
                    (<= loyalty-discount u50)
                )
                (begin
                    (map-set school-discounts { school: school } {
                        early-payment-discount: early-payment-discount,
                        multi-child-discount: multi-child-discount,
                        loyalty-discount: loyalty-discount,
                        min-blocks-early: min-blocks-early,
                    })
                    (ok true)
                )
                ERR_INVALID_DISCOUNT
            )
            ERR_INVALID_SCHOOL
        )
    )
)

(define-public (update-parent-eligibility
        (parent principal)
        (children-count uint)
    )
    (let ((school tx-sender))
        (if (is-some (map-get? school-info { school: school }))
            (let (
                    (current-eligibility (default-to {
                        children-count: u1,
                        total-paid: u0,
                        loyalty-tier: u0,
                    }
                        (map-get? parent-discount-eligibility {
                            parent: parent,
                            school: school,
                        })
                    ))
                    (new-loyalty-tier (if (>= (get total-paid current-eligibility) u1000000)
                        u2
                        (if (>= (get total-paid current-eligibility) u500000)
                            u1
                            u0
                        )
                    ))
                )
                (map-set parent-discount-eligibility {
                    parent: parent,
                    school: school,
                } {
                    children-count: children-count,
                    total-paid: (get total-paid current-eligibility),
                    loyalty-tier: new-loyalty-tier,
                })
                (ok true)
            )
            ERR_INVALID_SCHOOL
        )
    )
)

(define-public (create-vault
        (student-name (string-ascii 100))
        (school principal)
        (release-blocks uint)
        (term (string-ascii 50))
    )
    (let (
            (vault-id (+ (var-get vault-counter) u1))
            (release-block (+ burn-block-height release-blocks))
        )
        (if (and (> (stx-get-balance tx-sender) u0) (> release-blocks u0))
            (if (is-some (map-get? school-info { school: school }))
                (let (
                        (amount (stx-get-balance tx-sender))
                        (discount-info (calculate-discount-amount amount tx-sender school
                            release-blocks
                        ))
                        (final-amount (get discounted-amount discount-info))
                    )
                    (try! (stx-transfer? final-amount tx-sender (as-contract tx-sender)))
                    (map-set vaults { vault-id: vault-id } {
                        parent: tx-sender,
                        student-name: student-name,
                        school: school,
                        amount: final-amount,
                        release-block: release-block,
                        created-block: burn-block-height,
                        released: false,
                        term: term,
                    })
                    (map-set parent-vaults {
                        parent: tx-sender,
                        vault-id: vault-id,
                    } { exists: true }
                    )
                    (map-set school-vaults {
                        school: school,
                        vault-id: vault-id,
                    } { exists: true }
                    )
                    (var-set vault-counter vault-id)
                    (var-set total-locked (+ (var-get total-locked) final-amount))
                    (update-parent-stats tx-sender final-amount true)
                    (let ((current-eligibility (default-to {
                            children-count: u1,
                            total-paid: u0,
                            loyalty-tier: u0,
                        }
                            (map-get? parent-discount-eligibility {
                                parent: tx-sender,
                                school: school,
                            })
                        )))
                        (map-set parent-discount-eligibility {
                            parent: tx-sender,
                            school: school,
                        } {
                            children-count: (get children-count current-eligibility),
                            total-paid: (+ (get total-paid current-eligibility) final-amount),
                            loyalty-tier: (get loyalty-tier current-eligibility),
                        })
                    )
                    (ok vault-id)
                )
                ERR_INVALID_SCHOOL
            )
            ERR_INVALID_AMOUNT
        )
    )
)

(define-public (deposit-to-vault
        (vault-id uint)
        (amount uint)
    )
    (match (map-get? vaults { vault-id: vault-id })
        vault-data (if (is-eq tx-sender (get parent vault-data))
            (if (not (get released vault-data))
                (if (>= (stx-get-balance tx-sender) amount)
                    (begin
                        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
                        (map-set vaults { vault-id: vault-id }
                            (merge vault-data { amount: (+ (get amount vault-data) amount) })
                        )
                        (var-set total-locked (+ (var-get total-locked) amount))
                        (update-parent-stats tx-sender amount true)
                        (ok true)
                    )
                    ERR_INSUFFICIENT_BALANCE
                )
                ERR_ALREADY_RELEASED
            )
            ERR_UNAUTHORIZED
        )
        ERR_VAULT_NOT_FOUND
    )
)

(define-public (release-funds (vault-id uint))
    (match (map-get? vaults { vault-id: vault-id })
        vault-data (if (>= burn-block-height (get release-block vault-data))
            (if (not (get released vault-data))
                (let (
                        (amount (get amount vault-data))
                        (school (get school vault-data))
                    )
                    (try! (as-contract (stx-transfer? amount tx-sender school)))
                    (map-set vaults { vault-id: vault-id }
                        (merge vault-data { released: true })
                    )
                    (var-set total-released (+ (var-get total-released) amount))
                    (var-set total-locked (- (var-get total-locked) amount))
                    (update-parent-stats (get parent vault-data) amount false)
                    (update-school-stats school amount)
                    (ok true)
                )
                ERR_ALREADY_RELEASED
            )
            ERR_FUNDS_LOCKED
        )
        ERR_VAULT_NOT_FOUND
    )
)

(define-public (emergency-withdraw (vault-id uint))
    (match (map-get? vaults { vault-id: vault-id })
        vault-data (if (is-eq tx-sender (get parent vault-data))
            (if (not (get released vault-data))
                (if (< burn-block-height (get release-block vault-data))
                    (let ((amount (get amount vault-data)))
                        (try! (as-contract (stx-transfer? amount tx-sender (get parent vault-data))))
                        (map-set vaults { vault-id: vault-id }
                            (merge vault-data { released: true })
                        )
                        (var-set total-locked (- (var-get total-locked) amount))
                        (update-parent-stats (get parent vault-data) amount false)
                        (ok true)
                    )
                    ERR_FUNDS_LOCKED
                )
                ERR_ALREADY_RELEASED
            )
            ERR_UNAUTHORIZED
        )
        ERR_VAULT_NOT_FOUND
    )
)

(define-public (extend-release-date
        (vault-id uint)
        (additional-blocks uint)
    )
    (match (map-get? vaults { vault-id: vault-id })
        vault-data (if (is-eq tx-sender (get parent vault-data))
            (if (not (get released vault-data))
                (if (> additional-blocks u0)
                    (begin
                        (map-set vaults { vault-id: vault-id }
                            (merge vault-data { release-block: (+ (get release-block vault-data) additional-blocks) })
                        )
                        (ok true)
                    )
                    ERR_INVALID_DATE
                )
                ERR_ALREADY_RELEASED
            )
            ERR_UNAUTHORIZED
        )
        ERR_VAULT_NOT_FOUND
    )
)

(define-public (batch-release-funds (vault-ids (list 20 uint)))
    (ok (map release-funds vault-ids))
)

(define-read-only (get-releasable-vaults-count)
    (let ((current-count (var-get vault-counter)))
        (fold check-releasable-vault
            (list
                u1                 u2                 u3                 u4
                u5                 u6                 u7                 u8
                u9                 u10                 u11                 u12
                u13                 u14                 u15                 u16
                u17                 u18
                u19                 u20
            )
            u0
        )
    )
)

(define-private (check-releasable-vault
        (vault-id uint)
        (acc uint)
    )
    (if (is-vault-releasable vault-id)
        (+ acc u1)
        acc
    )
)

(define-read-only (is-parent-vault
        (vault-id uint)
        (parent principal)
    )
    (match (map-get? vaults { vault-id: vault-id })
        vault-data (is-eq parent (get parent vault-data))
        false
    )
)

(define-read-only (is-school-vault
        (vault-id uint)
        (school principal)
    )
    (match (map-get? vaults { vault-id: vault-id })
        vault-data (is-eq school (get school vault-data))
        false
    )
)

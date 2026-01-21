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
(define-constant ERR_INVALID_DISTRIBUTION (err u11))
(define-constant ERR_DISTRIBUTION_NOT_FOUND (err u12))

;; Analytics & Reporting System Error Constants
(define-constant ERR_ANALYTICS_NOT_FOUND (err u301))
(define-constant ERR_INVALID_DATE_RANGE (err u302))
(define-constant ERR_NO_DATA_AVAILABLE (err u303))

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

(define-map school-distribution-config
    { school: principal }
    {
        operations: uint,
        scholarship: uint,
        maintenance: uint,
        emergency: uint,
        operations-wallet: principal,
        scholarship-wallet: principal,
        maintenance-wallet: principal,
        emergency-wallet: principal,
    }
)

(define-map distribution-stats
    { school: principal }
    {
        total-operations: uint,
        total-scholarship: uint,
        total-maintenance: uint,
        total-emergency: uint,
    }
)

;; Analytics & Reporting System Data Maps
(define-map monthly-payment-totals
    { year: uint, month: uint }
    {
        total-amount: uint,
        payment-count: uint,
        unique-schools: uint,
        unique-parents: uint,
    }
)

(define-map seasonal-trends
    { year: uint, quarter: uint }
    {
        total-payments: uint,
        avg-payment: uint,
        student-count: uint,
        peak-payment-day: uint,
    }
)

(define-map payment-day-statistics
    { day-of-month: uint }
    {
        payment-count: uint,
        total-amount: uint,
        avg-amount: uint,
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

(define-read-only (get-school-distribution-config (school principal))
    (map-get? school-distribution-config { school: school })
)

(define-read-only (get-distribution-stats (school principal))
    (map-get? distribution-stats { school: school })
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

(define-read-only (calculate-distribution-amounts
        (total-amount uint)
        (school principal)
    )
    (match (map-get? school-distribution-config { school: school })
        distribution-config (let (
                (operations-amount (/ (* total-amount (get operations distribution-config)) u100))
                (scholarship-amount (/ (* total-amount (get scholarship distribution-config)) u100))
                (maintenance-amount (/ (* total-amount (get maintenance distribution-config)) u100))
                (emergency-amount (/ (* total-amount (get emergency distribution-config)) u100))
            )
            {
                operations-amount: operations-amount,
                scholarship-amount: scholarship-amount,
                maintenance-amount: maintenance-amount,
                emergency-amount: emergency-amount,
                operations-wallet: (get operations-wallet distribution-config),
                scholarship-wallet: (get scholarship-wallet distribution-config),
                maintenance-wallet: (get maintenance-wallet distribution-config),
                emergency-wallet: (get emergency-wallet distribution-config),
            }
        )
        {
            operations-amount: total-amount,
            scholarship-amount: u0,
            maintenance-amount: u0,
            emergency-amount: u0,
            operations-wallet: school,
            scholarship-wallet: school,
            maintenance-wallet: school,
            emergency-wallet: school,
        }
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

(define-private (update-distribution-stats
        (school principal)
        (operations-amount uint)
        (scholarship-amount uint)
        (maintenance-amount uint)
        (emergency-amount uint)
    )
    (let ((current-stats (default-to {
            total-operations: u0,
            total-scholarship: u0,
            total-maintenance: u0,
            total-emergency: u0,
        }
            (map-get? distribution-stats { school: school })
        )))
        (map-set distribution-stats { school: school } {
            total-operations: (+ (get total-operations current-stats) operations-amount),
            total-scholarship: (+ (get total-scholarship current-stats) scholarship-amount),
            total-maintenance: (+ (get total-maintenance current-stats) maintenance-amount),
            total-emergency: (+ (get total-emergency current-stats) emergency-amount),
        })
    )
)

(define-private (update-payment-analytics
        (amount uint)
        (school principal)
    )
    (let (
            (current-block burn-block-height)
            (year (get-year-from-block current-block))
            (month (get-month-from-block current-block))
            (quarter (get-quarter-from-month month))
            (blocks-per-day u144)
            (day-of-month (+ (mod (/ (mod current-block (* blocks-per-day u30)) blocks-per-day) u31) u1))
        )
        (let (
                (monthly-stats (default-to {
                    total-amount: u0,
                    payment-count: u0,
                    unique-schools: u0,
                    unique-parents: u0,
                }
                    (map-get? monthly-payment-totals { year: year, month: month })
                ))
                (quarterly-stats (default-to {
                    total-payments: u0,
                    avg-payment: u0,
                    student-count: u0,
                    peak-payment-day: u0,
                }
                    (map-get? seasonal-trends { year: year, quarter: quarter })
                ))
                (day-stats (default-to {
                    payment-count: u0,
                    total-amount: u0,
                    avg-amount: u0,
                }
                    (map-get? payment-day-statistics { day-of-month: day-of-month })
                ))
            )
            (let (
                    (new-monthly-total (+ (get total-amount monthly-stats) amount))
                    (new-monthly-count (+ (get payment-count monthly-stats) u1))
                    (new-quarterly-total (+ (get total-payments quarterly-stats) amount))
                    (new-quarterly-count (+ (get student-count quarterly-stats) u1))
                    (new-day-count (+ (get payment-count day-stats) u1))
                    (new-day-total (+ (get total-amount day-stats) amount))
                )
                (map-set monthly-payment-totals { year: year, month: month } {
                    total-amount: new-monthly-total,
                    payment-count: new-monthly-count,
                    unique-schools: (+ (get unique-schools monthly-stats) u1),
                    unique-parents: (+ (get unique-parents monthly-stats) u1),
                })
                (map-set seasonal-trends { year: year, quarter: quarter } {
                    total-payments: new-quarterly-total,
                    avg-payment: (if (> new-quarterly-count u0) (/ new-quarterly-total new-quarterly-count) u0),
                    student-count: new-quarterly-count,
                    peak-payment-day: day-of-month,
                })
                (map-set payment-day-statistics { day-of-month: day-of-month } {
                    payment-count: new-day-count,
                    total-amount: new-day-total,
                    avg-amount: (if (> new-day-count u0) (/ new-day-total new-day-count) u0),
                })
            )
        )
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

(define-public (configure-fee-distribution
        (operations-percentage uint)
        (scholarship-percentage uint)
        (maintenance-percentage uint)
        (emergency-percentage uint)
        (operations-wallet principal)
        (scholarship-wallet principal)
        (maintenance-wallet principal)
        (emergency-wallet principal)
    )
    (let ((school tx-sender))
        (if (is-some (map-get? school-info { school: school }))
            (if (is-eq
                    (+ operations-percentage scholarship-percentage
                        maintenance-percentage emergency-percentage
                    )
                    u100
                )
                (begin
                    (map-set school-distribution-config { school: school } {
                        operations: operations-percentage,
                        scholarship: scholarship-percentage,
                        maintenance: maintenance-percentage,
                        emergency: emergency-percentage,
                        operations-wallet: operations-wallet,
                        scholarship-wallet: scholarship-wallet,
                        maintenance-wallet: maintenance-wallet,
                        emergency-wallet: emergency-wallet,
                    })
                    (ok true)
                )
                ERR_INVALID_DISTRIBUTION
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
                        (distribution (calculate-distribution-amounts amount school))
                    )
                    (if (> (get operations-amount distribution) u0)
                        (try! (as-contract (stx-transfer? (get operations-amount distribution)
                            tx-sender (get operations-wallet distribution)
                        )))
                        true
                    )
                    (if (> (get scholarship-amount distribution) u0)
                        (try! (as-contract (stx-transfer? (get scholarship-amount distribution)
                            tx-sender (get scholarship-wallet distribution)
                        )))
                        true
                    )
                    (if (> (get maintenance-amount distribution) u0)
                        (try! (as-contract (stx-transfer? (get maintenance-amount distribution)
                            tx-sender (get maintenance-wallet distribution)
                        )))
                        true
                    )
                    (if (> (get emergency-amount distribution) u0)
                        (try! (as-contract (stx-transfer? (get emergency-amount distribution)
                            tx-sender (get emergency-wallet distribution)
                        )))
                        true
                    )
                    (map-set vaults { vault-id: vault-id }
                        (merge vault-data { released: true })
                    )
                    (var-set total-released (+ (var-get total-released) amount))
                    (var-set total-locked (- (var-get total-locked) amount))
                    (update-parent-stats (get parent vault-data) amount false)
                    (update-school-stats school amount)
                    (update-distribution-stats school
                        (get operations-amount distribution)
                        (get scholarship-amount distribution)
                        (get maintenance-amount distribution)
                        (get emergency-amount distribution)
                    )
                    (update-payment-analytics amount school)
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

;; ==========================================
;; ANALYTICS & REPORTING SYSTEM
;; ==========================================

;; Get monthly payment statistics
(define-read-only (get-monthly-statistics (year uint) (month uint))
    (if (and (>= year u2020) (<= year u2050) (>= month u1) (<= month u12))
        (match (map-get? monthly-payment-totals { year: year, month: month })
            stats (ok stats)
            ERR_ANALYTICS_NOT_FOUND
        )
        ERR_INVALID_DATE_RANGE
    )
)

;; Get quarterly seasonal trends
(define-read-only (get-quarterly-trends (year uint) (quarter uint))
    (if (and (>= year u2020) (<= year u2050) (>= quarter u1) (<= quarter u4))
        (match (map-get? seasonal-trends { year: year, quarter: quarter })
            trends (ok trends)
            ERR_ANALYTICS_NOT_FOUND
        )
        ERR_INVALID_DATE_RANGE
    )
)

;; Calculate average payments over date range
(define-read-only (calculate-payment-average (start-year uint) (end-year uint))
    (if (and (>= start-year u2020) (<= end-year u2050) (<= start-year end-year))
        (let (
            (year-diff (- end-year start-year))
            (vault-count (var-get vault-counter))
            (released-amount (var-get total-released))
        )
            (if (> vault-count u0)
                (ok {
                    average-payment: (/ released-amount vault-count),
                    total-payments: vault-count,
                    years-analyzed: (+ year-diff u1),
                    success: true,
                })
                ERR_NO_DATA_AVAILABLE
            )
        )
        ERR_INVALID_DATE_RANGE
    )
)

;; Get payment frequency by day of month
(define-read-only (get-payment-day-pattern (day uint))
    (if (and (>= day u1) (<= day u31))
        (match (map-get? payment-day-statistics { day-of-month: day })
            pattern (ok pattern)
            (ok {
                payment-count: u0,
                total-amount: u0,
                avg-amount: u0,
            })
        )
        ERR_INVALID_DATE_RANGE
    )
)

;; Aggregate yearly payment totals
(define-read-only (aggregate-yearly-totals (year uint))
    (if (and (>= year u2020) (<= year u2050))
        (let (
            (q1 (default-to { total-payments: u0, avg-payment: u0, student-count: u0, peak-payment-day: u0 }
                (map-get? seasonal-trends { year: year, quarter: u1 })))
            (q2 (default-to { total-payments: u0, avg-payment: u0, student-count: u0, peak-payment-day: u0 }
                (map-get? seasonal-trends { year: year, quarter: u2 })))
            (q3 (default-to { total-payments: u0, avg-payment: u0, student-count: u0, peak-payment-day: u0 }
                (map-get? seasonal-trends { year: year, quarter: u3 })))
            (q4 (default-to { total-payments: u0, avg-payment: u0, student-count: u0, peak-payment-day: u0 }
                (map-get? seasonal-trends { year: year, quarter: u4 })))
            (total-yearly-payments (+ (+ (get total-payments q1) (get total-payments q2))
                                    (+ (get total-payments q3) (get total-payments q4))))
            (total-yearly-students (+ (+ (get student-count q1) (get student-count q2))
                                    (+ (get student-count q3) (get student-count q4))))
        )
            (ok {
                year: year,
                total-payments: total-yearly-payments,
                total-students: total-yearly-students,
                avg-yearly-payment: (if (> total-yearly-payments u0) (/ total-yearly-payments u4) u0),
                quarters-analyzed: u4,
            })
        )
        ERR_INVALID_DATE_RANGE
    )
)

;; Generate comprehensive vault performance metrics
(define-read-only (generate-performance-metrics)
    (let (
        (vault-count (var-get vault-counter))
        (locked-amount (var-get total-locked))
        (released-amount (var-get total-released))
        (overall-total (+ locked-amount released-amount))
    )
        (ok {
            total-vaults-created: vault-count,
            total-amount-locked: locked-amount,
            total-amount-released: released-amount,
            total-amount-processed: overall-total,
            release-rate: (if (> overall-total u0) (/ (* released-amount u100) overall-total) u0),
            avg-vault-size: (if (> vault-count u0) (/ overall-total vault-count) u0),
            system-utilization: (if (> overall-total u0) (/ (* locked-amount u100) overall-total) u0),
            performance-score: (if (> vault-count u10) u100 (* vault-count u10)),
        })
    )
)

;; Get analytics system health status
(define-read-only (get-analytics-health)
    (let (
        (vault-count (var-get vault-counter))
        (total-processed (+ (var-get total-locked) (var-get total-released)))
    )
        (ok {
            system-status: (if (> vault-count u0) "active" "inactive"),
            data-points: vault-count,
            total-volume: total-processed,
            analytics-version: "v1.0.0",
            last-updated: burn-block-height,
        })
    )
)

;; Calculate month from block height (simplified approximation)
(define-read-only (get-month-from-block (target-block uint))
    (let (
        (blocks-per-month u4320) ;; Approximate blocks per month (144 blocks/day * 30 days)
        (months-since-genesis (/ target-block blocks-per-month))
        (month (+ (mod months-since-genesis u12) u1))
    )
        month
    )
)

;; Calculate year from block height (simplified approximation)
(define-read-only (get-year-from-block (target-block uint))
    (let (
        (blocks-per-year u51840) ;; Approximate blocks per year (144 blocks/day * 360 days)
        (years-since-genesis (/ target-block blocks-per-year))
        (year (+ years-since-genesis u2020)) ;; Base year 2020
    )
        year
    )
)

;; Calculate quarter from month
(define-read-only (get-quarter-from-month (month uint))
    (if (<= month u3) u1
        (if (<= month u6) u2
            (if (<= month u9) u3 u4)
        )
    )
)

;; Get comprehensive vault insights
(define-read-only (get-vault-insights (vault-id uint))
    (match (map-get? vaults { vault-id: vault-id })
        vault-data (let (
            (created-month (get-month-from-block (get created-block vault-data)))
            (created-year (get-year-from-block (get created-block vault-data)))
            (created-quarter (get-quarter-from-month created-month))
            (days-locked (/ (- (get release-block vault-data) (get created-block vault-data)) u144))
        )
            (ok {
                vault-id: vault-id,
                created-month: created-month,
                created-year: created-year,
                created-quarter: created-quarter,
                lock-duration-days: days-locked,
                amount: (get amount vault-data),
                status: (get-vault-status vault-id),
                parent: (get parent vault-data),
                school: (get school vault-data),
                student-name: (get student-name vault-data),
                term: (get term vault-data),
            })
        )
        ERR_VAULT_NOT_FOUND
    )
)

;; VetoVault Governance Token (SIP-010 Compliant)
;; A governance token with voting power, delegation, and snapshot capabilities
(use-trait sip-010-trait .sip-010-trait.sip-010-trait)
(impl-trait .sip-010-trait.sip-010-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-INVALID-RECIPIENT (err u104))
(define-constant ERR-SELF-DELEGATION (err u105))
(define-constant ERR-SNAPSHOT-NOT-FOUND (err u106))
(define-constant ERR-INVALID-SNAPSHOT (err u107))

;; Token metadata
(define-fungible-token vetovault-token)
(define-constant TOKEN-NAME "VetoVault Governance Token")
(define-constant TOKEN-SYMBOL "VVT")
(define-constant TOKEN-DECIMALS u6)
(define-constant TOKEN-URI u"https://vetovault.com/token-metadata.json")

;; Data variables
(define-data-var token-total-supply uint u0)
(define-data-var snapshot-counter uint u0)

;; Data maps
(define-map token-balances principal uint)
(define-map token-supplies-at-snapshot uint uint)
(define-map token-balances-at-snapshot {snapshot-id: uint, account: principal} uint)
(define-map delegates principal principal)
(define-map delegated-votes principal uint)
(define-map delegated-votes-at-snapshot {snapshot-id: uint, account: principal} uint)
(define-map snapshot-block-heights uint uint)

;; SIP-010 Functions

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
    (begin
        (asserts! (or (is-eq from tx-sender) (is-eq from contract-caller)) ERR-NOT-TOKEN-OWNER)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (not (is-eq to from)) ERR-INVALID-RECIPIENT)
        (asserts! (>= (ft-get-balance vetovault-token from) amount) ERR-INSUFFICIENT-BALANCE)
        
        ;; Update balances
        (try! (ft-transfer? vetovault-token amount from to))
        
        ;; Update delegated votes if necessary
        (let ((from-delegate (get-delegate from))
              (to-delegate (get-delegate to)))
            (if (is-some from-delegate)
                (update-delegated-votes (unwrap-panic from-delegate) (- (get-delegated-votes (unwrap-panic from-delegate)) amount))
                true)
            (if (is-some to-delegate)
                (update-delegated-votes (unwrap-panic to-delegate) (+ (get-delegated-votes (unwrap-panic to-delegate)) amount))
                true))
        
        (print {action: "transfer", from: from, to: to, amount: amount, memo: memo})
        (ok true)))

(define-read-only (get-name)
    (ok TOKEN-NAME))

(define-read-only (get-symbol)
    (ok TOKEN-SYMBOL))

(define-read-only (get-decimals)
    (ok TOKEN-DECIMALS))

(define-read-only (get-balance (who principal))
    (ok (ft-get-balance vetovault-token who)))

(define-read-only (get-total-supply)
    (ok (ft-get-supply vetovault-token)))

(define-read-only (get-token-uri)
    (ok (some TOKEN-URI)))

;; Governance Functions

(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        
        (try! (ft-mint? vetovault-token amount recipient))
        
        ;; Update delegated votes if recipient has a delegate
        (let ((recipient-delegate (get-delegate recipient)))
            (if (is-some recipient-delegate)
                (update-delegated-votes (unwrap-panic recipient-delegate) (+ (get-delegated-votes (unwrap-panic recipient-delegate)) amount))
                true))
        
        (print {action: "mint", recipient: recipient, amount: amount})
        (ok true)))

(define-public (burn (amount uint) (owner principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (>= (ft-get-balance vetovault-token owner) amount) ERR-INSUFFICIENT-BALANCE)
        
        (try! (ft-burn? vetovault-token amount owner))
        
        ;; Update delegated votes if owner has a delegate
        (let ((owner-delegate (get-delegate owner)))
            (if (is-some owner-delegate)
                (update-delegated-votes (unwrap-panic owner-delegate) (- (get-delegated-votes (unwrap-panic owner-delegate)) amount))
                true))
        
        (print {action: "burn", owner: owner, amount: amount})
        (ok true)))

;; Delegation Functions

(define-public (delegate (delegatee principal))
    (begin
        (asserts! (not (is-eq tx-sender delegatee)) ERR-SELF-DELEGATION)
        
        (let ((current-delegate (get-delegate tx-sender))
              (sender-balance (ft-get-balance vetovault-token tx-sender)))
            
            ;; Remove votes from current delegate if exists
            (if (is-some current-delegate)
                (update-delegated-votes (unwrap-panic current-delegate) 
                    (- (get-delegated-votes (unwrap-panic current-delegate)) sender-balance))
                true)
            
            ;; Set new delegate
            (map-set delegates tx-sender delegatee)
            
            ;; Add votes to new delegate
            (update-delegated-votes delegatee (+ (get-delegated-votes delegatee) sender-balance))
            
            (print {action: "delegate", delegator: tx-sender, delegatee: delegatee})
            (ok true))))

(define-public (undelegate)
    (begin
        (let ((current-delegate (get-delegate tx-sender))
              (sender-balance (ft-get-balance vetovault-token tx-sender)))
            
            (asserts! (is-some current-delegate) (ok true))
            
            ;; Remove votes from current delegate
            (update-delegated-votes (unwrap-panic current-delegate) 
                (- (get-delegated-votes (unwrap-panic current-delegate)) sender-balance))
            
            ;; Remove delegation
            (map-delete delegates tx-sender)
            
            (print {action: "undelegate", delegator: tx-sender})
            (ok true))))

(define-read-only (get-delegate (account principal))
    (map-get? delegates account))

(define-read-only (get-delegated-votes (account principal))
    (default-to u0 (map-get? delegated-votes account)))

;; Snapshot Functions

(define-public (create-snapshot)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        
        (let ((snapshot-id (+ (var-get snapshot-counter) u1))
              (current-supply (ft-get-supply vetovault-token)))
            
            ;; Increment snapshot counter
            (var-set snapshot-counter snapshot-id)
            
            ;; Store total supply at snapshot
            (map-set token-supplies-at-snapshot snapshot-id current-supply)
            
            ;; Store block height
            (map-set snapshot-block-heights snapshot-id stacks-block-height)
            
            (print {action: "create-snapshot", snapshot-id: snapshot-id, block-height: stacks-block-height})
            (ok snapshot-id))))

(define-read-only (get-balance-at-snapshot (snapshot-id uint) (account principal))
    (let ((balance (map-get? token-balances-at-snapshot {snapshot-id: snapshot-id, account: account})))
        (if (is-some balance)
            (ok (unwrap-panic balance))
            (if (> snapshot-id (var-get snapshot-counter))
                ERR-INVALID-SNAPSHOT
                (ok u0)))))

(define-read-only (get-total-supply-at-snapshot (snapshot-id uint))
    (let ((supply (map-get? token-supplies-at-snapshot snapshot-id)))
        (if (is-some supply)
            (ok (unwrap-panic supply))
            ERR-SNAPSHOT-NOT-FOUND)))

(define-read-only (get-delegated-votes-at-snapshot (snapshot-id uint) (account principal))
    (let ((votes (map-get? delegated-votes-at-snapshot {snapshot-id: snapshot-id, account: account})))
        (if (is-some votes)
            (ok (unwrap-panic votes))
            (if (> snapshot-id (var-get snapshot-counter))
                ERR-INVALID-SNAPSHOT
                (ok u0)))))

(define-read-only (get-voting-power (account principal))
    (let ((balance (ft-get-balance vetovault-token account))
          (delegated (get-delegated-votes account)))
        (ok (+ balance delegated))))

(define-read-only (get-voting-power-at-snapshot (snapshot-id uint) (account principal))
    (let ((balance (unwrap-panic (get-balance-at-snapshot snapshot-id account)))
          (delegated (unwrap-panic (get-delegated-votes-at-snapshot snapshot-id account))))
        (ok (+ balance delegated))))

(define-read-only (get-current-snapshot-id)
    (ok (var-get snapshot-counter)))

(define-read-only (get-snapshot-block-height (snapshot-id uint))
    (map-get? snapshot-block-heights snapshot-id))

;; Private Functions

(define-private (update-delegated-votes (account principal) (new-amount uint))
    (begin
        (map-set delegated-votes account new-amount)
        true))

;; Snapshot update functions (called during transfers, mints, burns)
(define-private (update-balance-snapshot (snapshot-id uint) (account principal) (balance uint))
    (map-set token-balances-at-snapshot {snapshot-id: snapshot-id, account: account} balance))

(define-private (update-delegated-votes-snapshot (snapshot-id uint) (account principal) (votes uint))
    (map-set delegated-votes-at-snapshot {snapshot-id: snapshot-id, account: account} votes))

;; Initialize contract
(begin
    (print {action: "contract-deployed", name: TOKEN-NAME, symbol: TOKEN-SYMBOL})
    (ok true))

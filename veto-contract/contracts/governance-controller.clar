;; governance-controller.clar
;; Main governance coordination contract for proposal lifecycle management

;; =============================================================================
;; CONSTANTS AND ERROR CODES
;; =============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u1001))
(define-constant ERR_PROPOSAL_EXPIRED (err u1002))
(define-constant ERR_PROPOSAL_NOT_ACTIVE (err u1003))
(define-constant ERR_PROPOSAL_ALREADY_EXISTS (err u1004))
(define-constant ERR_INVALID_PROPOSAL_TYPE (err u1005))
(define-constant ERR_INSUFFICIENT_VOTING_POWER (err u1006))
(define-constant ERR_ALREADY_VOTED (err u1007))
(define-constant ERR_VOTING_PERIOD_ENDED (err u1008))
(define-constant ERR_EXECUTION_FAILED (err u1009))
(define-constant ERR_INVALID_PARAMETER (err u1010))
(define-constant ERR_PROPOSAL_NOT_PASSED (err u1011))
(define-constant ERR_TIMELOCK_NOT_EXPIRED (err u1012))

;; Proposal states
(define-constant PROPOSAL_STATE_PENDING u0)
(define-constant PROPOSAL_STATE_ACTIVE u1)
(define-constant PROPOSAL_STATE_SUCCEEDED u2)
(define-constant PROPOSAL_STATE_DEFEATED u3)
(define-constant PROPOSAL_STATE_QUEUED u4)
(define-constant PROPOSAL_STATE_EXECUTED u5)
(define-constant PROPOSAL_STATE_CANCELLED u6)

;; Proposal types
(define-constant PROPOSAL_TYPE_STANDARD u0)
(define-constant PROPOSAL_TYPE_PARAMETER_CHANGE u1)
(define-constant PROPOSAL_TYPE_EMERGENCY u2)
(define-constant PROPOSAL_TYPE_TREASURY u3)

;; =============================================================================
;; DATA MAPS AND VARIABLES
;; =============================================================================

;; Governance parameters
(define-data-var voting-delay uint u1440) ;; blocks (~1 day)
(define-data-var voting-period uint u10080) ;; blocks (~1 week)
(define-data-var proposal-threshold uint u1000000) ;; minimum tokens to create proposal
(define-data-var quorum-threshold uint u40) ;; percentage (40%)
(define-data-var timelock-delay uint u17280) ;; blocks (~12 hours)
(define-data-var guardian principal CONTRACT_OWNER)
(define-data-var proposal-counter uint u0)

;; Proposal data structure
(define-map proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-utf8 256),
    description: (string-utf8 1024),
    proposal-type: uint,
    targets: (list 10 principal),
    values: (list 10 uint),
    calldatas: (list 10 (buff 1024)),
    start-block: uint,
    end-block: uint,
    for-votes: uint,
    against-votes: uint,
    abstain-votes: uint,
    state: uint,
    eta: (optional uint),
    created-at: uint,
    last-updated: uint
  }
)

;; Vote receipts
(define-map vote-receipts
  { proposal-id: uint, voter: principal }
  {
    has-voted: bool,
    support: uint, ;; 0 = against, 1 = for, 2 = abstain
    votes: uint,
    reason: (optional (string-utf8 256))
  }
)

;; Proposal snapshots for voting power calculation
(define-map proposal-snapshots
  { proposal-id: uint }
  {
    snapshot-block: uint,
    total-supply: uint
  }
)

;; Queued transactions for timelock
(define-map queued-transactions
  { tx-hash: (buff 32) }
  {
    proposal-id: uint,
    target: principal,
    value: uint,
    data: (buff 1024),
    eta: uint
  }
)

;; Cancelled proposals tracking
(define-map cancelled-proposals
  { proposal-id: uint }
  { cancelled-by: principal, cancelled-at: uint }
)

;; Data variables for token contract integration
(define-data-var token-contract (optional principal) none)

;; =============================================================================
;; TOKEN INTEGRATION FUNCTIONS
;; =============================================================================

;; Set the token contract that will be used for voting power
(define-public (set-token-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set token-contract (some contract))
    (print { event: "token-contract-set", contract: contract })
    (ok true))
)

;; Get voting power with fallback mechanism
(define-private (get-voting-power-safe (account principal) (height uint))
  (match (var-get token-contract)
    token-addr
    ;; If token contract is set, try to call it (you'll need to implement this based on your token contract)
    ;; For now, returning default value - implement actual contract call when token contract is available
    u1000000 ;; Default voting power - replace with: (default-to u0 (contract-call? token-addr get-votes-at account block-height))
    ;; If no token contract set, return default
    u1000000)
)

;; Get total supply with fallback mechanism  
(define-private (get-total-supply-safe)
  (match (var-get token-contract)
    token-addr
    ;; If token contract is set, try to call it
    u100000000 ;; Default total supply - replace with: (default-to u0 (contract-call? token-addr get-total-supply))
    ;; If no token contract set, return default
    u100000000)
)

;; =============================================================================
;; PRIVATE FUNCTIONS
;; =============================================================================

(define-private (get-current-block-height)
  stacks-block-height
)

(define-private (get-voting-power (account principal) (height uint))
  (get-voting-power-safe account height)
)

(define-private (calculate-proposal-state (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal
    (let
      (
        (current-block (get-current-block-height))
        (start-block (get start-block proposal))
        (end-block (get end-block proposal))
        (for-votes (get for-votes proposal))
        (against-votes (get against-votes proposal))
        (total-votes (+ for-votes against-votes (get abstain-votes proposal)))
        (quorum-votes (/ (* (var-get quorum-threshold) 
                           (default-to u0 
                             (get total-supply 
                               (map-get? proposal-snapshots { proposal-id: proposal-id })))) u100))
      )
      (if (< current-block start-block)
        PROPOSAL_STATE_PENDING
        (if (<= current-block end-block)
          PROPOSAL_STATE_ACTIVE
          (if (and (>= total-votes quorum-votes) (> for-votes against-votes))
            PROPOSAL_STATE_SUCCEEDED
            PROPOSAL_STATE_DEFEATED))))
    PROPOSAL_STATE_DEFEATED)
)

(define-private (generate-tx-hash (proposal-id uint) (target principal) (value uint) (data (buff 1024)))
  ;; Generate a unique hash for the transaction
  (sha256 (concat (concat (unwrap-panic (to-consensus-buff? proposal-id))
                         (unwrap-panic (to-consensus-buff? target)))
                 (concat (unwrap-panic (to-consensus-buff? value)) data)))
)

;; =============================================================================
;; PUBLIC FUNCTIONS - PROPOSAL CREATION
;; =============================================================================

(define-public (propose 
  (title (string-utf8 256))
  (description (string-utf8 1024))
  (proposal-type uint)
  (targets (list 10 principal))
  (values (list 10 uint))
  (calldatas (list 10 (buff 1024))))
  (let
    (
      (proposer tx-sender)
      (current-block (get-current-block-height))
      (voting-power (get-voting-power proposer current-block))
      (proposal-id (+ (var-get proposal-counter) u1))
      (start-block (+ current-block (var-get voting-delay)))
      (end-block (+ start-block (var-get voting-period)))
    )
    ;; Validate proposer has enough voting power
    (asserts! (>= voting-power (var-get proposal-threshold)) ERR_INSUFFICIENT_VOTING_POWER)
    
    ;; Validate proposal type
    (asserts! (<= proposal-type PROPOSAL_TYPE_TREASURY) ERR_INVALID_PROPOSAL_TYPE)
    
    ;; Validate targets, values, and calldatas have same length
    (asserts! (and (is-eq (len targets) (len values))
                  (is-eq (len targets) (len calldatas))) ERR_INVALID_PARAMETER)
    
    ;; Create proposal
    (map-set proposals
      { proposal-id: proposal-id }
      {
        proposer: proposer,
        title: title,
        description: description,
        proposal-type: proposal-type,
        targets: targets,
        values: values,
        calldatas: calldatas,
        start-block: start-block,
        end-block: end-block,
        for-votes: u0,
        against-votes: u0,
        abstain-votes: u0,
        state: PROPOSAL_STATE_PENDING,
        eta: none,
        created-at: current-block,
        last-updated: current-block
      }
    )
    
    ;; Create snapshot for voting power calculation
    (map-set proposal-snapshots
      { proposal-id: proposal-id }
      {
        snapshot-block: current-block,
        total-supply: (get-total-supply-safe)
      }
    )
    
    ;; Update proposal counter
    (var-set proposal-counter proposal-id)
    
    (print {
      event: "proposal-created",
      proposal-id: proposal-id,
      proposer: proposer,
      title: title,
      start-block: start-block,
      end-block: end-block
    })
    
    (ok proposal-id))
)

;; =============================================================================
;; PUBLIC FUNCTIONS - VOTING
;; =============================================================================

(define-public (cast-vote (proposal-id uint) (support uint) (reason (optional (string-utf8 256))))
  (let
    (
      (voter tx-sender)
      (current-block (get-current-block-height))
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (start-block (get start-block proposal))
      (end-block (get end-block proposal))
      (voting-power (get-voting-power voter (get snapshot-block 
                      (unwrap! (map-get? proposal-snapshots { proposal-id: proposal-id })
                              ERR_PROPOSAL_NOT_FOUND))))
    )
    ;; Validate voting period
    (asserts! (>= current-block start-block) ERR_PROPOSAL_NOT_ACTIVE)
    (asserts! (<= current-block end-block) ERR_VOTING_PERIOD_ENDED)
    
    ;; Check if already voted
    (asserts! (is-none (map-get? vote-receipts { proposal-id: proposal-id, voter: voter }))
              ERR_ALREADY_VOTED)
    
    ;; Validate support value (0 = against, 1 = for, 2 = abstain)
    (asserts! (<= support u2) ERR_INVALID_PARAMETER)
    
    ;; Record vote
    (map-set vote-receipts
      { proposal-id: proposal-id, voter: voter }
      {
        has-voted: true,
        support: support,
        votes: voting-power,
        reason: reason
      }
    )
    
    ;; Update proposal vote counts
    (let
      (
        (updated-proposal
          (if (is-eq support u0) ;; against
            (merge proposal { against-votes: (+ (get against-votes proposal) voting-power) })
            (if (is-eq support u1) ;; for
              (merge proposal { for-votes: (+ (get for-votes proposal) voting-power) })
              (merge proposal { abstain-votes: (+ (get abstain-votes proposal) voting-power) }))))
      )
      (map-set proposals
        { proposal-id: proposal-id }
        (merge updated-proposal { last-updated: current-block })))
    
    (print {
      event: "vote-cast",
      proposal-id: proposal-id,
      voter: voter,
      support: support,
      votes: voting-power,
      reason: reason
    })
    
    (ok true))
)

;; =============================================================================
;; PUBLIC FUNCTIONS - PROPOSAL EXECUTION
;; =============================================================================

(define-public (queue-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (current-state (calculate-proposal-state proposal-id))
      (current-block (get-current-block-height))
      (eta (+ current-block (var-get timelock-delay)))
    )
    ;; Validate proposal succeeded
    (asserts! (is-eq current-state PROPOSAL_STATE_SUCCEEDED) ERR_PROPOSAL_NOT_PASSED)
    
    ;; Queue all transactions
    (let
      (
        (targets (get targets proposal))
        (values (get values proposal))
        (calldatas (get calldatas proposal))
      )
      (map queue-transaction
           (map generate-tx-hash
                (list proposal-id proposal-id proposal-id proposal-id proposal-id 
                      proposal-id proposal-id proposal-id proposal-id proposal-id)
                targets values calldatas)
           (list proposal-id proposal-id proposal-id proposal-id proposal-id 
                 proposal-id proposal-id proposal-id proposal-id proposal-id)
           targets values calldatas
           (list eta eta eta eta eta eta eta eta eta eta))
    )
    
    ;; Update proposal state
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal {
        state: PROPOSAL_STATE_QUEUED,
        eta: (some eta),
        last-updated: current-block
      }))
    
    (print {
      event: "proposal-queued",
      proposal-id: proposal-id,
      eta: eta
    })
    
    (ok true))
)

(define-private (queue-transaction 
  (tx-hash (buff 32))
  (proposal-id uint)
  (target principal)
  (value uint)
  (data (buff 1024))
  (eta uint))
  (map-set queued-transactions
    { tx-hash: tx-hash }
    {
      proposal-id: proposal-id,
      target: target,
      value: value,
      data: data,
      eta: eta
    }))

(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (current-block (get-current-block-height))
      (eta (unwrap! (get eta proposal) ERR_PROPOSAL_NOT_FOUND))
    )
    ;; Validate proposal is queued and timelock has passed
    (asserts! (is-eq (get state proposal) PROPOSAL_STATE_QUEUED) ERR_PROPOSAL_NOT_PASSED)
    (asserts! (>= current-block eta) ERR_TIMELOCK_NOT_EXPIRED)
    
    ;; Execute all transactions (simplified - in practice would need more complex execution)
    ;; This is a placeholder for actual execution logic
    
    ;; Update proposal state
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal {
        state: PROPOSAL_STATE_EXECUTED,
        last-updated: current-block
      }))
    
    (print {
      event: "proposal-executed",
      proposal-id: proposal-id
    })
    
    (ok true))
)

;; =============================================================================
;; PUBLIC FUNCTIONS - GOVERNANCE MANAGEMENT
;; =============================================================================

(define-public (cancel-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (current-block (get-current-block-height))
    )
    ;; Only proposer or guardian can cancel
    (asserts! (or (is-eq tx-sender (get proposer proposal))
                 (is-eq tx-sender (var-get guardian))) ERR_UNAUTHORIZED)
    
    ;; Can only cancel active or pending proposals
    (asserts! (or (is-eq (get state proposal) PROPOSAL_STATE_PENDING)
                 (is-eq (get state proposal) PROPOSAL_STATE_ACTIVE)) ERR_PROPOSAL_NOT_ACTIVE)
    
    ;; Update proposal state
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal {
        state: PROPOSAL_STATE_CANCELLED,
        last-updated: current-block
      }))
    
    ;; Record cancellation
    (map-set cancelled-proposals
      { proposal-id: proposal-id }
      {
        cancelled-by: tx-sender,
        cancelled-at: current-block
      })
    
    (print {
      event: "proposal-cancelled",
      proposal-id: proposal-id,
      cancelled-by: tx-sender
    })
    
    (ok true))
)

;; =============================================================================
;; PUBLIC FUNCTIONS - PARAMETER MANAGEMENT
;; =============================================================================

(define-public (set-voting-delay (new-delay uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set voting-delay new-delay)
    (print { event: "voting-delay-updated", new-delay: new-delay })
    (ok true))
)

(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set voting-period new-period)
    (print { event: "voting-period-updated", new-period: new-period })
    (ok true))
)

(define-public (set-proposal-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set proposal-threshold new-threshold)
    (print { event: "proposal-threshold-updated", new-threshold: new-threshold })
    (ok true))
)

(define-public (set-quorum-threshold (new-quorum uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-quorum u100) ERR_INVALID_PARAMETER)
    (var-set quorum-threshold new-quorum)
    (print { event: "quorum-threshold-updated", new-quorum: new-quorum })
    (ok true))
)

(define-public (set-timelock-delay (new-delay uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set timelock-delay new-delay)
    (print { event: "timelock-delay-updated", new-delay: new-delay })
    (ok true))
)

(define-public (set-guardian (new-guardian principal))
  (begin
    (asserts! (is-eq tx-sender (var-get guardian)) ERR_UNAUTHORIZED)
    (var-set guardian new-guardian)
    (print { event: "guardian-updated", new-guardian: new-guardian })
    (ok true))
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-proposal-state (proposal-id uint))
  (calculate-proposal-state proposal-id)
)

(define-read-only (get-vote-receipt (proposal-id uint) (voter principal))
  (map-get? vote-receipts { proposal-id: proposal-id, voter: voter })
)

(define-read-only (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? vote-receipts { proposal-id: proposal-id, voter: voter }))
)

(define-read-only (get-governance-parameters)
  {
    voting-delay: (var-get voting-delay),
    voting-period: (var-get voting-period),
    proposal-threshold: (var-get proposal-threshold),
    quorum-threshold: (var-get quorum-threshold),
    timelock-delay: (var-get timelock-delay),
    guardian: (var-get guardian),
    proposal-counter: (var-get proposal-counter)
  }
)

(define-read-only (get-proposal-snapshot (proposal-id uint))
  (map-get? proposal-snapshots { proposal-id: proposal-id })
)

(define-read-only (get-queued-transaction (tx-hash (buff 32)))
  (map-get? queued-transactions { tx-hash: tx-hash })
)

(define-read-only (is-proposal-cancelled (proposal-id uint))
  (is-some (map-get? cancelled-proposals { proposal-id: proposal-id }))
)

(define-read-only (get-current-block)
  (get-current-block-height)
)
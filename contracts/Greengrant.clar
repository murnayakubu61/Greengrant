;; title: Greengrant
;; version: 1.0.0
;; summary: Environmental DAO Grants - Fund green innovation via community votes
;; description: A decentralized platform for funding environmental projects through community governance

;; traits

;; token definitions

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-already-voted (err u104))
(define-constant err-voting-ended (err u105))
(define-constant err-voting-active (err u106))
(define-constant err-insufficient-funds (err u107))
(define-constant err-proposal-not-approved (err u108))
(define-constant err-already-executed (err u109))
(define-constant err-invalid-duration (err u110))

(define-constant min-proposal-amount u1000000)
(define-constant max-proposal-amount u100000000)
(define-constant voting-duration u1440)
(define-constant min-votes-required u3)

;; data vars
(define-data-var next-proposal-id uint u1)
(define-data-var total-treasury uint u0)
(define-data-var dao-members uint u0)

;; data maps
(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    amount: uint,
    recipient: principal,
    votes-for: uint,
    votes-against: uint,
    start-block: uint,
    end-block: uint,
    executed: bool,
    approved: bool
  }
)

(define-map member-votes
  { proposal-id: uint, voter: principal }
  { vote: bool, amount: uint }
)

(define-map dao-membership
  principal
  { joined-block: uint, voting-power: uint, contributions: uint }
)

(define-map member-contributions
  principal
  uint
)

;; public functions
(define-public (join-dao)
  (let ((current-block stacks-block-height))
    (map-set dao-membership tx-sender {
      joined-block: current-block,
      voting-power: u1,
      contributions: u0
    })
    (var-set dao-members (+ (var-get dao-members) u1))
    (ok true)
  )
)

(define-public (contribute-to-treasury (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set total-treasury (+ (var-get total-treasury) amount))
    (match (map-get? dao-membership tx-sender)
      member (map-set dao-membership tx-sender (merge member { 
        contributions: (+ (get contributions member) amount),
        voting-power: (+ (get voting-power member) (/ amount u1000000))
      }))
      (map-set dao-membership tx-sender {
        joined-block: stacks-block-height,
        voting-power: (/ amount u1000000),
        contributions: amount
      })
    )
    (map-set member-contributions tx-sender 
      (+ (default-to u0 (map-get? member-contributions tx-sender)) amount))
    (ok true)
  )
)

(define-public (create-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (amount uint)
  (recipient principal))
  (let ((proposal-id (var-get next-proposal-id))
        (current-block stacks-block-height))
    (asserts! (>= amount min-proposal-amount) err-invalid-amount)
    (asserts! (<= amount max-proposal-amount) err-invalid-amount)
    (asserts! (<= amount (var-get total-treasury)) err-insufficient-funds)
    (asserts! (is-some (map-get? dao-membership tx-sender)) err-unauthorized)
    
    (map-set proposals proposal-id {
      proposer: tx-sender,
      title: title,
      description: description,
      amount: amount,
      recipient: recipient,
      votes-for: u0,
      votes-against: u0,
      start-block: current-block,
      end-block: (+ current-block voting-duration),
      executed: false,
      approved: false
    })
    
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-not-found))
        (member (unwrap! (map-get? dao-membership tx-sender) err-unauthorized))
        (current-block stacks-block-height)
        (voting-power (get voting-power member)))
    
    (asserts! (< current-block (get end-block proposal)) err-voting-ended)
    (asserts! (is-none (map-get? member-votes { proposal-id: proposal-id, voter: tx-sender })) err-already-voted)
    
    (map-set member-votes 
      { proposal-id: proposal-id, voter: tx-sender }
      { vote: vote-for, amount: voting-power })
    
    (if vote-for
      (map-set proposals proposal-id (merge proposal { 
        votes-for: (+ (get votes-for proposal) voting-power) 
      }))
      (map-set proposals proposal-id (merge proposal { 
        votes-against: (+ (get votes-against proposal) voting-power) 
      }))
    )
    
    (ok true)
  )
)

(define-public (finalize-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-not-found))
        (current-block stacks-block-height)
        (total-votes (+ (get votes-for proposal) (get votes-against proposal))))
    
    (asserts! (>= current-block (get end-block proposal)) err-voting-active)
    (asserts! (not (get executed proposal)) err-already-executed)
    (asserts! (>= total-votes min-votes-required) err-insufficient-funds)
    
    (let ((approved (> (get votes-for proposal) (get votes-against proposal))))
      (map-set proposals proposal-id (merge proposal { 
        approved: approved,
        executed: true 
      }))
      
      (if approved
        (begin
          (try! (as-contract (stx-transfer? (get amount proposal) tx-sender (get recipient proposal))))
          (var-set total-treasury (- (var-get total-treasury) (get amount proposal)))
          (ok { approved: true, executed: true })
        )
        (ok { approved: false, executed: true })
      )
    )
  )
)

(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= amount (var-get total-treasury)) err-insufficient-funds)
    (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
    (var-set total-treasury (- (var-get total-treasury) amount))
    (ok true)
  )
)

;; read only functions
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-member-info (member principal))
  (map-get? dao-membership member)
)

(define-read-only (get-member-vote (proposal-id uint) (voter principal))
  (map-get? member-votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-treasury-balance)
  (var-get total-treasury)
)

(define-read-only (get-dao-stats)
  {
    total-members: (var-get dao-members),
    treasury-balance: (var-get total-treasury),
    next-proposal-id: (var-get next-proposal-id)
  }
)

(define-read-only (get-proposal-status (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (let ((current-block stacks-block-height)
                   (total-votes (+ (get votes-for proposal) (get votes-against proposal))))
      (some {
        active: (< current-block (get end-block proposal)),
        can-finalize: (and (>= current-block (get end-block proposal)) (not (get executed proposal))),
        total-votes: total-votes,
        participation-rate: (if (> (var-get dao-members) u0) 
                              (/ (* total-votes u100) (var-get dao-members)) 
                              u0)
      }))
    none
  )
)

(define-read-only (get-member-contributions (member principal))
  (default-to u0 (map-get? member-contributions member))
)

(define-read-only (is-member (address principal))
  (is-some (map-get? dao-membership address))
)

(define-read-only (get-voting-power (member principal))
  (match (map-get? dao-membership member)
    member-data (get voting-power member-data)
    u0
  )
)

;; private functions
(define-private (calculate-voting-power (contribution uint))
  (+ u1 (/ contribution u1000000))
)
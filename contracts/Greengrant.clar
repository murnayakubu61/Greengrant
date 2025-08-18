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
(define-constant err-invalid-impact-score (err u111))
(define-constant err-report-not-found (err u112))
(define-constant err-already-reported (err u113))
(define-constant err-report-period-ended (err u114))
(define-constant err-not-project-recipient (err u115))
(define-constant err-invalid-verification-status (err u116))
(define-constant err-collaboration-not-found (err u117))
(define-constant err-already-in-collaboration (err u118))
(define-constant err-collaboration-full (err u119))
(define-constant err-cannot-collaborate-with-self (err u120))
(define-constant err-collaboration-not-open (err u121))
(define-constant err-insufficient-collaboration-votes (err u122))
(define-constant err-invalid-collaboration-status (err u123))

(define-constant min-proposal-amount u1000000)
(define-constant max-proposal-amount u100000000)
(define-constant voting-duration u1440)
(define-constant min-votes-required u3)
(define-constant impact-report-period u2016)
(define-constant max-impact-score u100)
(define-constant reputation-boost-threshold u80)
(define-constant max-collaboration-members u4)
(define-constant collaboration-synergy-bonus u20)
(define-constant min-collaboration-votes u2)

;; data vars
(define-data-var next-proposal-id uint u1)
(define-data-var total-treasury uint u0)
(define-data-var dao-members uint u0)
(define-data-var next-report-id uint u1)
(define-data-var next-collaboration-id uint u1)

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

(define-map project-impact-reports
  uint
  {
    proposal-id: uint,
    reporter: principal,
    impact-score: uint,
    verification-count: uint,
    verified-score: uint,
    report-block: uint,
    description: (string-ascii 500),
    metrics: (string-ascii 300),
    verified: bool
  }
)

(define-map impact-verifications
  { report-id: uint, verifier: principal }
  { verified: bool, score: uint, verification-block: uint }
)

(define-map member-reputation
  principal
  {
    total-proposals: uint,
    successful-proposals: uint,
    total-impact-score: uint,
    reputation-score: uint,
    verification-count: uint,
    last-updated: uint
  }
)

(define-map proposal-impact-tracking
  uint
  {
    has-report: bool,
    report-id: uint,
    final-impact-score: uint,
    report-deadline: uint,
    impact-verified: bool
  }
)

(define-map project-collaborations
  uint
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    member-count: uint,
    total-funding: uint,
    created-block: uint,
    status: (string-ascii 20),
    voting-ends: uint,
    synergy-multiplier: uint
  }
)

(define-map collaboration-members
  { collaboration-id: uint, member: principal }
  {
    proposal-id: uint,
    joined-block: uint,
    funding-amount: uint,
    confirmed: bool
  }
)

(define-map collaboration-votes
  { collaboration-id: uint, voter: principal }
  { approved: bool, vote-block: uint }
)

(define-map proposal-collaboration-status
  uint
  {
    seeking-collaboration: bool,
    collaboration-id: uint,
    category: (string-ascii 50),
    synergy-tags: (string-ascii 200)
  }
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
    
    (map-set proposal-impact-tracking proposal-id {
      has-report: false,
      report-id: u0,
      final-impact-score: u0,
      report-deadline: (+ current-block voting-duration impact-report-period),
      impact-verified: false
    })
    
    (match (map-get? member-reputation tx-sender)
      reputation (map-set member-reputation tx-sender (merge reputation {
        total-proposals: (+ (get total-proposals reputation) u1),
        last-updated: current-block
      }))
      (map-set member-reputation tx-sender {
        total-proposals: u1,
        successful-proposals: u0,
        total-impact-score: u0,
        reputation-score: u0,
        verification-count: u0,
        last-updated: current-block
      })
    )
    
    (map-set proposal-collaboration-status proposal-id {
      seeking-collaboration: false,
      collaboration-id: u0,
      category: "general",
      synergy-tags: ""
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

(define-public (submit-impact-report 
  (proposal-id uint)
  (impact-score uint)
  (description (string-ascii 500))
  (metrics (string-ascii 300)))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-not-found))
        (tracking (unwrap! (map-get? proposal-impact-tracking proposal-id) err-not-found))
        (report-id (var-get next-report-id))
        (current-block stacks-block-height))
    
    (asserts! (is-eq tx-sender (get recipient proposal)) err-not-project-recipient)
    (asserts! (and (get approved proposal) (get executed proposal)) err-proposal-not-approved)
    (asserts! (not (get has-report tracking)) err-already-reported)
    (asserts! (<= impact-score max-impact-score) err-invalid-impact-score)
    (asserts! (<= current-block (get report-deadline tracking)) err-report-period-ended)
    
    (map-set project-impact-reports report-id {
      proposal-id: proposal-id,
      reporter: tx-sender,
      impact-score: impact-score,
      verification-count: u0,
      verified-score: u0,
      report-block: current-block,
      description: description,
      metrics: metrics,
      verified: false
    })
    
    (map-set proposal-impact-tracking proposal-id (merge tracking {
      has-report: true,
      report-id: report-id
    }))
    
    (var-set next-report-id (+ report-id u1))
    (ok report-id)
  )
)

(define-public (verify-impact-report 
  (report-id uint)
  (verified bool)
  (score uint))
  (let ((report (unwrap! (map-get? project-impact-reports report-id) err-report-not-found))
        (member (unwrap! (map-get? dao-membership tx-sender) err-unauthorized))
        (current-block stacks-block-height))
    
    (asserts! (<= score max-impact-score) err-invalid-impact-score)
    (asserts! (is-none (map-get? impact-verifications { report-id: report-id, verifier: tx-sender })) err-already-reported)
    
    (map-set impact-verifications 
      { report-id: report-id, verifier: tx-sender }
      { verified: verified, score: score, verification-block: current-block })
    
    (let ((new-verification-count (+ (get verification-count report) u1))
          (new-verified-score (+ (get verified-score report) score)))
      
      (map-set project-impact-reports report-id (merge report {
        verification-count: new-verification-count,
        verified-score: new-verified-score,
        verified: (and verified (>= new-verification-count u3))
      }))
      
      (match (map-get? member-reputation tx-sender)
        reputation (map-set member-reputation tx-sender (merge reputation {
          verification-count: (+ (get verification-count reputation) u1),
          last-updated: current-block
        }))
        (map-set member-reputation tx-sender {
          total-proposals: u0,
          successful-proposals: u0,
          total-impact-score: u0,
          reputation-score: u0,
          verification-count: u1,
          last-updated: current-block
        })
      )
      
      (ok true)
    )
  )
)

(define-public (finalize-impact-assessment (report-id uint))
  (let ((report (unwrap! (map-get? project-impact-reports report-id) err-report-not-found))
        (proposal (unwrap! (map-get? proposals (get proposal-id report)) err-not-found))
        (tracking (unwrap! (map-get? proposal-impact-tracking (get proposal-id report)) err-not-found)))
    
    (asserts! (>= (get verification-count report) u3) err-insufficient-funds)
    (asserts! (not (get impact-verified tracking)) err-already-executed)
    
    (let ((avg-score (/ (get verified-score report) (get verification-count report)))
          (proposer (get proposer proposal)))
      
      (map-set proposal-impact-tracking (get proposal-id report) (merge tracking {
        final-impact-score: avg-score,
        impact-verified: true
      }))
      
      (match (map-get? member-reputation proposer)
        reputation (let ((new-reputation-score 
                          (calculate-reputation-score 
                            (+ (get successful-proposals reputation) u1)
                            (+ (get total-impact-score reputation) avg-score)
                            (+ (get total-proposals reputation) u1))))
          (map-set member-reputation proposer (merge reputation {
            successful-proposals: (+ (get successful-proposals reputation) u1),
            total-impact-score: (+ (get total-impact-score reputation) avg-score),
            reputation-score: new-reputation-score,
            last-updated: stacks-block-height
          })))
        (map-set member-reputation proposer {
          total-proposals: u1,
          successful-proposals: u1,
          total-impact-score: avg-score,
          reputation-score: avg-score,
          verification-count: u0,
          last-updated: stacks-block-height
        })
      )
      
      (if (>= avg-score reputation-boost-threshold)
        (match (map-get? dao-membership proposer)
          member (map-set dao-membership proposer (merge member {
            voting-power: (+ (get voting-power member) u2)
          }))
          true)
        true)
      
      (ok avg-score)
    )
  )
)

(define-public (enable-collaboration-seeking 
  (proposal-id uint)
  (category (string-ascii 50))
  (synergy-tags (string-ascii 200)))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-not-found))
        (status (unwrap! (map-get? proposal-collaboration-status proposal-id) err-not-found)))
    
    (asserts! (is-eq tx-sender (get proposer proposal)) err-unauthorized)
    (asserts! (not (get executed proposal)) err-already-executed)
    (asserts! (not (get seeking-collaboration status)) err-already-in-collaboration)
    
    (map-set proposal-collaboration-status proposal-id (merge status {
      seeking-collaboration: true,
      category: category,
      synergy-tags: synergy-tags
    }))
    
    (ok true)
  )
)

(define-public (create-collaboration 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (category (string-ascii 50))
  (initial-proposal-id uint))
  (let ((collaboration-id (var-get next-collaboration-id))
        (proposal (unwrap! (map-get? proposals initial-proposal-id) err-not-found))
        (status (unwrap! (map-get? proposal-collaboration-status initial-proposal-id) err-not-found))
        (current-block stacks-block-height))
    
    (asserts! (is-eq tx-sender (get proposer proposal)) err-unauthorized)
    (asserts! (get seeking-collaboration status) err-collaboration-not-open)
    (asserts! (and (get approved proposal) (get executed proposal)) err-proposal-not-approved)
    
    (map-set project-collaborations collaboration-id {
      creator: tx-sender,
      title: title,
      description: description,
      category: category,
      member-count: u1,
      total-funding: (get amount proposal),
      created-block: current-block,
      status: "open",
      voting-ends: (+ current-block voting-duration),
      synergy-multiplier: u100
    })
    
    (map-set collaboration-members 
      { collaboration-id: collaboration-id, member: tx-sender }
      {
        proposal-id: initial-proposal-id,
        joined-block: current-block,
        funding-amount: (get amount proposal),
        confirmed: true
      })
    
    (map-set proposal-collaboration-status initial-proposal-id (merge status {
      collaboration-id: collaboration-id
    }))
    
    (var-set next-collaboration-id (+ collaboration-id u1))
    (ok collaboration-id)
  )
)

(define-public (join-collaboration 
  (collaboration-id uint)
  (proposal-id uint))
  (let ((collaboration (unwrap! (map-get? project-collaborations collaboration-id) err-collaboration-not-found))
        (proposal (unwrap! (map-get? proposals proposal-id) err-not-found))
        (status (unwrap! (map-get? proposal-collaboration-status proposal-id) err-not-found))
        (current-block stacks-block-height))
    
    (asserts! (is-eq tx-sender (get proposer proposal)) err-unauthorized)
    (asserts! (get seeking-collaboration status) err-collaboration-not-open)
    (asserts! (and (get approved proposal) (get executed proposal)) err-proposal-not-approved)
    (asserts! (is-eq (get status collaboration) "open") err-collaboration-not-open)
    (asserts! (< (get member-count collaboration) max-collaboration-members) err-collaboration-full)
    (asserts! (not (is-eq (get proposer proposal) (get creator collaboration))) err-cannot-collaborate-with-self)
    (asserts! (is-none (map-get? collaboration-members { collaboration-id: collaboration-id, member: tx-sender })) err-already-in-collaboration)
    
    (map-set collaboration-members 
      { collaboration-id: collaboration-id, member: tx-sender }
      {
        proposal-id: proposal-id,
        joined-block: current-block,
        funding-amount: (get amount proposal),
        confirmed: false
      })
    
    (map-set project-collaborations collaboration-id (merge collaboration {
      member-count: (+ (get member-count collaboration) u1),
      total-funding: (+ (get total-funding collaboration) (get amount proposal))
    }))
    
    (map-set proposal-collaboration-status proposal-id (merge status {
      collaboration-id: collaboration-id
    }))
    
    (ok true)
  )
)

(define-public (vote-on-collaboration 
  (collaboration-id uint)
  (approved bool))
  (let ((collaboration (unwrap! (map-get? project-collaborations collaboration-id) err-collaboration-not-found))
        (member (unwrap! (map-get? dao-membership tx-sender) err-unauthorized))
        (current-block stacks-block-height))
    
    (asserts! (is-eq (get status collaboration) "open") err-collaboration-not-open)
    (asserts! (< current-block (get voting-ends collaboration)) err-voting-ended)
    (asserts! (is-none (map-get? collaboration-votes { collaboration-id: collaboration-id, voter: tx-sender })) err-already-voted)
    
    (map-set collaboration-votes 
      { collaboration-id: collaboration-id, voter: tx-sender }
      { approved: approved, vote-block: current-block })
    
    (ok true)
  )
)

(define-public (finalize-collaboration (collaboration-id uint))
  (let ((collaboration (unwrap! (map-get? project-collaborations collaboration-id) err-collaboration-not-found))
        (current-block stacks-block-height))
    
    (asserts! (>= current-block (get voting-ends collaboration)) err-voting-active)
    (asserts! (is-eq (get status collaboration) "open") err-collaboration-not-open)
    (asserts! (>= (get member-count collaboration) min-collaboration-votes) err-insufficient-collaboration-votes)
    
    (let ((synergy-multiplier (calculate-synergy-multiplier (get member-count collaboration))))
      (map-set project-collaborations collaboration-id (merge collaboration {
        status: "active",
        synergy-multiplier: synergy-multiplier
      }))
      
      (ok synergy-multiplier)
    )
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

(define-read-only (get-impact-report (report-id uint))
  (map-get? project-impact-reports report-id)
)

(define-read-only (get-member-reputation (member principal))
  (map-get? member-reputation member)
)

(define-read-only (get-proposal-impact-tracking (proposal-id uint))
  (map-get? proposal-impact-tracking proposal-id)
)

(define-read-only (get-impact-verification (report-id uint) (verifier principal))
  (map-get? impact-verifications { report-id: report-id, verifier: verifier })
)

(define-read-only (get-reputation-leaderboard)
  {
    total-verified-reports: (var-get next-report-id),
    average-reputation: (calculate-average-reputation)
  }
)

(define-read-only (get-collaboration (collaboration-id uint))
  (map-get? project-collaborations collaboration-id)
)

(define-read-only (get-collaboration-member (collaboration-id uint) (member principal))
  (map-get? collaboration-members { collaboration-id: collaboration-id, member: member })
)

(define-read-only (get-collaboration-vote (collaboration-id uint) (voter principal))
  (map-get? collaboration-votes { collaboration-id: collaboration-id, voter: voter })
)

(define-read-only (get-proposal-collaboration-status (proposal-id uint))
  (map-get? proposal-collaboration-status proposal-id)
)

(define-read-only (get-collaboration-stats)
  {
    total-collaborations: (var-get next-collaboration-id),
    active-collaborations: (count-active-collaborations)
  }
)

;; private functions
(define-private (calculate-voting-power (contribution uint))
  (+ u1 (/ contribution u1000000))
)

(define-private (calculate-reputation-score 
  (successful-proposals uint)
  (total-impact-score uint)
  (total-proposals uint))
  (if (> total-proposals u0)
    (let ((success-rate (/ (* successful-proposals u100) total-proposals))
          (avg-impact (/ total-impact-score total-proposals)))
      (/ (+ (* success-rate u60) (* avg-impact u40)) u100))
    u0)
)

(define-private (calculate-average-reputation)
  (let ((member-count (var-get dao-members)))
    (if (> member-count u0)
      (/ u5000 member-count)
      u0))
)

(define-private (calculate-synergy-multiplier (member-count uint))
  (if (>= member-count u4)
    (+ u100 (* collaboration-synergy-bonus u2))
    (if (>= member-count u3)
      (+ u100 collaboration-synergy-bonus)
      (if (>= member-count u2)
        (+ u100 (/ collaboration-synergy-bonus u2))
        u100)))
)

(define-private (count-active-collaborations)
  (/ (var-get next-collaboration-id) u2)
)




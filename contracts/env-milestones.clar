;; title: Environmental Milestones
;; version: 1.0.0
;; summary: Track community-wide environmental goals and milestones
;; description: Enables the DAO to set long-term environmental targets and track collective progress

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-unauthorized (err u202))
(define-constant err-invalid-amount (err u203))
(define-constant err-milestone-closed (err u204))
(define-constant err-milestone-completed (err u205))
(define-constant err-invalid-target (err u206))
(define-constant err-already-contributed (err u207))
(define-constant err-insufficient-threshold (err u208))
(define-constant err-milestone-active (err u209))

(define-constant min-milestone-target u1)
(define-constant max-milestone-target u1000000)
(define-constant milestone-duration u4320) ;; ~30 days
(define-constant completion-threshold u90) ;; 90% completion required
(define-constant reward-pool-percentage u5) ;; 5% of milestone value

;; data vars
(define-data-var next-milestone-id uint u1)
(define-data-var total-milestone-rewards uint u0)

;; data maps
(define-map environmental-milestones
  uint
  {
    creator: principal,
    title: (string-ascii 80),
    description: (string-ascii 400),
    category: (string-ascii 30),
    target-value: uint,
    unit: (string-ascii 20),
    current-progress: uint,
    start-block: uint,
    end-block: uint,
    status: (string-ascii 15),
    reward-pool: uint,
    contributors-count: uint,
    completion-percentage: uint
  }
)

(define-map milestone-contributions
  { milestone-id: uint, contributor: principal }
  {
    amount-contributed: uint,
    contribution-block: uint,
    evidence: (string-ascii 200),
    verified: bool
  }
)

(define-map milestone-verifications
  { milestone-id: uint, verifier: principal }
  {
    verified-progress: uint,
    verification-block: uint,
    notes: (string-ascii 150)
  }
)

(define-map contributor-achievements
  principal
  {
    milestones-completed: uint,
    total-environmental-contribution: uint,
    achievement-score: uint,
    last-activity: uint
  }
)

;; public functions
(define-public (create-milestone
  (title (string-ascii 80))
  (description (string-ascii 400))
  (category (string-ascii 30))
  (target-value uint)
  (unit (string-ascii 20))
  (reward-amount uint))
  (let ((milestone-id (var-get next-milestone-id))
        (current-block stacks-block-height))
    
    (asserts! (>= target-value min-milestone-target) err-invalid-target)
    (asserts! (<= target-value max-milestone-target) err-invalid-target)
    (asserts! (> reward-amount u0) err-invalid-amount)
    
    ;; Transfer reward to contract
    (try! (stx-transfer? reward-amount tx-sender (as-contract tx-sender)))
    
    (map-set environmental-milestones milestone-id {
      creator: tx-sender,
      title: title,
      description: description,
      category: category,
      target-value: target-value,
      unit: unit,
      current-progress: u0,
      start-block: current-block,
      end-block: (+ current-block milestone-duration),
      status: "active",
      reward-pool: reward-amount,
      contributors-count: u0,
      completion-percentage: u0
    })
    
    (var-set total-milestone-rewards (+ (var-get total-milestone-rewards) reward-amount))
    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

(define-public (contribute-to-milestone
  (milestone-id uint)
  (contribution-amount uint)
  (evidence (string-ascii 200)))
  (let ((milestone (unwrap! (map-get? environmental-milestones milestone-id) err-not-found))
        (current-block stacks-block-height))
    
    (asserts! (is-eq (get status milestone) "active") err-milestone-closed)
    (asserts! (< current-block (get end-block milestone)) err-milestone-closed)
    (asserts! (> contribution-amount u0) err-invalid-amount)
    (asserts! (is-none (map-get? milestone-contributions { milestone-id: milestone-id, contributor: tx-sender })) err-already-contributed)
    
    (map-set milestone-contributions 
      { milestone-id: milestone-id, contributor: tx-sender }
      {
        amount-contributed: contribution-amount,
        contribution-block: current-block,
        evidence: evidence,
        verified: false
      })
    
    (let ((new-progress (+ (get current-progress milestone) contribution-amount))
          (new-percentage (/ (* new-progress u100) (get target-value milestone))))
      
      (map-set environmental-milestones milestone-id (merge milestone {
        current-progress: new-progress,
        contributors-count: (+ (get contributors-count milestone) u1),
        completion-percentage: new-percentage
      }))
      
      (update-contributor-achievements tx-sender contribution-amount)
      (ok new-progress)
    )
  )
)

(define-public (verify-contribution
  (milestone-id uint)
  (contributor principal)
  (verified-amount uint))
  (let ((milestone (unwrap! (map-get? environmental-milestones milestone-id) err-not-found))
        (contribution (unwrap! (map-get? milestone-contributions { milestone-id: milestone-id, contributor: contributor }) err-not-found))
        (current-block stacks-block-height))
    
    (asserts! (not (get verified contribution)) err-already-contributed)
    (asserts! (<= verified-amount (get amount-contributed contribution)) err-invalid-amount)
    
    (map-set milestone-contributions 
      { milestone-id: milestone-id, contributor: contributor }
      (merge contribution { verified: true }))
    
    (map-set milestone-verifications
      { milestone-id: milestone-id, verifier: tx-sender }
      {
        verified-progress: verified-amount,
        verification-block: current-block,
        notes: "Contribution verified"
      })
    
    (ok true)
  )
)

(define-public (complete-milestone (milestone-id uint))
  (let ((milestone (unwrap! (map-get? environmental-milestones milestone-id) err-not-found)))
    
    (asserts! (is-eq (get status milestone) "active") err-milestone-closed)
    (asserts! (>= (get completion-percentage milestone) completion-threshold) err-insufficient-threshold)
    
    (map-set environmental-milestones milestone-id (merge milestone {
      status: "completed"
    }))
    
    ;; Distribute rewards to contributors
    (try! (distribute-milestone-rewards milestone-id))
    (ok true)
  )
)

(define-public (extend-milestone (milestone-id uint) (additional-blocks uint))
  (let ((milestone (unwrap! (map-get? environmental-milestones milestone-id) err-not-found)))
    
    (asserts! (is-eq tx-sender (get creator milestone)) err-unauthorized)
    (asserts! (is-eq (get status milestone) "active") err-milestone-closed)
    
    (map-set environmental-milestones milestone-id (merge milestone {
      end-block: (+ (get end-block milestone) additional-blocks)
    }))
    
    (ok (get end-block (unwrap! (map-get? environmental-milestones milestone-id) err-not-found)))
  )
)

;; read-only functions
(define-read-only (get-milestone (milestone-id uint))
  (map-get? environmental-milestones milestone-id)
)

(define-read-only (get-milestone-contribution (milestone-id uint) (contributor principal))
  (map-get? milestone-contributions { milestone-id: milestone-id, contributor: contributor })
)

(define-read-only (get-contributor-achievements (contributor principal))
  (map-get? contributor-achievements contributor)
)

(define-read-only (get-milestone-stats)
  {
    total-milestones: (var-get next-milestone-id),
    total-rewards-pool: (var-get total-milestone-rewards),
    active-milestones: (count-active-milestones)
  }
)

(define-read-only (get-milestone-progress (milestone-id uint))
  (match (map-get? environmental-milestones milestone-id)
    milestone (some {
      progress-percentage: (get completion-percentage milestone),
      current-value: (get current-progress milestone),
      target-value: (get target-value milestone),
      time-remaining: (if (> (get end-block milestone) stacks-block-height)
                        (- (get end-block milestone) stacks-block-height)
                        u0),
      is-achievable: (>= (get completion-percentage milestone) completion-threshold)
    })
    none
  )
)

;; private functions
(define-private (distribute-milestone-rewards (milestone-id uint))
  (let ((milestone (unwrap! (map-get? environmental-milestones milestone-id) err-not-found))
        (reward-per-contributor (/ (get reward-pool milestone) (get contributors-count milestone))))
    
    (if (> reward-per-contributor u0)
      (as-contract (stx-transfer? reward-per-contributor tx-sender (get creator milestone)))
      (ok true))
  )
)

(define-private (update-contributor-achievements (contributor principal) (contribution uint))
  (match (map-get? contributor-achievements contributor)
    achievements (map-set contributor-achievements contributor (merge achievements {
      total-environmental-contribution: (+ (get total-environmental-contribution achievements) contribution),
      achievement-score: (calculate-achievement-score 
                           (+ (get total-environmental-contribution achievements) contribution)
                           (get milestones-completed achievements)),
      last-activity: stacks-block-height
    }))
    (map-set contributor-achievements contributor {
      milestones-completed: u0,
      total-environmental-contribution: contribution,
      achievement-score: contribution,
      last-activity: stacks-block-height
    })
  )
)

(define-private (calculate-achievement-score (total-contribution uint) (completed-milestones uint))
  (+ total-contribution (* completed-milestones u50))
)

(define-private (count-active-milestones)
  (/ (var-get next-milestone-id) u2)
)

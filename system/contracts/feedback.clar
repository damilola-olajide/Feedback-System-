;; Feedback System Smart Contract
;; A comprehensive system for managing user feedback and ratings

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_RATING (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INVALID_INPUT (err u104))
(define-constant ERR_PERMISSION_DENIED (err u105))

;; Data Variables
(define-data-var next-feedback-id uint u1)
(define-data-var total-feedbacks uint u0)

;; Data Maps
(define-map feedbacks
  { feedback-id: uint }
  {
    author: principal,
    target-id: (string-ascii 64),
    rating: uint,
    comment: (string-utf8 500),
    timestamp: uint,
    is-active: bool
  }
)

(define-map user-feedback-count
  { user: principal }
  { count: uint }
)

(define-map target-ratings
  { target-id: (string-ascii 64) }
  {
    total-rating: uint,
    feedback-count: uint,
    average-rating: uint
  }
)

(define-map admins
  { admin: principal }
  { is-admin: bool }
)

;; Initialize contract owner as admin
(map-set admins { admin: CONTRACT_OWNER } { is-admin: true })

;; Private Functions
(define-private (is-admin (user principal))
  (default-to false (get is-admin (map-get? admins { admin: user })))
)

(define-private (is-valid-rating (rating uint))
  (and (>= rating u1) (<= rating u5))
)

;; Added input validation for feedback-id to prevent unchecked data usage
(define-private (is-valid-feedback-id (feedback-id uint))
  (and (>= feedback-id u1) (< feedback-id (var-get next-feedback-id)))
)

;; Added input validation for principal to ensure it's not null
(define-private (is-valid-principal (user principal))
  (not (is-eq user 'SP000000000000000000002Q6VF78))
)

(define-private (update-target-rating (target-id (string-ascii 64)) (new-rating uint))
  (let (
    (current-data (default-to 
      { total-rating: u0, feedback-count: u0, average-rating: u0 }
      (map-get? target-ratings { target-id: target-id })
    ))
    (new-total (+ (get total-rating current-data) new-rating))
    (new-count (+ (get feedback-count current-data) u1))
    (new-average (/ new-total new-count))
  )
    (map-set target-ratings 
      { target-id: target-id }
      {
        total-rating: new-total,
        feedback-count: new-count,
        average-rating: new-average
      }
    )
  )
)

(define-private (remove-from-target-rating (target-id (string-ascii 64)) (old-rating uint))
  (let (
    (current-data (unwrap-panic (map-get? target-ratings { target-id: target-id })))
    (new-total (- (get total-rating current-data) old-rating))
    (new-count (- (get feedback-count current-data) u1))
    (new-average (if (> new-count u0) (/ new-total new-count) u0))
  )
    (if (> new-count u0)
      (map-set target-ratings 
        { target-id: target-id }
        {
          total-rating: new-total,
          feedback-count: new-count,
          average-rating: new-average
        }
      )
      (map-delete target-ratings { target-id: target-id })
    )
  )
)

;; Public Functions

;; Submit new feedback
(define-public (submit-feedback (target-id (string-ascii 64)) (rating uint) (comment (string-utf8 500)))
  (let (
    (feedback-id (var-get next-feedback-id))
    (current-user-count (default-to u0 (get count (map-get? user-feedback-count { user: tx-sender }))))
    ;; Added local validation variables to check inputs before using them
    (validated-rating (begin (asserts! (is-valid-rating rating) ERR_INVALID_RATING) rating))
  )
    (asserts! (> (len target-id) u0) ERR_INVALID_INPUT)
    (asserts! (> (len comment) u0) ERR_INVALID_INPUT)
    
    ;; Store feedback using validated rating
    (map-set feedbacks
      { feedback-id: feedback-id }
      {
        author: tx-sender,
        target-id: target-id,
        rating: validated-rating,
        comment: comment,
        timestamp: block-height,
        is-active: true
      }
    )
    
    ;; Update counters
    (var-set next-feedback-id (+ feedback-id u1))
    (var-set total-feedbacks (+ (var-get total-feedbacks) u1))
    (map-set user-feedback-count 
      { user: tx-sender } 
      { count: (+ current-user-count u1) }
    )
    
    ;; Update target rating with validated rating
    (update-target-rating target-id validated-rating)
    
    (ok feedback-id)
  )
)

;; Get feedback by ID
(define-read-only (get-feedback (feedback-id uint))
  (map-get? feedbacks { feedback-id: feedback-id })
)

;; Get target rating summary
(define-read-only (get-target-rating (target-id (string-ascii 64)))
  (map-get? target-ratings { target-id: target-id })
)

;; Update feedback (only by author)
(define-public (update-feedback (feedback-id uint) (new-rating uint) (new-comment (string-utf8 500)))
  (let (
    ;; Added validation for feedback-id before using it
    (validated-feedback-id (begin (asserts! (is-valid-feedback-id feedback-id) ERR_INVALID_INPUT) feedback-id))
    (validated-new-rating (begin (asserts! (is-valid-rating new-rating) ERR_INVALID_RATING) new-rating))
    (feedback-data (unwrap! (map-get? feedbacks { feedback-id: validated-feedback-id }) ERR_NOT_FOUND))
  )
    (asserts! (is-eq (get author feedback-data) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (get is-active feedback-data) ERR_NOT_FOUND)
    (asserts! (> (len new-comment) u0) ERR_INVALID_INPUT)
    
    ;; Update target rating (remove old, add new)
    (remove-from-target-rating (get target-id feedback-data) (get rating feedback-data))
    (update-target-rating (get target-id feedback-data) validated-new-rating)
    
    ;; Update feedback using validated inputs
    (map-set feedbacks
      { feedback-id: validated-feedback-id }
      (merge feedback-data {
        rating: validated-new-rating,
        comment: new-comment,
        timestamp: block-height
      })
    )
    
    (ok true)
  )
)

;; Delete feedback (by author or admin)
(define-public (delete-feedback (feedback-id uint))
  (let (
    ;; Added validation for feedback-id before using it
    (validated-feedback-id (begin (asserts! (is-valid-feedback-id feedback-id) ERR_INVALID_INPUT) feedback-id))
    (feedback-data (unwrap! (map-get? feedbacks { feedback-id: validated-feedback-id }) ERR_NOT_FOUND))
    (is-author (is-eq (get author feedback-data) tx-sender))
    (is-admin-user (is-admin tx-sender))
  )
    (asserts! (or is-author is-admin-user) ERR_UNAUTHORIZED)
    (asserts! (get is-active feedback-data) ERR_NOT_FOUND)
    
    ;; Remove from target rating
    (remove-from-target-rating (get target-id feedback-data) (get rating feedback-data))
    
    ;; Mark as inactive instead of deleting using validated feedback-id
    (map-set feedbacks
      { feedback-id: validated-feedback-id }
      (merge feedback-data { is-active: false })
    )
    
    ;; Update counters
    (var-set total-feedbacks (- (var-get total-feedbacks) u1))
    
    (ok true)
  )
)

;; Add admin (only by contract owner)
(define-public (add-admin (new-admin principal))
  (let (
    ;; Added validation for principal before using it
    (validated-admin (begin (asserts! (is-valid-principal new-admin) ERR_INVALID_INPUT) new-admin))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set admins { admin: validated-admin } { is-admin: true })
    (ok true)
  )
)

;; Remove admin (only by contract owner)
(define-public (remove-admin (admin-to-remove principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal admin-to-remove) ERR_INVALID_INPUT)
    (asserts! (not (is-eq admin-to-remove CONTRACT_OWNER)) ERR_PERMISSION_DENIED)
    (map-delete admins { admin: admin-to-remove })
    (ok true)
  )
)

;; Get user feedback count
(define-read-only (get-user-feedback-count (user principal))
  (default-to u0 (get count (map-get? user-feedback-count { user: user })))
)

;; Get total feedbacks count
(define-read-only (get-total-feedbacks)
  (var-get total-feedbacks)
)

;; Check if user is admin
(define-read-only (check-admin (user principal))
  (is-admin user)
)

;; Get contract stats
(define-read-only (get-contract-stats)
  {
    total-feedbacks: (var-get total-feedbacks),
    next-feedback-id: (var-get next-feedback-id),
    contract-owner: CONTRACT_OWNER
  }
)

;; Batch get feedbacks (get multiple feedback entries)
(define-read-only (get-feedbacks-batch (feedback-ids (list 20 uint)))
  (map get-feedback feedback-ids)
)

;; Customer Feedback Contract
;; Collects and manages customer feedback for cleaning services

(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_FEEDBACK_EXISTS (err u401))
(define-constant ERR_FEEDBACK_NOT_FOUND (err u402))
(define-constant ERR_INVALID_RATING (err u403))

;; Data structures
(define-map customer-feedback
  { feedback-id: uint }
  {
    customer-id: principal,
    provider-id: principal,
    service-type: (string-ascii 50),
    rating: uint,
    comment: (string-ascii 500),
    service-date: uint,
    feedback-date: uint,
    verified: bool
  }
)

(define-map feedback-categories
  { feedback-id: uint, category: (string-ascii 50) }
  { rating: uint, comment: (string-ascii 200) }
)

(define-data-var next-feedback-id uint u1)

;; Submit customer feedback
(define-public (submit-feedback (provider-id principal)
                               (service-type (string-ascii 50))
                               (rating uint)
                               (comment (string-ascii 500))
                               (service-date uint))
  (let ((feedback-id (var-get next-feedback-id)))
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (map-set customer-feedback
      { feedback-id: feedback-id }
      {
        customer-id: tx-sender,
        provider-id: provider-id,
        service-type: service-type,
        rating: rating,
        comment: comment,
        service-date: service-date,
        feedback-date: block-height,
        verified: false
      }
    )
    (var-set next-feedback-id (+ feedback-id u1))
    (ok feedback-id)
  )
)

;; Add category-specific feedback
(define-public (add-category-feedback (feedback-id uint)
                                     (category (string-ascii 50))
                                     (rating uint)
                                     (comment (string-ascii 200)))
  (match (map-get? customer-feedback { feedback-id: feedback-id })
    feedback-data
    (begin
      (asserts! (is-eq tx-sender (get customer-id feedback-data)) ERR_UNAUTHORIZED)
      (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
      (map-set feedback-categories
        { feedback-id: feedback-id, category: category }
        { rating: rating, comment: comment }
      )
      (ok true)
    )
    ERR_FEEDBACK_NOT_FOUND
  )
)

;; Verify feedback (admin only)
(define-public (verify-feedback (feedback-id uint))
  (match (map-get? customer-feedback { feedback-id: feedback-id })
    feedback-data
    (begin
      (map-set customer-feedback
        { feedback-id: feedback-id }
        (merge feedback-data { verified: true })
      )
      (ok true)
    )
    ERR_FEEDBACK_NOT_FOUND
  )
)

;; Get feedback details
(define-read-only (get-feedback (feedback-id uint))
  (map-get? customer-feedback { feedback-id: feedback-id })
)

;; Get category feedback
(define-read-only (get-category-feedback (feedback-id uint) (category (string-ascii 50)))
  (map-get? feedback-categories { feedback-id: feedback-id, category: category })
)

;; Calculate average rating for provider
(define-read-only (get-provider-rating (provider-id principal))
  ;; This is a simplified version - in practice, you'd need to iterate through all feedback
  ;; For now, returning a placeholder
  (some u4)
)

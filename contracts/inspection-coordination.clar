;; Inspection Coordination Contract
;; Manages quality inspections and scheduling

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INSPECTION_EXISTS (err u301))
(define-constant ERR_INSPECTION_NOT_FOUND (err u302))
(define-constant ERR_INVALID_STATUS (err u303))
(define-constant ERR_PROVIDER_NOT_VERIFIED (err u304))

;; Inspection status constants
(define-constant STATUS_SCHEDULED u0)
(define-constant STATUS_IN_PROGRESS u1)
(define-constant STATUS_COMPLETED u2)
(define-constant STATUS_CANCELLED u3)

;; Data structures
(define-map inspections
  { inspection-id: uint }
  {
    provider-id: principal,
    inspector-id: principal,
    service-type: (string-ascii 50),
    scheduled-date: uint,
    actual-date: (optional uint),
    status: uint,
    location: (string-ascii 200),
    notes: (string-ascii 500),
    created-date: uint
  }
)

(define-map inspection-results
  { inspection-id: uint, standard-id: (string-ascii 50) }
  { score: uint, notes: (string-ascii 300) }
)

(define-map inspectors
  { inspector-id: principal }
  {
    name: (string-ascii 100),
    certified: bool,
    specializations: (list 10 (string-ascii 50)),
    active: bool
  }
)

(define-data-var next-inspection-id uint u1)

;; Register an inspector
(define-public (register-inspector (inspector-id principal)
                                  (name (string-ascii 100))
                                  (specializations (list 10 (string-ascii 50))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set inspectors
      { inspector-id: inspector-id }
      {
        name: name,
        certified: true,
        specializations: specializations,
        active: true
      }
    )
    (ok inspector-id)
  )
)

;; Schedule an inspection
(define-public (schedule-inspection (provider-id principal)
                                   (inspector-id principal)
                                   (service-type (string-ascii 50))
                                   (scheduled-date uint)
                                   (location (string-ascii 200)))
  (let ((inspection-id (var-get next-inspection-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set inspections
      { inspection-id: inspection-id }
      {
        provider-id: provider-id,
        inspector-id: inspector-id,
        service-type: service-type,
        scheduled-date: scheduled-date,
        actual-date: none,
        status: STATUS_SCHEDULED,
        location: location,
        notes: "",
        created-date: block-height
      }
    )
    (var-set next-inspection-id (+ inspection-id u1))
    (ok inspection-id)
  )
)

;; Start inspection
(define-public (start-inspection (inspection-id uint))
  (match (map-get? inspections { inspection-id: inspection-id })
    inspection-data
    (begin
      (asserts! (or (is-eq tx-sender (get inspector-id inspection-data))
                    (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status inspection-data) STATUS_SCHEDULED) ERR_INVALID_STATUS)
      (map-set inspections
        { inspection-id: inspection-id }
        (merge inspection-data {
          status: STATUS_IN_PROGRESS,
          actual-date: (some block-height)
        })
      )
      (ok true)
    )
    ERR_INSPECTION_NOT_FOUND
  )
)

;; Complete inspection with results
(define-public (complete-inspection (inspection-id uint) (notes (string-ascii 500)))
  (match (map-get? inspections { inspection-id: inspection-id })
    inspection-data
    (begin
      (asserts! (or (is-eq tx-sender (get inspector-id inspection-data))
                    (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status inspection-data) STATUS_IN_PROGRESS) ERR_INVALID_STATUS)
      (map-set inspections
        { inspection-id: inspection-id }
        (merge inspection-data {
          status: STATUS_COMPLETED,
          notes: notes
        })
      )
      (ok true)
    )
    ERR_INSPECTION_NOT_FOUND
  )
)

;; Add inspection result for a standard
(define-public (add-inspection-result (inspection-id uint)
                                     (standard-id (string-ascii 50))
                                     (score uint)
                                     (notes (string-ascii 300)))
  (match (map-get? inspections { inspection-id: inspection-id })
    inspection-data
    (begin
      (asserts! (or (is-eq tx-sender (get inspector-id inspection-data))
                    (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
      (map-set inspection-results
        { inspection-id: inspection-id, standard-id: standard-id }
        { score: score, notes: notes }
      )
      (ok true)
    )
    ERR_INSPECTION_NOT_FOUND
  )
)

;; Get inspection details
(define-read-only (get-inspection (inspection-id uint))
  (map-get? inspections { inspection-id: inspection-id })
)

;; Get inspection result
(define-read-only (get-inspection-result (inspection-id uint) (standard-id (string-ascii 50)))
  (map-get? inspection-results { inspection-id: inspection-id, standard-id: standard-id })
)

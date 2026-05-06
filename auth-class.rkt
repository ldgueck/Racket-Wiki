#lang racket

(require web-server/http) ;; Fixes 'request-cookies' and 'make-cookie'

(provide auth%) ;; Allows wiki.rkt to see this class

(define auth%
  (class object%
    (super-new)
    ;; We remove the global 'config' check and just require the password to be passed in
    (init-field password) 
    (field[session-token (number->string (random 1000000000))])
    
    (define/public (check-password? attempt) (equal? attempt password))
    
    (define/public (is-authorized? req)
      (let ([cookies (request-cookies req)])
        (let ([my-cookie (findf (lambda (c) (equal? (client-cookie-name c) "wiki-session")) cookies)])
          (and my-cookie (equal? (client-cookie-value my-cookie) session-token)))))
          
    (define/public (make-auth-cookie) 
      (make-cookie "wiki-session" session-token #:path "/"))
      
    (define/public (make-logout-cookie) 
      (make-cookie "wiki-session" "expired" #:path "/" #:expires "Thu, 01 Jan 1970 00:00:00 GMT"))))
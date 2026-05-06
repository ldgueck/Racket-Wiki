#lang racket

(require racket/date
         xml
         (except-in markdown xexpr->string)) ;; Bring in the required libraries

(provide wiki%) ;; Export the class

(define wiki%
  (class object%
    (super-new)
    ;; Accept the paths from wiki.rkt instead of relying on globals
    (init-field path
                history-path
                images-path)
    
    (field[lock (make-semaphore 1)])
    (field [pages (if (file-exists? path)
                      (let ([data (with-input-from-file path read)]) (if (list? data) (make-hash data) (make-hash)))
                      (make-hash (list (cons "HomePage" "# Welcome"))))])

    (define/private (get-safe-filename name) (regexp-replace* #px"[^a-zA-Z0-9]" name "_"))

    (define/public (archive-version! name)
      (let ([current-text (hash-ref pages name #f)])
        (when (and current-text (not (equal? current-text "")))
          (let* ([d (current-date)][ts (format "~a-~a-~a_~a-~a-~a" (date-year d) (date-month d) (date-day d) (date-hour d) (date-minute d) (date-second d))][filename (format "~a_~a.txt" (get-safe-filename name) ts)])
            (with-output-to-file (build-path history-path filename) #:exists 'replace (lambda () (display current-text)))))))

    (define/public (save!)
      (define temp (string-append (path->string path) ".tmp"))
      (with-output-to-file temp #:exists 'replace (lambda () (write (hash->list pages))))
      (rename-file-or-directory temp path #t))

    (define/public (get-text name) (call-with-semaphore lock (lambda () (hash-ref pages name ""))))
    (define/public (set-text! name txt) (call-with-semaphore lock (lambda () (archive-version! name) (hash-set! pages name txt) (save!))))
    (define/public (delete-page! name) (call-with-semaphore lock (lambda () (hash-remove! pages name) (save!))))
    (define/public (get-all-names) (sort (hash-keys pages) string<?))

    (define/public (delete-image! filename) (let ([p (build-path images-path filename)]) (when (file-exists? p) (delete-file p))))
    (define/public (get-used-images)
      (let ([all-text (apply string-append (hash-values pages))])
        (let ([matches (regexp-match* #px"/images/([^\\s\\)\\]\"]+)" all-text #:match-select values)])
          (if matches (remove-duplicates (map second matches)) '()))))

    (define/public (rename-page! old-n new-n)
      (call-with-semaphore lock
        (lambda ()
          (let ([content (hash-ref pages old-n #f)])
            (if (and content (not (hash-has-key? pages new-n)))
                (begin (hash-set! pages new-n content) (hash-remove! pages old-n)
                  (let ([old-link (format "[[~a]]" old-n)] [new-link (format "[[~a]]" new-n)])
                    (for ([(name txt) (in-hash pages)]) (hash-set! pages name (string-replace txt old-link new-link))))
                  (save!) #t) #f)))))

    (define/public (get-history-files name)
      (let ([prefix (string-append (get-safe-filename name) "_")])
        (sort (filter (lambda (f) (string-prefix? (path->string f) prefix)) (directory-list history-path))
              (lambda (a b) (string>? (path->string a) (path->string b))))))

    (define/private (normalize s) (regexp-replace* #px"[’‘]" (string-downcase s) "'"))
    (define/public (get-backlinks target)
      (define clean-t (normalize target))
      (for/list ([(name content) (in-hash pages)] #:when (and (not (equal? name target)) (string-contains? (normalize content) clean-t))) name))
    
    (define/public (get-orphan-pages)
      (filter (lambda (name) (let ([links (send this get-backlinks name)]) (and (not (member name '("HomePage" "WikiManual"))) (empty? links)))) (get-all-names)))

    (define/public (get-wanted-pages)
      (define all-text (apply string-append (hash-values pages)))
      (define matches (regexp-match* #px"\\[\\[([^\\]]+)\\]\\]" all-text #:match-select values))
      (filter (lambda (p) (not (hash-has-key? pages p))) (remove-duplicates (if matches (map second matches) '()))))

    (define/public (render-to-html name)
      (define html-str (xexpr->string `(div ,@(parse-markdown (get-text name)))))
      (regexp-replace* #px"\\[\\[([^\\]]+)\\]\\]" html-str
        (lambda (entire wiki-name) 
          (define color (if (hash-has-key? pages wiki-name) "#007bff" "#dc3545"))
          (format "<a href='/view/~a' style='color:~a; font-weight:bold;'>~a</a>" wiki-name color wiki-name))))))
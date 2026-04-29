#lang racket

;; --- 1. LIBRARIES ---
(require racket/class
         web-server/servlet
         web-server/servlet-env
         xml
         racket/runtime-path
         racket/file         ; For binary file reading
         (except-in markdown xexpr->string)) ; Markdown support

;; --- 2. STORAGE & PATH SETUP ---
(define-runtime-path db-path "wiki_storage.rktd")
(define-runtime-path images-path "images")

;; Create the images directory if missing
(unless (directory-exists? images-path)
  (make-directory images-path))

;; --- 3. THE WIKI ENGINE (OO) ---
(define wiki%
  (class object%
    (super-new)
    (init-field [path db-path])
    (field [lock (make-semaphore 1)])
    
    ;; 3a. Data Loading
    (field [pages (if (file-exists? path)
                      (let ([data (with-input-from-file path read)])
                        (if (list? data) (make-hash data) (make-hash)))
                      (make-hash 
                       (list (cons "HomePage" "# Home\nWelcome to your Wiki.")
                             (cons "WikiManual" "# Manual\nUse [[Brackets]] for links."))))])

    ;; 3b. Atomic Persistence
    (define/public (save!)
      (define temp (string-append (path->string path) ".tmp"))
      (with-output-to-file temp #:exists 'replace
        (lambda () (write (hash->list pages))))
      (rename-file-or-directory temp path #t))

    ;; 3c. Thread-Safe Accessors
    (define/public (get-text name) 
      (call-with-semaphore lock (lambda () (hash-ref pages name ""))))
    
    (define/public (set-text! name txt) 
      (call-with-semaphore lock (lambda () (hash-set! pages name txt) (send this save!))))

    (define/public (delete-page! name)
      (call-with-semaphore lock (lambda () (hash-remove! pages name) (send this save!))))

    (define/public (get-all-names) (sort (hash-keys pages) string<?))

    ;; 3d. Normalization (Solves the "Apostrophe Trap" and Case Issues)
    (define/private (normalize s)
      (let* ([s1 (string-downcase s)]
             [s2 (regexp-replace* #px"[’‘]" s1 "'")]) ; Convert curly apostrophes to straight
        s2))

    ;; 3e. Backlinks Logic (Deep Search)
    (define/public (get-backlinks target)
      (define clean-target (normalize target))
      (for/list ([(name content) (in-hash pages)]
                 #:when (and (not (equal? name target))
                             (string-contains? (normalize content) clean-target)))
        name))

    ;; 3f. Orphan Detection
    (define/public (get-orphan-pages)
      (filter (lambda (name)
                (let ([links (send this get-backlinks name)])
                  (and (not (member name '("HomePage" "WikiManual"))) 
                       (empty? links))))
              (get-all-names)))

    ;; 3g. Wanted Pages (Finding empty links)
    (define/public (get-wanted-pages)
      (define all-text (apply string-append (hash-values pages)))
      (define br-matches (map second (or (regexp-match* #px"\\[\\[([^\\]]+)\\]\\]" all-text #:match-select values) '())))
      (define cm-matches (or (regexp-match* #px"(?<![A-Za-z])([A-Z][a-z]+[A-Z][a-zA-Z]*)(?![A-Za-z])" all-text) '()))
      (filter (lambda (p) (not (hash-has-key? pages p))) (remove-duplicates (append br-matches cm-matches))))

    ;; 3h. Rendering (Markdown + Brackets)
    (define/public (render-to-html name)
      (define raw (get-text name))
      (define html-str (xexpr->string `(div ,@(parse-markdown raw))))
      (regexp-replace* #px"\\[\\[([^\\]]+)\\]\\]" html-str
        (lambda (entire wiki-name) 
          (define exists? (hash-has-key? pages wiki-name))
          (format "<a href='/view/~a' style='color:~a; font-weight:bold;'>~a</a>" 
                  wiki-name (if exists? "#007bff" "#dc3545") wiki-name))))
    ))

(define my-wiki (new wiki%))

;; --- 4. WEB INTERFACE ---

(define (layout title content)
  (response/xexpr
   `(html (body ([style "font-family:sans-serif; max-width:850px; margin:40px auto; background:#fcfcfc; padding:20px; color:#333;"])
                (div ([style "display:flex; justify-content:space-between; align-items:center;"])
                     ;; Backlinks trigger by clicking Title
                     (h1 (a ([href ,(string-append "/backlinks/" title)] [style "text-decoration:none; color:black;"]) ,title))
                     (form ([action "/search"] [method "get"]) (input ([name "q"] [placeholder "Search..."]))))
                (div ([style "border:1px solid #eee; padding:30px; background:white; min-height:300px; border-radius:8px; shadow: 0 4px 10px #eee;"]) ,content)
                (hr)
                (div ([style "display:flex; gap:15px; font-size:0.85em; opacity:0.8;"])
                     (a ([href "/view/HomePage"]) "Home") (a ([href "/index"]) "Index")
                     (a ([href "/wanted"]) "Wanted") (a ([href "/orphans"]) "Orphans")
                     (a ([href ,(string-append "/edit/" title)]) "Edit"))))))

;; Manual Image Server (Serves files as binary bytes)
(define (serve-image file-path)
  (if (file-exists? file-path)
      (let ([ext (path->string file-path)])
        (response/full 200 #"OK" (current-seconds)
         (cond [(string-suffix? ext ".png") #"image/png"]
               [(string-suffix? ext ".jpg") #"image/jpeg"]
               [(string-suffix? ext ".gif") #"image/gif"]
               [else #"application/octet-stream"])
         empty (list (file->bytes file-path))))
      (response/xexpr '(body "Image not found."))))

;; --- 5. THE DISPATCHER ---

(define (start req)
  (define uri (request-uri req))
  (define parts (map path/param-path (url-path uri)))
  (define query (url-query uri))
  
  (cond
    ;; Images
    [(and (not (empty? parts)) (equal? (first parts) "images"))
     (serve-image (build-path images-path (second parts)))]

    ;; Search (Case-Insensitive)
    [(and (not (empty? parts)) (equal? (first parts) "search"))
     (define q (string-downcase (or (and (assoc 'q query) (cdr (assoc 'q query))) "")))
     (layout "Search Results" 
             `(ul ,@(map (lambda (p) `(li (a ([href ,(string-append "/view/" p)]) ,p))) 
                         (filter (lambda (p) (string-contains? (string-downcase p) q)) (send my-wiki get-all-names)))))]

    ;; Index / Wanted / Orphans
    [(equal? parts '("index")) (layout "Index" `(ul ,@(map (lambda (p) `(li (a ([href ,(string-append "/view/" p)]) ,p))) (send my-wiki get-all-names))))]
    [(equal? parts '("wanted")) (layout "Wanted" `(ul ,@(map (lambda (p) `(li (a ([href ,(string-append "/view/" p)] [style "color:red;"]) ,p))) (send my-wiki get-wanted-pages))))]
    [(equal? parts '("orphans")) (layout "Orphan Pages" `(ul ,@(map (lambda (p) `(li (a ([href ,(string-append "/view/" p)]) ,p))) (send my-wiki get-orphan-pages))))]

    ;; Backlinks
    [(and (>= (length parts) 2) (equal? (first parts) "backlinks"))
     (define n (second parts))
     (define b-links (send my-wiki get-backlinks n))
     (layout (string-append "Links to " n) 
             (if (empty? b-links) '(p "No other pages link here yet.")
                 `(ul ,@(map (lambda (p) `(li (a ([href ,(string-append "/view/" p)]) ,p))) b-links))))]

    ;; Delete
    [(and (>= (length parts) 2) (equal? (first parts) "delete"))
     (send my-wiki delete-page! (second parts))
     (redirect-to "/index")]

    ;; Save / View / Edit
    [(and (>= (length parts) 2) (equal? (first parts) "save"))
     (send my-wiki set-text! (second parts) (extract-binding/single 'content (request-bindings req)))
     (redirect-to (string-append "/view/" (second parts)))]

    [(and (>= (length parts) 2) (equal? (first parts) "view"))
     (layout (second parts) (make-cdata #f #f (send my-wiki render-to-html (second parts))))]

    [(and (>= (length parts) 2) (equal? (first parts) "edit"))
     (define n (second parts))
     (response/xexpr
      `(html (body ([style "font-family:sans-serif; margin:40px;"])
                   (h1 "Edit " ,n)
                   (form ([action ,(string-append "/save/" n)] [method "post"])
                         (textarea ([name "content"] [style "width:100%; height:400px; font-family:monospace;"]) 
                                   ,(send my-wiki get-text n))
                         (br) (input ([type "submit"] [value "Save Changes"]))
                         " " (a ([href ,(string-append "/view/" n)]) "Cancel")
                         " | " (a ([href ,(string-append "/delete/" n)] 
                                   [style "color:red;"]
                                   [onclick "return confirm('Delete permanently?')"]) "🗑 Delete")))))]

    [else (redirect-to "/view/HomePage")]))

;; --- 6. START SERVER ---
(printf "Wiki Milestone 2.1 Live at http://localhost:8889\n")
(serve/servlet start #:listen-ip #f #:port 8889 #:servlet-path "/" #:servlet-regexp #rx"" #:command-line? #t)
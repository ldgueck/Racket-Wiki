#lang racket

;; --- 1. LIBRARIES ---
(require racket/class
         web-server/servlet
         web-server/servlet-env
         web-server/http
         web-server/http/cookie
         xml
         racket/runtime-path
         racket/file
         racket/list
         racket/date
         (except-in markdown xexpr->string)
         "theme.rkt") 

;; --- 2. PATHS & CONFIG ---
(define-runtime-path db-dir ".")
(define-runtime-path static-path "static")
(define-runtime-path images-path "images")
(define-runtime-path history-path "history")
(define-runtime-path config-path "config.rktd")

(for ([p (list images-path history-path)]) (unless (directory-exists? p) (make-directory p)))

(define config (if (file-exists? config-path) (with-input-from-file config-path read) #hash()))
(define SITE-TITLE (hash-ref config 'wiki-title "Family Wiki"))

;; --- 3. THE ENGINES (OO) ---

(define auth%
  (class object%
    (super-new)
    (init-field [password (hash-ref config 'password "admin")])
    (field [session-token (number->string (random 1000000000))])
    (define/public (check-password? attempt) (equal? attempt password))
    (define/public (is-authorized? req)
      (let ([cookies (request-cookies req)])
        (let ([my-cookie (findf (lambda (c) (equal? (client-cookie-name c) "wiki-session")) cookies)])
          (and my-cookie (equal? (client-cookie-value my-cookie) session-token)))))
    (define/public (make-auth-cookie) (make-cookie "wiki-session" session-token #:path "/"))
    (define/public (make-logout-cookie) 
      (make-cookie "wiki-session" "expired" #:path "/" #:expires "Thu, 01 Jan 1970 00:00:00 GMT"))))

(define wiki%
  (class object%
    (super-new)
    (init-field [db-name (hash-ref config 'db-file "wiki_storage.rktd")])
    (define path (build-path db-dir db-name))
    (field [lock (make-semaphore 1)])
    (field [pages (if (file-exists? path)
                      (let ([data (with-input-from-file path read)]) (if (list? data) (make-hash data) (make-hash)))
                      (make-hash (list (cons "HomePage" "# Welcome"))))])

    ;; Safe filename generator (Windows-friendly)
    (define/private (get-safe-filename name)
      (regexp-replace* #px"[^a-zA-Z0-9]" name "_"))

    ;; ARCHIVE: Save current state to history before overwriting
    (define/public (archive-version! name)
      (let ([current-text (hash-ref pages name #f)])
        (if (and current-text (not (equal? current-text "")))
            (let* ([d (current-date)]
                   [ts (format "~a-~a-~a_~a-~a-~a" (date-year d) (date-month d) (date-day d) (date-hour d) (date-minute d) (date-second d))]
                   [filename (format "~a_~a.txt" (get-safe-filename name) ts)]
                   [backup-file (build-path history-path filename)])
              (with-output-to-file backup-file #:exists 'replace (lambda () (display current-text)))
              (printf ">>> [HISTORY] Backup created: ~a\n" filename))
            (printf ">>> [HISTORY] Skip backup for brand new page: ~a\n" name))))

    (define/public (save!)
      (define temp (string-append (path->string path) ".tmp"))
      (with-output-to-file temp #:exists 'replace (lambda () (write (hash->list pages))))
      (rename-file-or-directory temp path #t))

    (define/public (get-text name) (call-with-semaphore lock (lambda () (hash-ref pages name ""))))
    
    (define/public (set-text! name txt) 
      (call-with-semaphore lock 
        (lambda () 
          (archive-version! name) ; Step 1: Backup old
          (hash-set! pages name txt) ; Step 2: Update RAM
          (save!)))) ; Step 3: Write DB

    (define/public (delete-page! name) (call-with-semaphore lock (lambda () (hash-remove! pages name) (save!))))
    (define/public (get-all-names) (sort (hash-keys pages) string<?))
    
    (define/public (get-history-files name)
      (let ([prefix (string-append (get-safe-filename name) "_")])
        (sort (filter (lambda (f) (string-prefix? (path->string f) prefix)) (directory-list history-path))
              (lambda (a b) (string>? (path->string a) (path->string b))))))

    (define/private (normalize s) (regexp-replace* #px"[’‘]" (string-downcase s) "'"))
    
    (define/public (get-backlinks target)
      (define clean-target (normalize target))
      (for/list ([(name content) (in-hash pages)] 
                 #:when (and (not (equal? name target)) (string-contains? (normalize content) clean-target))) 
        name))
    
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
          (format "<a href='/view/~a' style='color:~a; font-weight:bold;'>~a</a>" wiki-name color wiki-name))))

    ;; --- ADD TO wiki% CLASS ---
    (define/public (rename-page! old-name new-name)
      (call-with-semaphore lock
        (lambda ()
          (let ([content (hash-ref pages old-name #f)])
            (if (and content (not (hash-has-key? pages new-name)))
                (begin
                  ;; 1. Move the content to the new name
                  (hash-set! pages new-name content)
                  (hash-remove! pages old-name)
                  
                  ;; 2. Global Search and Replace for links
                  ;; We look for [[Old Name]] and change to [[New Name]]
                  (let ([old-link (format "[[~a]]" old-name)]
                        [new-link (format "[[~a]]" new-name)])
                    (for ([(name txt) (in-hash pages)])
                      (hash-set! pages name (string-replace txt old-link new-link))))
                  
                  ;; 3. Save the changes
                  (save!)
                  (printf ">>> [RENAME] '~a' is now '~a'. Links updated.\n" old-name new-name)
                  #t)
                #f)))))

    ;; --- ADD TO wiki% CLASS ---

    ;; Physical deletion of an image file
    (define/public (delete-image! filename)
      (let ([p (build-path images-path filename)])
        (when (file-exists? p)
          (delete-file p)
          (printf ">>> [JANITOR] Deleted image: ~a\n" filename))))

    ;; Returns a list of filenames actually mentioned in the wiki text
    (define/public (get-used-images)
      (let ([all-text (apply string-append (hash-values pages))])
        ;; Regex looks for anything following the /images/ path
        (let ([matches (regexp-match* #px"/images/([^\\s\\)\\]\"]+)" all-text #:match-select values)])
          (if matches 
              (remove-duplicates (map second matches))
              '()))))))

(define my-wiki (new wiki%))
(define my-auth (new auth%))

;; --- 4. DISPATCHER HELPERS ---
(define (response-with-cookie resp c)
  (struct-copy response resp [headers (cons (cookie->header c) (response-headers resp))]))

(define (serve-img file-path)
  (if (file-exists? file-path)
      (let ([ext (path->string file-path)])
        (response/full 200 #"OK" (current-seconds) (if (string-suffix? ext ".png") #"image/png" #"image/jpeg") 
                     empty (list (file->bytes file-path))))
      (response/xexpr '(body "Not found"))))

;; --- 5. DISPATCHER ---

(define (start req)
  (define uri (request-uri req))
  (define parts (map path/param-path (url-path uri)))
  (define query (url-query uri))
  
  (cond
    [(and (not (empty? parts)) (equal? (first parts) "static"))
     (response/full 200 #"OK" (current-seconds) #"text/css" empty (list (file->bytes (build-path static-path (second parts)))))]

;; --- ADD TO YOUR cond IN start FUNCTION ---

    ;; 1. Show the Rename Form
    [(and (>= (length parts) 2) (equal? (first parts) "rename"))
     (let ([n (second parts)])
       (layout (string-append "Rename: " n)
               `(form ([action ,(string-append "/do-rename/" n)] [method "post"])
                      (p "Enter a new name for this page. All links to this page will be updated.")
                      (input ([type "text"] [name "newname"] [value ,n] [style "width:300px;"]))
                      (input ([type "submit"] [value "Rename Page"])))
               SITE-TITLE))]

    ;; 2. Handle the Rename Action
    [(and (>= (length parts) 2) (equal? (first parts) "do-rename"))
     (let* ([old-n (second parts)]
            [new-n (extract-binding/single 'newname (request-bindings req))])
       (if (send my-wiki rename-page! old-n new-n)
           (redirect-to (string-append "/view/" new-n))
           (layout "Error" `(p "Could not rename. Name might already exist.") SITE-TITLE)))]

    [(equal? parts '("login"))
     (layout "Login" `(form ([action "/do-login"] [method "post"]) (input ([type "password"] [name "pw"] [autofocus "true"])) (input ([type "submit"]))) SITE-TITLE #:is-login? #t)]
    
    [(equal? parts '("do-login"))
     (if (send my-auth check-password? (extract-binding/single 'pw (request-bindings req)))
         (response-with-cookie (redirect-to "/view/HomePage") (send my-auth make-auth-cookie))
         (redirect-to "/login"))]

    [(equal? parts '("logout")) (response-with-cookie (redirect-to "/login") (send my-auth make-logout-cookie))]
    [(not (send my-auth is-authorized? req)) (redirect-to "/login")]

    ;; --- PROTECTED ---
    [(and (not (empty? parts)) (equal? (first parts) "images")) (serve-img (build-path images-path (second parts)))]
    [(and (not (empty? parts)) (equal? (first parts) "search"))
     (let* ([q (string-downcase (or (and (assoc 'q query) (cdr (assoc 'q query))) ""))]
            [res (filter (lambda (p) (string-contains? (string-downcase p) q)) (send my-wiki get-all-names))])
       (layout "Search" `(ul ,@(map (lambda (p) `(li (a ([href ,(string-append "/view/" p)]) ,p))) res)) SITE-TITLE))]

    [(equal? parts '("index")) (layout "Index" `(ul ,@(map (lambda (p) `(li (a ([href ,(string-append "/view/" p)]) ,p))) (send my-wiki get-all-names))) SITE-TITLE)]
    [(equal? parts '("wanted")) (layout "Wanted" `(ul ,@(map (lambda (p) `(li (a ([href ,(string-append "/view/" p)] [style "color:red;"]) ,p))) (send my-wiki get-wanted-pages))) SITE-TITLE)]
    [(equal? parts '("orphans")) (layout "Orphans" `(ul ,@(map (lambda (p) `(li (a ([href ,(string-append "/view/" p)]) ,p))) (send my-wiki get-orphan-pages))) SITE-TITLE)]
    
    [(equal? parts '("upload"))
     (layout "Upload" `(form ([action "/do-upload"] [method "post"] [enctype "multipart/form-data"]) (input ([type "file"] [name "file"])) (input ([type "submit"]))) SITE-TITLE)]

    [(equal? parts '("do-upload"))
     (define b (request-bindings/raw req))
     (define f-b (findf (lambda (x) (bytes=? (binding-id x) #"file")) b))
     (if (binding:file? f-b)
         (let* ([fn (regexp-replace* #px"[^a-zA-Z0-9.-]" (bytes->string/utf-8 (binding:file-filename f-b)) "_")])
           (with-output-to-file (build-path images-path fn) #:exists 'replace (lambda () (write-bytes (binding:file-content f-b))))
           (layout "Uploaded" `(p "Saved as: " (code ,fn)) SITE-TITLE))
         (redirect-to "/upload"))]

    [(equal? parts '("gallery"))
     (let ([files (filter (lambda (f) (regexp-match? #px"\\.(png|jpg|jpeg|gif)$" (path->string f))) (directory-list images-path))])
       (layout "Gallery" `(div ([style "display:grid; grid-template-columns:repeat(auto-fill, minmax(150px,1fr)); gap:10px;"])
                               ,@(map (lambda (f) `(img ([src ,(string-append "/images/" (path->string f))] [style "width:150px;"]))) files)) SITE-TITLE))]

    [(and (>= (length parts) 2) (equal? (first parts) "backlinks"))
     (let ([links (send my-wiki get-backlinks (second parts))])
       (layout (string-append "Links to " (second parts)) `(ul ,@(map (lambda (p) `(li (a ([href ,(string-append "/view/" p)]) ,p))) links)) SITE-TITLE))]
    
    [(and (>= (length parts) 2) (equal? (first parts) "history"))
     (let ([name (second parts)])
       (layout (string-append "History: " name)
               `(ul ,@(map (lambda (v) `(li (a ([href ,(string-append "/view-history/" (path->string v))]) ,(path->string v)))) 
                           (send my-wiki get-history-files name))) SITE-TITLE))]
    
    [(and (>= (length parts) 2) (equal? (first parts) "view-history"))
     (let ([content (file->string (build-path history-path (second parts)))])
       (layout (second parts) `(pre ,content) SITE-TITLE))]

    [(and (>= (length parts) 2) (equal? (first parts) "save"))
     (send my-wiki set-text! (second parts) (extract-binding/single 'content (request-bindings req)))
     (redirect-to (string-append "/view/" (second parts)))]

    [(and (>= (length parts) 2) (equal? (first parts) "view"))
     (layout (second parts) (make-cdata #f #f (send my-wiki render-to-html (second parts))) SITE-TITLE)]

    [(and (>= (length parts) 2) (equal? (first parts) "edit"))
     (layout (string-append "Editing: " (second parts))
             `(form ([action ,(string-append "/save/" (second parts))] [method "post"])
                    (textarea ([name "content"] [style "width:100%; height:500px; font-family:monospace;"]) 
                              ,(send my-wiki get-text (second parts)))
                    (br) (input ([type "submit"] [value "Save Changes"])))
             SITE-TITLE)]

    [(and (>= (length parts) 2) (equal? (first parts) "delete")) (send my-wiki delete-page! (second parts)) (redirect-to "/index")]
    [else (redirect-to "/view/HomePage")]))

;; --- 6. RUN ---
(printf "Wiki Milestone 5 [HISTORY] live at http://localhost:8889\n")
(serve/servlet start #:listen-ip #f #:port (hash-ref config 'port 8889) #:servlet-path "/" #:servlet-regexp #rx"" #:command-line? #t)
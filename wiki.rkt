#lang racket

;; --- 1. LIBRARIES ---
(require racket/class
         web-server/servlet
         web-server/servlet-env
         web-server/http
         xml
         racket/runtime-path
         racket/file
         racket/list
         racket/date
         file/zip
         (except-in markdown xexpr->string)
         "auth-class.rkt"
         "wiki-class.rkt"
         "theme.rkt") 

;; --- 2. PATHS & CONFIG ---
(define-runtime-path current-dir ".")
(define-runtime-path static-path "static")
(define-runtime-path images-path "images")
(define-runtime-path history-path "history")
(define-runtime-path config-path "config.rktd")

;; Ensure folders exist
(for ([p (list images-path history-path)]) (unless (directory-exists? p) (make-directory p)))

;; Load Config
(define config (if (file-exists? config-path) (with-input-from-file config-path read) #hash()))
(define SITE-TITLE (hash-ref config 'wiki-title "Family Wiki"))
(define ACTIVE-DB-PATH (build-path current-dir (hash-ref config 'db-file "wiki_storage.rktd")))

;; --- 3. ENGINES (OO) ---





;; Pass the paths to the wiki class
(define my-wiki (new wiki% 
                     [path ACTIVE-DB-PATH]
                     [history-path history-path]
                     [images-path images-path]))

;; Pass the config password to the auth class
(define my-auth (new auth%[password (hash-ref config 'password "admin")]))

;; --- 4. HELPERS ---

(define (response-with-cookie resp c)
  (struct-copy response resp [headers (cons (cookie->header c) (response-headers resp))]))

(define (serve-img file-path)
  (if (file-exists? file-path)
      (response/full 200 #"OK" (current-seconds) (if (string-suffix? (path->string file-path) ".png") #"image/png" #"image/jpeg") 
                     empty (list (file->bytes file-path)))
      (response/xexpr '(body "Not found"))))

;; --- 5. DISPATCHER ---

(define (start req)
  (define uri (request-uri req))
  (define parts (map path/param-path (url-path uri)))
  (define query (url-query uri))
  
  (cond
    ;; Static (Public)
    [(and (not (empty? parts)) (equal? (first parts) "static"))
     (response/full 200 #"OK" (current-seconds) #"text/css" empty (list (file->bytes (build-path static-path (second parts)))))]
    
    ;; Auth (Public)
    [(equal? parts '("login"))
     (layout "Login" `(form ([action "/do-login"] [method "post"]) (input ([type "password"] [name "pw"] [autofocus "true"])) (input ([type "submit"]))) SITE-TITLE #:is-login? #t)]
    [(equal? parts '("do-login"))
     (if (send my-auth check-password? (extract-binding/single 'pw (request-bindings req)))
         (response-with-cookie (redirect-to "/view/HomePage") (send my-auth make-auth-cookie)) (redirect-to "/login"))]
    [(equal? parts '("logout")) (response-with-cookie (redirect-to "/login") (send my-auth make-logout-cookie))]
    
    ;; Guard
    [(not (send my-auth is-authorized? req)) (redirect-to "/login")]

    ;; --- PROTECTED ---
    
    ;; EXPORT
    [(equal? parts '("export"))
     (define zip-fn "wiki_backup.zip")
     (define zip-full-path (build-path current-dir zip-fn))
     (when (file-exists? zip-full-path) (delete-file zip-full-path))
     (parameterize ([current-directory current-dir])
       (zip zip-full-path (hash-ref config 'db-file "wiki_storage.rktd") "images" "history"))
     (response 200 #"OK" (current-seconds) #"application/zip"
      (list (header #"Content-Disposition" (string->bytes/utf-8 (format "attachment; filename=\"~a\"" zip-fn)))
            (header #"Content-Length" (string->bytes/utf-8 (number->string (file-size zip-full-path)))))
      (lambda (out-port) (with-input-from-file zip-full-path (lambda () (copy-port (current-input-port) out-port)))))]

    [(and (not (empty? parts)) (equal? (first parts) "images")) (serve-img (build-path images-path (second parts)))]
    
    [(and (not (empty? parts)) (equal? (first parts) "search"))
     (let* ([q (string-downcase (or (and (assoc 'q query) (cdr (assoc 'q query))) ""))]
            [res (filter (lambda (p) (string-contains? (string-downcase p) q)) (send my-wiki get-all-names))])
       (layout "Search Results" `(ul ,@(map (lambda (p) `(li (a ([href ,(string-append "/view/" p)]) ,p))) res)) SITE-TITLE))]

    [(equal? parts '("index")) (layout "Site Index" `(ul ,@(map (lambda (p) `(li (a ([href ,(string-append "/view/" p)]) ,p))) (send my-wiki get-all-names))) SITE-TITLE)]
    [(equal? parts '("wanted")) (layout "Wanted" `(ul ,@(map (lambda (p) `(li (a ([href ,(string-append "/view/" p)] [style "color:red;"]) ,p))) (send my-wiki get-wanted-pages))) SITE-TITLE)]
    [(equal? parts '("orphans")) (layout "Orphan Pages" `(ul ,@(map (lambda (p) `(li (a ([href ,(string-append "/view/" p)]) ,p))) (send my-wiki get-orphan-pages))) SITE-TITLE)]
    
    [(equal? parts '("upload")) (layout "Upload" `(form ([action "/do-upload"] [method "post"] [enctype "multipart/form-data"]) (input ([type "file"] [name "file"])) (input ([type "submit"]))) SITE-TITLE)]
    [(equal? parts '("do-upload"))
     (let* ([b (request-bindings/raw req)] [f-b (findf (lambda (x) (bytes=? (binding-id x) #"file")) b)])
       (if (binding:file? f-b)
           (let ([fn (regexp-replace* #px"[^a-zA-Z0-9.-]" (bytes->string/utf-8 (binding:file-filename f-b)) "_")])
             (with-output-to-file (build-path images-path fn) #:exists 'replace (lambda () (write-bytes (binding:file-content f-b))))
             (layout "Uploaded" `(p "Saved: " (code ,fn)) SITE-TITLE))
           (redirect-to "/upload")))]

    [(equal? parts '("gallery"))
     (let* ([all-f (filter (lambda (f) (regexp-match? #px"\\.(png|jpg|jpeg|gif)$" (path->string f))) (directory-list images-path))]
            [used (send my-wiki get-used-images)])
       (layout "Media Gallery"
               `(div ([style "display:grid; grid-template-columns:repeat(auto-fill, minmax(180px,1fr)); gap:20px;"])
                     ,@(map (lambda (f) 
                              (let* ([fn (path->string f)] [is-u? (member fn used)])
                                `(div ([style ,(string-append "border:1px solid #ddd; padding:10px; border-radius:5px; text-align:center;" (if is-u? "" "background:#fff0f0;"))])
                                      (img ([src ,(string-append "/images/" fn)] [style "width:150px; height:100px; object-fit:cover;"]))
                                      (div ([style "font-size:0.7em; margin:5px 0; word-break:break-all;"]) (code ,fn))
                                      (a ([href ,(string-append "/delete-image/" fn)] [style "color:red; font-size:0.8em;"] [onclick "return confirm('Delete image?')"]) "Delete"))))
                            all-f)) SITE-TITLE))]

    [(and (>= (length parts) 2) (equal? (first parts) "backlinks"))
     (layout (string-append "Links to " (second parts)) `(ul ,@(map (lambda (p) `(li (a ([href ,(string-append "/view/" p)]) ,p))) (send my-wiki get-backlinks (second parts)))) SITE-TITLE)]
    [(and (>= (length parts) 2) (equal? (first parts) "history"))
     (layout "History" `(ul ,@(map (lambda (v) `(li (a ([href ,(string-append "/view-history/" (path->string v))]) ,(path->string v)))) (send my-wiki get-history-files (second parts)))) SITE-TITLE)]
    [(and (>= (length parts) 2) (equal? (first parts) "view-history")) (layout (second parts) `(pre ,(file->string (build-path history-path (second parts)))) SITE-TITLE)]

    [(and (>= (length parts) 2) (equal? (first parts) "rename"))
     (layout "Rename" `(form ([action ,(string-append "/do-rename/" (second parts))] [method "post"]) (input ([type "text"] [name "newname"] [value ,(second parts)])) (input ([type "submit"]))) SITE-TITLE)]
    [(and (>= (length parts) 2) (equal? (first parts) "do-rename"))
     (let ([new-n (extract-binding/single 'newname (request-bindings req))])
       (if (send my-wiki rename-page! (second parts) new-n) (redirect-to (string-append "/view/" new-n)) (layout "Error" '(p "Failed") SITE-TITLE)))]

    [(and (>= (length parts) 2) (equal? (first parts) "save")) (send my-wiki set-text! (second parts) (extract-binding/single 'content (request-bindings req))) (redirect-to (string-append "/view/" (second parts)))]
    [(and (>= (length parts) 2) (equal? (first parts) "view")) (layout (second parts) (make-cdata #f #f (send my-wiki render-to-html (second parts))) SITE-TITLE)]
    [(and (>= (length parts) 2) (equal? (first parts) "edit"))
     (layout (second parts) `(form ([action ,(string-append "/save/" (second parts))] [method "post"]) (textarea ([name "content"] [style "width:100%; height:500px; font-family:monospace;"]) ,(send my-wiki get-text (second parts))) (br) (input ([type "submit"]))) SITE-TITLE)]
    [(and (>= (length parts) 2) (equal? (first parts) "delete")) (send my-wiki delete-page! (second parts)) (redirect-to "/index")]
    [(and (>= (length parts) 2) (equal? (first parts) "delete-image")) (send my-wiki delete-image! (second parts)) (redirect-to "/gallery")]
    [else (redirect-to "/view/HomePage")]))

;; --- 6. RUN ---
(printf "Wiki Milestone 9 [FINAL] live at http://localhost:8889\n")
(serve/servlet start #:listen-ip #f #:port (hash-ref config 'port 8889) #:servlet-path "/" #:servlet-regexp #rx"" #:command-line? #t)
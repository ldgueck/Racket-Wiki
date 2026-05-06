#lang racket

(require web-server/servlet)

(provide layout)

(define (layout title content site-title #:is-login? [is-login? #f])
  ;; 1. Identify "System" pages where "Page Actions" (Edit/Rename/Delete) are hidden
  (define system-pages '("Index" "Wanted" "Orphan Pages" "Media Gallery" "Search Results" 
                         "Login" "Uploaded" "Error" "History" "Site Index"))
  (define is-system-page? (member title system-pages))

  (response/xexpr
   `(html (head (title ,title)
                (link ([rel "stylesheet"] [href "/static/style.css"])))
          (body 
           ,(if is-login?
                ;; --- LOGIN LAYOUT ---
                `(div ([class "main-container"])
                      (div ([class "box"] [style "text-align:center; padding-top:100px;"])
                           (h1 ,site-title)
                           ,content))
                
                ;; --- MAIN WORKSPACE LAYOUT ---
                `(div ([style "display:flex; width:100%;"])
                      
                      ;; --- LEFT SIDEBAR ---
                      (div ([class "sidebar"])
                           (h1 ,site-title)
                           
                           ;; A. Search
                           (div ([class "sidebar-section"])
                                (form ([action "/search"] [method "get"]) 
                                      (input ([name "q"] [class "search-input"] [placeholder "Search..."]))))

                           ;; B. Navigation
                           (div ([class "sidebar-section"])
                                (div ([class "sidebar-label"]) "Navigation")
                                (nav
                                 (a ([href "/view/HomePage"]) "🏠 Home")
                                 (a ([href "/index"]) "🗂 All Pages")
                                 (a ([href "/wanted"]) "❓ Wanted")
                                 (a ([href "/orphans"]) "🕸 Orphans")
                                 (a ([href "/export"] [style "color:#e67e22; font-weight:bold;"]) "📦 Export All")))

                           ;; C. Media
                           (div ([class "sidebar-section"])
                                (div ([class "sidebar-label"]) "Media")
                                (nav
                                 (a ([href "/upload"]) "🖼 Upload Image")
                                 (a ([href "/gallery"]) "🎨 Gallery")))

                           ;; D. Page Actions (Only show when viewing a real wiki page)
                           ,(if is-system-page? 
                                "" 
                                `(div ([class "sidebar-section"])
                                      (div ([class "sidebar-label"]) "Page Actions")
                                      (nav
                                       (a ([href ,(string-append "/edit/" title)] [style "color:green; font-weight:bold;"]) "📝 Edit Page")
                                       (a ([href ,(string-append "/rename/" title)]) "✏️ Rename")
                                       (a ([href ,(string-append "/history/" title)]) "⏳ History")
                                       (a ([href ,(string-append "/delete/" title)] [style "color:red;"] 
                                           [onclick "return confirm('Delete this page forever?')"]) "🗑 Delete"))))

                           ;; E. Footer
                           (div ([style "margin-top:auto; padding-top:20px; border-top:1px solid #edece9;"])
                                (a ([href "/logout"] [style "font-size:0.8em; color:gray; text-decoration:none;"]) "Logout")))

                      ;; --- RIGHT CONTENT AREA ---
                      (div ([class "main-container"])
                           (div ([class "box"])
                                (h1 ([class "page-title"]) 
                                    (a ([href ,(string-append "/backlinks/" title)] 
                                        [style "text-decoration:none; color:inherit;"]
                                        [title "View Backlinks"]) ,title))
                                (div ([class "wiki-content"]) ,content)))))))))
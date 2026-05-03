#lang racket
(require web-server/servlet)
(provide layout)

(define (layout title content site-title #:is-login? [is-login? #f])
  (response/xexpr
   `(html (head (title ,title)
                (link ([rel "stylesheet"] [href "/static/style.css"])))
          (body 
           (div ([style "display:flex; justify-content:space-between; align-items:center;"])
                (h1 (a ([href "/view/HomePage"] [style "text-decoration:none; color:black;"]) ,site-title))
                ,(if is-login? "" 
                     `(form ([action "/search"] [method "get"]) 
                            (input ([name "q"] [placeholder "Search..."])))))
           (hr)
           (h2 ,title)
           (div ([class "box"]) ,content)
           (hr)
           ,(if is-login? ""
                `(div ([class "footer"])
                      (a ([href "/view/HomePage"]) "🏠 Home")
                      (a ([href "/index"]) "🗂 Index")
                      (a ([href "/wanted"]) "❓ Wanted")
                      (a ([href "/orphans"]) "🕸 Orphans")
                      (a ([href "/upload"]) "🖼 Upload")
                      (a ([href "/gallery"]) "🎨 Gallery")
                      (a ([href ,(string-append "/edit/" title)] [style "color:green; font-weight:bold;"]) "📝 Edit")
                      (a ([href ,(string-append "/history/" title)]) "⏳ History")
                      (a ([href ,(string-append "/delete/" title)] [style "color:red;"] 
                          [onclick "return confirm('Delete page forever?')"]) "🗑 Delete")
                      ;; Inside the (div ([class "footer"]) ...) block in theme.rkt:
                      (a ([href ,(string-append "/rename/" title)]) "✏️ Rename")
                      (a ([href "/logout"] [style "margin-left:auto; color:gray;"]) "Log Out")))))))
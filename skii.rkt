#lang racket

;; TODO: openssl context
;; TODO: what happens if the internet disconnects?

(require openssl)
(require racket/date)

(define irc-dir (build-path (find-system-path 'home-dir)
                            "utilities/irc/taurine.csclub.uwaterloo.ca"))
(define-values (src-dir _1 _2) (split-path (find-system-path 'run-file)))

(define nick "cdchawthorne")
(define fullname "Christopher Davis Constant Hawthorne")
(define pass (file->string (build-path src-dir "password")))
(define hostname "taurine.csclub.uwaterloo.ca")
(define port 50505)

(define (login to-server nick pass fullname)
  (when pass (fprintf to-server "PASS ~a\r\n" pass))
  (fprintf to-server "NICK ~a\r\n" nick)
  (fprintf to-server "USER ~a 0 * :~a\r\n" nick fullname))

(date-display-format 'iso-8601)

(make-directory* irc-dir)
(define-values (from-server to-server) (ssl-connect hostname port))

(define to-client (open-output-file (build-path irc-dir "out")
                                    #:exists 'append))

(define from-client-name (build-path irc-dir "in"))
(unless (file-exists? from-client-name)
  (void (system* "/usr/bin/mkfifo" from-client-name)))
(define from-client (open-input-file from-client-name))

;; Yeah, yeah.
;; But things get unpleasant if you have to worry about from-client returning
;; #<eof>
(void (open-output-file from-client-name #:exists 'append))

(file-stream-buffer-mode to-client 'line)
(file-stream-buffer-mode to-server 'line)

(login to-server nick pass fullname)

(define (handle-from-server msg)
  (match msg
    [(regexp #rx"^PING (.*)$" (list _ payload))
     (fprintf to-server "PONG ~a\r\n" payload)]
    [_ (fprintf to-client "~a ~a\n" (date->string (current-date) #t) msg)]))

(define (handle-from-client msg)
  (fprintf to-server "~a\r\n" msg)
  (fprintf to-client "~a ~a\n" (date->string (current-date) #t) msg))

(define (run)
  (sync (wrap-evt from-client (λ (p) (handle-from-client (read-line p))))
        (wrap-evt from-server (λ (p) (handle-from-server (read-line p)))))
  (run))

(run)

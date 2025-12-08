(defmodule MAIN (export ?ALL))

;; template che rappresenta la mossa eseguita al passo ?step
;; definisce la struttura dell'azione eseguita dall'agente
(deftemplate exec
    (slot step)
    (slot action (allowed-values fire guess unguess solve))
    (slot x) ;; non usato nel caso del comando solve
    (slot y) ;; non usato nel caso del comando solve
)

;; stato corrente dell'esecuzione
;; traccia lo stato corrente del gioco
(deftemplate status (slot step) (slot currently (allowed-values running stopped)) )

;; numero di mosse ancora disponibili (tra fire e guess)
;; tiene il conteggio delle mosse rimanenti
(deftemplate moves (slot fires) (slot guesses) )

;; raccoglie le statistiche di gioco per punteggio finale
(deftemplate statistics
    (slot num_fire_ok)
    (slot num_fire_ko)
    (slot num_guess_ok)
    (slot num_guess_ko)
    (slot num_safe)
    (slot num_sink)
)

;; inizializza il gioco e passa il controllo al modulo ENV
;; forza il passaggio al modulo ENV all'inizio del gioco
(defrule go-on-env-first (declare (salience 30))
    ?f <- (first-pass-to-env)
=>
    (retract ?f)
    (focus ENV)
)

;; controlla che step non abbiano superato il limite poi passa
;; il controllo al modulo AGENT per decidere l'azione da eseguire
(defrule go-on-agent  (declare (salience 20))
    (maxduration ?d)
    (status (step ?s&:(< ?s ?d)) (currently running))
 =>
    ;(printout t crlf crlf)
    ;(printout t "vado ad agent  step" ?s)
    (focus AGENT)
)


;; SI PASSA AL MODULO ENV DOPO CHE AGENTE HA DECISO AZIONE DA FARE
;; si attiva quando esiste un'azione exec con lo stesso step dello status corrente
;; l'agente ha deciso cosa fare a questo turno, ora l'ambiente deve simulare l'effetto
(defrule go-on-env  (declare (salience 30))
    ?f1 <-	(status (step ?s))
    (exec (step ?s))
=>
    ; (printout t crlf crlf)
    ; (printout t "vado ad ENV  step" ?s)
    (focus ENV)
)

;; si attiva quando si raggiungono gli step massimi consentiti
;; forza azione solve e passa il controllo al modulo ENV per calcolo punteggio
(defrule game-over
    (maxduration ?d)
    (status (step ?s&:(>= ?s ?d)) (currently running))
=>
    (assert (exec (step ?s) (action solve)))
    (focus ENV)
)

;; inizializza i fatti globali all'inizio del gioco
(deffacts initial-facts
    (maxduration 100) ;; settiamo numero max di step
    (status (step 0) (currently running)) ;; impostiamo step a zero e stato a running, poi tutte le statistiche a zero
          (statistics (num_fire_ok 0) (num_fire_ko 0) (num_guess_ok 0) (num_guess_ko 0) (num_safe 0) (num_sink 0))
    (first-pass-to-env)
    (moves (fires 5) (guesses 20) )
)


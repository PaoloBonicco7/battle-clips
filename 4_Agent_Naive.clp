;  ---------------------------------------------
;  --- Agente Semplice per Battaglia Navale ---
;  ---------------------------------------------
(defmodule AGENT (import MAIN ?ALL) (import ENV ?ALL) (export ?ALL))

;; template per impostazzioni iniziali
(deftemplate action-count
    (slot fires (default 0))
    (slot guesses (default 0))
)

;; impostiamo valori iniziali
(deffacts initial-agent-facts
    (action-count (fires 0) (guesses 0))
)

;; ========================    REGOLE     ======================================

;; =============================================================================
;; 1 - REGOLA GUESS SU CELLE NOTE - Punti garantiti
;; Salience 10: massima priorità
;; =============================================================================

;; 1 - guess su cella già nota contenente nave
;; Attivazione: esiste una k-cell con contenuto nave su cui non abbiamo ancora fatto guess
;; Limite: nessuno, questa azione è sempre corretta
(defrule guess-known-boat (declare (salience 10))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))                                  ; una sola azione per step
    (moves (guesses ?ng&:(> ?ng 0)))                        ; abbiamo ancora guess
    (k-cell (x ?x) (y ?y) (content top | bot | left | right | middle | sub))  ; cella nave nota
    (not (exec (action guess) (x ?x) (y ?y)))               ; non già guessato
    ?rc <- (k-per-col (col ?y) (num ?nc))                   ; cattura contatore colonna
    ?rr <- (k-per-row (row ?x) (num ?nr))                   ; cattura contatore riga
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y ?y)))
    (modify ?rr (num (- ?nr 1)))                            ; decrementa contatore riga
    (modify ?rc (num (- ?nc 1)))                            ; decrementa contatore colonna
    (printout t "GUESS cella nota [" ?x "," ?y "]" crlf)
    (pop-focus)
)

;; =============================================================================
;; 2 - REGOLE DI ESTENSIONE NAVE - Guess su celle adiacenti a pezzi noti
;; Salience 9: priorità alta dopo guess su celle già note
;; Problemi noti comuni:
;;      - Middle potrebbe essere parte di nave con orientamento opposto
;;      - Decrementa row e col senza certezza di colpire
;; =============================================================================

;; 2a - guess estensione LEFT
;; Attivazione: middle/right possono avere nave a sinistra
(defrule guess-near-boat-left (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (k-cell (x ?x) (y ?y) (content middle | right))         ; pezzi che possono estendersi a sinistra
    (test (> ?y 0))                                         ; cella a sinistra esiste
    (not (k-cell (x ?x) (y =(- ?y 1))))                     ; non già conosciuta
    (not (exec (action fire) (x ?x) (y =(- ?y 1))))         ; non già sparato
    (not (exec (action guess) (x ?x) (y =(- ?y 1))))        ; non già guessato
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y (- ?y 1))))
    (printout t "GUESS estensione LEFT [" ?x "," (- ?y 1) "]" crlf)
    (pop-focus)
)

;; 2b - guess estensione RIGHT
;; Attivazione: middle/left possono avere nave a destra
(defrule guess-near-boat-right (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (k-cell (x ?x) (y ?y) (content middle | left))          ; pezzi che possono estendersi a destra
    (test (< ?y 9))                                         ; cella a destra esiste
    (not (k-cell (x ?x) (y =(+ ?y 1))))                     ; non già conosciuta
    (not (exec (action fire) (x ?x) (y =(+ ?y 1))))         ; non già sparato
    (not (exec (action guess) (x ?x) (y =(+ ?y 1))))        ; non già guessato
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y (+ ?y 1))))
    (printout t "GUESS estensione RIGHT [" ?x "," (+ ?y 1) "]" crlf)
    (pop-focus)
)

;; 2c - guess estensione UP
;; Attivazione: middle/bot possono avere nave sopra
(defrule guess-near-boat-up (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (k-cell (x ?x) (y ?y) (content middle | bot))           ; pezzi che possono estendersi sopra
    (test (> ?x 0))                                         ; cella sopra esiste
    (not (k-cell (x =(- ?x 1)) (y ?y)))                     ; non già conosciuta
    (not (exec (action fire) (x =(- ?x 1)) (y ?y)))         ; non già sparato
    (not (exec (action guess) (x =(- ?x 1)) (y ?y)))        ; non già guessato
=>
    (assert (exec (step ?s) (action guess) (x (- ?x 1)) (y ?y)))
    (printout t "GUESS estensione UP [" (- ?x 1) "," ?y "]" crlf)
    (pop-focus)
)

;; 2d - guess estensione DOWN
;; Attivazione: middle/top possono avere nave sotto
(defrule guess-near-boat-down (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (k-cell (x ?x) (y ?y) (content middle | top))           ; pezzi che possono estendersi sotto
    (test (< ?x 9))                                         ; cella sotto esiste
    (not (k-cell (x =(+ ?x 1)) (y ?y)))                     ; non già conosciuta
    (not (exec (action fire) (x =(+ ?x 1)) (y ?y)))         ; non già sparato
    (not (exec (action guess) (x =(+ ?x 1)) (y ?y)))        ; non già guessato
=>
    (assert (exec (step ?s) (action guess) (x (+ ?x 1)) (y ?y)))
    (printout t "GUESS estensione DOWN [" (+ ?x 1) "," ?y "]" crlf)
    (pop-focus)
)

;; =============================================================================
;; 3- REGOLA FIRE STRATEGICO - Esplorazione intelligente
;; Salience 5: priorità media, dopo guess su celle note e estensioni
;; =============================================================================

;; 3 - fire sulla cella con massima probabilità
;; Attivazione: trova la cella all'intersezione di riga e colonna con più navi
;; Limite: cerca massimo riga e colonna separatamente, non considera la somma come score,
;;         e si blocca se l'intersezione dei massimi è già nota/sparata/guessata
(defrule fire-best-cell (declare (salience 5))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (fires ?nf&:(> ?nf 0)))                          ; abbiamo ancora fire
    (k-per-row (row ?r) (num ?nr&:(> ?nr 0)))               ; riga con navi > 0
    (k-per-col (col ?c) (num ?nc&:(> ?nc 0)))               ; colonna con navi > 0
    (not (k-per-row (row ?r2&:(neq ?r2 ?r)) (num ?nr2&:(> ?nr2 ?nr))))  ; nessuna riga migliore
    (not (k-per-col (col ?c2&:(neq ?c2 ?c)) (num ?nc2&:(> ?nc2 ?nc))))  ; nessuna colonna migliore
    (not (k-cell (x ?r) (y ?c)))                            ; cella non già nota
    (not (exec (action fire) (x ?r) (y ?c)))                ; non già sparato
    (not (exec (action guess) (x ?r) (y ?c)))               ; non già guessed
=>
    (assert (exec (step ?s) (action fire) (x ?r) (y ?c)))
    (printout t "FIRE best cell [" ?r "," ?c "] (row:" ?nr " col:" ?nc ")" crlf)
    (pop-focus)
)


;; =============================================================================
;; REGOLA FIRE FALLBACK - Quando fire-best-cell non trova il massimo assoluto
;; Salience 4: priorità sotto fire-best-cell
;; Limite: non ottimizza, spara sulla prima cella promettente che trova
;; =============================================================================

(defrule fire-any-promising (declare (salience 4))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (fires ?nf&:(> ?nf 0)))                          ; abbiamo ancora fire
    (k-per-row (row ?r) (num ?nr&:(> ?nr 0)))               ; riga con navi > 0
    (k-per-col (col ?c) (num ?nc&:(> ?nc 0)))               ; colonna con navi > 0
    (not (k-cell (x ?r) (y ?c)))                            ; cella non già nota
    (not (exec (action fire) (x ?r) (y ?c)))                ; non già sparato
    (not (exec (action guess) (x ?r) (y ?c)))               ; non già guessato
=>
    (assert (exec (step ?s) (action fire) (x ?r) (y ?c)))
    (printout t "FIRE fallback [" ?r "," ?c "]" crlf)
    (pop-focus)
)


;; =============================================================================
;; REGOLA GUESS FALLBACK - Quando non abbiamo più fire
;; Salience 3: priorità bassa, dopo tutte le regole di fire
;; Limite: sceglie cella arbitraria tra quelle promettenti, non ottimizza per score;
;;         decrementa contatori assumendo guess corretto (può diventare inconsistente)
;; =============================================================================

(defrule guess-any-promising (declare (salience 3))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (fires 0) (guesses ?ng&:(> ?ng 0)))              ; fire esauriti, guess disponibili
    (k-per-row (row ?r) (num ?nr&:(> ?nr 0)))               ; riga con navi > 0
    (k-per-col (col ?c) (num ?nc&:(> ?nc 0)))               ; colonna con navi > 0
    (not (k-cell (x ?r) (y ?c)))                            ; cella non già nota
    (not (exec (action fire) (x ?r) (y ?c)))                ; non già sparato
    (not (exec (action guess) (x ?r) (y ?c)))               ; non già guessato
=>
    (assert (exec (step ?s) (action guess) (x ?r) (y ?c)))
    (printout t "GUESS fallback [" ?r "," ?c "]" crlf)
    (pop-focus)
)


;; =============================================================================
;; REGOLA SOLVE - Terminazione
;; Salience -10: ultima risorsa, si attiva solo quando nessun'altra regola può
;; Limite: termina appena non sa cosa fare, anche se ha ancora mosse disponibili
;; =============================================================================

(defrule give-up (declare (salience -10))
    (status (step ?s) (currently running))
    ; (moves (fires 0) (guesses 0))           ; esaurite tutte le mosse
    (not (exec (step ?s)))                  ; nessuna azione pianificata
 =>
    (assert (exec (step ?s) (action solve)))
    (printout t "SOLVE - termino" crlf)
    (pop-focus)
)

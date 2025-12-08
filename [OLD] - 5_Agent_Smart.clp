;  ---------------------------------------------
;  --- Agente Smart per Battaglia Navale ---
;  ---------------------------------------------
(defmodule AGENT (import MAIN ?ALL) (import ENV ?ALL) (export ?ALL))

;; template per impostazioni iniziali
(deftemplate action-count
    (slot fires (default 0))
    (slot guesses (default 0))
)

;; impostiamo valori iniziali
(deffacts initial-agent-facts
    (action-count (fires 0) (guesses 0))
)

;; =============================================================================
;; DEDUZIONE ACQUA DA CONTATORI ZERO
;; Salience 20: si attiva prima di qualsiasi azione
;; Logica: se una riga/colonna ha num=0, tutte le sue celle sconosciute sono acqua
;; =============================================================================

;; Se riga ha 0 navi rimanenti, tutte le celle non-note di quella riga sono acqua
(defrule deduce-water-row-zero (declare (salience 20))
    (k-per-row (row ?x) (num 0))
    (k-per-col (col ?y))                    ; itera su tutte le colonne
    (not (k-cell (x ?x) (y ?y)))            ; cella non già nota
    (not (known-water ?x ?y))               ; non già dedotta come acqua
=>
    (assert (known-water ?x ?y))
    (printout t "DEDUCE water [" ?x "," ?y "] row " ?x " has 0 ships" crlf)
)

;; Se colonna ha 0 navi rimanenti, tutte le celle non-note di quella colonna sono acqua
(defrule deduce-water-col-zero (declare (salience 20))
    (k-per-col (col ?y) (num 0))
    (k-per-row (row ?x))                    ; itera su tutte le righe
    (not (k-cell (x ?x) (y ?y)))            ; cella non già nota
    (not (known-water ?x ?y))               ; non già dedotta come acqua
=>
    (assert (known-water ?x ?y))
    (printout t "DEDUCE water [" ?x "," ?y "] col " ?y " has 0 ships" crlf)
)

;; =============================================================================
;; DEDUZIONE ACQUA DA DIAGONALI
;; Salience 20: si attiva prima di qualsiasi azione
;; Logica: le navi non possono toccarsi in diagonale, quindi le 4 celle
;;         diagonali rispetto a qualsiasi pezzo nave sono sempre acqua
;; =============================================================================

;; Diagonale alto-sinistra (x-1, y-1)
(defrule deduce-water-diag-up-left (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content top | bot | left | right | middle | sub))
    (test (and (> ?x 0) (> ?y 0)))          ; cella diagonale esiste
    (not (known-water =(- ?x 1) =(- ?y 1)))
=>
    (assert (known-water (- ?x 1) (- ?y 1)))
    (printout t "DEDUCE water [" (- ?x 1) "," (- ?y 1) "] diagonal of [" ?x "," ?y "]" crlf)
)

;; Diagonale alto-destra (x-1, y+1)
(defrule deduce-water-diag-up-right (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content top | bot | left | right | middle | sub))
    (test (and (> ?x 0) (< ?y 9)))          ; cella diagonale esiste
    (not (known-water =(- ?x 1) =(+ ?y 1)))
=>
    (assert (known-water (- ?x 1) (+ ?y 1)))
    (printout t "DEDUCE water [" (- ?x 1) "," (+ ?y 1) "] diagonal of [" ?x "," ?y "]" crlf)
)

;; Diagonale basso-sinistra (x+1, y-1)
(defrule deduce-water-diag-down-left (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content top | bot | left | right | middle | sub))
    (test (and (< ?x 9) (> ?y 0)))          ; cella diagonale esiste
    (not (known-water =(+ ?x 1) =(- ?y 1)))
=>
    (assert (known-water (+ ?x 1) (- ?y 1)))
    (printout t "DEDUCE water [" (+ ?x 1) "," (- ?y 1) "] diagonal of [" ?x "," ?y "]" crlf)
)

;; Diagonale basso-destra (x+1, y+1)
(defrule deduce-water-diag-down-right (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content top | bot | left | right | middle | sub))
    (test (and (< ?x 9) (< ?y 9)))          ; cella diagonale esiste
    (not (known-water =(+ ?x 1) =(+ ?y 1)))
=>
    (assert (known-water (+ ?x 1) (+ ?y 1)))
    (printout t "DEDUCE water [" (+ ?x 1) "," (+ ?y 1) "] diagonal of [" ?x "," ?y "]" crlf)
)

;; =============================================================================
;; REGOLA GUESS SU CELLE NOTE - Punti garantiti (VERSIONE SMART)
;; Salience 10: massima priorità - sono punti sicuri
;; Versione smart: verifichiamo che i contatori sono > 0
;; =============================================================================

;; 1 - guess su cella già nota contenente nave
;; Attivazione: esiste una k-cell con contenuto nave su cui non abbiamo ancora fatto guess
(defrule guess-known-boat (declare (salience 10))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))                                  ; una sola azione per step
    (moves (guesses ?ng&:(> ?ng 0)))                        ; abbiamo ancora guess
    (k-cell (x ?x) (y ?y) (content top | bot | left | right | middle | sub))  ; cella nave nota
    (not (exec (action guess) (x ?x) (y ?y)))               ; non già guessato
    ?rc <- (k-per-col (col ?y) (num ?nc&:(> ?nc 0)))        ; cattura contatore colonna E verifichiamo > 0
    ?rr <- (k-per-row (row ?x) (num ?nr&:(> ?nr 0)))        ; cattura contatore riga E verifichiamo > 0
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y ?y)))
    (modify ?rr (num (- ?nr 1)))                            ; decrementa contatore riga
    (modify ?rc (num (- ?nc 1)))                            ; decrementa contatore colonna
    (printout t "GUESS cella nota [" ?x "," ?y "]" crlf)
    (pop-focus)
)

;; =============================================================================
;; REGOLE DI ESTENSIONE NAVE (VERSIONE SMART)
;; Salience 9: priorità alta dopo guess su celle già note
;; Miglioramento: verifica orientamento del middle prima di estendere
;; Problema residuo: decrementa row e col senza certezza assoluta di colpire
;; =============================================================================

;; 2a - guess estensione LEFT (SMART)
;; Attivazione: 
;;   - right: sicuramente ha nave a sinistra
;;   - middle: solo se confermato orizzontale (ha pezzo noto a destra)
(defrule guess-near-boat-left (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (or
        ;; Caso 1: right - sicuramente orizzontale, nave a sinistra
        (k-cell (x ?x) (y ?y) (content right))
        ;; Caso 2: middle con pezzo a destra - confermato orizzontale
        (and
            (k-cell (x ?x) (y ?y) (content middle))
            (k-cell (x ?x) (y =(+ ?y 1)) (content middle | right))
        )
        ;; Caso 3: middle con pezzo a sinistra - confermato orizzontale, continua a sinistra
        (and
            (k-cell (x ?x) (y ?y) (content middle))
            (k-cell (x ?x) (y =(- ?y 1)) (content middle | left))
        )
    )
    (test (> ?y 0))                                         ; cella a sinistra esiste
    (not (k-cell (x ?x) (y =(- ?y 1))))                     ; non già conosciuta
    (not (exec (action fire) (x ?x) (y =(- ?y 1))))         ; non già sparato
    (not (exec (action guess) (x ?x) (y =(- ?y 1))))        ; non già guessato
    ?rc <- (k-per-col (col =(- ?y 1)) (num ?nc&:(> ?nc 0))) ; colonna ha ancora navi
    ?rr <- (k-per-row (row ?x) (num ?nr&:(> ?nr 0)))        ; riga ha ancora navi
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y (- ?y 1))))
    (modify ?rr (num (- ?nr 1)))
    (modify ?rc (num (- ?nc 1)))
    (printout t "GUESS estensione LEFT [" ?x "," (- ?y 1) "]" crlf)
    (pop-focus)
)

;; 2b - guess estensione RIGHT (SMART)
;; Attivazione:
;;   - left: sicuramente ha nave a destra
;;   - middle: solo se confermato orizzontale (ha pezzo noto a sinistra)
(defrule guess-near-boat-right (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (or
        ;; Caso 1: left - sicuramente orizzontale, nave a destra
        (k-cell (x ?x) (y ?y) (content left))
        ;; Caso 2: middle con pezzo a sinistra - confermato orizzontale
        (and
            (k-cell (x ?x) (y ?y) (content middle))
            (k-cell (x ?x) (y =(- ?y 1)) (content middle | left))
        )
        ;; Caso 3: middle con pezzo a destra - confermato orizzontale, continua a destra
        (and
            (k-cell (x ?x) (y ?y) (content middle))
            (k-cell (x ?x) (y =(+ ?y 1)) (content middle | right))
        )
    )
    (test (< ?y 9))                                         ; cella a destra esiste
    (not (k-cell (x ?x) (y =(+ ?y 1))))                     ; non già conosciuta
    (not (exec (action fire) (x ?x) (y =(+ ?y 1))))         ; non già sparato
    (not (exec (action guess) (x ?x) (y =(+ ?y 1))))        ; non già guessato
    ?rc <- (k-per-col (col =(+ ?y 1)) (num ?nc&:(> ?nc 0))) ; colonna ha ancora navi
    ?rr <- (k-per-row (row ?x) (num ?nr&:(> ?nr 0)))        ; riga ha ancora navi
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y (+ ?y 1))))
    (modify ?rr (num (- ?nr 1)))
    (modify ?rc (num (- ?nc 1)))
    (printout t "GUESS estensione RIGHT [" ?x "," (+ ?y 1) "]" crlf)
    (pop-focus)
)

;; 2c - guess estensione UP (SMART)
;; Attivazione:
;;   - bot: sicuramente ha nave sopra
;;   - middle: solo se confermato verticale (ha pezzo noto sotto)
(defrule guess-near-boat-up (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (or
        ;; Caso 1: bot - sicuramente verticale, nave sopra
        (k-cell (x ?x) (y ?y) (content bot))
        ;; Caso 2: middle con pezzo sotto - confermato verticale
        (and
            (k-cell (x ?x) (y ?y) (content middle))
            (k-cell (x =(+ ?x 1)) (y ?y) (content middle | bot))
        )
        ;; Caso 3: middle con pezzo sopra - confermato verticale, continua sopra
        (and
            (k-cell (x ?x) (y ?y) (content middle))
            (k-cell (x =(- ?x 1)) (y ?y) (content middle | top))
        )
    )
    (test (> ?x 0))                                         ; cella sopra esiste
    (not (k-cell (x =(- ?x 1)) (y ?y)))                     ; non già conosciuta
    (not (exec (action fire) (x =(- ?x 1)) (y ?y)))         ; non già sparato
    (not (exec (action guess) (x =(- ?x 1)) (y ?y)))        ; non già guessato
    ?rc <- (k-per-col (col ?y) (num ?nc&:(> ?nc 0)))        ; colonna ha ancora navi
    ?rr <- (k-per-row (row =(- ?x 1)) (num ?nr&:(> ?nr 0))) ; riga sopra ha ancora navi
=>
    (assert (exec (step ?s) (action guess) (x (- ?x 1)) (y ?y)))
    (modify ?rr (num (- ?nr 1)))
    (modify ?rc (num (- ?nc 1)))
    (printout t "GUESS estensione UP [" (- ?x 1) "," ?y "]" crlf)
    (pop-focus)
)

;; 2d - guess estensione DOWN (SMART)
;; Attivazione:
;;   - top: sicuramente ha nave sotto
;;   - middle: solo se confermato verticale (ha pezzo noto sopra)
(defrule guess-near-boat-down (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (or
        ;; Caso 1: top - sicuramente verticale, nave sotto
        (k-cell (x ?x) (y ?y) (content top))
        ;; Caso 2: middle con pezzo sopra - confermato verticale
        (and
            (k-cell (x ?x) (y ?y) (content middle))
            (k-cell (x =(- ?x 1)) (y ?y) (content middle | top))
        )
        ;; Caso 3: middle con pezzo sotto - confermato verticale, continua sotto
        (and
            (k-cell (x ?x) (y ?y) (content middle))
            (k-cell (x =(+ ?x 1)) (y ?y) (content middle | bot))
        )
    )
    (test (< ?x 9))                                         ; cella sotto esiste
    (not (k-cell (x =(+ ?x 1)) (y ?y)))                     ; non già conosciuta
    (not (exec (action fire) (x =(+ ?x 1)) (y ?y)))         ; non già sparato
    (not (exec (action guess) (x =(+ ?x 1)) (y ?y)))        ; non già guessato
    ?rc <- (k-per-col (col ?y) (num ?nc&:(> ?nc 0)))        ; colonna ha ancora navi
    ?rr <- (k-per-row (row =(+ ?x 1)) (num ?nr&:(> ?nr 0))) ; riga sotto ha ancora navi
=>
    (assert (exec (step ?s) (action guess) (x (+ ?x 1)) (y ?y)))
    (modify ?rr (num (- ?nr 1)))
    (modify ?rc (num (- ?nc 1)))
    (printout t "GUESS estensione DOWN [" (+ ?x 1) "," ?y "]" crlf)
    (pop-focus)
)


;; =============================================================================
;; REGOLA FIRE STRATEGICO (SMART) - Esplorazione intelligente
;; Salience 5: priorità media, dopo guess su celle note e estensioni
;; Miglioramento: usa somma row + col come score, considera tutte le celle libere
;; =============================================================================

;; 3 - fire sulla cella con massima probabilità (SMART)
;; Attivazione: trova la cella libera con score (nr + nc) massimo
;; Logica: la probabilità di trovare nave è proporzionale alla somma dei contatori
(defrule fire-best-cell-smart (declare (salience 5))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (fires ?nf&:(> ?nf 0)))                          ; abbiamo ancora fire
    
    ;; Trova una cella candidata
    (k-per-row (row ?r) (num ?nr&:(> ?nr 0)))               ; riga con navi > 0
    (k-per-col (col ?c) (num ?nc&:(> ?nc 0)))               ; colonna con navi > 0
    (not (k-cell (x ?r) (y ?c)))                            ; cella non già nota
    (not (exec (action fire) (x ?r) (y ?c)))                ; non già sparato
    (not (exec (action guess) (x ?r) (y ?c)))               ; non già guessato
    
    ;; Verifica che non esista una cella libera con score migliore
    (not
        (and
            (k-per-row (row ?r2) (num ?nr2&:(> ?nr2 0)))
            (k-per-col (col ?c2) (num ?nc2&:(> ?nc2 0)))
            (test (> (+ ?nr2 ?nc2) (+ ?nr ?nc)))            ; score strettamente migliore
            (not (k-cell (x ?r2) (y ?c2)))                  ; anche questa è libera
            (not (exec (action fire) (x ?r2) (y ?c2)))
            (not (exec (action guess) (x ?r2) (y ?c2)))
        )
    )
=>
    (assert (exec (step ?s) (action fire) (x ?r) (y ?c)))
    (printout t "FIRE best cell [" ?r "," ?c "] score:" (+ ?nr ?nc) " (row:" ?nr " col:" ?nc ")" crlf)
    (pop-focus)
)


;; =============================================================================
;; REGOLA FIRE FALLBACK - Quando fire-best-cell non trova il massimo assoluto
;; In questo caso non serve, perchè fire-best-cell-smart considera tutte le celle libere
;; =============================================================================


;; =============================================================================
;; REGOLA GUESS FALLBACK (SMART) - Quando non abbiamo più fire
;; Salience 3: priorità bassa, dopo tutte le regole di fire
;; Miglioramento: sceglie cella libera con score (nr + nc) massimo
;; Limite residuo: decrementa contatori assumendo guess corretto
;; =============================================================================

(defrule guess-any-promising-smart (declare (salience 3))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (fires 0) (guesses ?ng&:(> ?ng 0)))              ; fire esauriti, guess disponibili
    
    ;; Trova una cella candidata
    (k-per-row (row ?r) (num ?nr&:(> ?nr 0)))               ; riga con navi > 0
    (k-per-col (col ?c) (num ?nc&:(> ?nc 0)))               ; colonna con navi > 0
    (not (k-cell (x ?r) (y ?c)))                            ; cella non già nota
    (not (exec (action fire) (x ?r) (y ?c)))                ; non già sparato
    (not (exec (action guess) (x ?r) (y ?c)))               ; non già guessato
    
    ;; Verifica che non esista cella libera con score migliore
    (not
        (and
            (k-per-row (row ?r2) (num ?nr2&:(> ?nr2 0)))
            (k-per-col (col ?c2) (num ?nc2&:(> ?nc2 0)))
            (test (> (+ ?nr2 ?nc2) (+ ?nr ?nc)))            ; score strettamente migliore
            (not (k-cell (x ?r2) (y ?c2)))                  ; anche questa è libera
            (not (exec (action fire) (x ?r2) (y ?c2)))
            (not (exec (action guess) (x ?r2) (y ?c2)))
        )
    )
    
    ;; Cattura per modify
    ?rr <- (k-per-row (row ?r) (num ?nr))
    ?rc <- (k-per-col (col ?c) (num ?nc))
=>
    (assert (exec (step ?s) (action guess) (x ?r) (y ?c)))
    (modify ?rr (num (- ?nr 1)))
    (modify ?rc (num (- ?nc 1)))
    (printout t "GUESS fallback [" ?r "," ?c "] score:" (+ ?nr ?nc) crlf)
    (pop-focus)
)


;; =============================================================================
;; REGOLE DI CORREZIONE (SMART) - Unguess con tracking
;; Salience 15: alta priorità
;; Nota: ENV gestisce automaticamente il contatore guesses e il fatto (guess ?x ?y)
;; =============================================================================

;; 5a - unguess su cella che si è rivelata acqua
;; Attivazione: avevamo fatto guess (esiste fatto "guess ?x ?y"), ora sappiamo che è acqua
(defrule unguess-revealed-water (declare (salience 15))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (k-cell (x ?x) (y ?y) (content water))                  ; la cella è acqua
    (guess ?x ?y)                                           ; CORRETTO: esiste il fatto guess attivo
    ?rr <- (k-per-row (row ?x) (num ?nr))
    ?rc <- (k-per-col (col ?y) (num ?nc))
=>
    (assert (exec (step ?s) (action unguess) (x ?x) (y ?y)))
    (modify ?rr (num (+ ?nr 1)))                            ; ripristina contatore riga
    (modify ?rc (num (+ ?nc 1)))                            ; ripristina contatore colonna
    ;; Nota: ENV gestisce (retract guess) e incremento moves.guesses
    (printout t "UNGUESS correzione [" ?x "," ?y "] era acqua!" crlf)
    (pop-focus)
)

;; 5b - unguess su riga esaurita
;; Attivazione: riga ha 0 navi rimanenti, ma abbiamo guess attivi non confermati
(defrule unguess-row-exhausted (declare (salience 14))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (k-per-row (row ?x) (num 0))                            ; riga esaurita
    (guess ?x ?y)                                           ; CORRETTO: guess attivo su questa riga
    (not (k-cell (x ?x) (y ?y)))                            ; NON confermato da k-cell (speculativo)
    ?rc <- (k-per-col (col ?y) (num ?nc))
=>
    (assert (exec (step ?s) (action unguess) (x ?x) (y ?y)))
    (modify ?rc (num (+ ?nc 1)))                            ; ripristina solo colonna (riga già 0)
    (printout t "UNGUESS riga esaurita [" ?x "," ?y "]" crlf)
    (pop-focus)
)

;; 5c - unguess su colonna esaurita
;; Simmetrico per colonna
(defrule unguess-col-exhausted (declare (salience 14))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (k-per-col (col ?y) (num 0))                            ; colonna esaurita
    (guess ?x ?y)                                           ; CORRETTO: guess attivo su questa colonna
    (not (k-cell (x ?x) (y ?y)))                            ; NON confermato
    ?rr <- (k-per-row (row ?x) (num ?nr))
=>
    (assert (exec (step ?s) (action unguess) (x ?x) (y ?y)))
    (modify ?rr (num (+ ?nr 1)))                            ; ripristina solo riga (colonna già 0)
    (printout t "UNGUESS colonna esaurita [" ?x "," ?y "]" crlf)
    (pop-focus)
)

;; =============================================================================
;; REGOLE SOLVE (SMART) - Terminazione intelligente
;; Salience -10 e -20: ultime risorse con tentativi graduali
;; =============================================================================

;; 6a - ultimo tentativo: guess su qualsiasi cella non nota
;; Attivazione: abbiamo ancora guess ma nessuna cella "promettente" (score > 0)
;; Scopo: usare guess residui su celle qualsiasi prima di arrendersi
(defrule last-resort-guess (declare (salience -5))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))                        ; abbiamo ancora guess
    ;; Trova una cella qualsiasi non ancora toccata
    (k-per-row (row ?r) (num ?nr))                          ; qualsiasi riga (anche con 0)
    (k-per-col (col ?c) (num ?nc))                          ; qualsiasi colonna (anche con 0)
    (not (k-cell (x ?r) (y ?c)))                            ; cella non nota
    (not (exec (action fire) (x ?r) (y ?c)))
    (not (exec (action guess) (x ?r) (y ?c)))
    (not (unguessed ?r ?c))                                 ; non già annullata
    ?rr <- (k-per-row (row ?r) (num ?nr))
    ?rc <- (k-per-col (col ?c) (num ?nc))
=>
    (assert (exec (step ?s) (action guess) (x ?r) (y ?c)))
    (modify ?rr (num (- ?nr 1)))
    (modify ?rc (num (- ?nc 1)))
    (printout t "GUESS last resort [" ?r "," ?c "] (disperato)" crlf)
    (pop-focus)
)

;; 6b - solve quando non ci sono più celle da esplorare
;; Attivazione: tutte le celle sono note o già toccate
(defrule solve-no-cells-left (declare (salience -10))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    ;; Verifica che non esistano celle libere
    (not
        (and
            (k-per-row (row ?r))
            (k-per-col (col ?c))
            (not (k-cell (x ?r) (y ?c)))
            (not (exec (action fire) (x ?r) (y ?c)))
            (not (exec (action guess) (x ?r) (y ?c)))
        )
    )
=>
    (assert (exec (step ?s) (action solve)))
    (printout t "SOLVE - tutte le celle esplorate" crlf)
    (pop-focus)
)

;; 6c - solve quando non abbiamo più mosse
;; Attivazione: fire e guess esauriti
(defrule solve-no-moves-left (declare (salience -10))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (fires 0) (guesses 0))                           ; nessuna mossa disponibile
=>
    (assert (exec (step ?s) (action solve)))
    (printout t "SOLVE - mosse esaurite (fire:0 guess:0)" crlf)
    (pop-focus)
)

;; 6d - solve fallback assoluto
;; Attivazione: nessun'altra regola si è attivata (safety net)
(defrule solve-fallback (declare (salience -20))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
=>
    (assert (exec (step ?s) (action solve)))
    (printout t "SOLVE - fallback (nessuna regola attivabile)" crlf)
    (pop-focus)
)
;  ---------------------------------------------
;  --- Agente Smart per Battaglia Navale ---
;  ---------------------------------------------
(defmodule AGENT (import MAIN ?ALL) (import ENV ?ALL) (export ?ALL))


;; ===================== SEZIONE 1: DEDUZIONE (salience 20) ====================

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
;; DEDUZIONE ACQUA ORTOGONALE AI PEZZI TERMINALI
;; Logica: i bordi esterni dei pezzi terminali sono sempre acqua
;; =============================================================================

;; Sopra TOP c'è sempre acqua
(defrule deduce-water-above-top (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content top))
    (test (> ?x 0))
    (not (known-water =(- ?x 1) ?y))
=>
    (assert (known-water (- ?x 1) ?y))
    (printout t "DEDUCE water [" (- ?x 1) "," ?y "] above TOP" crlf)
)

;; Sotto BOT c'è sempre acqua
(defrule deduce-water-below-bot (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content bot))
    (test (< ?x 9))
    (not (known-water =(+ ?x 1) ?y))
=>
    (assert (known-water (+ ?x 1) ?y))
    (printout t "DEDUCE water [" (+ ?x 1) "," ?y "] below BOT" crlf)
)

;; A sinistra di LEFT c'è sempre acqua
(defrule deduce-water-leftof-left (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content left))
    (test (> ?y 0))
    (not (known-water ?x =(- ?y 1)))
=>
    (assert (known-water ?x (- ?y 1)))
    (printout t "DEDUCE water [" ?x "," (- ?y 1) "] left of LEFT" crlf)
)

;; A destra di RIGHT c'è sempre acqua
(defrule deduce-water-rightof-right (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content right))
    (test (< ?y 9))
    (not (known-water ?x =(+ ?y 1)))
=>
    (assert (known-water ?x (+ ?y 1)))
    (printout t "DEDUCE water [" ?x "," (+ ?y 1) "] right of RIGHT" crlf)
)

;; Intorno a SUB: sopra
(defrule deduce-water-above-sub (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content sub))
    (test (> ?x 0))
    (not (known-water =(- ?x 1) ?y))
=>
    (assert (known-water (- ?x 1) ?y))
    (printout t "DEDUCE water [" (- ?x 1) "," ?y "] above SUB" crlf)
)

;; Intorno a SUB: sotto
(defrule deduce-water-below-sub (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content sub))
    (test (< ?x 9))
    (not (known-water =(+ ?x 1) ?y))
=>
    (assert (known-water (+ ?x 1) ?y))
    (printout t "DEDUCE water [" (+ ?x 1) "," ?y "] below SUB" crlf)
)

;; Intorno a SUB: sinistra
(defrule deduce-water-leftof-sub (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content sub))
    (test (> ?y 0))
    (not (known-water ?x =(- ?y 1)))
=>
    (assert (known-water ?x (- ?y 1)))
    (printout t "DEDUCE water [" ?x "," (- ?y 1) "] left of SUB" crlf)
)

;; Intorno a SUB: destra
(defrule deduce-water-rightof-sub (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content sub))
    (test (< ?y 9))
    (not (known-water ?x =(+ ?y 1)))
=>
    (assert (known-water ?x (+ ?y 1)))
    (printout t "DEDUCE water [" ?x "," (+ ?y 1) "] right of SUB" crlf)
)

;; =============================================================================
;; DEDUZIONE ACQUA LATERALE A NAVI VERTICALI/ORIZZONTALI
;; Logica: i lati di una nave (non le estremità) sono acqua
;; =============================================================================

;; A sinistra e destra di pezzi verticali (top, middle verticale, bot)
(defrule deduce-water-leftof-vertical (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content top | bot))
    (test (> ?y 0))
    (not (known-water ?x =(- ?y 1)))
=>
    (assert (known-water ?x (- ?y 1)))
    (printout t "DEDUCE water [" ?x "," (- ?y 1) "] left of vertical piece" crlf)
)

(defrule deduce-water-rightof-vertical (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content top | bot))
    (test (< ?y 9))
    (not (known-water ?x =(+ ?y 1)))
=>
    (assert (known-water ?x (+ ?y 1)))
    (printout t "DEDUCE water [" ?x "," (+ ?y 1) "] right of vertical piece" crlf)
)

;; Sopra e sotto pezzi orizzontali (left, middle orizzontale, right)
(defrule deduce-water-above-horizontal (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content left | right))
    (test (> ?x 0))
    (not (known-water =(- ?x 1) ?y))
=>
    (assert (known-water (- ?x 1) ?y))
    (printout t "DEDUCE water [" (- ?x 1) "," ?y "] above horizontal piece" crlf)
)

(defrule deduce-water-below-horizontal (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content left | right))
    (test (< ?x 9))
    (not (known-water =(+ ?x 1) ?y))
=>
    (assert (known-water (+ ?x 1) ?y))
    (printout t "DEDUCE water [" (+ ?x 1) "," ?y "] below horizontal piece" crlf)
)

;; ===================== SEZIONE 2: GUESS CERTI (salience 10) ==================

;; =============================================================================
;; GUESS SU CELLE NOTE - Punti garantiti
;; Salience 10: massima priorità
;; NESSUN controllo su contatori: le k-cell sono certezze assolute
;; =============================================================================

(defrule guess-known-boat (declare (salience 10))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (k-cell (x ?x) (y ?y) (content top | bot | left | right | middle | sub))
    (not (exec (action guess) (x ?x) (y ?y)))
    ?rr <- (k-per-row (row ?x) (num ?nr))
    ?rc <- (k-per-col (col ?y) (num ?nc))
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y ?y)))
    (modify ?rr (num (- ?nr 1)))
    (modify ?rc (num (- ?nc 1)))
    (printout t "GUESS cella nota [" ?x "," ?y "]" crlf)
    (pop-focus)
)


;; ===================== SEZIONE 3: ESTENSIONI (salience 9) ====================

;; =============================================================================
;; ESTENSIONI NAVE - Guess su celle adiacenti a pezzi noti
;; Salience 9: priorità alta
;; Verifica orientamento per middle, controlla contatori per celle nuove
;; =============================================================================

;; Estensione LEFT: da right, o da middle orizzontale confermato
(defrule guess-extend-left (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (or
        (k-cell (x ?x) (y ?y) (content right))
        (and
            (k-cell (x ?x) (y ?y) (content middle))
            (or (k-cell (x ?x) (y =(+ ?y 1)) (content middle | right))
                (k-cell (x ?x) (y =(- ?y 1)) (content middle | left)))
        )
    )
    (test (> ?y 0))
    (not (k-cell (x ?x) (y =(- ?y 1))))
    (not (exec (action guess) (x ?x) (y =(- ?y 1))))
    (not (exec (action fire) (x ?x) (y =(- ?y 1))))
    ?rr <- (k-per-row (row ?x) (num ?nr&:(> ?nr 0)))
    ?rc <- (k-per-col (col =(- ?y 1)) (num ?nc&:(> ?nc 0)))
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y (- ?y 1))))
    (modify ?rr (num (- ?nr 1)))
    (modify ?rc (num (- ?nc 1)))
    (printout t "GUESS extend LEFT [" ?x "," (- ?y 1) "]" crlf)
    (pop-focus)
)

;; Estensione RIGHT: da left, o da middle orizzontale confermato
(defrule guess-extend-right (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (or
        (k-cell (x ?x) (y ?y) (content left))
        (and
            (k-cell (x ?x) (y ?y) (content middle))
            (or (k-cell (x ?x) (y =(- ?y 1)) (content middle | left))
                (k-cell (x ?x) (y =(+ ?y 1)) (content middle | right)))
        )
    )
    (test (< ?y 9))
    (not (k-cell (x ?x) (y =(+ ?y 1))))
    (not (exec (action guess) (x ?x) (y =(+ ?y 1))))
    (not (exec (action fire) (x ?x) (y =(+ ?y 1))))
    ?rr <- (k-per-row (row ?x) (num ?nr&:(> ?nr 0)))
    ?rc <- (k-per-col (col =(+ ?y 1)) (num ?nc&:(> ?nc 0)))
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y (+ ?y 1))))
    (modify ?rr (num (- ?nr 1)))
    (modify ?rc (num (- ?nc 1)))
    (printout t "GUESS extend RIGHT [" ?x "," (+ ?y 1) "]" crlf)
    (pop-focus)
)

;; Estensione UP: da bot, o da middle verticale confermato
(defrule guess-extend-up (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (or
        (k-cell (x ?x) (y ?y) (content bot))
        (and
            (k-cell (x ?x) (y ?y) (content middle))
            (or (k-cell (x =(+ ?x 1)) (y ?y) (content middle | bot))
                (k-cell (x =(- ?x 1)) (y ?y) (content middle | top)))
        )
    )
    (test (> ?x 0))
    (not (k-cell (x =(- ?x 1)) (y ?y)))
    (not (exec (action guess) (x =(- ?x 1)) (y ?y)))
    (not (exec (action fire) (x =(- ?x 1)) (y ?y)))
    ?rr <- (k-per-row (row =(- ?x 1)) (num ?nr&:(> ?nr 0)))
    ?rc <- (k-per-col (col ?y) (num ?nc&:(> ?nc 0)))
=>
    (assert (exec (step ?s) (action guess) (x (- ?x 1)) (y ?y)))
    (modify ?rr (num (- ?nr 1)))
    (modify ?rc (num (- ?nc 1)))
    (printout t "GUESS extend UP [" (- ?x 1) "," ?y "]" crlf)
    (pop-focus)
)

;; Estensione DOWN: da top, o da middle verticale confermato
(defrule guess-extend-down (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (or
        (k-cell (x ?x) (y ?y) (content top))
        (and
            (k-cell (x ?x) (y ?y) (content middle))
            (or (k-cell (x =(- ?x 1)) (y ?y) (content middle | top))
                (k-cell (x =(+ ?x 1)) (y ?y) (content middle | bot)))
        )
    )
    (test (< ?x 9))
    (not (k-cell (x =(+ ?x 1)) (y ?y)))
    (not (exec (action guess) (x =(+ ?x 1)) (y ?y)))
    (not (exec (action fire) (x =(+ ?x 1)) (y ?y)))
    ?rr <- (k-per-row (row =(+ ?x 1)) (num ?nr&:(> ?nr 0)))
    ?rc <- (k-per-col (col ?y) (num ?nc&:(> ?nc 0)))
=>
    (assert (exec (step ?s) (action guess) (x (+ ?x 1)) (y ?y)))
    (modify ?rr (num (- ?nr 1)))
    (modify ?rc (num (- ?nc 1)))
    (printout t "GUESS extend DOWN [" (+ ?x 1) "," ?y "]" crlf)
    (pop-focus)
)


;; ===================== SEZIONE 4: FIRE (salience 5) ==========================

;; =============================================================================
;; FIRE STRATEGICO - Esplorazione con score (nr + nc)
;; Salience 5: dopo guess certi e estensioni
;; =============================================================================

(defrule fire-best-cell (declare (salience 5))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (fires ?nf&:(> ?nf 0)))
    ;; Cella candidata
    (k-per-row (row ?r) (num ?nr&:(> ?nr 0)))
    (k-per-col (col ?c) (num ?nc&:(> ?nc 0)))
    (not (k-cell (x ?r) (y ?c)))
    (not (known-water ?r ?c))               ; esclusione celle dedotte come acqua
    (not (exec (action fire) (x ?r) (y ?c)))
    (not (exec (action guess) (x ?r) (y ?c)))
    ;; Nessuna cella libera con score migliore
    (not
        (and
            (k-per-row (row ?r2) (num ?nr2&:(> ?nr2 0)))
            (k-per-col (col ?c2) (num ?nc2&:(> ?nc2 0)))
            (test (> (+ ?nr2 ?nc2) (+ ?nr ?nc)))
            (not (k-cell (x ?r2) (y ?c2)))
            (not (known-water ?r2 ?c2))     ; esclusione celle dedotte come acqua 
            (not (exec (action fire) (x ?r2) (y ?c2)))
            (not (exec (action guess) (x ?r2) (y ?c2)))
        )
    )
=>
    (assert (exec (step ?s) (action fire) (x ?r) (y ?c)))
    (printout t "FIRE best [" ?r "," ?c "] score:" (+ ?nr ?nc) crlf)
    (pop-focus)
)


;; ===================== SEZIONE 5: GUESS FALLBACK (salience 3) ================

;; =============================================================================
;; GUESS FALLBACK - Speculativo, NON decrementa contatori
;; Salience 3: guess su celle promettenti ma non certe
;; NON modifica i contatori per evitare di corrompere le deduzioni
;; =============================================================================

(defrule guess-best-cell (declare (salience 3))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (fires 0) (guesses ?ng&:(> ?ng 0)))
    ;; Cella candidata
    (k-per-row (row ?r) (num ?nr&:(> ?nr 0)))
    (k-per-col (col ?c) (num ?nc&:(> ?nc 0)))
    (not (k-cell (x ?r) (y ?c)))
    (not (known-water ?r ?c))
    (not (exec (action fire) (x ?r) (y ?c)))
    (not (exec (action guess) (x ?r) (y ?c)))
    ;; Nessuna cella libera con score migliore
    (not
        (and
            (k-per-row (row ?r2) (num ?nr2&:(> ?nr2 0)))
            (k-per-col (col ?c2) (num ?nc2&:(> ?nc2 0)))
            (test (> (+ ?nr2 ?nc2) (+ ?nr ?nc)))
            (not (k-cell (x ?r2) (y ?c2)))
            (not (known-water ?r2 ?c2))
            (not (exec (action fire) (x ?r2) (y ?c2)))
            (not (exec (action guess) (x ?r2) (y ?c2)))
        )
    )
=>
    (assert (exec (step ?s) (action guess) (x ?r) (y ?c)))
    ;; NON decrementare - guess speculativo, potrebbe essere sbagliato
    (printout t "GUESS speculative [" ?r "," ?c "] score:" (+ ?nr ?nc) crlf)
    (pop-focus)
)


;; ===================== SEZIONE 6: SOLVE (salience -10) =======================

;; =============================================================================
;; SOLVE - Terminazione
;; Salience -10: quando nessun'altra regola può attivarsi
;; =============================================================================

(defrule solve-done (declare (salience -10))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
=>
    (assert (exec (step ?s) (action solve)))
    (printout t "SOLVE - nessuna mossa utile" crlf)
    (pop-focus)
)

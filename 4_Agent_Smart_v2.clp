;  ---------------------------------------------
;  --- Agente Smart per Battaglia Navale ---
;  ---------------------------------------------
(defmodule AGENT (import MAIN ?ALL) (import ENV ?ALL) (export ?ALL))

;; Note sull'Agente Smart:

; - Fa deduzioni acqua ad alta priorità (salience 20): zero su riga/colonna, diagonali dei pezzi noti, bordi attorno a top/bot/left/right/sub e lati dei middle orientati, riducendo le celle candidate.
; - Converte ogni k-cell di nave in guess certa (salience 10), decrementando i contatori riga/colonna.
; - Estende navi a una cella di distanza dai pezzi noti (salience 8) senza toccare i contatori: prova la casella adiacente coerente con l’orientamento (left/right/top/bot/middle).
; - Se restano fire, esegue una heuristica nr+nc (salience 5) evitando celle note, acqua nota o già pianificate.
; - Se finite le fire ma restano guess, fa guess speculative sempre con heuristica nr+nc (salience 3) senza toccare contatori.
; - Se nulla è applicabile, solve (salience -10).


;; ===================== SEZIONE 1: DEDUZIONE (salience 20) ====================

;; =============================================================================
;; DEDUZIONE ACQUA DA CONTATORI ZERO
;; Salience 20: si attiva prima di qualsiasi azione
;; Logica: se una riga/colonna ha num=0, tutte le sue celle sconosciute sono acqua
;; =============================================================================

;; Se riga ha 0 navi rimanenti, tutte le celle non-note di quella riga sono acqua
(defrule deduce-water-row-zero (declare (salience 20))
    (k-per-row (row ?x) (num 0))
    (k-per-col (col ?y))                        ; itera su tutte le colonne
    (not (k-cell (x ?x) (y ?y)))                ; cella non già nota
    (not (known-water ?x ?y))                   ; non già dedotta come acqua
    (not (guess ?x ?y))
    (not (exec (action guess) (x ?x) (y ?y)))   ; evitata cella pianificata per guess
    (not (exec (action fire) (x ?x) (y ?y)))    ; evitata cella pianificata per fire    
=>
    (assert (known-water ?x ?y))
    (printout t "DEDUCE water [" ?x "," ?y "] row " ?x " has 0 ships" crlf)
)

;; Se colonna ha 0 navi rimanenti, tutte le celle non-note di quella colonna sono acqua
(defrule deduce-water-col-zero (declare (salience 20))
    (k-per-col (col ?y) (num 0))
    (k-per-row (row ?x))
    (not (k-cell (x ?x) (y ?y)))
    (not (known-water ?x ?y))
    (not (guess ?x ?y))
    (not (exec (action guess) (x ?x) (y ?y)))
    (not (exec (action fire) (x ?x) (y ?y)))
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
    (not (guess =(- ?x 1) =(- ?y 1)))       ; non già guessato
=>
    (assert (known-water (- ?x 1) (- ?y 1)))
    (printout t "DEDUCE water [" (- ?x 1) "," (- ?y 1) "] diagonal of [" ?x "," ?y "]" crlf)
)

;; Diagonale alto-destra (x-1, y+1)
(defrule deduce-water-diag-up-right (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content top | bot | left | right | middle | sub))
    (test (and (> ?x 0) (< ?y 9)))
    (not (known-water =(- ?x 1) =(+ ?y 1)))
    (not (guess =(- ?x 1) =(+ ?y 1)))
=>
    (assert (known-water (- ?x 1) (+ ?y 1)))
    (printout t "DEDUCE water [" (- ?x 1) "," (+ ?y 1) "] diagonal of [" ?x "," ?y "]" crlf)
)

;; Diagonale basso-sinistra (x+1, y-1)
(defrule deduce-water-diag-down-left (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content top | bot | left | right | middle | sub))
    (test (and (< ?x 9) (> ?y 0)))
    (not (known-water =(+ ?x 1) =(- ?y 1)))
    (not (guess =(+ ?x 1) =(- ?y 1)))
=>
    (assert (known-water (+ ?x 1) (- ?y 1)))
    (printout t "DEDUCE water [" (+ ?x 1) "," (- ?y 1) "] diagonal of [" ?x "," ?y "]" crlf)
)

;; Diagonale basso-destra (x+1, y+1)
(defrule deduce-water-diag-down-right (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content top | bot | left | right | middle | sub))
    (test (and (< ?x 9) (< ?y 9)))
    (not (known-water =(+ ?x 1) =(+ ?y 1)))
    (not (guess =(+ ?x 1) =(+ ?y 1)))
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
    (not (guess =(- ?x 1) ?y))
=>
    (assert (known-water (- ?x 1) ?y))
    (printout t "DEDUCE water [" (- ?x 1) "," ?y "] above TOP" crlf)
)

;; Sotto BOT c'è sempre acqua
(defrule deduce-water-below-bot (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content bot))
    (test (< ?x 9))
    (not (known-water =(+ ?x 1) ?y))
    (not (guess =(+ ?x 1) ?y))
=>
    (assert (known-water (+ ?x 1) ?y))
    (printout t "DEDUCE water [" (+ ?x 1) "," ?y "] below BOT" crlf)
)

;; A sinistra di LEFT c'è sempre acqua
(defrule deduce-water-leftof-left (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content left))
    (test (> ?y 0))
    (not (known-water ?x =(- ?y 1)))
    (not (guess ?x =(- ?y 1)))
=>
    (assert (known-water ?x (- ?y 1)))
    (printout t "DEDUCE water [" ?x "," (- ?y 1) "] left of LEFT" crlf)
)

;; A destra di RIGHT c'è sempre acqua
(defrule deduce-water-rightof-right (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content right))
    (test (< ?y 9))
    (not (known-water ?x =(+ ?y 1)))
    (not (guess ?x =(+ ?y 1)))
=>
    (assert (known-water ?x (+ ?y 1)))
    (printout t "DEDUCE water [" ?x "," (+ ?y 1) "] right of RIGHT" crlf)
)

;; Intorno a SUB: sopra
(defrule deduce-water-above-sub (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content sub))
    (test (> ?x 0))
    (not (known-water =(- ?x 1) ?y))
    (not (guess =(- ?x 1) ?y))
=>
    (assert (known-water (- ?x 1) ?y))
    (printout t "DEDUCE water [" (- ?x 1) "," ?y "] above SUB" crlf)
)

;; Intorno a SUB: sotto
(defrule deduce-water-below-sub (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content sub))
    (test (< ?x 9))
    (not (known-water =(+ ?x 1) ?y))
    (not (guess =(+ ?x 1) ?y))
=>
    (assert (known-water (+ ?x 1) ?y))
    (printout t "DEDUCE water [" (+ ?x 1) "," ?y "] below SUB" crlf)
)

;; Intorno a SUB: sinistra
(defrule deduce-water-leftof-sub (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content sub))
    (test (> ?y 0))
    (not (known-water ?x =(- ?y 1)))
    (not (guess ?x =(- ?y 1)))
=>
    (assert (known-water ?x (- ?y 1)))
    (printout t "DEDUCE water [" ?x "," (- ?y 1) "] left of SUB" crlf)
)

;; Intorno a SUB: destra
(defrule deduce-water-rightof-sub (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content sub))
    (test (< ?y 9))
    (not (known-water ?x =(+ ?y 1)))
    (not (guess ?x =(+ ?y 1)))
=>
    (assert (known-water ?x (+ ?y 1)))
    (printout t "DEDUCE water [" ?x "," (+ ?y 1) "] right of SUB" crlf)
)

;; =============================================================================
;; DEDUZIONE ACQUA LATERALE A NAVI VERTICALI/ORIZZONTALI
;; Logica: i lati di una nave (non le estremità) sono acqua
;; =============================================================================

;; Middle orizzontale confermato: acqua a sinistra
(defrule deduce-water-left-of-hor-middle (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content middle))
    (k-cell (x =(+ ?x 1)) (y ?y) (content top | middle | bot))
    (k-cell (x =(- ?x 1)) (y ?y) (content top | middle | bot))
    (test (> ?y 0))
    (not (known-water ?x =(- ?y 1)))
    (not (guess ?x =(- ?y 1)))
=>
    (assert (known-water ?x (- ?y 1)))
    (printout t "DEDUCE water left of hor middle [" ?x "," ?y "]" crlf)
)

;; Middle orizzontale confermato: acqua a destra
(defrule deduce-water-right-of-hor-middle (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content middle))
    (k-cell (x =(+ ?x 1)) (y ?y) (content top | middle | bot))
    (k-cell (x =(- ?x 1)) (y ?y) (content top | middle | bot))
    (test (< ?y 9))
    (not (known-water ?x =(+ ?y 1)))
    (not (guess ?x =(+ ?y 1)))
=>
    (assert (known-water ?x (+ ?y 1)))
    (printout t "DEDUCE water right of hor middle [" ?x "," ?y "]" crlf)
)

;; Middle verticale confermato: acqua sopra
(defrule deduce-water-above-ver-middle (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content middle))
    (k-cell (x ?x) (y =(+ ?y 1)) (content left | middle | right))
    (k-cell (x ?x) (y =(- ?y 1)) (content left | middle | right))
    (test (> ?x 0))
    (not (known-water =(- ?x 1) ?y))
    (not (guess =(- ?x 1) ?y))
=>
    (assert (known-water (- ?x 1) ?y))
    (printout t "DEDUCE water above ver middle [" ?x "," ?y "]" crlf)
)

;; Middle verticale confermato: acqua sotto
(defrule deduce-water-below-ver-middle (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content middle))
    (k-cell (x ?x) (y =(+ ?y 1)) (content left | middle | right))
    (k-cell (x ?x) (y =(- ?y 1)) (content left | middle | right))
    (test (< ?x 9))
    (not (known-water =(+ ?x 1) ?y))
    (not (guess =(+ ?x 1) ?y))
=>
    (assert (known-water (+ ?x 1) ?y))
    (printout t "DEDUCE water below ver middle [" ?x "," ?y "]" crlf)
)

;; A sinistra di top/bot acqua
(defrule deduce-water-leftof-hor (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content top | bot))
    (test (> ?y 0))
    (not (known-water ?x =(- ?y 1)))
    (not (guess ?x =(- ?y 1)))
=>
    (assert (known-water ?x (- ?y 1)))
    (printout t "DEDUCE water [" ?x "," (- ?y 1) "] left of hor piece" crlf)
)

;; A destra di top/bot acqua
(defrule deduce-water-rightof-hor (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content top | bot))
    (test (< ?y 9))
    (not (known-water ?x =(+ ?y 1)))
    (not (guess ?x =(+ ?y 1)))
=>
    (assert (known-water ?x (+ ?y 1)))
    (printout t "DEDUCE water [" ?x "," (+ ?y 1) "] right of hor piece" crlf)
)

;; Sopra left/right acqua
(defrule deduce-water-above-ver (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content left | right))
    (test (> ?x 0))
    (not (known-water =(- ?x 1) ?y))
    (not (guess =(- ?x 1) ?y))
=>
    (assert (known-water (- ?x 1) ?y))
    (printout t "DEDUCE water [" (- ?x 1) "," ?y "] above ver piece" crlf)
)

;; Sotto left/right acqua
(defrule deduce-water-below-ver (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content left | right))
    (test (< ?x 9))
    (not (known-water =(+ ?x 1) ?y))
    (not (guess =(+ ?x 1) ?y))
=>
    (assert (known-water (+ ?x 1) ?y))
    (printout t "DEDUCE water [" (+ ?x 1) "," ?y "] below ver piece" crlf)
)

;; =============================================================================
;; DEDUZIONE ACQUA DA K-CELL WATER
;; Se l'ambiente rivela una k-cell acqua, la tratto come known-water
;; =============================================================================

(defrule deduce-water-from-kcell-water (declare (salience 20))
    (k-cell (x ?x) (y ?y) (content water))
    (not (known-water ?x ?y))
 =>
    (assert (known-water ?x ?y))
    (printout t "DEDUCE water [" ?x "," ?y "] k-cell water" crlf)
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


;; ===================== SEZIONE 3: ESTENSIONI (salience 8) ====================

;; =============================================================================
;; NUOVA SEZIONE 3 - ESTENSIONI CORRETTE (Senza errori di bind)
;; =============================================================================

;; --- MIDDLE VERTICALI ---

;; Se ho un middle e c'è qualcosa SOTTO, devo estendere SOPRA
(defrule guess-extend-middle-up (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (k-cell (x ?x) (y ?y) (content middle))
    ;; Evidenza sotto (x+1) -> estendo sopra (x-1)
    (or (k-cell (x =(+ ?x 1)) (y ?y) (content ~water)) (guess =(+ ?x 1) ?y))
    (test (> ?x 0))
    (not (k-cell (x =(- ?x 1)) (y ?y)))
    (not (known-water =(- ?x 1) ?y))
    (not (guess =(- ?x 1) ?y))
=>
    (assert (exec (step ?s) (action guess) (x (- ?x 1)) (y ?y)))
    (printout t "GUESS Smart Middle UP [" (- ?x 1) "," ?y "]" crlf)
    (pop-focus)
)

;; Se ho un middle e c'è qualcosa SOPRA, devo estendere SOTTO
(defrule guess-extend-middle-down (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (k-cell (x ?x) (y ?y) (content middle))
    ;; Evidenza sopra (x-1) -> estendo sotto (x+1)
    (or (k-cell (x =(- ?x 1)) (y ?y) (content ~water)) (guess =(- ?x 1) ?y))
    (test (< ?x 9))
    (not (k-cell (x =(+ ?x 1)) (y ?y)))
    (not (known-water =(+ ?x 1) ?y))
    (not (guess =(+ ?x 1) ?y))
=>
    (assert (exec (step ?s) (action guess) (x (+ ?x 1)) (y ?y)))
    (printout t "GUESS Smart Middle DOWN [" (+ ?x 1) "," ?y "]" crlf)
    (pop-focus)
)

;; --- MIDDLE ORIZZONTALI ---

;; Se ho un middle e c'è qualcosa a DESTRA, devo estendere a SINISTRA
(defrule guess-extend-middle-left (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (k-cell (x ?x) (y ?y) (content middle))
    ;; Evidenza destra (y+1) -> estendo sinistra (y-1)
    (or (k-cell (x ?x) (y =(+ ?y 1)) (content ~water)) (guess ?x =(+ ?y 1)))
    (test (> ?y 0))
    (not (k-cell (x ?x) (y =(- ?y 1))))
    (not (known-water ?x =(- ?y 1)))
    (not (guess ?x =(- ?y 1)))
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y (- ?y 1))))
    (printout t "GUESS Smart Middle LEFT [" ?x "," (- ?y 1) "]" crlf)
    (pop-focus)
)

;; Se ho un middle e c'è qualcosa a SINISTRA, devo estendere a DESTRA
(defrule guess-extend-middle-right (declare (salience 9))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (k-cell (x ?x) (y ?y) (content middle))
    ;; Evidenza sinistra (y-1) -> estendo destra (y+1)
    (or (k-cell (x ?x) (y =(- ?y 1)) (content ~water)) (guess ?x =(- ?y 1)))
    (test (< ?y 9))
    (not (k-cell (x ?x) (y =(+ ?y 1))))
    (not (known-water ?x =(+ ?y 1)))
    (not (guess ?x =(+ ?y 1)))
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y (+ ?y 1))))
    (printout t "GUESS Smart Middle RIGHT [" ?x "," (+ ?y 1) "]" crlf)
    (pop-focus)
)

;; --- ESTENSIONI TERMINALI (Sostituiscono guess-extend-terminal unica) ---

(defrule guess-extend-top-down (declare (salience 8))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (k-cell (x ?x) (y ?y) (content top))
    (test (< ?x 9))
    (not (k-cell (x =(+ ?x 1)) (y ?y)))
    (not (known-water =(+ ?x 1) ?y))
    (not (guess =(+ ?x 1) ?y))
=>
    (assert (exec (step ?s) (action guess) (x (+ ?x 1)) (y ?y)))
    (printout t "GUESS Ext TOP -> DOWN [" (+ ?x 1) "," ?y "]" crlf)
    (pop-focus)
)

(defrule guess-extend-bot-up (declare (salience 8))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (k-cell (x ?x) (y ?y) (content bot))
    (test (> ?x 0))
    (not (k-cell (x =(- ?x 1)) (y ?y)))
    (not (known-water =(- ?x 1) ?y))
    (not (guess =(- ?x 1) ?y))
=>
    (assert (exec (step ?s) (action guess) (x (- ?x 1)) (y ?y)))
    (printout t "GUESS Ext BOT -> UP [" (- ?x 1) "," ?y "]" crlf)
    (pop-focus)
)

(defrule guess-extend-left-right (declare (salience 8))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (k-cell (x ?x) (y ?y) (content left))
    (test (< ?y 9))
    (not (k-cell (x ?x) (y =(+ ?y 1))))
    (not (known-water ?x =(+ ?y 1)))
    (not (guess ?x =(+ ?y 1)))
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y (+ ?y 1))))
    (printout t "GUESS Ext LEFT -> RIGHT [" ?x "," (+ ?y 1) "]" crlf)
    (pop-focus)
)

(defrule guess-extend-right-left (declare (salience 8))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    (k-cell (x ?x) (y ?y) (content right))
    (test (> ?y 0))
    (not (k-cell (x ?x) (y =(- ?y 1))))
    (not (known-water ?x =(- ?y 1)))
    (not (guess ?x =(- ?y 1)))
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y (- ?y 1))))
    (printout t "GUESS Ext RIGHT -> LEFT [" ?x "," (- ?y 1) "]" crlf)
    (pop-focus)
)


;; --- SEGUI LA LINEA (Follow Line) ---

;; Verticale verso il basso
(defrule guess-follow-line-ver-down (declare (salience 8))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    ;; Trova due pezzi verticali adiacenti (x,y) e (x+1,y)
    (or (k-cell (x ?x) (y ?y) (content ~water)) (guess ?x ?y))
    (or (k-cell (x =(+ ?x 1)) (y ?y) (content ~water)) (guess =(+ ?x 1) ?y))
    ;; Prova a estendere a x+2
    (test (< ?x 8))
    (not (k-cell (x =(+ ?x 2)) (y ?y)))
    (not (known-water =(+ ?x 2) ?y))
    (not (guess =(+ ?x 2) ?y))
=>
    (assert (exec (step ?s) (action guess) (x (+ ?x 2)) (y ?y)))
    (printout t "GUESS Follow Line Ver DOWN [" (+ ?x 2) "," ?y "]" crlf)
    (pop-focus)
)

;; Verticale verso l'alto
(defrule guess-follow-line-ver-up (declare (salience 8))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    ;; Trova due pezzi verticali adiacenti (x,y) e (x+1,y)
    (or (k-cell (x ?x) (y ?y) (content ~water)) (guess ?x ?y))
    (or (k-cell (x =(+ ?x 1)) (y ?y) (content ~water)) (guess =(+ ?x 1) ?y))
    ;; Prova a estendere a x-1
    (test (> ?x 0))
    (not (k-cell (x =(- ?x 1)) (y ?y)))
    (not (known-water =(- ?x 1) ?y))
    (not (guess =(- ?x 1) ?y))
=>
    (assert (exec (step ?s) (action guess) (x (- ?x 1)) (y ?y)))
    (printout t "GUESS Follow Line Ver UP [" (- ?x 1) "," ?y "]" crlf)
    (pop-focus)
)

;; Orizzontale verso destra
(defrule guess-follow-line-hor-right (declare (salience 8))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    ;; Trova due pezzi orizzontali adiacenti (x,y) e (x,y+1)
    (or (k-cell (x ?x) (y ?y) (content ~water)) (guess ?x ?y))
    (or (k-cell (x ?x) (y =(+ ?y 1)) (content ~water)) (guess ?x =(+ ?y 1)))
    ;; Prova a estendere a y+2
    (test (< ?y 8))
    (not (k-cell (x ?x) (y =(+ ?y 2))))
    (not (known-water ?x =(+ ?y 2)))
    (not (guess ?x =(+ ?y 2)))
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y (+ ?y 2))))
    (printout t "GUESS Follow Line Hor RIGHT [" ?x "," (+ ?y 2) "]" crlf)
    (pop-focus)
)

;; Orizzontale verso sinistra
(defrule guess-follow-line-hor-left (declare (salience 8))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (moves (guesses ?ng&:(> ?ng 0)))
    ;; Trova due pezzi orizzontali adiacenti (x,y) e (x,y+1)
    (or (k-cell (x ?x) (y ?y) (content ~water)) (guess ?x ?y))
    (or (k-cell (x ?x) (y =(+ ?y 1)) (content ~water)) (guess ?x =(+ ?y 1)))
    ;; Prova a estendere a y-1
    (test (> ?y 0))
    (not (k-cell (x ?x) (y =(- ?y 1))))
    (not (known-water ?x =(- ?y 1)))
    (not (guess ?x =(- ?y 1)))
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y (- ?y 1))))
    (printout t "GUESS Follow Line Hor LEFT [" ?x "," (- ?y 1) "]" crlf)
    (pop-focus)
)

;; Se in una riga manca 1 nave e c'è solo 1 casella libera disponibile (non acqua nota, non k-cell), è lei!
(defrule guess-last-spot-row (declare (salience 12))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (k-per-row (row ?r) (num 1))
    ;; Trova una cella candidata
    (not (k-cell (x ?r) (y ?c)))
    (not (known-water ?r ?c))
    (not (guess ?r ?c))
    ;; Verifica che non ce ne siano altre nella stessa riga
    (not (and (test (neq ?c ?c2))
              (not (k-cell (x ?r) (y ?c2)))
              (not (known-water ?r ?c2))
              (not (guess ?r ?c2))))
=>
    (assert (exec (step ?s) (action guess) (x ?r) (y ?c)))
    (printout t "GUESS Last Spot in Row [" ?r "," ?c "]" crlf)
    (pop-focus)
)

;; Stessa cosa per la colonna
(defrule guess-last-spot-col (declare (salience 12))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (k-per-col (col ?c) (num 1))
    (not (k-cell (x ?r) (y ?c)))
    (not (known-water ?r ?c))
    (not (guess ?r ?c))
    (not (and (test (neq ?r ?r2))
              (not (k-cell (x ?r2) (y ?c)))
              (not (known-water ?r2 ?c))
              (not (guess ?r2 ?c))))
=>
    (assert (exec (step ?s) (action guess) (x ?r) (y ?c)))
    (printout t "GUESS Last Spot in Col [" ?r "," ?c "]" crlf)
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
    (k-per-row (row ?r) (num ?nr&:(> ?nr 0)))   ; righe con navi rimanenti
    (k-per-col (col ?c) (num ?nc&:(> ?nc 0)))   ; colonne con navi rimanenti
    (not (k-cell (x ?r) (y ?c)))                ; cella non ancora nota
    (not (known-water ?r ?c))                   ; esclusione celle dedotte come acqua
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
    (assert (exec (step ?s) (action fire) (x ?r) (y ?c)))
    (printout t "FIRE best [" ?r "," ?c "]" crlf)
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
    (printout t "GUESS speculative [" ?r "," ?c "]" crlf)
    (pop-focus)
)

;; ===================== SEZIONE 5B: SOLVE (salience -10) =======================

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

;; ===================== SEZIONE 6: UNGUESS RIPULITURA (salience 15) ===========

;; Se una cella è stata marcata acqua (known-water o k-cell water) e c'è un guess, ripulisce
(defrule unguess-on-water (declare (salience 15))
    (status (step ?s) (currently running))
    (not (exec (step ?s)))
    (guess ?x ?y)
    (or (known-water ?x ?y) (k-cell (x ?x) (y ?y) (content water)))
    (moves (guesses ?ng&:(< ?ng 20)))
=>
    (assert (exec (step ?s) (action unguess) (x ?x) (y ?y)))
    (printout t "UNGUESS su cella acqua [" ?x "," ?y "]" crlf)
    (pop-focus)
)

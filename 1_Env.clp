(defmodule ENV (import MAIN ?ALL) (export deftemplate k-cell k-per-row  k-per-col))

;; PARTE 1 - STRUTTURA DATI CHE RAPPRESENTA LA MAPPA 

;; definisce il contenuto di ogni cella della griglia di gioco (sconosciuto alll'agente)
;; es: (cell (x 3) (y 5) (content boat) (status none))   ; c'è una nave, non ancora scoperta
(deftemplate cell
	(slot x)
	(slot y)
	(slot content (allowed-values water boat hit-boat))
	(slot status (allowed-values none guessed fired missed))
)

;; definisce lo stato delle navi orizzontali
;; serve per capire quando una nave è affondata, altrimenti abbiamo solo riferimenti
;; alle singole celle ma non sappiamo "collegarle" per capire quando una nave è stata affondata
;; es: (boat-hor (name nav1) (x 5) (ys 2 3 4) (size 3) (status safe safe safe))
(deftemplate boat-hor
	(slot name)
	(slot x)
	(multislot ys)
	(slot size)
	(multislot status (allowed-values safe hit))
)

;; definisce lo stato delle navi verticali
;; es: (boat-ver (name nav2) (xs 1 2) (y 7) (size 2) (status safe safe))
(deftemplate boat-ver
	(slot name)
	(multislot xs)
	(slot y)
	(slot size)
	(multislot status (allowed-values safe hit))
)

;; definisce le celle con informazioni certe per l'agente
;; es: (k-cell (x 4) (y 5) (content left)) ;; cella certa con parte sinistra nave
(deftemplate k-cell 
	(slot x)
	(slot y)
	(slot content (allowed-values water left right middle top bot sub))
)

;; definisce il numero di navi conosciute per ogni riga
;; (k-per-row (row 3) (num 4))   ; nella riga 3 ci sono 4 celle con nave
(deftemplate k-per-row
	(slot row)
	(slot num)
)

;; definisce il numero di navi conosciute per ogni colonna
;; (k-per-row (row 3) (num 4))   ; nella riga 3 ci sono 4 celle con nave
(deftemplate k-per-col
	(slot col)
	(slot num)
)


;; PARTE 2 - REGOLE DI ESECUZIONE AZIONI ( fire, guess, unguess, solve) E CALCOLO PUNTEGGIO

;; esegue FIRE
(defrule action-fire 
	?us <- (status (step ?s) (currently running))	;; controlla che il gioco sia in esecuzione
	(exec (step ?s) (action fire) (x ?x) (y ?y))	;; prende l'azione da eseguire (fire)
	?mvs <- (moves (fires ?nf &:(> ?nf 0)))				;; controlla che ci siano mosse fire disponibili
=>
	(assert (fire ?x ?y))													;; crea fatto (fire ?x ?y) che attiverà le regole di simulazione
	(modify ?us (step (+ ?s 1)) )									;; incrementa contatore step
	(modify ?mvs (fires (- ?nf 1)))								;; decrementa contatore fire
)

;; esegue GUESS
(defrule action-guess
	?us <- (status (step ?s) (currently running))
	(exec (step ?s) (action guess) (x ?x) (y ?y))
	?mvs <- (moves (guesses ?ng &:(> ?ng 0)))
=>
	(assert (guess ?x ?y))
	(modify ?us (step (+ ?s 1)) )
	(modify ?mvs (guesses (- ?ng 1)))
)

;; esegue UNGUESS
(defrule action-unguess
	?us <- (status (step ?s) (currently running))
	(exec (step ?s) (action unguess) (x ?x) (y ?y))
	?gu <- (guess ?x ?y)														;; controlla che la cella sia guess (prima di fare ungess)
	?mvs <- (moves (guesses ?ng &:(< ?ng 20)))
=>	
	(retract ?gu)
	(modify ?us (step (+ ?s 1)) )
	(modify ?mvs (guesses (+ ?ng 1)))
)

;; esegue SOLVE
(defrule action-solve
	?us <- (status (step ?s) (currently running))
	(exec (step ?s) (action solve))
=>
	(assert (solve))
  (modify ?us (step (+ ?s 1)) (currently stopped) )
)

;; PARTE 3 - SIMULAZIONE EFFETTI DEL FIRE SULLA MAPPA

;; simula effetto di FIRE sulla mappa e aggiorna statistiche
(defrule fire-ok
	(fire ?x ?y)																							;; esegue fire
	?fc <- (cell (x ?x) (y ?y) (content boat) (status none))	;; controlla se c'è una nave non ancora scoperta (status none)
	?st <- (statistics (num_fire_ok ?fok))										;; prende statistiche per aggiornare num_fire_ok
=>
	(modify ?fc (content hit-boat) (status fired))						;; aggiorna il contenuto della cella e lo stato
  (modify ?st (num_fire_ok (+ ?fok 1)))											;; incrementa num_fire_ok
)

;; come prima ma per il caso di acqua (water)
(defrule fire-ko
	(fire ?x ?y)
	?fc <- (cell (x ?x) (y ?y) (content water) (status none))
	?st <- (statistics (num_fire_ko ?fko))
=>
	(modify ?fc (status missed))
  (modify ?st (num_fire_ko (+ ?fko 1)))
)

;; modifica lo stato di una nave "hor" dopo esser stata colpita
(defrule hit-boat-hor-trace
	(cell (x ?x) (y ?y) (content hit-boat))
	?b <- (boat-hor (x ?x) (ys $? ?y $?) (size ?s) (status $?prima safe $?dopo))
  (not (considered ?x ?y))
=>
	(modify ?b (status ?prima hit ?dopo))
  (assert (considered ?x ?y))
)

;; modifica lo stato di una nave "ver" dopo esser stata colpita
(defrule hit-boat-ver-trace
	(cell (x ?x) (y ?y) (content hit-boat))
  (not (considered ?x ?y))
	?b <- (boat-ver (xs $? ?x $?) (y ?y) (size ?s) (status $?prima safe $?dopo))
=>
	(modify ?b (status ?prima hit ?dopo))
  (assert (considered ?x ?y))
)

;; verifica se una nave orizzontale è affondata
(defrule sink-boat-hor

	(cell (x ?x) (y ?y) (content hit-boat))
	(boat-hor (name ?n) (x ?x) (ys $? ?y $?) (size ?s) (status $?ss))
        
	(or 
		(and (test (eq ?s 1))											;; caso in cui size nave è uguale a 1
		     (test (subsetp $?ss (create$ hit)))	;; verifica se lo stato ha tutti "hit" (nave affondata)
                )															;; subsetp verifica che tutti gli elementi di un insieme siano contenuti in un altro insieme

		(and (test (eq ?s 2))
		     (test (subsetp $?ss (create$ hit hit)))
                )

		(and (test (eq ?s 3))
		     (test (subsetp $?ss (create$ hit hit hit)))
                )

		(and (test (eq ?s 4))
		     (test (subsetp $?ss (create$ hit hit hit hit)))
                )
	)
=>
	(assert (sink-boat ?n))
)

;; verifica se una nave orizzontale è affondata
(defrule sink-boat-ver

	(cell (x ?x) (y ?y) (content hit-boat))
	(boat-ver (name ?n) (xs $? ?x $?) (y ?y) (size ?s) (status $?ss))
        
	(or 
		(and (test (eq ?s 1))
		     (test (subsetp $?ss (create$ hit)))
                )

		(and (test (eq ?s 2))
		     (test (subsetp $?ss (create$ hit hit)))
                )

		(and (test (eq ?s 3))
		     (test (subsetp $?ss (create$ hit hit hit)))
                )

		(and (test (eq ?s 4))
		     (test (subsetp $?ss (create$ hit hit hit hit)))
                )
	)
=>
	(assert (sink-boat ?n))
)


;; PARTE 4 - REGOLE DI VALUTAIONE FINALE
;; questo set di regole viene attivaot quando termina il gioco

;; incrementa contatore di guess ok
(defrule solve-count-guessed-ok
	(solve)
	(guess ?x ?y)
	?c <- (cell (x ?x) (y ?y) (content boat) (status none))
	?st <- (statistics (num_guess_ok ?gok))
=>
	(modify ?st (num_guess_ok (+ 1 ?gok)))
	(modify ?c (content hit-boat) (status guessed))
)

;; penalità: incrementa contatore di guess ko
(defrule solve-count-guessed-ko 
	(solve)
	(guess ?x ?y)
	?c <- (cell (x ?x) (y ?y) (content water) (status none))
	?st <- (statistics (num_guess_ko ?gko))
=>
	(modify ?st (num_guess_ko (+ 1 ?gko)))
	(modify ?c (status missed))
)

;; penalità: incrementa contatore di safe (navi non scoperte)
(defrule solve-count-safe 
	(solve)
	?c <-(cell (x ?x) (y ?y) (content boat) (status none))
	(not (guess ?x ?y))
	?st <- (statistics (num_safe ?saf))
=>
	(modify ?st (num_safe(+ 1 ?saf)))
	(modify ?c (status missed))
)

;; incrementa contatore di sink (navi affondate)
(defrule solve-sink-count
	(solve)
	?s <- (sink-boat ?n)
	(not (sink-checked ?n))
	?st <- (statistics (num_sink ?sink))
=>
	(modify ?st (num_sink (+ 1 ?sink)))
	(retract ?s)
	(assert (sink-checked ?n))
)

;; calcola il punteggio finale
(deffunction scoring (?fok ?fko ?gok ?gko ?saf ?sink ?nf ?ng)
	(- (+ (* ?gok 15) (* ?sink 20) )  (+ (* ?gko 10) (* ?saf 10) (* ?nf 20) (* ?ng 20) ))
)

;; regola finale che calcola e stampa il punteggio
(defrule solve-scoring (declare (salience -10)) ;; bassa priorità per essere l'ultima ad essere eseguita
	(solve)
	(statistics (num_fire_ok ?fok) (num_fire_ko ?fko) (num_guess_ok ?gok) (num_guess_ko ?gko) (num_safe ?saf) (num_sink ?sink))
	(moves (fires ?nf) (guesses ?ng))
=>
	(printout t "Your score is " (scoring ?fok ?fko ?gok ?gko ?saf ?sink ?nf ?ng) crlf)
)
	
;; PARTE 5 - REGOLE DI AGGIORNAMENTO DELLA MAPPA CONOSCENZA DELL'AGENTE

;; simula fire su celle già note (senza incrementare statistiche)
(defrule reset-map
	(k-cell (x ?x) (y ?y) (content ?c&:(neq ?c water)))	;; Trova una k-cell (?x, ?y) il cui contenuto ?c, non sia water
	?st <- (statistics (num_fire_ok ?fok))
	(not (resetted ?x ?y))
=>
	(assert (fire ?x ?y))
	(modify ?st (num_fire_ok (- ?fok 1))) ;; non contiamo come fire le posizioni note inizialmente
	(assert (resetted ?x ?y))
)

;; PARTE 6 - RIVELANO ALL'AGENTE COSA C'È NELLA CELLA DOPO UN FIRE
;; qua la priorità permette all'agente di controllare prima le regole più specifiche (sub, left, right, top, bot, middle)

;; SOTTOMARINO - nave sie 1
(defrule make-visible-sub (declare (salience 10))
	(fire ?x ?y)
	(cell (x ?x) (y ?y) (content boat))
	(boat-hor (x ?x) (ys ?y $?) (size 1))
	(not (k-cell (x ?x) (y ?y) ) )
=>
	(assert (k-cell (x ?x) (y ?y) (content sub)))
	(assert (resetted ?x ?y))
)

;; LEFT
(defrule make-visible-left (declare (salience 5))
	(fire ?x ?y)
	(cell (x ?x) (y ?y) (content boat))
	(boat-hor (x ?x) (ys ?y $?))
	(not (k-cell (x ?x) (y ?y) ))
=>
	(assert (k-cell (x ?x) (y ?y) (content left)))
	(assert (resetted ?x ?y))
)

;; RIGHT
(defrule make-visible-right (declare (salience 5))
	(fire ?x ?y)
	(cell (x ?x) (y ?y) (content boat))
	(boat-hor (x ?x) (ys $? ?y))
	(not (k-cell (x ?x) (y ?y)) )
=>
	(assert (k-cell (x ?x) (y ?y) (content right)))
	(assert (resetted ?x ?y))
)

;; TOP
(defrule make-visible-top (declare (salience 5))
	(fire ?x ?y)
	(cell (x ?x) (y ?y) (content boat))
	(boat-ver (y ?y) (xs ?x $?))
	(not (k-cell (x ?x) (y ?y) ) )
=>
	(assert (k-cell (x ?x) (y ?y) (content top)))
	(assert (resetted ?x ?y))
)
	
;; BOT
(defrule make-visible-bot (declare (salience 5))
	(fire ?x ?y)
	(cell (x ?x) (y ?y) (content boat))
	(boat-ver (y ?y) (xs $? ?x))
	(not (k-cell (x ?x) (y ?y) ) )
=>
	(assert (k-cell (x ?x) (y ?y) (content bot)))
	(assert (resetted ?x ?y))
)

;; MIDDLE
(defrule make-visible-middle (declare (salience 5))
	(fire ?x ?y)
	(cell (x ?x) (y ?y) (content boat))
	(not (k-cell (x ?x) (y ?y) ) )
=>
	(assert (k-cell (x ?x) (y ?y) (content middle)))
	(assert (resetted ?x ?y))
)

;; WATER
(defrule make-visible-water (declare (salience 5))
	(fire ?x ?y)
	(cell (x ?x) (y ?y) (content water))
	(not (k-cell (x ?x) (y ?y) ) )
=>
	(assert (k-cell (x ?x) (y ?y) (content water)))
	(assert (resetted ?x ?y))
)
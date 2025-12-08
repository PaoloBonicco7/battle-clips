# Battle Clips - Note di Progetto

## Indice
1. [Introduzione a CLIPS](#1-introduzione-a-clips)
2. [Architettura del Progetto](#2-architettura-del-progetto)
3. [Analisi dei File](#3-analisi-dei-file)
4. [Flusso di Esecuzione](#4-flusso-di-esecuzione)
5. [Conoscenza Disponibile all'Agente](#5-conoscenza-disponibile-allagente)
6. [Come Implementare l'Agente](#6-come-implementare-lagente)
7. [Strategie Suggerite](#7-strategie-suggerite)
8. [Comandi CLIPS Utili](#8-comandi-clips-utili)

---

## 1. Introduzione a CLIPS

### 1.1 Cos'e CLIPS?
CLIPS (C Language Integrated Production System) e un sistema esperto basato su regole.
Il paradigma e diverso dalla programmazione tradizionale: invece di scrivere sequenze di istruzioni,
si definiscono **fatti** (conoscenza) e **regole** (come reagire ai fatti).

### 1.2 Concetti Fondamentali

#### FATTI (Facts)
I fatti rappresentano la conoscenza del sistema. Possono essere:

**Fatti Ordinati (Ordered Facts)**
```clips
(fire 3 5)           ; fatto semplice con valori posizionali
(guess 2 4)          ; altro fatto ordinato
```

**Fatti Non Ordinati (Deftemplate)**
```clips
(deftemplate cell
    (slot x)
    (slot y)
    (slot content (allowed-values water boat hit-boat))
)

; Uso:
(cell (x 3) (y 5) (content water))
```

#### REGOLE (Rules)
Le regole hanno la struttura: SE (condizioni) ALLORA (azioni)

```clips
(defrule nome-regola
    (declare (salience 10))          ; priorita opzionale (default 0)
    ; --- PARTE SINISTRA (LHS) - Condizioni ---
    (fatto1 ?variabile)              ; match con variabile
    (fatto2 (slot ?val))             ; match su slot
    ?ptr <- (fatto3)                 ; cattura puntatore al fatto
    (test (> ?val 5))                ; test condizionale
    (not (fatto-negato))             ; negazione
=>
    ; --- PARTE DESTRA (RHS) - Azioni ---
    (assert (nuovo-fatto))           ; crea nuovo fatto
    (retract ?ptr)                   ; rimuove fatto
    (modify ?ptr (slot nuovo-valore)); modifica fatto
    (printout t "messaggio" crlf)    ; stampa
    (bind ?var valore)               ; assegna variabile
)
```

#### MODULI (Modules)
I moduli organizzano regole e fatti in namespace separati:

```clips
(defmodule AGENT
    (import MAIN ?ALL)    ; importa tutto da MAIN
    (import ENV ?ALL)     ; importa tutto da ENV
    (export ?ALL)         ; esporta tutto
)
```

Il comando `(focus MODULO)` attiva un modulo specifico.

### 1.3 Pattern Matching

```clips
?x                    ; qualsiasi valore, catturato in ?x
?                     ; qualsiasi valore, non catturato
$?                    ; zero o piu valori (multislot)
~valore               ; diverso da valore
?x&:(> ?x 5)          ; con constraint: ?x dove ?x > 5
?x&:(neq ?x val)      ; ?x diverso da val
valore1|valore2       ; OR tra valori
```

### 1.4 Ciclo di Esecuzione CLIPS
1. **Match**: trova tutte le regole le cui condizioni sono soddisfatte
2. **Conflict Resolution**: sceglie quale regola eseguire (salience, ordine)
3. **Execute**: esegue la parte destra della regola scelta
4. Ripete fino a quando non ci sono piu regole applicabili

---

## 2. Architettura del Progetto

### 2.1 Struttura dei File

```
battle-clips/
├── 0_Main.clp          # Modulo principale, orchestrazione
├── 1_Env.clp           # Ambiente (NON MODIFICARE)
├── 2_case1.clp         # Scenario di esempio (mappa)
├── 3_Agent.clp         # Agente placeholder (DA MODIFICARE/SOSTITUIRE)
├── case1_obs_2.clp     # Scenario con alcune celle note
├── case1_no_obs.clp    # Scenario senza celle note iniziali
├── mapEnvironment.clp  # Altro scenario
├── go.bat / go_new.bat # Script di avvio
├── clips               # Eseguibile CLIPS
├── map_editor/         # Editor per creare nuove mappe
└── notes/              # Esempi di agenti
    ├── agente_avanzato.clp
    └── agente_probabilistico.clp
```

### 2.2 I Tre Moduli

```
┌─────────────────────────────────────────────────────────────┐
│                         MAIN                                 │
│  - Orchestrazione del gioco                                 │
│  - Passa il controllo tra ENV e AGENT                       │
│  - Gestisce lo step corrente e lo stato del gioco           │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│          ENV            │     │         AGENT           │
│  - Simula l'ambiente    │     │  - Il tuo sistema       │
│  - Esegue le azioni     │     │    esperto              │
│  - Calcola il punteggio │     │  - Decide le azioni     │
│  - NON MODIFICARE       │     │  - DA IMPLEMENTARE      │
└─────────────────────────┘     └─────────────────────────┘
```

---

## 3. Analisi dei File

### 3.1 `0_Main.clp` - Modulo Principale

**Template definiti:**
```clips
(deftemplate exec           ; Azione da eseguire
   (slot step)              ; A quale step
   (slot action             ; Tipo di azione
       (allowed-values fire guess unguess solve))
   (slot x)                 ; Coordinata x
   (slot y)                 ; Coordinata y
)

(deftemplate status         ; Stato del gioco
    (slot step)             ; Step corrente
    (slot currently         ; running o stopped
        (allowed-values running stopped))
)

(deftemplate moves          ; Mosse disponibili
    (slot fires)            ; Fire rimanenti (iniziale: 5)
    (slot guesses)          ; Guess attivi (max: 20)
)

(deftemplate statistics     ; Statistiche per punteggio
    (slot num_fire_ok)
    (slot num_fire_ko)
    (slot num_guess_ok)
    (slot num_guess_ko)
    (slot num_safe)
    (slot num_sink)
)
```

**Flusso di controllo:**
```
┌──────────────────────────────────────────────────────────────────┐
│                    FLUSSO DI ESECUZIONE                         │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. (reset) → carica deffacts iniziali                          │
│       ↓                                                          │
│  2. first-pass-to-env → focus su ENV                            │
│       ↓                                                          │
│  3. ENV inizializza k-cell visibili                             │
│       ↓                                                          │
│  4. go-on-agent: focus su AGENT (step < 100, running)           │
│       ↓                                                          │
│  5. AGENT asserisce (exec (step S) (action ...) ...)            │
│       ↓                                                          │
│  6. AGENT chiama (pop-focus) → torna a MAIN                     │
│       ↓                                                          │
│  7. go-on-env: c'e un exec per step corrente → focus ENV        │
│       ↓                                                          │
│  8. ENV esegue l'azione e aggiorna stato                        │
│       ↓                                                          │
│  9. Torna a punto 4 (fino a solve o step 100)                   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 3.2 `1_Env.clp` - Ambiente (NON MODIFICARE)

**Template per la conoscenza dell'agente (esportati):**
```clips
(deftemplate k-cell         ; Cella NOTA all'agente
    (slot x)
    (slot y)
    (slot content           ; Cosa contiene
        (allowed-values water left right middle top bot sub))
)

(deftemplate k-per-row      ; Navi in questa riga
    (row)                   ; Numero riga (0-9)
    (num)                   ; Quante celle nave
)

(deftemplate k-per-col      ; Navi in questa colonna
    (col)                   ; Numero colonna (0-9)
    (num)                   ; Quante celle nave
)
```

**Significato dei contenuti k-cell:**
```
water  = acqua
sub    = sottomarino (nave da 1)
left   = estremita sinistra di nave orizzontale
right  = estremita destra di nave orizzontale
top    = estremita superiore di nave verticale
bot    = estremita inferiore di nave verticale
middle = pezzo centrale (puo essere verticale O orizzontale)
```

**Template interni ENV (non accessibili):**
```clips
(deftemplate cell           ; Stato REALE della cella
    (slot x)
    (slot y)
    (slot content (allowed-values water boat hit-boat))
    (slot status (allowed-values none guessed fired missed))
)

(deftemplate boat-hor       ; Nave orizzontale
    (slot name)
    (slot x)
    (multislot ys)          ; colonne occupate
    (slot size)
    (multislot status)      ; safe/hit per ogni pezzo
)

(deftemplate boat-ver       ; Nave verticale
    (slot name)
    (multislot xs)          ; righe occupate
    (slot y)
    (slot size)
    (multislot status)
)
```

### 3.3 File Scenario (es. `case1_obs_2.clp`)

Contiene:
1. **Tutte le celle reali** (`cell`) - stato nascosto all'agente
2. **Definizione navi** (`boat-hor`, `boat-ver`)
3. **Celle inizialmente note** (`k-cell`) - visibili all'agente
4. **Conteggi per riga/colonna** (`k-per-row`, `k-per-col`)

Esempio da `case1_obs_2.clp`:
```clips
; Alcune celle sono note fin dall'inizio
(k-cell (x 4) (y 1) (content water))     ; Sappiamo che [4,1] e acqua
(k-cell (x 6) (y 4) (content middle))    ; Sappiamo che [6,4] e parte di nave

; Conteggi (SEMPRE forniti)
(k-per-row (row 0) (num 0))  ; Riga 0: 0 celle nave
(k-per-row (row 1) (num 2))  ; Riga 1: 2 celle nave
...
(k-per-col (col 4) (num 5))  ; Colonna 4: 5 celle nave
```

---

## 4. Flusso di Esecuzione

### 4.1 Come l'Agente Deve Comportarsi

L'agente viene attivato da MAIN con `(focus AGENT)`.
Deve:
1. Analizzare i fatti disponibili (`k-cell`, `k-per-row`, `k-per-col`)
2. Decidere UN'AZIONE da eseguire
3. Asserire il fatto `exec` con l'azione scelta
4. Chiamare `(pop-focus)` per restituire il controllo

**Esempio minimo di regola agente:**
```clips
(defrule mia-azione
    (status (step ?s) (currently running))
    ; ... altre condizioni ...
=>
    (assert (exec (step ?s) (action fire) (x 3) (y 5)))
    (pop-focus)
)
```

### 4.2 Le Quattro Azioni

| Azione | Descrizione | Vincoli |
|--------|-------------|---------|
| `fire x y` | Rivela contenuto cella [x,y] | Max 5 totali |
| `guess x y` | Ipotizza nave in [x,y] | Max 20 contemporanei |
| `unguess x y` | Rimuove guess da [x,y] | Solo su celle guessed |
| `solve` | Termina il gioco | Finale |

### 4.3 Cosa Succede Dopo Ogni Azione

**Dopo `fire x y`:**
- Se c'e nave: viene creato `(k-cell (x X) (y Y) (content TIPO))`
- Se c'e acqua: viene creato `(k-cell (x X) (y Y) (content water))`
- Il contatore `fires` in `moves` diminuisce

**Dopo `guess x y`:**
- Viene creato il fatto `(guess X Y)` nell'ENV
- Il contatore `guesses` in `moves` diminuisce

**Dopo `unguess x y`:**
- Il fatto `(guess X Y)` viene rimosso
- Il contatore `guesses` aumenta

---

## 5. Conoscenza Disponibile all'Agente

### 5.1 Fatti Accessibili

L'agente puo vedere (attraverso import):

```clips
; Da MAIN:
(status (step ?s) (currently running|stopped))
(moves (fires ?nf) (guesses ?ng))
(exec ...)  ; azioni gia eseguite

; Da ENV (esportati):
(k-cell (x ?x) (y ?y) (content ?c))    ; celle note
(k-per-row (row ?r) (num ?n))          ; conteggio per riga
(k-per-col (col ?c) (num ?n))          ; conteggio per colonna
```

### 5.2 Informazioni Deducibili

Dalle `k-cell` puoi dedurre:
- Se `content = sub` → nave completa da 1 cella
- Se `content = left` → nave continua a DESTRA (y+1, y+2, ...)
- Se `content = right` → nave continua a SINISTRA (y-1, y-2, ...)
- Se `content = top` → nave continua in BASSO (x+1, x+2, ...)
- Se `content = bot` → nave continua in ALTO (x-1, x-2, ...)
- Se `content = middle` → nave continua in DUE direzioni (ambiguo!)

Dai conteggi:
- Se `k-per-row (row R) (num 0)` → tutta la riga R e acqua
- Se `k-per-col (col C) (num 0)` → tutta la colonna C e acqua

---

## 6. Come Implementare l'Agente

### 6.1 Struttura Consigliata

```clips
(defmodule AGENT (import MAIN ?ALL) (import ENV ?ALL) (export ?ALL))

; ============ TEMPLATE PROPRI ============
(deftemplate mia-cella      ; Stato interno dell'agente
    (slot x)
    (slot y)
    (slot stato             ; unknown, water, boat, guessed
        (allowed-values unknown water boat guessed))
)

; ============ FATTI INIZIALI ============
(deffacts inizializzazione
    ; Griglia 10x10 inizialmente sconosciuta
    ; Puoi generarla o scriverla esplicitamente
)

; ============ REGOLE DI INFERENZA ============
; Salience alta: si eseguono prima, NON generano azioni

(defrule propaga-conoscenza (declare (salience 100))
    ; Aggiorna stato interno basandosi su k-cell
    ...
=>
    ; Modifica mia-cella
)

; ============ REGOLE DI AZIONE ============
; Salience decrescente per priorita

(defrule azione-sicura (declare (salience 50))
    ; Quando sono CERTO che una cella ha una nave
    (status (step ?s) (currently running))
    ...
=>
    (assert (exec (step ?s) (action guess) (x ?x) (y ?y)))
    (pop-focus)
)

(defrule azione-esplorazione (declare (salience 30))
    ; Quando devo esplorare
    (status (step ?s) (currently running))
    (moves (fires ?nf&:(> ?nf 0)))
    ...
=>
    (assert (exec (step ?s) (action fire) (x ?x) (y ?y)))
    (pop-focus)
)

(defrule termina (declare (salience -100))
    ; Fallback finale
    (status (step ?s) (currently running))
=>
    (assert (exec (step ?s) (action solve)))
    (pop-focus)
)
```

### 6.2 Pattern Utili

**Trovare la riga/colonna con piu navi:**
```clips
(k-per-row (row ?r) (num ?n))
(not (k-per-row (row ?r2&:(neq ?r2 ?r)) (num ?n2&:(> ?n2 ?n))))
```

**Verificare che non ho gia fatto un'azione:**
```clips
(not (exec (action fire|guess) (x ?x) (y ?y)))
```

**Cella adiacente:**
```clips
(k-cell (x ?x) (y ?y) (content top))
; Cella sotto:
(my-cell (x =(+ ?x 1)) (y ?y) ...)
```

### 6.3 Errori Comuni da Evitare

1. **Dimenticare `(pop-focus)`** - Il controllo non torna a MAIN
2. **Non controllare i limiti** - `fires` e `guesses` hanno limiti
3. **Asserire azioni duplicate** - Controllare con `(not (exec ...))`
4. **Non gestire `middle`** - E ambiguo, puo essere hor o ver
5. **Superare 20 guess attivi** - Usare `unguess` se necessario

---

## 7. Strategie Suggerite

### 7.1 Strategia Base (Semplice)
1. Fare guess su tutte le k-cell note che sono navi
2. Usare i conteggi per escludere righe/colonne vuote
3. Fare guess random sulle celle rimanenti

### 7.2 Strategia Intermedia
1. Come base, piu:
2. Propagare vincoli (es. se `middle` e adiacente a `water` in una direzione, deve estendersi nell'altra)
3. Usare `fire` per risolvere ambiguita su `middle`
4. Prioritizzare righe/colonne con piu navi

### 7.3 Strategia Avanzata
1. Mantenere stato interno completo
2. Calcolare probabilita per ogni cella
3. Considerare la composizione della flotta (1x4, 2x3, 3x2, 4x1)
4. Usare vincoli di adiacenza (navi separate da almeno 1 cella)
5. Backtracking con `unguess` se necessario

### 7.4 Confronto Strategia (Richiesto)

Il progetto richiede **almeno 2 strategie diverse**. Suggerimenti:

| Strategia A | Strategia B |
|-------------|-------------|
| Greedy sui conteggi | Probabilistica |
| Usa tutti i fire subito | Conserva fire |
| Nessun unguess | Usa unguess per correggere |
| Solo regole semplici | Inferenza complessa |

---

## 8. Comandi CLIPS Utili

### 8.1 Esecuzione

```clips
; Caricamento
(load "0_Main.clp")
(load "1_Env.clp")
(load "case1_obs_2.clp")
(load "3_Agent.clp")

; Inizializzazione
(reset)                    ; Carica tutti i deffacts

; Esecuzione
(run)                      ; Esegue fino alla fine
(run 10)                   ; Esegue 10 step
(step)                     ; Esegue 1 step
```

### 8.2 Debug

```clips
(facts)                    ; Mostra tutti i fatti
(facts AGENT)              ; Fatti del modulo AGENT
(rules)                    ; Mostra tutte le regole
(agenda)                   ; Mostra regole attivabili
(watch facts)              ; Traccia cambiamenti fatti
(watch rules)              ; Traccia esecuzione regole
(watch activations)        ; Traccia attivazioni
(unwatch all)              ; Disabilita tracciamento
```

### 8.3 Breakpoint

```clips
(set-break nome-regola)    ; Ferma prima di questa regola
(remove-break nome-regola) ; Rimuove breakpoint
```

### 8.4 Script di Avvio (go.bat)

```clips
(load 0_Main.clp)
(load 1_Env.clp)
(load case1_obs_2.clp)   ; Cambia scenario qui
(load 3_Agent.clp)       ; Cambia agente qui
(reset)
(run)
```

---

## Appendice: Formula Punteggio

```
Punteggio = (15 * guess_ok + 20 * sink) - (10 * guess_ko + 10 * safe + 20 * fire_non_usati + 20 * guess_non_usati)
```

Dove:
- `guess_ok`: celle guessed che contengono nave
- `sink`: navi completamente affondate (tutti i pezzi hit/guessed)
- `guess_ko`: celle guessed che contengono acqua
- `safe`: celle nave non toccate (ne fired ne guessed)
- `fire_non_usati`: fire rimasti (su 5)
- `guess_non_usati`: guess rimasti (su 20)

**Obiettivo**: Massimizzare guess corretti e navi affondate, minimizzare errori e risorse non usate.

---

## TODO per il Progetto

- [ ] Studiare gli agenti di esempio in `notes/`
- [ ] Implementare strategia base
- [ ] Implementare strategia avanzata
- [ ] Testare con diversi scenari (case1, no_obs, mapEnvironment)
- [ ] Creare nuovi scenari con map_editor
- [ ] Confrontare punteggi delle strategie
- [ ] Documentare limiti e comportamento senza celle note iniziali

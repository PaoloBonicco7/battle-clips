# battle-clips

Simulazione single-player della battaglia navale, pensata per confrontare diversi approcci basati su sistemi a regole in CLIPS.

## Run

### Agente Naive

```clips
(batch go_naive.bat)
```

### Agente Smart

```clips
(batch go_smart.bat)
```

### Agente Debug

```clips
(batch go_debug.bat)
```

> Per cambiare la mappa basta modificare il file `go_*.bat` impostando il nome della mappa che si vuole testare.

## Struttura

### `map_editor/`

Script Java per la generazione assistita delle mappe.

### `maps/`

Mappe di gioco con le rispettive configurazioni note.

| File       | Navi    | Celle note iniziali | Difficoltà |
|-----------|---------|---------------------|------------|
| map_1.clp | 10 navi | 4 k-cell            | Facile     |
| map_2.clp | 10 navi | 2 k-cell            | Medio      |
| map_3.clp | 10 navi | 0 k-cell            | Difficile  |
| map_1b.clp| 10 navi | 4 k-cell            | Facile     |
| map_2b.clp| 10 navi | 2 k-cell            | Medio      |
| map_3b.clp| 10 navi | 0 k-cell            | Difficile  |

### `run_scripts/`

Script per eseguire rapidamente gli agenti e cambiare configurazioni di test.

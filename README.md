# FSZP

Space shooter in prima persona, stile Elite (8-bit era), realizzato in Godot 4.6.

## Stato attuale

### Movimento
- Player come `Node3D` (non RigidBody3D — abbandonato per conflitti con Jolt Physics) con integrazione manuale della velocità.
- Controllo 6DOF stile Elite: mouse per beccheggio/imbardata, WASD che replica gli assi del mouse, Q/E per il rollio.
- Q/Z (Su/Giù) per la spinta, con inerzia.
- FOV 60° (fedele all'originale Elite).

### Armi
- **Cannone** (Spazio / click sinistro): fuoco diretto a cadenza regolare.
- **Missili a ricerca** (4 in dotazione): tasto **R** per puntare — il bersaglio deve restare nel mirino per 3 secondi per ottenere il lock (indicatore lampeggiante con arco di progresso, poi "LOCKED"). Il lock resta attivo anche rilasciando R. Tasto **F** per lanciare. Il missile insegue il bersaglio con guida fluida (slerp) a velocità costante.
- **Missili nucleari** (2 in dotazione): stesso meccanismo di puntamento/lancio dei missili normali, tasti **Y** (lock) e **H** (lancio). Distruggono istantaneamente il bersaglio bloccato e tutte le navi nemiche/asteroidi entro un raggio di 50 unità.
- HUD munizioni: contatori "MSL" e "NUKE" in basso a sinistra, accanto agli scudi.

### Scudi
- 4 barre direzionali (Left / Front / Back / Right) in basso a sinistra.
- Il danno viene applicato al settore corrispondente alla direzione di provenienza del proiettile rispetto alla prua della nave.
- Ricarica lenta automatica dopo un breve periodo senza colpi subiti.

### Nemici — Navi pirata
- Macchina a stati: IDLE → APPROACH → ATTACK → RETREAT (ciclo).
- Hanno scafo con 3 punti vita; danneggiamento progressivo mostrato con scurimento del colore e una scia di fumo grigio proporzionale al danno.
- Alla distruzione rilasciano un container recuperabile.
- 5 navi pirata generate per livello (asteroidi attualmente a zero spawn — sostituiti dai pirati come minaccia principale).

### Raggio traente
- Tasto **T**: attrae il container più vicino entro 60 unità con un fascio visivo (ImmediateMesh).
- Una volta raggiunto, il container viene raccolto automaticamente.

### HUD
- Radar 3D in stile Elite (disco ellittico inclinato, linee verticali per l'altitudine, punti colorati per i bersagli) in basso a destra.
- Mirino di puntamento missili/nuke al centro schermo, con indicatore persistente (rombo + distanza) sul bersaglio agganciato.
- Barre scudi e contatori munizioni in basso a sinistra.

### Asteroidi (sistema esistente, non attivo di default)
- Sfere con leggera variazione cromatica e drift.
- Generazione 0 → colpiti si dividono in 2 figli (generazione 1) con drift casuale divergente; i figli esplodono senza ulteriore divisione.

## Comandi

| Azione | Tasto |
|---|---|
| Beccheggio/imbardata | Mouse / WASD |
| Rollio | Q / E |
| Spinta su / giù | Freccia Su / Freccia Giù |
| Fuoco cannone | Spazio / click sinistro |
| Lock missile | R |
| Lancio missile | F |
| Lock missile nucleare | Y |
| Lancio missile nucleare | H |
| Raggio traente | T |
| Rilascia mouse | Esc |

## Prossimi passi
- Introdurre asset 3D dedicati (modelli per nave player, navi pirata, asteroidi, missili) in sostituzione delle primitive geometriche attuali.
- Comportamento IA pirata più elaborato e imprevedibile.
- Drop casuale dei container (attualmente garantito a ogni uccisione).

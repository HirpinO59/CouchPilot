# CouchPilot

> [Read this in English](README.md)

App macOS in menu bar: colleghi un controller — Xbox, DualSense o qualunque pad riconosciuto da macOS — e comandi il Mac dal divano: cursore, click, scroll, volume, Mission Control. Scritta in Swift, zero dipendenze esterne.

<p align="center">
  <img src="docs/images/demo.gif" width="640" alt="YouTube, Mission Control e cambio app col controller">
</p>

**Versione 1.0.0.** Questo è il documento tecnico completo; il [README inglese](README.md) è la vetrina per gli utenti.

## Build e avvio

```bash
./build.sh install   # compila e installa in /Applications (./build.sh da solo compila e basta)
```

Lo script compila con SPM, assembla `build/CouchPilot.app` e firma con l'identità Apple Development trovata nel Keychain (stabile → il permesso Accessibilità resta valido tra le build). Identità diversa: `COUCHPILOT_SIGN_ID="..." ./build.sh`.

**Primo avvio:** macOS chiede il permesso Accessibilità. Concedilo in Impostazioni di Sistema → Privacy e Sicurezza → Accessibilità (l'icona in menu bar mostra ⚠️ finché manca; c'è la voce di menu che apre il pannello giusto). Dopo la concessione non serve riavviare l'app.

## Mappatura

| Input | Azione |
|---|---|
| Stick sinistro | Movimento cursore — configurabile |
| A | Click sinistro (tieni premuto = drag) |
| X | Click destro |
| Stick destro | Scroll verticale/orizzontale — configurabile |
| Menu (☰) da solo | Apre il menu di CouchPilot in barra — fisso, non riassegnabile |
| View (⧉) + Menu (☰) **insieme, 2 s** | Attiva/disattiva CouchPilot, nei due sensi |
| B | Mission Control |
| Y | Play/Pausa |
| D-pad su/giù | Volume + / − (tieni premuto per ripetere) — configurabile |
| D-pad sx/dx | Traccia precedente / successiva — configurabile |
| LB / RB | Space precedente / successivo |
| View (⧉) da solo | Mostra Scrivania — configurabile. Scatta al rilascio, così non parte quando View serve al comando di accensione |
| R2 (tenuto) | Precisione: cursore e scroll a ¼ della velocità |
| L2 (tenuto) | Turbo: velocità ×2 |
| L3 (pressione stick sx) | Configurabile — default: Mute |
| R3 (pressione stick dx) | Configurabile — default: Click centrale |

Mission Control, Spaces e Scrivania usano la scorciatoia configurata nelle impostazioni del Mac (letta a ogni pressione da `com.apple.symbolichotkeys`, con fallback sui default): se le rimappi, l'app si adegua.

Le assegnazioni non si scelgono da un elenco fisso: si **registrano**. In "Assegnazione tasti" ogni tasto offre le tre scelte più sensate per quel tasto, e sotto c'è "Registra input…" — si preme un tasto, una combinazione o un pulsante del mouse e l'app lo copia tale e quale. Ciò che viene registrato è salvato come codice di tasto, non come lettera, quindi resta lo stesso su qualunque disposizione di tastiera.

La cattura usa un tap sugli eventi (`InputCapture.swift`), attivo e non solo in ascolto: serve per intercettare anche i tasti multimediali (volume, play, luminosità), che il sistema non consegna alle app come normali eventi di tastiera, e per evitare che premerli durante la registrazione cambi davvero il volume. Il tap si spegne da solo alla chiusura della finestra, quando la finestra perde il fuoco e comunque dopo 20 secondi.

Attivazione automatica alla connessione del pad, disattivazione alla disconnessione (con rilascio dei pulsanti se eri a metà drag).

## Menu

In cima al menu c'è il controller collegato con un **indicatore di batteria in stile macOS**: guscio, riempimento proporzionale e percentuale ritagliata dentro ([BatteryIcon.swift](Sources/CouchPilot/BatteryIcon.swift), disegnato con CoreGraphics come template image, così si tinge da sé in tema chiaro e scuro). Si aggiorna all'apertura del menu, al massimo una lettura ogni 30 secondi. I pad che non espongono il dato mostrano solo il nome.

Da dove arriva il dato: `GCController.battery` è la via ufficiale e funziona su DualSense e simili, ma **sui pad Xbox via Bluetooth riporta livello 0 e stato sconosciuto** (verificato su macOS 26). Il livello reale sta nello stack Bluetooth e si legge con `system_profiler SPBluetoothDataType -json` (~0,2 s), eseguito fuori dal thread principale. L'app prova prima la via ufficiale e ripiega sulla seconda.

- **Attivo** — toggle on/off (equivale a View + Menu tenuti insieme 2 secondi)
- **Assegnazione tasti** — schermata con il disegno del pad collegato e, per ogni comando, il valore assegnato: si clicca il valore, si prende uno dei tre suggerimenti o si registra un input nuovo, diventa giallo e si salva. In alto il titolo e l'intestazione coi comandi fissi (R2 precisione, L2 turbo, accensione), coi nomi veri dei tasti del pad collegato: View/Menu su Xbox, Create/Options su DualSense. Tutti i tasti sono riassegnabili tranne i due centrali, riservati al comando di accensione. Ci sono anche i due stick, con la pressione (L3/R3) e il **movimento** separati: il movimento sceglie fra cursore, scorrimento e niente. **View** (Create sul DualSense) ha la didascalia sopra il disegno, con la linea che sale dritta: sta al centro del pad e non appartiene a nessuna delle due colonne
- **Guida rapida** — tre schede, mostrate una sola volta al primo avvio e richiamabili da qui, con Indietro/Avanti in basso. La prima presenta l'app con i pulsanti Invia feedback e Buy Me a Coffee (Ko-fi), e — **solo se il permesso Accessibilità manca** — lo spiega con un pulsante che apre il pannello giusto; appena il permesso arriva la scheda diventa da sola una conferma (`PermissionsGate.granted`, agganciata al polling che l'app fa già ogni 2 s). A chi l'ha già concesso l'istruzione non viene mostrata, e c'è la spunta per l'avvio al login. **La seconda è solo la dimostrazione**: nessun titolo, nessuna scritta, un filmato in riproduzione continua, muto e senza comandi (`Resources/welcome2.mp4`, 1280×720, 30 fps, ~2 Mbps — un video e non una GIF: a parità di peso ha il triplo dei pixel e il triplo dei fotogrammi). La terza è l'assegnazione tasti
- **Calibra stick** — campiona 2 secondi a stick fermi e salva l'offset di riposo (per il drift)
- **Impostazioni** — tutta la configurazione in un posto solo, effetto immediato:
  - parametri a preset: velocità cursore e scroll, deadzone, curva di risposta, fattori R2/L2 (le stesse chiavi restano regolabili a valori arbitrari via `defaults write`, tabella sotto);
  - **Disattiva nelle app** — elenco di app con cui l'app si mette in pausa da sola quando sono in primo piano (precaricate: GeForce Now e Steam). "Aggiungi app…" apre un selettore sulla cartella Applicazioni (si possono scegliere più app insieme); per togliere un'esclusione, clicca il suo nome nell'elenco. In pausa il pad resta tutto al gioco, ☰ compreso;
  - **Pausa automatica nei giochi** — pausa su qualsiasi app che si dichiara "gioco" nell'Info.plist (`LSApplicationCategoryType`): lo stesso criterio con cui macOS attiva la modalità gioco, ma vale anche in finestra. I giochi che non si dichiarano si aggiungono a mano con "Disattiva nelle app";
  - **Lingua** — italiano, inglese, spagnolo, cinese semplificato, o **Automatica** (segue la lingua di sistema; se non è tra quelle tradotte, inglese). Il menu si ricostruisce all'istante, senza riavviare;
  - **Ripristina predefiniti**.
- **Avvia al login** — login item via `SMAppService`
- **Segnala un problema o un'idea…** — apre su GitHub una segnalazione già impostata: le tre domande da compilare (cosa succede, cosa ti aspettavi, come riprodurlo) e in fondo i dati tecnici — versione dell'app, versione di macOS, modello di Mac, controller collegato. Sono visibili e cancellabili prima di inviare. I canali si configurano in [Feedback.swift](Sources/CouchPilot/Feedback.swift): se un canale è vuoto la voce non compare, se sono attivi entrambi diventano un sottomenu. Oltre a GitHub è attiva **"Scrivi un'email…"**, che apre una bozza già compilata con gli stessi dati — serve a chi non ha un account GitHub, che è la maggioranza di chi scaricherà l'app. L'indirizzo finisce nel sorgente pubblico e dentro l'app, quindi i bot lo raccolgono: è una scelta consapevole, e se lo spam diventa ingestibile si cambia il campo e si ricompila.
- **Esci**

## Parametri

Salvati in `UserDefaults` (dominio `com.hirpino.couchpilot`). Letti a ogni tick: le modifiche valgono subito, senza riavviare l'app. La via normale è il menu **Impostazioni**; il terminale serve solo per valori fuori dai preset.

```bash
defaults write com.hirpino.couchpilot maxSpeed -float 1400
```

| Chiave | Default | Cosa fa |
|---|---|---|
| `deadzone` | 0.15 | Deadzone radiale dello stick di movimento (sinistro) |
| `exponent` | 2.0 | Curva di risposta (più alto = più precisione a bassa deflessione) |
| `maxSpeed` | 1400 | Velocità massima cursore (px/s) |
| `scrollDeadzone` | 0.20 | Deadzone dello stick di scroll (destro) |
| `scrollSpeed` | 700 | Velocità massima scroll (px/s) |
| `debugLog` | false | Logga valori stick e posizione ogni 0.5s (visibili in Console.app, processo CouchPilot) |
| `excludedApps` | GeForce Now, Steam | Bundle id delle app che mettono in pausa il controllo (gestibili dal menu) |
| `autoPauseGames` | true | Pausa automatica quando l'app in primo piano è categorizzata come gioco |
| `precisionFactor` | 0.25 | Moltiplicatore velocità con R2 tenuto |
| `boostFactor` | 2.0 | Moltiplicatore velocità con L2 tenuto |
| `actionL3` / `actionR3` | mute / middleClick | Azione dei pulsanti stick (gestibili dal menu) |
| `language` | auto | Lingua del menu: `auto`, `it`, `en`, `es`, `zh` |

## Test manuali

- [ ] Hover sui menu della barra: le voci si evidenziano al passaggio
- [ ] Drag di una finestra tenendo A
- [ ] Click sulle icone del Dock (zona di magnificazione)
- [ ] Passaggio da un display all'altro, cursore che non si incastra sul bordo
- [ ] Movimento lentissimo (stick appena inclinato): il cursore deve muoversi
- [ ] Disconnessione del controller a metà drag: il pulsante si rilascia
- [ ] Riavvio del Mac con login item attivo
- [ ] Doppio click con due pressioni rapide di A
- [ ] Toggle premendo View + Menu insieme; View da solo continua a mostrare la Scrivania

**Fase 2:**
- [ ] Y mette in play/pausa (Musica, YouTube, Spotify)
- [ ] D-pad su/giù alza/abbassa il volume, tenuto premuto continua da solo
- [ ] D-pad sx/dx cambia traccia
- [ ] B apre e chiude Mission Control
- [ ] LB/RB si spostano tra gli Spaces (servono ≥2 scrivanie)
- [ ] View da solo mostra la Scrivania e la ripristina; View+Menu **non** la mostra
- [ ] R2 tenuto: il cursore rallenta visibilmente; rilasciato torna normale
- [ ] L2 tenuto: il cursore accelera; L2+R2 insieme ≈ metà velocità
- [ ] R2 + stick destro: scroll lento e controllato

## Note

- **macOS naviga da solo col D-pad:** con un controller collegato, il sistema usa la croce direzionale per muoversi in Spotlight, Launchpad e simili, e non è disattivabile dalle Impostazioni. Se un'azione della croce scatta *mentre* macOS sposta anche la selezione, metti quella direzione su **Nessuna azione** in Assegnazione tasti.
- **Conflitti col pad:** i giochi (GeForce Now, Steam…) ricevono l'input del controller insieme a noi. La soluzione è l'auto-pausa per app in primo piano ("Disattiva nelle app"). Altre app di mapping (Controlly, Enjoyable…) non vanno tenute attive in contemporanea: eventi doppi.
- La build va fatta sempre da questa cartella (stesso path + stessa firma = permesso Accessibilità stabile).
- In roadmap: profili per applicazione, scorciatoie personalizzate sui pulsanti, D-pad come frecce.

## Privacy

L'app non raccoglie, non salva e non trasmette alcun dato personale. Non contiene codice di rete: non si collega a nessun server, non ha analytics né telemetria.

Il permesso di Accessibilità serve a *generare* eventi di mouse e tastiera. C'è un solo punto in cui CouchPilot legge l'input: mentre stai registrando un'assegnazione in "Assegnazione tasti" apre un tap sugli eventi, per catturare il tasto, la combinazione o il click che premi — compresi i tasti multimediali, che macOS non consegna mai alle app come normali eventi di tastiera. Quel tap vive solo durante la registrazione: si chiude quando finisci, quando la finestra perde il fuoco o viene chiusa, e comunque dopo 20 secondi. Di quello che premi non resta niente tranne l'assegnazione che hai scelto, e niente esce dal Mac. Sta tutto in un file leggibile dall'inizio alla fine: [`InputCapture.swift`](Sources/CouchPilot/InputCapture.swift).

Restano sul Mac e non escono mai da lì: le preferenze (`UserDefaults`), un file di log tecnico in `~/Library/Logs/CouchPilot.log` con connessioni del pad ed errori. Per mostrare la batteria del controller l'app interroga `system_profiler` in locale.

## Icona

Disegnata da codice in [Tools/makeicon.swift](Tools/makeicon.swift) con CoreGraphics: nessun file grafico binario nel progetto, si rigenera e si modifica cambiando i numeri nello script. `build.sh` la ricostruisce da sé quando lo script cambia, e assembla l'`.icns` con `iconutil`.

Per vederla senza ricompilare tutto:

```bash
swift Tools/makeicon.swift /tmp/icone && open /tmp/icone
```

Opzioni: `--nocursor` rende la sola sagoma del gamepad (utile per giudicare le proporzioni), `--legacy-plate` disegna lo squircle nell'immagine invece di lasciarlo al sistema.

**Nota su macOS 26:** il sistema applica da sé maschera e rilievo alle icone. L'artwork va quindi disegnato *a tutto campo*, senza margini trasparenti e senza squircle: se trova margini, macOS incolla l'icona su un vassoio bianco e il risultato è un riquadro dentro l'altro.

## Struttura

```
Sources/CouchPilot/
  main.swift            avvio NSApplication (accessory, niente Dock)
  AppDelegate.swift     menu bar, wiring, permessi, login item
  ControllerMonitor.swift  connect/disconnect del pad
  CursorDriver.swift    loop 120 Hz, deadzone, curva, clamp multi-monitor
  EventPoster.swift     CGEvent: move/drag, click, scroll
  PermissionsGate.swift AXIsProcessTrusted + apertura pannello
  Settings.swift        parametri UserDefaults
  Strings.swift         traduzioni (it/en/es/zh) e scelta della lingua
  BatteryReader.swift   batteria del pad: GameController + ripiego Bluetooth
  BatteryIcon.swift     indicatore di batteria disegnato in stile macOS
Info.plist              LSUIElement, bundle id com.hirpino.couchpilot
Tools/makeicon.swift    generatore dell'icona (CoreGraphics)
build.sh                build + icona + bundle + codesign
```

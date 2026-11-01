# Karaoke Maker per Mac

App nativa per macOS 13 o successivo, per Apple Silicon e Intel. Serve a creare video karaoke: carichi l'audio, incolli il testo, sincronizzi le parole a mano ed esporti il video.

## Installazione
L'app non è firmata con un account sviluppatore Apple a pagamento, quindi macOS blocca il doppio clic sui file scaricati dal browser.

**Metodo consigliato (Terminale, senza blocchi):** apri l'app Terminale e incolla questa riga:
```
curl -L -o /tmp/KaraokeMaker.zip https://github.com/aromatovunque-pixel/aromatovunque/releases/download/karaoke-maker-latest/KaraokeMaker-mac.zip && ditto -x -k /tmp/KaraokeMaker.zip /Applications && open "/Applications/Karaoke Maker.app"
```

**Se hai già scaricato lo zip e trascinato l'app in Applicazioni**, nel Terminale:
```
xattr -cr "/Applications/Karaoke Maker.app"
```
Poi aprila normalmente.

**Senza Terminale:** prova ad aprire l'app una volta, poi vai in Impostazioni di Sistema → Privacy e sicurezza, scorri in basso e premi **Apri comunque**.

## Come si usa
**1 · Testo e audio**
- Inserisci titolo e artista.
- Carica l'audio con la voce, che serve per sincronizzare. Puoi anche caricare la base senza voce: è quella che finisce nel video.
- Incolla il testo: una riga del file diventa una riga del karaoke.
- Usa una riga vuota per separare le strofe. Le righe tra `[parentesi quadre]` vengono ignorate.

**2 · Sincronizza**
- In modalità **Segna** premi `Spazio` all'inizio di ogni parola. Premi `↩` per segnare la fine della riga, `⌫` per annullare e `Esc` per mettere in pausa.
- `← →` spostano la parola selezionata di 0,05 s, con `⇧` di 0,2 s. `↑ ↓` passano alla parola precedente o successiva.
- Se fai clic su una parola, la riascolti da 3 secondi prima.
- Sulla forma d'onda puoi trascinare i marcatori gialli per correggere i tempi con precisione.
- Puoi rallentare l'audio a 85%, 70% o 50% senza che cambi l'intonazione.
- In modalità **Controlla** la parola cantata si illumina mentre l'audio scorre.

**3 · Video**
- **Evidenziazione:** *Scorrimento*, dove il colore riempie la parola mentre viene cantata, oppure *Parola per parola*, con l'effetto "pop" opzionale.
- **Righe:** riga corrente più la successiva, oppure due righe alternate come nei karaoke professionali.
- Puoi scegliere carattere, dimensione, colori, contorno, ombra, posizione verticale, maiuscolo, conto alla rovescia e titolo iniziale.
- **Sfondo:** sfumato animato, tinta unita, immagine oppure trasparente.

**Esportazione** (⌘E)
- *MP4 H.264* o *HEVC* con sfondo, Full HD 1920×1080 come impostazione predefinita. Sono disponibili anche 720p, 4K, verticale 1080×1920 e quadrato.
- *ProRes 422 HQ* per il montaggio.
- *ProRes 4444* o *HEVC* **trasparenti**, con canale alfa, da sovrapporre in Final Cut, Premiere, DaVinci o iMovie.
- L'esportazione non avviene in tempo reale: puoi continuare a usare il Mac e annullarla in qualsiasi momento.

Dal menu **File** puoi anche esportare un file `.lrc` con i tempi di ogni parola.

All'avvio si apre un progetto nuovo. Con File → Apri (o trascinando il file sull'icona) puoi aprire anche un **.txt** con il testo, un **.lrc** (anche con i tempi di ogni parola) o direttamente un **file audio** (mp3, m4a, wav…).

I progetti si salvano come file `.karaoke`. L'app apre anche i progetti `.json` della vecchia versione web: usa File → Apri.

## Compilare da sorgente
Ti servono macOS 13 o successivo e Xcode oppure i Command Line Tools.
```
cd karaoke-maker
./build.sh
```
L'app compilata si trova in `dist/Karaoke Maker.app`.

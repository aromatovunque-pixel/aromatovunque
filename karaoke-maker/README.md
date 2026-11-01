# Karaoke Maker per Mac

App nativa per macOS 13 o successivo, per Apple Silicon e Intel. Serve a creare video karaoke: carichi l'audio, incolli il testo, sincronizzi le parole a mano ed esporti il video.

## Installazione
1. Scarica `KaraokeMaker-mac.zip` dalla release **karaoke-maker-latest** del repository. In alternativa compila l'app tu stesso (vedi sotto).
2. Estrai lo zip e trascina **Karaoke Maker** nella cartella Applicazioni.
3. Al primo avvio fai clic destro sull'app e scegli **Apri**. Se macOS la blocca ancora, vai in Impostazioni di Sistema → Privacy e sicurezza → **Apri comunque**.

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

I progetti si salvano come file `.karaoke`. L'app apre anche i progetti `.json` della vecchia versione web: usa File → Apri.

## Compilare da sorgente
Ti servono macOS 13 o successivo e Xcode oppure i Command Line Tools.
```
cd karaoke-maker
./build.sh
```
L'app compilata si trova in `dist/Karaoke Maker.app`.

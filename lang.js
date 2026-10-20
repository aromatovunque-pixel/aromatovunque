/* Aromat Ovunque* — traduzioni del sito
 *
 * Lingue: italiano (predefinito), tedesco, francese, romancio.
 * I testi italiani restano scritti nelle pagine HTML: questo file
 * contiene tedesco, francese e romancio, più i testi italiani usati solo
 * dagli script (es. il gioco Aromat World).
 *
 * Uso nelle pagine:
 *   <span data-i18n="chiave">testo italiano</span>       → testo
 *   <p data-i18n-html="chiave">testo con <b>tag</b></p>  → HTML
 *   <img data-i18n-alt="chiave" alt="...">               → attributo alt
 *   <div data-lang-switch></div>                         → pulsanti IT · DE · FR · RM
 * Negli script: window.i18n.t('chiave', { valore: 1 })
 * Link diretto a una lingua: pagina.html?lang=de
 */
(function () {
  'use strict';

  var LANGS = ['it', 'de', 'fr', 'rm'];

  var D = {
    // Testi italiani che esistono solo negli script
    it: {
      'shop.open': 'Apri',
      'shop.close': 'Chiudi',

      'aw.hintTouch': 'Tocca SALTA',
      'aw.hintKeys': 'Premi INVIO o SPAZIO',
      'aw.start': '{hint} per iniziare',
      'aw.resume': '{hint} per riprendere',
      'aw.continue': '{hint} per continuare',
      'aw.retry': '{hint} per riprovare il livello',
      'aw.replay': '{hint} per rigiocare',
      'aw.intro1': 'Raccogli i granelli, evita la fondue',
      'aw.intro2': 'e arriva alla bandiera svizzera!',
      'aw.intro3': 'Colpisci da sotto le scatole ? per le sorprese',
      'aw.intro4': 'Salta due volte di fila per il doppio salto!',
      'aw.record': 'RECORD {b}',
      'aw.coins': 'GRANELLI {s}',
      'aw.level': 'LIVELLO {n}',
      'aw.pause': 'PAUSA',
      'aw.clear': 'LIVELLO COMPLETATO!',
      'aw.coinsGot': 'Granelli raccolti: {a}/{b}',
      'aw.score': 'Punteggio: {s}',
      'aw.gameover': 'GAME OVER',
      'aw.scoreRecord': 'Punteggio: {s} · Record: {b}',
      'aw.win': 'HAI VINTO!',
      'aw.winLine': 'Aromat ovunque, anche nel Castello del Sale.',
      'aw.final': 'Punteggio finale: {s}',
      'aw.newRecord': 'NUOVO RECORD!',
      'aw.recordLine': 'Record: {b}',
      'aw.allCoins': 'TUTTI I GRANELLI! +200',
      'aw.checkpoint': 'CHECKPOINT',
      'aw.chips': 'PATATINE ZWEIFEL! +1 VITA',
      'aw.van': 'FURGONE AROMAT! INVINCIBILE',
      'aw.magnet': 'CALAMITA! ATTIRA I GRANELLI',
      'aw.vanBar': 'FURGONE',
      'aw.magnetBar': 'CALAMITA',
      'aw.lv1': 'Prati di Aromat',
      'aw.lv2': 'Fiume di Fondue',
      'aw.lv3': 'Monti Ticinesi',
      'aw.lv4': 'Castello del Sale'
    },

    de: {
      // Home
      'idx.doctitle': 'Aromat Überall*',
      'idx.title': 'Aromat Überall*',
      'idx.cta': 'Eintreten',
      'idx.disclaimer': '<b>* Disclaimer:</b> Diese Website wurde ausschliesslich zur Unterhaltung und als Satire erstellt. ' +
        'Die gezeigten Produkte sind frei erfunden und entsprechen weder echten Produkten noch deren kommerziellen Eigenschaften.' +
        '<br><br>Allen eine schöne Fasnacht.',

      // Navigazione
      'nav.home': 'Home',
      'nav.game': 'Spiel',

      // Shop
      'shop.doctitle': 'Aromat Überall* – Shop',
      'shop.cats': 'Kategorien',
      'shop.open': 'Öffnen',
      'shop.close': 'Schliessen',
      'shop.h1': 'Wochenaktionen',
      'shop.lead': 'Zufällige Rabatte von 20–50 %. Wenn es dich nicht überzeugt, ist das normal.',
      'shop.votes': 'Stimmen',
      'shop.view': 'Ansehen',

      'cat.all': 'Alle',
      'cat.bevande': 'Getränke',
      'cat.caffe': 'Kaffee',
      'cat.dolci': 'Süsses',
      'cat.cura': 'Körperpflege',
      'cat.casa': 'Haushalt',
      'cat.carne': 'Fleisch',
      'cat.latticini': 'Milchprodukte & Diverses',
      'cat.animali': 'Tiere',
      'cat.salute': 'Gesundheit',
      'cat.sanvalentino': 'Valentinstag',
      'cat.extra': 'Extra',

      'tag.bevande': 'GETRÄNKE',
      'tag.caffe': 'KAFFEE',
      'tag.dolci': 'SÜSSES',
      'tag.cura': 'PFLEGE',
      'tag.casa': 'HAUSHALT',
      'tag.carne': 'FLEISCH',
      'tag.latticini': 'MILCHPRODUKTE',
      'tag.animali': 'TIERE',
      'tag.salute': 'GESUNDHEIT',
      'tag.sanvalentino': 'VALENTINSTAG',
      'tag.extra': 'EXTRA',

      'p.coca.name': 'Coca Aromat',
      'p.coca.desc': '„Das einzige Getränk, das dich durstig macht“',
      'p.sciroppo.name': 'Aromat-Sirup',
      'p.sciroppo.desc': '„Süsse, die nicht verzeiht.“',
      'p.milk.name': 'Milk Aromat',
      'p.milk.desc': 'Perfekt gegen Verstopfung.',
      'p.caffe.name': 'Espresso-Kapseln',
      'p.caffe.desc': '„Kompatibel, stark, absolut vermeidbar“',
      'p.cioccolato.name': 'Dunkle Schokolade',
      'p.cioccolato.desc': '„Stark und stur.“',
      'p.gelato.name': 'Aromat Supreme Glace',
      'p.gelato.desc': '„Süss, cremig, unerklärlich.“',
      'p.aromella.name': 'Aromella',
      'p.aromella.desc': '„Streichfähig. Stell keine Fragen.“',
      'p.kellogs.name': 'Kellogs mit Aromat',
      'p.kellogs.desc': '„Knusprige Cerealien. Fragwürdige Entscheidungen.“',
      'p.nesquik.name': 'Nesquik mit Aromat',
      'p.nesquik.desc': '„Milch, wie sie nicht sein sollte“',
      'p.dentifricio.name': 'Aromat-Zahnpasta',
      'p.dentifricio.desc': '„Kräftiger Atem. Null Kompromisse.“',
      'p.profumo.name': 'Eau de Toilette',
      'p.profumo.desc': '„Für den Mann, der fragen muss.“',
      'p.deodorante.name': 'Aromat-Deo',
      'p.deodorante.desc': '„48 h. Oder mehr. Wer weiss.“',
      'p.carta.name': 'Aromat-WC-Papier',
      'p.carta.desc': '„Angenehm gewürzt.“',
      'p.luganighetta.name': 'Luganighetta Aromat',
      'p.luganighetta.desc': '„Für Grillabende mit Freunden.“',
      'p.fondue.name': 'Fondue Aromat',
      'p.fondue.desc': 'Die Zutat, die immer gefehlt hat.',
      'p.yogurt.name': 'Aromat-Joghurt',
      'p.yogurt.desc': 'Schweizer Crème. Falsche Ideen.',
      'p.catfood.name': 'Aromat-Katzenfutter',
      'p.catfood.desc': '„Für Katzen mit … fragwürdigen Ansprüchen.“',
      'p.citran.name': 'Aromat-Citran Forte',
      'p.citran.desc': 'Grippe und Erkältung, aber mit Persönlichkeit.',
      'p.arodor.name': 'Arodor-Pralinen',
      'p.arodor.desc': 'Bist du verliebt, schenk Aromat',
      'p.sigarette.name': 'Aromat-Zigaretten',
      'p.sigarette.desc': '„Für alle, denen die Gesundheit egal ist – aber mit Stil.“',
      'p.cicche.name': 'Aromat-Kaugummi',
      'p.cicche.desc': '„Anhaltender Geschmack. Miese Entscheidungen.“',
      'p.durex.name': 'Aromat-Kondome',
      'p.durex.desc': '“Don\'t be silly, protect your Knörli.”',

      // Aromat Game (pizza)
      'slot.subtitle': 'Schiess das Aromat auf die Pizza',
      'slot.time': 'Zeit',
      'slot.hats': 'Mützen',
      'slot.mult': 'Multiplikator',
      'slot.fire': 'SCHIESS',
      'slot.congrats': 'GRATULIERE!',
      'slot.prize': 'Du hast die Chance gewonnen, mir einen Drink zu spendieren!!',
      'slot.final': 'Endstand:',

      // Aromat World
      'aw.keys': '<b>← →</b> / <b>A D</b> bewegen · <b>Leertaste</b> / <b>↑</b> springen (2× Doppelsprung) · <b>Shift</b> / <b>X</b> Dash · <b>P</b> Pause · <b>M</b> Ton',
      'aw.jumpBtn': 'SPRING',
      'aw.hintTouch': 'Tippe auf SPRING',
      'aw.hintKeys': 'Drück ENTER oder LEERTASTE',
      'aw.start': '{hint}, um zu starten',
      'aw.resume': '{hint}, um weiterzuspielen',
      'aw.continue': '{hint}, um weiterzumachen',
      'aw.retry': '{hint}, um das Level zu wiederholen',
      'aw.replay': '{hint}, um nochmal zu spielen',
      'aw.intro1': 'Sammle die Körnchen, meide das Fondue',
      'aw.intro2': 'und erreiche die Schweizer Fahne!',
      'aw.intro3': 'Stoss die ?-Kisten von unten an: Überraschung!',
      'aw.intro4': 'Zweimal springen für den Doppelsprung!',
      'aw.record': 'REKORD {b}',
      'aw.coins': 'KÖRNCHEN {s}',
      'aw.level': 'LEVEL {n}',
      'aw.pause': 'PAUSE',
      'aw.clear': 'LEVEL GESCHAFFT!',
      'aw.coinsGot': 'Gesammelte Körnchen: {a}/{b}',
      'aw.score': 'Punkte: {s}',
      'aw.scoreRecord': 'Punkte: {s} · Rekord: {b}',
      'aw.win': 'GEWONNEN!',
      'aw.winLine': 'Aromat überall, sogar im Salzschloss.',
      'aw.final': 'Endpunktzahl: {s}',
      'aw.newRecord': 'NEUER REKORD!',
      'aw.recordLine': 'Rekord: {b}',
      'aw.allCoins': 'ALLE KÖRNCHEN! +200',
      'aw.chips': 'ZWEIFEL CHIPS! +1 LEBEN',
      'aw.van': 'AROMAT-LIEFERWAGEN! UNBESIEGBAR',
      'aw.magnet': 'MAGNET! ZIEHT KÖRNCHEN AN',
      'aw.vanBar': 'WAGEN',
      'aw.magnetBar': 'MAGNET',
      'aw.lv1': 'Aromat-Wiesen',
      'aw.lv2': 'Fondue-Fluss',
      'aw.lv3': 'Tessiner Berge',
      'aw.lv4': 'Salzschloss'
    },

    fr: {
      // Home
      'idx.doctitle': 'Aromat Partout*',
      'idx.title': 'Aromat Partout*',
      'idx.cta': 'Entrer',
      'idx.disclaimer': '<b>* Avertissement :</b> ce site a été réalisé uniquement à des fins de divertissement et de satire. ' +
        'Les produits présentés sont imaginaires et ne correspondent ni à des produits réels ni à leurs caractéristiques commerciales.' +
        '<br><br>Bon Carnaval à tous.',

      // Navigazione
      'nav.home': 'Accueil',
      'nav.game': 'Jeu',

      // Shop
      'shop.doctitle': 'Aromat Partout* – Shop',
      'shop.cats': 'Catégories',
      'shop.open': 'Ouvrir',
      'shop.close': 'Fermer',
      'shop.h1': 'Promos de la semaine',
      'shop.lead': 'Réductions aléatoires de 20 à 50 %. Si ça ne te convainc pas, c’est normal.',
      'shop.votes': 'votes',
      'shop.view': 'Voir',

      'cat.all': 'Tous',
      'cat.bevande': 'Boissons',
      'cat.caffe': 'Café',
      'cat.dolci': 'Douceurs',
      'cat.cura': 'Soins personnels',
      'cat.casa': 'Maison',
      'cat.carne': 'Viande',
      'cat.latticini': 'Produits laitiers & divers',
      'cat.animali': 'Animaux',
      'cat.salute': 'Santé',
      'cat.sanvalentino': 'Saint-Valentin',
      'cat.extra': 'Extra',

      'tag.bevande': 'BOISSONS',
      'tag.caffe': 'CAFÉ',
      'tag.dolci': 'DOUCEURS',
      'tag.cura': 'SOINS',
      'tag.casa': 'MAISON',
      'tag.carne': 'VIANDE',
      'tag.latticini': 'PRODUITS LAITIERS',
      'tag.animali': 'ANIMAUX',
      'tag.salute': 'SANTÉ',
      'tag.sanvalentino': 'SAINT-VALENTIN',
      'tag.extra': 'EXTRA',

      'p.coca.name': 'Coca Aromat',
      'p.coca.desc': '« La seule boisson qui donne soif »',
      'p.sciroppo.name': 'Sirop Aromat',
      'p.sciroppo.desc': '« Une douceur qui ne pardonne pas. »',
      'p.milk.name': 'Milk Aromat',
      'p.milk.desc': 'Parfait contre la constipation.',
      'p.caffe.name': 'Capsules Espresso',
      'p.caffe.desc': '« Compatibles, corsées, parfaitement évitables »',
      'p.cioccolato.name': 'Chocolat noir',
      'p.cioccolato.desc': '« Fort et têtu. »',
      'p.gelato.name': 'Glace Aromat Suprême',
      'p.gelato.desc': '« Douce, crémeuse, inexplicable. »',
      'p.aromella.name': 'Aromella',
      'p.aromella.desc': '« À tartiner. Ne pose pas de questions. »',
      'p.kellogs.name': 'Kellogs à l’Aromat',
      'p.kellogs.desc': '« Céréales croustillantes. Choix discutables. »',
      'p.nesquik.name': 'Nesquik à l’Aromat',
      'p.nesquik.desc': '« Le lait comme il ne devrait pas être »',
      'p.dentifricio.name': 'Dentifrice à l’Aromat',
      'p.dentifricio.desc': '« Haleine puissante. Zéro compromis. »',
      'p.profumo.name': 'Eau de Toilette',
      'p.profumo.desc': '« Pour l’homme qui doit demander. »',
      'p.deodorante.name': 'Déodorant Aromat',
      'p.deodorante.desc': '« 48 h. Ou plus. Qui sait. »',
      'p.carta.name': 'Papier toilette Aromat',
      'p.carta.desc': '« Agréablement assaisonné. »',
      'p.luganighetta.name': 'Luganighetta Aromat',
      'p.luganighetta.desc': '« Pour les grillades entre amis. »',
      'p.fondue.name': 'Fondue Aromat',
      'p.fondue.desc': 'L’ingrédient qui a toujours manqué.',
      'p.yogurt.name': 'Yogourt Aromat',
      'p.yogurt.desc': 'Crème suisse. Mauvaises idées.',
      'p.catfood.name': 'Nourriture pour chats Aromat',
      'p.catfood.desc': '« Pour félins aux goûts… discutables. »',
      'p.citran.name': 'Aromat-Citran Forte',
      'p.citran.desc': 'Grippe et rhume, mais avec de la personnalité.',
      'p.arodor.name': 'Chocolats Arodor',
      'p.arodor.desc': 'T’es amoureux ? Offre de l’Aromat',
      'p.sigarette.name': 'Cigarettes Aromat',
      'p.sigarette.desc': '« Pour ceux qui se fichent de leur santé, mais avec style. »',
      'p.cicche.name': 'Chewing-gums à l’Aromat',
      'p.cicche.desc': '« Goût persistant. Très mauvais choix. »',
      'p.durex.name': 'Préservatifs Aromat',
      'p.durex.desc': '“Don\'t be silly, protect your Knörli.”',

      // Aromat Game (pizza)
      'slot.subtitle': 'Tire l’Aromat sur la pizza',
      'slot.time': 'Temps',
      'slot.hats': 'Bonnets',
      'slot.mult': 'Multiplicateur',
      'slot.fire': 'TIRER',
      'slot.congrats': 'BRAVO !',
      'slot.prize': 'Tu as gagné l’occasion de me payer un verre !!',
      'slot.final': 'Score final :',

      // Aromat World
      'aw.keys': '<b>← →</b> / <b>A D</b> bouger · <b>Espace</b> / <b>↑</b> sauter (2× double saut) · <b>Shift</b> / <b>X</b> dash · <b>P</b> pause · <b>M</b> son',
      'aw.jumpBtn': 'SAUTE',
      'aw.hintTouch': 'Touche SAUTE',
      'aw.hintKeys': 'Appuie sur ENTRÉE ou ESPACE',
      'aw.start': '{hint} pour commencer',
      'aw.resume': '{hint} pour reprendre',
      'aw.continue': '{hint} pour continuer',
      'aw.retry': '{hint} pour réessayer le niveau',
      'aw.replay': '{hint} pour rejouer',
      'aw.intro1': 'Ramasse les grains, évite la fondue',
      'aw.intro2': 'et atteins le drapeau suisse !',
      'aw.intro3': 'Frappe les boîtes ? par-dessous pour les surprises',
      'aw.intro4': 'Saute deux fois pour un double saut !',
      'aw.record': 'RECORD {b}',
      'aw.coins': 'GRAINS {s}',
      'aw.level': 'NIVEAU {n}',
      'aw.pause': 'PAUSE',
      'aw.clear': 'NIVEAU TERMINÉ !',
      'aw.coinsGot': 'Grains ramassés : {a}/{b}',
      'aw.score': 'Score : {s}',
      'aw.scoreRecord': 'Score : {s} · Record : {b}',
      'aw.win': 'TU AS GAGNÉ !',
      'aw.winLine': 'Aromat partout, même au Château du Sel.',
      'aw.final': 'Score final : {s}',
      'aw.newRecord': 'NOUVEAU RECORD !',
      'aw.recordLine': 'Record : {b}',
      'aw.allCoins': 'TOUS LES GRAINS ! +200',
      'aw.chips': 'CHIPS ZWEIFEL ! +1 VIE',
      'aw.van': 'CAMIONNETTE AROMAT ! INVINCIBLE',
      'aw.magnet': 'AIMANT ! ATTIRE LES GRAINS',
      'aw.vanBar': 'CAMION',
      'aw.magnetBar': 'AIMANT',
      'aw.lv1': 'Prés d’Aromat',
      'aw.lv2': 'Rivière de Fondue',
      'aw.lv3': 'Montagnes tessinoises',
      'aw.lv4': 'Château du Sel'
    },
    rm: {
      // Home
      'idx.doctitle': 'Aromat Dapertut*',
      'idx.title': 'Aromat Dapertut*',
      'idx.cta': 'Entrar',
      'idx.disclaimer': '<b>* Avis:</b> Questa pagina d’internet è vegnida fatga exclusivamain per divertiment e satira. ' +
        'Ils products preschentads èn inventads e na correspundan ni a products reals ni a lur caracteristicas commerzialas.' +
        '<br><br>Bun Tschaiver a tuts.',

      // Navigaziun
      'nav.home': 'Home',
      'nav.game': 'Gieu',

      // Shop
      'shop.doctitle': 'Aromat Dapertut* – Shop',
      'shop.cats': 'Categorias',
      'shop.open': 'Avrir',
      'shop.close': 'Serrar',
      'shop.h1': 'Acziuns da l’emna',
      'shop.lead': 'Rabats casuals da 20–50 %. Sche quai na ta persvada betg, è quai normal.',
      'shop.votes': 'vuschs',
      'shop.view': 'Mussar',

      'cat.all': 'Tuts',
      'cat.bevande': 'Bavrondas',
      'cat.caffe': 'Caffè',
      'cat.dolci': 'Dultschezzas',
      'cat.cura': 'Tgira dal corp',
      'cat.casa': 'Chasa',
      'cat.carne': 'Charn',
      'cat.latticini': 'Products da latg & divers',
      'cat.animali': 'Animals',
      'cat.salute': 'Sanadad',
      'cat.sanvalentino': 'Son Valentin',
      'cat.extra': 'Extra',

      'tag.bevande': 'BAVRONDAS',
      'tag.caffe': 'CAFFÈ',
      'tag.dolci': 'DULTSCHEZZAS',
      'tag.cura': 'TGIRA',
      'tag.casa': 'CHASA',
      'tag.carne': 'CHARN',
      'tag.latticini': 'PRODUCTS DA LATG',
      'tag.animali': 'ANIMALS',
      'tag.salute': 'SANADAD',
      'tag.sanvalentino': 'SON VALENTIN',
      'tag.extra': 'EXTRA',

      'p.coca.name': 'Coca Aromat',
      'p.coca.desc': '«L’unica bavronda che ta fa vegnir said»',
      'p.sciroppo.name': 'Sirup Aromat',
      'p.sciroppo.desc': '«Dultschezza che na perduna betg.»',
      'p.milk.name': 'Milk Aromat',
      'p.milk.desc': 'Perfect cunter la constipaziun.',
      'p.caffe.name': 'Capsulas Espresso',
      'p.caffe.desc': '«Cumpatiblas, fermas, absolutamain evitablas»',
      'p.cioccolato.name': 'Tschigulatta naira',
      'p.cioccolato.desc': '«Ferma ed ostinada.»',
      'p.gelato.name': 'Glatscha Aromat Supreme',
      'p.gelato.desc': '«Dultscha, cremusa, inexplitgabla.»',
      'p.aromella.name': 'Aromella',
      'p.aromella.desc': '«Per sin il paun. Betg far dumondas.»',
      'p.kellogs.name': 'Kellogs cun Aromat',
      'p.kellogs.desc': '«Cereals crustigliants. Decisiuns dubiusas.»',
      'p.nesquik.name': 'Nesquik cun Aromat',
      'p.nesquik.desc': '«Latg sco ch’el na duess betg esser»',
      'p.dentifricio.name': 'Pasta da dents Aromat',
      'p.dentifricio.desc': '«Flad ferm. Nagins cumpromiss.»',
      'p.profumo.name': 'Eau de Toilette',
      'p.profumo.desc': '«Per l’um che sto dumandar.»',
      'p.deodorante.name': 'Deodorant Aromat',
      'p.deodorante.desc': '«48 uras. U dapli. Tgi sa.»',
      'p.carta.name': 'Pavaigl da tualetta Aromat',
      'p.carta.desc': '«Agreablamain condimentà.»',
      'p.luganighetta.name': 'Luganighetta Aromat',
      'p.luganighetta.desc': '«Per grigliadas cun ils amis.»',
      'p.fondue.name': 'Fondue Aromat',
      'p.fondue.desc': 'L’ingredient che ha adina mancà.',
      'p.yogurt.name': 'Jogurt Aromat',
      'p.yogurt.desc': 'Crema svizra. Ideas sbagliadas.',
      'p.catfood.name': 'Pavel per giats Aromat',
      'p.catfood.desc': '«Per giats cun pretensiuns… dubiusas.»',
      'p.citran.name': 'Aromat-Citran Forte',
      'p.citran.desc': 'Grippa e fradaglia, ma cun personalitad.',
      'p.arodor.name': 'Pralinas Arodor',
      'p.arodor.desc': 'Sche ti es inamurà, regala Aromat',
      'p.sigarette.name': 'Cigarettas Aromat',
      'p.sigarette.desc': '«Per quels che la sanadad na fa nagut, ma cun stil.»',
      'p.cicche.name': 'Chicles Aromat',
      'p.cicche.desc': '«Gust persistent. Decisiuns nauschas.»',
      'p.durex.name': 'Preservativs Aromat',
      'p.durex.desc': '“Don\'t be silly, protect your Knörli.”',

      // Aromat Game (pizza)
      'slot.subtitle': 'Sajetta l’Aromat sin la pizza',
      'slot.time': 'Temp',
      'slot.hats': 'Chapitschas',
      'slot.mult': 'Multiplicatur',
      'slot.fire': 'SAJETTA',
      'slot.congrats': 'GRATULAZIUN!',
      'slot.prize': 'Ti has gudagnà la schanza da ma pajar ina bavronda!!',
      'slot.final': 'Puncts finals:',

      // Aromat World
      'aw.keys': '<b>← →</b> / <b>A D</b> mover · <b>Spazi</b> / <b>↑</b> sigliir (2× sigl dubel) · <b>Shift</b> / <b>X</b> dash · <b>P</b> pausa · <b>M</b> tun',
      'aw.jumpBtn': 'SIGLIA',
      'aw.hintTouch': 'Tutga SIGLIA',
      'aw.hintKeys': 'Smatga ENTER u SPAZI',
      'aw.start': '{hint} per cumenzar',
      'aw.resume': '{hint} per cuntinuar',
      'aw.continue': '{hint} per ir vinavant',
      'aw.retry': '{hint} per empruvar anc ina giada il nivel',
      'aw.replay': '{hint} per giugar anc ina giada',
      'aw.intro1': 'Rimna ils grauns, evita la fondue',
      'aw.intro2': 'e cuntanscha la bandiera svizra!',
      'aw.intro3': 'Batta da sut las chaschettas ? per las surpraisas',
      'aw.intro4': 'Siglia duas giadas per il sigl dubel!',
      'aw.record': 'RECORD {b}',
      'aw.coins': 'GRAUNS {s}',
      'aw.level': 'NIVEL {n}',
      'aw.pause': 'PAUSA',
      'aw.clear': 'NIVEL REUSSÌ!',
      'aw.coinsGot': 'Grauns rimnads: {a}/{b}',
      'aw.score': 'Puncts: {s}',
      'aw.scoreRecord': 'Puncts: {s} · Record: {b}',
      'aw.win': 'TI HAS GUDAGNÀ!',
      'aw.winLine': 'Aromat dapertut, schizunt en il Chastè da Sal.',
      'aw.final': 'Puncts finals: {s}',
      'aw.newRecord': 'NOV RECORD!',
      'aw.recordLine': 'Record: {b}',
      'aw.allCoins': 'TUTS ILS GRAUNS! +200',
      'aw.chips': 'CHIPS ZWEIFEL! +1 VITA',
      'aw.van': 'CAMIONET AROMAT! INVINCIBEL',
      'aw.magnet': 'MAGNET! TIRA ILS GRAUNS',
      'aw.vanBar': 'CAMIONET',
      'aw.magnetBar': 'MAGNET',
      'aw.lv1': 'Prads d’Aromat',
      'aw.lv2': 'Flum da Fondue',
      'aw.lv3': 'Muntognas tessinaisas',
      'aw.lv4': 'Chastè da Sal'
    }
  };

  function read(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
  function write(k, v) { try { localStorage.setItem(k, v); } catch (e) {} }

  function initialLang() {
    var m = /[?&]lang=(it|de|fr|rm)\b/.exec(location.search);
    if (m) { write('lang', m[1]); return m[1]; }
    var saved = read('lang');
    return LANGS.indexOf(saved) >= 0 ? saved : 'it'; // l'italiano ha la priorità
  }

  var lang = initialLang();
  var orig = {}; // testi italiani letti dalle pagine

  function t(key, vars) {
    var s = (D[lang] && D[lang][key]) || D.it[key] || orig[key] || key;
    if (vars) s = s.replace(/\{(\w+)\}/g, function (_, k) { return k in vars ? vars[k] : '{' + k + '}'; });
    return s;
  }

  function each(sel, fn) { Array.prototype.forEach.call(document.querySelectorAll(sel), fn); }

  function pick(key, it) {
    if (lang === 'it') return it;
    return (D[lang] && D[lang][key]) || it;
  }

  function apply() {
    document.documentElement.lang = lang;
    each('[data-i18n]', function (el) {
      var k = el.getAttribute('data-i18n');
      if (!(k in orig)) orig[k] = el.textContent;
      el.textContent = pick(k, orig[k]);
    });
    each('[data-i18n-html]', function (el) {
      var k = el.getAttribute('data-i18n-html');
      if (!(k in orig)) orig[k] = el.innerHTML;
      el.innerHTML = pick(k, orig[k]);
    });
    each('[data-i18n-alt]', function (el) {
      var k = el.getAttribute('data-i18n-alt'), ok = 'alt:' + k;
      if (!(ok in orig)) orig[ok] = el.getAttribute('alt') || '';
      el.setAttribute('alt', pick(k, orig[ok]));
    });
    each('.lang-switch button', function (b) {
      var on = b.getAttribute('data-lang') === lang;
      b.classList.toggle('on', on);
      b.setAttribute('aria-pressed', String(on));
    });
    document.dispatchEvent(new CustomEvent('langchange', { detail: { lang: lang } }));
  }

  function setLang(l) {
    if (LANGS.indexOf(l) < 0) return;
    lang = l;
    write('lang', l);
    apply();
  }

  function buildSwitchers() {
    if (!document.getElementById('lang-switch-css')) {
      var st = document.createElement('style');
      st.id = 'lang-switch-css';
      st.textContent =
        '.lang-switch{display:inline-flex;gap:2px;padding:3px;border-radius:999px;' +
        'background:rgba(0,0,0,.28);border:1px solid rgba(255,255,255,.22);flex:0 0 auto}' +
        '.lang-switch button{appearance:none;-webkit-appearance:none;border:0;background:transparent;color:inherit;' +
        'font:inherit;font-size:12px;font-weight:800;letter-spacing:.5px;padding:6px 9px;border-radius:999px;cursor:pointer;opacity:.75}' +
        '.lang-switch button.on{background:#ffd400;color:#000;opacity:1}' +
        '.lang-switch.light{background:#fff;border-color:rgba(0,0,0,.12);color:#0b0b0b;box-shadow:0 8px 18px rgba(0,0,0,.06)}';
      document.head.appendChild(st);
    }
    each('[data-lang-switch]', function (box) {
      if (box.querySelector('button')) return;
      box.classList.add('lang-switch');
      if (box.getAttribute('data-lang-switch') === 'light') box.classList.add('light');
      box.setAttribute('role', 'group');
      box.setAttribute('aria-label', 'Lingua / Sprache / Langue / Lingua');
      LANGS.forEach(function (l) {
        var b = document.createElement('button');
        b.type = 'button';
        b.textContent = l.toUpperCase();
        b.setAttribute('data-lang', l);
        b.addEventListener('click', function () { setLang(l); });
        box.appendChild(b);
      });
    });
  }

  window.i18n = { t: t, setLang: setLang, get lang() { return lang; } };

  function init() { buildSwitchers(); apply(); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();

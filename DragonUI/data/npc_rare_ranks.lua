-- Compact rare/rareelite lookup (510 creature entries). Names packed per locale.
-- Runtime filter excludes dev/UNUSED/QA placeholder names from client data exports.
local addon = select(2, ...)local M = {}

M.EntryCSV = [[61,79,99,100,462,471,472,503,506,507,519,520,521,534,572,573,574,584,596,599,601,616,763,771,947,1037,1063,1106,1112,1119,1130,1132,1137,1140,1260,1361,1398,1399,1424,1425,1531,1533,1552,1720,1837,1838,1839,1841,1843,1844,1847,1848,1849,1850,1851,1885,1910,1911,1920,1936,1944,1948,2090,2108,2172,2175,2184,2186,2191,2192,2258,2283,2447,2452,2453,2476,2541,2598,2600,2601,2602,2603,2604,2605,2606,2609,2744,2749,2751,2752,2753,2754,2779,2850,2931,3056,3068,3253,3270,3295,3398,3470,3535,3581,3586,3651,3652,3672,3718,3735,3773,3792,3831,3872,4015,4030,4066,4132,4339,4380,4425,4438,4842,5343,5345,5346,5347,5348,5349,5350,5352,5354,5356,5367,5399,5400,5785,5786,5787,5789,5790,5793,5794,5795,5796,5797,5798,5799,5800,5807,5808,5809,5822,5823,5824,5826,5827,5828,5829,5830,5831,5832,5834,5835,5836,5837,5838,5841,5842,5847,5848,5849,5851,5859,5863,5864,5865,5912,5915,5916,5928,5930,5931,5932,5933,5934,5935,5937,6118,6228,6488,6489,6490,6581,6582,6583,6584,6585,6646,6647,6648,6649,6650,6651,6652,7015,7016,7017,7057,7104,7137,7895,8199,8200,8201,8202,8203,8204,8205,8206,8207,8208,8210,8211,8212,8213,8214,8215,8216,8217,8218,8219,8277,8278,8279,8280,8281,8282,8283,8296,8297,8298,8299,8300,8301,8302,8303,8304,8503,8660,8923,8924,8976,8978,8979,8981,9024,9041,9042,9046,9217,9218,9219,9417,9596,9602,9604,9718,10077,10078,10080,10081,10082,10119,10196,10197,10198,10199,10200,10201,10202,10203,10236,10237,10238,10239,10263,10356,10357,10358,10359,10376,10393,10509,10558,10559,10639,10640,10641,10642,10643,10644,10647,10809,10810,10817,10818,10819,10820,10821,10822,10823,10824,10825,10826,10827,10828,10899,11383,11447,11467,11497,11498,11580,11676,11688,12037,12116,12237,12431,12432,12433,13896,13977,14016,14018,14019,14221,14222,14223,14224,14225,14226,14227,14228,14229,14230,14231,14232,14233,14234,14235,14236,14237,14266,14267,14268,14269,14270,14271,14272,14273,14275,14276,14277,14278,14279,14280,14281,14339,14340,14341,14342,14343,14344,14345,14346,14424,14425,14426,14427,14428,14429,14430,14431,14432,14433,14445,14446,14447,14448,14471,14472,14473,14474,14475,14476,14477,14478,14479,14487,14488,14490,14491,14492,14506,14697,15796,16179,16180,16181,16184,16379,16380,16854,16855,17075,17144,18241,18677,18678,18679,18680,18681,18682,18683,18684,18685,18686,18689,18690,18692,18693,18694,18695,18696,18697,18698,18699,20932,22060,22062,22625,22631,22636,22637,22642,25323,25406,25410,25411,25412,25413,26791,28280,28282,31071,31072,31073,31074,31086,31093,31156,31244,31284,31286,31287,31288,31289,31974,31998,32054,32111,32120,32338,32357,32358,32361,32377,32386,32398,32400,32409,32417,32422,32429,32435,32438,32447,32471,32475,32481,32485,32487,32491,32495,32500,32501,32517,32630,33776,35074,35189,37293,37317,37375,37432,37443,38453,39019]]

M.NamePacks = {
    enUS = [[
7:XT
Accursed Slitherblade
Achellios the Banished
Aean Swiftriver
Akkrilus
Akubar the Seer
Alshirr Banebreath
Ambassador Bloodrage
Ambassador Jerrikar
Anathemus
Antilos
Antilus the Soarer
Aotona
Apothecary Falthis
Araga
Arash-ethis
Arcturis
Azshir the Sleepless
Azurous
Azzere the Skyblade
Bannok Grimaxe
Barnabus
Baron Bloodbane
Bayne
Ben
Berylgos
Big Samras
Bjarn
Blackmoss the Fetid
Blind Hunter
Bloodroar the Stalker
Boahn
Bog Lurker
Bone Witch
Boss Galgosh
Boulderheart
Brack
Brainwashed Noble
Branch Snapper
Brimgore
Bro'Gaz the Clanless
Broken Tooth
Brokespear
Brontus
Brother Ravenoak
Bruegal Ironknuckle
Burgle Eye
Burning Felguard
Capo the Mean
Captain Armistice
Captain Flat Tusk
Captain Gerogg Hammertoe
Captain Greshkil
Carnivous the Breaker
Chatter
Chief Engineer Lorthander
Christmas Goraluk Anvilcrack
Clack the Reaver
Clutchmother Zavas
Coilfang Emissary
Collidus the Warp-Watcher
Commander Felstrom
Craig Steele
Craig Steele (1)
Craig Steele (2)
Craig Steele2
Craig Steele2 (1)
Craig Steele3
Cranky Benj
Crazed Indu'le Survivor
Creepthess
Crippler
Crusty
Crystal Fang
Cursed Centaur
Cyclok the Mad
Dalaran Spellscribe
Darbel Montrose
Dark Iron Ambassador
Darkmist Widow
Dart
Death Flayer
Death Howl
Death Knight Soulbearer
Deatheye
Deathmaw
Deathspeaker Selendre
Deathsworn Captain
Deeb
Dessecus
Deviate Faerie Dragon
Diamond Head
Digger Flameforge
Digmaster Shovelphlange
Dirkee
Dishu
Doomsayer Jurim
Dr. Whitherlimb
Dragonmaw Battlemaster
Dreadscorn
Dreadwhisper
Dreamwatcher Forktongue
Drogoth the Roamer
Duggan Wildhammer
Duke Ragereaver
Duskstalker
Dustwraith
Earthcaller Halmgar
Eck'alom
Edan the Howler
Elder Mystic Razorsnout
Eldinarcus
Emogg the Crusher
Enforcer Emilgund
Engineer Whirleygig
Ever-Core the Punisher
Fallen Champion
Farmer Solliden
Faulty War Golem
Fedfennel
Felendor the Accuser
Fellicent's Shade
Felweaver Scornn
Fenissa the Assassin
Fenros
Fingat
Firecaller Radison
Fjordune the Greater
Fjordune the Greater (1)
Fjordune the Greater (2)
Fjordune the Greater (3)
Flagglemurk the Cruel
Foe Reaper 4000
Foreman Grills
Foreman Jerris
Foreman Marcrid
Foreman Rigger
Foulbelly
Foulmane
Fulgorge
Fumblub Gearwind
Fury Shelda
Garneg Charskull
Gash'nak the Cannibal
Gash'nak the Cannibal (1)
Gash'nak the Cannibal (2)
Gash'nak the Cannibal (3)
Gatekeeper Rageroar
General Colbatann
General Fangferror
Geolord Mottle
Geomancer Flintdagger
Geopriest Gukk'rok
Gesharahan
Ghok Bashguud
Ghost Howl
Gibblesnik
Gibblewilt
Giggler
Gilmorian
Gish the Unmoving
Gluggle
Gnarl Leafbrother
Gnawbone
Gondria
Goraluk Anvilcrack
Gorefang
Goretooth
Gorgon'och
Grash Thunderbrew
Gravis Slipknot
Great Father Arctikus
Greater Firebird
Gretheer
Griegen
Grimmaw
Grimungous
Grizlak
Grizzle Snowpaw
Grocklar
Grubthor
Gruff
Gruff Swiftbite
Gruklash
Grunter
Haarka the Ravenous
Hagg Taurenbane
Hahk'Zor
Hammerspine
Hannah Bladeleaf
Harb Foulmountain
Hayoc
Hearthsinger Forresten
Heartrazor
Hed'mush the Rotting
Heggin Stonewhisker
Hemathion
Hematos
High General Abbendis
High Priestess Hai'watna
High Thane Jorfus
Highlord Mastrogonde
Hildana Deathstealer
Hissperak
Humar the Pridelord
Huricanian
Hyakiss the Lurker
Icehorn
Immolatus
Ironback
Ironeye the Invincible
Ironspine
Jade
Jalinde Summerdrake
Jed Runewatcher
Jimmy the Bleeder
Jin'Zallah the Sandbringer
Kashoch the Reaver
Kaskk
Kazon
Kelemis the Lifeless
King Krush
King Mosh
King Ping
Kovork
Kraator
Kregg Keelhaul
Krellack
Krethis Shadowspinner
Kurmokk
Lady Hederine
Lady Moongazer
Lady Sesspira
Lady Szallah
Lady Vespia
Lady Vespira
Lady Zephris
Lapress
Large Loch Crocolisk
Leech Widow
Leprithus
Licillin
Lizzle Sprysprocket
Lo'Grosh
Loque'nahak
Lord Angler
Lord Captain Wyrmak
Lord Condar
Lord Darkscythe
Lord Hel'nurath
Lord Malathrom
Lord Maldazzar
Lord Sakrasis
Lord Sinslayer
Lost One Chieftain
Lost One Cook
Lost Soul
Lumbering Horror
Lupos
Ma'ruk Wyrmscale
Magister Hawkhelm
Magosh
Magronos the Unyielding
Malfunctioning Reaver
Malgin Barleybrew
Marcus Bel
Marisa du'Paige
Marticar
Master Digger
Master Feardred
Mazzranache
Mekthorg the Wild
Meshlok the Harvester
Mezzir the Howler
Miner Johnson
Mirelow
Mist Howler
Mith'rethis the Enchanter
Mojo the Twisted
Molok the Crusher
Molt Thorn
Mongress
Monnos the Elder
Morcrush
Morgaine the Sly
Mother Fang
Muad
Mugglefin
Murderous Blisterpaw
Mushgog
Nal'taszar
Naraxis
Narg the Taskmaster
Narillasanz
Nefaru
Nerubian Overseer
Netherstorm Rare Chimaera UNUSED
Nimar the Slayer
Nuramoc
Oakpaw
Okrek
Old Cliff Jumper
Old Crystalbark
Old Grizzlegut
Old Vicejaw
Olm the Wise
Omgorn the Lost
Oozeworm
Panzor the Invincible
Perobas the Bloodthirster
Pridewing Patriarch
Priestess of Elune
Prince Kellen
Prince Nazjak
Prince Raze
Putridius
Putridus the Ancient
Pyromancer Loregrain
QA Test Dummy 82 High Damage
QA Test Dummy 83 High Damage
Qirot
Quest - Northrend BG - Gate Kill
Quest - Wintergrasp - Bridge Kill
Quest - Wintergrasp - Gate Kill
Quest - Wintergrasp - PvP Kill - Alliance
Quest - Wintergrasp - PvP Kill - Fire
Quest - Wintergrasp - PvP Kill - Horde
Quest - Wintergrasp - PvP Kill - Life
Quest - Wintergrasp - PvP Kill - Shadow
Quest - Wintergrasp - PvP Kill - Vehicle
Quest - Wintergrasp - PvP Kill - Water
Quest - Wintergrasp - Southern Tower Kill
Quest - Wintergrasp - Structure Kill
Quest - Wintergrasp - Tower Kill
Quest - Wintergrasp - Vehicle Protected
Quest - Wintergrasp - Wall Kill
Quest - Wintergrasp - Workshop Kill
Ragepaw
Rak'shiri
Ranger Lord Hawkspear
Rathorian
Ravage
Ravasaur Matriarch
Ravenclaw Regent
Razorfen Spearhide
Razormaw Matriarch
Razortalon
Rekk'tilac
Ressan the Needler
Retherokk the Berserker
Rex Ashil
Rezrelek
Rezrelek (1)
Rezrelek (2)
Rezrelek (3)
Ribchaser
Rippa
Ripscale
Ro'Bark
Rocklance
Rohh the Silent
Rokad the Ravager
Roloch
Rorgish Jowl
Rot Hide Bruiser
Rumbler
Ruul Onestone
Sandarr Dunereaver
Sandworm
Scald
Scale Belly
Scalebeard
Scargil
Scarlet Executioner
Scarlet High Clerist
Scarlet Highlord Daion
Scarlet Interrogator
Scarlet Judge
Scarlet Smith
Scarshield Quartermaster
Scillia Daggerquil
Scott Keenan
Seeker Aqualon
Seething Hate
Sentinel Amarassan
Sergeant Brashclaw
Serra Mountainhome
Setis
Sewer Beast
Shadikith the Glider
Shadowclaw
Shadowforge Commander
Shanda the Spinner
Shleipnarr
Siege Golem
Silithid Harvester
Silithid Ravager
Singer
Sister Hatelash
Sister Rathtalon
Sister Riven
Skarr the Unbreakable
Skhowl
Skoll
Skul
Slark
Slave Master Blackheart
Sleeping Dragon
Sludge Beast
Sludginn
Smoldar
Snagglespear
Snarler
Snarlflare
Snarlmane
Snort the Heckler
Soriid the Devourer
Sorrow Wing
Soul of Tanaris
Speaker Mar'grom
Spirestone Battle Lord
Spirestone Butcher
Spirestone Lord Magus
Spirit of the Damned
Spiteflayer
Squiddic
Sri'skulk
Staggon
Stone Fury
Stonearm
Stonespine
Strider Clutchmother
Swiftmane
Swinegart Spearhide
Syreian the Bonecarver
Takk the Leaper
Tamra Stormpike
Taskmaster Whipfang
Tatterhide
Tatterhide (1)
Tatterhide (2)
Tatterhide (3)
Tepolar
Terror Spinner
Terrorspark
Terrowulf Packlord
Thauris Balgarr
The Behemoth
The Evalcharr
The Husk
The Ongar
The Rake
The Razza
The Reak
The Rot
Thora Feathermoon
Threggil
Thunderstomp
Thurmonde the Devout
Thuros Lightfingers
Timber
Time-Lost Proto Drake
Tormented Spirit
Tregla
Trigore the Lasher
Tsu'zee
Tukemuth
Twilight Lord Everun
Uhk'loc
Ursol'lok
Uruson
Ushalac the Gloomdweller
Ushalac the Gloomdweller (1)
Ushalac the Gloomdweller (2)
Ushalac the Gloomdweller (3)
Varo'then's Ghost
Vengeful Ancient
Verek
Verifonix
Vern
Veyzhak the Cannibal
Vigdis the War Maiden
Vile Sting
Voidhunter Yar
Volchan
Vorakem Doomspeaker
Vultros
Vyragosa
War Golem
Warder Stilgiss
Warleader Krazzilak
Warlord Kolkanis
Warlord Thresh'jin
Watch Commander Zalaphil
Wep
Witherheart the Stalker
Yor <UNUSED>
Zalas Witherbark
Zaricotl
Zekkis
Zerillis
Zora
Zul'Brin Warpbranch
Zul'arek Hatefowler
Zul'drak Sentinel
[UNUSED] Ancient Guardian
[UNUSED] Deathcaller Majestis
[UNUSED] Kern the Enforcer
[UNUSED] Kolkar Observer
[UNUSED] Wrathtail Tide Princess
]],
    esES = [[
7:XT
Filozante detestable
Achellios el Desterrado
Aean Río Veloz
Akkrilus
Akubar el Vidente
Alshirr Respiramiedo
Embajador Sanguinarius
Embajador Jerrikar
Anathemus
Antilos
Antilus el Surcador
Aotona
Boticario Falthis
Araga
Arash-ethis
Arcturis
Azshir el Insomne
Azurous
Azzere el Filo del Cielo
Bannok Hacha Macabra
Barnabus
Barón Malasangre
Bayne
Ben
Berylgos
Gran Samras
Bjarn
Musgonegro el Fétido
Cazador ciego
Rugesangre el Acechador
Boahn
Rondador de ciénaga
Bruja Osaria
Jefe Vayachi
Corapetra
Brack
Noble con lavado de cerebro
Quebrarramas
Brotasangre
Bro'Gaz sin Clan
Diente partido
Lanzarrota
Brontus
Hermano Roblecuervo
Bruegal Nudoferro
Ojo Ladrón
Guardia vil ardiente
Capo el Miserable [UNUSED]
Capitana Armisticio
Capitán Colmillo Plano
Capitán Gerogg Piemartillo
Capitán Greshkil
Carnivous el Rompedor
Castañeta
Ingeniero jefe Lorthander
Goraluk Yunquegrieta navideño
Clack el Atracador
Madrezarpa Zavas
Emisaria Colmillo Torcido
Collidus el Vigía
Comandante Yelestrón
Craig Steele
Craig Steele (1)
Craig Steele (2)
Craig Steele2
Craig Steele2 (1)
Craig Steele3
Cascarrabias Ben
Superviviente Indu'le enloquecido
Trepazoso
Lisiador
Pincitas
Colmillo de cristal
Centauro maldito
Cyclok el Loco
Escribachizo de Molino Ámbar
Darbel Montrosa
Embajador Hierro Negro
Viuda Niebla Negra
Dardo
Despellejador de la Muerte
Aullador de la Muerte
Robaalmas caballero de la Muerte
Ojo de la Muerte
Faucemuerte
Portavoz de la muerte Selendre
Capitán Juramorte
Deeb
Dessecus
Dragón feérico descarriado
Cabeza Diamante
Cavador Flamaforja
Maestro de excavación Palatiro
Dirkee
Dishu
Orador del Sino Jurim
Dr. Miembro Marchito
Maestro de batalla Faucedraco
Desdeñamiedos
Rumoratroz
Vigía de los sueños Lengua Bífida
Drogoth el Vagabundo
Duggan Martillo Salvaje
Duque Atracador
Acechador nocturno
Ánima de polvo
Clamatierras Halmgar
Eck'alom
Edan el Aullador
Anciana mística Filocico
Eldinarcus
Emogg el Triturador
Déspota Emilgund
Ingeniero Giralesín
Núcleo eterno el Castigador
Campeón caído
Granjero Solliden
Gólem de guerra defectuoso
Fedfennel
Felendor la Acusadora
Sombra de Felicent
Tejeyel Scronn
Fenissa la Asesina
Fenros
Fingat
Clamafuegos Radison
Fjordune el Grande
Fjordune the Greater (1)
Fjordune the Greater (2)
Fjordune the Greater (3)
Flagglemurk el Cruel
Siegaenemigos 4000
Supervisor Asas
Supervisor Jerris
Supervisor Marcrid
Supervisor Rigger
Panzatroz
Crinatroz
Atiborrador
Fumblub Vientoencajado
Furia Shelda
Garneg Hullacráneo
Gash'nak el Caníbal
Gash'nak the Cannibal (1)
Gash'nak the Cannibal (2)
Gash'nak the Cannibal (3)
Guardián Gruñefuria
General Colbatann
General Colmiterror
Geoseñor Motas
Geomántico Dagasílex
Geosacerdote Gukk'rok
Gesharahan
Ghok Bashguud
Aullido Fantasma
Gibblesnik
Gibblewilt
Mueca
Gilmorian
Gish el Inamovible
Gluggl
Núdor Fraterfolio
Roehuesos
Gondria
Goraluk Yunquegrieta
Mandisangre
Dientegore
Gorgon'och
Grash Cebatruenos
Gravis Nudocorredizo
Gran patriarca Arctikus
Alascuas
Gretheer
Griegen
Faucenestra
Grimungus
Kubb
Pardo Patanieve
Grocklar
Grubthor
Gruff
Bronco Mordeveloz
Gruklash
Gruñón
Haarka el Voraz
Hagg Taurruina
Hahk'Zor
Martidorsal
Hannah Filohoja
Harb Monte Fétido
Hayoc
Cantachimeneas Forresten
Cuorevaja
Hed'mush el Podrido
Heggin Pelopiedra
Hemathion
Hematos
Lynnia Abbendis
Suma sacerdotisa Hai'watna
Señor feudal Jorfus
Alto señor Mastrogonde
Hildana Quitaalmas
Hissperak
Humar el Señor Orgulloso
Huricanian
Hyakiss el Rondador
Hielocuerno
Immolatus
Espaldacerada
Ojohierro el Invencible
Dorsacerado
Jade
Jalinde Dracoestío
Jed Vigía de las Runas
Jimmy el Sangrador
Jin'Zallah el Arenero
Kashoch el Atracador
Kaskk
Kazon
Kelemis el Difunto
Rey Krush
Rey Mosh
Rey Ping
Kovork
Kraator
Kregg Volcayecto
Krellack
Krethis Tejeumbra
Kurmokk
Lady Hederine
Lady Miraluna
Lady Sesspira
Lady Szallah
Lady Vespia
Lady Vespira
Lady Zephris
Lapress
Gosh-Haldir
Viuda sanguijuela
Leprithus
Licillin
Lizzle Engranágil
Lo'Grosh
Loque'nahak
Señor Pescador
Capitán Wyrmak
Lord Condar
Lord Hoz Oscura
Lord Hel'nurath
Lord Malathrom
Lord Maldazzar
Lord Sakrasis
Lord Sesgapecados
Cabecilla Perdido
Cocinero Perdido
Alma perdida
Horror torpe
Lupos
Ma'ruk Vermiscala
Magistrix Yelmalcón
Magosh
Magronos el Implacable
Atracador estropeado
Malgin Cebadiz
Marcus Bel
Marisa du'Paige
Marticar
Maestro excavador
Maestro Pavoria
Mazzranache
Mekthorg el Salvaje
Meshlok el Cosechador
Mezzir el Aullador
[UNUSED 4.x ]Minero Johnson
Lodonante
Aullanieblas
Mith'rethis el Encantador
Mojo el Retorcido
Molok el Triturador
Fundespino
Mongress
Monnos el Viejo
Morchaca
Morgaine la Astuta
Madre Colmillo
Muad
Aletereje
Llagapata mortífera
Mushgog
Nal'taszar
Naraxis
Narg el Capataz
Narillasanz
Nefaru
Sobrestante nerubiano
Netherstorm Rare Chimaera UNUSED
Nimar el Destripador
Nuramoc
Pataroble
Okrek
Viejo Saltariscos
Viejo Ladracristal
Viejo Tripasgrises
Viejo Malafauce
Olm el Sabio
Omgorn el Perdido
Mocogusano
Panzor el Invencible
Perobas el Sediento de sangre
Patriarca Alaorgullo
Sacerdotisa de Elune
Príncipe Kellen
Príncipe Nazjak
Príncipe Raze
Putridus
Putridus el Antiguo
Piromántico Fruto del Saber
QA Test Dummy 82 High Damage
QA Test Dummy 83 High Damage
Qirot
Quest - Northrend BG - Gate Kill
Quest - Wintergrasp - Bridge Kill
Quest - Wintergrasp - Gate Kill
Quest - Wintergrasp - PvP Kill - Alliance
Quest - Wintergrasp - PvP Kill - Fire
Quest - Wintergrasp - PvP Kill - Horde
Quest - Wintergrasp - PvP Kill - Life
Quest - Wintergrasp - PvP Kill - Shadow
Quest - Wintergrasp - PvP Kill - Vehicle
Quest - Wintergrasp - PvP Kill - Water
Quest - Wintergrasp - Southern Tower Kill
Quest - Wintergrasp - Structure Kill
Quest - Wintergrasp - Tower Kill
Quest - Wintergrasp - Vehicle Protected
Quest - Wintergrasp - Wall Kill
Quest - Wintergrasp - Workshop Kill
Patafuria
Rak'shiri
Cazador letal Lanzalcón
Rathorian
Devastatia
Matriarca ravasaurio
Regente Corvozarpa
Cuerolanza de Rajacieno
Matriarca Tajobuche
Filogarra
Rekk'tilac
Ressan el Agujas
Retherokk el Rabioso
Rex Ashil
Rezrelek
Rezrelek (1)
Rezrelek (2)
Rezrelek (3)
Rompecostillas
Rippa
Rasgascama
Ro'Bark
Lanzapiedras
Rohh el Silencioso
Rokad el Devastador
Roloch
Rorgish Jowl
Truhán Putrepellejo
Estruendor
Ruul Onapiedra
Sandarr Asaltadunas
Gusano de arena
Escaldar
Panzascama
Barbascamas
Rasgabranquia
Verdugo Escarlata
Alto Clérigo Escarlata
Alta señora Escarlata Daion
Interrogador Escarlata
Juez Escarlata
Herrero Escarlata
Intendente del Escudo del Estigma
Scillia Dagapluma
Scott Keenan
Buscador Aqualon
Odio hirviente
Centinela Amarassan
Sargento Garravil
Serra Colinhogar
Setis
Bestia de cloaca
Shadikith el Planeador
Garrasombría
Comandante de Forjatiniebla
Shanda la Giratoria
Shleipnarr
Barricada
Cosechador silítido
Krkk'kx
Kantor
Hermana Azote de Odio
Hermana Rathtalon
Hermana Riven
Skarr el Roto
Skhowl
Skoll
Skul
Eslarc
Maestro de esclavos Negrozón
Dragón durmiente
Anomalía de lodo
Barrosín
Smoldar
Jalalanza
Gruñidor
Llamagruños
Melegruños
Bufo el Molesto
Soriid el Devorador
Alapenas
Alma de Tanaris
Portavoz Mar'grom
Señor de batalla Cumbrerroca
Carnicero Cumbrerroca
Señor Magus Cumbrerroca
Espíritu de los Malditos
Escupetripas
Squiddic
Sri'skulk
Staggon
Maggarrak
Brazorroca
Pidrespina
Zancador Madrezarpa
Velocrín
Suingart Cuerolanza
Syreian la Talahuesos
Takk el Saltarín
Tamra Pico Tormenta
Capataz Latimillo
Jiroculto
Tatterhide (1)
Tatterhide (2)
Tatterhide (3)
Tepolar
Hilador de terror
Chispa terrorífica
Señor de la manada Luporror
Thauris Balgarr
El Behemoth
El Evalcharr
La Cáscara
El Ongar
El Despedazador
El Razza
El Rik
El Podrido
Thora Plumaluna
Threggil
Silenciatruenos
Thurmonde el Devoto
Thuros Dedos Ligeros
Gris
Protodraco Tiempo Perdido
Espíritu atormentado
Tregla
Tritesta el Azotador
Tsu'zee
Tukemuth
Señor Crepuscular Everun
Uhk'loc
Ursol'lok
Uruson
Ushalac, el Morador de la oscuridad
Ushalac the Gloomdweller (1)
Ushalac the Gloomdweller (2)
Ushalac the Gloomdweller (3)
Fantasma de Varo'then
Anciano vengativo
Verek
Verifonix
Vern
Veyzhak el Caníbal
Vigdis la Doncella de la guerra
Aguijón vil
Cazador del vacío Yar
Volchan
Vorakem Augurador
Vultros
Vyragosa
Gólem de guerra
Depositario Stilgiss
Líder de guerra Krazzilak
Señor de la guerra Kolkanis
Señor de la guerra Thresh'jin
Sargento Curtis
Wep
Blancorazón el Acechador
Yor <UNUSED>
Zalas Secacorteza
Zaricotl
Zekkis
Zerillis
Zora
Ramurdimbre Zul'Brin
Matagallinas Zul'arek
Centinela de Zul'drak
Sombra de Shadumbra
[UNUSED] Hija de Majestis
[UNUSED] Kern el Déspota
[UNUSED] Observador Kolkar
Princesa de las mareas Colafuria
]],
    esMX = [[
7:XT
Filozante detestable
Achellios el Desterrado
Aean Río Veloz
Akkrilus
Akubar el Vidente
Alshirr Respiramiedo
Embajador Sanguinarius
Embajador Jerrikar
Anathemus
Antilos
Antilus el Surcador
Aotona
Boticario Falthis
Araga
Arash-ethis
Arcturis
Azshir el Insomne
Azurous
Azzere el Filo del Cielo
Bannok Hacha Macabra
Barnabus
Barón Malasangre
Bayne
Ben
Berylgos
Gran Samras
Bjarn
Musgonegro el Fétido
Cazador ciego
Rugesangre el Acechador
Boahn
Rondador de ciénaga
Bruja Osaria
Jefe Vayachi
Corapetra
Brack
Noble con lavado de cerebro
Quebrarramas
Brotasangre
Bro'Gaz sin Clan
Diente partido
Lanzarrota
Brontus
Hermano Roblecuervo
Bruegal Nudoferro
Ojo Ladrón
Guardia vil ardiente
Capo el Miserable [UNUSED]
Capitana Armisticio
Capitán Colmillo Plano
Capitán Gerogg Piemartillo
Capitán Greshkil
Carnivous el Rompedor
Castañeta
Ingeniero jefe Lorthander
Goraluk Yunquegrieta navideño
Clack el Atracador
Madrezarpa Zavas
Emisaria Colmillo Torcido
Collidus el Vigía
Comandante Yelestrón
Craig Steele
Craig Steele (1)
Craig Steele (2)
Craig Steele2
Craig Steele2 (1)
Craig Steele3
Cascarrabias Ben
Superviviente Indu'le enloquecido
Trepazoso
Lisiador
Pincitas
Colmillo de cristal
Centauro maldito
Cyclok el Loco
Escribachizo de Molino Ámbar
Darbel Montrosa
Embajador Hierro Negro
Viuda Niebla Negra
Dardo
Despellejador de la Muerte
Aullador de la Muerte
Robaalmas caballero de la Muerte
Ojo de la Muerte
Faucemuerte
Portavoz de la muerte Selendre
Capitán Juramorte
Deeb
Dessecus
Dragón feérico descarriado
Cabeza Diamante
Cavador Flamaforja
Maestro de excavación Palatiro
Dirkee
Dishu
Orador del Sino Jurim
Dr. Miembro Marchito
Maestro de batalla Faucedraco
Desdeñamiedos
Rumoratroz
Vigía de los sueños Lengua Bífida
Drogoth el Vagabundo
Duggan Martillo Salvaje
Duque Atracador
Acechador nocturno
Ánima de polvo
Clamatierras Halmgar
Eck'alom
Edan el Aullador
Anciana mística Filocico
Eldinarcus
Emogg el Triturador
Déspota Emilgund
Ingeniero Giralesín
Núcleo eterno el Castigador
Campeón caído
Granjero Solliden
Gólem de guerra defectuoso
Fedfennel
Felendor la Acusadora
Sombra de Felicent
Tejeyel Scronn
Fenissa la Asesina
Fenros
Fingat
Clamafuegos Radison
Fjordune el Grande
Fjordune the Greater (1)
Fjordune the Greater (2)
Fjordune the Greater (3)
Flagglemurk el Cruel
Siegaenemigos 4000
Supervisor Asas
Supervisor Jerris
Supervisor Marcrid
Supervisor Rigger
Panzatroz
Crinatroz
Atiborrador
Fumblub Vientoencajado
Furia Shelda
Garneg Hullacráneo
Gash'nak el Caníbal
Gash'nak the Cannibal (1)
Gash'nak the Cannibal (2)
Gash'nak the Cannibal (3)
Guardián Gruñefuria
General Colbatann
General Colmiterror
Geoseñor Motas
Geomántico Dagasílex
Geosacerdote Gukk'rok
Gesharahan
Ghok Bashguud
Aullido Fantasma
Gibblesnik
Gibblewilt
Mueca
Gilmorian
Gish el Inamovible
Gluggl
Núdor Fraterfolio
Roehuesos
Gondria
Goraluk Yunquegrieta
Mandisangre
Dientegore
Gorgon'och
Grash Cebatruenos
Gravis Nudocorredizo
Gran patriarca Arctikus
Alascuas
Gretheer
Griegen
Faucenestra
Grimungus
Kubb
Pardo Patanieve
Grocklar
Grubthor
Gruff
Bronco Mordeveloz
Gruklash
Gruñón
Haarka el Voraz
Hagg Taurruina
Hahk'Zor
Martidorsal
Hannah Filohoja
Harb Monte Fétido
Hayoc
Cantachimeneas Forresten
Cuorevaja
Hed'mush el Podrido
Heggin Pelopiedra
Hemathion
Hematos
Lynnia Abbendis
Suma sacerdotisa Hai'watna
Señor feudal Jorfus
Alto señor Mastrogonde
Hildana Quitaalmas
Hissperak
Humar el Señor Orgulloso
Huricanian
Hyakiss el Rondador
Hielocuerno
Immolatus
Espaldacerada
Ojohierro el Invencible
Dorsacerado
Jade
Jalinde Dracoestío
Jed Vigía de las Runas
Jimmy el Sangrador
Jin'Zallah el Arenero
Kashoch el Atracador
Kaskk
Kazon
Kelemis el Difunto
Rey Krush
Rey Mosh
Rey Ping
Kovork
Kraator
Kregg Volcayecto
Krellack
Krethis Tejeumbra
Kurmokk
Lady Hederine
Lady Miraluna
Lady Sesspira
Lady Szallah
Lady Vespia
Lady Vespira
Lady Zephris
Lapress
Gosh-Haldir
Viuda sanguijuela
Leprithus
Licillin
Lizzle Engranágil
Lo'Grosh
Loque'nahak
Señor Pescador
Capitán Wyrmak
Lord Condar
Lord Hoz Oscura
Lord Hel'nurath
Lord Malathrom
Lord Maldazzar
Lord Sakrasis
Lord Sesgapecados
Cabecilla Perdido
Cocinero Perdido
Alma perdida
Horror torpe
Lupos
Ma'ruk Vermiscala
Magistrix Yelmalcón
Magosh
Magronos el Implacable
Atracador estropeado
Malgin Cebadiz
Marcus Bel
Marisa du'Paige
Marticar
Maestro excavador
Maestro Pavoria
Mazzranache
Mekthorg el Salvaje
Meshlok el Cosechador
Mezzir el Aullador
[UNUSED 4.x ]Minero Johnson
Lodonante
Aullanieblas
Mith'rethis el Encantador
Mojo el Retorcido
Molok el Triturador
Fundespino
Mongress
Monnos el Viejo
Morchaca
Morgaine la Astuta
Madre Colmillo
Muad
Aletereje
Llagapata mortífera
Mushgog
Nal'taszar
Naraxis
Narg el Capataz
Narillasanz
Nefaru
Sobrestante nerubiano
Netherstorm Rare Chimaera UNUSED
Nimar el Destripador
Nuramoc
Pataroble
Okrek
Viejo Saltariscos
Viejo Ladracristal
Viejo Tripasgrises
Viejo Malafauce
Olm el Sabio
Omgorn el Perdido
Mocogusano
Panzor el Invencible
Perobas el Sediento de sangre
Patriarca Alaorgullo
Sacerdotisa de Elune
Príncipe Kellen
Príncipe Nazjak
Príncipe Raze
Putridus
Putridus el Antiguo
Piromántico Fruto del Saber
QA Test Dummy 82 High Damage
QA Test Dummy 83 High Damage
Qirot
Quest - Northrend BG - Gate Kill
Quest - Wintergrasp - Bridge Kill
Quest - Wintergrasp - Gate Kill
Quest - Wintergrasp - PvP Kill - Alliance
Quest - Wintergrasp - PvP Kill - Fire
Quest - Wintergrasp - PvP Kill - Horde
Quest - Wintergrasp - PvP Kill - Life
Quest - Wintergrasp - PvP Kill - Shadow
Quest - Wintergrasp - PvP Kill - Vehicle
Quest - Wintergrasp - PvP Kill - Water
Quest - Wintergrasp - Southern Tower Kill
Quest - Wintergrasp - Structure Kill
Quest - Wintergrasp - Tower Kill
Quest - Wintergrasp - Vehicle Protected
Quest - Wintergrasp - Wall Kill
Quest - Wintergrasp - Workshop Kill
Patafuria
Rak'shiri
Cazador letal Lanzalcón
Rathorian
Devastatia
Matriarca ravasaurio
Regente Corvozarpa
Cuerolanza de Rajacieno
Matriarca Tajobuche
Filogarra
Rekk'tilac
Ressan el Agujas
Retherokk el Rabioso
Rex Ashil
Rezrelek
Rezrelek (1)
Rezrelek (2)
Rezrelek (3)
Rompecostillas
Rippa
Rasgascama
Ro'Bark
Lanzapiedras
Rohh el Silencioso
Rokad el Devastador
Roloch
Rorgish Jowl
Truhán Putrepellejo
Estruendor
Ruul Onapiedra
Sandarr Asaltadunas
Gusano de arena
Escaldar
Panzascama
Barbascamas
Rasgabranquia
Verdugo Escarlata
Alto Clérigo Escarlata
Alta señora Escarlata Daion
Interrogador Escarlata
Juez Escarlata
Herrero Escarlata
Intendente del Escudo del Estigma
Scillia Dagapluma
Scott Keenan
Buscador Aqualon
Odio hirviente
Centinela Amarassan
Sargento Garravil
Serra Colinhogar
Setis
Bestia de cloaca
Shadikith el Planeador
Garrasombría
Comandante de Forjatiniebla
Shanda la Giratoria
Shleipnarr
Barricada
Cosechador silítido
Krkk'kx
Kantor
Hermana Azote de Odio
Hermana Rathtalon
Hermana Riven
Skarr el Roto
Skhowl
Skoll
Skul
Eslarc
Maestro de esclavos Negrozón
Dragón durmiente
Anomalía de lodo
Barrosín
Smoldar
Jalalanza
Gruñidor
Llamagruños
Melegruños
Bufo el Molesto
Soriid el Devorador
Alapenas
Alma de Tanaris
Portavoz Mar'grom
Señor de batalla Cumbrerroca
Carnicero Cumbrerroca
Señor Magus Cumbrerroca
Espíritu de los Malditos
Escupetripas
Squiddic
Sri'skulk
Staggon
Maggarrak
Brazorroca
Pidrespina
Zancador Madrezarpa
Velocrín
Suingart Cuerolanza
Syreian la Talahuesos
Takk el Saltarín
Tamra Pico Tormenta
Capataz Latimillo
Jiroculto
Tatterhide (1)
Tatterhide (2)
Tatterhide (3)
Tepolar
Hilador de terror
Chispa terrorífica
Señor de la manada Luporror
Thauris Balgarr
El Behemoth
El Evalcharr
La Cáscara
El Ongar
El Despedazador
El Razza
El Rik
El Podrido
Thora Plumaluna
Threggil
Silenciatruenos
Thurmonde el Devoto
Thuros Dedos Ligeros
Gris
Protodraco Tiempo Perdido
Espíritu atormentado
Tregla
Tritesta el Azotador
Tsu'zee
Tukemuth
Señor Crepuscular Everun
Uhk'loc
Ursol'lok
Uruson
Ushalac, el Morador de la oscuridad
Ushalac the Gloomdweller (1)
Ushalac the Gloomdweller (2)
Ushalac the Gloomdweller (3)
Fantasma de Varo'then
Anciano vengativo
Verek
Verifonix
Vern
Veyzhak el Caníbal
Vigdis la Doncella de la guerra
Aguijón vil
Cazador del vacío Yar
Volchan
Vorakem Augurador
Vultros
Vyragosa
Gólem de guerra
Depositario Stilgiss
Líder de guerra Krazzilak
Señor de la guerra Kolkanis
Señor de la guerra Thresh'jin
Sargento Curtis
Wep
Blancorazón el Acechador
Yor <UNUSED>
Zalas Secacorteza
Zaricotl
Zekkis
Zerillis
Zora
Ramurdimbre Zul'Brin
Matagallinas Zul'arek
Centinela de Zul'drak
Sombra de Shadumbra
[UNUSED] Hija de Majestis
[UNUSED] Kern el Déspota
[UNUSED] Observador Kolkar
Princesa de las mareas Colafuria
]],
    deDE = [[
7:XT
Verfluchter der Zackenkämme
Achellios der Verbannte
Aean Flinkbach
Akkrilus
Akubar der Seher
Alshirr Teufelsodem
Botschafter Blutzorn
Botschafter Jerrikar
Anathemus
Antilos
Antilus der Aufsteiger
Aotona
Apotheker Falthis
Araga
Arash-ethis
Arcturis
Azshir der Schlaflose
Azurous
Azzere die Himmelsklinge
Bannok Grimmaxt
Barnabus
Baron Blutbann
Bayne
Ben
Berylgos
Der Große Samras
Bjarn
Schwarzmoos der Stinker
Blinder Jäger
Blutschrei der Pirscher
Boahn
Sumpflauerer
Knochenhexe
Boss Galgosh
Felsenherz
Brack
Manipulierter Adliger
Astschnapper
Schwefelblut
Bro'Gaz der Klanlose
Zerbrochener Zahn
Bruchspeer
Brontus
Bruder Rabeneiche
Bruegal Eisenfaust
Schwarzauge
Brennende Teufelswache
Capo der Gemeine
Hauptmann Waffenruh
Hauptmann Stumpfhauer
Hauptmann Gerogg Hammerzeh
Hauptmann Greshkil
Carnivous der Zerstörer
Chatter
Chefingenieur Lorthander
Winterboss Goraluk Hammerbruch
Clack der Häscher
Gelegemutter Zavas
Abgesandte des Echsenkessels
Collidus der Sphärenwächter
Kommandant Felstrom
Craig Steele
Craig Steele (1)
Craig Steele (2)
Craig Steele2
Craig Steele2 (1)
Craig Steele3
Benj der Missmutige
Wahnsinniger Überlebender von Indu'le
Kriechfänger
Verkrüppler
Krusti
Kristallfangzahn
Verfluchter Zentaur
Cyclok der Irre
Zauberschreiber von Mühlenbern
Darbel Montrose
Botschafter der Dunkeleisenzwerge
Graunebelwitwe
Pfeil
Todesschinder
Todesheuler
Todesritter Seelenspalter
Todesauge
Totenreißer
Todessprecher Selendre
Todeshöriger Hauptmann
Deeb
Moosmannus
Deviatfeendrache
Diamantenkopf
Buddler Flammenschmied
Grubenmeister Schaufelphlansch
Dirkee
Dishu
Verdammnisverkünder Jurim
Dr. Krummbein
Kampfmeister des Drachenmals
Mutreich
Todesraunen
Traumbehüter Spaltzunge
Drogoth der Wanderer
Duggan Wildhammer
Fürst Zornschlächter
Dämmerpirscher
Karaburan
Erdenrufer Halmgar
Eck'alom
Edan der Heuler
Alte Mystikerin Grimmschnauze
Eldinarcus
Emogg der Zermalmer
Vollstrecker Emilgund
Ingenieur Wirbelgig
Steinherz der Bestrafer
Gefallener Champion
Bauer Solliden
Defekter Kriegsgolem
Fedfennel
Felendor die Anklägerin
Fellicents Schemen
Höllenwirker Hoohn
Fenissa die Assassine
Fenros
Flossgat
Feuerrufer Radison
Fjordune der Größere
Fjordune the Greater (1)
Fjordune the Greater (2)
Fjordune the Greater (3)
Platsch der Grausame
Feindschnitter 4000
Großknecht Grills
Großknecht Jerris
Großknecht Marcrid
Großknecht Rigger
Faulbauch
Faulmähne
Gierschlund
Flumblub Gangwindung
Furie Shelda
Garneg Brandschädel
Gash'nak der Kannibale
Gash'nak the Cannibal (1)
Gash'nak the Cannibal (2)
Gash'nak the Cannibal (3)
Torwächter Donnerschrei
General Colbatann
General Fangferror
Geofürst Sprenkel
Geomant Flintdolch
Geopriester Gukk'rok
Gesharahan
Ghok Haudrauf
Geistheuler
Gibblesnik
Frickelwelk
Kicherer
Kiemorius
Gish der Unbewegliche
Gluckser
Laubbruder Knarz
Knochennager
Gondria
Goraluk Hammerbruch
Blutmaul
Bluthauer
Gorgon'och
Grash Donnerbräu
Gravis Galgenknoten
Altvater Arktikus
Glutschwinge
Gretheer
Griegen
Grimmtatze
Grimungous
Kubb
Grizzel Schneepfote
Grocklar
Grubthor
Gruff
Gruff Schnappflink
Gruklash
Suhlaman
Haarka der Gefräßige
Hagg Taurenfluch
Hahk'Zor
Baumfaust
Hannah Messerblatt
Harb Faulberg
Hayoc
Herdsinger Forresten
Klingenherz
Hed'mush der Faulende
Heggin Steinbart
Hemathion
Hematos
Hochgeneral Abbendis
Hohepriesterin Hai'watna
Hochthan Jorfus
Hochlord Mastrogonde
Hildana Todesstehler
Hissperak
Humar der Rudellord
Hurrikanus
Hyakiss der Lauerer
Eishorn
Korruptus
Eisenpanzer
Eisenauge der Unbesiegbare
Eisenrücken
Jade
Jalinde Sommerdrache
Jed Runenblick
Jimmy der Bluter
Jin'Zallah der Sandbringer
Kashoch der Häscher
Kaskk
Kazon
Kelemis der Leblose
König Knirsch
König Mosh
King Ping
Kovork
Kraator
Kregg Kielhol
Krellack
Krethis Schattennetz
Kurmokk
Lady Hederine
Lady Mondblick
Lady Sesspira
Lady Szallah
Lady Vespia
Lady Vespira
Lady Zephris
Lapress
Gosh-Haldir
Egelwitwe
Leprithus
Licillin
Lizzle Flinkspross
Lo'Grosh
Loque'nahak
Lord Angler
Hauptmann Wyrmak
Lord Condar
Lord Finstersense
Lord Hel'nurath
Lord Malathrom
Lord Maldazzar
Lord Sakrasis
Lord Sündenbrecher
Häuptling der Verirrten
Koch der Verirrten
Verirrte Seele
Schwerfälliger Schrecken
Lupos
Ma'ruk Wyrmschuppe
Magister Falkhelm
Magosh
Magronos der Unerschütterliche
Fehlfunktionierender Häscher
Malgin Gerstenbräu
Marcus Bel
Marisa du'Paige
Marticar
Meisterbuddler
Meister Gräuelbart
Mazzranach
Mekthorg der Wilde
Meshlok der Ernter
Mezzir der Heuler
Minenarbeiter Johnson
Brülmor
Nebelheuler
Mith'rethis der Verzauberer
Mojo der Verwachsene
Molok der Zermalmer
Moosbart
Mongress
Monnos der Älteste
Mordruck
Morgaine die Verschlagene
Giftzahnbrutmutter
Muad
Muggelflosse
Mordlustige Eiterpfote
Mushgog
Nal'taszar
Naraxis
Narg der Zuchtmeister
Narillasanz
Nefaru
Nerubischer Aufseher
Schimäre des Nethersturms
Nimar der Töter
Nuramoc
Knurrtatze
Okrek
Klippenspringer
Alte Kristallborke
Silbergrimm der Weise
Zwingenkiefer
Olm der Weise
Omgorn der Verirrte
Schlammwurm
Panzor der Unbesiegbare
Perobas der Blutdürster
Prachtschwingenpatriarch
Priesterin von Elune
Prinz Kellen
Prinz Nazjak
Prinz Schleifer
Putridius
Putridus der Uralte
Pyromant Weisenkorn
QA Test Dummy 82 High Damage
QA Test Dummy 83 High Damage
Qirot
Quest - Northrend BG - Gate Kill
Quest - Wintergrasp - Bridge Kill
Quest - Wintergrasp - Gate Kill
Quest - Wintergrasp - PvP Kill - Allianz
Quest - Wintergrasp - PvP Kill - Fire
Quest - Wintergrasp - PvP Kill - Horde
Quest - Wintergrasp - PvP Kill - Life
Quest - Wintergrasp - PvP Kill - Shadow
Quest - Wintergrasp - PvP Kill - Vehicle
Quest - Wintergrasp - PvP Kill - Water
Quest - Wintergrasp - Southern Tower Kill
Quest - Wintergrasp - Structure Kill
Quest - Wintergrasp - Tower Kill
Quest - Wintergrasp - Vehicle Protected
Quest - Wintergrasp - Wall Kill
Quest - Wintergrasp - Workshop Kill
Wutpranke
Rak'shiri
Todesjäger Falkenspeer
Rathorian
Verheerer
Ravasaurusmatriarchin
Regent von Rabenklaue
Speerträger der Klingenhauer
Scharfzahnmatriarchin
Reißerklaue
Rekk'tilac
Ressan der Aufstachler
Retherokk der Berserker
Rex Ashil
Rezrelek
Rezrelek (1)
Rezrelek (2)
Rezrelek (3)
Rippenbrecher
Rippa
Reißerschuppe
Ro'Bell
Felslanze
Rohh der Schweigsame
Rokad der Verheerer
Roloch
Grummelkehle
Haudrauf der Moderfelle
Rumpler
Ruul Zweistein
Sandarr der Wüstenräuber
Sandwurm
Scald
Schuppenbauch
Schuppenbart
Narbenflosse
Scharlachroter Henker
Scharlachroter Hochkleriker
Scharlachrote Hochfürstin Daion
Scharlachroter Befrager
Scharlachroter Richter
Scharlachroter Schmied
Rüstmeister der Schmetterschilde
Scillia Dolchfeder
Scott Keenan
Sucher Aqualon
Wutentbrannter Hass
Schildwache Amarassan
Unteroffizier Geiferkralle
Serra Bergesheim
Setis
Kanalbestie
Shadikith der Gleiter
Schattenklaue
Kommandant der Schattenschmiede
Shanda die Weberin
Shleipnarr
Barrikade
Silithidernter
Krkk'kx
Sängerin
Schwester Hasspeitsche
Schwester Wildkralle
Schwester Sichelschwinge
Skarr der Gebrochene
Skhowl
Skoll
Skul
Slark
Sklavenmeister Schwarzherz
Schlafender Großdrache
Schlickanomalie
Schlicker
Smoldar
Stummelspeer
Knurrer
Fletschzahn
Knurrmähne
Snort der Spucker
Soriid der Verschlinger
Trauerschwinge
Seele von Tanaris
Sprecher Mar'grom
Kampflord der Felsspitzoger
Metzger der Felsspitzoger
Maguslord der Felsspitzoger
Geist der Verdammten
Fledderschnabel
Kalmarrik
Sri'skulk
Staggon
Maggarrak
Steinarm
Steinbuckel
Schreitergelegemutter
Flinkmähne
Speerträger Schweingart
Syreian die Knochenschnitzerin
Takk der Springer
Tamra Sturmlanze
Zuchtmeister Peitschzahn
Zottelfell
Tatterhide (1)
Tatterhide (2)
Tatterhide (3)
Tepolar
Terrorspinner
Terrorstifter
Terrowulfrudelführer
Thauris Balgarr
Das Ungetüm
Evalcharr
Die Hülse
Der Ongar
Der Kratzer
Der Razza
Der Reak
Der Faulende
Thora Mondfeder
Threggil
Donnerstampfer
Thurmonde der Andächtige
Thuros Flinkfinger
Holzkopf
Zeitverlorener Protodrache
Gepeinigter Geist
Tregla
Trigore der Peitscher
Tsu'zee
Tukemuth
Zwielichtfürst Everun
Uhk'loc
Ursol'lok
Uruson
Ushalac der im Düsteren haust
Ushalac the Gloomdweller (1)
Ushalac the Gloomdweller (2)
Ushalac the Gloomdweller (3)
Varo'thens Geist
Rachsüchtiges Urtum
Verek
Verifonix
Vern
Veyzhack der Kannibale
Vigdis die Kriegsmaid
Übelstich
Leerjäger Yar
Volchan
Vorakem Unheilsbote
Vultros
Vyragosa
Kriegsgolem
Wärter Stilgiss
Kriegsanführer Krazzilak
Kriegsherr Kolkanis
Kriegsherr Thresh'jin
Unteroffizier Curtis
Wep
Kaltherz der Streicher
Yor <UNUSED>
Zalas Bleichborke
Zaricotl
Zekkis
Zerillis
Zora
Zul'Brin Wirbelstab
Zul'arek Faulhass
Schildwache von Zul'Drak
Schatten von Schattumbra
[UNUSED] Deathcaller Majestis
[UNUSED] Kern the Enforcer
[UNUSED] Kolkar Observer
Gezeitenprinzessin der Rächerflossen
]],
    frFR = [[
7:XT
Ondulame maudit
Achellios le Banni
Aean Ondevive
Akkrilus
Akubar le Prophète
Alshirr Souffléau
Ambassadeur Ragesang
Ambassadeur Jerrikar
Anathème
Antilos
Antilus le Planeur
Aotona
Apothicaire Falthis
Araga
Arash-Ethis
Arcturis
Azshir le Sans-Sommeil
Azurous
Azzere la lame céleste
Bannok Hache-Sinistre
Barnabus
Baron Sangreplaie
Bayne
Ben
Berylgos
Gros Samras
Bjarn
Noiremousse le Fétide
Chasseur aveugle
Rugissang le Traqueur
Boahn
Rôdeur des tourbières
Sorcière des ossements
Boss Galgosh
Rochecœur
Brack
Noble manipulé
Brise-Branche
Soufresang
Bro'Gaz Sans-Clan
Brèchedent
Brise-Epieu
Brontus
Frère Corvichêne
Bruegal Poing-de-Fer
Pique-les-Yeux
Gangregarde ardent
[INUTILISÉ] Capo le mauvais
Capitaine Armistice
Capitaine Plate-Défense
Capitaine Gerogg Martèlorteil
Capitaine Greshkil
Carnivous le Casseur
Cliqueteuse
Ingénieur en chef Lorthander
Goraluk Brisenclume de Noël
Clack le Saccageur
Matriarche Zavas
Emissaire de Glissecroc
Collidus le Guetteur-Dimensionnel
Commandant Gangretrombe
Craig Steele
Craig Steele (1)
Craig Steele (2)
Craig Steele2
Craig Steele2 (1)
Craig Steele3
Benj le teigneux
Survivant d'Indu'le affolé
Insinueuse
Estropieur
Croustille
Croc cristallin
Centaure maudit
Cyclok le Fol
Copiste de Moulin-de-l'Ambre
Darbel Montrose
Ambassadeur sombrefer
Veuve de Sombrebrume
Flèche
Ecorcheur mortel
Hurlemort
Chevalier de la mort Porte-l'âme
Oeil-de-mort
Gueule-du-trépas
Nécroratrice Selendre
Capitaine Ligemort
Deeb
Dessecus
Dragon féerique déviant
Tête-de-diamant
Terrassier Forgeflamme
Maître des fouilles Pellaphlange
Dirkee
Dishu
Auspice funeste Jurim
Docteur Gâtemembre
Maître de guerre gueule-de-dragon
Dériseffroi
Bruissangoisse
Gardien des rêves Langue-Fourchue
Drogoth le Vagabond
Duggan Marteau-hardi
Duc Ravarage
Traqueur de la pénombre
Ame en peine poudreuse
Implorateur de la terre Halmgar
Eck'alom
Edan le Hurleur
Ancienne mystique Tranchegroin
Eldinarcus
Emogg le Broyeur
Massacreur Emilgund
Ingénieur Tourbicoton
Permacœur le Punisseur
Champion déchu
Fermier de Solliden
Golem de guerre défaillant
Fenouillard
Felendor l'Accusateur
Ombre de Fellicent
Gangretisseur Arrogg
Fenissa l'Assassin
Fenros
Fingat
Mandefeu Radison
Fjordune le Très-Grand
Fjordune le Grand (1)
Fjordune le Grand (2)
Fjordune le Grand (3)
Flagglemurk le Cruel
Faucheur 4000
Contremaître Grills
Contremaître Jerris
Contremaître Marcrid
Contremaître Gréeur
Souillebedon
Vilcrin
Goinfreplein
Larmagauche Venbraye
Furie Shelda
Garneg Grille-crâne
Gash'nak le Cannibale
Gash'nak le Cannibal (1)
Gash'nak le Cannibal (2)
Gash'nak le Cannibal (3)
Portier Hurlerage
Général Colbatann
Général Crocdangoiffe
Géomaîtresse Mouchette
Géomancien Dague-de-silex
Géoprêtresse Gukk'rok
Gesharahan
Ghok Bounnebaffe
Hurleur fantomatique
Margouilloche
Margouilleur
Glousse
Gilmorian
Gish l'Immobile
Glougloug
Noueux Frèrefeuilles
Ronge-les-os
Gondria
Goraluk Brisenclume
Croquetripe
Sangredent
Gorgon'och
Grash Tonnebière
Gravis Lecollet
Grand-père Arctikus
Braisaile
Gretheer
Griegen
Mornegueule
Grimungous
Kubb
Grison Neigepatte
Grocklar
Grubthor
Gruff
Gruff Mord-vite
Gruklash
Grunter
Haarka le Féroce
Hagg Plaie-des-taurens
Hahk'Zor
Martelléchine
Hannah Feuillelame
Harb Mont-Souillé
Hayoc
Chanteloge Forrestin
Tranchecœur
Hed'mush le Pourrissant
Heggin Moustache-de-pierre
Hemathion
Hématos
Lynnia Abbendis
Grande prêtresse Hai'watna
Grand thane Jorfus
Généralissime Mastrogonde
Hildana Voleuse-de-Mort
Hissperak
Humar le Fier
Ouraganien
Hyakiss la Rôdeuse
Corneglace
Immolatus
Dos-de-fer
Ferregard l'Invincible
Echine-de-fer
Jade
Jalinde Drake-d'été
Jed Guette-runes
Jimmy le Saignant
Jin'Zallah Porte-sable
Kashoch le saccageur
Kaskk
Kazon
Kelemis le Sans-Vie
Roi Krush
Roi Mosh
Roi Ping
Kovork
Kraator
Kregg Soulaquille
Krellack
Krethis Tisse-l'ombre
Kurmokk
Dame Hederine
Dame Mirelune
Dame Sesspira
Dame Szallah
Dame Vespia
Dame Vespira
Dame Zephris
Lapress
Gosh-Haldir
Veuve sanguine
Leprithus
Licillin
Barouf Fulgurouage
Lo'Grosh
Loque'nahak
Seigneur Baudroie
Capitaine Wyrmak
Seigneur Condar
Seigneur Sombrefaux
Seigneur Hel'nurath
Seigneur Malathrom
Seigneur Maldazzar
Seigneur Sakrasis
Seigneur Salvassio
Chef Perdu
Cuisinier perdu
Ame égarée
Horreur chancelante
Lupos
Ma'ruk Wyrmécaille
Magistère Falcoiffe
Magosh
Magronos l'Inflexible
Saccageur défectueux
Malgin Brasselorge
Marcus Bel
Marisa du'Paige
Marticar
Maître Terrassier
Maître Trouilleffroi
Mazzranache
Mekthorg le Sauvage
Meshlok le Moissonneur
Mezzir le hurleur
[INUTILISÉ 4.x] Mineur Johnson
Bas-boueux
Hurleur des brumes
Mith'rethis l'Enchanteur
Mojo le Tordu
Molok l'Anéantisseur
Rougeronce
Mongress
Monnos l'Ancien
Morcrase
Morgaine la rusée
Mère Croc
Muad
Moldaileron
Brûlepatte meurtrier
Mushgog
Nal'taszar
Naraxis
Narg le Sous-chef
Narillasanz
Nefaru
Surveillant nérubien
Chimère rare de Raz-de-Néant
Nimar le Pourfendeur
Nuramoc
Chênepatte
Okrek
Vieux Saute-falaise
Vieil Ecorce-de-Cristal
Vieux Grisebedaine
Vieux Vile mâchoire
Olm la Sage
Omgorn l'Egaré
Ver de limon
Panzor l'Invincible
Perobas le Carnassier
Patriarche aile-fière
Prêtresse d'Elune
Prince Kellen
Prince Nazjak
Prince Raze
Putridius
Putridus l'Antique
Pyromancien Blé-du-Savoir
QA Test Dummy 82 High Damage
QA Test Dummy 83 High Damage
Qirot
Quest - Northrend BG - Gate Kill
Quest - Wintergrasp - Bridge Kill
Quest - Wintergrasp - Gate Kill
Quest - Wintergrasp - PvP Kill - Alliance
Quest - Wintergrasp - PvP Kill - Fire
Quest - Wintergrasp - PvP Kill - Horde
Quest - Wintergrasp - PvP Kill - Life
Quest - Wintergrasp - PvP Kill - Shadow
Quest - Wintergrasp - PvP Kill - Vehicle
Quest - Wintergrasp - PvP Kill - Water
Quest - Wintergrasp - Southern Tower Kill
Quest - Wintergrasp - Structure Kill
Quest - Wintergrasp - Tower Kill
Quest - Wintergrasp - Vehicle Protected
Quest - Wintergrasp - Wall Kill
Quest - Wintergrasp - Workshop Kill
Ragepatte
Rak'shiri
Chasse-mort Eperlance
Rathorian
Ravage
Matriarche ravasaure
Régent Serres-de-Corbeau
Lanceur de Tranchebauge
Matriarche tranchegueule
Trancheserre
Rekk'tilac
Ressan le Harceleur
Retherokk le Berserker
Rex Ashil
Rezrelek
Rezrelek (1)
Rezrelek (2)
Rezrelek (3)
Chassecôtes
Rippa
Arrachécaille
Ro'Bark
Rochelance
Rohh le silencieux
Rodak le ravageur
Roloch
Joufflu le croquant
Cogneur poil-putride
Grondeur
Ruul Unepierre
Sandarr Ravadune
Ver des sables
Brûlar
Ventrécaille
Barbe-d'écailles
Scargil
Bourreau écarlate
Grand prêtre écarlate
Généralissime écarlate Daion
Interrogateur écarlate
Juge écarlate
Forgeron écarlate
Intendant du Bouclier balafré
Scillia Daguempenne
Scott Keenan
Aqualon le Chercheur
Haine vengeresse
Sentinelle Amarassan
Sergent Promptegriffe
Serra Âtremont
Setis
Bête des égouts
Shadikith le glisseur
Ombregriffe
Commandant ombreforge
Shanda la Tisseuse
Shleipnarr
Barricade
Moissonneur silithide
Krkk'kx
Singer
Sœur Cinglehaine
Sœur Rathtalon
Sœur Riven
Bâlhafr le Brisé
Grybou
Skoll
Krân
Slark
Maître des esclaves Cœur-Noir
Dragon dormant
Anomalie de vase
Bouillasseux
Fumar
Travépieu
Grogneur
Grondefuse
Grondecrin
Nifle la Moqueuse
Soriid le Dévoreur
Ailes du désespoir
Ame de Tanaris
Porte-parole Mar'grom
Seigneur de bataille pierre-du-pic
Boucher pierre-du-pic
Seigneur magus pierre-du-pic
Esprit de damné
Ecorchebile
Squiddic
Sri'skulk
Staggon
Maggarrak
Bras-de-pierre
Echine-de-pierre
Matriarche trotteuse
Vif-crins
Peau-piquante Pourcegart
Syreian la Sculpteuse d'os
Takk le Bondisseur
Tamra Foudrepique
Sous-chef Fouettecroc
Lambeaux
Tatre-peau (1)
Tatre-peau (2)
Tatre-peau (3)
Tepolar
Tisseuse de terreur
Lueur terrifiante
Chef de meute Frayeloup
Thauris Balgarr
Le Béhémoth
L'Evalcharr
La Bogue
L'Ongar
Le Griffu
La Razza
Le Jonc
La Pourriture
Thora Pennelune
Threggil
Grondeterre
Thurmonde le Dévot
Thuros Doigts-agiles
Grumeux
Proto-drake perdu dans le temps
Esprit tourmenté
Tregla
Trigore le Flagelleur
Tsu'zee
Tukemuth
Seigneur du Crépuscule Everun
Uhk'loc
Ursol'lok
Uruson
Ushalac le Hante-chagrin
Ushalac le Gloomdweller (1)
Ushalac le Gloomdweller (2)
Ushalac le Gloomdweller (3)
Fantôme de Varo'then
Ancien vengeur
Verek
Drolatix
Vern
Veyzhak le Cannibale
Vigdis la Vierge de guerre
Dardeur
Chasseur du Vide Yar
Volchan
Vorakem Parleruine
Vultros
Vyragosa
Golem de guerre
Gardien Stilgiss
Chef de guerre Krazzilak
Seigneur de guerre Kolkanis
Seigneur de guerre Thresh'jin
Sergent Curtis
Wep
Flétricœur le Traqueur
Yor <UNUSED>
Zalas fanécorce
Zaricotl
Zekkis
Zerillis
Zora
Zul'Brin Voilebranche
Zul'arek Volaillaîne
Sentinelle de Zul'Drak
Ombre de Shadumbra
[INUTILISÉ] Implorateur de mort Majestis
[INUTILISÉ] Kern le Massacreur
[INUTILISÉ] Observateur kolkar
Princesse des mers irequeue
]],
    koKR = [[
7:XT
저주받은 뱀갈퀴 나가
추방자 아킬리오스
이안 스위프트리버
아크릴루스
현자 아쿠바르
맹독숨결 알쉬르
사절 블러드레이지
사자 제리카르
아나테무스
안틸로스
창공의 안틸루스
아오토나
연금술사 팔디스
아라가
아라쉬에디스
아크튜리스
잠들지 않는 아즈쉬르
아주로우스
창공의 칼날 아제레
반노크 그림액스
바르나부스
남작 블러드베인
크르르
벤
베릴고스
큰곰 삼라스
비야른
악취나는 검은이끼괴물
눈먼사냥꾼
추적자 블러드로어
보안
늪지 잠복꾼
해골 마녀
우두머리 갈고쉬
바위심장
브랙
세뇌당한 귀족
썩은가지
피바다
외톨이 브로가즈
부러진 송곳니
부러진창
브론투스
수사 레이븐오크
브루갈 아이언너클
외눈박이
불타는 지옥수호병
악당 카포 [미사용]
대장 알미스티스
호위대장 납작엄니
경비대장 지로그 해머토
대장 그레쉬킬
파괴자 카니버스
우두머리 집게턱타란툴라
선임기술자 노산더
크리스마스 고랄루크 앤빌크랙
칼날집게발 딸깍이
여왕 자바스
갈퀴송곳니 사절
차원의 감시자 콜리더스
사령관 펠스트롬
Craig Steele
Craig Steele (1)
Craig Steele (2)
Craig Steele2
Craig Steele2 (1)
Craig Steele3
심술쟁이 벤지
광기 어린 인두르 생존자
땅거미
절름발이
딱딱이
수정 맹독거미
저주받은 켄타우로스
미치광이 사이클록
호박색 농장 역술사
다벨 몬트로즈
검은무쇠 사절
과부 암흑안개거미
바람뿔
맹독무당전갈
검은울음
죽음의 기사 소울베어러
죽음의 눈
송장아귀
죽음예언자 셀렌드레
죽음의 경비대장
디브
데시쿠스
돌연변이 요정용
다이아몬드 마크루라
채굴꾼 플레임포지
발굴단장 쇼벨플랜지
더키
디슈
파멸의 예언자 유림
박사 위더림
용아귀 지휘관
드레드스콘
드레드위스퍼
꿈감시자 갈래혓바닥
방랑자 드로고스
두간 와일드해머
공작 레이지리버
그늘표범
더스트레이스
대지의주술사 함가르
엑칼롬
포효의 에단
장로비술사 레이저스나웃
엘디나르쿠스
무쇠주먹 에모그
감독관 에밀군드
기술자 휠리기그
응징자 영원핵
타락한 용사
농부 솔리덴
불완전한 전쟁 골렘
페드페널
밀고자 펠렌도르
펠리센트의 유령
펠위버 스코른
암살자 페닛사
펜로스
핀개트
불꽃의 소환사 래디슨
거대한 프조듄
Fjordune the Greater (1)
Fjordune the Greater (2)
Fjordune the Greater (3)
무자비한 플래글머크
전투 절단기 4000
현장감독 그릴즈
현장감독 제리스
현장감독 마크리드
현장감독 리거
뒤뚱발이
파울메인
모래아귀
펌블럽 기어윈드
복수의 여신 쉘다
가르넥 찰스컬
식인귀 가쉬나크
Gash'nak the Cannibal (1)
Gash'nak the Cannibal (2)
Gash'nak the Cannibal (3)
문지기 레이지로어
장군 콜바탄
장군 팽페러
가시대장 점박이
흙점쟁이 플린트대거
가시사제 구크로크
게샤라한
고크 배시구드
유령울음늑대
기블스니크
기블윌트
히죽이
길모리안
부동의 기쉬
글루글
나알 리프브라더
뼈갈이
곤드리아
고랄루크 앤빌크랙
피송곳니
쐐기이빨
고르고노취
그래쉬 썬더브루
그라비스 슬립노트
대부 아크티쿠스
잿불날개
그리시르
그리겐
검은아귀
그림운거스
커브
눈발톱 그리즐
그록클라르
그룹토르
그러프
날쌘발톱 그러프
그루클라쉬
꿀꿀이
포악한 하르카
하그 타우렌베인
하크조르
가시망치
한나 블레이드리프
하브 파울마운틴
하요크
하스싱어 포레스턴
칼날심장
부패의 헤드무쉬
헤긴 스톤위스커
헤마시온
헤마토스
리니아 아벤디스
대여사제 하이와트나
고위 영주 조르푸스
대영주 마스트로곤드
힐다나 데스스틸러
히스페락
사자왕 후마르
허리케니안
잠복꾼 히아키스
얼음뿔
이몰라투스
무쇠껍질
무적의 무쇠눈바실리스크
무쇠해골
비취
잘린데 서머드레이크
제드 룬워처
날도둑 지미
모래술사 진잘라
약탈자 카쇼크
카스크
카존
죽음의 켈레미스
왕 크루쉬
폭군 모쉬
왕부리
코보르크
크라토르
크레그 킬홀
크렐락크
그림자거미 크레시스
쿠르모크
여군주 헤더린
여군주 문게이저
여군주 세스피라
여군주 스잘라
여군주 베스피아
여군주 베스피라
여군주 제프리스
라프리스
고쉬할디르
거머리과부거미
레프리투스
리킬린
리즐 스프리스프로켓
로그로쉬
로크나하크
마크루라왕 아귀
군주 웜막
독수리왕 콘다르
군주 다크사이드
군주 헬누라스
군주 말라스롬
말다자르 경
군주 사크라시스
군주 신슬레이어
잃어버린 드레나이 족장
잃어버린 드레나이 요리사
길 잃은 영혼
성큼걸이 누더기골렘
루포스
마룩 웜스케일
마법학자 호크헬름
마고쉬
고집불통 마그로노스
상태이상의 전투절단기
말긴 발리브루
마커스 벨
마리사 두페이지
마르티카
우두머리 채굴꾼
군주 피어드레드
마즈라나체
야수 메크토그
정원사 메슬로크
포효의 메찌르
[4.x 미사용]광부 존슨
골구렁
긴울음 안개늑대
마법부여사 미스레디스
험상궂은 모조
무쇠주먹 몰로크
허물가시
몽그레스
고대의 몬노스
모르크루쉬
교활한 도적 몰게니
여왕 굴거미
무아드
우렁비늘
피에 굶주린 문둥발하이에나
머쉬고그
날타스자르
나락시스
현장감독 나르그
나릴라산즈
네파루
네루비안 우두머리
희귀한 황천의 폭풍 키메라
학살자 니마르
누라모크
떡갈손
오크렉
늙은 절벽껑충늑대
노쇠한 수정껍질
늙은 그리즐거트
늙은곰 톱니이빨
지혜의 오름
실성한 옴고른
수액벌레
무적의 판저
피에 굶주린 페로바스
우두머리 사자날개 와이번
엘룬의 대여사제
왕자 켈렌
왕자 나자크
왕자 라제
퓨트리디우스
고대의 퓨트리두스
화염술사 로어그레인
죽어라때려보라지 82 공격력 높음
죽어라때려보라지 83 공격력 높음
퀴로트
퀘스트 노스렌드 전장 관문 처치
퀘스트 - 겨울손아귀 - 다리 처치
퀘스트 - 겨울손아귀 - 관문 처치
겨울손아귀 퀘스트
겨울손아귀 퀘스트
겨울손아귀 퀘스트
겨울손아귀 퀘스트
겨울손아귀 퀘스트
겨울손아귀 퀘스트
겨울손아귀 퀘스트
퀘스트 - 겨울손아귀 - 남쪽 탑 파괴
퀘스트 - 겨울손아귀 - 구조물 처치
퀘스트 - 겨울손아귀 - 탑 처치
퀘스트 - 겨울손아귀 - 탈것 보호
퀘스트 - 겨울손아귀 - 성벽 처치
퀘스트 - 겨울손아귀 - 작업장 처치
성난발톱
라크쉬리
죽음사냥꾼 호크스피어
라소리안
부라퀴
우두머리 라바사우루스
까마귀발톱 섭정
가시덩굴 가시근위병
무쇠턱 우두머리랩터
서슬갈퀴
레크틸락
칼날비명 레산
광전사 레세로크
렉스 아쉴
레즈렐렉
Rezrelek (1)
Rezrelek (2)
Rezrelek (3)
늑골잡이
리파
비늘톱
로바크
바위송곳
암살자 로
파괴자 로카드
로로취
난폭한 몽구리
썩은가죽 투사
우레정령
루울 원스톤
산다르 듄리버
미늘벌레
스칼드
무쇠비늘 바실리스크
비늘수염
칼지느러미
붉은십자군 사형집행인
붉은십자군 고위성직자
붉은십자군 대영주 다이온
붉은십자군 심문관
붉은십자군 재판관
붉은십자군 대장장이
방패부대 병참장교
스킬리아 대거퀼
Scott Keenan
수색자 아쿠알론
증오의 살덩이마귀
파수꾼 아마랏산
부대장 가시발톱
세라 마운틴홈
세티스
시궁창 악어
활강의 샤디키스
그림자발톱
어둠괴철로 사령관
검은올가미 샨다
셸리나르
철옹성
여왕 실리시드
크륵큭스
싱어
마녀 헤이트래쉬
마녀 라스탈론
마녀 리벤
패배의 스카르
스카울
스콜
스컬
슬라크
노예상인 블랙하트
잠들어 있는 용
녹괴물
곤죽이
스몰더
스나글스피어
스날러
불꽃용
썩은갈기
칼날발톱 킁킁이
파멸의 소리드
슬픈날개
타나리스의 정기
연설가 마르그롬
뾰족바위 전투대장
뾰족바위 학살자
뾰족바위 마법사장
저주받은 자의 영혼
재앙의 검은발톱
망둥이
스리술크
스타곤
마가라크
무쇠팔
뾰족바위
우두머리 타조
번개갈기
가시근위병 스와인가트
뼈분리자 사이레이안
껑충발 타크
탐라 스톰파이크
행동대장 채찍송곳니
너덜가죽
Tatterhide (1)
Tatterhide (2)
Tatterhide (3)
테폴러
공포의 그물거미
도깨비불꽃
테로울프 우두머리
타우리스 발가르
거수
에발차르
허스크
온가르
갈퀴
라자
리크
시궁괴물
토라 페더문
트레길
천둥발굽
경건한 신자 트루몬드
투로스 라이트핑거스
팀버
잃어버린 시간의 원시비룡
고통받는 영혼
트레글라
채찍꼬리 트리고어
츄지
투크무스
황혼의 군주 이브런
우크로크
우르솔로크
우루손
어둠의 우샬라크
Ushalac the Gloomdweller (1)
Ushalac the Gloomdweller (2)
Ushalac the Gloomdweller (3)
바로덴의 유령발늑대
복수심에 불타는 고대정령
베레크
베리포닉스
베른
식인트롤 베이쟉
여전사 비그디스
죽음의 맹독전갈
공허의 사냥꾼 야르
볼찬
보라켐 둠스피커
벌트로스
바이라고사
전쟁 골렘
문지기 스틸기스
부대장 크라질락
대장 콜카니스
장군 트레쉬진
하사관 커티스
웨프
추적자 메마른심장
Yor <UNUSED>
마른나무껍질 잘라스
자리코틀
젝키스
제릴리스
조라
줄브린 워프브랜치
줄라렉 헤이트파울러
줄드락 파수병
샤둠브라의 혼
[미사용] 죽음을부르는자 마제스티스
[미사용] 독재자 컨
[미사용] 콜카르 Observer
성난지느러미 바다공주
]],
    ptBR = [[
7:XT
Accursed Slitherblade
Achellios the Banished
Aean Swiftriver
Akkrilus
Akubar the Seer
Alshirr Banebreath
Ambassador Bloodrage
Ambassador Jerrikar
Anathemus
Antilos
Antilus the Soarer
Aotona
Apothecary Falthis
Araga
Arash-ethis
Arcturis
Azshir the Sleepless
Azurous
Azzere the Skyblade
Bannok Grimaxe
Barnabus
Baron Bloodbane
Bayne
Ben
Berylgos
Big Samras
Bjarn
Blackmoss the Fetid
Blind Hunter
Bloodroar the Stalker
Boahn
Bog Lurker
Bone Witch
Boss Galgosh
Boulderheart
Brack
Brainwashed Noble
Branch Snapper
Brimgore
Bro'Gaz the Clanless
Broken Tooth
Brokespear
Brontus
Brother Ravenoak
Bruegal Ironknuckle
Burgle Eye
Burning Felguard
Capo the Mean
Captain Armistice
Captain Flat Tusk
Captain Gerogg Hammertoe
Captain Greshkil
Carnivous the Breaker
Chatter
Chief Engineer Lorthander
Christmas Goraluk Anvilcrack
Clack the Reaver
Clutchmother Zavas
Coilfang Emissary
Collidus the Warp-Watcher
Commander Felstrom
Craig Steele
Craig Steele (1)
Craig Steele (2)
Craig Steele2
Craig Steele2 (1)
Craig Steele3
Cranky Benj
Crazed Indu'le Survivor
Creepthess
Crippler
Crusty
Crystal Fang
Cursed Centaur
Cyclok the Mad
Dalaran Spellscribe
Darbel Montrose
Dark Iron Ambassador
Darkmist Widow
Dart
Death Flayer
Death Howl
Death Knight Soulbearer
Deatheye
Deathmaw
Deathspeaker Selendre
Deathsworn Captain
Deeb
Dessecus
Deviate Faerie Dragon
Diamond Head
Digger Flameforge
Digmaster Shovelphlange
Dirkee
Dishu
Doomsayer Jurim
Dr. Whitherlimb
Dragonmaw Battlemaster
Dreadscorn
Dreadwhisper
Dreamwatcher Forktongue
Drogoth the Roamer
Duggan Wildhammer
Duke Ragereaver
Duskstalker
Dustwraith
Earthcaller Halmgar
Eck'alom
Edan the Howler
Elder Mystic Razorsnout
Eldinarcus
Emogg the Crusher
Enforcer Emilgund
Engineer Whirleygig
Ever-Core the Punisher
Fallen Champion
Farmer Solliden
Faulty War Golem
Fedfennel
Felendor the Accuser
Fellicent's Shade
Felweaver Scornn
Fenissa the Assassin
Fenros
Fingat
Firecaller Radison
Fjordune the Greater
Fjordune the Greater (1)
Fjordune the Greater (2)
Fjordune the Greater (3)
Flagglemurk the Cruel
Foe Reaper 4000
Foreman Grills
Foreman Jerris
Foreman Marcrid
Foreman Rigger
Foulbelly
Foulmane
Fulgorge
Fumblub Gearwind
Fury Shelda
Garneg Charskull
Gash'nak the Cannibal
Gash'nak the Cannibal (1)
Gash'nak the Cannibal (2)
Gash'nak the Cannibal (3)
Gatekeeper Rageroar
General Colbatann
General Fangferror
Geolord Mottle
Geomancer Flintdagger
Geopriest Gukk'rok
Gesharahan
Ghok Bashguud
Ghost Howl
Gibblesnik
Gibblewilt
Giggler
Gilmorian
Gish the Unmoving
Gluggle
Gnarl Leafbrother
Gnawbone
Gondria
Goraluk Anvilcrack
Gorefang
Goretooth
Gorgon'och
Grash Thunderbrew
Gravis Slipknot
Great Father Arctikus
Greater Firebird
Gretheer
Griegen
Grimmaw
Grimungous
Grizlak
Grizzle Snowpaw
Grocklar
Grubthor
Gruff
Gruff Swiftbite
Gruklash
Grunter
Haarka the Ravenous
Hagg Taurenbane
Hahk'Zor
Hammerspine
Hannah Bladeleaf
Harb Foulmountain
Hayoc
Hearthsinger Forresten
Heartrazor
Hed'mush the Rotting
Heggin Stonewhisker
Hemathion
Hematos
High General Abbendis
High Priestess Hai'watna
High Thane Jorfus
Highlord Mastrogonde
Hildana Deathstealer
Hissperak
Humar the Pridelord
Huricanian
Hyakiss the Lurker
Icehorn
Immolatus
Ironback
Ironeye the Invincible
Ironspine
Jade
Jalinde Summerdrake
Jed Runewatcher
Jimmy the Bleeder
Jin'Zallah the Sandbringer
Kashoch the Reaver
Kaskk
Kazon
Kelemis the Lifeless
King Krush
King Mosh
King Ping
Kovork
Kraator
Kregg Keelhaul
Krellack
Krethis Shadowspinner
Kurmokk
Lady Hederine
Lady Moongazer
Lady Sesspira
Lady Szallah
Lady Vespia
Lady Vespira
Lady Zephris
Lapress
Large Loch Crocolisk
Leech Widow
Leprithus
Licillin
Lizzle Sprysprocket
Lo'Grosh
Loque'nahak
Lord Angler
Lord Captain Wyrmak
Lord Condar
Lord Darkscythe
Lord Hel'nurath
Lord Malathrom
Lord Maldazzar
Lord Sakrasis
Lord Sinslayer
Lost One Chieftain
Lost One Cook
Lost Soul
Lumbering Horror
Lupos
Ma'ruk Wyrmscale
Magister Hawkhelm
Magosh
Magronos the Unyielding
Malfunctioning Reaver
Malgin Barleybrew
Marcus Bel
Marisa du'Paige
Marticar
Master Digger
Master Feardred
Mazzranache
Mekthorg the Wild
Meshlok the Harvester
Mezzir the Howler
Miner Johnson
Mirelow
Mist Howler
Mith'rethis the Enchanter
Mojo the Twisted
Molok the Crusher
Molt Thorn
Mongress
Monnos the Elder
Morcrush
Morgaine the Sly
Mother Fang
Muad
Mugglefin
Murderous Blisterpaw
Mushgog
Nal'taszar
Naraxis
Narg the Taskmaster
Narillasanz
Nefaru
Nerubian Overseer
Netherstorm Rare Chimaera UNUSED
Nimar the Slayer
Nuramoc
Oakpaw
Okrek
Old Cliff Jumper
Old Crystalbark
Old Grizzlegut
Old Vicejaw
Olm the Wise
Omgorn the Lost
Oozeworm
Panzor the Invincible
Perobas the Bloodthirster
Pridewing Patriarch
Priestess of Elune
Prince Kellen
Prince Nazjak
Prince Raze
Putridius
Putridus the Ancient
Pyromancer Loregrain
QA Test Dummy 82 High Damage
QA Test Dummy 83 High Damage
Qirot
Quest - Northrend BG - Gate Kill
Quest - Wintergrasp - Bridge Kill
Quest - Wintergrasp - Gate Kill
Quest - Wintergrasp - PvP Kill - Alliance
Quest - Wintergrasp - PvP Kill - Fire
Quest - Wintergrasp - PvP Kill - Horde
Quest - Wintergrasp - PvP Kill - Life
Quest - Wintergrasp - PvP Kill - Shadow
Quest - Wintergrasp - PvP Kill - Vehicle
Quest - Wintergrasp - PvP Kill - Water
Quest - Wintergrasp - Southern Tower Kill
Quest - Wintergrasp - Structure Kill
Quest - Wintergrasp - Tower Kill
Quest - Wintergrasp - Vehicle Protected
Quest - Wintergrasp - Wall Kill
Quest - Wintergrasp - Workshop Kill
Ragepaw
Rak'shiri
Ranger Lord Hawkspear
Rathorian
Ravage
Ravasaur Matriarch
Ravenclaw Regent
Razorfen Spearhide
Razormaw Matriarch
Razortalon
Rekk'tilac
Ressan the Needler
Retherokk the Berserker
Rex Ashil
Rezrelek
Rezrelek (1)
Rezrelek (2)
Rezrelek (3)
Ribchaser
Rippa
Ripscale
Ro'Bark
Rocklance
Rohh the Silent
Rokad the Ravager
Roloch
Rorgish Jowl
Rot Hide Bruiser
Rumbler
Ruul Onestone
Sandarr Dunereaver
Sandworm
Scald
Scale Belly
Scalebeard
Scargil
Scarlet Executioner
Scarlet High Clerist
Scarlet Highlord Daion
Scarlet Interrogator
Scarlet Judge
Scarlet Smith
Scarshield Quartermaster
Scillia Daggerquil
Scott Keenan
Seeker Aqualon
Seething Hate
Sentinel Amarassan
Sergeant Brashclaw
Serra Mountainhome
Setis
Sewer Beast
Shadikith the Glider
Shadowclaw
Shadowforge Commander
Shanda the Spinner
Shleipnarr
Siege Golem
Silithid Harvester
Silithid Ravager
Singer
Sister Hatelash
Sister Rathtalon
Sister Riven
Skarr the Unbreakable
Skhowl
Skoll
Skul
Slark
Slave Master Blackheart
Sleeping Dragon
Sludge Beast
Sludginn
Smoldar
Snagglespear
Snarler
Snarlflare
Snarlmane
Snort the Heckler
Soriid the Devourer
Sorrow Wing
Soul of Tanaris
Speaker Mar'grom
Spirestone Battle Lord
Spirestone Butcher
Spirestone Lord Magus
Spirit of the Damned
Spiteflayer
Squiddic
Sri'skulk
Staggon
Stone Fury
Stonearm
Stonespine
Strider Clutchmother
Swiftmane
Swinegart Spearhide
Syreian the Bonecarver
Takk the Leaper
Tamra Stormpike
Taskmaster Whipfang
Tatterhide
Tatterhide (1)
Tatterhide (2)
Tatterhide (3)
Tepolar
Terror Spinner
Terrorspark
Terrowulf Packlord
Thauris Balgarr
The Behemoth
The Evalcharr
The Husk
The Ongar
The Rake
The Razza
The Reak
The Rot
Thora Feathermoon
Threggil
Thunderstomp
Thurmonde the Devout
Thuros Lightfingers
Timber
Time-Lost Proto Drake
Tormented Spirit
Tregla
Trigore the Lasher
Tsu'zee
Tukemuth
Twilight Lord Everun
Uhk'loc
Ursol'lok
Uruson
Ushalac the Gloomdweller
Ushalac the Gloomdweller (1)
Ushalac the Gloomdweller (2)
Ushalac the Gloomdweller (3)
Varo'then's Ghost
Vengeful Ancient
Verek
Verifonix
Vern
Veyzhak the Cannibal
Vigdis the War Maiden
Vile Sting
Voidhunter Yar
Volchan
Vorakem Doomspeaker
Vultros
Vyragosa
War Golem
Warder Stilgiss
Warleader Krazzilak
Warlord Kolkanis
Warlord Thresh'jin
Watch Commander Zalaphil
Wep
Witherheart the Stalker
Yor <UNUSED>
Zalas Witherbark
Zaricotl
Zekkis
Zerillis
Zora
Zul'Brin Warpbranch
Zul'arek Hatefowler
Zul'drak Sentinel
[UNUSED] Ancient Guardian
[UNUSED] Deathcaller Majestis
[UNUSED] Kern the Enforcer
[UNUSED] Kolkar Observer
[UNUSED] Wrathtail Tide Princess
]],
    ruRU = [[
7:XT
Проклятый Скользящий Плавник
Акеллиос-Изгнанник
Эан Быстрая Река
Аккрилус
Провидец Акубар
Алшир Гиблодых
Посол Ярокров
Посол Жеррикар
Анатемус
Антилос
Антилус Парящий
Аотона
Аптекарь Фалтис
Арага
Араш-етис
Арктур
Азшир Неспящий
Лазурис
Аззира Клинок Небес
Баннок Люторез
Барнабус
Барон Кровопорч
Зверр
Бен
Бериллос
Большой Самрас
Бьярн
Черномшец злосмрадный
Слепой охотник
Рокотун Ловец
Боан
Болотный скрытень
Костяной ведьмак
Главарь Галгош
Камнесерд
Бракк
Зомбированный дворянин
Веткохват
Краегор
Бро'Газ Без Клана
Сломанный зуб
Копьелом
Бронтус
Брат Вороний Дуб
Бругал Железный Кулак
Воровской Глаз
Пылающий страж Скверны
Жадный Капо
Капитан Армстис
Капитан Тупой Клык
Капитан Герогг Тяжелоступ
Капитан Грешкил
Карнивус Разрушитель
Трещунья
Главный инженер Лортандер
Горалук Разбитая Наковальня, рождественский костюм
Щелкун Разоритель
Матка Завас
Эмиссар резервуара Кривого Клыка
Страж портала Коллидус
Командор Сквернстром
Крейг Стииле
Craig Steele (1)
Craig Steele (2)
Крейг Стииле2
Craig Steele2 (1)
Крейг Стииле3
Злобный Бенджи
Выживший сумасшедший из деревни Инду'ле
Ползух
Расчленитель
Хрустик
Хрустальный Клык
Проклятый кентавр
Циклок Безумный
Даларанский чарокнижник
Дарбелла Монтроуз
Посол из клана Черного Железа
Черная вдова Мглистой пещеры
Дарт
Смертоносный живодер
Смертный вой
Рыцарь Смерти Терзатель Душ
Смертеглаз
Гиблопасть
Вестница cмерти Селендра
Капитан служителей Смерти
Диб
Дессекус
Загадочный волшебный дракон
Ромбоголов
Землекоп Огнеплав
Мастер Лопаторук
Дирки
Дишу
Вестник рока Джурим
Доктор Белоручка
Военачальник из клана Драконьей Пасти
Бесстрашный
Шепот Ужаса
Двуязыкий Сновидец
Дрогот Бродяга
Дуган Громовой Молот
Герцог Беспощадный
Закатный ловец
Пыльный призрак
Заклинательница земли Халмгар
Эк'алом
Идан Ревун
Старый мистик Остроморд
Элдинаркус
Амогг Сокрушитель
Головорез Эмильгунд
Инженер Безобразец
Недремлющий Каратель
Павший воитель
Фермер Соллиден
Неисправный боевой голем
Федфенхель
Фелендор Обвинительница
Тень Феллисенты
Скорнн Ткач Скверны
Фенисса Убийца
Фенрос
Узкий Плавник
Радисон Призыватель Огня
Фьордан Старший
Фьордун Старший (1)
Fjordune the Greater (2)
Fjordune the Greater (3)
Грязнюк Жестокий
Врагорез-4000
Штейгер Грилз
Штейгер Джеррис
Штейгер Маркрид
Штейгер Риггер
Гнилобрюх
Скверногрив
Обжорень
Фумблуб Ветрозуб
Фурия Шельда
Гарнег Обугленный Череп
Гаш'нак Каннибал
Гаш'нак Каннибал (1)
Gash'nak the Cannibal (2)
Gash'nak the Cannibal (3)
Привратник Грознорев
Генерал Колбатанн
Генерал Фангферрор
Владычица земель Рябка
Геомант Кремненож
Жрица Земли Гукк'рок
Гешарахан
Гок Крепкобив
Призрачный Вой
Глупошмыг
Гибломор
Хохотунья
Гилмориан
Гиш Недвижимый
Барабуль
Брат листвы
Костоглод
Гондрия
Горалук Треснувшая Наковальня
Жуткоклык
Жуткозуб
Горгон'ох
Граш Громовар
Гравис Слипнот
Великий Отец Арктикус
Большой огнекрыл
Гретир
Григен
Зловещая Утроба
Мрачноус
Гризлак
Гриззл Снежная Лапа
Гроклар
Грубтор
Графф
Графф Быстрохват
Груклаш
Хрюггер
Хаарка Ненасытный
Хагг Тауребой
Хак'Зор
Твердоспин
Ханна Остролист
Харб Поганая Гора
Хайок
Певчий Форрестен
Сердцерез
Хед'маш Гниющий
Хеггин Камнеус
Гематион
Гематос
Верховный генерал Аббендис
Верховная жрица Хай'ватна
Верховный тан Йорфус
Верховный лорд Мастрогонд
Хильдана Похитительница Смерти
Шшшперак
Вожак стаи Хумар
Ураганий
Хиакисс Скрытень
Ледорог
Испепелитель
Сталеспин
Железноглаз Неуязвимый
Железноспин
Нефрит
Джалинда Дракон Лета
Джед Руновед
Джимми Вымогатель
Джин'Заллах Хозяин Барханов
Кашох Разоритель
Каскк
Казон
Келемис Безжизненный
Король Круш
Король Мош
Король Пинг
Коворк
Краатор
Крегг Кильватель
Креллак
Кретис Тенеткач
Курмокк
Леди Хедерина
Леди Луноокая
Леди Сесспира
Леди Сзалла
Леди Веспия
Леди Веспира
Леди Зефрис
Лапресс
Большой озерный кроколиск
Кровавая Вдова
Лепритус
Лисиллин
Лиззл Шустрец
Ло'Грош
Локе'нахак
Морской черт
Лорд-капитан Змеюк
Лорд Кондар
Лорд Темнокос
Лорд Хел'нурат
Лорд Малатром
Лорд Малдаззар
Лорд Сакрасис
Лорд Нечестивец
Вождь из племени Заблудших
Повар из племени Заблудших
Заблудшая душа
Неуклюжий ужас
Волкус
Ма'рук Змеиная Чешуя
Магистр Соколиный Шлем
Магош
Магронос Неуступчивый
Сломанный разоритель
Малгин Ячменовар
Маркус Бел
Мариса дю Пэж
Мартикар
Старший землекоп
Мастер Страхожуть
Маззранач
Мекторг Дикий
Мешлок Жнец
Меззир Ревун
Шахтер Джонсон
Подболотник
Ревун из тумана
Мит'ретис Чаротворец
Моджо Зловредный
Молок Сокрушитель
Облезлый Шип
Полукров
Моннос Древний
Моркруш
Моргана Лукавая
Мать Клык
Муад
Шоколадный Плавник
Безжалостный хромоног
Мушгог
Нал'тазар
Нараксис
Нарг Надсмотрщик
Нарилласанз
Нефару
Нерубский надзиратель
Редкая химера Пустоверти UNUSED
Нимар Душегуб
Нурамок
Дуболап
Окрек
Старый утесный прыгун
Старый кристальный древень
Старый Серобрюх
Старый Губач
Олм Мудрый
Омгорн Заблудший
Слизнечерв
Панцер Непобедимый
Перобас Кровожадный
Величавый патриарх
Жрица Элуны
Принц Келлен
Принц Назджак
Принц Рейз
Гнилиус
Гниллий Древний
Пироман Зерно Мудрости
QA Test Dummy 82 High Damage
QA Test Dummy 83 High Damage
Квирот
Quest - Northrend BG - Gate Kill
Quest - Wintergrasp - Bridge Kill
Quest - Wintergrasp - Gate Kill
Quest - Wintergrasp - PvP Kill - Alliance
Quest - Wintergrasp - PvP Kill - Fire
Quest - Wintergrasp - PvP Kill - Horde
Quest - Wintergrasp - PvP Kill - Life
Quest - Wintergrasp - PvP Kill - Shadow
Quest - Wintergrasp - PvP Kill - Vehicle
Quest - Wintergrasp - PvP Kill - Water
Quest - Wintergrasp - Southern Tower Kill
Quest - Wintergrasp - Structure Kill
Quest - Wintergrasp - Tower Kill
Quest - Wintergrasp - Vehicle Protected
Quest - Wintergrasp - Wall Kill
Quest - Wintergrasp - Workshop Kill
Яролап
Рак'шири
Предводитель следопытов Ястребиное Копье
Раториан
Разор
Равазавр-матриарх
Регент Когтя Ворона
Копьешкур из племени Иглошкурых
Острозуб-матриарх
Бритвокоготь
Рекк'тилак
Куссан Жалящий
Ретерокк Берсерк
Рекс Ашил
Резрелек
Резрелек (1)
Rezrelek (2)
Rezrelek (3)
Костелом
Потрошила
Чешуекус
Ро'Барк
Каменное Копье
Рохх Молчаливый
Рокад Опустошитель
Ролох
Роргиш Мощная Челюсть
Костолом из стаи Гнилошкуров
Грохотун
Руул Одинокий Камень
Сандарр Разоритель Барханов
Песчаный червь
Жар
Чешуйчатое брюхо
Чешуебород
Шрамник
Палач из Алого ордена
Верховный священник Алого ордена
Верховный лорд Алого Натиска Дайон
Дознаватель из Алого ордена
Судья из Алого ордена
Кузнец Алого ордена
Интендант из легиона Изрубленного Щита
Сцилла Стальное Перо
Скотт Кинан
Искатель Аквалон
Пылающая ненависть
Часовой Амарассан
Сержант Острый Коготь
Серра Горный Дом
Сетис
Тварь из Стоков
Шадикит Скользящий
Тенекоготь
Тенегорнский командир
Шанда Прядильщица
Шлейпнарр
Осадный голем
Силитид-жнец
Опустошитель-силитид
Певица
Сестра Плеть Ненависти
Сестра Коготь Кургана
Сестра Терзающая
Скарр Непреклонный
Сквой
Сколл
Череп
Сларк
Повелитель рабов Черносерд
Спящий дракон
Слякохлюп
Болотный слякоч
Смолдар
Кривое Копье
Рыкун
Огнемордик
Спутанная Грива
Фырк Дразнила
Сориид Пожиратель
Крыло скорби
Душа Танариса
Проповедник Маргром
Полководец из клана Черной Вершины
Мясник из клана Черной Вершины
Лорд-волхв из клана Черной Вершины
Дух проклятого
Злобоклюй
Кальмарник
Шри'скалк
Олеон
Каменная Ярость
Каменная рука
Каменный Гребень
Долгоног-несушка
Быстрогрив
Свинеар Копьешкур
Сирейна Костерез
Такк Прыгун
Тамран Грозовая Вершина
Надсмотрщик Хлестоклык
Грязношкур
Грязношкур (1)
Tatterhide (2)
Tatterhide (3)
Теполар
Ткач ужаса
Искра Ужаса
Вожак терроволков
Таурис Бальгарр
Чудище
Эвалчарр
Кикиморд
Онгар
Цап-царап
Разза
Рик
Гниль
Тора Оперенная Луна
Треггил
Громоступ
Турмонд Благочестивый
Турос Ловкорук
Серый
Затерянный во времени протодракон
Страдающая душа
Трегла
Тригор Хлестун
Цу'зи
Тюкмут
Владыка Эверан из культа Сумеречного Молота
Ак'лок
Урсол'лок
Урусон
Ушалак Обитатель Сумрака
Ушалак Обитатель Сумрака (1)
Ushalac the Gloomdweller (2)
Ushalac the Gloomdweller (3)
Привидение Варо'тена
Мстительное древо
Верек
Мигафоникс
Верн
Вейжак Каннибал
Вигдис Воительница
Коварное Жало
Охотник Бездны Яр
Волхан
Воракем Глашатай Судьбы
Сарыч
Вирагоса
Боевой голем
Тюремщик Стилгисс
Военный вождь Краззилак
Полководец Колканис
Полководец Молот'джин
Командир стражи Залафил
Уэп
Сухосерд Ловчий
Yor <UNUSED>
Залас Сухокожий
Зарикотль
Зеккис
Зериллис
Зора
Зул'Брин Криводрев
Зул'арек Злобный Охотник
Часовой Зул'драка
[UNUSED] Древо-Хранитель
[UNUSED] Призыватель смерти Маджестис
[UNUSED] Керн Мародер
[UNUSED] Наблюдатель клана Колкар
[UNUSED] Принцесса Приливов из клана Зловещего Хвоста
]],
    zhCN = [[
7:XT
可憎的滑刃纳迦
流放者阿切鲁斯
艾恩·流水
阿克瑞鲁斯
先知阿库巴尔
奥辛尔·灵息
布拉德雷大使
耶瑞卡尔大使
安纳塞姆斯
安提里奥斯
滑翔者安蒂鲁斯
奥图纳
药剂师法尔瑟斯
阿拉加
阿拉瑟希斯
阿克图瑞斯
永醒的艾希尔
埃苏罗斯
天空之刃艾泽里
班诺克·巨斧
巴纳布斯
布拉德贝恩男爵
贝恩
本恩
伯里苟斯
萨姆拉斯
游荡的冰爪熊
恶臭的黑苔兽
盲眼猎手
潜行者布拉多尔
博艾恩
泥沼潜伏者
骨巫
大头目加尔高什
波德哈特
布拉克
被洗脑的贵族
钳枝沼泽兽
布雷姆戈
独行者布罗加斯
断牙
断矛
布隆塔斯
拉文诺克修士
布鲁高·铁拳
贼眼
燃烧地狱卫士
守财奴卡波尔
阿米斯迪斯队长
獠牙队长
基洛戈·锤趾队长
格雷基尔上尉
卡尼沃斯
查特
主工程师洛杉德尔
圣诞版古拉鲁克
掠夺者科拉克
萨瓦丝女王
盘牙大使
扭曲观察者科里度斯
指挥官菲斯托姆
Craig Steele
Craig Steele (1)
Craig Steele (2)
Craig Steele2
Craig Steele2 (1)
Craig Steele3
暴躁的本希
疯狂的因度雷幸存者
克雷普塞斯
残骨骷髅
硬壳蟹
水晶之牙
被诅咒的半人马
疯狂的塞科洛克
安伯米尔书记员
达贝尔·蒙特罗斯
黑铁大使
暗雾寡妇蛛
达尔特
死亡毒蝎
死亡之嚎
死亡骑士索比莱尔
死眼
死亡之喉
亡语者塞伦德
死亡之誓
迪布
迪塞库斯
变异精灵龙
钻石头
矿工弗雷姆
挖掘专家舒尔弗拉格
迪尔奇
迪舒
灾难预言者尤瑞姆
维斯利姆博士
龙喉军官
德雷斯克恩
恐怖耳语者
睡梦守卫弗克托
咆哮者杜格斯
杜甘·蛮锤
瑞格雷沃公爵
暮色巡游者
灰尘怨灵
唤地者哈穆加
埃卡洛姆
饥饿的雪怪
秘法师拉佐斯诺特
埃迪纳库斯
摧毁者埃摩戈
执行者埃米尔冈德
技师维尔雷格
惩罚者埃沃考尔
死灵勇士
农夫索利丹
未完善的作战傀儡
费德菲尼尔
控诉者法雷多尔
菲林森特的阴影
斯考恩
刺客芬妮萨
芬罗斯
芬加特
召火者拉迪森
巨人弗瑟杜恩
Fjordune the Greater (1)
Fjordune the Greater (2)
Fjordune the Greater (3)
残忍的弗拉格莫克
死神4000型
工头葛瑞尔斯
工头杰瑞斯
工头玛希瑞德
工头里格尔
弗尔伯利
弗曼恩
弗尔古格
方卜拉布·飞轮
愤怒的谢尔达
加内格·焦颅
食尸者加什纳克
Gash'nak the Cannibal (1)
Gash'nak the Cannibal (2)
Gash'nak the Cannibal (3)
护门者拉格罗尔
科巴塔恩将军
方弗罗将军
吉欧洛德·杂斑
地占师弗林塔格
土地祭司古科罗克
格沙拉罕
霍克·巴什古德
鬼嚎
吉比斯尼克
吉波维特
基格勒尔
基摩里安
僵硬的吉斯
戈鲁格尔
纳尔利夫
纳博恩
古德利亚
古拉鲁克
血牙狼人
血齿鳄
高戈诺奇
格拉什·雷酒
格拉维斯·斯里诺特
霜鬃长老
余烬之翼
格雷瑟尔
戈雷根
格雷莫尔
格瑞姆格斯
卡布
雪爪灰熊怪
格罗卡拉
格鲁布索尔
格鲁夫
格拉夫·疾齿
格鲁克拉什
格朗特
贪婪的哈尔卡
哈格
哈克佐尔
锤脊
汉娜·刃叶
哈尔伯·邪泉
哈尤克
弗雷斯特恩
锐爪飞心
腐烂者海德姆什
赫金·石须
赫玛希恩
赫玛图斯
莉尼亚·阿比迪斯
高阶祭司海瓦纳
大领主约夫斯
玛斯托格
海达娜·窃魂者
西斯普拉克
狮王休玛
哈瑞坎尼安
潜伏者希亚其斯
冰角
伊姆拉图斯
铁背龟
不可战胜的铁眼
铁脊死灵
翡翠
加林德·夏龙
杰德
流血者吉米
唤沙者辛萨拉
劫掠者卡苏克
卡斯克
卡松
无命者克里米斯
暴龙王克鲁什
暴龙之王摩什
乒乒国王
考沃克
克兰托尔
克雷格·尼哈鲁
克里拉克
暗网编织者克雷希斯
库尔莫克
赫达琳
莫嘉泽尔
瑟丝彼拉
莎尔莱
薇丝比娅
薇丝普拉
塞菲莉斯
拉普雷斯
格什哈尔迪
吸血寡妇
莱布里萨斯
利斯林
里兹·滑链
洛格罗什
洛卡纳哈
安戈雷尔
维尔玛克中尉
康达尔
黑暗镰刀
赫尔努拉斯
玛拉索姆公爵
玛达萨尔
萨克拉希斯
辛斯雷尔
失落者酋长
失落者厨师
失落的灵魂
笨拙的憎恶
鲁伯斯
马鲁克·龙鳞
玛济斯·鹰盔
玛高什
顽强的玛古诺斯
失控的掠夺者
玛尔金·麦酒
马库斯·拜尔
魔理莎·杜派格
玛尔提卡
掘地工头目
菲达雷德
马兹拉纳其
野蛮的麦索格
收割者麦什洛克
嚎叫者米基尔
矿工约翰森
米尔洛
迷雾嚎叫者
附魔师米瑟雷希斯
扭曲者莫吉尔
碎骨者穆罗克
摩塔索恩
莫戈雷斯
长者莫诺斯
莫克拉什
狡猾的莫加尼
母蜘蛛
穆亚德
玛戈芬
残忍的疱爪土狼
姆斯高格
纳尔塔萨
纳拉克西斯
监工纳尔格
纳瑞尔拉萨斯
奈法鲁
蛛怪监工
Netherstorm Rare Chimaera UNUSED
屠戮者尼玛尔
努拉莫克
橡爪
奥卡雷
海崖奔跳者
水晶树皮
灰腹老熊
维斯迦尔
智者奥尔姆
失落者奥姆高尔
泥浆虫
无敌的潘佐尔
嗜血者比洛巴斯
巨翼雄兽
艾露恩的女祭司
凯雷恩王子
纳兹加克王子
拉兹王子
普特迪乌斯
古老的普迪图斯
控火师罗格雷恩
QA Test Dummy 82 High Damage
QA Test Dummy 83 High Damage
基洛特
Quest - Northrend BG - Gate Kill
Quest - Wintergrasp - Bridge Kill
Quest - Wintergrasp - Gate Kill
Quest - Wintergrasp - PvP Kill - Alliance
Quest - Wintergrasp - PvP Kill - Fire
Quest - Wintergrasp - PvP Kill - Horde
Quest - Wintergrasp - PvP Kill - Life
Quest - Wintergrasp - PvP Kill - Shadow
Quest - Wintergrasp - PvP Kill - Vehicle
Quest - Wintergrasp - PvP Kill - Water
Quest - Wintergrasp - Southern Tower Kill
Quest - Wintergrasp - Structure Kill
Quest - Wintergrasp - Tower Kill
Quest - Wintergrasp - Vehicle Protected
Quest - Wintergrasp - Wall Kill
Quest - Wintergrasp - Workshop Kill
拉吉波尔
拉克西里
死亡猎人霍克斯比尔
拉索利安
毁灭
暴掠龙女王
鸦爪摄政者
剃刀沼泽刺鬃守卫
刺喉雌龙
锋爪
雷克提拉克
毒针雷萨恩
狂暴者雷瑟罗克
雷克斯·亚希尔
勒兹雷克
Rezrelek (1)
Rezrelek (2)
Rezrelek (3)
雷布查斯
瑞帕
雷普斯凯尔
洛巴尔克
石枪
沉默的罗恩
蹂躏者洛卡德
罗洛克
洛吉什
腐皮惩戒者
拉姆布勒
鲁尔·巨石
杉达尔·沙掠者
沙虫
斯卡尔德
金鳞蜥蜴
鳞须海龟
斯卡基尔
血色刽子手
血色高阶牧师
血色领主达尔因
血色质问者
血色法官
血色铁匠
裂盾军需官
希利亚·匕羽
Scott Keenan
搜寻者埃库隆
沸腾之怨
哨兵阿玛拉珊
利爪队长
瑟拉·山岭
瑟提斯
下水道鳄鱼
滑翔者沙德基斯
影爪
暗炉指挥官
纺织者杉达
夏雷纳尔
路障
异种收割者
克尔克斯克
歌唱者
海特拉什
莱丝塔伦
瑞雯
沮丧的斯卡尔
斯格霍尔
逐日
斯库尔
斯拉克
奴隶主托恩·黑心
沉睡之龙
淤泥畸体
斯拉丁
斯莫达尔
断矛
咆哮者
斯纳弗莱尔
斯纳麦恩
土狼斯诺特
吞噬者索利德
悲哀之翼
塔纳利斯之魂
演讲者玛尔高姆
尖石统帅
尖石屠夫
尖石首席法师
诅咒者之魂
斯比弗雷尔
斯奎迪克
瑟斯库克
斯塔贡
玛格拉克
石臂
石脊
雌性森林陆行鸟
迅鬃斑马
斯文格加特·矛鬃
雕骨者希蕾娜
“跳跃者”塔克
塔尔玛·雷矛
工头维普弗恩
碎毛雪人
Tatterhide (1)
Tatterhide (2)
Tatterhide (3)
泰伯拉
恐惧织网者
特罗斯巴克
恐狼族长
萨里斯·巴加尔
贝哈默斯
伊夫卡尔
哈斯克
欧加尔
扫荡者
拉扎尔
雷克
腐烂者
索拉·羽月
瑟雷基尔
雷蹄蜥蜴
虔诚的瑟蒙德
索罗斯·莱特芬格
狂暴的冬狼
迷失始祖幼龙
痛苦的灵魂
特雷格拉
鞭笞者特里高雷
苏斯
图克姆斯
暮光之王艾沃兰
乌卡洛克
乌索洛克
乌鲁森
乌什拉克
Ushalac the Gloomdweller (1)
Ushalac the Gloomdweller (2)
Ushalac the Gloomdweller (3)
瓦罗森的幽灵
狂怒的树人
维雷克
维里弗尼克斯
瓦尔
食尸者维萨克
女战士维格蒂丝
邪刺恐蝎
空灵猎手亚尔
沃尔查
沃拉克姆
乌尔图斯
维拉苟萨
作战傀儡
典狱官斯迪尔基斯
克莱吉拉克
科卡尼斯
督军塔雷金
科提斯中士
维普
漫步者维瑟哈特
Yor <UNUSED>
扎拉斯·枯木
扎里科特
泽基斯
泽雷利斯
苏尔拉
祖布林·扭枝
祖拉雷克
祖达克斥候
猎影之影
[UNUSED] Deathcaller Majestis
[UNUSED] Kern the Enforcer
[UNUSED] Kolkar Observer
怒尾潮汐公主
]],
    zhTW = [[
7:XT
可憎的滑刃納迦
『放逐者』阿基里歐斯
艾恩·流水
阿克瑞魯斯
『先知』阿庫巴爾
奧辛爾·靈息
布拉德雷大使
傑瑞卡大使
安納塞姆斯
安提里奧斯
『翱翔者』安蒂魯斯
奧托納
藥劑師法爾瑟斯
阿拉加
阿拉瑟希斯
大角
不眠的艾希爾
埃蘇羅斯
『天刃』艾澤里
班諾克·巨斧
巴納布斯
布拉德貝恩男爵
貝恩
本恩
伯里苟斯
薩姆拉斯
遊蕩的冰爪熊
惡臭的黑苔獸
盲眼獵手
『潛獵者』血吼
博艾恩
泥沼潛伏者
骸骨女巫
大頭目加爾高西
波德哈特
布拉克
被洗腦的貴族
鉗枝沼澤獸
布雷姆戈
無氏族的伯卡茲
斷牙
斷矛
布隆塔斯
拉文諾克修士
布魯戈·艾爾克納寇
賊眼
燃燒惡魔守衛
守財奴卡波爾 [UNUSED]
阿米斯迪斯隊長
獠牙隊長
基洛戈·錘趾隊長
格雷基爾上尉
『擊破者』卡尼沃斯
查特
首席工程師羅桑德
聖誕版古拉魯克
『劫奪者』科拉克
薩瓦絲女王
盤牙特使
『扭曲監視者』克里達斯
指揮官菲斯托姆
Craig Steele
Craig Steele (1)
Craig Steele (2)
Craig Steele2
Craig Steele2 (1)
Craig Steele3
暴躁的本希
瘋狂的因度雷生還者
克雷普塞斯
殘廢者
硬殼
水晶之牙
被詛咒的半人馬
『瘋子』塞科洛克
安伯米爾法術抄寫員
達貝爾·蒙特羅斯
黑鐵大使
暗霧寡婦蛛
達爾特
死亡毒蠍
死亡之嚎
死亡騎士索比萊爾
死眼
死亡之喉
亡頌者塞倫德
死亡誓言者隊長
迪布
迪塞庫斯
變異精靈龍
鑽石頭
礦工弗雷姆
挖掘專家舒爾弗拉格
德碁
迪舒
末日預言者裘瑞姆
魏德林博士
龍喉軍官
德雷斯克恩
恐怖耳語者
睡夢守衛弗克托
『咆哮者』杜格斯
杜甘·蠻錘
瑞格雷沃公爵
暮色巡者
灰塵怨靈
喚地者哈穆加
埃卡洛姆
飢餓的雪怪
秘術使拉佐斯諾特
艾丁納克斯
『碾碎者』埃摩戈
執行者埃米爾岡德
工程師維爾雷格
恆核懲戒者
亡靈勇士
農夫索利丹
未完善的戰爭魔像
費德菲尼爾
『控訴者』法雷多爾
菲林森特的陰影
惡魔編織者斯考恩
『刺客』凡妮莎
芬羅斯
芬加特
召火者拉迪森
巨人弗瑟杜恩
Fjordune the Greater (1)
Fjordune the Greater (2)
Fjordune the Greater (3)
殘忍的弗拉格莫克
敵人收割者4000
工頭葛瑞爾斯
工頭傑瑞斯
工頭瑪希瑞德
工頭里格爾
弗爾伯利
弗曼恩
飽食者
方寶·機風
憤怒的謝爾達
加內格·焦顱
『食人者』加希納克
Gash'nak the Cannibal (1)
Gash'nak the Cannibal (2)
Gash'nak the Cannibal (3)
守門者暴吼
科巴塔恩將軍
方弗羅將軍
吉歐洛德·雜斑
地卜師弗林塔格
土地祭司古科羅克
格沙拉罕
霍克·巴什古德
鬼嚎
吉比斯尼克
吉波維特
基格勒爾
基摩里安
僵硬的吉斯
戈魯格爾
樹瘤·葉伴
納博恩
剛卓亞
古拉魯克
血牙狼人
鋒牙
高戈諾奇
格拉什·雷酒
格拉夫斯·斯里諾特
霜鬃長老阿克提卡斯
燼翼
格雷瑟爾
格里根
格雷莫爾
格瑞姆格斯
庫布
雪爪灰熊怪
葛洛克拉
格魯布索爾
格魯夫
格拉夫·疾齒
格魯克拉什
格朗特
貪婪的哈爾卡
哈格
哈克佐爾
錘脊者
漢娜·刃葉
哈爾伯·邪泉
哈尤克
爐邊歌手弗瑞斯坦
撕心者
『腐爛者』海德姆什
赫金·石鬚
赫瑪西恩
赫瑪多斯
琳恩妮雅·阿比迪斯
高階祭司海瓦納
大族長裘弗斯
大領主瑪斯托格
希爾達娜·亡據者
西斯普拉克
『獅王』修瑪
哈瑞坎尼安
潛伏者亞奇斯
冰角
伊姆拉圖斯
鐵背龜
無敵的鐵眼
鐵脊死靈
碧玉
加林德·夏龍
傑德
『流血者』吉米
喚沙者辛薩拉
『劫奪者』卡蘇克
卡斯克
卡松
無生命的克里米斯
克洛許王
暴龍之王莫什
乒乒王
考沃克
克拉特
克雷格·尼哈魯
克里拉克
『旋影者』克雷希斯
庫爾莫克
赫達琳女士
莫嘉澤爾女士
瑟絲彼拉女士
莎爾萊女士
薇絲比婭女士
薇絲普拉
塞菲莉斯女士
拉普雷斯
戈許哈爾迪爾
吸血寡婦
萊普利瑟斯
利斯林
里茲·滑鏈
洛格羅什
羅奎納哈克
安戈雷爾領主
維爾瑪克隊長
康達爾
暗鐮領主
赫爾努拉斯領主
瑪拉索姆領主
瑪達薩爾領主
薩克拉希斯領主
辛斯雷爾領主
失落者酋長
失落者廚師
失落的靈魂
笨拙的憎惡
魯伯斯
馬魯克·龍鱗
博學者鷹盔
瑪高什
不屈的瑪古諾斯
失控的劫奪者
瑪爾金·麥酒
馬庫斯·拜爾
瑪里莎·杜派格
瑪堤卡
掘地工頭目
菲達雷德
馬茲拉納奇
狂野的米克索格
『收割者』麥什洛克
『嚎叫者』米基爾
[UNUSED 4.x ]礦工強森
米爾洛
迷霧嚎叫者
『附魔師』米瑟雷希斯
『扭曲者』莫吉爾
碎骨者穆羅克
摩塔索恩
莫戈雷斯
長者莫諾斯
崩碎者
狡猾的莫加尼
母蜘蛛
穆亞德
瑪戈芬
殘忍的皰爪土狼
姆斯高格
納爾塔薩
納拉克西斯
監工納爾格
納瑞爾拉薩斯
奈法魯
奈幽監督者
Netherstorm Rare Chimaera UNUSED
『屠戮者』尼瑪爾
努拉莫克
橡爪
歐克瑞克
海崖奔跳者
老晶樹
灰腹老熊
維斯迦爾
『智者』奧爾姆
『失落者』歐姆高爾
軟泥蟲
無敵的潘佐爾
『嗜血者』佩洛巴斯
巨翼族王
伊露恩的女祭司
凱雷恩王子
納茲加克王子
拉茲王子
普特迪烏斯
古老的普崔達斯
火占師羅格雷恩
QA Test Dummy 82 High Damage
QA Test Dummy 83 High Damage
基洛特
任務 - 北裂境BG - 大門擊殺
任務 - 冬握湖 - 橋上擊殺
任務 - 冬握湖 - 大門擊殺
任務 - 冬握 - PvP擊殺 - 聯盟
任務 - 冬握 - PvP擊殺 - 火焰
任務 - 冬握湖 - PvP擊殺 - 部落
任務 - 冬握 - PvP擊殺 - 生命
任務 - 冬握 - PvP擊殺 - 暗影
任務 - 冬握 - PvP擊殺 - 飛行器
任務 - 冬握 - PvP擊殺 - 水
Quest - Wintergrasp - Southern Tower Kill
任務 - 冬握 - 結構擊殺
任務 - 冬握 - 高塔擊殺
任務 - 冬握 - 保護飛行器
任務 - 冬握湖 - 城牆擊殺
任務 - 冬握湖 - 工坊擊殺
怒掌
拉克西里
亡靈獵手霍克斯比爾
拉索利安
劫掠
暴掠龍族母
鴉爪攝政者
剃刀沼澤刺鬃守衛
刺喉龍族母
鋒爪
雷克提拉克
『激怒者』雷薩恩
『狂暴者』雷瑟羅克
雷克斯·亞希爾
勒茲雷克
Rezrelek (1)
Rezrelek (2)
Rezrelek (3)
雷布查斯
瑞帕
雷普斯凱爾
洛巴爾克
石槍
沉默的羅恩
劫毀者拉卡
羅洛克
洛吉什
腐皮懲戒者
拉姆布勒
盧爾·巨石
杉達爾·沙掠者
沙蟲
斯卡爾德
金鱗蜥蜴
鱗鬚海龜
斯卡基爾
血色劊子手
血色高階牧師
血色大領主黛昂
血色審問者
血色法官
血色鐵匠
裂盾軍需官
希利亞·匕羽
Scott Keenan
搜尋者埃庫隆
沸騰憎恨
哨兵阿瑪拉珊
利爪隊長
瑟拉·山嶺
瑟提斯
下水道猛獸
滑翔者薛迪依斯
影爪
影爐指揮官
『編織者』杉達
夏雷納爾
攻城魔像
異種收割者
克爾基斯
詠唱者
鷹女海特拉什
鷹女萊絲塔倫
鷹女瑞雯
傷殘的斯卡爾
斯格霍爾
史科爾
斯庫爾
斯拉克
奴隸主托恩·黑心
沉睡之龍
淤泥異常體
斯拉丁
斯莫達爾
暴矛
咆哮者
斯納弗賴爾
斯納麥恩
『土狼』斯諾特
『吞噬者』索利德
悲哀之翼
塔納利斯之魂
首長瑪庫隆
尖石戰鬥統帥
尖石屠夫
尖石首席魔導師
詛咒神教之靈
斯比弗雷爾
斯奎迪克
瑟斯庫克
斯塔貢
瑪加拉克
石臂
石脊
雌性森林陸行鳥
迅鬃斑馬
斯文格加特·矛鬃
『雕骨者』塞瑞安
『跳躍者』塔克
塔爾瑪·雷矛
監工維普弗恩
碎毛雪人
Tatterhide (1)
Tatterhide (2)
Tatterhide (3)
泰伯拉
恐懼紡織者
特羅斯巴克
恐狼族長
薩里斯·巴加爾
貝希摩斯
伊夫卡爾
哈斯克
歐加爾
掃蕩者
拉札
雷克
腐爛者
索拉·羽月
瑟雷基爾
雷蹄蜥蜴
虔誠的瑟蒙德
索羅斯·萊特芬格
狂暴的冬狼
時光流逝元龍
痛苦之靈
崔格拉
『鞭笞者』特里高雷
蘇斯
土克瑪斯
暮光領主艾沃蘭
烏卡洛克
厄索洛克
烏魯森
『鬱居者』烏夏拉克
Ushalac the Gloomdweller (1)
Ushalac the Gloomdweller (2)
Ushalac the Gloomdweller (3)
瓦羅森的鬼魂
狂怒的古樹
維雷克
維里弗尼克斯
維恩
『食人者』維薩克
『戰爭侍女』葳格迪斯
邪刺恐蠍
虛無獵人亞爾
沃爾查
弗拉肯·厄語者
烏爾圖斯
維拉苟莎
戰爭魔像
護衛斯迪爾基斯
克萊吉拉克
督軍科卡尼斯
督軍塔雷什森
指揮官柯堤斯
維普
『漫步者』維瑟哈特
Yor <UNUSED>
札拉斯·枯木
札里科特
澤基斯
澤雷利斯
蘇爾拉
祖布林·扭枝
祖拉雷克
祖爾德拉克哨兵
薩杜布拉之影
[UNUSED] Deathcaller Majestis
[UNUSED] Kern the Enforcer
[UNUSED] Kolkar Observer
怒尾海潮女祭司
]],
}

local function ParseCSVEntries(csv)
    local set = {}
    for entry in string.gmatch(csv, "%d+") do
        set[tonumber(entry)] = true
    end
    return set
end

-- Client strings where Blizzard's localizers reused the exact same display
-- name for two unrelated creature templates, one rare/rare-elite and one a
-- normal/elite/worldboss spawn (e.g. esES "Acechador nocturno" = both
-- Duskstalker (rare, entry 14430, level 9) and Nightstalker (normal trash,
-- entry 17203, level 9)). Verified against NotPlater's full (unfiltered)
-- creature/locale export, cross-referencing every rare-ranked name against
-- every other name in the same locale.
--
-- The nameplate's level text is readable before ever targeting the unit
-- (unlike its GUID/entry id, which 3.3.5a only exposes once you target it),
-- and in most of these pairs the rare and the impostor are different levels.
-- So instead of blacklisting the name outright, map it to the rare variant's
-- expected level: IsRareName only confirms "rare" if the plate's level
-- matches. A `false` value marks the rare handful of pairs that are also
-- level-identical (a true coin flip with no pre-target signal at all) -
-- those still can't be resolved by name and stay name-blocked until the
-- player targets the unit and the id-based check in native_style.lua takes
-- over. "Time-Lost Proto Drake"/"Time-Lost Proto-Drake" also collides in
-- most locales, but the elite-ranked entry (32153, level 1, 1 HP) is a
-- non-spawning placeholder, not a real encounterable mob, so it's left out
-- entirely to avoid blinding the (very real, very hunted) rare on sight.
local NameLevelHints = {
    ["Glutschwinge"] = 46, -- deDE: Greater Firebird (rare, 46) / Smolderwing (normal, 41)
    ["벤"] = 1, -- koKR: Ben (rare, 1) / Ven (normal, 30)
    ["검은아귀"] = 11, -- koKR: Grimmaw (rare, 11) / Blackmaw (normal, 79)
    ["해골 마녀"] = 61, -- koKR/zhTW: Bone Witch (rare, 61) / The Bone Witch (elite, 80)
    ["타락한 용사"] = 33, -- koKR: Fallen Champion (rare, 33) / Corrupted Champion (normal, 80)
    ["꿀꿀이"] = 50, -- koKR: Grunter (rare, 50) / Mr. Wiggles (normal, 1)
    ["리즐 스프리스프로켓"] = 1, -- koKR: Lizzle Sprysprocket (rare, 1) / Rizzle Sprysprocket (normal, 70)
    ["붉은십자군 심문관"] = false, -- koKR: Scarlet Interrogator (rare) / Scarlet Inquisitor (elite) - both level 61
    ["고통받는 영혼"] = 9, -- koKR: Tormented Spirit (rare, 9) / Tormented Soul (normal, 68)
    ["Болотный скрытень"] = 63, -- ruRU: Bog Lurker (rare, 63) / Marsh Lurker (normal, 62)
    ["Хрустик"] = 32, -- ruRU: Crusty (rare, 32) / Crunchy (normal, 5)
    ["Гилмориан"] = 43, -- ruRU: Gilmorian (rare, 43) / Gargoth (normal, 65)
    ["Полководец из клана Черной Вершины"] = false, -- ruRU: Spirestone Battle Lord (rare) / Spirestone Warlord (elite) - both level 58
    ["Волхан"] = 60, -- ruRU: Volchan (rare, 60) / Volkhan (elite, 82)
    ["Acechador nocturno"] = false, -- esES/esMX: Duskstalker (rare) / Nightstalker (normal) - both level 9
    ["Devastazione"] = 51, -- itIT/zhCN "毁灭": Ravage (rare, 51) / Devastation (elite, 70)
    ["卡斯克"] = 40, -- zhCN: Kaskk (rare, 40) / Cask (elite, 1)
    ["毁灭"] = 51, -- zhCN: Ravage (rare, 51) / Devastation (elite, 70)
    ["赫玛图斯"] = 60, -- zhCN: Hematos (rare, 60) / Hematus (normal, 50)
    ["库尔莫克"] = 42, -- zhCN: Kurmokk (rare, 42) / Kormok (elite, 60)
    ["笨拙的憎恶"] = 1, -- zhCN: Lumbering Horror (rare, 1) / Lumbering Abomination (elite, 80)
    ["腐烂者"] = 43, -- zhCN/zhTW "腐爛者": The Rot (rare, 43) / Rotted One (normal, 26)
    ["下水道鳄鱼"] = 50, -- zhCN: Sewer Beast (rare, 50) / Sewer Crocolisk (normal, 1)
    ["骸骨女巫"] = 61, -- zhTW: Bone Witch (rare, 61) / The Bone Witch (elite, 80)
    ["腐爛者"] = 43, -- zhTW: The Rot (rare, 43) / Rotted One (normal, 26)
}

local function IsShippableRareName(name)
    if not name or name == "" then
        return false
    end
    if name:find("UNUSED", 1, true) then
        return false
    end
    if name:find("QA Test", 1, true) then
        return false
    end
    if name:find("Craig Steele", 1, true) then
        return false
    end
    if name:find("Christmas Goraluk", 1, true) then
        return false
    end
    return true
end

local function ParseNamePack(pack)
    local set = {}
    if not pack or pack == "" then
        return set
    end
    for line in string.gmatch(pack, "[^\n]+") do
        if IsShippableRareName(line) then
            set[line] = true
        end
    end
    return set
end

function M:EnsureEntrySet()
    if not self._entrySet then
        self._entrySet = ParseCSVEntries(self.EntryCSV)
    end
    return self._entrySet
end

function M:EnsureNameSet(locale)
    locale = locale or (GetLocale and GetLocale()) or "enUS"
    if self._nameLocale == locale and self._nameSet then
        return self._nameSet
    end
    local pack = self.NamePacks[locale] or self.NamePacks.enUS
    self._nameSet = ParseNamePack(pack)
    self._nameLocale = locale
    return self._nameSet
end

function M:IsRareEntry(entry)
    return entry and self:EnsureEntrySet()[entry] == true
end

function M:IsRareName(name, level)
    if not name then
        return false
    end
    if not self:EnsureNameSet()[name] then
        return false
    end
    local hint = NameLevelHints[name]
    if hint == nil then
        return true
    end
    if hint == false then
        return false
    end
    return level ~= nil and level == hint
end

addon.NpcRareRanks = M
return M

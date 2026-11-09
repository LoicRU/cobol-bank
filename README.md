# cobol-bank

Mini core-banking en **GnuCOBOL** : fichiers indexés, menu console, authentification par PIN, comptes, dépôts / retraits / virements, historique, batch mensuel d'intérêts et de frais, détection de fraude basique et relevés de compte imprimables.

> Projet pédagogique. L'empreinte du PIN est calculée en COBOL pur (sel par client, 2000 tours de mélange arithmétique) : **ce n'est pas du SHA-256** et ne doit pas protéger de vrais secrets. Les fichiers de données ne sont pas chiffrés.

## Fonctions

- **Authentification** : identifiant + PIN (4 à 6 chiffres), blocage après 3 échecs, alertes de fraude (échecs rapprochés, blocage), déblocage par un administrateur.
- **Comptes** : comptes courants (avec découvert autorisé optionnel) et comptes épargne, statuts actif / gelé / clos, plafond journalier par compte, modification par l'administrateur.
- **Opérations** : dépôt, retrait, virement atomique ; chaque tentative (acceptée ou refusée, avec motif) est écrite dans l'historique.
- **Fraude** : plafond journalier de sorties (refus) et montant anormal par rapport à la moyenne du compte (alerte), journal d'alertes consultable par l'administrateur.
- **Batch mensuel** : intérêts (taux propre à l'épargne) et frais de tenue (comptes courants seulement), rejouable sans doublon (une période déjà traitée est refusée).
- **Inscription et ouverture de comptes en libre-service** : un visiteur crée son propre client (nom + PIN), puis chaque client s'ouvre jusqu'à 5 comptes (courant ou épargne), en console comme sur le web.
- **Interface web** (côté client) : inscription, ouverture de compte, consultation des comptes, dépôt, retrait, virement et historique dans le navigateur, via un petit serveur Python qui appelle le COBOL.
- **Relevés** : fichier texte formaté ou export CSV sur une période, avec contrôle de cohérence (solde initial + crédits − débits = solde final).

## Installation

```
sudo apt install gnucobol      # testé avec GnuCOBOL 3.1.2
make                           # compile bin/banque
make run                       # lance le programme
make test                      # compile et lance toutes les suites de tests
make web                       # lance l'interface web sur http://127.0.0.1:8080 (Python 3 requis)
make demo                      # cree un jeu de donnees de demonstration dans demo/
make run-demo                  # lance le programme sur ces donnees
make web-demo                  # lance l'interface web sur ces donnees
make clean                     # supprime exécutables et fichiers de test
```

## Premier lancement

Sans client, le programme crée l'administrateur : **identifiant 1**, avec le nom et le PIN que tu saisis. Pour se connecter, on saisit l'**identifiant** (numérique) ou le **nom** du client (sans tenir compte de la casse). Si deux clients portent le même nom, le programme demande l'identifiant. Un nom inconnu donne la même réponse qu'un mauvais PIN. Les fichiers sont créés dans `data/` et `reports/`.

Parcours d'essai :

1. Connexion `1` avec le PIN de l'administrateur.
2. Menu admin `1` : créer un client (Alice, rôle `C`, PIN 4321) → identifiant 2.
3. Menu admin `2` : ouvrir un compte pour le client 2 (type courant par défaut, plafond `0` = valeur par défaut, découvert `0` = aucun) → compte `1000000001`.
4. Déconnexion `0`, reconnexion avec `2` / 4321, dépôt `2`, retrait `3`, virement `4`.
5. Relevé `6` : dates de début et de fin au format `AAAAMMJJ`, fichier écrit dans `reports/`.

> **Mise à jour depuis la V1.0** : le format des comptes, des clients et de l'historique a changé (type de compte, découvert, soldes signés, date d'inscription). Supprimer les anciens fichiers (`rm -f data/*.dat`) puis `make clean && make`.

## Démo

`make demo` crée `demo/` (jamais `data/`) en rejouant un scénario sur le vrai programme : clients, comptes, dépôts, retraits, virements, un retrait refusé, un plafond dépassé, un client bloqué et le batch mensuel. `make run-demo` lance ensuite le programme sur ces données.

| Identifiant ou nom | PIN | Rôle |
|---|---|---|
| 1 Admin | 1234 | administrateur |
| 2 Alice | 4321 | client, comptes courants 1000000001 et 1000000002, épargne 1000000005 |
| 3 Bob | 5555 | client, compte 1000000003 (plafond 500.00, découvert autorisé 200.00, solde négatif après le batch) |
| 4 Clara | 2468 | client **bloqué** (compte 1000000004) : à débloquer par l'admin |

Le menu admin, option 4, montre les alertes `PLAFOND_JOUR`, `ECHECS_RAPIDES` et `PIN_BLOQUE`. Le relevé d'Alice est déjà dans `demo/reports/`.

### Export CSV

Au moment de demander un relevé, le menu propose le format : `1` texte (par défaut) ou `2` CSV. Le fichier `RELEVE_<compte>_<début>_<fin>.csv` utilise le séparateur `;` (s'ouvre directement dans Excel en français), des montants avec point décimal et du texte sans accents :

```
Titulaire;Alice
Compte;1000000001
Periode_debut;2026-11-09
Periode_fin;2026-11-09
Solde_initial;0.00
date;heure;operation;compte_lie;debit;credit;solde
2026-11-09;14:03;DEPOT;;;500.00;500.00
2026-11-09;14:03;RETRAIT;;120.50;;379.50
Solde_final;379.50
Total_debits;120.50
Total_credits;500.00
Operations;2
Verification;OK
```

Un nom de titulaire qui commencerait par `=`, `+`, `-` ou `@` est préfixé d'une apostrophe pour ne pas être interprété comme une formule par un tableur.

### Exemple de relevé

```
RELEVE DE COMPTE
Titulaire : Alice
Compte    : 1000000001
Periode   : 2026-11-09 au 2026-11-09
Edite le  : 2026-11-09

Solde initial :         0.00

Date        Heure  Operation         Compte lie  Debit         Credit        Solde
----------------------------------------------------------------------------------------------------
2026-11-09  14:03  DEPOT                                             500.00        500.00
2026-11-09  14:03  RETRAIT                             120.50                      379.50
----------------------------------------------------------------------------------------------------
Solde final :       379.50
Total debits  :       120.50
Total credits :       500.00
Operations    :       2
Verification : OK
```

## Exemple de session

Session réelle sur les données de `make demo` (Alice, identifiant 2, PIN 4321, saisi sans affichage). Les lignes après `Choix :`, `Montant :` et les autres invites sont les saisies. Le menu client n'est reproduit qu'une fois.

```
=== COBOL-BANK ===
1. Connexion
2. Creer mon compte client
0. Quitter
Choix : 1
Identifiant ou nom : 2
PIN : 
Bonjour Alice

--- Menu client ---
1. Mes comptes
2. Depot
3. Retrait
4. Virement
5. Historique d'un compte
6. Releve de compte
7. Changer mon PIN
8. Ouvrir un compte
0. Deconnexion
Choix : 1
Compte 1000000001  solde       1078.85  statut A  courant
Compte 1000000002  solde        348.44  statut A  courant
Compte 1000000005  solde       1002.50  statut A  epargne

[menu client]
Choix : 2
Numero de compte : 1000000001
Montant : 100
Nouveau solde :       1178.85
Operation effectuee.

[menu client]
Choix : 3
Numero de compte : 1000000001
Montant : 20000
Solde insuffisant.

[menu client]
Choix : 3
Numero de compte : 1000000001
Montant : 50
Nouveau solde :       1128.85
Operation effectuee.

[menu client]
Choix : 4
Numero de compte : 1000000002
Compte destinataire : 1000000001
Montant : 50
Nouveau solde :        298.44
Operation effectuee.

[menu client]
Choix : 5
Numero de compte : 1000000002
2026-11-09 15:23 D       300.00 A                              
2026-11-09 15:23 V        50.00 A                              
2026-11-09 15:23 I         0.44 A INTERETS 202611              
2026-11-09 15:23 F         2.00 A FRAIS DE TENUE 202611        
2026-11-09 15:23 V        50.00 A                              

[menu client]
Choix : 0
Deconnecte.

=== COBOL-BANK ===
1. Connexion
2. Creer mon compte client
0. Quitter
Choix : 0
Au revoir.
```

Le retrait de 20000 est refusé (solde insuffisant) et la dernière ligne de l'historique est le virement émis pendant la session. Les types sont D dépôt, R retrait, V virement, I intérêts, F frais ; `A` signale une opération acceptée, `R` une opération refusée.

## Interface web

```
make web                 # compile bin/api puis lance le serveur sur le port 8080
python3 web/server.py 9000   # autre port
```

Ouvrir `http://127.0.0.1:8080`, créer son compte client (« Créer mon compte client » : nom et PIN, l'identifiant attribué s'affiche) puis se connecter avec l'identifiant numérique et le PIN d'un **client** (les administrateurs restent en console, code 78). Pour essayer sur les données de démonstration :

```
make web-demo                 # recrée demo/ à chaque lancement, puis lance le site dessus
sh tests/demo.sh web 9000     # même chose sur un autre port
```

En mode démo, la page de connexion affiche un encart « Comptes de démonstration » (Alice, Bob, Clara, avec identifiants et PIN) : un clic sur « Utiliser » remplit le formulaire. L'encart n'apparaît jamais sans `--demo`.

Fonctionnement : `web/index.html` appelle `POST /api/<commande>` sur `web/server.py`, qui transmet une ligne (`commande id pin paramètres`) à `bin/api` (module `API.cob`) par l'entrée standard et renvoie son JSON. Le serveur ne garde aucun état : l'identifiant et le PIN accompagnent chaque requête et sont vérifiés par `AUTH` à chaque fois, donc le blocage après échecs de PIN, le plafond journalier, le découvert et les règles de l'épargne s'appliquent exactement comme en console. Le serveur n'écoute que sur `127.0.0.1`, valide strictement les champs (chiffres seulement) et ne met ni PIN ni corps de requête dans ses logs ; les appels au COBOL sont sérialisés.

> Usage **local uniquement** : pas de HTTPS ni de session, le PIN circule en clair entre le navigateur et le serveur. Ne pas exposer ce serveur sur un réseau.

Commandes de `bin/api` : `inscription`, `connexion`, `comptes`, `ouvrir`, `depot`, `retrait`, `virement`, `historique` (200 dernières opérations). Codes ajoutés : 74 (compte d'un autre client), 77 (commande inconnue), 78 (rôle non autorisé), 79 (paramètre invalide).

## Menus

| Menu client | Menu administrateur |
|---|---|
| 1 Mes comptes | 1 Créer un client |
| 2 Dépôt | 2 Ouvrir un compte |
| 3 Retrait | 3 Débloquer un client |
| 4 Virement | 4 Consulter les alertes |
| 5 Historique d'un compte | 5 Traitement mensuel |
| 6 Relevé de compte | 6 Relevé d'un compte |
| 7 Changer mon PIN | 7 Changer mon PIN |
| 8 Ouvrir un compte | 8 Modifier un compte |
| 0 Déconnexion | 0 Déconnexion |

Le menu de départ propose aussi `2 Créer mon compte client` (inscription libre).

### Inscription et ouverture en libre-service

- **Inscription** (`AUTH`, action `N`) : le nom contient des lettres (accents compris), chiffres, espaces, tirets ou apostrophes, 30 caractères au plus (sinon code 84) ; le PIN fait 4 à 6 chiffres (83). L'identifiant est attribué par le programme et le rôle est **toujours client**. Au-delà de `MAX_INSCRIPTIONS_HEURE` par heure : refus (85) et alerte `INSCRIPTIONS` visible dans le menu admin.
- **Ouverture de compte** (`COMPTE`, action `N`) : le client choisit courant ou épargne (87 si autre chose) ; le compte est créé à solde 0, sans découvert, avec le plafond par défaut ; au-delà de `MAX_COMPTES_CLIENT` comptes : refus (88). L'ouverture est écrite dans l'historique (type `O`, « OUVERTURE DE COMPTE »). L'administrateur ajuste ensuite plafond et découvert (menu admin 8).
- Il n'y a **aucune vérification d'identité** : n'importe qui peut s'inscrire. Acceptable pour un projet pédagogique local, pas pour un vrai service.

### Comptes courants et épargne

| | Courant | Épargne |
|---|---|---|
| Solde minimal | `−découvert autorisé` (0 par défaut) | 0 |
| Dépôt, virement reçu | oui | oui |
| Retrait | oui (jusqu'au découvert) | **non** (code 90) |
| Virement émis | oui (jusqu'au découvert) | seulement vers un **courant du même client** (sinon code 90) |
| Intérêts mensuels | `TAUX_ANNUEL_PCT`, sur solde positif | `TAUX_EPARGNE_PCT`, sur solde positif |
| Frais de tenue | oui, tant que `solde − frais ≥ −découvert` | aucun |

Le découvert est un plafond de solde négatif : aucun agio n'est calculé. Les soldes négatifs apparaissent avec un signe `-` dans les menus, l'historique et les relevés. Le menu admin `8` modifie le plafond journalier, le découvert (courant seulement) et le statut (actif, gelé, clos) d'un compte ; une saisie vide laisse la valeur actuelle.

Un client n'accède qu'à ses propres comptes (code 74 sinon). Le rôle administrateur est vérifié avant chaque action réservée.

## Architecture

```
src/          programme principal, modules et API.cob (interface web)
web/          serveur Python et page HTML
copybooks/    structures d'enregistrements (COMPTE, CLIENT, TRX, ALERTE, BATCH, RELEVE, PARAMS)
config/       parametres.cfg
data/         fichiers de données (ignorés par Git)
reports/      relevés et rapports générés (ignorés par Git)
tests/        suites de tests
```

| Module | Rôle | Codes de retour principaux |
|---|---|---|
| `BANQUE` | connexion, menus, saisies | — |
| `AUTH` | clients, inscription libre, PIN, blocage | 00, 22, 23, 81 (identifiant ou PIN faux), 82 (bloqué), 83 (PIN invalide), 84 (nom invalide), 85 (trop d'inscriptions) |
| `COMPTE` | comptes, dépôt, retrait, virement | 00, 22, 23, 87, 88, 90 (interdit sur épargne), 91 à 96, 98 |
| `TRX` | historique des transactions (ajout seul) | 00 |
| `FRAUDE` | plafond journalier, montant anormal, alertes d'échecs de PIN | 00, 96 (plafond), 97 (alerte seule) |
| `RELEVE` | relevé de compte (texte ou CSV) sur une période | 00, 23, 73, 74, 75 (incohérent), 76 (format inconnu) |
| `BATCH-INT` | intérêts et frais mensuels | 00, 71 (déjà traitée), 72 (interrompue), 73 |
| `API` | une commande client en JSON pour l'interface web (utilise AUTH, COMPTE) | 00 et codes d'AUTH / COMPTE, 74, 77, 78, 79 |
| `PARAM` | lecture et validation de la configuration | 00, 61, 62, 63 |

Données : `COMPTES.dat`, `CLIENTS.dat` et `BATCH.dat` sont des fichiers indexés ; `TRANSACTIONS.dat` et `ALERTES.dat` sont des journaux en ajout seul.

### Règles de conception

- Montants en virgule fixe (`PIC S9(9)V99`), jamais de flottants.
- Invariant : aucun solde en dessous de `−découvert autorisé` du compte (0 pour l'épargne).
- Toute opération est journalisée, acceptée ou refusée, avec son motif ; le contrôle de fraude passe en dernier.
- Le virement est atomique : les deux comptes sont validés avant d'écrire, et la source est restaurée si l'écriture de la destination échoue.
- L'historique garde le solde après chaque opération, ce qui permet de vérifier un relevé.
- Un identifiant inconnu et un mauvais PIN renvoient le même code (81).
- Une erreur d'entrée/sortie dans le menu affiche un message clair et arrête le programme (code retour 1).
- Une configuration invalide est refusée : le programme ne démarre pas, et les modules n'agissent pas.

## Configuration

`config/parametres.cfg` (format `CLE=valeur`, `#` pour les commentaires). Une clé absente garde sa valeur par défaut.

| Clé | Défaut | Rôle |
|---|---|---|
| `PLAFOND_DEFAUT` | 1000.00 | plafond journalier des comptes sans plafond propre |
| `FACTEUR_ANOMALIE` | 5 | alerte si montant > facteur × moyenne du compte |
| `MIN_HISTORIQUE` | 3 | opérations minimales avant d'appliquer cette règle |
| `TAUX_ANNUEL_PCT` | 1.50 | taux annuel des intérêts des comptes courants (%) |
| `TAUX_EPARGNE_PCT` | 3.00 | taux annuel des intérêts des comptes épargne (%) |
| `MAX_COMPTES_CLIENT` | 5 | comptes qu'un client peut ouvrir lui-même (l'administrateur n'est pas limité) |
| `MAX_INSCRIPTIONS_HEURE` | 20 | inscriptions libres par heure ; au-delà, refus (code 85) et alerte `INSCRIPTIONS` |
| `FRAIS_TENUE` | 2.00 | frais mensuels de tenue de compte |
| `MAX_ECHECS_PIN` | 3 | échecs de PIN avant blocage |
| `ALERTE_ECHECS` | 2 | échecs de PIN consécutifs déclenchant l'alerte `ECHECS_RAPIDES` (sans blocage) |
| `FENETRE_ECHECS_SEC` | 300 | durée (secondes) dans laquelle ces échecs doivent survenir |

Variables d'environnement (utiles surtout pour les tests) : `PARAMS_FILE`, `CLIENTS_FILE`, `COMPTES_FILE`, `TRX_FILE`, `ALERTES_FILE`, `BATCH_FILE`, `BATCH_REPORT_DIR`, `RELEVE_DIR`.

## Tests

`make test` lance dix suites, chacune sur des fichiers temporaires dans `tests/` (jamais `data/` ni `reports/`) :

| Suite | Couvre |
|---|---|
| `test_param` | lecture, fichiers invalides, effet d'une valeur modifiée sur AUTH, FRAUDE et BATCH-INT |
| `test_compte` | création, dépôt, retrait, virement, cas de refus, plafond et anomalie, découvert et règles de l'épargne, ouverture de compte et limite par client |
| `test_auth` | création, PIN, blocage, déblocage, changement de PIN, inscription libre (validations, limite horaire, alerte) |
| `test_batch` | intérêts, frais, arrondis, dépassement, rejeu, période interrompue |
| `test_releve` | périodes, soldes (y compris négatifs), cohérence, droits, export CSV, bout en bout |
| `test_epargne` | batch : intérêts d'épargne, pas de frais sur l'épargne, frais limités par le découvert |
| `test_trx` | numérotation de l'historique |
| `test_menu.sh` | scénario complet par saisies redirigées (client, admin, blocage, batch, connexion par nom) |
| `test_web.sh` | `bin/api` et serveur HTTP : inscription, ouverture de compte, connexion, comptes, opérations, refus, injections de paramètres, PIN absent des logs |
| `test_demo.sh` | le jeu de démonstration produit les soldes, alertes et relevés annoncés |

## Limites connues

- Un seul utilisateur à la fois : pas de gestion de concurrence entre plusieurs processus.
- PIN pédagogique (voir l'avertissement en tête), fichiers non chiffrés.
- Pas de devise ni de fuseau : une seule monnaie, date et heure du système.
- Inscription libre sans vérification d'identité (limitée seulement par `MAX_INSCRIPTIONS_HEURE`) ; un nouveau client peut porter le même nom qu'un autre.
- Pas d'agios : un solde négatif ne produit pas d'intérêts débiteurs.
- Le relevé est un fichier texte ; il n'y a pas d'export PDF.

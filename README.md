# cobol-bank

Mini core-banking en **GnuCOBOL** : fichiers indexés, menu console, authentification par PIN, comptes, dépôts / retraits / virements, historique, batch mensuel d'intérêts et de frais, détection de fraude basique et relevés de compte imprimables.

> Projet pédagogique. L'empreinte du PIN est calculée en COBOL pur (sel par client, 2000 tours de mélange arithmétique) : **ce n'est pas du SHA-256** et ne doit pas protéger de vrais secrets. Les fichiers de données ne sont pas chiffrés.

## Fonctions

- **Authentification** : identifiant + PIN (4 à 6 chiffres), blocage après 3 échecs, alertes de fraude (échecs rapprochés, blocage), déblocage par un administrateur.
- **Comptes** : création, statuts actif / gelé / clos, plafond journalier par compte.
- **Opérations** : dépôt, retrait, virement atomique ; chaque tentative (acceptée ou refusée, avec motif) est écrite dans l'historique.
- **Fraude** : plafond journalier de sorties (refus) et montant anormal par rapport à la moyenne du compte (alerte), journal d'alertes consultable par l'administrateur.
- **Batch mensuel** : intérêts et frais de tenue, rejouable sans doublon (une période déjà traitée est refusée).
- **Relevés** : fichier texte formaté sur une période, avec contrôle de cohérence (solde initial + crédits − débits = solde final).

## Installation

```
sudo apt install gnucobol      # testé avec GnuCOBOL 3.1.2
make                           # compile bin/banque
make run                       # lance le programme
make test                      # compile et lance toutes les suites de tests
make clean                     # supprime exécutables et fichiers de test
```

## Premier lancement

Sans client, le programme crée l'administrateur : **identifiant 1**, avec le nom et le PIN que tu saisis. Pour se connecter, on saisit l'identifiant **numérique** (pas le nom). Les fichiers sont créés dans `data/` et `reports/`.

Parcours d'essai :

1. Connexion `1` avec le PIN de l'administrateur.
2. Menu admin `1` : créer un client (Alice, rôle `C`, PIN 4321) → identifiant 2.
3. Menu admin `2` : ouvrir un compte pour le client 2 (plafond `0` = valeur par défaut) → compte `1000000001`.
4. Déconnexion `0`, reconnexion avec `2` / 4321, dépôt `2`, retrait `3`, virement `4`.
5. Relevé `6` : dates de début et de fin au format `AAAAMMJJ`, fichier écrit dans `reports/`.

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
| 0 Déconnexion | 0 Déconnexion |

Un client n'accède qu'à ses propres comptes (code 74 sinon). Le rôle administrateur est vérifié avant chaque action réservée.

## Architecture

```
src/          programme principal et modules
copybooks/    structures d'enregistrements (COMPTE, CLIENT, TRX, ALERTE, BATCH, RELEVE, PARAMS)
config/       parametres.cfg
data/         fichiers de données (ignorés par Git)
reports/      relevés et rapports générés (ignorés par Git)
tests/        suites de tests
```

| Module | Rôle | Codes de retour principaux |
|---|---|---|
| `BANQUE` | connexion, menus, saisies | — |
| `AUTH` | clients, PIN, blocage | 00, 22, 23, 81 (identifiant ou PIN faux), 82 (bloqué), 83 (PIN invalide) |
| `COMPTE` | comptes, dépôt, retrait, virement | 00, 22, 23, 91 à 96, 98 |
| `TRX` | historique des transactions (ajout seul) | 00 |
| `FRAUDE` | plafond journalier, montant anormal, alertes d'échecs de PIN | 00, 96 (plafond), 97 (alerte seule) |
| `RELEVE` | relevé de compte sur une période | 00, 23, 73, 74, 75 (incohérent) |
| `BATCH-INT` | intérêts et frais mensuels | 00, 71 (déjà traitée), 72 (interrompue), 73 |
| `PARAM` | lecture et validation de la configuration | 00, 61, 62, 63 |

Données : `COMPTES.dat`, `CLIENTS.dat` et `BATCH.dat` sont des fichiers indexés ; `TRANSACTIONS.dat` et `ALERTES.dat` sont des journaux en ajout seul.

### Règles de conception

- Montants en virgule fixe (`PIC S9(9)V99`), jamais de flottants.
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
| `TAUX_ANNUEL_PCT` | 1.50 | taux annuel des intérêts (%) |
| `FRAIS_TENUE` | 2.00 | frais mensuels de tenue de compte |
| `MAX_ECHECS_PIN` | 3 | échecs de PIN avant blocage |
| `ALERTE_ECHECS` | 2 | échecs de PIN consécutifs déclenchant l'alerte `ECHECS_RAPIDES` (sans blocage) |
| `FENETRE_ECHECS_SEC` | 300 | durée (secondes) dans laquelle ces échecs doivent survenir |

Variables d'environnement (utiles surtout pour les tests) : `PARAMS_FILE`, `CLIENTS_FILE`, `COMPTES_FILE`, `TRX_FILE`, `ALERTES_FILE`, `BATCH_FILE`, `BATCH_REPORT_DIR`, `RELEVE_DIR`.

## Tests

`make test` lance six suites, chacune sur des fichiers temporaires dans `tests/` (jamais `data/` ni `reports/`) :

| Suite | Couvre |
|---|---|
| `test_param` | lecture, fichiers invalides, effet d'une valeur modifiée sur AUTH, FRAUDE et BATCH-INT |
| `test_compte` | création, dépôt, retrait, virement, cas de refus, plafond et anomalie |
| `test_auth` | création, PIN, blocage, déblocage, changement de PIN |
| `test_batch` | intérêts, frais, arrondis, dépassement, rejeu, période interrompue |
| `test_releve` | périodes, soldes, cohérence, droits, bout en bout |
| `test_menu.sh` | scénario complet par saisies redirigées (client, admin, blocage, batch) |

## Limites connues

- Un seul utilisateur à la fois : pas de gestion de concurrence entre plusieurs processus.
- PIN pédagogique (voir l'avertissement en tête), fichiers non chiffrés.
- Pas de devise ni de fuseau : une seule monnaie, date et heure du système.
- Le relevé est un fichier texte ; il n'y a pas d'export PDF.

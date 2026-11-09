# Cahier des charges : cobol-bank

Mini système de core banking écrit en COBOL (GnuCOBOL), avec fichiers indexés et interface console.

- **Auteur** : Loïc Ruyssen
- **Date** : 2026-11-09
- **Version du document** : 1.1 (V1 du projet, complétée : export CSV, connexion par nom, jeu de démonstration, découvert autorisé, comptes épargne et interface web locale)

---

## 1. Contexte et objectifs

COBOL fait tourner une grande partie des systèmes bancaires réels. Ce projet recrée une banque simplifiée dans ce langage pour :

- apprendre COBOL en profondeur (structure DIVISION, fichiers indexés, arithmétique décimale, sous-programmes) ;
- reproduire la logique métier d'un cœur bancaire (comptes, transactions, intérêts, contrôle de fraude) ;
- produire un projet de portfolio original, avec une dimension sécurité.

**Objectifs mesurables de la V1**

1. Un client peut se connecter par PIN et effectuer dépôts, retraits et virements.
2. Aucune opération ne peut produire de solde incohérent (pas de perte ni de création d'argent).
3. Chaque opération est tracée dans un historique consultable.
4. Un traitement batch mensuel applique intérêts et frais.
5. Les opérations suspectes sont détectées et journalisées.
6. Un relevé de compte formaté peut être généré.

---

## 2. Périmètre

### Inclus en V1

- Authentification client par identifiant et PIN, avec blocage après échecs répétés.
- Gestion des clients et des comptes (création, consultation).
- Dépôt, retrait, virement interne.
- Historique des transactions.
- Calcul mensuel des intérêts et des frais (programme batch séparé).
- Détection de fraude basique (plafonds, montant anormal, journal d'alertes).
- Relevé de compte imprimable (fichier texte formaté).
- Jeu de données de test et tests de bout en bout.
- *(V1.1)* Export CSV des relevés, connexion par identifiant ou par nom, jeu de démonstration (`make demo`).
- *(V1.1)* Interface web locale côté client (consultation, dépôt, retrait, virement, historique) appelant les programmes COBOL.
- *(V1.1)* Découvert autorisé par compte courant et comptes épargne (taux propre, retrait en espèces interdit).

### Exclu de la V1

- API REST publique, interface web exposée sur un réseau (la V1.1 fournit une interface web locale, sans HTTPS).
- Virements vers des banques externes (SEPA, SWIFT).
- Multi-devises.
- Accès concurrent de plusieurs utilisateurs simultanés.
- Cartes bancaires, prêts, comptes épargne réglementés (plafonds légaux, livrets défiscalisés), agios sur découvert.

---

## 3. Acteurs

| Acteur | Rôle |
|---|---|
| **Client** | Se connecte, consulte son solde, effectue des opérations, demande un relevé. |
| **Administrateur** | Crée clients et comptes, débloque un PIN, lance le batch mensuel, consulte les alertes de fraude. |

---

## 4. Exigences fonctionnelles

### 4.1 Authentification

- **F-AUTH-1** : le client saisit son identifiant et son PIN (4 à 6 chiffres).
- **F-AUTH-2** : le PIN est stocké sous forme hachée, jamais en clair.
- **F-AUTH-3** : après 3 échecs consécutifs, le client est bloqué ; seul un administrateur peut le débloquer.
- **F-AUTH-4** : un succès remet le compteur d'échecs à zéro.

### 4.2 Clients et comptes

- **F-CPT-1** : l'administrateur crée un client (identifiant, nom, PIN initial).
- **F-CPT-2** : un client possède un ou plusieurs comptes, chacun identifié par un numéro unique.
- **F-CPT-3** : un compte porte un type, un solde, un plafond journalier et un statut (actif, gelé, clos).
- **F-CPT-4** : le client consulte le solde de ses comptes.
- **F-CPT-5** *(V1.1)* : un compte est **courant** ou **épargne**. Un compte courant porte un découvert autorisé (0 par défaut) ; un compte épargne n'a jamais de découvert.
- **F-CPT-6** *(V1.1)* : l'administrateur modifie le plafond journalier, le découvert (courant seulement) et le statut d'un compte.

### 4.3 Opérations

- **F-OP-1 Dépôt** : crédite un compte d'un montant strictement positif.
- **F-OP-2 Retrait** : débite un compte si le solde après opération reste supérieur ou égal à `−découvert autorisé` (0 par défaut, donc solde suffisant). Un retrait sur un compte épargne est refusé (code 90).
- **F-OP-3 Virement** : débite un compte source et crédite un compte destination dans la même opération ; si l'une des deux écritures échoue, l'autre est annulée.
- **F-OP-4** : chaque opération réussie ou refusée génère une ligne d'historique (date, heure, type, comptes, montant, statut, motif de refus éventuel).
- **F-OP-5** : un compte gelé ou clos refuse toute opération.
- **F-OP-6** *(V1.1)* : un compte épargne accepte les dépôts et les virements reçus ; ses virements émis ne sont possibles que vers un compte courant du même client (sinon refus, code 90).

### 4.4 Intérêts et frais (batch mensuel)

- **F-BAT-1** : un programme batch parcourt tous les comptes actifs.
- **F-BAT-2** : il crédite les intérêts mensuels selon le taux paramétré (un taux pour les comptes courants, un taux pour les comptes épargne), sur les soldes positifs uniquement.
- **F-BAT-3** : il débite les frais de tenue de compte paramétrés sur les comptes courants, tant que le solde reste supérieur ou égal à `−découvert autorisé` ; les comptes épargne n'en paient pas.
- **F-BAT-4** : chaque écriture est enregistrée dans l'historique avec un type dédié (intérêt, frais).
- **F-BAT-5** : il produit un rapport de fin de traitement (nombre de comptes traités, total des intérêts, total des frais, anomalies).
- **F-BAT-6** : le batch est rejouable sans doublon : un second lancement sur la même période est refusé.

### 4.5 Détection de fraude basique

- **F-FRD-1** : un plafond journalier cumulé par compte est appliqué aux retraits et virements sortants ; l'opération qui le dépasse est refusée.
- **F-FRD-2** : une opération dont le montant dépasse un multiple paramétré de la moyenne des opérations du compte déclenche une alerte.
- **F-FRD-3** : plusieurs échecs d'authentification rapprochés sur un même identifiant déclenchent une alerte.
- **F-FRD-4** : toute alerte est inscrite dans un journal dédié (date, heure, compte ou client, règle déclenchée, montant).
- **F-FRD-5** : l'administrateur peut consulter le journal d'alertes.

### 4.6 Relevés

- **F-REL-1** : le client choisit un compte et une période.
- **F-REL-2** : le programme génère un fichier texte formaté : en-tête (titulaire, numéro de compte, période), solde initial, liste des opérations, solde final, totaux débit et crédit.
- **F-REL-3** : le solde initial plus les crédits moins les débits égale le solde final ; sinon le relevé signale une incohérence.
- **F-REL-4** *(V1.1)* : le relevé peut aussi être exporté en CSV (séparateur `;`, point décimal). Les soldes négatifs sont affichés avec un signe `-`.

---

## 5. Exigences non fonctionnelles

| Réf. | Exigence |
|---|---|
| **NF-1 Précision** | Tous les montants utilisent des champs numériques décimaux (`PIC S9(9)V99`, idéalement `COMP-3`). Aucun calcul en virgule flottante. |
| **NF-2 Intégrité** | Une opération multi-écritures (virement) est atomique du point de vue applicatif : en cas d'échec intermédiaire, l'état est restauré. |
| **NF-3 Sécurité** | PIN hachés, aucun secret en clair dans les fichiers ni les journaux, messages d'erreur d'authentification génériques. |
| **NF-4 Traçabilité** | L'historique des transactions est en ajout seul ; aucune ligne n'est modifiée ni supprimée. |
| **NF-5 Robustesse** | Tous les `FILE STATUS` sont vérifiés ; une erreur d'E/S produit un message clair et un arrêt propre. |
| **NF-6 Portabilité** | Compilation avec GnuCOBOL 3.x sur Linux, sans dépendance externe. |
| **NF-7 Lisibilité** | Code en format libre, paragraphes nommés, commentaires sur les règles de gestion, une copybook par structure d'enregistrement. |
| **NF-8 Performance** | Temps de réponse interactif inférieur à une seconde pour 10 000 comptes ; batch mensuel en moins de 10 secondes pour 10 000 comptes. |

---

## 6. Architecture technique

### 6.1 Environnement

- Langage : COBOL, compilateur GnuCOBOL 3.x.
- Stockage : fichiers indexés (ISAM) pour clients et comptes, fichiers séquentiels pour transactions et alertes.
- Interface : console (menu texte, `ACCEPT` / `DISPLAY`).
- Build : `Makefile`.

### 6.2 Programmes

| Programme | Rôle |
|---|---|
| `BANQUE.cob` | Programme principal : menus client et administrateur, orchestration. |
| `AUTH.cob` | Vérification du PIN, gestion des échecs et du blocage. |
| `COMPTE.cob` | Création, consultation, dépôt, retrait, virement. |
| `FRAUDE.cob` | Application des règles de fraude, écriture des alertes. |
| `RELEVE.cob` | Génération des relevés. |
| `BATCH-INT.cob` | Traitement mensuel des intérêts et frais. |

Les programmes communiquent par `CALL ... USING` avec des zones de liaison définies dans des copybooks.

### 6.3 Modèle de données

**CLIENTS** (indexé, clé : identifiant client)

| Champ | Description |
|---|---|
| ID-CLIENT | Identifiant unique |
| NOM | Nom du client |
| PIN-HASH | Empreinte du PIN |
| ECHECS | Nombre d'échecs consécutifs |
| STATUT | Actif, bloqué |

**COMPTES** (indexé, clé : numéro de compte, clé alternative : identifiant client)

| Champ | Description |
|---|---|
| NUM-COMPTE | Numéro unique |
| TYPE | Courant (C) ou épargne (E) |
| DECOUVERT | Découvert autorisé (0 pour l'épargne) |
| ID-CLIENT | Titulaire |
| SOLDE | Solde courant (décimal signé) |
| PLAFOND-JOUR | Plafond journalier de sorties |
| STATUT | Actif, gelé, clos |
| DATE-OUVERTURE | Date d'ouverture |

**TRANSACTIONS** (séquentiel, ajout seul)

| Champ | Description |
|---|---|
| ID-TRX | Numéro séquentiel |
| DATE-HEURE | Horodatage |
| TYPE | Dépôt, retrait, virement, intérêt, frais |
| COMPTE-SRC / COMPTE-DST | Comptes concernés |
| MONTANT | Montant de l'opération |
| STATUT | Accepté, refusé |
| MOTIF | Motif de refus éventuel |

**ALERTES** (séquentiel, ajout seul)

| Champ | Description |
|---|---|
| DATE-HEURE | Horodatage |
| REGLE | Règle de fraude déclenchée |
| ID-CLIENT / NUM-COMPTE | Cible de l'alerte |
| MONTANT | Montant concerné, le cas échéant |

**PARAMETRES** (fichier de configuration lu au démarrage) : taux d'intérêt annuel, frais mensuels, plafonds par défaut, multiple de détection d'anomalie, nombre maximal d'échecs de PIN.

---

## 7. Règles de gestion

Les valeurs ci-dessous sont des **valeurs par défaut proposées**, toutes modifiables dans le fichier de paramètres.

| Règle | Valeur par défaut |
|---|---|
| Échecs de PIN avant blocage | 3 |
| Longueur du PIN | 4 à 6 chiffres |
| Plafond journalier de sorties par compte | 1 000,00 |
| Découvert autorisé | 0 (modifiable par compte courant) |
| Taux d'intérêt annuel de l'épargne | 3,00 % |
| Taux d'intérêt annuel | 1,50 % (appliqué au douzième chaque mois) |
| Frais de tenue de compte mensuels | 2,00 |
| Seuil d'alerte « montant anormal » | 5 fois la moyenne des opérations du compte |
| Montant minimal d'une opération | 0,01 |

**Formule des intérêts mensuels**

```
intérêt = solde × taux annuel ÷ 12      (arrondi au centime, solde > 0 uniquement)
```

---

## 8. Tests et critères d'acceptation

### 8.1 Scénarios de bout en bout

| # | Scénario | Résultat attendu |
|---|---|---|
| T1 | Connexion avec bon PIN | Accès au menu client |
| T2 | 3 mauvais PIN consécutifs | Compte bloqué, alerte inscrite |
| T3 | Dépôt de 100,00 | Solde +100,00, une ligne d'historique |
| T4 | Retrait supérieur au solde | Refus, solde inchangé, ligne « refusé » |
| T5 | Virement valide A vers B | Solde A −X, solde B +X, deux écritures cohérentes |
| T6 | Virement vers un compte inexistant | Refus, aucun solde modifié |
| T7 | Retraits cumulés au-delà du plafond journalier | Dernier retrait refusé, alerte inscrite |
| T8 | Opération 5 fois supérieure à la moyenne | Alerte inscrite |
| T9 | Batch mensuel | Intérêts et frais appliqués, rapport produit |
| T10 | Second lancement du batch sur la même période | Refusé |
| T11 | Relevé sur une période | Solde initial + crédits − débits = solde final |
| T12 | Opération sur compte gelé | Refus |

### 8.2 Invariants vérifiés après chaque scénario

- La somme de tous les soldes varie uniquement du montant des dépôts, retraits, intérêts et frais, jamais d'un virement.
- Aucun solde inférieur à `−découvert autorisé` du compte (donc aucun solde négatif tant que le découvert vaut 0, et jamais pour l'épargne).
- Le nombre de lignes d'historique ne diminue jamais.

### 8.3 Critères d'acceptation de la V1

- Les 12 scénarios passent via un script de test automatisé (`make test`).
- Le projet compile sans avertissement bloquant.
- Le README explique l'installation de GnuCOBOL, la compilation, l'exécution et les jeux de test.

---

## 9. Planning par étapes

| Étape | Contenu | Livrable |
|---|---|---|
| 1 | Structure du dépôt, copybooks, fichiers de données, Makefile | Projet qui compile |
| 2 | Clients, comptes, authentification | Connexion par PIN fonctionnelle |
| 3 | Dépôt, retrait, virement, historique | Opérations de base testées |
| 4 | Détection de fraude | Plafonds et alertes |
| 5 | Batch intérêts et frais | Traitement mensuel rejouable |
| 6 | Relevés | Fichiers de relevé formatés |
| 7 | Tests de bout en bout, README | V1 livrable |

---

## 10. Évolutions possibles (hors V1)

- Interface web d'administration, HTTPS et sessions, API REST documentée.
- Virements programmés.
- Règles de fraude plus riches (géolocalisation simulée, fréquence, horaires).
- Migration du stockage vers une base SQL.
- Agios (intérêts débiteurs) sur découvert, comptes épargne plafonnés.

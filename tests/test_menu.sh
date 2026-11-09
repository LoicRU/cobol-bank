#!/bin/sh
# test_menu.sh - scenario de bout en bout du programme principal (bin/banque)
# Les saisies sont envoyees par redirection ; fichiers temporaires dans tests/.
# Usage : sh tests/test_menu.sh   (depuis la racine, apres make bin/banque)

BIN=bin/banque
T=tests
rm -f $T/MENU_*
export CLIENTS_FILE=$T/MENU_CLIENTS.dat COMPTES_FILE=$T/MENU_COMPTES.dat
export TRX_FILE=$T/MENU_TRX.dat ALERTES_FILE=$T/MENU_ALERTES.dat
export PARAMS_FILE=$T/MENU_AUCUN_PARAMS.cfg
export BATCH_FILE=$T/MENU_BATCH.dat BATCH_REPORT_DIR=$T RELEVE_DIR=$T
AUJ=$(date +%Y%m%d)
NB_ECHECS=0

verifie() { # $1 = libelle, $2 = fichier de sortie, $3 = motif
    if grep -q -- "$3" "$2"; then
        echo "  PASS $1"
    else
        echo "  FAIL $1 (motif absent : $3)"
        NB_ECHECS=$((NB_ECHECS + 1))
    fi
}
absent() { # $1 = libelle, $2 = fichier de sortie, $3 = motif
    if grep -q -- "$3" "$2"; then
        echo "  FAIL $1 (motif present : $3)"
        NB_ECHECS=$((NB_ECHECS + 1))
    else
        echo "  PASS $1"
    fi
}

echo "MENU : premier lancement, creation client et comptes"
printf '%s\n' Admin 1234 \
    1 1 1234 \
    1 Alice C 4321 \
    1 Bob C 5555 \
    2 2 "" 0 0 \
    2 3 "" 0 0 \
    1 \
    0 0 | $BIN > $T/MENU_1.out 2>&1
verifie "administrateur cree" $T/MENU_1.out "Administrateur cree : identifiant 1"
verifie "client Alice (id 2)" $T/MENU_1.out "Client cree : identifiant 000002"
verifie "client Bob (id 3)" $T/MENU_1.out "Client cree : identifiant 000003"
verifie "compte Alice ouvert" $T/MENU_1.out "Compte ouvert : 1000000001"
verifie "compte Bob ouvert" $T/MENU_1.out "Compte ouvert : 1000000002"

echo "MENU : operations d'Alice"
printf '%s\n' \
    1 2 4321 \
    2 1000000001 500 \
    3 1000000001 100 \
    4 1000000001 1000000002 50,5 \
    3 1000000002 10 \
    3 1000000001 99999 \
    3 1000000001 abc \
    3 1000000001 -5 \
    1 \
    5 1000000001 \
    6 1000000001 $AUJ $AUJ "" \
    6 1000000001 $AUJ $AUJ 2 \
    6 1000000002 $AUJ $AUJ \
    0 0 | $BIN > $T/MENU_2.out 2>&1
verifie "connexion Alice" $T/MENU_2.out "Bonjour Alice"
verifie "depot : nouveau solde 500" $T/MENU_2.out "Nouveau solde :        500.00"
verifie "retrait 100 : solde 400" $T/MENU_2.out "Nouveau solde :        400.00"
verifie "virement 50,5 : solde 349.50" $T/MENU_2.out "Nouveau solde :        349.50"
verifie "compte d'un autre refuse (74)" $T/MENU_2.out "Ce compte n'est pas a vous"
verifie "solde insuffisant (93)" $T/MENU_2.out "Solde insuffisant"
verifie "montant texte refuse" $T/MENU_2.out "Montant invalide"
verifie "mes comptes : 349.50" $T/MENU_2.out "Compte 1000000001  solde        349.50"
verifie "historique : operation refusee avec motif" $T/MENU_2.out "99999.00 R SOLDE INSUFFISANT"
verifie "releve : 3 operations" $T/MENU_2.out "Operations :       3"
verifie "releve : total debits 150.50" $T/MENU_2.out "Total debits  :         150.50"
verifie "releve : solde final 349.50" $T/MENU_2.out "Solde final   :        349.50"
verifie "releve d'un compte tiers refuse" $T/MENU_2.out "Ce compte n'est pas a vous"
verifie "fichier releve ecrit" $T/RELEVE_1000000001_${AUJ}_${AUJ}.txt "Verification : OK"
verifie "format choisi : texte par defaut" $T/MENU_2.out "_${AUJ}_${AUJ}.txt"
verifie "format choisi : CSV" $T/MENU_2.out "_${AUJ}_${AUJ}.csv"
verifie "fichier CSV ecrit" $T/RELEVE_1000000001_${AUJ}_${AUJ}.csv "Verification;OK"
verifie "chemin affiche = dossier reel" $T/MENU_2.out "Fichier : tests/RELEVE_"

echo "MENU : PIN faux, blocage, alerte, deblocage"
printf '%s\n' 1 2 0000 1 2 0000 1 2 0000 1 2 4321 \
    1 1 1234 4 3 2 0 \
    1 2 4321 0 0 | $BIN > $T/MENU_3.out 2>&1
verifie "mauvais PIN" $T/MENU_3.out "Identifiant ou PIN incorrect"
verifie "client bloque meme avec le bon PIN" $T/MENU_3.out "Client bloque"
verifie "alerte PIN_BLOQUE visible par l'admin" $T/MENU_3.out "PIN_BLOQUE"
verifie "deblocage" $T/MENU_3.out "Client debloque"
verifie "reconnexion apres deblocage" $T/MENU_3.out "Bonjour Alice"

echo "MENU : droits"
printf '%s\n' 1 2 4321 0 0 | $BIN > $T/MENU_4.out 2>&1
absent "menu client sans option admin" $T/MENU_4.out "Creer un client"

echo "MENU : traitement mensuel"
printf '%s\n' 1 1 1234 5 "" 5 "" 5 abc 0 0 | $BIN > $T/MENU_5.out 2>&1
verifie "batch execute" $T/MENU_5.out "Traitement termine."
verifie "batch rejoue refuse" $T/MENU_5.out "Periode deja traitee"
verifie "batch periode invalide" $T/MENU_5.out "Periode invalide"
printf '%s\n' 1 2 4321 1 0 0 | $BIN > $T/MENU_6.out 2>&1
verifie "solde apres interets et frais (347.94)" $T/MENU_6.out "solde        347.94"

echo "MENU : epargne, decouvert et modification de compte"
printf '%s\n' 1 1 1234 \
    2 2 2 0 \
    8 1000000002 "" 100 "" \
    8 1000000003 "" "" \
    8 1000000002 abc \
    8 1000000002 "" "" X \
    0 0 | $BIN > $T/MENU_10.out 2>&1
verifie "compte epargne ouvert" $T/MENU_10.out "Type : epargne"
verifie "compte epargne : numero" $T/MENU_10.out "Compte ouvert : 1000000003"
verifie "decouvert accorde a Bob" $T/MENU_10.out "Compte modifie"
verifie "modification refusee : montant invalide" $T/MENU_10.out "Aucune modification"
verifie "modification refusee : statut invalide" $T/MENU_10.out "Statut invalide"
printf '%s\n' 1 3 5555 3 1000000002 100 3 1000000002 60 1 6 1000000002 $AUJ $AUJ "" 0 0 \
    | $BIN > $T/MENU_11.out 2>&1
verifie "retrait dans le decouvert : solde negatif" $T/MENU_11.out "Nouveau solde :        -51.44"
verifie "retrait au-dela du decouvert refuse" $T/MENU_11.out "Solde insuffisant"
verifie "mes comptes : decouvert affiche" $T/MENU_11.out "decouvert autorise       100.00"
verifie "releve : solde final negatif" $T/MENU_11.out "Solde final   : *-51.44"
printf '%s\n' 1 2 4321 2 1000000003 200 3 1000000003 10 4 1000000003 1000000002 10 \
    4 1000000003 1000000001 50 1 0 0 | $BIN > $T/MENU_12.out 2>&1
verifie "epargne : depot" $T/MENU_12.out "Nouveau solde :        200.00"
verifie "epargne : retrait interdit (90)" $T/MENU_12.out "interdite sur un compte epargne"
verifie "epargne : virement vers un tiers interdit" $T/MENU_12.out "interdite sur un compte epargne"
verifie "epargne : virement vers son courant" $T/MENU_12.out "Nouveau solde :        150.00"
verifie "mes comptes : epargne affiche" $T/MENU_12.out "epargne"

echo "MENU : inscription libre et ouverture de compte par le client"
printf '%s\n' 2 "Zoe Martin" 2468 2 "Zo<e" 2468 2 "Zoe" 12 0 | $BIN > $T/MENU_13.out 2>&1
verifie "inscription : client cree" $T/MENU_13.out "Client cree : identifiant 000004"
verifie "inscription : nom invalide" $T/MENU_13.out "Nom invalide"
verifie "inscription : PIN invalide" $T/MENU_13.out "PIN invalide"
printf '%s\n' 1 4 2468 8 "" 8 2 8 9 8 "" 8 "" 8 "" 8 "" 1 0 0 | $BIN > $T/MENU_14.out 2>&1
verifie "connexion du nouveau client" $T/MENU_14.out "Bonjour Zoe Martin"
verifie "ouverture : premier compte courant" $T/MENU_14.out "Compte ouvert : 1000000004"
verifie "ouverture : compte epargne" $T/MENU_14.out "Type : epargne"
verifie "ouverture : type invalide" $T/MENU_14.out "Type de compte invalide"
verifie "ouverture : limite de comptes" $T/MENU_14.out "Nombre maximal de comptes atteint"
verifie "mes comptes : 5 comptes" $T/MENU_14.out "Compte 1000000008  solde"
absent "mes comptes : pas de 6e compte" $T/MENU_14.out "Compte 1000000009"

echo "MENU : fin de saisie sans plantage"
printf '' | timeout 20 $BIN > $T/MENU_7.out 2>&1
verifie "arret propre sur fin d'entree" $T/MENU_7.out "arret"

echo "MENU : connexion par nom"
printf '%s\n' 1 alice 4321 0 0 | $BIN > $T/MENU_9.out 2>&1
verifie "nom en minuscules accepte" $T/MENU_9.out "Bonjour Alice"
printf '%s\n' 1 Zorro 4321 0 | $BIN > $T/MENU_9.out 2>&1
verifie "nom inconnu : message generique" $T/MENU_9.out "Identifiant ou PIN incorrect"
absent "nom inconnu : pas de connexion" $T/MENU_9.out "Bonjour"
printf '%s\n' 1 Bob 0000 1 Bob 0000 1 Bob 0000 1 Bob 5555 0 | $BIN > $T/MENU_9.out 2>&1
verifie "client bloque par nom" $T/MENU_9.out "Client bloque"
printf '%s\n' 1 1 1234 1 Alice C 1111 0 1 Alice 0 | $BIN > $T/MENU_9.out 2>&1
verifie "homonymes : identifiant demande" $T/MENU_9.out "Plusieurs clients portent ce nom"
printf '%s\n' 1 2 4321 0 0 | $BIN > $T/MENU_9.out 2>&1
verifie "homonymes : connexion par identifiant" $T/MENU_9.out "Bonjour Alice"

echo "MENU : erreur de fichier (arret propre)"
printf '%s\n' 1 2 4321 1 0 0 | COMPTES_FILE=$T $BIN > $T/MENU_8.out 2>&1
CODE=$?
verifie "message d'erreur fichier" $T/MENU_8.out "Erreur fichier"
verifie "arret du programme" $T/MENU_8.out "arret du programme"
if [ $CODE -ne 0 ]; then echo "  PASS code retour non nul"; else echo "  FAIL code retour non nul"; NB_ECHECS=$((NB_ECHECS + 1)); fi

rm -f $T/MENU_* $T/RELEVE_1000000001_* $T/RELEVE_1000000002_* $T/BATCH_*.txt
if [ $NB_ECHECS -eq 0 ]; then
    echo "TOUS LES TESTS PASSENT"
else
    echo "ECHECS : $NB_ECHECS"
    exit 1
fi

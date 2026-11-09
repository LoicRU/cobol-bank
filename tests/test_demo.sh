#!/bin/sh
# test_demo.sh - verifie que la demo produit les donnees annoncees
BIN=bin/banque
T=tests
export DEMO_DIR=$T/DEMO_TMP
export PARAMS_FILE=$T/DEMO_AUCUN_PARAMS.cfg
AUJ=$(date +%Y%m%d)
NB_ECHECS=0

verifie() { # $1 = libelle, $2 = fichier, $3 = motif
    if grep -q -- "$3" "$2"; then echo "  PASS $1"
    else echo "  FAIL $1 (motif absent : $3)"; NB_ECHECS=$((NB_ECHECS + 1)); fi
}

echo "DEMO : creation du jeu de donnees"
sh $T/demo.sh > $T/DEMO_sortie.txt 2>&1
verifie "recapitulatif affiche" $T/DEMO_sortie.txt "Demo creee"
verifie "releve d'Alice genere" $DEMO_DIR/reports/RELEVE_1000000001_${AUJ}_${AUJ}.txt "RELEVE DE COMPTE"
verifie "releve CSV genere" $DEMO_DIR/reports/RELEVE_1000000001_${AUJ}_${AUJ}.csv "Verification;OK"
verifie "releve coherent" $DEMO_DIR/reports/RELEVE_1000000001_${AUJ}_${AUJ}.txt "Verification : OK"
verifie "rapport du batch genere" $DEMO_DIR/reports/BATCH_$(date +%Y%m).txt "PERIODE"

# soldes apres le batch (taux 1.50 %, frais 2.00)
printf '%s\n' 1 Alice 4321 1 0 0 | sh $T/demo.sh run > $T/DEMO_alice.txt 2>&1
printf '%s\n' 1 Bob 5555 1 0 0 | sh $T/demo.sh run > $T/DEMO_bob.txt 2>&1
printf '%s\n' 1 Alice 4321 3 1000000005 5 0 0 | sh $T/demo.sh run > $T/DEMO_epargne.txt 2>&1
printf '%s\n' 1 Clara 2468 0 | sh $T/demo.sh run > $T/DEMO_clara.txt 2>&1
printf '%s\n' 1 1 1234 4 0 0 | sh $T/demo.sh run > $T/DEMO_admin.txt 2>&1

echo "DEMO : contenu"
verifie "Alice compte 1 : 1078.85" $T/DEMO_alice.txt "Compte 1000000001  solde       1078.85"
verifie "Alice compte 2 : 348.44" $T/DEMO_alice.txt "Compte 1000000002  solde        348.44"
verifie "Bob compte 3 : -102.00 (decouvert)" $T/DEMO_bob.txt "Compte 1000000003  solde       -102.00"
verifie "Bob : decouvert affiche" $T/DEMO_bob.txt "decouvert autorise       200.00"
verifie "Alice epargne : 1002.50 (interets 3 %, sans frais)" $T/DEMO_alice.txt "Compte 1000000005  solde       1002.50"
verifie "Alice epargne : retrait refuse" $T/DEMO_epargne.txt "interdite sur un compte epargne"
verifie "Clara bloquee" $T/DEMO_clara.txt "Client bloque"
verifie "alerte plafond journalier" $T/DEMO_admin.txt "PLAFOND_JOUR"
verifie "alerte echecs rapproches" $T/DEMO_admin.txt "ECHECS_RAPIDES"
verifie "alerte blocage" $T/DEMO_admin.txt "PIN_BLOQUE"

echo "DEMO : rejeu"
sh $T/demo.sh > /dev/null 2>&1
printf '%s\n' 1 Alice 4321 1 0 0 | sh $T/demo.sh run > $T/DEMO_alice2.txt 2>&1
verifie "meme resultat apres recreation" $T/DEMO_alice2.txt "Compte 1000000001  solde       1078.85"

rm -rf $DEMO_DIR $T/DEMO_*
if [ $NB_ECHECS -eq 0 ]; then echo "TOUS LES TESTS PASSENT"
else echo "ECHECS : $NB_ECHECS"; exit 1; fi

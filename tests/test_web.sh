#!/bin/sh
# test_web.sh - API COBOL (bin/api) et serveur web sur le jeu de demonstration
# Usage : sh tests/test_web.sh   (depuis la racine, apres make bin/api)
T=tests
export DEMO_DIR=$T/WEB_TMP
export PARAMS_FILE=$T/WEB_AUCUN_PARAMS.cfg
export CLIENTS_FILE=$DEMO_DIR/CLIENTS.dat COMPTES_FILE=$DEMO_DIR/COMPTES.dat
export TRX_FILE=$DEMO_DIR/TRANSACTIONS.dat ALERTES_FILE=$DEMO_DIR/ALERTES.dat
export BATCH_FILE=$DEMO_DIR/BATCH.dat
PORT=8097
URL=http://127.0.0.1:$PORT
NB_ECHECS=0

verifie() { # $1 = libelle, $2 = texte, $3 = motif
    if printf '%s' "$2" | grep -q -- "$3"; then echo "  PASS $1"
    else echo "  FAIL $1 (motif absent : $3 ; recu : $2)"; NB_ECHECS=$((NB_ECHECS + 1)); fi
}
api() { printf '%s\n' "$1" | bin/api; }
post() { curl -s -X POST "$URL/api/$1" -d "$2"; }

sh $T/demo.sh > /dev/null 2>&1

echo "API : bin/api en ligne de commande"
verifie "connexion Alice" "$(api 'connexion 2 4321')" '"nom":"Alice"'
verifie "mauvais PIN (81)" "$(api 'connexion 2 0000')" '"statut":"81"'
verifie "identifiant inconnu (81)" "$(api 'connexion 99 4321')" '"statut":"81"'
verifie "administrateur refuse (78)" "$(api 'connexion 1 1234')" '"statut":"78"'
verifie "commande inconnue (77)" "$(api 'foo 2 4321')" '"statut":"77"'
verifie "comptes : solde courant" "$(api 'comptes 2 4321')" '"num":"1000000001","solde":1078.85'
verifie "comptes : epargne" "$(api 'comptes 2 4321')" '"solde":1002.50,"plafond":0.00,"decouvert":0.00,"type":"E"'
verifie "comptes : decouvert de Bob" "$(api 'comptes 3 5555')" '"solde":-102.00,"plafond":500.00,"decouvert":200.00'
verifie "depot" "$(api 'depot 2 4321 1000000001 10,50')" '"solde":1089.35'
verifie "retrait" "$(api 'retrait 2 4321 1000000001 9.35')" '"solde":1080.00'
verifie "virement" "$(api 'virement 2 4321 1000000002 1000000001 20')" '"solde":328.44'
verifie "retrait epargne interdit (90)" "$(api 'retrait 2 4321 1000000005 5')" '"statut":"90"'
verifie "compte d'un autre (74)" "$(api 'retrait 2 4321 1000000003 5')" '"statut":"74"'
verifie "virement depuis le compte d'un autre (74)" "$(api 'virement 2 4321 1000000003 1000000001 5')" '"statut":"74"'
verifie "solde insuffisant (93)" "$(api 'retrait 2 4321 1000000002 999999')" '"statut":"93"'
verifie "montant invalide (79)" "$(api 'depot 2 4321 1000000001 abc')" '"statut":"79"'
verifie "montant a 3 decimales (79)" "$(api 'depot 2 4321 1000000001 1.234')" '"statut":"79"'
verifie "montant nul (79)" "$(api 'depot 2 4321 1000000001 0')" '"statut":"79"'
verifie "historique de l'epargne" "$(api 'historique 2 4321 1000000005')" '"motif":"RETRAIT INTERDIT EPARGNE"'
verifie "historique d'un autre compte (74)" "$(api 'historique 2 4321 1000000003')" '"statut":"74"'
verifie "Clara bloquee (82)" "$(api 'connexion 4 2468')" '"statut":"82"'

echo "WEB : serveur HTTP"
python3 web/server.py $PORT > $T/WEB_serveur.log 2>&1 &
PID=$!
for i in 1 2 3 4 5 6 7 8 9 10; do
    curl -s -o /dev/null "$URL/" && break
    sleep 0.3
done
verifie "page d'accueil" "$(curl -s $URL/)" "<title>cobol-bank</title>"
verifie "connexion Bob" "$(post connexion '{"id":"3","pin":"5555"}')" '"nom": "Bob"'
verifie "comptes de Bob" "$(post comptes '{"id":"3","pin":"5555"}')" '"solde": -102.0'
verifie "depot via HTTP" "$(post depot '{"id":"3","pin":"5555","compte":"1000000003","montant":"102"}')" '"solde": 0.0'
verifie "mauvais PIN via HTTP" "$(post comptes '{"id":"3","pin":"1111"}')" '"statut": "81"'
verifie "parametre avec espace refuse" "$(post depot '{"id":"3","pin":"5555","compte":"1000000003 9","montant":"1"}')" '"statut": "79"'
verifie "retour a la ligne refuse" "$(post depot '{"id":"3","pin":"5555","compte":"1000000003\n","montant":"1"}')" '"statut": "79"'
verifie "PIN trop court refuse" "$(post comptes '{"id":"3","pin":"12"}')" '"statut": "79"'
verifie "JSON invalide refuse" "$(post comptes 'pas du json')" '"statut": "79"'
verifie "commande inconnue" "$(post virer '{}')" '"statut": "77"'
verifie "chemin inconnu" "$(curl -s $URL/secret)" '"statut": "404"'
absent=$(grep -c "5555" $T/WEB_serveur.log)
if [ "$absent" -eq 0 ]; then echo "  PASS le PIN n'apparait pas dans les logs"
else echo "  FAIL le PIN apparait dans les logs"; NB_ECHECS=$((NB_ECHECS + 1)); fi
kill $PID 2>/dev/null
wait $PID 2>/dev/null

rm -rf $DEMO_DIR $T/WEB_*
if [ $NB_ECHECS -eq 0 ]; then echo "TOUS LES TESTS PASSENT"
else echo "ECHECS : $NB_ECHECS"; exit 1; fi

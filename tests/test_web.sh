#!/bin/sh
# test_web.sh - API COBOL (bin/api) et serveur web sur le jeu de demonstration
# Usage : sh tests/test_web.sh   (depuis la racine, apres make bin/api)
T=tests
export DEMO_DIR=$T/WEB_TMP
export PARAMS_FILE=$T/WEB_AUCUN_PARAMS.cfg
export CLIENTS_FILE=$DEMO_DIR/CLIENTS.dat COMPTES_FILE=$DEMO_DIR/COMPTES.dat
export TRX_FILE=$DEMO_DIR/TRANSACTIONS.dat ALERTES_FILE=$DEMO_DIR/ALERTES.dat
export PROGRAMMES_FILE=$DEMO_DIR/PROGRAMMES.dat
export BATCH_FILE=$DEMO_DIR/BATCH.dat RELEVE_DIR=$DEMO_DIR/reports
AUJ=$(date +%Y%m%d)
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
verifie "comptes : decouvert de Bob" "$(api 'comptes 3 5555')" '"solde":-103.00,"plafond":500.00,"decouvert":200.00'
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

verifie "API : inscription" "$(api 'inscription 0 1357 Jean-Pierre_D'"'"'Arc')" '"id":5'
verifie "API : connexion apres inscription" "$(api 'connexion 5 1357')" '"nom":"Jean-Pierre D'"'"'Arc"'
verifie "API : nom invalide (84)" "$(api 'inscription 0 1357 Zo<e')" '"statut":"84"'
verifie "API : PIN invalide (83)" "$(api 'inscription 0 12 Zoe')" '"statut":"83"'
verifie "API : ouverture epargne" "$(api 'ouvrir 5 1357 E')" '"num":"1000000006","type":"E"'
verifie "API : type invalide (87)" "$(api 'ouvrir 5 1357 X')" '"statut":"87"'
verifie "API : historique de l'ouverture" "$(api 'historique 5 1357 1000000006')" '"motif":"OUVERTURE DE COMPTE"'

echo "API : releve"
verifie "releve texte" "$(api "releve 3 5555 1000000003 $AUJ $AUJ T")" '"fichier":"RELEVE_1000000003_'"$AUJ"'_'"$AUJ"'.txt","operations":'
verifie "releve CSV" "$(api "releve 3 5555 1000000003 $AUJ $AUJ C")" '.csv"'
verifie "releve : fichier ecrit et coherent" "$(cat $DEMO_DIR/reports/RELEVE_1000000003_${AUJ}_${AUJ}.txt)" 'Verification : OK'
verifie "releve : compte d'un autre (74)" "$(api "releve 2 4321 1000000003 $AUJ $AUJ T")" '"statut":"74"'
verifie "releve : periode invalide (73)" "$(api "releve 3 5555 1000000003 20269999 $AUJ T")" '"statut":"73"'
verifie "releve : fin avant debut (73)" "$(api "releve 3 5555 1000000003 $AUJ 20200101 T")" '"statut":"73"'
verifie "releve : format inconnu (79)" "$(api "releve 3 5555 1000000003 $AUJ $AUJ X")" '"statut":"79"'
verifie "releve : compte inconnu (23)" "$(api "releve 3 5555 1999999999 $AUJ $AUJ T")" '"statut":"23"'
verifie "releve : refuse a l'admin (78)" "$(api "releve 1 1234 1000000003 $AUJ $AUJ T")" '"statut":"78"'

echo "API : virements programmes"
DEMAIN=$(date -d tomorrow +%Y%m%d)
verifie "programmes d'Alice : mensuel" "$(api 'programmes 2 4321')" '"id":1,"client":2,"src":"1000000001","dst":"1000000003","montant":30.00'
verifie "programmes d'Alice : unique du jour" "$(api 'programmes 2 4321')" '"freq":"U","statut":"A"'
verifie "programmes de Bob : aucun" "$(api 'programmes 3 5555')" '"programmes":\[\]'
verifie "programmer" "$(api "programmer 2 4321 1000000001 1000000003 5 $DEMAIN M")" '"id":3'
verifie "programmer : date passee (52)" "$(api 'programmer 2 4321 1000000001 1000000003 5 20200101 U')" '"statut":"52"'
verifie "programmer : frequence invalide (79)" "$(api "programmer 2 4321 1000000001 1000000003 5 $DEMAIN X")" '"statut":"79"'
verifie "programmer : montant invalide (79)" "$(api "programmer 2 4321 1000000001 1000000003 abc $DEMAIN U")" '"statut":"79"'
verifie "programmer : compte d'un autre (74)" "$(api "programmer 2 4321 1000000003 1000000001 5 $DEMAIN U")" '"statut":"74"'
verifie "programmer : destinataire inconnu (23)" "$(api "programmer 2 4321 1000000001 1999999999 5 $DEMAIN U")" '"statut":"23"'
verifie "programmer : epargne vers un tiers (90)" "$(api "programmer 2 4321 1000000005 1000000003 5 $DEMAIN U")" '"statut":"90"'
verifie "programmer : refuse a l'admin (78)" "$(api "programmer 1 1234 1000000001 1000000003 5 $DEMAIN U")" '"statut":"78"'
verifie "annuler le programme d'un autre (55)" "$(api 'annuler 3 5555 3')" '"statut":"55"'
verifie "annuler" "$(api 'annuler 2 4321 3')" '"ok":true'
verifie "annuler deux fois (56)" "$(api 'annuler 2 4321 3')" '"statut":"56"'
verifie "annuler un inconnu (54)" "$(api 'annuler 2 4321 99')" '"statut":"54"'
verifie "admin-programmes" "$(api 'admin-programmes 1 1234')" '"statut":"X"'
verifie "admin-programmes refuse a un client (78)" "$(api 'admin-programmes 2 4321')" '"statut":"78"'
verifie "admin-echeances refuse a un client (78)" "$(api 'admin-echeances 2 4321')" '"statut":"78"'
verifie "admin-echeances : 1 virement" "$(api 'admin-echeances 1 1234')" '"ok":true,"executes":1,"refuses":0'
verifie "admin-echeances : rejeu sans doublon" "$(api 'admin-echeances 1 1234')" '"executes":0,"refuses":0'
verifie "programme unique termine" "$(api 'programmes 2 4321')" '"freq":"U","statut":"T","executions":1'

echo "API : commandes administrateur"
verifie "admin-connexion" "$(api 'admin-connexion 1 1234')" '"nom":"Admin"'
verifie "admin-connexion : mauvais PIN (81)" "$(api 'admin-connexion 1 0000')" '"statut":"81"'
verifie "admin-connexion refusee a un client (78)" "$(api 'admin-connexion 2 4321')" '"statut":"78"'
verifie "admin-clients refuse a un client (78)" "$(api 'admin-clients 2 4321')" '"statut":"78"'
verifie "admin-batch refuse a un client (78)" "$(api 'admin-batch 2 4321 202612')" '"statut":"78"'
verifie "commande client refusee a l'admin (78)" "$(api 'comptes 1 1234')" '"statut":"78"'
verifie "admin-clients" "$(api 'admin-clients 1 1234')" '"nom":"Alice","role":"C","statut":"A"'
verifie "admin-clients : Clara bloquee" "$(api 'admin-clients 1 1234')" '"nom":"Clara","role":"C","statut":"B"'
verifie "admin-comptes : tous les clients" "$(api 'admin-comptes 1 1234')" '"statut":"A","client":3'
verifie "admin-alertes" "$(api 'admin-alertes 1 1234')" '"regle":"PLAFOND_JOUR"'
verifie "admin-bloquer" "$(api 'admin-bloquer 1 1234 5')" '"ok":true'
verifie "client bloque : connexion refusee (82)" "$(api 'connexion 5 1357')" '"statut":"82"'
verifie "admin-debloquer" "$(api 'admin-debloquer 1 1234 5')" '"ok":true'
verifie "client debloque : connexion" "$(api 'connexion 5 1357')" '"nom":"Jean-Pierre'
verifie "admin ne se bloque pas lui-meme (79)" "$(api 'admin-bloquer 1 1234 1')" '"statut":"79"'
verifie "admin-bloquer : client inconnu (23)" "$(api 'admin-bloquer 1 1234 99')" '"statut":"23"'
verifie "admin-bloquer : identifiant invalide (79)" "$(api 'admin-bloquer 1 1234 abc')" '"statut":"79"'
verifie "admin-modifier" "$(api 'admin-modifier 1 1234 1000000003 700 250,50 A')" '"ok":true'
verifie "admin-modifier : effet visible" "$(api 'comptes 3 5555')" '"plafond":700.00,"decouvert":250.50'
verifie "admin-modifier : gel" "$(api 'admin-modifier 1 1234 1000000004 0 0 G')" '"ok":true'
verifie "admin-modifier : gel visible" "$(api 'admin-comptes 1 1234')" '"num":"1000000004","solde":0.00,"plafond":0.00,"decouvert":0.00,"type":"C","statut":"G"'
verifie "admin-modifier : decouvert sur epargne (79)" "$(api 'admin-modifier 1 1234 1000000005 0 50 A')" '"statut":"79"'
verifie "admin-modifier : statut invalide (79)" "$(api 'admin-modifier 1 1234 1000000003 0 0 X')" '"statut":"79"'
verifie "admin-modifier : montant invalide (79)" "$(api 'admin-modifier 1 1234 1000000003 abc 0 A')" '"statut":"79"'
verifie "admin-modifier : plafond negatif (79)" "$(api 'admin-modifier 1 1234 1000000003 -5 0 A')" '"statut":"79"'
verifie "admin-modifier : compte inconnu (23)" "$(api 'admin-modifier 1 1234 1999999999 0 0 A')" '"statut":"23"'
verifie "admin-batch : periode invalide (73)" "$(api 'admin-batch 1 1234 13')" '"statut":"73"'

echo "WEB : serveur HTTP"
python3 web/server.py $PORT > $T/WEB_serveur.log 2>&1 &
PID=$!
for i in 1 2 3 4 5 6 7 8 9 10; do
    curl -s -o /dev/null "$URL/" && break
    sleep 0.3
done
verifie "config : pas de mode demo" "$(curl -s $URL/api/config)" '"demo": false'
verifie "page d'accueil" "$(curl -s $URL/)" "<title>cobol-bank</title>"
verifie "connexion Bob" "$(post connexion '{"id":"3","pin":"5555"}')" '"nom": "Bob"'
verifie "comptes de Bob" "$(post comptes '{"id":"3","pin":"5555"}')" '"solde": -103.0'
verifie "depot via HTTP" "$(post depot '{"id":"3","pin":"5555","compte":"1000000003","montant":"103"}')" '"solde": 0.0'
verifie "mauvais PIN via HTTP" "$(post comptes '{"id":"3","pin":"1111"}')" '"statut": "81"'
verifie "parametre avec espace refuse" "$(post depot '{"id":"3","pin":"5555","compte":"1000000003 9","montant":"1"}')" '"statut": "79"'
verifie "retour a la ligne refuse" "$(post depot '{"id":"3","pin":"5555","compte":"1000000003\n","montant":"1"}')" '"statut": "79"'
verifie "PIN trop court refuse" "$(post comptes '{"id":"3","pin":"12"}')" '"statut": "79"'
verifie "JSON invalide refuse" "$(post comptes 'pas du json')" '"statut": "79"'
verifie "commande inconnue" "$(post virer '{}')" '"statut": "77"'
verifie "chemin inconnu" "$(curl -s $URL/secret)" '"statut": "404"'
verifie "inscription via HTTP" "$(post inscription '{"nom":"Zoé Müller","pin":"2468"}')" '"id": 6'
verifie "connexion du nouvel inscrit" "$(post connexion '{"id":"6","pin":"2468"}')" 'Zo.u00e9 M.u00fcller'
verifie "inscription : nom invalide refuse" "$(post inscription '{"nom":"Z<oe","pin":"2468"}')" '"statut": "79"'
verifie "inscription : sous-ligne refusee" "$(post inscription '{"nom":"a_b","pin":"2468"}')" '"statut": "79"'
verifie "inscription : nom trop long refuse" "$(post inscription '{"nom":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","pin":"2468"}')" '"statut": "79"'
verifie "inscription : PIN invalide refuse" "$(post inscription '{"nom":"Zoe","pin":"12"}')" '"statut": "79"'
verifie "ouverture via HTTP" "$(post ouvrir '{"id":"6","pin":"2468","type":"C"}')" '"type": "C"'
verifie "ouverture : type invalide refuse" "$(post ouvrir '{"id":"6","pin":"2468","type":"X"}')" '"statut": "79"'
post ouvrir '{"id":"6","pin":"2468","type":"C"}' > /dev/null
post ouvrir '{"id":"6","pin":"2468","type":"C"}' > /dev/null
post ouvrir '{"id":"6","pin":"2468","type":"E"}' > /dev/null
post ouvrir '{"id":"6","pin":"2468","type":"C"}' > /dev/null
verifie "ouverture : 6e compte refuse (88)" "$(post ouvrir '{"id":"6","pin":"2468","type":"C"}')" '"statut": "88"'
verifie "releve via HTTP : texte" "$(post releve '{"id":"3","pin":"5555","compte":"1000000003","debut":"'$AUJ'","fin":"'$AUJ'","format":"T"}')" 'RELEVE DE COMPTE'
verifie "releve via HTTP : CSV" "$(post releve '{"id":"3","pin":"5555","compte":"1000000003","debut":"'$AUJ'","fin":"'$AUJ'","format":"C"}')" 'Verification;OK'
verifie "releve via HTTP : compte d'un autre (74)" "$(post releve '{"id":"2","pin":"4321","compte":"1000000003","debut":"'$AUJ'","fin":"'$AUJ'","format":"T"}')" '"statut": "74"'
verifie "releve via HTTP : date invalide refusee" "$(post releve '{"id":"3","pin":"5555","compte":"1000000003","debut":"2026-11-01","fin":"'$AUJ'","format":"T"}')" '"statut": "79"'
verifie "releve via HTTP : injection refusee" "$(post releve '{"id":"3","pin":"5555","compte":"1000000003 ../x","debut":"'$AUJ'","fin":"'$AUJ'","format":"T"}')" '"statut": "79"'
verifie "releve via HTTP : format refuse" "$(post releve '{"id":"3","pin":"5555","compte":"1000000003","debut":"'$AUJ'","fin":"'$AUJ'","format":"X"}')" '"statut": "79"'
verifie "admin via HTTP : connexion" "$(post admin-connexion '{"id":"1","pin":"1234"}')" '"nom": "Admin"'
verifie "admin via HTTP : refuse a un client (78)" "$(post admin-clients '{"id":"3","pin":"5555"}')" '"statut": "78"'
verifie "admin via HTTP : clients" "$(post admin-clients '{"id":"1","pin":"1234"}')" '"nom": "Alice"'
verifie "admin via HTTP : comptes" "$(post admin-comptes '{"id":"1","pin":"1234"}')" '"client": 3'
verifie "admin via HTTP : alertes" "$(post admin-alertes '{"id":"1","pin":"1234"}')" '"alertes": \['
verifie "admin via HTTP : bloquer" "$(post admin-bloquer '{"id":"1","pin":"1234","client":"6"}')" '"ok": true'
verifie "admin via HTTP : client bloque (82)" "$(post connexion '{"id":"6","pin":"2468"}')" '"statut": "82"'
verifie "admin via HTTP : debloquer" "$(post admin-debloquer '{"id":"1","pin":"1234","client":"6"}')" '"ok": true'
verifie "admin via HTTP : modifier" "$(post admin-modifier '{"id":"1","pin":"1234","compte":"1000000003","plafond":"500","decouvert":"200","statut":"A"}')" '"ok": true'
verifie "admin via HTTP : statut invalide refuse" "$(post admin-modifier '{"id":"1","pin":"1234","compte":"1000000003","plafond":"500","decouvert":"200","statut":"X"}')" '"statut": "79"'
verifie "admin via HTTP : injection refusee" "$(post admin-modifier '{"id":"1","pin":"1234","compte":"1000000003","plafond":"5 6","decouvert":"200","statut":"A"}')" '"statut": "79"'
verifie "admin via HTTP : client non numerique refuse" "$(post admin-bloquer '{"id":"1","pin":"1234","client":"abc"}')" '"statut": "79"'
verifie "admin via HTTP : periode invalide refusee" "$(post admin-batch '{"id":"1","pin":"1234","periode":"12"}')" '"statut": "79"'
verifie "admin via HTTP : batch" "$(post admin-batch '{"id":"1","pin":"1234","periode":"202612"}')" '"periode": "202612"'
verifie "admin via HTTP : batch, agios au resume" "$(post admin-batch '{"id":"1","pin":"1234","periode":"202701"}')" '"agios": '
verifie "admin via HTTP : batch deja traite (71)" "$(post admin-batch '{"id":"1","pin":"1234","periode":"202612"}')" '"statut": "71"'
verifie "programmes via HTTP" "$(post programmes '{"id":"2","pin":"4321"}')" '"montant": 30.0'
verifie "programmer via HTTP" "$(post programmer '{"id":"2","pin":"4321","source":"1000000001","destination":"1000000003","montant":"5","date":"'$DEMAIN'","freq":"U"}')" '"id": 4'
verifie "programmer via HTTP : date invalide refusee" "$(post programmer '{"id":"2","pin":"4321","source":"1000000001","destination":"1000000003","montant":"5","date":"2026-12-01","freq":"U"}')" '"statut": "79"'
verifie "programmer via HTTP : frequence refusee" "$(post programmer '{"id":"2","pin":"4321","source":"1000000001","destination":"1000000003","montant":"5","date":"'$DEMAIN'","freq":"X"}')" '"statut": "79"'
verifie "programmer via HTTP : injection refusee" "$(post programmer '{"id":"2","pin":"4321","source":"1000000001 9","destination":"1000000003","montant":"5","date":"'$DEMAIN'","freq":"U"}')" '"statut": "79"'
verifie "annuler via HTTP" "$(post annuler '{"id":"2","pin":"4321","programme":"4"}')" '"ok": true'
verifie "annuler via HTTP : numero invalide refuse" "$(post annuler '{"id":"2","pin":"4321","programme":"a b"}')" '"statut": "79"'
verifie "admin via HTTP : programmes" "$(post admin-programmes '{"id":"1","pin":"1234"}')" '"programmes": \['
verifie "admin via HTTP : programmes refuse a un client (78)" "$(post admin-programmes '{"id":"2","pin":"4321"}')" '"statut": "78"'
verifie "admin via HTTP : echeances" "$(post admin-echeances '{"id":"1","pin":"1234"}')" '"executes": 0'
absent=$(grep -c "5555\|1234" $T/WEB_serveur.log)
if [ "$absent" -eq 0 ]; then echo "  PASS le PIN n'apparait pas dans les logs"
else echo "  FAIL le PIN apparait dans les logs"; NB_ECHECS=$((NB_ECHECS + 1)); fi
kill $PID 2>/dev/null
wait $PID 2>/dev/null

python3 web/server.py --demo $PORT > $T/WEB_demo.log 2>&1 &
PID=$!
sleep 1
verifie "config : mode demo" "$(curl -s $URL/api/config)" '"demo": true'
kill $PID 2>/dev/null
wait $PID 2>/dev/null

rm -rf $DEMO_DIR $T/WEB_*
if [ $NB_ECHECS -eq 0 ]; then echo "TOUS LES TESTS PASSENT"
else echo "ECHECS : $NB_ECHECS"; exit 1; fi

#!/bin/sh
# demo.sh - jeu de donnees de demonstration, dans demo/ (jamais data/)
#   sh tests/demo.sh        recree demo/ en jouant un scenario sur le vrai programme
#   sh tests/demo.sh run    lance le programme sur les donnees de demo/
#   sh tests/demo.sh web [port]   lance l'interface web sur les donnees de demo/
#                           (cree demo/ si besoin ; affiche les comptes d'essai)
# Variables : DEMO_DIR (defaut demo), PARAMS_FILE (defaut config/parametres.cfg)

BIN=bin/banque
D=${DEMO_DIR:-demo}
export CLIENTS_FILE=$D/CLIENTS.dat COMPTES_FILE=$D/COMPTES.dat
export TRX_FILE=$D/TRANSACTIONS.dat ALERTES_FILE=$D/ALERTES.dat
export BATCH_FILE=$D/BATCH.dat BATCH_REPORT_DIR=$D/reports RELEVE_DIR=$D/reports

if [ "$1" = "run" ]; then
    [ -f "$CLIENTS_FILE" ] || { echo "Pas de donnees : lancer d'abord make demo"; exit 1; }
    exec $BIN
fi

if [ "$1" = "web" ]; then
    [ -f "$CLIENTS_FILE" ] || sh "$0" > /dev/null
    exec python3 web/server.py --demo ${2:+"$2"}
fi

[ -x $BIN ] || { echo "Compiler d'abord : make"; exit 1; }
AUJ=$(date +%Y%m%d)
rm -rf "$D"
mkdir -p "$D/reports"

# 1. administrateur, clients et comptes
#    1 Admin / 2 Alice / 3 Bob / 4 Clara ; comptes 1000000001 a 1000000005
#    (1000000005 : compte epargne d'Alice ; Bob a 200.00 de decouvert)
printf '%s\n' Admin 1234 \
    1 1 1234 \
    1 Alice C 4321 \
    1 Bob C 5555 \
    1 Clara C 2468 \
    2 2 "" 0 0 \
    2 2 "" 0 0 \
    2 3 "" 500 200 \
    2 4 "" 0 0 \
    2 2 2 0 \
    0 0 | $BIN > /dev/null 2>&1

# 2. Alice : depots, retraits, virement, refus, plafond depasse, releve
printf '%s\n' \
    1 2 4321 \
    2 1000000001 2000 \
    2 1000000002 300 \
    3 1000000001 120,50 \
    4 1000000001 1000000003 200 \
    3 1000000001 50000 \
    3 1000000001 600 \
    3 1000000001 200 \
    2 1000000005 1000 \
    3 1000000005 50 \
    6 1000000001 "$AUJ" "$AUJ" "" \
    6 1000000001 "$AUJ" "$AUJ" 2 \
    0 0 | $BIN > /dev/null 2>&1

# 3. Bob : depot et virement vers le deuxieme compte d'Alice
printf '%s\n' 1 3 5555 \
    2 1000000003 150 \
    4 1000000003 1000000002 50 \
    3 1000000003 400 \
    0 0 | $BIN > /dev/null 2>&1

# 4. Clara se trompe trois fois de PIN : alertes et blocage
printf '%s\n' 1 Clara 0000 1 Clara 0000 1 Clara 0000 0 | $BIN > /dev/null 2>&1

# 5. traitement mensuel (mois en cours)
printf '%s\n' 1 1 1234 5 "" 0 0 | $BIN > /dev/null 2>&1

cat <<FIN
Demo creee dans $D/

  Identifiant ou nom   PIN    Role
  1 Admin              1234   administrateur
  2 Alice              4321   client (comptes 1000000001 et 1000000002,
                              epargne 1000000005)
  3 Bob                5555   client (compte 1000000003, plafond 500.00,
                              decouvert autorise 200.00, solde negatif)
  4 Clara              2468   client BLOQUE (compte 1000000004) :
                              l'admin peut la debloquer (menu 3)

Dans le menu admin : option 4 pour les alertes (plafond depasse, echecs de
PIN rapproches, blocage), option 6 pour un releve, option 8 pour modifier
un compte (plafond, decouvert, statut).
Releves d'Alice (texte et CSV) deja generes dans $D/reports/

Lancer le programme sur ces donnees : make run-demo
FIN

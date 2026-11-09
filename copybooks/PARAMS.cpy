*> PARAMS.cpy - parametres de la banque (lus par le module PARAM)
*> PRM-TAUX-ANNUEL : taux annuel en fraction (0.0150 = 1.50 %)
01 PARAMS-REC.
   05 PRM-PLAFOND-DEFAUT   PIC 9(7)V99.
   05 PRM-FACTEUR          PIC 9(2).
   05 PRM-MIN-HISTORIQUE   PIC 9(2).
   05 PRM-TAUX-ANNUEL      PIC 9V9999.
   05 PRM-FRAIS-TENUE      PIC 9(5)V99.
   05 PRM-MAX-ECHECS       PIC 9(2).
   05 PRM-ALERTE-ECHECS    PIC 9(2).
   05 PRM-FENETRE-SEC      PIC 9(5).
   05 PRM-TAUX-EPARGNE     PIC 9V9999.

*> RELEVE.cpy - resultat d'un releve de compte
*> REL-COHERENT : O si solde initial + credits - debits = solde final
01 RELEVE-RES.
   05 REL-NB-OPS        PIC 9(7).
   05 REL-SOLDE-INIT    PIC 9(9)V99.
   05 REL-SOLDE-FIN     PIC 9(9)V99.
   05 REL-TOT-DEBITS    PIC 9(11)V99.
   05 REL-TOT-CREDITS   PIC 9(11)V99.
   05 REL-COHERENT      PIC X.

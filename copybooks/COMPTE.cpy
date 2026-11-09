*> COMPTE.cpy - enregistrement d'un compte bancaire
*> Cle primaire : CPT-NUM
01 COMPTE-REC.
   05 CPT-NUM          PIC 9(10).
   05 CPT-ID-CLIENT    PIC 9(6).
   05 CPT-SOLDE        PIC S9(9)V99.
   05 CPT-PLAFOND      PIC 9(7)V99.
   05 CPT-STATUT       PIC X.
      88 CPT-ACTIF     VALUE "A".
      88 CPT-GELE      VALUE "G".
      88 CPT-CLOS      VALUE "C".
   05 CPT-DATE-OUV     PIC 9(8).

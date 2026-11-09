*> COMPTE.cpy - enregistrement d'un compte bancaire
*> Cle primaire : CPT-NUM
*> CPT-TYPE      : C compte courant (tout sauf E), E compte epargne
*> CPT-DECOUVERT : decouvert autorise (montant positif, 0 = aucun) ;
*>                 toujours 0 sur un compte epargne
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
   05 CPT-TYPE         PIC X.
      88 CPT-EPARGNE   VALUE "E".
      88 CPT-COURANT   VALUE "C".
   05 CPT-DECOUVERT    PIC 9(7)V99.

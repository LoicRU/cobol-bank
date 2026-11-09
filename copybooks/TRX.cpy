*> TRX.cpy - une ligne de l'historique des transactions
*> TRX-TYPE   : D depot, R retrait, V virement, I interet, F frais
*> TRX-STATUT : A accepte, R refuse
*> Depot : source = 0. Retrait : destination = 0.
01 TRX-REC.
   05 TRX-ID           PIC 9(10).
   05 TRX-DATE         PIC 9(8).
   05 TRX-HEURE        PIC 9(6).
   05 TRX-TYPE         PIC X.
   05 TRX-CPT-SRC      PIC 9(10).
   05 TRX-CPT-DST      PIC 9(10).
   05 TRX-MONTANT      PIC 9(9)V99.
   05 TRX-STATUT       PIC X.
   05 TRX-MOTIF        PIC X(30).

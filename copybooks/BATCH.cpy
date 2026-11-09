*> BATCH.cpy - suivi et resultat d'un traitement mensuel (une ligne par periode)
*> Cle primaire : BAT-PERIODE (AAAAMM)
*> BAT-ETAT : E en cours (ou interrompu), T termine
01 BATCH-REC.
   05 BAT-PERIODE          PIC 9(6).
   05 BAT-ETAT             PIC X.
      88 BAT-EN-COURS      VALUE "E".
      88 BAT-TERMINE       VALUE "T".
   05 BAT-DATE             PIC 9(8).
   05 BAT-NB-LUS           PIC 9(7).
   05 BAT-NB-ACTIFS        PIC 9(7).
   05 BAT-NB-INTERETS      PIC 9(7).
   05 BAT-TOT-INTERETS     PIC 9(11)V99.
   05 BAT-NB-FRAIS         PIC 9(7).
   05 BAT-TOT-FRAIS        PIC 9(11)V99.
   05 BAT-NB-FRAIS-REFUSES PIC 9(7).
   05 BAT-NB-ANOMALIES     PIC 9(7).
   05 BAT-NB-AGIOS         PIC 9(7).
   05 BAT-TOT-AGIOS        PIC 9(11)V99.

*> ALERTE.cpy - une ligne du journal d'alertes de fraude (ajout seul)
*> ALR-REGLE : PLAFOND_JOUR, MONTANT_ANORMAL, PIN_BLOQUE, ECHECS_RAPIDES
01 ALERTE-REC.
   05 ALR-ID           PIC 9(10).
   05 ALR-DATE         PIC 9(8).
   05 ALR-HEURE        PIC 9(6).
   05 ALR-REGLE        PIC X(16).
   05 ALR-ID-CLIENT    PIC 9(6).
   05 ALR-CPT          PIC 9(10).
   05 ALR-MONTANT      PIC 9(9)V99.
   05 ALR-DETAIL       PIC X(30).

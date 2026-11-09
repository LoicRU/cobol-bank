*> PROGRAMME.cpy - un virement programme
*> Cle primaire : PRG-ID
*> PRG-FREQ    : U une seule fois, M chaque mois (meme jour, ramene a la fin
*>               du mois si le mois est plus court)
*> PRG-STATUT  : A actif, T termine (virement unique fait), X annule par le
*>               client ou l'administrateur, E arrete apres un refus definitif
*> PRG-DATE-PROCHAINE : prochaine echeance (AAAAMMJJ) ; PRG-JOUR : jour du
*>               mois voulu (pour les echeances mensuelles)
*> PRG-DERNIER : statut (COMPTE) de la derniere tentative, "00" si reussie,
*>               espaces si jamais tentee
01 PROG-REC.
   05 PRG-ID             PIC 9(8).
   05 PRG-ID-CLIENT      PIC 9(6).
   05 PRG-CPT-SRC        PIC 9(10).
   05 PRG-CPT-DST        PIC 9(10).
   05 PRG-MONTANT        PIC 9(9)V99.
   05 PRG-DATE-PROCHAINE PIC 9(8).
   05 PRG-JOUR           PIC 99.
   05 PRG-FREQ           PIC X.
      88 PRG-UNIQUE      VALUE "U".
      88 PRG-MENSUEL     VALUE "M".
   05 PRG-STATUT         PIC X.
      88 PRG-ACTIF       VALUE "A".
   05 PRG-NB-EXEC        PIC 9(4).
   05 PRG-DERNIER        PIC XX.

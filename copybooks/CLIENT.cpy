*> CLIENT.cpy - enregistrement d'un client
*> Cle primaire : CLI-ID
*> Le PIN n'est jamais stocke : on garde un sel et une empreinte (voir AUTH.cob)
01 CLIENT-REC.
   05 CLI-ID           PIC 9(6).
   05 CLI-NOM          PIC X(30).
   05 CLI-ROLE         PIC X.
      88 CLI-ROLE-CLIENT VALUE "C".
      88 CLI-ROLE-ADMIN  VALUE "A".
   05 CLI-SEL          PIC 9(9).
   05 CLI-PIN-HASH     PIC 9(18).
   05 CLI-ECHECS       PIC 9(2).
   05 CLI-STATUT       PIC X.
      88 CLI-ACTIF     VALUE "A".
      88 CLI-BLOQUE    VALUE "B".
*> Debut de la serie d'echecs de PIN en cours (date AAAAMMJJ, heure HHMMSS) ;
*> sert a reperer des echecs rapproches. Sans signification si CLI-ECHECS = 0.
   05 CLI-SERIE-DATE  PIC 9(8).
   05 CLI-SERIE-HEURE PIC 9(6).

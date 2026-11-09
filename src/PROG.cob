*> PROG.cob - virements programmes (fichier indexe)
*>
*> Appel : CALL "PROG" USING LK-ACTION LK-PROG-REC LK-DATE LK-NB-OK LK-NB-KO
*>                           LK-STATUS
*>   LK-ACTION :
*>     "N" nouveau programme : entree LK-PRG-ID-CLIENT, CPT-SRC, CPT-DST,
*>         MONTANT, DATE-PROCHAINE, FREQ (U ou M) ; l'identifiant est attribue
*>         et renvoye. LK-DATE = date du jour (AAAAMMJJ).
*>     "S" suivant : LK-PRG-ID = dernier identifiant vu (0 pour commencer),
*>         LK-PRG-ID-CLIENT = client (0 = tous) ; renvoie le programme suivant
*>         dans LK-PROG-REC, statut 10 quand il n'y en a plus.
*>     "A" annuler : LK-PRG-ID, LK-PRG-ID-CLIENT (0 = administrateur, aucun
*>         controle d'appartenance).
*>     "E" executer les echeances : tous les programmes actifs dont la date est
*>         <= LK-DATE ; LK-NB-OK virements faits, LK-NB-KO refuses.
*>   LK-STATUS :
*>     00 ok       10 fin de liste (S)   51 trop de programmes actifs
*>     52 date invalide ou passee        53 frequence invalide
*>     54 programme introuvable          55 programme d'un autre client
*>     56 programme non actif
*>     et les codes de COMPTE : 23 compte introuvable, 74 compte source qui
*>     n'est pas au client, 91 montant nul, 92 compte non actif, 95 meme
*>     compte, 90 virement interdit depuis l'epargne
*>
*> Execution (E) : chaque echeance passe par COMPTE "V", donc les memes
*> controles qu'un virement normal (decouvert, plafond, fraude, epargne) et
*> une ligne d'historique. Apres un succes : un programme unique devient
*> termine, un programme mensuel passe au mois suivant (plusieurs echeances
*> manquees sont rattrapees, 12 au plus par appel). Un refus pour solde
*> insuffisant (93) ou plafond (96) est reessaye a l'appel suivant ; tout
*> autre refus arrete le programme (statut E). Rejouable sans doublon.
*> Fichier : variable d'environnement PROGRAMMES_FILE, sinon
*> data/PROGRAMMES.dat
IDENTIFICATION DIVISION.
PROGRAM-ID. PROG.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-PROG ASSIGN TO DYNAMIC WS-FILENAME
        ORGANIZATION IS INDEXED
        ACCESS MODE IS DYNAMIC
        RECORD KEY IS PRG-ID
        FILE STATUS IS WS-FS.

DATA DIVISION.
FILE SECTION.
FD F-PROG.
COPY "PROGRAMME.cpy".

WORKING-STORAGE SECTION.
COPY "COMPTE.cpy".
COPY "PARAMS.cpy".
01 WS-FS           PIC XX.
01 WS-FILENAME     PIC X(100).
01 WS-PRM-STATUS   PIC XX.
01 WS-FIN          PIC X.
01 WS-TROUVE       PIC X.
01 WS-CMP-ACTION   PIC X.
01 WS-CMP-MONTANT  PIC 9(9)V99.
01 WS-CMP-DST      PIC 9(10).
01 WS-CMP-STATUS   PIC XX.
01 WS-SRC-EPARGNE  PIC X.
01 WS-ID-MAX       PIC 9(8).
01 WS-NB-ACTIFS    PIC 9(5).
01 WS-OCC          PIC 99.
01 WS-STOP         PIC X.
01 WS-VIR-STATUS   PIC XX.
01 WS-D8           PIC 9(8).
01 WS-D8-R REDEFINES WS-D8.
   05 WS-Y         PIC 9(4).
   05 WS-M         PIC 99.
   05 WS-J         PIC 99.
01 WS-NEXT-FIRST   PIC 9(8).
01 WS-NF-R REDEFINES WS-NEXT-FIRST.
   05 WS-NF-Y      PIC 9(4).
   05 WS-NF-M      PIC 99.
   05 WS-NF-J      PIC 99.
01 WS-DERNIER-JOUR PIC 9(8).
01 WS-DJ-R REDEFINES WS-DERNIER-JOUR.
   05 FILLER       PIC 9(6).
   05 WS-DJ        PIC 99.

LINKAGE SECTION.
01 LK-ACTION       PIC X.
COPY "PROGRAMME.cpy" REPLACING LEADING ==PRG-== BY ==LK-PRG-==
                               ==PROG-REC== BY ==LK-PROG-REC==.
01 LK-DATE         PIC 9(8).
01 LK-NB-OK        PIC 9(5).
01 LK-NB-KO        PIC 9(5).
01 LK-STATUS       PIC XX.

PROCEDURE DIVISION USING LK-ACTION LK-PROG-REC LK-DATE LK-NB-OK LK-NB-KO
                         LK-STATUS.
MAIN-PARA.
    MOVE "00" TO LK-STATUS
    MOVE "data/PROGRAMMES.dat" TO WS-FILENAME
    ACCEPT WS-FILENAME FROM ENVIRONMENT "PROGRAMMES_FILE"
        ON EXCEPTION MOVE "data/PROGRAMMES.dat" TO WS-FILENAME
    END-ACCEPT
    OPEN I-O F-PROG
    IF WS-FS = "35"
        OPEN OUTPUT F-PROG
        CLOSE F-PROG
        OPEN I-O F-PROG
    END-IF
    IF WS-FS NOT = "00"
        MOVE WS-FS TO LK-STATUS
        GOBACK
    END-IF
    EVALUATE LK-ACTION
        WHEN "N" PERFORM NOUVEAU-PROGRAMME
        WHEN "S" PERFORM PROGRAMME-SUIVANT
        WHEN "A" PERFORM ANNULER-PROGRAMME
        WHEN "E" PERFORM EXECUTER-ECHEANCES
        WHEN OTHER MOVE "99" TO LK-STATUS
    END-EVALUATE
    CLOSE F-PROG
    GOBACK.

*> ---------------------------------------------------------------
NOUVEAU-PROGRAMME.
    CALL "PARAM" USING PARAMS-REC WS-PRM-STATUS
    IF WS-PRM-STATUS NOT = "00"
        MOVE WS-PRM-STATUS TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    IF LK-PRG-MONTANT = 0
        MOVE "91" TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    IF LK-PRG-FREQ NOT = "U" AND LK-PRG-FREQ NOT = "M"
        MOVE "53" TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    IF FUNCTION TEST-DATE-YYYYMMDD(LK-PRG-DATE-PROCHAINE) NOT = 0
       OR LK-PRG-DATE-PROCHAINE < LK-DATE
        MOVE "52" TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    IF LK-PRG-CPT-SRC = LK-PRG-CPT-DST
        MOVE "95" TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    *> compte source : existe, au client, actif
    INITIALIZE COMPTE-REC
    MOVE LK-PRG-CPT-SRC TO CPT-NUM
    MOVE "L" TO WS-CMP-ACTION
    CALL "COMPTE" USING WS-CMP-ACTION COMPTE-REC WS-CMP-MONTANT
                        WS-CMP-DST WS-CMP-STATUS
    IF WS-CMP-STATUS NOT = "00"
        MOVE WS-CMP-STATUS TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    IF CPT-ID-CLIENT NOT = LK-PRG-ID-CLIENT
        MOVE "74" TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    IF NOT CPT-ACTIF
        MOVE "92" TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    MOVE "N" TO WS-SRC-EPARGNE
    IF CPT-EPARGNE
        MOVE "O" TO WS-SRC-EPARGNE
    END-IF
    *> compte destination : existe et actif ; regle de l'epargne
    INITIALIZE COMPTE-REC
    MOVE LK-PRG-CPT-DST TO CPT-NUM
    CALL "COMPTE" USING WS-CMP-ACTION COMPTE-REC WS-CMP-MONTANT
                        WS-CMP-DST WS-CMP-STATUS
    IF WS-CMP-STATUS NOT = "00"
        MOVE WS-CMP-STATUS TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    IF NOT CPT-ACTIF
        MOVE "92" TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    IF WS-SRC-EPARGNE = "O"
       AND (CPT-EPARGNE OR CPT-ID-CLIENT NOT = LK-PRG-ID-CLIENT)
        MOVE "90" TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    PERFORM COMPTER-PROGRAMMES
    IF LK-STATUS NOT = "00"
        EXIT PARAGRAPH
    END-IF
    IF WS-NB-ACTIFS >= PRM-MAX-PROGRAMMES
        MOVE "51" TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    INITIALIZE PROG-REC
    COMPUTE PRG-ID = WS-ID-MAX + 1
    MOVE LK-PRG-ID-CLIENT TO PRG-ID-CLIENT
    MOVE LK-PRG-CPT-SRC TO PRG-CPT-SRC
    MOVE LK-PRG-CPT-DST TO PRG-CPT-DST
    MOVE LK-PRG-MONTANT TO PRG-MONTANT
    MOVE LK-PRG-DATE-PROCHAINE TO PRG-DATE-PROCHAINE
    MOVE LK-PRG-DATE-PROCHAINE TO WS-D8
    MOVE WS-J TO PRG-JOUR
    MOVE LK-PRG-FREQ TO PRG-FREQ
    MOVE "A" TO PRG-STATUT
    MOVE 0 TO PRG-NB-EXEC
    MOVE SPACES TO PRG-DERNIER
    WRITE PROG-REC
    MOVE WS-FS TO LK-STATUS
    IF WS-FS = "00"
        MOVE PROG-REC TO LK-PROG-REC
    END-IF.

*> Plus grand identifiant (WS-ID-MAX) et nombre de programmes actifs du
*> client (WS-NB-ACTIFS)
COMPTER-PROGRAMMES.
    MOVE 0 TO WS-ID-MAX WS-NB-ACTIFS
    MOVE LOW-VALUES TO PRG-ID
    START F-PROG KEY IS >= PRG-ID
    IF WS-FS = "00"
        MOVE "N" TO WS-FIN
        PERFORM UNTIL WS-FIN = "O"
            READ F-PROG NEXT RECORD
                AT END
                    MOVE "O" TO WS-FIN
                NOT AT END
                    IF PRG-ID > WS-ID-MAX
                        MOVE PRG-ID TO WS-ID-MAX
                    END-IF
                    IF PRG-ID-CLIENT = LK-PRG-ID-CLIENT AND PRG-ACTIF
                        ADD 1 TO WS-NB-ACTIFS
                    END-IF
            END-READ
        END-PERFORM
        MOVE "00" TO LK-STATUS
    ELSE
        IF WS-FS = "23"
            MOVE "00" TO LK-STATUS
        ELSE
            MOVE WS-FS TO LK-STATUS
        END-IF
    END-IF.

*> ---------------------------------------------------------------
PROGRAMME-SUIVANT.
    MOVE LK-PRG-ID TO PRG-ID
    START F-PROG KEY IS > PRG-ID
    IF WS-FS NOT = "00"
        IF WS-FS = "23"
            MOVE "10" TO LK-STATUS
        ELSE
            MOVE WS-FS TO LK-STATUS
        END-IF
        EXIT PARAGRAPH
    END-IF
    MOVE "10" TO LK-STATUS
    MOVE "N" TO WS-TROUVE
    PERFORM UNTIL WS-TROUVE = "O"
        READ F-PROG NEXT RECORD
            AT END
                MOVE "O" TO WS-TROUVE
            NOT AT END
                IF LK-PRG-ID-CLIENT = 0
                   OR PRG-ID-CLIENT = LK-PRG-ID-CLIENT
                    MOVE PROG-REC TO LK-PROG-REC
                    MOVE "00" TO LK-STATUS
                    MOVE "O" TO WS-TROUVE
                END-IF
        END-READ
    END-PERFORM.

*> ---------------------------------------------------------------
ANNULER-PROGRAMME.
    MOVE LK-PRG-ID TO PRG-ID
    READ F-PROG KEY IS PRG-ID
    IF WS-FS = "23"
        MOVE "54" TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    IF WS-FS NOT = "00"
        MOVE WS-FS TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    IF LK-PRG-ID-CLIENT NOT = 0 AND PRG-ID-CLIENT NOT = LK-PRG-ID-CLIENT
        MOVE "55" TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    IF NOT PRG-ACTIF
        MOVE "56" TO LK-STATUS
        EXIT PARAGRAPH
    END-IF
    MOVE "X" TO PRG-STATUT
    REWRITE PROG-REC
    MOVE WS-FS TO LK-STATUS.

*> ---------------------------------------------------------------
EXECUTER-ECHEANCES.
    MOVE 0 TO LK-NB-OK LK-NB-KO
    MOVE LOW-VALUES TO PRG-ID
    START F-PROG KEY IS >= PRG-ID
    IF WS-FS NOT = "00"
        IF WS-FS NOT = "23"
            MOVE WS-FS TO LK-STATUS
        END-IF
        EXIT PARAGRAPH
    END-IF
    MOVE "N" TO WS-FIN
    PERFORM UNTIL WS-FIN = "O" OR LK-STATUS NOT = "00"
        READ F-PROG NEXT RECORD
            AT END
                MOVE "O" TO WS-FIN
            NOT AT END
                IF PRG-ACTIF AND PRG-DATE-PROCHAINE <= LK-DATE
                    PERFORM TRAITER-PROGRAMME
                END-IF
        END-READ
    END-PERFORM.

TRAITER-PROGRAMME.
    MOVE 0 TO WS-OCC
    MOVE "N" TO WS-STOP
    PERFORM UNTIL WS-STOP = "O" OR NOT PRG-ACTIF
                  OR PRG-DATE-PROCHAINE > LK-DATE OR WS-OCC >= 12
        ADD 1 TO WS-OCC
        PERFORM VIREMENT-DU-PROGRAMME
        MOVE WS-VIR-STATUS TO PRG-DERNIER
        EVALUATE WS-VIR-STATUS
            WHEN "00"
            WHEN "98"
                ADD 1 TO LK-NB-OK
                ADD 1 TO PRG-NB-EXEC
                IF PRG-UNIQUE
                    MOVE "T" TO PRG-STATUT
                ELSE
                    PERFORM AVANCER-ECHEANCE
                END-IF
            WHEN "93"
            WHEN "96"
                ADD 1 TO LK-NB-KO
                MOVE "O" TO WS-STOP
            WHEN OTHER
                ADD 1 TO LK-NB-KO
                MOVE "E" TO PRG-STATUT
                MOVE "O" TO WS-STOP
        END-EVALUATE
    END-PERFORM
    REWRITE PROG-REC
    IF WS-FS NOT = "00"
        MOVE WS-FS TO LK-STATUS
    END-IF.

*> Execute le virement du programme courant ; resultat dans WS-VIR-STATUS
VIREMENT-DU-PROGRAMME.
    INITIALIZE COMPTE-REC
    MOVE PRG-CPT-SRC TO CPT-NUM
    MOVE "L" TO WS-CMP-ACTION
    CALL "COMPTE" USING WS-CMP-ACTION COMPTE-REC WS-CMP-MONTANT
                        WS-CMP-DST WS-VIR-STATUS
    IF WS-VIR-STATUS = "00" AND CPT-ID-CLIENT NOT = PRG-ID-CLIENT
        MOVE "74" TO WS-VIR-STATUS
    END-IF
    IF WS-VIR-STATUS = "00"
        MOVE PRG-MONTANT TO WS-CMP-MONTANT
        MOVE PRG-CPT-DST TO WS-CMP-DST
        MOVE "V" TO WS-CMP-ACTION
        CALL "COMPTE" USING WS-CMP-ACTION COMPTE-REC WS-CMP-MONTANT
                            WS-CMP-DST WS-VIR-STATUS
    END-IF.

*> Echeance mensuelle suivante : meme jour (PRG-JOUR), ramene au dernier jour
*> du mois s'il est plus court ; au-dela de l'annee 9998 le programme s'arrete
AVANCER-ECHEANCE.
    MOVE PRG-DATE-PROCHAINE TO WS-D8
    IF WS-M = 12
        ADD 1 TO WS-Y
        MOVE 1 TO WS-M
    ELSE
        ADD 1 TO WS-M
    END-IF
    IF WS-Y > 9998
        MOVE "T" TO PRG-STATUT
        EXIT PARAGRAPH
    END-IF
    *> dernier jour de ce mois = veille du 1er du mois suivant
    MOVE WS-D8 TO WS-NEXT-FIRST
    MOVE 1 TO WS-NF-J
    IF WS-NF-M = 12
        ADD 1 TO WS-NF-Y
        MOVE 1 TO WS-NF-M
    ELSE
        ADD 1 TO WS-NF-M
    END-IF
    COMPUTE WS-DERNIER-JOUR = FUNCTION DATE-OF-INTEGER(
        FUNCTION INTEGER-OF-DATE(WS-NEXT-FIRST) - 1)
    IF PRG-JOUR > WS-DJ
        MOVE WS-DJ TO WS-J
    ELSE
        MOVE PRG-JOUR TO WS-J
    END-IF
    MOVE WS-D8 TO PRG-DATE-PROCHAINE.

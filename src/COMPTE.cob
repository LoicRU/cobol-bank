*> COMPTE.cob - acces au fichier indexe des comptes + depot / retrait
*>
*> Appel : CALL "COMPTE" USING LK-ACTION LK-COMPTE-REC LK-MONTANT LK-STATUS
*>   LK-ACTION : "C" creer, "L" lire (par LK-CPT-NUM), "U" mettre a jour,
*>               "D" depot, "R" retrait (compte LK-CPT-NUM, montant LK-MONTANT)
*>   LK-MONTANT : utilise seulement par D et R
*>   LK-STATUS :
*>     00 ok                      22 cle deja existante
*>     23 compte introuvable      99 action inconnue
*>     91 montant invalide (0)    92 compte non actif
*>     93 solde insuffisant       94 depassement de capacite du solde
*>     98 operation faite mais ligne d'historique non ecrite
*>     autre : FILE STATUS d'une erreur d'entree/sortie
*> D et R ecrivent une ligne d'historique (acceptee ou refusee) via TRX.
*> Fichier : variable d'environnement COMPTES_FILE, sinon data/COMPTES.dat
IDENTIFICATION DIVISION.
PROGRAM-ID. COMPTE.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-COMPTES ASSIGN TO DYNAMIC WS-FILENAME
        ORGANIZATION IS INDEXED
        ACCESS MODE IS DYNAMIC
        RECORD KEY IS CPT-NUM
        FILE STATUS IS WS-FS.

DATA DIVISION.
FILE SECTION.
FD F-COMPTES.
COPY "COMPTE.cpy".

WORKING-STORAGE SECTION.
01 WS-FS          PIC XX.
01 WS-FILENAME    PIC X(100).
01 WS-MOTIF       PIC X(30).
01 WS-LU          PIC X.
01 WS-TRX-STATUS  PIC XX.
COPY "TRX.cpy".

LINKAGE SECTION.
01 LK-ACTION      PIC X.
COPY "COMPTE.cpy" REPLACING LEADING ==CPT-== BY ==LK-CPT-==
                            ==COMPTE-REC== BY ==LK-COMPTE-REC==.
01 LK-MONTANT     PIC 9(9)V99.
01 LK-STATUS      PIC XX.

PROCEDURE DIVISION USING LK-ACTION LK-COMPTE-REC LK-MONTANT LK-STATUS.
MAIN-PARA.
    MOVE "data/COMPTES.dat" TO WS-FILENAME
    ACCEPT WS-FILENAME FROM ENVIRONMENT "COMPTES_FILE"
        ON EXCEPTION MOVE "data/COMPTES.dat" TO WS-FILENAME
    END-ACCEPT

    PERFORM OUVRIR-FICHIER
    IF WS-FS NOT = "00"
        MOVE WS-FS TO LK-STATUS
        GOBACK
    END-IF

    EVALUATE LK-ACTION
        WHEN "C" PERFORM CREER-COMPTE
        WHEN "L" PERFORM LIRE-COMPTE
        WHEN "U" PERFORM MAJ-COMPTE
        WHEN "D" PERFORM OPERATION
        WHEN "R" PERFORM OPERATION
        WHEN OTHER MOVE "99" TO LK-STATUS
    END-EVALUATE

    CLOSE F-COMPTES
    GOBACK.

OUVRIR-FICHIER.
    OPEN I-O F-COMPTES
    IF WS-FS = "35"
        *> fichier absent : on le cree vide puis on le rouvre
        OPEN OUTPUT F-COMPTES
        CLOSE F-COMPTES
        OPEN I-O F-COMPTES
    END-IF.

CREER-COMPTE.
    MOVE LK-COMPTE-REC TO COMPTE-REC
    WRITE COMPTE-REC
    MOVE WS-FS TO LK-STATUS.

LIRE-COMPTE.
    MOVE LK-CPT-NUM TO CPT-NUM
    READ F-COMPTES KEY IS CPT-NUM
    IF WS-FS = "00"
        MOVE COMPTE-REC TO LK-COMPTE-REC
    END-IF
    MOVE WS-FS TO LK-STATUS.

MAJ-COMPTE.
    MOVE LK-CPT-NUM TO CPT-NUM
    READ F-COMPTES KEY IS CPT-NUM
    IF WS-FS = "00"
        MOVE LK-COMPTE-REC TO COMPTE-REC
        REWRITE COMPTE-REC
    END-IF
    MOVE WS-FS TO LK-STATUS.

*> Depot (D) ou retrait (R) : controles, mise a jour du solde, historique
OPERATION.
    MOVE "00" TO LK-STATUS
    MOVE SPACES TO WS-MOTIF
    MOVE "N" TO WS-LU
    MOVE LK-CPT-NUM TO CPT-NUM
    READ F-COMPTES KEY IS CPT-NUM
    IF WS-FS = "00"
        MOVE "O" TO WS-LU
    END-IF

    EVALUATE TRUE
        WHEN WS-LU NOT = "O"
            MOVE WS-FS TO LK-STATUS
            MOVE "COMPTE INTROUVABLE" TO WS-MOTIF
        WHEN LK-MONTANT = 0
            MOVE "91" TO LK-STATUS
            MOVE "MONTANT INVALIDE" TO WS-MOTIF
        WHEN NOT CPT-ACTIF
            MOVE "92" TO LK-STATUS
            MOVE "COMPTE NON ACTIF" TO WS-MOTIF
        WHEN LK-ACTION = "R" AND CPT-SOLDE < LK-MONTANT
            MOVE "93" TO LK-STATUS
            MOVE "SOLDE INSUFFISANT" TO WS-MOTIF
    END-EVALUATE

    IF LK-STATUS = "00"
        IF LK-ACTION = "D"
            ADD LK-MONTANT TO CPT-SOLDE
                ON SIZE ERROR
                    MOVE "94" TO LK-STATUS
                    MOVE "DEPASSEMENT DE CAPACITE" TO WS-MOTIF
            END-ADD
        ELSE
            SUBTRACT LK-MONTANT FROM CPT-SOLDE
        END-IF
    END-IF

    IF LK-STATUS = "00"
        REWRITE COMPTE-REC
        MOVE WS-FS TO LK-STATUS
    END-IF

    IF WS-LU = "O"
        MOVE COMPTE-REC TO LK-COMPTE-REC
    END-IF

    PERFORM JOURNALISER.

JOURNALISER.
    INITIALIZE TRX-REC
    MOVE LK-ACTION TO TRX-TYPE
    IF LK-ACTION = "D"
        MOVE LK-CPT-NUM TO TRX-CPT-DST
    ELSE
        MOVE LK-CPT-NUM TO TRX-CPT-SRC
    END-IF
    MOVE LK-MONTANT TO TRX-MONTANT
    IF LK-STATUS = "00"
        MOVE "A" TO TRX-STATUT
    ELSE
        MOVE "R" TO TRX-STATUT
        IF WS-MOTIF = SPACES
            MOVE "ERREUR FICHIER" TO WS-MOTIF
        END-IF
    END-IF
    MOVE WS-MOTIF TO TRX-MOTIF
    CALL "TRX" USING TRX-REC WS-TRX-STATUS
    IF WS-TRX-STATUS NOT = "00" AND LK-STATUS = "00"
        MOVE "98" TO LK-STATUS
    END-IF.

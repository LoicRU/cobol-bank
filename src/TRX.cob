*> TRX.cob - ajout d'une ligne a l'historique (fichier en ajout seul)
*>
*> Appel : CALL "TRX" USING LK-TRX-REC LK-STATUS
*>   L'appelant renseigne type, comptes, montant, statut, motif.
*>   TRX.cob attribue l'id (dernier id + 1), la date et l'heure,
*>   puis renvoie l'enregistrement complete dans LK-TRX-REC.
*>   Le dernier id est garde en memoire apres une lecture complete du fichier.
*>   Il est relu si la taille du fichier a change depuis notre derniere
*>   ecriture (fichier modifie, remplace ou supprime) : la numerotation
*>   reste donc juste, et le cout d'une ecriture ne depend plus de la taille
*>   de l'historique. Pas d'acces concurrent en V1.
*>   LK-STATUS : FILE STATUS ("00" = ligne ecrite)
*> Fichier : variable d'environnement TRX_FILE, sinon data/TRANSACTIONS.dat
IDENTIFICATION DIVISION.
PROGRAM-ID. TRX.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-TRX ASSIGN TO DYNAMIC WS-FILENAME
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS.

DATA DIVISION.
FILE SECTION.
FD F-TRX.
COPY "TRX.cpy".

WORKING-STORAGE SECTION.
01 WS-FS          PIC XX.
01 WS-FILENAME    PIC X(100).
01 WS-DERNIER-ID  PIC 9(10) VALUE 0.
01 WS-CACHE-NOM   PIC X(100) VALUE SPACES.
01 WS-CACHE-OK    PIC X VALUE "N".
01 WS-CACHE-TAILLE PIC 9(18) VALUE 0.
01 WS-TAILLE      PIC 9(18).
01 WS-DETAILS.
   05 WS-DET-TAILLE   PIC X(8) COMP-X.
   05 WS-DET-JOUR     PIC X COMP-X.
   05 WS-DET-MOIS     PIC X COMP-X.
   05 WS-DET-ANNEE    PIC X(2) COMP-X.
   05 WS-DET-HEURES   PIC X COMP-X.
   05 WS-DET-MINUTES  PIC X COMP-X.
   05 WS-DET-SECONDES PIC X COMP-X.
   05 WS-DET-CENTIEMES PIC X COMP-X.
01 WS-FIN         PIC X.
01 WS-DATE        PIC 9(8).
01 WS-TIME        PIC 9(8).

LINKAGE SECTION.
COPY "TRX.cpy" REPLACING LEADING ==TRX-== BY ==LK-TRX-==.
01 LK-STATUS      PIC XX.

PROCEDURE DIVISION USING LK-TRX-REC LK-STATUS.
MAIN-PARA.
    MOVE "data/TRANSACTIONS.dat" TO WS-FILENAME
    ACCEPT WS-FILENAME FROM ENVIRONMENT "TRX_FILE"
        ON EXCEPTION MOVE "data/TRANSACTIONS.dat" TO WS-FILENAME
    END-ACCEPT

    MOVE "00" TO LK-STATUS
    IF WS-CACHE-OK = "O" AND WS-FILENAME = WS-CACHE-NOM
        PERFORM LIRE-TAILLE
        IF WS-TAILLE NOT = WS-CACHE-TAILLE
            MOVE "N" TO WS-CACHE-OK
        END-IF
    END-IF
    IF WS-CACHE-OK NOT = "O" OR WS-FILENAME NOT = WS-CACHE-NOM
        PERFORM TROUVER-DERNIER-ID
        IF LK-STATUS NOT = "00"
            MOVE "N" TO WS-CACHE-OK
            GOBACK
        END-IF
    END-IF

    OPEN EXTEND F-TRX
    IF WS-FS = "35"
        *> fichier absent : OPEN OUTPUT le cree, la numerotation repart de 1
        OPEN OUTPUT F-TRX
        MOVE 0 TO WS-DERNIER-ID
    END-IF
    IF WS-FS NOT = "00" AND WS-FS NOT = "05"
        MOVE WS-FS TO LK-STATUS
        MOVE "N" TO WS-CACHE-OK
        GOBACK
    END-IF

    MOVE LK-TRX-REC TO TRX-REC
    ADD 1 TO WS-DERNIER-ID GIVING TRX-ID
    ACCEPT WS-DATE FROM DATE YYYYMMDD
    ACCEPT WS-TIME FROM TIME
    MOVE WS-DATE TO TRX-DATE
    MOVE WS-TIME(1:6) TO TRX-HEURE

    WRITE TRX-REC
    MOVE WS-FS TO LK-STATUS
    CLOSE F-TRX
    IF LK-STATUS = "00"
        MOVE TRX-ID TO WS-DERNIER-ID
        MOVE WS-FILENAME TO WS-CACHE-NOM
        PERFORM LIRE-TAILLE
        MOVE WS-TAILLE TO WS-CACHE-TAILLE
        MOVE "O" TO WS-CACHE-OK
        MOVE TRX-REC TO LK-TRX-REC
    ELSE
        MOVE "N" TO WS-CACHE-OK
    END-IF
    GOBACK.

*> Taille du fichier en octets (0 s'il n'existe pas)
LIRE-TAILLE.
    MOVE 0 TO WS-TAILLE
    CALL "CBL_CHECK_FILE_EXIST" USING WS-FILENAME WS-DETAILS
    IF RETURN-CODE = 0
        MOVE WS-DET-TAILLE TO WS-TAILLE
    END-IF
    MOVE 0 TO RETURN-CODE.

TROUVER-DERNIER-ID.
    MOVE "00" TO LK-STATUS
    MOVE 0 TO WS-DERNIER-ID
    MOVE "N" TO WS-FIN
    OPEN INPUT F-TRX
    EVALUATE WS-FS
        WHEN "00"
            PERFORM UNTIL WS-FIN = "O"
                READ F-TRX
                    AT END MOVE "O" TO WS-FIN
                    NOT AT END MOVE TRX-ID TO WS-DERNIER-ID
                END-READ
            END-PERFORM
            CLOSE F-TRX
        WHEN "35"
            CONTINUE
        WHEN OTHER
            MOVE WS-FS TO LK-STATUS
    END-EVALUATE.

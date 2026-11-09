*> test_epargne.cob - traitement mensuel : comptes epargne et decouvert
*> Fichiers temporaires dans tests/. Periode 202701, taux courant 1.50 %,
*> taux epargne 3.00 %, frais 2.00, agios 12.00 % (valeur par defaut).
*>   1 courant  1000.00             -> +1.25 -2.00 = 999.25
*>   2 epargne  1000.00             -> +2.50, aucun frais = 1002.50
*>   3 courant  -100.00 (decouv 200) -> pas d'interets, frais -102.00,
*>                                       agios 1.00 = -103.00
*>   4 courant  -199.00 (decouv 200) -> frais refuses (-201 < -200),
*>                                       agios 1.99 = -200.99 (au-dela du decouvert)
*>   5 courant  -100.00 (decouv 0)   -> frais refuses, agios 1.00 = -101.00
*>   6 epargne     0.00             -> rien
IDENTIFICATION DIVISION.
PROGRAM-ID. TEST-EPARGNE.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-TRX ASSIGN TO "tests/TRX_EPG_TEST.dat"
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS-TRX.

DATA DIVISION.
FILE SECTION.
FD F-TRX.
COPY "TRX.cpy" REPLACING LEADING ==TRX-== BY ==FT-==.

WORKING-STORAGE SECTION.
COPY "COMPTE.cpy".
COPY "BATCH.cpy" REPLACING LEADING ==BAT-== BY ==RS-==
                           ==BATCH-REC== BY ==RS-REC==.
01 WS-ACTION       PIC X.
01 WS-STATUS       PIC XX.
01 WS-LIBELLE      PIC X(44).
01 WS-NB-ECHECS    PIC 9(3) VALUE 0.
01 WS-MONTANT      PIC 9(9)V99 VALUE 0.
01 WS-DST          PIC 9(10) VALUE 0.
01 WS-PERIODE      PIC 9(6).
01 WS-NUM          PIC 9(10).
01 WS-SOLDE-ATT    PIC S9(9)V99.
01 WS-AFF          PIC -(9)9.99.
01 WS-FS-TRX       PIC XX.
01 WS-FIN          PIC X.
01 WS-NB-TRX       PIC 9(5).
01 WS-NB-F-A       PIC 9(5).
01 WS-NB-F-R       PIC 9(5).
01 WS-NB-I-A       PIC 9(5).
01 WS-NB-EPG       PIC 9(5).
01 WS-SOLDE-F3     PIC S9(9)V99.
01 WS-NB-A-A       PIC 9(5).
01 WS-SOLDE-A3     PIC S9(9)V99.

PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY "PARAMS_FILE" UPON ENVIRONMENT-NAME
    DISPLAY "tests/AUCUN_PARAMS.cfg" UPON ENVIRONMENT-VALUE
    CALL "CBL_DELETE_FILE" USING "tests/COMPTES_EPG_TEST.dat"
    CALL "CBL_DELETE_FILE" USING "tests/TRX_EPG_TEST.dat"
    CALL "CBL_DELETE_FILE" USING "tests/BATCH_EPG_TEST.dat"
    CALL "CBL_DELETE_FILE" USING "tests/BATCH_202701.txt"
    DISPLAY "COMPTES_FILE" UPON ENVIRONMENT-NAME
    DISPLAY "tests/COMPTES_EPG_TEST.dat" UPON ENVIRONMENT-VALUE
    DISPLAY "TRX_FILE" UPON ENVIRONMENT-NAME
    DISPLAY "tests/TRX_EPG_TEST.dat" UPON ENVIRONMENT-VALUE
    DISPLAY "BATCH_FILE" UPON ENVIRONMENT-NAME
    DISPLAY "tests/BATCH_EPG_TEST.dat" UPON ENVIRONMENT-VALUE
    DISPLAY "BATCH_REPORT_DIR" UPON ENVIRONMENT-NAME
    DISPLAY "tests" UPON ENVIRONMENT-VALUE

    MOVE 1 TO CPT-NUM
    MOVE 1000.00 TO CPT-SOLDE
    MOVE "C" TO CPT-TYPE
    MOVE 0 TO CPT-DECOUVERT
    PERFORM CREER-COMPTE
    MOVE 2 TO CPT-NUM
    MOVE "E" TO CPT-TYPE
    PERFORM CREER-COMPTE
    MOVE 3 TO CPT-NUM
    MOVE -100.00 TO CPT-SOLDE
    MOVE "C" TO CPT-TYPE
    MOVE 200.00 TO CPT-DECOUVERT
    PERFORM CREER-COMPTE
    MOVE 4 TO CPT-NUM
    MOVE -199.00 TO CPT-SOLDE
    PERFORM CREER-COMPTE
    MOVE 5 TO CPT-NUM
    MOVE -100.00 TO CPT-SOLDE
    MOVE 0 TO CPT-DECOUVERT
    PERFORM CREER-COMPTE
    MOVE 6 TO CPT-NUM
    MOVE 0 TO CPT-SOLDE
    MOVE "E" TO CPT-TYPE
    PERFORM CREER-COMPTE

    MOVE 202701 TO WS-PERIODE
    INITIALIZE RS-REC
    CALL "BATCH-INT" USING WS-PERIODE RS-REC WS-STATUS
    MOVE "traitement de la periode 202701" TO WS-LIBELLE
    IF WS-STATUS = "00"
        DISPLAY "PASS " WS-LIBELLE
    ELSE
        DISPLAY "FAIL " WS-LIBELLE " (statut " WS-STATUS ")"
        ADD 1 TO WS-NB-ECHECS
    END-IF

    MOVE 1 TO WS-NUM
    MOVE 999.25 TO WS-SOLDE-ATT
    MOVE "courant : interets 1.50 % et frais" TO WS-LIBELLE
    PERFORM VERIF-SOLDE
    MOVE 2 TO WS-NUM
    MOVE 1002.50 TO WS-SOLDE-ATT
    MOVE "epargne : interets 3.00 %, aucun frais" TO WS-LIBELLE
    PERFORM VERIF-SOLDE
    MOVE 3 TO WS-NUM
    MOVE -103.00 TO WS-SOLDE-ATT
    MOVE "solde negatif : frais, agios, pas d'interets" TO WS-LIBELLE
    PERFORM VERIF-SOLDE
    MOVE 4 TO WS-NUM
    MOVE -200.99 TO WS-SOLDE-ATT
    MOVE "frais refuses, agios au-dela du decouvert" TO WS-LIBELLE
    PERFORM VERIF-SOLDE
    MOVE 5 TO WS-NUM
    MOVE -101.00 TO WS-SOLDE-ATT
    MOVE "frais refuses, agios sans decouvert" TO WS-LIBELLE
    PERFORM VERIF-SOLDE
    MOVE 6 TO WS-NUM
    MOVE 0 TO WS-SOLDE-ATT
    MOVE "epargne vide : inchange" TO WS-LIBELLE
    PERFORM VERIF-SOLDE

    PERFORM LIRE-HISTORIQUE
    MOVE "historique : 9 lignes" TO WS-LIBELLE
    IF WS-NB-TRX = 9
        DISPLAY "PASS " WS-LIBELLE
    ELSE
        DISPLAY "FAIL " WS-LIBELLE " (" WS-NB-TRX ")"
        ADD 1 TO WS-NB-ECHECS
    END-IF
    MOVE "historique : 2 interets, 2 frais, 2 frais refuses"
        TO WS-LIBELLE
    IF WS-NB-I-A = 2 AND WS-NB-F-A = 2 AND WS-NB-F-R = 2
        DISPLAY "PASS " WS-LIBELLE
    ELSE
        DISPLAY "FAIL " WS-LIBELLE " (" WS-NB-I-A "/" WS-NB-F-A "/"
                WS-NB-F-R ")"
        ADD 1 TO WS-NB-ECHECS
    END-IF
    MOVE "historique : 3 agios (comptes 3, 4, 5), solde apres -103.00"
        TO WS-LIBELLE
    IF WS-NB-A-A = 3 AND WS-SOLDE-A3 = -103.00
        DISPLAY "PASS " WS-LIBELLE
    ELSE
        DISPLAY "FAIL " WS-LIBELLE " (" WS-NB-A-A ")"
        ADD 1 TO WS-NB-ECHECS
    END-IF
    MOVE "historique : aucune ligne de frais sur l'epargne" TO WS-LIBELLE
    IF WS-NB-EPG = 0
        DISPLAY "PASS " WS-LIBELLE
    ELSE
        DISPLAY "FAIL " WS-LIBELLE " (" WS-NB-EPG ")"
        ADD 1 TO WS-NB-ECHECS
    END-IF
    MOVE "historique : solde negatif conserve (-102.00)" TO WS-LIBELLE
    IF WS-SOLDE-F3 = -102.00
        DISPLAY "PASS " WS-LIBELLE
    ELSE
        MOVE WS-SOLDE-F3 TO WS-AFF
        DISPLAY "FAIL " WS-LIBELLE " (" WS-AFF ")"
        ADD 1 TO WS-NB-ECHECS
    END-IF

    CALL "CBL_DELETE_FILE" USING "tests/COMPTES_EPG_TEST.dat"
    CALL "CBL_DELETE_FILE" USING "tests/TRX_EPG_TEST.dat"
    CALL "CBL_DELETE_FILE" USING "tests/BATCH_EPG_TEST.dat"
    CALL "CBL_DELETE_FILE" USING "tests/BATCH_202701.txt"
    IF WS-NB-ECHECS = 0
        DISPLAY "TOUS LES TESTS PASSENT"
        MOVE 0 TO RETURN-CODE
    ELSE
        DISPLAY WS-NB-ECHECS " TEST(S) EN ECHEC"
        MOVE 1 TO RETURN-CODE
    END-IF
    STOP RUN.

CREER-COMPTE.
    MOVE 100 TO CPT-ID-CLIENT
    MOVE 0 TO CPT-PLAFOND
    MOVE "A" TO CPT-STATUT
    MOVE "C" TO WS-ACTION
    CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST WS-STATUS.

VERIF-SOLDE.
    INITIALIZE COMPTE-REC
    MOVE WS-NUM TO CPT-NUM
    MOVE "L" TO WS-ACTION
    CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST WS-STATUS
    IF WS-STATUS = "00" AND CPT-SOLDE = WS-SOLDE-ATT
        DISPLAY "PASS " WS-LIBELLE
    ELSE
        MOVE CPT-SOLDE TO WS-AFF
        DISPLAY "FAIL " WS-LIBELLE " (solde " WS-AFF ")"
        ADD 1 TO WS-NB-ECHECS
    END-IF.

LIRE-HISTORIQUE.
    MOVE 0 TO WS-NB-TRX WS-NB-F-A WS-NB-F-R WS-NB-I-A WS-NB-EPG
              WS-NB-A-A
    MOVE "N" TO WS-FIN
    OPEN INPUT F-TRX
    IF WS-FS-TRX = "00"
        PERFORM UNTIL WS-FIN = "O"
            READ F-TRX
                AT END MOVE "O" TO WS-FIN
                NOT AT END
                    ADD 1 TO WS-NB-TRX
                    IF FT-TYPE = "I" AND FT-STATUT = "A"
                        ADD 1 TO WS-NB-I-A
                    END-IF
                    IF FT-TYPE = "A" AND FT-STATUT = "A"
                        ADD 1 TO WS-NB-A-A
                    END-IF
                    IF FT-TYPE = "A" AND FT-CPT-SRC = 3
                        MOVE FT-SOLDE-SRC TO WS-SOLDE-A3
                    END-IF
                    IF FT-TYPE = "F" AND FT-STATUT = "A"
                        ADD 1 TO WS-NB-F-A
                    END-IF
                    IF FT-TYPE = "F" AND FT-STATUT = "R"
                        ADD 1 TO WS-NB-F-R
                    END-IF
                    IF FT-CPT-SRC = 2 OR FT-CPT-SRC = 6
                       OR (FT-TYPE = "F" AND FT-CPT-DST = 2)
                        ADD 1 TO WS-NB-EPG
                    END-IF
                    IF FT-TYPE = "F" AND FT-CPT-SRC = 3
                        MOVE FT-SOLDE-SRC TO WS-SOLDE-F3
                    END-IF
            END-READ
        END-PERFORM
        CLOSE F-TRX
    END-IF.

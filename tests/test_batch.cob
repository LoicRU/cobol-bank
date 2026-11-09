*> test_batch.cob - tests du traitement mensuel BATCH-INT
*> Fichiers temporaires dans tests/, jamais ceux de data/ ou reports/
*>
*> Jeu de donnees (periode 202611, taux 1.50 %, frais 2.00) :
*>   1 actif   1000.00      -> +1.25 -2.00 = 999.25
*>   2 actif    100.00      -> +0.13 (0.125 arrondi) -2.00 = 98.13
*>   3 actif      1.50      -> interets 0.00, frais refuses (solde < 2.00)
*>   4 gele     500.00      -> ignore
*>   5 clos     300.00      -> ignore
*>   6 actif      0.00      -> frais refuses
*>   7 actif 999999999.00   -> interets refuses (depassement), frais 2.00
IDENTIFICATION DIVISION.
PROGRAM-ID. TEST-BATCH.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-CPT ASSIGN TO "tests/COMPTES_BATCH_TEST.dat"
        ORGANIZATION IS INDEXED
        ACCESS MODE IS SEQUENTIAL
        RECORD KEY IS FC-NUM
        FILE STATUS IS WS-FS-CPT.
    SELECT F-TRX ASSIGN TO "tests/TRX_BATCH_TEST.dat"
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS-TRX.
    SELECT F-BAT ASSIGN TO "tests/BATCH_TEST.dat"
        ORGANIZATION IS INDEXED
        ACCESS MODE IS RANDOM
        RECORD KEY IS FB-PERIODE
        FILE STATUS IS WS-FS-BAT.
    SELECT F-RAP ASSIGN TO "tests/BATCH_202611.txt"
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS-RAP.

DATA DIVISION.
FILE SECTION.
FD F-CPT.
COPY "COMPTE.cpy" REPLACING LEADING ==CPT-== BY ==FC-==
                            ==COMPTE-REC== BY ==FC-REC==.
FD F-TRX.
COPY "TRX.cpy" REPLACING LEADING ==TRX-== BY ==FT-==.
FD F-BAT.
COPY "BATCH.cpy" REPLACING LEADING ==BAT-== BY ==FB-==
                           ==BATCH-REC== BY ==FB-REC==.
FD F-RAP.
01 FR-LIGNE        PIC X(80).

WORKING-STORAGE SECTION.
COPY "COMPTE.cpy".
COPY "BATCH.cpy" REPLACING LEADING ==BAT-== BY ==RS-==
                           ==BATCH-REC== BY ==RS-REC==.
01 WS-ACTION       PIC X.
01 WS-STATUS       PIC XX.
01 WS-ATTENDU      PIC XX.
01 WS-LIBELLE      PIC X(44).
01 WS-NB-ECHECS    PIC 9(3) VALUE 0.
01 WS-MONTANT      PIC 9(9)V99 VALUE 0.
01 WS-DST          PIC 9(10) VALUE 0.
01 WS-PERIODE      PIC 9(6).
01 WS-NUM          PIC 9(10).
01 WS-FS-CPT       PIC XX.
01 WS-FS-TRX       PIC XX.
01 WS-FS-BAT       PIC XX.
01 WS-FS-RAP       PIC XX.
01 WS-FIN          PIC X.
01 WS-SOMME        PIC S9(13)V99.
01 WS-SOMME-AV     PIC S9(13)V99.
01 WS-VAL-LU       PIC S9(13)V99.
01 WS-VAL-ATT      PIC S9(13)V99.
01 WS-NB-TRX       PIC 9(5).
01 WS-NB-IA        PIC 9(5).
01 WS-NB-IR        PIC 9(5).
01 WS-NB-FA        PIC 9(5).
01 WS-NB-FR        PIC 9(5).
01 WS-NB-LIGNES    PIC 9(5).
01 WS-NB-MENTIONS  PIC 9(5).

PROCEDURE DIVISION.
MAIN-PARA.
    CALL "CBL_DELETE_FILE" USING "tests/COMPTES_BATCH_TEST.dat"
    CALL "CBL_DELETE_FILE" USING "tests/TRX_BATCH_TEST.dat"
    CALL "CBL_DELETE_FILE" USING "tests/BATCH_TEST.dat"
    CALL "CBL_DELETE_FILE" USING "tests/BATCH_202611.txt"
    CALL "CBL_DELETE_FILE" USING "tests/BATCH_202612.txt"
    DISPLAY "COMPTES_FILE" UPON ENVIRONMENT-NAME
    DISPLAY "tests/COMPTES_BATCH_TEST.dat" UPON ENVIRONMENT-VALUE
    DISPLAY "TRX_FILE" UPON ENVIRONMENT-NAME
    DISPLAY "tests/TRX_BATCH_TEST.dat" UPON ENVIRONMENT-VALUE
    DISPLAY "BATCH_FILE" UPON ENVIRONMENT-NAME
    DISPLAY "tests/BATCH_TEST.dat" UPON ENVIRONMENT-VALUE
    DISPLAY "BATCH_REPORT_DIR" UPON ENVIRONMENT-NAME
    DISPLAY "tests" UPON ENVIRONMENT-VALUE

    *> --- jeu de donnees ---
    MOVE 1 TO CPT-NUM
    MOVE 1000.00 TO CPT-SOLDE
    MOVE "A" TO CPT-STATUT
    PERFORM CREER-COMPTE
    MOVE 2 TO CPT-NUM
    MOVE 100.00 TO CPT-SOLDE
    PERFORM CREER-COMPTE
    MOVE 3 TO CPT-NUM
    MOVE 1.50 TO CPT-SOLDE
    PERFORM CREER-COMPTE
    MOVE 4 TO CPT-NUM
    MOVE 500.00 TO CPT-SOLDE
    MOVE "G" TO CPT-STATUT
    PERFORM CREER-COMPTE
    MOVE 5 TO CPT-NUM
    MOVE 300.00 TO CPT-SOLDE
    MOVE "C" TO CPT-STATUT
    PERFORM CREER-COMPTE
    MOVE 6 TO CPT-NUM
    MOVE 0 TO CPT-SOLDE
    MOVE "A" TO CPT-STATUT
    PERFORM CREER-COMPTE
    MOVE 7 TO CPT-NUM
    MOVE 999999999.00 TO CPT-SOLDE
    PERFORM CREER-COMPTE

    *> --- periodes invalides ---
    MOVE 202613 TO WS-PERIODE
    PERFORM LANCER-BATCH
    MOVE "73" TO WS-ATTENDU
    MOVE "periode invalide (mois 13)" TO WS-LIBELLE
    PERFORM VERIFIER
    MOVE 199912 TO WS-PERIODE
    PERFORM LANCER-BATCH
    MOVE "periode invalide (annee 1999)" TO WS-LIBELLE
    PERFORM VERIFIER

    *> --- premier lancement : 202611 ---
    PERFORM SOMMER-SOLDES
    MOVE WS-SOMME TO WS-SOMME-AV
    MOVE 202611 TO WS-PERIODE
    PERFORM LANCER-BATCH
    MOVE "00" TO WS-ATTENDU
    MOVE "traitement de la periode 202611" TO WS-LIBELLE
    PERFORM VERIFIER

    MOVE "comptes lus" TO WS-LIBELLE
    MOVE RS-NB-LUS TO WS-VAL-LU
    MOVE 7 TO WS-VAL-ATT
    PERFORM VERIF-VALEUR
    MOVE "comptes actifs traites" TO WS-LIBELLE
    MOVE RS-NB-ACTIFS TO WS-VAL-LU
    MOVE 5 TO WS-VAL-ATT
    PERFORM VERIF-VALEUR
    MOVE "comptes avec interets credites" TO WS-LIBELLE
    MOVE RS-NB-INTERETS TO WS-VAL-LU
    MOVE 2 TO WS-VAL-ATT
    PERFORM VERIF-VALEUR
    MOVE "total des interets (1.25 + 0.13)" TO WS-LIBELLE
    MOVE RS-TOT-INTERETS TO WS-VAL-LU
    MOVE 1.38 TO WS-VAL-ATT
    PERFORM VERIF-VALEUR
    MOVE "comptes avec frais preleves" TO WS-LIBELLE
    MOVE RS-NB-FRAIS TO WS-VAL-LU
    MOVE 3 TO WS-VAL-ATT
    PERFORM VERIF-VALEUR
    MOVE "total des frais" TO WS-LIBELLE
    MOVE RS-TOT-FRAIS TO WS-VAL-LU
    MOVE 6.00 TO WS-VAL-ATT
    PERFORM VERIF-VALEUR
    MOVE "frais non preleves (solde insuffisant)" TO WS-LIBELLE
    MOVE RS-NB-FRAIS-REFUSES TO WS-VAL-LU
    MOVE 2 TO WS-VAL-ATT
    PERFORM VERIF-VALEUR
    MOVE "anomalies (depassement de capacite)" TO WS-LIBELLE
    MOVE RS-NB-ANOMALIES TO WS-VAL-LU
    MOVE 1 TO WS-VAL-ATT
    PERFORM VERIF-VALEUR

    MOVE 1 TO WS-NUM
    MOVE "solde compte 1 (1000.00 + 1.25 - 2.00)" TO WS-LIBELLE
    MOVE 999.25 TO WS-VAL-ATT
    PERFORM VERIF-SOLDE
    MOVE 2 TO WS-NUM
    MOVE "solde compte 2 (interets 0.125 arrondis a 0.13)" TO WS-LIBELLE
    MOVE 98.13 TO WS-VAL-ATT
    PERFORM VERIF-SOLDE
    MOVE 3 TO WS-NUM
    MOVE "solde compte 3 (frais refuses, jamais negatif)" TO WS-LIBELLE
    MOVE 1.50 TO WS-VAL-ATT
    PERFORM VERIF-SOLDE
    MOVE 4 TO WS-NUM
    MOVE "solde compte 4 gele : ignore" TO WS-LIBELLE
    MOVE 500.00 TO WS-VAL-ATT
    PERFORM VERIF-SOLDE
    MOVE 5 TO WS-NUM
    MOVE "solde compte 5 clos : ignore" TO WS-LIBELLE
    MOVE 300.00 TO WS-VAL-ATT
    PERFORM VERIF-SOLDE
    MOVE 6 TO WS-NUM
    MOVE "solde compte 6 a zero : inchange" TO WS-LIBELLE
    MOVE 0 TO WS-VAL-ATT
    PERFORM VERIF-SOLDE
    MOVE 7 TO WS-NUM
    MOVE "solde compte 7 (credit refuse, frais preleves)" TO WS-LIBELLE
    MOVE 999999997.00 TO WS-VAL-ATT
    PERFORM VERIF-SOLDE

    PERFORM SOMMER-SOLDES
    MOVE "somme des soldes = avant + interets - frais" TO WS-LIBELLE
    MOVE WS-SOMME TO WS-VAL-LU
    COMPUTE WS-VAL-ATT = WS-SOMME-AV + 1.38 - 6.00
    PERFORM VERIF-VALEUR

    PERFORM COMPTER-TRX
    MOVE "historique : lignes ecrites" TO WS-LIBELLE
    MOVE WS-NB-TRX TO WS-VAL-LU
    MOVE 8 TO WS-VAL-ATT
    PERFORM VERIF-VALEUR
    MOVE "historique : interets acceptes (I/A)" TO WS-LIBELLE
    MOVE WS-NB-IA TO WS-VAL-LU
    MOVE 2 TO WS-VAL-ATT
    PERFORM VERIF-VALEUR
    MOVE "historique : interets refuses (I/R)" TO WS-LIBELLE
    MOVE WS-NB-IR TO WS-VAL-LU
    MOVE 1 TO WS-VAL-ATT
    PERFORM VERIF-VALEUR
    MOVE "historique : frais acceptes (F/A)" TO WS-LIBELLE
    MOVE WS-NB-FA TO WS-VAL-LU
    MOVE 3 TO WS-VAL-ATT
    PERFORM VERIF-VALEUR
    MOVE "historique : frais refuses (F/R)" TO WS-LIBELLE
    MOVE WS-NB-FR TO WS-VAL-LU
    MOVE 2 TO WS-VAL-ATT
    PERFORM VERIF-VALEUR

    PERFORM VERIF-SUIVI
    PERFORM VERIF-RAPPORT

    *> --- rejeu de la meme periode : refuse, rien ne bouge ---
    MOVE 202611 TO WS-PERIODE
    PERFORM LANCER-BATCH
    MOVE "71" TO WS-ATTENDU
    MOVE "meme periode relancee (refus)" TO WS-LIBELLE
    PERFORM VERIFIER
    PERFORM SOMMER-SOLDES
    MOVE "soldes inchanges apres le rejeu" TO WS-LIBELLE
    MOVE WS-SOMME TO WS-VAL-LU
    COMPUTE WS-VAL-ATT = WS-SOMME-AV + 1.38 - 6.00
    PERFORM VERIF-VALEUR
    PERFORM COMPTER-TRX
    MOVE "historique inchange apres le rejeu" TO WS-LIBELLE
    MOVE WS-NB-TRX TO WS-VAL-LU
    MOVE 8 TO WS-VAL-ATT
    PERFORM VERIF-VALEUR

    *> --- periode interrompue : verification manuelle, rien ne bouge ---
    PERFORM MARQUER-INTERROMPUE
    MOVE 202610 TO WS-PERIODE
    PERFORM LANCER-BATCH
    MOVE "72" TO WS-ATTENDU
    MOVE "periode interrompue (refus)" TO WS-LIBELLE
    PERFORM VERIFIER
    PERFORM SOMMER-SOLDES
    MOVE "soldes inchanges apres periode interrompue" TO WS-LIBELLE
    MOVE WS-SOMME TO WS-VAL-LU
    COMPUTE WS-VAL-ATT = WS-SOMME-AV + 1.38 - 6.00
    PERFORM VERIF-VALEUR

    *> --- mois suivant : traite normalement ---
    MOVE 202612 TO WS-PERIODE
    PERFORM LANCER-BATCH
    MOVE "00" TO WS-ATTENDU
    MOVE "traitement de la periode 202612" TO WS-LIBELLE
    PERFORM VERIFIER
    MOVE "202612 : comptes avec interets credites" TO WS-LIBELLE
    MOVE RS-NB-INTERETS TO WS-VAL-LU
    MOVE 2 TO WS-VAL-ATT
    PERFORM VERIF-VALEUR
    MOVE 1 TO WS-NUM
    MOVE "202612 : solde compte 1 (999.25 + 1.25 - 2.00)" TO WS-LIBELLE
    MOVE 998.50 TO WS-VAL-ATT
    PERFORM VERIF-SOLDE
    MOVE 2 TO WS-NUM
    MOVE "202612 : solde compte 2 (98.13 + 0.12 - 2.00)" TO WS-LIBELLE
    MOVE 96.25 TO WS-VAL-ATT
    PERFORM VERIF-SOLDE

    CALL "CBL_DELETE_FILE" USING "tests/COMPTES_BATCH_TEST.dat"
    CALL "CBL_DELETE_FILE" USING "tests/TRX_BATCH_TEST.dat"
    CALL "CBL_DELETE_FILE" USING "tests/BATCH_TEST.dat"
    CALL "CBL_DELETE_FILE" USING "tests/BATCH_202611.txt"
    CALL "CBL_DELETE_FILE" USING "tests/BATCH_202612.txt"
    IF WS-NB-ECHECS = 0
        DISPLAY "TOUS LES TESTS PASSENT"
        MOVE 0 TO RETURN-CODE
    ELSE
        DISPLAY WS-NB-ECHECS " TEST(S) EN ECHEC"
        MOVE 1 TO RETURN-CODE
    END-IF
    STOP RUN.

*> Cree le compte CPT-NUM / CPT-SOLDE / CPT-STATUT (COMPTE.cpy de travail)
CREER-COMPTE.
    MOVE 100 TO CPT-ID-CLIENT
    MOVE 0 TO CPT-PLAFOND
    MOVE "C" TO WS-ACTION
    CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST WS-STATUS.

LANCER-BATCH.
    INITIALIZE RS-REC
    CALL "BATCH-INT" USING WS-PERIODE RS-REC WS-STATUS.

VERIFIER.
    IF WS-STATUS = WS-ATTENDU
        DISPLAY "PASS " WS-LIBELLE
    ELSE
        DISPLAY "FAIL " WS-LIBELLE " (statut " WS-STATUS
                ", attendu " WS-ATTENDU ")"
        ADD 1 TO WS-NB-ECHECS
    END-IF.

VERIF-VALEUR.
    IF WS-VAL-LU = WS-VAL-ATT
        DISPLAY "  PASS " WS-LIBELLE
    ELSE
        DISPLAY "  FAIL " WS-LIBELLE " (lu " WS-VAL-LU
                ", attendu " WS-VAL-ATT ")"
        ADD 1 TO WS-NB-ECHECS
    END-IF.

*> Relit le compte WS-NUM par COMPTE et compare son solde a WS-VAL-ATT
VERIF-SOLDE.
    INITIALIZE COMPTE-REC
    MOVE WS-NUM TO CPT-NUM
    MOVE "L" TO WS-ACTION
    CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST WS-STATUS
    MOVE CPT-SOLDE TO WS-VAL-LU
    PERFORM VERIF-VALEUR.

*> WS-SOMME = somme des soldes de tous les comptes (lecture directe du fichier)
SOMMER-SOLDES.
    MOVE 0 TO WS-SOMME
    MOVE "N" TO WS-FIN
    OPEN INPUT F-CPT
    IF WS-FS-CPT = "00"
        PERFORM UNTIL WS-FIN = "O"
            READ F-CPT NEXT RECORD
                AT END MOVE "O" TO WS-FIN
                NOT AT END ADD FC-SOLDE TO WS-SOMME
            END-READ
        END-PERFORM
        CLOSE F-CPT
    END-IF.

*> Compte les lignes de l'historique par type et statut
COMPTER-TRX.
    MOVE 0 TO WS-NB-TRX WS-NB-IA WS-NB-IR WS-NB-FA WS-NB-FR
    MOVE "N" TO WS-FIN
    OPEN INPUT F-TRX
    IF WS-FS-TRX = "00"
        PERFORM UNTIL WS-FIN = "O"
            READ F-TRX
                AT END MOVE "O" TO WS-FIN
                NOT AT END
                    ADD 1 TO WS-NB-TRX
                    EVALUATE FT-TYPE ALSO FT-STATUT
                        WHEN "I" ALSO "A" ADD 1 TO WS-NB-IA
                        WHEN "I" ALSO "R" ADD 1 TO WS-NB-IR
                        WHEN "F" ALSO "A" ADD 1 TO WS-NB-FA
                        WHEN "F" ALSO "R" ADD 1 TO WS-NB-FR
                    END-EVALUATE
            END-READ
        END-PERFORM
        CLOSE F-TRX
    END-IF.

*> La periode 202611 est marquee terminee, avec le bon nombre de comptes lus
VERIF-SUIVI.
    OPEN INPUT F-BAT
    MOVE 202611 TO FB-PERIODE
    READ F-BAT KEY IS FB-PERIODE
    IF WS-FS-BAT = "00" AND FB-ETAT = "T" AND FB-NB-LUS = 7
        DISPLAY "  PASS suivi : periode 202611 marquee terminee"
    ELSE
        DISPLAY "  FAIL suivi : periode 202611 (statut fichier "
                WS-FS-BAT ")"
        ADD 1 TO WS-NB-ECHECS
    END-IF
    CLOSE F-BAT.

*> Ajoute a la main la periode 202610 marquee "en cours" (lancement interrompu)
MARQUER-INTERROMPUE.
    OPEN I-O F-BAT
    INITIALIZE FB-REC
    MOVE 202610 TO FB-PERIODE
    MOVE "E" TO FB-ETAT
    WRITE FB-REC
    CLOSE F-BAT.

*> Le rapport existe, contient plusieurs lignes et cite la periode
VERIF-RAPPORT.
    MOVE 0 TO WS-NB-LIGNES WS-NB-MENTIONS
    MOVE "N" TO WS-FIN
    OPEN INPUT F-RAP
    IF WS-FS-RAP = "00"
        PERFORM UNTIL WS-FIN = "O"
            READ F-RAP
                AT END MOVE "O" TO WS-FIN
                NOT AT END
                    ADD 1 TO WS-NB-LIGNES
                    INSPECT FR-LIGNE TALLYING WS-NB-MENTIONS
                        FOR ALL "202611"
            END-READ
        END-PERFORM
        CLOSE F-RAP
    END-IF
    IF WS-NB-LIGNES >= 10 AND WS-NB-MENTIONS >= 1
        DISPLAY "  PASS rapport : " WS-NB-LIGNES " lignes, periode citee"
    ELSE
        DISPLAY "  FAIL rapport : " WS-NB-LIGNES " lignes, "
                WS-NB-MENTIONS " mention(s) de la periode"
        ADD 1 TO WS-NB-ECHECS
    END-IF.

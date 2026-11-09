*> BATCH-INT.cob - traitement mensuel : interets et frais de tenue de compte
*>
*> Appel : CALL "BATCH-INT" USING LK-PERIODE LK-BATCH-REC LK-STATUS
*>   LK-PERIODE    : periode AAAAMM (ex. 202611)
*>   LK-BATCH-REC  : renvoie les compteurs du traitement (copybook BATCH.cpy)
*>   LK-STATUS :
*>     00 traitement termine         71 periode deja traitee (rien n'est fait)
*>     72 periode interrompue lors d'un precedent lancement : verification
*>        manuelle necessaire, rien n'est fait
*>     73 periode invalide           autre : FILE STATUS d'une erreur d'E/S
*>        (le traitement s'arrete, la periode reste marquee "interrompue")
*>
*> Pour chaque compte ACTIF (les comptes geles ou clos sont ignores) :
*>   1. interets = solde x taux annuel / 12, arrondi au centime, credites
*>      seulement si solde > 0 et interets >= 0.01 (type I dans l'historique)
*>   2. frais de tenue preleves (type F) si le solde le permet, jamais de
*>      solde negatif : sinon une ligne F refusee est ecrite
*>   Un credit qui depasserait la capacite du solde est refuse (ligne I
*>   refusee) et compte comme anomalie.
*> Rejouable sans doublon : chaque periode est enregistree dans le fichier de
*> suivi (cle AAAAMM) avant le traitement, "E" en cours puis "T" termine.
*> Un rapport texte est ecrit dans <BATCH_REPORT_DIR>/BATCH_AAAAMM.txt.
*> Taux et frais sont des constantes en attendant le fichier de parametres.
*> Fichiers : COMPTES_FILE (data/COMPTES.dat), BATCH_FILE (data/BATCH.dat),
*>            TRX_FILE (via TRX), BATCH_REPORT_DIR (reports)
IDENTIFICATION DIVISION.
PROGRAM-ID. BATCH-INT.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-COMPTES ASSIGN TO DYNAMIC WS-COMPTES-NAME
        ORGANIZATION IS INDEXED
        ACCESS MODE IS DYNAMIC
        RECORD KEY IS CPT-NUM
        FILE STATUS IS WS-FS.
    SELECT F-BATCH ASSIGN TO DYNAMIC WS-BATCH-NAME
        ORGANIZATION IS INDEXED
        ACCESS MODE IS RANDOM
        RECORD KEY IS BAT-PERIODE
        FILE STATUS IS WS-FS-BAT.
    SELECT F-RAPPORT ASSIGN TO DYNAMIC WS-RAPPORT-NAME
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS-RAP.

DATA DIVISION.
FILE SECTION.
FD F-COMPTES.
COPY "COMPTE.cpy".
FD F-BATCH.
COPY "BATCH.cpy".
FD F-RAPPORT.
01 RAPPORT-LIGNE        PIC X(80).

WORKING-STORAGE SECTION.
01 WS-FS               PIC XX.
01 WS-FS-BAT           PIC XX.
01 WS-FS-RAP           PIC XX.
01 WS-TRX-STATUS       PIC XX.
01 WS-COMPTES-NAME     PIC X(100).
01 WS-BATCH-NAME       PIC X(100).
01 WS-REPORT-DIR       PIC X(80).
01 WS-RAPPORT-NAME     PIC X(120).
01 WS-TAUX             PIC 9V9999 VALUE 0.0150.
01 WS-FRAIS            PIC 9(5)V99 VALUE 2.00.
01 WS-SOLDE-MAX        PIC 9(9)V99 VALUE 999999999.99.
01 WS-PERIODE          PIC 9(6).
01 WS-PERIODE-R REDEFINES WS-PERIODE.
   05 WS-AN            PIC 9(4).
   05 WS-MS            PIC 99.
01 WS-INT              PIC 9(9)V99.
01 WS-SOLDE-APRES-INT  PIC S9(9)V99.
01 WS-INT-STATUT       PIC X.
01 WS-INT-MOTIF        PIC X(30).
01 WS-FRAIS-STATUT     PIC X.
01 WS-FRAIS-MOTIF      PIC X(30).
01 WS-MODIFIE          PIC X.
01 WS-FIN              PIC X.
01 WS-LIGNE            PIC X(80).
01 WS-E-NB             PIC Z(6)9.
01 WS-E-MT             PIC Z(10)9.99.
01 WS-E-VAR            PIC -Z(10)9.99.
01 WS-E-TAUX           PIC Z9.99.
01 WS-TAUX-PCT         PIC 99V99.
01 WS-VARIATION        PIC S9(11)V99.
COPY "BATCH.cpy" REPLACING LEADING ==BAT-== BY ==RES-==
                           ==BATCH-REC== BY ==RES-REC==.
COPY "TRX.cpy".

LINKAGE SECTION.
01 LK-PERIODE          PIC 9(6).
COPY "BATCH.cpy" REPLACING LEADING ==BAT-== BY ==LK-BAT-==
                           ==BATCH-REC== BY ==LK-BATCH-REC==.
01 LK-STATUS           PIC XX.

PROCEDURE DIVISION USING LK-PERIODE LK-BATCH-REC LK-STATUS.
MAIN-PARA.
    MOVE "00" TO LK-STATUS
    PERFORM LIRE-ENVIRONNEMENT

    MOVE LK-PERIODE TO WS-PERIODE
    IF WS-AN < 2000 OR WS-MS < 1 OR WS-MS > 12
        MOVE "73" TO LK-STATUS
        GOBACK
    END-IF

    PERFORM RESERVER-PERIODE
    IF LK-STATUS NOT = "00"
        GOBACK
    END-IF

    PERFORM TRAITER-COMPTES
    MOVE RES-REC TO LK-BATCH-REC
    IF LK-STATUS = "00"
        PERFORM CLOTURER-PERIODE
    END-IF
    GOBACK.

LIRE-ENVIRONNEMENT.
    MOVE "data/COMPTES.dat" TO WS-COMPTES-NAME
    ACCEPT WS-COMPTES-NAME FROM ENVIRONMENT "COMPTES_FILE"
        ON EXCEPTION MOVE "data/COMPTES.dat" TO WS-COMPTES-NAME
    END-ACCEPT
    MOVE "data/BATCH.dat" TO WS-BATCH-NAME
    ACCEPT WS-BATCH-NAME FROM ENVIRONMENT "BATCH_FILE"
        ON EXCEPTION MOVE "data/BATCH.dat" TO WS-BATCH-NAME
    END-ACCEPT
    MOVE "reports" TO WS-REPORT-DIR
    ACCEPT WS-REPORT-DIR FROM ENVIRONMENT "BATCH_REPORT_DIR"
        ON EXCEPTION MOVE "reports" TO WS-REPORT-DIR
    END-ACCEPT.

*> Refuse une periode deja traitee ou interrompue, sinon la marque "en cours"
RESERVER-PERIODE.
    OPEN I-O F-BATCH
    IF WS-FS-BAT = "35"
        OPEN OUTPUT F-BATCH
        CLOSE F-BATCH
        OPEN I-O F-BATCH
    END-IF
    IF WS-FS-BAT NOT = "00"
        MOVE WS-FS-BAT TO LK-STATUS
    ELSE
        MOVE LK-PERIODE TO BAT-PERIODE
        READ F-BATCH KEY IS BAT-PERIODE
        EVALUATE WS-FS-BAT
            WHEN "00"
                IF BAT-TERMINE
                    MOVE "71" TO LK-STATUS
                ELSE
                    MOVE "72" TO LK-STATUS
                END-IF
            WHEN "23"
                INITIALIZE BATCH-REC
                MOVE LK-PERIODE TO BAT-PERIODE
                MOVE "E" TO BAT-ETAT
                ACCEPT BAT-DATE FROM DATE YYYYMMDD
                WRITE BATCH-REC
                MOVE WS-FS-BAT TO LK-STATUS
            WHEN OTHER
                MOVE WS-FS-BAT TO LK-STATUS
        END-EVALUATE
        CLOSE F-BATCH
    END-IF.

TRAITER-COMPTES.
    INITIALIZE RES-REC
    MOVE LK-PERIODE TO RES-PERIODE
    MOVE "E" TO RES-ETAT
    OPEN I-O F-COMPTES
    IF WS-FS = "35"
        OPEN OUTPUT F-COMPTES
        CLOSE F-COMPTES
        OPEN I-O F-COMPTES
    END-IF
    IF WS-FS NOT = "00"
        MOVE WS-FS TO LK-STATUS
    ELSE
        MOVE "N" TO WS-FIN
        PERFORM UNTIL WS-FIN = "O" OR LK-STATUS NOT = "00"
            READ F-COMPTES NEXT RECORD
                AT END
                    MOVE "O" TO WS-FIN
                NOT AT END
                    PERFORM TRAITER-UN-COMPTE
            END-READ
            IF WS-FS NOT = "00" AND WS-FS NOT = "10"
                MOVE WS-FS TO LK-STATUS
            END-IF
        END-PERFORM
        CLOSE F-COMPTES
    END-IF.

TRAITER-UN-COMPTE.
    ADD 1 TO RES-NB-LUS
    IF CPT-ACTIF
        ADD 1 TO RES-NB-ACTIFS
        MOVE "N" TO WS-MODIFIE
        PERFORM CALCULER-INTERETS
        PERFORM CALCULER-FRAIS
        IF WS-MODIFIE = "O"
            REWRITE COMPTE-REC
            IF WS-FS NOT = "00"
                MOVE WS-FS TO LK-STATUS
            END-IF
        END-IF
        IF LK-STATUS = "00"
            PERFORM JOURNALISER-INTERETS
        END-IF
        IF LK-STATUS = "00"
            PERFORM JOURNALISER-FRAIS
        END-IF
    END-IF.

*> WS-INT-STATUT : N aucun interet, A credite, R refuse (depassement)
CALCULER-INTERETS.
    MOVE "N" TO WS-INT-STATUT
    MOVE 0 TO WS-INT
    IF CPT-SOLDE > 0
        COMPUTE WS-INT ROUNDED = CPT-SOLDE * WS-TAUX / 12
        IF WS-INT > 0
            *> comparaison explicite plutot que ON SIZE ERROR : le solde
            *> maximum est 999999999.99 (PIC S9(9)V99)
            IF CPT-SOLDE + WS-INT > WS-SOLDE-MAX
                MOVE "R" TO WS-INT-STATUT
                MOVE "DEPASSEMENT DE CAPACITE" TO WS-INT-MOTIF
                ADD 1 TO RES-NB-ANOMALIES
            ELSE
                ADD WS-INT TO CPT-SOLDE
                MOVE "A" TO WS-INT-STATUT
                MOVE "O" TO WS-MODIFIE
                ADD 1 TO RES-NB-INTERETS
                ADD WS-INT TO RES-TOT-INTERETS
            END-IF
        END-IF
    END-IF
    *> solde apres les interets (inchange s'il n'y en a pas / refus)
    MOVE CPT-SOLDE TO WS-SOLDE-APRES-INT.

*> WS-FRAIS-STATUT : A preleves, R refuses (solde insuffisant)
CALCULER-FRAIS.
    IF CPT-SOLDE >= WS-FRAIS
        SUBTRACT WS-FRAIS FROM CPT-SOLDE
        MOVE "A" TO WS-FRAIS-STATUT
        MOVE "O" TO WS-MODIFIE
        ADD 1 TO RES-NB-FRAIS
        ADD WS-FRAIS TO RES-TOT-FRAIS
    ELSE
        MOVE "R" TO WS-FRAIS-STATUT
        MOVE "SOLDE INSUFFISANT" TO WS-FRAIS-MOTIF
        ADD 1 TO RES-NB-FRAIS-REFUSES
    END-IF.

JOURNALISER-INTERETS.
    IF WS-INT-STATUT NOT = "N"
        INITIALIZE TRX-REC
        MOVE "I" TO TRX-TYPE
        MOVE CPT-NUM TO TRX-CPT-DST
        MOVE WS-SOLDE-APRES-INT TO TRX-SOLDE-DST
        MOVE WS-INT TO TRX-MONTANT
        MOVE WS-INT-STATUT TO TRX-STATUT
        IF WS-INT-STATUT = "A"
            STRING "INTERETS " DELIMITED BY SIZE
                   LK-PERIODE DELIMITED BY SIZE
                   INTO TRX-MOTIF
        ELSE
            MOVE WS-INT-MOTIF TO TRX-MOTIF
        END-IF
        CALL "TRX" USING TRX-REC WS-TRX-STATUS
        IF WS-TRX-STATUS NOT = "00"
            MOVE WS-TRX-STATUS TO LK-STATUS
        END-IF
    END-IF.

JOURNALISER-FRAIS.
    INITIALIZE TRX-REC
    MOVE "F" TO TRX-TYPE
    MOVE CPT-NUM TO TRX-CPT-SRC
    MOVE CPT-SOLDE TO TRX-SOLDE-SRC
    MOVE WS-FRAIS TO TRX-MONTANT
    MOVE WS-FRAIS-STATUT TO TRX-STATUT
    IF WS-FRAIS-STATUT = "A"
        STRING "FRAIS DE TENUE " DELIMITED BY SIZE
               LK-PERIODE DELIMITED BY SIZE
               INTO TRX-MOTIF
    ELSE
        MOVE WS-FRAIS-MOTIF TO TRX-MOTIF
    END-IF
    CALL "TRX" USING TRX-REC WS-TRX-STATUS
    IF WS-TRX-STATUS NOT = "00"
        MOVE WS-TRX-STATUS TO LK-STATUS
    END-IF.

*> Marque la periode "terminee" avec ses compteurs, puis ecrit le rapport
CLOTURER-PERIODE.
    MOVE "T" TO RES-ETAT
    ACCEPT RES-DATE FROM DATE YYYYMMDD
    OPEN I-O F-BATCH
    IF WS-FS-BAT NOT = "00"
        MOVE WS-FS-BAT TO LK-STATUS
    ELSE
        MOVE LK-PERIODE TO BAT-PERIODE
        READ F-BATCH KEY IS BAT-PERIODE
        IF WS-FS-BAT = "00"
            MOVE RES-REC TO BATCH-REC
            REWRITE BATCH-REC
        END-IF
        MOVE WS-FS-BAT TO LK-STATUS
        CLOSE F-BATCH
    END-IF
    MOVE RES-REC TO LK-BATCH-REC
    IF LK-STATUS = "00"
        PERFORM ECRIRE-RAPPORT
    END-IF.

ECRIRE-RAPPORT.
    MOVE SPACES TO WS-RAPPORT-NAME
    STRING WS-REPORT-DIR DELIMITED BY SPACE
           "/BATCH_" DELIMITED BY SIZE
           LK-PERIODE DELIMITED BY SIZE
           ".txt" DELIMITED BY SIZE
           INTO WS-RAPPORT-NAME
    OPEN OUTPUT F-RAPPORT
    IF WS-FS-RAP NOT = "00"
        MOVE WS-FS-RAP TO LK-STATUS
    ELSE
        MOVE SPACES TO WS-LIGNE
        STRING "RAPPORT DU TRAITEMENT MENSUEL - PERIODE " DELIMITED BY SIZE
               LK-PERIODE DELIMITED BY SIZE
               INTO WS-LIGNE
        PERFORM ECRIRE-LIGNE

        MOVE SPACES TO WS-LIGNE
        STRING "Date du traitement : " DELIMITED BY SIZE
               RES-DATE DELIMITED BY SIZE
               INTO WS-LIGNE
        PERFORM ECRIRE-LIGNE

        COMPUTE WS-TAUX-PCT = WS-TAUX * 100
        MOVE WS-TAUX-PCT TO WS-E-TAUX
        MOVE WS-FRAIS TO WS-E-MT
        MOVE SPACES TO WS-LIGNE
        STRING "Taux annuel : " DELIMITED BY SIZE
               WS-E-TAUX DELIMITED BY SIZE
               " %   Frais mensuels : " DELIMITED BY SIZE
               WS-E-MT DELIMITED BY SIZE
               INTO WS-LIGNE
        PERFORM ECRIRE-LIGNE

        MOVE RES-NB-LUS TO WS-E-NB
        MOVE SPACES TO WS-LIGNE
        STRING "Comptes lus : " DELIMITED BY SIZE
               WS-E-NB DELIMITED BY SIZE INTO WS-LIGNE
        PERFORM ECRIRE-LIGNE

        MOVE RES-NB-ACTIFS TO WS-E-NB
        MOVE SPACES TO WS-LIGNE
        STRING "Comptes actifs traites : " DELIMITED BY SIZE
               WS-E-NB DELIMITED BY SIZE INTO WS-LIGNE
        PERFORM ECRIRE-LIGNE

        MOVE RES-NB-INTERETS TO WS-E-NB
        MOVE RES-TOT-INTERETS TO WS-E-MT
        MOVE SPACES TO WS-LIGNE
        STRING "Interets credites : " DELIMITED BY SIZE
               WS-E-NB DELIMITED BY SIZE
               " compte(s), total " DELIMITED BY SIZE
               WS-E-MT DELIMITED BY SIZE INTO WS-LIGNE
        PERFORM ECRIRE-LIGNE

        MOVE RES-NB-FRAIS TO WS-E-NB
        MOVE RES-TOT-FRAIS TO WS-E-MT
        MOVE SPACES TO WS-LIGNE
        STRING "Frais preleves : " DELIMITED BY SIZE
               WS-E-NB DELIMITED BY SIZE
               " compte(s), total " DELIMITED BY SIZE
               WS-E-MT DELIMITED BY SIZE INTO WS-LIGNE
        PERFORM ECRIRE-LIGNE

        MOVE RES-NB-FRAIS-REFUSES TO WS-E-NB
        MOVE SPACES TO WS-LIGNE
        STRING "Frais non preleves (solde insuffisant) : "
               DELIMITED BY SIZE
               WS-E-NB DELIMITED BY SIZE INTO WS-LIGNE
        PERFORM ECRIRE-LIGNE

        MOVE RES-NB-ANOMALIES TO WS-E-NB
        MOVE SPACES TO WS-LIGNE
        STRING "Anomalies (depassement de capacite) : "
               DELIMITED BY SIZE
               WS-E-NB DELIMITED BY SIZE INTO WS-LIGNE
        PERFORM ECRIRE-LIGNE

        COMPUTE WS-VARIATION = RES-TOT-INTERETS - RES-TOT-FRAIS
        MOVE WS-VARIATION TO WS-E-VAR
        MOVE SPACES TO WS-LIGNE
        STRING "Variation totale des soldes : " DELIMITED BY SIZE
               WS-E-VAR DELIMITED BY SIZE INTO WS-LIGNE
        PERFORM ECRIRE-LIGNE

        CLOSE F-RAPPORT
    END-IF.

ECRIRE-LIGNE.
    MOVE WS-LIGNE TO RAPPORT-LIGNE
    WRITE RAPPORT-LIGNE.

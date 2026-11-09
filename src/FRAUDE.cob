*> FRAUDE.cob - detection de fraude basique et journal d'alertes
*>
*> Appel : CALL "FRAUDE" USING LK-ACTION LK-CPT-NUM LK-ID-CLIENT LK-MONTANT
*>                             LK-PLAFOND LK-STATUS
*>   LK-ACTION :
*>     "C" controle d'une sortie d'argent (retrait ou virement sortant) du
*>         compte LK-CPT-NUM pour LK-MONTANT, avec le plafond LK-PLAFOND
*>     "B" alerte de blocage de PIN pour le client LK-ID-CLIENT
*>   LK-STATUS :
*>     00 rien a signaler            96 plafond journalier depasse (refuser)
*>     97 montant anormal : alerte ecrite, l'operation reste autorisee
*>     99 action inconnue            autre : FILE STATUS d'une erreur d'E/S
*>
*> Regles (constantes en attendant le fichier de parametres) :
*>   - plafond : somme des sorties acceptees du compte AUJOURD'HUI + montant
*>     ne doit pas depasser le plafond (0 = plafond par defaut 1000.00) ;
*>     le jour meme, atteindre exactement le plafond est accepte
*>   - anomalie : si le compte a au moins 3 operations acceptees dans
*>     l'historique, un montant superieur a 5 fois leur moyenne est signale
*> L'historique est lu dans le fichier des transactions ; les alertes sont
*> ajoutees au journal (ajout seul).
*> Fichiers : TRX_FILE (defaut data/TRANSACTIONS.dat),
*>            ALERTES_FILE (defaut data/ALERTES.dat)
IDENTIFICATION DIVISION.
PROGRAM-ID. FRAUDE.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-TRX ASSIGN TO DYNAMIC WS-TRX-NAME
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS-TRX.
    SELECT F-ALR ASSIGN TO DYNAMIC WS-ALR-NAME
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS-ALR.

DATA DIVISION.
FILE SECTION.
FD F-TRX.
COPY "TRX.cpy".
FD F-ALR.
COPY "ALERTE.cpy".

WORKING-STORAGE SECTION.
01 WS-TRX-NAME      PIC X(100).
01 WS-ALR-NAME      PIC X(100).
01 WS-FS-TRX        PIC XX.
01 WS-FS-ALR        PIC XX.
01 WS-ALR-STATUS    PIC XX.
01 WS-PLAFOND-DEFAUT PIC 9(7)V99 VALUE 1000.00.
01 WS-FACTEUR       PIC 9 VALUE 5.
01 WS-MIN-HIST      PIC 9 VALUE 3.
01 WS-AUJOURDHUI    PIC 9(8).
01 WS-TIME          PIC 9(8).
01 WS-CUMUL         PIC 9(11)V99.
01 WS-NB-OPS        PIC 9(7).
01 WS-TOTAL-OPS     PIC 9(13)V99.
01 WS-PLAFOND-EFF   PIC 9(7)V99.
01 WS-DERNIER-ID    PIC 9(10).
01 WS-FIN           PIC X.
01 WS-REGLE         PIC X(16).
01 WS-DETAIL        PIC X(30).

LINKAGE SECTION.
01 LK-ACTION        PIC X.
01 LK-CPT-NUM       PIC 9(10).
01 LK-ID-CLIENT     PIC 9(6).
01 LK-MONTANT       PIC 9(9)V99.
01 LK-PLAFOND       PIC 9(7)V99.
01 LK-STATUS        PIC XX.

PROCEDURE DIVISION USING LK-ACTION LK-CPT-NUM LK-ID-CLIENT LK-MONTANT
                         LK-PLAFOND LK-STATUS.
MAIN-PARA.
    MOVE "data/TRANSACTIONS.dat" TO WS-TRX-NAME
    ACCEPT WS-TRX-NAME FROM ENVIRONMENT "TRX_FILE"
        ON EXCEPTION MOVE "data/TRANSACTIONS.dat" TO WS-TRX-NAME
    END-ACCEPT
    MOVE "data/ALERTES.dat" TO WS-ALR-NAME
    ACCEPT WS-ALR-NAME FROM ENVIRONMENT "ALERTES_FILE"
        ON EXCEPTION MOVE "data/ALERTES.dat" TO WS-ALR-NAME
    END-ACCEPT

    EVALUATE LK-ACTION
        WHEN "C" PERFORM CONTROLER-SORTIE
        WHEN "B" PERFORM ALERTE-BLOCAGE
        WHEN OTHER MOVE "99" TO LK-STATUS
    END-EVALUATE
    GOBACK.

CONTROLER-SORTIE.
    MOVE "00" TO LK-STATUS
    PERFORM LIRE-HISTORIQUE
    IF LK-STATUS = "00"
        IF LK-PLAFOND = 0
            MOVE WS-PLAFOND-DEFAUT TO WS-PLAFOND-EFF
        ELSE
            MOVE LK-PLAFOND TO WS-PLAFOND-EFF
        END-IF
        IF WS-CUMUL + LK-MONTANT > WS-PLAFOND-EFF
            MOVE "PLAFOND_JOUR" TO WS-REGLE
            MOVE "CUMUL DU JOUR DEPASSE" TO WS-DETAIL
            PERFORM ECRIRE-ALERTE
            MOVE "96" TO LK-STATUS
        ELSE
            IF WS-NB-OPS >= WS-MIN-HIST
               AND LK-MONTANT * WS-NB-OPS > WS-FACTEUR * WS-TOTAL-OPS
                MOVE "MONTANT_ANORMAL" TO WS-REGLE
                MOVE "MONTANT > 5 X MOYENNE" TO WS-DETAIL
                PERFORM ECRIRE-ALERTE
                IF WS-ALR-STATUS = "00"
                    MOVE "97" TO LK-STATUS
                ELSE
                    MOVE WS-ALR-STATUS TO LK-STATUS
                END-IF
            END-IF
        END-IF
    END-IF.

ALERTE-BLOCAGE.
    MOVE "PIN_BLOQUE" TO WS-REGLE
    MOVE "ECHECS CONSECUTIFS DE PIN" TO WS-DETAIL
    PERFORM ECRIRE-ALERTE
    MOVE WS-ALR-STATUS TO LK-STATUS.

*> Parcourt les transactions : cumul des sorties du jour pour le compte,
*> nombre et total de ses operations acceptees (tous jours confondus)
LIRE-HISTORIQUE.
    MOVE 0 TO WS-CUMUL
    MOVE 0 TO WS-NB-OPS
    MOVE 0 TO WS-TOTAL-OPS
    ACCEPT WS-AUJOURDHUI FROM DATE YYYYMMDD
    MOVE "N" TO WS-FIN
    OPEN INPUT F-TRX
    EVALUATE WS-FS-TRX
        WHEN "00"
            PERFORM UNTIL WS-FIN = "O"
                READ F-TRX
                    AT END MOVE "O" TO WS-FIN
                    NOT AT END PERFORM CUMULER-LIGNE
                END-READ
            END-PERFORM
            CLOSE F-TRX
        WHEN "35"
            CONTINUE
        WHEN OTHER
            MOVE WS-FS-TRX TO LK-STATUS
    END-EVALUATE.

CUMULER-LIGNE.
    IF TRX-STATUT = "A"
        IF (TRX-TYPE = "R" OR TRX-TYPE = "V")
           AND TRX-CPT-SRC = LK-CPT-NUM
           AND TRX-DATE = WS-AUJOURDHUI
            ADD TRX-MONTANT TO WS-CUMUL
        END-IF
        IF (TRX-TYPE = "D" OR TRX-TYPE = "R" OR TRX-TYPE = "V")
           AND (TRX-CPT-SRC = LK-CPT-NUM OR TRX-CPT-DST = LK-CPT-NUM)
            ADD 1 TO WS-NB-OPS
            ADD TRX-MONTANT TO WS-TOTAL-OPS
        END-IF
    END-IF.

*> Ajoute une alerte au journal (WS-REGLE, WS-DETAIL, LK-*) ; WS-ALR-STATUS
*> = "00" si la ligne est ecrite
ECRIRE-ALERTE.
    MOVE "00" TO WS-ALR-STATUS
    MOVE 0 TO WS-DERNIER-ID
    MOVE "N" TO WS-FIN
    OPEN INPUT F-ALR
    EVALUATE WS-FS-ALR
        WHEN "00"
            PERFORM UNTIL WS-FIN = "O"
                READ F-ALR
                    AT END MOVE "O" TO WS-FIN
                    NOT AT END MOVE ALR-ID TO WS-DERNIER-ID
                END-READ
            END-PERFORM
            CLOSE F-ALR
        WHEN "35"
            CONTINUE
        WHEN OTHER
            MOVE WS-FS-ALR TO WS-ALR-STATUS
    END-EVALUATE

    IF WS-ALR-STATUS = "00"
        INITIALIZE ALERTE-REC
        ADD 1 TO WS-DERNIER-ID GIVING ALR-ID
        ACCEPT WS-AUJOURDHUI FROM DATE YYYYMMDD
        ACCEPT WS-TIME FROM TIME
        MOVE WS-AUJOURDHUI TO ALR-DATE
        MOVE WS-TIME(1:6) TO ALR-HEURE
        MOVE WS-REGLE TO ALR-REGLE
        MOVE LK-ID-CLIENT TO ALR-ID-CLIENT
        MOVE LK-CPT-NUM TO ALR-CPT
        MOVE LK-MONTANT TO ALR-MONTANT
        MOVE WS-DETAIL TO ALR-DETAIL
        OPEN EXTEND F-ALR
        IF WS-FS-ALR = "35"
            OPEN OUTPUT F-ALR
        END-IF
        IF WS-FS-ALR NOT = "00" AND WS-FS-ALR NOT = "05"
            MOVE WS-FS-ALR TO WS-ALR-STATUS
        ELSE
            WRITE ALERTE-REC
            MOVE WS-FS-ALR TO WS-ALR-STATUS
            CLOSE F-ALR
        END-IF
    END-IF.

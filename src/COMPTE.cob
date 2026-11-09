*> COMPTE.cob - acces au fichier indexe des comptes + depot / retrait / virement
*>
*> Appel : CALL "COMPTE" USING LK-ACTION LK-COMPTE-REC LK-MONTANT LK-DST
*>                             LK-STATUS
*>   LK-ACTION : "C" creer, "L" lire (par LK-CPT-NUM), "U" mettre a jour,
*>               "D" depot, "R" retrait (compte LK-CPT-NUM, montant LK-MONTANT),
*>               "V" virement de LK-CPT-NUM vers LK-DST (montant LK-MONTANT)
*>   LK-MONTANT : utilise seulement par D, R et V
*>   LK-DST     : compte destination, utilise seulement par V
*>   LK-STATUS :
*>     00 ok                      22 cle deja existante
*>     23 compte introuvable      99 action inconnue
*>     91 montant invalide (0)    92 compte non actif
*>     93 solde insuffisant       94 depassement de capacite du solde
*>     95 virement vers le meme compte
*>     96 plafond journalier depasse (controle FRAUDE, retrait et virement)
*>     98 operation faite mais ligne d'historique non ecrite
*>     autre : FILE STATUS d'une erreur d'entree/sortie
*> D, R et V ecrivent une ligne d'historique (acceptee ou refusee) via TRX.
*> V est atomique : tout est controle avant d'ecrire ; si l'ecriture de la
*> destination echoue, la source est remise dans son etat d'origine.
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
01 WS-FS-SRC      PIC XX.
01 WS-FS-DST      PIC XX.
01 WS-FILENAME    PIC X(100).
01 WS-MOTIF       PIC X(30).
01 WS-LU          PIC X.
01 WS-LU-DST      PIC X.
01 WS-DST-AVANT   PIC S9(9)V99.
01 WS-TRX-STATUS  PIC XX.
01 WS-FRD-ACTION  PIC X VALUE "C".
01 WS-FRD-CPT     PIC 9(10).
01 WS-FRD-CLI     PIC 9(6).
01 WS-FRD-PLAFOND PIC 9(7)V99.
01 WS-FRD-STATUS  PIC XX.
*> copies de travail pour le virement : source, destination, source d'origine
COPY "COMPTE.cpy" REPLACING LEADING ==CPT-== BY ==SRC-==
                            ==COMPTE-REC== BY ==SRC-REC==.
COPY "COMPTE.cpy" REPLACING LEADING ==CPT-== BY ==DST-==
                            ==COMPTE-REC== BY ==DST-REC==.
COPY "COMPTE.cpy" REPLACING LEADING ==CPT-== BY ==ORG-==
                            ==COMPTE-REC== BY ==ORG-REC==.
COPY "TRX.cpy".

LINKAGE SECTION.
01 LK-ACTION      PIC X.
COPY "COMPTE.cpy" REPLACING LEADING ==CPT-== BY ==LK-CPT-==
                            ==COMPTE-REC== BY ==LK-COMPTE-REC==.
01 LK-MONTANT     PIC 9(9)V99.
01 LK-DST         PIC 9(10).
01 LK-STATUS      PIC XX.

PROCEDURE DIVISION USING LK-ACTION LK-COMPTE-REC LK-MONTANT LK-DST
                         LK-STATUS.
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
        WHEN "V" PERFORM VIREMENT
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

    *> un retrait est une sortie d'argent : controle de fraude en dernier
    IF LK-STATUS = "00" AND LK-ACTION = "R"
        MOVE LK-CPT-NUM TO WS-FRD-CPT
        MOVE CPT-ID-CLIENT TO WS-FRD-CLI
        MOVE CPT-PLAFOND TO WS-FRD-PLAFOND
        PERFORM CONTROLE-FRAUDE
    END-IF

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

*> Virement (V) : lit les deux comptes, controle tout, puis ecrit
VIREMENT.
    MOVE "00" TO LK-STATUS
    MOVE SPACES TO WS-MOTIF
    MOVE "N" TO WS-LU
    MOVE "N" TO WS-LU-DST

    MOVE LK-CPT-NUM TO CPT-NUM
    READ F-COMPTES KEY IS CPT-NUM
    MOVE WS-FS TO WS-FS-SRC
    IF WS-FS = "00"
        MOVE "O" TO WS-LU
        MOVE COMPTE-REC TO SRC-REC
    END-IF

    MOVE LK-DST TO CPT-NUM
    READ F-COMPTES KEY IS CPT-NUM
    MOVE WS-FS TO WS-FS-DST
    IF WS-FS = "00"
        MOVE "O" TO WS-LU-DST
        MOVE COMPTE-REC TO DST-REC
        MOVE DST-SOLDE TO WS-DST-AVANT
    END-IF

    EVALUATE TRUE
        WHEN WS-LU NOT = "O"
            MOVE WS-FS-SRC TO LK-STATUS
            MOVE "COMPTE SOURCE INTROUVABLE" TO WS-MOTIF
        WHEN WS-LU-DST NOT = "O"
            MOVE WS-FS-DST TO LK-STATUS
            MOVE "COMPTE DESTINATION INTROUVABLE" TO WS-MOTIF
        WHEN LK-MONTANT = 0
            MOVE "91" TO LK-STATUS
            MOVE "MONTANT INVALIDE" TO WS-MOTIF
        WHEN LK-CPT-NUM = LK-DST
            MOVE "95" TO LK-STATUS
            MOVE "MEME COMPTE" TO WS-MOTIF
        WHEN NOT SRC-ACTIF OR NOT DST-ACTIF
            MOVE "92" TO LK-STATUS
            MOVE "COMPTE NON ACTIF" TO WS-MOTIF
        WHEN SRC-SOLDE < LK-MONTANT
            MOVE "93" TO LK-STATUS
            MOVE "SOLDE INSUFFISANT" TO WS-MOTIF
    END-EVALUATE

    IF LK-STATUS = "00"
        MOVE SRC-REC TO ORG-REC
        ADD LK-MONTANT TO DST-SOLDE
            ON SIZE ERROR
                MOVE "94" TO LK-STATUS
                MOVE "DEPASSEMENT DE CAPACITE" TO WS-MOTIF
        END-ADD
    END-IF

    *> le virement est une sortie pour la source : controle de fraude
    IF LK-STATUS = "00"
        MOVE LK-CPT-NUM TO WS-FRD-CPT
        MOVE SRC-ID-CLIENT TO WS-FRD-CLI
        MOVE SRC-PLAFOND TO WS-FRD-PLAFOND
        PERFORM CONTROLE-FRAUDE
    END-IF

    IF LK-STATUS = "00"
        SUBTRACT LK-MONTANT FROM SRC-SOLDE
        PERFORM ECRIRE-VIREMENT
    END-IF

    IF WS-LU = "O"
        MOVE SRC-REC TO LK-COMPTE-REC
    END-IF

    PERFORM JOURNALISER.

*> Ecrit source puis destination ; annule la source si la destination echoue
ECRIRE-VIREMENT.
    MOVE SRC-REC TO COMPTE-REC
    REWRITE COMPTE-REC
    IF WS-FS NOT = "00"
        MOVE WS-FS TO LK-STATUS
        MOVE "ECRITURE SOURCE ECHOUEE" TO WS-MOTIF
        MOVE ORG-REC TO SRC-REC
    ELSE
        MOVE DST-REC TO COMPTE-REC
        REWRITE COMPTE-REC
        IF WS-FS NOT = "00"
            MOVE WS-FS TO LK-STATUS
            MOVE "ECRITURE DESTINATION ANNULEE" TO WS-MOTIF
            MOVE ORG-REC TO COMPTE-REC
            REWRITE COMPTE-REC
            MOVE ORG-REC TO SRC-REC
        END-IF
    END-IF.

*> Controle de fraude sur une sortie (WS-FRD-CPT / CLI / PLAFOND renseignes).
*> 96 : plafond depasse, refus ; 97 : alerte ecrite mais autorise ;
*> toute autre erreur (fichier) : refus par prudence.
CONTROLE-FRAUDE.
    CALL "FRAUDE" USING WS-FRD-ACTION WS-FRD-CPT WS-FRD-CLI LK-MONTANT
                        WS-FRD-PLAFOND WS-FRD-STATUS
    EVALUATE WS-FRD-STATUS
        WHEN "00"
            CONTINUE
        WHEN "97"
            CONTINUE
        WHEN "96"
            MOVE "96" TO LK-STATUS
            MOVE "PLAFOND JOURNALIER DEPASSE" TO WS-MOTIF
        WHEN OTHER
            MOVE WS-FRD-STATUS TO LK-STATUS
            MOVE "ERREUR CONTROLE FRAUDE" TO WS-MOTIF
    END-EVALUATE.

JOURNALISER.
    INITIALIZE TRX-REC
    MOVE LK-ACTION TO TRX-TYPE
    *> comptes concernes et solde de chacun juste apres l'operation
    *> (solde actuel, inchange, si l'operation est refusee)
    EVALUATE LK-ACTION
        WHEN "D"
            MOVE LK-CPT-NUM TO TRX-CPT-DST
            IF WS-LU = "O"
                MOVE CPT-SOLDE TO TRX-SOLDE-DST
            END-IF
        WHEN "R"
            MOVE LK-CPT-NUM TO TRX-CPT-SRC
            IF WS-LU = "O"
                MOVE CPT-SOLDE TO TRX-SOLDE-SRC
            END-IF
        WHEN "V"
            MOVE LK-CPT-NUM TO TRX-CPT-SRC
            MOVE LK-DST TO TRX-CPT-DST
            IF WS-LU = "O"
                MOVE SRC-SOLDE TO TRX-SOLDE-SRC
            END-IF
            IF WS-LU-DST = "O"
                IF LK-STATUS = "00"
                    MOVE DST-SOLDE TO TRX-SOLDE-DST
                ELSE
                    MOVE WS-DST-AVANT TO TRX-SOLDE-DST
                END-IF
            END-IF
    END-EVALUATE
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

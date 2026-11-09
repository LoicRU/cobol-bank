*> PARAM.cob - lecture du fichier de parametres (CLE=valeur)
*>
*> Appel : CALL "PARAM" USING LK-PARAMS-REC LK-STATUS
*>   LK-PARAMS-REC : parametres (copybook PARAMS.cpy), toujours remplis ;
*>                   une cle absente garde sa valeur par defaut
*>   LK-STATUS :
*>     00 ok (fichier absent = valeurs par defaut)
*>     61 valeur invalide ou hors limites   62 cle inconnue
*>     63 ligne mal formee (pas exactement un "=")
*>     autre : FILE STATUS d'une erreur d'entree/sortie
*> Le traitement s'arrete a la premiere erreur : l'appelant doit refuser
*> de continuer avec une configuration douteuse.
*>
*> Cles (valeur par defaut, limites) :
*>   PLAFOND_DEFAUT   1000.00  0.01 a 9999999.99
*>   FACTEUR_ANOMALIE 5        entier 1 a 99
*>   MIN_HISTORIQUE   3        entier 1 a 99
*>   TAUX_ANNUEL_PCT  1.50     0 a 100 (2 decimales)
*>   FRAIS_TENUE      2.00     0 a 99999.99
*>   MAX_ECHECS_PIN   3        entier 1 a 99
*>   ALERTE_ECHECS    2        entier 2 a 99
*>   FENETRE_ECHECS_SEC 300    entier 1 a 86400
*> Fichier : variable d'environnement PARAMS_FILE, sinon
*> config/parametres.cfg
IDENTIFICATION DIVISION.
PROGRAM-ID. PARAM.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-PARAM ASSIGN TO DYNAMIC WS-FILENAME
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS.

DATA DIVISION.
FILE SECTION.
FD F-PARAM.
01 PARAM-LIGNE         PIC X(200).

WORKING-STORAGE SECTION.
01 WS-FS               PIC XX.
01 WS-FILENAME         PIC X(100).
01 WS-FIN              PIC X.
01 WS-LIGNE            PIC X(200).
01 WS-CLE              PIC X(40).
01 WS-VAL              PIC X(40).
01 WS-NB-EGAL          PIC 9(3).
01 WS-NUM              PIC S9(9)V9(6).
01 WS-DEC-MAX          PIC 9.
01 WS-MIN-V            PIC S9(9)V9(6).
01 WS-MAX-V            PIC S9(9)V9(6).
01 WS-OK               PIC X.

LINKAGE SECTION.
COPY "PARAMS.cpy" REPLACING LEADING ==PRM-== BY ==LK-PRM-==
                            ==PARAMS-REC== BY ==LK-PARAMS-REC==.
01 LK-STATUS           PIC XX.

PROCEDURE DIVISION USING LK-PARAMS-REC LK-STATUS.
MAIN-PARA.
    MOVE "00" TO LK-STATUS
    PERFORM VALEURS-PAR-DEFAUT
    MOVE "config/parametres.cfg" TO WS-FILENAME
    ACCEPT WS-FILENAME FROM ENVIRONMENT "PARAMS_FILE"
        ON EXCEPTION MOVE "config/parametres.cfg" TO WS-FILENAME
    END-ACCEPT

    OPEN INPUT F-PARAM
    EVALUATE WS-FS
        WHEN "00"
            MOVE "N" TO WS-FIN
            PERFORM UNTIL WS-FIN = "O" OR LK-STATUS NOT = "00"
                READ F-PARAM
                    AT END
                        MOVE "O" TO WS-FIN
                    NOT AT END
                        MOVE PARAM-LIGNE TO WS-LIGNE
                        PERFORM TRAITER-LIGNE
                END-READ
            END-PERFORM
            CLOSE F-PARAM
        WHEN "35"
            CONTINUE
        WHEN OTHER
            MOVE WS-FS TO LK-STATUS
    END-EVALUATE
    GOBACK.

VALEURS-PAR-DEFAUT.
    MOVE 1000.00 TO LK-PRM-PLAFOND-DEFAUT
    MOVE 5 TO LK-PRM-FACTEUR
    MOVE 3 TO LK-PRM-MIN-HISTORIQUE
    MOVE 0.0150 TO LK-PRM-TAUX-ANNUEL
    MOVE 2.00 TO LK-PRM-FRAIS-TENUE
    MOVE 3 TO LK-PRM-MAX-ECHECS
    MOVE 2 TO LK-PRM-ALERTE-ECHECS
    MOVE 300 TO LK-PRM-FENETRE-SEC.

*> Ignore lignes vides et commentaires ; sinon CLE=valeur
TRAITER-LIGNE.
    IF FUNCTION TRIM(WS-LIGNE) = SPACES
       OR FUNCTION TRIM(WS-LIGNE)(1:1) = "#"
        CONTINUE
    ELSE
        MOVE 0 TO WS-NB-EGAL
        INSPECT WS-LIGNE TALLYING WS-NB-EGAL FOR ALL "="
        IF WS-NB-EGAL NOT = 1
            MOVE "63" TO LK-STATUS
        ELSE
            MOVE SPACES TO WS-CLE WS-VAL
            UNSTRING WS-LIGNE DELIMITED BY "=" INTO WS-CLE WS-VAL
            MOVE FUNCTION UPPER-CASE(FUNCTION TRIM(WS-CLE)) TO WS-CLE
            MOVE FUNCTION TRIM(WS-VAL) TO WS-VAL
            INSPECT WS-VAL REPLACING ALL "," BY "."
            PERFORM APPLIQUER-CLE
        END-IF
    END-IF.

APPLIQUER-CLE.
    MOVE 0 TO WS-DEC-MAX
    EVALUATE WS-CLE
        WHEN "PLAFOND_DEFAUT"
            MOVE 2 TO WS-DEC-MAX
            MOVE 0.01 TO WS-MIN-V
            MOVE 9999999.99 TO WS-MAX-V
        WHEN "FACTEUR_ANOMALIE"
            MOVE 1 TO WS-MIN-V
            MOVE 99 TO WS-MAX-V
        WHEN "MIN_HISTORIQUE"
            MOVE 1 TO WS-MIN-V
            MOVE 99 TO WS-MAX-V
        WHEN "TAUX_ANNUEL_PCT"
            MOVE 2 TO WS-DEC-MAX
            MOVE 0 TO WS-MIN-V
            MOVE 100 TO WS-MAX-V
        WHEN "FRAIS_TENUE"
            MOVE 2 TO WS-DEC-MAX
            MOVE 0 TO WS-MIN-V
            MOVE 99999.99 TO WS-MAX-V
        WHEN "MAX_ECHECS_PIN"
            MOVE 1 TO WS-MIN-V
            MOVE 99 TO WS-MAX-V
        WHEN "ALERTE_ECHECS"
            MOVE 2 TO WS-MIN-V
            MOVE 99 TO WS-MAX-V
        WHEN "FENETRE_ECHECS_SEC"
            MOVE 1 TO WS-MIN-V
            MOVE 86400 TO WS-MAX-V
        WHEN OTHER
            MOVE "62" TO LK-STATUS
    END-EVALUATE
    IF LK-STATUS = "00"
        PERFORM LIRE-NOMBRE
        IF WS-OK = "O"
            EVALUATE WS-CLE
                WHEN "PLAFOND_DEFAUT"
                    MOVE WS-NUM TO LK-PRM-PLAFOND-DEFAUT
                WHEN "FACTEUR_ANOMALIE"
                    MOVE WS-NUM TO LK-PRM-FACTEUR
                WHEN "MIN_HISTORIQUE"
                    MOVE WS-NUM TO LK-PRM-MIN-HISTORIQUE
                WHEN "TAUX_ANNUEL_PCT"
                    COMPUTE LK-PRM-TAUX-ANNUEL = WS-NUM / 100
                WHEN "FRAIS_TENUE"
                    MOVE WS-NUM TO LK-PRM-FRAIS-TENUE
                WHEN "MAX_ECHECS_PIN"
                    MOVE WS-NUM TO LK-PRM-MAX-ECHECS
                WHEN "ALERTE_ECHECS"
                    MOVE WS-NUM TO LK-PRM-ALERTE-ECHECS
                WHEN "FENETRE_ECHECS_SEC"
                    MOVE WS-NUM TO LK-PRM-FENETRE-SEC
            END-EVALUATE
        ELSE
            MOVE "61" TO LK-STATUS
        END-IF
    END-IF.

*> WS-VAL -> WS-NUM ; WS-OK = "O" si nombre valide, au plus WS-DEC-MAX
*> decimales et compris entre WS-MIN-V et WS-MAX-V
LIRE-NOMBRE.
    MOVE "N" TO WS-OK
    IF FUNCTION TEST-NUMVAL(WS-VAL) = 0
        COMPUTE WS-NUM = FUNCTION NUMVAL(WS-VAL)
            ON SIZE ERROR
                MOVE 0 TO WS-NUM
                EXIT PARAGRAPH
        END-COMPUTE
        IF WS-NUM >= WS-MIN-V AND WS-NUM <= WS-MAX-V
            IF WS-DEC-MAX = 0
                IF FUNCTION MOD(WS-NUM, 1) = 0
                    MOVE "O" TO WS-OK
                END-IF
            ELSE
                IF FUNCTION MOD(WS-NUM * 100, 1) = 0
                    MOVE "O" TO WS-OK
                END-IF
            END-IF
        END-IF
    END-IF.

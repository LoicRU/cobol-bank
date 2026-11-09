*> AUTH.cob - clients et authentification par PIN
*>
*> Appel : CALL "AUTH" USING LK-ACTION LK-CLIENT-REC LK-PIN LK-NEW-PIN
*>                           LK-STATUS
*>   LK-ACTION :
*>     "C" creer un client   (LK-CLI-ID, LK-CLI-NOM, LK-CLI-ROLE, LK-PIN)
*>     "L" connexion         (LK-CLI-ID, LK-PIN) ; renvoie nom, role, statut
*>                           dans LK-CLIENT-REC (sel et empreinte mis a 0)
*>     "D" debloquer         (LK-CLI-ID) ; l'appelant verifie que l'utilisateur
*>                           est administrateur
*>     "P" changer le PIN    (LK-CLI-ID, ancien LK-PIN, nouveau LK-NEW-PIN)
*>   LK-PIN, LK-NEW-PIN : 4 a 6 chiffres, cadres a gauche, complete d'espaces
*>   LK-STATUS :
*>     00 ok                         22 identifiant deja existant
*>     23 identifiant introuvable    81 identifiant ou PIN incorrect
*>     82 client bloque              83 PIN invalide (4 a 6 chiffres)
*>     99 action inconnue            autre : FILE STATUS d'une erreur d'E/S
*>
*> Regles : 3 echecs consecutifs bloquent le client ; un succes remet le
*> compteur a zero ; un client bloque est refuse meme avec le bon PIN.
*> Un identifiant inconnu et un mauvais PIN donnent le meme code (81).
*>
*> ATTENTION - empreinte du PIN : elle est calculee en COBOL pur (sel propre
*> a chaque client, 2000 tours de melange arithmetique). C'est pedagogique,
*> PAS du SHA-256 : ne pas l'utiliser pour de vrais secrets.
*> Fichier : variable d'environnement CLIENTS_FILE, sinon data/CLIENTS.dat
IDENTIFICATION DIVISION.
PROGRAM-ID. AUTH.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-CLIENTS ASSIGN TO DYNAMIC WS-FILENAME
        ORGANIZATION IS INDEXED
        ACCESS MODE IS DYNAMIC
        RECORD KEY IS CLI-ID
        FILE STATUS IS WS-FS.

DATA DIVISION.
FILE SECTION.
FD F-CLIENTS.
COPY "CLIENT.cpy".

WORKING-STORAGE SECTION.
01 WS-FS           PIC XX.
01 WS-FILENAME     PIC X(100).
01 WS-MAX-ECHECS   PIC 9(2) VALUE 3.
01 WS-TOURS        PIC 9(5) VALUE 2000.
01 WS-MULT         PIC 9(16) VALUE 6364136223846793.
01 WS-PREMIER      PIC 9(18) VALUE 999999999999999989.
01 WS-H            PIC 9(18).
01 WS-C            PIC 9(5).
01 WS-I            PIC 9(5).
01 WS-J            PIC 9.
01 WS-PIN-IN       PIC X(6).
01 WS-SALT-IN      PIC 9(9).
01 WS-HASH-OUT     PIC 9(18).
01 WS-LEN          PIC 9.
01 WS-PIN-OK       PIC X.
01 WS-TIME         PIC 9(8).

LINKAGE SECTION.
01 LK-ACTION       PIC X.
COPY "CLIENT.cpy" REPLACING LEADING ==CLI-== BY ==LK-CLI-==
                            ==CLIENT-REC== BY ==LK-CLIENT-REC==.
01 LK-PIN          PIC X(6).
01 LK-NEW-PIN      PIC X(6).
01 LK-STATUS       PIC XX.

PROCEDURE DIVISION USING LK-ACTION LK-CLIENT-REC LK-PIN LK-NEW-PIN
                         LK-STATUS.
MAIN-PARA.
    MOVE "data/CLIENTS.dat" TO WS-FILENAME
    ACCEPT WS-FILENAME FROM ENVIRONMENT "CLIENTS_FILE"
        ON EXCEPTION MOVE "data/CLIENTS.dat" TO WS-FILENAME
    END-ACCEPT

    PERFORM OUVRIR-FICHIER
    IF WS-FS NOT = "00"
        MOVE WS-FS TO LK-STATUS
        GOBACK
    END-IF

    EVALUATE LK-ACTION
        WHEN "C" PERFORM CREER-CLIENT
        WHEN "L" PERFORM CONNEXION
        WHEN "D" PERFORM DEBLOQUER
        WHEN "P" PERFORM CHANGER-PIN
        WHEN OTHER MOVE "99" TO LK-STATUS
    END-EVALUATE

    CLOSE F-CLIENTS
    GOBACK.

OUVRIR-FICHIER.
    OPEN I-O F-CLIENTS
    IF WS-FS = "35"
        *> fichier absent : on le cree vide puis on le rouvre
        OPEN OUTPUT F-CLIENTS
        CLOSE F-CLIENTS
        OPEN I-O F-CLIENTS
    END-IF.

CREER-CLIENT.
    MOVE LK-PIN TO WS-PIN-IN
    PERFORM VALIDER-PIN
    IF WS-PIN-OK NOT = "O"
        MOVE "83" TO LK-STATUS
    ELSE
        INITIALIZE CLIENT-REC
        MOVE LK-CLI-ID TO CLI-ID
        MOVE LK-CLI-NOM TO CLI-NOM
        IF LK-CLI-ROLE = "A"
            MOVE "A" TO CLI-ROLE
        ELSE
            MOVE "C" TO CLI-ROLE
        END-IF
        PERFORM NOUVEAU-SEL-ET-HASH
        MOVE 0 TO CLI-ECHECS
        MOVE "A" TO CLI-STATUT
        WRITE CLIENT-REC
        MOVE WS-FS TO LK-STATUS
    END-IF.

CONNEXION.
    MOVE LK-CLI-ID TO CLI-ID
    READ F-CLIENTS KEY IS CLI-ID
    IF WS-FS = "00"
        MOVE LK-PIN TO WS-PIN-IN
        PERFORM VERIFIER-PIN
        IF LK-STATUS = "00"
            MOVE CLIENT-REC TO LK-CLIENT-REC
            MOVE 0 TO LK-CLI-SEL
            MOVE 0 TO LK-CLI-PIN-HASH
        END-IF
    ELSE
        IF WS-FS = "23"
            MOVE "81" TO LK-STATUS
        ELSE
            MOVE WS-FS TO LK-STATUS
        END-IF
    END-IF.

DEBLOQUER.
    MOVE LK-CLI-ID TO CLI-ID
    READ F-CLIENTS KEY IS CLI-ID
    IF WS-FS = "00"
        MOVE 0 TO CLI-ECHECS
        MOVE "A" TO CLI-STATUT
        REWRITE CLIENT-REC
    END-IF
    MOVE WS-FS TO LK-STATUS.

CHANGER-PIN.
    MOVE LK-CLI-ID TO CLI-ID
    READ F-CLIENTS KEY IS CLI-ID
    IF WS-FS NOT = "00"
        MOVE WS-FS TO LK-STATUS
    ELSE
        MOVE LK-PIN TO WS-PIN-IN
        PERFORM VERIFIER-PIN
        IF LK-STATUS = "00"
            MOVE LK-NEW-PIN TO WS-PIN-IN
            PERFORM VALIDER-PIN
            IF WS-PIN-OK NOT = "O"
                MOVE "83" TO LK-STATUS
            ELSE
                PERFORM NOUVEAU-SEL-ET-HASH
                REWRITE CLIENT-REC
                MOVE WS-FS TO LK-STATUS
            END-IF
        END-IF
    END-IF.

*> Verifie WS-PIN-IN contre le client lu (CLIENT-REC) et tient les compteurs
VERIFIER-PIN.
    IF CLI-BLOQUE
        MOVE "82" TO LK-STATUS
    ELSE
        MOVE CLI-SEL TO WS-SALT-IN
        PERFORM CALCULER-HASH
        IF WS-HASH-OUT = CLI-PIN-HASH
            MOVE "00" TO LK-STATUS
            IF CLI-ECHECS NOT = 0
                MOVE 0 TO CLI-ECHECS
                REWRITE CLIENT-REC
                IF WS-FS NOT = "00"
                    MOVE WS-FS TO LK-STATUS
                END-IF
            END-IF
        ELSE
            ADD 1 TO CLI-ECHECS
            IF CLI-ECHECS >= WS-MAX-ECHECS
                MOVE "B" TO CLI-STATUT
                MOVE "82" TO LK-STATUS
            ELSE
                MOVE "81" TO LK-STATUS
            END-IF
            REWRITE CLIENT-REC
            IF WS-FS NOT = "00"
                MOVE WS-FS TO LK-STATUS
            END-IF
        END-IF
    END-IF.

*> WS-PIN-OK = "O" si WS-PIN-IN fait 4 a 6 chiffres suivis d'espaces
VALIDER-PIN.
    MOVE "O" TO WS-PIN-OK
    MOVE 0 TO WS-LEN
    INSPECT WS-PIN-IN TALLYING WS-LEN FOR CHARACTERS BEFORE INITIAL SPACE
    IF WS-LEN < 4
        MOVE "N" TO WS-PIN-OK
    ELSE
        IF WS-PIN-IN(1:WS-LEN) IS NOT NUMERIC
            MOVE "N" TO WS-PIN-OK
        END-IF
        IF WS-LEN < 6
            IF WS-PIN-IN(WS-LEN + 1:6 - WS-LEN) NOT = SPACES
                MOVE "N" TO WS-PIN-OK
            END-IF
        END-IF
    END-IF.

*> Nouveau sel (heure + identifiant) puis empreinte de WS-PIN-IN
NOUVEAU-SEL-ET-HASH.
    ACCEPT WS-TIME FROM TIME
    COMPUTE CLI-SEL = FUNCTION MOD(WS-TIME * 1000003 + CLI-ID * 7919,
                                   999999937)
    MOVE CLI-SEL TO WS-SALT-IN
    PERFORM CALCULER-HASH
    MOVE WS-HASH-OUT TO CLI-PIN-HASH.

*> Empreinte salee de WS-PIN-IN avec WS-SALT-IN -> WS-HASH-OUT (pedagogique)
CALCULER-HASH.
    MOVE WS-SALT-IN TO WS-H
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-TOURS
        PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > 6
            COMPUTE WS-C = FUNCTION ORD(WS-PIN-IN(WS-J:1)) + WS-I + WS-J
            COMPUTE WS-H = FUNCTION MOD(WS-H * WS-MULT + WS-C,
                                        WS-PREMIER)
        END-PERFORM
    END-PERFORM
    MOVE WS-H TO WS-HASH-OUT.

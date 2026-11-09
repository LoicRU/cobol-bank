*> API.cob - interface en ligne pour l'UI web (cote client uniquement)
*>
*> Lit UNE ligne sur l'entree standard :
*>     <commande> <identifiant> <pin> [parametres]
*> et repond par UNE ligne de JSON sur la sortie standard.
*> Le PIN passe par l'entree standard, jamais par les arguments (visibles
*> dans la liste des processus). Chaque appel est independant : l'identifiant
*> et le PIN sont verifies par AUTH a chaque fois.
*>
*> Commandes :
*>   connexion  id pin
*>   comptes    id pin
*>   depot      id pin compte montant
*>   retrait    id pin compte montant
*>   virement   id pin source destination montant
*>   historique id pin compte
*>   ouvrir     id pin type            (type C courant ou E epargne)
*>   inscription 0 pin nom             (sans authentification ; le nom ecrit
*>                                      les espaces en "_" ; role client)
*> Commandes administrateur (role A obligatoire, sinon 78 ; les commandes
*> ci-dessus exigent le role client, sinon 78) :
*>   admin-connexion id pin
*>   admin-clients   id pin            tous les clients (sans sel ni empreinte)
*>   admin-comptes   id pin            tous les comptes
*>   admin-alertes   id pin            les 200 dernieres alertes
*>   admin-bloquer   id pin client     (pas soi-meme : 79)
*>   admin-debloquer id pin client
*>   admin-modifier  id pin compte plafond decouvert statut   (statut A, G ou C ;
*>                                     decouvert 0 obligatoire sur epargne)
*>   admin-batch     id pin [AAAAMM]   traitement mensuel (defaut : mois courant)
*> Reponse : {"ok":true,...} ou {"ok":false,"statut":"NN"}
*> Statuts : ceux de AUTH et COMPTE, plus
*>     74 compte qui n'est pas au client   77 commande inconnue
*>     78 role non autorise (commande client refusee a un administrateur et
*>        inversement)   71 72 73 : statuts du traitement mensuel
*>     79 parametre invalide (compte ou montant)
*>     83 PIN invalide  84 nom invalide  85 trop d'inscriptions
*>     87 type invalide 88 trop de comptes
*> Montant : chiffres avec point ou virgule decimale, 2 decimales au plus.
IDENTIFICATION DIVISION.
PROGRAM-ID. API.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-CPT ASSIGN TO DYNAMIC WS-CPT-NAME
        ORGANIZATION IS INDEXED
        ACCESS MODE IS SEQUENTIAL
        RECORD KEY IS FC-NUM
        FILE STATUS IS WS-FS.
    SELECT F-TRX ASSIGN TO DYNAMIC WS-TRX-NAME
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS.
    SELECT F-CLI ASSIGN TO DYNAMIC WS-CLI-NAME
        ORGANIZATION IS INDEXED
        ACCESS MODE IS SEQUENTIAL
        RECORD KEY IS FL-ID
        FILE STATUS IS WS-FS.
    SELECT F-ALR ASSIGN TO DYNAMIC WS-ALR-NAME
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS.

DATA DIVISION.
FILE SECTION.
FD F-CPT.
COPY "COMPTE.cpy" REPLACING LEADING ==CPT-== BY ==FC-==
                            ==COMPTE-REC== BY ==FC-REC==.
FD F-TRX.
COPY "TRX.cpy" REPLACING LEADING ==TRX-== BY ==FT-==
                         ==TRX-REC== BY ==FT-REC==.
FD F-CLI.
COPY "CLIENT.cpy" REPLACING LEADING ==CLI-== BY ==FL-==
                            ==CLIENT-REC== BY ==FL-REC==.
FD F-ALR.
COPY "ALERTE.cpy" REPLACING LEADING ==ALR-== BY ==FA-==
                            ==ALERTE-REC== BY ==FA-REC==.

WORKING-STORAGE SECTION.
COPY "COMPTE.cpy".
COPY "CLIENT.cpy".
COPY "PARAMS.cpy".
COPY "BATCH.cpy".
01 WS-CLI-NAME      PIC X(100).
01 WS-ALR-NAME      PIC X(100).
01 WS-ROLE          PIC X.
01 WS-ADMIN         PIC X VALUE "N".
01 WS-P4            PIC X(32).
01 WS-PERIODE       PIC 9(6).
01 WS-AUJ           PIC 9(8).
01 WS-PLAF          PIC 9(9)V99.
01 WS-DECOUV        PIC 9(9)V99.
01 WS-STAT-NEW      PIC X.
01 WS-ED-T          PIC Z(10)9.99.
01 WS-FS            PIC XX.
01 WS-CPT-NAME      PIC X(100).
01 WS-TRX-NAME      PIC X(100).
01 WS-LIGNE         PIC X(200).
01 WS-CMD           PIC X(16).
01 WS-ID-TXT        PIC X(20).
01 WS-PIN           PIC X(6).
01 WS-PIN-TXT       PIC X(20).
01 WS-NEW-PIN       PIC X(6) VALUE SPACES.
01 WS-P1            PIC X(32).
01 WS-P2            PIC X(32).
01 WS-P3            PIC X(32).
01 WS-ACTION        PIC X.
01 WS-STATUS        PIC XX.
01 WS-MONTANT       PIC 9(9)V99.
01 WS-DST           PIC 9(10).
01 WS-SRC           PIC 9(10).
01 WS-TXT           PIC X(20).
01 WS-NUM-VAL       PIC 9(10).
01 WS-NUM-OK        PIC X.
01 WS-MONT-OK       PIC X.
01 WS-ID-CLIENT     PIC 9(6).
01 WS-FIN           PIC X.
01 WS-NB            PIC 9(5).
01 WS-N             PIC 9(5).
01 WS-DEBUT         PIC 9(5).
01 WS-PREMIER       PIC X.
01 WS-CIBLE         PIC 9(10).
01 WS-NOM           PIC X(30).
01 WS-ED-S          PIC -(9)9.99.
01 WS-ED-M          PIC Z(8)9.99.
01 WS-SOLDE-OP      PIC S9(9)V99.
01 WS-NB-MAX        PIC 9(3) VALUE 200.
01 WS-STAT-OP       PIC XX.
01 WS-ED-N         PIC Z(5)9.

PROCEDURE DIVISION.
MAIN-PARA.
    CALL "PARAM" USING PARAMS-REC WS-STATUS
    IF WS-STATUS NOT = "00"
        PERFORM REPONDRE-ERREUR
        STOP RUN
    END-IF
    MOVE "data/COMPTES.dat" TO WS-CPT-NAME
    ACCEPT WS-CPT-NAME FROM ENVIRONMENT "COMPTES_FILE"
        ON EXCEPTION MOVE "data/COMPTES.dat" TO WS-CPT-NAME
    END-ACCEPT
    MOVE "data/TRANSACTIONS.dat" TO WS-TRX-NAME
    ACCEPT WS-TRX-NAME FROM ENVIRONMENT "TRX_FILE"
        ON EXCEPTION MOVE "data/TRANSACTIONS.dat" TO WS-TRX-NAME
    END-ACCEPT

    MOVE "data/CLIENTS.dat" TO WS-CLI-NAME
    ACCEPT WS-CLI-NAME FROM ENVIRONMENT "CLIENTS_FILE"
        ON EXCEPTION MOVE "data/CLIENTS.dat" TO WS-CLI-NAME
    END-ACCEPT
    MOVE "data/ALERTES.dat" TO WS-ALR-NAME
    ACCEPT WS-ALR-NAME FROM ENVIRONMENT "ALERTES_FILE"
        ON EXCEPTION MOVE "data/ALERTES.dat" TO WS-ALR-NAME
    END-ACCEPT

    MOVE SPACES TO WS-LIGNE WS-CMD WS-ID-TXT WS-PIN-TXT
                   WS-P1 WS-P2 WS-P3 WS-P4
    ACCEPT WS-LIGNE
    UNSTRING WS-LIGNE DELIMITED BY ALL SPACE
        INTO WS-CMD WS-ID-TXT WS-PIN-TXT WS-P1 WS-P2 WS-P3 WS-P4
    END-UNSTRING

    IF WS-CMD = "inscription"
        PERFORM CMD-INSCRIPTION
        STOP RUN
    END-IF
    PERFORM AUTHENTIFIER
    *> commande admin-* : role A ; toute autre commande : role C
    IF WS-STATUS = "00"
        IF WS-CMD(1:6) = "admin-"
            MOVE "O" TO WS-ADMIN
            IF WS-ROLE NOT = "A"
                MOVE "78" TO WS-STATUS
            END-IF
        ELSE
            IF WS-ROLE NOT = "C"
                MOVE "78" TO WS-STATUS
            END-IF
        END-IF
    END-IF
    IF WS-STATUS NOT = "00"
        PERFORM REPONDRE-ERREUR
    ELSE
        EVALUATE WS-CMD
            WHEN "connexion"  PERFORM CMD-CONNEXION
            WHEN "comptes"    PERFORM CMD-COMPTES
            WHEN "depot"      PERFORM CMD-DEPOT-RETRAIT
            WHEN "retrait"    PERFORM CMD-DEPOT-RETRAIT
            WHEN "virement"   PERFORM CMD-VIREMENT
            WHEN "historique" PERFORM CMD-HISTORIQUE
            WHEN "ouvrir"     PERFORM CMD-OUVRIR
            WHEN "admin-connexion" PERFORM CMD-CONNEXION
            WHEN "admin-clients"   PERFORM CMD-ADMIN-CLIENTS
            WHEN "admin-comptes"   PERFORM CMD-COMPTES
            WHEN "admin-alertes"   PERFORM CMD-ADMIN-ALERTES
            WHEN "admin-bloquer"   PERFORM CMD-ADMIN-STATUT
            WHEN "admin-debloquer" PERFORM CMD-ADMIN-STATUT
            WHEN "admin-modifier"  PERFORM CMD-ADMIN-MODIFIER
            WHEN "admin-batch"     PERFORM CMD-ADMIN-BATCH
            WHEN OTHER
                MOVE "77" TO WS-STATUS
                PERFORM REPONDRE-ERREUR
        END-EVALUATE
    END-IF
    STOP RUN.

*> Identifiant et PIN -> AUTH "L" ; le role est garde dans WS-ROLE
AUTHENTIFIER.
    MOVE "81" TO WS-STATUS
    MOVE WS-ID-TXT TO WS-TXT
    PERFORM CONVERTIR-NUM
    IF WS-NUM-OK = "O" AND WS-NUM-VAL <= 999999
       AND FUNCTION LENGTH(FUNCTION TRIM(WS-PIN-TXT)) <= 6
        MOVE WS-NUM-VAL TO WS-ID-CLIENT
        MOVE WS-PIN-TXT TO WS-PIN
        INITIALIZE CLIENT-REC
        MOVE WS-ID-CLIENT TO CLI-ID
        MOVE "L" TO WS-ACTION
        CALL "AUTH" USING WS-ACTION CLIENT-REC WS-PIN WS-NEW-PIN
                          WS-STATUS
        IF WS-STATUS = "00"
            MOVE CLI-ROLE TO WS-ROLE
            MOVE CLI-NOM TO WS-NOM
            INSPECT WS-NOM REPLACING ALL '"' BY "'"
            INSPECT WS-NOM REPLACING ALL "\" BY "/"
        END-IF
    END-IF.

*> inscription 0 <pin> <nom_avec_underscores>
CMD-INSCRIPTION.
    IF FUNCTION LENGTH(FUNCTION TRIM(WS-PIN-TXT)) > 6
        MOVE "83" TO WS-STATUS
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    INITIALIZE CLIENT-REC
    MOVE WS-PIN-TXT TO WS-PIN
    MOVE SPACES TO CLI-NOM
    INSPECT WS-P1 REPLACING ALL "_" BY SPACE
    IF FUNCTION LENGTH(FUNCTION TRIM(WS-P1)) > 30
        MOVE "84" TO WS-STATUS
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    MOVE WS-P1 TO CLI-NOM
    MOVE "N" TO WS-ACTION
    CALL "AUTH" USING WS-ACTION CLIENT-REC WS-PIN WS-NEW-PIN WS-STATUS
    IF WS-STATUS = "00"
        MOVE CLI-ID TO WS-ED-N
        DISPLAY '{"ok":true,"id":' FUNCTION TRIM(WS-ED-N) '}'
    ELSE
        PERFORM REPONDRE-ERREUR
    END-IF.

*> ouvrir id pin type
CMD-OUVRIR.
    INITIALIZE COMPTE-REC
    MOVE WS-ID-CLIENT TO CPT-ID-CLIENT
    MOVE WS-P1(1:1) TO CPT-TYPE
    IF WS-P1(2:) NOT = SPACES
        MOVE "N" TO CPT-TYPE
    END-IF
    MOVE "N" TO WS-ACTION
    CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST WS-STATUS
    IF WS-STATUS = "00" OR WS-STATUS = "98"
        DISPLAY '{"ok":true,"statut":"' WS-STATUS '","num":"' CPT-NUM
                '","type":"' CPT-TYPE '"}'
    ELSE
        PERFORM REPONDRE-ERREUR
    END-IF.

CMD-CONNEXION.
    MOVE WS-ID-CLIENT TO WS-ED-N
    DISPLAY '{"ok":true,"id":' FUNCTION TRIM(WS-ED-N) ',"nom":"'
            FUNCTION TRIM(WS-NOM) '"}'.

CMD-COMPTES.
    MOVE "Y" TO WS-PREMIER
    DISPLAY '{"ok":true,"comptes":[' WITH NO ADVANCING
    OPEN INPUT F-CPT
    IF WS-FS = "00"
        MOVE "N" TO WS-FIN
        PERFORM UNTIL WS-FIN = "O"
            READ F-CPT NEXT RECORD
                AT END
                    MOVE "O" TO WS-FIN
                NOT AT END
                    IF WS-ADMIN = "O" OR FC-ID-CLIENT = WS-ID-CLIENT
                        PERFORM ECRIRE-COMPTE
                    END-IF
            END-READ
        END-PERFORM
        CLOSE F-CPT
    END-IF
    DISPLAY ']}'.

ECRIRE-COMPTE.
    IF WS-PREMIER = "N"
        DISPLAY "," WITH NO ADVANCING
    END-IF
    MOVE "N" TO WS-PREMIER
    DISPLAY '{"num":"' FC-NUM '"' WITH NO ADVANCING
    MOVE FC-SOLDE TO WS-ED-S
    DISPLAY ',"solde":' FUNCTION TRIM(WS-ED-S) WITH NO ADVANCING
    MOVE FC-PLAFOND TO WS-ED-M
    DISPLAY ',"plafond":' FUNCTION TRIM(WS-ED-M) WITH NO ADVANCING
    MOVE FC-DECOUVERT TO WS-ED-M
    DISPLAY ',"decouvert":' FUNCTION TRIM(WS-ED-M) WITH NO ADVANCING
    IF FC-EPARGNE
        DISPLAY ',"type":"E"' WITH NO ADVANCING
    ELSE
        DISPLAY ',"type":"C"' WITH NO ADVANCING
    END-IF
    DISPLAY ',"statut":"' FC-STATUT '","client":' WITH NO ADVANCING
    MOVE FC-ID-CLIENT TO WS-ED-N
    DISPLAY FUNCTION TRIM(WS-ED-N) '}' WITH NO ADVANCING.

*> depot / retrait : WS-P1 = compte, WS-P2 = montant
CMD-DEPOT-RETRAIT.
    MOVE WS-P1 TO WS-TXT
    PERFORM CONVERTIR-NUM
    IF WS-NUM-OK NOT = "O"
        MOVE "79" TO WS-STATUS
        PERFORM REPONDRE-ERREUR
    ELSE
        MOVE WS-NUM-VAL TO WS-SRC
        MOVE WS-P2 TO WS-TXT
        PERFORM CONVERTIR-MONTANT
        IF WS-MONT-OK NOT = "O"
            MOVE "79" TO WS-STATUS
            PERFORM REPONDRE-ERREUR
        ELSE
            PERFORM VERIFIER-PROPRIETAIRE
            IF WS-STATUS NOT = "00"
                PERFORM REPONDRE-ERREUR
            ELSE
                IF WS-CMD = "depot"
                    MOVE "D" TO WS-ACTION
                ELSE
                    MOVE "R" TO WS-ACTION
                END-IF
                MOVE 0 TO WS-DST
                CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT
                                    WS-DST WS-STATUS
                PERFORM REPONDRE-OPERATION
            END-IF
        END-IF
    END-IF.

*> virement : WS-P1 = source, WS-P2 = destination, WS-P3 = montant
CMD-VIREMENT.
    MOVE WS-P1 TO WS-TXT
    PERFORM CONVERTIR-NUM
    IF WS-NUM-OK NOT = "O"
        MOVE "79" TO WS-STATUS
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    MOVE WS-NUM-VAL TO WS-SRC
    MOVE WS-P2 TO WS-TXT
    PERFORM CONVERTIR-NUM
    IF WS-NUM-OK NOT = "O"
        MOVE "79" TO WS-STATUS
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    MOVE WS-NUM-VAL TO WS-DST
    MOVE WS-P3 TO WS-TXT
    PERFORM CONVERTIR-MONTANT
    IF WS-MONT-OK NOT = "O"
        MOVE "79" TO WS-STATUS
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    PERFORM VERIFIER-PROPRIETAIRE
    IF WS-STATUS NOT = "00"
        PERFORM REPONDRE-ERREUR
    ELSE
        MOVE "V" TO WS-ACTION
        CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST
                            WS-STATUS
        PERFORM REPONDRE-OPERATION
    END-IF.

*> Lit le compte WS-SRC ; WS-STATUS = 00 s'il appartient au client
VERIFIER-PROPRIETAIRE.
    INITIALIZE COMPTE-REC
    MOVE WS-SRC TO CPT-NUM
    MOVE "L" TO WS-ACTION
    CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST WS-STATUS
    IF WS-STATUS = "00" AND CPT-ID-CLIENT NOT = WS-ID-CLIENT
        MOVE "74" TO WS-STATUS
    END-IF.

*> Apres D / R / V : le solde de la source est relu (COMPTE-REC peut etre
*> perime) puis la reponse est ecrite. 98 = operation faite, historique non
*> ecrit : traite comme un succes avec avertissement.
REPONDRE-OPERATION.
    IF WS-STATUS = "00" OR WS-STATUS = "98"
        MOVE WS-STATUS TO WS-STAT-OP
        INITIALIZE COMPTE-REC
        MOVE WS-SRC TO CPT-NUM
        MOVE "L" TO WS-ACTION
        CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST
                            WS-STATUS
        MOVE CPT-SOLDE TO WS-ED-S
        DISPLAY '{"ok":true,"statut":"' WS-STAT-OP '","solde":'
                FUNCTION TRIM(WS-ED-S) '}'
    ELSE
        PERFORM REPONDRE-ERREUR
    END-IF.

CMD-HISTORIQUE.
    MOVE WS-P1 TO WS-TXT
    PERFORM CONVERTIR-NUM
    IF WS-NUM-OK NOT = "O"
        MOVE "79" TO WS-STATUS
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    MOVE WS-NUM-VAL TO WS-SRC
    MOVE 0 TO WS-MONTANT WS-DST
    PERFORM VERIFIER-PROPRIETAIRE
    IF WS-STATUS NOT = "00"
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    MOVE WS-SRC TO WS-CIBLE
    *> premier passage : nombre d'operations du compte
    MOVE 0 TO WS-NB
    OPEN INPUT F-TRX
    IF WS-FS = "00"
        MOVE "N" TO WS-FIN
        PERFORM UNTIL WS-FIN = "O"
            READ F-TRX
                AT END MOVE "O" TO WS-FIN
                NOT AT END
                    IF FT-CPT-SRC = WS-CIBLE OR FT-CPT-DST = WS-CIBLE
                        ADD 1 TO WS-NB
                    END-IF
            END-READ
        END-PERFORM
        CLOSE F-TRX
    END-IF
    *> deuxieme passage : les WS-NB-MAX dernieres
    IF WS-NB > WS-NB-MAX
        COMPUTE WS-DEBUT = WS-NB - WS-NB-MAX
    ELSE
        MOVE 0 TO WS-DEBUT
    END-IF
    MOVE 0 TO WS-N
    MOVE "Y" TO WS-PREMIER
    MOVE WS-NB TO WS-ED-N
    DISPLAY '{"ok":true,"total":' FUNCTION TRIM(WS-ED-N)
            ',"operations":[' WITH NO ADVANCING
    OPEN INPUT F-TRX
    IF WS-FS = "00"
        MOVE "N" TO WS-FIN
        PERFORM UNTIL WS-FIN = "O"
            READ F-TRX
                AT END MOVE "O" TO WS-FIN
                NOT AT END
                    IF FT-CPT-SRC = WS-CIBLE OR FT-CPT-DST = WS-CIBLE
                        ADD 1 TO WS-N
                        IF WS-N > WS-DEBUT
                            PERFORM ECRIRE-OPERATION
                        END-IF
                    END-IF
            END-READ
        END-PERFORM
        CLOSE F-TRX
    END-IF
    DISPLAY ']}'.

ECRIRE-OPERATION.
    IF WS-PREMIER = "N"
        DISPLAY "," WITH NO ADVANCING
    END-IF
    MOVE "N" TO WS-PREMIER
    IF FT-CPT-SRC = WS-CIBLE
        MOVE FT-SOLDE-SRC TO WS-SOLDE-OP
    ELSE
        MOVE FT-SOLDE-DST TO WS-SOLDE-OP
    END-IF
    MOVE FT-MONTANT TO WS-ED-M
    DISPLAY '{"date":"' FT-DATE '","heure":"' FT-HEURE '","type":"'
            FT-TYPE '","src":"' FT-CPT-SRC '","dst":"' FT-CPT-DST
            '","montant":' FUNCTION TRIM(WS-ED-M) WITH NO ADVANCING
    MOVE WS-SOLDE-OP TO WS-ED-S
    DISPLAY ',"solde":' FUNCTION TRIM(WS-ED-S) ',"statut":"'
            FT-STATUT '","motif":"' FUNCTION TRIM(FT-MOTIF) '"}'
            WITH NO ADVANCING.

*> admin-clients : tous les clients, sans sel ni empreinte
CMD-ADMIN-CLIENTS.
    MOVE "Y" TO WS-PREMIER
    DISPLAY '{"ok":true,"clients":[' WITH NO ADVANCING
    OPEN INPUT F-CLI
    IF WS-FS = "00"
        MOVE "N" TO WS-FIN
        PERFORM UNTIL WS-FIN = "O"
            READ F-CLI NEXT RECORD
                AT END
                    MOVE "O" TO WS-FIN
                NOT AT END
                    PERFORM ECRIRE-CLIENT
            END-READ
        END-PERFORM
        CLOSE F-CLI
    END-IF
    DISPLAY ']}'.

ECRIRE-CLIENT.
    IF WS-PREMIER = "N"
        DISPLAY "," WITH NO ADVANCING
    END-IF
    MOVE "N" TO WS-PREMIER
    MOVE FL-NOM TO WS-NOM
    INSPECT WS-NOM REPLACING ALL '"' BY "'"
    INSPECT WS-NOM REPLACING ALL "\" BY "/"
    MOVE FL-ID TO WS-ED-N
    DISPLAY '{"id":' FUNCTION TRIM(WS-ED-N) ',"nom":"'
            FUNCTION TRIM(WS-NOM) '","role":"' FL-ROLE '","statut":"'
            FL-STATUT '"}' WITH NO ADVANCING.

*> admin-alertes : les WS-NB-MAX dernieres alertes
CMD-ADMIN-ALERTES.
    MOVE 0 TO WS-NB
    OPEN INPUT F-ALR
    IF WS-FS = "00"
        MOVE "N" TO WS-FIN
        PERFORM UNTIL WS-FIN = "O"
            READ F-ALR
                AT END MOVE "O" TO WS-FIN
                NOT AT END ADD 1 TO WS-NB
            END-READ
        END-PERFORM
        CLOSE F-ALR
    END-IF
    IF WS-NB > WS-NB-MAX
        COMPUTE WS-DEBUT = WS-NB - WS-NB-MAX
    ELSE
        MOVE 0 TO WS-DEBUT
    END-IF
    MOVE 0 TO WS-N
    MOVE "Y" TO WS-PREMIER
    MOVE WS-NB TO WS-ED-N
    DISPLAY '{"ok":true,"total":' FUNCTION TRIM(WS-ED-N)
            ',"alertes":[' WITH NO ADVANCING
    OPEN INPUT F-ALR
    IF WS-FS = "00"
        MOVE "N" TO WS-FIN
        PERFORM UNTIL WS-FIN = "O"
            READ F-ALR
                AT END MOVE "O" TO WS-FIN
                NOT AT END
                    ADD 1 TO WS-N
                    IF WS-N > WS-DEBUT
                        PERFORM ECRIRE-ALERTE
                    END-IF
            END-READ
        END-PERFORM
        CLOSE F-ALR
    END-IF
    DISPLAY ']}'.

ECRIRE-ALERTE.
    IF WS-PREMIER = "N"
        DISPLAY "," WITH NO ADVANCING
    END-IF
    MOVE "N" TO WS-PREMIER
    MOVE FA-DETAIL TO WS-NOM
    INSPECT WS-NOM REPLACING ALL '"' BY "'"
    INSPECT WS-NOM REPLACING ALL "\" BY "/"
    MOVE FA-MONTANT TO WS-ED-M
    DISPLAY '{"date":"' FA-DATE '","heure":"' FA-HEURE '","regle":"'
            FUNCTION TRIM(FA-REGLE) '","client":' WITH NO ADVANCING
    MOVE FA-ID-CLIENT TO WS-ED-N
    DISPLAY FUNCTION TRIM(WS-ED-N) ',"compte":"' FA-CPT '","montant":'
            FUNCTION TRIM(WS-ED-M) ',"detail":"' FUNCTION TRIM(WS-NOM)
            '"}' WITH NO ADVANCING.

*> admin-bloquer / admin-debloquer : WS-P1 = identifiant du client
CMD-ADMIN-STATUT.
    MOVE WS-P1 TO WS-TXT
    PERFORM CONVERTIR-NUM
    IF WS-NUM-OK NOT = "O" OR WS-NUM-VAL > 999999 OR WS-NUM-VAL = 0
        MOVE "79" TO WS-STATUS
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    IF WS-CMD = "admin-bloquer" AND WS-NUM-VAL = WS-ID-CLIENT
        MOVE "79" TO WS-STATUS
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    INITIALIZE CLIENT-REC
    MOVE WS-NUM-VAL TO CLI-ID
    IF WS-CMD = "admin-bloquer"
        MOVE "B" TO WS-ACTION
    ELSE
        MOVE "D" TO WS-ACTION
    END-IF
    CALL "AUTH" USING WS-ACTION CLIENT-REC WS-PIN WS-NEW-PIN WS-STATUS
    IF WS-STATUS = "00"
        DISPLAY '{"ok":true,"statut":"00"}'
    ELSE
        PERFORM REPONDRE-ERREUR
    END-IF.

*> admin-modifier : WS-P1 compte, WS-P2 plafond, WS-P3 decouvert, WS-P4 statut
CMD-ADMIN-MODIFIER.
    MOVE WS-P1 TO WS-TXT
    PERFORM CONVERTIR-NUM
    IF WS-NUM-OK NOT = "O"
        MOVE "79" TO WS-STATUS
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    MOVE WS-NUM-VAL TO WS-SRC
    MOVE WS-P2 TO WS-TXT
    PERFORM CONVERTIR-MONTANT-ZERO
    IF WS-MONT-OK NOT = "O"
        MOVE "79" TO WS-STATUS
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    MOVE WS-MONTANT TO WS-PLAF
    MOVE WS-P3 TO WS-TXT
    PERFORM CONVERTIR-MONTANT-ZERO
    IF WS-MONT-OK NOT = "O"
        MOVE "79" TO WS-STATUS
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    MOVE WS-MONTANT TO WS-DECOUV
    IF WS-P4(2:) NOT = SPACES
       OR (WS-P4(1:1) NOT = "A" AND WS-P4(1:1) NOT = "G"
           AND WS-P4(1:1) NOT = "C")
        MOVE "79" TO WS-STATUS
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    MOVE WS-P4(1:1) TO WS-STAT-NEW
    INITIALIZE COMPTE-REC
    MOVE WS-SRC TO CPT-NUM
    MOVE "L" TO WS-ACTION
    CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST WS-STATUS
    IF WS-STATUS NOT = "00"
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    IF CPT-EPARGNE AND WS-DECOUV > 0
        MOVE "79" TO WS-STATUS
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    MOVE WS-PLAF TO CPT-PLAFOND
    MOVE WS-DECOUV TO CPT-DECOUVERT
    MOVE WS-STAT-NEW TO CPT-STATUT
    MOVE "U" TO WS-ACTION
    CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST WS-STATUS
    IF WS-STATUS = "00"
        DISPLAY '{"ok":true,"statut":"00"}'
    ELSE
        PERFORM REPONDRE-ERREUR
    END-IF.

*> admin-batch : WS-P1 = periode AAAAMM (facultative)
CMD-ADMIN-BATCH.
    ACCEPT WS-AUJ FROM DATE YYYYMMDD
    COMPUTE WS-PERIODE = WS-AUJ / 100
    IF WS-P1 NOT = SPACES
        MOVE WS-P1 TO WS-TXT
        PERFORM CONVERTIR-NUM
        IF WS-NUM-OK = "O" AND WS-NUM-VAL <= 999999
            MOVE WS-NUM-VAL TO WS-PERIODE
        ELSE
            MOVE 0 TO WS-PERIODE
        END-IF
    END-IF
    CALL "SYSTEM" USING "mkdir -p data reports"
    CALL "BATCH-INT" USING WS-PERIODE BATCH-REC WS-STATUS
    IF WS-STATUS NOT = "00"
        PERFORM REPONDRE-ERREUR
        EXIT PARAGRAPH
    END-IF
    DISPLAY '{"ok":true,"periode":"' WS-PERIODE '","actifs":'
            WITH NO ADVANCING
    MOVE BAT-NB-ACTIFS TO WS-ED-N
    DISPLAY FUNCTION TRIM(WS-ED-N) ',"interets":' WITH NO ADVANCING
    MOVE BAT-NB-INTERETS TO WS-ED-N
    DISPLAY FUNCTION TRIM(WS-ED-N) ',"total_interets":' WITH NO ADVANCING
    MOVE BAT-TOT-INTERETS TO WS-ED-T
    DISPLAY FUNCTION TRIM(WS-ED-T) ',"frais":' WITH NO ADVANCING
    MOVE BAT-NB-FRAIS TO WS-ED-N
    DISPLAY FUNCTION TRIM(WS-ED-N) ',"total_frais":' WITH NO ADVANCING
    MOVE BAT-TOT-FRAIS TO WS-ED-T
    DISPLAY FUNCTION TRIM(WS-ED-T) ',"refuses":' WITH NO ADVANCING
    MOVE BAT-NB-FRAIS-REFUSES TO WS-ED-N
    DISPLAY FUNCTION TRIM(WS-ED-N) ',"agios":' WITH NO ADVANCING
    MOVE BAT-NB-AGIOS TO WS-ED-N
    DISPLAY FUNCTION TRIM(WS-ED-N) ',"total_agios":' WITH NO ADVANCING
    MOVE BAT-TOT-AGIOS TO WS-ED-T
    DISPLAY FUNCTION TRIM(WS-ED-T) ',"anomalies":' WITH NO ADVANCING
    MOVE BAT-NB-ANOMALIES TO WS-ED-N
    DISPLAY FUNCTION TRIM(WS-ED-N) '}'.

REPONDRE-ERREUR.
    DISPLAY '{"ok":false,"statut":"' WS-STATUS '"}'.

*> WS-TXT -> WS-NUM-VAL ; WS-NUM-OK = "O" si 1 a 10 chiffres
CONVERTIR-NUM.
    MOVE "N" TO WS-NUM-OK
    MOVE 0 TO WS-NUM-VAL
    IF FUNCTION TRIM(WS-TXT) NOT = SPACES
       AND FUNCTION LENGTH(FUNCTION TRIM(WS-TXT)) <= 10
        IF FUNCTION TRIM(WS-TXT) IS NUMERIC
            MOVE FUNCTION NUMVAL(WS-TXT) TO WS-NUM-VAL
            MOVE "O" TO WS-NUM-OK
        END-IF
    END-IF.

*> WS-TXT -> WS-MONTANT ; WS-MONT-OK = "O" si 0 <= montant < 10 millions
CONVERTIR-MONTANT-ZERO.
    MOVE "N" TO WS-MONT-OK
    INSPECT WS-TXT REPLACING ALL "," BY "."
    IF FUNCTION TEST-NUMVAL(WS-TXT) = 0
        IF FUNCTION NUMVAL(WS-TXT) >= 0
           AND FUNCTION NUMVAL(WS-TXT) < 10000000
           AND FUNCTION MOD(FUNCTION NUMVAL(WS-TXT) * 100, 1) = 0
            MOVE FUNCTION NUMVAL(WS-TXT) TO WS-MONTANT
            MOVE "O" TO WS-MONT-OK
        END-IF
    END-IF.

*> WS-TXT -> WS-MONTANT ; WS-MONT-OK = "O" si > 0, < 1 milliard, 2 decimales
CONVERTIR-MONTANT.
    MOVE "N" TO WS-MONT-OK
    INSPECT WS-TXT REPLACING ALL "," BY "."
    IF FUNCTION TEST-NUMVAL(WS-TXT) = 0
        IF FUNCTION NUMVAL(WS-TXT) > 0
           AND FUNCTION NUMVAL(WS-TXT) < 1000000000
           AND FUNCTION MOD(FUNCTION NUMVAL(WS-TXT) * 100, 1) = 0
            MOVE FUNCTION NUMVAL(WS-TXT) TO WS-MONTANT
            MOVE "O" TO WS-MONT-OK
        END-IF
    END-IF.

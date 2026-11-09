*> BANQUE.cob - programme principal : connexion et menus client / admin
*>
*> Premier lancement (aucun client) : creation de l'administrateur (id 1).
*> Menu client : comptes, depot, retrait, virement, historique, releve, PIN.
*> Menu admin  : creer client, ouvrir compte, debloquer, alertes, batch
*>               mensuel, releve de n'importe quel compte, PIN.
*> Toute la logique metier est dans les modules (AUTH, COMPTE, RELEVE,
*> BATCH-INT, FRAUDE) ; ici : saisie, controle de role et d'appartenance,
*> affichage.
*> Fichiers : memes variables d'environnement que les modules (CLIENTS_FILE,
*>   COMPTES_FILE, TRX_FILE, ALERTES_FILE) ; data/ et reports/ sont crees
*>   au besoin.
IDENTIFICATION DIVISION.
PROGRAM-ID. BANQUE.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-CPT ASSIGN TO DYNAMIC WS-CPT-NAME
        ORGANIZATION IS INDEXED
        ACCESS MODE IS SEQUENTIAL
        RECORD KEY IS FC-NUM
        FILE STATUS IS WS-FS.
    SELECT F-CLI ASSIGN TO DYNAMIC WS-CLI-NAME
        ORGANIZATION IS INDEXED
        ACCESS MODE IS SEQUENTIAL
        RECORD KEY IS FL-ID
        FILE STATUS IS WS-FS.
    SELECT F-TRX ASSIGN TO DYNAMIC WS-TRX-NAME
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS.
    SELECT F-ALR ASSIGN TO DYNAMIC WS-ALR-NAME
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS.

DATA DIVISION.
FILE SECTION.
FD F-CPT.
COPY "COMPTE.cpy" REPLACING LEADING ==CPT-== BY ==FC-==
                            ==COMPTE-REC== BY ==FC-REC==.
FD F-CLI.
COPY "CLIENT.cpy" REPLACING LEADING ==CLI-== BY ==FL-==
                            ==CLIENT-REC== BY ==FL-REC==.
FD F-TRX.
COPY "TRX.cpy" REPLACING LEADING ==TRX-== BY ==FT-==
                         ==TRX-REC== BY ==FT-REC==.
FD F-ALR.
COPY "ALERTE.cpy" REPLACING LEADING ==ALR-== BY ==FA-==
                            ==ALERTE-REC== BY ==FA-REC==.

WORKING-STORAGE SECTION.
COPY "COMPTE.cpy".
COPY "CLIENT.cpy".
COPY "BATCH.cpy".
COPY "RELEVE.cpy".
COPY "PARAMS.cpy".
COPY "PROGRAMME.cpy".
01 WS-SOUS-FIN      PIC X.
01 WS-NB-OK         PIC 9(5).
01 WS-NB-KO         PIC 9(5).
01 WS-PROG-DERNIER  PIC 9(8).
01 WS-FS            PIC XX.
01 WS-CPT-NAME      PIC X(100).
01 WS-CLI-NAME      PIC X(100).
01 WS-TRX-NAME      PIC X(100).
01 WS-ALR-NAME      PIC X(100).
01 WS-STATUS        PIC XX.
01 WS-ACTION        PIC X.
01 WS-FIN           PIC X.
01 WS-CHOIX         PIC X(10).
01 WS-IN            PIC X(40).
01 WS-QUITTER       PIC X VALUE "N".
01 WS-SESSION       PIC X VALUE "N".
01 WS-VIDES         PIC 9(3) VALUE 0.
*> utilisateur connecte
01 WS-USER-ID       PIC 9(6) VALUE 0.
01 WS-USER-ROLE     PIC X VALUE SPACE.
01 WS-USER-NOM      PIC X(30).
*> saisies
01 WS-PIN           PIC X(6).
01 WS-NEW-PIN       PIC X(6).
01 WS-MONTANT       PIC 9(9)V99.
01 WS-DST           PIC 9(10).
01 WS-NUM-OK        PIC X.
01 WS-NUM-VAL       PIC 9(10).
01 WS-MONT-OK       PIC X.
01 WS-DEB           PIC 9(8).
01 WS-FIN-P         PIC 9(8).
01 WS-PERIODE       PIC 9(6).
01 WS-AUJ           PIC 9(8).
01 WS-MAX           PIC 9(10).
01 WS-NB            PIC 9(5).
01 WS-ID-CLIENT     PIC 9(6).
01 WS-ID-TROUVE     PIC X.
01 WS-FORMAT-REL    PIC X.
01 WS-EXT-REL       PIC X(4).
01 WS-RELEVE-DIR    PIC X(80).
01 WS-NB-HOMONYMES  PIC 9(3).
01 WS-NOM-CHERCHE   PIC X(40).
01 WS-CPT-CIBLE     PIC 9(10).
01 WS-PLAFOND       PIC 9(7)V99.
01 WS-DECOUVERT     PIC 9(7)V99.
01 WS-TYPE-CPT      PIC X.
01 WS-OPT           PIC X.
01 WS-OPT-VAL       PIC 9(7)V99.
01 WS-NOUV-STATUT   PIC X.
*> affichage
01 WS-ED            PIC Z(8)9.99.
01 WS-EDS           PIC -(9)9.99.
01 WS-ED2           PIC Z(10)9.99.
01 WS-ED-NB         PIC Z(6)9.
01 WS-DATE-ED       PIC X(10).
01 WS-DATE-SRC      PIC 9(8).
01 WS-HEURE-ED      PIC X(5).
01 WS-HEURE-SRC     PIC 9(6).
01 WS-LIGNE         PIC X(100).

PROCEDURE DIVISION.
MAIN-PARA.
    PERFORM PREPARER
    PERFORM PREMIER-LANCEMENT
    PERFORM UNTIL WS-QUITTER = "O"
        DISPLAY " "
        DISPLAY "=== COBOL-BANK ==="
        DISPLAY "1. Connexion"
        DISPLAY "2. Creer mon compte client"
        DISPLAY "0. Quitter"
        PERFORM LIRE-CHOIX
        EVALUATE WS-CHOIX(1:1)
            WHEN "1"
                PERFORM CONNEXION
                IF WS-SESSION = "O"
                    IF WS-USER-ROLE = "A"
                        PERFORM MENU-ADMIN
                    ELSE
                        PERFORM MENU-CLIENT
                    END-IF
                END-IF
            WHEN "2"
                PERFORM INSCRIPTION
            WHEN "0"
                MOVE "O" TO WS-QUITTER
            WHEN OTHER
                DISPLAY "Choix invalide"
        END-EVALUATE
    END-PERFORM
    DISPLAY "Au revoir."
    MOVE 0 TO RETURN-CODE
    STOP RUN.

*> ---------------------------------------------------------------
*> Initialisation
*> ---------------------------------------------------------------
PREPARER.
    CALL "CBL_CREATE_DIR" USING "data"
    CALL "CBL_CREATE_DIR" USING "reports"
    CALL "PARAM" USING PARAMS-REC WS-STATUS
    IF WS-STATUS NOT = "00"
        PERFORM MESSAGE-STATUT
        DISPLAY "Configuration refusee : corriger config/parametres.cfg"
        MOVE 1 TO RETURN-CODE
        STOP RUN
    END-IF
    MOVE "data/COMPTES.dat" TO WS-CPT-NAME
    ACCEPT WS-CPT-NAME FROM ENVIRONMENT "COMPTES_FILE"
        ON EXCEPTION MOVE "data/COMPTES.dat" TO WS-CPT-NAME
    END-ACCEPT
    MOVE "data/CLIENTS.dat" TO WS-CLI-NAME
    ACCEPT WS-CLI-NAME FROM ENVIRONMENT "CLIENTS_FILE"
        ON EXCEPTION MOVE "data/CLIENTS.dat" TO WS-CLI-NAME
    END-ACCEPT
    MOVE "data/TRANSACTIONS.dat" TO WS-TRX-NAME
    ACCEPT WS-TRX-NAME FROM ENVIRONMENT "TRX_FILE"
        ON EXCEPTION MOVE "data/TRANSACTIONS.dat" TO WS-TRX-NAME
    END-ACCEPT
    MOVE "data/ALERTES.dat" TO WS-ALR-NAME
    ACCEPT WS-ALR-NAME FROM ENVIRONMENT "ALERTES_FILE"
        ON EXCEPTION MOVE "data/ALERTES.dat" TO WS-ALR-NAME
    END-ACCEPT
    MOVE "reports" TO WS-RELEVE-DIR
    ACCEPT WS-RELEVE-DIR FROM ENVIRONMENT "RELEVE_DIR"
        ON EXCEPTION MOVE "reports" TO WS-RELEVE-DIR
    END-ACCEPT.

*> Aucun client : on cree l'administrateur (id 1)
PREMIER-LANCEMENT.
    PERFORM PROCHAIN-CLIENT
    IF WS-MAX = 0
        DISPLAY " "
        DISPLAY "Premier lancement : creation de l'administrateur."
        PERFORM SAISIR-NOM
        PERFORM SAISIR-PIN-NOUVEAU
        INITIALIZE CLIENT-REC
        MOVE 1 TO CLI-ID
        MOVE WS-IN TO CLI-NOM
        MOVE "A" TO CLI-ROLE
        MOVE "C" TO WS-ACTION
        CALL "AUTH" USING WS-ACTION CLIENT-REC WS-PIN WS-NEW-PIN
                          WS-STATUS
        IF WS-STATUS = "00"
            DISPLAY "Administrateur cree : identifiant 1"
        ELSE
            PERFORM MESSAGE-STATUT
        END-IF
    END-IF.

*> ---------------------------------------------------------------
*> Connexion
*> ---------------------------------------------------------------
CONNEXION.
    MOVE "N" TO WS-SESSION
    DISPLAY "Identifiant ou nom : " WITH NO ADVANCING
    MOVE SPACES TO WS-IN
    ACCEPT WS-IN
    MOVE "N" TO WS-ID-TROUVE
    PERFORM CONVERTIR-NUM
    IF WS-NUM-OK = "O" AND WS-NUM-VAL <= 999999
        MOVE WS-NUM-VAL TO WS-ID-CLIENT
        MOVE "O" TO WS-ID-TROUVE
    ELSE
        IF FUNCTION TRIM(WS-IN) NOT = SPACES
            PERFORM CHERCHER-PAR-NOM
            IF WS-NB-HOMONYMES > 1
                DISPLAY "Plusieurs clients portent ce nom : "
                        "saisir l'identifiant numerique."
                EXIT PARAGRAPH
            END-IF
            IF WS-NB-HOMONYMES = 1
                MOVE "O" TO WS-ID-TROUVE
            END-IF
        END-IF
    END-IF
    PERFORM SAISIR-PIN
    IF WS-ID-TROUVE NOT = "O"
        *> identifiant ou nom inconnu : meme reponse qu'un mauvais PIN
        MOVE "81" TO WS-STATUS
        PERFORM MESSAGE-STATUT
    ELSE
        INITIALIZE CLIENT-REC
        MOVE WS-ID-CLIENT TO CLI-ID
        MOVE "L" TO WS-ACTION
        CALL "AUTH" USING WS-ACTION CLIENT-REC WS-PIN WS-NEW-PIN
                          WS-STATUS
        IF WS-STATUS = "00"
            MOVE "O" TO WS-SESSION
            MOVE WS-ID-CLIENT TO WS-USER-ID
            MOVE CLI-ROLE TO WS-USER-ROLE
            MOVE CLI-NOM TO WS-USER-NOM
            DISPLAY "Bonjour " FUNCTION TRIM(WS-USER-NOM)
        ELSE
            PERFORM MESSAGE-STATUT
        END-IF
    END-IF.

*> Cherche WS-IN parmi les noms de clients (sans tenir compte de la casse) :
*> WS-NB-HOMONYMES = nombre de clients trouves, WS-ID-CLIENT = le premier
CHERCHER-PAR-NOM.
    MOVE 0 TO WS-NB-HOMONYMES
    MOVE FUNCTION UPPER-CASE(FUNCTION TRIM(WS-IN)) TO WS-NOM-CHERCHE
    OPEN INPUT F-CLI
    PERFORM CONTROLER-OUVERTURE
    IF WS-FS = "00"
        MOVE "N" TO WS-FIN
        PERFORM UNTIL WS-FIN = "O"
            READ F-CLI
                AT END
                    MOVE "O" TO WS-FIN
                NOT AT END
                    IF FUNCTION UPPER-CASE(FUNCTION TRIM(FL-NOM))
                       = WS-NOM-CHERCHE
                        ADD 1 TO WS-NB-HOMONYMES
                        IF WS-NB-HOMONYMES = 1
                            MOVE FL-ID TO WS-ID-CLIENT
                        END-IF
                    END-IF
            END-READ
        END-PERFORM
        CLOSE F-CLI
    END-IF.

*> ---------------------------------------------------------------
*> Menu client
*> ---------------------------------------------------------------
MENU-CLIENT.
    PERFORM UNTIL WS-SESSION NOT = "O"
        DISPLAY " "
        DISPLAY "--- Menu client ---"
        DISPLAY "1. Mes comptes"
        DISPLAY "2. Depot"
        DISPLAY "3. Retrait"
        DISPLAY "4. Virement"
        DISPLAY "5. Historique d'un compte"
        DISPLAY "6. Releve de compte"
        DISPLAY "7. Changer mon PIN"
        DISPLAY "8. Ouvrir un compte"
        DISPLAY "9. Virements programmes"
        DISPLAY "0. Deconnexion"
        PERFORM LIRE-CHOIX
        EVALUATE WS-CHOIX(1:1)
            WHEN "9" PERFORM MENU-PROGRAMMES
            WHEN "8" PERFORM OUVRIR-MON-COMPTE
            WHEN "1" PERFORM LISTER-MES-COMPTES
            WHEN "2" PERFORM OPERATION-DEPOT
            WHEN "3" PERFORM OPERATION-RETRAIT
            WHEN "4" PERFORM OPERATION-VIREMENT
            WHEN "5" PERFORM VOIR-HISTORIQUE
            WHEN "6" PERFORM EDITER-RELEVE
            WHEN "7" PERFORM CHANGER-PIN
            WHEN "0" PERFORM DECONNEXION
            WHEN OTHER DISPLAY "Choix invalide"
        END-EVALUATE
    END-PERFORM.

*> ---------------------------------------------------------------
*> Virements programmes (client : les siens ; administrateur : tous)
*> ---------------------------------------------------------------
MENU-PROGRAMMES.
    MOVE "N" TO WS-SOUS-FIN
    PERFORM UNTIL WS-SOUS-FIN = "O"
        DISPLAY " "
        DISPLAY "--- Virements programmes ---"
        IF WS-USER-ROLE = "A"
            DISPLAY "1. Tous les virements programmes"
            DISPLAY "3. Annuler un virement programme"
            DISPLAY "4. Executer les echeances du jour"
        ELSE
            DISPLAY "1. Mes virements programmes"
            DISPLAY "2. Programmer un virement"
            DISPLAY "3. Annuler un virement programme"
        END-IF
        DISPLAY "0. Retour"
        PERFORM LIRE-CHOIX
        EVALUATE TRUE
            WHEN WS-CHOIX(1:1) = "1"
                PERFORM LISTER-PROGRAMMES
            WHEN WS-CHOIX(1:1) = "2" AND WS-USER-ROLE NOT = "A"
                PERFORM PROGRAMMER-VIREMENT
            WHEN WS-CHOIX(1:1) = "3"
                PERFORM ANNULER-PROGRAMME-SAISIE
            WHEN WS-CHOIX(1:1) = "4" AND WS-USER-ROLE = "A"
                PERFORM EXECUTER-ECHEANCES-ADMIN
            WHEN WS-CHOIX(1:1) = "0"
                MOVE "O" TO WS-SOUS-FIN
            WHEN OTHER
                DISPLAY "Choix invalide"
        END-EVALUATE
    END-PERFORM.

LISTER-PROGRAMMES.
    MOVE 0 TO WS-PROG-DERNIER WS-NB
    MOVE "00" TO WS-STATUS
    ACCEPT WS-AUJ FROM DATE YYYYMMDD
    PERFORM UNTIL WS-STATUS NOT = "00"
        INITIALIZE PROG-REC
        MOVE WS-PROG-DERNIER TO PRG-ID
        IF WS-USER-ROLE = "A"
            MOVE 0 TO PRG-ID-CLIENT
        ELSE
            MOVE WS-USER-ID TO PRG-ID-CLIENT
        END-IF
        MOVE "S" TO WS-ACTION
        CALL "PROG" USING WS-ACTION PROG-REC WS-AUJ WS-NB-OK WS-NB-KO
                          WS-STATUS
        IF WS-STATUS = "00"
            MOVE PRG-ID TO WS-PROG-DERNIER
            ADD 1 TO WS-NB
            PERFORM AFFICHER-PROGRAMME
        END-IF
    END-PERFORM
    IF WS-STATUS NOT = "10"
        PERFORM MESSAGE-STATUT
    ELSE
        IF WS-NB = 0
            DISPLAY "Aucun virement programme."
        END-IF
    END-IF.

AFFICHER-PROGRAMME.
    MOVE PRG-MONTANT TO WS-ED
    MOVE PRG-DATE-PROCHAINE TO WS-DATE-SRC
    PERFORM FORMATER-DATE
    DISPLAY "No " PRG-ID " : " PRG-CPT-SRC " -> " PRG-CPT-DST " "
            WS-ED " EUR, " WITH NO ADVANCING
    IF PRG-MENSUEL
        DISPLAY "chaque mois, " WITH NO ADVANCING
    ELSE
        DISPLAY "une fois, " WITH NO ADVANCING
    END-IF
    EVALUATE PRG-STATUT
        WHEN "A" DISPLAY "prochain le " WS-DATE-ED WITH NO ADVANCING
        WHEN "T" DISPLAY "termine" WITH NO ADVANCING
        WHEN "X" DISPLAY "annule" WITH NO ADVANCING
        WHEN OTHER DISPLAY "arrete (refus " PRG-DERNIER ")"
                           WITH NO ADVANCING
    END-EVALUATE
    MOVE PRG-NB-EXEC TO WS-ED-NB
    DISPLAY ", " FUNCTION TRIM(WS-ED-NB) " execution(s)"
    IF PRG-ACTIF AND PRG-DERNIER NOT = SPACES AND PRG-DERNIER NOT = "00"
        DISPLAY "     dernier essai refuse (code " PRG-DERNIER
                "), nouvel essai a la prochaine execution"
    END-IF.

PROGRAMMER-VIREMENT.
    PERFORM SAISIR-COMPTE-PROPRE
    IF WS-STATUS NOT = "00"
        EXIT PARAGRAPH
    END-IF
    INITIALIZE PROG-REC
    MOVE WS-USER-ID TO PRG-ID-CLIENT
    MOVE CPT-NUM TO PRG-CPT-SRC
    DISPLAY "Compte destinataire : " WITH NO ADVANCING
    ACCEPT WS-IN
    PERFORM CONVERTIR-NUM
    IF WS-NUM-OK NOT = "O"
        DISPLAY "Numero de compte invalide"
        EXIT PARAGRAPH
    END-IF
    MOVE WS-NUM-VAL TO PRG-CPT-DST
    PERFORM SAISIR-MONTANT
    IF WS-MONT-OK NOT = "O"
        EXIT PARAGRAPH
    END-IF
    MOVE WS-MONTANT TO PRG-MONTANT
    DISPLAY "Date de la premiere echeance (AAAAMMJJ) : " WITH NO ADVANCING
    ACCEPT WS-IN
    PERFORM CONVERTIR-NUM
    IF WS-NUM-OK NOT = "O" OR WS-NUM-VAL > 99999999
        DISPLAY "Date invalide"
        EXIT PARAGRAPH
    END-IF
    MOVE WS-NUM-VAL TO PRG-DATE-PROCHAINE
    DISPLAY "Frequence (1 une fois, 2 chaque mois) [1] : "
            WITH NO ADVANCING
    MOVE SPACES TO WS-IN
    ACCEPT WS-IN
    IF WS-IN(1:1) = "2"
        MOVE "M" TO PRG-FREQ
    ELSE
        MOVE "U" TO PRG-FREQ
    END-IF
    ACCEPT WS-AUJ FROM DATE YYYYMMDD
    MOVE "N" TO WS-ACTION
    CALL "PROG" USING WS-ACTION PROG-REC WS-AUJ WS-NB-OK WS-NB-KO
                      WS-STATUS
    IF WS-STATUS = "00"
        DISPLAY "Virement programme : numero " PRG-ID
    ELSE
        PERFORM MESSAGE-STATUT
    END-IF.

ANNULER-PROGRAMME-SAISIE.
    DISPLAY "Numero du virement programme : " WITH NO ADVANCING
    ACCEPT WS-IN
    PERFORM CONVERTIR-NUM
    IF WS-NUM-OK NOT = "O" OR WS-NUM-VAL > 99999999
        DISPLAY "Numero invalide"
        EXIT PARAGRAPH
    END-IF
    INITIALIZE PROG-REC
    MOVE WS-NUM-VAL TO PRG-ID
    IF WS-USER-ROLE = "A"
        MOVE 0 TO PRG-ID-CLIENT
    ELSE
        MOVE WS-USER-ID TO PRG-ID-CLIENT
    END-IF
    MOVE "A" TO WS-ACTION
    ACCEPT WS-AUJ FROM DATE YYYYMMDD
    CALL "PROG" USING WS-ACTION PROG-REC WS-AUJ WS-NB-OK WS-NB-KO
                      WS-STATUS
    IF WS-STATUS = "00"
        DISPLAY "Virement programme annule."
    ELSE
        PERFORM MESSAGE-STATUT
    END-IF.

EXECUTER-ECHEANCES-ADMIN.
    INITIALIZE PROG-REC
    ACCEPT WS-AUJ FROM DATE YYYYMMDD
    MOVE "E" TO WS-ACTION
    CALL "PROG" USING WS-ACTION PROG-REC WS-AUJ WS-NB-OK WS-NB-KO
                      WS-STATUS
    IF WS-STATUS = "00"
        MOVE WS-NB-OK TO WS-ED-NB
        DISPLAY "Virements faits    : " WS-ED-NB
        MOVE WS-NB-KO TO WS-ED-NB
        DISPLAY "Virements refuses  : " WS-ED-NB
    ELSE
        PERFORM MESSAGE-STATUT
    END-IF.

*> Inscription libre depuis le menu de depart : role client uniquement
INSCRIPTION.
    DISPLAY "Nom : " WITH NO ADVANCING
    MOVE SPACES TO WS-IN
    ACCEPT WS-IN
    INITIALIZE CLIENT-REC
    MOVE FUNCTION TRIM(WS-IN) TO CLI-NOM
    IF FUNCTION LENGTH(FUNCTION TRIM(WS-IN)) > 30
        MOVE "84" TO WS-STATUS
        PERFORM MESSAGE-STATUT
        EXIT PARAGRAPH
    END-IF
    PERFORM SAISIR-PIN-NOUVEAU
    MOVE "N" TO WS-ACTION
    CALL "AUTH" USING WS-ACTION CLIENT-REC WS-PIN WS-NEW-PIN WS-STATUS
    IF WS-STATUS = "00"
        DISPLAY "Client cree : identifiant " CLI-ID
        DISPLAY "Connectez-vous, puis ouvrez un compte (option 8)."
    ELSE
        PERFORM MESSAGE-STATUT
    END-IF.

*> Ouverture d'un compte par le client connecte (courant ou epargne)
OUVRIR-MON-COMPTE.
    DISPLAY "Type (1 courant, 2 epargne) [1] : " WITH NO ADVANCING
    MOVE SPACES TO WS-IN
    ACCEPT WS-IN
    INITIALIZE COMPTE-REC
    EVALUATE FUNCTION TRIM(WS-IN)
        WHEN SPACES
        WHEN "1"
            MOVE "C" TO CPT-TYPE
        WHEN "2"
            MOVE "E" TO CPT-TYPE
        WHEN OTHER
            MOVE "N" TO CPT-TYPE
    END-EVALUATE
    MOVE WS-USER-ID TO CPT-ID-CLIENT
    MOVE "N" TO WS-ACTION
    CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST WS-STATUS
    IF WS-STATUS = "00"
        DISPLAY "Compte ouvert : " CPT-NUM
        IF CPT-EPARGNE
            DISPLAY "Type : epargne"
        ELSE
            DISPLAY "Type : courant"
        END-IF
    ELSE
        PERFORM MESSAGE-STATUT
    END-IF.

DECONNEXION.
    MOVE "N" TO WS-SESSION
    MOVE 0 TO WS-USER-ID
    MOVE SPACE TO WS-USER-ROLE
    DISPLAY "Deconnecte.".

LISTER-MES-COMPTES.
    MOVE 0 TO WS-NB
    OPEN INPUT F-CPT
    PERFORM CONTROLER-OUVERTURE
    IF WS-FS = "00"
        MOVE "N" TO WS-FIN
        PERFORM UNTIL WS-FIN = "O"
            READ F-CPT
                AT END
                    MOVE "O" TO WS-FIN
                NOT AT END
                    IF FC-ID-CLIENT = WS-USER-ID
                        ADD 1 TO WS-NB
                        MOVE FC-SOLDE TO WS-EDS
                        IF FC-EPARGNE
                            DISPLAY "Compte " FC-NUM "  solde " WS-EDS
                                    "  statut " FC-STATUT "  epargne"
                        ELSE
                            DISPLAY "Compte " FC-NUM "  solde " WS-EDS
                                    "  statut " FC-STATUT "  courant"
                            IF FC-DECOUVERT > 0
                                MOVE FC-DECOUVERT TO WS-ED
                                DISPLAY "   decouvert autorise " WS-ED
                            END-IF
                        END-IF
                    END-IF
            END-READ
        END-PERFORM
        CLOSE F-CPT
    END-IF
    IF WS-NB = 0
        DISPLAY "Aucun compte."
    END-IF.

OPERATION-DEPOT.
    PERFORM SAISIR-COMPTE-PROPRE
    IF WS-STATUS = "00"
        PERFORM SAISIR-MONTANT
        IF WS-MONT-OK = "O"
            MOVE "D" TO WS-ACTION
            CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST
                                WS-STATUS
            PERFORM AFFICHER-RESULTAT-OPERATION
        END-IF
    END-IF.

OPERATION-RETRAIT.
    PERFORM SAISIR-COMPTE-PROPRE
    IF WS-STATUS = "00"
        PERFORM SAISIR-MONTANT
        IF WS-MONT-OK = "O"
            MOVE "R" TO WS-ACTION
            CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST
                                WS-STATUS
            PERFORM AFFICHER-RESULTAT-OPERATION
        END-IF
    END-IF.

OPERATION-VIREMENT.
    PERFORM SAISIR-COMPTE-PROPRE
    IF WS-STATUS = "00"
        DISPLAY "Compte destinataire : " WITH NO ADVANCING
        ACCEPT WS-IN
        PERFORM CONVERTIR-NUM
        IF WS-NUM-OK NOT = "O"
            DISPLAY "Numero de compte invalide"
        ELSE
            MOVE WS-NUM-VAL TO WS-DST
            PERFORM SAISIR-MONTANT
            IF WS-MONT-OK = "O"
                MOVE "V" TO WS-ACTION
                CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT
                                    WS-DST WS-STATUS
                PERFORM AFFICHER-RESULTAT-OPERATION
            END-IF
        END-IF
    END-IF.

AFFICHER-RESULTAT-OPERATION.
    IF WS-STATUS = "00" OR WS-STATUS = "98"
        PERFORM RELIRE-SOLDE
    END-IF
    PERFORM MESSAGE-STATUT.

*> Affiche le nouveau solde du compte source (COMPTE-REC peut etre perime)
RELIRE-SOLDE.
    MOVE "L" TO WS-ACTION
    CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST WS-STATUS
    IF WS-STATUS = "00"
        MOVE CPT-SOLDE TO WS-EDS
        DISPLAY "Nouveau solde : " WS-EDS
    END-IF
    MOVE "00" TO WS-STATUS.

VOIR-HISTORIQUE.
    PERFORM SAISIR-COMPTE-PROPRE
    IF WS-STATUS = "00"
        MOVE CPT-NUM TO WS-CPT-CIBLE
        MOVE 0 TO WS-NB
        OPEN INPUT F-TRX
    PERFORM CONTROLER-OUVERTURE
        IF WS-FS = "00"
            MOVE "N" TO WS-FIN
            PERFORM UNTIL WS-FIN = "O"
                READ F-TRX
                    AT END
                        MOVE "O" TO WS-FIN
                    NOT AT END
                        IF FT-CPT-SRC = WS-CPT-CIBLE
                           OR FT-CPT-DST = WS-CPT-CIBLE
                            ADD 1 TO WS-NB
                            PERFORM AFFICHER-LIGNE-HISTORIQUE
                        END-IF
                END-READ
            END-PERFORM
            CLOSE F-TRX
        END-IF
        IF WS-NB = 0
            DISPLAY "Aucune operation."
        END-IF
    END-IF.

AFFICHER-LIGNE-HISTORIQUE.
    MOVE FT-DATE TO WS-DATE-SRC
    PERFORM FORMATER-DATE
    MOVE FT-HEURE TO WS-HEURE-SRC
    MOVE SPACES TO WS-HEURE-ED
    STRING WS-HEURE-SRC(1:2) ":" WS-HEURE-SRC(3:2)
        DELIMITED BY SIZE INTO WS-HEURE-ED
    MOVE FT-MONTANT TO WS-ED
    DISPLAY WS-DATE-ED " " WS-HEURE-ED " " FT-TYPE " " WS-ED " "
            FT-STATUT " " FT-MOTIF.

EDITER-RELEVE.
    IF WS-USER-ROLE = "A"
        MOVE 0 TO WS-ID-CLIENT
        DISPLAY "Compte : " WITH NO ADVANCING
        ACCEPT WS-IN
        PERFORM CONVERTIR-NUM
        IF WS-NUM-OK = "O"
            MOVE WS-NUM-VAL TO CPT-NUM
            MOVE "00" TO WS-STATUS
        ELSE
            DISPLAY "Numero de compte invalide"
            MOVE "99" TO WS-STATUS
        END-IF
    ELSE
        MOVE WS-USER-ID TO WS-ID-CLIENT
        PERFORM SAISIR-COMPTE-PROPRE
    END-IF
    IF WS-STATUS = "00"
        DISPLAY "Date de debut (AAAAMMJJ) : " WITH NO ADVANCING
        ACCEPT WS-IN
        PERFORM CONVERTIR-NUM
        IF WS-NUM-OK = "O" AND WS-NUM-VAL <= 99999999
            MOVE WS-NUM-VAL TO WS-DEB
            DISPLAY "Date de fin (AAAAMMJJ) : " WITH NO ADVANCING
            ACCEPT WS-IN
            PERFORM CONVERTIR-NUM
            IF WS-NUM-OK = "O" AND WS-NUM-VAL <= 99999999
                MOVE WS-NUM-VAL TO WS-FIN-P
                MOVE CPT-NUM TO WS-CPT-CIBLE
                DISPLAY "Format (1 texte, 2 CSV) [1] : "
                        WITH NO ADVANCING
                MOVE SPACES TO WS-IN
                ACCEPT WS-IN
                IF WS-IN(1:1) = "2"
                    MOVE "C" TO WS-FORMAT-REL
                ELSE
                    MOVE "T" TO WS-FORMAT-REL
                END-IF
                CALL "RELEVE" USING WS-ID-CLIENT WS-CPT-CIBLE WS-DEB
                                    WS-FIN-P WS-FORMAT-REL RELEVE-RES
                                    WS-STATUS
                PERFORM AFFICHER-RESULTAT-RELEVE
            ELSE
                DISPLAY "Date invalide"
            END-IF
        ELSE
            DISPLAY "Date invalide"
        END-IF
    END-IF.

AFFICHER-RESULTAT-RELEVE.
    IF WS-STATUS = "00" OR WS-STATUS = "75"
        MOVE REL-NB-OPS TO WS-ED-NB
        DISPLAY "Operations : " WS-ED-NB
        MOVE REL-SOLDE-INIT TO WS-EDS
        DISPLAY "Solde initial : " WS-EDS
        MOVE REL-TOT-CREDITS TO WS-ED2
        DISPLAY "Total credits : " WS-ED2
        MOVE REL-TOT-DEBITS TO WS-ED2
        DISPLAY "Total debits  : " WS-ED2
        MOVE REL-SOLDE-FIN TO WS-EDS
        DISPLAY "Solde final   : " WS-EDS
        IF WS-FORMAT-REL = "C"
            MOVE ".csv" TO WS-EXT-REL
        ELSE
            MOVE ".txt" TO WS-EXT-REL
        END-IF
        DISPLAY "Fichier : " FUNCTION TRIM(WS-RELEVE-DIR) "/RELEVE_"
                WS-CPT-CIBLE "_" WS-DEB "_" WS-FIN-P WS-EXT-REL
    END-IF
    IF WS-STATUS NOT = "00"
        PERFORM MESSAGE-STATUT
    END-IF.

CHANGER-PIN.
    DISPLAY "PIN actuel."
    PERFORM SAISIR-PIN
    PERFORM SAISIR-PIN-NOUVEAU-SEUL
    MOVE WS-USER-ID TO CLI-ID
    MOVE "P" TO WS-ACTION
    CALL "AUTH" USING WS-ACTION CLIENT-REC WS-PIN WS-NEW-PIN WS-STATUS
    IF WS-STATUS = "00"
        DISPLAY "PIN modifie."
    ELSE
        PERFORM MESSAGE-STATUT
    END-IF.

*> ---------------------------------------------------------------
*> Menu administrateur
*> ---------------------------------------------------------------
MENU-ADMIN.
    PERFORM UNTIL WS-SESSION NOT = "O"
        DISPLAY " "
        DISPLAY "--- Menu administrateur ---"
        DISPLAY "1. Creer un client"
        DISPLAY "2. Ouvrir un compte"
        DISPLAY "3. Debloquer un client"
        DISPLAY "4. Consulter les alertes"
        DISPLAY "5. Traitement mensuel (interets et frais)"
        DISPLAY "6. Releve d'un compte"
        DISPLAY "7. Changer mon PIN"
        DISPLAY "8. Modifier un compte"
        DISPLAY "9. Virements programmes"
        DISPLAY "0. Deconnexion"
        PERFORM LIRE-CHOIX
        EVALUATE WS-CHOIX(1:1)
            WHEN "9" PERFORM MENU-PROGRAMMES
            WHEN "8" PERFORM ADMIN-MODIFIER-COMPTE
            WHEN "1" PERFORM ADMIN-CREER-CLIENT
            WHEN "2" PERFORM ADMIN-OUVRIR-COMPTE
            WHEN "3" PERFORM ADMIN-DEBLOQUER
            WHEN "4" PERFORM ADMIN-ALERTES
            WHEN "5" PERFORM ADMIN-BATCH
            WHEN "6" PERFORM EDITER-RELEVE
            WHEN "7" PERFORM CHANGER-PIN
            WHEN "0" PERFORM DECONNEXION
            WHEN OTHER DISPLAY "Choix invalide"
        END-EVALUATE
    END-PERFORM.

ADMIN-CREER-CLIENT.
    IF WS-USER-ROLE NOT = "A"
        DISPLAY "Reserve a l'administrateur"
    ELSE
        PERFORM PROCHAIN-CLIENT
        PERFORM SAISIR-NOM
        INITIALIZE CLIENT-REC
        MOVE WS-IN TO CLI-NOM
        DISPLAY "Role (C client, A administrateur) [C] : "
                WITH NO ADVANCING
        ACCEPT WS-IN
        IF WS-IN(1:1) = "A" OR WS-IN(1:1) = "a"
            MOVE "A" TO CLI-ROLE
        ELSE
            MOVE "C" TO CLI-ROLE
        END-IF
        COMPUTE CLI-ID = WS-MAX + 1
        PERFORM SAISIR-PIN-NOUVEAU
        MOVE "C" TO WS-ACTION
        CALL "AUTH" USING WS-ACTION CLIENT-REC WS-PIN WS-NEW-PIN
                          WS-STATUS
        IF WS-STATUS = "00"
            DISPLAY "Client cree : identifiant " CLI-ID
        ELSE
            PERFORM MESSAGE-STATUT
        END-IF
    END-IF.

ADMIN-OUVRIR-COMPTE.
    IF WS-USER-ROLE NOT = "A"
        DISPLAY "Reserve a l'administrateur"
    ELSE
        DISPLAY "Identifiant du client : " WITH NO ADVANCING
        ACCEPT WS-IN
        PERFORM CONVERTIR-NUM
        IF WS-NUM-OK NOT = "O" OR WS-NUM-VAL > 999999
            DISPLAY "Identifiant invalide"
        ELSE
            MOVE WS-NUM-VAL TO WS-ID-CLIENT
            PERFORM VERIFIER-CLIENT-EXISTE
            IF WS-STATUS = "00"
                PERFORM SAISIR-PARAMS-COMPTE
                IF WS-OPT = "O"
                    PERFORM CREER-COMPTE
                END-IF
            ELSE
                PERFORM MESSAGE-STATUT
            END-IF
        END-IF
    END-IF.

*> Saisie du type, du plafond et du decouvert d'un nouveau compte.
*> WS-OPT = "O" si tout est valide (WS-TYPE-CPT, WS-PLAFOND, WS-DECOUVERT)
SAISIR-PARAMS-COMPTE.
    MOVE "N" TO WS-OPT
    MOVE "C" TO WS-TYPE-CPT
    MOVE 0 TO WS-PLAFOND WS-DECOUVERT
    DISPLAY "Type (1 courant, 2 epargne) [1] : " WITH NO ADVANCING
    ACCEPT WS-IN
    EVALUATE FUNCTION TRIM(WS-IN)
        WHEN SPACES
        WHEN "1"
            MOVE "C" TO WS-TYPE-CPT
            MOVE "O" TO WS-OPT
        WHEN "2"
            MOVE "E" TO WS-TYPE-CPT
            MOVE "O" TO WS-OPT
        WHEN OTHER
            DISPLAY "Type invalide"
    END-EVALUATE
    IF WS-OPT = "O"
        MOVE "N" TO WS-OPT
        DISPLAY "Plafond journalier (0 = 1000.00) : " WITH NO ADVANCING
        ACCEPT WS-IN
        PERFORM LIRE-MONTANT-ZERO-OK
        IF WS-MONT-OK = "O"
            MOVE WS-MONTANT TO WS-PLAFOND
            MOVE "O" TO WS-OPT
        ELSE
            DISPLAY "Montant invalide"
        END-IF
    END-IF
    IF WS-OPT = "O" AND WS-TYPE-CPT = "C"
        MOVE "N" TO WS-OPT
        DISPLAY "Decouvert autorise (0 = aucun) : " WITH NO ADVANCING
        ACCEPT WS-IN
        PERFORM LIRE-MONTANT-ZERO-OK
        IF WS-MONT-OK = "O"
            MOVE WS-MONTANT TO WS-DECOUVERT
            MOVE "O" TO WS-OPT
        ELSE
            DISPLAY "Montant invalide"
        END-IF
    END-IF.

*> WS-IN -> WS-MONTANT ; WS-MONT-OK = "O" si 0 <= montant <= 9999999.99
*> avec 2 decimales au plus (le zero est accepte)
LIRE-MONTANT-ZERO-OK.
    MOVE "N" TO WS-MONT-OK
    INSPECT WS-IN REPLACING ALL "," BY "."
    IF FUNCTION TEST-NUMVAL(WS-IN) = 0
        IF FUNCTION NUMVAL(WS-IN) >= 0
           AND FUNCTION NUMVAL(WS-IN) <= 9999999.99
           AND FUNCTION MOD(FUNCTION NUMVAL(WS-IN) * 100, 1) = 0
            MOVE FUNCTION NUMVAL(WS-IN) TO WS-MONTANT
            MOVE "O" TO WS-MONT-OK
        END-IF
    END-IF.

CREER-COMPTE.
    PERFORM PROCHAIN-COMPTE
    INITIALIZE COMPTE-REC
    COMPUTE CPT-NUM = WS-MAX + 1
    MOVE WS-ID-CLIENT TO CPT-ID-CLIENT
    MOVE 0 TO CPT-SOLDE
    MOVE WS-PLAFOND TO CPT-PLAFOND
    MOVE WS-TYPE-CPT TO CPT-TYPE
    MOVE WS-DECOUVERT TO CPT-DECOUVERT
    MOVE "A" TO CPT-STATUT
    ACCEPT WS-AUJ FROM DATE YYYYMMDD
    MOVE WS-AUJ TO CPT-DATE-OUV
    MOVE "C" TO WS-ACTION
    CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST WS-STATUS
    IF WS-STATUS = "00"
        DISPLAY "Compte ouvert : " CPT-NUM
        IF CPT-EPARGNE
            DISPLAY "Type : epargne"
        ELSE
            DISPLAY "Type : courant"
        END-IF
    ELSE
        PERFORM MESSAGE-STATUT
    END-IF.

*> Modification d'un compte : plafond, decouvert (courant seulement), statut.
*> Une saisie vide laisse la valeur actuelle.
ADMIN-MODIFIER-COMPTE.
    IF WS-USER-ROLE NOT = "A"
        DISPLAY "Reserve a l'administrateur"
    ELSE
        DISPLAY "Numero du compte : " WITH NO ADVANCING
        ACCEPT WS-IN
        PERFORM CONVERTIR-NUM
        IF WS-NUM-OK NOT = "O"
            DISPLAY "Numero invalide"
        ELSE
            MOVE WS-NUM-VAL TO CPT-NUM
            MOVE "L" TO WS-ACTION
            CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST
                                WS-STATUS
            IF WS-STATUS = "00"
                PERFORM MODIFIER-COMPTE-SAISIES
            ELSE
                PERFORM MESSAGE-STATUT
            END-IF
        END-IF
    END-IF.

MODIFIER-COMPTE-SAISIES.
    MOVE "O" TO WS-OPT
    MOVE CPT-PLAFOND TO WS-ED
    DISPLAY "Plafond actuel " WS-ED
            " - nouveau (vide = inchange) : " WITH NO ADVANCING
    ACCEPT WS-IN
    IF FUNCTION TRIM(WS-IN) NOT = SPACES
        PERFORM LIRE-MONTANT-ZERO-OK
        IF WS-MONT-OK = "O"
            MOVE WS-MONTANT TO CPT-PLAFOND
        ELSE
            DISPLAY "Montant invalide"
            MOVE "N" TO WS-OPT
        END-IF
    END-IF
    IF WS-OPT = "O" AND NOT CPT-EPARGNE
        MOVE CPT-DECOUVERT TO WS-ED
        DISPLAY "Decouvert actuel " WS-ED
                " - nouveau (vide = inchange) : " WITH NO ADVANCING
        ACCEPT WS-IN
        IF FUNCTION TRIM(WS-IN) NOT = SPACES
            PERFORM LIRE-MONTANT-ZERO-OK
            IF WS-MONT-OK = "O"
                MOVE WS-MONTANT TO CPT-DECOUVERT
            ELSE
                DISPLAY "Montant invalide"
                MOVE "N" TO WS-OPT
            END-IF
        END-IF
    END-IF
    IF WS-OPT = "O"
        DISPLAY "Statut actuel " CPT-STATUT
                " (A actif, G gele, C clos) - nouveau (vide = inchange) : "
                WITH NO ADVANCING
        ACCEPT WS-IN
        EVALUATE FUNCTION UPPER-CASE(FUNCTION TRIM(WS-IN))
            WHEN SPACES
                CONTINUE
            WHEN "A"
            WHEN "G"
            WHEN "C"
                MOVE FUNCTION UPPER-CASE(WS-IN(1:1)) TO CPT-STATUT
            WHEN OTHER
                DISPLAY "Statut invalide"
                MOVE "N" TO WS-OPT
        END-EVALUATE
    END-IF
    IF WS-OPT = "O"
        MOVE "U" TO WS-ACTION
        CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST
                            WS-STATUS
        IF WS-STATUS = "00"
            DISPLAY "Compte modifie."
        ELSE
            PERFORM MESSAGE-STATUT
        END-IF
    ELSE
        DISPLAY "Aucune modification."
    END-IF.

ADMIN-DEBLOQUER.
    IF WS-USER-ROLE NOT = "A"
        DISPLAY "Reserve a l'administrateur"
    ELSE
        DISPLAY "Identifiant du client a debloquer : " WITH NO ADVANCING
        ACCEPT WS-IN
        PERFORM CONVERTIR-NUM
        IF WS-NUM-OK NOT = "O" OR WS-NUM-VAL > 999999
            DISPLAY "Identifiant invalide"
        ELSE
            MOVE WS-NUM-VAL TO CLI-ID
            MOVE "D" TO WS-ACTION
            CALL "AUTH" USING WS-ACTION CLIENT-REC WS-PIN WS-NEW-PIN
                              WS-STATUS
            IF WS-STATUS = "00"
                DISPLAY "Client debloque."
            ELSE
                PERFORM MESSAGE-STATUT
            END-IF
        END-IF
    END-IF.

ADMIN-ALERTES.
    IF WS-USER-ROLE NOT = "A"
        DISPLAY "Reserve a l'administrateur"
    ELSE
        MOVE 0 TO WS-NB
        OPEN INPUT F-ALR
    PERFORM CONTROLER-OUVERTURE
        IF WS-FS = "00"
            MOVE "N" TO WS-FIN
            PERFORM UNTIL WS-FIN = "O"
                READ F-ALR
                    AT END
                        MOVE "O" TO WS-FIN
                    NOT AT END
                        ADD 1 TO WS-NB
                        PERFORM AFFICHER-ALERTE
                END-READ
            END-PERFORM
            CLOSE F-ALR
        END-IF
        IF WS-NB = 0
            DISPLAY "Aucune alerte."
        END-IF
    END-IF.

AFFICHER-ALERTE.
    MOVE FA-DATE TO WS-DATE-SRC
    PERFORM FORMATER-DATE
    MOVE FA-HEURE TO WS-HEURE-SRC
    MOVE SPACES TO WS-HEURE-ED
    STRING WS-HEURE-SRC(1:2) ":" WS-HEURE-SRC(3:2)
        DELIMITED BY SIZE INTO WS-HEURE-ED
    MOVE FA-MONTANT TO WS-ED
    DISPLAY WS-DATE-ED " " WS-HEURE-ED " " FA-REGLE
            " client " FA-ID-CLIENT " compte " FA-CPT " " WS-ED
            " " FA-DETAIL.

ADMIN-BATCH.
    IF WS-USER-ROLE NOT = "A"
        DISPLAY "Reserve a l'administrateur"
    ELSE
        ACCEPT WS-AUJ FROM DATE YYYYMMDD
        COMPUTE WS-PERIODE = WS-AUJ / 100
        DISPLAY "Periode AAAAMM (vide = " WS-PERIODE ") : "
                WITH NO ADVANCING
        ACCEPT WS-IN
        IF FUNCTION TRIM(WS-IN) NOT = SPACES
            PERFORM CONVERTIR-NUM
            IF WS-NUM-OK = "O" AND WS-NUM-VAL <= 999999
                MOVE WS-NUM-VAL TO WS-PERIODE
            ELSE
                MOVE 0 TO WS-PERIODE
            END-IF
        END-IF
        CALL "BATCH-INT" USING WS-PERIODE BATCH-REC WS-STATUS
        IF WS-STATUS = "00"
            DISPLAY "Traitement termine."
            MOVE BAT-NB-ACTIFS TO WS-ED-NB
            DISPLAY "Comptes actifs     : " WS-ED-NB
            MOVE BAT-NB-INTERETS TO WS-ED-NB
            DISPLAY "Interets credites  : " WS-ED-NB
            MOVE BAT-TOT-INTERETS TO WS-ED2
            DISPLAY "Total interets     : " WS-ED2
            MOVE BAT-NB-FRAIS TO WS-ED-NB
            DISPLAY "Frais preleves     : " WS-ED-NB
            MOVE BAT-TOT-FRAIS TO WS-ED2
            DISPLAY "Total frais        : " WS-ED2
            MOVE BAT-NB-AGIOS TO WS-ED-NB
            DISPLAY "Agios preleves     : " WS-ED-NB
            MOVE BAT-TOT-AGIOS TO WS-ED2
            DISPLAY "Total agios        : " WS-ED2
            MOVE BAT-NB-FRAIS-REFUSES TO WS-ED-NB
            DISPLAY "Frais refuses      : " WS-ED-NB
            MOVE BAT-NB-ANOMALIES TO WS-ED-NB
            DISPLAY "Anomalies          : " WS-ED-NB
        ELSE
            PERFORM MESSAGE-STATUT
        END-IF
    END-IF.

*> ---------------------------------------------------------------
*> Outils : saisie et controle
*> ---------------------------------------------------------------
LIRE-CHOIX.
    DISPLAY "Choix : " WITH NO ADVANCING
    MOVE SPACES TO WS-CHOIX
    ACCEPT WS-CHOIX
    IF WS-CHOIX = SPACES
        ADD 1 TO WS-VIDES
        IF WS-VIDES > 20
            DISPLAY "Fin de la saisie : arret."
            STOP RUN
        END-IF
    ELSE
        MOVE 0 TO WS-VIDES
    END-IF.

*> Demande un numero de compte du client connecte ; WS-STATUS = "00" si OK
*> (COMPTE-REC contient alors le compte) ; 74 si le compte n'est pas a lui
SAISIR-COMPTE-PROPRE.
    DISPLAY "Numero de compte : " WITH NO ADVANCING
    ACCEPT WS-IN
    PERFORM CONVERTIR-NUM
    IF WS-NUM-OK NOT = "O"
        DISPLAY "Numero de compte invalide"
        MOVE "99" TO WS-STATUS
    ELSE
        INITIALIZE COMPTE-REC
        MOVE WS-NUM-VAL TO CPT-NUM
        MOVE "L" TO WS-ACTION
        CALL "COMPTE" USING WS-ACTION COMPTE-REC WS-MONTANT WS-DST
                            WS-STATUS
        IF WS-STATUS = "00"
            IF CPT-ID-CLIENT NOT = WS-USER-ID
                MOVE "74" TO WS-STATUS
            END-IF
        END-IF
        IF WS-STATUS NOT = "00"
            PERFORM MESSAGE-STATUT
        END-IF
    END-IF.

SAISIR-MONTANT.
    DISPLAY "Montant : " WITH NO ADVANCING
    ACCEPT WS-IN
    PERFORM LIRE-MONTANT-TEXTE
    IF WS-MONT-OK NOT = "O"
        DISPLAY "Montant invalide"
    END-IF.

*> WS-IN -> WS-MONTANT ; WS-MONT-OK = "O" si > 0, 2 decimales max
LIRE-MONTANT-TEXTE.
    MOVE "N" TO WS-MONT-OK
    INSPECT WS-IN REPLACING ALL "," BY "."
    IF FUNCTION TEST-NUMVAL(WS-IN) = 0
        IF FUNCTION NUMVAL(WS-IN) > 0
           AND FUNCTION NUMVAL(WS-IN) < 1000000000
           AND FUNCTION MOD(FUNCTION NUMVAL(WS-IN) * 100, 1) = 0
            MOVE FUNCTION NUMVAL(WS-IN) TO WS-MONTANT
            MOVE "O" TO WS-MONT-OK
        END-IF
    END-IF.

*> WS-IN -> WS-NUM-VAL ; WS-NUM-OK = "O" si uniquement des chiffres (1 a 10)
CONVERTIR-NUM.
    MOVE "N" TO WS-NUM-OK
    MOVE 0 TO WS-NUM-VAL
    IF FUNCTION TRIM(WS-IN) NOT = SPACES
       AND FUNCTION LENGTH(FUNCTION TRIM(WS-IN)) <= 10
        IF FUNCTION TRIM(WS-IN) IS NUMERIC
            MOVE FUNCTION NUMVAL(WS-IN) TO WS-NUM-VAL
            MOVE "O" TO WS-NUM-OK
        END-IF
    END-IF.

SAISIR-NOM.
    DISPLAY "Nom : " WITH NO ADVANCING
    MOVE SPACES TO WS-IN
    ACCEPT WS-IN
    IF FUNCTION TRIM(WS-IN) = SPACES
        MOVE "SANS NOM" TO WS-IN
    END-IF.

*> Saisie des PIN : l'echo du terminal est coupe avec stty (sans effet si
*> l'entree n'est pas un terminal, par exemple dans les tests)
SAISIR-PIN.
    DISPLAY "PIN : " WITH NO ADVANCING
    MOVE SPACES TO WS-PIN
    CALL "SYSTEM" USING "stty -echo 2>/dev/null"
    ACCEPT WS-PIN
    CALL "SYSTEM" USING "stty echo 2>/dev/null"
    DISPLAY " ".

SAISIR-PIN-NOUVEAU.
    DISPLAY "Nouveau PIN (4 a 6 chiffres) : " WITH NO ADVANCING
    MOVE SPACES TO WS-PIN
    CALL "SYSTEM" USING "stty -echo 2>/dev/null"
    ACCEPT WS-PIN
    CALL "SYSTEM" USING "stty echo 2>/dev/null"
    DISPLAY " ".

SAISIR-PIN-NOUVEAU-SEUL.
    DISPLAY "Nouveau PIN (4 a 6 chiffres) : " WITH NO ADVANCING
    MOVE SPACES TO WS-NEW-PIN
    CALL "SYSTEM" USING "stty -echo 2>/dev/null"
    ACCEPT WS-NEW-PIN
    CALL "SYSTEM" USING "stty echo 2>/dev/null"
    DISPLAY " ".

*> Le client WS-ID-CLIENT existe-t-il ? (WS-STATUS 00 ou 23)
VERIFIER-CLIENT-EXISTE.
    MOVE "23" TO WS-STATUS
    OPEN INPUT F-CLI
    PERFORM CONTROLER-OUVERTURE
    IF WS-FS = "00"
        MOVE "N" TO WS-FIN
        PERFORM UNTIL WS-FIN = "O"
            READ F-CLI
                AT END
                    MOVE "O" TO WS-FIN
                NOT AT END
                    IF FL-ID = WS-ID-CLIENT
                        MOVE "00" TO WS-STATUS
                        MOVE "O" TO WS-FIN
                    END-IF
            END-READ
        END-PERFORM
        CLOSE F-CLI
    END-IF.

*> WS-MAX = plus grand identifiant client (0 si aucun)
PROCHAIN-CLIENT.
    MOVE 0 TO WS-MAX
    OPEN INPUT F-CLI
    PERFORM CONTROLER-OUVERTURE
    IF WS-FS = "00"
        MOVE "N" TO WS-FIN
        PERFORM UNTIL WS-FIN = "O"
            READ F-CLI
                AT END
                    MOVE "O" TO WS-FIN
                NOT AT END
                    IF FL-ID > WS-MAX
                        MOVE FL-ID TO WS-MAX
                    END-IF
            END-READ
        END-PERFORM
        CLOSE F-CLI
    END-IF.

*> WS-MAX = plus grand numero de compte (1000000000 si aucun)
PROCHAIN-COMPTE.
    MOVE 1000000000 TO WS-MAX
    OPEN INPUT F-CPT
    PERFORM CONTROLER-OUVERTURE
    IF WS-FS = "00"
        MOVE "N" TO WS-FIN
        PERFORM UNTIL WS-FIN = "O"
            READ F-CPT
                AT END
                    MOVE "O" TO WS-FIN
                NOT AT END
                    IF FC-NUM > WS-MAX
                        MOVE FC-NUM TO WS-MAX
                    END-IF
            END-READ
        END-PERFORM
        CLOSE F-CPT
    END-IF.

*> WS-DATE-SRC (AAAAMMJJ) -> WS-DATE-ED (AAAA-MM-JJ)
FORMATER-DATE.
    MOVE SPACES TO WS-DATE-ED
    STRING WS-DATE-SRC(1:4) "-" WS-DATE-SRC(5:2) "-" WS-DATE-SRC(7:2)
        DELIMITED BY SIZE INTO WS-DATE-ED.

*> Apres un OPEN INPUT : le fichier doit etre ouvert (00) ou absent (35,
*> traite comme vide) ; toute autre erreur arrete le programme
CONTROLER-OUVERTURE.
    IF WS-FS NOT = "00" AND WS-FS NOT = "35"
        MOVE WS-FS TO WS-STATUS
        PERFORM ERREUR-FATALE
    END-IF.

*> Erreur d'entree/sortie : message clair, arret propre (code retour 1)
ERREUR-FATALE.
    DISPLAY " "
    DISPLAY "Erreur fichier (" WS-STATUS ") : arret du programme."
    DISPLAY "Aucune donnee n'est perdue ; verifier les fichiers de data/."
    MOVE 1 TO RETURN-CODE
    STOP RUN.

*> Message en clair pour WS-STATUS
MESSAGE-STATUT.
    EVALUATE WS-STATUS
        WHEN "00" DISPLAY "Operation effectuee."
        WHEN "22" DISPLAY "Existe deja."
        WHEN "23" DISPLAY "Introuvable."
        WHEN "51" DISPLAY "Nombre maximal de virements programmes atteint."
        WHEN "52" DISPLAY "Date invalide ou passee."
        WHEN "53" DISPLAY "Frequence invalide."
        WHEN "54" DISPLAY "Virement programme introuvable."
        WHEN "55" DISPLAY "Ce virement programme n'est pas a vous."
        WHEN "56" DISPLAY "Ce virement programme n'est plus actif."
        WHEN "61" DISPLAY "Parametre invalide ou hors limites."
        WHEN "62" DISPLAY "Parametre inconnu dans le fichier."
        WHEN "63" DISPLAY "Ligne de parametres mal formee."
        WHEN "71" DISPLAY "Periode deja traitee."
        WHEN "72" DISPLAY "Periode interrompue : verification manuelle."
        WHEN "73" DISPLAY "Periode invalide."
        WHEN "74" DISPLAY "Ce compte n'est pas a vous."
        WHEN "76" DISPLAY "Format de releve invalide."
        WHEN "75" DISPLAY "Releve ecrit mais INCOHERENT : a verifier."
        WHEN "81" DISPLAY "Identifiant ou PIN incorrect."
        WHEN "82" DISPLAY "Client bloque : voir un administrateur."
        WHEN "83" DISPLAY "PIN invalide (4 a 6 chiffres)."
        WHEN "84" DISPLAY "Nom invalide (lettres, chiffres, espace, tiret, apostrophe ; 30 caracteres au plus)."
        WHEN "85" DISPLAY "Trop d'inscriptions cette heure : reessayer plus tard."
        WHEN "87" DISPLAY "Type de compte invalide."
        WHEN "88" DISPLAY "Nombre maximal de comptes atteint."
        WHEN "90" DISPLAY "Operation interdite sur un compte epargne."
        WHEN "91" DISPLAY "Montant invalide."
        WHEN "92" DISPLAY "Compte non actif."
        WHEN "93" DISPLAY "Solde insuffisant."
        WHEN "94" DISPLAY "Depassement de capacite du solde."
        WHEN "95" DISPLAY "Virement vers le meme compte."
        WHEN "96" DISPLAY "Plafond journalier depasse."
        WHEN "98" DISPLAY "Fait, mais historique non ecrit."
        WHEN "99" DISPLAY "Saisie invalide."
        WHEN OTHER PERFORM ERREUR-FATALE
    END-EVALUATE.

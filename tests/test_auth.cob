*> test_auth.cob - tests de AUTH (clients, PIN, blocage, changement de PIN)
*> Utilise tests/CLIENTS_TEST.dat, jamais data/CLIENTS.dat
IDENTIFICATION DIVISION.
PROGRAM-ID. TEST-AUTH.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-CLI ASSIGN TO "tests/CLIENTS_TEST.dat"
        ORGANIZATION IS INDEXED
        ACCESS MODE IS RANDOM
        RECORD KEY IS FT-ID
        FILE STATUS IS WS-FS-CLI.
    SELECT F-ALR ASSIGN TO "tests/ALERTES_AUTH_TEST.dat"
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS-ALR.

DATA DIVISION.
FILE SECTION.
FD F-CLI.
COPY "CLIENT.cpy" REPLACING LEADING ==CLI-== BY ==FT-==
                            ==CLIENT-REC== BY ==FT-REC==.
FD F-ALR.
COPY "ALERTE.cpy" REPLACING LEADING ==ALR-== BY ==FA-==
                            ==ALERTE-REC== BY ==FA-REC==.

WORKING-STORAGE SECTION.
COPY "CLIENT.cpy".
COPY "ALERTE.cpy" REPLACING LEADING ==ALR-== BY ==LA-==
                            ==ALERTE-REC== BY ==LA-REC==.
01 WS-FS-ALR      PIC XX.
01 WS-FIN         PIC X.
01 WS-NB-ALR      PIC 9(5).
01 WS-ID-NOUVEAU  PIC 9(6).
01 WS-NB-INSCRITS PIC 9(3).
01 WS-NB-ALR-ATT  PIC 9(5).
01 WS-REGLE-ATT   PIC X(16) VALUE "PIN_BLOQUE".
01 WS-ACTION      PIC X.
01 WS-PIN         PIC X(6).
01 WS-NEWPIN      PIC X(6).
01 WS-STATUS      PIC XX.
01 WS-ATTENDU     PIC XX.
01 WS-LIBELLE     PIC X(44).
01 WS-NB-ECHECS   PIC 9(3) VALUE 0.
01 WS-FS-CLI      PIC XX.
01 WS-ID          PIC 9(6).
01 WS-NOM         PIC X(30).
01 WS-ROLE        PIC X.
01 WS-ECHECS-ATT  PIC 9(2).
01 WS-STATUT-ATT  PIC X.
01 WS-HASH-1      PIC 9(18).
01 WS-HASH-2      PIC 9(18).

PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY "PARAMS_FILE" UPON ENVIRONMENT-NAME
    DISPLAY "tests/AUCUN_PARAMS.cfg" UPON ENVIRONMENT-VALUE
    CALL "CBL_DELETE_FILE" USING "tests/CLIENTS_TEST.dat"
    DISPLAY "CLIENTS_FILE" UPON ENVIRONMENT-NAME
    DISPLAY "tests/CLIENTS_TEST.dat" UPON ENVIRONMENT-VALUE
    CALL "CBL_DELETE_FILE" USING "tests/ALERTES_AUTH_TEST.dat"
    DISPLAY "ALERTES_FILE" UPON ENVIRONMENT-NAME
    DISPLAY "tests/ALERTES_AUTH_TEST.dat" UPON ENVIRONMENT-VALUE

    *> --- creation ---
    MOVE "C" TO WS-ACTION
    MOVE 1 TO WS-ID
    MOVE "Alice" TO WS-NOM
    MOVE "C" TO WS-ROLE
    MOVE "1234" TO WS-PIN
    MOVE "00" TO WS-ATTENDU
    MOVE "creer client 1 (PIN 1234)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    MOVE 0 TO WS-ECHECS-ATT
    MOVE "A" TO WS-STATUT-ATT
    PERFORM VERIF-ETAT

    MOVE 2 TO WS-ID
    MOVE "Bob" TO WS-NOM
    MOVE "A" TO WS-ROLE
    MOVE "creer client 2 admin (meme PIN 1234)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    MOVE 3 TO WS-ID
    MOVE "Chloe" TO WS-NOM
    MOVE "C" TO WS-ROLE
    MOVE "123456" TO WS-PIN
    MOVE "creer client 3 (PIN 6 chiffres)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    MOVE 1 TO WS-ID
    MOVE "1234" TO WS-PIN
    MOVE "22" TO WS-ATTENDU
    MOVE "creer doublon (identifiant existant)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    MOVE 4 TO WS-ID
    MOVE "12" TO WS-PIN
    MOVE "83" TO WS-ATTENDU
    MOVE "PIN trop court (refus)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    MOVE "12ab" TO WS-PIN
    MOVE "PIN non numerique (refus)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    MOVE "12 345" TO WS-PIN
    MOVE "PIN avec espace au milieu (refus)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    *> --- le PIN n'est pas stocke en clair, sel different par client ---
    MOVE 1 TO WS-ID
    PERFORM LIRE-FICHIER
    MOVE FT-PIN-HASH TO WS-HASH-1
    MOVE 2 TO WS-ID
    PERFORM LIRE-FICHIER
    MOVE FT-PIN-HASH TO WS-HASH-2
    IF WS-HASH-1 NOT = WS-HASH-2 AND WS-HASH-1 NOT = 1234
        DISPLAY "PASS meme PIN, empreintes differentes, pas en clair"
    ELSE
        DISPLAY "FAIL empreintes identiques ou PIN en clair"
        ADD 1 TO WS-NB-ECHECS
    END-IF

    *> --- connexion ---
    MOVE "L" TO WS-ACTION
    MOVE 1 TO WS-ID
    MOVE "1234" TO WS-PIN
    MOVE "00" TO WS-ATTENDU
    MOVE "connexion client 1 (bon PIN)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    IF CLI-NOM = "Alice" AND CLI-ROLE = "C" AND CLI-PIN-HASH = 0
       AND CLI-SEL = 0
        DISPLAY "  PASS nom et role renvoyes, empreinte masquee"
    ELSE
        DISPLAY "  FAIL enregistrement renvoye incorrect"
        ADD 1 TO WS-NB-ECHECS
    END-IF

    MOVE "0000" TO WS-PIN
    MOVE "81" TO WS-ATTENDU
    MOVE "mauvais PIN (1er echec)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    MOVE 1 TO WS-ECHECS-ATT
    MOVE "A" TO WS-STATUT-ATT
    PERFORM VERIF-ETAT

    MOVE "1234" TO WS-PIN
    MOVE "00" TO WS-ATTENDU
    MOVE "bon PIN : compteur remis a zero" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    MOVE 0 TO WS-ECHECS-ATT
    PERFORM VERIF-ETAT

    MOVE "0000" TO WS-PIN
    MOVE "81" TO WS-ATTENDU
    MOVE "mauvais PIN (1er echec)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    MOVE 0 TO WS-NB-ALR-ATT
    MOVE "PIN_BLOQUE" TO WS-REGLE-ATT
    PERFORM VERIF-ALERTE
    MOVE "mauvais PIN (2e echec)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    MOVE 2 TO WS-ECHECS-ATT
    PERFORM VERIF-ETAT
    MOVE 1 TO WS-NB-ALR-ATT
    MOVE "ECHECS_RAPIDES" TO WS-REGLE-ATT
    PERFORM VERIF-ALERTE

    MOVE "82" TO WS-ATTENDU
    MOVE "mauvais PIN (3e echec : bloque)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    MOVE 3 TO WS-ECHECS-ATT
    MOVE "B" TO WS-STATUT-ATT
    PERFORM VERIF-ETAT
    MOVE 2 TO WS-NB-ALR-ATT
    MOVE "PIN_BLOQUE" TO WS-REGLE-ATT
    PERFORM VERIF-ALERTE

    MOVE "1234" TO WS-PIN
    MOVE "bon PIN mais client bloque (refus)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    PERFORM VERIF-ETAT

    *> --- deblocage ---
    MOVE "D" TO WS-ACTION
    MOVE "00" TO WS-ATTENDU
    MOVE "debloquer client 1" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    MOVE 0 TO WS-ECHECS-ATT
    MOVE "A" TO WS-STATUT-ATT
    PERFORM VERIF-ETAT

    MOVE "L" TO WS-ACTION
    MOVE "connexion apres deblocage" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    MOVE 999 TO WS-ID
    MOVE "81" TO WS-ATTENDU
    MOVE "identifiant inconnu : meme code que mauvais PIN" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    MOVE "D" TO WS-ACTION
    MOVE "23" TO WS-ATTENDU
    MOVE "debloquer identifiant inconnu" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    *> --- changement de PIN (client 3 : 123456 -> 9999) ---
    MOVE "P" TO WS-ACTION
    MOVE 3 TO WS-ID
    MOVE "000000" TO WS-PIN
    MOVE "9999" TO WS-NEWPIN
    MOVE "81" TO WS-ATTENDU
    MOVE "changer PIN avec mauvais ancien PIN (refus)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    MOVE "123456" TO WS-PIN
    MOVE "12" TO WS-NEWPIN
    MOVE "83" TO WS-ATTENDU
    MOVE "changer PIN vers un PIN invalide (refus)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    MOVE "9999" TO WS-NEWPIN
    MOVE "00" TO WS-ATTENDU
    MOVE "changer PIN 123456 -> 9999" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    MOVE "L" TO WS-ACTION
    MOVE "81" TO WS-ATTENDU
    MOVE "connexion avec l'ancien PIN (refus)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    MOVE "9999" TO WS-PIN
    MOVE "00" TO WS-ATTENDU
    MOVE "connexion avec le nouveau PIN" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    MOVE "X" TO WS-ACTION
    MOVE "99" TO WS-ATTENDU
    MOVE "action inconnue" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    *> fenetre expiree : serie vieille de plusieurs annees, 2 echecs -> pas
    *> d'alerte rapprochee
    MOVE "L" TO WS-ACTION
    MOVE "0000" TO WS-PIN
    MOVE "81" TO WS-ATTENDU
    MOVE "echec 1 (nouvelle serie)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    PERFORM VIEILLIR-SERIE
    MOVE "echec 2 hors fenetre : pas d'alerte" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    MOVE 2 TO WS-NB-ALR-ATT
    MOVE "PIN_BLOQUE" TO WS-REGLE-ATT
    PERFORM VERIF-ALERTE
    MOVE "9999" TO WS-PIN
    MOVE "00" TO WS-ATTENDU
    MOVE "connexion : serie remise a zero" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    *> au total deux alertes : echecs rapides, puis blocage
    MOVE 1 TO WS-ID
    MOVE 2 TO WS-NB-ALR-ATT
    PERFORM VERIF-ALERTE

    PERFORM TEST-INSCRIPTION

    CALL "CBL_DELETE_FILE" USING "tests/CLIENTS_TEST.dat"
    CALL "CBL_DELETE_FILE" USING "tests/ALERTES_AUTH_TEST.dat"
    IF WS-NB-ECHECS = 0
        DISPLAY "TOUS LES TESTS PASSENT"
        MOVE 0 TO RETURN-CODE
    ELSE
        DISPLAY WS-NB-ECHECS " TEST(S) EN ECHEC"
        MOVE 1 TO RETURN-CODE
    END-IF
    STOP RUN.

*> Inscription libre (action N) : validations, identifiant attribue,
*> role client, connexion possible, limite horaire (20 par defaut) + alerte
TEST-INSCRIPTION.
    MOVE "N" TO WS-ACTION
    MOVE 0 TO WS-ID
    *> le role demande (A) est ignore : une inscription donne toujours un client
    MOVE "A" TO WS-ROLE
    MOVE "2468" TO WS-PIN
    MOVE "Jean-Pierre D'Arc" TO WS-NOM
    MOVE "00" TO WS-ATTENDU
    MOVE "inscription : nom avec tiret et apostrophe" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    MOVE CLI-ID TO WS-ID-NOUVEAU
    IF WS-ID-NOUVEAU > 1
        DISPLAY "  PASS identifiant attribue : " WS-ID-NOUVEAU
    ELSE
        DISPLAY "  FAIL identifiant attribue : " WS-ID-NOUVEAU
        ADD 1 TO WS-NB-ECHECS
    END-IF
    MOVE 1 TO WS-NB-INSCRITS
    MOVE "L" TO WS-ACTION
    MOVE WS-ID-NOUVEAU TO WS-ID
    MOVE "00" TO WS-ATTENDU
    MOVE "inscription : connexion avec le PIN choisi" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    IF CLI-ROLE = "C" AND CLI-NOM = "Jean-Pierre D'Arc"
        DISPLAY "  PASS inscription : role client, nom conserve"
    ELSE
        DISPLAY "  FAIL inscription : role " CLI-ROLE " nom " CLI-NOM
        ADD 1 TO WS-NB-ECHECS
    END-IF

    MOVE "N" TO WS-ACTION
    MOVE "84" TO WS-ATTENDU
    MOVE "Z<oe" TO WS-NOM
    MOVE "inscription : caractere interdit (84)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    MOVE SPACES TO WS-NOM
    MOVE "inscription : nom vide (84)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    MOVE " Zoe" TO WS-NOM
    MOVE "inscription : espace au debut (84)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    MOVE "Zoe""x" TO WS-NOM
    MOVE "inscription : guillemet (84)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    MOVE "Zoe" TO WS-NOM
    MOVE "12" TO WS-PIN
    MOVE "83" TO WS-ATTENDU
    MOVE "inscription : PIN trop court (83)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER
    MOVE "12ab" TO WS-PIN
    MOVE "inscription : PIN non numerique (83)" TO WS-LIBELLE
    PERFORM APPELER
    PERFORM VERIFIER

    *> limite : 20 inscriptions par heure (valeur par defaut)
    MOVE "2468" TO WS-PIN
    MOVE "00" TO WS-ATTENDU
    MOVE "00" TO WS-STATUS
    PERFORM UNTIL WS-STATUS NOT = "00" OR WS-NB-INSCRITS > 40
        MOVE "Client" TO WS-NOM
        PERFORM APPELER
        IF WS-STATUS = "00"
            ADD 1 TO WS-NB-INSCRITS
        END-IF
    END-PERFORM
    MOVE "85" TO WS-ATTENDU
    MOVE "inscription : 21e de l'heure refusee (85)" TO WS-LIBELLE
    PERFORM VERIFIER
    IF WS-NB-INSCRITS = 20
        DISPLAY "  PASS 20 inscriptions acceptees avant le refus"
    ELSE
        DISPLAY "  FAIL inscriptions acceptees : " WS-NB-INSCRITS
        ADD 1 TO WS-NB-ECHECS
    END-IF
    PERFORM LIRE-DERNIERE-ALERTE
    IF WS-NB-ALR = 3 AND LA-REGLE = "INSCRIPTIONS"
        DISPLAY "  PASS alerte INSCRIPTIONS ecrite"
    ELSE
        DISPLAY "  FAIL alerte : " WS-NB-ALR " " LA-REGLE
        ADD 1 TO WS-NB-ECHECS
    END-IF.

LIRE-DERNIERE-ALERTE.
    MOVE 0 TO WS-NB-ALR
    MOVE "N" TO WS-FIN
    OPEN INPUT F-ALR
    IF WS-FS-ALR = "00"
        PERFORM UNTIL WS-FIN = "O"
            READ F-ALR
                AT END MOVE "O" TO WS-FIN
                NOT AT END
                    ADD 1 TO WS-NB-ALR
                    MOVE FA-REC TO LA-REC
            END-READ
        END-PERFORM
        CLOSE F-ALR
    END-IF.

*> Appel de AUTH avec WS-ID, WS-NOM, WS-ROLE, WS-PIN, WS-NEWPIN
APPELER.
    INITIALIZE CLIENT-REC
    MOVE WS-ID TO CLI-ID
    MOVE WS-NOM TO CLI-NOM
    MOVE WS-ROLE TO CLI-ROLE
    CALL "AUTH" USING WS-ACTION CLIENT-REC WS-PIN WS-NEWPIN WS-STATUS.

VERIFIER.
    IF WS-STATUS = WS-ATTENDU
        DISPLAY "PASS " WS-LIBELLE
    ELSE
        DISPLAY "FAIL " WS-LIBELLE " (statut " WS-STATUS
                ", attendu " WS-ATTENDU ")"
        ADD 1 TO WS-NB-ECHECS
    END-IF.

*> Journal d alertes : WS-NB-ALR-ATT alerte(s), derniere WS-REGLE-ATT du client 1
VERIF-ALERTE.
    MOVE 0 TO WS-NB-ALR
    MOVE "N" TO WS-FIN
    OPEN INPUT F-ALR
    IF WS-FS-ALR = "00"
        PERFORM UNTIL WS-FIN = "O"
            READ F-ALR
                AT END MOVE "O" TO WS-FIN
                NOT AT END
                    ADD 1 TO WS-NB-ALR
                    MOVE FA-REC TO LA-REC
            END-READ
        END-PERFORM
        CLOSE F-ALR
    END-IF
    IF WS-NB-ALR = WS-NB-ALR-ATT
       AND (WS-NB-ALR = 0 OR (LA-REGLE = WS-REGLE-ATT
                              AND LA-ID-CLIENT = 1))
        DISPLAY "  PASS alerte : " WS-NB-ALR " au journal, "
                LA-REGLE " client " LA-ID-CLIENT
    ELSE
        DISPLAY "  FAIL alerte : " WS-NB-ALR " au journal, attendu "
                WS-NB-ALR-ATT
        ADD 1 TO WS-NB-ECHECS
    END-IF.

*> Recule de plusieurs annees le debut de la serie d'echecs du client WS-ID
VIEILLIR-SERIE.
    OPEN I-O F-CLI
    MOVE WS-ID TO FT-ID
    READ F-CLI KEY IS FT-ID
    MOVE 20200101 TO FT-SERIE-DATE
    REWRITE FT-REC
    CLOSE F-CLI.

*> Lit le client WS-ID directement dans le fichier
LIRE-FICHIER.
    OPEN INPUT F-CLI
    MOVE WS-ID TO FT-ID
    READ F-CLI KEY IS FT-ID
    CLOSE F-CLI.

*> Compare compteur d'echecs et statut du client WS-ID a ceux attendus
VERIF-ETAT.
    PERFORM LIRE-FICHIER
    IF FT-ECHECS = WS-ECHECS-ATT AND FT-STATUT = WS-STATUT-ATT
        DISPLAY "  PASS etat : " FT-ECHECS " echec(s), statut " FT-STATUT
    ELSE
        DISPLAY "  FAIL etat : " FT-ECHECS " echec(s), statut " FT-STATUT
                " (attendu " WS-ECHECS-ATT ", " WS-STATUT-ATT ")"
        ADD 1 TO WS-NB-ECHECS
    END-IF.

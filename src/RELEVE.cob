*> RELEVE.cob - releve de compte (fichier texte formate)
*>
*> Appel : CALL "RELEVE" USING LK-ID-CLIENT LK-CPT-NUM LK-DEBUT LK-FIN
*>                             LK-FORMAT LK-RELEVE-RES LK-STATUS
*>   LK-ID-CLIENT : client qui demande le releve ; il doit etre titulaire du
*>                  compte. 0 = administrateur, aucun controle d'appartenance
*>                  (l'appelant verifie le role).
*>   LK-DEBUT, LK-FIN : periode AAAAMMJJ, bornes incluses
*>   LK-FORMAT : "T" fichier texte formate (.txt), "C" fichier CSV (.csv,
*>               separateur ";", montants avec point decimal, sans accents)
*>   LK-RELEVE-RES : renvoie nombre d'operations, solde initial et final,
*>                   total des debits et des credits (copybook RELEVE.cpy)
*>   LK-STATUS :
*>     00 releve ecrit et coherent   23 compte introuvable
*>     73 periode invalide           74 le compte n'appartient pas au client
*>     76 format inconnu (ni "T" ni "C")
*>     75 releve ecrit mais INCOHERENT : solde initial + credits - debits
*>        est different du solde final, a verifier
*>     autre : FILE STATUS d'une erreur d'entree/sortie
*>
*> Le releve ne liste que les operations ACCEPTEES du compte dans la periode.
*> Les soldes viennent de l'historique (solde apres chaque operation) :
*>   solde initial = solde juste avant la premiere operation de la periode ;
*>   sans operation dans la periode, solde du compte a cette date (derniere
*>   operation avant, sinon premiere operation apres, sinon solde actuel).
*>   solde final = solde apres la derniere operation de la periode.
*> L'historique est lu dans l'ordre d'ecriture (chronologique).
*> Fichiers : TRX_FILE (data/TRANSACTIONS.dat), COMPTES_FILE
*>   (data/COMPTES.dat), CLIENTS_FILE (data/CLIENTS.dat),
*>   RELEVE_DIR (reports) pour le releve RELEVE_<compte>_<debut>_<fin>.txt
*>   ou .csv
IDENTIFICATION DIVISION.
PROGRAM-ID. RELEVE.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-TRX ASSIGN TO DYNAMIC WS-TRX-NAME
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS-TRX.
    SELECT F-COMPTES ASSIGN TO DYNAMIC WS-COMPTES-NAME
        ORGANIZATION IS INDEXED
        ACCESS MODE IS RANDOM
        RECORD KEY IS CPT-NUM
        FILE STATUS IS WS-FS-CPT.
    SELECT F-CLIENTS ASSIGN TO DYNAMIC WS-CLIENTS-NAME
        ORGANIZATION IS INDEXED
        ACCESS MODE IS RANDOM
        RECORD KEY IS CLI-ID
        FILE STATUS IS WS-FS-CLI.
    SELECT F-RELEVE ASSIGN TO DYNAMIC WS-RELEVE-NAME
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS-REL.

DATA DIVISION.
FILE SECTION.
FD F-TRX.
COPY "TRX.cpy".
FD F-COMPTES.
COPY "COMPTE.cpy".
FD F-CLIENTS.
COPY "CLIENT.cpy".
FD F-RELEVE.
01 RELEVE-LIGNE        PIC X(100).

WORKING-STORAGE SECTION.
01 WS-FS-TRX           PIC XX.
01 WS-FS-CPT           PIC XX.
01 WS-FS-CLI           PIC XX.
01 WS-FS-REL           PIC XX.
01 WS-TRX-NAME         PIC X(100).
01 WS-COMPTES-NAME     PIC X(100).
01 WS-CLIENTS-NAME     PIC X(100).
01 WS-RELEVE-DIR       PIC X(80).
01 WS-RELEVE-NAME      PIC X(140).
01 WS-FIN              PIC X.
01 WS-PTR              PIC 9(3).
01 WS-ED-L             PIC Z(10)9.99.
01 WS-NOM              PIC X(30).
01 WS-SOLDE-ACTUEL     PIC S9(11)V99.
01 WS-AUJOURDHUI       PIC 9(8).
*> analyse d'une ligne de l'historique
01 WS-CONCERNE         PIC X.
01 WS-CREDIT           PIC S9(11)V99.
01 WS-DEBIT            PIC S9(11)V99.
01 WS-APRES            PIC S9(11)V99.
01 WS-AVANT            PIC S9(11)V99.
01 WS-LIBELLE          PIC X(16).
01 WS-CONTRE           PIC 9(10).
*> bilan de la periode
01 WS-HAS-PERIODE      PIC X.
01 WS-HAS-AVANT        PIC X.
01 WS-HAS-APRES        PIC X.
01 WS-INIT-PER         PIC S9(11)V99.
01 WS-FIN-PER          PIC S9(11)V99.
01 WS-APRES-AVANT      PIC S9(11)V99.
01 WS-AVANT-APRES      PIC S9(11)V99.
01 WS-NB-OPS           PIC 9(7).
01 WS-TOT-DEB          PIC S9(11)V99.
01 WS-TOT-CRED         PIC S9(11)V99.
01 WS-INIT             PIC S9(11)V99.
01 WS-FINAL            PIC S9(11)V99.
01 WS-CALCULE          PIC S9(11)V99.
*> mise en page
01 WS-ED               PIC Z(8)9.99.
01 WS-ED-NB            PIC Z(6)9.
01 WS-LIGNE            PIC X(100).
01 WS-DATE-ED          PIC X(10).
01 WS-DATE-DEB         PIC X(10).
01 WS-NOM-CSV          PIC X(31).
01 WS-NOM-CSV2         PIC X(31).
01 WS-DATE-SRC         PIC 9(8).
01 WS-HEURE-SRC        PIC 9(6).
01 WS-LIGNE-OP.
   05 LO-DATE          PIC X(10).
   05 FILLER           PIC XX VALUE SPACES.
   05 LO-HEURE         PIC X(5).
   05 FILLER           PIC XX VALUE SPACES.
   05 LO-LIBELLE       PIC X(16).
   05 FILLER           PIC XX VALUE SPACES.
   05 LO-CONTRE        PIC X(10).
   05 FILLER           PIC XX VALUE SPACES.
   05 LO-DEBIT         PIC X(12).
   05 FILLER           PIC XX VALUE SPACES.
   05 LO-CREDIT        PIC X(12).
   05 FILLER           PIC XX VALUE SPACES.
   05 LO-SOLDE         PIC X(12).

LINKAGE SECTION.
01 LK-ID-CLIENT        PIC 9(6).
01 LK-CPT-NUM          PIC 9(10).
01 LK-DEBUT            PIC 9(8).
01 LK-FIN              PIC 9(8).
01 LK-FORMAT           PIC X.
COPY "RELEVE.cpy" REPLACING LEADING ==REL-== BY ==LK-REL-==
                            ==RELEVE-RES== BY ==LK-RELEVE-RES==.
01 LK-STATUS           PIC XX.

PROCEDURE DIVISION USING LK-ID-CLIENT LK-CPT-NUM LK-DEBUT LK-FIN
                         LK-FORMAT LK-RELEVE-RES LK-STATUS.
MAIN-PARA.
    MOVE "00" TO LK-STATUS
    INITIALIZE LK-RELEVE-RES
    PERFORM LIRE-ENVIRONNEMENT

    IF LK-FORMAT NOT = "T" AND LK-FORMAT NOT = "C"
        MOVE "76" TO LK-STATUS
        GOBACK
    END-IF

    IF FUNCTION TEST-DATE-YYYYMMDD(LK-DEBUT) NOT = 0
       OR FUNCTION TEST-DATE-YYYYMMDD(LK-FIN) NOT = 0
       OR LK-DEBUT > LK-FIN
        MOVE "73" TO LK-STATUS
        GOBACK
    END-IF

    PERFORM VERIFIER-COMPTE
    IF LK-STATUS NOT = "00"
        GOBACK
    END-IF

    PERFORM LIRE-TITULAIRE
    PERFORM ANALYSER-HISTORIQUE
    IF LK-STATUS NOT = "00"
        GOBACK
    END-IF

    PERFORM ECRIRE-RELEVE
    IF LK-STATUS = "00" AND LK-REL-COHERENT NOT = "O"
        MOVE "75" TO LK-STATUS
    END-IF
    GOBACK.

LIRE-ENVIRONNEMENT.
    MOVE "data/TRANSACTIONS.dat" TO WS-TRX-NAME
    ACCEPT WS-TRX-NAME FROM ENVIRONMENT "TRX_FILE"
        ON EXCEPTION MOVE "data/TRANSACTIONS.dat" TO WS-TRX-NAME
    END-ACCEPT
    MOVE "data/COMPTES.dat" TO WS-COMPTES-NAME
    ACCEPT WS-COMPTES-NAME FROM ENVIRONMENT "COMPTES_FILE"
        ON EXCEPTION MOVE "data/COMPTES.dat" TO WS-COMPTES-NAME
    END-ACCEPT
    MOVE "data/CLIENTS.dat" TO WS-CLIENTS-NAME
    ACCEPT WS-CLIENTS-NAME FROM ENVIRONMENT "CLIENTS_FILE"
        ON EXCEPTION MOVE "data/CLIENTS.dat" TO WS-CLIENTS-NAME
    END-ACCEPT
    MOVE "reports" TO WS-RELEVE-DIR
    ACCEPT WS-RELEVE-DIR FROM ENVIRONMENT "RELEVE_DIR"
        ON EXCEPTION MOVE "reports" TO WS-RELEVE-DIR
    END-ACCEPT.

*> Le compte existe et appartient bien au client demande
VERIFIER-COMPTE.
    OPEN INPUT F-COMPTES
    IF WS-FS-CPT = "35"
        MOVE "23" TO LK-STATUS
    ELSE
        IF WS-FS-CPT NOT = "00"
            MOVE WS-FS-CPT TO LK-STATUS
        ELSE
            MOVE LK-CPT-NUM TO CPT-NUM
            READ F-COMPTES KEY IS CPT-NUM
            IF WS-FS-CPT NOT = "00"
                MOVE WS-FS-CPT TO LK-STATUS
            ELSE
                IF LK-ID-CLIENT NOT = 0
                   AND LK-ID-CLIENT NOT = CPT-ID-CLIENT
                    MOVE "74" TO LK-STATUS
                ELSE
                    MOVE CPT-SOLDE TO WS-SOLDE-ACTUEL
                END-IF
            END-IF
            CLOSE F-COMPTES
        END-IF
    END-IF.

*> Nom du titulaire (WS-NOM) ; "(CLIENT INCONNU)" si introuvable
LIRE-TITULAIRE.
    MOVE "(CLIENT INCONNU)" TO WS-NOM
    OPEN INPUT F-CLIENTS
    IF WS-FS-CLI = "00"
        MOVE CPT-ID-CLIENT TO CLI-ID
        READ F-CLIENTS KEY IS CLI-ID
        IF WS-FS-CLI = "00"
            MOVE CLI-NOM TO WS-NOM
        END-IF
        CLOSE F-CLIENTS
    END-IF.

*> Premier passage : soldes, totaux et nombre d'operations de la periode
ANALYSER-HISTORIQUE.
    MOVE "N" TO WS-HAS-PERIODE
    MOVE "N" TO WS-HAS-AVANT
    MOVE "N" TO WS-HAS-APRES
    MOVE 0 TO WS-INIT-PER WS-FIN-PER WS-APRES-AVANT WS-AVANT-APRES
    MOVE 0 TO WS-NB-OPS WS-TOT-DEB WS-TOT-CRED
    MOVE "N" TO WS-FIN
    OPEN INPUT F-TRX
    EVALUATE WS-FS-TRX
        WHEN "00"
            PERFORM UNTIL WS-FIN = "O"
                READ F-TRX
                    AT END
                        MOVE "O" TO WS-FIN
                    NOT AT END
                        PERFORM EXAMINER-LIGNE
                        IF WS-CONCERNE = "O"
                            PERFORM CLASSER-OPERATION
                        END-IF
                END-READ
            END-PERFORM
            CLOSE F-TRX
        WHEN "35"
            CONTINUE
        WHEN OTHER
            MOVE WS-FS-TRX TO LK-STATUS
    END-EVALUATE

    IF LK-STATUS = "00"
        EVALUATE TRUE
            WHEN WS-HAS-PERIODE = "O"
                MOVE WS-INIT-PER TO WS-INIT
                MOVE WS-FIN-PER TO WS-FINAL
            WHEN WS-HAS-AVANT = "O"
                MOVE WS-APRES-AVANT TO WS-INIT
                MOVE WS-APRES-AVANT TO WS-FINAL
            WHEN WS-HAS-APRES = "O"
                MOVE WS-AVANT-APRES TO WS-INIT
                MOVE WS-AVANT-APRES TO WS-FINAL
            WHEN OTHER
                MOVE WS-SOLDE-ACTUEL TO WS-INIT
                MOVE WS-SOLDE-ACTUEL TO WS-FINAL
        END-EVALUATE
        COMPUTE WS-CALCULE = WS-INIT + WS-TOT-CRED - WS-TOT-DEB
        MOVE WS-NB-OPS TO LK-REL-NB-OPS
        MOVE WS-INIT TO LK-REL-SOLDE-INIT
        MOVE WS-FINAL TO LK-REL-SOLDE-FIN
        MOVE WS-TOT-DEB TO LK-REL-TOT-DEBITS
        MOVE WS-TOT-CRED TO LK-REL-TOT-CREDITS
        IF WS-CALCULE = WS-FINAL
            MOVE "O" TO LK-REL-COHERENT
        ELSE
            MOVE "N" TO LK-REL-COHERENT
        END-IF
    END-IF.

*> Analyse la ligne lue : WS-CONCERNE = "O" si c'est une operation acceptee
*> du compte ; renseigne credit, debit, solde apres/avant, libelle, contrepartie
EXAMINER-LIGNE.
    MOVE "N" TO WS-CONCERNE
    MOVE 0 TO WS-CREDIT WS-DEBIT WS-APRES WS-AVANT WS-CONTRE
    MOVE SPACES TO WS-LIBELLE
    IF TRX-STATUT = "A"
        EVALUATE TRX-TYPE
            WHEN "D"
            WHEN "I"
                IF TRX-CPT-DST = LK-CPT-NUM
                    MOVE "O" TO WS-CONCERNE
                    MOVE TRX-MONTANT TO WS-CREDIT
                    MOVE TRX-SOLDE-DST TO WS-APRES
                    IF TRX-TYPE = "D"
                        MOVE "DEPOT" TO WS-LIBELLE
                    ELSE
                        MOVE "INTERETS" TO WS-LIBELLE
                    END-IF
                END-IF
            WHEN "R"
            WHEN "F"
                IF TRX-CPT-SRC = LK-CPT-NUM
                    MOVE "O" TO WS-CONCERNE
                    MOVE TRX-MONTANT TO WS-DEBIT
                    MOVE TRX-SOLDE-SRC TO WS-APRES
                    IF TRX-TYPE = "R"
                        MOVE "RETRAIT" TO WS-LIBELLE
                    ELSE
                        MOVE "FRAIS DE TENUE" TO WS-LIBELLE
                    END-IF
                END-IF
            WHEN "V"
                IF TRX-CPT-SRC = LK-CPT-NUM
                    MOVE "O" TO WS-CONCERNE
                    MOVE TRX-MONTANT TO WS-DEBIT
                    MOVE TRX-SOLDE-SRC TO WS-APRES
                    MOVE TRX-CPT-DST TO WS-CONTRE
                    MOVE "VIREMENT EMIS" TO WS-LIBELLE
                ELSE
                    IF TRX-CPT-DST = LK-CPT-NUM
                        MOVE "O" TO WS-CONCERNE
                        MOVE TRX-MONTANT TO WS-CREDIT
                        MOVE TRX-SOLDE-DST TO WS-APRES
                        MOVE TRX-CPT-SRC TO WS-CONTRE
                        MOVE "VIREMENT RECU" TO WS-LIBELLE
                    END-IF
                END-IF
        END-EVALUATE
    END-IF
    IF WS-CONCERNE = "O"
        COMPUTE WS-AVANT = WS-APRES - WS-CREDIT + WS-DEBIT
    END-IF.

*> Range une operation du compte : avant, dans ou apres la periode
CLASSER-OPERATION.
    EVALUATE TRUE
        WHEN TRX-DATE < LK-DEBUT
            MOVE WS-APRES TO WS-APRES-AVANT
            MOVE "O" TO WS-HAS-AVANT
        WHEN TRX-DATE > LK-FIN
            IF WS-HAS-APRES NOT = "O"
                MOVE WS-AVANT TO WS-AVANT-APRES
                MOVE "O" TO WS-HAS-APRES
            END-IF
        WHEN OTHER
            IF WS-HAS-PERIODE NOT = "O"
                MOVE WS-AVANT TO WS-INIT-PER
                MOVE "O" TO WS-HAS-PERIODE
            END-IF
            MOVE WS-APRES TO WS-FIN-PER
            ADD WS-CREDIT TO WS-TOT-CRED
            ADD WS-DEBIT TO WS-TOT-DEB
            ADD 1 TO WS-NB-OPS
    END-EVALUATE.

ECRIRE-RELEVE.
    MOVE SPACES TO WS-RELEVE-NAME
    MOVE 1 TO WS-PTR
    STRING WS-RELEVE-DIR DELIMITED BY SPACE
           "/RELEVE_" DELIMITED BY SIZE
           LK-CPT-NUM DELIMITED BY SIZE
           "_" DELIMITED BY SIZE
           LK-DEBUT DELIMITED BY SIZE
           "_" DELIMITED BY SIZE
           LK-FIN DELIMITED BY SIZE
           INTO WS-RELEVE-NAME WITH POINTER WS-PTR
    IF LK-FORMAT = "C"
        STRING ".csv" DELIMITED BY SIZE
               INTO WS-RELEVE-NAME WITH POINTER WS-PTR
    ELSE
        STRING ".txt" DELIMITED BY SIZE
               INTO WS-RELEVE-NAME WITH POINTER WS-PTR
    END-IF
    OPEN OUTPUT F-RELEVE
    IF WS-FS-REL NOT = "00"
        MOVE WS-FS-REL TO LK-STATUS
    ELSE
        IF LK-FORMAT = "C"
            PERFORM ECRIRE-ENTETE-CSV
            PERFORM ECRIRE-OPERATIONS
            PERFORM ECRIRE-PIED-CSV
        ELSE
            PERFORM ECRIRE-ENTETE
            PERFORM ECRIRE-OPERATIONS
            PERFORM ECRIRE-PIED
        END-IF
        CLOSE F-RELEVE
    END-IF.

ECRIRE-ENTETE.
    MOVE "RELEVE DE COMPTE" TO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE SPACES TO WS-LIGNE
    STRING "Titulaire : " DELIMITED BY SIZE
           WS-NOM DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE SPACES TO WS-LIGNE
    STRING "Compte    : " DELIMITED BY SIZE
           LK-CPT-NUM DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE LK-DEBUT TO WS-DATE-SRC
    PERFORM FORMATER-DATE
    MOVE WS-DATE-ED TO WS-DATE-DEB
    MOVE LK-FIN TO WS-DATE-SRC
    PERFORM FORMATER-DATE
    MOVE SPACES TO WS-LIGNE
    STRING "Periode   : " DELIMITED BY SIZE
           WS-DATE-DEB DELIMITED BY SIZE
           " au " DELIMITED BY SIZE
           WS-DATE-ED DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    ACCEPT WS-AUJOURDHUI FROM DATE YYYYMMDD
    MOVE WS-AUJOURDHUI TO WS-DATE-SRC
    PERFORM FORMATER-DATE
    MOVE SPACES TO WS-LIGNE
    STRING "Edite le  : " DELIMITED BY SIZE
           WS-DATE-ED DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE SPACES TO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE WS-INIT TO WS-ED
    MOVE SPACES TO WS-LIGNE
    STRING "Solde initial : " DELIMITED BY SIZE
           WS-ED DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE SPACES TO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE SPACES TO WS-LIGNE-OP
    MOVE "Date" TO LO-DATE
    MOVE "Heure" TO LO-HEURE
    MOVE "Operation" TO LO-LIBELLE
    MOVE "Compte lie" TO LO-CONTRE
    MOVE "Debit" TO LO-DEBIT
    MOVE "Credit" TO LO-CREDIT
    MOVE "Solde" TO LO-SOLDE
    MOVE WS-LIGNE-OP TO WS-LIGNE
    PERFORM ECRIRE-LIGNE
    MOVE ALL "-" TO WS-LIGNE
    PERFORM ECRIRE-LIGNE.

*> Second passage : une ligne par operation acceptee de la periode
ECRIRE-OPERATIONS.
    MOVE "N" TO WS-FIN
    OPEN INPUT F-TRX
    IF WS-FS-TRX = "00"
        PERFORM UNTIL WS-FIN = "O"
            READ F-TRX
                AT END
                    MOVE "O" TO WS-FIN
                NOT AT END
                    PERFORM EXAMINER-LIGNE
                    IF WS-CONCERNE = "O"
                       AND TRX-DATE >= LK-DEBUT AND TRX-DATE <= LK-FIN
                        IF LK-FORMAT = "C"
                            PERFORM ECRIRE-OPERATION-CSV
                        ELSE
                            PERFORM ECRIRE-OPERATION
                        END-IF
                    END-IF
            END-READ
        END-PERFORM
        CLOSE F-TRX
    END-IF.

ECRIRE-OPERATION.
    MOVE SPACES TO WS-LIGNE-OP
    MOVE TRX-DATE TO WS-DATE-SRC
    PERFORM FORMATER-DATE
    MOVE WS-DATE-ED TO LO-DATE
    MOVE TRX-HEURE TO WS-HEURE-SRC
    STRING WS-HEURE-SRC(1:2) DELIMITED BY SIZE
           ":" DELIMITED BY SIZE
           WS-HEURE-SRC(3:2) DELIMITED BY SIZE
           INTO LO-HEURE
    MOVE WS-LIBELLE TO LO-LIBELLE
    IF WS-CONTRE NOT = 0
        MOVE WS-CONTRE TO LO-CONTRE
    END-IF
    IF WS-DEBIT NOT = 0
        MOVE WS-DEBIT TO WS-ED
        MOVE WS-ED TO LO-DEBIT
    END-IF
    IF WS-CREDIT NOT = 0
        MOVE WS-CREDIT TO WS-ED
        MOVE WS-ED TO LO-CREDIT
    END-IF
    MOVE WS-APRES TO WS-ED
    MOVE WS-ED TO LO-SOLDE
    MOVE WS-LIGNE-OP TO WS-LIGNE
    PERFORM ECRIRE-LIGNE.

ECRIRE-PIED.
    MOVE ALL "-" TO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE WS-FINAL TO WS-ED
    MOVE SPACES TO WS-LIGNE
    STRING "Solde final : " DELIMITED BY SIZE
           WS-ED DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE WS-TOT-DEB TO WS-ED
    MOVE SPACES TO WS-LIGNE
    STRING "Total debits  : " DELIMITED BY SIZE
           WS-ED DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE WS-TOT-CRED TO WS-ED
    MOVE SPACES TO WS-LIGNE
    STRING "Total credits : " DELIMITED BY SIZE
           WS-ED DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE WS-NB-OPS TO WS-ED-NB
    MOVE SPACES TO WS-LIGNE
    STRING "Operations    : " DELIMITED BY SIZE
           WS-ED-NB DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE SPACES TO WS-LIGNE
    IF LK-REL-COHERENT = "O"
        MOVE "Verification : OK" TO WS-LIGNE
    ELSE
        STRING "Verification : INCOHERENCE (solde initial + credits"
               DELIMITED BY SIZE
               " - debits different du solde final)" DELIMITED BY SIZE
               INTO WS-LIGNE
    END-IF
    PERFORM ECRIRE-LIGNE.

*> ---- format CSV : separateur ";", montants avec point, sans espaces ----
ECRIRE-ENTETE-CSV.
    *> nom : pas de ";" et pas de debut de formule (=, +, -, @) pour un tableur
    MOVE WS-NOM TO WS-NOM-CSV
    INSPECT WS-NOM-CSV REPLACING ALL ";" BY ","
    IF WS-NOM-CSV(1:1) = "=" OR "+" OR "-" OR "@"
        MOVE SPACES TO WS-NOM-CSV2
        STRING "'" DELIMITED BY SIZE
               WS-NOM-CSV DELIMITED BY SIZE INTO WS-NOM-CSV2
        MOVE WS-NOM-CSV2 TO WS-NOM-CSV
    END-IF
    MOVE SPACES TO WS-LIGNE
    STRING "Titulaire;" DELIMITED BY SIZE
           FUNCTION TRIM(WS-NOM-CSV) DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE SPACES TO WS-LIGNE
    STRING "Compte;" DELIMITED BY SIZE
           LK-CPT-NUM DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE LK-DEBUT TO WS-DATE-SRC
    PERFORM FORMATER-DATE
    MOVE SPACES TO WS-LIGNE
    STRING "Periode_debut;" DELIMITED BY SIZE
           WS-DATE-ED DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE LK-FIN TO WS-DATE-SRC
    PERFORM FORMATER-DATE
    MOVE SPACES TO WS-LIGNE
    STRING "Periode_fin;" DELIMITED BY SIZE
           WS-DATE-ED DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE WS-INIT TO WS-ED-L
    MOVE SPACES TO WS-LIGNE
    STRING "Solde_initial;" DELIMITED BY SIZE
           FUNCTION TRIM(WS-ED-L) DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE "date;heure;operation;compte_lie;debit;credit;solde"
        TO WS-LIGNE
    PERFORM ECRIRE-LIGNE.

ECRIRE-OPERATION-CSV.
    MOVE SPACES TO WS-LIGNE
    MOVE 1 TO WS-PTR
    MOVE TRX-DATE TO WS-DATE-SRC
    PERFORM FORMATER-DATE
    MOVE TRX-HEURE TO WS-HEURE-SRC
    STRING WS-DATE-ED DELIMITED BY SIZE
           ";" DELIMITED BY SIZE
           WS-HEURE-SRC(1:2) DELIMITED BY SIZE
           ":" DELIMITED BY SIZE
           WS-HEURE-SRC(3:2) DELIMITED BY SIZE
           ";" DELIMITED BY SIZE
           FUNCTION TRIM(WS-LIBELLE) DELIMITED BY SIZE
           ";" DELIMITED BY SIZE
        INTO WS-LIGNE WITH POINTER WS-PTR
    IF WS-CONTRE NOT = 0
        STRING WS-CONTRE DELIMITED BY SIZE
            INTO WS-LIGNE WITH POINTER WS-PTR
    END-IF
    STRING ";" DELIMITED BY SIZE INTO WS-LIGNE WITH POINTER WS-PTR
    IF WS-DEBIT NOT = 0
        MOVE WS-DEBIT TO WS-ED-L
        STRING FUNCTION TRIM(WS-ED-L) DELIMITED BY SIZE
            INTO WS-LIGNE WITH POINTER WS-PTR
    END-IF
    STRING ";" DELIMITED BY SIZE INTO WS-LIGNE WITH POINTER WS-PTR
    IF WS-CREDIT NOT = 0
        MOVE WS-CREDIT TO WS-ED-L
        STRING FUNCTION TRIM(WS-ED-L) DELIMITED BY SIZE
            INTO WS-LIGNE WITH POINTER WS-PTR
    END-IF
    MOVE WS-APRES TO WS-ED-L
    STRING ";" DELIMITED BY SIZE
           FUNCTION TRIM(WS-ED-L) DELIMITED BY SIZE
        INTO WS-LIGNE WITH POINTER WS-PTR
    PERFORM ECRIRE-LIGNE.

ECRIRE-PIED-CSV.
    MOVE WS-FINAL TO WS-ED-L
    MOVE SPACES TO WS-LIGNE
    STRING "Solde_final;" DELIMITED BY SIZE
           FUNCTION TRIM(WS-ED-L) DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE WS-TOT-DEB TO WS-ED-L
    MOVE SPACES TO WS-LIGNE
    STRING "Total_debits;" DELIMITED BY SIZE
           FUNCTION TRIM(WS-ED-L) DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE WS-TOT-CRED TO WS-ED-L
    MOVE SPACES TO WS-LIGNE
    STRING "Total_credits;" DELIMITED BY SIZE
           FUNCTION TRIM(WS-ED-L) DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE WS-NB-OPS TO WS-ED-NB
    MOVE SPACES TO WS-LIGNE
    STRING "Operations;" DELIMITED BY SIZE
           FUNCTION TRIM(WS-ED-NB) DELIMITED BY SIZE INTO WS-LIGNE
    PERFORM ECRIRE-LIGNE

    MOVE SPACES TO WS-LIGNE
    IF LK-REL-COHERENT = "O"
        MOVE "Verification;OK" TO WS-LIGNE
    ELSE
        MOVE "Verification;INCOHERENCE" TO WS-LIGNE
    END-IF
    PERFORM ECRIRE-LIGNE.

*> WS-DATE-SRC (AAAAMMJJ) -> WS-DATE-ED (AAAA-MM-JJ)
FORMATER-DATE.
    MOVE SPACES TO WS-DATE-ED
    STRING WS-DATE-SRC(1:4) DELIMITED BY SIZE
           "-" DELIMITED BY SIZE
           WS-DATE-SRC(5:2) DELIMITED BY SIZE
           "-" DELIMITED BY SIZE
           WS-DATE-SRC(7:2) DELIMITED BY SIZE
           INTO WS-DATE-ED.

ECRIRE-LIGNE.
    MOVE WS-LIGNE TO RELEVE-LIGNE
    WRITE RELEVE-LIGNE.

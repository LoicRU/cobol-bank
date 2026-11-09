#!/usr/bin/env python3
"""Serveur web de cobol-bank (bibliotheque standard uniquement).

Sert web/index.html et transmet chaque requete POST /api/<commande> au
programme COBOL bin/api. Le serveur ne garde aucun etat : l'identifiant et le
PIN accompagnent chaque requete et sont verifies par le COBOL (AUTH).

Usage : python3 web/server.py [port]        (defaut 8080, 127.0.0.1 seulement)
Variables d'environnement : celles de cobol-bank (COMPTES_FILE, ...) et
API_BIN pour changer l'executable (defaut bin/api).
"""
import json
import os
import re
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGE = os.path.join(RACINE, "web", "index.html")
API_BIN = os.environ.get("API_BIN", os.path.join(RACINE, "bin", "api"))

# commande -> parametres attendus (dans l'ordre de la ligne envoyee au COBOL)
COMMANDES = {
    "connexion": [],
    "comptes": [],
    "depot": ["compte", "montant"],
    "retrait": ["compte", "montant"],
    "virement": ["source", "destination", "montant"],
    "historique": ["compte"],
}
RE_ID = re.compile(r"^[0-9]{1,6}$")
RE_PIN = re.compile(r"^[0-9]{4,6}$")
RE_COMPTE = re.compile(r"^[0-9]{1,10}$")
RE_MONTANT = re.compile(r"^[0-9]{1,9}([.,][0-9]{1,2})?$")


def valider(commande, corps):
    """Renvoie la ligne a envoyer au COBOL, ou None si la requete est mal formee.

    Tout est controle ici (chiffres seulement) pour qu'aucun espace ni retour
    a la ligne ne puisse glisser un parametre supplementaire dans la ligne."""
    if not isinstance(corps, dict):
        return None
    ident, pin = str(corps.get("id", "")), str(corps.get("pin", ""))
    if not RE_ID.fullmatch(ident) or not RE_PIN.fullmatch(pin):
        return None
    morceaux = [commande, ident, pin]
    for nom in COMMANDES[commande]:
        valeur = str(corps.get(nom, ""))
        motif = RE_MONTANT if nom == "montant" else RE_COMPTE
        if not motif.fullmatch(valeur):
            return None
        morceaux.append(valeur)
    return " ".join(morceaux) + "\n"


VERROU = threading.Lock()  # les fichiers COBOL ne gerent pas la concurrence


def appeler_cobol(ligne):
    try:
        with VERROU:
            res = subprocess.run([API_BIN], input=ligne, capture_output=True,
                                 text=True, cwd=RACINE, timeout=20)
        return json.loads(res.stdout.strip().splitlines()[-1])
    except (OSError, subprocess.TimeoutExpired, ValueError, IndexError):
        return {"ok": False, "statut": "99"}


class Gestionnaire(BaseHTTPRequestHandler):
    server_version = "cobol-bank"

    def _envoyer(self, code, contenu, type_mime):
        self.send_response(code)
        self.send_header("Content-Type", type_mime)
        self.send_header("Content-Length", str(len(contenu)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(contenu)

    def _json(self, code, objet):
        self._envoyer(code, json.dumps(objet).encode(), "application/json")

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            with open(PAGE, "rb") as f:
                self._envoyer(200, f.read(), "text/html; charset=utf-8")
        else:
            self._json(404, {"ok": False, "statut": "404"})

    def do_POST(self):
        commande = self.path[len("/api/"):] if self.path.startswith("/api/") else ""
        if commande not in COMMANDES:
            return self._json(404, {"ok": False, "statut": "77"})
        try:
            taille = int(self.headers.get("Content-Length", "0"))
            if taille > 4096:
                raise ValueError
            corps = json.loads(self.rfile.read(taille) or b"{}")
        except ValueError:
            return self._json(400, {"ok": False, "statut": "79"})
        ligne = valider(commande, corps)
        if ligne is None:
            return self._json(400, {"ok": False, "statut": "79"})
        self._json(200, appeler_cobol(ligne))

    def log_message(self, fmt, *args):  # pas de PIN ni de corps dans les logs
        sys.stderr.write("%s %s\n" % (self.command, self.path))


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    if not os.path.exists(API_BIN):
        sys.exit("bin/api introuvable : lancer make")
    serveur = ThreadingHTTPServer(("127.0.0.1", port), Gestionnaire)
    print("cobol-bank web : http://127.0.0.1:%d  (Ctrl+C pour arreter)" % port)
    try:
        serveur.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()

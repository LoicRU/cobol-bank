COBC   = cobc
FLAGS  = -free -I copybooks

.PHONY: all test clean

all: bin/banque

bin/banque: src/BANQUE.cob
	$(COBC) -x $(FLAGS) -o $@ $<

bin/test_compte: tests/test_compte.cob src/COMPTE.cob src/TRX.cob src/FRAUDE.cob copybooks/COMPTE.cpy copybooks/TRX.cpy copybooks/ALERTE.cpy
	$(COBC) -x $(FLAGS) -o $@ tests/test_compte.cob src/COMPTE.cob src/TRX.cob src/FRAUDE.cob

bin/test_auth: tests/test_auth.cob src/AUTH.cob src/FRAUDE.cob copybooks/CLIENT.cpy copybooks/ALERTE.cpy copybooks/TRX.cpy
	$(COBC) -x $(FLAGS) -o $@ tests/test_auth.cob src/AUTH.cob src/FRAUDE.cob

test: bin/test_compte bin/test_auth
	./bin/test_compte
	./bin/test_auth

clean:
	rm -f bin/banque bin/test_compte bin/test_auth tests/*.dat tests/*.idx
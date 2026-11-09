COBC   = cobc
FLAGS  = -free -I copybooks

.PHONY: all test clean

all: bin/banque

bin/banque: src/BANQUE.cob
	$(COBC) -x $(FLAGS) -o $@ $<

bin/test_compte: tests/test_compte.cob src/COMPTE.cob src/TRX.cob copybooks/COMPTE.cpy copybooks/TRX.cpy
	$(COBC) -x $(FLAGS) -o $@ tests/test_compte.cob src/COMPTE.cob src/TRX.cob

test: bin/test_compte
	./bin/test_compte

clean:
	rm -f bin/banque bin/test_compte tests/*.dat tests/*.idx
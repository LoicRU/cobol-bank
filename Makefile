COBC   = cobc
FLAGS  = -free -I copybooks

.PHONY: all test clean

all: bin/banque

bin/banque: src/BANQUE.cob
	$(COBC) -x $(FLAGS) -o $@ $<

bin/test_compte: tests/test_compte.cob src/COMPTE.cob src/TRX.cob src/FRAUDE.cob copybooks/COMPTE.cpy copybooks/TRX.cpy copybooks/ALERTE.cpy
	$(COBC) -x $(FLAGS) -o $@ tests/test_compte.cob src/COMPTE.cob src/TRX.cob src/FRAUDE.cob

bin/test_batch: tests/test_batch.cob src/BATCH-INT.cob src/COMPTE.cob src/TRX.cob src/FRAUDE.cob copybooks/BATCH.cpy copybooks/COMPTE.cpy copybooks/TRX.cpy copybooks/ALERTE.cpy
	$(COBC) -x $(FLAGS) -o $@ tests/test_batch.cob src/BATCH-INT.cob src/COMPTE.cob src/TRX.cob src/FRAUDE.cob

test: bin/test_compte bin/test_auth bin/test_batch
	./bin/test_compte
	./bin/test_auth
	./bin/test_batch

clean:
	rm -f bin/banque bin/test_compte bin/test_auth bin/test_batch tests/*.dat tests/*.txt tests/*.idx
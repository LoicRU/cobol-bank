COBC   = cobc
FLAGS  = -free -I copybooks

.PHONY: all test clean run

all: bin/banque

MODULES = src/PARAM.cob src/AUTH.cob src/COMPTE.cob src/TRX.cob src/FRAUDE.cob src/RELEVE.cob src/BATCH-INT.cob

bin/banque: src/BANQUE.cob $(MODULES) $(wildcard copybooks/*.cpy)
	$(COBC) -x $(FLAGS) -o $@ src/BANQUE.cob $(MODULES)

run: bin/banque
	./bin/banque

bin/test_compte: tests/test_compte.cob src/PARAM.cob src/COMPTE.cob src/TRX.cob src/FRAUDE.cob copybooks/COMPTE.cpy copybooks/TRX.cpy copybooks/ALERTE.cpy copybooks/PARAMS.cpy
	$(COBC) -x $(FLAGS) -o $@ tests/test_compte.cob src/COMPTE.cob src/TRX.cob src/FRAUDE.cob src/PARAM.cob

bin/test_auth: tests/test_auth.cob src/PARAM.cob src/AUTH.cob src/FRAUDE.cob copybooks/CLIENT.cpy copybooks/ALERTE.cpy copybooks/TRX.cpy
	$(COBC) -x $(FLAGS) -o $@ tests/test_auth.cob src/AUTH.cob src/FRAUDE.cob src/PARAM.cob

bin/test_batch: tests/test_batch.cob src/PARAM.cob src/BATCH-INT.cob src/COMPTE.cob src/TRX.cob src/FRAUDE.cob copybooks/BATCH.cpy copybooks/COMPTE.cpy copybooks/TRX.cpy copybooks/ALERTE.cpy copybooks/PARAMS.cpy
	$(COBC) -x $(FLAGS) -o $@ tests/test_batch.cob src/BATCH-INT.cob src/COMPTE.cob src/TRX.cob src/FRAUDE.cob src/PARAM.cob

bin/test_releve: tests/test_releve.cob src/PARAM.cob src/RELEVE.cob src/COMPTE.cob src/AUTH.cob src/TRX.cob src/FRAUDE.cob src/BATCH-INT.cob copybooks/RELEVE.cpy copybooks/COMPTE.cpy copybooks/CLIENT.cpy copybooks/TRX.cpy copybooks/BATCH.cpy copybooks/ALERTE.cpy copybooks/PARAMS.cpy
	$(COBC) -x $(FLAGS) -o $@ tests/test_releve.cob src/RELEVE.cob src/COMPTE.cob src/AUTH.cob src/TRX.cob src/FRAUDE.cob src/BATCH-INT.cob src/PARAM.cob

bin/test_param: tests/test_param.cob src/PARAM.cob src/AUTH.cob src/FRAUDE.cob src/COMPTE.cob src/TRX.cob src/BATCH-INT.cob copybooks/PARAMS.cpy copybooks/CLIENT.cpy copybooks/COMPTE.cpy copybooks/BATCH.cpy copybooks/TRX.cpy copybooks/ALERTE.cpy
	$(COBC) -x $(FLAGS) -o $@ tests/test_param.cob src/PARAM.cob src/AUTH.cob src/FRAUDE.cob src/COMPTE.cob src/TRX.cob src/BATCH-INT.cob

bin/test_trx: tests/test_trx.cob src/TRX.cob copybooks/TRX.cpy
	$(COBC) -x $(FLAGS) -o $@ tests/test_trx.cob src/TRX.cob

test: bin/test_trx bin/test_param bin/test_compte bin/test_auth bin/test_batch bin/test_releve bin/banque
	./bin/test_trx
	./bin/test_param
	./bin/test_compte
	./bin/test_auth
	./bin/test_batch
	./bin/test_releve
	sh tests/test_menu.sh

clean:
	rm -f bin/banque bin/test_compte bin/test_auth bin/test_batch bin/test_releve bin/test_param bin/test_trx tests/*.dat tests/*.txt tests/*.idx
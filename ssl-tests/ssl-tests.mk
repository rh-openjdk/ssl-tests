SSLTESTS_SRC_DIR = $(SSLTESTS_DIR)/src
SSLTESTS_MAIN_CLASS = Main

.PHONY: ssl-tests ssl-tests-clean ssl-tests-build ssl-tests-run

ssl-tests: ssl-tests-run

ssl-tests-clean:
	rm -rf $(SSLTESTS_CLASSES_DIR)

ssl-tests-build: $(SSLTESTS_CLASSES_DIR)

ssl-tests-run: $(SSLTESTS_CLASSES_DIR) $(KEYSTORE_JKS) $(TRUSTSTORE_JKS)
	$(JAVA) -cp $< \
	-Djavax.net.ssl.keyStore=$(KEYSTORE_JKS) \
	-Djavax.net.ssl.keyStorePassword=$(KEYSTORE_PASSWORD) \
	-Djavax.net.ssl.trustStore=$(TRUSTSTORE_JKS) \
	-Djavax.net.ssl.trustStorePassword=$(TRUSTSTORE_PASSWORD) \
	$(SSLTESTS_MAIN_CLASS)

$(SSLTESTS_CLASSES_DIR): $(SSLTESTS_SRC_DIR)
	mkdir -p $@
	$(JAVAC) -d $@ $</*

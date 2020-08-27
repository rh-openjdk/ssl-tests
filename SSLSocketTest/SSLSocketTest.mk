SSLSOCKETTEST_SRC_DIR = $(SSLSOCKETTEST_DIR)/src
SSLSOCKETTEST_MAIN_CLASS = Main

.PHONY: SSLSocketTest SSLSocketTest-clean SSLSocketTest-build SSLSocketTest-run

SSLSocketTest: SSLSocketTest-run

SSLSocketTest-clean:
	rm -rf $(SSLSOCKETTEST_CLASSES_DIR)

SSLSocketTest-build: $(SSLSOCKETTEST_CLASSES_DIR)

SSLSocketTest-run: $(SSLSOCKETTEST_CLASSES_DIR) $(KEYSTORE_JKS) $(TRUSTSTORE_JKS)
	$(JAVA) -cp $< \
	-Djavax.net.ssl.keyStore=$(KEYSTORE_JKS) \
	-Djavax.net.ssl.keyStorePassword=$(KEYSTORE_PASSWORD) \
	-Djavax.net.ssl.trustStore=$(TRUSTSTORE_JKS) \
	-Djavax.net.ssl.trustStorePassword=$(TRUSTSTORE_PASSWORD) \
	$(SSLSOCKETTEST_MAIN_CLASS)

$(SSLSOCKETTEST_CLASSES_DIR): $(SSLSOCKETTEST_SRC_DIR)
	mkdir -p $@
	$(JAVAC) -d $@ $</*

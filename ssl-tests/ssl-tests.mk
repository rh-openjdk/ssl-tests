SSLTESTS_SRC_DIR = $(SSLTESTS_DIR)/src
SSLTESTS_MAIN_CLASS = Main
SSLTESTS_ONLY_SSL_DEFAULTS_PARAM := $(shell if [ 1 = "$(SSLTESTS_ONLY_SSL_DEFAULTS)" ] ; then  printf '%s' '-Dssltests.onlyssldefaults=1' ; fi )
SSLTESTS_SSL_CONFIG_FILTER_PARAM := $(shell if [ -n "$(SSLTESTS_SSL_CONFIG_FILTER)" ] ; then  printf '%s='%s'' '-Dssltests.sslconfigFilter' '$(SSLTESTS_SSL_CONFIG_FILTER)' ; fi )
SSLTESTS_IGNORE_PROTOCOLS_PARAM := $(shell if [ -n "$(SSLTESTS_IGNORE_PROTOCOLS)" ] ; then  printf "%s='%s'" '-Dssltests.ignoredProtocolsPattern' '$(SSLTESTS_IGNORE_PROTOCOLS)' ; fi )
SSLTESTS_IGNORE_CIPHERS_PARAM := $(shell if [ -n "$(SSLTESTS_IGNORE_CIPHERS)" ] ; then  printf "%s='%s'" '-Dssltests.ignoredCiphersPattern' '$(SSLTESTS_IGNORE_CIPHERS)' ; fi )
SSLTESTS_USE_OPENSSL_CLIENT_PARAM := $(shell if [ 1 = "$(SSLTESTS_USE_OPENSSL_CLIENT)" ] ; then  printf '%s' '-Dssltests.cafile=$(ROOT_CRT) -Dssltests.useOpensslClient=1 -Dssltests.onlyssldefaults=1' ; fi )
SSLTESTS_USE_GNUTLS_CLIENT_PARAM := $(shell if [ 1 = "$(SSLTESTS_USE_GNUTLS_CLIENT)" ] ; then  printf '%s' '-Dssltests.cafile=$(ROOT_CRT) -Dssltests.useGnutlsClient=1 -Dssltests.onlyssldefaults=1' ; fi )
SSLTESTS_USE_NSS_CLIENT_PARAM := $(shell if [ 1 = "$(SSLTESTS_USE_NSS_CLIENT)" ] ; then  printf '%s' '-Dssltests.nssdbDir=$(NSSDB_CLIENT_DIR) -Dssltests.useNssClient=1 -Dssltests.onlyssldefaults=1' ; fi )
SSLTESTS_NSSDB_DEP := $(shell if [ 1 = "$(SSLTESTS_USE_NSS_CLIENT)" ] ; then  printf '%s' '$(NSSDB_CLIENT_DIR)' ; fi )
SSLTESTS_SERVER_SHUTDOWN_OUTPUT_PARAM := $(shell if [ -n "$(SSLTESTS_SERVER_SHUTDOWN_OUTPUT)" ] ; then  printf "%s" '-Dssltests.serverShutdownOutput=1' ; fi )

.PHONY: ssl-tests ssl-tests-clean ssl-tests-build ssl-tests-run

ssl-tests: ssl-tests-run

ssl-tests-clean:
	rm -rf $(SSLTESTS_CLASSES_DIR)

ssl-tests-build: $(SSLTESTS_CLASSES_DIR)

ssl-tests-run: $(SSLTESTS_CLASSES_DIR) $(JAVA_SECURITY_DEPS) $(SSLTESTS_NSSDB_DEP)
	$(JAVA) -cp $< \
	$(JAVA_SECURITY_PARAMS) \
	$(SSLTESTS_ONLY_SSL_DEFAULTS_PARAM) $(SSLTESTS_SSL_CONFIG_FILTER_PARAM) $(SSLTESTS_IGNORE_PROTOCOLS_PARAM) $(SSLTESTS_IGNORE_CIPHERS_PARAM) $(SSLTESTS_USE_OPENSSL_CLIENT_PARAM) $(SSLTESTS_USE_GNUTLS_CLIENT_PARAM) $(SSLTESTS_USE_NSS_CLIENT_PARAM) $(SSLTESTS_SERVER_SHUTDOWN_OUTPUT_PARAM) \
	$(SSLTESTS_CUSTOM_JAVA_PARAMS) \
	$(SSLTESTS_MAIN_CLASS)


$(SSLTESTS_CLASSES_DIR): $(SSLTESTS_SRC_DIR)
	mkdir -p $@
	$(JAVAC) -encoding UTF-8 -g -d $@ $</*

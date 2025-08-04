SSLTESTS_SRC_DIR = $(SSLTESTS_DIR)/src
SSLTESTS_MAIN_CLASS = Main

SSLTESTS_IGNORE_PROTOCOLS ?= $(shell \
    if [ 1 = "$(TEST_PKCS11_FIPS)" ] ; then \
        if ! [ 1 = "$(JAVA_CONF_FIPS)" ] || ! [ 1 = "$(FIPS_MODE_ENABLED)" ] ; then \
            printf '%s' 'TLSv1|TLSv1.1|TLSv1.3' ; \
        elif [ 1 = "$(SSLTESTS_USE_OPENSSL_CLIENT)" ] || [ 1 = "$(SSLTESTS_USE_GNUTLS_CLIENT)" ] || [ 1 = "$(SSLTESTS_USE_NSS_CLIENT)" ] ; then \
            printf '%s' 'TLSv1.2' ; \
        fi ; \
    else \
        if grep -q "Red Hat Enterprise Linux Server release 7" /etc/redhat-release \
        && [ "aarch64" = "$$( uname -m )" ] ; then \
            printf '%s' 'TLSv1.3' ; \
        fi ; \
    fi ; \
)
SSLTESTS_IGNORE_CIPHERS ?= $(shell \
    if [ 1 = "$(TEST_PKCS11_FIPS)" ] ; then \
        if ! [ 1 = "$(JAVA_CONF_FIPS)" ] || ! [ 1 = "$(FIPS_MODE_ENABLED)" ] ; then \
            if [ "$(JAVA_VERSION_MAJOR)" -ge 16 ] ; then \
                printf '%s' 'SSL_.*|TLS_DHE_DSS_.*|TLS_ECDHE_.*' ; \
            else \
                printf '%s' 'SSL_.*|TLS_DHE_DSS_.*' ; \
            fi ; \
        fi ; \
    fi ; \
)

SSLTESTS_ONLY_SSL_DEFAULTS_PARAM := $(shell if [ 1 = "$(SSLTESTS_ONLY_SSL_DEFAULTS)" ] ; then  printf '%s' '-Dssltests.onlyssldefaults=1' ; fi )
SSLTESTS_SSL_CONFIG_FILTER_PARAM := $(shell if [ -n "$(SSLTESTS_SSL_CONFIG_FILTER)" ] ; then  printf '%s='%s'' '-Dssltests.sslconfigFilter' '$(SSLTESTS_SSL_CONFIG_FILTER)' ; fi )
SSLTESTS_IGNORE_PROTOCOLS_PARAM := $(shell if [ -n "$(SSLTESTS_IGNORE_PROTOCOLS)" ] ; then  printf "%s='%s'" '-Dssltests.ignoredProtocolsPattern' '$(SSLTESTS_IGNORE_PROTOCOLS)' ; fi )
SSLTESTS_IGNORE_CIPHERS_PARAM := $(shell if [ -n "$(SSLTESTS_IGNORE_CIPHERS)" ] ; then  printf "%s='%s'" '-Dssltests.ignoredCiphersPattern' '$(SSLTESTS_IGNORE_CIPHERS)' ; fi )
SSLTESTS_USE_OPENSSL_CLIENT_PARAM := $(shell if [ 1 = "$(SSLTESTS_USE_OPENSSL_CLIENT)" ] ; then  printf '%s' '-Dssltests.cafile=$(ROOT_CRT) -Dssltests.useOpensslClient=1' ; fi )
SSLTESTS_USE_GNUTLS_CLIENT_PARAM := $(shell if [ 1 = "$(SSLTESTS_USE_GNUTLS_CLIENT)" ] ; then  printf '%s' '-Dssltests.cafile=$(ROOT_CRT) -Dssltests.useGnutlsClient=1' ; fi )
SSLTESTS_USE_NSS_CLIENT_PARAM := $(shell if [ 1 = "$(SSLTESTS_USE_NSS_CLIENT)" ] ; then  printf '%s' '-Dssltests.nssdbDir=$(NSSDB_CLIENT_DIR) -Dssltests.useNssClient=1' ; fi )
SSLTESTS_NSSDB_DEP := $(shell if [ 1 = "$(SSLTESTS_USE_NSS_CLIENT)" ] ; then  printf '%s' '$(NSSDB_CLIENT_DIR)' ; fi )
SSLTESTS_SERVER_SHUTDOWN_OUTPUT_PARAM := $(shell if [ -n "$(SSLTESTS_SERVER_SHUTDOWN_OUTPUT)" ] ; then  printf "%s" '-Dssltests.serverShutdownOutput=1' ; fi )

.PHONY: ssl-tests ssl-tests-clean ssl-tests-build ssl-tests-run

ssl-tests: ssl-tests-run

ssl-tests-clean:
	rm -rf $(SSLTESTS_CLASSES_DIR)

ssl-tests-build: $(SSLTESTS_CLASSES_DIR)

ssl-tests-run: $(SSLTESTS_CLASSES_DIR) $(JAVA_SECURITY_DEPS) $(SSLTESTS_NSSDB_DEP)
	if $(JAVAC) -version 2>&1 | grep " 11" ; then \
		exports=""; \
	elif $(JAVAC) -version 2>&1 | grep " 1.8.0" ; then \
		exports=""; \
	else \
		exports="--add-exports java.base/sun.security.internal.spec=ALL-UNNAMED"; \
	fi ;\
	$(JAVA) -cp "$<$(JAVA_CP_APPEND)" \
	$$exports \
	$(JAVA_SECURITY_PARAMS) \
	$(SSLTESTS_ONLY_SSL_DEFAULTS_PARAM) $(SSLTESTS_SSL_CONFIG_FILTER_PARAM) $(SSLTESTS_IGNORE_PROTOCOLS_PARAM) $(SSLTESTS_IGNORE_CIPHERS_PARAM) $(SSLTESTS_USE_OPENSSL_CLIENT_PARAM) $(SSLTESTS_USE_GNUTLS_CLIENT_PARAM) $(SSLTESTS_USE_NSS_CLIENT_PARAM) $(SSLTESTS_SERVER_SHUTDOWN_OUTPUT_PARAM) \
	$(SSLTESTS_CUSTOM_JAVA_PARAMS) \
	$(SSLTESTS_MAIN_CLASS)


$(SSLTESTS_CLASSES_DIR): $(SSLTESTS_SRC_DIR)
	mkdir -p $@
	$(JAVAC) -encoding UTF-8 -g -d $@ $</*

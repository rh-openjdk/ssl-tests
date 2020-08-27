JAVA ?= $(shell if [ -n "$(JAVA_HOME)" ] ; then printf '%s/bin/java' "$(JAVA_HOME)" ; else printf 'java' ; fi )
JAVAC ?= $(shell if [ -n "$(JAVA_HOME)" ] ; then printf '%s/bin/javac' "$(JAVA_HOME)" ; else printf 'javac' ; fi )
KEYTOOL ?= $(shell if [ -n "$(JAVA_HOME)" ] ; then printf '%s/bin/keytool' "$(JAVA_HOME)" ; else printf 'keytool' ; fi )
OPENSSL = openssl

all: ssl-tests

CERTGEN_DIR = certgen
CERTGEN_BUILD_DIR = build/certgen
include $(CERTGEN_DIR)/certgen.mk

SSLCONTEXTINFO_DIR = SSLContextInfo
SSLCONTEXTINFO_CLASSES_DIR = build/SSLContextInfo
include $(SSLCONTEXTINFO_DIR)/SSLContextInfo.mk

SSLSOCKETINFO_DIR = SSLSocketInfo
SSLSOCKETINFO_CLASSES_DIR = build/SSLSocketInfo
include $(SSLSOCKETINFO_DIR)/SSLSocketInfo.mk

SSLTESTS_DIR = ssl-tests
SSLTESTS_CLASSES_DIR = build/ssl-tests
include $(SSLTESTS_DIR)/ssl-tests.mk

clean:
	rm -rf build

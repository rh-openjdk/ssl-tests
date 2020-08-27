JAVA ?= $(shell if [ -n "$(JAVA_HOME)" ] ; then printf '%s/bin/java' "$(JAVA_HOME)" ; else printf 'java' ; fi )
JAVAC ?= $(shell if [ -n "$(JAVA_HOME)" ] ; then printf '%s/bin/javac' "$(JAVA_HOME)" ; else printf 'javac' ; fi )
KEYTOOL ?= $(shell if [ -n "$(JAVA_HOME)" ] ; then printf '%s/bin/keytool' "$(JAVA_HOME)" ; else printf 'keytool' ; fi )
OPENSSL = openssl

all: SSLSocketTest

CERTGEN_DIR = certgen
CERTGEN_BUILD_DIR = build/certgen
include $(CERTGEN_DIR)/certgen.mk

SSLCONTEXTINFO_DIR = SSLContextInfo
SSLCONTEXTINFO_CLASSES_DIR = build/SSLContextInfo
include $(SSLCONTEXTINFO_DIR)/SSLContextInfo.mk

SSLSOCKETINFO_DIR = SSLSocketInfo
SSLSOCKETINFO_CLASSES_DIR = build/SSLSocketInfo
include $(SSLSOCKETINFO_DIR)/SSLSocketInfo.mk

SSLSOCKETTEST_DIR = SSLSocketTest
SSLSOCKETTEST_CLASSES_DIR = build/SSLSocketTest
include $(SSLSOCKETTEST_DIR)/SSLSocketTest.mk

clean:
	rm -rf build

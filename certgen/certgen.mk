# Copyright (c) 2018, 2020 Zdeněk Žamberský
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# requires following to be set
#   CERTGEN_DIR - directory with this file
#   CERTGEN_BUILD_DIR - directory, where to place build products
#   OPENSSL - openssl executable
#   KEYTOOL - keytool executable
#   + see test/certgen-test.gmk

RSA_KEY_SIZE = 2048
# DSA size needs to be 1024 to avoid:
# java.security.InvalidKeyException: The security strength of SHA-1 digest algorithm is not sufficient for this key size
DSA_KEY_SIZE = 1024
CRT_DAYS = 365

CERTGEN_CONFS_DIR = $(CERTGEN_DIR)/ssl-confs

ROOT_KEY = $(CERTGEN_BUILD_DIR)/root.key
ROOT_CRT = $(CERTGEN_BUILD_DIR)/root.crt
ROOT_SRL = $(CERTGEN_BUILD_DIR)/root.srl
ROOT_CNF = $(CERTGEN_CONFS_DIR)/root.cnf

INTERMEDIATE_KEY = $(CERTGEN_BUILD_DIR)/intermediate.key
INTERMEDIATE_CSR = $(CERTGEN_BUILD_DIR)/intermediate.csr
INTERMEDIATE_CRT = $(CERTGEN_BUILD_DIR)/intermediate.crt
INTERMEDIATE_SRL = $(CERTGEN_BUILD_DIR)/intermediate.srl
INTERMEDIATE_CNF = $(CERTGEN_CONFS_DIR)/intermediate.cnf

SERVER_KEY_RSA = $(CERTGEN_BUILD_DIR)/server-rsa.key
SERVER_CSR_RSA = $(CERTGEN_BUILD_DIR)/server-rsa.csr
SERVER_CRT_RSA = $(CERTGEN_BUILD_DIR)/server-rsa.crt
SERVER_CNF_RSA = $(CERTGEN_CONFS_DIR)/server.cnf

SERVER_KEY_EC = $(CERTGEN_BUILD_DIR)/server-ec.key
SERVER_CSR_EC = $(CERTGEN_BUILD_DIR)/server-ec.csr
SERVER_CRT_EC = $(CERTGEN_BUILD_DIR)/server-ec.crt
SERVER_CNF_EC = $(CERTGEN_CONFS_DIR)/server.cnf

SERVER_KEY_PARAM_DSA = $(CERTGEN_BUILD_DIR)/server-dsa.param
SERVER_KEY_DSA = $(CERTGEN_BUILD_DIR)/server-dsa.key
SERVER_CSR_DSA = $(CERTGEN_BUILD_DIR)/server-dsa.csr
SERVER_CRT_DSA = $(CERTGEN_BUILD_DIR)/server-dsa.crt
SERVER_CNF_DSA = $(CERTGEN_CONFS_DIR)/server.cnf

CA_CHAIN_CRT = $(CERTGEN_BUILD_DIR)/cachain.crt
KEYSORE_P12_RSA = $(CERTGEN_BUILD_DIR)/keystore-rsa.p12
KEYSORE_P12_EC = $(CERTGEN_BUILD_DIR)/keystore-ec.p12
KEYSORE_P12_DSA = $(CERTGEN_BUILD_DIR)/keystore-dsa.p12
KEYSTORE_P12 = $(CERTGEN_BUILD_DIR)/keystore.p12
KEYSTORE_JKS = $(CERTGEN_BUILD_DIR)/keystore.jks
KEYSTORE_PASSWORD = changeit

TRUSTSTORE_JKS = $(CERTGEN_BUILD_DIR)/truststore.jks
TRUSTSTORE_P12 = $(CERTGEN_BUILD_DIR)/truststore.p12
TRUSTSTORE_PASSWORD = changeit

NSSDB_DIR = $(CERTGEN_BUILD_DIR)/nssdb
NSSDB_PASSWORD =
NSSDB_FIPS ?= 0

NSSDB_CLIENT_DIR = $(CERTGEN_BUILD_DIR)/nssdb-client

CERTGEN_TEST_DIR = $(CERTGEN_DIR)/test
CERTGEN_TEST_BUILD_DIR = $(CERTGEN_BUILD_DIR)/test

.PHONY: certgen_all certgen_clean

certgen_all: $(KEYSTORE_JKS) $(TRUSTSTORE_JKS) certgen_test_run

certgen_nssdb: $(NSSDB_DIR)

certgen_clean: cleantest
	rm -rf $(ROOT_KEY) $(ROOT_CRT) $(ROOT_SRL) \
	$(INTERMEDIATE_KEY) $(INTERMEDIATE_CSR) $(INTERMEDIATE_CRT) \
	$(INTERMEDIATE_SRL) \
	$(SERVER_KEY) $(SERVER_CSR) $(SERVER_CRT) \
	$(CA_CHAIN_CRT) \
	$(KEYSORE_P12) $(KEYSTORE_JKS) \
	$(TRUSTSTORE_JKS)

# create keys dir
$(CERTGEN_BUILD_DIR):
	mkdir $(CERTGEN_BUILD_DIR)

# generate root CA key
$(ROOT_KEY): | $(CERTGEN_BUILD_DIR)
	$(OPENSSL) genrsa -out $(ROOT_KEY) $(RSA_KEY_SIZE)

# generate root CA crt (self-signed)
$(ROOT_CRT): $(ROOT_KEY) $(ROOT_CNF)
	$(OPENSSL) req -x509 -new -nodes -key $(ROOT_KEY) -days $(CRT_DAYS) \
	-config $(ROOT_CNF) -out $(ROOT_CRT)


# generate intermediate CA key
$(INTERMEDIATE_KEY): | $(CERTGEN_BUILD_DIR)
	$(OPENSSL) genrsa -out $(INTERMEDIATE_KEY) $(RSA_KEY_SIZE)

# generate intermediate CA  csr (certificate signing request)
$(INTERMEDIATE_CSR): $(INTERMEDIATE_KEY) $(INTERMEDIATE_CNF)
	$(OPENSSL) req -new -key $(INTERMEDIATE_KEY) \
	-config $(INTERMEDIATE_CNF) -out $(INTERMEDIATE_CSR)

# generate intermediate CA certificate, using csr, signed by root CA
$(INTERMEDIATE_CRT): $(INTERMEDIATE_CSR) $(ROOT_CRT) $(ROOT_KEY) $(ROOT_CNF)
	$(OPENSSL) x509 -req -days $(CRT_DAYS) -in $(INTERMEDIATE_CSR) \
	-CA $(ROOT_CRT) -CAkey $(ROOT_KEY) -CAserial $(ROOT_SRL) -CAcreateserial \
	-extfile $(ROOT_CNF) -extensions intermediate_ext -out $(INTERMEDIATE_CRT)


# generate server RSA key
$(SERVER_KEY_RSA): | $(CERTGEN_BUILD_DIR)
	$(OPENSSL) genrsa -out $(SERVER_KEY_RSA) $(RSA_KEY_SIZE)

# generate server RSA csr (certificate signing request)
$(SERVER_CSR_RSA): $(SERVER_KEY_RSA) $(SERVER_CNF_RSA)
	$(OPENSSL) req -new -key $(SERVER_KEY_RSA) -config $(SERVER_CNF_RSA) \
	-out $(SERVER_CSR_RSA)

# generate server RSA certificate, using csr, signed by intermediate CA
$(SERVER_CRT_RSA): $(SERVER_CSR_RSA) $(INTERMEDIATE_CRT) $(INTERMEDIATE_KEY)
	$(OPENSSL) x509 -req -days $(CRT_DAYS) -in $(SERVER_CSR_RSA) \
	-CA $(INTERMEDIATE_CRT) -CAkey $(INTERMEDIATE_KEY) \
	-CAserial $(INTERMEDIATE_SRL) -CAcreateserial \
	-extfile $(INTERMEDIATE_CNF) -extensions server_ext -out $(SERVER_CRT_RSA)

# generate server EC key
$(SERVER_KEY_EC): | $(CERTGEN_BUILD_DIR)
	openssl ecparam -name prime256v1 -genkey -noout -out $(SERVER_KEY_EC)

# generate server EC csr (certificate signing request)
$(SERVER_CSR_EC): $(SERVER_KEY_EC) $(SERVER_CNF_EC)
	$(OPENSSL) req -new -key $(SERVER_KEY_EC) -config $(SERVER_CNF_EC) \
	-out $(SERVER_CSR_EC)

# generate server EC certificate, using csr, signed by intermediate CA
$(SERVER_CRT_EC): $(SERVER_CSR_EC) $(INTERMEDIATE_CRT) $(INTERMEDIATE_KEY)
	$(OPENSSL) x509 -req -days $(CRT_DAYS) -in $(SERVER_CSR_EC) \
	-CA $(INTERMEDIATE_CRT) -CAkey $(INTERMEDIATE_KEY) \
	-CAserial $(INTERMEDIATE_SRL) -CAcreateserial \
	-extfile $(INTERMEDIATE_CNF) -extensions server_ext -out $(SERVER_CRT_EC)

# generate server DSA param (fallback to pregenerated, needed in FIPS mode)
$(SERVER_KEY_PARAM_DSA): | $(CERTGEN_BUILD_DIR)
	# openssl dsaparam -out $(SERVER_KEY_PARAM_DSA) $(DSA_KEY_SIZE)
	cp $(CERTGEN_DIR)/server-dsa.param $(SERVER_KEY_PARAM_DSA)

# generate server DSA key (fallback to pregenerated, needed in FIPS mode)
$(SERVER_KEY_DSA): $(SERVER_KEY_PARAM_DSA) | $(CERTGEN_BUILD_DIR)
	openssl gendsa -out $(SERVER_KEY_DSA) $(SERVER_KEY_PARAM_DSA) \
	|| cp $(CERTGEN_DIR)/server-dsa.key $(SERVER_KEY_DSA)

# generate server DSA csr (certificate signing request)
$(SERVER_CSR_DSA): $(SERVER_KEY_DSA) $(SERVER_CNF_DSA)
	$(OPENSSL_NOFIPS) req -new -key $(SERVER_KEY_DSA) -config $(SERVER_CNF_DSA) \
	-out $(SERVER_CSR_DSA)

# generate server DSA certificate, using csr, signed by intermediate CA
$(SERVER_CRT_DSA): $(SERVER_CSR_DSA) $(INTERMEDIATE_CRT) $(INTERMEDIATE_KEY)
	$(OPENSSL_NOFIPS) x509 -req -days $(CRT_DAYS) -in $(SERVER_CSR_DSA) \
	-CA $(INTERMEDIATE_CRT) -CAkey $(INTERMEDIATE_KEY) \
	-CAserial $(INTERMEDIATE_SRL) -CAcreateserial \
	-extfile $(INTERMEDIATE_CNF) -extensions server_ext -out $(SERVER_CRT_DSA)


# See: https://blogs.oracle.com/jtc/installing-trusted-certificates-into-a-java-keystore
# concat CA certificates to the chain
$(CA_CHAIN_CRT): $(ROOT_CRT) $(INTERMEDIATE_CRT)
	cat $(ROOT_CRT) $(INTERMEDIATE_CRT) > $(CA_CHAIN_CRT)

# workaround to be able to generate pkcs12 keystore in fips
# See: https://github.com/openssl/openssl/issues/20617
OPENSSL_NOFIPS := $(shell if [ 1 = "$(TEST_PKCS11_FIPS)" ] || [ 1 = "$(FIPS_MODE_ENABLED)" ] ; then printf 'OPENSSL_CONF=%s %s' "$(CERTGEN_CONFS_DIR)/empty.cfg" "$(OPENSSL)" ; else printf '%s' "$(OPENSSL)" ; fi )

# create keystore in PKCS12 format, which can then be imported to jks
$(KEYSORE_P12_RSA): $(SERVER_CRT_RSA) $(SERVER_KEY_RSA) $(CA_CHAIN_CRT)
	$(OPENSSL_NOFIPS) pkcs12 -export -chain -in $(SERVER_CRT_RSA) -inkey $(SERVER_KEY_RSA) \
	-name server-rsa -CAfile $(CA_CHAIN_CRT) -out $(KEYSORE_P12_RSA)  \
	-passout pass:$(KEYSTORE_PASSWORD)

# create EC keystore in PKCS12 format, which can then be imported to jks
$(KEYSORE_P12_EC): $(SERVER_CRT_EC) $(SERVER_KEY_EC) $(CA_CHAIN_CRT)
	$(OPENSSL_NOFIPS) pkcs12 -export -chain -in $(SERVER_CRT_EC) -inkey $(SERVER_KEY_EC) \
	-name server-ec -CAfile $(CA_CHAIN_CRT) -out $(KEYSORE_P12_EC)  \
	-passout pass:$(KEYSTORE_PASSWORD)

# create DSA keystore in PKCS12 format, which can then be imported to jks
$(KEYSORE_P12_DSA): $(SERVER_CRT_DSA) $(SERVER_KEY_DSA) $(CA_CHAIN_CRT)
	$(OPENSSL_NOFIPS) pkcs12 -export -chain -in $(SERVER_CRT_DSA) -inkey $(SERVER_KEY_DSA) \
	-name server-dsa -CAfile $(CA_CHAIN_CRT) -out $(KEYSORE_P12_DSA)  \
	-passout pass:$(KEYSTORE_PASSWORD)

# create p12 keystore
KEYSTORE_P12_DSA_DEP := $(shell if ! [ 1 = "$(TEST_PKCS11_FIPS)" ] ; then printf '%s' "$(KEYSORE_P12_DSA)" ; fi )
$(KEYSTORE_P12): $(KEYSORE_P12_RSA) $(KEYSORE_P12_EC) $(KEYSTORE_P12_DSA_DEP)
	$(KEYTOOL) $(KEYTOOL_PARAMS) -importkeystore \
	-srckeystore $(KEYSORE_P12_RSA) -srcstoretype PKCS12 \
	-srcstorepass $(KEYSTORE_PASSWORD) \
	-destkeystore $(KEYSTORE_P12) -deststoretype PKCS12 \
	-deststorepass $(KEYSTORE_PASSWORD) \
	-noprompt -v
	$(KEYTOOL) $(KEYTOOL_PARAMS) -importkeystore \
	-srckeystore $(KEYSORE_P12_EC) -srcstoretype PKCS12 \
	-srcstorepass $(KEYSTORE_PASSWORD) \
	-destkeystore $(KEYSTORE_P12) -deststoretype PKCS12 \
	-deststorepass $(KEYSTORE_PASSWORD) \
	-noprompt -v
	if ! [ 1 = "$(TEST_PKCS11_FIPS)" ] ; then \
		$(KEYTOOL) $(KEYTOOL_PARAMS) -importkeystore \
		-srckeystore $(KEYSORE_P12_DSA) -srcstoretype PKCS12 \
		-srcstorepass $(KEYSTORE_PASSWORD) \
		-destkeystore $(KEYSTORE_P12) -deststoretype PKCS12 \
		-deststorepass $(KEYSTORE_PASSWORD) \
		-noprompt -v ; \
	fi

# create java keystore
$(KEYSTORE_JKS): $(KEYSTORE_P12)
	$(KEYTOOL) $(KEYTOOL_PARAMS) -importkeystore \
	-srckeystore $(KEYSTORE_P12) -srcstoretype PKCS12 \
	-srcstorepass $(KEYSTORE_PASSWORD) \
	-destkeystore $(KEYSTORE_JKS) -deststoretype JKS \
	-deststorepass $(KEYSTORE_PASSWORD) \
	-noprompt -v

# create truststore with root CA cert
$(TRUSTSTORE_P12): $(ROOT_CRT)
	$(KEYTOOL) $(KEYTOOL_PARAMS) -import -file $(ROOT_CRT) -alias rootca \
	-keystore $(TRUSTSTORE_P12) -storetype PKCS12 -storepass $(TRUSTSTORE_PASSWORD) -noprompt

# create truststore with root CA cert
$(TRUSTSTORE_JKS): $(ROOT_CRT)
	$(KEYTOOL) $(KEYTOOL_PARAMS) -import -file $(ROOT_CRT) -alias rootca \
	-keystore $(TRUSTSTORE_JKS) -storepass $(TRUSTSTORE_PASSWORD) -noprompt

# create nss db with keys and certs
$(NSSDB_DIR): $(ROOT_CRT) $(KEYSORE_P12_RSA) $(KEYSORE_P12_EC) # $(KEYSORE_P12_DSA)
	mkdir $(NSSDB_DIR)
	echo "$(NSSDB_PASSWORD)" > $(NSSDB_DIR)/password.txt
	certutil -N -d $(NSSDB_DIR) -f $(NSSDB_DIR)/password.txt
	touch $(NSSDB_DIR)/secmod.db
	certutil -A -n rootca -i $(ROOT_CRT) -t C,, -d $(NSSDB_DIR) -f $(NSSDB_DIR)/password.txt
	pk12util -i $(KEYSORE_P12_RSA) -W $(KEYSTORE_PASSWORD) -d $(NSSDB_DIR) -k $(NSSDB_DIR)/password.txt
	pk12util -i $(KEYSORE_P12_EC) -W $(KEYSTORE_PASSWORD) -d $(NSSDB_DIR) -k $(NSSDB_DIR)/password.txt
	# pk12util -i $(KEYSORE_P12_DSA) -W $(KEYSTORE_PASSWORD) -d $(NSSDB_DIR) -k $(NSSDB_DIR)/password.txt
	if [ 1 = $(NSSDB_FIPS) ] ; then \
		printf '\n' | modutil -fips true -dbdir $(NSSDB_DIR) ; \
	fi

$(NSSDB_CLIENT_DIR): $(ROOT_CRT)
	mkdir $(NSSDB_CLIENT_DIR)
	echo "" > $(NSSDB_CLIENT_DIR)/password.txt
	certutil -N -d $(NSSDB_CLIENT_DIR) -f $(NSSDB_CLIENT_DIR)/password.txt
	certutil -A -n rootca -i $(ROOT_CRT) -t C,, -d $(NSSDB_CLIENT_DIR) -f $(NSSDB_CLIENT_DIR)/password.txt

include $(CERTGEN_TEST_DIR)/certgen-test.mk

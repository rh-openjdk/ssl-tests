# Copyright (c) 2018 Zdeněk Žamberský
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

KEY_SIZE = 2048
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

SERVER_KEY = $(CERTGEN_BUILD_DIR)/server.key
SERVER_CSR = $(CERTGEN_BUILD_DIR)/server.csr
SERVER_CRT = $(CERTGEN_BUILD_DIR)/server.crt
SERVER_CNF = $(CERTGEN_CONFS_DIR)/server.cnf

SERVER_KEY_EC = $(CERTGEN_BUILD_DIR)/server-ec.key
SERVER_CSR_EC = $(CERTGEN_BUILD_DIR)/server-ec.csr
SERVER_CRT_EC = $(CERTGEN_BUILD_DIR)/server-ec.crt
SERVER_CNF_EC = $(CERTGEN_CONFS_DIR)/server.cnf

CA_CHAIN_CRT = $(CERTGEN_BUILD_DIR)/cachain.crt
KEYSORE_P12 = $(CERTGEN_BUILD_DIR)/keystore.p12
KEYSORE_P12_EC = $(CERTGEN_BUILD_DIR)/keystore-ec.p12
KEYSTORE_JKS = $(CERTGEN_BUILD_DIR)/keystore.jks
KEYSTORE_JKS_EC = $(CERTGEN_BUILD_DIR)/keystore-ec.jks
KEYSTORE_PASSWORD = changeit

TRUSTSTORE_JKS = $(CERTGEN_BUILD_DIR)/truststore.jks
TRUSTSTORE_PASSWORD = changeit

CERTGEN_TEST_DIR = $(CERTGEN_DIR)/test
CERTGEN_TEST_BUILD_DIR = $(CERTGEN_BUILD_DIR)/test

.PHONY: certgen_all certgen_clean

certgen_all: $(KEYSTORE_JKS) $(TRUSTSTORE_JKS) certgen_test_run

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
	$(OPENSSL) genrsa -out $(ROOT_KEY) $(KEY_SIZE)

# generate root CA crt (self-signed)
$(ROOT_CRT): $(ROOT_KEY) $(ROOT_CNF)
	$(OPENSSL) req -x509 -new -nodes -key $(ROOT_KEY) -days $(CRT_DAYS) \
	-config $(ROOT_CNF) -out $(ROOT_CRT)


# generate intermediate CA key
$(INTERMEDIATE_KEY): | $(CERTGEN_BUILD_DIR)
	$(OPENSSL) genrsa -out $(INTERMEDIATE_KEY) $(KEY_SIZE)

# generate intermediate CA  csr (certificate signing request)
$(INTERMEDIATE_CSR): $(INTERMEDIATE_KEY) $(INTERMEDIATE_CNF)
	$(OPENSSL) req -new -key $(INTERMEDIATE_KEY) \
	-config $(INTERMEDIATE_CNF) -out $(INTERMEDIATE_CSR)

# generate intermediate CA certificate, using csr, signed by root CA
$(INTERMEDIATE_CRT): $(INTERMEDIATE_CSR) $(ROOT_CRT) $(ROOT_KEY) $(ROOT_CNF)
	$(OPENSSL) x509 -req -days $(CRT_DAYS) -in $(INTERMEDIATE_CSR) \
	-CA $(ROOT_CRT) -CAkey $(ROOT_KEY) -CAserial $(ROOT_SRL) -CAcreateserial \
	-extfile $(ROOT_CNF) -extensions intermediate_ext -out $(INTERMEDIATE_CRT)


# generate server key
$(SERVER_KEY): | $(CERTGEN_BUILD_DIR)
	$(OPENSSL) genrsa -out $(SERVER_KEY) $(KEY_SIZE)

# generate server csr (certificate signing request)
$(SERVER_CSR): $(SERVER_KEY) $(SERVER_CNF)
	$(OPENSSL) req -new -key $(SERVER_KEY) -config $(SERVER_CNF) \
	-out $(SERVER_CSR)

# generate server certificate, using csr, signed by intermediate CA
$(SERVER_CRT): $(SERVER_CSR) $(INTERMEDIATE_CRT) $(INTERMEDIATE_KEY)
	$(OPENSSL) x509 -req -days $(CRT_DAYS) -in $(SERVER_CSR) \
	-CA $(INTERMEDIATE_CRT) -CAkey $(INTERMEDIATE_KEY) \
	-CAserial $(INTERMEDIATE_SRL) -CAcreateserial \
	-extfile $(INTERMEDIATE_CNF) -extensions server_ext -out $(SERVER_CRT)

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


# See: https://blogs.oracle.com/jtc/installing-trusted-certificates-into-a-java-keystore
# concat CA certificates to the chain
$(CA_CHAIN_CRT): $(ROOT_CRT) $(INTERMEDIATE_CRT)
	cat $(ROOT_CRT) $(INTERMEDIATE_CRT) > $(CA_CHAIN_CRT)

# create keystore in PKCS12 format, which can then be imported to jks
$(KEYSORE_P12): $(SERVER_CRT) $(SERVER_KEY) $(CA_CHAIN_CRT)
	$(OPENSSL) pkcs12 -export -chain -in $(SERVER_CRT) -inkey $(SERVER_KEY) \
	-name server -CAfile $(CA_CHAIN_CRT) -out $(KEYSORE_P12)  \
	-passout pass:$(KEYSTORE_PASSWORD)

# create EC keystore in PKCS12 format, which can then be imported to jks
$(KEYSORE_P12_EC): $(SERVER_CRT_EC) $(SERVER_KEY_EC) $(CA_CHAIN_CRT)
	$(OPENSSL) pkcs12 -export -chain -in $(SERVER_CRT_EC) -inkey $(SERVER_KEY_EC) \
	-name server-ec -CAfile $(CA_CHAIN_CRT) -out $(KEYSORE_P12_EC)  \
	-passout pass:$(KEYSTORE_PASSWORD)

# create java keystore
$(KEYSTORE_JKS): $(KEYSORE_P12) $(KEYSORE_P12_EC)
	$(KEYTOOL) -importkeystore \
	-srckeystore $(KEYSORE_P12) -srcstoretype PKCS12 \
	-srcstorepass $(KEYSTORE_PASSWORD) \
	-destkeystore $(KEYSTORE_JKS) -deststoretype JKS \
	-deststorepass $(KEYSTORE_PASSWORD) \
	-noprompt -v
	$(KEYTOOL) -importkeystore \
	-srckeystore $(KEYSORE_P12_EC) -srcstoretype PKCS12 \
	-srcstorepass $(KEYSTORE_PASSWORD) \
	-destkeystore $(KEYSTORE_JKS) -deststoretype JKS \
	-deststorepass $(KEYSTORE_PASSWORD) \
	-noprompt -v

$(KEYSTORE_JKS_EC): $(KEYSORE_P12_EC)
	$(KEYTOOL) -importkeystore \
	-srckeystore $(KEYSORE_P12_EC) -srcstoretype PKCS12 \
	-srcstorepass $(KEYSTORE_PASSWORD) \
	-destkeystore $(KEYSTORE_JKS_EC) -deststoretype JKS \
	-deststorepass $(KEYSTORE_PASSWORD) \
	-noprompt -v

# create truststore with root CA cert
$(TRUSTSTORE_JKS): $(ROOT_CRT)
	$(KEYTOOL) -import -file $(ROOT_CRT) -alias rootca \
	-keystore $(TRUSTSTORE_JKS) -storepass $(TRUSTSTORE_PASSWORD) -noprompt

include $(CERTGEN_TEST_DIR)/certgen-test.mk

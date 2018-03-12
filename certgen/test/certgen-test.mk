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
#   CERTGEN_TEST_DIR - directory with this file
#   CERTGEN_TEST_BUILD_DIR - directory, where to place build products
#   JAVA - java executable
#   JAVAC - javac executable

CERTGEN_TEST_SRC_DIR = $(CERTGEN_TEST_DIR)/src

CERTGEN_TEST_CLASSES_DIR = $(CERTGEN_TEST_BUILD_DIR)/classes
CERTGEN_TEST_MAIN_CLASS = TestSSL

.PHONY: certgen_test_clean certgen_test_run

certgen_test_clean:
	rm -rf $(CERTGEN_TEST_CLASSES_DIR)

$(CERTGEN_TEST_BUILD_DIR): | $(CERTGEN_BUILD_DIR)
	mkdir $(CERTGEN_TEST_BUILD_DIR)

$(CERTGEN_TEST_CLASSES_DIR): | $(CERTGEN_TEST_BUILD_DIR)
	mkdir $(CERTGEN_TEST_CLASSES_DIR)
	$(JAVAC) -d $(CERTGEN_TEST_CLASSES_DIR) \
	$(CERTGEN_TEST_SRC_DIR)/$(CERTGEN_TEST_MAIN_CLASS).java

# test app should return non-zero value without keystore + truststore config
# and zero when correct keystore + truststore is set
certgen_test_run: $(CERTGEN_TEST_CLASSES_DIR) $(KEYSTORE_JKS) $(TRUSTSTORE_JKS)
	! $(JAVA) -cp $(CERTGEN_TEST_CLASSES_DIR) \
	$(CERTGEN_TEST_MAIN_CLASS) &> /dev/null
	$(JAVA) -cp $(CERTGEN_TEST_CLASSES_DIR) \
	-Djavax.net.ssl.keyStore=$(KEYSTORE_JKS) \
	-Djavax.net.ssl.keyStorePassword=$(KEYSTORE_PASSWORD) \
	-Djavax.net.ssl.trustStore=$(TRUSTSTORE_JKS) \
	-Djavax.net.ssl.trustStorePassword=$(TRUSTSTORE_PASSWORD) \
	$(CERTGEN_TEST_MAIN_CLASS)

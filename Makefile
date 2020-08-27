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

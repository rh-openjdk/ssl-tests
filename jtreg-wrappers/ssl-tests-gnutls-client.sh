#!/bin/sh
# @test
# @requires os.family == "linux" & bin.gnutlscli != "false"
# @bug 6666664
# @summary ssl-tests with gnutls client
# @run shell/timeout=1000 ssl-tests-gnutls-client.sh

set -eu
rm -rf build
export JAVA_HOME="${TESTJAVA}"
make -f "${TESTSRC:-.}/../Makefile" ssl-tests TOP_DIR="${TESTSRC:-.}/.." SSLTESTS_USE_GNUTLS_CLIENT=1

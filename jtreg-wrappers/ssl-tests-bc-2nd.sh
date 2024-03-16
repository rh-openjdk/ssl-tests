#!/bin/sh
# @test
# @bug 6666661
# @requires os.family == "linux" | os.family == "windows"
# @summary ssl-test-bc with BouncyCastle provider (BC_2ND configuration)
# @run shell/timeout=1000 ssl-tests-bc-2nd.sh

set -eu
rm -rf build
export JAVA_HOME="${TESTJAVA}"
# KEYSTORE_PKCS12_LEGACY=1 is workaround for issue in BC (will be removed when fixed), see:
# https://github.com/bcgit/bc-java/issues/958
make -f "${TESTSRC:-.}/../Makefile" ssl-tests TOP_DIR="${TESTSRC:-.}/.." TEST_BC_2ND=1 KEYSTORE_PKCS12_LEGACY=1

#!/bin/sh
# @test
# @requires os.family == "linux"
# @bug 6666666
# @summary ssl-test with nss client
# @run shell/timeout=1000 ssl-tests-nss-client.sh

set -eu
rm -rf build
export JAVA_HOME="${TESTJAVA}"
make -C "${TESTSRC:-.}/.." ssl-tests BUILD_DIR="$PWD/build" SSLTESTS_USE_NSS_CLIENT=1

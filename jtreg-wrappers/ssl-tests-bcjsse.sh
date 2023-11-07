#!/bin/sh
# @test
# @bug 6666666
# @requires os.family == "linux" | os.family == "windows"
# @summary ssl-tests with BouncyCastle provider (BCJSSE configuration)
# @run shell/timeout=1000 ssl-tests-bcjsse.sh

set -eu
rm -rf build
export JAVA_HOME="${TESTJAVA}"
make -f "${TESTSRC:-.}/../Makefile" ssl-tests TOP_DIR="${TESTSRC:-.}/.." TEST_BCJSSE=1

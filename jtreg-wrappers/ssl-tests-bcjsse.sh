#!/bin/sh
# @test
# @bug 6666666
# @summary ssl-tests with BouncyCastle provider (BCJSSE configuration)
# @run shell/timeout=1000 ssl-tests-bcjsse.sh

set -eu
rm -rf build
export JAVA_HOME="${TESTJAVA}"
make -C "${TESTSRC:-.}/.." ssl-tests  BUILD_DIR="$PWD/build" TEST_BCJSSE=1

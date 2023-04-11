#!/bin/sh
# @test
# @bug 6666666
# @requires jdk.version.major <= 11
# @summary ssl-test-bc with BouncyCastle provider (BCFIPS configuration)
# @run shell/timeout=4000 ssl-tests-bcfips.sh

set -eu
rm -rf build
export JAVA_HOME="${TESTJAVA}"
make -f "${TESTSRC:-.}/../Makefile" ssl-tests  TOP_DIR="${TESTSRC:-.}/.." TEST_BCFIPS=1 USE_URANDOM=1

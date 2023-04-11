#!/bin/sh
# @test
# @bug 6666666
# @summary ssl-tests
# @run shell/timeout=1000 ssl-tests.sh

set -eu
rm -rf build
export JAVA_HOME="${TESTJAVA}"
make -f "${TESTSRC:-.}/../Makefile" ssl-tests TOP_DIR="${TESTSRC:-.}/.."

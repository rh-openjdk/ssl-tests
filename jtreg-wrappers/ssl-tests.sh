#!/bin/sh
# @test
# @bug 6666666
# @requires os.family == "linux" | os.family == "windows" | os.family == "mac"
# @summary ssl-tests
# @run shell/timeout=1000 ssl-tests.sh

set -eu
rm -rf build
export JAVA_HOME="${TESTJAVA}"
if uname -m | grep -q ppc64 ; then
    # workaround for: https://bugzilla.redhat.com/show_bug.cgi?id=2164644
    export NSS_DISABLE_PPC_GHASH=1
fi
make -f "${TESTSRC:-.}/../Makefile" ssl-tests TOP_DIR="${TESTSRC:-.}/.."

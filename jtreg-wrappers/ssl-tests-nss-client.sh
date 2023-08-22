#!/bin/sh
# @test
# @requires os.family == "linux"
# @bug 6666666
# @summary ssl-test with nss client
# @run shell/timeout=1000 ssl-tests-nss-client.sh

set -eu
rm -rf build

if grep -q 'Alpine' /etc/os-release > /dev/null 2>&1 ; then
    echo "Skipping on Alpine, as it does not have required NSS tools"
    exit 0
fi

if ! type listsuites > /dev/null 2>&1 \
&& ! [ -e "/usr/lib64/nss/unsupported-tools/listsuites" ] \
&& ! [ -e "/usr/lib/nss/unsupported-tools/listsuites" ] ; then
    # if system does not contain nss listsuites utility, build it
    curl -L -f -o listsuites.c https://raw.githubusercontent.com/servo/nss/949eb9848f4fa5f83756f3ab7fdf9b0d3f20d37f/cmd/listsuites/listsuites.c
    gcc $( pkg-config --cflags nss ) -o listsuites listsuites.c  $( pkg-config --libs nss )
    export PATH="${PATH:-}${PATH:+:}${PWD}"
fi

export JAVA_HOME="${TESTJAVA}"
make -f "${TESTSRC:-.}/../Makefile" ssl-tests TOP_DIR="${TESTSRC:-.}/.." SSLTESTS_USE_NSS_CLIENT=1

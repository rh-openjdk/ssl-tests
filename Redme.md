General
This project consists of:
- certgen - generates keys/certificates/keystores (required by SSLSocketTest)
- SSLContest info - lists available SSLContexts
- SSL


To use specific JDK use JAVA_HOME env. variable:
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk



SSLSocketTest
It iterates over all providers/SSLContext/protocol/algorithm combinations and test them one by one.
I creates basic client+server scenario, where server just echos (repeats) everything client sends.
Both server and client sockets are configured to have only one protocol and one cipher enabled (these ones to be tested).
Test checks no exeptions are thrown and that data send and received match.

run by:
make SSLSocketTest

Ignored tests:
Currently tested combination may show as IGNORED for following reasons:
- SSLv2Hello protocol is used, having this enabled as only protocol does not make sense as far as I know
- TLS_EMPTY_RENEGOTIATION_INFO_SCSV cipher is used, as this in not really a ciper
- "No appropriate protocol" exeption is thrown, which means combination of protocol/algorithm is invalid (thrown by handshaker)
- protocol starts with DTLS - tests currently does not support  DTLS

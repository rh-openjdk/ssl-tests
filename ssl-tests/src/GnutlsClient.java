/*
 * The MIT License
 *
 * Copyright 2021 Zdeněk Žamberský.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.InputStreamReader;
import java.io.BufferedReader;
import java.io.PrintStream;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.Set;
import java.util.HashSet;
import java.util.List;
import java.util.ArrayList;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.FileSystems;

/*
broken configs?
make clean && make SSLTESTS_USE_OPENSSL_CLIENT=1 SSLTESTS_SSL_CONFIG_FILTER='SunJSSE,TLSv1.3,TLSv1.3,TLS_AES_256_GCM_SHA384'
not supported by ojdk?
make clean && make SSLTESTS_USE_OPENSSL_CLIENT=1 SSLTESTS_SSL_CONFIG_FILTER='SunJSSE,TLSv1.3,TLSv1.3,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384'
*/

public class GnutlsClient extends ExternalClient {

    public GnutlsClient() {
    }


    public static String getJavaProtoName(String gnuTlsProto) {
        switch (gnuTlsProto) {
            /* ssl3 ?? */
            case "TLS1.0":
                return "TLSv1";
            case "TLS1.1":
                return "TLSv1.1";
            case "TLS1.2":
                return "TLSv1.2";
            case "TLS1.3":
                return "TLSv1.3";
            default:
                throw new IllegalArgumentException("Unknown protocol: " + gnuTlsProto);
        }
    }


    public static HashSet getSupportedCiphers(String protocol) throws Exception {
        HashSet hs = new HashSet();
        List<String> lines = ExternalClient.getCommandOutput("gnutls-cli", "--priority", "NORMAL", "--list");
        boolean cipherSuitesFound = false;
        String[] components;
        String cipherSuite;
        String cipherProto;

        for (String line : lines) {
            line = line.trim();
            if (!cipherSuitesFound) {
                if (line.startsWith("Cipher suites")) {
                    cipherSuitesFound = true;
                }
                continue;
            }
            if (line.length() == 0) {
                break;
            }
            components = line.split("\\s+");
            if (components.length < 4) {
                break;
            }
            cipherSuite = components[0];
            cipherProto = components[3];
            cipherProto = getJavaProtoName(cipherProto);
            /* convert cipher suite names from gnutls format to IANA format */
            cipherSuite = cipherSuite.replaceAll("^TLS_ECDHE_ECDSA_","TLS_ECDHE_ECDSA_WITH_");
            cipherSuite = cipherSuite.replaceAll("^TLS_ECDHE_RSA_","TLS_ECDHE_RSA_WITH_");
            cipherSuite = cipherSuite.replaceAll("^TLS_DHE_RSA_","TLS_DHE_RSA_WITH_");
            cipherSuite = cipherSuite.replaceAll("^TLS_RSA_","TLS_RSA_WITH_");
            cipherSuite = cipherSuite.replaceAll("_SHA1$","_SHA");
            cipherSuite = cipherSuite.replaceAll("_POLY1305$", "_POLY1305_SHA256");
            if (!testCompatible(protocol, cipherSuite, cipherProto)) {
                continue;
            }
            hs.add(cipherSuite);
        }
        return hs;
    }

    public ProcessBuilder getClientProcessBuilder(String host, int port, String cafile, String logfile) {
        return new  ProcessBuilder("gnutls-cli", "--x509cafile=" + cafile, "--logfile=" + logfile, "--port=" + port, host);
    }

}

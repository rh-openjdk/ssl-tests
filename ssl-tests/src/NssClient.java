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

public class NssClient extends ExternalClient {

    static String toolsPrefix;
    String nssdbDir;

    static {
        String lib64PathStr = "/usr/lib64/nss/unsupported-tools/";
        String libPathStr = "/usr/lib/nss/unsupported-tools/";
        Path lib64Path = FileSystems.getDefault().getPath(lib64PathStr);
        Path libPath = FileSystems.getDefault().getPath(libPathStr);
        if (Files.exists(lib64Path)) {
            toolsPrefix = lib64PathStr;
        } else if (Files.exists(libPath)) {
            toolsPrefix = libPathStr;
        } else {
            toolsPrefix = "/usr/bin/";
        }
    }

    public NssClient() {
        nssdbDir = System.getProperty("ssltests.nssdbDir");
        skipData = true;
    }

    public static HashSet getSupportedCiphers(String protocol) throws Exception {
        HashSet hs = new HashSet();
        List<String> lines = ExternalClient.getCommandOutput(toolsPrefix + "listsuites");
        boolean cipherFound = false;
        String cipher = null;
        String cipherProtocol;
        String additionalLine;

        for (String line : lines) {
            line = line.trim();
            if (!cipherFound) {
                if (line.startsWith("TLS_")) {
                    // remove traling :
                    cipher = line.replaceAll(":$", "");
                    cipherFound = true;
                }
                continue;
            }
            cipherFound = false;
            additionalLine = line;
            if (additionalLine.indexOf("Enabled") < 0) {
                continue;
            }
            cipherProtocol = null;
            if (additionalLine.indexOf("TLS 1.3") >= 0) {
                cipherProtocol = "TLSv1.3";
            }
            if (!testCompatible(protocol, cipher, cipherProtocol)) {
                continue;
            }
            hs.add(cipher);
        }
        return hs;
    }

    public ProcessBuilder getClientProcessBuilder(String host, int port, String cafile, String logfile) {
        return new  ProcessBuilder(toolsPrefix + "tstclnt", "-4", "-d", nssdbDir, "-h",  host, "-p", String.valueOf(port), "-Q");
    }

}

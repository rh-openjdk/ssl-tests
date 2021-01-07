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

public class OpensslClient extends SSLSocketClient {

    String cafile;

    public OpensslClient() {
        super(null, null, null);
        cafile = System.getProperty("ssltests.cafile");
    }

    public static HashSet getSupportedCiphers(String protocol) throws Exception {
        HashSet hs = new HashSet();
        String protoOption;
        if (protocol.equals("SSLv2Hello")) {
            /* empty */
            return hs;
        } else if (protocol.equals("SSLv3")) {
            protoOption="-ssl3";
        } else if (protocol.equals("TLSv1")) {
            protoOption="-tls1";
        } else if (protocol.startsWith("TLSv1.")) {
            protoOption="-tls1_" + protocol.substring(6);
        } else {
            throw new IllegalArgumentException("Invalid protocol " + protocol);
        }
        String name;
        Path path = FileSystems.getDefault().getPath("/etc/crypto-policies/back-ends/openssl.config");
        if (Files.exists(path)) {
            /* Ciphers enabled by current system crypto policy */
            name="PROFILE=SYSTEM";
        } else {
            name="DEFAULT";
        }
        ProcessBuilder pb =
            new ProcessBuilder("openssl", "ciphers", protoOption, "-s", "-stdname", name);
        pb.redirectError(ProcessBuilder.Redirect.INHERIT);
        Process p = pb.start();
        p.getOutputStream().close();
        try (InputStream is = p.getInputStream();
            InputStreamReader isr = new InputStreamReader(is);
            BufferedReader br = new BufferedReader(isr)) {
            String line = null;
            while ((line = br.readLine()) != null) {
                int spaceIndex = line.indexOf(" ");
                if (spaceIndex > 0) {
                    line = line.substring(0, spaceIndex);
                }
                hs.add(line);
            }
        }
        int retval = p.waitFor();
        if (retval != 0) {
            throw new RuntimeException("Openssl ciphers exit value not zero: " + retval);
        }
        return hs;
    }

    public void test(String host, int port) throws IOException {
        Path msgFile = Files.createTempFile("ssl-tests-openssl", null);
        ProcessBuilder pb =
            new ProcessBuilder("openssl", "s_client", "-connect", host + ":" + port, "-servername", host, "-CAfile", cafile, "-msg", "-msgfile", msgFile.toString(), "-quiet", "-no_ign_eof");
        int retval = 0;
        boolean error = false;
        Thread sendingThread = null;
        StreamReader sr = null;
        Process p = pb.start();
        try {
            sr = new StreamReader(p.getErrorStream());
            sendingThread = new Thread() {
                @Override
                public void run() {
                    OutputStream os = p.getOutputStream();
                    try {
                        int sent = 0;
                        while (sent < dataBuffer.length) {
                            os.write(dataBuffer[sent++]);
                        }
                        os.flush();
                    } catch (Exception ex) {
                        Logger.getLogger(OpensslClient.class.getName()).log(Level.SEVERE, null, ex);
                        p.destroy();
                    }
                }
            };
            sr.start();
            sendingThread.start();
            InputStream is = p.getInputStream();

            int read = 0;
            int readByte = 0;
            while ((readByte = is.read()) >= 0) {
                if (read > dataBuffer.length) {
                    throw new RuntimeException("Received more data then sent!");
                }
                if (readByte != (dataBuffer[read++] & 0xFF)) {
                    throw new RuntimeException("Received different data then sent!");
                }
                if (readByte == EOT) {
                    break;
                }
            }
            if (read != dataBuffer.length) {
                throw new RuntimeException("Received less data then sent: " + read + " < " + dataBuffer.length  + " !");
            }
        } catch (Exception ex) {
            Logger.getLogger(OpensslClient.class.getName()).log(Level.SEVERE, null, ex);
            p.destroy();
            error = true;
        } finally {
            if (sendingThread != null) {
                try {
                    sendingThread.join();
                    sendingThread = null;
                } catch (InterruptedException ex) {
                    Logger.getLogger(OpensslClient.class.getName()).log(Level.SEVERE, null, ex);
                }
            }

            try {
                p.getOutputStream().close();
            } catch (Exception ex) {
                Logger.getLogger(OpensslClient.class.getName()).log(Level.SEVERE, null, ex);
                p.destroy();
            }
            try {
                retval = p.waitFor();
                if (retval != 0) {
                    error = true;
                }
            } catch (InterruptedException ex) {
                Logger.getLogger(OpensslClient.class.getName()).log(Level.SEVERE, null, ex);
            }
            if (sr != null) {
                try {
                    sr.waitfor();
                    if (error) {
                        sr.printWithPrefix(System.err, "stderr: ");
                    }
                    sr = null;
                } catch (InterruptedException ex) {
                    Logger.getLogger(OpensslClient.class.getName()).log(Level.SEVERE, null, ex);
                }
            }
            if (error) {
                for (String line : Files.readAllLines(msgFile)) {
                    System.err.println("msgfile: " + line);
                }
            }
            Files.deleteIfExists(msgFile);
        }
        if (retval != 0) {
            throw new RuntimeException("Openssl exit value not zero: " + retval);
        }
    }

}

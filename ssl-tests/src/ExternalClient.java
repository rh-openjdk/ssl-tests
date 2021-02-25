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

public abstract class ExternalClient extends SSLSocketClient {

    String cafile;
    boolean skipData = false;

    public ExternalClient() {
        super(null, null, null);
        cafile = System.getProperty("ssltests.cafile");
    }

    public static boolean testCompatible(String protocol, String cipherSuite, String cipherProtocol) {
        if (cipherProtocol == null) {
            if (cipherSuite.indexOf("_GCM_") >= 0
                || cipherSuite.indexOf("_CHACHA20_") >= 0
                || cipherSuite.indexOf("_SHA256") >= 0
                || cipherSuite.indexOf("_SHA384") >= 0) {
                if (cipherSuite.indexOf("_WITH_") >= 0) {
                    cipherProtocol = "TLSv1.2";
                } else {
                    cipherProtocol = "TLSv1.3";
                }
            } else {
                    cipherProtocol = "TLSv1";
            }
        }
        switch (protocol) {
            case "SSLv3":
                return cipherProtocol.equals("SSLv3");
            case "TLSv1":
                return cipherProtocol.equals("TLSv1");
            case "TLSv1.1":
                return cipherProtocol.equals("TLSv1.1") || cipherProtocol.equals("TLSv1");
            case "TLSv1.2":
                return cipherProtocol.equals("TLSv1.2") || cipherProtocol.equals("TLSv1.1") || cipherProtocol.equals("TLSv1");
            case "TLSv1.3":
                return cipherProtocol.equals("TLSv1.3");
            default:
                throw new IllegalArgumentException("Unknown protocol: " + protocol);
        }
    }

    public static List<String> getCommandOutput(boolean ignoreError, boolean bothOutputs, String... cmds) throws IOException {
        ProcessBuilder pb = new  ProcessBuilder(cmds);
        StreamReader outReader = null;
        StreamReader errReader = null;
        Process p = null;
        int retval = 0;
        boolean error = false;
        try {
            p = pb.start();
            outReader = new StreamReader(p.getInputStream());
            errReader = new StreamReader(p.getErrorStream());
            outReader.start();
            errReader.start();
            p.getOutputStream().close();
        } catch (IOException ex) {
            if (p != null) {
                p.destroy();
            }
            error = true;
            throw ex;
        } finally {
            if (p != null) {
                try {
                    retval = p.waitFor();
                    if (!ignoreError && retval != 0) {
                        error = true;
                    }
                } catch (InterruptedException ex) {
                    Logger.getLogger(ExternalClient.class.getName()).log(Level.SEVERE, null, ex);
                }
            }
            if (outReader != null) {
                try {
                    outReader.waitFor();
                } catch (InterruptedException ex) {
                    Logger.getLogger(ExternalClient.class.getName()).log(Level.SEVERE, null, ex);
                }
            }
            if (errReader != null) {
                try {
                    errReader.waitFor();
                } catch (InterruptedException ex) {
                    Logger.getLogger(ExternalClient.class.getName()).log(Level.SEVERE, null, ex);
                }
                if (error) {
                    errReader.printWithPrefix(System.err, "stderr: ");
                }
            }
        }
        if (!ignoreError && retval != 0) {
            throw new RuntimeException("Program exit value not zero: " + retval);
        }
        if (bothOutputs) {
            List<String> output = new ArrayList<String>();
            output.addAll(outReader.lines);
            output.addAll(errReader.lines);
            return output;
        }
        return outReader.lines;
    }

    public static List<String> getCommandOutput(String... cmds) throws IOException {
        return getCommandOutput(false, false, cmds);
    }

    public static List<String> getCommandOutputAllIgnoreStatus(String... cmds) throws IOException {
        return getCommandOutput(true, true, cmds);
    }

    public abstract ProcessBuilder getClientProcessBuilder(String host, int port, String cafile, String msgFile);


    public void test(String host, int port) throws IOException {
        Path logfile = Files.createTempFile("ssl-tests-openssl", null);
        ProcessBuilder pb = getClientProcessBuilder(host, port, cafile, logfile.toString());
        int retval = 0;
        boolean error = false;
        Thread sendingThread = null;
        StreamReader errsr = null;
        StreamReader outsr = null;
        Process p = pb.start();
        try {
            errsr = new StreamReader(p.getErrorStream());
            errsr.start();
            if (skipData) {
                outsr = new StreamReader(p.getInputStream());
                outsr.start();
            } else {
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
                            Logger.getLogger(ExternalClient.class.getName()).log(Level.SEVERE, null, ex);
                            p.destroy();
                        }
                    }
                };

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
            }
        } catch (IOException ex) {
            p.destroy();
            error = true;
            throw ex;
        } finally {
            if (sendingThread != null) {
                try {
                    sendingThread.join();
                    sendingThread = null;
                } catch (InterruptedException ex) {
                    Logger.getLogger(ExternalClient.class.getName()).log(Level.SEVERE, null, ex);
                }
            }
            try {
                // sending thread is done,
                // close stdin -> client program should terminate afterwards
                p.getOutputStream().close();
            } catch (Exception ex) {
                Logger.getLogger(ExternalClient.class.getName()).log(Level.SEVERE, null, ex);
                p.destroy();
            }
            try {
                // wait for client program to terminate
                retval = p.waitFor();
                if (retval != 0) {
                    error = true;
                }
            } catch (InterruptedException ex) {
                Logger.getLogger(ExternalClient.class.getName()).log(Level.SEVERE, null, ex);
            }
            try {
                // close stdout
                if (skipData) {
                    outsr.waitFor();
                } else {
                    p.getInputStream().close();
                }
            } catch (Exception ex) {
                Logger.getLogger(ExternalClient.class.getName()).log(Level.SEVERE, null, ex);
            }
            if (errsr != null) {
                try {
                    // wait for the stderr reader
                    errsr.waitFor();
                    if (error) {
                        errsr.printWithPrefix(System.err, "stderr: ");
                    }
                    errsr = null;
                } catch (InterruptedException ex) {
                    Logger.getLogger(ExternalClient.class.getName()).log(Level.SEVERE, null, ex);
                }
            }
            if (error) {
                for (String line : Files.readAllLines(logfile)) {
                    System.err.println("logfile: " + line);
                }
            }
            Files.deleteIfExists(logfile);
        }
        if (retval != 0) {
            throw new RuntimeException("Program exit value not zero: " + retval);
        }
    }
}

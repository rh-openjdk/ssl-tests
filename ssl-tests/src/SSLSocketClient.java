/*
 * The MIT License
 *
 * Copyright 2020 Zdeněk Žamberský.
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
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

public class SSLSocketClient {

    SSLSocketFactory sslSocketFactory;
    String[] protocols;
    String[] ciphers;
    static final byte[] dataBuffer;

    public static final int EOT = 0x4;

    static {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 2000; ++i) {
            sb = sb.append("message").append(i).append("\n");
        }
        sb.append((char) EOT);
        /* End of transmition */
        dataBuffer = sb.toString().getBytes(StandardCharsets.UTF_8);
    }

    public SSLSocketClient(SSLSocketFactory sslSocketFactory,
            String[] protocols,
            String[] ciphers) {
        this.sslSocketFactory = sslSocketFactory;
        this.protocols = protocols;
        this.ciphers = ciphers;
    }

    public void test(String host, int port) throws IOException {

        try (SSLSocket sslSocket = (SSLSocket) sslSocketFactory.createSocket()) {

            sslSocket.setEnabledProtocols(protocols);
            sslSocket.setEnabledCipherSuites(ciphers);

            InetSocketAddress socketAddress = new InetSocketAddress(host, port);
            sslSocket.connect(socketAddress);
            // we want exceptions to be thrown early (before we start a sending thread, if possible)
            sslSocket.startHandshake();

            Thread sendingThread = new Thread() {
                @Override
                public void run() {
                    try {
                        OutputStream os = sslSocket.getOutputStream();
                        int sent = 0;
                        while (sent < dataBuffer.length) {
                            os.write(dataBuffer[sent++]);
                        }
                    } catch (Exception ex) {
                        if (!SSLSocketTester.isOkException(ex)) {
                                Logger.getLogger(SSLSocketClient.class.getName()).log(Level.SEVERE, null, ex);
                                try {
                                    sslSocket.close();
                                } catch (IOException ex2) {
                                    // ignored
                                }
                        }
                    }
                }
            };
            try {
                sendingThread.start();
                InputStream is = sslSocket.getInputStream();

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
            } finally {
                try {
                    sendingThread.join();
                    sendingThread = null;
                } catch (InterruptedException ex) {
                    Logger.getLogger(SSLSocketClient.class.getName()).log(Level.SEVERE, null, ex);
                }
            }
        }
    }

}

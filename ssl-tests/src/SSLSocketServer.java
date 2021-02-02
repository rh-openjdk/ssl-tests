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
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketException;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.net.ssl.SSLServerSocketFactory;
import javax.net.ssl.SSLServerSocket;

public class SSLSocketServer {

    final Object lock = new Object();

    SSLServerSocketFactory serverSocketFactory;
    String[] protocols;
    String[] ciphers;

    SSLServerSocket serverSocket;
    Thread serverThread;
    String host = "localhost";
    int port = 0;
    boolean shutdownOutput = false;

    public SSLSocketServer(
            SSLServerSocketFactory serverSocketFactory,
            String[] protocols,
            String[] ciphers) {
        this.ciphers = ciphers;
        this.protocols = protocols;
        this.serverSocketFactory = serverSocketFactory;
    }

    public void start() throws IOException {
        synchronized (lock) {
            if (serverSocket == null) {
                serverSocket
                        = (SSLServerSocket) serverSocketFactory.createServerSocket();
                serverSocket.setEnabledProtocols(protocols);
                serverSocket.setEnabledCipherSuites(ciphers);
                InetSocketAddress serverAddress
                        = new InetSocketAddress(host, port);
                serverSocket.bind(serverAddress);
                port = serverSocket.getLocalPort();
                Runnable runnable = new Runnable() {
                    @Override
                    public void run() {
                        try {
                            serverLoop();
                        } catch (SocketException ignored) {
                            // this exception is expected
                            // on serverSocket close
                        } catch (Exception ex) {
                            if (!SSLSocketTester.isOkException(ex)) {
                                    Logger.getLogger(
                                        SSLSocketServer.class.getName())
                                        .log(Level.SEVERE, null, ex);
                            }
                        }
                    }
                };
                serverThread = new Thread(runnable);
                serverThread.start();
            }
        }
    }

    public String getHost() {
        synchronized (lock) {
            return host;
        }
    }

    public int getPort() {
        synchronized (lock) {
            return port;
        }
    }

    public void stop() throws IOException {
        synchronized (lock) {
            if (serverSocket != null) {
                try {
                    serverSocket.close();
                } finally {
                    try {
                        if (serverThread != null) {
                            serverThread.join();
                        }
                    } catch (InterruptedException ex) {
                        Logger.getLogger(SSLSocketServer.class.getName()).log(Level.SEVERE, null, ex);
                    }
                    port = 0;
                    serverThread = null;
                    serverSocket = null;
                }
            }
        }
    }

    public void serverLoop() throws IOException {
        for (;;) {
            try (Socket socket = serverSocket.accept()) {
                OutputStream os = socket.getOutputStream();
                InputStream is = socket.getInputStream();
                int readByte;
                while ((readByte = is.read()) >= 0) {
                    os.write(readByte);
                }
                // see: https://bugzilla.redhat.com/show_bug.cgi?id=1918473
                if (shutdownOutput) {
                    socket.shutdownOutput();
                }
            }
        }
    }

}

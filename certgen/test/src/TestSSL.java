/*
Copyright (c) 2018 Zdeněk Žamberský

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

import javax.net.ssl.SSLServerSocketFactory;
import javax.net.ServerSocketFactory;
import javax.net.ssl.SSLSocketFactory;
import javax.net.SocketFactory;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.InetSocketAddress;
import java.net.InetAddress;
import java.net.SocketException;
import java.io.IOException;
import java.io.OutputStream;
import java.io.InputStream;

public class TestSSL {

    public static void main(String[] args) throws Exception {
        Server server = new Server();
        try {
            server.start();
            int port = server.getPort();
            SocketFactory sslSocketFactory = SSLSocketFactory.getDefault();
            try(Socket socket = sslSocketFactory.createSocket()) {

                String hostname = "localhost";
                InetSocketAddress inetSocketAddress =
                    new InetSocketAddress(hostname, port);
                socket.connect(inetSocketAddress);
                try (OutputStream outputStream = socket.getOutputStream()) {
                    // just doing connect is not enough to test SSLSocket works
                    // send single byte to force it to do all handshakes etc...
                    outputStream.write(1);
                    outputStream.flush();
                }
            }
        } finally {
            server.stop();
        }
    }

    static class Server {

        private final Object lock = new Object();
        ServerSocket serverSocket = null;
        Thread thread = null;
        int port = 0;

        public Server() {
        }

        public void start() throws IOException {
            synchronized (lock) {
                if (serverSocket == null) {
                    ServerSocketFactory sslServerConnectionFactory =
                        SSLServerSocketFactory.getDefault();
                    serverSocket =
                        sslServerConnectionFactory.createServerSocket();
                    InetSocketAddress inetSocketAddress =
                        new InetSocketAddress((InetAddress) null, 0);
                    serverSocket.bind(inetSocketAddress);
                    thread = new Thread(new Runnable() {
                            public void run() {
                                try {
                                    mainLoop();
                                } catch (SocketException ignored) {
                                    // this exception is expected
                                    // on serverSocket close
                                } catch (IOException e) {
                                    e.printStackTrace();
                                }
                            }
                    });
                    thread.start();
                    port = serverSocket.getLocalPort();
                }
            }
        }

        public void stop() throws IOException, InterruptedException {
            synchronized (lock) {
                if(serverSocket != null) {
                    try {
                        // closing socket makes server thread exit accept loop
                        // with exception
                        serverSocket.close();
                    } finally {
                        thread.join();
                        serverSocket = null;
                        port = 0;
                    }
                }
            }
        }

        public int getPort() {
            return port;
        }


        private void mainLoop() throws IOException {
            for (;;) {
                // accept loop (until serverSocket is closed)
                try (Socket socket = serverSocket.accept()) {
                    try (InputStream inputStream = socket.getInputStream()) {
                        // just read and discard all received data
                        // until connection is closed
                        while(inputStream.read() >= 0);
                    }
                }
            }
        }
    }
}
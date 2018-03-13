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

import java.net.Socket;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;
import java.net.ServerSocket;
import javax.net.ssl.SSLServerSocket;
import javax.net.ssl.SSLServerSocketFactory;
import java.io.IOException;
import java.util.Arrays;

public class SSLSocketInfo {

    public static void printInfo(String name, String[] values) {
        System.out.println("  " + name);
        for(String value : values) {
            System.out.println("    " + value);
        }
    }

    public static void main(String[] args) {
        System.out.println("SSLSocket:");
        SSLSocketFactory socketFactory = (SSLSocketFactory) SSLSocketFactory.getDefault();
        try (Socket socket = socketFactory.createSocket()) {
            SSLSocket sslSocket = (SSLSocket) socket;
            printInfo("SupportedProtocols", sslSocket.getSupportedProtocols());
            printInfo("SupportedCipherSuites", sslSocket.getSupportedCipherSuites());

            printInfo("DefaultProtocols", sslSocket.getEnabledProtocols());
            printInfo("DefaultCipherSuites", sslSocket.getEnabledCipherSuites());
        } catch (IOException e) {
            e.printStackTrace();
        }
        System.out.println();
        System.out.println("SSLServerSocket:");
        SSLServerSocketFactory serverSocketFactory = (SSLServerSocketFactory) SSLServerSocketFactory.getDefault();
        try (ServerSocket serverSocket = serverSocketFactory.createServerSocket()) {
            SSLServerSocket sslServerSocket = (SSLServerSocket) serverSocket;
            printInfo("SupportedProtocols", sslServerSocket.getSupportedProtocols());
            printInfo("SupportedCipherSuites", sslServerSocket.getSupportedCipherSuites());

            printInfo("DefaultProtocols", sslServerSocket.getEnabledProtocols());
            printInfo("DefaultCipherSuites", sslServerSocket.getEnabledCipherSuites());
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

}
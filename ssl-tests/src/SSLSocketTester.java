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

import java.io.FileInputStream;
import java.io.IOException;
import java.security.KeyStore;
import java.security.NoSuchAlgorithmException;
import java.security.Provider;
import java.security.SecureRandom;
import java.security.Security;
import java.util.Set;
import java.util.HashSet;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.regex.Pattern;
import javax.net.ssl.KeyManager;
import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLParameters;
import javax.net.ssl.SSLServerSocketFactory;
import javax.net.ssl.SSLSocketFactory;
import javax.net.ssl.TrustManager;
import javax.net.ssl.TrustManagerFactory;

public class SSLSocketTester {

    KeyManager[] serverKeyManagers;
    TrustManager[] serverTrustManagers;
    KeyManager[] clientKeyManagers;
    TrustManager[] clientTrustManagers;

    boolean onlySSLDefaults;
    String[] sslConfigFilterParts = null;
    static boolean ignoreSomeEx = true;
    boolean failed;

    Pattern ignoredCiphersPattern = null;
    Pattern ignoredProtocolsPattern = null;
    boolean useOpensslClient = false;
    boolean useGnutlsClient = false;
    boolean useNssClient = false;
    boolean serverShutdownOutput = false;

    public SSLSocketTester() {

    }

    private static boolean getBooleanProperty(String name, boolean defaultValue) {
        String val = System.getProperty(name);
        if (val != null) {
            String valLow = val.toLowerCase();
            if (valLow.equals("1") || valLow.equals("true")) {
                return true;
            } else if (valLow.equals("0") || valLow.equals("false")) {
                return false;
            }
        }
        return defaultValue;
    }

    public void init() throws Exception {
        String serverKeystoreFile = System.getProperty("javax.net.ssl.keyStore");
        String serverKeystorePassword = System.getProperty("javax.net.ssl.keyStorePassword");
        String clientTruststoreFile = System.getProperty("javax.net.ssl.trustStore");
        String clientTruststorePassword = System.getProperty("javax.net.ssl.trustStorePassword");
        if (serverKeystoreFile == null || serverKeystoreFile.equals("NONE")) {
            // fips mode
            serverKeyManagers = getKeyManagers(null,
                    "nss.SECret.123");
            clientTrustManagers = getTrustManagers(null,
                    "nss.SECret.123");
        } else {
            serverKeyManagers = getKeyManagers(serverKeystoreFile,
                    serverKeystorePassword);
            clientTrustManagers = getTrustManagers(clientTruststoreFile,
                    clientTruststorePassword);
        }
        onlySSLDefaults = getBooleanProperty("ssltests.onlyssldefaults", true);
        String sslConfigFilter = System.getProperty("ssltests.sslconfigFilter");
        if (sslConfigFilter != null) {
            String[] sslConfigFilterParts1 = sslConfigFilter.split(",");
            if (sslConfigFilterParts1.length == 4) {
                sslConfigFilterParts = sslConfigFilterParts1;
            }
        }
        String ignoredCiphersPatternString = System.getProperty("ssltests.ignoredCiphersPattern");
        if (ignoredCiphersPatternString != null) {
            ignoredCiphersPattern = Pattern.compile(ignoredCiphersPatternString);
        }
        String ignoredProtocolsPatternString = System.getProperty("ssltests.ignoredProtocolsPattern");
        if (ignoredProtocolsPatternString != null) {
            ignoredProtocolsPattern = Pattern.compile(ignoredProtocolsPatternString);
        }

        useOpensslClient = getBooleanProperty("ssltests.useOpensslClient", false);
        useGnutlsClient = getBooleanProperty("ssltests.useGnutlsClient", false);
        useNssClient = getBooleanProperty("ssltests.useNssClient", false);
        serverShutdownOutput = SSLSocketTester.getBooleanProperty("ssltests.serverShutdownOutput", false);
    }

    KeyManager[] getKeyManagers(String file, String password) throws Exception {
        KeyStore keyStore = loadKeystore(file, password);
        String keyManagerDefaultAlg = KeyManagerFactory.getDefaultAlgorithm();
        KeyManagerFactory keyManagerFactory
                = KeyManagerFactory.getInstance(keyManagerDefaultAlg);
        keyManagerFactory.init(keyStore, password.toCharArray());
        return keyManagerFactory.getKeyManagers();
    }

    TrustManager[] getTrustManagers(
            String file,
            String password) throws Exception {
        KeyStore keyStore = loadKeystore(file, password);
        String trustManagerDefAlg = TrustManagerFactory.getDefaultAlgorithm();
        TrustManagerFactory trustManagerFactory
                = TrustManagerFactory.getInstance(trustManagerDefAlg);
        trustManagerFactory.init(keyStore);
        return trustManagerFactory.getTrustManagers();
    }

    KeyStore loadKeystore(String file, String password) throws Exception {
        String defaultType = KeyStore.getDefaultType();
        KeyStore keystore = KeyStore.getInstance(defaultType);
        char[] passwordArray = password == null ? null : password.toCharArray();
        if (file != null) {
            try (FileInputStream fis = new FileInputStream(file)) {
                keystore.load(fis, passwordArray);
            }
        } else {
            keystore.load(null, passwordArray);
        }
        return keystore;
    }

    public void testSingle(
            String providerName,
            String alghoritm,
            String protocol,
            String cipher) throws Exception {
        Provider provider = Security.getProvider(providerName);
        SSLContext serverContext
                = SSLContext.getInstance(alghoritm, provider);
        SSLContext clientContext
                = SSLContext.getInstance(alghoritm, provider);
        serverContext.init(serverKeyManagers,
                serverTrustManagers,
                new SecureRandom());
        clientContext.init(clientKeyManagers,
                clientTrustManagers,
                new SecureRandom());
        testConfiguration(
                serverContext,
                clientContext,
                protocol,
                cipher,
                false);
    }

    public void testProviders() throws Exception {
        Provider[] providers = Security.getProviders();
        for (Provider provider : providers) {
            if (providesSSLContext(provider)) {
                if (sslConfigFilterParts != null
                    && !sslConfigFilterParts[0].equals(provider.getName())) {
                    continue;
                }

                // System.out.println("Provider: " + provider.getName());
                testProvider(provider);
            }
        }
    }

    public boolean isSSLContext(Provider.Service service) {
        return service.getType().equals("SSLContext");
    }

    public boolean providesSSLContext(Provider provider) {
        Set<Provider.Service> services = provider.getServices();
        for (Provider.Service service : services) {
            if (isSSLContext(service)) {
                return true;
            }
        }
        return false;
    }

    public void testProvider(Provider provider) throws Exception {
        Set<Provider.Service> services = provider.getServices();
        for (Provider.Service service : services) {
            if (isSSLContext(service)) {
                String alghorithm = service.getAlgorithm();
                if (sslConfigFilterParts != null
                    && !sslConfigFilterParts[1].equals(alghorithm)) {
                    continue;
                }

                SSLContext serverContext
                        = SSLContext.getInstance(alghorithm, provider);
                SSLContext clientContext
                        = SSLContext.getInstance(alghorithm, provider);
                /* Default contexts are auto initialized */
                if (!serverContext.getProtocol().toUpperCase().equals("DEFAULT")) {
                    serverContext.init(serverKeyManagers,
                            serverTrustManagers,
                            new SecureRandom());
                }
                if (!clientContext.getProtocol().toUpperCase().equals("DEFAULT")) {
                    clientContext.init(clientKeyManagers,
                            clientTrustManagers,
                            new SecureRandom());
                }
                testConfigurations(serverContext, clientContext);
            }
        }
    }

    public void testConfigurations(
            SSLContext sslServerContext,
            SSLContext sslClientContext) {
        SSLParameters sslParameters
                = onlySSLDefaults ? sslServerContext.getDefaultSSLParameters()
                        : sslServerContext.getSupportedSSLParameters();
        boolean isBC = sslClientContext.getProvider().getName().equals("BCJSSE");
        for (String protocol
                : sslParameters.getProtocols()) {
            boolean skippedProtocol = false;
            if (protocol.equals("SSLv2Hello")) {
                skippedProtocol = true;
            }
            /*
                DTLS is not supported yet by this test
            */
            if (protocol.startsWith("DTLS")) {
                skippedProtocol = true;
            }
            if (ignoredProtocolsPattern != null
                && ignoredProtocolsPattern.matcher(protocol).matches()) {
                    skippedProtocol = true;
            }
            Set validCiphers = null;
            if (!skippedProtocol) {
                try {
                    if (useOpensslClient) {
                        validCiphers = OpensslClient.getSupportedCiphers(protocol);
                    } else if (useGnutlsClient) {
                        validCiphers = GnutlsClient.getSupportedCiphers(protocol);
                    } else if (useNssClient) {
                        validCiphers = NssClient.getSupportedCiphers(protocol);
                    } else if (isBC) {
                        SSLParameters sslparams = onlySSLDefaults ?
                        sslClientContext.getDefaultSSLParameters() :
                        sslClientContext.getSupportedSSLParameters();
                        validCiphers = new HashSet();
                        for (String cipher : sslparams.getCipherSuites()) {
                            if (ExternalClient.testCompatible(protocol, cipher, null)) {
                                validCiphers.add(cipher);
                            }
                        }
                    }
                } catch (Exception ex) {
                    throw new RuntimeException(ex);
                }
            }
            if (sslConfigFilterParts != null
                && !sslConfigFilterParts[2].equals(protocol)) {
                continue;
            }
            for (String cipher : sslParameters.getCipherSuites()) {
                if (sslConfigFilterParts != null
                    && !sslConfigFilterParts[3].equals(cipher)) {
                    continue;
                }
                boolean skipTesting = skippedProtocol;
                /*
                TLS_EMPTY_RENEGOTIATION_INFO_SCSV is skipped
                as it is not really a cipher, see:
                https://tools.ietf.org/html/rfc5746#section-3.3
                */
                if (cipher.equals("TLS_EMPTY_RENEGOTIATION_INFO_SCSV")) {
                    skipTesting = true;
                }
                /*
                kerberos seems to need more complicated setup,
                not yet supported (ignore for now):
                https://hg.openjdk.java.net/jdk8u/jdk8u/jdk/file/d5c320d784e5/test/sun/security/krb5/auto/SSL.java
                */
                if (cipher.startsWith("TLS_KRB5")) {
                    skipTesting = true;
                }
                if (ignoredCiphersPattern != null
                    && ignoredCiphersPattern.matcher(cipher).matches()) {
                    skipTesting = true;
                }

                if ((useOpensslClient || useGnutlsClient || useNssClient || isBC) && validCiphers != null) {
                    if (!validCiphers.contains(cipher)) {
                        skipTesting = true;
                    }
                }
                testConfiguration(sslServerContext,
                        sslClientContext,
                        protocol,
                        cipher, skipTesting);
            }
        }
    }

    public void testConfiguration(
            SSLContext sslServerContext,
            SSLContext sslClientContext,
            String protocol,
            String cipher,
            boolean skipTesting) {
        if (sslServerContext.getProvider() != sslClientContext.getProvider()) {
            // should not happen, if not bug in test
            throw new RuntimeException(
                    "Server and Client does not have mathing provider!");
        }
        if (!sslServerContext.getProtocol()
                .equals(sslClientContext.getProtocol())) {
            // should not happen, if not bug in test
            throw new RuntimeException(
                    "Server and Client does not have mathing protocol!");
        }
        String providerName = sslServerContext.getProvider().getName();
        String algorithmName = sslServerContext.getProtocol();

        if (skipTesting) {
            printResult(providerName, algorithmName, protocol, cipher, "IGNORED");
            return;
        }

        sslServerContext.getProvider().getName();
        sslServerContext.getProtocol();

        String[] enabledProtocols = new String[]{protocol};
        String[] enabledCiphers = new String[]{cipher};

        SSLServerSocketFactory sslServerSocketFactory
                = sslServerContext.getServerSocketFactory();

        SSLSocketFactory sslSocketFactory
                = sslClientContext.getSocketFactory();

        SSLSocketServer sslSocketServer
                = new SSLSocketServer(
                        sslServerSocketFactory,
                        enabledProtocols,
                        enabledCiphers);
        if (serverShutdownOutput) {
            sslSocketServer.shutdownOutput = true;
        }

        SSLSocketClient sslSocketClient;
        if (useOpensslClient) {
            sslSocketClient = new OpensslClient();
        } else if (useGnutlsClient) {
            sslSocketClient = new GnutlsClient();
        } else if (useNssClient) {
            sslSocketClient = new NssClient();
        } else {
            sslSocketClient = new SSLSocketClient(
                sslSocketFactory,
                enabledProtocols,
                enabledCiphers);
        }
        try {
            try {
                sslSocketServer.start();
                sslSocketClient.test(
                        sslSocketServer.getHost(),
                        sslSocketServer.getPort());
                printResult(providerName, algorithmName, protocol, cipher, "PASSED");
            } finally {
                sslSocketServer.stop();
            }
        } catch (Exception ex) {
            String resultStr;
            if (isOkException(ex)) {
                resultStr = "IGNORED";
            } else {
                failed = true;
                resultStr = "FAILED";
                Logger.getLogger(SSLSocketTester.class.getName()).log(Level.SEVERE, null, ex);
            }
            printResult(providerName, algorithmName, protocol, cipher, resultStr);
        }
    }

    public void printResult(
            String providerName,
            String agortihm,
            String protocol,
            String cipher,
            String result) {
        StringBuilder sb = new StringBuilder();
        sb.append(result);
        sb.append(": ");
        sb.append(providerName);
        sb.append("/");
        sb.append(agortihm);
        sb.append(": ");
        sb.append(protocol);
        sb.append(" + ");
        sb.append(cipher);
        sb.append("\n");
        System.out.print(sb.toString());
    }

    public static boolean isOkException(Exception ex) {
        if (ignoreSomeEx) {
            /*
            This exception is thrown by handshaker,
            when invalid protocol/cipher combination is used,
            see:
            https://hg.openjdk.java.net/jdk8u/jdk8u/jdk/file/ce1f37506608/src/share/classes/sun/security/ssl/Handshaker.java#l554
            */
            String message = ex.getMessage();
            if (message != null) {
                return message.contains("No appropriate protocol (protocol is disabled or cipher suites are inappropriate)");
            }
        }
        return false;
    }

}

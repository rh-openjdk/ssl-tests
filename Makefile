JAVA ?= $(shell if [ -n "$(JAVA_HOME)" ] ; then printf '%s/bin/java' "$(JAVA_HOME)" ; else printf 'java' ; fi )
JAVAC ?= $(shell if [ -n "$(JAVA_HOME)" ] ; then printf '%s/bin/javac' "$(JAVA_HOME)" ; else printf 'javac' ; fi )
KEYTOOL ?= $(shell if [ -n "$(JAVA_HOME)" ] ; then printf '%s/bin/keytool' "$(JAVA_HOME)" ; else printf 'keytool' ; fi )
OPENSSL = openssl

JAVA_VERSION_MAJOR := $(shell $(JAVA) -version 2>&1 | grep version | head -n 1 | sed -E 's/^.*"(1[.])?([0-9]+).*$$/\2/g' )
JAVA_HOME_DIR  := $(shell if [ -n "$(JAVA_HOME)" ] ; then printf '%s' "$(JAVA_HOME)" ; else readlink -f $$( which $(JAVA) 2>/dev/null || type $(JAVA) | sed 's;.* ;;g' ) | sed 's;/bin/java$$;;g' | sed 's;/jre$$;;g' ; fi )
JAVA_CONF_DIR := $(shell if [ 8 -ge $(JAVA_VERSION_MAJOR) ] ; then printf '%s' "$(JAVA_HOME_DIR)/jre/lib" ; else printf '%s' "$(JAVA_HOME_DIR)/conf" ; fi )

FIPS_MODE_ENABLED := $(shell if [ -e "/proc/sys/crypto/fips_enabled" ] && [ 1 = $$(cat /proc/sys/crypto/fips_enabled) ] ; then echo 1 ; else echo 0 ; fi )
TEST_PKCS11_FIPS ?= $(shell if [ 1 = $(FIPS_MODE_ENABLED) ] && [ -n "$(JAVA_HOME_DIR)" ] && cat $(JAVA_CONF_DIR)/security/java.security 2>&1 | grep -q '^fips.provider' ; then echo 1; else echo 0 ; fi )
NSSDB_FIPS := $(shell if [ 0 = $(FIPS_MODE_ENABLED) ] && [ 1 = $(TEST_PKCS11_FIPS) ] ; then echo 1 ; else echo 0 ; fi )

JAVA_PKCS11_FIPS_CONF_DIR = build/java-pkcs11-conf
JAVA_PKCS11_FIPS_NSS_CFG = $(JAVA_PKCS11_FIPS_CONF_DIR)/nss.fips.cfg
JAVA_PKCS11_FIPS_SECURITY_CFG = $(JAVA_PKCS11_FIPS_CONF_DIR)/java.security

BC_JARS_DIRS = build/bc-jars
BC_BCPROV_JAR = $(BC_JARS_DIRS)/bcprov-ext-jdk15on-168.jar
BC_BCTLS_JAR = $(BC_JARS_DIRS)/bctls-jdk15on-168.jar
BC_BCPKIX_JAR = $(BC_JARS_DIRS)/bcpkix-jdk15on-168.jar

JAVA_BC_CONF_DIR = build/java-bc-conf
JAVA_BC_SECURITY_CFG = $(JAVA_BC_CONF_DIR)/java.security

JAVA_BCJSSE_CONF_DIR = build/java-bcjsse-conf
JAVA_BCJSSE_SECURITY_CFG = $(JAVA_BCJSSE_CONF_DIR)/java.security

all: ssl-tests

CERTGEN_DIR = certgen
CERTGEN_BUILD_DIR = build/certgen
include $(CERTGEN_DIR)/certgen.mk

JAVA_SECURITY_PARAMS := $(shell \
    if [ 1 = "$(TEST_BC)" ] ; then \
        printf '%s ' -Djava.security.properties==$(JAVA_BC_SECURITY_CFG) ; \
        printf '%s ' -Djavax.net.ssl.keyStore=$(KEYSTORE_P12) ; \
        printf '%s ' -Djavax.net.ssl.keyStorePassword=$(KEYSTORE_PASSWORD) ; \
        printf '%s ' -Djavax.net.ssl.trustStore=$(TRUSTSTORE_P12) ; \
        printf '%s ' -Djavax.net.ssl.trustStorePassword=$(TRUSTSTORE_PASSWORD) ; \
    elif [ 1 = "$(TEST_BCJSSE)" ] ; then \
        printf '%s ' -Djava.security.properties==$(JAVA_BCJSSE_SECURITY_CFG) ; \
        printf '%s ' -Djavax.net.ssl.keyStore=$(KEYSTORE_P12) ; \
        printf '%s ' -Djavax.net.ssl.keyStorePassword=$(KEYSTORE_PASSWORD) ; \
        printf '%s ' -Djavax.net.ssl.trustStore=$(TRUSTSTORE_P12) ; \
        printf '%s ' -Djavax.net.ssl.trustStorePassword=$(TRUSTSTORE_PASSWORD) ; \
    elif [ 1 = "$(TEST_PKCS11_FIPS)" ] ; then \
        printf '%s ' -Djava.security.properties==$(JAVA_PKCS11_FIPS_SECURITY_CFG) ; \
        if cat "$(JAVA_CONF_DIR)/security/java.security" 2>&1 | grep -q '^fips.provider' ; then \
            printf '%s ' '-Dcom.redhat.fips=true' ; \
        else \
            printf '%s ' '-Djavax.net.ssl.keyStore=NONE' ; \
        fi ; \
    else \
        printf '%s ' -Djavax.net.ssl.keyStore=$(KEYSTORE_JKS) ; \
        printf '%s ' -Djavax.net.ssl.keyStorePassword=$(KEYSTORE_PASSWORD) ; \
        printf '%s ' -Djavax.net.ssl.trustStore=$(TRUSTSTORE_JKS) ; \
        printf '%s ' -Djavax.net.ssl.trustStorePassword=$(TRUSTSTORE_PASSWORD) ; \
    fi ; \
)
JAVA_SECURITY_DEPS := $(shell \
    if [ 1 = "$(TEST_BC)" ] ; then \
        printf '%s %s %s %s %s ' $(JAVA_BC_SECURITY_CFG) $(BC_BCPROV_JAR) $(BC_BCTLS_JAR) $(BC_BCPKIX_JAR) $(KEYSTORE_P12) $(TRUSTSTORE_P12) ; \
    elif [ 1 = "$(TEST_BCJSSE)" ] ; then \
        printf '%s %s %s %s %s %s ' $(JAVA_BCJSSE_SECURITY_CFG) $(BC_BCPROV_JAR) $(BC_BCTLS_JAR) $(BC_BCPKIX_JAR) $(KEYSTORE_P12) $(TRUSTSTORE_P12) ; \
    elif [ 1 = "$(TEST_PKCS11_FIPS)" ] ; then \
        printf '%s ' $(JAVA_PKCS11_FIPS_SECURITY_CFG) ; \
    else \
        printf '%s %s ' $(KEYSTORE_JKS) $(TRUSTSTORE_JKS) ; \
    fi ; \
)
JAVA_CP_APPEND := $(shell \
    if [ 1 = "$(TEST_BC)" ] ; then \
        printf ':%s:%s:%s' $(BC_BCPROV_JAR) $(BC_BCTLS_JAR) $(BC_BCPKIX_JAR) ; \
    elif [ 1 = "$(TEST_BCJSSE)" ] ; then \
        printf ':%s:%s:%s' $(BC_BCPROV_JAR) $(BC_BCTLS_JAR) $(BC_BCPKIX_JAR) ; \
    fi ; \
)

SSLCONTEXTINFO_DIR = SSLContextInfo
SSLCONTEXTINFO_CLASSES_DIR = build/SSLContextInfo
include $(SSLCONTEXTINFO_DIR)/SSLContextInfo.mk

SSLSOCKETINFO_DIR = SSLSocketInfo
SSLSOCKETINFO_CLASSES_DIR = build/SSLSocketInfo
include $(SSLSOCKETINFO_DIR)/SSLSocketInfo.mk

SSLTESTS_DIR = ssl-tests
SSLTESTS_CLASSES_DIR = build/ssl-tests
include $(SSLTESTS_DIR)/ssl-tests.mk

clean:
	rm -rf build

$(JAVA_PKCS11_FIPS_CONF_DIR):
	mkdir $@

$(JAVA_BC_CONF_DIR):
	mkdir $@

$(JAVA_BCJSSE_CONF_DIR):
	mkdir $@

$(BC_JARS_DIRS):
	mkdir $@

$(JAVA_PKCS11_FIPS_NSS_CFG): | $(JAVA_PKCS11_FIPS_CONF_DIR)
	if [ -e $(JAVA_CONF_DIR)/security/nss.fips.cfg ] ; then \
		cp $(JAVA_CONF_DIR)/security/nss.fips.cfg $@ ; \
	    sed -i 's;^nssSecmodDirectory[[:space:]]*=.*$$;nssSecmodDirectory = $(NSSDB_DIR);g' $@ ; \
	else \
		printf '%s\n%s\n%s\n%s\n%s\n' \
		"name = NSS-FIPS" \
		"nssLibraryDirectory = /usr/lib64" \
		"nssSecmodDirectory = $(NSSDB_DIR)" \
		"nssDbMode = readOnly" \
		"nssModule = fips" \
		>> $@ ; \
	fi

$(JAVA_PKCS11_FIPS_SECURITY_CFG): $(JAVA_PKCS11_FIPS_NSS_CFG) | $(JAVA_PKCS11_FIPS_CONF_DIR) $(NSSDB_DIR)
	cp $(JAVA_CONF_DIR)/security/java.security $@
	if cat $@ | grep -q '^fips.provider' ; then \
		if [ 8 -ge $(JAVA_VERSION_MAJOR) ] ; then \
			sed -i 's;^fips.provider.1=sun.security.pkcs11.SunPKCS11.*$$;fips.provider.1=sun.security.pkcs11.SunPKCS11 $(JAVA_PKCS11_FIPS_NSS_CFG);g' $@ ; \
		else \
			sed -i 's;^fips.provider.1=SunPKCS11.*$$;fips.provider.1=SunPKCS11 $(JAVA_PKCS11_FIPS_NSS_CFG);g' $@ ;	\
		fi ; \
		if ! [ 0 = "$(SET_RPMS_KEYSTORE_TYPE)" ] ; then \
			sed -i "s;^keystore.type=.*$$;keystore.type=PKCS11;g" $@ ; \
		fi \
	else \
		sed -i "s;^security\.provider\.;#security.provider;g" $@ ; \
		sed -i 's;^keystore.type=.*$$;keystore.type=PKCS11;g' $@ ; \
		if [ 8 -ge $(JAVA_VERSION_MAJOR) ] ; then \
			printf '%s\n%s\n%s\n%s\n' \
			"security.provider.1=sun.security.pkcs11.SunPKCS11 $(JAVA_PKCS11_FIPS_NSS_CFG)" \
			"security.provider.2=sun.security.provider.Sun" \
			"security.provider.3=sun.security.ec.SunEC" \
			"security.provider.4=com.sun.net.ssl.internal.ssl.Provider SunPKCS11-NSS-FIPS" \
			>> $@ ; \
		else \
			printf '%s\n%s\n%s\n%s\n' \
			"security.provider.1=SunPKCS11 $(JAVA_PKCS11_FIPS_NSS_CFG)" \
			"security.provider.2=SUN" \
			"security.provider.3=SunEC" \
			"security.provider.4=SunJSSE SunPKCS11-NSS-FIPS" \
			>> $@ ; \
		fi ; \
	fi


$(BC_BCPROV_JAR): | $(BC_JARS_DIRS)
	#curl -L -f -o $(BC_BCPROV_JAR) "https://www.bouncycastle.org/download/bcprov-jdk15on-168.jar"
	cp ~/Downloads/bcprov-ext-jdk15on-168.jar $(BC_BCPROV_JAR)

$(BC_BCTLS_JAR): | $(BC_JARS_DIRS)
	#curl -L -f -o $(BC_BCTLS_JAR) "https://www.bouncycastle.org/download/bctls-jdk15on-168.jar"
	cp ~/Downloads/bctls-jdk15on-168.jar $(BC_BCTLS_JAR)

$(BC_BCPKIX_JAR): | $(BC_JARS_DIRS)
	#curl -L -f -o $(BC_BCTLS_JAR) "https://www.bouncycastle.org/download/bcpkix-jdk15on-168.jar"
	cp ~/Downloads/bcpkix-jdk15on-168.jar $(BC_BCPKIX_JAR)

# See: https://downloads.bouncycastle.org/fips-java/BC-FJA-UserGuide-1.0.2.pdf
$(JAVA_BC_SECURITY_CFG): | $(JAVA_BC_CONF_DIR)
	cp $(JAVA_CONF_DIR)/security/java.security $@
	if cat $@ | grep -q '^fips.provider' ; then \
		sed -i 's;^fips.provider;#fips.provider;g' $@ ; \
		if [ 8 -ge $(JAVA_VERSION_MAJOR) ] ; then \
			printf '%s\n%s\n%s\n' \
			"fips.provider.1=org.bouncycastle.jce.provider.BouncyCastleProvider" \
			"fips.provider.2=com.sun.net.ssl.internal.ssl.Provider BC" \
			"fips.provider.3=sun.security.provider.Sun" \
			>> $@ ; \
		else \
			printf '%s\n%s\n%s\n' \
			"fips.provider.1=org.bouncycastle.jce.provider.BouncyCastleProvider" \
			"fips.provider.2=SunJSSE BC" \
			"fips.provider.3=sun.security.provider.Sun" \
			>> $@ ; \
		fi ; \
	fi
	sed -i 's;^security.provider;#security.provider;g' $@
	sed -i 's;keystore.type=.*;keystore.type=pkcs12;g' $@
	if [ 8 -ge $(JAVA_VERSION_MAJOR) ] ; then \
		printf '%s\n%s\n%s\n%s\n' \
		"security.provider.1=org.bouncycastle.jce.provider.BouncyCastleProvider" \
		"security.provider.2=com.sun.net.ssl.internal.ssl.Provider BC" \
		"security.provider.3=sun.security.provider.Sun" \
		"ssl.KeyManagerFactory.algorithm=X509" \
		>> $@ ; \
	else \
		printf '%s\n%s\n%s\n' \
		"security.provider.1=org.bouncycastle.jce.provider.BouncyCastleProvider" \
		"security.provider.2=SunJSSE BC" \
		"security.provider.3=sun.security.provider.Sun" \
		>> $@ ; \
	fi

# See: https://downloads.bouncycastle.org/fips-java/BC-FJA-(D)TLSUserGuide-1.0.9.pdf
$(JAVA_BCJSSE_SECURITY_CFG): | $(JAVA_BCJSSE_CONF_DIR)
	cp $(JAVA_CONF_DIR)/security/java.security $@
	if cat $@ | grep -q '^fips.provider' ; then \
		sed -i 's;^fips.provider;#fips.provider;g' $@ ; \
		printf '%s\n%s\n%s\n' \
		"fips.provider.1=org.bouncycastle.jce.provider.BouncyCastleProvider" \
		"fips.provider.2=org.bouncycastle.jsse.provider.BouncyCastleJsseProvider BC" \
		"fips.provider.3=sun.security.provider.Sun" \
		>> $@ ; \
	fi
	sed -i 's;^security.provider;#security.provider;g' $@
	sed -i 's;keystore.type=.*;keystore.type=pkcs12;g' $@
	printf '%s\n%s\n%s\n' \
	"security.provider.1=org.bouncycastle.jce.provider.BouncyCastleProvider" \
	"security.provider.2=org.bouncycastle.jsse.provider.BouncyCastleJsseProvider BC" \
	"security.provider.3=sun.security.provider.Sun" \
	>> $@ ;
	# http://bouncy-castle.1462172.n4.nabble.com/BC-FIPS-does-not-reject-JKS-keystores-tp4659800.html
	printf '%s\n' \
	"ssl.KeyManagerFactory.algorithm=X509" \
	>> $@ ;


java-pkcs11-fips-conf: $(JAVA_PKCS11_FIPS_SECURITY_CFG)

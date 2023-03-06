JAVA ?= $(shell if [ -n "$(JAVA_HOME)" ] ; then printf '%s/bin/java' "$(JAVA_HOME)" | tr '\\' '/' ; else printf 'java' ; fi )
JAVAC ?= $(shell if [ -n "$(JAVA_HOME)" ] ; then printf '%s/bin/javac' "$(JAVA_HOME)" | tr '\\' '/' ; else printf 'javac' ; fi )
KEYTOOL ?= $(shell if [ -n "$(JAVA_HOME)" ] ; then printf '%s/bin/keytool' "$(JAVA_HOME)" | tr '\\' '/' ; else printf 'keytool' ; fi )
OPENSSL = openssl

JAVA_VERSION_MAJOR := $(shell $(JAVA) -version 2>&1 | grep version | head -n 1 | sed -E 's/^.*"(1[.])?([0-9]+).*$$/\2/g' )
JAVA_HOME_DIR  := $(shell if [ -n "$(JAVA_HOME)" ] ; then printf '%s' "$(JAVA_HOME)" ; else readlink -f $$( which $(JAVA) 2>/dev/null || type $(JAVA) | sed 's;.* ;;g' ) | sed 's;/bin/java$$;;g' | sed 's;/jre$$;;g' ; fi )
JAVA_CONF_DIR := $(shell if [ 8 -ge $(JAVA_VERSION_MAJOR) ] ; then printf '%s' "$(JAVA_HOME_DIR)/jre/lib" ; else printf '%s' "$(JAVA_HOME_DIR)/conf" ; fi )

FIPS_MODE_ENABLED := $(shell if [ -e "/proc/sys/crypto/fips_enabled" ] && [ 1 = $$(cat /proc/sys/crypto/fips_enabled) ] ; then echo 1 ; else echo 0 ; fi )
TEST_PKCS11_FIPS ?= $(shell if [ 1 = $(FIPS_MODE_ENABLED) ] && [ -n "$(JAVA_HOME_DIR)" ] && cat $(JAVA_CONF_DIR)/security/java.security 2>&1 | grep -q '^fips.provider' ; then echo 1; else echo 0 ; fi )
NSSDB_FIPS := $(shell if [ 0 = $(FIPS_MODE_ENABLED) ] && [ 1 = $(TEST_PKCS11_FIPS) ] ; then echo 1 ; else echo 0 ; fi )
NSS_LIBDIR = $(shell \
  if [ -e '/usr/lib64' ] ; then \
    if [ -e /usr/lib64/libnss3.so ] ; then \
        printf '%s' "/usr/lib64" ; \
    else \
        dirname /usr/lib/*linux*/libnss3.so | head -n 1 ; \
    fi \
  else \
    if [ -e /usr/lib/libnss3.so ] ; then \
        printf '%s' "/usr/lib" ; \
    else \
        dirname /usr/lib/*linux*/libnss3.so | head -n 1 ; \
    fi \
  fi \
)
KEYTOOL_PARAMS := $(shell printf '%s ' '-J-Dcom.redhat.fips=false' ; if [ 1 = "$(KEYSTORE_PKCS12_LEGACY)" ] ; then printf '%s ' '-J-Dkeystore.pkcs12.legacy' ; fi )

JAVA_PKCS11_FIPS_CONF_DIR = build/java-pkcs11-conf
JAVA_PKCS11_FIPS_NSS_CFG = $(JAVA_PKCS11_FIPS_CONF_DIR)/nss.fips.cfg
JAVA_PKCS11_FIPS_SECURITY_CFG = $(JAVA_PKCS11_FIPS_CONF_DIR)/java.security

BC_JARS_DIRS = build/bc-jars
BC_VERSION = 1.70
BC_VARIANT = jdk15on
BC_BCPROV_VERSION = $(BC_VERSION)
BC_BCTLS_VERSION = $(BC_VERSION)
BC_BCPKIX_VERSION = $(BC_VERSION)
BC_BCUTIL_VERSION = $(BC_VERSION)
BC_BCPROV_JAR = $(BC_JARS_DIRS)/bcprov-$(BC_VARIANT)-$(BC_BCPROV_VERSION).jar
BC_BCTLS_JAR = $(BC_JARS_DIRS)/bctls-$(BC_VARIANT)-$(BC_BCTLS_VERSION).jar
BC_BCPKIX_JAR = $(BC_JARS_DIRS)/bcpkix-$(BC_VARIANT)-$(BC_BCPKIX_VERSION).jar
BC_BCUTIL_JAR = $(BC_JARS_DIRS)/bcutil-$(BC_VARIANT)-$(BC_BCUTIL_VERSION).jar

BC_BCFIPS_VERSION = 1.0.2.3
BC_BCFIPS_JAR = $(BC_JARS_DIRS)/bc-fips-$(BC_BCFIPS_VERSION).jar

JAVA_BCFIPS_CONF_DIR = build/java-bcfips-conf
JAVA_BCFIPS_SECURITY_CFG = $(JAVA_BCFIPS_CONF_DIR)/java.security

JAVA_BCJSSE_CONF_DIR = build/java-bcjsse-conf
JAVA_BCJSSE_SECURITY_CFG = $(JAVA_BCJSSE_CONF_DIR)/java.security

JAVA_BC_2ND_CONF_DIR = build/java-bc-2nd-conf
JAVA_BC_2ND_SECURITY_CFG = $(JAVA_BC_2ND_CONF_DIR)/java.security

all: ssl-tests

CERTGEN_DIR = certgen
CERTGEN_BUILD_DIR = build/certgen
include $(CERTGEN_DIR)/certgen.mk

# BCFIPS needs workaround for jdk>=13:
# https://github.com/bcgit/bc-java/issues/589#issuecomment-530780788
JAVA_SECURITY_PARAMS := $(shell \
    if [ 1 = "$(TEST_BCFIPS)" ] ; then \
        printf '%s ' -Djava.security.properties==$(JAVA_BCFIPS_SECURITY_CFG) ; \
        printf '%s ' -Djavax.net.ssl.keyStore=$(KEYSTORE_P12) ; \
        printf '%s ' -Djavax.net.ssl.keyStorePassword=$(KEYSTORE_PASSWORD) ; \
        printf '%s ' -Djavax.net.ssl.trustStore=$(TRUSTSTORE_P12) ; \
        printf '%s ' -Djavax.net.ssl.trustStorePassword=$(TRUSTSTORE_PASSWORD) ; \
        printf '%s ' -Dorg.bouncycastle.rsa.allow_multi_use=true ; \
        if [ 13 -le $(JAVA_VERSION_MAJOR) ] ; then \
            printf '%s ' '-Djdk.tls.namedGroups="secp256r1, secp384r1, ffdhe2048, ffdhe3072"' ; \
        fi ; \
    elif [ 1 = "$(TEST_BCJSSE)" ] ; then \
        printf '%s ' -Djava.security.properties==$(JAVA_BCJSSE_SECURITY_CFG) ; \
        printf '%s ' -Djavax.net.ssl.keyStore=$(KEYSTORE_P12) ; \
        printf '%s ' -Djavax.net.ssl.keyStorePassword=$(KEYSTORE_PASSWORD) ; \
        printf '%s ' -Djavax.net.ssl.trustStore=$(TRUSTSTORE_P12) ; \
        printf '%s ' -Djavax.net.ssl.trustStorePassword=$(TRUSTSTORE_PASSWORD) ; \
    elif [ 1 = "$(TEST_BC_2ND)" ] ; then \
        printf '%s ' -Djava.security.properties==$(JAVA_BC_2ND_SECURITY_CFG) ; \
        printf '%s ' -Djavax.net.ssl.keyStore=$(KEYSTORE_P12) ; \
        printf '%s ' -Djavax.net.ssl.keyStorePassword=$(KEYSTORE_PASSWORD) ; \
        printf '%s ' -Djavax.net.ssl.trustStore=$(TRUSTSTORE_P12) ; \
        printf '%s ' -Djavax.net.ssl.trustStorePassword=$(TRUSTSTORE_PASSWORD) ; \
    elif [ 1 = "$(TEST_PKCS11_FIPS)" ] ; then \
        printf '%s ' -Djava.security.properties==$(JAVA_PKCS11_FIPS_SECURITY_CFG) ; \
        printf '%s ' -Djdk.tls.ephemeralDHKeySize=2048 ; \
        if cat "$(JAVA_CONF_DIR)/security/java.security" 2>&1 | grep -q '^fips.provider' && [ 1 = $(FIPS_MODE_ENABLED) ] ; then \
            printf '%s ' '-Dcom.redhat.fips=true' ; \
        else \
            printf '%s ' '-Djavax.net.ssl.keyStore=NONE' ; \
        fi ; \
        if cat "$(JAVA_CONF_DIR)/security/java.security" 2>&1 | grep -q '^fips.keystore.type=pkcs12' ; then \
            printf '%s ' -Djavax.net.ssl.keyStore=$(KEYSTORE_P12) ; \
            printf '%s ' -Djavax.net.ssl.keyStorePassword=$(KEYSTORE_PASSWORD) ; \
            printf '%s ' -Djavax.net.ssl.trustStore=$(TRUSTSTORE_JKS) ; \
            printf '%s ' -Djavax.net.ssl.trustStorePassword=$(TRUSTSTORE_PASSWORD) ; \
        fi ; \
    else \
        printf '%s ' -Djavax.net.ssl.keyStore=$(KEYSTORE_JKS) ; \
        printf '%s ' -Djavax.net.ssl.keyStorePassword=$(KEYSTORE_PASSWORD) ; \
        printf '%s ' -Djavax.net.ssl.trustStore=$(TRUSTSTORE_JKS) ; \
        printf '%s ' -Djavax.net.ssl.trustStorePassword=$(TRUSTSTORE_PASSWORD) ; \
    fi ; \
    if [ 1 = "$(USE_URANDOM)" ] ; then \
        printf '%s ' -Djava.security.egd=file:/dev/./urandom ; \
    fi \
)
JAVA_SECURITY_DEPS := $(shell \
    if [ 1 = "$(TEST_BCFIPS)" ] ; then \
        printf '%s %s %s %s ' $(JAVA_BCFIPS_SECURITY_CFG) $(BC_BCFIPS_JAR) $(KEYSTORE_P12) $(TRUSTSTORE_P12) ; \
    elif [ 1 = "$(TEST_BCJSSE)" ] ; then \
        printf '%s %s %s %s %s %s %s ' $(JAVA_BCJSSE_SECURITY_CFG) $(BC_BCPROV_JAR) $(BC_BCTLS_JAR) $(BC_BCPKIX_JAR) $(BC_BCUTIL_JAR) $(KEYSTORE_P12) $(TRUSTSTORE_P12) ; \
    elif [ 1 = "$(TEST_BC_2ND)" ] ; then \
        printf '%s %s %s %s %s %s %s ' $(JAVA_BC_2ND_SECURITY_CFG) $(BC_BCPROV_JAR) $(BC_BCTLS_JAR) $(BC_BCPKIX_JAR) $(BC_BCUTIL_JAR) $(KEYSTORE_P12) $(TRUSTSTORE_P12) ; \
    elif [ 1 = "$(TEST_PKCS11_FIPS)" ] ; then \
        printf '%s ' $(JAVA_PKCS11_FIPS_SECURITY_CFG) ; \
        if cat "$(JAVA_CONF_DIR)/security/java.security" 2>&1 | grep -q '^fips.keystore.type=pkcs12' ; then \
            printf '%s %s ' $(KEYSTORE_P12) $(TRUSTSTORE_JKS) ; \
        fi ; \
    else \
        printf '%s %s ' $(KEYSTORE_JKS) $(TRUSTSTORE_JKS) ; \
    fi ; \
)
SEP := $(shell if uname -s | grep -qi cygwin ; then printf ';' ; else printf ':' ; fi )
JAVA_CP_APPEND := $(shell \
    if [ 1 = "$(TEST_BCFIPS)" ] ; then \
        printf "$(SEP)%s" $(BC_BCFIPS_JAR) ; \
    elif [ 1 = "$(TEST_BCJSSE)" ] ; then \
        printf "$(SEP)%s$(SEP)%s$(SEP)%s$(SEP)%s" $(BC_BCPROV_JAR) $(BC_BCTLS_JAR) $(BC_BCPKIX_JAR) $(BC_BCUTIL_JAR) ; \
    elif [ 1 = "$(TEST_BC_2ND)" ] ; then \
        printf "$(SEP)%s$(SEP)%s$(SEP)%s$(SEP)%s" $(BC_BCPROV_JAR) $(BC_BCTLS_JAR) $(BC_BCPKIX_JAR) $(BC_BCUTIL_JAR) ; \
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

$(JAVA_BCFIPS_CONF_DIR):
	mkdir $@

$(JAVA_BCJSSE_CONF_DIR):
	mkdir $@

$(JAVA_BC_2ND_CONF_DIR):
	mkdir $@

$(BC_JARS_DIRS):
	mkdir $@

$(JAVA_PKCS11_FIPS_NSS_CFG): | $(JAVA_PKCS11_FIPS_CONF_DIR)
	if [ -e $(JAVA_CONF_DIR)/security/nss.fips.cfg ] ; then \
		cp $(JAVA_CONF_DIR)/security/nss.fips.cfg $@ ; \
	    sed -i 's;^nssSecmodDirectory[[:space:]]*=.*$$;nssSecmodDirectory = $(NSSDB_DIR);g' $@ ; \
	else \
		printf '%s\n%s\n%s\n%s\n%s\n%s\n' \
		"name = NSS-FIPS" \
		"nssLibraryDirectory = $(NSS_LIBDIR)" \
		"nssSecmodDirectory = $(NSSDB_DIR)" \
		"nssDbMode = readOnly" \
		"nssModule = fips" \
		"attributes(*,CKO_SECRET_KEY,CKK_GENERIC_SECRET)={ CKA_SIGN=true }" \
		>> $@ ; \
	fi

$(JAVA_PKCS11_FIPS_SECURITY_CFG): $(JAVA_PKCS11_FIPS_NSS_CFG) | $(JAVA_PKCS11_FIPS_CONF_DIR) $(NSSDB_DIR)
	cp $(JAVA_CONF_DIR)/security/java.security $@
	printf '\n' >> $@ ;
	if cat $@ | grep -q '^fips.provider' && [ 1 = $(FIPS_MODE_ENABLED) ] ; then \
		if [ 8 -ge $(JAVA_VERSION_MAJOR) ] ; then \
			sed -i 's;^fips.provider.1=sun.security.pkcs11.SunPKCS11.*$$;fips.provider.1=sun.security.pkcs11.SunPKCS11 $(JAVA_PKCS11_FIPS_NSS_CFG);g' $@ ; \
		else \
			sed -i 's;^fips.provider.1=SunPKCS11.*$$;fips.provider.1=SunPKCS11 $(JAVA_PKCS11_FIPS_NSS_CFG);g' $@ ;	\
		fi ; \
		if ! [ 0 = "$(SET_RPMS_KEYSTORE_TYPE)" ] \
		&& cat $@ 2>&1 | grep -q '^fips.keystore.type=PKCS11' ; then \
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
	curl -L -f -o $(BC_BCPROV_JAR) "https://repo1.maven.org/maven2/org/bouncycastle/bcprov-$(BC_VARIANT)/$(BC_BCPROV_VERSION)/bcprov-$(BC_VARIANT)-$(BC_BCPROV_VERSION).jar"

$(BC_BCTLS_JAR): | $(BC_JARS_DIRS)
	curl -L -f -o $(BC_BCTLS_JAR) "https://repo1.maven.org/maven2/org/bouncycastle/bctls-$(BC_VARIANT)/$(BC_BCTLS_VERSION)/bctls-$(BC_VARIANT)-$(BC_BCTLS_VERSION).jar"

$(BC_BCPKIX_JAR): | $(BC_JARS_DIRS)
	curl -L -f -o $(BC_BCPKIX_JAR) "https://repo1.maven.org/maven2/org/bouncycastle/bcpkix-$(BC_VARIANT)/$(BC_BCPKIX_VERSION)/bcpkix-$(BC_VARIANT)-$(BC_BCPKIX_VERSION).jar"

$(BC_BCUTIL_JAR): | $(BC_JARS_DIRS)
	curl -L -f -o $(BC_BCUTIL_JAR) "https://repo1.maven.org/maven2/org/bouncycastle/bcutil-$(BC_VARIANT)/$(BC_BCUTIL_VERSION)/bcutil-$(BC_VARIANT)-$(BC_BCUTIL_VERSION).jar"

$(BC_BCFIPS_JAR): | $(BC_JARS_DIRS)
	curl -L -f -o $(BC_BCFIPS_JAR) "https://repo1.maven.org/maven2/org/bouncycastle/bc-fips/$(BC_BCFIPS_VERSION)/bc-fips-$(BC_BCFIPS_VERSION).jar"

# See: https://downloads.bouncycastle.org/fips-java/BC-FJA-UserGuide-1.0.2.pdf
# this setup requires BCFIPS provider as BC provider does not provide "SunTlsMasterSecret":
# https://github.com/openjdk/jdk/blob/05a764f4ffb8030d6b768f2d362c388e5aabd92d/src/java.base/share/classes/sun/security/ssl/SSLMasterKeyDerivation.java#L105
# this prevents testing anything else than TLSv1.3
# C:HYBRID;ENABLE{All}; should make BC less entropy hungry, see section 2.3 of guide higer

$(JAVA_BCFIPS_SECURITY_CFG): | $(JAVA_BCFIPS_CONF_DIR)
	cp $(JAVA_CONF_DIR)/security/java.security $@
	printf '\n' >> $@ ;
	if cat $@ | grep -q '^fips.provider' ; then \
		sed -i 's;^fips.provider;#fips.provider;g' $@ ; \
		if [ 8 -ge $(JAVA_VERSION_MAJOR) ] ; then \
			printf '%s\n%s\n%s\n' \
			"fips.provider.1=org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider C:HYBRID;ENABLE{All};" \
			"fips.provider.2=com.sun.net.ssl.internal.ssl.Provider BCFIPS" \
			"fips.provider.3=sun.security.provider.Sun" \
			>> $@ ; \
		else \
			printf '%s\n%s\n%s\n' \
			"fips.provider.1=org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider C:HYBRID;ENABLE{All};" \
			"fips.provider.2=SunJSSE BCFIPS" \
			"fips.provider.3=sun.security.provider.Sun" \
			>> $@ ; \
		fi ; \
	fi
	sed -i 's;^security.provider;#security.provider;g' $@
	sed -i 's;keystore.type=.*;keystore.type=pkcs12;g' $@
	if [ 8 -ge $(JAVA_VERSION_MAJOR) ] ; then \
		printf '%s\n%s\n%s\n%s\n' \
		"security.provider.1=org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider C:HYBRID;ENABLE{All};" \
		"security.provider.2=com.sun.net.ssl.internal.ssl.Provider BCFIPS" \
		"security.provider.3=sun.security.provider.Sun" \
		"ssl.KeyManagerFactory.algorithm=PKIX" \
		>> $@ ; \
	else \
		printf '%s\n%s\n%s\n' \
		"security.provider.1=org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider C:HYBRID;ENABLE{All};" \
		"security.provider.2=SunJSSE BCFIPS" \
		"security.provider.3=sun.security.provider.Sun" \
		>> $@ ; \
	fi

# See: https://downloads.bouncycastle.org/fips-java/BC-FJA-(D)TLSUserGuide-1.0.9.pdf
$(JAVA_BCJSSE_SECURITY_CFG): | $(JAVA_BCJSSE_CONF_DIR)
	cp $(JAVA_CONF_DIR)/security/java.security $@
	printf '\n' >> $@ ;
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

# BC inserted as second provider, see:
# https://docs.oracle.com/cd/E19830-01/819-4712/ablsc/index.html
# http://tomee.apache.org/bouncy-castle.html
# https://bugs.openjdk.java.net/browse/JDK-8256252
$(JAVA_BC_2ND_SECURITY_CFG): | $(JAVA_BC_2ND_CONF_DIR)
	cp $(JAVA_CONF_DIR)/security/java.security $@
	printf '\n' >> $@ ;
	i=2 ; \
	while cat $@ | grep -q "^security.provider.$${i}[[:space:]]*=" ; do \
		i=$$(( i + 1 )) ; \
	done ; \
	while [ $${i} -ge 2 ] ; do \
		sed -i "s;^security.provider.$${i}[[:space:]]*=;security.provider.$$(( i + 1 ))=;g"  $@ ; \
		i=$$(( i - 1 )) ; \
	done
	sed -i 's;keystore.type=.*;keystore.type=pkcs12;g' $@
	printf '%s\n' \
	"security.provider.2=org.bouncycastle.jce.provider.BouncyCastleProvider" \
	>> $@ ;
	if cat $@ | grep -q '^fips.provider' ; then \
		sed -i 's;^fips.provider;#fips.provider;g' $@ ; \
	    providers="$$( cat $@ | grep '^security.provider.*$$' )" ; \
	    printf '%s\n' "$${providers}" | sed 's;^security.provider;fips.provider;g' \
	    >> $@ ; \
	fi

java-pkcs11-fips-conf: $(JAVA_PKCS11_FIPS_SECURITY_CFG)

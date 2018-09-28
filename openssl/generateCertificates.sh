#!/usr/bin/env bash

cd "$(dirname "$0")"

crtDir="../crt/"
domainKey=${crtDir}domain.localhost.key
domainCrt=${crtDir}domain.localhost.crt
caKey=${crtDir}ca.key
caCrt=${crtDir}ca.crt
bundleCrt=${crtDir}domain.localhost.bundle.crt

csrDir="csr/"
domainCsr=${csrDir}domain.localhost.csr

cnfDir="cnf/"
domainCnf=${cnfDir}domain/domain.cnf
domainExtensionsCnf=${cnfDir}domain/ssl-extensions-x509.cnf
caCnf=${cnfDir}ca/ca.cnf
caReqCnf=${cnfDir}ca/ca-req.cnf
caExtensionsCnf=${cnfDir}ca/ssl-extensions-x509.cnf

openssl req -config ${domainCnf} -nodes -new -out ${domainCsr} -keyout ${domainKey} -days 24854
openssl genrsa -out ${caKey} 2048
openssl req -config ${caReqCnf} -new -x509 -key ${caKey} -out ${caCrt} -days 24854
openssl x509 -req -in ${domainCsr} -CA ${caCrt} -CAkey ${caKey} -CAcreateserial -out ${domainCrt} -extensions v3_ca -extfile ${domainExtensionsCnf} -days 24854
openssl ca -config ${caCnf} \
        -keyfile ${caKey} \
        -cert ${caCrt} \
        -out ${domainCrt} \
        -outdir ${crtDir} \
        -infiles ${domainCsr} \
        -extensions v3_ca \
        -extfile ${domainExtensionsCnf} \
        -copy_extensions copyall
openssl verify -CAfile ${caCrt} ${domainCrt}
cat ${domainCrt} ${caCrt} > ${bundleCrt}

systemCrtDir="/usr/local/share/ca-certificates/"
systemCrtPath=${systemCrtDir}localhost-ca.crt

echo 'Installing certificate to system'
sudo rm -f ${systemCrtPath}
sudo cp ${caCrt} ${systemCrtPath}
sudo update-ca-certificates

echo "Installing certificates to NSS PKI DB"
if ! [ -x "$(command -v certutil)" ]; then
    sudo apt install libnss3-tools
fi

certName="localhost-ca"

for certDB in $(sudo find ~/ -name "cert8.db" 2>/dev/null)
do
    certdir=$(dirname ${certDB});
    echo "Found cert8.db in ${certdir}"
    sudo certutil -D-n ${certName} -d sql:${certdir} > /dev/null 2>&1
    sudo certutil -A -n ${certName} -t "TCu,Cu,Tu" -i ${caCrt} -d sql:${certdir}
done

for certDB in $(sudo find ~/ -name "cert9.db" 2>/dev/null)
do
    certdir=$(dirname ${certDB});
    echo "Found crt cert9.db in ${certdir}"
    sudo certutil -D -n ${certName} -d sql:${certdir} > /dev/null 2>&1
    sudo certutil -A -n ${certName} -t "TCu,Cu,Tu" -i ${caCrt} -d sql:${certdir}
done

echo 'done.'

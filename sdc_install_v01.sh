#! /bin/bash

SDC_TARFILE=streamsets-datacollector-all-1.6.0.0.tgz
SDC_DIRNAME=streamsets-datacollector-1.6.0.0
SDC_TARFILEURI=https://archives.streamsets.com/datacollector/latest/tarball/$SDC_TARFILE

SDC_TMPFOLDER=/tmp/streamsets
SDC_INSTALLFOLDER=/usr/share/$SDC_DIRNAME

checkHostNameAndSetClusterName() {
    fullHostName=$(hostname -f)
    echo "fullHostName=$fullHostName"
    CLUSTERNAME=$(sed -n -e 's/.*\.\(.*\)-ssh.*/\1/p' <<< $fullHostName)
    if [ -z "$CLUSTERNAME" ]; then
        CLUSTERNAME=$(echo -e "import hdinsight_common.ClusterManifestParser as ClusterManifestParser\nprint ClusterManifestParser.parse_local_manifest().deployment.cluster_name" | python)
        if [ $? -ne 0 ]; then
            echo "[ERROR] Cannot determine cluster name. Exiting!"
            exit 133
        fi
    fi
    echo "Cluster Name=$CLUSTERNAME"
}

checkJava() {
  #TODO: check if we have Oracle Java
  echo '**************************************************************'
  echo "** StreamSets Data Collector requires Oracle Java to run... **"
  echo '**************************************************************'
}

downloadAndUnzipStreamSets() {
    echo "Removing StreamSets installation and tmp folder"

    rm -rf $SDC_INSTALLFOLDER/
    rm -rf $SDC_TMPFOLDER/
    mkdir $SDC_TMPFOLDER/

    echo "Downloading StreamSets tar file"
    wget $SDC_TARFILEURI -P $SDC_TMPFOLDER

    echo "Unzipping StreamSets"
    cd $SDC_TMPFOLDER
    sudo tar -zxvf $SDC_TARFILE -C /usr/share/

    rm -rf $SDC_TMPFOLDER/
}

setupStreamSetsService() {
    echo "Adding sdc user"
    useradd -G sdc sdc

    echo "Copy sdcinitd to /etc/init.d"
    cp -f $SDC_INSTALLFOLDER/initd/_sdcinitd_prototype /etc/init.d/sdc


    echo "Making sdc a service and starting it"
    sed -i "s#export SDC_DIST=\"\"#export SDC_DIST=\"$SDC_INSTALLFOLDER\"#g" /etc/init.d/sdc
    sed -i "s#export SDC_HOME=\"\"#export SDC_HOME=\"$SDC_INSTALLFOLDER\"#g" /etc/init.d/sdc

    chmod 755 /etc/init.d/sdc

    mkdir -p /etc/sdc

    cp -R $SDC_INSTALLFOLDER/etc/* /etc/sdc

    chown -R sdc:sdc /etc/sdc

    chmod go-rwx /etc/sdc/form-realm.properties

    mkdir -p /var/log/sdc
    chown -R sdc:sdc /var/log/sdc

    mkdir -p /var/lib/sdc
    chown -R sdc:sdc /var/lib/sdc

    mkdir -p /var/lib/sdc-resources
    chown -R sdc:sdc /var/lib/sdc-resources

    service sdc start

    update-rc.d sdc defaults 97 03
}


if [ "$(id -u)" != "0" ]; then
    echo "[ERROR] This script has to be run as root."
    usage
fi

if [ -e $SDC_INSTALLFOLDER ]; then
    echo "StreamSets is already installed. Exiting ..."
    exit 0
fi

checkHostNameAndSetClusterName
checkJava
downloadAndUnzipStreamSets
setupStreamSetsService

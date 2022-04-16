#!/bin/bash

# variables
kafkaversion=3.1.0
builddir=/tmp/splunk-kafka-connect-build/splunk-kafka-connect

githash=`git rev-parse --short HEAD 2>/dev/null | sed "s/\(.*\)/@\1/"` # get current git hash
gitbranch=`git rev-parse --abbrev-ref HEAD` # get current git branch
gitversion=`git describe --abbrev=0 --tags 2>/dev/null` # returns the latest tag from current commit
jarversion=${gitversion}

# if no version found from git tag, it is a dev build
if [[ -z "$gitversion" ]]; then
  gitversion="dev"
  jarversion=${gitversion}-SNAPSHOT
fi

packagename=splunk-kafka-connect-${gitversion}.tar.gz

# record git info in version.properties file under resources folder
resourcedir='src/main/resources'
/bin/rm -f ${resourcedir}/version.properties
echo githash=${githash} >> ${resourcedir}/version.properties
echo gitbranch=${gitbranch} >> ${resourcedir}/version.properties
echo gitversion=${gitversion} >> ${resourcedir}/version.properties


curdir=`pwd`

/bin/rm -rf ${builddir}
mkdir -p ${builddir}/connectors
mkdir -p ${builddir}/bin
mkdir -p ${builddir}/config
mkdir -p ${builddir}/libs

# Build the package
echo "Building the connector package ..."
mvn versions:set -DnewVersion=${jarversion}
mvn package > /dev/null 2>&1

# Copy over the package
echo "Copy over splunk-kafka-connect jar ..."
cp target/splunk-kafka-connect-${jarversion}.jar ${builddir}/connectors
cp config/connect-distributed-quickstart.properties ${builddir}/config/connect-distributed.properties
cp README.md ${builddir}
cp LICENSE ${builddir}

# Download kafka
echo "Downloading kafka_2.13-${kafkaversion} ..."
wget -q --no-check-certificate https://archive.apache.org/dist/kafka/${kafkaversion}/kafka_2.13-${kafkaversion}.tgz -P ${builddir}
cd ${builddir} && tar xzf kafka_2.13-${kafkaversion}.tgz

# Copy over kafka connect runtime
echo "Copy over kafka connect runtime ..."
cp kafka_2.13-${kafkaversion}/bin/connect-distributed.sh ${builddir}/bin
cp kafka_2.13-${kafkaversion}/bin/kafka-run-class.sh ${builddir}/bin
cp kafka_2.13-${kafkaversion}/config/connect-log4j.properties ${builddir}/config
cp kafka_2.13-${kafkaversion}/libs/*.jar ${builddir}/libs

# Clean up
echo "Clean up ..."
/bin/rm -rf kafka_2.13-${kafkaversion}
/bin/rm -f kafka_2.13-${kafkaversion}.tgz


# Create a container image
mv /tmp/splunk-kafka-connect-build/splunk-kafka-connect build
docker build build -t turbonomic/splunk-kafka-connect

/bin/rm -rf build/splunk-kafka-connect
echo "Done with build & packaging"

echo

cat << EOP
To run the splunk-kafka-connect, do the following steps:
1. untar the package: tar xzf splunk-kafka-connect.tar.gz
2. config config/connect-distributed.properties according to your env
3. run: bash bin/connect-distributed.sh config/connect-distributed.properties
4. Use Kafka Connect REST api to create data collection tasks
EOP

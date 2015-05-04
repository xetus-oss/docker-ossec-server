#!/bin/bash

#
# OSSEC container bootstrap. See the README for information of the environment
# variables expected by this script.
#
source /data_dirs.env
FIRST_TIME_INSTALLATION=false
DATA_PATH=/var/ossec/data

for ossecdir in "${DATA_DIRS[@]}"; do
  if [ ! -e "${DATA_PATH}/${ossecdir}" ]
  then
    echo "Installing ${ossecdir}"
    cp -pr /var/ossec/${ossecdir}-template ${DATA_PATH}/${ossecdir}
    FIRST_TIME_INSTALLATION=true
  fi
done

#
# Check for the process_list file. If this file is missing, it doesn't
# count as a first time installation
#
touch ${DATA_PATH}/process_list
chgrp ossec ${DATA_PATH}/process_list
chmod g+rw ${DATA_PATH}/process_list

#
# If this is a first time installation, then do the  
# special configuration steps.
#
AUTO_ENROLLMENT_ENABLED=${AUTO_ENROLLMENT_ENABLED:-true}

#
# Support SMTP, if configured
#
SMTP_ENABLED_DEFAULT=false
if [ -n "$ALERTS_TO_EMAIL" ]
then
  SMTP_ENABLED_DEFAULT=true
fi
SMTP_ENABLED=${SMTP_ENABLED:-$SMTP_ENABLED_DEFAULT}

if [ $FIRST_TIME_INSTALLATION == true ]
then 
  
  #
  # Support auto-enrollment if configured
  #
  if [ $AUTO_ENROLLMENT_ENABLED == true ]
  then
    if [ ! -e ${DATA_PATH}/etc/sslmanager.key ]
    then
      echo "Creating ossec-authd key and cert"
      openssl genrsa -out ${DATA_PATH}/etc/sslmanager.key 4096
      openssl req -new -x509 -key ${DATA_PATH}/etc/sslmanager.key\
        -out ${DATA_PATH}/etc/sslmanager.cert -days 3650\
        -subj /CN=${HOSTNAME}/
    fi
  fi

  if [ $SMTP_ENABLED == true ]
  then
    if [[ -z "$SMTP_RELAY_HOST" || -z "$ALERTS_TO_EMAIL" ]]
    then
      echo "Unable to configure SMTP, SMTP_RELAY_HOST or ALERTS_TO_EMAIL not defined"
      SMTP_ENABLED=false
    else
      
      ALERTS_FROM_EMAIL=${ALERTS_FROM_EMAIL:-ossec_alerts@$HOSTNAME}
      echo "d-i  ossec-hids/email_notification  boolean yes" >> /tmp/debconf.selections
      echo "d-i  ossec-hids/email_from  string $ALERTS_FROM_EMAIL" >> /tmp/debconf.selections
      echo "d-i  ossec-hids/email_to  string $ALERTS_TO_EMAIL" >> /tmp/debconf.selections
      echo "d-i  ossec-hids/smtp_server  string $SMTP_RELAY_HOST" >> /tmp/debconf.selections
    fi
  fi
  
  if [ $SMTP_ENABLED == false ]
  then
    echo "d-i  ossec-hids/email_notification  boolean no" >> /tmp/debconf.selections
  fi

  if [ -e /tmp/debconf.selections ]
  then
    debconf-set-selections /tmp/debconf.selections
    dpkg-reconfigure -f noninteractive ossec-hids
    rm /tmp/debconf.selections
    /var/ossec/bin/ossec-control stop
  fi

  #
  # Support SYSLOG forwarding, if configured
  #
  SYSLOG_FORWADING_ENABLED=${SYSLOG_FORWADING_ENABLED:-false}
  if [ $SYSLOG_FORWADING_ENABLED == true ]
  then
    if [ -z "$SYSLOG_FORWARDING_SERVER_IP" ]
    then
      echo "Cannot setup sylog forwarding because SYSLOG_FORWARDING_SERVER_IP is not defined"
    else
      SYSLOG_FORWARDING_SERVER_PORT=${SYSLOG_FORWARDING_SERVER_PORT:-514}
      SYSLOG_FORWARDING_FORMAT=${SYSLOG_FORWARDING_FORMAT:-default}
      SYSLOG_XML_SNIPPET="\
  <syslog_output>\n\
    <server>${SYSLOG_FORWARDING_SERVER_IP}</server>\n\
    <port>${SYSLOG_FORWARDING_SERVER_PORT}</port>\n\
    <format>${SYSLOG_FORWARDING_FORMAT}</format>\n\
  </syslog_output>";

      cat /var/ossec/etc/ossec.conf |\
        perl -pe "s,<ossec_config>,<ossec_config>\n${SYSLOG_XML_SNIPPET}\n," \
        > /var/ossec/etc/ossec.conf-new
      mv -f /var/ossec/etc/ossec.conf-new /var/ossec/etc/ossec.conf
      chgrp ossec /var/ossec/etc/ossec.conf
      /var/ossec/bin/ossec-control enable client-syslog
    fi
  fi
fi

function ossec_shutdown(){
  /var/ossec/bin/ossec-control stop;
  if [ $AUTO_ENROLLMENT_ENABLED == true ]
  then
     kill $AUTHD_PID
  fi
}

# Trap exit signals and do a proper shutdown
trap "ossec_shutdown; exit" SIGINT SIGTERM

#
# Startup the services
#
chmod -R g+rw ${DATA_PATH}/logs/ ${DATA_PATH}/stats/ ${DATA_PATH}/queue/ ${DATA_PATH}/etc/client.keys
/var/ossec/bin/ossec-control start
if [ $AUTO_ENROLLMENT_ENABLED == true ]
then
  echo "Starting ossec-authd..."
  /var/ossec/bin/ossec-authd -p 1515 -g ossec $AUTHD_OPTIONS >/dev/null 2>&1 &
  AUTHD_PID=$!
fi
sleep 15 # give ossec a reasonable amount of time to start before checking status
LAST_OK_DATE=`date +%s`

#
# Watch the service in a while loop, exit if the service exits
#
STATUS_CMD="service ossec status | sed '/ossec-maild/d' | grep 'is not running' | test -z"
if [ $SMTP_ENABLED == true ]
then
  STATUS_CMD="/var/ossec/bin/ossec-control status"
fi

while true
do
  eval $STATUS_CMD > /dev/null
  if (( $? != 0 ))
  then
    CUR_TIME=`date +%s`
    # Allow ossec to not run return an ok status for up to 15 seconds 
    # before worring.
    if (( (CUR_TIME - LAST_OK_DATE) > 15 ))
    then
      echo "ossec not properly running! exiting..."
      ossec_shutdown
      exit 1
    fi
  else
    LAST_OK_DATE=`date +%s`
  fi
  sleep 1
done
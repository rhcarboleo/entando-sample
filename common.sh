#!/usr/bin/env bash
export ENTANDO_OPS_HOME=https://raw.githubusercontent.com/entando/entando-ops/EN-1541
export OPENSHIFT_PROJECT=entando-sample

function get_property {
    echo "$(cat $(dirname $0)/target/all-filters/all-filters.properties | grep -oP "(?<=^profile\.$1\=).+$")"
}
function echo_header() {
    echo
    echo "########################################################################"
    echo $1
    echo "########################################################################"
}
function set_openshift_project(){
    oc whoami 2> /dev/null
    if ! [[ $? -eq 0  ]]; then
        echo "Please first log into Openshift using oc login -u <<your username>>"
        exit 1;
    fi
    if oc project ${OPENSHIFT_PROJECT}; then
      echo "Welcome to ${OPENSHIFT_PROJECT}";
    else
      oc new-project ${OPENSHIFT_PROJECT};
    fi;
}
function calculate_mirror_url(){
    APPLICATION_NAME=$(get_property application.name)
    NEXUS_URL="$( oc describe route $APPLICATION_NAME-nexus|grep -oP "(?<=Requested\sHost:\t\t)[^ ]+")"
    if [ ! -z $NEXUS_URL ]; then
        NEXUS_URL="http://$NEXUS_URL/repository/maven-public"
    fi
    echo $NEXUS_URL
}

function get_openshift_subdomain(){
    #TODO also inspect openshift config: minishift openshift config view | grep
    PUBLIC_HOSTNAME=$(minishift config get public-hostname)
    if [[ $PUBLIC_HOSTNAME == "<nil>" ]]; then
       PUBLIC_HOSTNAME=$(minishift openshift config view | grep -oP "(?<=  subdomain: )[0-9\.a-zA-Z_\-]+")
       if [[ -z $PUBLIC_HOSTNAME ]]; then
          echo "$(minishift ip).nip.io"
       else
          echo $PUBLIC_HOSTNAME
       fi
    else
        echo $PUBLIC_HOSTNAME
    fi
}

#!/usr/bin/env bash
export ENTANDO_OPS_HOME=~/Code/entando/entando-ops/
export OPENSHIFT_PROJECT=$(cat src/main/filters/filter-openshift-eap.properties | grep -oP "(?<=profile\.openshift\.project\=).+$")
function generate_expanded_properties_file(){
#for the time being we are only really interest in some basic properties, but in future we may
#want to exploit property expansion more in which case we may need to generate per profile
   mvn resources:copy-resources@generate-filter-properties -Popenshift-eap
}
function get_property {
    echo "$(cat $(dirname $0)/target/filters/filter-openshift-eap.properties | grep -oP "(?<=^profile\.$1\=).+$")"
}
function echo_header() {
    echo
    echo "########################################################################"
    echo $1
    echo "########################################################################"
}
function set_openshift_project(){
    if oc project ${OPENSHIFT_PROJECT}; then
      echo "Welcome to ${OPENSHIFT_PROJECT}";
    else
      oc new-project ${OPENSHIFT_PROJECT};
    fi;
}
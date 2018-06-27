#!/usr/bin/env bash
source $(dirname $0)/common.sh

function import_kie_imagestreams() {
    echo_header "Importing KIE Image Streams"
    oc delete is rhpam70-businesscentral-openshift 2> /dev/null
    oc delete is rhpam70-businesscentral-monitoring-openshift 2> /dev/null
    oc delete is rhpam70-kieserver-openshift 2> /dev/null
    oc delete is rhpam70-controller-openshift 2> /dev/null
    oc delete is rhpam70-smartrouter-openshift 2> /dev/null
    oc delete is rhpam70-businesscentral-indexing-openshift 2> /dev/null
    oc create -f https://raw.githubusercontent.com/jboss-container-images/rhpam-7-openshift-image/7.0.0.GA/rhpam70-image-streams.yaml
}

function create_secrets_and_linked_service_accounts() {
    echo_header "Creating PAM Central keystore secret."
    oc delete sa businesscentral-service-account 2> /dev/null
    oc delete secret businesscentral-app-secret 2> /dev/null
    oc process -f https://raw.githubusercontent.com/jboss-container-images/rhpam-7-openshift-image/rhpam70-dev/example-app-secret-template.yaml | oc create -f -
    oc create serviceaccount businesscentral-service-account
    sleep 0.5 #to give Openshift time to apply changes in time
    oc secrets link --for=mount businesscentral-service-account businesscentral-app-secret

    echo_header "Creating KIEServer keystore secret."
    oc delete secret kieserver-app-secret 2> /dev/null
    oc delete sa kieserver-service-account 2> /dev/null
    oc process -f https://raw.githubusercontent.com/jboss-container-images/rhpam-7-openshift-image/rhpam70-dev/example-app-secret-template.yaml -p SECRET_NAME=kieserver-app-secret | oc create -f -
    oc create serviceaccount kieserver-service-account
    sleep 0.5
    oc secrets link --for=mount kieserver-service-account kieserver-app-secret

}

function create_kie_application() {
    echo_header "Creating Process Automation Manager 7 Application config."
    APPLICATION_NAME="pam"
    oc delete services "$APPLICATION_NAME-rhpamcentr" 2> /dev/null
    oc delete services "$APPLICATION_NAME-kieserver" 2> /dev/null
    oc delete routes "$APPLICATION_NAME-rhpamcentr" 2> /dev/null
oc delete routes "secure-$APPLICATION_NAME-rhpamcentr" 2> /dev/null
    oc delete routes "$APPLICATION_NAME-kieserver" 2> /dev/null
    oc delete routes "secure-$APPLICATION_NAME-kieserver" 2> /dev/null
    oc delete deploymentconfigs "$APPLICATION_NAME-rhpamcentr" 2> /dev/null
    oc delete deploymentconfigs "$APPLICATION_NAME-kieserver" 2> /dev/null
    oc delete persistentvolumeclaims "$APPLICATION_NAME-rhpamcentr-claim" 2> /dev/null
    oc delete persistentvolumeclaims "$APPLICATION_NAME-h2-claim" 2> /dev/null
    oc process -f https://raw.githubusercontent.com/jboss-container-images/rhpam-7-openshift-image/7.0.0.GA/templates/rhpam70-authoring.yaml \
            -p APPLICATION_NAME="$APPLICATION_NAME" \
            -p BUSINESS_CENTRAL_HTTPS_SECRET=businesscentral-app-secret \
            -p KIE_SERVER_HTTPS_SECRET=kieserver-app-secret \
            -p IMAGE_STREAM_NAMESPACE="pam" \
            -p IMAGE_STREAM_TAG="1.0" \
            -p KIE_ADMIN_USER="pamAdmin" \
            -p KIE_ADMIN_PWD="redhatpam1!" \
            -p KIE_SERVER_CONTROLLER_USER="ampie" \
            -p KIE_SERVER_CONTROLLER_PWD="P@ssword" \
            -p KIE_SERVER_USER="ampie" \
            -p KIE_SERVER_PWD="P@ssword" \
            -p BUSINESS_CENTRAL_MEMORY_LIMIT="2Gi" \
            | oc create -f -

}
generate_expanded_properties_file openshift
import_kie_imagestreams
create_secrets_and_linked_service_accounts
create_kie_application
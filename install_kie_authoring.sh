#!/usr/bin/env bash
source $(dirname $0)/common.sh

function recreate_kie_imagestreams() {
    echo_header "Importing KIE Image Streams"
    YAML_URL=https://raw.githubusercontent.com/jboss-container-images/rhpam-7-openshift-image/7.0.0.GA/rhpam70-image-streams.yaml
    oc replace --force --grace-period 60 -f $YAML_URL
}

function recreate_secrets_and_linked_service_accounts() {
    echo_header "Creating PAM Central keystore secret."
    oc delete sa businesscentral-service-account 2> /dev/null
    oc process -f https://raw.githubusercontent.com/jboss-container-images/rhpam-7-openshift-image/rhpam70-dev/example-app-secret-template.yaml \
          | oc replace --force --grace-period 60  -f -
    oc create serviceaccount businesscentral-service-account
    sleep 0.5 #very unscientific way to give Openshift time to apply changes in time
    oc secrets link --for=mount businesscentral-service-account businesscentral-app-secret

    echo_header "Creating KIEServer keystore secret."
    oc delete sa kieserver-service-account 2> /dev/null
    oc process -f https://raw.githubusercontent.com/jboss-container-images/rhpam-7-openshift-image/rhpam70-dev/example-app-secret-template.yaml \
          -p SECRET_NAME=kieserver-app-secret \
          | oc  replace --force --grace-period 60  -f -
    oc create serviceaccount kieserver-service-account
    sleep 0.5 #very unscientific way to give Openshift time to apply changes in time
    oc secrets link --for=mount kieserver-service-account kieserver-app-secret
}

function recreate_kie_application() {
    echo_header "Creating Process Automation Manager 7 Application config."
    APPLICATION_NAME="pam"
    DOMAIN_SUFFIX=get_openshift_subdomain
    oc process -f https://raw.githubusercontent.com/jboss-container-images/rhpam-7-openshift-image/7.0.0.GA/templates/rhpam70-authoring.yaml \
            -p APPLICATION_NAME="$APPLICATION_NAME" \
            -p BUSINESS_CENTRAL_HTTPS_SECRET=businesscentral-app-secret \
            -p KIE_SERVER_HTTPS_SECRET=kieserver-app-secret \
            -p IMAGE_STREAM_NAMESPACE="${OPENSHIFT_PROJECT}" \
            -p IMAGE_STREAM_TAG="1.0" \
            -p KIE_ADMIN_USER="pamAdmin" \
            -p KIE_ADMIN_PWD="redhatpam1!" \
            -p KIE_SERVER_CONTROLLER_USER="ampie" \
            -p KIE_SERVER_CONTROLLER_PWD="P@ssword" \
            -p KIE_SERVER_USER="ampie" \
            -p KIE_SERVER_PWD="P@ssword" \
            -p BUSINESS_CENTRAL_MEMORY_LIMIT="2Gi" \
            -p EXECUTION_SERVER_HOSTNAME_HTTP="http://pam-kieserver-$OPENSHIFT_PROJECT.$DOMAIN_SUFFIX/" \
            | oc replace --force --grace-period 60  -f -

}
set_openshift_project
recreate_kie_imagestreams
recreate_secrets_and_linked_service_accounts
recreate_kie_application

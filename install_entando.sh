#!/usr/bin/env bash
source $(dirname $0)/common.sh
export ENTANDO_OPS_HOME=~/Code/entando/entando-ops

function import_entando_image_streams(){
    echo_header "Importing Entando Image Streams"
    IMAGES=("app-builder-openshift" "entando-eap71-quickstart-openshift")
    for IMAGE in "${IMAGES[@]}"
    do
        oc replace --force --grace-period 60  -f $ENTANDO_OPS_HOME/Openshift/image-streams/$IMAGE.json
    done
}
import_entando_image_streams
oc process -f $ENTANDO_OPS_HOME/Openshift/templates/entando-eap71-quickstart.yml \
 -p ENTANDO_RUNTIME_HOSTNAME_HTTP=entando-runtime.192.168.42.117.nip.io \
 -p ENTANDO_APP_BUILDER_HOSTNAME_HTTP=appbuilder.192.168.42.117.nip.io \
 -p KIE_SERVER_BASE_URL=http://pam-kieserver-pam.192.168.42.117.nip.io/ \
 -p KIE_SERVER_USERNAME=ampie \
 -p KIE_SERVER_PASSWORD=P@ssword \
 -p IMAGE_STREAM_NAMESPACE=${OPENSHIFT_PROJECT} \
 | oc replace --force --grace-period 60  -f -

#!/usr/bin/env bash
source $(dirname $0)/common.sh

function recreate_entando_image_streams(){
    echo_header "Importing Entando Image Streams"
    IMAGES=("app-builder-openshift" "entando-eap71-quickstart-openshift")
    for IMAGE in "${IMAGES[@]}"
    do
        oc replace --force --grace-period 60  -f $ENTANDO_OPS_HOME/Openshift/image-streams/$IMAGE.json
    done
}
function recreate_entando_app(){
  DOMAIN_SUFFIX=get_openshift_subdomain
  oc process -f $ENTANDO_OPS_HOME/Openshift/templates/entando-eap71-quickstart.yml \
   -p ENTANDO_RUNTIME_HOSTNAME_HTTP=entando-runtime.$DOMAIN_SUFFIX \
   -p ENTANDO_APP_BUILDER_HOSTNAME_HTTP=appbuilder.$DOMAIN_SUFFIX \
   -p KIE_SERVER_BASE_URL=http://pam-kieserver-$OPENSHIFT_PROJECT.$DOMAIN_SUFFIX/ \
   -p KIE_SERVER_USERNAME=ampie \
   -p KIE_SERVER_PASSWORD=P@ssword \
   -p IMAGE_STREAM_NAMESPACE=${OPENSHIFT_PROJECT} \
   | oc replace --force --grace-period 60  -f -

}
set_openshift_project
recreate_entando_image_streams
recreate_entando_app

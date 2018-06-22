#!/usr/bin/env bash
oc process -f ~/Code/entando/entando-ops/Openshift/templates/entando-wildfly12-quickstart.yml \
 -p ENTANDO_RUNTIME_HOSTNAME_HTTP=entando-runtime.192.168.42.8.xip.io \
 -p ENTANDO_APP_BUILDER_HOSTNAME_HTTP=appbuilder.192.168.42.8.xip.io \
 -p KIE_SERVER_BASE_URL=http://kieserver.192..168.42.8 \
 -p KIE_SERVER_USERNAME=ampie \
 -p KIE_SERVER_PASSWORD=ampie \
 -p IMAGE_STREAM_NAMESPACE=entando
#!/usr/bin/env bash
source "$(dirname $0)/common.sh"
apply_maven_filters openshift
set_openshift_project
rm overlays -rf
oc start-build "$(get_property application.name)-s2i" --from-dir .
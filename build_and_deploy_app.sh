oc login -u system:admin
oc project myproject
oc delete deploymentconfig entando-sample
oc delete service entando-sample-service
oc delete route entando-sample-service
oc login -u developer -p developer
rm overlays -rf
mvn clean process-resources fabric8:build fabric8:resource fabric8:apply -Popenshift -DskipTests

oc login -u system:admin
oc project myproject
oc delete deploymentconfig entando-sample-db
oc delete service entando-sample-db-service
oc delete route entando-sample-db-service
oc delete pvc entando-sample-db-pvc
oc login -u developer -p developer
rm overlays -rf
mvn clean process-resources fabric8:build fabric8:resource fabric8:apply -DskipTests

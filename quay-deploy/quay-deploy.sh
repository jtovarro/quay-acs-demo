##1) Create a Secret using the configuration file
oc create secret generic --from-file config.yaml=./config_s3_aws.yaml config-bundle-secret -n quay-enterprise

##2) Deploy the registry
oc create -f quayregistry.yaml -n quay-enterprise
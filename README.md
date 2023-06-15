# Red Hat Quay and Advanced Cluster Security

## __Prerequisites__
- 1x Red Hat OpenShift Platform (RHOCP4) v4.13
- 1x AWS account with a bucket storage.

## __Installing Red Hat Quay using AWS S3 storage unmanaged storage__
Log in you RHOCP cluster:

- Click __OperatorHub__ and search for *Advanced Cluster Security* or *ACS*
- Click __install__.
- Take a look to the config shown, use the default namespace *rhacs-operator* to install the RH Quay Operator.
- Click __install__ again.

Once the operator is successfuly installed (it can take some minutes) create a namespace:

#### __NOTE:__ Log in if your are not already logged. Use your user, password and API.

```
oc login -u redhat https://api.ocp-lab-4.12.12.sandbox1795.opentlc.com:6443
```

```
oc new-project quay-enterprise
```




### __Summary__

RH Quay instalantions with ACS.

---
### Related Links
[1] 

## Author

Juan Carlos Tovar @RedHat

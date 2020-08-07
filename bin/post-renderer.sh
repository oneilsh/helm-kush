#!/bin/bash


cat <&0 | sed "s/$RELEASE_NAME/RELEASE-NAME/" > $WORK_DIR/helm-template-output.yaml
 
kubectl kustomize $WORK_DIR | sed "s/RELEASE-NAME/$RELEASE_NAME/g"


#!/bin/bash

cat <&0 > $WORK_DIR/helm-template-output.yaml



if [ "$INTERPOLATE" == "true" ]; then
  IFS=''
  kubectl kustomize $WORK_DIR | sed "s/RELEASE-NAME/$RELEASE_NAME/g" | \
  while read line; do
    eval echo \"$line\"
  done
else 
  kubectl kustomize $WORK_DIR | sed "s/RELEASE-NAME/$RELEASE_NAME/g"
fi	



#!/bin/bash

cat <&0 > $WORK_DIR/helm-template-output.yaml

if [ "$INTERPOLATE" == "true" ]; then
  for FILE in $(ls -1 $WORK_DIR); do
    if echo "$FILE" | grep -Eqs '\.sh$'; then
      source "$WORK_DIR/$FILE"
    fi
  done
fi


if [ "$INTERPOLATE" == "true" ]; then
  IFS=''
  kubectl kustomize $WORK_DIR | sed "s/RELEASE-NAME/$RELEASE_NAME/g" | \
  while read line; do
    eval echo \"$line\"
  done
else 
  kubectl kustomize $WORK_DIR | sed "s/RELEASE-NAME/$RELEASE_NAME/g"
fi	


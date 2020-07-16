#!/bin/bash

#set -e   # this doesnt seem to help..

cat <&0 | sed "s/$RELEASE_NAME/RELEASE-NAME/" > $WORK_DIR/helm-template-output.yaml


if [ "$INTERPOLATE" == "true" ]; then
  IFS=''
  kubectl kustomize $WORK_DIR | sed "s/RELEASE-NAME/$RELEASE_NAME/g" | \
  while read -r line; do
    # look for ...$(...)...
    if echo "$line" | grep -Eqs '.*?\$\(.*?\).*'; then
      eval echo -E \"$line\"
    else
      echo -E $line
    fi
  done
else
  kubectl kustomize $WORK_DIR | sed "s/RELEASE-NAME/$RELEASE_NAME/g"
fi	



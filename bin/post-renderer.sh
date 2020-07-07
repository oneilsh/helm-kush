#!/bin/bash

cat <&0 > $WORK_DIR/helm-template-output.yaml



if [ "$INTERPOLATE" == "true" ]; then
  IFS=''
  kubectl kustomize $WORK_DIR | sed "s/RELEASE-NAME/$RELEASE_NAME/g" | \
  while read line; do
    if echo "$line" | grep -Eqs '[[:blank:]]*--kush-interpolate[[:blank:]]*$'; then
      newline=$(echo "$line" | sed -r 's/[[:blank:]]*--kush-interpolate[[:blank:]]*$//')
      eval echo \"$newline\"
    else
      echo "$line"
    fi
  done
else 
  kubectl kustomize $WORK_DIR | sed "s/RELEASE-NAME/$RELEASE_NAME/g"
fi	



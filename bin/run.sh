#!/usr/bin/env bash

export black="$(tput setaf 0)"
export red="$(tput setaf 1)"
export green="$(tput setaf 2)"
export yellow="$(tput setaf 3)"
export blue="$(tput setaf 4)"
export magenta="$(tput setaf 5)"
export cyan="$(tput setaf 6)"
export white="$(tput setaf 7)"

if ! echo "$1" | grep -Eqs "^((install)|(upgrade)|(template))$"; then
   echo "${red}Sorry, helm kush is only avaible for install, upgrade, and template.${white}" 1>&2
   exit 1
fi

INTERPOLATE="false"
CMD=$1
CHART=""
RELEASE_NAME="RELEASE-NAME"
FLAGS=${@:3}
if echo "$3" | grep -Eqs "(^--)|(^$)"; then
   CHART=$2
else
   RELEASE_NAME=$2
   CHART=$3
   FLAGS="${@:4}"
fi

if echo "$FLAGS" | grep -Eqs -- '--kush-interpolate'; then
  INTERPOLATE="true"
  FLAGS=$(echo $FLAGS | sed 's/--kush-interpolate//')
fi

CHARTNAME=$($HELM_BIN show chart $CHART | grep '^name: ' | sed -r 's/^name: //')


TEMPDIR=$(mktemp -d)

CHARTDIR="$TEMPDIR/$CHARTNAME"

if [ -d $CHART ]; then
  CHART=$(realpath $CHART)
  cp -r $CHART $TEMPDIR
else
  $HELM_BIN pull --untar --untardir=$TEMPDIR $CHART 
fi



if [ -d "$CHARTDIR/kush" ]; then
  export WORK_DIR="$CHARTDIR/kush/"
  export RELEASE_NAME=$RELEASE_NAME
  export INTERPOLATE=$INTERPOLATE
  export CHARTDIR=$CHARTDIR

  if [ "$INTERPOLATE" == "true" ]; then
    for FILE in $(ls -1 $WORK_DIR); do
      if echo "$FILE" | grep -Eqs '\.sh$'; then
        source "$WORK_DIR/$FILE"
      fi
    done
  fi

  $HELM_BIN $CMD "$CHARTDIR" $FLAGS --post-renderer="$HELM_PLUGIN_DIR/bin/post-renderer.sh"
fi


#rm -rf $TEMPDIR



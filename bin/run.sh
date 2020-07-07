#!/usr/bin/env bash

black="$(tput setaf 0)"
red="$(tput setaf 1)"
green="$(tput setaf 2)"
yellow="$(tput setaf 3)"
blue="$(tput setaf 4)"
magenta="$(tput setaf 5)"
cyan="$(tput setaf 6)"
white="$(tput setaf 7)"

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

echo $FLAGS
if echo "$FLAGS" | grep -Eqs -- '--kush-interpolate'; then
  echo "${yellow}Warning: using --kush-interpolate!${white}"
  INTERPOLATE="true"
  FLAGS=$(echo $FLAGS | sed 's/--kush-interpolate//')
  echo $FLAGS
else
  echo "${yellow}Not using --kush-interpolate.${white}"
fi

CHARTNAME=$($HELM_BIN show chart $CHART | grep '^name: ' | sed -r 's/^name: //')


TEMPDIR=$(mktemp -d)


$HELM_BIN pull --untar --untardir=$TEMPDIR $CHART 



if [ -d "$TEMPDIR/$CHARTNAME/kush" ]; then
  export WORK_DIR="$TEMPDIR/$CHARTNAME/kush/"
  export RELEASE_NAME=$RELEASE_NAME
  export INTERPOLATE=$INTERPOLATE
  echo $HELM_BIN template $TEMPDIR/$CHARTNAME $FLAGS --post-renderer="$HELM_PLUGIN_DIR/bin/post-renderer.sh"
  $HELM_BIN template $TEMPDIR/$CHARTNAME $FLAGS --post-renderer="$HELM_PLUGIN_DIR/bin/post-renderer.sh"
fi


#rm -rf $TEMPDIR



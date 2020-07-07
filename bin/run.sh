#!/usr/bin/env bash

# some helpers for color
export black="$(tput setaf 0)"
export red="$(tput setaf 1)"
export green="$(tput setaf 2)"
export yellow="$(tput setaf 3)"
export blue="$(tput setaf 4)"
export magenta="$(tput setaf 5)"
export cyan="$(tput setaf 6)"
export white="$(tput setaf 7)"

# check if we're running as helm kush (install|upgrade|template)
if ! echo "$1" | grep -Eqs "^((install)|(upgrade)|(template))$"; then
   echo "${red}Sorry, helm kush is only avaible for install, upgrade, and template.${white}" 1>&2
   exit 1
fi

# parse the helm command, chart, and release name (if given)
# tricky because some helm commands make the release name optional
# if a release name isn't given, we can assume the third arg is a flag or just not given
# (after the command, post-kush, e.g. in helm kush template repo/chart --dry-run)
# save everything after the chart in FLAGS
INTERPOLATE="false"
CMD=$1
CHART=""
RELEASE_NAME="RELEASE-NAME"
FLAGS="${@:3}"
if echo "$3" | grep -Eqs "(^--)|(^$)"; then
   CHART=$2
else
   RELEASE_NAME=$2
   CHART=$3
   FLAGS="${@:4}"
fi

# see if the user passes a --kush-interpolate flag; if so, drop it from the flags
if echo "$FLAGS" | grep -Eqs -- '--kush-interpolate'; then
  INTERPOLATE="true"
  FLAGS=$(echo $FLAGS | sed 's/--kush-interpolate//')
fi

# need a list of --values files to possibly pre-interpolate with #$ syntax
USER_VALUES_FILES=()
USERFILES=false
for FLAG in "$@"; do
  if [ "$FLAG" == "-f" ] || [ "$FLAG" == "--values" ]; then
    USERFILES=true
  elif echo "$FLAG" | grep -Eqs "(^--)"; then
    USERFILES=false
  elif [ "$USERFILES" == "true" ]; then
    USER_VALUES_FILES+=("$FLAG")    
  fi
done

# get the chart name (gives the folder name after untarring)
# make a temp directory to put a copy in
CHARTNAME=$($HELM_BIN show chart $CHART | grep '^name: ' | sed -r 's/^name: //')
TEMPDIR=$(mktemp -d)

CHARTDIR="$TEMPDIR/$CHARTNAME"

# make a copy in the temp dir; if they're specifying a local path use that
if [ -d $CHART ]; then
  CHART=$(realpath $CHART)
  cp -r $CHART $TEMPDIR
else
  $HELM_BIN pull --untar --untardir=$TEMPDIR $CHART 
fi

# if there's a kush dir in the chart, we've got work to do
if [ -d "$CHARTDIR/kush" ]; then
  export WORK_DIR="$CHARTDIR/kush/"
  export RELEASE_NAME=$RELEASE_NAME
  export INTERPOLATE=$INTERPOLATE
  export CHARTDIR=$CHARTDIR

  if [ "$INTERPOLATE" == "true" ]; then
    for FILE in $(ls -1 $WORK_DIR); do
      if echo "$FILE" | grep -Eqs '\.pre\.sh$'; then
        source "$WORK_DIR/$FILE"
      fi
    done
 
    for VALUEFILE in "${USER_VALUES_FILES[@]}"; do
      source <(cat "$VALUEFILE" | grep -E '^[[:blank:]]*#\$' | sed 's/^[[:blank:]]*#\$//')
    done
  fi

  $HELM_BIN $CMD "$CHARTDIR" $FLAGS --post-renderer="$HELM_PLUGIN_DIR/bin/post-renderer.sh"

  if [ "$INTERPOLATE" == "true" ]; then
    for FILE in $(ls -1 $WORK_DIR); do
      if echo "$FILE" | grep -Eqs '\.post\.sh$'; then
        source "$WORK_DIR/$FILE"
      fi
    done
   
    for VALUEFILE in "${USER_VALUES_FILES[@]}"; do
      source <(cat "$VALUEFILE" | grep -E '^[[:blank:]]*#%' | sed 's/^[[:blank:]]*#%//')
    done
  fi

else 
  echo "${red}Error: helm kush called on chart with no kush/ directory, try standard '$HELM_BIN $CMD'.${white}" 1>&2
fi


rm -rf $TEMPDIR



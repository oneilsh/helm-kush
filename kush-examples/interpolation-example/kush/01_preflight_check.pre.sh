if [ $(echo $ADMIN_INIT_USERNAME | wc -c) -gt 14 ]; then
  echo "${red}Error: \$ADMIN_INIT_USERNAME cannot be longer than 14 characters (got $ADMIN_INIT_USERNAME). ${white}" 1>&2
  exit 1
fi

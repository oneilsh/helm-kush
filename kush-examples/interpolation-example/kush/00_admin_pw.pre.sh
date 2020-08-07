
if [ "$ADMIN_INIT_USERNAME" == "" ]; then
  ADMIN_INIT_USERNAME=$USER
fi

if [ "$ADMIN_INIT_PASSWORD" == "" ]; then
  # sed here fixes windows-style newline
  ADMIN_INIT_PASSWORD=$(curl --silent "https://makemeapassword.ligos.net/api/v1/passphrase/plain?whenUp=StartOfWord&sp=F&pc=1&wc=2&sp=y&maxCh=20" | sed -r 's/\r//g')
fi

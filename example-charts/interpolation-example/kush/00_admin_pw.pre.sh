
export ADMIN_INIT_USERNAME=$USER
export ADMIN_INIT_PASSWORD=$(curl --silent "https://makemeapassword.ligos.net/api/v1/passphrase/plain?whenUp=StartOfWord&sp=F&pc=1&wc=2&sp=y&maxCh=20")

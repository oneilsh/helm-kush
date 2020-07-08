
# the sed is to remove trailing windows-newline returned by server
ADMIN_INIT_USERNAME=$USER
ADMIN_INIT_PASSWORD=$(wget "https://makemeapassword.ligos.net/api/v1/passphrase/plain?whenUp=StartOfWord&sp=F&pc=1&wc=2&sp=y&maxCh=20" -qO- | sed -e 's/\r//g')


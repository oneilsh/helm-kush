
# the sed is to remove trailing windows-newline returned by server
export ADMIN_INIT_PASSWORD=$(wget "https://makemeapassword.ligos.net/api/v1/passphrase/plain?whenUp=StartOfWord&sp=F&pc=1&wc=2&sp=y&maxCh=20" -qO- | sed -e 's/\r//g')

# update NOTES.txt with newformed login info
echo "${yellow}Your username/password are $USER/$ADMIN_INIT_PASSWORD, write them down!${white}" >> $CHARTDIR/templates/NOTES.txt

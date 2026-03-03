#!/bin/bash
# reset_certbot.sh <domain>

dom=$1;

if [ "$dom" == "" ]; then
  echo "ERROR: domain not specified!";
  echo "reset_certbot.sh <domain>";
  echo "";
  exit 0;
fi

conf="/etc/apache2/sites-available/$dom.conf";

echo "=> Disable SSL site during rebuild"
sudo a2dissite $dom-le-ssl.conf

# Check for valid
if [ ! -f "$conf" ]; then
  echo "ERROR: Apache configuration for $dom not found!";
  echo "reset_certbot.sh <domain>";
  echo "";
  exit 0;
fi

# Get the webroot for the domain
WEBROOT=`grep DocumentRoot $conf |sed -e"s/DocumentRoot[ \t]*//"`;
echo "=> WebRoot = $WEBROOT";

echo "=> Remove old SSL certificate data in letsencrypt";
sudo rm -vrf /etc/letsencrypt/live/$dom /etc/letsencrypt/archive/$dom /etc/letsencrypt/renewal/$dom.conf;

echo "=> Request new SSL certificate";
if [[ "$dom" =~ .*\..*\..* ]]; then
  # For Subdomains - don't assume www.
  sudo certbot certonly --non-interactive --agree-tos --webroot -w $WEBROOT -d $dom;
else
  sudo certbot certonly --non-interactive --agree-tos --webroot -w $WEBROOT -d $dom -d www.$dom;
fi

status=$?
if [ $status -ne 0 ]; then
  echo "";
  echo "ERROR on certbot - not enabling SSL site"
  echo "";
  exit 1;
else
  echo "=> Enable SSL site after letsencrypt"
  sudo a2ensite $dom-le-ssl.conf
fi

exit 0;


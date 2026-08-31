#!/bin/bash -e
##########################################
# apply_https_fixes.sh
#
# Apply Fedora HTTPS / logging fixes on a live system:
#   1. a2enconf other-vhosts-access-log
#   2. Enable local HTTPS for earth.love (Fedora self-signed
#      localhost.crt until mkcert is applied for el.local)
#
# Run: sudo ./apply_https_fixes.sh
# Or:  ./apply_https_fixes.sh   (will sudo internally)
##########################################

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SETUPDIR="$( cd -- "$SCRIPTPATH/.." >/dev/null 2>&1 ; pwd -P )"
BINDIR="$( cd -- "$SETUPDIR/.." >/dev/null 2>&1 ; pwd -P )"

run() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@";
  else
    sudo "$@";
  fi
}

echo '-- Refresh earthlove.conf drop-in'
run cp -pv "$SCRIPTPATH/earthlove.conf" /etc/httpd/conf.d/earthlove.conf

echo '-- Enable other-vhosts-access-log'
run cp -puv "$SCRIPTPATH/other-vhosts-access-log.conf" /etc/httpd/conf-available/
run a2enconf other-vhosts-access-log

echo '-- Install local HTTPS vhosts (Fedora localhost.crt until mkcert)'
run cp -puv "$BINDIR/config/000-default-ssl.conf" /etc/httpd/sites-available/
run cp -puv "$BINDIR/config/earth.love-ssl.conf" /etc/httpd/sites-available/
run a2ensite 000-default-ssl.conf
run a2ensite earth.love-ssl.conf

if [ -e /etc/httpd/conf.d/welcome.conf ]; then
  echo '-- Disable stock welcome.conf';
  run mv -v /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.d/welcome.conf.disabled;
fi

if [ -f /etc/httpd/conf.d/ssl.conf ] \
   && grep -q '^#DocumentRoot "/var/www/html"' /etc/httpd/conf.d/ssl.conf; then
  echo '-- Set ssl.conf DocumentRoot to /LOVE/earth.love/_WEB';
  run sed -i 's|^#DocumentRoot "/var/www/html"|DocumentRoot "/LOVE/earth.love/_WEB"|' \
    /etc/httpd/conf.d/ssl.conf;
fi

echo '-- Local HTTPS for el.local via mkcert (optional; does not abort on failure)'
if ! "$SCRIPTPATH/apply_mkcert_el_local.sh"; then
  echo 'NOTE: mkcert for el.local was not applied (network, sudo, or missing tools).'
  echo 'NOTE: Local HTTPS remains the Fedora self-signed localhost.crt.'
  echo 'NOTE: Re-run: bin/setup/fedora/apply_mkcert_el_local.sh'
fi

run apachectl configtest
run systemctl reload httpd

echo
echo '#########################################'
echo '# HTTPS / a2enconf fixes applied'
echo '#########################################'
/ELBIN/sites 2>/dev/null || true
curl -skI https://127.0.0.1/ | head -5
curl -sk -H 'Host: earth.love' https://127.0.0.1/o/page 2>/dev/null | grep -E 'ms\)' | head -1

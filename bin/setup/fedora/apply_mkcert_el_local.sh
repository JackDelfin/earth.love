#!/bin/bash
set -euo pipefail
##########################################
# apply_mkcert_el_local.sh
#
# Issue a locally-trusted TLS certificate for el.local (and localhost)
# with mkcert, install the mkcert CA into this user's trust stores, and
# enable Apache vhosts that use those files.
#
# This does not need a public website.  Browsers on THIS machine trust
# the cert; other computers will not unless they also install the CA.
#
# Run:  ./apply_mkcert_el_local.sh
#    or sudo ./apply_mkcert_el_local.sh
##########################################

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
BINDIR="$( cd -- "$SCRIPTPATH/../.." >/dev/null 2>&1 ; pwd -P )"
CERT_FILE=/etc/pki/tls/certs/el.local.pem
KEY_FILE=/etc/pki/tls/private/el.local.key

run() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

if [ "$(id -u)" -eq 0 ]; then
  REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"
  if [ -z "$REAL_USER" ] || [ "$REAL_USER" = "root" ]; then
    echo "Run this script as the desktop user (with sudo), not as a root login." >&2
    echo "The mkcert CA must be installed in that user's browser trust store." >&2
    exit 1
  fi
else
  REAL_USER="$USER"
fi
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
if [ -z "$REAL_HOME" ] || [ ! -d "$REAL_HOME" ]; then
  echo "Unable to determine home directory for $REAL_USER." >&2
  exit 1
fi

as_user() {
  if [ "$(id -u)" -eq 0 ]; then
    sudo -u "$REAL_USER" -H "$@"
  elif [ "$USER" = "$REAL_USER" ]; then
    env HOME="$REAL_HOME" "$@"
  else
    sudo -u "$REAL_USER" -H "$@"
  fi
}

echo '-- Install nss-tools (Firefox / NSS trust) and mkcert'
if ! rpm -q nss-tools >/dev/null 2>&1; then
  run dnf install -y nss-tools
fi

MKCERT="$(command -v mkcert || true)"
if [ -z "$MKCERT" ]; then
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) GOARCH=amd64 ;;
    aarch64) GOARCH=arm64 ;;
    *)
      echo "Unsupported architecture for the mkcert binary: $ARCH" >&2
      exit 1
      ;;
  esac
  TMP_MKCERT="$(mktemp)"
  if ! curl -fsSL "https://dl.filippo.io/mkcert/latest?for=linux/${GOARCH}" -o "$TMP_MKCERT"; then
    rm -f "$TMP_MKCERT"
    echo "Unable to download mkcert." >&2
    exit 1
  fi
  chmod 0755 "$TMP_MKCERT"
  run mv -f "$TMP_MKCERT" /usr/local/bin/mkcert
  MKCERT=/usr/local/bin/mkcert
fi

echo "-- Install the mkcert CA for $REAL_USER (system + browser stores)"
as_user "$MKCERT" -install

CAROOT="$(as_user "$MKCERT" -CAROOT)"
if [ -z "$CAROOT" ] || [ ! -f "$CAROOT/rootCA.pem" ]; then
  echo "mkcert CA was not created at CAROOT=$CAROOT" >&2
  exit 1
fi

echo "-- Issue Apache certificate for el.local, localhost, 127.0.0.1, ::1"
WORKDIR="$(as_user mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
as_user env CAROOT="$CAROOT" "$MKCERT" \
  -cert-file "$WORKDIR/el.local.pem" \
  -key-file "$WORKDIR/el.local.key" \
  el.local localhost 127.0.0.1 ::1
run install -m 0644 -o root -g root "$WORKDIR/el.local.pem" "$CERT_FILE"
run install -m 0600 -o root -g root "$WORKDIR/el.local.key" "$KEY_FILE"
if [ -x /usr/sbin/restorecon ]; then
  run restorecon -F "$CERT_FILE" "$KEY_FILE" || true
fi

echo '-- Install and enable el.local HTTP + HTTPS vhosts'
run cp -puv "$BINDIR/config/el.local.conf" /etc/httpd/sites-available/el.local.conf
run cp -puv "$BINDIR/config/el.local-ssl.conf" /etc/httpd/sites-available/el.local-ssl.conf
run a2ensite el.local.conf
run a2ensite el.local-ssl.conf

# Name-less local HTTPS (https://127.0.0.1) should present the same cert.
point_vhost_at_mkcert() {
  local file="$1"
  if [ -f "$file" ] && grep -q 'SSLCertificateFile /etc/pki/tls/certs/localhost.crt' "$file"; then
    echo "-- Point $file at the mkcert files"
    run sed -i \
      -e "s|SSLCertificateFile /etc/pki/tls/certs/localhost.crt|SSLCertificateFile $CERT_FILE|" \
      -e "s|SSLCertificateKeyFile /etc/pki/tls/private/localhost.key|SSLCertificateKeyFile $KEY_FILE|" \
      "$file"
  fi
}
point_vhost_at_mkcert /etc/httpd/sites-available/000-default-ssl.conf
point_vhost_at_mkcert /etc/httpd/conf.d/ssl.conf

if ! grep -qE '^[[:space:]]*127\.0\.0\.1[[:space:]].*\bel\.local\b' /etc/hosts; then
  echo '-- Add el.local to /etc/hosts'
  run bash -c 'printf "\n127.0.0.1 el.local\n" >> /etc/hosts'
fi

echo '-- Test and reload Apache'
run apachectl configtest
run systemctl reload httpd

echo
echo '#########################################'
echo "# mkcert HTTPS is ready for https://el.local"
echo "# CA: $CAROOT"
echo '# Restart the browser if it still warns.'
echo '#########################################'

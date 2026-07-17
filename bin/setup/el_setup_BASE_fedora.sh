#!/bin/bash -e
##########################################
# el_setup_BASE_fedora.sh
#
# Install the BASE components for Akashic-Orbit
# on Fedora Linux (also RHEL/CentOS/Rocky/Alma family)
#
# Fedora differences handled here (vs el_setup_BASE.sh for Ubuntu/Debian):
#   - dnf instead of apt; no snap (certbot comes from dnf)
#   - Apache is "httpd" with config in /etc/httpd (not apache2)
#   - Debian compatibility layer installed so ALL earth.love tools
#     (elSETUP_DOM.pl, RMSITE.pl, qsite, sites, ROTATE_LOGS.pl, ...)
#     work unchanged:
#       * /etc/httpd/sites-available + sites-enabled (+ conf-available/enabled)
#       * /etc/apache2 -> /etc/httpd symlink
#       * a2ensite / a2dissite / a2enconf / a2disconf / a2enmod shims
#       * systemctl "apache2" alias for the httpd service
#       * www-data user/group (apache user joins the www-data group)
#   - firewalld instead of UFW
#   - SELinux file contexts for /LOVE and /ELBIN
#
# Consider redirecting output from this script to a log record
# ./el_setup_BASE_fedora.sh 2>&1 1|tee el_setup_BASE_fedora_`date +%Y%m%d_%H%M%S`.out
#
# 2026.07.16 oK created for Fedora
##########################################

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

echo '##################################################';
echo '# Install the BASE components for Akashic-Orbit  #';
echo '#                 (Fedora Linux)                  #';
echo '##################################################';

echo
echo '# System Information:';
cat /etc/os-release | grep -e'^NAME=' -e'^VERSION=';
DISTRO=`. /etc/os-release && echo $ID`;
PROCESSORS=`cat /proc/cpuinfo |grep processor|wc -l`;
echo
echo 'Distro:' $DISTRO;
echo 'Processors:' $PROCESSORS;
cat /proc/meminfo | grep MemTotal;
echo 'Drives:';
lsblk|grep -e"G " -e"T "|sed -e'/^loop/d';

if [ "$DISTRO" != "fedora" ]; then
  echo
  echo "NOTE: This installer targets Fedora - detected: $DISTRO";
  echo "      RHEL/Rocky/Alma should also work (packages via dnf).";
fi

#########################################
echo
echo '# -------------------------'
echo '# System Update and Upgrade'
echo '# -------------------------'
echo '--'
echo '-- dnf upgrade --refresh -y'
echo '--'
sudo dnf upgrade --refresh -y

echo
echo '# -------------------------'
echo '# Install Needed Components'
echo '# -------------------------'
echo
echo '--'
echo '-- Install cpp gcc'
echo '--'
sudo dnf install cpp gcc -y

echo
echo '--'
echo '-- Install dos2unix'
echo '--'
sudo dnf install dos2unix -y

echo
echo '--'
echo '-- Install curl'
echo '-- (--allowerasing swaps out curl-minimal/libcurl-minimal'
echo '--  which ship on fresh Fedora installs)'
echo '--'
sudo dnf install curl libcurl -y --allowerasing

echo
echo '--'
echo '-- Install wget'
echo '--'
sudo dnf install wget -y

echo
echo '--'
echo '-- Install rsync'
echo '--'
sudo dnf install rsync -y

echo
echo '--'
echo '-- Install GeoIP - geoiplookup (with GeoLite data)'
echo '--'
sudo dnf install GeoIP GeoIP-GeoLite-data -y;

# rfkill is part of util-linux on Fedora - nothing to install
echo
echo '--'
echo '-- rfkill (provided by util-linux on Fedora)'
echo '--'
command -v rfkill && rfkill --version || echo 'rfkill not found (optional)'

echo
echo '# -------------------------'
echo '# -- INSTALL NETWORKS'
echo '# --     and SYS UTILITIES'
echo '# -------------------------'
echo
echo '--'
echo '-- Install bind-utils (dnsutils equivalent)'
echo '-- - dig hostname'
echo '--'
sudo dnf install bind-utils -y
echo
echo '--'
echo '-- Install net-tools'
echo '--'
sudo dnf install net-tools -y
echo
echo '--'
echo '-- Install traceroute'
echo '--'
sudo dnf install traceroute -y
echo
echo '--'
echo '-- Install sysstat'
echo '--'
sudo dnf install sysstat -y
echo
echo '--'
echo '-- Install atop'
echo '--'
sudo dnf install atop -y

echo
echo '--'
echo '-- Install OpenSSH'
echo '--'
sudo dnf install openssh-server -y
sudo systemctl enable sshd

echo
echo '# -------------------------'
echo '# -- Install Apache (httpd + mod_ssl + htpasswd tools)'
echo '# -------------------------'
sudo dnf install httpd mod_ssl httpd-tools -y

echo
echo '# -------------------------'
echo '# -- Install libcurl and dev'
echo '# -------------------------'
sudo dnf install pkgconf-pkg-config libcurl libcurl-devel -y --allowerasing

echo
echo '--'
echo '-- Create www-data user and group (Debian compatibility)'
echo '-- All earth.love tools chown files to www-data:www-data.'
echo '-- Apache still runs as the standard Fedora "apache" user,'
echo '-- which joins the www-data group for g+w access.'
echo '--'
if ! getent group www-data >/dev/null; then
  sudo groupadd --system www-data;
fi
if ! getent passwd www-data >/dev/null; then
  sudo useradd --system --gid www-data --home-dir /var/www --no-create-home --shell /usr/sbin/nologin www-data;
fi
sudo usermod -a -G www-data apache

echo
echo '--'
echo '-- Set the installing user into the www-data group'
echo '--'
ELUSER="${SUDO_USER:-$USER}";
if [ "$ELUSER" != "root" ] && [ "$ELUSER" != "" ]; then
  sudo usermod -a -G www-data $ELUSER;
  echo "-- $ELUSER added to www-data group (takes effect on next login)";
fi

echo
echo '# -------------------------'
echo '# -- Install goaccess'
echo '# -------------------------'
sudo dnf install goaccess -y

echo
echo '# -------------------------'
echo '# -- Install Perl CPAN: LWP/CGI'
echo '# -------------------------'

echo
echo '--'
echo '-- Install perl'
echo '--'
sudo dnf install perl -y

echo
echo '--'
echo '-- Install cpanminus'
echo '--'
sudo dnf install perl-App-cpanminus -y

echo
echo '--'
echo '-- Perl LWP (dnf: perl-libwww-perl)'
echo '-- perl-LWP-Protocol-https adds HTTPS support'
echo '-- (required by cpanm below - CPAN mirrors are https-only)'
echo '--'
sudo dnf install perl-libwww-perl perl-LWP-Protocol-https -y

echo
echo '--'
echo '-- Perl CGI (dnf: perl-CGI)'
echo '--'
sudo dnf install perl-CGI -y

echo
echo '--'
echo '-- Perl JSON and JSON::MaybeXS (dnf)'
echo '--'
sudo dnf install perl-JSON perl-JSON-MaybeXS -y

echo
echo '--'
echo '-- Perl NET::CURL'
echo '-- (Net::Curl is not packaged for Fedora - use cpanm)'
echo '-- Only needed by the GoDaddy DNS tools in /ELBIN -'
echo '-- a failure here warns but does not stop the install'
echo '--'
sudo dnf install perl-ExtUtils-PkgConfig -y
if ! sudo cpanm --notest Net::Curl; then
  echo '**********************************************************';
  echo '* WARNING: cpanm Net::Curl FAILED                        *';
  echo '* Needed only for getGoDaddyDNS.pl / setGoDaddyDNS.pl.   *';
  echo '* Retry later with:  sudo cpanm --notest Net::Curl       *';
  echo '**********************************************************';
fi

echo
echo '# -------------------------'
echo '# Install ImageMagick'
echo '#   Command-Line Image Conversion Tools'
echo '# -------------------------'
sudo dnf install ImageMagick -y

echo
echo '# -------------------------'
echo '# Install firewalld'
echo '#   (Fedora standard firewall - replaces UFW)'
echo '# -------------------------'
sudo dnf install firewalld -y
sudo systemctl enable --now firewalld

echo
echo '-- Configure firewalld -' $DISTRO
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
sudo firewall-cmd --list-services

echo
echo '# -------------------------'
echo '# Configure Apache'
echo '# -------------------------'

echo
echo '--'
echo '-- Create Debian-style sites/conf directories under /etc/httpd'
echo '--'
sudo mkdir -pv /etc/httpd/sites-available /etc/httpd/sites-enabled
sudo mkdir -pv /etc/httpd/conf-available  /etc/httpd/conf-enabled

echo
echo '--'
echo '-- Symlink /etc/apache2 -> /etc/httpd'
echo '-- earth.love tools reference /etc/apache2/... paths directly'
echo '--'
if [ ! -e /etc/apache2 ]; then
  sudo ln -sv /etc/httpd /etc/apache2;
elif [ -L /etc/apache2 ]; then
  echo "-- /etc/apache2 symlink already exists: "`readlink /etc/apache2`;
else
  echo "ERROR: /etc/apache2 exists and is NOT a symlink - resolve manually!";
  exit 1;
fi

echo
echo '--'
echo '-- Install the a2ensite/a2dissite/a2enconf/a2disconf/a2enmod shims'
echo '--'
sudo cp -pv $SCRIPTPATH/fedora/a2ctl /usr/local/sbin/a2ctl
sudo chmod 755 /usr/local/sbin/a2ctl
for a2cmd in a2ensite a2dissite a2enconf a2disconf a2enmod a2dismod; do
  sudo ln -sfv /usr/local/sbin/a2ctl /usr/local/sbin/$a2cmd;
done

echo
echo '--'
echo '-- Install the earth.love httpd drop-in configs'
echo '--   earthlove.conf     - sites-enabled/conf-enabled includes'
echo '--   earthlove-cgi.conf - serve CGI from /o/ (instead of /cgi-bin/)'
echo '--'
sudo cp -pv $SCRIPTPATH/fedora/earthlove.conf     /etc/httpd/conf.d/
sudo cp -pv $SCRIPTPATH/fedora/earthlove-cgi.conf /etc/httpd/conf.d/

echo
echo '--'
echo '-- Alias the httpd service as "apache2"'
echo '-- earth.love tools run: systemctl reload apache2'
echo '--'
sudo mkdir -p /etc/systemd/system/httpd.service.d
printf '[Install]\nAlias=apache2.service\n' | sudo tee /etc/systemd/system/httpd.service.d/earthlove-alias.conf >/dev/null
sudo systemctl daemon-reload
sudo systemctl reenable httpd

echo
echo '--'
echo '-- Verify CGI / SSL / Rewrite modules are loaded'
echo '-- (loaded via /etc/httpd/conf.modules.d on Fedora)'
echo '--'
sudo a2enmod cgid || sudo a2enmod cgi
sudo a2enmod ssl
sudo a2enmod rewrite

echo
echo '# -------------------------'
echo '# SELinux Configuration'
echo '# -------------------------'
echo '-- /LOVE  : httpd_sys_rw_content_t (Apache serves + Akashic CGI writes)'
echo '-- /ELBIN : bin_t (piped log program run by Apache)'
SELMODE=`getenforce 2>/dev/null || echo Disabled`;
echo "-- SELinux mode: $SELMODE";
sudo dnf install policycoreutils-python-utils -y
if [ "$SELMODE" != "Disabled" ]; then
  sudo semanage fcontext -a -t httpd_sys_rw_content_t '/LOVE(/.*)?' 2>/dev/null \
    || echo '-- /LOVE fcontext already defined';
  sudo semanage fcontext -a -t bin_t '/ELBIN(/.*)?' 2>/dev/null \
    || echo '-- /ELBIN fcontext already defined';
else
  echo '-- SELinux Disabled - skipping fcontext setup';
fi

echo
echo '--'
echo '-- Install Certbot for HTTPS Certificate Management'
echo '-- (dnf on Fedora - no snap needed)'
echo '--'
sudo dnf install certbot python3-certbot-apache -y

echo
echo '--'
echo '-- Provide /etc/letsencrypt/options-ssl-apache.conf'
echo '-- (referenced by the DOMS.earth-le-ssl.conf SSL vhost template;'
echo '--  normally created by the certbot apache plugin on first run)'
echo '--'
sudo mkdir -p /etc/letsencrypt
if [ ! -e /etc/letsencrypt/options-ssl-apache.conf ]; then
  TLSOPTS=`ls /usr/lib/python3*/site-packages/certbot_apache/_internal/tls_configs/current-options-ssl-apache.conf 2>/dev/null | head -1`;
  if [ "$TLSOPTS" != "" ]; then
    sudo cp -pv $TLSOPTS /etc/letsencrypt/options-ssl-apache.conf;
  else
    echo "NOTE: certbot apache tls_configs not found - options-ssl-apache.conf";
    echo "      will be created by certbot on first --apache run.";
  fi
fi

echo
echo '--'
echo '-- Enable and Restart Apache (httpd)'
echo '--'
sudo systemctl enable httpd

# mod_ssl's ssl.conf points at /etc/pki/tls/certs/localhost.crt, which
# Fedora only generates on the FIRST httpd start (httpd-init.service).
# configtest below runs before that first start - generate the
# self-signed placeholder cert now so configtest passes.
if [ ! -e /etc/pki/tls/certs/localhost.crt ]; then
  echo '-- Generating default self-signed TLS cert (httpd-init)';
  sudo systemctl start httpd-init.service \
    || sudo /usr/libexec/httpd-ssl-gencerts;
fi

sudo apachectl configtest
sudo systemctl restart httpd
systemctl is-active httpd

echo
echo '--'
echo '-- Verify the apache2 service alias'
echo '--'
systemctl status apache2 --no-pager | head -3

echo '#########################################'
echo '# BASE Setup Complete (Fedora)'
echo '#########################################'

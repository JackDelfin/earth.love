use strict;
use warnings;

use Cwd qw(abs_path);
use File::Spec;
use FindBin;
use Test::More;

my $repo = abs_path(File::Spec->catdir($FindBin::Bin, '..', '..'));

sub slurp {
  my ($path) = @_;
  open(my $fh, '<', $path) or die "Unable to read $path: $!";
  local $/;
  return <$fh>;
}

my $http_vhost = File::Spec->catfile($repo, 'bin', 'config', 'el.local.conf');
my $ssl_vhost = File::Spec->catfile($repo, 'bin', 'config', 'el.local-ssl.conf');
my $default_ssl = File::Spec->catfile($repo, 'bin', 'config', '000-default-ssl.conf');
my $apply = File::Spec->catfile($repo, 'bin', 'setup', 'fedora', 'apply_mkcert_el_local.sh');
my $earthlove = File::Spec->catfile($repo, 'bin', 'setup', 'el_setup_EARTHLOVE_fedora.sh');
my $https_fixes = File::Spec->catfile($repo, 'bin', 'setup', 'fedora', 'apply_https_fixes.sh');

subtest 'el.local vhosts exist and name the mkcert files' => sub {
  ok(-f $http_vhost, 'el.local HTTP vhost exists');
  ok(-f $ssl_vhost, 'el.local HTTPS vhost exists');
  my $http = slurp($http_vhost);
  my $ssl = slurp($ssl_vhost);
  like($http, qr/^\s*ServerName\s+el\.local\b/m, 'HTTP vhost ServerName is el.local');
  like($ssl, qr/^\s*ServerName\s+el\.local\b/m, 'HTTPS vhost ServerName is el.local');
  like($ssl, qr{SSLCertificateFile /etc/pki/tls/certs/el\.local\.pem},
    'HTTPS vhost uses the mkcert certificate path');
  like($ssl, qr{SSLCertificateKeyFile /etc/pki/tls/private/el\.local\.key},
    'HTTPS vhost uses the mkcert key path');
  unlike($ssl, qr{localhost\.crt}, 'HTTPS vhost does not use Fedora localhost.crt');
  like($ssl, qr{Include /etc/letsencrypt/options-ssl-apache\.conf},
    'HTTPS vhost includes the shared Apache TLS options');
};

subtest 'apply_mkcert_el_local.sh is the live installer' => sub {
  ok(-f $apply, 'apply_mkcert_el_local.sh exists');
  ok(-x $apply, 'apply_mkcert_el_local.sh is executable');
  my $source = slurp($apply);
  like($source, qr/\bmkcert\b/, 'apply script invokes mkcert');
  like($source, qr/\bnss-tools\b/, 'apply script installs nss-tools');
  like($source, qr/\bel\.local\b/, 'apply script names el.local');
  like($source, qr/\bCAROOT\b/, 'apply script uses the mkcert CAROOT');
  like($source, qr/desktop user/, 'apply script installs the CA as the desktop user');
  like($source, qr/\bSUDO_USER\b/, 'apply script recovers the desktop user from sudo');
  like($source, qr/as_user mktemp -d/, 'certificate workdir is created as the desktop user');
  unlike($source, qr/\brun sudo -u\b/, 'as_user does not double-sudo through run');
  like($source, qr/a2ensite el\.local-ssl\.conf/,
    'apply script enables the SSL vhost after the cert files exist');
};

subtest 'Fedora setup hooks invoke mkcert without requiring it on first boot' => sub {
  my $earthlove_source = slurp($earthlove);
  my $fixes_source = slurp($https_fixes);
  like($earthlove_source,
    qr{if ! "\$SCRIPTPATH/fedora/apply_mkcert_el_local\.sh"},
    'EARTHLOVE Fedora setup invokes apply_mkcert_el_local.sh and ignores failure');
  unlike($earthlove_source, qr/^\s*(?:sudo\s+)?a2ensite\s+el\.local-ssl/m,
    'EARTHLOVE Fedora setup does not a2ensite el.local-ssl.conf before certs exist');
  like($fixes_source,
    qr{if ! "\$SCRIPTPATH/apply_mkcert_el_local\.sh"},
    'apply_https_fixes.sh invokes apply_mkcert_el_local.sh and ignores failure');
  like($fixes_source, qr/self-signed/,
    'apply_https_fixes.sh documents that local HTTPS is self-signed until mkcert');
  my $stock = slurp($default_ssl);
  like($stock, qr{SSLCertificateFile /etc/pki/tls/certs/localhost\.crt},
    'repo 000-default-ssl.conf still uses Fedora localhost.crt for first boot');
};

done_testing;

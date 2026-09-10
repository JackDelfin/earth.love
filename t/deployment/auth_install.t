use strict;
use warnings;

use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin;
use IPC::Open3;
use Symbol qw(gensym);
use Test::More;

my $repo = abs_path(File::Spec->catdir($FindBin::Bin, '..', '..'));
my $sync = File::Spec->catfile($repo, 'bin', 'setup', 'el_sync_auth_templates.sh');
my $packager = File::Spec->catfile($repo, 'bin', 'setup', 'el_package_setup_dom.sh');

sub write_file {
  my ($path, $contents, $mode) = @_;
  open(my $fh, '>', $path) or die "Unable to write $path: $!";
  print {$fh} $contents;
  close($fh) or die "Unable to close $path: $!";
  chmod($mode, $path) if defined $mode;
}

sub slurp {
  my ($path) = @_;
  open(my $fh, '<', $path) or die "Unable to read $path: $!";
  local $/;
  return <$fh>;
}

sub run_command {
  my (@command) = @_;
  my $error = gensym();
  my $pid = open3(undef, my $output, $error, @command);
  local $/;
  my $stdout = <$output> // '';
  my $stderr = <$error> // '';
  waitpid($pid, 0);
  return ($? >> 8, $stdout.$stderr);
}

subtest 'propagation requests all configured vhost domains' => sub {
  for my $relative (qw(bin/setup/el_propogate.sh bin/setup/el_propogate_fedora.sh)) {
    my $source = slurp(File::Spec->catfile($repo, $relative));
    like($source, qr/el_sync_auth_templates\.sh"? --all/, "$relative synchronizes every vhost");
    unlike($source, qr/el_sync_auth_templates\.sh \/LOVE\/earth\.love/, "$relative has no single-domain sync");
  }
  my $sync_source = slurp($sync);
  like($sync_source, qr/TEMPLATE_OWNER=www-data.*TEMPLATE_OWNER=apache/s,
    'template ownership falls back to the Fedora Apache account when needed');
  like($sync_source, qr/EL_BUTTON_NEW\.oml.*EL_BUTTON_ADD\.oml/s,
    'dedicated mutation-route buttons are part of the forced security template sync');
  like($sync_source, qr/EL_LOGON\.oml.*EL_SIGNUP\.oml/s,
    'public signup template is part of the forced authentication template sync');
  like($sync_source, qr/EL_HEADER\.oml.*EL_NAV_BUTTONS\.oml.*EL_NAV_MENUS\.oml.*DEFAULT\.oml/s,
    'header chrome and the default landing page are part of the forced template sync');
  like($sync_source, qr/EL_NAV_SHOW_MORE\.oml.*EL_TOKENS_SEARCH\.oml/s,
    'data-box toolbar templates are part of the forced template sync');
  like($sync_source, qr/EL_TOKENS\.oml.*EL_TOKENS_INPUT\.oml/s,
    'read-route tokens including elSHOW_POST are part of the forced template sync');
  my $propagator = slurp(File::Spec->catfile($repo, 'bin', 'tools', 'PROPOGATE_earthlove.pl'));
  like($propagator, qr/ellogon\.pl\s+elsignup\.pl\s+ellogoff\.pl/s,
    'public signup CGI is installed with the authentication routes');
  like($propagator, qr/my \@CGISOURCE = qw \{[^}]*\bpage\.pl\b[^}]*elnew\.pl/s,
    'canonical read and mutation CGI are installed');
  unlike($propagator, qr/my \@CGISOURCE = qw \{[^}]*\belshow\.pl\b/s,
    'elshow is not a separate installed read route');
  unlike($propagator, qr/my \@CGISOURCE = qw \{[^}]*\bpage7\.pl\b/s,
    'Orbit7 read aliases are not installed');
  like($propagator, qr/my \@CGIRETIRED = qw \{[^}]*\bpage7\.pl\b/s,
    'Orbit7 read aliases are retired from cgi-bin on propagate');
  like($propagator, qr/my \@CGIRETIRED = qw \{[^}]*\belshow\.pl\b/s,
    'elshow is retired from cgi-bin on propagate');
  my $tokens = slurp(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_TOKENS.oml'));
  like($tokens, qr/ELSHOW\s+=\[#_ORBIT#page\?/, 'ELSHOW uses the canonical /o/page handler');
  unlike($tokens, qr/ELSHOW\s+=\[#_ORBIT#elshow\?/, 'ELSHOW no longer points at /o/elshow');
  ok(-x File::Spec->catfile($repo, 'bin', 'cgi', 'elsignup.pl'),
    'public signup CGI source is executable');
  my $new_button = slurp(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_BUTTON_NEW.oml'));
  my $add_button = slurp(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_BUTTON_ADD.oml'));
  like($new_button, qr/#_ORBIT#elnew\?/, 'create navigation enters the authorized elnew handler');
  unlike($new_button, qr/#SHOWPAGE_BUTTON#/, 'create navigation cannot invoke EL_NEW through generic page');
  like($add_button, qr/#_ORBIT#eladd\?/, 'add navigation enters the authorized eladd handler');
  unlike($add_button, qr/#SHOWPAGE_BUTTON#/, 'add navigation cannot invoke EL_ADD through generic page');
};

subtest 'deployment fails closed and is independent of the installed Perl version' => sub {
  for my $relative (qw(bin/setup/el_propogate.sh bin/setup/el_propogate_fedora.sh)) {
    my $source = slurp(File::Spec->catfile($repo, $relative));
    like($source, qr/^set -euo pipefail$/m, "$relative exits on an unhandled command failure");
    like($source, qr{/usr/bin/perl -MConfig -e 'print \$Config\{sitelib\}'},
      "$relative discovers the site-library path from the CGI interpreter");
    unlike($source, qr{/usr/local/share/perl/5\.38\.2},
      "$relative does not hardcode a distribution Perl version");
    like($source,
      qr/if ! sudo "\$SCRIPTPATH\/el_sync_auth_templates\.sh" --all; then.*?exit 1/s,
      "$relative explicitly fails when template synchronization fails");
    unlike($source, qr{chmod \+x /(?:usr/lib|var/www)/cgi-bin/\*},
      "$relative has no obsolete wildcard CGI chmod");
  }

  my $propagator = slurp(File::Spec->catfile($repo, 'bin', 'tools', 'PROPOGATE_earthlove.pl'));
  like($propagator, qr/chmod\(0755, \$newfile, \$file\) == 2/,
    'the propagator itself makes both CGI names executable');

  my $activation = slurp(File::Spec->catfile($repo, 'bin', 'SETUP_DOM', 'installACTIVATION.pl'));
  like($activation, qr/system\('sudo', \$auth_template_sync, \$domdir\)/,
    'activation routes policy files and root-specific shadows through the hardened synchronizer');

  for my $relative (qw(
      bin/setup/el_setup_EARTHLOVE.sh
      bin/setup/el_setup_EARTHLOVE_fedora.sh
  )) {
    my $source = slurp(File::Spec->catfile($repo, $relative));
    like($source,
      qr{if ! "\$SCRIPTPATH/el_package_setup_dom\.sh" .*?; then.*?exit 1}s,
      "$relative fails if deterministic security-package staging fails");
  }

  my $guide = slurp(File::Spec->catfile($repo, 'doc', '4_AUTHENTICATION.md'));
  like($guide, qr{sudo -u www-data /usr/local/sbin/eluser create},
    'administrator examples use the absolute eluser installation path');
  unlike($guide, qr{sudo -u (?:www-data|apache) eluser\b},
    'administrator examples do not depend on the runtime user PATH');
};

subtest 'domain setup packaging overwrites stale files and fails closed' => sub {
  my $tmp = tempdir(CLEANUP => 1);
  my $target = File::Spec->catdir($tmp, 'SETUP_DOM');
  make_path(File::Spec->catdir($target, '_TEMPLATES'));
  my $stale_activation = File::Spec->catfile($target, 'installACTIVATION.pl');
  my $stale_template = File::Spec->catfile($target, '_TEMPLATES', 'EL_LOGON.oml');
  write_file($stale_activation, "stale activation\n", 0755);
  write_file($stale_template, "stale template\n", 0644);
  my $future = time + 86_400;
  utime($future, $future, $stale_activation, $stale_template)
    or die "Unable to set future package mtimes: $!";

  my ($status, $output) = run_command($packager,
    File::Spec->catdir($repo, 'bin'), $target);
  is($status, 0, 'domain setup package staging succeeds') or diag($output);
  is(slurp($stale_activation),
    slurp(File::Spec->catfile($repo, 'bin', 'SETUP_DOM', 'installACTIVATION.pl')),
    'a newer-mtime activation installer is force-refreshed');
  is(slurp($stale_template),
    slurp(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_LOGON.oml')),
    'a newer-mtime authentication template is force-refreshed');
  ok(-x File::Spec->catfile($target, 'el_sync_auth_templates.sh'),
    'the packaged synchronizer is executable');
  ok(-f File::Spec->catfile($target, '_TEMPLATES', 'EL_SIGNUP.oml'),
    'the packaged domain setup includes the public signup template');

  my $outside = File::Spec->catfile($tmp, 'outside-template');
  write_file($outside, "outside must remain unchanged\n", 0644);
  unlink($stale_template) or die "Unable to replace packaged template for symlink test: $!";
  symlink($outside, $stale_template) or die "Unable to create packaged template symlink: $!";
  my ($resync_status, $resync_output) = run_command($packager,
    File::Spec->catdir($repo, 'bin'), $target);
  is($resync_status, 0, 'restaging safely replaces a nested destination symlink')
    or diag($resync_output);
  ok(!-l $stale_template && -f $stale_template,
    'the packaged authentication template is restored as a regular file');
  is(slurp($stale_template),
    slurp(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_LOGON.oml')),
    'the replacement template contains the current policy');
  is(slurp($outside), "outside must remain unchanged\n",
    'restaging never writes through a destination symlink');

  my $invalid_target = File::Spec->catfile($tmp, 'not-a-directory');
  write_file($invalid_target, "occupied\n");
  my ($failure_status, $failure_output) = run_command($packager,
    File::Spec->catdir($repo, 'bin'), $invalid_target);
  isnt($failure_status, 0, 'an invalid package target fails instead of continuing');
  like($failure_output, qr/Refusing unsafe domain-setup package target/,
    'package failure identifies its unsafe target');
};

subtest 'fresh-domain builders establish the private store last' => sub {
  my $setup = slurp(File::Spec->catfile($repo, 'bin', 'SETUP_DOM', 'elSETUP_DOM.pl'));
  my $build_at = index($setup, 'system("$appdir/elBUILD_root.pl"');
  my $auth_at = index($setup, 'EnsureAuthRoot($AuthDir, $AuthRuntimeUser)', $build_at + 1);
  ok($build_at >= 0 && $auth_at > $build_at, 'per-domain setup re-hardens auth after its builder');

  my $akashic = slurp(File::Spec->catfile($repo, 'bin', 'setup', 'el_setup_AKASHIC.sh'));
  like($akashic, qr/install -d -o "\$AUTH_RUNTIME_USER" -g "\$AUTH_RUNTIME_USER" -m 0700 "\$AUTH_DIR"/,
    'main Earth.Love build creates a runtime-owned 0700 auth root');

  my $activation = slurp(File::Spec->catfile($repo, 'bin', 'SETUP_DOM', 'installACTIVATION.pl'));
  like($activation, qr/EnsureAuthRoot\(\$domdir, \$AuthRuntimeUser\)/,
    'activation installation also establishes the private auth root');

  for my $relative (qw(
      bin/SETUP_DOM/elBUILD_root.pl
      bin/SETUP_DOM/elSETUP_DOM.pl
      bin/SETUP_DOM/installACTIVATION.pl
      bin/setup/el_setup_AKASHIC.sh
  )) {
    like(slurp(File::Spec->catfile($repo, $relative)), qr{restorecon[^\n]*-RF[^\n]*(?:\$auth_dir|\$AUTH_DIR)},
      "$relative restores the targeted authentication SELinux label");
  }

  for my $relative (qw(
      bin/SETUP_DOM/elBUILD_root.pl
      bin/build/BUILD_root.pl
      bin/build/BUILD_earthlove.pl
  )) {
    unlike(slurp(File::Spec->catfile($repo, $relative)),
      qr/CreateWordBase\('_ORBIT\.PASSPHRASE'/,
      "$relative does not build the misleading legacy passphrase tree");
  }
};

subtest 'eluser keeps recovery commands independent of crypto providers' => sub {
  my $source = slurp(File::Spec->catfile($repo, 'bin', 'tools', 'eluser.pl'));
  like($source, qr/if \(\$command eq 'create' \|\| \$command eq 'reset'\) \{\s*my \(\$deps, \$missing\) = \$auth->dependencies_available/s,
    'crypto dependency check is scoped to credential writes');
  like($source, qr/if \(\$command eq 'role'\) \{\s*die "The role command requires --role/s,
    'role command requires an explicit role option');
  like($source, qr/if \(\$command eq 'create'\) \{\s*\$role = 'viewer' if \(!defined\(\$role\)\)/s,
    'create retains viewer as its safe default');
  unlike($source, qr/^use Term::ReadKey/m, 'non-credential commands do not load terminal passphrase support');
  like($source, qr/eval \{ require Term::ReadKey; 1 \}/,
    'terminal passphrase support is loaded only when a passphrase is read');
  like($source, qr/--role is valid only with create or role/,
    'irrelevant role options are rejected');
  like($source, qr/--person is valid only with create/,
    'irrelevant person options are rejected');
  like($source, qr/if \(\$< == 0 \|\| \$> == 0\)/,
    'eluser refuses both real-root and effective-root execution');
  my @version_bumps = ($source =~ /bump_auth_version/g);
  my @bulk_revokes = ($source =~ /revoke_all_sessions/g);
  is(scalar(@version_bumps), 1,
    'only the explicit revoke command advances auth_version in the CLI');
  is(scalar(@bulk_revokes), 1,
    'only the explicit revoke command performs separate bulk revocation');
  like($source,
    qr/if \(\$command eq 'enable'\).*?update_account\(\$username, status => 'active'\)/s,
    'enable delegates atomic version invalidation and revocation to update_account');
};

SKIP: {
  my ($probe_status) = run_command('unshare', '-Ur', 'true');
  skip 'unprivileged user namespaces are unavailable for safe installer testing', 19
    if $probe_status != 0;

  my $tmp = tempdir(CLEANUP => 1);
  my $sites = File::Spec->catdir($tmp, 'sites');
  my $fake_bin = File::Spec->catdir($tmp, 'fake-bin');
  make_path($sites, $fake_bin);

  # A user namespace supplies EUID 0.  These wrappers ignore ownership changes
  # that cannot be represented in that namespace while retaining real copies,
  # comparisons, directory creation, and permission checks.
  write_file(
    File::Spec->catfile($fake_bin, 'install'),
    "#!/bin/sh\nfor value do target=\"\$value\"; done\nmkdir -p -- \"\$target\"\n",
    0755,
  );
  write_file(File::Spec->catfile($fake_bin, 'chown'), "#!/bin/sh\nexit 0\n", 0755);

  # Exercise the exact installed layout: activation and its synchronizer live
  # in SETUP_DOM, with the complete source in SETUP_DOM/_TEMPLATES.
  my $packaged = File::Spec->catdir($tmp, 'SETUP_DOM');
  my ($package_copy_status, $package_copy_output) = run_command(
    $packager, File::Spec->catdir($repo, 'bin'), $packaged,
  );
  is($package_copy_status, 0, 'test packages the complete template source')
    or diag($package_copy_output);

  my $packaged_domain = File::Spec->catdir($tmp, 'packaged.example');
  make_path(File::Spec->catdir($packaged_domain, '_WEB'));
  make_path(File::Spec->catdir($packaged_domain, '_ROOT', '_TEMPLATES'));
  my $path = "$fake_bin:$ENV{PATH}";
  my ($packaged_status, $packaged_output) = run_command(
    'unshare', '-Ur', 'env', "PATH=$path",
    File::Spec->catfile($packaged, 'el_sync_auth_templates.sh'), $packaged_domain,
  );
  is($packaged_status, 0, 'the packaged SETUP_DOM synchronizer finds its local templates')
    or diag($packaged_output);
  ok(-f File::Spec->catfile($packaged_domain, '_ROOT', '_TEMPLATES', 'EL_LOGON.oml'),
    'packaged-layout execution installs the login template');

  my @domains;
  for my $name (qw(one.example two.example)) {
    my $domain = File::Spec->catdir($tmp, $name);
    make_path(File::Spec->catdir($domain, '_WEB'));
    make_path(File::Spec->catdir($domain, '_ROOT', '_TEMPLATES'));
    push @domains, $domain;
  }

  write_file(File::Spec->catfile($sites, 'one.conf'),
    "DocumentRoot $domains[0]/_WEB\n");
  write_file(File::Spec->catfile($sites, 'one-ssl.conf'),
    "  DocumentRoot \"$domains[0]/_WEB\" # duplicate TLS vhost\n");
  write_file(File::Spec->catfile($sites, 'two.conf'),
    "DocumentRoot \"$domains[1]/_WEB/\"\n");
  write_file(File::Spec->catfile($sites, 'default.conf'),
    "DocumentRoot /var/www/html\n");

  my $stale = File::Spec->catfile($domains[0], '_ROOT', '_TEMPLATES', 'EL_HEADER.oml');
  write_file($stale, "stale\n");
  my $shadow_dir = File::Spec->catdir($domains[0], 'CUSTOM', '_TEMPLATES');
  make_path($shadow_dir);
  my $shadow = File::Spec->catfile($shadow_dir, 'EL_HEADER.oml');
  write_file($shadow, "stale root-specific shadow\n");

  my ($status, $output) = run_command(
    'unshare', '-Ur', 'env',
    "EL_APACHE_SITES_DIR=$sites", "PATH=$path", $sync, '--all',
  );
  is($status, 0, 'all-domain synchronization succeeds for initialized vhosts')
    or diag($output);
  my $sync_count = () = $output =~ /Synchronizing authentication templates for /g;
  is($sync_count, 2, 'HTTP and HTTPS vhosts are deduplicated by canonical domain');
  like($output, qr/Skipping non-Orbit DocumentRoot/, 'unrelated document roots are safely skipped');

  for my $domain (@domains) {
    my $installed = File::Spec->catfile($domain, '_ROOT', '_TEMPLATES', 'EL_LOGON.oml');
    ok(-f $installed, "auth template installed for $domain");
    is(slurp($installed), slurp(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_LOGON.oml')),
      "auth template content is current for $domain");
  }
  ok(-f "$stale.~1~", 'a numbered backup preserves a replaced template');
  is(slurp($stale), slurp(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_HEADER.oml')),
    'stale security template is force-synchronized');
  is(slurp($shadow), slurp(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_HEADER.oml')),
    'an existing root-specific security shadow is force-synchronized');
  ok(-f "$shadow.~1~", 'the replaced root-specific shadow receives a numbered backup');
  ok(!-e File::Spec->catfile($shadow_dir, 'EL_LOGON.oml'),
    'unshadowed templates are not populated into every root-specific directory');

  my $broken_sites = File::Spec->catdir($tmp, 'broken-sites');
  make_path($broken_sites);
  write_file(File::Spec->catfile($broken_sites, 'broken.conf'),
    "DocumentRoot $tmp/not-created/_WEB\n");
  my ($broken_status, $broken_output) = run_command(
    'unshare', '-Ur', 'env',
    "EL_APACHE_SITES_DIR=$broken_sites", "PATH=$path", $sync, '--all',
  );
  isnt($broken_status, 0, 'a configured Orbit-like vhost cannot remain silently stale');
  like($broken_output, qr/Refusing configured but uninitialized\/unsafe Orbit DocumentRoot/,
    'configured invalid Orbit root is reported as a deployment error');

  my $unsafe_sites = File::Spec->catdir($tmp, 'unsafe-sites');
  my $unsafe_domain = File::Spec->catdir($tmp, 'unsafe.example');
  make_path($unsafe_sites, File::Spec->catdir($unsafe_domain, '_WEB'));
  make_path(File::Spec->catdir($unsafe_domain, '_ROOT', '_TEMPLATES'));
  write_file(File::Spec->catfile($unsafe_sites, 'unsafe.conf'),
    "DocumentRoot $unsafe_domain/_WEB\n");
  symlink('/dev/null', File::Spec->catfile($unsafe_domain, '_ROOT', '_TEMPLATES', 'EL_LOGON.oml'))
    or die "Unable to create unsafe template link: $!";

  my ($unsafe_status, $unsafe_output) = run_command(
    'unshare', '-Ur', 'env',
    "EL_APACHE_SITES_DIR=$unsafe_sites", "PATH=$path", $sync, '--all',
  );
  isnt($unsafe_status, 0, 'an attempted unsafe template update fails propagation');
  like($unsafe_output, qr/Refusing symbolic-link authentication template/,
    'unsafe attempted update reports the precise refusal');
}

done_testing;

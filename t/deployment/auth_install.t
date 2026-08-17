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
    like($source, qr/el_sync_auth_templates\.sh --all/, "$relative synchronizes every vhost");
    unlike($source, qr/el_sync_auth_templates\.sh \/LOVE\/earth\.love/, "$relative has no single-domain sync");
  }
  my $sync_source = slurp($sync);
  like($sync_source, qr/TEMPLATE_OWNER=www-data.*TEMPLATE_OWNER=apache/s,
    'template ownership falls back to the Fedora Apache account when needed');
  like($sync_source, qr/EL_BUTTON_NEW\.oml.*EL_BUTTON_ADD\.oml/s,
    'dedicated mutation-route buttons are part of the forced security template sync');
  my $new_button = slurp(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_BUTTON_NEW.oml'));
  my $add_button = slurp(File::Spec->catfile($repo, 'bin', '_TEMPLATES', 'EL_BUTTON_ADD.oml'));
  like($new_button, qr/#_ORBIT#elnew\?/, 'create navigation enters the authorized elnew handler');
  unlike($new_button, qr/#SHOWPAGE_BUTTON#/, 'create navigation cannot invoke EL_NEW through generic page');
  like($add_button, qr/#_ORBIT#eladd\?/, 'add navigation enters the authorized eladd handler');
  unlike($add_button, qr/#SHOWPAGE_BUTTON#/, 'add navigation cannot invoke EL_ADD through generic page');
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
  like($source,
    qr/if \(\$command eq 'enable'\).*?bump_auth_version.*?revoke_all_sessions.*?update_account\(\$username, status => 'active'\)/s,
    'enable invalidates sessions while disabled and writes active last');
};

SKIP: {
  my ($probe_status) = run_command('unshare', '-Ur', 'true');
  skip 'unprivileged user namespaces are unavailable for safe installer testing', 16
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

  my $path = "$fake_bin:$ENV{PATH}";
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

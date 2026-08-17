#!/usr/bin/perl

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'bin/lib';
use Orbit::Orbit7;

sub make_domain {
  my ($base, $name) = @_;
  my $domain = File::Spec->catdir($base, $name);
  make_path(
    File::Spec->catdir($domain, '_WEB'),
    map { File::Spec->catdir($domain, 'LANGS', $_) }
      qw(_WORDS _PHRASES _PATHS _TREES _TEMPLATES _DATES),
  );
  return abs_path($domain);
}

sub orbit_for_document_root {
  my ($document_root, $global_override, $host) = @_;
  local %ENV = (
    GATEWAY_INTERFACE => 'CGI/1.1',
    REQUEST_METHOD    => 'GET',
    DOCUMENT_ROOT     => $document_root,
    EARTH_LOVE        => $global_override,
    ELROOT            => 'LANGS',
    QUERY_STRING      => '',
    REQUEST_URI       => '/o/page?r=LANGS',
    HTTP_HOST         => $host,
    REQUEST_SCHEME    => 'https',
    HTTPS             => 'on',
    SERVER_PORT       => '443',
    REMOTE_ADDR       => '192.0.2.10',
  );
  return Orbit->new();
}

my $temporary = tempdir(CLEANUP => 1);
my $domain_a = make_domain($temporary, 'alpha.example');
my $domain_b = make_domain($temporary, 'beta.example');

subtest 'each virtual host binds its own data and authentication roots' => sub {
  my $alpha = orbit_for_document_root(
    File::Spec->catdir($domain_a, '_WEB'),
    $domain_b,
    'alpha.example',
  );
  my $beta = orbit_for_document_root(
    File::Spec->catdir($domain_b, '_WEB'),
    $domain_a,
    'beta.example',
  );

  is($alpha->{_DomainDir}, $domain_a.'/', 'alpha request ignores the conflicting global override');
  is($beta->{_DomainDir}, $domain_b.'/', 'beta request ignores the conflicting global override');
  is($alpha->{_Akashic}->{_DomainDir}, $domain_a.'/', 'alpha data service is bound to alpha');
  is($beta->{_Akashic}->{_DomainDir}, $domain_b.'/', 'beta data service is bound to beta');
  is($alpha->{_Auth}->{domain_dir}, $domain_a, 'alpha auth service is bound to alpha');
  is($beta->{_Auth}->{domain_dir}, $domain_b, 'beta auth service is bound to beta');
  isnt($alpha->{_Auth}->{auth_root}, $beta->{_Auth}->{auth_root}, 'domains cannot share an auth root');
};

subtest 'later environment-token loading cannot rebind a constructed request' => sub {
  my $alpha = orbit_for_document_root(
    File::Spec->catdir($domain_a, '_WEB'),
    $domain_b,
    'alpha.example',
  );

  local %ENV = (
    DOCUMENT_ROOT  => File::Spec->catdir($domain_b, '_WEB'),
    EARTH_LOVE     => $domain_b,
    REQUEST_METHOD => 'GET',
    HTTP_HOST      => 'beta.example',
    REQUEST_SCHEME => 'https',
    SERVER_PORT    => '443',
  );
  $alpha->LoadEnvTokens();

  is($alpha->{_DomainDir}, $domain_a.'/', 'Orbit domain remains immutable for the request');
  is($alpha->{_Auth}->{domain_dir}, $domain_a, 'auth domain remains immutable for the request');
  is($alpha->Get_Token('ENV_DOMAINDIR'), $domain_a.'/', 'exposed domain token reflects the bound domain');
};

subtest 'malformed CGI document roots fail closed' => sub {
  local %ENV = (
    GATEWAY_INTERFACE => 'CGI/1.1',
    REQUEST_METHOD    => 'GET',
    DOCUMENT_ROOT     => $domain_a,
    EARTH_LOVE        => $domain_b,
  );
  my $ok = eval { Orbit->new(); 1 };
  ok(!$ok, 'a document root outside the required _WEB layout is rejected');
  like($@, qr/DOCUMENT_ROOT/, 'the failure identifies the invalid server binding');

  local %ENV = (
    GATEWAY_INTERFACE => 'CGI/1.1',
    REQUEST_METHOD    => 'GET',
    DOCUMENT_ROOT     => File::Spec->abs2rel(File::Spec->catdir($domain_a, '_WEB')),
    EARTH_LOVE        => $domain_b,
  );
  $ok = eval { Orbit->new(); 1 };
  ok(!$ok, 'a relative server document root is rejected');

  my $split_domain = File::Spec->catdir($temporary, 'split.example');
  make_path($split_domain);
  symlink(File::Spec->catdir($domain_b, '_WEB'), File::Spec->catdir($split_domain, '_WEB'))
    or die "create split document-root symlink: $!";
  local %ENV = (
    GATEWAY_INTERFACE => 'CGI/1.1',
    REQUEST_METHOD    => 'GET',
    DOCUMENT_ROOT     => File::Spec->catdir($split_domain, '_WEB'),
    EARTH_LOVE        => $domain_a,
  );
  $ok = eval { Orbit->new(); 1 };
  ok(!$ok, 'a document root symlink cannot split content from authentication state');
};

done_testing();

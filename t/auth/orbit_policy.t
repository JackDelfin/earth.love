use strict;
use warnings;
use utf8;

use Test::More;
use lib 'bin/lib';
use Orbit::User;

{
  package TestAuth;
  sub new { bless { audits => [] }, shift }
  sub verify_csrf {
    my ($self, $session, $candidate) = @_;
    return defined($candidate) && $candidate eq ($session->{csrf_secret} // '') ? 1 : 0;
  }
  sub audit {
    my ($self, %event) = @_;
    push @{$self->{audits}}, \%event;
    return 1;
  }
}

{
  package TestCGI;
  sub new { my ($class, %params) = @_; bless { params => \%params, cookies => {} }, $class }
  sub param {
    my ($self, $name) = @_;
    return keys %{$self->{params}} if !defined($name);
    my $value = $self->{params}{$name};
    return ref($value) eq 'ARRAY' && wantarray ? @$value : $value;
  }
  sub cookie { my ($self, $name) = @_; return $self->{cookies}{$name} }
  sub cgi_error { my ($self) = @_; return $self->{params}{_cgi_error} // '' }
  sub header {
    my ($self, @args) = @_;
    $self->{header_args} = \@args;
    return '';
  }
}

{
  no warnings 'redefine';
  sub Orbit::RegisterError {
    my ($self, $message) = @_;
    $self->{_TestError} = $message;
    return 1;
  }
}

sub orbit_for {
  my ($role, %params) = @_;
  return bless {
    _Role             => $role,
    _User             => $role eq 'anonymous' ? '' : 'river-editor',
    _InvalidRootInput => 0,
    _MustChange       => 0,
    _cgi              => TestCGI->new(%params),
    _Auth             => TestAuth->new,
    _Session          => { csrf_secret => 'csrf-value' },
    _ResponseStatus   => '200 OK',
  }, 'Orbit';
}

subtest 'fixed role matrix and protected roots' => sub {
  my $anonymous = orbit_for('anonymous');
  ok($anonymous->AuthorizeAction('content.read', root => 'LANGS/ENG'), 'anonymous may read public content');
  ok(!$anonymous->AuthorizeAction('content.write', root => 'LANGS/ENG'), 'anonymous may not write');
  ok(!$anonymous->AuthorizeAction('person.self_create', root => 'PERSONS'),
    'anonymous cannot create a linked person');

  my $viewer = orbit_for('viewer');
  ok($viewer->AuthorizeAction('account.self'), 'viewer may use own account functions');
  ok(!$viewer->AuthorizeAction('content.write', root => 'LANGS/ENG'), 'viewer may not write content');
  ok($viewer->AuthorizeAction('person.self_create', root => 'PERSONS'),
    'viewer may create a person when linking it to their own account');
  ok(!$viewer->AuthorizeAction('person.self_create', root => 'LANGS/ENG'),
    'viewer cannot use person self-create on other roots');
  $viewer->{_MustChange} = 1;
  ok(!$viewer->AuthorizeAction('person.self_create', root => 'PERSONS'),
    'forced-change viewer cannot create a person');
  $viewer->{_MustChange} = 0;

  my $editor = orbit_for('editor');
  ok($editor->AuthorizeAction('content.write', root => 'LANGS/ENG'), 'editor may write public content');
  ok(!$editor->AuthorizeAction('system.write', root => 'LANGS/ENG'), 'editor may not perform system writes');
  ok(!$editor->AuthorizeAction('content.write', root => '_ORBIT/USERS'), 'editor may not write protected roots');
  ok(!$editor->AuthorizeAction('content.write', root => '../LANGS'), 'traversal root is denied');
  $editor->{_MustChange} = 1;
  ok(!$editor->AuthorizeAction('content.write', root => 'LANGS/ENG'), 'forced-change editor cannot write content');
  ok($editor->AuthorizeAction('account.self'), 'forced-change editor can still change own passphrase');

  my $admin = orbit_for('admin');
  ok($admin->AuthorizeAction('system.write', root => 'LANGS/ENG'), 'admin may perform explicit system action');
  ok($admin->AuthorizeAction('account.admin'), 'admin may administer accounts');
  ok(!$admin->AuthorizeAction('content.write', root => '_ORBIT'), 'even admin cannot use generic writes on protected roots');
  ok(!$admin->AuthorizeAction('unknown.action', root => 'LANGS'), 'unknown actions deny by default');

  my $guard = orbit_for('admin');
  $guard->{_User} = 'sky-watcher';
  like(
    $guard->_AdminProtectTarget('sky-watcher', 'disable', [
      { username => 'sky-watcher', role => 'admin', status => 'active' },
    ]),
    qr/own administrator/,
    'an administrator cannot disable themselves from the admin page',
  );
  like(
    $guard->_AdminProtectTarget('sky-watcher', 'role', [
      { username => 'sky-watcher', role => 'admin', status => 'active' },
    ]),
    qr/own administrator/,
    'an administrator cannot demote themselves from the admin page',
  );
  $guard->{_cgi} = TestCGI->new(role => 'editor');
  like(
    $guard->_AdminProtectTarget('sky-watcher', 'disable', [
      { username => 'sky-watcher', role => 'admin', status => 'active' },
      { username => 'other-admin', role => 'admin', status => 'active' },
    ]),
    qr/own administrator/,
    'self-protection applies even when another administrator exists',
  );
  $guard->{_User} = 'other-admin';
  $guard->{_cgi} = TestCGI->new(role => 'viewer');
  like(
    $guard->_AdminProtectTarget('sky-watcher', 'role', [
      { username => 'sky-watcher', role => 'admin', status => 'active' },
    ]),
    qr/last active administrator/,
    'the last active administrator cannot be demoted',
  );
  is(
    $guard->_AdminProtectTarget('river-editor', 'disable', [
      { username => 'sky-watcher', role => 'admin', status => 'active' },
      { username => 'river-editor', role => 'editor', status => 'active' },
    ]),
    '',
    'a non-admin account can be disabled',
  );

  $admin->{_InvalidRootInput} = 1;
  ok(!$admin->AuthorizeAction('content.write', root => 'LANGS'), 'a replaced invalid CGI root cannot become an allowed write');
};

subtest 'mutation route method and CSRF enforcement' => sub {
  local $ENV{REQUEST_METHOD} = 'GET';
  my $editor = orbit_for('editor');
  is_deeply([$editor->AuthorizeMutationRequest('LANGS/ENG', 'create')], [1, 0], 'GET may render form but cannot process');
  is($editor->{_MutationTemplateAllowed}, 'EL_NEW', 'authorized create handler opts in only its entry template');

  local $ENV{REQUEST_METHOD} = 'POST';
  $editor = orbit_for('anonymous', _cgi_error => '413 Request entity too large');
  is_deeply([$editor->AuthorizeMutationRequest('LANGS/ENG', 'create')], [0, 0], 'oversized body is rejected before authorization');
  is($editor->{_ResponseStatus}, '413 Content Too Large', 'oversized body retains a 413 response');

  $editor = orbit_for('anonymous', _cgi_error => '400 Bad request');
  is_deeply([$editor->AuthorizeMutationRequest('LANGS/ENG', 'create')], [0, 0], 'malformed body is rejected before authorization');
  is($editor->{_ResponseStatus}, '400 Bad Request', 'malformed body retains a 400 response');

  $editor = orbit_for('editor');
  is_deeply([$editor->AuthorizeMutationRequest('LANGS/ENG', 'create')], [0, 0], 'POST without CSRF is denied');
  is($editor->{_ResponseStatus}, '403 Forbidden', 'missing CSRF sets forbidden status');
  is($editor->{_MutationTemplateAllowed}, '', 'a denied handler cannot opt in a mutation template');

  $editor = orbit_for('editor', csrf_token => 'wrong');
  is_deeply([$editor->AuthorizeMutationRequest('LANGS/ENG', 'create')], [0, 0], 'bad CSRF is denied');

  $editor = orbit_for('editor', csrf_token => 'csrf-value');
  is_deeply([$editor->AuthorizeMutationRequest('LANGS/ENG', 'create')], [1, 1], 'valid POST and CSRF may process');

  $editor = orbit_for(
    'editor', csrf_token => 'csrf-value', formfields => '_text',
    _text => '<script>#CSRF_TOKEN#</script>',
  );
  is_deeply([$editor->AuthorizeMutationRequest('LANGS/ENG', 'create')], [0, 0], 'editor markup and OML payload is denied');
  is($editor->{_ResponseStatus}, '400 Bad Request', 'unsafe editor content is a bad request');

  my $admin = orbit_for(
    'admin', csrf_token => 'csrf-value', formfields => '_text',
    _text => '#OML[trusted-administrator-template]#',
  );
  is_deeply([$admin->AuthorizeMutationRequest('LANGS/ENG', 'create')], [1, 1], 'administrator retains trusted template-author access');

  local $ENV{REQUEST_METHOD} = 'PUT';
  $editor = orbit_for('editor', csrf_token => 'csrf-value');
  is_deeply([$editor->AuthorizeMutationRequest('LANGS/ENG', 'create')], [0, 0], 'unsupported method is denied');
  is($editor->{_ResponseStatus}, '405 Method Not Allowed', 'unsupported method sets 405');
};

subtest 'web top-level templates fail closed' => sub {
  my $anonymous = orbit_for('anonymous');
  ok($anonymous->_WebTemplateAllowed('DEFAULT'), 'default entry point is public');
  ok($anonymous->_WebTemplateAllowed('EL_SHOW'), 'read-only content entry point is public');
  ok($anonymous->_WebTemplateAllowed('EL_STYLE'), 'stylesheet entry point is public');
  ok(!$anonymous->_WebTemplateAllowed('EL_VIEW_FLOWER_BASIC'), 'internal rendering helper cannot be selected as a page');
  ok(!$anonymous->_WebTemplateAllowed('EL_LOGON'), 'credential template requires its dedicated handler');
  ok(!$anonymous->_WebTemplateAllowed('EL_SIGNUP'), 'signup template requires its dedicated handler');
  ok(!$anonymous->_WebTemplateAllowed('EL_PROFILE'), 'profile template requires its dedicated handler');
  ok(!$anonymous->_WebTemplateAllowed('EL_SETTINGS'), 'settings template requires its dedicated handler');

  local $ENV{HTTPS} = 'on';
  local $anonymous->{_AuthTemplateAllowed} = 1;
  ok($anonymous->_WebTemplateAllowed('EL_LOGON'), 'secure authentication handler may render its form');
  ok($anonymous->_WebTemplateAllowed('EL_PROFILE'), 'profile handler may render its page');
  ok($anonymous->_WebTemplateAllowed('EL_SETTINGS'), 'settings handler may render its page');
  ok(!$anonymous->_WebTemplateAllowed('EL_ADMIN'), 'anonymous cannot render the admin template');

  my $admin = orbit_for('admin');
  ok(!$admin->_WebTemplateAllowed('EL_ADMIN'), 'admin template requires its dedicated handler');
  local $admin->{_AuthTemplateAllowed} = 1;
  ok($admin->_WebTemplateAllowed('EL_ADMIN'), 'admin handler may render its page');
  $admin->{_MustChange} = 1;
  ok(!$admin->_WebTemplateAllowed('EL_ADMIN'), 'forced-change admin cannot open administration');

  local $anonymous->{_MutationTemplateAllowed} = 'EL_ADD';
  ok($anonymous->_WebTemplateAllowed('EL_ADD'), 'authorized mutation handler may render its own template');
  ok(!$anonymous->_WebTemplateAllowed('EL_NEW'), 'one mutation handler cannot opt in a different template');

  local $anonymous->{_bCommandLine} = 1;
  ok($anonymous->_WebTemplateAllowed('EL_SHOW_STATIC'), 'command-line and batch rendering retain internal templates');
};

subtest 'safe redirect targets' => sub {
  my $orbit = orbit_for('anonymous');
  is($orbit->_ValidateReturnTo('/o/page?r=LANGS'), '/o/page?r=LANGS', 'relative local path accepted');
  is($orbit->_ValidateReturnTo('https://evil.example/'), '/o/page', 'absolute URL rejected');
  is($orbit->_ValidateReturnTo('//evil.example/'), '/o/page', 'scheme-relative URL rejected');
  is($orbit->_ValidateReturnTo('/o/../_ORBIT'), '/o/page', 'parent traversal rejected');
  is($orbit->_ValidateReturnTo('/o/%2e%2e/_ORBIT'), '/o/page', 'encoded parent traversal rejected');
  is($orbit->_ValidateReturnTo('/o/%252e%252e/_ORBIT'), '/o/page', 'double-encoded parent traversal rejected');
  is($orbit->_ValidateReturnTo('/o/page?q=a%2Fb'), '/o/page?q=a%2Fb', 'encoded query data remains valid');
  is($orbit->_ValidateReturnTo('/o/page%'), '/o/page', 'malformed percent escape rejected');
  is($orbit->_ValidateReturnTo("/o/page\r\nX-Test: bad"), '/o/page', 'header injection rejected');
  is($orbit->_ValidateReturnTo('/o/page%0d%0aX-Test:bad'), '/o/page', 'encoded header injection rejected');
  is($orbit->_ValidateReturnTo("/o/page\x1fhidden"), '/o/page', 'all ASCII control bytes are rejected');
};

subtest 'redirects retain the standard response security headers' => sub {
  my $orbit = orbit_for('anonymous');
  my $output = '';
  open(my $capture, '>', \$output) or die "open scalar output: $!";
  {
    local *STDOUT = $capture;
    $orbit->_EmitRedirect('/o/page');
  }
  close($capture) or die "close scalar output: $!";
  my %headers = @{$orbit->{_cgi}{header_args}};
  is($headers{-X_Content_Type_Options}, 'nosniff', 'redirect disables MIME sniffing');
  is($headers{-Referrer_Policy}, 'same-origin', 'redirect limits referrer disclosure');
  is($headers{-X_Frame_Options}, 'SAMEORIGIN', 'redirect retains frame protection');
};

subtest 'production and loopback cookie policy' => sub {
  local %ENV = %ENV;
  $ENV{HTTPS} = 'on';
  $ENV{REQUEST_SCHEME} = 'https';
  $ENV{SERVER_PORT} = 443;
  my $orbit = orbit_for('anonymous');
  is(
    $orbit->_NewSessionCookie('a' x 43),
    '__Host-el_sid='.('a' x 43).'; Path=/; HttpOnly; SameSite=Lax; Secure',
    'production cookie is host-only, Secure, HttpOnly, and Lax',
  );
  like(
    $orbit->_NewLoginCSRFCookie('n' x 43),
    qr/^__Host-el_login_csrf=.*HttpOnly; SameSite=Strict; Max-Age=600; Secure\z/,
    'production login nonce cookie is host-only, short-lived, HttpOnly, Secure, and Strict',
  );

  delete $ENV{HTTPS};
  $ENV{REQUEST_SCHEME} = 'http';
  $ENV{SERVER_PORT} = 8080;
  $ENV{EL_AUTH_ALLOW_INSECURE_LOOPBACK} = 1;
  $ENV{REMOTE_ADDR} = '127.0.0.1';
  $ENV{HTTP_HOST} = 'localhost:8080';
  ok($orbit->_AuthTransportAllowed, 'explicit loopback HTTP development mode is allowed');
  like($orbit->_NewSessionCookie('b' x 43), qr/^el_dev_sid=.*HttpOnly; SameSite=Lax\z/, 'development cookie has a distinct name and no Secure flag');
  like($orbit->_NewLoginCSRFCookie('n' x 43), qr/^el_dev_login_csrf=.*SameSite=Strict; Max-Age=600\z/, 'development login nonce has a distinct non-Secure cookie name');

  $ENV{REMOTE_ADDR} = '192.0.2.10';
  ok(!$orbit->_AuthTransportAllowed, 'insecure LAN client is denied');
  is($orbit->_NewSessionCookie('c' x 43), '', 'session helper cannot mint a LAN HTTP cookie');
  is($orbit->_ExpiredSessionCookie(), '', 'session helper cannot emit a LAN HTTP cookie');
  $ENV{REMOTE_ADDR} = '127.0.0.1';
  is($orbit->_NewSessionCookie('short'), '', 'session helper rejects malformed tokens');
};

subtest 'web mutations cannot trigger legacy remote image fetching' => sub {
  open(my $fh, '<:raw', 'bin/lib/Orbit/Akashic/Add.pm')
    or die "open Orbit/Akashic/Add.pm: $!";
  local $/;
  my $source = <$fh>;
  close($fh) or die "close Orbit/Akashic/Add.pm: $!";

  unlike($source, qr/SaveWordImageUrl\s*\(/,
    'the authenticated add route has no server-side URL fetch call');
  like($source, qr/\$DataType eq 'IMAGE'.*Image import is not available/s,
    'image mutations fail closed until a validated upload flow exists');
};

done_testing;

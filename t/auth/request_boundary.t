#!/usr/bin/perl
use strict;
use warnings;
use utf8;

use Test::More;
use lib 'bin/lib';
use Orbit::Orbit7;

{
  package BoundaryCGI;

  sub new {
    my ($class, %args) = @_;
    return bless {
      params    => $args{params} || {},
      cookies   => $args{cookies} || {},
      cgi_error => $args{cgi_error} || '',
    }, $class;
  }

  sub param {
    my ($self, $name) = @_;
    return keys %{$self->{params}} if !defined($name);
    return $self->{params}{$name};
  }

  sub cookie {
    my ($self, $name) = @_;
    return $self->{cookies}{$name};
  }

  sub cgi_error { return shift->{cgi_error}; }
}

{
  package BoundaryAuth;

  sub new {
    my ($class, %args) = @_;
    return bless {
      nonce               => $args{nonce} || ('n' x 43),
      authenticate_result => $args{authenticate_result},
      restore_result      => $args{restore_result},
      revoke_result       => exists($args{revoke_result}) ? $args{revoke_result} : 1,
      change_result       => $args{change_result},
      create_session_result => $args{create_session_result},
      create_session_error  => $args{create_session_error},
      authenticate_calls  => 0,
      revoke_calls        => 0,
      change_calls        => 0,
      create_session_calls => 0,
      audits              => [],
    }, $class;
  }

  sub issue_login_nonce { return shift->{nonce}; }

  sub verify_login_nonce {
    my ($self, $cookie, $candidate) = @_;
    return defined($cookie) && defined($candidate)
      && $cookie eq $self->{nonce} && $candidate eq $self->{nonce};
  }

  sub authenticate {
    my ($self) = @_;
    $self->{authenticate_calls}++;
    return $self->{authenticate_result} || { ok => 0 };
  }

  sub verify_csrf {
    my ($self, $session, $candidate) = @_;
    return defined($candidate) && $candidate eq ($session->{csrf_secret} // '');
  }

  sub revoke_session {
    my ($self) = @_;
    $self->{revoke_calls}++;
    return $self->{revoke_result};
  }

  sub restore_session { return shift->{restore_result} || { ok => 0 }; }

  sub change_passphrase {
    my ($self, @args) = @_;
    $self->{change_calls}++;
    $self->{change_args} = \@args;
    return $self->{change_result} || { ok => 0, error => 'invalid_credentials' };
  }

  sub create_session {
    my ($self, @args) = @_;
    $self->{create_session_calls}++;
    die $self->{create_session_error} if $self->{create_session_error};
    return $self->{create_session_result} || { token => ('r' x 43) };
  }

  sub audit {
    my ($self, %event) = @_;
    push @{$self->{audits}}, \%event;
    return 1;
  }
}

{
  package BoundaryOrbit;
  our @ISA = ('Orbit');

  sub RegisterError {
    my ($self, $message) = @_;
    $self->{_LastRegisteredError} = $message;
    return 1;
  }

  sub _ShowAuthTemplate {
    my ($self, $template) = @_;
    $self->{_LastTemplate} = $template;
    return 'template';
  }

  sub _RenderAuthError {
    my ($self, $status, $message) = @_;
    $self->{_LastAuthError} = [$status, $message];
    return 'error';
  }

  sub _EmitRedirect {
    my ($self, $location, $cookies) = @_;
    $self->{_LastRedirect} = [$location, $cookies];
    return 'redirect';
  }
}

sub boundary_orbit {
  my (%args) = @_;
  return bless {
    _TOKENS           => {},
    _Utils            => CoreUtils->new(),
    _StatsCnt         => 0,
    _STATS            => {},
    _bLogStats        => 0,
    _cgi              => $args{cgi} || BoundaryCGI->new(),
    _Auth             => $args{auth} || BoundaryAuth->new(),
    _Session          => $args{session},
    _SessionToken     => $args{session_token} // '',
    _SessionCookieName => $args{session_cookie_name} // '',
    _User             => $args{user} // '',
    _Role             => $args{role} // 'anonymous',
    _MustChange       => 0,
    _ResponseCookies  => [],
    _ResponseStatus   => '200 OK',
  }, 'BoundaryOrbit';
}

subtest 'all request-derived return targets remain non-recursive' => sub {
  local %ENV = %ENV;
  $ENV{HTTPS} = 'on';
  $ENV{REQUEST_SCHEME} = 'https';
  $ENV{SERVER_PORT} = 443;

  $ENV{REQUEST_URI} = '/o/page?q=#PROBE[]#';
  my $orbit = boundary_orbit();
  $orbit->_SetAnonymousAuthTokens();
  is($orbit->Get_Token('RETURN_TO'), $ENV{REQUEST_URI}, 'request URI is retained as a local return target');
  is($orbit->GetTokenRecursiveFlag('RETURN_TO'), 0, 'anonymous request URI cannot execute nested OML');

  local $ENV{REQUEST_METHOD} = 'GET';
  $orbit = boundary_orbit(
    cgi => BoundaryCGI->new(params => { return_to => '/o/page?q=#LOGON[]#' }),
  );
  is($orbit->HandleLogon(), 'template', 'logon form renders');
  is($orbit->GetTokenRecursiveFlag('RETURN_TO'), 0, 'logon return_to is non-recursive');

  $orbit = boundary_orbit(
    user => 'river-editor', role => 'editor',
    session => { csrf_secret => 'c' x 43 }, session_token => 's' x 43,
    cgi => BoundaryCGI->new(params => { return_to => '/o/page?q=#PASSWD[]#' }),
  );
  is($orbit->HandlePasswordChange(), 'template', 'passphrase-change form renders');
  is($orbit->GetTokenRecursiveFlag('RETURN_TO'), 0, 'passphrase return_to is non-recursive');
};

subtest 'logon requires a matching random cookie and form nonce' => sub {
  local %ENV = %ENV;
  $ENV{HTTPS} = 'on';
  $ENV{REQUEST_SCHEME} = 'https';
  $ENV{SERVER_PORT} = 443;
  $ENV{REQUEST_METHOD} = 'GET';
  my $nonce = 'n' x 43;
  my $auth = BoundaryAuth->new(nonce => $nonce);
  my $orbit = boundary_orbit(auth => $auth);

  is($orbit->HandleLogon(), 'template', 'GET prepares the login form');
  is($orbit->Get_Token('LOGIN_CSRF_TOKEN'), $nonce, 'form receives the random nonce');
  is(scalar @{$orbit->{_ResponseCookies}}, 1, 'GET queues exactly one nonce cookie');
  like(
    $orbit->{_ResponseCookies}[0],
    qr/^__Host-el_login_csrf=$nonce; Path=\/; HttpOnly; SameSite=Strict; Max-Age=600; Secure$/,
    'nonce cookie is host-only, Secure, HttpOnly, short-lived, and Strict',
  );

  $ENV{REQUEST_METHOD} = 'POST';
  $auth = BoundaryAuth->new(nonce => $nonce);
  $orbit = boundary_orbit(
    auth => $auth,
    cgi => BoundaryCGI->new(params => {
      username => 'victim', passphrase => 'attacker-known-passphrase',
      login_csrf_token => $nonce,
    }),
  );
  is($orbit->HandleLogon(), 'error', 'cross-site-style POST without nonce cookie is rejected');
  is_deeply($orbit->{_LastAuthError}, [403, 'The security token is invalid or expired.'], 'failure is forbidden');
  is($auth->{authenticate_calls}, 0, 'credentials are not evaluated before login CSRF validation');
  is($auth->{audits}[0]{reason}, 'login_csrf', 'rejected pre-session request is audited without reading credentials');
  ok(!defined($orbit->{_LastRedirect}), 'forged login does not set a session');

  $auth = BoundaryAuth->new(nonce => $nonce);
  $orbit = boundary_orbit(
    auth => $auth,
    cgi => BoundaryCGI->new(
      params => {
        username => 'victim', passphrase => 'valid passphrase', login_csrf_token => $nonce,
        return_to => '/o/page',
      },
      cookies => { '__Host-el_login_csrf' => $nonce },
    ),
  );
  $auth->{authenticate_result} = {
    ok => 1, token => ('s' x 43), account => { must_change => 0 },
  };
  is($orbit->HandleLogon(), 'redirect', 'matching cookie and form nonce permits credential validation');
  is($auth->{authenticate_calls}, 1, 'credentials are evaluated once');
  is($orbit->{_LastRedirect}[0], '/o/page', 'successful login uses the validated local return target');
  my $cookies = $orbit->{_LastRedirect}[1];
  is(ref($cookies), 'ARRAY', 'successful login emits both cookie changes');
  like($cookies->[0], qr/^__Host-el_sid=s{43};/, 'new session cookie is emitted');
  like($cookies->[1], qr/^__Host-el_login_csrf=; .*Max-Age=0;/, 'consumed login nonce cookie is expired');
};

subtest 'logoff expiration requires a live session and valid CSRF' => sub {
  local %ENV = %ENV;
  $ENV{HTTPS} = 'on';
  $ENV{REQUEST_SCHEME} = 'https';
  $ENV{SERVER_PORT} = 443;
  $ENV{REQUEST_METHOD} = 'POST';

  my $auth = BoundaryAuth->new();
  my $orbit = boundary_orbit(
    auth => $auth,
    cgi => BoundaryCGI->new(params => { csrf_token => 'forged', return_to => '/o/page' }),
  );
  is($orbit->HandleLogoff(), 'error', 'no-session logout is rejected');
  is($orbit->{_LastAuthError}[0], 401, 'no-session response is unauthorized');
  is($auth->{revoke_calls}, 0, 'no server session is revoked');
  ok(!defined($orbit->{_LastRedirect}), 'no-session request emits no expiration redirect');
  is_deeply($orbit->{_ResponseCookies}, [], 'no-session request queues no cookie expiration');

  $auth = BoundaryAuth->new();
  $orbit = boundary_orbit(
    auth => $auth, user => 'river-editor', role => 'editor',
    session => { csrf_secret => ('c' x 43) }, session_token => ('s' x 43),
    session_cookie_name => '__Host-el_sid',
    cgi => BoundaryCGI->new(params => { csrf_token => 'wrong', return_to => '/o/page' }),
  );
  is($orbit->HandleLogoff(), 'error', 'live session with invalid CSRF is rejected');
  is($orbit->{_LastAuthError}[0], 403, 'bad CSRF response is forbidden');
  is($auth->{revoke_calls}, 0, 'bad CSRF cannot revoke the session');
  ok(!defined($orbit->{_LastRedirect}), 'bad CSRF emits no cookie expiration');

  $auth = BoundaryAuth->new();
  $orbit = boundary_orbit(
    auth => $auth, user => 'river-editor', role => 'editor',
    session => { csrf_secret => ('c' x 43) }, session_token => ('s' x 43),
    session_cookie_name => '__Host-el_sid',
    cgi => BoundaryCGI->new(params => { csrf_token => ('c' x 43), return_to => '/o/page' }),
  );
  is($orbit->HandleLogoff(), 'redirect', 'valid authenticated CSRF logs off');
  is($auth->{revoke_calls}, 1, 'server session is revoked once');
  like($orbit->{_LastRedirect}[1], qr/^__Host-el_sid=; .*Max-Age=0;/, 'cookie expires only after successful revocation');
};

subtest 'passphrase-change throttling reaches the browser boundary' => sub {
  local %ENV = %ENV;
  $ENV{HTTPS} = 'on';
  $ENV{REQUEST_SCHEME} = 'https';
  $ENV{SERVER_PORT} = 443;
  $ENV{REQUEST_METHOD} = 'POST';
  $ENV{REMOTE_ADDR} = '203.0.113.220';
  $ENV{HTTP_USER_AGENT} = 'boundary-agent';

  my $auth = BoundaryAuth->new(
    change_result => { ok => 0, error => 'throttled', retry_after => 900 },
  );
  my $orbit = boundary_orbit(
    auth => $auth, user => 'river-editor', role => 'editor',
    session => { csrf_secret => ('c' x 43) }, session_token => ('s' x 43),
    cgi => BoundaryCGI->new(params => {
      csrf_token => ('c' x 43),
      current_passphrase => 'current passphrase value',
      new_passphrase => 'new passphrase value',
      confirm_passphrase => 'new passphrase value',
    }),
  );
  is($orbit->HandlePasswordChange(), 'template', 'throttled change safely redisplays the dedicated form');
  is($auth->{change_calls}, 1, 'credential service is called exactly once');
  is($auth->{change_args}[3], 'ip', 'change call includes context options');
  is($auth->{change_args}[4], '203.0.113.220', 'source IP reaches bounded admission');
  is($auth->{change_args}[5], 'user_agent', 'user-agent context key is passed');
  is($auth->{change_args}[6], 'boundary-agent', 'user agent reaches the audit boundary');
  is($orbit->{_LastRegisteredError}, 'Too many passphrase attempts. Try again later.',
    'the browser receives a clear generic throttle message');
};

subtest 'committed passphrase change expires stale cookie if session rotation fails' => sub {
  local %ENV = %ENV;
  $ENV{HTTPS} = 'on';
  $ENV{REQUEST_SCHEME} = 'https';
  $ENV{SERVER_PORT} = 443;
  $ENV{REQUEST_METHOD} = 'POST';

  my $auth = BoundaryAuth->new(
    change_result => { ok => 1, account => { username => 'river-editor' } },
    create_session_error => "injected session creation failure\n",
  );
  my $orbit = boundary_orbit(
    auth => $auth, user => 'river-editor', role => 'editor',
    session => { csrf_secret => ('c' x 43) }, session_token => ('s' x 43),
    session_cookie_name => '__Host-el_sid',
    cgi => BoundaryCGI->new(params => {
      csrf_token => ('c' x 43),
      current_passphrase => 'current passphrase value',
      new_passphrase => 'new passphrase value',
      confirm_passphrase => 'new passphrase value',
    }),
  );
  is($orbit->HandlePasswordChange(), 'error', 'session issuance failure is reported after the committed change');
  is($auth->{create_session_calls}, 1, 'replacement session creation is attempted once');
  is(scalar @{$orbit->{_ResponseCookies}}, 1, 'stale revoked session cookie is queued for expiration');
  like($orbit->{_ResponseCookies}[0], qr/^__Host-el_sid=; .*Max-Age=0;.*Secure$/,
    'queued cookie expiration retains the production cookie attributes');
  is_deeply(
    $orbit->{_LastAuthError},
    [500, 'The passphrase changed, but a new session could not be created. Please log on again.'],
    'browser message truthfully states that the credential commit succeeded',
  );
};

subtest 'failed session restoration does not create a logout primitive' => sub {
  local %ENV = %ENV;
  $ENV{HTTPS} = 'on';
  $ENV{REQUEST_SCHEME} = 'https';
  $ENV{SERVER_PORT} = 443;
  my $auth = BoundaryAuth->new(restore_result => { ok => 0, reason => 'expired' });
  my $orbit = boundary_orbit(
    auth => $auth,
    cgi => BoundaryCGI->new(cookies => { '__Host-el_sid' => ('s' x 43) }),
  );
  ok(!$orbit->RestoreSession(), 'expired session is not restored');
  is_deeply($orbit->{_ResponseCookies}, [], 'unauthenticated restore failure does not expire the cookie');
};

subtest 'Orbit 7 caps CGI bodies before object construction' => sub {
  is($CGI::POST_MAX, 10 * 1024 * 1024, 'shared Orbit 7 POST limit is 10 MiB');
  ok(!$CGI::DISABLE_UPLOADS, 'general Orbit routes retain file-upload support');

  local %ENV = (
    REQUEST_METHOD => 'POST',
    CONTENT_TYPE   => 'application/x-www-form-urlencoded',
    CONTENT_LENGTH => (10 * 1024 * 1024) + 1,
  );
  open(my $empty_stdin, '<', \my $empty) or die "open scalar stdin: $!";
  local *STDIN = $empty_stdin;
  my $cgi = CGI->new();
  like($cgi->cgi_error() // '', qr/^413\b/, 'oversized POST is rejected by CGI at construction');
  my @params = $cgi->param();
  is(scalar(@params), 0, 'oversized request parameters are never parsed');

  for my $script (qw(ellogon.pl ellogoff.pl elpasswd.pl)) {
    open(my $script_fh, '<:raw', "bin/cgi/$script")
      or die "open bin/cgi/$script: $!";
    local $/;
    my $source = <$script_fh>;
    close($script_fh) or die "close bin/cgi/$script: $!";
    like(
      $source,
      qr/\$CGI::POST_MAX\s*=\s*64\s*\*\s*1024\s*;.*
         \$CGI::DISABLE_UPLOADS\s*=\s*1\s*;.*Orbit->new\(\)/sx,
      "$script lowers the cap and disables uploads before constructing CGI",
    );
  }
};

done_testing;

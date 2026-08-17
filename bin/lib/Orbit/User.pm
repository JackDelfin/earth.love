#!/usr/bin/perl
# Version 7.0.0.0      01-Jul-2021
#*****************************************************************************************
#*
#*  Package Name    :   Orbit::User
#*
#*  Description     :   Implements Utility Functions within Orbit
#*
#*****************************************************************************************
# History:
#   2021.06.16 earth.love oK Refactored
#*****************************************************************************************
# Copyright 2021 Kevin Runner / Runchero Federation / PISA
#*******************************************************************************
# License: AGPLv3+: GNU Affero General Public License Version 3 or later
#*******************************************************************************
# This file is part of Orbit for Perl.
#
# Orbit for Perl is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Orbit for Perl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Orbit for Perl.  If not, see <https://www.gnu.org/licenses/>.
#*****************************************************************************************
# Functions Supported
#*****************************************
#
# Logon
#   - Validates the user/password and creates a User Access Log (session) record
#
# Logoff
#   - Logs a user out of their session (sets a flag on the user access log)
#   - If next page is not specified, the LOGON_PAGE will be displayed
#
# Change_Password
#   - Change a users password based on session stored in a cookie
#
# LoadAccessGroups
#   - Loads all Access Groups for a user into tokens named SEC_<access_group_code>
#
# HasAccess $Root, $Object, $Page, $Action, $Word
#   - Returns 1 if the current user has access to the data specified
#   - Returns 0 if the user is specifically denied access, but not personally
#   - Returns 2 if the user has VIEW ONLY access to the page
#
# GetUser
#   - Returns the User name - Set Externally
#
# SetUser $User, $UserDir
#   - Sets the internal User and UserDir variables (called internally)
#
# GetUserDir
#   - Returns the User directory location - Set Externally
#
# SetUserDir $UserDir
#   - Sets the internal UserDir to that specified - Set Externally
#   - Used for access to ACCESS.dat and other user settings
#
# GetLanguage
#   - Returns the User Language value
#
# SetLanguage $Lang
#   - Sets the User Language value - affects the #MSG[]# call
#
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';

use Orbit::Auth;


#******************************************************************************************
#* Logon
#*
#* - Validates the user/password and creates a User Access Log (session) record
#******************************************************************************************
sub Orbit::Logon { return shift->HandleLogon(@_); }


#******************************************************************************************
#* Logoff
#*
#* - Logs a user out of their session (sets a flag on the user access log)
#* - If next page is not specified, the LOGON_PAGE will be displayed
#******************************************************************************************
sub Orbit::Logoff { return shift->HandleLogoff(@_); }


#******************************************************************************************
#* Change_Password
#*
#* - Change a users password based on session stored in a cookie
#******************************************************************************************
sub Orbit::Change_Password { return shift->HandlePasswordChange(@_); }


#******************************************************************************************
# InitializeAuth / RestoreSession
#
# Build the per-domain authentication service and restore an opaque session before any
# CGI mutation handler is allowed to run.  Authentication failure never breaks public
# read-only pages; all writes still fail closed through AuthorizeMutationRequest.
#******************************************************************************************
sub Orbit::InitializeAuth
{
  my ( $self ) = @_;

  $self->{_Auth} = undef;
  $self->{_Session} = undef;
  $self->{_SessionToken} = '';
  $self->{_Role} = 'anonymous';
  $self->{_MustChange} = 0;
  $self->{_AuthError} = '';

  $self->_SetAnonymousAuthTokens();

  my $domain_dir = $self->{_DomainDir};
  return 0 if (!defined($domain_dir) || $domain_dir eq '' || !-d $domain_dir);

  my $auth;
  my $ok = eval {
    $auth = Orbit::Auth->new(domain_dir => $domain_dir);
    1;
  };
  if (!$ok || !defined($auth)) {
    $self->{_AuthError} = $@ || 'Authentication service could not be initialized';
    return 0;
  }

  $self->{_Auth} = $auth;
  $self->RestoreSession();
  return 1;
} #InitializeAuth


sub Orbit::RestoreSession
{
  my ( $self ) = @_;
  my $auth = $self->{_Auth};
  return 0 if (!defined($auth));

  my ($token, $cookie_name) = $self->_SessionCookieValue();
  return 0 if ($token eq '');
  $self->{_SessionCookieName} = $cookie_name;

  my $result;
  my $ok = eval {
    $result = $auth->restore_session(
      $token,
      ip         => ($ENV{'REMOTE_ADDR'} // ''),
      user_agent => ($ENV{'HTTP_USER_AGENT'} // ''),
    );
    1;
  };
  if (!$ok || ref($result) ne 'HASH' || !$result->{'ok'}) {
    $self->{_AuthError} = $@ if (!$ok);
    # Do not clear a bearer cookie in response to an unauthenticated request.
    # In particular, a cross-site POST to logoff must not be able to expire the
    # browser's cookie.  A later successful login overwrites stale cookies.
    return 0;
  }

  my $session = $result->{'session'} || {};
  my $account = $result->{'account'} || {};
  my $user = $account->{'username'} // $session->{'username'} // '';
  my $role = $account->{'role'} // 'viewer';
  return 0 if ($user eq '');

  $self->{_Session} = $session;
  $self->{_SessionToken} = $token;
  $self->{_SessionCookieName} = $cookie_name;
  $self->{_User} = $user;
  $self->{_Role} = $role;
  $self->{_MustChange} = $account->{'must_change'} ? 1 : 0;
  $self->{_UserDir} = $self->{_DomainDir}.'_ORBIT/_AUTH/USERS/';
  $self->{_ResponseNoStore} = 1;

  $self->Set_Token('AUTHENTICATED', '1');
  $self->Set_Token('AUTH_USER', $user);
  $self->Set_Token('AUTH_ROLE', $role);
  $self->Set_Token('CSRF_TOKEN', $session->{'csrf_token'} // '');
  $self->Set_Token('AUTH_MUST_CHANGE', $self->{_MustChange} ? '1' : '0');
  $self->Set_Token(
    'AUTH_CAN_WRITE',
    (!$self->{_MustChange} && ($role eq 'editor' || $role eq 'admin')) ? '1' : '0'
  );
  return 1;
} #RestoreSession


sub Orbit::_SetAnonymousAuthTokens
{
  my ( $self ) = @_;
  $self->{_User} = '';
  $self->{_MustChange} = 0;
  $self->Set_Token('AUTHENTICATED', '0');
  $self->Set_Token('AUTH_USER', '');
  $self->Set_Token('AUTH_ROLE', 'anonymous');
  $self->Set_Token('CSRF_TOKEN', '');
  $self->Set_Token('LOGIN_CSRF_TOKEN', '');
  $self->Set_Token('AUTH_MUST_CHANGE', '0');
  $self->Set_Token('AUTH_CAN_WRITE', '0');

  my $return_to = $self->_ValidateReturnTo($ENV{'REQUEST_URI'} // '');
  $self->SetUntrustedToken('RETURN_TO', $return_to);
  return 1;
} #_SetAnonymousAuthTokens


#******************************************************************************************
# Auth request handlers.  These read passphrases directly from CGI parameters; passphrases
# are deliberately never copied into Orbit tokens or generic formfields.
#******************************************************************************************
sub Orbit::HandleLogon
{
  my ( $self ) = @_;
  $self->{_ResponseNoStore} = 1;

  return $self->_RenderAuthError(403, 'HTTPS is required for logon.')
    if (!$self->_AuthTransportAllowed());

  my $method = uc($ENV{'REQUEST_METHOD'} // 'GET');
  my $return_to = $self->_ValidateReturnTo(scalar $self->{_cgi}->param('return_to'));
  $self->SetUntrustedToken('RETURN_TO', $return_to);

  if ($method eq 'GET') {
    return $self->_EmitRedirect($return_to) if ($self->{_User} ne '');
    return $self->_RenderAuthError(500, 'Logon could not create a secure request token.')
      if (!$self->_PrepareLoginCSRF());
    return $self->_ShowAuthTemplate('EL_LOGON');
  }
  return $self->_RenderAuthError(405, 'This request method is not allowed.')
    if ($method ne 'POST');
  return $self->_RenderAuthCGIError()
    if ($self->{_cgi}->can('cgi_error') && ($self->{_cgi}->cgi_error() // '') ne '');

  my $login_csrf = $self->{_cgi}->param('login_csrf_token');
  $login_csrf = '' if (!defined($login_csrf));
  if (!$self->_VerifyLoginCSRF($login_csrf)) {
    eval {
      $self->{_Auth}->audit(
        event => 'auth.login', result => 'denied', reason => 'login_csrf',
        ip => ($ENV{'REMOTE_ADDR'} // ''),
        user_agent => ($ENV{'HTTP_USER_AGENT'} // ''),
      ) if defined($self->{_Auth});
    };
    return $self->_RenderAuthError(403, 'The security token is invalid or expired.');
  }

  my $username = $self->{_cgi}->param('username');
  my $passphrase = $self->{_cgi}->param('passphrase');
  $username = '' if (!defined($username));
  $passphrase = '' if (!defined($passphrase));
  $username =~ tr/A-Z/a-z/;

  my $auth = $self->{_Auth};
  my $result;
  my $ok = defined($auth) && eval {
    $result = $auth->authenticate(
      $username,
      $passphrase,
      ip         => ($ENV{'REMOTE_ADDR'} // ''),
      user_agent => ($ENV{'HTTP_USER_AGENT'} // ''),
    );
    1;
  };

  # Do not reveal whether the user exists, is disabled, or is being throttled.
  if (!$ok || ref($result) ne 'HASH' || !$result->{'ok'}) {
    $self->{_AuthError} = $@ if (!$ok);
    $self->RegisterError('Logon failed. Check your username and passphrase and try again.');
    return $self->_RenderAuthError(500, 'Logon could not create a secure request token.')
      if (!$self->_PrepareLoginCSRF());
    return $self->_ShowAuthTemplate('EL_LOGON');
  }

  my $token = $result->{'token'} // '';
  return $self->_RenderAuthError(500, 'Logon could not create a secure session.')
    if ($token eq '');

  my $must_change = $result->{'account'} && $result->{'account'}->{'must_change'};
  $return_to = '/o/elpasswd' if ($must_change);
  return $self->_EmitRedirect(
    $return_to,
    [ $self->_NewSessionCookie($token), $self->_ExpiredLoginCSRFCookie() ],
  );
} #HandleLogon


sub Orbit::HandleLogoff
{
  my ( $self ) = @_;
  $self->{_ResponseNoStore} = 1;

  my $method = uc($ENV{'REQUEST_METHOD'} // 'GET');
  return $self->_RenderAuthError(405, 'Logoff requires a POST request.')
    if ($method ne 'POST');
  return $self->_RenderAuthCGIError()
    if ($self->{_cgi}->can('cgi_error') && ($self->{_cgi}->cgi_error() // '') ne '');

  my $return_to = $self->_ValidateReturnTo(scalar $self->{_cgi}->param('return_to'));
  my $csrf = $self->{_cgi}->param('csrf_token');
  $csrf = '' if (!defined($csrf));

  # Never emit an expiration cookie for an unauthenticated or forged request.
  # This prevents cross-site logout and makes cookie removal contingent on a
  # live server session plus its matching CSRF secret.
  return $self->_RenderAuthError(401, 'Please log on before logging off.')
    if (!defined($self->{_Session}) || ($self->{_User} // '') eq ''
      || !defined($self->{_Auth}) || ($self->{_SessionToken} // '') eq '');
  return $self->_RenderAuthError(403, 'The security token is invalid or expired.')
    if (!$self->_VerifyCSRF($csrf));

  my $revoked;
  my $revoke_ok = eval {
    $revoked = $self->{_Auth}->revoke_session($self->{_SessionToken});
    1;
  };
  return $self->_RenderAuthError(500, 'Logoff could not revoke the server session.')
    if (!$revoke_ok || !$revoked);
  eval {
    $self->{_Auth}->audit(
      event  => 'auth.logout', result => 'success', username => $self->{_User},
      ip     => ($ENV{'REMOTE_ADDR'} // ''),
      user_agent => ($ENV{'HTTP_USER_AGENT'} // ''),
    );
  };

  return $self->_EmitRedirect($return_to, $self->_ExpiredSessionCookie());
} #HandleLogoff


sub Orbit::HandlePasswordChange
{
  my ( $self ) = @_;
  $self->{_ResponseNoStore} = 1;

  return $self->_RenderAuthError(403, 'HTTPS is required to change a passphrase.')
    if (!$self->_AuthTransportAllowed());
  return $self->_RenderAuthError(401, 'Please log on before changing your passphrase.')
    if ($self->{_User} eq '' || !defined($self->{_Session}));

  my $method = uc($ENV{'REQUEST_METHOD'} // 'GET');
  my $return_to = $self->_ValidateReturnTo(scalar $self->{_cgi}->param('return_to'));
  $self->SetUntrustedToken('RETURN_TO', $return_to);
  return $self->_ShowAuthTemplate('EL_CHANGE_PASSPHRASE') if ($method eq 'GET');
  return $self->_RenderAuthError(405, 'This request method is not allowed.')
    if ($method ne 'POST');
  return $self->_RenderAuthCGIError()
    if ($self->{_cgi}->can('cgi_error') && ($self->{_cgi}->cgi_error() // '') ne '');

  my $csrf = $self->{_cgi}->param('csrf_token');
  $csrf = '' if (!defined($csrf));
  return $self->_RenderAuthError(403, 'The security token is invalid or expired.')
    if (!$self->_VerifyCSRF($csrf));

  my $current = $self->{_cgi}->param('current_passphrase');
  my $new = $self->{_cgi}->param('new_passphrase');
  my $confirm = $self->{_cgi}->param('confirm_passphrase');
  $current = '' if (!defined($current));
  $new = '' if (!defined($new));
  $confirm = '' if (!defined($confirm));

  if ($new ne $confirm) {
    $self->RegisterError('The new passphrases do not match.');
    return $self->_ShowAuthTemplate('EL_CHANGE_PASSPHRASE');
  }

  my $changed;
  my $ok = eval {
    $changed = $self->{_Auth}->change_passphrase(
      $self->{_User}, $current, $new,
      ip         => ($ENV{'REMOTE_ADDR'} // ''),
      user_agent => ($ENV{'HTTP_USER_AGENT'} // ''),
    );
    1;
  };
  if (!$ok || ref($changed) ne 'HASH' || !$changed->{'ok'}) {
    $self->{_AuthError} = $@ if (!$ok);
    $self->RegisterError(
      ref($changed) eq 'HASH' && ($changed->{'error'} // '') eq 'throttled'
        ? 'Too many passphrase attempts. Try again later.'
        : ref($changed) eq 'HASH' && ($changed->{'error'} // '') eq 'passphrase_reuse'
          ? 'The new passphrase must differ from the current passphrase.'
        : 'The passphrase could not be changed.'
    );
    return $self->_ShowAuthTemplate('EL_CHANGE_PASSPHRASE');
  }

  # Password changes revoke old sessions.  Issue a fresh, rotated session to this browser.
  my $session;
  $ok = eval {
    $session = $self->{_Auth}->create_session(
      $self->{_User},
      ip         => ($ENV{'REMOTE_ADDR'} // ''),
      user_agent => ($ENV{'HTTP_USER_AGENT'} // ''),
    );
    1;
  };
  if (!$ok || ref($session) ne 'HASH' || !$session->{'token'}) {
    # The old session was revoked as part of the committed credential change.
    # Expire its browser cookie even when issuing the replacement session fails.
    push @{$self->{_ResponseCookies}}, $self->_ExpiredSessionCookie();
    return $self->_RenderAuthError(500,
      'The passphrase changed, but a new session could not be created. Please log on again.');
  }

  return $self->_EmitRedirect($return_to, $self->_NewSessionCookie($session->{'token'}));
} #HandlePasswordChange


#******************************************************************************************
# Central v1 authorization policy
#******************************************************************************************
sub Orbit::AuthorizeAction
{
  my ( $self, $action, %context ) = @_;
  $action = '' if (!defined($action));
  my $root = $context{'root'} // '';
  my $role = $self->{_Role} // 'anonymous';

  return 1 if ($action eq 'account.self' && $role ne 'anonymous');
  return 0 if ($self->{_MustChange});
  return 0 if ($self->{_InvalidRootInput} || $self->{_InvalidRequestInput}
    || $self->{_InvalidFormFieldsInput});
  return 1 if ($action eq 'account.admin' && $role eq 'admin');
  return 0 if (!$self->_ValidPublicRoot($root));
  return 1 if ($action eq 'content.read');
  return 1 if ($action eq 'content.write' && ($role eq 'editor' || $role eq 'admin'));
  return 1 if ($action eq 'system.write' && $role eq 'admin');
  return 0;
} #AuthorizeAction


# Returns (route_allowed, process_mutation).  Authenticated editors may view a mutation
# form with GET, but only POST plus a valid CSRF token can reach storage code.
sub Orbit::AuthorizeMutationRequest
{
  my ( $self, $root, $operation ) = @_;
  $operation = 'write' if (!defined($operation) || $operation eq '');
  my $method = uc($ENV{'REQUEST_METHOD'} // 'GET');
  $self->{_MutationTemplateAllowed} = '';
  my %operation_template = (
    create          => 'EL_NEW',
    'system.create' => 'EL_NEW',
    add             => 'EL_ADD',
    edit            => 'EL_EDIT',
    delete          => 'EL_DEL',
  );
  my $mutation_template = $operation_template{$operation} // '';

  # CGI.pm refuses oversized or malformed bodies before exposing parameters.
  # Preserve that failure instead of turning it into a misleading role/CSRF
  # denial after the request body has already been discarded.
  if ($self->{_cgi}->can('cgi_error')) {
    my $cgi_error = $self->{_cgi}->cgi_error() // '';
    if ($cgi_error ne '') {
      my $too_large = $cgi_error =~ /\A413\b/ ? 1 : 0;
      $self->{_ResponseStatus} = $too_large
        ? '413 Content Too Large'
        : '400 Bad Request';
      $self->RegisterError($too_large
        ? 'The request is too large.'
        : 'The request is malformed.');
      $self->_AuditAuthorizationFailure($operation, $root,
        $too_large ? 'request_too_large' : 'malformed_request');
      return (0, 0);
    }
  }

  my $policy_action = ($operation =~ /^system\./) ? 'system.write' : 'content.write';
  if (!$self->AuthorizeAction($policy_action, root => $root)) {
    $self->{_ResponseStatus} = ($self->{_User} eq '') ? '401 Unauthorized' : '403 Forbidden';
    $self->RegisterError('You are not authorized to change this content.');
    $self->_AuditAuthorizationFailure($operation, $root, 'role_or_root');
    return (0, 0);
  }

  if ($method eq 'GET') {
    $self->{_MutationTemplateAllowed} = $mutation_template;
    return (1, 0);
  }
  if ($method ne 'POST') {
    $self->{_ResponseStatus} = '405 Method Not Allowed';
    $self->RegisterError('This request method is not allowed.');
    $self->_AuditAuthorizationFailure($operation, $root, 'method');
    return (0, 0);
  }

  my $csrf = $self->{_cgi}->param('csrf_token');
  $csrf = '' if (!defined($csrf));
  if (!$self->_VerifyCSRF($csrf)) {
    $self->{_ResponseStatus} = '403 Forbidden';
    $self->RegisterError('The security token is invalid or expired.');
    $self->_AuditAuthorizationFailure($operation, $root, 'csrf');
    return (0, 0);
  }

  # Editor input is content, never trusted OML or HTML.  The legacy renderer uses
  # several stored fields in markup contexts, so reject the syntax that could turn
  # an editor into an administrator through stored script/template injection.
  if (($self->{_Role} // '') eq 'editor' && !$self->_ValidateEditorMutationPayload()) {
    $self->{_ResponseStatus} = '400 Bad Request';
    $self->RegisterError('Content may not contain executable markup or template syntax.');
    $self->_AuditAuthorizationFailure($operation, $root, 'unsafe_payload');
    return (0, 0);
  }

  $self->{_MutationTemplateAllowed} = $mutation_template;
  return (1, 1);
} #AuthorizeMutationRequest


# Only these templates are executable web entry points.  Domain/root templates
# remain available as includes beneath EL_SHOW; accepting every helper as a
# top-level page would let formfields populate presentation tokens that helpers
# intentionally render as trusted markup.
sub Orbit::_WebTemplateAllowed
{
  my ( $self, $template ) = @_;
  return 0 if (!defined($template) || $template !~ /\A[A-Za-z][A-Za-z0-9_]{0,127}\z/);
  return 1 if ($self->{_bCommandLine} || $self->{_bBatchMode});

  my $name = uc($template);
  return 1 if ($name eq 'DEFAULT' || $name eq 'EL_SHOW' || $name eq 'EL_STYLE');
  return 1 if (($self->{_MutationTemplateAllowed} // '') eq $name);
  return 1 if ($self->{_AuthTemplateAllowed}
    && $name =~ /\A(?:EL_LOGON|EL_CHANGE_PASSPHRASE)\z/
    && $self->_AuthTransportAllowed());
  return 0;
} #_WebTemplateAllowed


sub Orbit::_ValidateEditorMutationPayload
{
  my ( $self ) = @_;
  return 0 if (!defined($self->{_cgi}));

  my @names = $self->{_cgi}->param();
  return 0 if (@names > 64);
  my $total = 0;
  foreach my $name (@names) {
    return 0 if (!defined($name) || $name !~ /\A[A-Za-z_][A-Za-z0-9_]{0,63}\z/);
    my @values = $self->{_cgi}->can('multi_param')
      ? $self->{_cgi}->multi_param($name)
      : (scalar $self->{_cgi}->param($name));
    return 0 if (@values > 16);
    foreach my $value (@values) {
      next if (!defined($value));
      return 0 if (ref($value));
      $total += length($value);
      return 0 if (length($value) > 131_072 || $total > 524_288);
      return 0 if ($value =~ /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/);
      return 0 if ($value =~ /[\#<>\"]|`/);
    }
  }
  return 1;
} #_ValidateEditorMutationPayload


sub Orbit::_VerifyCSRF
{
  my ( $self, $token ) = @_;
  return 0 if (!defined($self->{_Auth}) || !defined($self->{_Session}));
  my $valid = eval { $self->{_Auth}->verify_csrf($self->{_Session}, $token) };
  return $valid ? 1 : 0;
} #_VerifyCSRF


sub Orbit::_ValidPublicRoot
{
  my ( $self, $root ) = @_;
  return 0 if (!defined($root) || $root eq '');
  return 0 if (length($root) > 160 || $root =~ /[\\\x00-\x1f\x7f]/ || $root =~ /\.\./);
  my $canonical = uc($root);
  $canonical =~ s{\.}{/}g;
  return 0 if ($canonical =~ m{(?:^|/)_});
  return $canonical =~ m{\A[A-Z0-9-]+(?:/[A-Z0-9-]+)*\z} ? 1 : 0;
} #_ValidPublicRoot


sub Orbit::_AuditAuthorizationFailure
{
  my ( $self, $operation, $root, $reason ) = @_;
  return if (!defined($self->{_Auth}));
  eval {
    $self->{_Auth}->audit(
      event => 'auth.authorization', result => 'denied', username => ($self->{_User} // ''),
      ip => ($ENV{'REMOTE_ADDR'} // ''), user_agent => ($ENV{'HTTP_USER_AGENT'} // ''),
      reason => $reason, action => $operation, root => $root,
    );
  };
  return;
} #_AuditAuthorizationFailure


#******************************************************************************************
# HTTP/cookie helpers
#******************************************************************************************
sub Orbit::_AuthTransportAllowed
{
  my ( $self ) = @_;
  return 1 if (($ENV{'HTTPS'} // '') =~ /^(?:on|1)$/i);
  return 1 if (($ENV{'REQUEST_SCHEME'} // '') eq 'https');
  return 1 if (($ENV{'SERVER_PORT'} // '') eq '443');

  return 0 if (($ENV{'EL_AUTH_ALLOW_INSECURE_LOOPBACK'} // '') ne '1');
  my $remote = $ENV{'REMOTE_ADDR'} // '';
  my $host = $ENV{'HTTP_HOST'} // '';
  return 0 if ($remote !~ /^(?:127(?:\.\d{1,3}){3}|::1)$/);
  return $host =~ /^(?:localhost|127(?:\.\d{1,3}){3}|\[::1\])(?::\d+)?$/i ? 1 : 0;
} #_AuthTransportAllowed


sub Orbit::_SessionCookieValue
{
  my ( $self ) = @_;
  my @names = $self->_IsHTTPS()
    ? ('__Host-el_sid')
    : ($self->_AuthTransportAllowed() ? ('el_dev_sid') : ());
  foreach my $name (@names) {
    my $value = $self->{_cgi}->cookie($name);
    next if (!defined($value) || $value !~ /^[A-Za-z0-9_-]{43}$/);
    return ($value, $name);
  }
  return ('', '');
} #_SessionCookieValue


sub Orbit::_PrepareLoginCSRF
{
  my ( $self ) = @_;
  return 0 if (!defined($self->{_Auth}));

  my $nonce;
  my $ok = eval {
    $nonce = $self->{_Auth}->issue_login_nonce();
    1;
  };
  if (!$ok || !defined($nonce) || $nonce !~ /\A[A-Za-z0-9_-]{43}\z/) {
    $self->{_AuthError} = $@ if (!$ok);
    return 0;
  }

  $self->Set_Token('LOGIN_CSRF_TOKEN', $nonce);
  $self->{_ResponseCookies} = []
    if (ref($self->{_ResponseCookies}) ne 'ARRAY');
  push @{$self->{_ResponseCookies}}, $self->_NewLoginCSRFCookie($nonce);
  return 1;
} #_PrepareLoginCSRF


sub Orbit::_VerifyLoginCSRF
{
  my ( $self, $candidate ) = @_;
  return 0 if (!defined($self->{_Auth}));

  my $name = $self->_LoginCSRFCookieName();
  return 0 if ($name eq '');
  my $cookie = $self->{_cgi}->cookie($name);
  $cookie = '' if (!defined($cookie));
  my $valid = eval { $self->{_Auth}->verify_login_nonce($cookie, $candidate) };
  return $valid ? 1 : 0;
} #_VerifyLoginCSRF


sub Orbit::_LoginCSRFCookieName
{
  my ( $self ) = @_;
  return '__Host-el_login_csrf' if ($self->_IsHTTPS());
  return 'el_dev_login_csrf' if ($self->_AuthTransportAllowed());
  return '';
} #_LoginCSRFCookieName


sub Orbit::_NewLoginCSRFCookie
{
  my ( $self, $nonce ) = @_;
  return '' if (!defined($nonce) || $nonce !~ /\A[A-Za-z0-9_-]{43}\z/);
  my $name = $self->_LoginCSRFCookieName();
  return '' if ($name eq '');
  my $cookie = $name.'='.$nonce
    .'; Path=/; HttpOnly; SameSite=Strict; Max-Age=600';
  $cookie .= '; Secure' if ($name eq '__Host-el_login_csrf');
  return $cookie;
} #_NewLoginCSRFCookie


sub Orbit::_ExpiredLoginCSRFCookie
{
  my ( $self ) = @_;
  my $name = $self->_LoginCSRFCookieName();
  return '' if ($name eq '');
  my $cookie = $name
    .'=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT';
  $cookie .= '; Secure' if ($name eq '__Host-el_login_csrf');
  return $cookie;
} #_ExpiredLoginCSRFCookie


sub Orbit::_IsHTTPS
{
  return 1 if (($ENV{'HTTPS'} // '') =~ /^(?:on|1)$/i);
  return 1 if (($ENV{'REQUEST_SCHEME'} // '') eq 'https');
  return (($ENV{'SERVER_PORT'} // '') eq '443') ? 1 : 0;
} #_IsHTTPS


sub Orbit::_NewSessionCookie
{
  my ( $self, $token ) = @_;
  my $secure = $self->_IsHTTPS();
  my $name = $secure ? '__Host-el_sid' : 'el_dev_sid';
  my $cookie = $name.'='.$token.'; Path=/; HttpOnly; SameSite=Lax';
  $cookie .= '; Secure' if ($secure);
  return $cookie;
} #_NewSessionCookie


sub Orbit::_ExpiredSessionCookie
{
  my ( $self ) = @_;
  my $secure = $self->_IsHTTPS();
  my $name = $self->{_SessionCookieName} || ($secure ? '__Host-el_sid' : 'el_dev_sid');
  my $cookie = $name.'=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT';
  $cookie .= '; Secure' if ($secure && $name eq '__Host-el_sid');
  return $cookie;
} #_ExpiredSessionCookie


sub Orbit::_ValidateReturnTo
{
  my ( $self, $path ) = @_;
  $path = '' if (!defined($path));
  return '/o/page' if ($path eq '' || length($path) > 2048);
  return '/o/page' if ($path !~ m{^/} || $path =~ m{^//}
    || $path =~ /[\\\x00-\x1f\x7f]/);
  return '/o/page' if ($path =~ m{(?:^|/)\.\.(?:/|$)});
  return $path;
} #_ValidateReturnTo


sub Orbit::_EmitRedirect
{
  my ( $self, $location, $cookie ) = @_;
  $location = $self->_ValidateReturnTo($location);
  my @args = (
    -status => '303 See Other', -location => $location,
    -type => 'text/html', -charset => 'utf-8',
    -Cache_Control => 'no-store', -Pragma => 'no-cache',
    -Content_Security_Policy => "default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'self'; form-action 'self'; script-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; media-src 'self'; connect-src 'self'",
    -Permissions_Policy => 'camera=(), microphone=(), geolocation=()',
  );
  my $hsts = $self->_HSTSHeaderValue();
  push @args, (-Strict_Transport_Security => $hsts) if ($hsts ne '');
  push @args, (-cookie => $cookie) if (defined($cookie) && $cookie ne '');
  print $self->{_cgi}->header(@args);
  $self->{_HeadersSent} = 1;
  return 1;
} #_EmitRedirect


sub Orbit::_HSTSHeaderValue
{
  my ( $self ) = @_;
  return '' if (!$self->_IsHTTPS());
  my $host = $ENV{'HTTP_HOST'} // '';
  my $remote = $ENV{'REMOTE_ADDR'} // '';
  return '' if ($remote =~ /\A(?:127(?:\.\d{1,3}){3}|::1)\z/
    && $host =~ /\A(?:localhost|127(?:\.\d{1,3}){3}|\[::1\])(?::\d+)?\z/i);
  return 'max-age=31536000';
} #_HSTSHeaderValue


sub Orbit::_RenderAuthError
{
  my ( $self, $status, $message ) = @_;
  my %reason = (
    400 => 'Bad Request', 401 => 'Unauthorized', 403 => 'Forbidden',
    405 => 'Method Not Allowed', 413 => 'Content Too Large',
    500 => 'Internal Server Error',
  );
  $self->{_ResponseStatus} = $status.' '.($reason{$status} || 'Error');
  $self->RegisterError($message);
  return $self->ShowPage('DEFAULT');
} #_RenderAuthError


sub Orbit::_RenderAuthCGIError
{
  my ( $self ) = @_;
  my $error = $self->{_cgi}->cgi_error() // '';
  my $status = $error =~ /\A413\b/ ? 413 : 400;
  my $message = $status == 413
    ? 'The authentication request is too large.'
    : 'The authentication request is malformed.';
  return $self->_RenderAuthError($status, $message);
} #_RenderAuthCGIError


sub Orbit::_ShowAuthTemplate
{
  my ( $self, $template ) = @_;
  local $self->{_AuthTemplateAllowed} = 1;
  return $self->ShowPage($template);
} #_ShowAuthTemplate


#******************************************************************************************
# LoadAccessGroups
#   - Loads all Access Groups for a user into tokens named SEC_<access_group_code>
#******************************************************************************************
sub Orbit::LoadAccessGroups
{
  my ( $self ) = @_;

  return "CODE";
} #LoadAccessGroups


#******************************************************************************************
# HasAccess $Root, $Object, $Page, $Action, $Word
#   - Returns 1 if the current user has access to the data specified
#   - Returns 0 if the user is specifically denied access, but not personally
#   - Returns 2 if the user has VIEW ONLY access to the page
#******************************************************************************************
sub Orbit::HasAccess
{
  my ( $self, $Root, $Object, $Page, $Action, $Word ) = @_;
  $Root = '' if (!defined($Root));
  $Action = '' if (!defined($Action));

  # ACCESS.dat is deliberately reserved for a later ACL version.  V1 uses a fixed,
  # auditable role matrix and denies unknown/protected targets by default.
  my $policy_action = ($Action =~ /^(?:ADD|CREATE|NEW|EDIT|UPDATE|DELETE|DEL|SAVE|WRITE)$/i)
    ? 'content.write'
    : 'content.read';
  return $self->AuthorizeAction($policy_action, root => $Root) ? 1 : 0;
} #HasAccess


#******************************************************************************************
# GetUser
#   - Returns the User name - Set Externally
#******************************************************************************************
sub Orbit::GetUser
{
  my ( $self ) = @_;
  return $self->{_User};
} #GetUser


#******************************************************************************************
# SetUser $User, $UserDir
#   - Sets the internal User and UserDir variables (called internally)
#******************************************************************************************
sub Orbit::SetUser
{
  my ( $self, $User, $UserDir ) = @_;

  $User    = ""                       if (!defined($User));
  # Authentication users are direct, private directories rather than generic Akashic Words.
  $UserDir = $self->{_DomainDir}.'_ORBIT/_AUTH/USERS/'
    if (!defined($UserDir) || $UserDir eq "" || $UserDir eq '.');

  # Make sure User exists
  if ($User eq "") {
    $self->Uprint("SetUser: Error: No User. User Directory: [$UserDir]\n");
    return 1;
  }

  # Make sure User exists
  if (!-d $UserDir) {
    $self->Uprint("SetUser: Error: User Directory does not exist: [$UserDir]\n");
    return 1;
  }
  
  # Reset User and UserDir - this is where ACCESS.dat is stored, among other settings
  $self->{_User} = $User;
  $self->{_UserDir} = $UserDir;
  return 0;   # Successful
} #SetUser


#******************************************************************************************
# GetUserDir
#   - Returns the User directory location - Set Externally
#******************************************************************************************
sub Orbit::GetUserDir
{
  my ( $self ) = @_;
  return $self->{_UserDir};
} #GetUserDir


#******************************************************************************************
# SetUserDir $UserDir
#   - Sets the internal UserDir to that specified - Set Externally
#   - Used for access to ACCESS.dat and other user settings
#******************************************************************************************
sub Orbit::SetUserDir
{
  my ( $self, $UserDir ) = @_;
  
  # Make sure UserDir exists
  if (!-d $UserDir) {
    $self->Uprint("SetUserDir: Error: User Directory does not exist: [$UserDir]\n");
    return 1;
  }
  
  # Reset UserDir - this is where ACCESS.dat is stored, among other settings
  $self->{_UserDir} = $UserDir;
  return 0;   # Successful
} #SetUserDir


#******************************************************************************************
# GetLanguage
#   - Returns the User Language value
#******************************************************************************************
sub GetLanguage {
  my ( $self ) = @_;
  return $self->{_Lang};
} #GetLanguage


#******************************************************************************************
# SetLanguage $Lang
#   - Sets the User Language value - affects the #MSG[]# call
#******************************************************************************************
sub SetLanguage {
  my ( $self, $Lang ) = @_;
  $Lang =~ tr/[a-z]/[A-Z]/;   # Uppercase Language by convention since it's a subROOT
  $self->{_Lang} = $Lang;
  $self->{_Akashic}->SetVar('Lang', $Lang);   # Set the Akashic Lang since we're connected
  $self->Set_Token('LANG', $Lang);
} #SetLanguage


#========================================================================================
# END USER FUNCTIONS IMPLEMENTATION
#========================================================================================


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::User;
#******************************************************************************************
1;


#END Orbit::User Package

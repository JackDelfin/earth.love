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
use Carp qw(croak);

use Orbit::Auth;
use Orbit::Profile;
use Orbit::Person;


#******************************************************************************************
#* Logon
#*
#* - Validates the user/password and creates a User Access Log (session) record
#******************************************************************************************
sub Orbit::Logon { return shift->HandleLogon(@_); }
sub Orbit::Signup { return shift->HandleSignup(@_); }


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
sub Orbit::Settings { return shift->HandleSettings(@_); }


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
  $self->_PublishSelfSignupPolicy();
  $self->RestoreSession();
  # Word tokens are resolved during UserConfigurations, before Auth exists.
  # Rebuild Person-page tokens now that accounts can be read.
  eval { $self->_PublishPersonPageIfCurrent() };
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
  # Account data is validated by Orbit::Auth, but it is still data rather than
  # executable OML.  Keep the presentation boundary safe if a future or
  # substituted authentication backend returns OML-shaped identity text.
  $self->SetUntrustedToken('AUTH_USER', $user);
  $self->SetUntrustedToken('AUTH_ROLE', $role);
  $self->Set_Token('CSRF_TOKEN', $session->{'csrf_token'} // '');
  $self->Set_Token('AUTH_MUST_CHANGE', $self->{_MustChange} ? '1' : '0');
  $self->Set_Token(
    'AUTH_CAN_WRITE',
    (!$self->{_MustChange} && ($role eq 'editor' || $role eq 'admin')) ? '1' : '0'
  );
  $self->Set_Token(
    'AUTH_IS_ADMIN',
    (!$self->{_MustChange} && $role eq 'admin') ? '1' : '0'
  );
  $self->_PublishAccountMenuTokens();
  return 1;
} #RestoreSession


sub Orbit::_SetAnonymousAuthTokens
{
  my ( $self ) = @_;
  $self->{_User} = '';
  $self->{_MustChange} = 0;
  $self->Set_Token('AUTHENTICATED', '0');
  $self->SetUntrustedToken('AUTH_USER', '');
  $self->SetUntrustedToken('AUTH_ROLE', 'anonymous');
  $self->Set_Token('CSRF_TOKEN', '');
  $self->Set_Token('LOGIN_CSRF_TOKEN', '');
  $self->Set_Token('AUTH_MUST_CHANGE', '0');
  $self->Set_Token('AUTH_CAN_WRITE', '0');
  $self->Set_Token('AUTH_IS_ADMIN', '0');
  $self->Set_Token('AUTH_SELF_SIGNUP', '0');
  $self->Set_Token('AUTH_CAN_CREATE_PERSON', '0');
  $self->Set_Token('AUTH_AVATAR_INITIAL', '');
  $self->SetUntrustedToken('AUTH_AVATAR_URL', '');

  my $return_to = $self->_ValidateReturnTo($ENV{'REQUEST_URI'} // '');
  $self->SetUntrustedToken('RETURN_TO', $return_to);
  return 1;
} #_SetAnonymousAuthTokens


sub Orbit::_PublishSelfSignupPolicy
{
  my ( $self ) = @_;
  my $enabled = 0;
  $enabled = eval { $self->{_Auth}->self_signup_enabled() } ? 1 : 0
    if (defined($self->{_Auth}));
  $self->Set_Token('AUTH_SELF_SIGNUP', $enabled ? '1' : '0');
  return $enabled;
} #_PublishSelfSignupPolicy


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


sub Orbit::HandleSignup
{
  my ( $self ) = @_;
  $self->{_ResponseNoStore} = 1;

  return $self->_RenderAuthError(403, 'HTTPS is required for account creation.')
    if (!$self->_AuthTransportAllowed());

  my $method = uc($ENV{'REQUEST_METHOD'} // 'GET');
  return $self->_EmitRedirect('/o/page')
    if ($method eq 'GET' && ($self->{_User} // '') ne '');

  my $signup_enabled = $self->_PublishSelfSignupPolicy();
  return $self->_RenderAuthError(403, 'Account creation is not available.')
    if (!$signup_enabled);

  if ($method eq 'GET') {
    return $self->_RenderAuthError(500, 'Account creation could not create a secure request token.')
      if (!$self->_PrepareLoginCSRF());
    return $self->_ShowSignupTemplate('EL_SIGNUP');
  }
  return $self->_RenderAuthError(405, 'This request method is not allowed.')
    if ($method ne 'POST');
  return $self->_RenderAuthCGIError()
    if ($self->{_cgi}->can('cgi_error') && ($self->{_cgi}->cgi_error() // '') ne '');
  return $self->_RenderAuthError(403, 'Account creation is not available.')
    if (($self->{_User} // '') ne '');

  my $login_csrf = scalar $self->{_cgi}->param('login_csrf_token');
  $login_csrf = '' if (!defined($login_csrf) || ref($login_csrf));
  if (!$self->_VerifyLoginCSRF($login_csrf)) {
    eval {
      $self->{_Auth}->audit(
        event => 'auth.signup', result => 'denied', reason => 'login_csrf',
        ip => ($ENV{'REMOTE_ADDR'} // ''),
        user_agent => ($ENV{'HTTP_USER_AGENT'} // ''),
      );
    } if (defined($self->{_Auth}));
    return $self->_RenderAuthError(403, 'The security token is invalid or expired.');
  }

  my $admission;
  my $admitted = eval {
    $admission = $self->{_Auth}->admit_self_signup($ENV{'REMOTE_ADDR'} // '');
    1;
  };
  if (!$admitted || ref($admission) ne 'HASH' || !$admission->{allowed}) {
    eval {
      $self->{_Auth}->audit(
        event => 'auth.signup', result => 'throttled', reason => 'rate_limited',
        ip => ($ENV{'REMOTE_ADDR'} // ''),
        user_agent => ($ENV{'HTTP_USER_AGENT'} // ''),
      );
    } if (defined($self->{_Auth}));
    $self->RegisterError('Account creation is temporarily unavailable. Try again later.');
    return $self->_RenderAuthError(500, 'Account creation could not create a secure request token.')
      if (!$self->_PrepareLoginCSRF());
    return $self->_ShowSignupTemplate('EL_SIGNUP');
  }

  my $username = scalar $self->{_cgi}->param('username');
  my $passphrase = scalar $self->{_cgi}->param('passphrase');
  my $confirm = scalar $self->{_cgi}->param('confirm_passphrase');
  $username = '' if (!defined($username) || ref($username));
  $passphrase = '' if (!defined($passphrase) || ref($passphrase));
  $confirm = '' if (!defined($confirm) || ref($confirm));
  $username =~ tr/A-Z/a-z/;

  if ($passphrase ne $confirm
      || !$self->{_Auth}->validate_username($username)
      || !$self->{_Auth}->validate_passphrase($passphrase)) {
    $self->RegisterError('Account creation failed. Check your username and passphrase and try again.');
    return $self->_RenderAuthError(500, 'Account creation could not create a secure request token.')
      if (!$self->_PrepareLoginCSRF());
    return $self->_ShowSignupTemplate('EL_SIGNUP');
  }

  my $account;
  my $created = eval {
    $account = $self->{_Auth}->provision_self_signup($username, $passphrase);
    1;
  };
  if (!$created || ref($account) ne 'HASH') {
    $self->{_AuthError} = $@ if (!$created);
    $self->RegisterError('Account creation failed. Check your username and passphrase and try again.');
    return $self->_RenderAuthError(500, 'Account creation could not create a secure request token.')
      if (!$self->_PrepareLoginCSRF());
    return $self->_ShowSignupTemplate('EL_SIGNUP');
  }

  my $session;
  my $session_created = eval {
    $session = $self->{_Auth}->create_session(
      $username,
      ip => ($ENV{'REMOTE_ADDR'} // ''),
      user_agent => ($ENV{'HTTP_USER_AGENT'} // ''),
    );
    1;
  };
  my $token = ref($session) eq 'HASH' ? ($session->{token} // '') : '';
  if (!$session_created || $token eq '') {
    $self->{_AuthError} = $@ if (!$session_created);
    return $self->_RenderAuthError(
      500, 'The account was created, but a secure session could not be created. Please log on.',
    );
  }

  eval {
    $self->{_Auth}->audit(
      event => 'auth.signup', result => 'success', username => $username,
      ip => ($ENV{'REMOTE_ADDR'} // ''),
      user_agent => ($ENV{'HTTP_USER_AGENT'} // ''),
    );
  };
  return $self->_EmitRedirect(
    '/o/page',
    [ $self->_NewSessionCookie($token), $self->_ExpiredLoginCSRFCookie() ],
  );
} #HandleSignup


sub Orbit::HandleLogoff
{
  my ( $self ) = @_;
  $self->{_ResponseNoStore} = 1;

  return $self->_RenderAuthError(403, 'HTTPS is required for logoff.')
    if (!$self->_AuthTransportAllowed());

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


sub Orbit::HandleProfile
{
  my ( $self ) = @_;
  $self->{_ResponseNoStore} = 1;

  my $method = uc($ENV{'REQUEST_METHOD'} // 'GET');
  return $self->_RenderAuthError(405, 'This request method is not allowed.')
    if ($method ne 'GET');

  my $username = scalar $self->{_cgi}->param('u');
  $username = $self->{_User} if (!defined($username) || $username eq '');
  $username = '' if (!defined($username));
  $username =~ tr/A-Z/a-z/;

  if ($username eq '') {
    return $self->_EmitRedirect('/o/ellogon');
  }

  my $auth = $self->{_Auth};
  my $valid = defined($auth) && $auth->validate_username($username);
  my $account = $valid ? eval { $auth->read_account($username) } : undef;
  if (!$valid || !defined($account) || ($account->{status} // '') eq 'disabled') {
    return $self->_RenderAuthError(404, 'That profile is not available.');
  }

  $self->_AssignProfileTokens($username, $account);
  return $self->_ShowAccountTemplate('EL_PROFILE');
} #HandleProfile


sub Orbit::HandleSettings
{
  my ( $self ) = @_;
  $self->{_ResponseNoStore} = 1;

  return $self->_RenderAuthError(403, 'HTTPS is required to edit account settings.')
    if (!$self->_AuthTransportAllowed());
  return $self->_RenderAuthError(401, 'Please log on before editing settings.')
    if ($self->{_User} eq '' || !defined($self->{_Session}));

  my $method = uc($ENV{'REQUEST_METHOD'} // 'GET');
  my $tab = scalar $self->{_cgi}->param('tab');
  $tab = 'profile' if (!defined($tab) || $tab !~ /\A(?:profile|account)\z/);
  $self->Set_Token('SETTINGS_TAB', $tab);

  if ($method eq 'GET') {
    $self->_AssignProfileTokens($self->{_User});
    return $self->_ShowAccountTemplate('EL_SETTINGS');
  }
  return $self->_RenderAuthError(405, 'This request method is not allowed.')
    if ($method ne 'POST');
  return $self->_RenderAuthCGIError()
    if ($self->{_cgi}->can('cgi_error') && ($self->{_cgi}->cgi_error() // '') ne '');

  my $csrf = scalar $self->{_cgi}->param('csrf_token');
  $csrf = '' if (!defined($csrf));
  return $self->_RenderAuthError(403, 'The security token is invalid or expired.')
    if (!$self->_VerifyCSRF($csrf));

  my $settings_action = scalar $self->{_cgi}->param('settings_action');
  $settings_action = '' if (!defined($settings_action));
  if ($settings_action eq 'link_person' || $settings_action eq 'unlink_person') {
    my $person = ($settings_action eq 'unlink_person')
      ? ''
      : scalar $self->{_cgi}->param('person');
    my $linked = eval { $self->_BindPersonToUser($self->{_User}, $person); 1 };
    if (!$linked) {
      my $error = $@ || 'The person link could not be saved.';
      $error =~ s/\s+at\s+\S+\s+line\s+\d+.*//s;
      $self->RegisterError($error);
    }
    else {
      $self->RegisterSuccess($settings_action eq 'unlink_person'
        ? 'Person unlinked.'
        : 'Person linked to your account.');
    }
    $self->_PublishAccountMenuTokens();
    $self->_AssignProfileTokens($self->{_User});
    return $self->_ShowAccountTemplate('EL_SETTINGS');
  }

  if ($tab ne 'profile') {
    $self->_AssignProfileTokens($self->{_User});
    return $self->_ShowAccountTemplate('EL_SETTINGS');
  }

  my $profile = $self->_ProfileService;
  return $self->_RenderAuthError(500, 'Profile storage is unavailable.')
    if (!defined($profile));

  my $failed = 0;
  my $remove = scalar $self->{_cgi}->param('remove_avatar');
  if (defined($remove) && $remove ne '' && $remove ne '0') {
    my $cleared = eval { $profile->clear_avatar($self->{_User}); 1 };
    if (!$cleared) {
      $self->RegisterError('The profile picture could not be removed.');
      $failed = 1;
    }
  }

  my $person = eval { $self->_AssertPersonLinkable($self->{_User}, scalar $self->{_cgi}->param('person')) };
  if (!defined($person) && $@) {
    my $error = $@ || 'That person cannot be linked.';
    $error =~ s/\s+at\s+\S+\s+line\s+\d+.*//s;
    $self->RegisterError($error);
    $self->_AssignProfileTokens($self->{_User});
    return $self->_ShowAccountTemplate('EL_SETTINGS');
  }

  my $saved;
  my $ok = eval {
    $saved = $profile->write_public(
      $self->{_User},
      bio      => scalar $self->{_cgi}->param('bio'),
      pronouns => scalar $self->{_cgi}->param('pronouns'),
      url      => scalar $self->{_cgi}->param('url'),
      email    => scalar $self->{_cgi}->param('email'),
      person   => $person,
    );
    1;
  };
  if (!$ok || ref($saved) ne 'HASH') {
    my $error = $@ || 'The public profile could not be saved.';
    $error =~ s/\s+at\s+\S+\s+line\s+\d+.*//s;
    $self->RegisterError($error);
    $self->_AssignProfileTokens($self->{_User});
    return $self->_ShowAccountTemplate('EL_SETTINGS');
  }

  eval {
    $self->{_Auth}->update_account($self->{_User}, person => ($saved->{person} // ''));
    1;
  };

  my $upload = $self->{_cgi}->can('upload') ? $self->{_cgi}->upload('avatar') : undef;
  if ($upload) {
    my $fh = $upload;
    binmode($fh);
    my $bytes = do { local $/; <$fh> };
    $bytes = '' if (!defined($bytes));
    if ($bytes ne '') {
      my $avatar_ok = eval { $profile->save_avatar($self->{_User}, $bytes); 1 };
      if (!$avatar_ok) {
        my $error = $@ || 'The profile picture could not be saved.';
        $error =~ s/\s+at\s+\S+\s+line\s+\d+.*//s;
        $self->RegisterError($error);
        $failed = 1;
      }
    }
  }

  $self->RegisterSuccess('Public profile saved.') if (!$failed);
  $self->_PublishAccountMenuTokens();
  $self->_AssignProfileTokens($self->{_User});
  return $self->_ShowAccountTemplate('EL_SETTINGS');
} #HandleSettings


sub Orbit::HandleAdmin
{
  my ( $self ) = @_;
  $self->{_ResponseNoStore} = 1;

  return $self->_RenderAuthError(403, 'HTTPS is required for account administration.')
    if (!$self->_AuthTransportAllowed());
  return $self->_RenderAuthError(401, 'Please log on before using administration.')
    if ($self->{_User} eq '' || !defined($self->{_Session}));
  return $self->_RenderAuthError(403, 'Administrator access is required.')
    if (!$self->AuthorizeAction('account.admin'));

  my $method = uc($ENV{'REQUEST_METHOD'} // 'GET');
  return $self->_PublishAdminPage() if ($method eq 'GET');
  return $self->_RenderAuthError(405, 'This request method is not allowed.')
    if ($method ne 'POST');
  return $self->_RenderAuthCGIError()
    if ($self->{_cgi}->can('cgi_error') && ($self->{_cgi}->cgi_error() // '') ne '');

  my $csrf = scalar $self->{_cgi}->param('csrf_token');
  $csrf = '' if (!defined($csrf));
  return $self->_RenderAuthError(403, 'The security token is invalid or expired.')
    if (!$self->_VerifyCSRF($csrf));

  $self->_DispatchAdminAction();
  return $self->_PublishAdminPage();
} #HandleAdmin


sub Orbit::_DispatchAdminAction
{
  my ( $self ) = @_;
  my $action = scalar $self->{_cgi}->param('admin_action');
  $action = '' if (!defined($action));
  my $username = scalar $self->{_cgi}->param('username');
  $username = '' if (!defined($username));
  $username =~ tr/A-Z/a-z/;

  if ($action eq 'create') {
    return $self->_AdminCreateAccount();
  }
  if ($action eq 'self_signup') {
    return $self->_AdminSetSelfSignup();
  }
  if ($action eq 'link_person') {
    return $self->_AdminLinkPerson($username);
  }

  my $accounts = eval { $self->{_Auth}->list_accounts } || [];
  $accounts = [] if (ref($accounts) ne 'ARRAY');
  if ($action ne 'role' && $action ne 'disable' && $action ne 'enable'
      && $action ne 'revoke' && $action ne 'reset') {
    $self->RegisterError('Unknown administration action.');
    return;
  }
  if (!$self->{_Auth}->validate_username($username)) {
    $self->RegisterError('That user name is not valid.');
    return;
  }
  my $guard = $self->_AdminProtectTarget($username, $action, $accounts);
  if ($guard ne '') {
    $self->RegisterError($guard);
    return;
  }

  my $ok = eval {
    if ($action eq 'role') {
      my $role = scalar $self->{_cgi}->param('role');
      $role = '' if (!defined($role));
      $self->{_Auth}->update_account($username, role => $role);
    }
    elsif ($action eq 'disable') {
      $self->{_Auth}->update_account($username, status => 'disabled');
    }
    elsif ($action eq 'enable') {
      $self->{_Auth}->update_account($username, status => 'active');
    }
    elsif ($action eq 'revoke') {
      $self->{_Auth}->bump_auth_version($username);
      $self->{_Auth}->revoke_all_sessions($username, reason => 'administrator_revoke');
    }
    elsif ($action eq 'reset') {
      $self->_AdminResetPassphrase($username);
    }
    1;
  };
  if (!$ok) {
    my $error = $@ || 'The administration request could not be completed.';
    $error =~ s/\s+at\s+\S+\s+line\s+\d+.*//s;
    $self->RegisterError($error);
    return;
  }

  my %done = (
    role    => "Role updated for $username.",
    disable => "$username is disabled.",
    enable  => "$username is enabled.",
    revoke  => "Sessions revoked for $username.",
    reset   => "Temporary passphrase set for $username. They must change it at next logon.",
  );
  $self->RegisterSuccess($done{$action} || 'Administration change saved.');
  return;
} #_DispatchAdminAction


sub Orbit::_AdminSetSelfSignup
{
  my ( $self ) = @_;
  my $enabled = scalar $self->{_cgi}->param('enabled');
  if (!defined($enabled) || ref($enabled) || $enabled !~ /\A[01]\z/) {
    $self->RegisterError('Choose whether self-signup is enabled or disabled.');
    return;
  }

  my $saved = eval {
    $self->{_Auth}->set_self_signup($enabled);
    $self->{_Auth}->audit(
      event => 'auth.self_signup', result => 'success',
      username => ($self->{_User} // ''),
      ip => ($ENV{'REMOTE_ADDR'} // ''),
      user_agent => ($ENV{'HTTP_USER_AGENT'} // ''),
      action => $enabled ? 'enabled' : 'disabled',
    );
    1;
  };
  if (!$saved) {
    $self->{_AuthError} = $@;
    $self->RegisterError('The self-signup setting could not be saved.');
    return;
  }

  $self->_PublishSelfSignupPolicy();
  $self->RegisterSuccess($enabled
    ? 'Public self-signup is enabled.'
    : 'Public self-signup is disabled.');
  return;
} #_AdminSetSelfSignup


sub Orbit::_AdminCreateAccount
{
  my ( $self ) = @_;
  my $username = scalar $self->{_cgi}->param('username');
  $username = '' if (!defined($username));
  $username =~ tr/A-Z/a-z/;
  my $role = scalar $self->{_cgi}->param('role');
  $role = 'viewer' if (!defined($role) || $role eq '');
  my $passphrase = scalar $self->{_cgi}->param('passphrase');
  my $confirm = scalar $self->{_cgi}->param('confirm_passphrase');
  $passphrase = '' if (!defined($passphrase));
  $confirm = '' if (!defined($confirm));
  my $must_change = scalar $self->{_cgi}->param('must_change');
  $must_change = (defined($must_change) && $must_change ne '' && $must_change ne '0') ? 1 : 0;

  if (!$self->{_Auth}->validate_username($username)) {
    $self->RegisterError('That user name is not valid.');
    return;
  }
  my $person = eval { $self->_AssertPersonLinkable($username, scalar $self->{_cgi}->param('person')) };
  if (!defined($person) && $@) {
    my $error = $@ || 'That person cannot be linked.';
    $error =~ s/\s+at\s+\S+\s+line\s+\d+.*//s;
    $self->RegisterError($error);
    return;
  }
  $person = '' if !defined $person;
  if ($passphrase ne $confirm) {
    $self->RegisterError('The passphrase and confirmation do not match.');
    return;
  }

  my $created = eval {
    $self->{_Auth}->provision_account(
      $username,
      $passphrase,
      role => $role,
      must_change => $must_change,
      ($person ne '' ? (person => $person) : ()),
    );
  };
  if (!$created) {
    my $error = $@ || 'The account could not be created.';
    $error =~ s/\s+at\s+\S+\s+line\s+\d+.*//s;
    $self->RegisterError($error);
    return;
  }
  if ($person ne '') {
    my $linked = eval { $self->_BindPersonToUser($username, $person); 1 };
    if (!$linked) {
      my $error = $@ || 'The account was created, but the person could not be linked.';
      $error =~ s/\s+at\s+\S+\s+line\s+\d+.*//s;
      $self->RegisterError($error);
      $self->RegisterSuccess("Created $username with role $role.");
      return;
    }
  }
  $self->RegisterSuccess($person ne ''
    ? "Created $username with role $role, linked to $person."
    : "Created $username with role $role.");
  return;
} #_AdminCreateAccount


sub Orbit::_AdminLinkPerson
{
  my ( $self, $username ) = @_;
  if (!$self->{_Auth}->validate_username($username)) {
    $self->RegisterError('That user name is not valid.');
    return;
  }
  my $ok = eval {
    $self->_BindPersonToUser($username, scalar $self->{_cgi}->param('person'));
    1;
  };
  if (!$ok) {
    my $error = $@ || 'The person link could not be saved.';
    $error =~ s/\s+at\s+\S+\s+line\s+\d+.*//s;
    $self->RegisterError($error);
    return;
  }
  $self->RegisterSuccess("Linked $username to the selected person.");
  return;
} #_AdminLinkPerson


sub Orbit::_AdminResetPassphrase
{
  my ( $self, $username ) = @_;
  my $passphrase = scalar $self->{_cgi}->param('passphrase');
  my $confirm = scalar $self->{_cgi}->param('confirm_passphrase');
  $passphrase = '' if (!defined($passphrase));
  $confirm = '' if (!defined($confirm));
  die 'The passphrase and confirmation do not match.' if ($passphrase ne $confirm);
  $self->{_Auth}->reset_passphrase($username, $passphrase, must_change => 1);
  return 1;
} #_AdminResetPassphrase


sub Orbit::_AdminProtectTarget
{
  my ( $self, $username, $action, $accounts ) = @_;
  return '' if ($action eq 'create');
  if ($username eq $self->{_User}
      && ($action eq 'disable' || $action eq 'role' || $action eq 'revoke' || $action eq 'reset')) {
    return 'You cannot change, disable, reset, or revoke your own administrator session here.';
  }
  return '' if ($action ne 'disable' && $action ne 'role');

  my @admins = grep {
    ($_->{role} // '') eq 'admin' && ($_->{status} // '') eq 'active'
  } @$accounts;
  my ($target) = grep { ($_->{username} // '') eq $username } @$accounts;
  return '' if (!defined($target));
  return '' if (($target->{role} // '') ne 'admin' || ($target->{status} // '') ne 'active');
  if ($action eq 'disable' && @admins <= 1) {
    return 'The last active administrator cannot be disabled or demoted.';
  }
  if ($action eq 'role') {
    my $role = scalar $self->{_cgi}->param('role');
    $role = '' if (!defined($role));
    return 'The last active administrator cannot be disabled or demoted.'
      if ($role ne 'admin' && @admins <= 1);
  }
  return '';
} #_AdminProtectTarget


sub Orbit::_PublishAdminPage
{
  my ( $self ) = @_;
  $self->_PublishSelfSignupPolicy();
  my $accounts = eval { $self->{_Auth}->list_accounts };
  if (!defined($accounts) || ref($accounts) ne 'ARRAY') {
    $self->RegisterError('Account list is unavailable.');
    $accounts = [];
  }
  $self->SetUntrustedToken('ADMIN_ACCOUNT_TABLE', $self->_AdminAccountTable($accounts));
  my $selected = 'Orbit::Person'->normalize(scalar $self->{_cgi}->param('person'));
  $selected = '' if !defined $selected;
  $self->SetUntrustedToken('ADMIN_PERSON_OPTIONS',
    $self->_PersonSelectOptions($selected, '', $accounts));
  $self->SetUntrustedToken('ADMIN_USER_OPTIONS',
    $self->_UserSelectOptions('', $accounts));
  $self->SetUntrustedToken('ADMIN_CREATE_PERSON_URL',
    $self->_OrbitPrefix().'elnew?r=PERSONS&o=person&p=el_new');
  return $self->_ShowAccountTemplate('EL_ADMIN');
} #_PublishAdminPage


sub Orbit::_AdminAccountTable
{
  my ( $self, $accounts ) = @_;
  my $csrf = $self->_HtmlText($self->Get_Token('CSRF_TOKEN'));
  my $action = $self->_HtmlText($self->_OrbitPrefix().'eladmin');
  my $html = '<table class="w3-table-all w3-small"><thead><tr>'
    .'<th>User</th><th>Role</th><th>Status</th><th>Sessions</th>'
    .'<th>Last logon</th><th>Person</th><th>Actions</th></tr></thead><tbody>';
  if (!@$accounts) {
    $html .= '<tr><td colspan="7">No accounts found.</td></tr>';
  }
  foreach my $account (@$accounts) {
    my $user = $self->_HtmlText($account->{username});
    my $role = $self->_HtmlText($account->{role});
    my $status = $self->_HtmlText($account->{status});
    $status .= ' (must change passphrase)' if ($account->{must_change});
    my $person = $self->_HtmlText($account->{person} // '');
    my $person_label = $person;
    if (($account->{person} // '') ne '') {
      my $lookup = $self->_PersonService;
      if (defined($lookup) && $lookup->exists($account->{person})) {
        $person_label = $self->_HtmlText($lookup->display_name($account->{person}));
      }
    }
    my $sessions = $self->_HtmlText($account->{sessions} // 0);
    my $logon = $self->_HtmlText($self->_FormatAuthTime($account->{last_logon}));
    my $self_row = (($account->{username} // '') eq $self->{_User}) ? 1 : 0;
    $html .= '<tr><td>'.$user.'</td><td>'.$role.'</td><td>'.$status.'</td><td>'
      .$sessions.'</td><td>'.$logon.'</td><td>'.$person_label.'</td><td>';
    if (!$self_row) {
      $html .= '<form action="'.$action.'" method="post" class="w3-margin-bottom">'
        .'<input type="hidden" name="csrf_token" value="'.$csrf.'">'
        .'<input type="hidden" name="admin_action" value="role">'
        .'<input type="hidden" name="username" value="'.$user.'">'
        .'<select name="role">';
      foreach my $option (qw(viewer editor admin)) {
        my $sel = ($option eq ($account->{role} // '')) ? ' selected' : '';
        $html .= '<option value="'.$option.'"'.$sel.'>'.$option.'</option>';
      }
      $html .= '</select> <button type="submit" class="w3-button w3-round">Set role</button></form>';
      if (($account->{status} // '') eq 'disabled') {
        $html .= $self->_AdminActionForm($action, $csrf, $user, 'enable', 'Enable');
      }
      else {
        $html .= $self->_AdminActionForm($action, $csrf, $user, 'disable', 'Disable');
      }
      $html .= $self->_AdminActionForm($action, $csrf, $user, 'revoke', 'Revoke sessions');
    }
    else {
      $html .= '<span class="w3-text-grey">Signed in</span>';
    }
    $html .= '</td></tr>';
  }
  $html .= '</tbody></table>';
  return $html;
} #_AdminAccountTable


sub Orbit::_AdminActionForm
{
  my ( $self, $action_url, $csrf, $user, $action, $label ) = @_;
  return '<form action="'.$action_url.'" method="post" style="display:inline">'
    .'<input type="hidden" name="csrf_token" value="'.$csrf.'">'
    .'<input type="hidden" name="admin_action" value="'.$self->_HtmlText($action).'">'
    .'<input type="hidden" name="username" value="'.$user.'">'
    .'<button type="submit" class="w3-button w3-round w3-margin-right">'
    .$self->_HtmlText($label).'</button></form>';
} #_AdminActionForm


sub Orbit::_OrbitPrefix
{
  my ( $self ) = @_;
  my $prefix = $self->Get_Token('_ORBIT');
  return $prefix if (defined($prefix) && $prefix =~ m{\A/[A-Za-z0-9._/-]*\z});
  return '/o/';
} #_OrbitPrefix


sub Orbit::_HtmlText
{
  my ( $self, $value ) = @_;
  $value = '' if (!defined($value) || ref($value));
  $value =~ s/&/&amp;/g;
  $value =~ s/</&lt;/g;
  $value =~ s/>/&gt;/g;
  $value =~ s/"/&quot;/g;
  $value =~ s/'/&apos;/g;
  $value =~ s/#/&num;/g;
  return $value;
} #_HtmlText


sub Orbit::_FormatAuthTime
{
  my ( $self, $epoch ) = @_;
  return '' if (!defined($epoch) || $epoch !~ /\A[1-9][0-9]*\z/);
  my @t = gmtime($epoch);
  return sprintf('%04d-%02d-%02d %02d:%02d UTC',
    $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1]);
} #_FormatAuthTime


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
  return 1 if ($action eq 'person.self_create'
    && $role ne 'anonymous'
    && uc($root) eq 'PERSONS');
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
    create              => 'EL_NEW',
    'system.create'     => 'EL_NEW',
    'person.self_create'=> 'EL_NEW',
    add                 => 'EL_ADD',
    edit                => 'EL_EDIT',
    delete              => 'EL_DEL',
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

  my $policy_action = ($operation =~ /^system\./) ? 'system.write'
    : ($operation eq 'person.self_create') ? 'person.self_create'
    : 'content.write';
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
  if ((($self->{_Role} // '') eq 'editor' || $operation eq 'person.self_create')
      && !$self->_ValidateEditorMutationPayload()) {
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
  return 1 if ($self->{_AuthTemplateAllowed}
    && $self->{_SignupTemplateAllowed}
    && $name eq 'EL_SIGNUP'
    && $self->_AuthTransportAllowed()
    && $self->_PublishSelfSignupPolicy());
  return 1 if ($self->{_AuthTemplateAllowed}
    && $name =~ /\A(?:EL_PROFILE|EL_SETTINGS)\z/);
  return 1 if ($self->{_AuthTemplateAllowed}
    && $name eq 'EL_ADMIN'
    && $self->_AuthTransportAllowed()
    && $self->AuthorizeAction('account.admin'));
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
  return '' if (!$self->_AuthTransportAllowed());
  return '' if (!defined($token) || $token !~ /\A[A-Za-z0-9_-]{43}\z/);
  my $secure = $self->_IsHTTPS();
  my $name = $secure ? '__Host-el_sid' : 'el_dev_sid';
  my $cookie = $name.'='.$token.'; Path=/; HttpOnly; SameSite=Lax';
  $cookie .= '; Secure' if ($secure);
  return $cookie;
} #_NewSessionCookie


sub Orbit::_ExpiredSessionCookie
{
  my ( $self ) = @_;
  return '' if (!$self->_AuthTransportAllowed());
  my $secure = $self->_IsHTTPS();
  my $name = $secure ? '__Host-el_sid' : 'el_dev_sid';
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
  return '/o/page' if ($path =~ /%(?![0-9a-f]{2})/i
    || $path =~ /%(?:0[0-9a-f]|1[0-9a-f]|7f)/i);
  my ($path_component) = split(/[?#]/, $path, 2);
  return '/o/page' if ($path_component =~ /%(?:25|2e|2f|5c)/i);
  return '/o/page' if ($path_component =~ m{(?:^|/)\.\.(?:/|$)});
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
    -X_Content_Type_Options => 'nosniff',
    -Referrer_Policy => 'same-origin',
    -X_Frame_Options => 'SAMEORIGIN',
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


sub Orbit::_ShowSignupTemplate
{
  my ( $self, $template ) = @_;
  local $self->{_AuthTemplateAllowed} = 1;
  local $self->{_SignupTemplateAllowed} = 1;
  return $self->ShowPage($template);
} #_ShowSignupTemplate


sub Orbit::_ShowAccountTemplate
{
  my ( $self, $template ) = @_;
  local $self->{_AuthTemplateAllowed} = 1;
  return $self->ShowPage($template);
} #_ShowAccountTemplate


sub Orbit::_ProfileService
{
  my ( $self ) = @_;
  return $self->{_Profile} if defined($self->{_Profile});
  return undef if (!defined($self->{_DomainDir}) || $self->{_DomainDir} eq ''
    || !-d $self->{_DomainDir});
  # Quote the class name.  A subroutine named Profile in this package would
  # otherwise steal Orbit::Profile->new and turn storage setup into a no-op.
  my $profile = eval { 'Orbit::Profile'->new(domain_dir => $self->{_DomainDir}) };
  $self->{_Profile} = $profile if defined($profile);
  return $self->{_Profile};
} #_ProfileService


sub Orbit::_PersonService
{
  my ( $self ) = @_;
  return $self->{_PersonLookup} if defined($self->{_PersonLookup});
  return undef if (!defined($self->{_DomainDir}) || $self->{_DomainDir} eq ''
    || !-d $self->{_DomainDir});
  my $lookup = eval { 'Orbit::Person'->new(domain_dir => $self->{_DomainDir}) };
  $self->{_PersonLookup} = $lookup if defined($lookup);
  return $self->{_PersonLookup};
} #_PersonService


sub Orbit::_ClaimedPersonMap
{
  my ( $self, $accounts ) = @_;
  $accounts ||= eval { $self->{_Auth}->list_accounts } if defined($self->{_Auth});
  $accounts = [] if (ref($accounts) ne 'ARRAY');
  my %claimed;
  foreach my $account (@$accounts) {
    my $word = 'Orbit::Person'->normalize($account->{person} // '');
    next if !defined($word) || $word eq '';
    $claimed{$word} = $account->{username} if !exists $claimed{$word};
  }
  return \%claimed;
} #_ClaimedPersonMap


sub Orbit::_AssertPersonLinkable
{
  my ( $self, $username, $value ) = @_;
  my $word = 'Orbit::Person'->normalize($value);
  croak 'That person name is not valid.' if !defined $word;
  return '' if $word eq '';
  my $lookup = $self->_PersonService;
  croak 'That person has not been created yet.'
    if (!defined($lookup) || !$lookup->exists($word));
  my $claimed = $self->_ClaimedPersonMap;
  my $owner = $claimed->{$word} // '';
  croak 'That person is already linked to another account.'
    if ($owner ne '' && $owner ne $username);
  return $word;
} #_AssertPersonLinkable


sub Orbit::_BindPersonToUser
{
  my ( $self, $username, $value ) = @_;
  croak 'Authentication is unavailable.' if !defined($self->{_Auth});
  my $word = $self->_AssertPersonLinkable($username, $value);
  $self->{_Auth}->update_account($username, person => $word);
  my $profile = $self->_ProfileService;
  if (defined($profile)) {
    my $current = eval { $profile->read_public($username) };
    $current = $profile->empty_profile($username) if (ref($current) ne 'HASH');
    $profile->write_public(
      $username,
      bio      => $current->{bio},
      pronouns => $current->{pronouns},
      url      => $current->{url},
      email    => $current->{email},
      person   => $word,
    );
  }
  return $word;
} #_BindPersonToUser


sub Orbit::_PersonSelectOptions
{
  my ( $self, $selected, $username, $accounts ) = @_;
  $selected = 'Orbit::Person'->normalize($selected);
  $selected = '' if !defined $selected;
  $username = '' if !defined $username;
  my $claimed = $self->_ClaimedPersonMap($accounts);
  my $lookup = $self->_PersonService;
  my $people = defined($lookup) ? ($lookup->list_records || []) : [];
  $people = [] if (ref($people) ne 'ARRAY');

  my $html = '<option value="">Not linked</option>';
  my $found_selected = ($selected eq '') ? 1 : 0;
  foreach my $record (@$people) {
    my $word = $record->{word} // '';
    next if $word eq '';
    my $owner = $claimed->{$word} // '';
    next if ($owner ne '' && $owner ne $username);
    my $sel = ($word eq $selected) ? ' selected' : '';
    $found_selected = 1 if ($word eq $selected);
    my $label = $record->{name} // $word;
    $label .= ' ('.$word.')' if ($label ne $word);
    $html .= '<option value="'.$self->_HtmlText($word).'"'.$sel.'>'
      .$self->_HtmlText($label).'</option>';
  }
  if (!$found_selected && $selected ne '') {
    my $owner = $claimed->{$selected} // '';
    if ($owner eq '' || $owner eq $username) {
      my $label = $selected;
      $label = $lookup->display_name($selected) if defined($lookup);
      $html .= '<option value="'.$self->_HtmlText($selected).'" selected>'
        .$self->_HtmlText($label).' (not in directory)</option>';
    }
  }
  return $html;
} #_PersonSelectOptions


sub Orbit::_UserSelectOptions
{
  my ( $self, $selected, $accounts ) = @_;
  $selected = '' if !defined $selected;
  $accounts ||= [];
  my $lookup = $self->_PersonService;
  my $html = '<option value="">Choose a user</option>';
  foreach my $account (@$accounts) {
    next if (($account->{status} // '') eq 'disabled');
    my $user = $account->{username} // '';
    next if $user eq '';
    my $person = 'Orbit::Person'->normalize($account->{person} // '');
    $person = '' if !defined $person;
    my $label = $user;
    if ($person ne '') {
      my $name = $person;
      $name = $lookup->display_name($person) if defined($lookup);
      $label .= ' ('.$name.')';
    }
    my $sel = ($user eq $selected) ? ' selected' : '';
    $html .= '<option value="'.$self->_HtmlText($user).'"'.$sel.'>'
      .$self->_HtmlText($label).'</option>';
  }
  return $html;
} #_UserSelectOptions


sub Orbit::_PersonRootName
{
  my ( $self ) = @_;
  my $root = '';
  $root = $self->{_Root} if defined($self->{_Root}) && $self->{_Root} ne '';
  $root = $self->GetRoot() if ($root eq '' && $self->can('GetRoot'));
  $root = $self->Get_Token('ROOT') if ($root eq '' && $self->can('Get_Token'));
  $root = '' if !defined $root;
  $root =~ tr/a-z/A-Z/;
  $root =~ s{/}{.}g;
  return $root;
} #_PersonRootName


sub Orbit::_PublishPersonPageIfCurrent
{
  my ( $self, $word ) = @_;
  return 0 if !defined($self->{_Auth});
  return 0 if ($self->_PersonRootName() ne 'PERSONS');
  my $found = $self->can('Get_Token') ? ($self->Get_Token('_WORDFOUND_') // '') : '';
  return 0 if $found ne '1';
  $word = '' if !defined $word;
  if ($word eq '' && $self->can('Get_Token')) {
    $word = $self->Get_Token('WORD');
    $word = $self->Get_Token('_PHRASE_') if (!defined($word) || $word eq '');
    $word = $self->Get_Token('_WORD_') if (!defined($word) || $word eq '');
  }
  return $self->_PublishPersonPageTokens($word);
} #_PublishPersonPageIfCurrent


sub Orbit::_PublishPersonPageTokens
{
  my ( $self, $word ) = @_;
  $word = 'Orbit::Person'->normalize($word);
  $word = '' if !defined $word;
  $self->SetUntrustedToken('PERSON_LINKED_USER', '');
  $self->SetUntrustedToken('PERSON_LINKED_PROFILE_URL', '');
  $self->Set_Token('PERSON_CAN_LINK_SELF', '0');
  $self->SetUntrustedToken('PERSON_USER_OPTIONS', '<option value="">Choose a user</option>');
  $self->SetUntrustedToken('PERSON_CREATE_USER_URL', '');
  return 0 if ($word eq '' || !defined($self->{_Auth}));

  my $accounts = eval { $self->{_Auth}->list_accounts } || [];
  $accounts = [] if (ref($accounts) ne 'ARRAY');
  my $claimed = $self->_ClaimedPersonMap($accounts);
  my $owner = $claimed->{$word} // '';
  if ($owner ne '') {
    $self->SetUntrustedToken('PERSON_LINKED_USER', $owner);
    $self->SetUntrustedToken('PERSON_LINKED_PROFILE_URL',
      $self->_OrbitPrefix().'elprofile?u='.$owner);
  }
  else {
    my $can_self = 0;
    if ($self->{_User} ne '' && !$self->{_MustChange}) {
      my $mine = eval { $self->{_Auth}->read_account($self->{_User}) };
      my $own = '';
      if (ref($mine) eq 'HASH') {
        $own = 'Orbit::Person'->normalize($mine->{person} // '');
        $own = '' if !defined $own;
      }
      $can_self = 1 if ($own eq '');
    }
    $self->Set_Token('PERSON_CAN_LINK_SELF', $can_self ? '1' : '0');
    $self->SetUntrustedToken('PERSON_USER_OPTIONS',
      $self->_UserSelectOptions('', $accounts));
    $self->SetUntrustedToken('PERSON_CREATE_USER_URL',
      $self->_OrbitPrefix().'eladmin?person='.$self->_PersonQueryValue($word));
  }
  $self->SetUntrustedToken('PERSON_WORD', $word);
  return 1;
} #_PublishPersonPageTokens


sub Orbit::_PersonQueryValue
{
  my ( $self, $word ) = @_;
  $word = 'Orbit::Person'->normalize($word);
  return '' if !defined($word) || $word eq '';
  $word =~ s/%/%25/g;
  $word =~ s/\+/%2B/g;
  $word =~ s/ /+/g;
  return $word;
} #_PersonQueryValue


sub Orbit::_PublishAccountMenuTokens
{
  my ( $self ) = @_;
  my $user = $self->{_User} // '';
  my $initial = ($user ne '') ? uc(substr($user, 0, 1)) : '';
  $self->Set_Token('AUTH_AVATAR_INITIAL', $initial);
  my $url = '';
  if ($user ne '') {
    my $profile = $self->_ProfileService;
    if (defined($profile)) {
      my $record = eval { $profile->read_public($user) };
      $url = $profile->avatar_url($user, $record->{avatar})
        if (ref($record) eq 'HASH');
    }
  }
  $self->SetUntrustedToken('AUTH_AVATAR_URL', $url);
  return 1;
} #_PublishAccountMenuTokens


sub Orbit::_AssignProfileTokens
{
  my ( $self, $username, $account ) = @_;
  $account ||= eval { $self->{_Auth}->read_account($username) } if defined($self->{_Auth});
  $account = {} if ref($account) ne 'HASH';

  my $profile = $self->_ProfileService;
  my $record = defined($profile) ? eval { $profile->read_public($username) } : undef;
  $record = defined($profile) ? $profile->empty_profile($username) : {}
    if (ref($record) ne 'HASH');

  my $person = $account->{person} // $record->{person} // '';
  $person = 'Orbit::Person'->normalize($person);
  $person = '' if !defined $person;
  my $lookup = $self->_PersonService;
  my $person_exists = (defined($lookup) && $person ne '' && $lookup->exists($person)) ? 1 : 0;
  my $person_name = $person_exists ? $lookup->display_name($person) : $person;
  my $person_url = $person_exists ? $lookup->show_url($person) : '';
  my $avatar = defined($profile) ? $profile->avatar_url($username, $record->{avatar}) : '';
  my $is_self = ($self->{_User} ne '' && $self->{_User} eq $username) ? '1' : '0';
  my $own_person = $person;
  if ($is_self ne '1' && $self->{_User} ne '' && defined($self->{_Auth})) {
    my $mine = eval { $self->{_Auth}->read_account($self->{_User}) };
    $own_person = '';
    if (ref($mine) eq 'HASH') {
      $own_person = 'Orbit::Person'->normalize($mine->{person} // '');
      $own_person = '' if !defined $own_person;
    }
  }
  my $can_create = 0;
  if ($self->{_User} ne '' && !$self->{_MustChange}) {
    my $role = $self->{_Role} // '';
    $can_create = 1 if ($role eq 'editor' || $role eq 'admin' || $own_person eq '');
  }

  $self->Set_Token('PROFILE_USERNAME', $username);
  $self->Set_Token('PROFILE_ROLE', $account->{role} // '');
  $self->Set_Token('PROFILE_IS_SELF', $is_self);
  $self->Set_Token('AUTH_CAN_CREATE_PERSON', $can_create ? '1' : '0');
  $self->Set_Token('PROFILE_AVATAR_INITIAL', uc(substr($username, 0, 1)));
  $self->SetUntrustedToken('PROFILE_AVATAR_URL', $avatar);
  $self->SetUntrustedToken('PROFILE_BIO', $record->{bio} // '');
  $self->SetUntrustedToken('PROFILE_PRONOUNS', $record->{pronouns} // '');
  $self->SetUntrustedToken('PROFILE_URL', $record->{url} // '');
  $self->SetUntrustedToken('PROFILE_EMAIL', $record->{email} // '');
  $self->SetUntrustedToken('PROFILE_PERSON', $person);
  $self->SetUntrustedToken('PROFILE_PERSON_NAME', $person_name);
  $self->SetUntrustedToken('PROFILE_PERSON_URL', $person_url);
  $self->Set_Token('PROFILE_PERSON_EXISTS', $person_exists ? '1' : '0');
  my $accounts = eval { $self->{_Auth}->list_accounts } || [];
  $accounts = [] if (ref($accounts) ne 'ARRAY');
  $self->SetUntrustedToken('PROFILE_PERSON_OPTIONS',
    $self->_PersonSelectOptions($person, $username, $accounts));
  my $create_url = $self->_OrbitPrefix().'elnew?r=PERSONS&o=person&p=el_new&link_user=1';
  $self->SetUntrustedToken('PROFILE_CREATE_PERSON_URL', $create_url);
  return 1;
} #_AssignProfileTokens


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

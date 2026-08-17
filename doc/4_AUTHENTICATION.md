# Orbit 7 authentication and authorization

This document describes the first Orbit 7 user/passphrase implementation. It is
intentionally a small, file-backed, per-domain system. `ACCESS.dat` is reserved
for a later ACL design; it is not treated as an authentication database.

## V1 behavior

- Public content remains readable without an account.
- `viewer` accounts can log on and manage their own passphrase, but cannot write
  content.
- `editor` accounts can write public roots. Editor-supplied fields are treated as
  data and cannot contain HTML or executable OML syntax.
- `admin` accounts can perform explicitly classified system actions. Generic
  content routes still cannot write underscore-prefixed roots such as `_ORBIT`.
- Accounts and sessions are local to one domain directory. There is no
  cross-domain session or global single sign-on.
- Multiple devices are supported, with at most ten current sessions per user.
  Sessions expire after 30 minutes idle or eight hours absolute time. There is
  no “remember me” session in v1.

The web flows included in v1 are logon, logoff, and change passphrase. Account
creation, reset, disable/enable, role changes, and session revocation are local
administrator operations. Self-registration, email reset, security questions,
OAuth/SSO, email verification, 2FA, WebAuthn, teams, and fine-grained ACLs are
deferred.

## Private on-disk layout

Each domain owns a separate private store:

```text
<domain>/_ORBIT/_AUTH/
  USERS/
  PASSPHRASE/
  SESSIONS/
  RATELIMIT/ACCOUNT/
  RATELIMIT/IP/
  LOCKS/
  AUDIT/auth.jsonl
```

The `_AUTH` tree and its subdirectories are mode `0700`; records are mode
`0600`. They must be owned by the CGI runtime account (`www-data` on Debian or
Ubuntu, `apache` on Fedora). The deployment scripts prune this tree from their
legacy recursive web-content permission changes. Authentication paths reject
symbolic links and path escapes, and record replacement is atomic.

Passphrases use Argon2id through `Crypt::Argon2`, with a 16-byte random salt,
19 MiB memory, two iterations, one lane, and a 32-byte output. Random tokens use
`Crypt::URandom`. A missing crypto dependency is a hard authentication failure;
the code never falls back to a weaker hash or PRNG. Passphrases are normalized
to Unicode NFC and must be 15–128 characters (and at most 1024 UTF-8 bytes).

Only a SHA-256 digest of each 256-bit opaque session token is stored. A separate
256-bit CSRF secret is stored in the session record. Changing/resetting a
passphrase, changing account status/role, or an explicit administrator revoke
invalidates existing sessions through an account authentication version.

## HTTP and request security

Production authentication requires HTTPS. The production cookie is
`__Host-el_sid` with `Path=/`, `Secure`, `HttpOnly`, and `SameSite=Lax`.
Development over HTTP is available only when
`EL_AUTH_ALLOW_INSECURE_LOOPBACK=1`, both the client address and host are
loopback, and the separate `el_dev_sid` cookie is used.

All content mutations require an authenticated `editor` or `admin`, `POST`, and
the session CSRF value. Logoff and passphrase change also require `POST` and
CSRF. Logon uses a pre-authentication CSRF value so a third-party site cannot
silently replace a browser's identity with the attacker's account. Redirects
accept only local absolute paths. Authentication responses are `no-store` and
use restrictive CSP, clickjacking, referrer, MIME-sniffing, and permissions
headers. HSTS is sent on non-loopback HTTPS responses.

CGI/environment values and form values are non-recursive OML tokens. Structural
selectors such as page, root, word, tree, and template names are validated
before they can affect lookup paths. Data and template file reads enforce
domain-root containment, reject symlinks and traversal, and impose size limits.
Generic web requests can execute only `DEFAULT`, `EL_SHOW`, and `EL_STYLE` as
top-level templates. Authentication and mutation templates are enabled only by
their dedicated handlers after transport and authorization checks; other OML
templates remain internal includes. Underscored data formfields are accepted
only on dedicated mutation POST routes, while public pagination fields receive
type and markup validation. This prevents request data from manufacturing raw
presentation/control tokens in internal helper templates.
The legacy server-side remote-image URL fetch is disabled; a validated local
image-upload flow is deferred rather than exposing an editor-controlled SSRF
path.

## Administrator commands

Install scripts publish `eluser` in the system administration path. Run it as
the domain's CGI runtime user, never as root:

```sh
sudo -u www-data eluser init /LOVE/example.test
sudo -u www-data eluser create /LOVE/example.test river-editor --role editor
sudo -u www-data eluser reset /LOVE/example.test river-editor
sudo -u www-data eluser disable /LOVE/example.test river-editor
sudo -u www-data eluser enable /LOVE/example.test river-editor
sudo -u www-data eluser role /LOVE/example.test river-editor --role viewer
sudo -u www-data eluser revoke /LOVE/example.test river-editor
sudo -u www-data eluser maintain /LOVE/example.test
```

Use `apache` instead of `www-data` on Fedora. Passphrases are read twice from an
un-echoed terminal and are never accepted in command arguments. A reset issues
a temporary passphrase, revokes all sessions, and forces a change at the next
logon. Run `maintain` periodically (for example, daily) to remove expired
sessions and stale rate-limit state and to enforce audit retention.

## Rate limits and audit

Before doing expensive Argon2 work, a login reserves capacity in independent
account and IP buckets. Defaults are five failed attempts per account and twenty
per IP in 15 minutes, followed by a 15-minute lockout. Unknown usernames use
only bounded IP state and the same dummy Argon2 verification shape as a missing
or inactive account. The IP bucket is the hard pre-hash work limit. If only an
account bucket is locked, one IP reservation and one dummy verification are
still performed so the shared unknown-account bucket cannot become a username
timing oracle. Browser-visible failures remain generic.

Passphrase changes reserve the same account/IP capacity before Argon2 work.
They verify the current passphrase before hashing the proposed replacement;
failed current-passphrase attempts consume the shared limits, and concurrent
change attempts cannot exceed the same admission bounds as logon. The
canonicalized replacement must differ from the current passphrase, so a
temporary reset secret cannot clear `must_change` without being rotated.

Private JSON-lines audit records include timestamp, event/result, bounded user,
IP, user-agent, reason/action/root, request ID, count, and session digest when
applicable. They never include a passphrase, cookie, raw bearer token, CSRF
secret, or request body. The audit log rotates at 10 MiB and retains 30 archives
by default. Failed/successful/throttled logons, session creation/revocation,
logoff, account/credential changes, authorization denials, and maintenance are
recorded.

## Deployment checklist

1. Install `Crypt::Argon2`, `Crypt::URandom`, and `Term::ReadKey` with the
   platform setup script.
2. Propagate the Orbit libraries and CGI routes. Propagation synchronizes the
   security-sensitive templates to every configured virtual-host document root.
3. Verify `<domain>/_ORBIT/_AUTH` is `0700` and owned by the CGI runtime user.
4. Create the initial administrator with `eluser create ... --role admin`.
5. Exercise logon, a permitted write, a denied write, logoff, and the audit log
   before exposing the domain.
6. Schedule `eluser maintain` and normal protected backups of `_AUTH`.

Never serve `_ORBIT/_AUTH` through Apache, copy it with public templates, or run
`eluser` as root. Backups contain password verifiers and active session records
and need the same protection as the live store.

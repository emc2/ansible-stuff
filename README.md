# Ansible Scripts for a Secure FreeBSD-Based Network and Personal Machines

This repository contains a collection of Ansible scripts which aim to become
the primary means for configuring my personal machines and my network.  Care is
taken to see that the scripts can be reused in whole or in part by changing
variables.

## Setup

This section describes the Ansible setup.

### Ansible Inventory and Configuration

The Ansible `hosts` file is not included in this repository, as it is typically
found (on a FreeBSD machine) at `/usr/local/etc/ansible/hosts`.  The two
playbook files `pb.laptop.yml` and `pb.remote.yml` and the `group_vars` assume
a setup akin to the following:

    [freebsd:children]
    remote
    laptop

    [laptop]
    localhost

    [remote:children]
    ...

This creates a top-level group `freebsd`, with two children: `laptop` and
`remote` (it is assumed desktops will be configured remotely).  For mixed-OS
networks or setups, a different topology may be better.

### Access Configuration

Ansible is set up to access the machines based on two configurations: the
"normal" configuration and the "red-box" configuration.  The red-box is intended
to be a designated machine to be used only in case of emergency to bring the
network back up, and avoids the disaster that would take place if the KDC were
to go down.  The red-box configuration is also necessary to bootstrap the
network, since the normal configuration relies on a Kerberized PAM setup.

The normal configuration uses Kerberos authentication to access all machines.
An `admin` account must be created on all machines, for which an ordinary
`admin` Kerberos principal exists as well as an `admin/root` principal allowing
`su` access to the `root` account.  It is recommended that these accounts be
created *locally*, in order to account for the case where LDAP is down.  The
normal ansible setup is supplied with the Kerberos passwords for the `admin`
and `admin/root` principals, and uses `su` for privilege escalation.

The red-box configuration uses SSH keys to be distributed to the `admin`
account's home directory, with the private key being kept exclusively on the
red-box.  The root password is set to a *different* random value on each
machine locally.  This permits the red-box to access the machines even if
the KDC is down or PAM has not been set up for Kerberos authentication.

This is all achieved through vault files which are not included in this
repository for obvious reasons.

## General Configurations

This section describes configurations that are deployed to all machines.

### SSH Configuration

An `ssh_config` file is deployed to each machine (and a corresponding
`sshd_config` to server machines).  This file does a number of things:

First, the cipher selections are altered in order to disallow weak crypto and
institute an order of preference with regard to crypto that prefers stronger
ciphers first and takes factors such as the creator into accont in the order
of preference:

* The configuration makes an attempt at quantum-safety by allowing only CTR
  mode and disallowing any symmetric key algorithm weaker than 256 bits.
  However, no quantum-safe public-key algorithm is presently available for SSH.
* Ciphers such as RC4, MD5, DES, 3DES, and DSA are all disabled.
* Curve25519 is the preferred public-key algorithm, and the NIST P curves are
  disabled.
* ChaCha20/Poly1305 is the preferred authenticated encryption mechanism,
  with AES256-CTR being the only other allowed cipher.
* SHA512 is preferred, with RipeMD160 being preferred over SHA256.
* Encrypt-then-MAC modes are preferred over other modes.

Additionally, everything is put in place for a Kerberos/GSSAPI-based network:

* If a user attempts to connect without already having a Kerberos ticket,
  the system will ask for a password and obtain a ticket for them upon login.
* A ticket obtained in such a manner will be deleted upon logout.
* If a user attempts to connect and *does* possess a ticket, they will not be
  asked for a password, and the ticket will be forwarded to the new machine.

### Source Building

Several options are configured for source building (building world and ports):

* The `CPUTYPE` variable is set to `native`, causing the compiler to auto-detect
  and optimize for the local CPU architecture.  *This could be a cause of issues
  for some use cases!  Be aware of this!*
* LibreSSL is set as the OpenSSL port, and ports are configured to build using
  it as the OpenSSL library.
* A number of useless system components are disabled in `src.conf`.

## Server Configurations

This section describes the configurations that are deployed to network machines.
These are managed by the "remote" group in ansible.

### Kerberos

All authentication is handled through Kerberos, which is provided by a central
KDC.  *This also holds for service-to-service authentication!*  All machines
directly wired to the network are provided with the krb5.conf file.  Laptops
are assumed to be mobile, and thus are not directly Kerberized.

Pluggable Authentication Modules (PAM) on all wired machines are configured to
authenticate through Kerberos, then through UNIX accounts.  This facilitates the
creation of the local `admin` account, as a failsafe for network failure (and to
allow the red-box to work).

Ansible does *not* automatically generate the host keytabs at `/etc/krb5.keytab`
or any other keytab, as doing so would require Ansible to be provided with the
KDC admin password.  This is simply too great of a risk.  Keytabs need to be
generated out-of-band.

### SSL Certificates

Secure communication is achieved between all services by virtue of client SSL
certificates issued by an internal CA for each service.  This means that a large
number of certificates are generate and distributed to each machine: one for
for each machine and service.

The CA certificate and CRL are also distributed to every machine.  This serves
two purposes: first, it allows services to verify the certificates of client
services.  Second, it allows certificate authentication to be configured in lieu
of, or in addition to password authentication.

Certificates are generated and read from a standard location on the control
machine.  None of the CA information needs to be present in order for the
ansible tasks, however, meaning that the red-box machine can be equipped with
the latest snapshot of certificates in order to allow it to function.

### LDAP Clients

LDAP clients are supplied with a host-specific client certificate and an LDAP
configuration file.  The certificate and configuration file will be used only
for the LDAP command-line tools; any service will be supplied with its own
client certificate.

### LDAP NSS Information

The `nslcd` utility is used to connect `nsswitch` to the network LDAP database.
This requires a client cert be issued for each machine's `nslcd` daemon, as well
as the creation of a Kerberos principal and a keytab for that machine's daemon,
in keeping with the high security standards of the network.

The kerberos keytab must be placed at `/etc/keytabs/nslcd.keytab` and made
accessible to the `nslcd` user.

A cron job will be set up to refresh the kerberos credentials every 6 hours.
This ensures that the nslcd user always has a valid ticket for accessing the
LDAP database.

### LDAP Server

An OpenLDAP server instance is created on any machine in the `ldap` group.  An
SSL certificate and key must be created for the server by the local CA, and
the `ldap/<fqhn` service credential must be stored in the server's keytab
(`/etc/keytabs/ldap.keytab`)

This server instance currently allows four modes of authentication: SASL,
GSSAPI, and certificate authentication.  To facilitate the configuration of
authentication and authorization, some assumptions are made about the structure
of the LDAP database.  Users are assumed to be stored in
`cn=<name>,ou=people,<basedn>`, hosts are assumed to be stored under
`cn=<fqhn>,ou=hosts,<basedn>`, and the administrator is assumed to be
`cn=admin,<basedn>`.

Authentication and mapping to entries takes place as follows:

* Kerberos-based authentication can be performed for SASL authentication by
  placing `{SASL}<kerberos principal>` in the `userPassword` field for any entry
  with the `shadowAccount` type.  This is the recommended way of doing
  authentication.
* GSSAPI host principals (of the form `host/<fqhn>`) are mapped to
  `cn=<hostname>,ou=hosts,<basedn>`.
* GSSAPI service principals (of the form `<service>/<fqhn>`) are also mapped to
  the host entry for now.
* All other GSSAPI principals are mapped to `cn=<principal>,ou=people,<basedn>`.
* Certificates with a subject of `cn=<fqhn>,ou=hosts,o=<network name>` are
  mapped to `cn=<hostname>,ou=hosts,<basedn>`
* Certificates with a subject of `cn=<name>,ou=people,o=<network name>` are
  mapped to `cn=<name>,ou=people,<basedn>`.

The server is currently configured to request and verify client certificates,
but to allow connections without a client certificate.  The server is also
currently configured to allow plaintext as well as SSL connections.  All
services using the LDAP database should be issued machine-specific Kerberos
service credentials and client certificates.

#### TODOs

The following are goals for this configuration, and will be implemented as soon
as other configurations are updated:

* Add host service entries, such as `cn=nslcd,cn=myhost,ou=hosts,<basedn>`,
  configure GSSAPI authentication accordingly.
* Finer-grained access permissions.
* Disable certificate authentication.
* Require client certificates for all connections.
* Allow only SSL connections.
* Replication across multiple machines.

### PostgreSQL Servers

A PostgreSQL server will be installed on any machine in the `db` group.  An SSL
certificate and key must be created for the PostgreSQL server, and the Kerberos
service principal must be stored in the keytab `postgres.keytab` in the server's
data directory.

The PostgreSQL server is configured to only allow SSL remote connections, and to
authenticate with GSSAPI.  Note that database users must be created explicitly
for any user wishing to authenticate, in addition to the Kerberos principal for
that user.

PostgreSQL conninfo strings can generally be used to supply the necessary
arguments for proper SSL and authentication.

#### TODOs

The following are goals to be implemented:

* Demand and verify client certificates for all SSL connections.
* Disable certificate authentication.

### Dovecot IMAP Servers

A Dovecot IMAP server will be installed on any machine in the `mail` group.  The
present configuration requires postfix servers to run on a machine alongside a
Dovecot instance, so these are grouped into the same group for now (this can be
changed without too much trouble, though).

Dovecot will listen for both imaps and pop3s (both over SSL) as well as sieve
connections.  Unencrypted connections are not allowed at all.  It supports
authentication through GSSAPI, client certificates (though this is currently
untested), and SASL for regular passwords.  SASL authentication uses PAM as its
backend.  When combined with the Kerberos-based PAM configuration in this
suite, this provides full support for a Kerberos/LDAP
authentication/authorization scheme.

Dovecot uses LDAP for authorization.  Usernames are mapped to LDAP entries of
the form `cn=<name>,ou=people,<basedn>` of the object class `mailUser`.  These
are expected to contain `uidNumber`, `gidNumber`, and `homeDirectory` attributes
which tell Dovecot the corresponding user's user ID, primary group ID, and
home directory respectively.

*Note that Dovecot must have access to users' home directories in order to
function!*  This is fundamental to the way Dovecot (and most other mail servers)
work.  In a network setting, this is most easily achieved through NFS.

#### TODOs

* Test and possibly fix client certificate authentication settings.

## Personal Machines

This section describes the configurations that take place on personal machines.
These are obviously a matter of personal preference in many cases.

### Emacs Configuration

The configuration installs my standard `.emacs` file to the primary user's home
directory.  This file does a number of things:

* Disable hard tabs
* Set the preferred maximum line length to 80 columns, enable a mode to
  highlight portions of lines longer than this
* Highlight the current line
* Disable hard tabs (and contains a default-disabled option to represent them
  with a special character)
* Highlight trailing whitespace and delete it on save
* Enable the MELPA package system
* Enable and configure the flycheck package
* Enable the autocomplete package
* Enable and configure Haskell mode
* Set up autocomplete for Haskell

### X11 Configuration

X11 configuration tends to be too highly system-dependent for any sort of
universal configuration to be worthwhile.

Some font configuration can be done, however.  The X11 task adds a few font
configurations by symlinking from `fonts/conf.d` to `fonts/conf.avail`.  The
following items are set up:

* Turn on autohinting
* Turn on subpixel rendering
* Turn on LCD filtering (almost every monitor is LCD these days)
* Enable Unicode fonts
* Disable bitmap fonts

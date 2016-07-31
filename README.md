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

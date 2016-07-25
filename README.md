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

> [freebsd:children]
> remote
> laptop
>
> [laptop]
> localhost
>
> [remote:children]
> ...

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

## Kerberos

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

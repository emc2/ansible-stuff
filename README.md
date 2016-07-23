# Ansible Scripts for a Secure FreeBSD-Based Network

## Ansible Access Configuration

Ansible is set up to access the machines based on two configurations: the
"normal" configuration and the "red-box" configuration.  The red-box is intedend
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

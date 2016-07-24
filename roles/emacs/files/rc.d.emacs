#!/bin/sh

# PROVIDE: emacs
# REQUIRE: LOGIN

. /etc/rc.subr

name=emacs
rcvar=emacs_daemon_enable

start_cmd="emacs_daemon_start"
stop_cmd="emacs_daemon_stop"
restart_cmd="emacs_daemon_restart"

emacs_daemon_start()
{
	echo -n "Starting emacs daemon for users:"
	for user in $@; do
		echo " $user"
		su $user -c "/usr/local/bin/emacs --daemon --user $user" 2> /dev/null
	done
}

emacs_daemon_stop()
{
	echo -n "Stopping emacs daemon for users:"
	for user in $@; do
		echo " $user"
		pkill -U $user emacs* 2> /dev/null
	done
}

emacs_daemon_restart()
{
	echo -n "Restarting emacs daemon for users:"
	for user in $@; do
		echo " $user"
		pkill -U $user emacs* 2> /dev/null
		su $user -c "/usr/local/bin/emacs --daemon --user $user" 2> /dev/null
	done
}

load_rc_config $name
: ${emacs_daemon_enable:=NO}

case $# in
	1)	run_rc_command $@ ${emacs_daemon_users} ;;
	*)	run_rc_command $@ ;;
esac

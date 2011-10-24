#!/bin/bash

# rdiff-backup script
# Rootnode http://rootnode.net
#
# Copyright (C) 2011 Marcin Hlybin
# All rights reserved.

# exit on error
set -e 

# show usage
[ $# -eq 0 ] && echo -e "Usage: $0 server_name [user_name]" && exit 1 

# args 
server_name=$1
user_name=$2

# dirs
home_dir="/home"
backup_dir="/backup"
cd $backup_dir

# check backup type
[ -z $user_name ] && backup_type='system' || backup_type='users';

# set rdiff includes
case $backup_type in 
	system ) 
		destination_dir="$backup_dir/system/$server_name"
		rdiff_include="
			--include=/adm \
			--include=/etc \
			--include=/root \
			--include=/usr/src \
			--include=/usr/local \
			--include=/var/spool/cron \
			--include=/var/backups"
		;;
	users ) 
		destination_dir="$backup_dir/users"
		rdiff_include="--include=$home_dir/$user_name"
esac

# create directory
[ -d $destination_dir ] || mkdir -p -m 700 $destination_dir

/usr/bin/rdiff-backup \
	$rdiff_include \
	--exclude=/* \
root@$server_name.rootnode.net::/ $destination_dir

# client side /root/.ssh/authorized_keys:
# command="nice-n 19 /usr/bin/rdiff-backup --server --restrict-read-only /",from="IP ADDRESS HERE",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ssh-rsa SSH_KEY_HERE

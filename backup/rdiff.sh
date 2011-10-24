#!/bin/bash

# rdiff-backup script
# Rootnode http://rootnode.net
#
# Copyright (C) 2011 Marcin Hlybin
# All rights reserved.

# exit on error
set -e 

# usage
usage() {
	echo -e "Usage: $0 [ -l ] [ -r time_spec ] [ -u|-m user_name ] server_name" 
	exit 1	
}

[ $# -eq 0 ] && usage

# dirs
home_dir="/home"
backup_dir="/backup"
cd $backup_dir

# options
while getopts ":lr:u:m:" opt 
do
	case $opt in
	l) do_listing=1                                     ;;
	r) do_remove=1         ; remove_older_than=$OPTARG  ;;
	u) backup_type="users" ; user_name=$OPTARG          ;;
	m) backup_type="mysql" ; user_name=$OPTARG          ;; 
	*) usage                                            ;;
	esac
done

shift $((OPTIND-1))
server_name=$1
backup_type=${backup_type:-system}

case $backup_type in 
	system)      backup_path="$backup_dir/$backup_type/$server_name" ;;
	users|mysql) backup_path="$backup_dir/$backup_type/$user_name/$server_name" ;;
esac

# listing
if [ $do_listing ] 
then
	/usr/bin/rdiff-backup --parsable-output -l $backup_path 2>/dev/null | tail -1 | cut -d' ' -f1
	exit;
fi

# remove backup
if [ $do_remove ] 
then
	/usr/bin/rdiff-backup -v0 --remove_older_than $remove_older_than $backup_path
	exit;
fi

# set rdiff includes
case $backup_type in 
	system ) 
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
		rdiff_include="--include=$home_dir/$user_name"
esac

# create directory
[ -d $backup_path ] || mkdir -p -m 700 $backup_path

# create backup
/usr/bin/rdiff-backup \
	$rdiff_include \
	--exclude=/* \
	--exclude-device-files \
	--exclude-fifos \
	--exclude-sockets \
	--exclude-if-present .nobackup \
	--preserve-numerical-ids \
root@$server_name.rootnode.net::/ $backup_path 2>/dev/null

# client side /root/.ssh/authorized_keys:
# command="nice-n 19 /usr/bin/rdiff-backup --server --restrict-read-only /",from="IP ADDRESS HERE",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ssh-rsa SSH_KEY_HERE

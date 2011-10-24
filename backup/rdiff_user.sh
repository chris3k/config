#!/bin/bash

# rdiff-backup user script
# Rootnode http://rootnode.net
#
# Copyright (C) 2011 Marcin Hlybin
# All rights reserved.

set -e # exit on error
[ ! $1 ] && echo "Usage: $0 user_name" && exit 1 

dir=${rdiff_dir:-/backup/users}
user=$1 

cd $dest
[ ! -d $user ] && mkdir -m 700 $user

/usr/bin/rdiff-backup \
	--include=/home/$user \
	--exclude=/* \
root@$server.rootnode.net::/ /$dir/$user

## client file /root/.ssh/authorized_keys
# command="nice-n 19 /usr/bin/rdiff-backup --server --restrict-read-only /",from="IP ADDRESS HERE",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ssh-rsa SSH_KEY_HERE

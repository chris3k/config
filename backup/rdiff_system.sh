#!/bin/bash

# rdiff-backup script (system)
# Rootnode http://rootnode.net
#
# Copyright (C) 2011 Marcin Hlybin
# All rights reserved.

# Usage: ./rdiff.sh server_name

set -e # exit on error
dir=${rdiff_dir:-/backup/system}
server=$1 

cd $dest
[ !-d $server ] && mkdir -m 700 $server 

/usr/bin/rdiff-backup \
	--include=/adm \
	--include=/etc \
	--include=/root \
	--include=/usr/src \
	--include=/usr/local \
	--include=/var/spool/cron \
	--include=/var/backups \
	--exclude=/* \
root@$server.rootnode.net::/ /$dir/$server/rdiff

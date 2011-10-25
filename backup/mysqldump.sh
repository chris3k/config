#!/bin/bash

# mysqldump script
# Rootnode http://rootnode.net
#
# Copyright (C) 2011 Marcin Hlybin
# All rights reserved.

# exit on error
set -e 

# usage
usage() {
	echo -e "Usage: $0 uid server_name [ exclude_db ]" 
	exit 1	
}

# args
[ $# -lt 2 ] && usage

uid=$1
[ $uid -ge 2000 ] || usage

server_name=$2
shift 2

exclude_db=$@
exclude_db=${exclude_db// /\',\'} # add quotes

# dirs
mysql_tmp="/backup/mysqltmp"

# mysql tmp dir
[ -d $mysql_tmp ] && rm -rf -- $mysql_tmp
mkdir -p -m 700 $mysql_tmp/$server_name
cd $mysql_tmp/$server_name

# mysqldump
for database in `mysql -h $server_name.rootnode.net -Nse "SELECT db FROM mysql.db WHERE db like 'my${uid}_%' AND db NOT IN ('$exclude_db')"`
do
	mysqldump \
		--default-character-set=utf8 \
		--lock-tables \
		--complete-insert \
		--add-drop-table \
		--quick \
		--quote-names \
	$database > $database.sql
done

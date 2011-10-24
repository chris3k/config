#!/usr/bin/perl

# users backup script
# Rootnode http://rootnode.net
#
# Copyright (C) 2011 Marcin Hlybin
# All rights reserved.

use warnings;
use strict;
use 5.010;
use DBI;
use File::Path qw(rmtree);

# config
my $rdiff = '/rootnode/config/backup/rdiff.sh';
my $backup_dir = '/backup';
my $remove_older_than = '14D';

# usage
my $server_name = shift or die "Usage: $0 server_name\n";

# db
my $dbh = DBI->connect("dbi:mysql:rootnode;mysql_read_default_file=/root/.my.system.cnf",undef,undef,{ RaiseError => 1, AutoCommit => 1 });
my $db_backup_users = $dbh->prepare('SELECT login FROM uids WHERE block=0 AND del=0');
my $db_remove_users = $dbh->prepare('SELECT login FROM uids WHERE del=1');

sub check_backup {
	my($server_name, $user_name) = @_;
        my $last_backup = `/usr/bin/rdiff-backup --parsable-output -l $backup_dir/users/$user_name/$server_name 2>/dev/null | tail -1`;
        
	if($last_backup) {
                ($last_backup) = split(/\s+/,$last_backup);
                my @current = (localtime(time))[3,4,5];
                my @backup  = (localtime($last_backup))[3,4,5];
                
                if(@current ~~ @backup) {
                        # we have current backup 
			return 1;
                }
        }       
	return;	
}

# create backup
$db_backup_users->execute;
while(my($user_name) = $db_backup_users->fetchrow_array) {
        print $user_name.'...';

	# check for current backup
	if(check_backup($server_name, $user_name)) {
		print "current\n";
		next;
	}

        # rdiff-backup
        system("/bin/bash $rdiff $server_name $user_name");
        print $? ? "error" : "done" . "\n";
	
	# interrupted initial backup
	if($? == 256) {
		rmtree("$backup_dir/users/$user_name");
	} elsif($?) {
		print "$user_name (error $?)\n";
	}
	last;
}

# remove old users
$db_remove_users->execute;
while(my($user_name) = $db_remove_users->fetchrow_array) {
        if(-d "$backup_dir/users/$user_name") {        
                print $user_name.' ';
                rmtree("$backup_dir/users/$user_name") && print "removed\n";
        }       
}

# remove old backups
$db_backup_users->execute;
while(my($user_name) = $db_backup_users->fetchrow_array) {
	if(check_backup($server_name, $user_name)) {
		system("/usr/bin/rdiff-backup -v0 --remove-older-than $remove_older_than $backup_dir/users/$user_name/$server_name"); 	
	}	
}

#!/usr/bin/perl

# backup script
# Rootnode http://rootnode.net
#
# Copyright (C) 2011 Marcin Hlybin
# All rights reserved.

use warnings;
use strict;
use 5.010;
use DBI;
use YAML qw(LoadFile);
use File::Path qw(rmtree);

# config
my $config_file = 'backup.yaml';
-f $config_file or die "Config file not found!\n";
my $yaml = YAML::LoadFile($config_file);
my $rdiff = '/bin/bash /rootnode/config/backup/rdiff.sh';
my $backup_dir = '/backup';
my $remove_older_than = '14D';
my $hostname = `hostname -s`;
chomp $hostname;

# interactive mode
my $debug = ! system('tty -s');

sub check_backup {
        my($server_name, $user_name) = @_;
	my $last_backup;

	if(defined $user_name) {
        	$last_backup = `$rdiff -l -u $user_name $server_name`;
	} else {
		$last_backup = `$rdiff -l $server_name`;
	}
        
	chomp $last_backup;

        if($last_backup) {
                my @current = (localtime(time))[3,4,5];
                my @backup  = (localtime($last_backup))[3,4,5];

                if(@current ~~ @backup) {
                        # we have current backup 
                        return 1;
                }
        }
        return;
}

sub check_errors {
	my($error_code,$backup_path) = @_;
	
	if($error_code == 256) {
		# interrupted initial backup
		rmtree($backup_path);
	} elsif($error_code) {
		return $error_code;
	}
	
	return;
}

# system backups
foreach my $server_name ( @{ $yaml->{$hostname}->{system} } ) {
	$debug and print "system backup => $server_name...";

	my $backup_path="$backup_dir/system/$server_name";
	
	# check for current backup
	if(check_backup($server_name)) {
		$debug and print "current\n";
		next;
	}
	
	# rdiff-backup
	system("$rdiff $server_name");
	$debug and print $? ? "error\n" : "done\n";

	# errors
	if(check_errors($?,$backup_path)) {
		print "$server_name (error $?)\n";
	}
	
	# remove old backups
	if(check_backup($server_name)) {
		system("$rdiff -r $remove_older_than $server_name");
	}
} # system backups

# users backups
foreach my $server_name ( @{ $yaml->{$hostname}->{users} } ) {
	$debug and print "users backup => $server_name\n";	

	# db
	my $dbh = DBI->connect("dbi:mysql:rootnode;mysql_read_default_file=/root/.my.system.cnf",undef,undef,{ RaiseError => 1, AutoCommit => 1 });
	my $db_backup_users = $dbh->prepare('SELECT login FROM uids WHERE block=0 AND del=0 ORDER BY login');
	my $db_remove_users = $dbh->prepare('SELECT login FROM uids WHERE del=1 ORDER BY login');
	
	# create backup
	$db_backup_users->execute;
	while(my($user_name) = $db_backup_users->fetchrow_array) {
		$debug and print $user_name.'...';
		
		my $backup_path="$backup_dir/users/$user_name";

		# check for current backup
		if(check_backup($server_name, $user_name)) {
			$debug and print "current\n";
			next;
		}

		# rdiff-backup
		system("$rdiff -u $user_name $server_name");
		$debug and print $? ? "error\n" : "done\n";

		# errors
		if(check_errors($?,$backup_path)) {
			print "$user_name \@$server_name (error $?)\n";
		}
	}

	# remove old users
	$db_remove_users->execute;
	while(my($user_name) = $db_remove_users->fetchrow_array) {
		my $backup_path="$backup_dir/users/$user_name";
		if(-d $backup_path) {
			rmtree($backup_path);
		}
	}

	# remove old backups
	$db_backup_users->execute;
	while(my($user_name) = $db_backup_users->fetchrow_array) {
		if(check_backup($server_name, $user_name)) {
			system("$rdiff -r $remove_older_than -u $user_name $server_name");
		}
	}
} # users backups


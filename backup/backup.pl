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
use FindBin qw($Bin);
use File::Path qw(rmtree);

# config
my $config_file = shift || 'backup.yaml';
-f $config_file or die "Config file not found!\n";
my $yaml = YAML::LoadFile($config_file);

my $rdiff     = '/bin/bash $Bin/rdiff.sh';
my $mysqldump = '/bin/bash $Bin/mysqldump.sh';

my $mysql_config = '/root/.my.system.cnf';
my $backup_dir   = '/backup';

my $remove_older_than = '14D';

my $hostname = `hostname -s`;
chomp $hostname;

# interactive mode
my $debug = ! system('tty -s');
	
# db
my $dbh = DBI->connect("dbi:mysql:rootnode;mysql_read_default_file=$mysql_config",undef,undef,{ RaiseError => 1, AutoCommit => 1 });
my $db_backup_users = $dbh->prepare('SELECT login, uid FROM uids WHERE block=0 AND del=0 ORDER BY login');
my $db_remove_users = $dbh->prepare('SELECT login, uid FROM uids WHERE del=1 ORDER BY login');

sub check_backup {
        my($backup_type, $server_name, $user_name) = @_;
	my $last_backup;

	given($backup_type) [
		when('system') { $last_backup = `$rdiff -l $server_name` }
		when('users')  { $last_backup = `$rdiff -l -u $user_name $server_name` }
		when('mysql')  { $last_backup = `$rdiff -l -m $user_name $server_name` }
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

# system backups
foreach my $server_name ( @{ $yaml->{$hostname}->{system} } ) {
	$debug and print "system backup => $server_name...";

	my $backup_type='system';	
	my $backup_path="$backup_dir/$backup_type/$server_name";

	# check for current backup
	if(check_backup($backup_type,$server_name)) {
		$debug and print "current\n";
		next;
	}
	
	# rdiff-backup
	system("$rdiff $server_name");
	$debug and print $? ? "error\n" : "done\n";

	# errors
	if($?) {
		print "$server_name (error $?)\n";
	}
	
	# remove old backups
	if(check_backup($backup_type,$server_name)) {
		system("$rdiff -r $remove_older_than $server_name");
	}
} # system backups

# users backups
foreach my $server_name ( @{ $yaml->{$hostname}->{users} } ) {
	$debug and print "users backup => $server_name\n";	
	
	my $backup_type='users';

	# create backup
	$db_backup_users->execute;
	while(my($user_name) = $db_backup_users->fetchrow_array) {
		$debug and print $user_name.'...';
		
		my $backup_path="$backup_dir/$backup_type/$user_name";

		# check for current backup
		if(check_backup($backup_type, $server_name, $user_name)) {
			$debug and print "current\n";
			next;
		}

		# rdiff-backup
		system("$rdiff -u $user_name $server_name");
		$debug and print $? ? "error\n" : "done\n";

		# errors
		if($?) {
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
		if(check_backup($backup_type, $server_name, $user_name)) {
			system("$rdiff -r $remove_older_than -u $user_name $server_name");
		}
	}
} # users backups

# mysql backups
foreach my $server_name ( @{ $yaml->{$hostname}->{mysql} } ) {
	$debug and print "mysql backup => $server_name\n";

	my $backup_type='mysql';
	
	$db_backup_users->execute;
	while(my($user_name, $user_id) = $db_backup_users->fetchrow_array) {
		$debug and print $user_name.'...';

		my $backup_path = "$backup_dir/$backup_type/$user_name";	
		
		# check for current backup
		if(check_backup($backup_type, $server_name, $user_name)) {
			$debug and print "current\n";
			next;
		}

		# mysqldump
		system("$mysqldump $user_id $server_name");
		system("$rdiff -m $user_name $server_name");
	}
	
} # mysql backups

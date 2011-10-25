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
use feature 'switch';
use Data::Dumper;

# config
my $config_file = shift || 'backup.yaml';
-f $config_file or die "Config file not found!\n";
my $yaml = YAML::LoadFile($config_file);

my $rdiff     = "/bin/bash $Bin/rdiff.sh";
my $mysqldump = "/bin/bash $Bin/mysqldump.sh";

my $backup_dir   = '/backup';
my $mysql_config = '/root/.my.system.cnf';
my $mysql_tmp    = "$backup_dir/mysqltmp";

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

	given($backup_type) {
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
			$debug and print "\033[1;34mcurrent\033[0m\n";
                        return 1;
                }
        }
        return;
}

foreach my $backup_type (qw(system users mysql)) {
	foreach my $server_name ( @{ $yaml->{$hostname}->{$backup_type} } ) {
		if($backup_type eq 'system') {
			my $backup_path="$backup_dir/$backup_type/$server_name";
			$debug and print $backup_path.'.'x(60-length($backup_path));

			# check for current backup
			check_backup($backup_type, $server_name) and next;

			# rdiff-backup
			system("$rdiff $server_name");
			$debug and print $? ? "\033[1;31merror\033[0m\n" : "\033[1;32mdone\033[0m\n";
			
			# remove old backups
			if(check_backup($backup_type,$server_name)) {
				system("$rdiff -r $remove_older_than $server_name");
			}
		} else {
			$db_backup_users->execute;
			while(my($user_name,$user_id) = $db_backup_users->fetchrow_array) {
				my $backup_path="$backup_dir/$backup_type/$user_name";
				$debug and print $backup_path.'.'x(60-length($backup_path));

				# check for current backup
				check_backup($backup_type, $server_name, $user_name) and next;

				given($backup_type) {
					when('users') {
						# rdiff-backup
						system("$rdiff -u $user_name $server_name");
						$debug and print $? ? "\033[1;31merror\033[0m\n" : "\033[1;32mdone\033[0m\n";
					} # users
					when('mysql') {
                				# mysqldump
               					system("$mysqldump $user_id $server_name");
						$debug and print "dump: ".($? ? "\033[1;31merror\033[0m " : "\033[1;32mdone\033[0m ");
                				system("$rdiff -m $user_name $server_name");
						$debug and print "rdiff: ".($? ? "\033[1;31merror\033[0m\n" : "\033[1;32mdone\033[0m\n");
					}
				}
			} # while

			# remove old backups
			$db_backup_users->execute;
			while(my($user_name) = $db_backup_users->fetchrow_array) {
				if(check_backup($backup_type, $server_name, $user_name)) {
					system("$rdiff -r $remove_older_than -u $user_name $server_name");
				}
			} # while

			# remove old users
			$db_remove_users->execute;
			while(my($user_name) = $db_remove_users->fetchrow_array) {
				my $backup_path="$backup_dir/$backup_type/$user_name";
				rmtree($backup_path) if -d $backup_path;
			} # while
		} # if 
	} # server_name
} # backup_type

# cleanup
rmtree($mysql_tmp) if -d $mysql_tmp;

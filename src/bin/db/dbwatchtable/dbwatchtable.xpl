
##############################################################################
# Author: Glenn Thompson (GT)
#         ALASKA VOLCANO OBSERVATORY
#
# Created: 2009/02/20
#
# Modifications:
#
# Purpose:
#       watch a given table of a database and call another system command
#
# To do:
##############################################################################

use Datascope;
use Getopt::Std;

use strict;
use warnings;

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

# Usage - command line options and arguments
our ($opt_p, $opt_r, $opt_v); 
if ( ! &getopts('p:r:v') || $#ARGV != 1  ) {
    print  <<"EOU" ;

    Usage: $PROG_NAME [-p pffile] [-r recordno] [-v] database table

EOU
    exit 1 ;
}

# End of  GT Antelope Perl header
##############################################################################

#use File::Copy;
use File::stat;
#use English;
use Avoseis::Utils qw(getPf runCommand);

my ($database, $table) = @ARGV;

# read the parameter file
my ($last_record_only, $sleep_period, @commands) = &getParams($PROG_NAME, $opt_p, $opt_v);

# deal with switches and command line arguments here
my $nrowsprev = &counttablerows($database, $table);
if ($opt_r) {
	$nrowsprev = $opt_r;  
}
#print "PREV=$nrowsprev\n";
my $nrowsnow = 0;
  

# print out the time when the program starts
my $epochnow = str2epoch("now");
my $timestrnow = epoch2str( $epochnow, "%Y/%m/%d %H:%M" ); # epochtime now
print "\n###########  $PROG_NAME $timestrnow ##############\n\n";
my $watchfile = "$database.$table"; 
die("$PROG_NAME: $watchfile not found. Create (touch) before running this program again\n") unless (-e $watchfile);
print "$PROG_NAME: database $watchfile starting with $nrowsprev event records\n" ; 
my $inode_start = stat("$watchfile");

# force first run at startup after sleeping
my $mtimenow  = 0 ;
my $mtimeprev = 0 ;


# Sit and wait for new db records
for (;;) {
	if ( $mtimeprev != 0 ) {
		#print "sleeping for $sleep_period seconds\n" if $opt_v;
		sleep $sleep_period;
	} 
	my $inode = stat("$watchfile");
	my $mtimenow = $inode->mtime ; # when was origin table last modified?
	if ($mtimenow > $mtimeprev) {
		my $mtimestr = epoch2str($mtimenow,"%Y-%m-%d %H:%M:%S");
		print "$PROG_NAME: $watchfile has changed: modification time $mtimestr\n";
		$nrowsnow = &counttablerows($database, $table);

		print "$PROG_NAME: Number of table rows now is $nrowsnow, previously had $nrowsprev\n";
		if ($nrowsnow > $nrowsprev) {
			print "$PROG_NAME: Detected new records added to $watchfile\n";
			my $record;
			my @dbt = dbopen_table("$database.$table", "r");

			# Get to record to start at, which is either the first new record, or the last record, depending
			# on the value of $last_record_only in the parameter file (row is one more than record no)
			my $record_to_start_at = $nrowsprev;
			$record_to_start_at = ($nrowsnow - 1) if ($last_record_only);

			for ($record = $record_to_start_at; $record < $nrowsnow; $record++) {
				# read the table record and get the lddate
				$dbt[3] = $record;
				my ($lddate) = dbgetv(@dbt, "lddate");
				print "$PROG_NAME: record $record of $nrowsnow was created at ".epoch2str($lddate, "%Y/%m/%d %H:%M")."\n";
			
				# run all commands for this time window
				my $cmd;
				foreach $cmd (@commands) {
					my $cmd2 = $cmd;
					$cmd2 =~ s/TIME/$lddate/g; 
					$cmd2 =~ s/EVENTDB/$database/g; 
					$cmd2 =~ s/ALARMDB/$ENV{DBALARM}/g;
					$cmd2 =~ s/RECORDNO/$record/g;
					if ($cmd =~ /EVID/) {
						my $evid = dbgetv(@dbt, 'evid');
						$cmd2 =~ s/EVID/$evid/g;
					}
					if ($cmd =~ /ORID/) {
						my $orid = dbgetv(@dbt, 'orid');
						$cmd2 =~ s/ORID/$orid/g;
					}
					if ($cmd =~ /PREFOR/) {
						my $prefor = dbgetv(@dbt, 'prefor');
						$cmd2 =~ s/PREFOR/$prefor/g;
					}
					if ($cmd =~ /ALARMID/) {
						my $alarmid = dbgetv(@dbt, 'alarmid');
						$cmd2 =~ s/ALARMID/$alarmid/g;
					}

					my $runresult = &runCommand("$cmd2",1);
					print "$PROG_NAME: $runresult\n";
				}
			
			}
			dbclose(@dbt);
		}
		else
		{
			# start a new log file every time the database gets cut down
			if ($nrowsnow < $nrowsprev) {
				print "$PROG_NAME: Looks like $database.$table has been tailed\n";
			}
			else
			{
				my $mtimestr = epoch2str($mtimenow,"%Y-%m-%d %H:%M:%S");
				print "$PROG_NAME: no new record added, even though table was modified\n" if $opt_v;
			}

		}
		$nrowsprev = $nrowsnow;	 
	    $mtimeprev = $mtimenow;
	}
	$|++;
	print ".";

}
1;

###############################################
############# SUBROUTINES FOLLOW ##############
###############################################

sub getParams {
	my ($PROG_NAME, $opt_p, $opt_v) = @_;
	my $pfobjectref = &getPf($PROG_NAME, $opt_p, $opt_v);
	my ($last_record_only, $sleep_period, @commands); 

	@commands  = @{$pfobjectref->{'command_list'}};
	$last_record_only = $pfobjectref->{'last_record_only'};
	$sleep_period = $pfobjectref->{'sleep_period'};

	if ($opt_v) {
		print "COMMANDS = @commands\nlast_record_only = $last_record_only\nsleep_period=$sleep_period\n";
	}


 	return ($last_record_only, $sleep_period, @commands);
}


# count the rows in the table of the database (now also in SwarmAlarm.pm but not exported)
sub counttablerows {
	our $opt_v;
	my ($database, $table) = @_;
	print "Counting rows in $database.$table\n" if $opt_v;
	my @db     = dbopen( $database, "r" ) ;
	@db    = dblookup(@db, "", $table, "", "" ) ;
	my $nrows  = dbquery( @db, "dbRECORD_COUNT") ; # number of records in table
	dbclose(@db);
	return $nrows;
}


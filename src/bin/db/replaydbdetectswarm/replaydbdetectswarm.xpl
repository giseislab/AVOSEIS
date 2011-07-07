
##############################################################################
# Author: Glenn Thompson (GT)
#         ALASKA VOLCANO OBSERVATORY
#
# Created: 2009/05/15
#
# Modifications:
#
# Purpose:
#       #
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
our ($opt_v); 
if ( ! &getopts('v') || $#ARGV != 5  ) {
    print  <<"EOU" ;

    Usage: $PROG_NAME eventdbroot alarmdb starttime endtime timestep dbswarmdetectpf

	e.g.
	$PROG_NAME dbseg/Quakes alarms/alarmdb20090319RD 1237420800 1237852800 900 pf/dbdetectswarm_RD.pf



	-v	verbose mode on
EOU
    exit 1 ;
}

# End of  GT Antelope Perl header
##############################################################################

use Avoseis::SwarmAlarm;

my ($eventdbroot, $alarmdb, $starttime, $endtime, $timestep, $pf) = @ARGV;

# print out the time when the program starts
my $epochnow = str2epoch("now");
my $timestrnow = epoch2str( $epochnow, "%Y/%m/%d %H:%M" ); # epochtime now
print "\n###########  $PROG_NAME $timestrnow ##############\n\n";

unless (-e "$alarmdb") {
	&runCommand("cp /home/iceweb/run/dbalarm/alarm $alarmdb", 1);
}
foreach my $table qw(alarms alarmcomm alarmcache lastid) {
	&runCommand("touch $alarmdb.$table", 1) unless (-e $alarmdb.$table);
} 

my ($params, $result, $eventdb);
for (my $time = $starttime; $time < $endtime; $time += $timestep) {
	$eventdb = $eventdbroot .  epoch2str( $time, "_%Y_%m_%d");
	$params = "-p $pf -t $time -r ";
	$params .= " -v" if $opt_v;
	$result = &runCommand("dbdetectswarm $params $eventdb $alarmdb", 1);
	print "$result\n" if $opt_v;
}

1;


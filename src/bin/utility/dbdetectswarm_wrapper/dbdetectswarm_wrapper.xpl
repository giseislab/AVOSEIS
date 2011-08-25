

use Datascope;
use Getopt::Std;

use strict;
use warnings;

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

# Usage - command line options and arguments
#our ($opt_r);
if ( ! &getopts('') || $#ARGV != 3  ) {
    print STDERR <<"EOU" ;
	Usage:
		$PROG_NAME quakedb alarmdb swarmdb pffile 
EOU
	die("\n");
}

my @author_list = qw(WR_lo SP_lo RD_lo IL_lo AU_lo FO_lo SN_lo GR_lo KA_lo TR_lo MG_lo PL_lo AN_lo VE_lo PA_lo DU_lo SH_lo WE_lo AK_lo MA_lo OK_lo KO_lo GS_lo KN_lo TA_lo GA_lo SS_lo LS_lo);
my ($quakedb, $alarmdb, $swarmdb, $pffile) = @ARGV;

print "Looking for $pffile...";
if (-e $pffile) {
	foreach my $auth (@author_list) {
		print "author = $auth\n";
		system("dbdetectswarm  -p $pffile $quakedb $alarmdb $swarmdb $auth");
	}
}
else
{
	print "Not found. Skipping.\n";
}


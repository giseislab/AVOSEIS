

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

my @author_list = qw(WR SP RD IL AU FO SN GR KA TR MG PL AN VE PA DU SH WE AK MA OK KO GS KN TA GA SS LS);
my ($quakedb, $alarmdb, $swarmdb, $pffile) = @ARGV;

print "Looking for $pffile...";
if (-e $pffile) {
	foreach my $auth (@author_list) {
		print "author = $auth\n";
		system("computeEventRate -p $pffile $quakedb $swarmdb $auth");
	}
}
else
{
	print "Not found. Skipping.\n";
}


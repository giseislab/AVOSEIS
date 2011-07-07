
##############################################################################
# Author: Glenn Thompson (GT) 2010
#         ALASKA VOLCANO OBSERVATORY
#
##############################################################################

use Datascope;
use Getopt::Std;

use strict;
use warnings;

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

# Usage - command line options and arguments
our ($opt_p, $opt_v, $opt_d); 
if ( ! &getopts('p:vdr') || !( ($#ARGV == 0 ) || ($#ARGV == 2) ) ){
    print STDERR <<"EOU" ;

    Usage: $PROG_NAME [-p pffile] [-d] [-v] detection_table [tstart tend]

    For more information:
	> man $PROG_NAME	 
EOU
    exit 1 ;
}

# End of  GT Antelope Perl header
#################################################################
#use Avoseis::SwarmAlarm;

printf("\n**************************************\n\nRunning $PROG_NAME at %s\n\n", epoch2str(now(),"%Y-%m-%d %H:%M:%S")); 

#### COMMAND LINE ARGUMENTS

my $detection_table = $ARGV[0];
$detection_table.=".detection" unless ($detection_table =~ /detection$/);
die("database $detection_table does not exist\n") unless (-e $detection_table);
my @db = dbopen_table($detection_table, "r") or die("Cannot open $detection_table\n");

# array to hold detection hashes
my @detection;
my @stachan;

my $tstart = 0;
my $tend = 999999999999;
if ($#ARGV == 2) {
	$tstart = $ARGV[1];
	$tend = $ARGV[2];
}

@db = dbsubset(@db, "time > $tstart && time < $tend");


my $nrecs = dbquery(@db, "dbRECORD_COUNT");
print "Total detections = $nrecs\n";

# Load data into detection array
for (my $recno = 0; $recno < $nrecs; $recno++) {
	$db[3] = $recno;
	my ($thissta, $thischan, $thistime, $thissnr) = dbgetv(@db, "sta", "chan", "time", "snr");
	my %thisdetection;
	$thisdetection{"sta"} = $thissta;
	$thisdetection{"chan"} = $thischan;
	$thisdetection{"time"} = $thistime;
	$thisdetection{"snr"} = $thissnr;
	push @detection, %thisdetection;
	push @stachan, $thissta."_".$thischan;
}

# Sort by station-channel
my %count = &count_unique(@stachan);
foreach my $k (sort keys %count) {
    print "$k => $count{$k}\n";
}



sub count_unique {
    my @array = @_;
    my %count;
    map { $count{$_}++ } @array;

    # print them out:
    # map {print "$_ = ${count{$_}}\n"} sort keys(%count);
    return %count;
}


# array of the unique elements
sub return_unique {
    my @array = @_;
    my %count;
    map {$count{$_} = 1} @array;
    return sort keys(%count);
}

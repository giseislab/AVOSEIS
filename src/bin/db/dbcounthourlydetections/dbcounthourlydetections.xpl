
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

# Usage - command line options ad arguments
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
use POSIX;
use List::Util qw(min max);
printf("\n**************************************\n\nRunning $PROG_NAME at %s\n\n", epoch2str(now(),"%Y-%m-%d %H:%M:%S")) if $opt_v; 

#### COMMAND LINE ARGUMENTS

my $detection_table = $ARGV[0];
$detection_table.=".detection" unless ($detection_table =~ /detection$/);
die("database $detection_table does not exist\n") unless (-e $detection_table);

my @db = dbopen_table($detection_table, "r") or die("Cannot open $detection_table\n");
my $tstart = now() - 24*60*60; # default is to grab detections within last 24 hours only
my $tend = now();
if ($#ARGV == 2) { # if explicit time arguments given, use them
	$tstart = $ARGV[1];
	$tend = $ARGV[2];
}
else
{ # if called on a day database, load all
	if ($detection_table =~ /2[0-9][0-9][0-9]_[0-1][0-9]_[0-3][0_9]/) {
		$tstart = 0;
		$tend = 0;
	}
}

@db = dbsubset(@db, "time > $tstart && time < $tend");
my $nrecs = dbquery(@db, "dbRECORD_COUNT");
$db[3]=0;
my $starthour = floor(dbgetv(@db, "time")/3600)*3600;
$db[3]=$nrecs-1;
my $endhour = ceil(dbgetv(@db, "time")/3600)*3600;
printf "From %s to %s there are %d detections\n",epoch2str($starthour,"%Y-%m-%d %H:%M"), epoch2str($endhour,"%Y-%m-%d %H:%M"), $nrecs if $opt_v;
my %hash;

my $totalhours = ($endhour - $starthour) / 3600;
my $hourcount = 0;
for (my $hourcount = 0; $hourcount < $totalhours; $hourcount ++) {
	@db = dbopen_table($detection_table, "r");

	my $startthishour = $starthour + $hourcount * 3600;
	my $endthishour = $startthishour + 3600;
	@db = dbsubset(@db, "time > $startthishour && time < $endthishour");
	$nrecs = dbquery(@db, "dbRECORD_COUNT");
	printf "\nFrom %s to %s there are %d detections\n",epoch2str($startthishour,"%Y-%m-%d %H:%M"), epoch2str($endthishour,"%Y-%m-%d %H:%M"), $nrecs if $opt_v;


	# array to hold detection hashes
	my @detection = undef;
	my @stachan = undef;

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
	    #print "$k => $count{$k}\n";
	    my @hourlycountsat1stachan;
	    if (defined($hash{$k})) {
	    	@hourlycountsat1stachan = @{ $hash{$k} };
	    }
	    else
	    {
		for (my $h = 0; $h < $totalhours; $h++) {
			$hourlycountsat1stachan[$h] = 0;
		}
	    }
	    $hourlycountsat1stachan[$hourcount] = $count{$k};
	    $hash{$k} = \@hourlycountsat1stachan;
	}
}
dbclose(@db);

# print out the epoch times
print "UT Hour      (";
for (my $time = $starthour + 1800; $time < $endhour; $time += 3600) {
	printf " %s   ",epoch2str($time, "%H");
}
print ") TOTAL\n";

# print out whole %hash
foreach my $k (sort keys %hash) {
    my $total = 0;
    my @hourlycountsat1stachan = @{ $hash{$k} };
    my $max = max(@hourlycountsat1stachan);
    #if ($max >= 10) { 
	    my $kstr = $k;
	    while (length($kstr) < 12) {
		$kstr.=" ";
	    }
	    print "$kstr (" ;
	    foreach my $val (@hourlycountsat1stachan) {
		printf "%5d ",$val;
		$total += $val;
	    }
   	    printf ") %5d\n", $total; 
    #}	
}
1;

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

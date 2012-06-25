
##############################################################################
# Author: Glenn Thompson (GT) 2009
#         ALASKA VOLCANO OBSERVATORY
#
# History:
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
our ($opt_p, $opt_t, $opt_e, $opt_v, $opt_d, $opt_r); 
if ( ! &getopts('p:t:evdr') || $#ARGV < 2  ) {
    print STDERR <<"EOU" ;

    Usage: $PROG_NAME [-p pffile] [-e] [-t endtime] [-d] [-v] [-r] eventdb swarmdb volc_code

    For more information:
	> man $PROG_NAME	 
EOU
    exit 1 ;
}

# End of  GT Antelope Perl header
#################################################################
use POSIX qw(ceil);
#use Avoseis::SwarmTracker qw(make_swarmdb_descriptor loadEvents swarmStatistics);
use Avoseis::SwarmTracker qw(make_swarmdb_descriptor);
use Avoseis::Utils qw(getPf prettyprint floorMinute median);
#use Avoseis::AlarmManager;

printf("\n**************************************\n\nRunning $PROG_NAME at %s\n\n", epoch2str(now(),"%Y-%m-%d %H:%M:%S")); 

#### COMMAND LINE ARGUMENTS
my ($eventdb, $swarmdb, $volc_code) = @ARGV;
print "eventdb = $eventdb, swarmdb = $swarmdb, volc_code=$volc_code\n"; 

&make_swarmdb_descriptor($swarmdb);

my ($endTime); # end of timewindow to examine

# read parameter file
print "Reading parameter file for $PROG_NAME\n" if $opt_v;
my ($alarmclass, $alarmname, $msgdir, $msgpfdir, $volc_name, $twin, $auth_subset, $reminders_on, $escalation_on, $swarmend_on, $reminder_time, $newalarmref, $significantchangeref, $trackfile) = &getParams($PROG_NAME, $opt_p, $opt_v, $volc_code);


# read end epoch time or set to now
if ($opt_t) {
	$endTime = $opt_t;
}
else
{
	$endTime = floorMinute(now(),60);
}

# dereference refs to hash arrays
my (%currentMetrics);

# START TIME
my $startTime = $endTime - ( 60 * $twin);
printf "Timewindow of $twin minutes from %s to %s\n",epoch2str($startTime, "%Y-%m-%d %H:%M:%S"), epoch2str($endTime, "%Y-%m-%d %H:%M:%S");

# LOAD EVENT TIMES AND MAGNITUDES
my (@eventTime, @Ml);
printf("Load events from database $eventdb from %s to %s for author $auth_subset\n", epoch2str($startTime, "%Y-%m-%d %H:%M:%S"), epoch2str($endTime, "%Y-%m-%d %H:%M:%S")) if $opt_v;
loadEvents($eventdb, $startTime, $endTime, $auth_subset, \@eventTime, \@Ml, \%currentMetrics);
printf("Loaded %d events (Ml: @Ml)\n", $#Ml+1);

# GET STATISTICS FOR CURRENT TIME WINDOW
swarmStatistics(\@eventTime, \@Ml, $twin, \%currentMetrics);
print "\nStats for current time window\n" if $opt_v;
prettyprint(\%currentMetrics) if $opt_v;

# UPDATE METRICS TABLE
if ($currentMetrics{'mean_rate'} > 0) {
	my @dbsp = dbopen_table($swarmdb.".metrics","r+");
	print "Adding row to $swarmdb for $auth_subset\n";
	dbaddv(@dbsp, "auth", $auth_subset, "time", $startTime, "endtime", $endTime, "mean_rate", $currentMetrics{'mean_rate'}, "median_rate", $currentMetrics{'median_rate'}, "mean_ml", $currentMetrics{'mean_ml'}, "cum_ml", $currentMetrics{'cum_ml'});
	dbclose(@dbsp);
}

# Success
print "$PROG_NAME: Complete\n";
1;

###############################################################################
### LOAD PARAMETER FILE                                                      ##
### ($alarmclass, $alarmname, $msgdir, $msgpfdir, $volc_name, ...            ##  
###    $volc_code, $twin, $auth_subset, $reminders_on, $escalations_on, ...  ##
###    $cellphones_on, $reminder_time, $newalarmref, ...  ##
###    $significantchangeref) = getParams($PROG_NAME, $opt_p, $opt_v);       ##
###                                                                          ##
### Glenn Thompson, 2009/04/20                                               ##
###                                                                          ##
### Load the parameter file for this program, given its path                 ##
###############################################################################
sub getParams {

	my ($PROG_NAME, $opt_p, $opt_v, $volc_code) = @_;
	my $pfobjectref = &getPf($PROG_NAME, $opt_p, $opt_v);
print "opt_p = $opt_p\n";
     
	my ($alarmclass, $alarmname, $msgdir, $msgpfdir, $volc_name, $twin, $auth_subset, $reminders_on, $escalations_on, $swarmend_on, $reminder_time, $newalarmref, $significantchangeref, $trackfile); 

	# Generic parameters
	$alarmclass		= $pfobjectref->{'ALARMCLASS'};
 	$alarmname		= $alarmclass."_".$volc_code;
 	$msgdir			= $pfobjectref->{'MESSAGE_DIR'};
 	$msgpfdir		= $pfobjectref->{'MESSAGE_PFDIR'};
	$volc_name		= "unknown";
	$auth_subset		= $volc_code."_loMl";
	$twin			= $pfobjectref->{'TIMEWINDOW'};
	$reminders_on		= $pfobjectref->{'reminders_on'};
	$escalations_on		= $pfobjectref->{'escalations_on'};
	$swarmend_on		= $pfobjectref->{'swarmend_on'};
	$reminder_time		= $pfobjectref->{'REMINDER_TIME'};
	$newalarmref		= $pfobjectref->{'new_alarm'};
	$significantchangeref	= $pfobjectref->{'significant_change'};
	$trackfile		= "state/$alarmname.pf";

	# Now read any subnet specific overrides
	my $subnetsref 		= $pfobjectref->{'subnets'};
	my $subnetref 		= $subnetsref->{$volc_code};
	if (defined($subnetref->{'VOLC_NAME'})) {
       # addthisback 	$volc_name              = $$subnetref->{'VOLC_NAME'};
	}
	if (defined($subnetref->{'auth_subset'})) {
        	$auth_subset            = $$subnetref->{'auth_subset'};
	}
	if (defined($subnetref->{'new_alarm'})) {
        	$newalarmref            = $$subnetref->{'new_alarm'};
	}
	if (defined($subnetref->{'significant_change'})) {
        	$significantchangeref   = $$subnetref->{'significant_change'};
	}
	if (defined($subnetref->{'trackfile'})) {
        	$trackfile              = $$subnetref->{'trackfile'};
	}

	return ($alarmclass, $alarmname, $msgdir, $msgpfdir, $volc_name, $twin, $auth_subset, $reminders_on, $escalations_on, $swarmend_on, $reminder_time, $newalarmref, $significantchangeref, $trackfile); 
}

sub loadEvents {
        my ($dbname, $starttime, $endtime, $auth_subset, $eventtimeref, $Mlref, $currentStatsRef)  = @_;
        my (@db, @dbt, $recnum, $eventsDeclared, $eventsLocated);

        # Open and subset database
        @db = dbopen( $dbname , "r" );
        @db = dblookup(@db,"","origin","","");
        @db = dbsubset(@db,"(time<$endtime) && (time>$starttime)");
        @dbt = dblookup(@db,"","event","","");
        @db = dbjoin(@db,@dbt);
        @db = dbsubset(@db,"orid==prefor");
        $eventsDeclared = dbquery(@db,"dbRECORD_COUNT");
        my $subExp = '/.*'.$auth_subset.'.*/';
        @db = dbsubset(@db,"auth=~$subExp");            # revise for grid names
        $eventsLocated = dbquery(@db,"dbRECORD_COUNT");

        # Load events
        my ($sumEnergy, $energy, $cumMl, $minMl, $maxMl, $meanMl, $numMl, $sumMl, $lastTime, $nextTime, @timeDiff);
        for ($db[3]=0 ; $db[3]<$eventsLocated ; $db[3]++) {
                (${$eventtimeref}[$db[3]], ${$Mlref}[$db[3]]) = dbgetv(@db,"origin.time","ml");
        }

        # Close database
        dbclose(@db);

        # Populate %currentStats
        ${$currentStatsRef}{"events_declared"}  = $eventsDeclared;
        ${$currentStatsRef}{"events_located"}   = $eventsLocated;
        ${$currentStatsRef}{"timewindow_start"} = $starttime;
        ${$currentStatsRef}{"timewindow_end"}   = $endtime;

        return 1;
}

sub swarmStatistics {
        my ($eventtimeref, $Mlref, $timewindow, $currentStatsRef)  = @_;

        # INCIDENTAL PARAMETERS
        my ($sumEnergy, $energy, $numMl, $sumMl, $lastTime, $nextTime, @timeDiff);

        # RETURN PARAMETERS
        my ($meanRate, $medianRate, $cumMl, $minMl, $maxMl, $meanMl);

        # INITIALISE
        my $inf = 99999999.0;
        $minMl =  $inf;
        $maxMl = -$inf;
        $sumMl = 0;
        $numMl =   0;
        $cumMl = -$inf;
        $sumEnergy = 0;
        $lastTime = 0;
        $meanRate = 0;
        $medianRate = 0;
        $meanMl = -$inf;

        # PROCESS EVENTS (compute numMl, minMl, maxMl, sumEnergy, timeDiff)
        for (my $c=0 ; $c < ${$currentStatsRef}{"events_located"} ; $c++) {
                push( @timeDiff, ${$eventtimeref}[$c] - $lastTime );
                $lastTime = ${$eventtimeref}[$c];
                if ( (${$Mlref}[$c] > -2) && (${$Mlref}[$c] < 8) ) {
                        $numMl++;
                        $sumMl = $sumMl + ${$Mlref}[$c];
                        if (${$Mlref}[$c] < $minMl) {
                                $minMl = ${$Mlref}[$c];
                        }
                        if (${$Mlref}[$c] > $maxMl) {
                                $maxMl = ${$Mlref}[$c];
                        }

                        $energy = 10**(1.5 * ${$Mlref}[$c]); # cumulative magnitude computation verified with MATLAB
                        $sumEnergy += $energy;
                }
        }
        shift(@timeDiff);

        # COMPUTE medianRate, cumMl, meanMl, meanRate
        if ($numMl > 0) {
                if ($#timeDiff > 4) {
                        my ($medianDiff) = &median(@timeDiff);
                        $medianRate = POSIX::ceil(3600.0 / $medianDiff);
                }

                if ($sumEnergy > 0 ) {
                        $cumMl = sprintf("%.2f", POSIX::log10($sumEnergy) /1.5);
                }

                $meanMl = sprintf("%.2f", $sumMl / $numMl);
                $meanRate = ($numMl / $timewindow) * 60;
        }

        # APPEND ALL THE PARAMETERS COMPUTED TO THE currentStats HASH
        ${$currentStatsRef}{'mean_rate'} = $meanRate;
        ${$currentStatsRef}{'median_rate'} = $medianRate;
        ${$currentStatsRef}{'min_ml'} = $minMl;
        ${$currentStatsRef}{'mean_ml'} = $meanMl;
        ${$currentStatsRef}{'max_ml'} = $maxMl;
        ${$currentStatsRef}{'cum_ml'} = $cumMl;
        ${$currentStatsRef}{'num_ml'} = $numMl;

        return 1;

}


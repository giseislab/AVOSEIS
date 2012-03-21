
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
#use Avoseis::SwarmTracker;
#use Avoseis::Utils qw(getPf prettyprint floorMinute);
#use Avoseis::AlarmManager;

printf("\n**************************************\n\nRunning $PROG_NAME at %s\n\n", epoch2str(now(),"%Y-%m-%d %H:%M:%S")); 

#### COMMAND LINE ARGUMENTS
my ($eventdb, $swarmdb, $volc_code) = @ARGV;

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
my %new_alarm = %$newalarmref;
my %significant_change = %$significantchangeref;
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
	dbaddv(@dbsp, "auth", $auth_subset, "timewindow_starttime", $startTime, "timewindow_endtime", $endTime, "mean_rate", $currentMetrics{'mean_rate'}, "median_rate", $currentMetrics{'median_rate'}, "mean_ml", $currentMetrics{'mean_ml'}, "cum_ml", $currentMetrics{'cum_ml'});
	dbclose(@dbsp);
}

# Success
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

     
	my ($alarmclass, $alarmname, $msgdir, $msgpfdir, $volc_name, $twin, $auth_subset, $reminders_on, $escalations_on, $swarmend_on, $reminder_time, $newalarmref, $significantchangeref, $trackfile); 

	# Generic parameters
	$alarmclass		= $pfobjectref->{'ALARMCLASS'};
 	$alarmname		= $alarmclass."_".$volc_code;
 	$msgdir			= $pfobjectref->{'MESSAGE_DIR'};
 	$msgpfdir		= $pfobjectref->{'MESSAGE_PFDIR'};
	$volc_name		= "unknown";
	$auth_subset		= $volc_code."_lo";
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
        	$volc_name              = $$subnetref->{'VOLC_NAME'};
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


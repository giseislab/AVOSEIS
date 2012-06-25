
##############################################################################
# Author: Glenn Thompson (GT) 2009
#         ALASKA VOLCANO OBSERVATORY
#
# History:
#	2009-04-17: Created by GT, based on dbswarmdetect, a static threshold swarm detection module
# ADD FUNCTION TO READ CURRENT METRICS FORM metrics TABLE	
# need to add functionality to update swarm table.(see last function)
# also need to complete functionality to update state table.
# am I already reading the state table?
# finally, i don't want to be creating those parameter files anymore.
# lots of changes to make to declareAlarm and possibly other functions here,
# then there is the simplification and reorganisation of Avoseis::SwarmAlarm.
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
if ( ! &getopts('p:t:evdr') || $#ARGV !=2  ) {
    print STDERR <<"EOU" ;

    Usage: $PROG_NAME [-p pffile] [-e] [-t endtime] [-d] [-v] [-r] alarmdb swarmdb volc_code

    For more information:
	> man $PROG_NAME	 
EOU
    exit 1 ;
}

# End of  GT Antelope Perl header
#################################################################
use Avoseis::SwarmTracker qw(readStateTable);
use Avoseis::Utils qw(getPf prettyprint floorMinute);
#use Avoseis::AlarmManager;

printf("\n**************************************\n\nRunning $PROG_NAME at %s\n\n", epoch2str(now(),"%Y-%m-%d %H:%M:%S")); 

#### COMMAND LINE ARGUMENTS
my ($alarmdb, $swarmdb, $volc_code) = @ARGV;

# read parameter file
print "Reading parameter file for $PROG_NAME\n" if $opt_v;
my ($alarmclass, $alarmname, $msgdir, $msgpfdir, $volc_name, $twin, $auth_subset, $reminders_on, $escalation_on, $swarmend_on, $reminder_time, $newalarmref, $significantchangeref, $trackfile) = &getParams($PROG_NAME, $opt_p, $opt_v, $volc_code);


# dereference refs to hash arrays
my %new_alarm = %$newalarmref;
my %significant_change = %$significantchangeref;
my @stations = [];
my $dbgrid = "grids/dbgrid_".$auth_subset;
if (-e "$dbgrid.site") {
	my @dbs = dbopen_table("$dbgrid.site", "r");
	my $numstations = dbquery(@dbs, "dbRECORD_COUNT");
	if ($numstations > 0) {
		for (my $stanum = 0; $stanum < $numstations; $stanum++) {
			$dbs[3] = $stanum;
			$stations[$stanum] = dbgetv(@dbs, "sta");
		}
	}
	dbclose(@dbs);
}

# GET STATISTICS FOR TIME WINDOW CORRESPONDING TO PREVIOUS MESSAGE CORRESPONDING TO THIS ALARMNAME
# Read swarm_state table
my ($previousLevel) = readStateTable($swarmdb, $alarmname); # return -1 for no rows, 0 for "off", 1 for level 1, 2 for level 2...
print "Previous swarm state / alarm level for $alarmname is $previousLevel\n" if ($opt_v);
my ($previousSwarmIsOver, %currentMetrics, %previousMetrics, $agePreviousMessage);

# START TIME
my ($endTime); # end of timewindow to examine
# read end epoch time or set to now
if ($opt_t) {
        $endTime = $opt_t;
}
else
{
        $endTime = floorMinute(now(),60);
}
my $startTime = $endTime - ( 60 * $twin);
printf "Timewindow of $twin minutes from %s to %s\n",epoch2str($startTime, "%Y-%m-%d %H:%M:%S"), epoch2str($endTime, "%Y-%m-%d %H:%M:%S");

# assume there is not an ongoing swarm by default
$previousSwarmIsOver = 1;
$currentMetrics{'swarm_start'} = -1;
$currentMetrics{'swarm_end'} = '-1';
my ($alarmkey);

# assume prev loaded OK
if ($previousLevel > -1) { 
	#%previousMetrics = &readSwarmTable($swarmdb, $alarmname);
	%previousMetrics = &computereadSwarmTable($swarmdb, $alarmname);

	# display contents
	print "Stats for previous swarm message of alarmname $alarmname\n" if $opt_v;
	prettyprint(\%previousMetrics) if $opt_v;

	# IS THAT SWARM STILL CONSIDERED ACTIVE? CHECK ITS swarm_end PARAMETER
	if ( $previousMetrics{'swarm_end'} <= 0) {
		$previousSwarmIsOver = 0;
		if ($previousMetrics{'swarm_start'} > 0) {
			$currentMetrics{'swarm_start'} = $previousMetrics{'swarm_start'}; # swarm is ongoing still
		}
	}

	# WHAT IS THE DIFFERENCE BETWEEN TIME NOW AND TIME OF LAST ALARM
	$agePreviousMessage = ($endTime - $previousMetrics{'lddate'}) / 60; # in minutes
	printf "Previous message is %.0f minutes old\n", $agePreviousMessage; 
}
else
{
	$alarmkey = 0;
	$agePreviousMessage = 0;
}
print "Previous Swarm Over: $previousSwarmIsOver\n" if $opt_v;

my $eventdb; # needed for alarm delcarations
prettyprint(\%currentMetrics) if $opt_v;

# So far we have loaded the previous level or state of this swarm name / author. But we have not yet attempted to
# see if the swarm state/level has changed based on the new metrics we have computed.
########################################################

# CHECK FOR TEST MODE
if ($opt_d) {
	my $str = "test_$PROG_NAME";
	&declareAlarm($str, $str, \%currentMetrics, $volc_name, $startTime, $endTime, $eventdb, 
                \@stations, $alarmdb, $alarmclass, $alarmkey, $str, $msgdir, $msgpfdir);
	exit;
}

my $alarmSent = 0;

# are we above new swarm alarm threshold?
my $currentLevel = &compareLevels(\%currentMetrics, \%new_alarm, \%significant_change, $opt_v);

# Any change in level?
if ($currentLevel ne $previousLevel) {

	# swarm state / level has changed, so we need to update the state table and the swarm table
	&updateStateTable($swarmdb, \%currentMetrics, $alarmname, $currentLevel); 

	# New swarm?
	if ($previousLevel < 1) {
		print "THERE IS NO ACTIVE SWARM\nCHECKING FOR NEW SWARM\n";
		# CHECK IF A NEW SWARM HAS BEGUN
		if ($currentLevel > 0) {
			# declare new swarm alarm
			print "Declaring a new alarm\n" if $opt_v;
			$currentMetrics{'swarm_start'} = $startTime;
			$currentMetrics{'swarm_end'} = -1;
			&declareAlarm("start", "New Swarm", \%currentMetrics, $volc_name, $startTime, $endTime, $eventdb, 
	        		\@stations, $alarmdb, $alarmclass, $alarmkey, $alarmname, $msgdir, $msgpfdir);
		}
	}
	else
	{ # swarm is still active, but has it ended, or escalated? or do we need to send a reminder? 
		print "THERE IS AN ACTIVE SWARM\n";
		if ($currentLevel == 0) { # end swarm. 
			# We do not want to declare the swarm as over until at least $twin minutes have passed since start of swarm, otherwise we get too many swarms
			if ( ($endTime - $previousMetrics{'swarm_start'}) > (2 * $twin) ) {	# HERE LOOKS LIKE 2 * TIMEWINDOW!!	
				# DECLARE SWARM OVER
				print "DECLARING SWARM OVER\n";
				$currentMetrics{'swarm_end'} = $endTime;
				&declareAlarm("end", "Swarm Over", \%currentMetrics, $volc_name, $startTime, $endTime, $eventdb, 
	                               \@stations, $alarmdb, $alarmclass, $alarmkey, $alarmname, $msgdir, $msgpfdir) if $swarmend_on;
			}
			else
			{
				print "Swarm may have ended, but timeout period not lapsed yet.\n";
			}
		}
		elsif ($currentLevel > $previousLevel)
		{
			print "DECLARING SWARM ESCALATION\n";
			&declareAlarm("escalation", "Swarm Escalation", \%currentMetrics, $volc_name, $startTime, $endTime, $eventdb, 
	                                            \@stations, $alarmdb, $alarmclass, $alarmkey, $alarmname, $msgdir, $msgpfdir) if $escalation_on;
		}
		else 
		{			
			# CHECK WHETHER TO SEND A REMINDER
			print "SWARM CONTINUING BUT HAS NOT ESCALATED\nCHECKING TO SEE IF IT IS TIME TO SEND A REMINDER\n";

			if ($agePreviousMessage > $reminder_time) {
				# declare swarm reminder warning
				print "DECLARING A REMINDER\n";
				&declareAlarm("reminder", "Swarm Continuing", \%currentMetrics, $volc_name, $startTime, $endTime, $eventdb, 
	                                                   \@stations, $alarmdb, $alarmclass, $alarmkey, $alarmname, , $msgdir, $msgpfdir) if $reminders_on;
			}
		}

	}


}
# Success
1;
#########################################################

sub declareAlarm {
	my ($msgType, $subject, $currentref, $volc_name, $startTime, $endTime, $eventdb, $stationsref, $alarmdb, $alarmclass, $alarmkey, $alarmname, $msgdir, $msgpfdir) = @_;

	my $endTimeLOCAL  = epoch2str($endTime,'%k:%M:%S %z','US/Alaska');

	# compose Subject
	print "Compose subject\n" if $opt_v;
	$subject = "\'$subject $volc_name $endTimeLOCAL\'";
	
	# composeMessage
	print "Compose message\n" if $opt_v;
	my $txt = &composeMessage($msgType, $currentref,  $startTime, $endTime, $eventdb, $stationsref); 

	# getMessagePath
	print "Get path to write message to\n" if $opt_v;
	my ($mdir, $mdfile) = &getMessagePath($endTime, $msgdir, $alarmname);

	# writeMessage file
	print "Writing message to $mdir/$mdfile\n" if $opt_v;
	&writeMessage($mdir, $mdfile, $txt);

	# addAlarmsRow
	print "Get next alarmid\n" if $opt_v;
	my $alarmid = `dbnextid $alarmdb alarmid`; 
	chomp($alarmid);
	$alarmkey = $alarmid if ($msgType eq "start" || $msgType eq "test");
	print "Writing alarms row\n" if $opt_v;
	#my $alarmtime = $startTime;
	#$alarmtime = $endTime if ($msgType eq "end");
	&writeAlarmsRow($alarmdb, $alarmid, $alarmkey, $alarmclass, $alarmname, $endTime, $subject, $mdir, $mdfile);

	# getMessagePfPath
	print "Get path to write parameter file to\n" if $opt_v;	
	my ($mpfdir, $mpfdfile) = &getMessagePfPath($endTime, $msgpfdir, $alarmname);

	# addAlarmcacheRow
	print "Writing alarmcache row\n" if $opt_v;
	&writeAlarmcacheRow($alarmdb, $alarmid, $mpfdir, $mpfdfile);

	# putSwarmParams
	print "put swarm parameters to $mpfdir/$mpfdfile\n" if $opt_v;
	$currentMetrics{'message_type'} = $msgType;
	&putSwarmParams($mpfdir, $mpfdfile, %currentMetrics);

	# NOW CALL alarm_dispatch TO SEND THE MESSAGE
	#print "call alarmdispatch\n" if $opt_v;
	#&runCommand("dbalarmdispatch -v -p pf/dbalarmdispatch -t $endTime $alarmkey $alarmdb", 1); # alarmdispatch now run whenever alarms table has new row added

}


###############################################################################
### LOAD PARAMETER FILE                                                      ##
### ($alarmclass, $alarmname, $msgdir, $msgpfdir, $volc_name, ...            ##  
###    $volc_code, $twin, $auth_subset, $reminders_on, $escalations_on, ...  ##
###    $cellphones_on, $reminder_time, $newalarmref, ...  ##
###    $significantchangeref) = getParams($PROG_NAME, $opt_p, $opt_v);       ##
###                                                                          ##
### Glenn Thompson, 2009/04/20                                               ##
###                                                                          ##
### Load the parameter file for this program, given it's path                ##
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
        	$volc_name              = $subnetref->{'VOLC_NAME'};
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





sub compareLevels {
	my ($dataref, $thresholdref) = @_;
	my %data = %{$dataref};
	my %threshold = %{$thresholdref};

	my $triggered = 0;
	print $data{'mean_rate'}, "\n";
	print $threshold{'mean_rate'}, "\n";
	if (   $data{'mean_rate'} >= $threshold{'mean_rate'}  ) {
		$triggered = 1;
	
		# TEST MEDIAN RATE
		if (  defined($significant_change{'median_rate_pcchange'})   ) {
			$triggered = 0 if ($data{'median_rate'} < $threshold{'median_rate'});
		}


		# TEST MEAN ML
		if (defined($significant_change{'mean_ml_change'})) {
			$triggered = 0 if ($data{'mean_ml'} < $threshold{'mean_ml'});
		}

		# TEST CUMULATIVE ML
		if (defined($significant_change{'cum_ml_change'})) {
			$triggered = 0 if ($data{'cum_ml'} < $threshold{'cum_ml'});
		}
		
	}
	return $triggered;
}

sub changeThreshold {
	my ($thresholdref, $significantChangeRef, $epsilon) = @_;
	my %threshold = %{$thresholdref};
	my %significant_change = %{$significantChangeRef};
	my %newthreshold;
	my $fraction;

	# MEAN RATE
	$fraction = sprintf("%.2f",1.0 + $significant_change{'mean_rate_pcchange'}/100.0);
	if ($epsilon == 1) {
		$newthreshold{'mean_rate'} = $threshold{'mean_rate'} * $fraction;
	}
	else
	{
		$newthreshold{'mean_rate'} = $threshold{'mean_rate'} / $fraction;

	}


	# MEDIAN RATE
	if (defined($significant_change{'median_rate_pcchange'})   && defined($threshold{'median_rate'}) ) {
		$fraction = sprintf("%.2f",1.0 + $significant_change{'median_rate_pcchange'}/100.0);
		if ($epsilon == 1) {
			$newthreshold{'median_rate'} = $threshold{'median_rate'} * $fraction;
		}
		else
		{
			$newthreshold{'median_rate'} = $threshold{'median_rate'} / $fraction;
	
		}
	}

	# MEAN ML
	if (defined($significant_change{'mean_ml_change'})   && defined($threshold{'mean_ml'})) {
		$newthreshold{'mean_ml'} = $threshold{'mean_ml'} + $epsilon * $significant_change{'mean_ml_change'};
	}

	# CUMULATIVE ML
	if (defined($significant_change{'cum_ml_change'})  && defined($threshold{'cum_ml'}) ) {
		$newthreshold{'cum_ml'} = $threshold{'cum_ml'}  + $epsilon * $significant_change{'cum_ml_change'};
                if ($@){
                        print "Problem with cumulative ml\n";
                };

	}
	return %newthreshold;
}

sub getLastSwarm {
#prev    &Arr{
#    cum_ml      1.19
#    events_declared     2
#    events_located      2
#    max_ml      0.99
#    mean_ml     0.98
#    mean_rate   2
#    median_rate 0
#    message_type        end
#    min_ml      0.98
#    num_ml      2
#    swarm_end   1277303400.58837
#    swarm_start 1277286000.46597
#    timewindow_end      1277303400.58837
#    timewindow_start    1277299800.58837
#}

	# return hash array describing last swarm
	my ($swarmdb, $alarmname) = @_;
	my %previousMetrics = {};
	my @dbs = dbopen_table("$swarmdb.swarm", "r");
	@dbs = dbsubset(@dbs, "auth =='$alarmname'");
	my $numrecords = dbquery(@dbs, "dbRECORD_COUNT");
	if ($numrecords > 0) {
		$dbs[3] = ($numrecords-1);
		my ($auth, $time, $endtime, $highestLevel, $num_earthquakes, $num_located, $message_type, $num_ml, $min_ml, $max_ml, $mean_rate, $median_rate, $mean_ml, $cum_ml, $lddate) = dbgetv(qw(auth time endtime highestLevel numearthquakes num_located message_type num_ml min_ml max_ml mean_rate median_rate mean_ml cum_ml lddate));
		$previousMetrics{'auth'} = $auth;
		$previousMetrics{'swarm_start'} = $time;
		$previousMetrics{'swarm_end'} = $endtime;
		$previousMetrics{'highestLevel'} = $highestLevel;
		$previousMetrics{'num_earthquakes'} = $num_earthquakes;
		$previousMetrics{'num_located'} = $num_located;
		$previousMetrics{'message_type'} = $message_type;
		$previousMetrics{'num_ml'} = $num_ml;
		$previousMetrics{'min_ml'} = $min_ml;
		$previousMetrics{'max_ml'} = $max_ml;
		$previousMetrics{'mean_ml'} = $mean_ml;
		$previousMetrics{'cum_ml'} = $cum_ml;
		$previousMetrics{'mean_rate'} = $mean_rate;
		$previousMetrics{'median_rate'} = $median_rate;
		$previousMetrics{'lddate'} = $lddate;
	}
	dbclose(@dbs);
	return %previousMetrics;
}

sub updateStateTable {
	my ($swarmdb, $alarmname, $currentLevel) = @_; 

	# UPDATE THE STATE TABLE
	my @dbs = dbopen_table("$swarmdb.state", "r+");
	@dbs = dbsubset(@dbs, "auth =='$alarmname'");
	my $numrecords = dbquery(@dbs, "dbRECORD_COUNT");
	if ($numrecords == -1) {	
		# ADD A NEW ROW HERE (THIS ALARM NAME HAS NOT BEEN RECORDED BEFORE)
		$dbs[3] = 0;
		dbaddv(@dbs, "level", $currentLevel);
	} else {
		# AMEND EXISTING ROW (THIS ALARM NAME HAS BEEN RECORDED BEFORE)
		dbputv(@dbs, "level", $currentLevel);
	}
	dbclose(@dbs);
}

sub updateSwarmTable {
	# No alarming takes place based on the swarm table (at least in this program).
	# Its only purpose is to serve as an easy summary of the statistics of a swarm,
	# detected by this program.
	# The metrics recorded should be consistent with those produced by running the
	# CATALOG class in MATLAB. 
	# A swarm should be updated anytime there is an ongoing swarm (previousLevel > 0)
	# These data are only reported whenever there is a new alarm. But they can be
	# viewed with dbe even while there is an ongoing swarm.

	# This function is a template only currently.
	# The idea is to compute metrics for the whole swarm in exactly the same way as it
	# is done for a timewindow: i.e. using loadEvents and swarmStatistics.
	# Then all that is left is to write the data to the table.

	# Note that a swarm may be new (create with dbaddv, or it may be ongoing (update with dbputv).

	my ($swarmdb, $currentMetricsRef, $alarmname, $currentLevel) = @_; 

	# LOAD EVENT TIMES AND MAGNITUDES
	my (@eventTime, @Ml);
	printf("Load events from database $eventdb from %s to %s for author $auth_subset\n", epoch2str($startTime, "%Y-%m-%d %H:%M:%S"), epoch2str($endTime, "%Y-%m-%d %H:%M:%S")) if $opt_v;
	loadEvents($eventdb, $startTime, $endTime, $auth_subset, \@eventTime, \@Ml, \%currentMetrics);

	# GET STATISTICS FOR CURRENT TIME WINDOW
	swarmStatistics(\@eventTime, \@Ml, $twin, \%currentMetrics);
	print "\nStats for current time window\n" if $opt_v;
	prettyprint(\%currentMetrics) if $opt_v;


	my @dbs = dbopen_table("$swarmdb.swarm", "r");
	@dbs = dbsubset(@dbs, "auth =='$alarmname'");
	my $numrecords = dbquery(@dbs, "dbRECORD_COUNT");
	if ($numrecords > 0) {
		$dbs[3] = ($numrecords-1);
		my ($auth, $time, $endtime, $highestLevel, $num_earthquakes, $num_located, $message_type, $num_ml, $min_ml, $max_ml, $mean_rate, $median_rate, $mean_ml, $cum_ml, $lddate) = dbgetv(qw(auth time endtime numearthquakes num_located message_type num_ml min_ml max_ml mean_rate median_rate mean_ml cum_ml lddate));
		$auth = $previousMetrics{'auth'};
		$time = $previousMetrics{'swarm_start'};
		$endtime = $previousMetrics{'swarm_end'};
		if ($currentLevel > $previousMetrics{'highestLevel'}) {
			$highestLevel = $currentLevel;
		}
		$num_earthquakes = $previousMetrics{'num_earthquakes'};
		$previousMetrics{'num_located'} = $num_located;
		$previousMetrics{'message_type'} = $message_type;
		$previousMetrics{'num_ml'} = $num_ml;
		$previousMetrics{'min_ml'} = $min_ml;
		$previousMetrics{'max_ml'} = $max_ml;
		$previousMetrics{'mean_ml'} = $mean_ml;
		$previousMetrics{'cum_ml'} = $cum_ml;
		$previousMetrics{'mean_rate'} = $mean_rate;
	}

	# UPDATE THE SWARM TABLE
	@dbs = dbopen_table("$swarmdb.swarm", "r+");
	@dbs = dbsubset(@dbs, "auth =='$alarmname'");
	$numrecords = dbquery(@dbs, "dbRECORD_COUNT");
	if ($numrecords == -1) {	
		# ADD A NEW ROW HERE (THIS ALARM NAME HAS NOT BEEN RECORDED BEFORE)
		$dbs[3] = 0;
		dbaddv(@dbs, "level", $currentLevel);
	} else {
		# AMEND EXISTING ROW (THIS ALARM NAME HAS BEEN RECORDED BEFORE)
		dbputv(@dbs, "level", $currentLevel);
	}
	dbclose(@dbs);
}

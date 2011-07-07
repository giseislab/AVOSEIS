package Avoseis::SwarmAlarm;

#use 5.000000;
use strict;
use warnings;

require Exporter; 

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Avoseis::SwarmAlarm ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

# variable names
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

# subroutines
our @EXPORT = qw( 
getPf 
prettyprint
countStationHits 
median 
runCommand 
loadEvents 
swarmStatistics
getPrevMsgPfPath
composeMessage
getSwarmParams
putSwarmParams
writeAlarmsRow
writeAlarmcacheRow
getMessagePath   
writeMessage 
getMessagePfPath 
watchtable	
);

#our $VERSION = '0.01';
our $VERSION = sprintf "%d.%03d", q$Revision: 1.5 $ =~ /: (\d+)\.(\d+)/;

use Datascope;
use POSIX qw(log10 ceil);

# globals


# Preloaded methods go here.

###############################################################################
### LOAD PARAMETER FILE                                                      ##
### ($alarmclass, $alarmname, $msgdir, $msgpfdir, $volc_name, ...            ##  
###    $volc_code, $twin, $auth_subset, $reminders_on, $escalations_on, ...  ##
###    $cellphones_on, $reminder_time, $stathresholdsref, $newalarmref, ...  ##
###    $significantchangeref) = getPf($parameterfile);                       ##
###                                                                          ##
### Glenn Thompson, 2009/04/20                                               ##
###                                                                          ##
### Load the parameter file for this program, given it's path                ##
###############################################################################
sub getPf {
	my ($PROG_NAME, $opt_p, $opt_v) = @_;

	my ($pfile, $pfobjectref);

	# Get parameter file object reference from all files that match $PROG_NAME.pf along PFPATH cascade
	my @pfilearr = `pfwhich $PROG_NAME`; # get a list of all pfiles in cascade
	if ($#pfilearr > -1) {
		$pfile = $pfilearr[$#pfilearr]; chomp($pfile); # get the last pfile in the cascade
		if (-e $pfile) { # if pfile exists, read from it
			$pfobjectref = pfget($pfile, ""); # read all parameters from pfile into a hash ref
		}
	}

	# Override with parameters from a parameter file of a different name if -p option used
	if ($opt_p) {
	     	$pfile = $opt_p;
			if (-e $pfile) { # if pfile exists, read from it
			$pfobjectref = pfget($pfile, ""); # read all parameters from pfile into a hash ref
		}
	}
	
	# Display parameters if verbose mode is on
	if ($opt_v) {
		prettyprint($pfobjectref);
	} 
 
	return $pfobjectref;

}


######################################################
### PRETTY PRINT A HASH                             ##
### prettyprint(\%myhash);                          ##
###                                                 ##
### Glenn Thompson, 2009/05/04 after code from BRTT ##
###                                                 ##
######################################################
sub prettyprint {
        my $val = shift;
        my $prefix = "";
        if (@_) { $prefix = shift ; }

        if (ref($val) eq "HASH") {
                my @keys = sort ( keys  %$val );
                my %hash = %$val;
                foreach my $key (@keys) {
                        my $newprefix = $prefix . "{". $key . "}" ;
                        prettyprint ($hash{$key}, $newprefix) ;
                }
        } elsif (ref($val) eq "ARRAY") {
                my $i = 0;
                my @arr = @$val;
                foreach my $entry ( @$val ) {
                        my $newprefix = $prefix . "[". $i . "]" ;
                        prettyprint ($arr[$i], $newprefix) ;
                        $i++;
                }
        } else {
                print $prefix, " = ", $val, "\n";
        }
}

###############################################################################
### EVENT ARRIVALS PER STATION                                               ##
### %staHits = countStationHits($dbname, $startTime, $endTime, @stations); ##
###                                                                          ##
### Glenn Thompson, 2009/04/20                                               ##
###                                                                          ##
### Calculate the number of events for which there is                        ##
### an associated arrival for a station. Do this for                         ##
### an array of stations.                                                    ##
###############################################################################
sub countStationHits {
	my ($dbname, $startTime, $endTime, @stations) = @_;
	my (@db, @dbt, $hits, $rate, $sta, %staHits);
	foreach $sta (@stations) {
		@db = dbopen( $dbname , "r" );
		@db = dblookup(@db,"","arrival","","");
		@db = dbsubset(@db,"sta=~/$sta/");
		@db = dbsubset(@db,"(time<$endTime) && (time>$startTime)");
		@dbt = dblookup(@db,"","assoc","","");
		@db = dbjoin(@db,@dbt);
		@dbt = dblookup(@db,"","origin","","");
		@db = dbjoin(@db,@dbt);
		@dbt = dblookup(@db,"","event","","");
		@db = dbjoin(@db,@dbt);
		@db = dbsubset(@db,"orid==prefor");
		$staHits{$sta} = dbquery(@db,"dbRECORD_COUNT");
		dbclose(@db);
	}
	return (%staHits);
}


##########################################################
### MEDIAN                                              ##
### $median = median(@values);                          ##
###                                                     ##
### Mike West, 2009/01                                  ##
###                                                     ##
### Calculate the median value of a numeric array       ##
##########################################################
sub median {
	#@_ == 1 or die ('Sub usage: $median = median(\@array);');
	my (@array) = @_;
	@array = sort { $a <=> $b } @array;
	my $count = $#array;
	if ($count % 2) {
		return ($array[$count/2] + $array[$count/2 - 1]) / 2;  # odd
	} else {
		return $array[int($count/2)];	# even no. of elements in array ($count is odd!)
	}
} 

#############################################################
### RUNCOMMAND                                             ##
### $result = runCommand($cmd, $mode);                     ##
###                                                        ##
### Glenn Thompson, 2009/04/20                             ##
###                                                        ##
### Run a command safely at Unix shell, and return result. ##
### mode==0 just echoes the command and is for debugging.  ##
### mode==1 echoes & runs the command.                     ##
#############################################################
sub runCommand {     
     my ( $cmd, $mode ) = @_ ;
     our $PROG_NAME;

     print "$0: $cmd\n";
     my $result = "";
     $result = `$cmd` if $mode;
     chomp($result);
     $result =~ s/\s*//g;

     if ($?) {
         print STDERR "$cmd error $? \n" ;
     	 # unknown error
         exit(1);
     }

     return $result;
}

#####################################################################################################
### loadEvents                                                                                    ##
### loadEvents($dbname, $starttime, $endtime, $auth_subset, \@eventtime, \@Ml, \%currentStats);   ##
###                                                                                                ##
### Glenn Thompson, 2009/04/20                                                                     ##
###                                                                                                ##
### Given an event database, start and end times and an author name, load the corresponding event  ##
### times and magnitudes into arrays passed by reference                                           ##
###                                                                                                ##
### This function adds new fields to %currentStats (passed by reference) including:                ##
### events_declared, events_located, timewindow_start, timewindow_end                              ##
#####################################################################################################
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
	@db = dbsubset(@db,"auth=~$subExp");		# revise for grid names
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


########################################################################
### swarmStatistics                                                  ##
### swarmStatistics(@eventTime, @Ml, $timewindow, \%currentStats);   ##
###                                                                   ##
### Glenn Thompson, 2009/04/20                                        ##
###                                                                   ##
### Compute event statistics for the current timewindow, given the    ##
### arrays of event times and magnitudes.                             ##
### This function adds new fields to %currentStats including:         ##
### mean_rate, median_rate, min_ml, max_ml, mean_ml, cum_ml, num_ml   ##
########################################################################
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
			$medianRate = ceil(3600.0 / $medianDiff);
		}

		if ($sumEnergy > 0 ) {
			$cumMl = sprintf("%.2f", log10($sumEnergy) /1.5);
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


#####################################################################################################
### composeMessage                                                                                 ##
### $txt = composeMessage($msgType, \%currentStats, $startTime, $endTime, $dbname, \@stations);    ##
###                                                                                                ##
### Glenn Thompson, 2009/04/20                                                                     ##
###                                                                                                ##
### Compose a message, based on event statistics for                                               ##
### the current timewindow, and the message type                                                   ##
#####################################################################################################
sub composeMessage {
	my ($msgtype, $currentStatsRef, $startTime, $endTime, $dbname, $stationsref)  = @_;

	my (%current) = %{$currentStatsRef};

	my ($txt, $txtMeanRate, $txtMedianRate, $txtMinMl, $txtMaxMl, $txtMeanMl, $txtCumMl);
	my $endTimeUTC    = epoch2str($endTime,'%Y/%m/%d %k:%M:%S UTC');
	my $twinStr = sprintf("%2.0f", ($endTime-$startTime)/60 );
	
	$txt = "$endTimeUTC\nSpan: $twinStr minutes\n";


	if ($current{"mean_rate"} > 0) {
		$txtMeanRate = sprintf("Mean Rate: %2.0f/hr\n", $current{"mean_rate"});
	} else {
		$txtMeanRate = "Mean Rate: NA\n";
	}

	if ($current{"median_rate"} > 0) {
		$txtMedianRate = sprintf("Median Rate: %2.0f/hr\n", $current{"median_rate"});
	} else {
		$txtMedianRate = "Median Rate: NA\n";
	}

	if ($current{"cum_ml"} > 0 && $current{"cum_ml"} < 8) {
		$txtCumMl = sprintf("Cum Ml: %3.1f\n",$current{"cum_ml"});
	} else {
		$txtCumMl = "NA";
	}
	
	if ($current{"mean_ml"} > 0) {
		$txtMeanMl = sprintf("%3.1f", $current{"mean_ml"});
	} else {
		$txtMeanMl = 'NA';
	}

	if ($current{'min_ml'} < 8) {
		$txtMinMl = sprintf("%3.1f", $current{'min_ml'});
	} else {

		$txtMinMl = 'NA';
	}

	if ($current{'max_ml'} > 0 && $current{'max_ml'} < 8) {
		$txtMaxMl = sprintf("%3.1f", $current{'max_ml'});
	} else {
		$txtMaxMl = 'NA';
	}

	# Compose Main Message Body
	$txt .= sprintf("Evts: %2.0f (%1.0f located)\n", $current{"events_declared"}, $current{"events_located"});
	$txt .= $txtMeanRate;
	$txt .= $txtMedianRate;
	$txt .= sprintf("Mags: %s/%s/%s (of %d)\n", $txtMinMl, $txtMeanMl, $txtMaxMl, $current{"num_ml"});
	$txt .= $txtCumMl;

	# Count Station Hits
	my %staHits = countStationHits($dbname, $startTime, $endTime, @{$stationsref}); 

	# APPEND STATIONS ORDERED BY NUMBER OF HITS
	my $key;
	foreach $key (sort { $staHits{$b} <=> $staHits{$a} } keys %staHits) { 
	   $txt = $txt. "$key($staHits{$key}) ";
	}
	$txt = $txt."\nEnd.\n";	

	return ($txt);
}

#####################################################################################
### GETPREVMSGPFPATH                                                               ##
### ($dir, $dfile, $msgTime, $alarmkey) = getPrevMsgPfPath($alarmdb, $alarmname);  ##
###                                                                                ##
### Glenn Thompson, 2009/04/20                                                     ##
###                                                                                ##
### Given an alarm database and an alarm (algorithm) name, get the                 ##
### directory path, filename and time of the most recent message of that           ##
### alarm name.                                                                    ##
#####################################################################################
sub getPrevMsgPfPath {
	my ($alarmdb, $alarmname) = @_;
	my ($alarmid, $dir, $dfile, $msgTime, $alarmkey);
	$dir = "dummy"; $dfile = "dummy";

	my @dbalarm = dbopen_table($alarmdb.".alarms", "r");
	@dbalarm = dbsubset( @dbalarm, "alarmname == \"$alarmname\"");
	my $nrecs = dbquery( @dbalarm, "dbRECORD_COUNT");

	my $lastAlarmTime = 0;
	if ($nrecs > 0) {
		$dbalarm[3] = $nrecs - 1;
		($alarmid, $msgTime, $alarmkey) = dbgetv(@dbalarm, "alarmid", "time", "alarmkey");
	}
	dbclose(@dbalarm);

	if ($nrecs > 0) {

		@dbalarm = dbopen_table($alarmdb.".alarmcache", "r");
		@dbalarm = dbsubset( @dbalarm, "alarmid == \"$alarmid\"");
		$nrecs = dbquery( @dbalarm, "dbRECORD_COUNT");
		if ($nrecs > 0) {
			$dbalarm[3] = $nrecs - 1;
			($dir, $dfile) = dbgetv(@dbalarm, "dir", "dfile");
		}
		dbclose(@dbalarm);
	}

	return ($dir, $dfile, $msgTime, $alarmkey);
}

###################################################################################
### getSwarmParams                                                               ##
### %prev = getSwarmParams($dir, $dfile);                                        ##
### %prev has keys min_ml, mean_ml, max_ml, cum_ml, mean_rate, median_rate, ...  ##
###     events_declared, events_located, timewindow_start, timewindow_end, ...   ##
###     message_type, swarm_start, swarm_end                                     ##
###                                                                              ##
### Glenn Thompson, 2009/04/20                                                   ##
###                                                                              ##
### Given the dir and dfile of a message parameter file, read all message params ##
###################################################################################
sub getSwarmParams {
	my ($dir, $dfile) = @_;
	my %prev;

	if (defined($dir) && defined($dfile))	{
	my $mpf = "$dir/$dfile";

		if (-e $mpf) {
			%prev = %{pfget($mpf, "prev")};
			unless (defined($prev{'swarm_end'})) {
				$prev{'swarm_end'} = '-1';
			}
			elsif ($prev{'swarm_end'} eq "") {
				$prev{'swarm_end'} = '-1';
			}
				 
		}
		else
		{
			print STDERR "Cannot find $mpf\n";
		}
	
	}
	else
	{
		print STDERR "Looks like no previous message found \n";
	}
	
	return %prev;
}


###################################################################################
### putSwarmParams                                                               ##
### putSwarmParams($dir, $dfile, %current);                                      ##
### %current has keys min_ml, mean_ml, max_ml, cum_ml, mean_rate, median_rate, ..##
###     events_declared, events_located, timewindow_start, timewindow_end, ...   ##
###     message_type, swarm_start, swarm_end                                     ##
###                                                                              ##
### Glenn Thompson, 2009/04/20                                                   ##
###                                                                              ##
### Given the dir and dfile and a parameter hash, write all message parameters   ##
###################################################################################
sub putSwarmParams {
	my ($dir, $dfile, %current) = @_;
	my $mpfpath = "$dir/$dfile";
	unless (-e $dir) {
		system("mkdir -p $dir")
	}
	unless (-e $mpfpath) {
		my $pfobject = "temppf";
		pfnew($pfobject);
		pfput("prev", \%current, $pfobject);
		pfwrite($mpfpath, $pfobject);

		# Every line is indented by 4 and is wrapped in an extra &Arr{ } object
		# The following lines get rid of this!
		# GTHO 2009/05/08 hack
		my $mpftmp = "$mpfpath.tmp";
		print "opening $mpfpath as FIN\n";
		open(FIN, $mpfpath);
		print "opening $mpftmp as FOUT\n";
		open(FOUT, ">$mpftmp");
		while (<FIN>) {
			unless ($_ =~ "^&Arr{" || $_ =~ "^}") {
				print FOUT substr($_,4);
			}
		}
		print "closing fout\n";
		close(FOUT);
		print "closing FIN\n";
		close(FIN);
		print "moving $mpftmp to $mpfpath\n";
		system("mv $mpftmp $mpfpath");
		 
	}
	else
	{
		print STDERR "$mpfpath already exists, will not overwrite\n";
	}
	
	return 1;
}

###################################################################################
### WRITEMESSAGE                                                                 ##
### ($msgdir, $msgdfile) = writeMessage($mdir, $mdfile, $txt)                    ##
###                                                                              ##
### Glenn Thompson, 2009/04/22                                                   ##
###                                                                              ##
### Write the text message to this dir/dfile                                     ##
###################################################################################
sub writeMessage {
	my ($mdir, $mdfile, $txt) = @_;
	unless (-e $mdir) {
		system("mkdir -p $mdir")
	}
	open(FOUT, ">$mdir/$mdfile");
	print FOUT $txt;
	close(FOUT);
	return 1;
}


###################################################################################
### GETMESSAGEPATH                                                               ##
### ($msgdir, $msgdfile) = getMessagePath($msgTime, $msgdir, $alarmname)         ##
###                                                                              ##
### Glenn Thompson, 2009/04/22                                                   ##
###                                                                              ##
### Get the path to write this message file to                                   ##
###################################################################################
sub getMessagePath {
	my ($msgTime, $msgdir, $alarmname)=@_;
	my ($msgdfile);
	$msgdir = epoch2str($msgTime, "$msgdir/$alarmname/%Y/%m");
	$msgdfile = epoch2str($msgTime, '%d%H%M').".txt"; 
	return ($msgdir, $msgdfile);
}

###################################################################################
### GETMESSAGEPFPATH                                                             ##
### ($msgpfdir, $msgpfdfile) = getMessagePfPath($msgTime, $msgpfdir, $alarmname) ##
###                                                                              ##
### Glenn Thompson, 2009/04/22                                                   ##
###                                                                              ##
### Get the path to write this message parameter file to                         ##
###################################################################################
sub getMessagePfPath {
	my ($msgTime, $msgpfdir, $alarmname)=@_;
	my ($msgpfdfile);
	$msgpfdir = epoch2str($msgTime, "$msgpfdir/$alarmname/%Y/%m");
	$msgpfdfile = epoch2str($msgTime, '%d%H%M').".pf"; 
	return ($msgpfdir, $msgpfdfile);
}

###################################################################################
### WRITEALARMSROW                                                               ##
### writeAlarmsRow($dbalarm, $alarmid, $alarmkey, $alarmclass, $alarmname, ...   ##
###    $alarmtime, $subject, $dir, $dfile)                                       ##
###                                                                              ##
### Glenn Thompson, 2009/04/20                                                   ##
###                                                                              ##
### Write a row to an alarms table in $dbalarm                                   ##
###################################################################################
sub writeAlarmsRow {

	my ($dbalarm,  $alarmid, $alarmkey, $alarmclass, $alarmname, $alarmtime, $subject, $dir, $dfile) = @_;
	my (@db);


	# WRITE FIELD TO ALARMS TABLE
	@db = dbopen($dbalarm, "r+");
        @db = dblookup( @db, 0, "alarms", 0, 0 );
	$db[3] = dbaddnull(@db);
	print "$0: Writing row for $alarmkey into $dbalarm.alarms\n";
	dbputv(@db, "alarmid", $alarmid, "alarmkey", $alarmkey, "alarmclass", $alarmclass, "alarmname", $alarmname,
		"time", $alarmtime, "subject", $subject, "acknowledged", "n", "dir", $dir, "dfile", $dfile);
	dbclose(@db);

	return 1;
}

###################################################################################
### WRITEALARMCACHEROW                                                           ##
### writeAlarmcacheRow($dbalarm, $alarmid, $dir, $dfile)                         ##
###                                                                              ##
### Glenn Thompson, 2009/04/20                                                   ##
###                                                                              ##
### Write a row to an alarmcache table in $dbalarm                               ##
###################################################################################
sub writeAlarmcacheRow {

	my ($dbalarm, $alarmid, $dir, $dfile) = @_;
	my (@db);

	# WRITE FIELD TO ALARMS TABLE
	@db = dbopen($dbalarm, "r+");
        @db = dblookup( @db, 0, "alarmcache", 0, 0 );
	$db[3] = dbaddnull(@db);
	print "$0: Writing row for $alarmid $dir/$dfile into $dbalarm.alarmcache\n";
	dbputv(@db, "alarmid", $alarmid, "dir", $dir, "dfile", $dfile);
	dbclose(@db);

	return 1;
}

##########################################################################################################
### WATCHTABLE                                                                                          ##
### ($row_to_start_at, $numnewrows) = &watchtable($database, $table, $last_row_only, $opt_v, $trackpf)  ##
###                                                                                                     ##
### Glenn Thompson, 2009/05/13 based on dbwatchtable                                                    ##
###                                                                                                     ##
### Watch a database table, returning row to start at and number of new rows                            ##
##########################################################################################################
sub watchtable {

	use File::stat;
	use Avoseis::SwarmAlarm;

	my ($database, $table, $last_row_only, $opt_v, $trackpf) = @_;
	my $nrowsprev = 0;
	my $mtimeprev = 0;
	if (-e $trackpf) {
		$nrowsprev = pfget($trackpf, "nrowsprev");
		$mtimeprev = pfget($trackpf, "mtimeprev");
	}
	my $row_to_start_at = $nrowsprev + 1;

	my $nrowsnow = 0;
  	my $numnewrows = 0;

	my $watchfile = "$database.$table"; 
	my $inode = stat("$watchfile");
	my $mtimenow = $inode->mtime ; # when was origin table last modified?
	if ($mtimenow > $mtimeprev) {
		my $mtimestr = epoch2str($mtimenow,"%Y-%m-%d %H:%M:%S");
		print "$watchfile has changed: modification time $mtimestr\n" if $opt_v;
		$nrowsnow = &counttablerows($database, $table);
		$numnewrows =  ($nrowsnow - $nrowsprev);
		print "Number of table rows now is $nrowsnow, previously had $nrowsprev\n" if $opt_v;

		if ($numnewrows > 0) {
			printf "Detected %d new rows added to $watchfile\n",$numnewrows;

			# Get to row to start at, which is either the first new row, or the last row, depending
			# on the value of $last_row_only in the parameter file
			$row_to_start_at = $nrowsnow if ($last_row_only);
			# note db[3] should be set to row_to_start_at - 1
		}
	}

	if (open(FOUT, ">$trackpf")) {
		printf FOUT "nrowsprev\t$nrowsnow\n";
		printf FOUT "mtimeprev\t$mtimenow\n";
		close(FOUT);
	}

	return ($row_to_start_at, $numnewrows);
}
# count the rows in the table of the database
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

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Avoseis::SwarmAlarm - Perl extension for the AVOSeis swarm alarm system

=head1 SYNOPSIS

  use Avoseis::SwarmAlarm;


=head1 DESCRIPTION

Avoseis::SwarmAlarm was created with h2xs -AXc -n Avoseis::Swarmalarm. 

=head2 EXPORT

None by default.

=head2 FUNCTIONS

# read the program parameter file
($alarmclass, $alarmname, $msgdir, $msgpfdir, $volc_name, $volc_code, $twin, $auth_subset, $reminders_on, $escalations_on, $cellphones_on, $reminder_time, $stathresholdsref, $newalarmref, $significantchangeref) = getPf($parameterfile);

# how many hits per station?                               
%staHits = countStationHits($dbname, @stations, $startTime, $endTime); 
                    
# load the events into time & Ml arrays
loadEvents($dbname, $starttime, $endtime, $auth_subset, \@eventtime, \@Ml, \%currentStats);   

# compute statistics for this timewindow
swarmStatistics(@eventTime, @Ml, $timewindow, \%currentStats);   

# get the path to the last message of this alarmname
($dir, $dfile, $msgTime) = getPrevMsgPfPath($alarmdb, $alarmname);  

# read the message pf
%prev = getSwarmParams($dir, $dfile);

# compose the message to send
$txt = composeMessage($msgType, \%currentStats,  $startTime, $endTime, $dbname, \@stations);   

# get the path to put this message to
($dir, $dfile) = getMessagePath($msgTime, $msgdir, $alarmname);

# get the path to put this message pf to
($dir, $dfile) = getMessagePfPath($msgTime, $msgpfdir, $alarmname);

# write out the message pf
putSwarmParams($dir, $dfile, %current);                                                    

# write the alarms row
writeAlarmsRow($dbalarm, $alarmid, $alarmkey, $alarmclass, $alarmname, ...    
    $alarmtime, $subject, $dir, $dfile);  

# write the alarmcache row
writeAlarmscacheRow($dbalarm, $alarmid, $dir, $dfile);

# compute the median
$median = median(@values);                          

# run a command at the command line
$result = runCommand($cmd, $mode);  

# watch a database table
($row_to_start_at, $numnewrows) = watchtable($database, $table, $last_row_only, $opt_v, $trackpf);    
               
=head2 DATA STRUCTURES

%prev & %current have keys min_ml, mean_ml, max_ml, cum_ml, mean_rate, median_rate, ...   
     events_declared, events_located, timewindow_start, timewindow_end, ...   
     message_type, swarm_start, swarm_end



=head1 SEE ALSO


=head1 AUTHOR

Glenn Thompson, E<lt>glenn@giseis.alaska.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Glenn Thompson, University of Alaska Fairbanks

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut

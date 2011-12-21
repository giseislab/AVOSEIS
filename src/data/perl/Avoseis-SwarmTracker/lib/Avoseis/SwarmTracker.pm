package Avoseis::SwarmTracker;

#use 5.000000;
use strict;
use warnings;

require Exporter; 

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Avoseis::SwarmTracker ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

# variable names
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

# subroutines
our @EXPORT = qw( 
countStationHits 
loadEvents 
swarmStatistics
composeMessage
getSwarmParams
putSwarmParams
make_swarmdb_descriptor
readStateTable
updateStateTable
);

#our $VERSION = '0.01';
our $VERSION = sprintf "%d.%03d", q$Revision: 1.5 $ =~ /: (\d+)\.(\d+)/;

use Datascope;
use POSIX qw(log10 ceil);

# globals


# Preloaded methods go here.

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
	my ($HOST) = $ENV{'HOST'};

	my ($txt, $txtMeanRate, $txtMedianRate, $txtMinMl, $txtMaxMl, $txtMeanMl, $txtCumMl);
	my $endTimeUTC    = epoch2str($endTime,'%Y/%m/%d %k:%M UTC');
	my $twinStr = sprintf("%2.0f", ($endTime-$startTime)/60 );
	
	$txt .= "From $HOST at ";
	$txt .= "$endTimeUTC\nSpan: $twinStr minutes\n";


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
### make_swarmdb_descriptor                                                      ##
###                                                                              ##
### Make a descriptor for a blank swarm1.0 database. Also make blank tables, if  ##
### they do not already exist                                                    ##
###                                                                              ##
### Glenn Thompson, 2011/12/07                                                   ##
###################################################################################
sub make_swarmdb_descriptor {
        my $swarmdb = $_[0];
        unless (-e $swarmdb) {
                open(FSP,">$swarmdb");
                print FSP<<"EODES";
#
schema swarm1.0
dblocks local
EODES
                close(FSP);
        }
        foreach my $table qw(metrics state swarm) {
                my $file = "$swarmdb.$table";
                system("touch $file") unless (-e $file);
        }

	return 1;
}

###################################################################################
### readStateTable                                                               ##
###                                                                              ##
### Read the state table to retrieve the previous level/state for this           ##
### particular alarm                                                             ##
###                                                                              ##
### Glenn Thompson, 2011/12/07                                                   ##
###################################################################################
sub readStateTable {
        # return -1 for no rows, 0 for "off", 1 for level 1, 2 for level 2...
        my ($swarmdb, $alarmname) = @_;
        my $level = -1;
        my @dbs = dbopen_table("$swarmdb.state", "r");
        @dbs = dbsubset(@dbs, "auth =='$alarmname'");
        my $numrecords = dbquery(@dbs, "dbRECORD_COUNT");
        if ($numrecords == 1) {
                $dbs[3] = 0;
                $level = dbgetv(@dbs, "level");
        }
        dbclose(@dbs);
        return ($level);
}

###################################################################################
### updateStateTable                                                             ##
###                                                                              ##
### Update the state table with the new level/state for this particular alarm    ##
###                                                                              ##
### Glenn Thompson, 2011/12/07                                                   ##
###################################################################################
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

	return 1;
}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Avoseis::SwarmTracker - Perl extension for the AVOSeis swarm tracker system

=head1 SYNOPSIS

  use Avoseis::SwarmTracker;


=head1 DESCRIPTION

Avoseis::SwarmTracker was created with h2xs -AXc -n Avoseis::SwarmTracker. 

=head2 EXPORT

None by default.

=head2 FUNCTIONS

# how many hits per station?                               
%staHits = countStationHits($dbname, @stations, $startTime, $endTime); 
                    
# load the events into time & Ml arrays
loadEvents($dbname, $starttime, $endtime, $auth_subset, \@eventtime, \@Ml, \%currentStats);   

# compute statistics for this timewindow
swarmStatistics(@eventTime, @Ml, $timewindow, \%currentStats);  
 
# Compose a message for sending by the alarm manager
$txt = composeMessage($msgType, \%currentStats, $startTime, $endTime, $dbname, \@stations);   

# read the message pf
%prev = getSwarmParams($dir, $dfile);

# create a descriptor for a swarm1.0 database and blank tables too
$success = make_swarmdb_descriptor($swarmdb);

# Read state table
$previousLevel = readStateTable($swarmdb, $alarmname);

# Update state table
$success = updateStateTable($swarmdb, $alarmname, $currentLevel);

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

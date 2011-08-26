use Datascope;
use Getopt::Std;
# use File::Basename; # used in watchpickfiles2db

sub get_names {
	# The commented lines below are copied from watchpickfiles2b - but are activated there.
        #my ($startYear, $startMonth) = @_;
        #if (length($startMonth) == 1) {
        #        $startMonth = "0".$startMonth;
        #}

	# SET TIMES
	#my $pickdir, $databaseName, $databaseLog ; #GT
	my $pickdir ; #GT
	$startEpoch = str2epoch($startMonth.'/01/'.$startYear);
	$minimumEpoch =  str2epoch('09/01/1989');
	$AHMaxEpoch =  str2epoch('03/01/2002');

	if ($startEpoch<$minimumEpoch) {
		die('There are no hypocenters prior to September 1989.');
	} elsif ($startEpoch> now() ) {
		die('You cannot translate picks from the future.');
	} elsif ($startEpoch < $AHMaxEpoch) {
		$pickDir = '/Seis/Kiska4/picks/'.$startYear.'/'.$startYear.'_'.$startMonth.'/AH';
	} else {
		$pickDir = '/Seis/Kiska4/picks/'.$startYear.'/'.$startYear.'_'.$startMonth.'/SAC';
	}
	# GT
	#$databaseName = '/Seis/Kiska4/picks/'.$startYear.'/database/db'.$startYear.'_'.$startMonth;
	#$databaseLog = '/Seis/Kiska4/picks/'.$startYear.'/database/log_db'.$startYear.'_'.$startMonth;
	if ($opt_v) {
		print "\nPick file directory: $pickDir\n";
		print "New database name:   $databaseName\n";
	}

	# GET LIST OF PICKFILES
	my @pickFileList;
	opendir(PICKDIR,"$pickDir") || die "can't opendir $pickDir: $!";
	while (my $pickFileName = readdir(PICKDIR)) {
		# Test file for suitability here (begins with 6 digits, ends with 'p')
		if ( $pickFileName =~ m/\d{6}\S+p/ ) {
			push(@pickFileList,$pickDir.'/'.$pickFileName);
		}
	}
	closedir(PICKDIR);
	# GT
	#return($databaseName,$databaseLog,$pickDir,@pickFileList);
	return($pickDir,@pickFileList);
}


sub run_avo2db {
	# The following line was added from watchpickfiles2db. Although commented here, it is active there.
	#my ($lastOrigin, @pickFileList) = @_;

	# REMOVE OLD DATABASE - these lines are not in watchpickfiles2db.
	my @oldDatabase = glob("$databaseName $databaseName.*");
	unlink(@oldDatabase);
	unlink($databaseLog);

	# WRITE NEW DATABASE
	my $batchSize = 150;		# ~250 limit on command size for Sun
	my @files = sort { lc($a) cmp lc($b) } @pickFileList;
	if ($opt_v) {
		print "Progress: ";
	}

	########## THIS BLOCK FROM WATCHPICKFILES2DB, COMMENTED HERE, ACTIVE THERE #############
	#print @pickFileList;

	## Here I need to delete any files from pickFileList if their YYYYMMDD_hhiiss basenames are less than lastOrigin
	#my @newfiles;
	#if ($#files > -1) {
	#        foreach $file (@files) {
	#                #print "Processing $file\n" if $opt_v;
	#                $base = basename $file;
	#                $timestr = substr($base, 0, 4)."-".substr($base, 4, 2)."-".substr($base, 6, 2)." ".substr($base, 9, 2).":".substr($base, 11, 2).":".substr($base, 13, 2);
	#                $time = str2epoch($timestr);
	#                if ($time > $lastOrigin) {
	#                        push @newfiles, $file;
	#                }
	#        }
	#        @files = @newfiles;
	#}
	########### END OF BLOCK ###############################################################

	while ( $#files > -1 ) {
		if ( $#files > $batchSize ) {
			@subFiles  = @files[0 .. $batchSize];
			@files = @files[ ($batchSize+1) .. $#files];
		} else {
			@subFiles = @files;
			@files = ();

		}

		# EXECUTE 
		$command = "avo2db @subFiles $databaseName ";
		#print "\n\n\n$command\n\n";
		#system($command);
    		$output = `$command  2>&1`;
		open(LOG,">>$databaseLog");
		print LOG "$command\n";
		print LOG "$output\n\n";
		close(LOG);

		# PROGRESS BAR
		$percentDone = int( 100*($#pickFileList-$#files)/($#pickFileList+1) );
		#print "  $percentDone  $#subFiles out of $#pickFileList ...\n";
        	if ($opt_v) {
			print "$percentDone\% ";
		}		
	}
	if ($opt_v) {
		print "\n";
	}
}


sub check_database {
	@db = dbopen($databaseName,'r');
	@db = dblookup(@db,"","origin","","");
	@db = dbsort(@db,'time');
	my $nRecords = dbquery(@db,"dbRECORD_COUNT");
	my $pickFileListLength = $#pickFileList;

	if ($nRecords > 0) {`

		# GET FIRST ORIGIN TIME
		$db[3] = 1;
		$firstOrigin = dbgetv(@db,"time");

		# GET LAST ORIGIN TIME
		$db[3] = $nRecords-1;
		$lastOrigin = dbgetv(@db,"time");

		$firstOriginString = strdate($firstOrigin);
		$lastOriginString = strdate($lastOrigin);
	}
	dbclose(@db);
	if ($opt_v) {
		print "Finished. Translated $nRecords of $pickFileListLength pick files from $firstOriginString to $lastOriginString\n\n";
	}
	# Following line from watchpickfiles2db, active there, commented here
  	#return ($firstOrigin, $lastOrigin);
	
}






##############################################

$Usage = "
Usage: buildavodb_plus [-v] [startYear startMonth] [endYear endMonth] [outdb]

See manpage for buildavodb for details.
This version will use current startYear startMonth if those arguments are omitted.
It will call itself recursively if the optional endYear and endMonth arguments are used.
This version also accepts an user-defined output database on the command line.
Otherwise the default output database is 
	/Seis/Kiska4/picks/($startYear)/database/db($startYear)_($startMonth)

OPTIONS
-v verbose output
startYear
startMonth

AUTHOR
Glenn Thompson, based entirely on buildavodb by Mike West
October 2010
Also merged changes from watchpickfiles2db, which may have been a more recent code.
\n\n";


# GET OPTIONS
$opt_v = 0;
if ( ! &getopts('v') ) {
        die ( "$Usage" );
}

# DECLARE AND ASSIGN DEFAULT VALUES
our ($startMonthNum, $endMonthNum);
our $startYear = epoch2str(now(), "%Y");
our $startMonth = epoch2str(now(), "%m");
our $endYear = $startYear;
our $endMonth = $startMonth;
our $databaseName = '/Seis/Kiska4/picks/'.$startYear.'/database/db'.$startYear.'_'.$startMonth;
our $databaseLog = '/Seis/Kiska4/picks/'.$startYear.'/database/log_db'.$startYear.'_'.$startMonth;

# PROCESS COMMAND LINE ARGUMENTS
if ($#ARGV==0) {
	($databaseName) = $ARGV[0];
	$databaseLog = $databaseName."_log";
} elsif ($#ARGV==1) {
	($startYear, $startMonth) = @ARGV;
} elsif ($#ARGV==2) {
	($startYear, $startMonth, $databaseName) = @ARGV;
	$databaseLog = $databaseName."_log";
} elsif ($#ARGV==3) {
	($startYear, $startMonth, $endYear, $endMonth) = @ARGV;
} elsif ($#ARGV==4) {
	($startYear, $startMonth, $endYear, $endMonth, $databaseName) = @ARGV;
	$databaseLog = $databaseName."_log";
} else {
	die($Usage);
}

if ( length($startMonth) == 1 ) {
	$startMonth = '0'.$startMonth;
}
if ( ($startYear<1900) || ($startYear>2400) ) {
	die('Invalid year input');
}
if ( ($startMonth<1) || ($startMonth>12) ) {
	die('Invalid month input');
}
if ( length($endMonth) == 1 ) {
	$endMonth = '0'.$endMonth;
}
if ( ($endYear<1900) || ($endYear>2400) ) {
	die('Invalid end year input');
}
if ( ($endMonth<1) || ($endMonth>12) ) {
	die('Invalid end month input');
}

# internal time convention is the month number since January 1981
$startMonthNum = 12 * ($startYear-1980) + ($startMonth-1);
$endMonthNum = 12 * ($endYear-1980) + $endMonth;


# CONVERT ONE MONTH
if ( $startMonthNum == $endMonthNum) {
#	($databaseName,$databaseLog,$pickDir,@pickFileList) = &get_names(); # GT
	($pickDir,@pickFileList) = &get_names(); # GT
	&run_avo2db();
	&check_database();
}
else
{
# CONVERT SEVERAL MONTHS
	foreach ($n=$startMonthNum; $n<$endMonthNum; $n++) {
		$thisYear = 1980 + int($n/12);
		$thisMonth = 1 + ($n % 12);
		if ($#ARGV % 2 == 0) { # only if $#ARGV was 0, 2 or 4 was there a user-supplied databaseName
			$cmd = "buildavodb_plus -v $thisYear $thisMonth $databaseName"; 
		} else {
			$cmd = "buildavodb_plus -v $thisYear $thisMonth"; 
		}
		#print "$cmd\n";
		system("$cmd");
	}
}

# THIS IS HOW WATCHPICKFILES2DB SEEMED TO BE LOOPING OVER SEVERAL MONTHS
# THIS IS POSSIBLY A BETTER METHOD THAN ABOVE, AND PASSING ARGUMENTS RATHER THAN
# USING GLOBALS
#        $year = $startYear;
#        $month = $startMonth;
#        $finished = 0;
#        while (!$finished) {
#                if ($month==13) {
#                        $month=1;
#                        $year+=1;
#                }
#                ($pickDir,@pickFileList) = &get_names($year, $month); # GT
#                ($firstOrigin, $lastOrigin) = &check_database();
#                &run_avo2db($lastOrigin, @pickFileList);
#                ($firstOrigin, $lastOrigin) = &check_database();
#
#                $finished = 1 if ($year==$endYear && $month==$endMonth);
#                $month++;
#        }


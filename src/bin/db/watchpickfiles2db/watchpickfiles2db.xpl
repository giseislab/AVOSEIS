use Datascope;
use Getopt::Std;
use File::Basename;


sub get_names {
	my ($startYear, $startMonth) = @_;
	if (length($startMonth) == 1) {
		$startMonth = "0".$startMonth;
	}
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
my ($lastOrigin, @pickFileList) = @_;

my $batchSize = 150;		# ~250 limit on command size for Sun
my @files = sort { lc($a) cmp lc($b) } @pickFileList;
if ($opt_v) {
	print "Progress: ";
}
print @pickFileList;

## Here I need to delete any files from pickFileList if their YYYYMMDD_hhiiss basenames are less than lastOrigin
my @newfiles;
if ($#files > -1) {
	foreach $file (@files) {
		#print "Processing $file\n" if $opt_v;
		$base = basename $file;
		$timestr = substr($base, 0, 4)."-".substr($base, 4, 2)."-".substr($base, 6, 2)." ".substr($base, 9, 2).":".substr($base, 11, 2).":".substr($base, 13, 2);
		$time = str2epoch($timestr);
		if ($time > $lastOrigin) {
			push @newfiles, $file;
		}
	}
	@files = @newfiles;


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
}


sub check_database {
	 
	@db = dbopen($databaseName,'r');
	@db = dblookup(@db,"","origin","","");
	@db = dbsort(@db,'time');
	my $nRecords = dbquery(@db,"dbRECORD_COUNT");

	if ($nRecords>0) {


		# GET FIRST ORIGIN TIME
		$db[3] = 1;
		$firstOrigin = dbgetv(@db,"time");
		$db[3] = $nRecords-1;

		# GET LAST ORIGIN TIME
		$lastOrigin = dbgetv(@db,"time");

		#$firstOriginString = strdate($firstOrigin);
		#$lastOriginString = strdate($lastOrigin);

	}
	dbclose(@db);
	return ($firstOrigin, $lastOrigin);
}






##############################################

$Usage = "
Usage: buildavodbgt [-v] [YYYY MM] outdb

See buildavodb for details.
This version will use current YYYY MM if those arguments are omitted.
This version also requires an output database on the command line.

OPTIONS
-v verbose output
YYYY
MM

AUTHOR
Glenn Thompson, based entirely on buildavodb by Mike West
October 2010
\n\n";


# GET OPTIONS
$opt_v = 0;
if ( ! &getopts('v') ) {
        die ( "$Usage" );
}



# CHECK ARGUMENTS
my $numARGV = $#ARGV;
die("No command line arguments entered.\n\n$Usage") if ($#ARGV==-1); # GT
our $databaseName = pop(@ARGV); # added by GT
my $databaseLog = $databaseName."_log";
my $startYear = epoch2str(now()-7*86400, "%Y");
my $startMonth = epoch2str(now()-7*86400, "%m");
my $endYear = epoch2str(now(), "%Y");
my $endMonth = epoch2str(now(), "%m");
if ( ( $ARGV == 1 ) || ( $#ARGV == 3 ) ){
	print "YYYY MM arguments found on command line\n";
	$startYear = shift(@ARGV);
	$startMonth = shift(@ARGV);
	if ( length($startMonth) == 1 ) {
		$startMonth = '0'.$startMonth;
	}
	if ( ($startYear<1900) || ($startYear>2400) ) {
		die('Invalid year input');
	}
	if ( ($startMonth<1) || ($startMonth>12) ) {
		die('Invalid month input');
	}
} else { # GT
	if ($#ARGV == -1) { # only had dbname
		# Nothing to do
	}
	else
	{
		die ( "$#ARGV remaining command line arguments - expecting -1.\n\n$Usage" );
	}
}
if ( $#ARGV == 3 ) {
	$endYear = shift(@ARGV);
	$endMonth = shift(@ARGV);
	if ( length($endMonth) == 1 ) {
		$endMonth = '0'.$endMonth;
	}
	if ( ($endYear<1900) || ($endYear>2400) ) {
		die('Invalid end year input');
	}
	if ( ($endMonth<1) || ($endMonth>12) ) {
		die('Invalid end month input');
	}
}



if ( $numARGV == 0 || $numARGV == 2 ) {
	$year = $startYear;
	$month = $startMonth;
	$finished = 0;
	while (!$finished) {
		if ($month==13) {
			$month=1;
			$year+=1;
		}
		($pickDir,@pickFileList) = &get_names($year, $month); # GT
		($firstOrigin, $lastOrigin) = &check_database();
		&run_avo2db($lastOrigin, @pickFileList);
		($firstOrigin, $lastOrigin) = &check_database();

		$finished = 1 if ($year==$endYear && $month==$endMonth);
		$month++;
	}
}


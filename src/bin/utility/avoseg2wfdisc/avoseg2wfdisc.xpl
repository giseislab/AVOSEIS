
# avoseg2wfdisc
# Build wfdisc tables for AVO segmented earthquake qaveforms
# Michael West
# 4/2009

use Datascope;
use Getopt::Std;



sub prepare_waveform_names { 
	@dbIn = dbopen($dbInName,'r');		# NOT PASSING NAME?!
	@db  = dblookup(@dbIn,"","origin","",1);
	my $nRecords = dbquery(@db,"dbRECORD_COUNT"); 
	@db2 = dblookup(@dbIn,"","remark","",1);	
	my $nRecords = dbquery(@db2,"dbRECORD_COUNT"); 
	@db  = dbjoin(@db,@db2);
	my $nRecords = dbquery(@db,"dbRECORD_COUNT"); 
		if ( $nRecords < 0 ) {
		die('No remarks found');	
	}
	
	foreach $row (0..$nRecords-1) {
		$db[3] = $row ;
		my ($time,$remark) = dbgetv(@db,"time","remark");
		if (substr($remark,-1) eq 'p') {
        	chop($remark);
		} else {
			print "** WARNING: $remark does not end in p\n";	
		}
		my $yearDir = epoch2str($time, "%Y/"); 
		my $monthDir =  epoch2str($time, "%Y_%m/"); 
		my $dir = '/Seis/Kiska4/data/'.$yearDir.$monthDir.'SAC/'.$remark.'/*';
		push(@dirList, $dir);	
	}
	dbclose(@dbIn);
	return(@dirList);
}



sub run_sac2db {
 
	open(LOG,">$logName");
	print LOG "Creating waveform database:    $dbOutName\n";
	print LOG "Reading events from database:  $dbInName\n";
	print LOG "No. of events to be processed: $#dirList\n";
	close(LOG);
       if ($opt_v) {
		print "Creating waveform database:    $dbOutName\n";
		print "Reading events from database:  $dbInName\n";
		print "No. of events to be processed: $#dirList\n";
	}	

	# WRITE NEW DATABASE
	my $lengthDirList = $#dirList;
	my $batchSize = 3;		# ~250 limit on command size for Sun
	if ($opt_v) {
		print "Progress: ";
	}
	while ( $#dirList > -1 ) {
		if ( $#dirList > $batchSize ) {
			@subDirList  = @dirList[0 .. $batchSize];
			@dirList = @dirList[ ($batchSize+1) .. $#dirList];
		} else {
			@subDirList = @dirList;
			@dirList = ();
		}

		# ESTABLISH TEMPORARY DATABASES
		my $dbTmp1 = 'tmp_001';
		my $dbTmp2 = 'tmp_002';
		if ( @db = dbopen($dbTmp1,'r+') ) {
			dbdestroy(@db);
		}
		if ( @db = dbopen($dbTmp2,'r+') ) {
			dbdestroy(@db);
		}

		# CREATE TEMPORARY DATABASE
		$command = "sac2db @subDirList $dbTmp1";
		#print "\n\n\n$command\n\n";
    		$output = `$command  2>&1`;
		open(LOG,">>$logName");
		print LOG "\n\n-------------------------------------------------------------------------------------\n";
		print LOG "$command\n\n";
		print LOG "$output\n\n";
		close(LOG);

		# CLEAN TEMPORARY DATABASE
		@db = dbopen($dbTmp1,'r');	
		@db  = dblookup(@db,"","wfdisc","",1);
		my $timeMin = epoch('1/1/1980');
		my $timeMax = now()+86400;
		@db  = dbsubset(@db,"(time>$timeMin) && (time<$timeMax)");
		dbunjoin(@db,$dbTmp2);
		dbclose(@db);

		#FIX CHANNEL NAMES IN WFDISC TABLE
		@db = dbopen($dbTmp2,'r+');	
		@db  = dblookup(@db,"","wfdisc","",1);
		my $nRecords = dbquery(@db,"dbRECORD_COUNT"); 
		foreach $row (0..$nRecords-1) {
              		$db[3] = $row ;
			($chan) = dbgetv(@db,"chan");
			$chan = uc($chan);
			$db[3] = dbputv (@db,"chan", $chan);
		}

		# APPEND TEMPORARY DB TO FINAL DB
		system("cat $dbTmp2.wfdisc >> $dbOutName.wfdisc");

		# PROGRESS BAR
		$percentDone = int( 100*($lengthDirList-$#dirList)/($lengthDirList+1) );
		#print "  $percentDone  $#subFiles out of $#pickFileList ...\n";
        	if ($opt_v) {
			print "$percentDone\% ";
		}		
	}
	if ($opt_v) {
		print "\n";
	}
}






##############################################

$Usage = "
Usage: buildavodb [-v] [-f] dbin [dbout] 

avoseg2db writes a wfdisc table which points to the segmented waveforms that accompany the events in dbin. By default the program will not overwrite or add to an existing database. The -f option overrides this. The program creates a symbolic link avo_segmented_data that points to /Seis/Kisk4/data. Referencing the data through a link allows the database to be portable away from the seis lab networks.

OPTIONS
-v verbose output

-f force avoseg2wfdisc to add wfidsc rows to an existing database. By default avoseg2db will not overwrite existing database.

CAVEATS
There is currently no parameter file for this program. Most parameters are hardwired. While this matches the static structure of the pickfile directories, it does not allow for more generalized use. This code actually sends pickfiles to sac2db in batches of a few hundred. This is done to avoid exceeding the command line buffer size. It works fine but there is no actual testing of the command line length for compliance. avoseg2db assumes that the data for each origin is stored in the corresponding year_month directory, even for events that occur within seconds of the boundary. If this is not the case, avoseg2db may not not include the affected waveforms.

AUTHOR
Michael West
April 2009
\n\n";



# GET OPTIONS
$opt_v = $opt_f = 0;
if ( ! &getopts('vf') ) {
        die ( "$Usage" );
}

# CHECK ARGUMENTS
if ( ( $#ARGV == 0 ) || ( $#ARGV == 1) ) {
	$dbInName = shift(@ARGV);	
} else {
        die ( "Wrong number of arguments.\n $Usage" );
}

if ( $#ARGV == 0 ) {
	$dbOutName = shift(@ARGV);	
} else {
	$dbOutName = $dbInName.'_wf';	
}
$LogName = 'LOG_'.$dbOutName;

# TEST FOR EXISTENCE OF OUTPUT WFIDSC DATABASE
if ( (-e "$dbOutName") || (-e "$dbOutName.wfdisc") ) {
	print "A database named $dbOutName appears to exist already. Cannot over write.\n";
	die('database exists already');

}

# PREPARE WAVEFORM FILE NAMES
$dirList = &prepare_waveform_names();

# RUN SAC2DB
&run_sac2db();



#FIX CHANNEL NAMES IN ARRIVAL TABLE
@db = dbopen($dbInName,'r+');	
@db  = dblookup(@db,"","arrival","",1);
my $nRecords = dbquery(@db,"dbRECORD_COUNT"); 
foreach $row (0..$nRecords-1) {
	$db[3] = $row ;
	($chan) = dbgetv(@db,"chan");
	if (length($chan) == 1 ) {
		$chan = 'SH'.$chan;
	}
	if (length($chan) == 2 ) {
		print "Unsure how to handle 2-letter channel name. No change ...";
	}
	$db[3] = dbputv (@db,"chan", $chan);
}



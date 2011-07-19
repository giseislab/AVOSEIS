# Convert one month of AVO pick files to a one month database.
# Michael West, Apirl 2009
# 

use lib "$ENV{ANTELOPE}/data/perl" ;
use Datascope;
use Getopt::Std;


sub get_names {

	# SET TIMES
	$startEpoch = str2epoch($startMonth.'/01/'.$startYear);
	$minimumEpoch =  str2epoch('09/01/1989');
	if ($startEpoch<$minimumEpoch) {
		die('There are no hypocenters prior to September 1989.');
	}	
	if ($startEpoch> now() ) {
		die('You cannot translate picks from the future.');
	}	
	my $pickDir = '/Seis/Kiska4/picks/'.$startYear.'/'.$startYear.'_'.$startMonth.'/SAC';
	my $databaseName = '/Seis/Kiska4/picks/'.$startYear.'/database/dbNEW'.$startYear.'_'.$startMonth;
	my $databaseLog = '/Seis/Kiska4/picks/'.$startYear.'/database/log_db'.$startYear.'_'.$startMonth;
	

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
	return($databaseName,$databaseLog,$pickDir,@pickFileList);
}


sub run_avo2db {
	my $batchSize = 99;		# ~250 limit on command size
	$tmp = $#pickFileList;
	#print "There are $#pickFileList files in $pickDir\n";
	while ( $#pickFileList > -1 ) {
		if ( $#pickFileList > $batchSize ) {
			@subPickFileList  = @pickFileList[0 .. $batchSize];
			@pickFileList = @pickFileList[ ($batchSize+1) .. $#pickFileList];
		} else {
			@subPickFileList = @pickFileList;
			@pickFileList = ();

		}
		$command = "avo2db @subPickFileList $databaseName";
		#$command = length($command);
		#print "\n\n\n$command\n\n";
		system ($command);
	}
}



##############################################

$Usage = "
Usage: buildavodb YYYY MM 

This script converts a month of AVO pick files into Antelope database tables where YYYY and MM are the year and month, respectively. See man page for full description.
\n\n";


if ( $#ARGV == 1 ) {
	$startYear = shift(@ARGV);
	$startMonth = shift(@ARGV);
	}
elsif ( $#ARGV == 3 ) {
	$startYear = shift(@ARGV);
	$startMonth = shift(@ARGV);
	$endYear = shift(@ARGV);
	$endMonth = shift(@ARGV);
	die('Multiple month conversions have not yet been implimented.');
	}
else {
	die ( "$Usage" );
	}


($databaseName,$databaseLog,$pickDir,@pickFileList) = &get_names();
#print "--- $pickDir  $databaseName     $databaseLog\n";

my @oldDatabase = glob("$databaseName $databaseName.*");
unlink(@oldDatabase);

&run_avo2db();
print "Finished month: $startYear_$endYear\n";



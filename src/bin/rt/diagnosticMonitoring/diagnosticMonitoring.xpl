
##############################################################################
# Author: Glenn Thompson (GT) 2010
#         ALASKA VOLCANO OBSERVATORY
#
# History:
#       2010-03-22: Created by GT
#	2010-07-12: Substantially modified to fit swarm alarm project
#
# To do:
#	- remove any hard-wired paths
#	- add HTML content
##############################################################################

use Datascope;
use Getopt::Std;

use strict;
#use warnings;

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

# Usage - command line options and arguments
our ($opt_d, $opt_h, $opt_t);
if ( ! &getopts('h:d:t:') || !($#ARGV ==2 || $#ARGV == -1) ) {
   print STDERR <<"EOU" ;
   Usage: $PROG_NAME [-d debug-level] [-h htmloutputfile] [-t numdays] [YYYY MM DD]
EOU
   exit 1 ;
}

# End of  GT Antelope Perl header
#################################################################

use Avoseis::AlarmManager qw(writeAlarmsRow writeMessage declareDiagnosticAlarm);

use Env qw(HOST DBT_EARTHWORM DBT_OPTIMISED DBT_MASTER);
our $HTML_FILE = $opt_h;
our $HOST = $ENV{"HOST"};

my ($yyyy, $mm, $dd);
my $today = 1;
if ($#ARGV == 2) {
       ($yyyy, $mm, $dd) = @ARGV;
       $today = 0;
}
else
{
       $yyyy = epoch2str(now(), "%Y");
       $mm = epoch2str(now(), "%m");
       $dd = epoch2str(now(), "%d");
}
$opt_d = 0 unless ($opt_d);
$opt_t = (6/24) unless ($opt_t);
&print_html_header() if $opt_h;

my $alarmdb = "dbalarm/alarm";
my $dbname;
my $timesubset = "time > now() - 86400";

# ************ SET START & END TIME *******
my $numdays = $opt_t;
my $eepoch = now();
my $sepoch = $eepoch - 86400 * $numdays; 
my ($outOfDate, $txt, $txtnew, $alarms);

# *********** ARE SPECTROGRAMS WORKING ? **********
#my $lastsgram = "/usr/local/mosaic/AVO/avoseis/TreMoR/plots/spectrograms/lastspectrogram.png";
my $lastsgram = "/avort/modrun/spectrograms/lastspectrogram.png";
my $sgramsOff = 1;
if (-e $lastsgram) {
	if (-M $lastsgram < 1/24) {
		$sgramsOff = 0;  
	}
}
if ($sgramsOff) { 
	$txt .= "\n".&getFileAgeStr($lastsgram)."\n";
	$alarms++;
	$txt .= "Spectrograms are off\n";
}

# ************* CHECK EARTHWORM EVENTS ***************
# Switched off!
if (0) {
	$dbname = $ENV{DBDETECTIONS}."_".$yyyy."_".$mm."_".$dd;
	($outOfDate, $txtnew) = &check_table($dbname, "detection", $numdays, $timesubset);
	$txt .= $txtnew;
	if ($outOfDate) { 
		my $logfile = "logs_earthworm/carlstatrig_$yyyy$mm$dd.log";
		$txt .= "\n".&getFileAgeStr($logfile)."\n";
		$alarms++;
		$txt .= "No new detections in $dbname\n";
	}

	$dbname = $ENV{DBT_EARTHWORM};
	($outOfDate, $txtnew) = &check_table($dbname, "origin", $numdays, $timesubset);
	$txt .= $txtnew;
	if ($outOfDate) { 
		my $logfile = "logs_earthworm/carlsubtrig85.log_$yyyy$mm$dd";
		$txt .= "\n".&getFileAgeStr($logfile)."\n";
		$alarms++;
		$txt .= "No new origins in $dbname\n";
	}
}

# ************* CHECK ANTELOPE EVENTS ***************
$dbname = $ENV{DBT_OPTIMISED}; 
($outOfDate, $txtnew) = &check_table($dbname, "detection", $numdays, $timesubset );
if ($outOfDate) { 
	$txt .= $txtnew;
	$txt .= "No new detections in $dbname\n";
	$alarms++;
}

($outOfDate, $txtnew) = &check_table($dbname, "origin", $numdays, $timesubset);
if ($outOfDate) { 
	$txt .= $txtnew;
	$txt .= "No new origins in $dbname\n";
	$alarms++;
}

# **** SWARM TRACKING MODULE RUNNING ? **** Commented out 2011/12/21 because it is off
if (0) {
	my $logfile = "logs/cron-swarmtracker_antelope";
	if (-e $logfile) {
		if (-M $logfile > 1/24) {
			$txt .= &getFileAgeStr($logfile)."\n";
			$alarms++;
		}
	}
	else
	{
		$txt .= "$logfile does not exist: swarm tracking system not running?\n";
		$alarms++;
	} 
}

# **** WATCH ALARMS TABLE MODULE RUNNING ? ****
my $logfile = "logs/watchalarmstable";
if (-e $logfile) {
	if (-M $logfile > 1/24) {
		$txt .= &getFileAgeStr($logfile)."\n";
		$txt .= "dbwatchtable for alarms not running?\n";
		$alarms++;
		system("echo \"alarm system not running\" | rtmail -s \"alarm system down\" 9076877747\@mms.att.net");
	} 
}
else
{
		$txt .= "$logfile does not exist: dbwatchtable for alarms not running?\n";
		system("echo \"alarm system not running\" | rtmail -s \"alarm system down\" 9076877747\@mms.att.net");
		$alarms++;
} 

# ************* CHECK EVENT PROCESSING DB ***************
$dbname = $ENV{DBT_MASTER}; 
if (0) {
	($outOfDate, $txtnew) = &check_table($dbname, "origin", $numdays, "auth=~/ew_.*/");
	if ($outOfDate) { 
		$txt .= $txtnew;
		$alarms++;
		$txt .= "No new Earthworm origins in $dbname\n";
	}

	($outOfDate, $txtnew) = &check_table($dbname, "origin", $numdays, "auth=~/oa_.*/");
	if ($outOfDate) { 
		$txt .= $txtnew;
		$alarms++;
		$txt .= "No new AEIC automated origins in $dbname\n";
	}

	($outOfDate, $txtnew) = &check_table($dbname, "origin", $numdays, "auth=~/USGS.*/");
	if ($outOfDate) { 
		$txt .= $txtnew;
		$alarms++;
		$txt .= "No new USGS origins in $dbname\n";
	}
}

# *************** CHECK XPICK DATABASE ************
if (0) { # Skip test
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
	if ($wday > 0 && $wday < 6 && $hour > 16) { # 0 is Sunday, so this checks only after 4pm Mon-Fri
		$dbname = $ENV{DBEVENTS_XPICK};
		($outOfDate, $txtnew) = &check_table($dbname, "origin", 1, $timesubset);
		if ($outOfDate) { 
			$txt .= $txtnew;
			$alarms++;
			$txt .= "No new origins in $dbname (from XPick)\n";
		}
	}
}

# ****** PING SERVERS CHECK *******
use Net::Ping;
my %hostips = ("bronco" => 240, "earthworm" => 23, "chinook" => 107, "humpy" => 117, "raven" => 139, "muskox" => 98, "badger" => 44);
while ( my ($host, $value) = each %hostips) {
	print "Processing $host\n";
	my $ipaddress = "137.229.32.".$value;
	my $p = Net::Ping->new();
	#my $p = `ping -c 4 $ipaddress`; chomp($p);
	if ($p->ping($ipaddress, 4)) {
	#if ($p =~ /alive/ || !($p =~ /100% packet loss/)) {
		print "$host ($ipaddress) is alive (1st attempt).\n";
	}
	else
	{
		# 2nd attempt
		#if ($p->ping($ipaddress, 4)) {
		my $pu = `ping -c 1 $ipaddress`; chomp($p);
		if ($pu =~ /alive/ || !($pu =~ /100% packet loss/)) {
			print "$host ($ipaddress) is alive (2nd attempt).\n";
		}
		else
		{
			print "Cannot ping $host ($ipaddress)\n";
			$alarms++;
			$txt .= "Cannot ping $host ($ipaddress)\n";
		}
	}
	$p->close();
		
}			

# **** PROCESSES CHECK *********
#my @cmds = qw(rtexec orbdetect orbassoc orb2dbt carlsubtrig2antelope carlstatrig2antelope dbwatchtable);
my @cmds = qw(rtexec orbdetect orbassoc orb2dbt dbwatchtable);
eval {
	foreach my $cmd (@cmds) {
		my $wc = `ps -ef | grep $cmd | grep -v grep | wc -l`;
		chomp($wc);
		print "Got $wc rows for $cmd\n";
		if ($wc == 0) {
			$alarms++;
			$txt.="$cmd is not running on ".$HOST."\n";	
		}

	}
};


if ($alarms>0) { 
	$txt = "$alarms alarms\n\n$txt";
	print "$txt\n";
	my $STATEFILE = "state/diagnosticMonitoring.txt";
	my $lasttxt = "";
	{
  		local $/ = undef;
		if (-e $STATEFILE) {
  			open FILE, $STATEFILE or die "Couldn't open file: $!";
  			binmode FILE;
  			$lasttxt = <FILE>;
  			close FILE;
		}
	}
	if ($txt ne $lasttxt) {
		print "Differs from last message - sending alarm\n";
		&declareDiagnosticAlarm("$PROG_NAME: ".$ENV{HOST}, $txt, $alarmdb) if $alarms;
		open FSTATE, ">$STATEFILE";
		print FSTATE "$txt";
		close FSTATE;
	} else {
		print "Same as last message - no alarm will be sent\n";
		system("touch $STATEFILE");
	}

}

&print_html_footer() if $opt_h;
printf("Ran $PROG_NAME at %s\n\n", epoch2str(now(),"%Y-%m-%d %H:%M:%S"));
1;
###################################### SUBROUTINES FOLLOW ###################################

sub check_table {
	my ($dbname, $table, $ageLimit, $subset_expr) = @_;
	my (@db, $logfile, $numrows, $nrecslog, $age, $lddate, $outOfDate);
	$numrows = 0;
	$age = 99999999;
	$lddate = 0;
	$outOfDate = 1;
	my $txt = "\n";
	
	eval {
		@db = dbopen_table("$dbname.$table", "r");
		my $numrows2 = dbquery(@db, "dbRECORD_COUNT");
		@db = dbsubset(@db, $subset_expr);
		$numrows = dbquery(@db, "dbRECORD_COUNT");
		if ($numrows > 0) {
			$db[3] = $numrows-1;
			$lddate = dbgetv(@db, "lddate");
			dbclose(@db);
			if ($lddate > 0) {
				$age = now() - $lddate;
			}
		
			if ($age <= ($ageLimit*86400)) {
				$outOfDate = 0;
				$txt = "";
			}
			else
			{
				$txt .= sprintf("Rows: %d (subset from %d)\nlddate: %s\nage: %s\nageLimit: %s\n", $numrows, $numrows2, epoch2str($lddate, "%Y-%m-%d %H:%M:%S"), epoch2str($age, "%H:%M:%S"), epoch2str($ageLimit*86400, "%H:%M:%S"));
				$txt .="subset with $subset_expr\n" if ($subset_expr);
			}

		}
		else
		{
			$txt .= "Rows: 0 (subset from $numrows2)\n";
			$txt .="subset with $subset_expr\n" if ($subset_expr);
		}

	};
	if ($@) {
		$txt .= "Could not open $dbname.$table for reading? $@\n";
	}
	
	return ($outOfDate, $txt);
}

sub print_debug {
       my ($message, $debug_level) = @_;
       our ($opt_d);

       if ($opt_d >= $debug_level) {
               print "$message\n";
       }
}

sub print_html {
       my ($system, $item, $message, $expression) = @_;
               my $class = "d0";
               $class = "d1" if ($expression == 0);
               our $HTML_FILE;
               open(FHTML, ">>$HTML_FILE") or die("Cannot open $HTML_FILE for writing\n");
               print FHTML "<tr class=\"$class\"> <td><b>$system</b></td> <td>$item</td> <td><i>$message</i></td> </tr> \n";

               close(FHTML);
}

sub print_html_header {
               my $runtime = epoch2str(now(),"%Y-%m-%d %H:%M");
               our ($HTML_FILE);
               open(FHTML, ">$HTML_FILE") or die("Cannot open $HTML_FILE for writing\n");
               print FHTML <<EOF;
<html>
<head>
<title>Diagnostic monitoring on $HOST</title>
<style type="text/css">
tr.d0 td {
       background-color: #00FF00; color: black;
}
tr.d1 td {
       background-color: #FF0000; color: black;
}
</style>
</head>
<body>
<p>Running $PROG_NAME at $runtime</p>
<table>
EOF
               close(FHTML);
}

sub print_html_footer {
               our $HTML_FILE;
               open(FHTML, ">>$HTML_FILE") or die("Cannot open $HTML_FILE for writing\n");
               print FHTML <<EOF;
</table>
</body>
</html>
EOF
               close(FHTML);
}

sub getFileAgeStr {
	my ($file) = $_[0];
	my $fileAgeStr = "";
	if (-e $file) {
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
		$fileAgeStr = sprintf("$file last modified at %s", epoch2str($mtime, "%Y-%m-%d %H:%M"));
	}
	else
	{
		$fileAgeStr = "$file does not exist";
	}
	return $fileAgeStr;
}


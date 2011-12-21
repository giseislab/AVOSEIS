##############################################################################
# Author: Glenn Thompson (GT) 2009
#         ALASKA VOLCANO OBSERVATORY
#
#
# To do:
##############################################################################

use Datascope;
use Getopt::Std;

use strict;
use warnings;

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

# Usage - command line options and arguments
our ($opt_p, $opt_v, $opt_c);
if ( ! &getopts('p:vc') || $#ARGV < 0 || $#ARGV > 1  ) {
    print STDERR <<"EOU" ;

    Usage: $PROG_NAME [-p pffile] [-v] [-c] dbname [OLDLOGFILE]

    For more information:
        > man $PROG_NAME
EOU
	die("Args: $#ARGV\n");
    exit 1 ;
}


# End of  GT Antelope Perl header
#################################################################
use Avoseis::Utils qw(getPf runCommand);

printf("\n**************************************\n\nRunning $PROG_NAME at %s\n\n", epoch2str(now(),"%Y-%m-%d %H:%M:%S")); 

# read parameter file
print "Reading parameter file for $PROG_NAME\n" if $opt_v;
my ($smbclient_logfileshare, $smbclient_connectionfile, $smbclient_commandfile, $logfileleader, $masterstationspath,$archivepath,  $sleeptime, $avovolcspath, $carlsubtriglogdir) = &getParams($PROG_NAME, $opt_p, $opt_v);

use Cwd;
our $pwd = getcwd();
use File::Basename qw(basename dirname);

our $LOGFILE;
our $dbname;
our $masteridfile = $pwd."/".$ARGV[0].".lastid";
&runCommand("touch $masteridfile",1);
our $statefile = "";
our $statetime = 0;

# Provide a way of processing old days
our $OLDLOGFILE = "";
$OLDLOGFILE = $ARGV[1] if ($#ARGV == 1);

# statefile - for tracking latest origin processed
if ($#ARGV == 0) {
	mkdir("state");
	$statefile = "state/$PROG_NAME";
	if (-e $statefile) {
		$statetime = &read_statefile($statefile);
	}
	&runCommand("mkdir -p $carlsubtriglogdir",1);
}

my $previous_event = 0; # has there been a previous event?

my $ymd;

my $sitechan_table = "$masterstationspath/master_stations.sitechan";
our $loopagain = 1;
while ($loopagain) { # daemon process

	# write SMBCLIENTFILE
	if ($#ARGV == 1) {
		# Use an old log file on the current filesystem
		open(FIN, "$OLDLOGFILE") or die("Cannot open $OLDLOGFILE\n");
		$LOGFILE = $OLDLOGFILE;
		$ymd = substr($LOGFILE, -8, 4) . "_" . substr($LOGFILE, -4, 2) . "_" . substr($LOGFILE, -2);
		chomp($ymd);
	}
	else
	{
		$ymd = epoch2str(now() - 2*$sleeptime, "%Y_%m_%d"); # GTHO 20101111: added -$sleeptime so that should no miss events
		# in last $sleeptime seconds of a day as the log file name changes

		# Grab the current log file from the smbclient mounted filesystem
		$LOGFILE = $logfileleader.epoch2str(now(), "%Y%m%d");
		open(FCF, ">$smbclient_commandfile");
		print FCF "get $LOGFILE\n";
		close(FCF);
	
		# get LOGFILE
		&runCommand("smbclient $smbclient_logfileshare -A $smbclient_connectionfile < $smbclient_commandfile",1);
		
		# move it to CARLSUBTRIGLOGDIR
		if (!(-e $LOGFILE)) {
			sleep($sleeptime);
			next;
		}
		&runCommand("mv $LOGFILE $carlsubtriglogdir",1);

		# open LOGFILE or die
		open(FIN, "$carlsubtriglogdir/$LOGFILE");
		if ($@){
			print "Cannot open $carlsubtriglogdir/$LOGFILE\n";
			sleep($sleeptime);
			next;
		};
	}

	my $eventon = 0;
	my $firststation=0;
	my ($lat, $lon, $otime, $jdate, $nass, $lastotime) = 0;
	my ($subnet, $volcano);
	my $found;
	my $pretrigger = 30;
	my $posttrigger = 20;
	my @staphase;
		
	# open output database tables
	if ($opt_c) { # Continuous database
		$dbname = $ARGV[0];
	}
	else
	{ # Day volumes
		$dbname = $ARGV[0]."_$ymd";		
	}
	my @dbo = dbopen_table("$dbname.origin", "r+");
	my @dbe = dbopen_table("$dbname.event", "r+");
	my @dbas = dbopen_table("$dbname.assoc", "r+");
	my @dbar = dbopen_table("$dbname.arrival", "r+");
	
	# make links like dbew_2009_11_16.lastid@ -> dbew.lastid
	my $lastidfile = "$dbname.lastid";
	unless (-e $lastidfile) {
		my $dbdir = dirname $lastidfile;
		chdir($dbdir);
		my $masteridbase = basename $masteridfile;
		my $lastidbase = basename $lastidfile;
		&runCommand("ln -s $masteridbase $lastidbase",1); 
		chdir($pwd);
	}

	# find the arid, orid and evid to start at
	my $arid = `dbnextid $dbname arid`;
	chomp($arid);
	my $orid = `dbnextid $dbname orid`;
	chomp($orid);
	my $evid = `dbnextid $dbname evid`;
	chomp($evid);
	
	while (my $line = <FIN>) {
		if ($line=~/EVENT DETECTED/) {
			$previous_event = 1;
			my $otimestr = substr($line,19,20);
			my ($yyyy, $mm, $dd, $hh, $mi, $ss) = otimestr2time($otimestr);
			$otime = str2epoch("$yyyy/$mm/$dd $hh:$mi:$ss");
			my $ewevid = substr($line,54,6);
			$subnet = substr($line,87,2);
			$jdate = yearday($otime);
			($lat, $lon, $volcano, $found) = &subnet2latlon($subnet, $avovolcspath);
			
	 		$eventon = 1;
			$nass = 0;
			$firststation = 1;
			@staphase = qw();
			printf"\n$otimestr: EVENT DETECTED ew=$ewevid ant=$evid at $volcano\n" if ($otime > $statetime);
		}
		if ($eventon && ($line=~ /save/) && !($line=~/start/)) {
			my @temp = split(" ",substr($line,1,13));
			my $sta = $temp[0];
			unless ($sta eq "*") {
				my $l = length($sta);
				my $chan = $temp[1];
				my $net = $temp[2];
				my $phase = $temp[3];
				my $arrtimestr = substr($line,11+$l,20);
				my ($yyyy, $mm, $dd, $hh, $mi, $ss) = otimestr2time($arrtimestr);

				my $atime = str2epoch("$yyyy/$mm/$dd $hh:$mi:$ss"); # For some arrivals, atime is 0 in carlsubtrig. Why?



				if ($atime != 0) {

					print "$sta $chan $net $phase *$arrtimestr* $yyyy $mm $dd $hh $mi $ss";
					my $jdate = yearday($atime);
					my $chanid = -1; # NULL
					my $sitelat = -999.000; # NULL
					my $sitelon = -999.000; # NULL
					my @dbsc = dbopen_table($sitechan_table, "r") or die("$sitechan_table not found\n");
					my @dbsc2;
					eval {
						my $expr = "sta == \"$sta\" && chan == \"$chan\" && offdate == NULL";
						@dbsc2 = dbsubset(@dbsc, $expr);
					};
					if ($@){
						# 20110502 GTHO: System was getting stuck here on bad record
						# Change from die to next
						#die("Could not subset the sitechan table for $sta\n");
						print "Could not subset the sitechan table for $sta\n";
						next;	
					};
					my $nrecs = dbquery(@dbsc2, "dbRECORD_COUNT");
					if ($nrecs == 1) {
						$dbsc2[3]=0;
						$chanid = dbgetv(@dbsc2, "chanid");
						print "CHANID = $chanid\n" if $opt_v;
					}
					#dbclose(@dbsc2);
					dbclose(@dbsc);

					print "Getting lat,lon from site table\n" if $opt_v;
					my $delta = -1.000; # NULL
					my $timeres = -999.000; # NULL
					my $vmodel = "-";
					eval {
						my @dbsi = dbopen_table("$masterstationspath/master_stations.site", "r");
						my $expr = "sta == \"$sta\" && offdate == NULL";
						my @dbsi2 = dbsubset(@dbsi, $expr);
						my $nrecs = dbquery(@dbsi2, "dbRECORD_COUNT");
						if ($nrecs == 1) {
							$dbsi2[3]=0;
							$sitelat = dbgetv(@dbsi2, "lat");
							$sitelon = dbgetv(@dbsi2, "lon");
							print "SITELAT = $sitelat, SITELON = $sitelon\n" if $opt_v;

							if ($firststation) { # we only have first station information when we read first arrival
								print "*First station*\n" if $opt_v;
								# Set lat, lon to first station if volcano summit not found
								if (($lat == -999.000) || ($lon == -999.000)) {
									print "Setting lat/lon to first station $sta\n" if $opt_v;
									$volcano = "regional";
									$lat = $sitelat;
									$lon = $sitelon;
								}
								$firststation = 0;
							}

							# Computing delta (angular distance)
							unless (($lat == -999.000) || ($sitelat == -999.000)) {
								print "Computing delta\n" if $opt_v;
								#$delta = distance($lat, $lon, $sitelat, $sitelon);
								$delta = dbex_eval(@dbsi2, "distance($lat, $lon, $sitelat, $sitelon)");
								my $earthcircumference = 40040; #km		
								my $vmodel = "homhalfspc";
								my %phaseVelocity = ("P" => 4.0, "S" => 2.3);
								$timeres = $delta / 360 * $earthcircumference / $phaseVelocity{$phase}; # in s
								if ($phase eq "P") {
									$timeres = $delta / 360 * $earthcircumference / $phaseVelocity{$phase}; # in s
									my $timeres2 = dbex_eval(@dbsi2, "ptime($delta,0.0)");
									$timeres = $timeres2 if ($timeres2 < $timeres);
								}
								if ($phase eq "S") {
									$timeres = $delta / 360 * $earthcircumference / $phaseVelocity{$phase}; # in s
									my $timeres2 = dbex_eval(@dbsi2, "stime($delta,0.0)");
									$timeres = $timeres2 if ($timeres2 < $timeres);	
								}
								
							}
							else
							{
								print "Skipping delta & timeres calculation for $sta ($lat, $lon, $sitelat, $sitelon)\n";
							}
							
						}
						#dbclose(@dbsi2);
						dbclose(@dbsi);
					};
					if ($@){
						print "Could not subset the site table for $sta\n";
					};

					# Only write arrival and assoc records if we have set sitelat, sitelon, delta and timeres (no longer at NULL value)
					unless ( ($sitelat == -999.000) || ($sitelon == -999.000) || ($delta == -1.000) || ($timeres == -999.000) ) {
						eval{

							# 2010-04-06: The time given in the event detected line is sometimes after the first arrival time given
							# this messes up the database, so if atime < otime, set otime = atime - 1 second
							$otime = ($atime - 1) if ($atime < $otime);

							# only add records if this STA-PHASE combination has not yet been used for this origin
							# Adding this 2010/04/07 because previously we were getting P phase arrivals on multiple channels of same station within seconds
							unless ( grep {$_ eq $sta.$phase} @staphase) {
			
								# add arrival record
								print "Adding arrival record\n" if $opt_v;
								dbaddv(@dbar, "sta", $sta, "time", $atime, "arid", $arid, "jdate", $jdate, "chanid", $chanid, "chan", $chan, 
									"iphase", $phase, "auth", "ew");
						
								# add assoc record
								print "Adding assoc record\n" if $opt_v;
								dbaddv(@dbas, "arid", $arid, "orid", $orid, "sta", $sta, "phase", $phase, "delta", $delta, "vmodel", $vmodel, "timeres", 	$timeres);
								$nass++;
								$arid++;
								print " - written\n";

								push @staphase, $sta.$phase;
							}
							else
							{

								print "- not written, matches previous arrival for $sta $phase\n";
							}
						};
						if ($@){
							print " - write failed (duplicate arrival key?)\n";
						};
					}
					else
					{
						print " - write failed (station $sta not in master_stations db)\n";
					}
	

				}
				else
				{
				#	print " - skipping (no arrival time)\n";
				}
			}
		}
		if ($line =~ /Trigger ON/ && $previous_event) {
			
			if ($otime > $statetime) {
				print "Found new event trigger. Writing orid $orid, event $evid for $subnet for previous event";
				eval{
					# Create origin record
					dbaddv(@dbo, "lat", $lat, "lon", $lon, "depth", 10.0, "time", $otime, "orid", $orid, "evid", $evid, 
						"jdate", $jdate, "nass", $nass, "ndef", $nass, "review", "n", "dtype", "g", "algorithm", substr($PROG_NAME,0,12), "auth", "ew_$subnet");
		
					# Create event record
					dbaddv(@dbe, "evid", $evid, "prefor", $orid, "auth", "ew_$subnet");
		
					print " - success\n";
					$statetime = $otime if ($#ARGV == 0); # only update statetime if running on current log file
			
				};
				if ($@){
				        ### catch block
				        print "- failed (duplicate?)\n";
				};
	
				$evid++;
				$orid++;
			}
			else
			{
				print "Origin/event row not written: otime $otime, state time $statetime\n";
			}
			$eventon = 0;
			
		}
	}

	# When a new day is started, there is no "Trigger ON" message to mark the next event in the previous log file, so need to force the write of the last event
	if (($otime > $statetime) && $previous_event) {
		print "Found new event trigger. Writing orid $orid, event $evid for $subnet for previous event";
		eval{
			# Create origin record
			dbaddv(@dbo, "lat", $lat, "lon", $lon, "depth", 10.0, "time", $otime, "orid", $orid, "evid", $evid, 
				"jdate", $jdate, "nass", $nass, "ndef", $nass, "review", "n", "dtype", "g", "algorithm", substr($PROG_NAME,0,12), "auth", "ew_$subnet");
			# Create event record
			dbaddv(@dbe, "evid", $evid, "prefor", $orid, "auth", "ew_$subnet");
	
			print " - success\n";
			$statetime = $otime if ($#ARGV == 0); # only update statetime if running on current log file
		
		};
		if ($@){
		        ### catch block
		        print "- failed (duplicate?)\n";
		};
	}


	# Update state file
	&write_statefile($statefile, $statetime) if ($#ARGV == 0);

	# write or modify descriptor
	unless (-e $dbname) {
		# Descriptor does not exist, so create it
		open (FDES, ">$dbname");
		print FDES "#\nschema rt1.0\n";
		print FDES "dblocks none\n";
		my $yyyy = substr($ymd, 0, 4);
		print FDES "dbpath $masterstationspath/{master_stations}:$archivepath/archive_$yyyy/{archive_$ymd}";
		close(FDES);
	}
	
	# close databases
	eval{
		dbclose(@dbo);
		dbclose(@dbe);
		dbclose(@dbar);
		dbclose(@dbas);
	};
	
	# Update the lastid table
	my @dblastid = dbopen_table($lastidfile, "r+");
	
	$dblastid[3] = dbfind(@dblastid, "keyname == \"arid\"");
	$dblastid[3] = 0 if ($dblastid[3]<0);
	eval{
		dbputv(@dblastid, "keyvalue", ($arid-1));
	};
	
	$dblastid[3] = dbfind(@dblastid, "keyname == \"orid\"");
	eval{
		dbputv(@dblastid, "keyvalue", ($orid-1));
	};
	
	$dblastid[3] = dbfind(@dblastid, "keyname == \"evid\"");
	eval{
		dbputv(@dblastid, "keyvalue", ($evid-1));
	};

	if ($#ARGV == 0) {

		# Loop terminated OK
		print "$PROG_NAME loop finished - sleeping for $sleeptime seconds\n";
		sleep($sleeptime);
	}
	else
	{
		$loopagain = 0;
	}

}

print "$PROG_NAME: Finished\n";
1;

###############################################################################
### LOAD PARAMETER FILE                                                      ##
### ($alarmclass, $alarmname, $msgdir, $msgpfdir, $volc_name, ...            ##  
###    $volc_code, $twin, $auth_subset, $reminders_on, $escalations_on, ...  ##
###    $cellphones_on, $reminder_time, $stathresholdsref, $newalarmref, ...  ##
###    $significantchangeref) = getParams($PROG_NAME, $opt_p, $opt_v);       ##
###                                                                          ##
### Glenn Thompson, 2009/11/13                                               ##
###                                                                          ##
### Load the parameter file for this program, given it's path                ##
###############################################################################
sub getParams {

	my ($PROG_NAME, $opt_p, $opt_v) = @_;
	my $pfobjectref = &getPf($PROG_NAME, $opt_p, $opt_v);

     
	my ($smbclient_logfileshare, $smbclient_connectionfile, $smbclient_commandfile, $logfileleader, $masterstationspath, $archivepath, $sleeptime, $avovolcspath, $carlsubtriglogdir); 

	$smbclient_logfileshare		= $pfobjectref->{'smbclient_logfileshare'};
	$smbclient_connectionfile	= $pfobjectref->{'smbclient_connectionfile'};
	$smbclient_commandfile		= $pfobjectref->{'smbclient_commandfile'};
	$logfileleader			= $pfobjectref->{'logfileleader'};
	$masterstationspath		= $pfobjectref->{'masterstationspath'};
	$archivepath			= $pfobjectref->{'archivepath'};
	$sleeptime			= $pfobjectref->{'sleeptime'};
	$avovolcspath			= $pfobjectref->{'avovolcspath'};
	$carlsubtriglogdir		= $pfobjectref->{'carlsubtriglogdir'};

	return ($smbclient_logfileshare, $smbclient_connectionfile, $smbclient_commandfile, $logfileleader, $masterstationspath, $archivepath, $sleeptime, $avovolcspath, $carlsubtriglogdir); 
}

#______________________________________________________________________________
sub otimestr2time {
	my $otimestr = $_[0];
	my $yyyy = substr($otimestr, 0, 4);
	my $mm = substr($otimestr, 4, 2);
	my $dd = substr($otimestr, 6, 2);
	my $hh = substr($otimestr, 9, 2);
	my $mi = substr($otimestr, 12, 2);
	my $ss = substr($otimestr, 15, 2);
	return ($yyyy, $mm, $dd, $hh, $mi, $ss);
}

#______________________________________________________________________________
sub subnet2latlon {
	my ($subnet, $avovolcspath) = @_;
	my %subnet2volcano = qw(
ls Little_Sitkin
ce Semisopochnoi
ss Semisopochnoi
ga Gareloi
ta Tanaga
tg Tanaga
kn Kanaga
ki Kanaga
gs Great_Sitkin
ko Korovin
ok Okmok
ma Makushin
ak Akutan
we Westdahl
sh Shishaldin
dt Dutton
du Dutton
pa Pavlof
pv Pavlof
ve Veniaminof
vn Veniaminof
an Aniakchak
pl Peulik
ug Peulik 
mg Mageik
tr Trident
ka Katmai
gr Griggs
sn Snowy
fo Fourpeaked
au Augustine
il Iliamna
rd Redoubt
sp Spurr
wa Wrangell
wr Wrangell
rg Regional
cl Cleveland
aa Amukta
bg Bogoslof
bc BonaChurhill
cm Capital
ca Carlisle
ck Chiginagek
do Douglas
dr Drum
fi Fisher
go Gordon
ha Hayes
is Isanotski
kg Kagamil
kc Kasatochi
ks Kiska
py PyrePeak
re Rescheshnoi
sa Sanford
se Seguam
sv Sheveluch
tp Tanada
vs Vsevidof
yu Yunaska
);
	my $volcano = $subnet2volcano{$subnet};
	unless (defined($volcano)) {
		print "$volcano volcano undefined\n";
		$volcano = "Unknown";
	}
	my ($lat, $lon) = -999.000; # NULL
	open (FVOL, $avovolcspath) or die("Cannot open $avovolcspath\n");
	my $found = 0;
	while (my $line = <FVOL>) {
		if ($line =~ /$volcano/) {
			$found = 1;
			my @words = split " ", $line;
			$lat = $words[1];
			$lon = $words[2];
		}
	}
	close(FVOL);
	($lat, $lon) = -999.000 if (!defined($volcano)); # NULL

	return ($lat, $lon, $volcano, $found);
}

#______________________________________________________________________________
sub read_statefile {
	my $etime = 0;
	my $statefile = $_[0];
	if (-e $statefile) {
		open(FSTI, $statefile);
		$etime = <FSTI>;
		close(FSTI);
	}
	return $etime;
}
#______________________________________________________________________________
sub write_statefile {
	my ($statefile, $etime) = @_;
	open(FSTO, ">$statefile");
	printf(FSTO "%19.6f\n", $etime);
	close(FSTO);
}

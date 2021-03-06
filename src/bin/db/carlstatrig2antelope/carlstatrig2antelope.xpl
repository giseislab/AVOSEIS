
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
our ($opt_p, $opt_v, $opt_d, $opt_c, $opt_w);
if ( ! &getopts('p:vdcw:') || $#ARGV < 0 || $#ARGV > 1  ) {
    print STDERR <<"EOU" ;

    Usage: $PROG_NAME [-p pffile] [-v] [-d] [-c] dbname [OLDLOGFILE]

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
my ($smbclient_logfileshare, $smbclient_connectionfile, $smbclient_commandfile, $logfileleader, $masterstationspath, $archivepath, $sleeptime, $avovolcspath, $carlstatriglogdir) = &getParams($PROG_NAME, $opt_p, $opt_v);

use Cwd;
our $pwd = getcwd();

our $LOGFILE;
our $dbname;
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
	&runCommand("mkdir -p $carlstatriglogdir",1);
}

my $ymd;

our $loopagain = 1;
while ($loopagain) { # daemon process

	# write SMBCLIENTFILE
	if ($#ARGV == 1) {
		# Use an old log file on the current filesystem
		open(FIN, "$OLDLOGFILE") or die("Cannot open $OLDLOGFILE\n");
		$LOGFILE = $OLDLOGFILE;
		$ymd = substr($LOGFILE, -12, 4) . "_" . substr($LOGFILE, -8, 2) . "_" . substr($LOGFILE, -6, 2);
		chomp($ymd);
	}
	else
	{
		$ymd = epoch2str(now(), "%Y_%m_%d");

		# Grab the current log file from the smbclient mounted filesystem
		$LOGFILE = $logfileleader.epoch2str(now() - 2*$sleeptime, "%Y%m%d").".log"; # GTHO 20101111: Added -$sleeptime
		# to get detections in last $sleeptime seconds of a day
		open(FCF, ">$smbclient_commandfile");
		print FCF "get $LOGFILE\n";
		close(FCF);
	
		# get LOGFILE
		&runCommand("smbclient $smbclient_logfileshare -A $smbclient_connectionfile < $smbclient_commandfile",1);
		
		# move it to CARLSTATRIGLOGDIR
		if (!(-e $LOGFILE)) {
			sleep($sleeptime);
			next;
		}
		&runCommand("mv $LOGFILE $carlstatriglogdir",1);

		# open LOGFILE or die
		open(FIN, "$carlstatriglogdir/$LOGFILE");
		if ($@){
			print "Cannot open $carlstatriglogdir/$LOGFILE\n";
			sleep($sleeptime);
			next;
		};
	}

	# open output database tables
	if ($opt_c) { # Continuous database
		$dbname = $ARGV[0];
	}
	else
	{ # Day volumes
		$dbname = $ARGV[0]."_$ymd";		
	}
	my @dbdt = dbopen_table("$dbname.detection", "r+");
	
	
	my $trigcount = 0; # this needs to be saved with off triggers, but comes from on trigger line. Saving it so I can see if it's useful for showing RSO swarm on 2010/04/05
	while (my $line = <FIN>) {


		# ON TRIGGERS
		if ($line=~/triggered on/) {
			print "TRIGGER ON\n" if $opt_v;
			my (@list);
			my $count = 0;
			my @words = split " ",$line;
			my $eta = $words[4]; # eta > 0 means trigger on, eta < 0 means trigger off - see http://www.isti2.com/ew/ovr/carltrig_ovr.html
			$trigcount = $words[8]; # number of triggers on this station(channel?) today
			foreach my $word (@words) {
				if (($word =~ "A[KVT]") || ($word =~ /\d{10}\.\d{2}/)) {
					$word =~ s/\)//;
					$list[$count] = $word;
					$count++;
				}
			}
			if ($count==2) {
				print "COUNT EQ 2 $line\n" if $opt_v;
				my @stachannet = split(/\./, $list[0]);
				my $sta = $stachannet[0];
				my $chan = $stachannet[1];
				my $net = $stachannet[2];
				my $ontime = $list[1];
							
				eval{
	        			### try block
					print "$sta $ontime $chan P ew\n" if $opt_v;
	
					# Create detection record - one for start and stop
					#my $snr = 0.01 if ($snr == 0); # should this be eta?
					if ($opt_d) {
						dbaddv(@dbdt, "srcid", $PROG_NAME, "sta", $sta, "chan", $chan, "time", $ontime, "state", "D", "filter", "ew", "snr", $eta);
					}
					else
					{
						dbaddv(@dbdt, "srcid", $PROG_NAME, "sta", $sta, "chan", $chan, "time", $ontime, "state", "ON", "filter", "ew", "snr", $eta);
					}
					$statetime = $ontime;
				};
				if ($@){
				        ### catch block
				        print "FAILED\n" if $opt_v;
				};
			}
			else
			{
				print "COUNT NE 2 $line\n" if $opt_v;
			}
		}

		# OFF TRIGGERS
		if ($line=~/triggered off/) {
			print "TRIGGER\n" if $opt_v;
			my (@list);
			my $count = 0;
			my @words = split " ",$line;
			foreach my $word (@words) {
				if (($word =~ "A[KVT]") || ($word =~ /\d{10}\.\d{2}/)) {
					$word =~ s/\)//;
					$list[$count] = $word;
					$count++;
				}
			}
			if ($count==3) {
				print "COUNT EQ 3 $line\n" if $opt_v;
				my @stachannet = split(/\./, $list[0]);
				my $sta = $stachannet[0];
				my $chan = $stachannet[1];
				my $net = $stachannet[2];
				my $ontime = $list[2];
				my $offtime = $list[1];
							
				eval{
	        			### try block
					print "$sta $ontime $chan P ew\n" if $opt_v;
	
					# Create detection record - one for start and stop
					if ($opt_d) {
						# Do nothing. On trigger already recorded.
					}
					else
					{
						dbaddv(@dbdt, "srcid", $PROG_NAME, "sta", $sta, "chan", $chan, "time", $offtime, "state", "OFF", "filter", "ew", "snr", $trigcount);
					}
	
					$statetime = $offtime;
				};
				if ($@){
				        ### catch block
				        print "FAILED\n" if $opt_v;
				};
			}
			else
			{
				print "COUNT NE 3 $line\n" if $opt_v;
			}
		}
	}
	
	# Update state file
	&write_statefile($statefile, $statetime) if ($#ARGV == 0);

	# write or modify descriptor
	unless (-e $dbname) {
		# Descriptor does not exist, so create it
		open (FDES, ">$dbname");
		print FDES "#\nschema rt1.0\n";
		print FDES "dblocks none\n";
		my $yyyy = substr($ymd,0,4);
		#print FDES "dbpath /avort/oprun/dbmaster/{master_stations}:$archivepath/archive_$yyyy/{archive_$ymd}";
		print FDES "dbpath $masterstationspath/{master_stations}:$archivepath/archive_$yyyy/{archive_$ymd}";
		close(FDES);
	}
	
	# close databases
	eval{
		dbclose(@dbdt);
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
### () = getParams($PROG_NAME, $opt_p, $opt_v);                              ##
###                                                                          ##
### Glenn Thompson, 2009/11/13                                               ##
###                                                                          ##
### Load the parameter file for this program, given its path                 ##
###############################################################################
sub getParams {

	my ($PROG_NAME, $opt_p, $opt_v) = @_;
	my $pfobjectref = &getPf($PROG_NAME, $opt_p, $opt_v);

     
	my ($smbclient_logfileshare, $smbclient_connectionfile, $smbclient_commandfile, $logfileleader,$masterstationspath, $archivepath, $sleeptime, $avovolcspath, $carlstatriglogdir); 

	$smbclient_logfileshare		= $pfobjectref->{'smbclient_logfileshare'};
	$smbclient_connectionfile	= $pfobjectref->{'smbclient_connectionfile'};
	$smbclient_commandfile		= $pfobjectref->{'smbclient_commandfile'};
        $masterstationspath             = $pfobjectref->{'masterstationspath'};
        $archivepath                    = $pfobjectref->{'archivepath'};
	$logfileleader			= $pfobjectref->{'logfileleader'};
	$sleeptime			= $pfobjectref->{'sleeptime'};
	$avovolcspath			= $pfobjectref->{'avovolcspath'};
	$carlstatriglogdir		= $pfobjectref->{'carlstatriglogdir'};

	return ($smbclient_logfileshare, $smbclient_connectionfile, $smbclient_commandfile, $logfileleader,$masterstationspath, $archivepath, $sleeptime, $avovolcspath, $carlstatriglogdir); 
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


##############################################################################
# Author: Glenn Thompson (GT) 2009
#         ALASKA VOLCANO OBSERVATORY
#
# Modifications:
#	2009-03: Created by GT
#
# Purpose:
#       dispatch alarm declarations to email/cellphones
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
our ($opt_p, $opt_t, $opt_v, $opt_r, $opt_d); 
if ( ! &getopts('p:t:vr:d') || ($#ARGV != 1) ) {
    print STDERR <<"EOU" ;

    Usage: $PROG_NAME -p parameterfile [-t runtime] [-v] [-d]  alarmid alarmdatabase

EOU
    exit 1 ;
}

# End of  GT Antelope Perl header
#################################################################
use Avoseis::Utils qw(prettyprint getPf runCommand);
my (%record, $database);

print "\n************\n$PROG_NAME @ARGV\n\n";

# READ EPOCH TIME FROM COMMAND LINE OR SET TO NOW
my $runTime; # runTime is used to define latency, and it stops alarms being dispatched if max_latency is exceeded.
if ($opt_t) {
	$runTime = $opt_t;
}
else
{
	$runTime = now();
}
my $runTimeUTC    = epoch2str($runTime,'%Y/%m/%d %k:%M:%S UTC');
print "Running $PROG_NAME at $runTimeUTC\n" if $opt_v;

# READ THE RECORD NUMBER AND DATABASE OF INTEREST FROM THE COMMAND LINE
($record{'alarmid'}, $database) = @ARGV;

# CHECK ALARMS DATABASE TO SEE IF THIS ALARM HAS BEEN ACKNOWLEDGED
# ALSO READ IN time, subject, dir AND dfile.
printf "Reading $database.alarms to get details for alarmid %d\n", $record{'alarmid'} if $opt_v;
my @db = dbopen_table("$database.alarms", "r") or die("$PROG_NAME: Cannot open $database.alarms\n");
@db = dbsubset(@db, sprintf("alarmid == %s",$record{'alarmid'})); 
$db[3] = 0;
($record{'alarmkey'}, $record{'alarmclass'}, $record{'alarmname'}, $record{'alarmtime'}, $record{'subject'}, $record{'dir'}, $record{'dfile'}, $record{'acknowledged'}, $record{'acktime'}, $record{'ackauth'}) = dbgetv(@db, "alarmkey", "alarmclass", "alarmname", "time", "subject", "dir", "dfile", "acknowledged", "acktime", "ackauth");
dbclose(@db);
prettyprint(\%record) if $opt_v;

# READ PARAMETER FILE BASED ON alarm_name. NEED max_latency, recipients ARRAY.
print "Read parameters for $PROG_NAME\n" if $opt_v;
my ($max_latency, $sleep, %recipients) = &getParams($PROG_NAME, $opt_p, $opt_v, $record{'alarmclass'}, $record{'alarmname'});

my @addresses = keys %recipients;
if ($opt_v) {
	foreach (@addresses) {
		print "$PROG_NAME: Delay for $_ is ".$recipients{$_}." seconds\n";
	}
	print("$PROG_NAME: Sleep is $sleep seconds\n");
	print("$PROG_NAME: max_latency = $max_latency\n");
}

# Special test mode settings
my $timeAdjust = 0;
if ($opt_d) {
	$timeAdjust = now() - $record{'alarmtime'};
	$runTime = $record{'alarmtime'};
	printf "timeAdjust = %s, runTime = %s", epoch2str($timeAdjust, "%H:%M"), epoch2str($runTime, "%Y-%m-%d %H:%M");
	if ($record{'acknowledged'} eq 'y') {
		print "Resetting acknowledged flag to 'n'\n";
		my @db2 = dbopen_table("$database.alarms", "r+") or die("$PROG_NAME: Cannot open $database.alarms\n");
		@db2 = dbsubset(@db2, sprintf("alarmid == %s",$record{'alarmid'}));
		$db2[3] = 0;
		dbputv(@db2, "acknowledged", 'n');
		dbclose(@db2);
		$record{'acknowledged'} = 'n';
	}
}

# LATENCY must be LESS THAn max_latency. 
my $latency = ($runTime - $record{'alarmtime'});

# SET UP THE alreadyPaged HASH
my %alreadyPaged;
foreach my $address (@addresses) {
	$alreadyPaged{$address} = 0;
}
my $numRecipientsPaged = 0;

printf "run time = %s, ", epoch2str($runTime, "%Y/%m/%d %H:%M");
printf "alarm time = %s\n", epoch2str($record{'alarmtime'}, "%Y/%m/%d %H:%M");

# Load the message file and add the confirmation page link to the end
my $messagefile = sprintf("%s/%s",$record{'dir'},$record{'dfile'});
open(F, ">>$messagefile");
use Env;
my $confirmationpage = $ENV{'INTERNALWEBPRODUCTSURL'}."/html/confirm_alarms.php";
print F "\n\nConfirm at $confirmationpage\n";
close(F);

# LOOP

while (($record{'acknowledged'} eq "n") && ($latency < $max_latency) && ($numRecipientsPaged <= $#addresses)) {
#while (($record{'acknowledged'} eq "n") && ($latency < $max_latency) ) {

	# SEND EMAIL
	my @db2 = dbopen_table("$database.alarmcomm", "r+") or die("Cannot open $database.alarmcomm");
	my $address;
	foreach $address (@addresses) {
		if ($alreadyPaged{$address}==0) {
			my $delay = $recipients{$address};	
			printf "\nrecipient = $address, delay = $delay, latency now = %0.f, will time out after $max_latency\n", $latency;
			if ($latency >= $delay) {
				printf("$PROG_NAME: ALARM! Sending email to $address, latency now is %.0f seconds\n",$latency);
				$record{'subject'} = "TEST ONLY - IGNORE" if ($opt_d);
				&runCommand(sprintf("cat $messagefile | rtmail -d -f AVOSEIS_ALARM\@giseis.alaska.edu -s \"%s\" %s &", $record{'subject'}, $address), 1 );
				# LOG EMAIL IN THE ALARMCOMM TABLE
				$db2[3] = dbaddnull(@db2);
				dbputv(@db2, "alarmid", $record{'alarmid'}, "delaysec", $latency, "recipient", $address);    

				# NOW MAKE SURE THIS RECIPIENT IS NOT PAGED AGAIN
				$alreadyPaged{$address} = 1;
				$numRecipientsPaged++;
			}
		}

		# CHECK AGAIN FOR ACKNOWLEDGEMENT
		my @db3 = dbopen_table("$database.alarms", "r") or die("Cannot open $database.alarms\n");
		@db3 = dbsubset(@db3, sprintf("alarmid == %s",$record{'alarmid'}));
		my $nrecs = dbquery(@db3, "dbRECORD_COUNT");
		if ($nrecs == 1) {	
			$db3[3]=0;
			($record{'ackauth'}, $record{'acknowledged'}, $record{'acktime'}) = dbgetv(@db3, 'ackauth', 'acknowledged', 'acktime');
		}
		else
		{
			die("$PROG_NAME: Got $nrecs records for ".$record{'alarmid'}."\n");
		}
		#dbclose(@db3); # closing this here kills the connection to db2

		$runTime = now() - $timeAdjust;
		$latency = ($runTime - $record{'alarmtime'});
	}
	dbclose(@db2);

	# SLEEP FOR A WHILE
	sleep($sleep); # sleep for $sleep seconds
	
}
print "While loop ended" if $opt_v;

if ($record{'acknowledged'} eq "y") {
	my $responseLatency = $record{'acktime'} - $record{'alarmtime'};
	my $acktimestr =  epoch2str($record{'acktime'}, "%Y/%m/%d %H:%M");
	printf("\n$PROG_NAME: Alarm %s acknowledged at $acktimestr by %s: response latency %.0f seconds\n",$record{'alarmkey'}, $record{'ackauth'}, $responseLatency);
}
else
{
	printf("\n$PROG_NAME: Alarm %s not acknowledged",$record{'alarmkey'}) if $opt_v;
}
	


# Success
1;

###############################################
############# SUBROUTINES FOLLOW ##############
###############################################

###############################################################################
### LOAD PARAMETER FILE                                                      ##
###                                                                          ##
### Glenn Thompson, 2009/04/20                                               ##
###                                                                          ##
### Load the parameter file for this program, given it's path                ##
###############################################################################
sub getParams {

	my ($PROG_NAME, $opt_p, $opt_v, $alarmclass, $alarmname) = @_;
	my $pfobjectref = &getPf($PROG_NAME, $opt_p, $opt_v);
     
	my ($max_latency, $sleep, %recipients, %default);



	# FIRST GET THE DEFAULT PARAMETERS
	%default = %{$pfobjectref->{'default'}};
        $max_latency  = $default{"max_latency"};
        $sleep  = $default{"sleep"};
	%recipients = %{$default{"recipients"}};

	# NOW LOOK FOR OVERRIDES
	print "Looking for Arrays matching alarmclass=$alarmclass\n";
	my $overrideref = $pfobjectref->{$alarmclass};
	if (defined($overrideref)) {
		print "Override found\n";
		my %overridehash = %$overrideref;
		if (defined($overridehash{"max_latency"})) {
	        	$max_latency  = $overridehash{"max_latency"};
		}
		if (defined($overridehash{"sleep"})) {
	        	$sleep  = $overridehash{"sleep"};
		}
		my $extrarecipientsref = $overridehash{"recipients"};
		if (defined($extrarecipientsref)) {
			%recipients = (%recipients, %$extrarecipientsref);
		}
	}
	
	print "Looking for Arrays matching alarmname=$alarmname\n";
	$overrideref = $pfobjectref->{$alarmname};
	if (defined($overrideref)) {
		print "Override found\n";
		my %overridehash = %$overrideref;
		if (defined($overridehash{"max_latency"})) {
	        	$max_latency  = $overridehash{"max_latency"};
		}
		if (defined($overridehash{"sleep"})) {
	        	$sleep  = $overridehash{"sleep"};
		}
		my $extrarecipientsref = $overridehash{"recipients"};
		if (defined($extrarecipientsref)) {
			%recipients = (%recipients, %$extrarecipientsref);
		}
	}
	return ($max_latency, $sleep, %recipients); 

}




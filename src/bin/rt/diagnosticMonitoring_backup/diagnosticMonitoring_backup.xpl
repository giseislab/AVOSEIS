
##############################################################################
# Author: Glenn Thompson (GT) 2010
#         ALASKA VOLCANO OBSERVATORY
#
# Description:
#	Simply check that diagnosticMonitoring has run within past 2 hours. If not, declare alarm.
# History:
#	2010-07-12:  Created by GT.
#
# To do:
##############################################################################

use Datascope;
use Getopt::Std;

use strict;
#use warnings;

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

# End of  GT Antelope Perl header
#################################################################

use Avoseis::AlarmManager qw(writeAlarmsRow writeMessage);
my $DBALARM = "dbalarm/alarm";
foreach $dir ("/avort/oprun", "/avort/devrun") {
	my $logfile = "$dir/logs/cron-diagnostics";
	if (-e $logfile) {
		if (-M $logfile > 1/24) {
			&declareDiagnosticAlarm("diagnosticMonitoring not running?", "$logfile not being updated", $DBALARM);
		}
	}
	else
	{
			&declareDiagnosticAlarm("diagnosticMonitoring not running?", "$logfile does not exist", $DBALARM);
	}a
} 
printf("Ran $PROG_NAME at %s\n\n", epoch2str(now(),"%Y-%m-%d %H:%M:%S"));
###################################### SUBROUTINES FOLLOW ###################################

sub declareDiagnosticAlarm {

	my ($subject, $txt, $alarmdb) = @_;
	my $msgType = "$PROG_NAME";
	my $alarmclass = "diagnostic";
	my $alarmname = "diagnostic";

	$txt = "$subject\n$txt\n";

	eval {
		# addAlarmsRow
		my $alarmid = `dbnextid $alarmdb alarmid`; 
		chomp($alarmid);
		my $alarmkey = $alarmid;
		my $alarmtime = now(); 
		my $mdir = "dbalarm/alarmaudit/diagnostic";
		my $mdfile = $alarmtime;

		# writeMessage file
		&writeMessage($mdir, $mdfile, $txt);

		&writeAlarmsRow($alarmdb, $alarmid, $alarmkey, $alarmclass, $alarmname, $alarmtime, $subject, $mdir, $mdfile);
	};
	if ($@) {
		system("echo \"$PROG_NAME failed to write diagnostic alarm to $alarmdb\n$txt\" | rtmail -s \"Alarm write failed\" gthompson\@alaska.edu");
	}

}


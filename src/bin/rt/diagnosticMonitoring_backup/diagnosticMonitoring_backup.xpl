
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

use Avoseis::AlarmManager qw(writeAlarmsRow writeMessage declareDiagnosticAlarm);
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


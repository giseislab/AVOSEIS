package Avoseis::AlarmManager;

#use 5.000000;
use strict;
use warnings;

require Exporter; 

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Avoseis::AlarmManager ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

# variable names
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

# subroutines
our @EXPORT = qw( 
getPrevMsgPfPath
writeAlarmsRow
writeAlarmcacheRow
getMessagePath   
writeMessage 
getMessagePfPath 
declareDiagnosticAlarm
);

#our $VERSION = '0.01';
our $VERSION = sprintf "%d.%03d", q$Revision: 1.5 $ =~ /: (\d+)\.(\d+)/;

use Datascope;

# globals


# Preloaded methods go here.

#####################################################################################
### GETPREVMSGPFPATH                                                               ##
### ($dir, $dfile, $msgTime, $alarmkey) = getPrevMsgPfPath($alarmdb, $alarmname);  ##
###                                                                                ##
### Glenn Thompson, 2009/04/20                                                     ##
###                                                                                ##
### Given an alarm database and an alarm (algorithm) name, get the                 ##
### directory path, filename and time of the most recent message of that           ##
### alarm name.                                                                    ##
###
### This was part of the system where a temporary parameter file was used to track 
### the most recent state/metrics of a particular alarm name.
### It was used in the first generation of the swarm alarm system, where next the
### function:
###	 %prev = Avoseis::SwarmTracker::getSwarmParams($dir, $dfile) would be called.
#####################################################################################
sub getPrevMsgPfPath {
	my ($alarmdb, $alarmname) = @_;
	my ($alarmid, $dir, $dfile, $msgTime, $alarmkey);
	$dir = "dummy"; $dfile = "dummy";

	my @dbalarm = dbopen_table($alarmdb.".alarms", "r");
	@dbalarm = dbsubset( @dbalarm, "alarmname == \"$alarmname\"");
	my $nrecs = dbquery( @dbalarm, "dbRECORD_COUNT");

	my $lastAlarmTime = 0;
	if ($nrecs > 0) {
		$dbalarm[3] = $nrecs - 1;
		($alarmid, $msgTime, $alarmkey) = dbgetv(@dbalarm, "alarmid", "time", "alarmkey");
	}
	dbclose(@dbalarm);

	if ($nrecs > 0) {

		@dbalarm = dbopen_table($alarmdb.".alarmcache", "r");
		@dbalarm = dbsubset( @dbalarm, "alarmid == \"$alarmid\"");
		$nrecs = dbquery( @dbalarm, "dbRECORD_COUNT");
		if ($nrecs > 0) {
			$dbalarm[3] = $nrecs - 1;
			($dir, $dfile) = dbgetv(@dbalarm, "dir", "dfile");
		}
		dbclose(@dbalarm);
	}

	return ($dir, $dfile, $msgTime, $alarmkey);
}

###################################################################################
### WRITEMESSAGE                                                                 ##
### $success = writeMessage($mdir, $mdfile, $txt)                                ##
###                                                                              ##
### Glenn Thompson, 2009/04/22                                                   ##
###                                                                              ##
### Write the text message to this dir/dfile                                     ##
###################################################################################
sub writeMessage {
	my ($mdir, $mdfile, $txt) = @_;
	unless (-e $mdir) {
		system("mkdir -p $mdir")
	}
	open(FOUT, ">$mdir/$mdfile");
	print FOUT $txt;
	close(FOUT);
	return 1;
}


###################################################################################
### GETMESSAGEPATH                                                               ##
### ($msgdir, $msgdfile) = getMessagePath($msgTime, $msgdir, $alarmname)         ##
###                                                                              ##
### Glenn Thompson, 2009/04/22                                                   ##
###                                                                              ##
### Get the path to write this message file to                                   ##
###################################################################################
sub getMessagePath {
	my ($msgTime, $msgdir, $alarmname)=@_;
	my ($msgdfile);
	$msgdir = epoch2str($msgTime, "$msgdir/$alarmname/%Y/%m");
	$msgdfile = epoch2str($msgTime, '%d%H%M').".txt"; 
	return ($msgdir, $msgdfile);
}

###################################################################################
### GETMESSAGEPFPATH                                                             ##
### ($msgpfdir, $msgpfdfile) = getMessagePfPath($msgTime, $msgpfdir, $alarmname) ##
###                                                                              ##
### Glenn Thompson, 2009/04/22                                                   ##
###                                                                              ##
### Get the path to write this message parameter file to                         ##
###################################################################################
sub getMessagePfPath {
	my ($msgTime, $msgpfdir, $alarmname)=@_;
	my ($msgpfdfile);
	$msgpfdir = epoch2str($msgTime, "$msgpfdir/$alarmname/%Y/%m");
	$msgpfdfile = epoch2str($msgTime, '%d%H%M').".pf"; 
	return ($msgpfdir, $msgpfdfile);
}

###################################################################################
### WRITEALARMSROW                                                               ##
### writeAlarmsRow($dbalarm, $alarmid, $alarmkey, $alarmclass, $alarmname, ...   ##
###    $alarmtime, $subject, $dir, $dfile)                                       ##
###                                                                              ##
### Glenn Thompson, 2009/04/20                                                   ##
###                                                                              ##
### Write a row to an alarms table in $dbalarm                                   ##
###################################################################################
sub writeAlarmsRow {

	my ($dbalarm,  $alarmid, $alarmkey, $alarmclass, $alarmname, $alarmtime, $subject, $dir, $dfile) = @_;
	my (@db);


	# WRITE FIELD TO ALARMS TABLE
	@db = dbopen($dbalarm, "r+");
        @db = dblookup( @db, 0, "alarms", 0, 0 );
	$db[3] = dbaddnull(@db);
	print "$0: Writing row for $alarmkey into $dbalarm.alarms\n";
	dbputv(@db, "alarmid", $alarmid, "alarmkey", $alarmkey, "alarmclass", $alarmclass, "alarmname", $alarmname,
		"time", $alarmtime, "subject", $subject, "acknowledged", "n", "dir", $dir, "dfile", $dfile);
	dbclose(@db);

	return 1;
}

###################################################################################
### WRITEALARMCACHEROW                                                           ##
### writeAlarmcacheRow($dbalarm, $alarmid, $dir, $dfile)                         ##
###                                                                              ##
### Glenn Thompson, 2009/04/20                                                   ##
###                                                                              ##
### Write a row to an alarmcache table in $dbalarm                               ##
###################################################################################
sub writeAlarmcacheRow {

	my ($dbalarm, $alarmid, $dir, $dfile) = @_;
	my (@db);

	# WRITE FIELD TO ALARMS TABLE
	@db = dbopen($dbalarm, "r+");
        @db = dblookup( @db, 0, "alarmcache", 0, 0 );
	$db[3] = dbaddnull(@db);
	print "$0: Writing row for $alarmid $dir/$dfile into $dbalarm.alarmcache\n";
	dbputv(@db, "alarmid", $alarmid, "dir", $dir, "dfile", $dfile);
	dbclose(@db);

	return 1;
}


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
                system("echo \"$PROG_NAME failed to write diagnostic alarm to $alarmdb\n$txt\" | mailx -s \"Alarm write failed\" gthompson\@alaska.edu");
        }

}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Avoseis::AlarmManager - Perl extension for the AVOSeis alarm management system

=head1 SYNOPSIS

  use Avoseis::AlarmManager;


=head1 DESCRIPTION

Avoseis::AlarmManager was created with h2xs -AXc -n Avoseis::Swarmalarm. 

=head2 EXPORT

None by default.

=head2 FUNCTIONS

# get the path to the last message of this alarmname
($dir, $dfile, $msgTime) = getPrevMsgPfPath($alarmdb, $alarmname);  

# get the path to put this message to
($dir, $dfile) = getMessagePath($msgTime, $msgdir, $alarmname);

# get the path to put this message pf to
($dir, $dfile) = getMessagePfPath($msgTime, $msgpfdir, $alarmname);

# write the alarms row
writeAlarmsRow($dbalarm, $alarmid, $alarmkey, $alarmclass, $alarmname, ...    
    $alarmtime, $subject, $dir, $dfile);  

# write the alarmcache row
writeAlarmscacheRow($dbalarm, $alarmid, $dir, $dfile);

declareDiagnosticAlarm($subject, $txt, $alarmdb);

=head2 DATA STRUCTURES

=head1 SEE ALSO

=head1 AUTHOR

Glenn Thompson, E<lt>glenn@giseis.alaska.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Glenn Thompson, University of Alaska Fairbanks

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut

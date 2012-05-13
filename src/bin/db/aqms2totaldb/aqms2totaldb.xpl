##############################################################################
# Author: Glenn Thompson (GT) 2011/11/11
#         ALASKA VOLCANO OBSERVATORY
#
# Modifications:
#       2012-05-11: Created by GT, based on AQMS_to_Datascope_Vision Google Doc
#
##############################################################################
use strict;
use warnings;
use Datascope;

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

my $yyyy = epoch2str(now(), "%Y");
my $dir = "/Seis/Kiska4/picks/$yyyy/database";
my $mm = epoch2str(now(), "%m");
my $monthdb = "db$yyyy"."_$mm";
my $startdate = "$yyyy/$mm/01";
++$mm;
if ($mm == 13) {
	$mm =  "01";
	$yyyy++;
}
my $enddate = "$yyyy/$mm/01";
if (-e $monthdb) {
	unlink($monthdb);
	unlink("$monthdb.*");
}
system("aqms2db \"$startdate\" \"$enddate\" $monthdb");
if (-e $dir) {
	print "Copying $monthdb to $dir/$monthdb\n";
	if (-e "$dir/$monthdb") {
		unlink("$dir/$monthdb*");
	}
	system("dbcp $monthdb $dir/$monthdb");
	unlink("$monthdb*");
} else { 
	print "$dir does not exist\n";
}
system("make_total_database");

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
use Env;

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path
my $monthlydb = $ENV{'MONTHLYDB');
die("Cannot write to $monthlydb\n") unless (-w $monthlydb);
my $yyyy = epoch2str(now(), "%Y");
my $dir = "$monthlydb/$yyyy";
mkdir $dir unless (-d $dir);
my $mm = epoch2str(now(), "%m");
my $monthdb = "db$yyyy"."_$mm";
my $startdate = "$yyyy/$mm/01";
++$mm;
if ($mm == 13) {
	$mm =  "01";
	$yyyy++;
}
my $enddate = "$yyyy/$mm/01";
print("aqms2db \"$startdate\" \"$enddate\" $monthdb\n");
system("aqms2db \"$startdate\" \"$enddate\" $monthdb");
if (-e $dir) {
	print "moving $monthdb to $dir/$monthdb\n";
	system("mv $monthdb* $dir/");
} else { 
	print "$dir does not exist\n";
}
print("Calling make_total_database.\n");
system("make_total_database");
system("volcanoviews2volc2 -p pf/volcanoviews2volc2_datascope.pf");

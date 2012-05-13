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
#use Datascope;
#use URI::Escape;
require "getopts.pl";

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

# Usage
our ($opt_d);
if (  ! &Getopts('d') || $#ARGV < 2  ) {
    print STDERR <<"EOU" ;

    $PROG_NAME is used to read all finalized hypocenters from Tom Parker's AQMS web catalog search page, in hypoinverse 2000 format.
    Steps:
	1. Craft an appropriate url get query string from input arguments. 
	2. Send it to Tom Parker's web catalog search page (which itself wraps dbselect).
	3. Output a single file containing multiple Hypoinverse origin summary line and shadow cards (containing phase data).

    Usage: $PROG_NAME [-d] startdate enddate dbname [urltocatalogsearchpage]

    Options:
	-d 
		Delete the temporary hypoinverse file (results.hyp).

    Command line arguments: 
	startdate - Date corresponding to the earliest hypocenters to fetch (UTC) formatted as YYYY/MM/DD
	enddate - Date corresponding to the latest hypocenters to fetch (UTC) formatted as YYYY/MM/DD
	 - the path of the file to save the Hypoinverse 2000 format data to.
	dbname - name of the database to create.
	urltocatalogsearchpage - the URL of Tom Parker's AQMS web catalog search page. If omitted defaults to  
					http://www.avo.alaska.edu/admin/catalog/catalogResults.php

    Example: Get all finalized hypocenters from AQMS for the month of March, 2012:
	$PROG_NAME \"2012/03/01\" \"2012/04/01\" db2012_03 \"http://www.avo.alaska.edu/admin/catalog/catalogResults.php\"

EOU
    exit 1 ;
}

my ($STARTDATE, $ENDDATE, $DBNAME) = @ARGV;
my $URL;
if ($#ARGV == 3) {
	$URL = $ARGV[3];
} else {
	$URL = "http://www.avo.alaska.edu/admin/catalog/catalogResults.php";
}
my $OUTFILE = "results.hyp";
system("aqmswebsrvc2hypoinverse $STARTDATE $ENDDATE $OUTFILE $URL");
my $firstid = &getfirstid($STARTDATE);
print("hypoinverse2db -f $firstid -p hypoinverse2db $DBNAME\n");
system("hypoinverse2db -f $firstid -p hypoinverse2db $DBNAME");
unlink($OUTFILE) if ($opt_d);
1;
#################
sub getfirstid {
	my $startdate = $_[0];
	my ($idyr, $idmn, $dd) = split('/', $startdate);
	# generate monthnum - the month number beginning with Jan 1981
  	# This number is used as the first id for orid, evid and arid
  	my ($monthnum) = 12*($idyr-1980)+$idmn;
  	my ($firstid) = $monthnum.'00000';
  	return $firstid;
}


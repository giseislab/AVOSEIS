##############################################################################
# Author: Glenn Thompson (GT) 2011/11/11
#         ALASKA VOLCANO OBSERVATORY
#
# Modifications:
#       2012-05-04: Created by GT, based on AQMS_to_Datascope_Vision Google Doc
#
##############################################################################
use strict;
use warnings;
use URI::Escape;
require "getopts.pl";

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

# Usage
our ($opt_f, $opt_v);
if (  ! &Getopts('f:v') || $#ARGV < 2  ) {
    print STDERR <<"EOU" ;

    $PROG_NAME is used to read all finalized hypocenters from Tom Parker's AQMS web catalog search page, in hypoinverse 2000 format.
    Steps:
	1. Craft an appropriate url get query string from input arguments. 
	2. Send it to Tom Parker's web catalog search page (which itself wraps dbselect).
	3. Output a single file containing multiple Hypoinverse origin summary line and shadow cards (containing phase data).

    Usage: $PROG_NAME [-f format] startdate enddate outputhypo2000filename [urltocatalogsearchpage]

    Options:
	-v 	verbose mode on
	-f format
		Optional. Any of the formats allowed by the AQMS web catalog search page, e.g.
		ncedc, summary, detail, hypo, hyposha, hyposum, uw2. Default is hyposha.

    Command line arguments: 
	startdate - Date corresponding to the earliest hypocenters to fetch (UTC) formatted as YYYY/MM/DD
	enddate - Date corresponding to the latest hypocenters to fetch (UTC) formatted as YYYY/MM/DD
	outputhypo2000filename - the path of the file to save the Hypoinverse 2000 format data to.
	urltocatalogsearchpage - the URL of Tom Parker's AQMS web catalog search page. If omitted defaults to  
					http://www.avo.alaska.edu/admin/catalog/catalogResults.php

    Example: Get all finalized hypocenters from AQMS between from 00:00 March 1st, 2012 to 00:00 March 2nd, 2012:
	$PROG_NAME \"2012/03/01\" \"2012/03/02\" results.hyp \"http://www.avo.alaska.edu/admin/catalog/catalogResults.php\"

EOU
    exit 1 ;
}

my ($STARTDATE, $ENDDATE, $OUTFILE) = @ARGV;
my $TMPFILE = "$OUTFILE.tmp";
my $URL;
if ($#ARGV == 3) {
	$URL = $ARGV[3];
} else {
	$URL = "http://www.avo.alaska.edu/admin/catalog/catalogResults.php";
}
$opt_f = "hyposha" unless defined($opt_f);
print "opt_f = $opt_f\n" if ($opt_v);

my $querystring = "from=$STARTDATE&to=$ENDDATE&volcano=Any&radius=50&review=F&format=$opt_f&result=display";
$URL .= "?".$querystring;
print("wget --no-check-certificate --user=internalavo --password=volcs4avo --output-document=$TMPFILE \"$URL\"\n");
system("wget --no-check-certificate --user=internalavo --password=volcs4avo --output-document=$TMPFILE \"$URL\"");
open(FIN, $TMPFILE) or die("$TMPFILE not downloaded\n"); 
open(FOUT, ">$OUTFILE") or die("$OUTFILE not created\n"); 
 
while(my $line=<FIN>) {
	$line =~ s|<.+?>||g;
	print FOUT "$line";
}
close(FIN);
close(FOUT);
system("rm $TMPFILE");

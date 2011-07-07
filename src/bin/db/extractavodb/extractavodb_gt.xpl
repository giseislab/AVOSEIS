
# extractavodb
# Create database of avo data from requested date range
# Michael West
# 10/2006	created
# 02/2007	added "origins only" option
# 01/2008   rewritten from scratch to draw from AVO Total database
# 05/2010 Modified by GT to work from any database optionally
#
# TO-DO (old stuff - Michael West stuff)
# This script requires the "Total" database. Do not impliment until Total is a robust data source
# stamag table is not currently included. Not sure how to join it.

use Datascope ;
use Getopt::Std;



sub do_origin_tables {

	$start_date_epoch = str2epoch($start_date);
	$end_date_epoch = str2epoch($end_date);
	@db_dscr = dbopen($dbin,'r');
	@db = dblookup(@db_dscr,"","origin","",1);
	@db = dbsubset(@db,"(time>=$start_date_epoch) && (time<=$end_date_epoch)");
	$nrecords = dbquery(@db,"dbRECORD_COUNT");
	print "number of origin records: $nrecords\n";
	if (-e "$dbin.origerr") {
		@db2 = dblookup(@db_dscr,"","origerr","",1);
		@db  = dbjoin(@db,@db2,-outer) if(dbquery(@db2,"dbRECORD_COUNT")>0);
	}
	if ($DO_EXP) {
		@db = dbsubset(@db,"$exp");
	}
	@db = dbsort(@db,'time');
	@db2 = dblookup(@db_dscr,"","event","",1);
	@db  = dbjoin(@db,@db2);
	if (-e "$dbin.netmag") {
		@db2 = dblookup(@db_dscr,"","netmag","",1);
		@db  = dbjoin(@db,@db2,-outer) if(dbquery(@db2, "dbRECORD_COUNT")>0);
	}
	if (dbquery(@db,"dbTABLE_PRESENT")) {
		@db2 = dblookup(@db_dscr,"","remark","",1);
		@db  = dbjoin(@db, @db2,-outer) if (dbquery(@db2, "dbRECORD_COUNT")>0);
	}
	$nrecords = dbquery(@db,"dbRECORD_COUNT");
	print "number of origin records: $nrecords\n";


	# ADD OPTIONAL ARRIVAL/ASSOC/STAMAG TABLES
	if ( ($nrecords > 5000) && (!$opt_f) ) {
		die("You have requested more than 5000 earthquakes. This may require extensive processing time. Consider submitting smaller requests. If you really want to submit this entire request, use the -f flag.\n");
	}
	if ($nrecords == 0) {
		die("database does not exist or it contains no origin records");
	}
	if ($opt_a) {
		if ( ($nrecords > 500) && (!$opt_f) ) {
			die("You have requested arrival information from more than 500 earthquakes. This may require extensive processing time. Consider submitting smaller requests. If you really want to submit this entire request, use the -f flag.\n");
		}
		#@db2 = dbsubset(@db2,"(time>=$start_date_epoch) && (time<=$end_date_epoch)");
		@db2 = dblookup(@db_dscr,"","assoc","",1);
		@db  = dbjoin(@db,@db2);
		@db2 = dblookup(@db_dscr,"","arrival","",1);
		@db  = dbjoin(@db,@db2);
		$nrecords = dbquery(@db,"dbRECORD_COUNT");
		@db2 = dblookup(@db_dscr,"","stamag","",1);
		@db  = dbjoin(@db,@db2, -outer);
		print "number of arrival records: $nrecords\n";
	}	


	# CREATE OUTPUT DATABASE
	dbunjoin(@db,$dbout);
}


sub descriptor {
        open(OUT,">$_[0]");
        print OUT "\#\n";
        print OUT "schema css3.0\n";
        print OUT "dblocks\n";
        print OUT "dbidserver\n";
        print OUT "dbpath\n";
        close(OUT);
}






##############################################

# SET CONSTANTS
$dbin = "/Seis/Kiska4/picks/Total/Total";

$Usage = "

Usage: $0 [-af] [-i dbin] \"start_date\" \"end_date\" dbout [expression]

Create a new database containing all AVO event data for the given time 
range. If the database already exists it is overwritten. The start time, 
end times and output database name are required. Times can be given in 
any of the Antelope accepted formats. Optional expressions follow the 
conventional (if sometimes opaque) Antelope nomenclature. Expressions may 
refer to any field contained in origin and origerr tables. Examples are 
given below. The expression must be in quotes.

-a  includes the arrival, assoc, and stamag tables. Without this flag, 
    these tables are not included. Including these tables slows down the 
    request by an order of magnitude or more. If arrivals are needed, 
    however, this flag must be used.

-f  force extractavodb to carry out large requests for phase arrival 
    information. Without this flag, requests will abort if more than 5000
    origins are requested or if arrivals from more than 500 earthquakes are 
    requested.
    
Examples:

1) Extract eight years of events occurring within 15 km of
   Gareloi summit:
    extractavodb \"1/1/2000\" \"12/31/2007 23:59:59\" dbout \\
      \"deg2km(distance(lat,lon,51.7892,-178.796))<15\"

2) Extract 2006 events in Katmai region EXCLUDING those near Martin:
   extractavodb \"1/1/2006\" \"1/1/2007\" dbout \\
      \"deg2km(distance(lat,lon,58.3,-154.9))<50 && \\
       deg2km(distance(lat,lon,58.1692,-155.3566))>3\"

3) Extract all AVO earthquakes larger than magnitude 3.0
    extractavodb \"1989-001\" \"now\" dbout \"ml>3.0\"

4) Extract all deep b-type events within 20 km of Spurr, including 
   arrival information:
    extractavodb -a \"1/1/1989\" \"now\" dbout \\
     \"(deg2km(distance(lat,lon,61.299,-152.254))<25 && depth>20 && etype=~/b/)\"\n";


# READ INPUTS
#$opt_a = $opt_o = $opt_f = 0; # Kill "variable used once" error
if (  ! &getopts('aofi:') ||  ($#ARGV<1) || ($#ARGV>4) ) {
	die($Usage);
}
$start_date = $ARGV[0];
$end_date = $ARGV[1];
$dbout = $ARGV[2];
if ($#ARGV==3) {
	$DO_EXP = 1;
	$exp = $ARGV[3];
} else {
	$DO_EXP = 0;	
}
$dbin = $opt_i if $opt_i;

if ($opt_o) {
	warn("WARNING: the -o flag is now obsolete. By default, arrival, assoc and stamag tables are not produced. These tables may be included with the -a flag.\n");
}


# SWITCH START AND END DATE IF NECESSARY
$dt = str2epoch($end_date)-str2epoch($start_date);
if ($dt < 0) {
	print "Start and end dates are reversed\n";
	$tmp_date   = $end_date;
	$end_date   = $start_date;
	$start_date = $tmp_date;
}


# PREPARE TABLES
&do_origin_tables
&descriptor($dbout);


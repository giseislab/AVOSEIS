##############################################################################
# Authors: Michael West (MEW), Glenn Thompson (GT) 2006-2011
#         ALASKA VOLCANO OBSERVATORY
#
# Description:
# Extract part of the AVO catalog (or optionally any other catalog in CSS3.0 format)
# Michael West, Glenn Thompson
#
# History:
# 10/2006 created (MEW)
# 02/2007 added "origins only" option (MEW)
# 01/2008 rewritten to draw from AVO Total database (MEW)
# 05/2010 Modified to work from any database optionally (GT)
# 08/2011 Modified to check database tables exist before joining them (GT)
#       
# To do:
#
##############################################################################

use Datascope ;
use Getopt::Std;

#use strict;
#use warnings;

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

# Usage - command line options and arguments
our ($opt_a, $opt_f, $opt_i);
if (  ! &getopts('afi:') ||  ($#ARGV<1) || ($#ARGV>4) ) {
    print STDERR <<"EOU" ;

    Usage: $PROG_NAME [-af] [-i dbin] \"start_date\" \"end_date\" dbout [expression]
    
    For more information:
        > man $PROG_NAME
EOU
    exit 1 ;
}

# End of Perl header
#################################################################

printf("\n\nRunning $PROG_NAME at %s\n\n", epoch2str(now(),"%Y-%m-%d %H:%M:%S"));

#### COMMAND LINE ARGUMENTS
our ($start_date, $end_date, $dbout) = @ARGV[0..2];
our $subset_expression = "";
$subset_expression = $ARGV[3] if ($#ARGV>2);

# INPUT DATABASE
our $dbin = "/Seis/Kiska4/picks/Total/Total";
$dbin = $opt_i if $opt_i;

# SWITCH START AND END DATE IF NECESSARY
print $start_date,"\n";
print $end_date,"\n";
my $dt = str2epoch($end_date)-str2epoch($start_date);
if ($dt < 0) {
	print "Start and end dates are reversed\n";
	$tmp_date   = $end_date;
	$end_date   = $start_date;
	$start_date = $tmp_date;
}

&do_origin_tables
&descriptor($dbout);

##############################################

sub do_origin_tables {

	$start_date_epoch = str2epoch($start_date);
	$end_date_epoch = str2epoch($end_date);
	@db_dscr = dbopen($dbin,'r');
	@db = dblookup(@db_dscr,"","origin","",1);
	@db = dbsubset(@db,"(time>=$start_date_epoch) && (time<=$end_date_epoch)");
	$nrecords = dbquery(@db,"dbRECORD_COUNT");
	print "number of origin records after time subset: $nrecords\n";
	die if ($nrecords < 1);
	if (-e "$dbin.origerr") {
		@db2 = dblookup(@db_dscr,"","origerr","",1);
		@db  = dbjoin(@db,@db2,-outer) if(dbquery(@db2,"dbRECORD_COUNT")>0);
	}
	if ($subset_expression) {
		@db = dbsubset(@db,"$subset_expression");
	}
	@db = dbsort(@db,'time');
	@db2 = dblookup(@db_dscr,"","event","",1);
	@db  = dbjoin(@db,@db2);
	if (-e "$dbin.netmag") {
		@db2 = dblookup(@db_dscr,"","netmag","",1);
		@db  = dbjoin(@db,@db2,-outer) if(dbquery(@db2, "dbRECORD_COUNT")>0);
	}
	if (-e "$dbin.remark") {
		@db2 = dblookup(@db_dscr,"","remark","",1);
		@db  = dbjoin(@db, @db2,-outer) if (dbquery(@db2, "dbRECORD_COUNT")>0);
	}
	$nrecords = dbquery(@db,"dbRECORD_COUNT");
	print "number of origin recordsi after all subsets: $nrecords\n";


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
		if (-e "$dbin.assoc") {
			@db2 = dblookup(@db_dscr,"","assoc","",1);
			@db  = dbjoin(@db,@db2) if(dbquery(@db2, "dbRECORD_COUNT")>0);
		}
		if (-e "$dbin.arrival") {
			@db2 = dblookup(@db_dscr,"","arrival","",1);
			@db  = dbjoin(@db,@db2) if(dbquery(@db2, "dbRECORD_COUNT")>0);
		}
		if (-e "$dbin.arrival") {
			@db2 = dblookup(@db_dscr,"","stamag","",1);
			@db  = dbjoin(@db,@db2, -outer) if(dbquery(@db2, "dbRECORD_COUNT")>0);
		}
		print "number of arrival records: $nrecords\n";
	}	


	# CREATE OUTPUT DATABASE
	dbunjoin(@db,$dbout);
}

##############################################

sub descriptor {
        open(OUT,">$_[0]");
        print OUT "\#\n";
        print OUT "schema css3.0\n";
        print OUT "dblocks\n";
        print OUT "dbidserver\n";
        print OUT "dbpath\n";
        close(OUT);
}










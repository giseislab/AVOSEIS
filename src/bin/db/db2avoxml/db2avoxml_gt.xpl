

##############################################################################
# Author: Michael West 2008/01
#         Geophysical Institute, University of Alaska Fairbanks
#
# Modifications: Glenn Thompson
#	2010/10/27: Added this new program header. Changed all references to KML to XML.
#	2010/10/27: Added "reviewed" field to list of fields read and output in XML.
#	2010/11/02: Changed icon style for unreviewed events
#	2010/11/02: Added subset expressions with -e option
#
# Purpose:
#       Convert a database to XML suitable for display with Seth Snedigars Google Maps app.. 
#
# History:
# 	This program has been modified from db2kml.
# 	It is not related to the Antelope program db2xml created by Kent Lindquist
#
#
##############################################################################

use Datascope;
use Getopt::Std;

# SET MAXIMUM NUMBER OF EVENTS
$maxevents = 1000;

#USAGE
$Usage = "
Usage: db2avoxml [-sob] [-e subset_expr] dbname > xml_file

This script creates a xml file suitable for Seth's Google Maps app using 
event or station information extracted from the specified 
database. At least one option flag must be used or the resulting 
xml file will be empty.  

OPTIONS

-o creates placemarks for all preferred origins. This option 
   requires the origin, event and netmag tables. Origin placemarks 
   are colored by depth. Size is scaled by origin magnitude. 

-s create placemarks for all seismic stations in database.

-b creates basic placemarks for all origins. This is a simplified 
   version of the -o flag that reads only an origin table. The same 
   color and depth scale is used as for -o. A single magnitude is 
   assigned in the order of preference: Ms, mb, ml. In most cases 
   either -o or -b will be used, but not both.

-e subset with dbeval expression

CAVEATS
At this point, an actual database name is needed as input - db2avoxml 
cannot read a piped view.

AUTHOR
Michael West

DEVELOPED & MAINTAINED BY
Glenn Thompson (glenn\@giseis.alaska.edu)
\n\n";


# Command line arguments
$opt_s = $opt_o = $opt_b = $opt_e = 0; # Kill "variable used once" error
if ( ! &getopts('sobe:') || $#ARGV != 0 ) {
	die ( "$Usage" );
} else {
	if ($opt_s && $opt_o) {
		die("Error: -s and -o flags cannot be used together.\n");
	}
	$dbname = pop(@ARGV);
	@dbname = split(/\//,$dbname);

	$dbnameshort = pop(@dbname);

	# Write XML
	&xmlstart;
	if ($opt_o) {
		$BASIC = 0;
		&get_orig_records();
	}
	if ($opt_b) {
		$BASIC = 1;
		&get_orig_records();
	}
	if ($opt_s) {
		&get_site_records();
	}
	&xmlfinish;
}

######################################################################
sub xmlstart {		##### Write the starting portion of a xml file
print <<END_OF_ENTRY
<?xml version="1.0" encoding="UTF-8"?>
<markers>
END_OF_ENTRY
;
}


sub xmlfinish {	##### close a xml file
	print <<END_OF_ENTRY 
</markers>
END_OF_ENTRY
;
}


sub get_orig_records {	##### extract origin records
	# checks added by GTHO 2010/11/02
	die("database $dbname does not exist\n") unless (-e $dbname);
	die("table $dbname.origin does not exist\n") unless (-e $dbname.".origin");
	die("table $dbname.event does not exist\n") unless (-e $dbname.".event");
	@db = dbopen($dbname,'r');
	@db = dblookup(@db,"","origin","",1);
	@db = dbsubset(@db, $opt_e) if ($opt_e ne "0");
	if ($BASIC != 1) {
		@db2 = dblookup(@db,"","event","",1);
		@db  = dbjoin(@db,@db2);
		if (-e "$dbname.netmag") { # GTHO 2010/11/02 - not all databases contain a netmag table
			@db3 = dblookup(@db,"","netmag","",1);
			@db3  = dbjoin(@db,@db3);
			if (dbquery(@db3, "dbRECORD_COUNT")>0) { # This extra check needed because netmag table exists, but not for Earthworm origins
				@db = @db3;
			} else {
				$BASIC = 1;
			}
		}
		else
		{
			$BASIC = 1; # GTHO 2010/11/02 force basic mode if lacking netmag table since magnitude dbgetv will fail otherwise
		}
		@db  = dbsubset(@db,"orid == prefor");
	}
	@db = dbsort(@db,'-r','time');
	$nrecords = dbquery(@db,"dbRECORD_COUNT");
	if ($nrecords == 0) { # changed by GTHO
		die ("no records returned from $dbname matching $opt_e");
	}
	if ($nrecords > $maxevents) {
		$nrecords = $maxevents;
	}
	print STDERR "number of hypocenter placemarks: $nrecords\n";
	print STDERR "BASIC=$BASIC\n";
	
	# GET CURRENT TIME
	$theTime = strtime(now);
	print "\t<!-- created by db2avoxml from database: $dbname on $theTime UTC -->\n";
	#
	foreach $row (0..$nrecords-1) {
		$db[3] = $row ;
		# added "review", "auth", "nass", "ndef", "algorithm" to following line GTHO 2010/11/02
		($lon,$lat,$depth,$time,$orid,$evid,$etype,$review,$auth,$nass,$ndef,$algorithm) = dbgetv(@db,"lon","lat","depth","time","orid","evid","etype","review","auth","nass","ndef","algorithm");

		if ($BASIC) { 
			($mb,$ms,$ml) = dbgetv(@db,"mb","ms","ml");
			if ($ms != -999) {
				$magnitude = $ms;
				$magtype = 'Ms';
			} 
			elsif ($mb != -999) {
				$magnitude = $mb;
				$magtype = 'mb';
			} 
			elsif ($ml != -999) {
				$magnitude = $ml;
				$magtype = 'ml';
			} 
			else {
				$magnitude = 0;
				$magtype = 'Unknown magnitude';
			}
		}
		else 
		{ 
			($magnitude,$magtype) = dbgetv(@db,"magnitude","magtype");
		}

		# GTHO 2010/10/04 Remove ridiculous magnitudes
		if ($magnitude > 9.9) {
			$magtype = "error: $magnitude";
			$magnitude = 0;
		}
		
		our @netstachan = ();
		our $firstarrivaltime = 999999999999;
		our $lastarrivaltime = -999999999999;
		if (-e "$dbname.assoc" && -e "$dbname.arrival") {
			eval { # try to join this origin to assoc and arrival to get arrival.sta/chan/time 
				my @db2 = dbopen($dbname, 'r');
				my @dbo = dblookup(@db2,"","origin","",1);
				@dbo = dbsubset(@dbo,"orid==$orid"); 
				@dba = dblookup(@db2,"","assoc","",1);
				@dba = dbjoin(@dba, @dbo);
				my @dbar = dblookup(@db2,"","arrival","",1);
				@dba = dbjoin(@dba, @dbar);
				# try to add affiliation table to get net
				my @dbaf = dblookup(@db2,"","affiliation","",1);
				@dbaf = dbsubset(@dbaf,"net=~/A./");
				@dba = dbjoin(@dba, @dbaf);
				$numarrivals = dbquery(@dba, "dbRECORD_COUNT") + 1;
				if ($numarrivals > 0) {
					foreach $arow (0..$numarrivals-1) {
						$dba[3] = $arow;
						push @netstachan, sprintf("%s.%s.%s", dbgetv(@dba, "net"), dbgetv(@dba, "sta"), dbgetv(@dba, "chan")); 
						my $atime = dbgetv(@dba, "arrival.time");
						$firstarrivaltime = $atime if ($atime < $firstarrivaltime);
						$lastarrivaltime = $atime if ($atime > $lastarrivaltime);
					}
				}
			}
		}

		&origin_size_color;
		&do_origin;
	}
	dbclose(@db);
}


sub do_origin {	##### write out a single origin placemark
	$look_lon = $lon;
	$look_lat = $lat;
	# datestr format changed by GTHO 2010/11/02
	#$datestr = epoch2str($time,'%m/%d/%Y');
	$datestr = epoch2str($time,'%Y/%m/%d');
	$timestr = epoch2str($time,'%H:%M:%S');
	$timestampstr = epoch2str($time,'%Y-%m-%dT%H:%M:%SZ');
	$depth = sprintf "%3.1f",$depth;

	$magnitude = sprintf "%2.1f",$magnitude;
	$icon = substr $color, 2;
	# Different icon for unreviewed origins GTHO 2010/11/02
	if ($review eq "y" || $auth eq "scott" || $auth=~/UAF.*/ || $auth=~/AVO.*/) {
		$reviewed = "y";
		$icon = 'hyp'.$icon.'.png';
	} else {
		$reviewed = "n";
		$icon = 'unreviewed'.$icon.'.png';
	}

	if ($auth =~ /^ew/) {
		$source = "AVO Earthworm automatic";
	} elsif ($auth =~ /^USGS/) {
		$source = "USGS automatic";
	} elsif ($auth =~/^oa/ || $auth =~ /^orbassoc/) {
		$source = "AEIC automatic";
	} elsif ($auth =~/scott/ || $auth =~ /jpower/ || $auth =~ /dixon/ || $auth =~ /^AVO/) {
		$source = "AVO reviewed";
	} elsif ($auth =~ /^UAF/) {
		$source = "AEIC reviewed";
	} else  {
		$source = "unknown";
	}

	print "\t<marker name=\"ml:$magnitude $datestr\" icon=\"$icon\" lat=\"$lat\" lon=\"$lon\" depth=\"$depth\" ml=\"$magnitude\" scale=\"$size\" color=\"$color\" TimeStamp=\"$timestampstr\">";
	print "\[b\]$datestr $timestr UTC\[/b\]\[br\] \[b\]$magtype: $magnitude\[/b\]\[br\] lat=$lat, lon=$lon, depth=$depth km\[br\] source: $source\[br\] author: $auth\[br\] event type: $etype\[br\] event id: $evid";
	print "\[br\] \[b\]arrivals: $nass/$ndef\[/b\] \[br\]";

	# waveform URL
	my $pretime = 10;
	my $posttime = 10;
	my $minf = 0.8;
	my $maxf = 15.0;
	my $startTimeValve = epoch2str($firstarrivaltime-$pretime,'%Y%m%d%H%M%S%s');
	my $endTimeValve =   epoch2str($lastarrivaltime+$posttime,'%Y%m%d%H%M%S%s');
	if ($#netstachan > -1) {
		my %netstachancount;
		foreach my $netstachan (@netstachan) {
			$netstachancount{$netstachan}++;
		}
		$netstachanlist = join(",",keys(%netstachancount));
		my $waveform_url = "http://giseis.alaska.edu/AVO/internal/avoseis/dev/CODE/waveforms.php?starttime=$startTimeValve&endtime=$endTimeValve&stachanlist=$netstachanlist&minf=$minf&maxf=$maxf";
		print "\[a href=\"$waveform_url\"\ target=\"waveform\"]waveforms\[/a\]\n";
	}
	print "<\/marker>\n";
}


sub origin_size_color {	##### calculate the size and color of hypocenter icons
	my %depthlist = (
	0 => '-1.0',
	1 => '0.0',
	2 => '1.0',
	3 => '2.0',
	4 => '3.0',
	5 => '4.3',
	6 => '5.5',
	7 => '6.8',
	8 => '8.0',
	9 => '11.0',
	10 => '14.0',
	11 => '17.0',
	12 => '20.0',
	13 => '25.0',
	14 => '30.0',
	15 => '35.0',
	16 => '40.0',
	17 => '45.0',
	18 => '50.0',
	19 => '87.5',
	20 => '125.0',
	21 => '162.5',
	22 => '200.0',
	23 => '250.0',
	24 => '300.0',
	25 => '350.0',
	26 => '400.0',
	);
	@colors = qw(
 FFFFFFFF
 FFBFFFFF
 FF80FFFF
 FF40FFFF
 FF00FFFF
 FF00DFFF
 FF00BFFF
 FF009FFF
 FF0080FF
 FF0060FF
 FF0040FF
 FF0020FF
 FF0000FF
 FF0000DF
 FF0000BF
 FF00009F
 FF000080
 FF005940
 FF00B300
 FF408600
 FF805900
 FFBF2D00
 FFFF0000
 FFDF002D
 FFBF0059
 FF9F0086
 FF8000B3
	);
	$mindist=9999;
	$minindex=9999;
	foreach $key (keys %depthlist) {
	        $dist = abs($depthlist{$key}-$depth);
	        if ($dist < $mindist) {
	                $mindist = $dist;
	                $minindex = $key;
	        }
	}
	$color = $colors[$minindex];
	$size = ($magnitude+2.5)/8;
	$size = 0.9 * $size;
}




sub get_site_records {	##### extract site records
	@db = dbopen($dbname,'r');
	@db = dblookup(@db,"","site","",1);
	$nrecords = dbquery(@db,"dbRECORD_COUNT");
	if ($nrecords == 0) {
		die ("database does not exist or origin table contains no records");
	}
	print STDERR "number of station placemarks: $nrecords\n";
	$theTime = strtime(now);
	print "\t<!-- created by db2avoxml from database: $dbname on $theTime UTC -->\n";
	for ($db[3]=0 ; $db[3]<$nrecords ; $db[3]++) {
		($sta,$lon,$lat,$elev,$staname) = dbgetv(@db,"sta","lon","lat","elev","staname");
		$elev = $elev*1000;				# convert km to meters
		&do_site;
	}
	dbclose(@db);
}


sub do_site {		##### write out a single site placemark
	print "\t<marker name=\"$sta\" icon=\"seismometer_2.png\" lat=\"$lat\" lon=\"$lon\" elev=\"$elev\">";
	print "\[center][b\]$sta\[/b\]\[\/center]\[br\]\"$staname\"\[/br\]elevation: $elev meters";
	print "<\/marker>\n";
}











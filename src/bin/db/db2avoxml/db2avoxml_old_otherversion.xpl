# Create xml file of seismic network information. Used by AVO server to generate Google Maps
# This program has been modified from db2kml. As a result there are several references to "kml"
# in the script that now actually refer to xml code
# Michael West
# 01/2008
use Datascope;
use Getopt::Std;

# SET MAXIMUM NUMBER OF EVENTS
$maxevents = 300;





sub kmlstart {		##### Write the starting portion of a xml file
print <<END_OF_ENTRY
<?xml version="1.0" encoding="UTF-8"?>
<markers>
END_OF_ENTRY
;
}


sub kmlfinish {	##### close a kml file
	print <<END_OF_ENTRY 
</markers>
END_OF_ENTRY
;
}


sub get_orig_records {	##### extract origin records
	@db = dbopen($dbname,'r');
	@db = dblookup(@db,"","origin","",1);
	if ($BASIC != 1) {
		@db2 = dblookup(@db,"","event","",1);
		@db3 = dblookup(@db,"","netmag","",1);
		@db  = dbjoin(@db,@db2);
		@db  = dbjoin(@db,@db3);
		@db  = dbsubset(@db,"orid == prefor");
	}
	@db = dbsort(@db,'-r','time');
	$nrecords = dbquery(@db,"dbRECORD_COUNT");
	if ($nrecords == 0) {
		die ("database does not exist or origin table contains no records");
	}
	if ($nrecords > $maxevents) {
		$nrecords = $maxevents;
	}
	print STDERR "number of hypocenter placemarks: $nrecords\n";
	
	# GET CURRENT TIME
	#@months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	#($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = gmtime();
	#$year = 1900 + $yearOffset;
	#$theTime = "$months[$month] $dayOfMonth, $year $hour:$minute:$second UTC";
	$theTime = strtime(now);
	print "\t<!-- created by db2avoxml from database: $dbname on $theTime UTC -->\n";
	#
	foreach $row (0..$nrecords-1) {
		$db[3] = $row ;
		if ($BASIC) {
			($lon,$lat,$depth,$time,$orid,$evid,$etype,$mb,$ms,$ml,$auth) = dbgetv(@db,"lon","lat","depth","time","orid","evid","etype","mb","ms","ml","auth");
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
		else {
			($lon,$lat,$depth,$time,$orid,$evid,$etype,$magnitude,$magtype,$auth) = dbgetv(@db,"lon","lat","depth","time","orid","evid","etype","magnitude","magtype","auth");
		}
		#print STDERR "$magnitude\n";
		#$magnitude = printf "%5.1f",$magnitude;
		&origin_size_color;
		&do_origin;
	}
	dbclose(@db);
}


sub do_origin {	##### write out a single origin placemark
	$look_lon = $lon;
	$look_lat = $lat;
	$datestr = epoch2str($time,'%m/%d/%Y');
	$timestr = epoch2str($time,'%H:%M:%S');
	$timestampstr = epoch2str($time,'%Y-%m-%dT%H:%M:%SZ');
	$depth = sprintf "%3.1f",$depth;
	$magnitude = sprintf "%2.1f",$magnitude;
	$icon = substr $color, 2;
	$icon = 'hyp'.$icon.'.png';
	print "\t<marker name=\"ml:$magnitude $datestr\" icon=\"$icon\" lat=\"$lat\" lon=\"$lon\" depth=\"$depth\" ml=\"$magnitude\" scale=\"$size\" color=\"$color\" TimeStamp=\"$timestampstr\">";
	print "\[b\]$datestr $timestr UTC\[/b\]\[br\]\[b\]magnitude: $magnitude\[/b\]\[br\]lat,lon: $lat,$lon\[br\]depth: $depth";
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
	print "\[center][b\]$sta\[/b\]\[\/center]\[br\]\"$staname\"\[br\]elevation: $elev meters";
	print "<\/marker>\n";
}






##############################################

$Usage = "
Usage: db2avoxml [-sob]  dbname > xml_file

This script creates a kml file suitable for Google Earth using 
event or station information extracted from the specified 
database. At least one option flag must be used or the resulting 
kml file will be empty. Numerous subsets of placemarks may be 
desirable - stations in a date range, origins in a magnitude 
range. In lieu of coding these options into db2kml, it is more 
expedient to handle such subsets directly on the database before 
sending to db2kml.

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

CAVEATS
At this point, an actual database name is needed as input - db2kml 
cannot read a piped view.

AUTHOR
Michael West
\n\n";



$opt_s = $opt_o = $opt_b = 0; # Kill "variable used once" error
if ( ! &getopts('sob') || $#ARGV != 0 ) {
	die ( "$Usage" );
} else {
	if ($opt_s && $opt_o) {
		die("Error: -s and -o flags cannot be used together.\n");
	}
	$dbname = pop(@ARGV);
	@dbname = split(/\//,$dbname);
	$dbnameshort = pop(@dbname);
	&kmlstart;
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
	&kmlfinish;
}



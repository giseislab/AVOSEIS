##############################################################################
# Author: Glenn Thompson 2011/09/15
#       Geophysical Institute, University of Alaska Fairbanks
#
# Modifications
#
# Purpose:
#       Convert a CSS3.0 event database to XML suitable for display with Wes 
#	Thelen's VOLC2 Google Maps app.. 
#
# History:
# 	This program is based on db2avoxml_new in the repository CheetahSeismicTools.
#
#
##############################################################################
# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

use Datascope;
use Getopt::Std;
use Env;

# SET MAXIMUM NUMBER OF EVENTS
$maxevents = 300; # Changed from 1000 to 300 because seeing malloc problems in cronjobs.

#USAGE
$Usage = "
Usage: $0 [-sobf] [-e subset_expr] [-x N] [-w] dbname > xml_file

See manpage for further details.

AUTHOR
Glenn Thompson
\n\n";


# Command line arguments
$opt_s = $opt_o = $opt_b = $opt_e = $opt_f = $opt_x = 0; # Kill "variable used once" error
if ( ! &getopts('sobe:fx:') || $#ARGV != 0 ) {
	die ( "$Usage" );
} else {
	if ($opt_s && $opt_o) {
		die("Error: -s and -o flags cannot be used together.\n");
	}

	die($Usage) if (!$opt_o && !$opt_b && !$opt_s);

	$dbname = pop(@ARGV);
	die("database $dbname not found") unless (-e $dbname);
	die("table $dbname.origin not found") if (!(-e "$dbname.origin") && ($opt_o || $opt_b));
	die("table $dbname.site not found") if (!(-e "$dbname.site") && $opt_s);

	# Write XML
	our $xmlstr = "";
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
	print $xmlstr;

	1;
}

######################################################################
sub xmlstart {		##### Write the starting portion of a xml file
	$xmlstr .= "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
	$localtimestr = epoch2str(now(),'%Y/%m/%d %H:%M:%S %Z', 'US/Alaska');
	$utctimestr = epoch2str(now(),'%Y/%m/%d %H:%M:%S %Z');
	$xmlstr .= "\t<!-- created by $PROG_NAME from database: $dbname at $utctimestr UTC -->\n";
	unless (($opt_x==2) && ($opt_o || $opt_b)) {
		$xmlstr .= "<markers>\n";
	} else {
		$xmlstr .= "<merge fileTime_loc=\"$localtimestr\" fileTime_utc=\"$utctimestr\">\n";
	}
}


sub xmlfinish {	##### close a xml file
	unless (($opt_x==2) && ($opt_o || $opt_b)) {
		$xmlstr .= "</markers>\n";
	} else {
		$xmlstr .= "</merge>\n";
	}
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
		print STDERR "no records returned from $dbname matching $opt_e\n";
		return;
	}
	if (($nrecords > $maxevents) && (! $opt_f) ) {
		$nrecords = $maxevents;
	}
	print STDERR "number of hypocenter placemarks: $nrecords\n";
	print STDERR "BASIC=$BASIC\n";
	
	foreach $row (0..$nrecords-1) {
		$db[3] = $row ;
		# added "review", "auth", "nass", "ndef", "algorithm" to following line GTHO 2010/11/02
		($lon,$lat,$depth,$time,$orid,$evid,$etype,$review,$auth,$nass,$ndef,$algorithm) = dbgetv(@db,"lon","lat","depth","time","orid","evid","etype","review","auth","nass","ndef","algorithm");

		if ($BASIC) { 
			($mb,$ms,$ml) = dbgetv(@db,"mb","ms","ml");
			if ($ms != -999) {
				$magnitude = sprintf "%2.1f",$ms;
				$magtype = 'Ms';
			} 
			elsif ($mb != -999) {
				$magnitude = sprintf "%2.1f",$mb;
				$magtype = 'mb';
			} 
			elsif ($ml != -999) {
				$magnitude = sprintf "%2.1f",$ml;
				$magtype = 'ml';
			} 
			else {
				$magnitude = "";
				$magtype = 'No magnitude';
			}
		}
		else 
		{ 
			($magnitude,$magtype) = dbgetv(@db,"magnitude","magtype");
		}

		# GTHO 2010/10/04 Remove ridiculous magnitudes from orbmag
		if ($magnitude > 9.9) {
			$magtype = "error: $magnitude";
			$magnitude = -9.99;
		}
		
		# I thnk this exists only for the VALVE waveform hyperlinks
		# builds @netstachan and $firstarrivaltime, $lastarrivaltime	
		our @netstachan = ();
		our $firstarrivaltime = 999999999999;
		our $lastarrivaltime = -999999999999;
		if (-e "$dbname.assoc" && -e "$dbname.arrival" && $opt_w) {
			#eval { # try to join this origin to assoc and arrival to get arrival.sta/chan/time 
				my @db2 = dbopen($dbname, 'r');
				my @dbo = dblookup(@db2,"","origin","",1);
				@dbo = dbsubset(@dbo,"orid==$orid"); 
				if (@dba = dblookup(@db2,"","assoc","",1)) {
					@dba = dbjoin(@dba, @dbo);
					if (my @dbar = dblookup(@db2,"","arrival","",1)) {
						@dba = dbjoin(@dba, @dbar);

						# try to add affiliation table to get net
						if (my @dbaf = dblookup(@db2,"","affiliation","",1)){
							@dbaf = dbsubset(@dbaf,"net=~/A./");
							@dba = dbjoin(@dba, @dbaf);
							$numarrivals = dbquery(@dba, "dbRECORD_COUNT") + 1;
							if ($numarrivals > 0) {
								foreach $arow (0..$numarrivals-1) {
									$dba[3] = $arow;
									my $thisnet = "--";
									eval {
										$thisnet = dbgetv(@dba, "net");
									};
									push @netstachan, sprintf("%s.%s.%s", $thisnet, dbgetv(@dba, "sta"), dbgetv(@dba, "chan")); 
									eval {
										my $atime = dbgetv(@dba, "arrival.time");
										$firstarrivaltime = $atime if ($atime < $firstarrivaltime);
										$lastarrivaltime = $atime if ($atime > $lastarrivaltime);
									};
								}
							}
						}
					}
				}
			#};
			#warn $@ if $@;

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
	$icon = substr $color, 2;

	if ($review eq "y" || $auth eq "scott" || $auth=~/UAF.*/ || $auth=~/AVO.*/) {
		$reviewed = "y";
		$icon = 'hyp'.$icon.'.png';
	} else {
		$reviewed = "n";
		# Different icon for unreviewed origins if not in public mode GTHO 2010/11/02
		if ($opt_x > 0) {
			$icon = 'unreviewed'.$icon.'.png';
		}
		else
		{
			$icon = 'hyp'.$icon.'.png';
		}
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

	# WAVEFORM URL
	my $waveform_hyperlink = "";
	if ($opt_w && !$opt_x) {
		my $pretime = 10;
		my $posttime = 10;
		my $minf = 0.8;
		my $maxf = 15.0;
		my $startTimeValve = epoch2str($firstarrivaltime-$pretime,'%Y%m%d%H%M%S%s');
		my $endTimeValve =   epoch2str($lastarrivaltime+$posttime,'%Y%m%d%H%M%S%s');
		my $waveform_url = "";
		if ($#netstachan > -1) {
			my %netstachancount;
			foreach my $netstachan (@netstachan) {
				$netstachancount{$netstachan}++;
			}
			$netstachanlist = join(",",keys(%netstachancount));
			$waveform_url = $ENV{'INTERNALWEBPRODUCTSURL'}."/html/waveforms.php?starttime=$startTimeValve&amp;endtime=$endTimeValve&amp;stachanlist=$netstachanlist&amp;minf=$minf&amp;maxf=$maxf";
			$waveform_hyperlink = '\[a href=\"$waveform_url\" target=\"waveform\"\]waveforms\[/a\]';
		}
	}

	# PRINT XML CODE
	if ($opt_x==0) {
		$xmlstr.= "<marker name=\"$magnitude $datestr\" icon=\"$icon\" lat=\"$lat\" lon=\"$lon\" depth=\"$depth\" ml=\"$magnitude\" scale=\"$size\" color=\"$color\" TimeStamp=\"$timestampstr\">
\[b\]$datestr $timestr UTC\[/b\]\[br/\] 
\[b\]magnitude: $magnitude\[/b]\[br/\] 
lat=$lat, lon=$lon, depth=$depth km\[br/\] 
</marker>\n";
	};
	if ($opt_x==1) {
		$xmlstr.= "<marker name=\"$magnitude $datestr\" icon=\"$icon\" lat=\"$lat\" lon=\"$lon\" depth=\"$depth\" ml=\"$magnitude\" scale=\"$size\" color=\"$color\" TimeStamp=\"$timestampstr\">
\[b\]$datestr $timestr UTC\[/b\]\[br/\] 
\[b\]$magtype: $magnitude\[/b]\[br/\] 
lat=$lat, lon=$lon, depth=$depth km\[br/\] 
source: $source\[br\] author: $auth\[br/\] 
event type: $etype\[br/\] 
\[b\]arrivals: $nass/$ndef\[/b\] \[br/\]\n";	
		$xmlstr .= $waveform_hyperlink if ($waveform_hyperlink ne "");
		$xmlstr .= "</marker>\n";
	};
	if ($opt_x==2) {
		$year = epoch2str($time,'%Y');
		$month = epoch2str($time,'%m');
		$day = epoch2str($time,'%d');
		$hour = epoch2str($time,'%H');
		$minute = epoch2str($time,'%M');
		$second = epoch2str($time,'%S');
		$localtime = epoch2str($time, '%a %b %d, %Y %H:%M:%S %Z');
		$time_stamp = epoch2str(now(), '%Y/%m/%d_%H:%M:%S');
		$xmlstr .= "<event id=\"$evid\" network-code=\"AK\" time-stamp=\"$time_stamp\" version=\"1\">
<param name=\"year\" value=\"$year\"/>
<param name=\"month\" value=\"$month\"/>
<param name=\"day\" value=\"$day\"/>
<param name=\"hour\" value=\"$hour\"/>
<param name=\"minute\" value=\"$minute\"/>
<param name=\"second\" value=\"$second\"/>
<param name=\"latitude\" value=\"$lat\"/>
<param name=\"longitude\" value=\"$lon\"/>
<param name=\"depth\" value=\"$depth\"/>
<param name=\"magnitude\" value=\"$magnitude\"/>
<param name=\"num-stations\" value=\"$nass\"/>
<param name=\"num-phases\" value=\"$ndef\"/>
<param name=\"local-time\" value=\"$localtime\"/>
<param name=\"icon-style\" value=\"1\"/>
</event>\n";		
	}
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
	@db = dbsubset(@db, "offdate==NULL"); # added by GT 2010/11/17

	# added by GT 2011/09/20
	my @dbsc = dblookup(@db,"","sitechan","",1);
	@db = dbjoin(@db, @dbsc);
	@db = dbsubset(@db, $opt_e) if ($opt_e ne "0");
	
	# added by GT 2010/11/17
	my @db2 = dblookup(@db,"","affiliation","",1);
	@db = dbjoin(@db, @db2);
	@db = dbsubset(@db, "net=~/A[KTV]/ && chan=~/[BES]HZ/ && sitechan.offdate==NULL");
	# end of GT block

	$nrecords = dbquery(@db,"dbRECORD_COUNT");
	if ($nrecords == 0) {
		print STDERR "database $dbname does not exist or site table contains no records\n";
		return;
	}
	print STDERR "number of station placemarks: $nrecords\n";
	for ($db[3]=0 ; $db[3]<$nrecords ; $db[3]++) {
		my ($sta,$chan,$lon,$lat,$elev,$staname,$net) = dbgetv(@db,"sta","chan","lon","lat","elev","staname","net");
		$elev = $elev*1000;				# convert km to meters

		# added by GT 2010/11/17 - look for number of arrivals/events for this station
		my $num_arrivals = 0;
		if (-f "$dbname.arrival") {
			my @dba = dblookup(@db, "", "arrival", "", 1);
			@dba = dbsubset(@dba, "sta==\"$sta\"");
			@dba = dbjoin(@dba, @db);
			$num_arrivals = dbquery(@dba, "dbRECORD_COUNT");
			print STDERR "$num_arrivals arrivals for sta $sta\n";
			#dbclose(@dba);
		}
		# end of GT block
			
		&do_site($sta, $chan, $lon, $lat, $elev, $staname, $net, $num_arrivals);
	}
	dbclose(@db);
}


sub do_site {		##### write out a single site placemark
	my($sta, $chan, $lon, $lat, $elev, $staname, $net, $num_arrivals) = @_;
	my $icondir = $ENV{'PUBLICWEBPRODUCTSURL'}."/kml/icons";
	my $icon = "seismometer_2.png"; # default
	if ($net eq "AV") {
		if ($num_arrivals > 0) {
			$icon = "seismometer_avo_green.png";
		} else {
			$icon = "seismometer_avo_red.png";
		}
	}
	if ($net eq "AK") {
		if ($num_arrivals > 0) {
			$icon = "seismometer_aeic_green.png";
		} else {
			$icon = "seismometer_aeic_red.png";
		}
	}
	if ($net eq "AT") {
		if ($num_arrivals > 0) {
			$icon = "seismometer_atwc_green.png";
		} else {
			$icon = "seismometer_atwc_red.png";
		}
	}

	# PRINT XML
	if ($opt_x<2) {
		$xmlstr .= "<marker name=\"$sta\" icon=\"$icon\" lat=\"$lat\" lon=\"$lon\" elev=\"$elev\">
\[center\]\[b\]$sta\[/b\]\[/center\]\[br/\]
\"$staname\"\[br/\]
elevation: $elev meters\[br/\]
net: \"$net\"\[br/\]
arrivals: $num_arrivals\[br/\]
\"$sta\"-\"$net\"\[br/\]
</marker>\n";
	} else {
		if ($chan=~/BHZ/) {
			$type = "BB";
		}
		else
		{
			$type = "SP";
		}
		$xmlstr .= "<marker lat=\"$lat\" lng=\"$lon\" station=\"$sta\" channel=\"$chan\" network=\"$net\" location=\"--\" type=\"$type\"/>\n";
	}
}











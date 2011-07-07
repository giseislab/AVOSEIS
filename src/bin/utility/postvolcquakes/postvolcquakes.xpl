
# postvolcquakes
# Post recent volcanic events to web
# Michael West
# 01/2009
# Modified by Glenn Thompson 05/2009
# to make input database and output directory
# command line variables rather than hard wired
# 
# 
# 
use Datascope;
use Getopt::Std;


# CONSTANTS
$dbName = $ARGV[0];
$volcName = 'Redoubt';
$volcCode = 'RD';
$volcLat = 60.4852;
$volcLon = -152.7438;
$webDir = $ARGV[1]."/".$volcCode;

$Usage = "Usage: postvolcquakes eventdb webdir";
if ( ! &getopts('') || $#ARGV != 1 ) {
        die ( "$Usage\n" );
} else {


	# PREP TIME WINDOW
	$timeWindow = 3;	# in hours
	$endEpoch = now()+60;
	$startEpoch = $endEpoch-($timeWindow*3600);
	$endTimeUTC    =  epoch2str($endEpoch,'%Y/%m/%d %H:%M:%S %Z');
	$endTimeLOCAL  =  epoch2str($endEpoch,'%Y/%m/%d %H:%M:%S %Z','US/Alaska');
	$startTimeValve = epoch2str($startEpoch,'%Y%m%d%H%M%S%s');
	$endTimeValve =   epoch2str($endEpoch,'%Y%m%d%H%M%S%s');
	$twinString = sprintf("%3.0f", ($endEpoch-$startEpoch)/60 );

	mkdir($webDir, 0755) unless (-e $webDir); 
	open(OUTFILE,">$webDir/index.html");
	&htmlstart;
	&write_all_quakes;
	&htmlend;
	close(OUTFILE);
}


sub htmlstart {
	print OUTFILE "<!DOCTYPE html PUBLIC  \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n";
	print OUTFILE "<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"en\"> \n";
	print OUTFILE "<head>\n";
	print OUTFILE "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />\n";
	print OUTFILE "\t<title>$volcName recent events</title> \n";
	print OUTFILE "</head>\n";
	print OUTFILE "<body>\n";
	$sta = 'RDN';
	$chan = 'EHZ';
	print OUTFILE "<bold>$sta $chan</bold>\n";
	print OUTFILE "<img valign=\"middle\" src=\"http://avosouth.wr.usgs.gov/valve3/valve3.jsp?a=plot&o=png&w=1000&h=120&n=1&x.0=75&y.0=19&w.0=850&h.0=100&mh.0=600&src.0=ak_waves&st.0=$startTimeValve&et.0=$endTimeValve&selectedStation.0=$sta%20$chan%20AV&ch.0=$sta\$$chan\$AV&type.0=sg&rb.0=T&ysMin.0=Auto&ysMax.0=Auto&spminf.0=0.0&spmaxf.0=15.0&splp.0=T&splf.0=F&fminhz.0=0&fmaxhz.0=5&ftype.0=N \"> <br>\n";

	$sta = 'RDT';
	$chan = 'EHZ';
	print OUTFILE "<bold>$sta $chan</bold>\n";
	print OUTFILE "<img src=\"http://avosouth.wr.usgs.gov/valve3/valve3.jsp?a=plot&o=png&w=1000&h=120&n=1&x.0=75&y.0=19&w.0=850&h.0=100&mh.0=600&src.0=ak_waves&st.0=$startTimeValve&et.0=$endTimeValve&selectedStation.0=$sta%20$chan%20AV&ch.0=$sta\$$chan\$AV&type.0=sg&rb.0=T&ysMin.0=Auto&ysMax.0=Auto&spminf.0=0.0&spmaxf.0=15.0&splp.0=T&splf.0=F&fminhz.0=0&fmaxhz.0=5&ftype.0=N \"> <br>\n";

#	$sta = 'RED';
#	$chan = 'EHZ';
#	print OUTFILE "<bold>$sta $chan</bold>\n";
#	print OUTFILE "<img src=\"http://avosouth.wr.usgs.gov/valve3/valve3.jsp?a=plot&o=png&w=1000&h=120&n=1&x.0=75&y.0=19&w.0=850&h.0=100&mh.0=600&src.0=ak_waves&st.0=$startTimeValve&et.0=$endTimeValve&selectedStation.0=$sta%20$chan%20AV&ch.0=$sta\$$chan\$AV&type.0=sg&rb.0=T&ysMin.0=Auto&ysMax.0=Auto&spminf.0=0.0&spmaxf.0=15.0&splp.0=T&splf.0=F&fminhz.0=0&fmaxhz.0=5&ftype.0=N \"> <br>\n";

	$sta = 'REF';
	$chan = 'EHZ';
	print OUTFILE "<bold>$sta $chan</bold>\n";
	print OUTFILE "<img src=\"http://avosouth.wr.usgs.gov/valve3/valve3.jsp?a=plot&o=png&w=1000&h=120&n=1&x.0=75&y.0=19&w.0=850&h.0=100&mh.0=600&src.0=ak_waves&st.0=$startTimeValve&et.0=$endTimeValve&selectedStation.0=$sta%20$chan%20AV&ch.0=$sta\$$chan\$AV&type.0=sg&rb.0=T&ysMin.0=Auto&ysMax.0=Auto&spminf.0=0.0&spmaxf.0=15.0&splp.0=T&splf.0=F&fminhz.0=0&fmaxhz.0=5&ftype.0=N \"> <br>\n";

	$sta = 'RSO';
	$chan = 'EHZ';
	print OUTFILE "<bold>$sta $chan</bold>\n";
	print OUTFILE "<img src=\"http://avosouth.wr.usgs.gov/valve3/valve3.jsp?a=plot&o=png&w=1000&h=150&n=1&x.0=75&y.0=19&w.0=850&h.0=100&mh.0=600&src.0=ak_waves&st.0=$startTimeValve&et.0=$endTimeValve&selectedStation.0=$sta%20$chan%20AV&ch.0=$sta\$$chan\$AV&type.0=sg&rb.0=T&ysMin.0=Auto&ysMax.0=Auto&spminf.0=0.0&spmaxf.0=15.0&splp.0=T&splf.0=F&fminhz.0=0&fmaxhz.0=5&ftype.0=N \"> <br>\n";

	print OUTFILE "<code>\n";
	print OUTFILE "\t<h2>Recent event detections on the $volcName subnetwork (past $timeWindow hours)</h2>\n";
}


sub htmlend {
	print OUTFILE "<br>\n<font size=-1><i>File written at: $endTimeUTC ($endTimeLOCAL)</i></font>\n";
	print OUTFILE "</code>\n";
	print OUTFILE "</body>\n";
	print OUTFILE "</html>\n";
}



# CYCLE THROUGH EVENTS
sub write_all_quakes {
	@db = dbopen( $dbName , "r" );
	@db = dblookup(@db,"","origin","","");
	@db = dbsubset(@db,"time>$startEpoch");
	@db = dbsubset(@db,"time<=$endEpoch");
	@db = dbsort(@db,"time",'-r');
	@dbt = dblookup(@db,"","event","","");
	@db = dbjoin(@db,@dbt);
	@db = dbsubset(@db,"orid==prefor");
	$recnum = dbquery(@db,"dbRECORD_COUNT");
	if ($recnum == 0) {
		print OUTFILE "\t\t<tr><td>There are no events in the past $timeWindow hours.</tr></td>\n";
	} else {
        	@dbSubset = @db;
		foreach $row (0..$recnum-1) {
			$dbSubset[3] = $row ;
			($lon,$lat,$depth,$time,$orid,$ml,$nass,$auth) = dbgetv(@dbSubset,"lon","lat","depth","time","orid","ml","nass","auth");
			$range   = dbex_eval(@dbSubset,"deg2km(distance($volcLat,$volcLon,lat,lon))");
			$azimuth = dbex_eval(@dbSubset,"azimuth($volcLat,$volcLon,lat,lon)");
      			$compass = compass_from_azimuth($azimuth);
			&write_one_quake;
		}
	}
	dbclose(@db);
}


# WRITE OUT SINGLE EVENT
sub write_one_quake {
	$timeString = epoch2str($time,'%Y/%m/%d %H:%M:%S');
	if ($ml < -2) {
		$ml='n/a';
	} else {
		$ml = sprintf("%3.1f", $ml);
	}
#	$latString = sprintf("%8.3f", $lat);
#	$lonString = sprintf("%8.3f", $lon);
#	$depthString = sprintf("%5.1f", $depth);
	$rangeString = sprintf("%-2.1f",$range);
#	$azimuthString = sprintf("%-3.0f",$azimuth);
#	print OUTFILE "<tr><td>  $timeString </td><td> $ml </td><td> $rangeString </td><td> $azimuthString </td></tr>\n";
	printf OUTFILE "%s (ml %3s) %5.1f km %+3s of %s. <i>%3d phases using %s</i><br>\n",$timeString,$ml,$range,$compass,$volcName,$nass,$auth;
	}




sub compass_from_azimuth {
        local( $azimuth ) = @_;
        while( $azimuth < 0. ) { $azimuth += 360.; };
        while( $azimuth > 360. ) { $azimuth -= 360.; };
        if( $azimuth >= 348.75 || $azimuth < 11.25 ) {
                return "N";             # 0.00
        } elsif( $azimuth >= 11.25 && $azimuth < 33.75 ) {
                return "NNE";           # 22.50
        } elsif( $azimuth >= 33.75 && $azimuth < 56.25 ) {
                return "NE";            # 45.00
        } elsif( $azimuth >= 56.25 && $azimuth < 78.75 ) {
                return "ENE";           # 67.50
        } elsif( $azimuth >= 78.75 && $azimuth < 101.25 ) {
                return "E";             # 90.00
        } elsif( $azimuth >= 101.25 && $azimuth < 123.75 ) {
                return "ESE";           # 112.50
        } elsif( $azimuth >= 123.75 && $azimuth < 146.25 ) {
                return "SE";            # 135.00
        } elsif( $azimuth >= 146.25 && $azimuth < 168.75 ) {
                return "SSE";           # 157.50
        } elsif( $azimuth >= 168.75 && $azimuth < 191.25 ) {
                return "S";             # 180.00
        } elsif( $azimuth >= 191.25 && $azimuth < 213.75 ) {
                return "SSW";           # 202.50
        } elsif( $azimuth >= 213.75 && $azimuth < 236.25 ) {
                return "SW";            # 225.00
        } elsif( $azimuth >= 236.25 && $azimuth < 258.75 ) {
                return "WSW";           # 247.50
        } elsif( $azimuth >= 258.75 && $azimuth < 281.25 ) {
                return "W";             # 270.00
        } elsif( $azimuth >= 281.25 && $azimuth < 303.75 ) {
                return "WNW";           # 292.50
        } elsif( $azimuth >= 303.75 && $azimuth < 326.25 ) {
                return "NW";            # 315.00
        } elsif( $azimuth >= 326.25 && $azimuth < 348.75 ) {
                return "NNW";           # 337.50
        }
        MyDie( "Faulty logic in compass_from_azimuth subroutine" );
}







##############################################



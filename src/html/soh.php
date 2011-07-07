<?php
include('./includes/antelope.inc');

$placesdb = "$datadir/places/volcanoes";

$sitedb = "$datadir/dbmaster/master_stations";
$volcanolat = -999;
$volcanolon = -999;


// Read in CGI parameters
$VOLCANO= !isset($_REQUEST['VOLCANO'])? NULL : $_REQUEST['VOLCANO'];
$DISTANCE= !isset($_REQUEST['DISTANCE'])? NULL : $_REQUEST['DISTANCE'];
$DATATYPE= !isset($_REQUEST['DATATYPE'])? NULL : $_REQUEST['DATATYPE'];
		
$page_title = "State-of-Health";
$css = array( "style.css", "table.css" );
$googlemaps = 0;
$js = array( "changedivcontent.js");

// Standard XHTML header
include('includes/header.inc');
include('includes/dbgetvolcanoes.inc');
include('includes/mosaicMaker.inc');
#header(0);
$volcanoes = dbgetvolcanoes($placesdb);

function compare_distances($a, $b) 
{ 
	$retval = strnatcmp($a['dist'], $b['dist']); 
	if(!$retval) return strnatcmp($a['netstachan'], $b['netstachan']); 
	return $retval; 
} 
?>

<body bgcolor="#FFFFFF">
	
	<form name="soh" method="get">
	<b>Choose volcano</b>
	<SELECT NAME="VOLCANO">
<?php

	foreach($volcanoes as $thisvolcano) {
	    if ($thisvolcano == $VOLCANO) {
		print "<OPTION SELECTED>$thisvolcano\n";
	    }
	    else
	    {
	    	print "<OPTION>$thisvolcano\n";
	    }
	}
?>

	</SELECT>


	<b>Choose distance (km)</b>
	<SELECT NAME="DISTANCE">
<?php
	$distances = array("15", "25", "50", "100", "200");
	foreach($distances as $thisdistance) {
	    if ($thisdistance == $DISTANCE) {
		print "<OPTION SELECTED>$thisdistance\n";
	    }
	    else
	    {
	    	print "<OPTION>$thisdistance\n";
	    }
	}
?>

	</SELECT>


	<b>Choose data type</b>
	<SELECT NAME="DATATYPE">
<?php
	$datatypes = array("LIST", "RSAM", "SPECTROGRAMS", "WAVEFORMS");
	foreach($datatypes as $thisdatatype) {
	    if ($thisdatatype == $DATATYPE) {
		print "<OPTION SELECTED>$thisdatatype\n";
	    }
	    else
	    {
	    	print "<OPTION>$thisdatatype\n";
	    }
	}
?>

	</SELECT>


	<input type="submit" value="Submit" />
	</form>

<?php
	if (isset($VOLCANO) && isset($DISTANCE)) {
		$netstachans = array();
		$dbp = ds_dbopen_table("$placesdb.places", "r");
		$dbp = dbsubset($dbp, "place == \"$VOLCANO\"");
		$nrecs = dbnrecs($dbp);
		#echo "Got $nrecs matching records for $VOLCANO in $placesdb.places<br/>";
		if ($nrecs == 1) {
        		$dbp[3]=0;
        		list($volcanolat, $volcanolon) = dbgetv($dbp, "lat", "lon");
			echo "$VOLCANO: lat=$volcanolat, lon=$volcanolon<br/>";
        		ds_dbclose($dbp);

        		$dbs = ds_dbopen_table("$sitedb.site", "r");
        		$dbs = dbsubset($dbs, "offdate==NULL");
        		$dbs = dbsubset($dbs, "deg2km(distance(site.lat, site.lon, $volcanolat, $volcanolon)) <= $DISTANCE");
        		$nstations = dbnrecs($dbs);
			echo "Found $nstations matching stations,&nbsp; ";

        		$dba = ds_dbopen_table("$sitedb.affiliation", "r") or die("Cannot open $sitedb.affiliation\n");
        		$dba = dbsubset($dba, 'net=~/A./');
        		$dbs = dbjoin($dbs, $dba);
        		$dbsc = ds_dbopen_table("$sitedb.sitechan", "r");
        		$dbsc = dbsubset($dbsc, "offdate==NULL");
        		$dbsc = dbsubset($dbsc, "chan=~/[BHES][DH][ZNEF]/");
        		$dbsc = dbjoin($dbsc, $dbs);
        		$nchannels = dbnrecs($dbsc);

			echo "$nchannels matching channels<br/>";
		        if ($nchannels > 0) {
				#print "<table border=1>\n<tr><th>NET_STA_CHAN</th> <th>Distance(km)</th></tr>\n";
        		        for ($dbsc[3]=0; $dbsc[3]<$nchannels; $dbsc[3]++) {
                   		 	list($net, $sta, $chan) = dbgetv($dbsc, 'net', 'sta', 'chan');
                        		$dist = dbex_eval($dbsc, "deg2km(distance(lat, lon, $volcanolat, $volcanolon))");
					$netstachan = $net."_".$sta."_".$chan;
					$netstachans[$dbsc[3]] = array('net' => $net, 'sta' => $sta, 'chan' => $chan, 'dist' => $dist, 'netstachan' => $netstachan);
                        		#printf("<tr><td align=\"left\">%s_%s_%s</td> <td align=\"right\"> %.1f</td> </tr>\n",$net,$sta,$chan,$dist);
                		}
				#print "</table>\n";
        		}
        		ds_dbclose($dbsc);

			# sort alphabetically by dist and then net_sta_chan
			usort($netstachans, 'compare_distances');
		}

		if (isset($DATATYPE)) {
			print "<table border=1>\n";
			if ($DATATYPE == "LIST") {
				print "<tr><th>NET STA CHAN</th> <th>km</th> <th>miles</th> </tr>\n";
			}
			for ($i = 0; $i < $nchannels; $i++) {	
				$net = $netstachans[$i]['net'];			
				$sta = $netstachans[$i]['sta'];			
				$chan = $netstachans[$i]['chan'];			
				$dist = $netstachans[$i]['dist'];
				$url = "http://avosouth.wr.usgs.gov/valve3/valve3.jsp";
				#$mediumsize = "w=760&h=200&n=1&x.0=75&y.0=19&w.0=610&h.0=140&mh.0=400";
				$largesize = "w=1300&h=200&n=1&x.0=65&y.0=23&w.0=1200&h.0=150&mh.0=400";
				$mediumsize = "w=1300&h=150&n=1&x.0=55&y.0=19&w.0=1200&h.0=100&mh.0=400";
				$smallsize = "w=1300&h=100&n=1&x.0=45&y.0=15&w.0=1200&h.0=70&mh.0=400";
				$tinysize = "w=1300&h=40&n=1&x.0=0&y.0=0&w.0=1300&h.0=35&mh.0=400";
				$size = $smallsize;
				$getstring = "?a=plot&o=png&$size";

				# start and end time
				$hoursagostart = 3;
				$hoursagostop = 0;
				if ($DATATYPE == "RSAM") {
					$hoursagostart = 3 * 24;
				};
       				$timestart = now() - $hoursagostart * 60 * 60 ;
        			list ($year, $month, $day, $hour, $minute) = epoch2YmdHM($timestart);
				$timestartstr = $year.$month.$day.$hour.$minute."00000";
        			$timestop = now() - $hoursagostop * 60 * 60 ;
        			list ($year_stop, $month_stop, $day_stop, $hour_stop, $minute_stop) = epoch2YmdHM($timestop);
				$timestopstr = $year_stop.$month_stop.$day_stop.$hour_stop.$minute_stop."00000";

				$getstring2 = "st.0=".$timestartstr."&et.0=".$timestopstr."&selectedStation.0=".$sta."%20".$chan."%20".$net."&ch.0=".$sta."$".$chan."$".$net;

				if ($DATATYPE == "LIST") {
					print "<tr><td align=\"left\">$net $sta $chan</td>\n";	
					printf("<td align=\"right\">%.1f</td>",$dist);
					printf("<td align=\"right\">%.1f</td></tr>\n",($dist/1.609));
				}
				else
				{

					printf( "<tr><td align=\"center\">$net $sta $chan<br/>%.1f km</td>\n",$dist);	

					if ($DATATYPE == "RSAM") {
						$src = "src.0=ak_rsam";
						$typestr = "type.0=values&valuesPeriod.0=60&ysMin.0=Auto&ysMax.0=Auto&rb.0=T&threshold.0=50&ratio.0=1.3&maxEventLength.0=300&cntsBin.0=H&countsPeriod.0=60";
					}
	
					if ($DATATYPE == "WAVEFORMS") {	
						$src = "src.0=ak_waves";
						$typestr = "type.0=wf&rb.0=T&ysMin.0=Auto&ysMax.0=Auto&spminf.0=0.0&spmaxf.0=15.0&splp.0=T&splf.0=F&fminhz.0=0.5&fmaxhz.0=15.0&ftype.0=N";
					}
					if ($DATATYPE == "SPECTROGRAMS") {
						$src = "src.0=ak_waves";
						$typestr = "type.0=sg&rb.0=T&ysMin.0=Auto&ysMax.0=Auto&spminf.0=0.0&spmaxf.0=15.0&splp.0=T&splf.0=F&fminhz.0=0.5&fmaxhz.0=15.0&ftype.0=N";
					}
					$fullurl = $url.$getstring."&".$src."&".$getstring2."&".$typestr;
					#print "$fullurl\n<br/>\n";
					print "<td><img src=\"$fullurl\"></td></tr>\n";
				}
			}
			print "</table>\n";
		}
	}


?>


</body>
</html>


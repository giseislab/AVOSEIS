<?php
include('./includes/antelope.inc');

// Read in CGI parameters
$starttime= !isset($_REQUEST['starttime'])? epoch2str(now()-3600, '%Y%m%d%H%M%S%s') : $_REQUEST['starttime'];
$endtime= !isset($_REQUEST['endtime'])? epoch2str(now(), '%Y%m%d%H%M%S%s') : $_REQUEST['endtime'];
$fmin= !isset($_REQUEST['fmin'])? 0.8 : $_REQUEST['fmin'];
$fmax= !isset($_REQUEST['fmax'])? 15.0 : $_REQUEST['fmax'];
$stachanlist = !isset($_REQUEST['stachanlist'])? "AV.RSO.EHZ,AV.REF.EHZ" : $_REQUEST['stachanlist'];
		
$page_title = "waveforms";
$css = array( "style.css", "table.css" );
$googlemaps = 0;
$js = array( "changedivcontent.js");

// Standard XHTML header
include('includes/header.inc');
##include('includes/mosaicMaker.inc');
##header(0);

?>
<body bgcolor="#FFFFFF">
<?php	
if (isset($starttime) && isset($endtime) && isset($stachanlist)) {
	$netstachanarray = explode(",", $stachanlist);
	print "<table border=1>\n";
	foreach ($netstachanarray as $netstachan) {
		list ($net, $sta, $chan) = explode(".", $netstachan); 
		$url = "http://avosouth.wr.usgs.gov/valve3/valve3.jsp";
		#$url = "http://humpy.giseis.alaska.edu:8080/valve3/valve3.jsp";
		$largesize = "w=1300&h=200&n=1&x.0=65&y.0=23&w.0=1200&h.0=150&mh.0=400";
		$mediumsize = "w=1300&h=150&n=1&x.0=55&y.0=19&w.0=1200&h.0=100&mh.0=400";
		$smallsize = "w=1300&h=100&n=1&x.0=45&y.0=15&w.0=1200&h.0=70&mh.0=400";
		$tinysize = "w=1300&h=40&n=1&x.0=0&y.0=0&w.0=1300&h.0=35&mh.0=400";
		$size = $smallsize;
		$getstring = "?a=plot&o=png&$size";
		$getstring2 = "st.0=".$starttime."&et.0=".$endtime."&selectedStation.0=".$sta."%20".$chan."%20".$net."&ch.0=".$sta."$".$chan."$".$net;
		printf( "<tr><td align=\"center\">$net $sta $chan</td>\n");	
		$src = "src.0=ak_waves";
		$typestr = "type.0=wf&rb.0=T&ysMin.0=Auto&ysMax.0=Auto&spminf.0=$fmin&spmaxf.0=$fmax&splp.0=T&splf.0=F&fminhz.0=$fmin&fmaxhz.0=$fmax&ftype.0=B";
		$fullurl = $url.$getstring."&".$src."&".$getstring2."&".$typestr;
		print "<td><img src=\"$fullurl\"></td></tr>\n";
	}
	print "</table>\n";
}

?>


</body>
</html>


<?php
include('./includes/antelope.inc');
$detectionsfile = "$datadir/diagnostic/hourlydetections.txt";

// Read in CGI parameters
$DBGRID= !isset($_REQUEST['DBGRID'])? NULL : $_REQUEST['DBGRID'];
		
$page_title = "Grid detections";
$css = array( "style.css", "table.css" );
$googlemaps = 0;
$js = array( "changedivcontent.js");

// Standard XHTML header
include('includes/header.inc');

?>

<body bgcolor="#FFFFFF">
	
	<h1>Hourly detections</h1>

	<form name="dbgrid" method="get">
	<b>Choose grid</b>
	<SELECT NAME="DBGRID">
<?php
	// Loop over all files matching dbgrid*.site
	$sitefiles = glob("$datadir/grids/dbgrid*.site");
	foreach($sitefiles as $sitefile) {
	    if ($sitefile == $DBGRID) {
		print "<OPTION SELECTED>$sitefile\n";
	    }
	    else
	    {
	    	print "<OPTION>$sitefile\n";
	    }
	}
?>

	</SELECT>
	<input type="submit" value="Submit" />
	</form>

<?php
	if (isset($DBGRID)) {
	# open database table
	$db = ds_dbopen_table($DBGRID, "r") or die("<p>Could not open $DBGRID</p></body></html>");
	$nrecs = dbnrecs($db);
	print "<p>($nrecs sites)</p>";
	if ($nrecs > 0) {
		echo "<pre>\n";
		echo `grep time $detectionsfile`;
		for ($db[3]=0; $db[3] < $nrecs; $db[3]++) {
			$sta = dbgetv($db, 'sta');
			if ($result =  `grep $sta $detectionsfile`) {
				echo $result;
			}
			else
			{
				$nullstations = $nullstations." ".$sta;
			}
			
		}
		if ($nullstations) {
			print "0 detections on $nullstations\n";
		}
		echo "</pre>\n";
	}
	ds_dbclose($db);
	}

?>


</body>
</html>

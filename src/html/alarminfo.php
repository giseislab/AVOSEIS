<?php
include('./includes/antelope.inc');

// Read in CGI parameters
$alarmid= !isset($_REQUEST['alarmid'])? NULL : $_REQUEST['alarmid'];
$alarmkey= !isset($_REQUEST['alarmkey'])? NULL : $_REQUEST['alarmkey'];
$alarmname = !isset($_REQUEST['alarmname'])? NULL : $_REQUEST['alarmname'];
$subject = !isset($_REQUEST['subject'])? NULL : $_REQUEST['subject'];	
$dir = !isset($_REQUEST['dir'])? NULL : $_REQUEST['dir'];
$dfile = !isset($_REQUEST['dfile'])? NULL : $_REQUEST['dfile'];	
$acknowledged = !isset($_REQUEST['acknowledged'])? NULL : $_REQUEST['acknowledged'];		
$ackauth = !isset($_REQUEST['ackauth'])? NULL : $_REQUEST['ackauth'];		
$acktime = !isset($_REQUEST['acktime'])? NULL : $_REQUEST['acktime'];	
		
$page_title = "Alarm $alarmkey";
$css = array( "style.css", "table.css" );
$googlemaps = 0;
$js = array( "changedivcontent.js");

// Standard XHTML header
include('includes/mosaicMaker.inc');
include('includes/header.inc');

?>

<body bgcolor="#FFFFFF">

<?php
if (isset($alarmkey)) {	
	print "<h3>Alarm message</h3>\n";
	print "<p/><b>Subject: $subject</b></p>\n";
	#include("$dir/$dfile");
	$dir = "$datadir/$dir";
	$alarmcomm = "$datadir/dbalarm/alarm.alarmcomm";
	print "<p>(Reading message from $dir/$dfile)</p>";
	$myFile = "$dir/$dfile";
	$fh = fopen($myFile, 'r');
	while ($theData = fgets($fh)) {;
		echo "&nbsp;&nbsp;&nbsp;   $theData<br/>";	
	}
	fclose($fh);




	# open database alarmcomm table

	$db = ds_dbopen_table($alarmcomm, "r") or die("<p>Could not open $alarmcomm</p></body></html>");

	$db = dbsubset($db, "alarmid == $alarmid");
	$nrecs = dbnrecs($db);
	print "<p>(Read $nrecs records from $alarmcomm for alarmid=$alarmid)</p>";

	if ($nrecs > 0) {
		print "<h3>Alarm Calldown</h3>\n";
		print "<table border=\"1\">";
		printf("<tr><th>Time (UTC)</th><th>Recipient</th><th>Delay (s)</th> </tr>\n");

		for ($db[3]=0; $db[3] < $nrecs; $db[3]++) {
			list($recipient, $delaysec, $lddate) = dbgetv($db, 'recipient', 'delaysec', 'lddate');
			list ($ayear, $amonth, $aday, $ahour, $aminute) = epoch2YmdHM($lddate);
			$astr = epoch2str($lddate,'%Y/%m/%d %H:%M:%S');	
			#printf("<tr><td>$ayear/$amonth/$aday $ahour:$aminute</td><td>$recipient</td><td>$delaysec</td> </tr>\n");
			printf("<tr><td>$astr</td><td>$recipient</td><td>%4.0f</td> </tr>\n",$delaysec);

		}
		print "</table>\n";
	}
	ds_dbclose($db);


	if ($acknowledged == 'y') {
		printf("<p><b>This alarm was acknowledged by $ackauth at %s UTC</b></p>",epoch2str($acktime, '%Y/%m/%d %H:%M:%S'));
	}
	else
	{
		printf("<p><b>This alarm has not been acknowledged</b></p>");

	}

}
else
{
	print "<p>No alarm selected. Choose an <a href=\"confirm_alarms.php\">alarm</a></p>\n";
}
?>


</body>
</html>

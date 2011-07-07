<?php
include('./includes/antelope.inc');
$database = "$datadir/dbalarm/alarm.alarms";

// Read in CGI parameters
$username = !isset($_REQUEST['username'])? NULL : $_REQUEST['username'];
#$passwd = !isset($_REQUEST['passwd'])? NULL : $_REQUEST['passwd'];
$ackkey = !isset($_REQUEST['ackkey'])? NULL : $_REQUEST['ackkey'];	
$showall = !isset($_REQUEST['showall'])? 0 : $_REQUEST['showall'];
$ackauth = !isset($_REQUEST['ackkey'])? NULL : $_REQUEST['ackkey'];	
$boolShowAll = ($showall == "Show_All") ? 1 : 0;
$oldestTimeToShow = now() - 7 * 24 * 60 * 60; 
$oldestTimeToShow = str2epoch('2009/02/22'); 	

$page_title = "Alarm Acknowledgement Page";
$css = array( "style.css", "table.css" );
$googlemaps = 0;
$js = array( "changedivcontent.js");

// Standard XHTML header
include('includes/mosaicMaker.inc');
include('includes/header.inc');

?>

<body bgcolor="#FFFFFF">

<?php

	# Check for author/login
	if (is_null($username)){
		print "<h2>Alarm acknowledgment menu</h2>";
?>
		<form method="post">

		<h3>Please enter your name: <input type="text" name="username" size="20" maxlength="40"/></h3>


		<p>The menu that follows is used to acknowledge and cancel AVO seismic alarms. <br/>Access is not
restricted, however, alarm acknowledgments are tagged with your name.</p>

		<p>By acknowledging an alarm, you accept responsibility for one of the following:</p>
		<ol>
		<li>analyzing the data to determine if action is warranted</li>
		<li>contacting another person who will do (1)</li>
		</ol>
		<p><input type="submit" name="submit" value="Enter" /></p>
		<!-- <input type="hidden" name="submitted" value="TRUE" /> -->
		</form>
		</body>
		</html>
<?php
		die("");
	}

	# THIS IS WHERE ALARMS ARE ACKNOWLEDGED
	# open database
	print "<p>Trying to open $database</p>\n";
	$db = ds_dbopen_table($database, "r+") or die("<p>Could not open $database</p></body></html>");

	if (!is_null($ackkey)) {
		$db = dbsubset($db, "alarmkey == '$ackkey'") or die("<p>Could not subset $database</p></body></html>");
		$nrecs = dbnrecs($db);

		if ($nrecs > 0) {
			$acktime = now(); 
			list ($ayear, $amonth, $aday, $ahour, $aminute) = epoch2YmdHM($acktime);

			for ($db[3]=0; $db[3] < $nrecs; $db[3]++) {
				# DON'T LET A PREVIOUSLY ACKNOWLEDGED ALARM GET RE-ACKNOWLEDGED
				# For example, if there have been 10 alarms about a swarm, and the previous 9
				# were acknowledged, confirming the 10th should not overprint the author and time
				# on the other nine!
				$already_acknowledged = dbgetv($db, 'acknowledged');
				if ($already_acknowledged != 'y') {
					dbputv($db, 'acknowledged', 'y', 'acktime', $acktime, 'ackauth', $username); # or die("<p>Could not write to $database</p></body></html>");
				}
			}
		}
	}
	ds_dbclose($db);	

?>
<div id="message">
</div>

<form method="get">
<hr/>
<?php
	$toggleshowall = "Show_All";
	if ($boolShowAll == 1) {
		$toggleshowall = "Show Unacknowledged Alarms Only";
	}
	echo "<input type=\"submit\" name=\"showall\" value=\"$toggleshowall\">";

	echo "<input type=\"hidden\" name=\"username\" value=\"$username\" />";
	try {
		list ($oyear, $omonth, $oday, $ohour, $ominute) = epoch2YmdHM($oldestTimeToShow);
	}
	catch (Exception $e) {
		echo '<p>Caught exception ',$e->getMessage(), "\n";
	}
	print "<p>Showing alarms since $oyear/$omonth/$oday $ohour:$ominute UTC from $database</p>\n";
	$tooOld = 0;


?>
<hr/>
<p>Each row in the following table corresponds to a separate alarm that was declared</p>
<p><b>Acknowledge alarms by clicking on the button in column 1 (Key)</b></p>

<table border="1">

<?php
	$db = ds_dbopen_table($database, "r+") or die("<p>Could not open $database</p></body></html>");

	if ($boolShowAll == 0) {
		$db = dbsubset($db, "acknowledged == 'n'");
	}
	printf("<tr><th>Key</th><th>UTC Time</th><th>Alarm Class</th><th>Algorithm Name</th><th>Subject</th><th>Calldown...</th> </tr>\n");

        for ($db[3]=(dbnrecs($db)-1); $db[3] > -1 && !$tooOld; $db[3]--) {

		# read in database row
                list($alarmid, $alarmkey, $alarmclass, $alarmname, $time, $subject, $acknowledged, $ackauth, $acktime, $dir, $dfile)  = dbgetv($db, 'alarmid', 'alarmkey', 'alarmclass', 'alarmname', 'time', 'subject', 'acknowledged', 'ackauth', 'acktime', 'dir', 'dfile');

		# check if time is older than oldestTimeToShow
		if ($time >= $oldestTimeToShow) {

			# format time for printing out
			list($year, $month, $day, $hour, $minute)=epoch2YmdHM($time);
			$timestr="$year/$month/$day $hour:$minute";
			if ($acktime > 0) {
				list ($ayear, $amonth, $aday, $ahour, $aminute) = epoch2YmdHM($acktime);
				$acktimestr="$ayear/$amonth/$aday $ahour:$aminute</p>\n";
			}
			else
			{
				$acktimestr="";
			}
	
	
			# create a url to a spectrogram mosaic
			list($syear, $smonth, $sday, $shour, $sminute)=epoch2YmdHM($time-(60*60*11/6)); # should go back ~1h50m
			$sminute = floorminute($sminute);
			$mosaicurl = "iceweb2/html/mosaicMakerDateTime.php?subnet=Redoubt&year=$syear&month=$smonth&day=$sday&hour=$shour&minute=$sminute&numhours=2";
			$mosaiclink = "<a href=\"$mosaicurl\" target=\"_new\">show</a>";
	 
			# create a link to the message file
			#$messagelink = "<a href=\"$dir/$dfile\" onclick=\"load('$dir/$dfile','message');return false;\">show</a>";

			# create a submit link to calldown
			#$calldown = "<input type=\"submit\" name=\"calldown\" value=\"$alarmid\">";

			# create a more link
			$calldownlink = "<a href=\"alarminfo.php?alarmid=$alarmid&alarmkey=$alarmkey&alarmname=$alarmname&subject=$subject&dir=$dir&dfile=$dfile&acknowledged=$acknowledged&ackauth=$ackauth&acktime=$acktime\" target=\"more\">show</a>"; 

			if ($acknowledged == 'n') {
				$status = "not_acknowledged"; # used in table.css
				$firstcol = "<input type=\"submit\" name=\"ackkey\" value=\"$alarmkey\">";
	
			}
			else
			{
				$firstcol = $alarmkey;
				$status ="acknowledged";
			}
			printf("<tr class=\"$status\"><td>$firstcol</td> <td>$timestr</td> <td>$alarmclass</td> <td>$alarmname</td> <td>$subject</td> <td>$calldownlink</td> </tr>\n");

			$timestr="$year/$month/$day $hour:$minute";
		}
		else
		{
			$tooOld = 1;
		}
			
        }
	
	# close database
	ds_dbclose($db);	
?>

</table>

</form>

<hr/>
<h3>Current parameter file settings</h3>
<?php

#$pfarray = array('rtexec.pf', 'orbdetect.pf', 'orbassoc.pf', 'dbwatchtable.pf', 'dbdetectswarm_RD.pf', 'dbalarmdispatch.pf');
$pfarray = glob("../pf/*.pf");
foreach ($pfarray as $pffile) {
	$pfbase = basename($pffile);
	#echo "<a href=\"showPfs.php?pffile=$pffile\" target=\"params\" >$pffile</a><br/>";
	echo "<a href=\"showPfs.php?pffile=$pffile\" target=\"params\" >$pfbase</a><br/>";
}

# The current time
list ($cyear, $cmonth, $cday, $chour, $c1minute) = epoch2YmdHM(now());

# Server time
echo "<hr/>";
echo "<p>Server processed your request at: $cyear/$cmonth/$cday $chour:$c1minute</p>";	
echo "<p>Your name $username will be recorded when you acknowledge alarms</p>";
?>

</body>
</html>

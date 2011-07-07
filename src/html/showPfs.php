<?php
include('./includes/antelope.inc');

// Read in CGI parameters
$pffile= !isset($_REQUEST['pffile'])? NULL : $_REQUEST['pffile'];
		
$page_title = "Parameter file $pffile";
$css = array( "style.css", "table.css" );
$googlemaps = 0;
$js = array( "changedivcontent.js");

// Standard XHTML header
include('includes/header.inc');
?>

<body bgcolor="#FFFFFF">

<?php
	$myFile = "$pfdir/$pffile";
	
	print "<h3>Contents of the parameter file $myFile</h3>\n";

	$fh = fopen($myFile, 'r');
	while ($theData = fgets($fh)) {;
		echo "&nbsp;&nbsp;&nbsp;   $theData<br/>";	
	}
	fclose($fh);

?>


</body>
</html>

<?php
$refresh = 0;
echo "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"
	\"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n";

echo "<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">\n";
echo "<head>\n";
	echo "<meta http-equiv=\"content-type\" content=\"text/html\"; charset=iso-8859-1\" />\n";
	if ($refresh > 0) {
		echo "<meta http-equiv=\"refresh\" content=\"$refresh\" />\n";
	}

	echo "<title>$page_title</title>\n";
	echo "\n";
	foreach ($css as $cssfile) {
		echo "\t<link rel=\"stylesheet\" href=\"css/$cssfile\" />\n";
	}
	if ($googlemaps == 1) {
		echo "\t<script src=\"http://maps.google.com/maps?file=api&amp;v=2&amp;key=ABQIAAAAXvsk9998ISR02l2phHU8XBSfXd_Vn7F8xzcCxmIsDuIu46yPpxTI_Mxhu7CxWYXteCoX3Fn7-edpmA\" type=\"text/javascript\"></script>\n";
	}
	foreach ($js as $jsfile) {
		echo "\t<script src=\"includes/$jsfile\" type=\"text/javascript\"> </script>\n";
	}
echo "</head>\n";
?>

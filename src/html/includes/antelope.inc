<?php
$_ENV{'ANTELOPE'} = "/opt/antelope/5.0-64";
#
if( !extension_loaded( "Datascope" ) ) { 
        dl( "Datascope.so" ) or die( "Failed to dynamically load Datascope.so" ) ; 
}
$cwd = getcwd();

clearstatcache();

# global variables	
$pfdir = '../pf';
$datadir = '../data';
$plotsdir = '../plots';
$AVOEQ = '../AVOEQ';

?>

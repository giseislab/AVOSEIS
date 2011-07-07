
# db2responselist 
# Create hyperlinked response file list
# Michael West
# 10/2006
use Datascope ;



if (! $#ARGV == 0 ) {
        die ( "Useage: dbresponse2html dbin. *Note that actual response files must be copied by hand." );
}



# GET TABLES FOR ORIGINS
$dbname = pop(@ARGV);
@db = dbopen($dbname,'r');
@db = dblookup(@db,"","sitechan","",1);
@db2 = dblookup(@db,"","sensor","",1);
@db3 = dblookup(@db,"","instrument","",1);
@db  = dbjoin(@db,@db2);
@db  = dbjoin(@db,@db3);
@db = dbsort(@db,'sta');
$nrecords = dbquery(@db,"dbRECORD_COUNT");
print STDERR "number of channels $nrecords\n";


if ($nrecords == 0) {
	die ("database does not exist or joined view contains no records");
}


# FILE HEADER
print "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
print "<html>\n";
print "<head>\n";
print "<meta http-equiv=\"content-type\" content=\"text/html;charset=iso-8859-1\">\n";
print "<title>AVO - Response file details</title>\n";
#print "<style type=\"text/css\">\n";
#print "td\n";
#print "   {\n";
#print "    font-family:sans-serif\n";
#print "    font-size:x-small\n";
#print "   }\n";
#print "</style>\n";
print "</head>\n";

print "\n\n<body bgcolor=\"#ffffff\" link=\"#000066\">\n";
print "<font face=\"Helvetica, Geneva, Arial, SunSans-Regular, sans-serif\">\n";

$curr_date = strlocaltime(now());
print "Last updated at: $curr_date<br><br>\n";
print "<table border=0>\n";
print "<tr><th>sta</th><th>chan</th><th>on-date</th><th>off-date</th><th>id</th><th>file_location</th><th>instrument_name</th><tr>\n";

for ($db[3]=0 ; $db[3]<$nrecords ; $db[3]++) {
	($sta,$chan,$dir,$dfile,$rsptype,$inid,$insname,$instr_time,$instr_endtime) = dbgetv(@db,"sta","chan","dir","dfile","rsptype","inid","insname","sensor.time","sensor.endtime");
	$instr_timestr    = epoch2str($instr_time,'%Y/%m/%d(%j)');
	$instr_endtimestr = epoch2str($instr_endtime,'%Y/%m/%d(%j)');
	$dirdfile = $dir.'/'.$dfile;
	#printf "%-5s %3s %s %s %4d <a href=\"%s\">%s</a> %s<br>\n",$sta,$chan,$instr_timestr,$instr_endtimestr,$inid,$dirdfile,$dirdfile,$insname;
	printf "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td align=\"right\">%d</td><td><a href=\"%s\">%s</a></td><td>%s</td></tr>\n",$sta,$chan,$instr_timestr,$instr_endtimestr,$inid,$dirdfile,$dirdfile,$insname;
}
dbclose(@db);





# PRINT HTML FOOTER
print "</table>\n";
print "</font>\n";
print "</body>\n";
print "</html>\n";








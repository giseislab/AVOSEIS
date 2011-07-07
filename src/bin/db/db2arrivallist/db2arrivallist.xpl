
# db2arrivallist
# Output a text formatted list of origin and arrival information
# Michael West
# 10/2006
use Datascope ;


if (! $#ARGV == 0 ) {
	die ( "Useage: db2arrivallist dbin > outfile" );
}


# GET TABLES FOR ORIGINS
$dbname = pop(@ARGV);
@db    = dbopen($dbname,'r');
@dbor  = dblookup(@db,"","origin","","");
@db2   = dblookup(@db,"","event","","");
@db3   = dblookup(@db,"","netmag","","");
@dbor  = dbjoin(@dbor,@db2);
@dbor  = dbsubset(@dbor,'orid==prefor');
@dbor  = dbjoin(@dbor,@db3);
@dbor  = dbsort(@dbor,'-r','time');
$nrecords = dbquery(@dbor,"dbRECORD_COUNT");
#print STDERR "number of hypocenters: $nrecords\n";
if ($nrecords == 0) {
	die ("No records exist after join");
}


# GET TABLES FOR ARRIVALS
@dbarr  = dbopen($dbname,'r');
@dbarr  = dblookup(@dbarr,"","origin","","");
@db1    = dblookup(@dbarr,"","event","","");
@db2    = dblookup(@dbarr,"","assoc","","");
@db3    = dblookup(@dbarr,"","arrival","","");
@dbarr  = dbjoin(@dbarr,@db1);
@dbarr  = dbsubset(@dbarr,'orid==prefor');
@dbarr  = dbjoin(@dbarr,@db2);
@dbarr  = dbjoin(@dbarr,@db3);
#@dbarr  = dbsort(@dbarr,'-r','orid');
$nrecordsarr = dbquery(@dbor,"dbRECORD_COUNT");


# HEADER INFO
$curr_date = strlocaltime(now());
#print "Last updated at: $curr_date\n\n";
print "Produced at $curr_date (from database $dbname)\n\n";
print "Origin line format:\n";
print "  date   yrday     time         lat      lon    depth  mag magtype author eventid\n\n";
print "Arrival line format:\n";
print "     sta   chan  phase  date   yrday     time      residual  arrivalid\n\n";


# DO FOR EACH EVENT
$nrecordsToDo = $nrecords;
#if ($nrecords > 50) {    # truncate to 50 origins
#	$nrecordsToDo = 50;
#}
for ($dbor[3]=0 ; $dbor[3]<$nrecordsToDo ; $dbor[3]++) {
	($lon,$lat,$depth,$time,$orid,$evid,$magnitude,$magtype,$auth) = dbgetv(@dbor,"lon","lat","depth","time","orid","evid","magnitude","magtype","auth");
	$timestr = epoch2str($time,'%D (%j) %H:%M:%S.%s');
	printf "\n%s %9.4f %9.4f %5.1f %4.1f    %s   %s %d\n",$timestr,$lat,$lon,$depth,$magnitude,$magtype,$auth,$evid;


	# LOOP THROUGH ARRIVALS FOR THIS EVENT
	@dbarr1 = dbsubset(@dbarr,"orid==$orid");
	$nrecordsarr1 = dbquery(@dbarr1,"dbRECORD_COUNT");
	for ($dbarr1[3]=0 ; $dbarr1[3]<$nrecordsarr1 ; $dbarr1[3]++) {
		($arid,$sta,$chan,$phase,$arr_time,$timeres,$timedef) = dbgetv(@dbarr1,"arid","sta","chan","phase","arrival.time","timeres","timedef");
		$arr_timestr = epoch2str($arr_time,'%D (%j) %H:%M:%S.%s');
	if ( ($timedef !~ 'n') && ($timeres>-999) ) {
			printf "     %-5s  %3s  %3s  %s  %8.3f  %d\n",$sta,$chan,$phase,$arr_timestr,$timeres,$arid;
		}
	}

}
dbclose(@dbor);
#dbclose(@dbarr);  # not sure why this line causes an error?


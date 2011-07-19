
# get_avo_stations_db
# 
# Michael West
# 10/2006
use Datascope ;
use File::Copy ;


if (! $#ARGV == 0 ) {
	die ( "Useage: get_avo_stations_db dbout\n\nSee man page for description" );
}


$dbstations = '/iwrun/op/params/Stations/master_stations';
$dbout = pop(@ARGV);

# REMOVE OLD TABLES
unlink($dbout);
unlink($dbout.'network');
unlink($dbout.'affiliation');
unlink($dbout.'site');
unlink($dbout.'sitechan');
unlink($dbout.'sensor');
unlink($dbout.'instrument');
unlink($dbout.'calibration');
unlink($dbout.'snetsta');
unlink($dbout.'schanloc');

# SUBSET NET AND JOIN TABLES
@dbwhole = dbopen($dbstations,'r');
@db = dblookup(@dbwhole,"","network","","");
@db = dbsubset(@db,'net=="AV"');
@db1 = dblookup(@dbwhole,"","affiliation","","");
@db = dbjoin(@db,@db1);

@db1 = dblookup(@dbwhole,"","site","","");
@db = dbjoin(@db,@db1);
$ydnow = yearday(now);
print "** $ydnow **\n";
@db = dbsubset(@db,"(site.offdate>=$ydnow) || (site.offdate==NULL)");

@db1 = dblookup(@dbwhole,"","sitechan","","");
@db = dbjoin(@db,@db1);

@db1 = dblookup(@dbwhole,"","sensor","","");
@db = dbjoin(@db,@db1,'-outer');

@db1 = dblookup(@dbwhole,"","instrument","","");
@db = dbjoin(@db,@db1,'-outer');

@db1 = dblookup(@dbwhole,"","calibration","","");
@db = dbjoin(@db,@db1,'-outer');

@db1 = dblookup(@dbwhole,"","schanloc","","");
@db = dbjoin(@db,@db1,'-outer');

@db1 = dblookup(@dbwhole,"","snetsta","","");
@db = dbjoin(@db,@db1,'-outer');

dbunjoin(@db,$dbout);

copy($dbstations.sensor,$dbout.sensor);
copy($dbstations.instrument,$dbout.instrument);
copy($dbstations.calibration,$dbout.calibration);


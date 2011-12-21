
##############################################################################
# Author: Glenn Thompson (GT) 2009
#         ALASKA VOLCANO OBSERVATORY
#
# History:
#	2009-07-29: Created by GT, based on dbsplitcron, a csh by Mitch
#
# To do:
##############################################################################

use Datascope;
use Getopt::Std;

use strict;
use warnings;

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

# Usage - command line options and arguments
our ($opt_v, $opt_d, $opt_n); 
if ( ! &getopts('vdn:') || $#ARGV < 0  ) {
    print STDERR <<"EOU" ;


    Usage: $PROG_NAME [-v] [-d] [-n N] /home/iceweb/run/events/unreviewed/events [2009-07-25]

    This program is used to take a quakes database, containing several days
    of data, and split out from it a database like Quakes_2009_07_25 and make
    links like Quakes_2009_07_26@ - > quakes. The first command line argument
    is the directory containing these databases.

    The optional date parameter makes it possible to split out a database for
    any date, rather than just the previous day (default). 
	
    The -d switch will permanently remove records from the input database.
    Omitting this `will leave the selected records in both databases.

    The -n switch can be used to override the number of days to keep in the
    input database. The default is 1 (the current UT day only). This argument
    is ignored if a yyyy-mm-dd command line argument is given.
 
EOU
    exit 1 ;
}

# End of  GT Antelope Perl header
#################################################################
use Avoseis::Utils qw(runCommand);
use File::Basename;
use Cwd;
our $cwd= getcwd();
printf("\n**************************************\n\nRunning $PROG_NAME at %s\n\n", epoch2str(now(),"%Y-%m-%d %H:%M:%S")); 

#### COMMAND LINE ARGUMENTS
my $numberOfDays = 1;
if ($opt_n) {
	$numberOfDays = $opt_n;
	die("-n argument should be a positive integer between 1 and 365 (days)\n") if ($numberOfDays < 1 || $numberOfDays > 365);
}
my $oneday = "86400";
my $epochstartdate = str2epoch(epoch2str(now() - $oneday * $numberOfDays,  "%Y-%m-%d"));
if ($#ARGV == 1) {
	$epochstartdate = str2epoch($ARGV[1]);
}
my $epochenddate = $epochstartdate + $oneday;

my ($inputdb, $dbdir, $outputdb, $outputdbbase);
if (-f $ARGV[0]) {
	$inputdb = basename($ARGV[0]);
	$dbdir = dirname($ARGV[0]);
	$outputdbbase = $inputdb;
}
else
{
	$dbdir = $ARGV[0];
	$inputdb = "quakes";
	$outputdbbase = "Quakes";
}
$outputdb = $outputdbbase.epoch2str($epochstartdate, "_%Y_%m_%d");
die("Input database ($dbdir/$inputdb) does not exist!\n") unless (-e "$dbdir/$inputdb");
chdir("$dbdir");


# remove current links - each day we will replace a link to outputdb with a split database
if ( -l $outputdb ) {
  print "Removing the link $outputdb\n";
  unlink($outputdb);
}
foreach my $table qw( arrival assoc event netmag origin stamag detection wfrms) {
  if ( -l $outputdb.".".$table ) {
    print "Removing the link $outputdb.$table\@\n";
    unlink($outputdb.".".$table);
  }
}
# THINK DBSPLIT IS SMART ENOUGH TO COPY TO OUTPUTDB, RATHER THAN OVERWRITE OUTPUTDB - SO DON"T NEED THIS OR MERGE
# copy the outputdb if it exists
#foreach my $table qw(origin event assoc arrival netmag stamag origerr detection) {
#	if (-e "$outputdb.$table") {
#		&runCommand("cp $outputdb.$table $outputdb.$table.old", 1);
#	}
#}


# split the database between the start and end dates
printf "Will create $outputdb by splitting out rows from database $inputdb %s to %s\n",epoch2str($epochstartdate, "%Y-%m-%d"),epoch2str($epochenddate, "%Y-%m-%d");
if ($opt_d) { # Permanently delete the selected records from the input database, and move them to the output database
	&runCommand("dbsplit -dkv -p $cwd/pf/dbsplit_detection.pf -s \"time > $epochstartdate && time < $epochenddate\" $inputdb $outputdb",1);
	&runCommand("dbsplit -dkv -p $cwd/pf/dbsplit.pf -s \"time > $epochstartdate && time < $epochenddate\" $inputdb $outputdb",1);
}
else
{ # Copy the selected records from the input database to the output database
	&runCommand("dbsplit -fkv -p $cwd/pf/dbsplit_detection.pf -s \"time > $epochstartdate && time < $epochenddate\" $inputdb $outputdb",1);
	&runCommand("dbsplit -fkv -p $cwd/pf/dbsplit.pf -s \"time > $epochstartdate && time < $epochenddate\" $inputdb $outputdb",1);
}

# DBSPLIT SMART ENOUGH BECAUSE IT COPIES RATHER THAN OVERWRITES
# merge the old outputdb if it exists - allows new reviewed origins to be folded into an old database
#foreach my $table qw(origin event assoc arrival netmag stamag origerr detection) {
#	if (-e "$outputdb.$table.old") {
#		if (-e "$outputdb.$table") { # merge them
#			&runCommand("cat $outputdb.$table.old $outputdb.$table > $outputdb.$table.new", 1);
#			&runCommand("mv $outputdb.$table.new $outputdb.$table", 1);
#			&runCommand("rm $outputdb.$table.old", 1);
#		} else {
#			&runCommand("mv $outputdb.$table.old $outputdb.$table", 1);
#		}
#	}
#}

# cp descriptor file - it just points to the master stations database, and will contain local event tables
if ( -f $inputdb ) {
  print "Copying $inputdb to $outputdb\n";
  &runCommand("cp $inputdb $outputdb",1);
}

# create new links like Quakes_2009_07_29@ -> quakes
for (my $epochtime = $epochenddate; $epochtime < now(); $epochtime += $oneday) {
	my $linkoutputdb = epoch2str($epochtime, $outputdbbase."_%Y_%m_%d");
	if ( -f $inputdb ) {
	  if ( ! -f $linkoutputdb ) {
	    print "Linking $linkoutputdb\@ -> $inputdb\n" if ($opt_v);
	    system("ln -s $inputdb $linkoutputdb");
	  }
	  else
	  {
	    print "No links needed for $linkoutputdb - it's a file\n" if ($opt_v);
	  }
	}

	# create new links like Quakes_2009_07_29.origin@ -> quakes.origin
	foreach my $table qw( arrival assoc event netmag origin stamag detection wfrms) {
	  if ( -f "$inputdb.$table" ) {
	    if (! -f "$linkoutputdb.$table" ) {
	      print "Linking $linkoutputdb.$table\@ -> $inputdb.$table\n" if ($opt_v);
	      system("ln -s $inputdb.$table $linkoutputdb.$table");
	    }
	  }
	}
}

# Finally, lets check if there are any records older than N days left
my @db = dbopen_table("$inputdb.origin", "r");
@db = dbsubset(@db, "time < $epochstartdate");
if (dbquery(@db, "dbRECORD_COUNT") > 0) {
	@db = dbsort(@db, "time");
	$db[3] = dbquery(@db, "dbRECORD_COUNT") - 1;# could just reverse sort and look at record 0	
	my $time = dbgetv(@db, "time");
	my $stime = epoch2str($time, "%Y-%m-%d");
	my $outdb = epoch2str($time, $outputdb."_%Y_%m_%d");
	print "Will now run $PROG_NAME ".$ARGV[0]." $stime\n";
	chdir($cwd);
	if ($opt_d) {	
		&runCommand("$PROG_NAME -d -v ".$ARGV[0]." $stime", 1);
	}else{
		&runCommand("$PROG_NAME -v ".$ARGV[0]." $stime", 1);
	}
}
dbclose(@db);

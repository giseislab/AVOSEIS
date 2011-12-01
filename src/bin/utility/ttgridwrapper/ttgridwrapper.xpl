use Datascope;
require "getopts.pl" ;
#use strict;
#use warnings;
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();	# PROG_NAME becomes $0 minus any path

#### THIS IS NOT USING OPTIMISED ORBASSOC VALUES

# Usage - command line options and arguments
our ($opt_e);
if ( ! &Getopts('e') || ! $#ARGV == 0  ) {
        print STDERR <<"EOU" ;

        Usage: $PROG_NAME [-e] ttgridpf 

        $PROG_NAME  does three things:
	(1) calls ttgrid for all grids described in a ttgrid parameter file
	Default is to do nothing if a grid file already exists.
	The -e (ERASE) option overwrites pre-existing grids.
        (2) writes a grid regions database for all grids described 
	in a ttgrid parameter file
	(3) write an orbassoc.pf file
EOU
        exit 1 ;
}
use File::Basename;
use List::Util qw[min max];
use Avoseis::SwarmAlarm qw(runCommand getPf prettyprint );
my $ttgridpffile = $ARGV[0];
my $stationdb = "dbmaster/master_stations";
#use Env;

# Create path to new grid regions db
my $gridregiondb = basename $ttgridpffile;
$gridregiondb =~ s/ttgrid/grid/;
$gridregiondb =~ s/\.pf//;
$gridregiondb = "regions/$gridregiondb";
print "GRIDREGIONDB = $gridregiondb\n";

# If grid regions db exists, either delete it or quit program
if (-e $gridregiondb) {
        print "Delete existing $gridregiondb?\n";
        if (<STDIN> =~ /n/) {
                die("Cannot continue\n");
        }
}

# Create descriptor
unless (-e $gridregiondb) {
	open(FOUT, ">$gridregiondb");
	print FOUT<<EOF;
#
schema places1.2
dblocks none
EOF
}

# Create blank regions table & open for writing
system("touch $gridregiondb.regions");
my @db = dbopen_table("$gridregiondb.regions", "r+");

# Load the gridshash from the ttgrid parameter file
my $pfref = &getPf($ttgridpffile);
my %allvars = %$pfref;
my $gridsref = $allvars{"grids"};
my %gridshash = %$gridsref;

# Loop over each grid
foreach my $gridname (keys %gridshash) {
	print "\nGrid = $gridname\n";
	my $gridref = $gridshash{$gridname};
#	my %gridhash = %$gridref;
#	&prettyprint(%gridhash);

	# Calculate corners of grid
	my (@arrlon, @arrlat);
	&gridhash2vertices(0, $gridref, \@arrlon, \@arrlat);

	# Add these corners to the grid regions database
	dbaddv(@db, 'regname', $gridname, 'vertex', 1, 'lon', $arrlon[0], 'lat', $arrlat[0]);
	dbaddv(@db, 'regname', $gridname, 'vertex', 2, 'lon', $arrlon[1], 'lat', $arrlat[1]);
	dbaddv(@db, 'regname', $gridname, 'vertex', 3, 'lon', $arrlon[2], 'lat', $arrlat[2]);
	dbaddv(@db, 'regname', $gridname, 'vertex', 4, 'lon', $arrlon[3], 'lat', $arrlat[3]);
}
dbclose(@db);

# We are going to (re)generate the orbassoc.pf file, here. If it exists, delete it or quit program.
my $orbassocfile = $ttgridpffile;
$orbassocfile =~ s/ttgrid/orbassoc/;
print "ORBASSOCFILE = $orbassocfile\n";
if (-e $orbassocfile) {
	print "Delete existing $orbassocfile?\n";
	if (<STDIN> =~ /n/) {
		die("Cannot continue\n");
	}
}

# Generate header for orbassoc.pf
&orbassoc_header($orbassocfile);

# Get the vertices of the grid. The only reason we are doing this is to put a 30km buffer around the
# grid and then get all stations within this buffer + grid region.
my $buffer = 30 * 360 / 40000; # 30km in decimal degrees
foreach my $gridname (keys %gridshash) {
	print "\nGrid = $gridname\n";
	my $gridref = $gridshash{$gridname};
#	my %gridhash = %$gridref;
#	&prettyprint(%gridhash);

	# Return the corners of a rectangle with a buffer around it - this will tell us which stations to use for each grid
	my (@arrlon, @arrlat);
	&gridhash2vertices($buffer, $gridref, \@arrlon, \@arrlat);

	# From the vertices, get the minimum and maximum longitudes and latitudes of this buffer
	my $lonmin = min(@arrlon);
	my $lonmax = max(@arrlon);
	my $latmin = min(@arrlat);
	my $latmax = max(@arrlat);
	
	# Create a temporary grid parameter file, run ttgrid to create a grid file, and then append to orbassoc.pf
	my $tmppf = "tmp_".$gridname.".pf";
#	if(&gridhash2tmppffile(\%gridhash, $gridname, $tmppf)) {
	if(&gridhash2tmppffile($gridref, $gridname, $tmppf)) {
		print "SUCCESS\n";
		&create_gridfile("grid_$gridname", $latr, $lonr, $lonmin, $lonmax, $latmin, $latmax, $stationdb, $tmppf);
		&orbassoc_addgrid($orbassocfile, $gridname);
	}
	else
	{
		print "FAILED\n";
	}

}
&orbassoc_footer($orbassocfile);

# Update allgrids which contains a site table of all stations used in all grids
#&runCommand("cat grids*/dbgrid*.site | sort | uniq >  allgrids.site", 1);
&orbdetect_stations;
1;


##################################################################
sub gridhash2vertices {

	my ($buffer, $gridhashref, $arrlonref, $arrlatref) = @_;
        my @arrlon = @$arrlonref;
        my @arrlat = @$arrlatref;
	my %gridhash = %$gridhashref;

        foreach my $key (keys %gridhash) {
                if (ref($gridhash{$key}) eq "ARRAY") {
                        my $arrref = $gridhash{$key};
                        my @arr = @$arrref;
                        print "$key = { @arr }\n";
                }
                else
                {
                        print "$key = $gridhash{$key}\n";
                }
        }

	my $strike = $gridhash{'strike'};
	unless ($strike) {
		$strike = 90.0;
		$gridhash{'strike'} = $strike;
	}

        my $lonr = $gridhash{'lonr'};
        my $latr = $gridhash{'latr'};
        my $xmin = $gridhash{'xmin'} - $buffer;
        my $xmax = $gridhash{'xmax'} + $buffer;
        my $ymin = $gridhash{'ymin'} - $buffer;
        my $ymax = $gridhash{'ymax'} + $buffer;

        # Vertex 1
        my ($tmplon, $tmplat) = &move_x($xmin, $strike, $lonr, $latr);
        ($arrlon[0], $arrlat[0]) = &move_y($ymin, $strike, $tmplon, $tmplat);

        # Vertex 2
        ($tmplon, $tmplat) = &move_x($xmax, $strike, $lonr, $latr);
        ($arrlon[1], $arrlat[1]) = &move_y($ymin, $strike, $tmplon, $tmplat);

        # Vertex 3
        ($tmplon, $tmplat) = &move_x($xmax, $strike, $lonr, $latr);
        ($arrlon[2], $arrlat[2]) = &move_y($ymax, $strike, $tmplon, $tmplat);

        # Vertex 4
        ($tmplon, $tmplat) = &move_x($xmin, $strike, $lonr, $latr);
        ($arrlon[3], $arrlat[3]) = &move_y($ymax, $strike, $tmplon, $tmplat);
}


########################################################################
sub orbassoc_header {
	$file = $_[0];
	open(FORB, ">$file");
	print FORB<<EOF;
process_time_window        8            # Main detection processing time window
process_ncycle             8            # how often to do detection processing, in detections
process_tcycle           0.0            # how often to do detection processing, in delta time
process_timeout         60.0            # timeout for processing detections
grid_params &Arr{
EOF
	1;
}

sub orbassoc_addgrid {
        ($file, $gridname) = @_;
        open(FORB, ">>$file");
	if ($gridname =~ /lo$/) {
		print FORB<<EOF;
        $gridname &Arr{
                nsta_thresh     4       # Minimum allowable number of stations
                nxd             11      # Number of east-west grid nodes for depth scans
                nyd             11      # Number of north-south grid nodes for depth scans
                cluster_twin    3       # Clustering time window 
                try_S           no      # yes = Try observations as both P and S
                                        # no  = Observations are P only
                associate_S     no      # yes = Try to associate observations as both P and S
                reprocess_S     no      # yes = Reprocess when new S-associations found
                # phase_sifter  l       # Iphase value for phase sifting, match to iphase in dbdetect.pf
                auth            $gridname   # Set auth field in origin table
                algorithm       orbassoc        # Override algorithm field in origin table
                priority        5       # Grid priority - higher value selects this grid over lower priority grids
                use_dwt         no      # yes = Use source receiver distance weighting factor (or no)
                dwt_dist_near   2.0
                dwt_wt_near     1.0
                dwt_dist_far    6.0
                dwt_wt_far      0.1
        }
EOF
	}
	


        if ($gridname =~ /reg$/) {
                print FORB<<EOF;
        $gridname &Arr{
                nsta_thresh     8       # Minimum allowable number of stations
                nxd             11      # Number of east-west grid nodes for depth scans
                nyd             11      # Number of north-south grid nodes for depth scans
                cluster_twin    3       # Clustering time window
                try_S           yes      # yes = Try observations as both P and S
                                        # no  = Observations are P only
                associate_S     no      # yes = Try to associate observations as both P and S
                reprocess_S     no      # yes = Reprocess when new S-associations found
                # phase_sifter  l       # Iphase value for phase sifting, match to iphase in dbdetect.pf
                auth            $gridname   # Set auth field in origin table
                algorithm       orbassoc        # Override algorithm field in origin table
                priority        2       # Grid priority - higher value selects this grid over lower priority grids
                use_dwt         no      # yes = Use source receiver distance weighting factor (or no)
                dwt_dist_near   2.0
                dwt_wt_near     1.0
                dwt_dist_far    6.0
                dwt_wt_far      0.1
        }
EOF
        }
  1;
}

sub orbassoc_footer {
        $file = $_[0];
        open(FORB, ">>$file");
        print FORB<<EOF;
}
pf_revision_time 1155927041
EOF
        1;
}

sub gridhash2tmppffile {
	($hashref, $gridname, $tmppf) = @_;
	%hash = %$hashref;
	open(FPF, ">$tmppf") or die("Cannot write to $tmppf\n");
	print FPF<<EOF;
grids &Arr{
        $gridname &Arr{
                mode            $hash{'mode'}     # defines an equal-distance projection regular 3-D mesh
                latr            $hash{'latr'}   # reference latitude    (origin of grid)
                lonr            $hash{'lonr'}  # reference longitude   (origin of grid)
                nx              $hash{'nx'}      # Number of X-axis distance grid nodes
                ny              $hash{'ny'}      # Number of Y-axis distance grid nodes
                xmin            $hash{'xmin'}   # Minimum value of X-axis distance grid in degrees
                xmax            $hash{'xmax'}   # Maximum value of X-axis distance grid in degrees
                ymin            $hash{'ymin'}   # Minimum value of Y-axis distance grid in degrees
                ymax            $hash{'ymax'}   # Maximum value of Y-axis distance grid in degrees
                strike          $hash{'strike'}    # Angle from north clockwise in degrees to the X-axis
                compute_P       yes     # yes = Compute P travel times
                compute_S       yes     # yes = Compute S travel times
                method          $hash{'method'}  # method for computing travel times
                model           $hash{'model'}  # model for computing travel times
                depths &Tbl{
EOF
	$deptharrref = $gridhash{'depths'};
        @deptharr = @$deptharrref;
	foreach $depth (@deptharr) {
		print FPF "\t\t$depth\n";
	}
        print FPF<<EOF2;
                }
        }
}
EOF2
	close(FPF);
	return 1;
}

sub create_gridfile {
        ($gridbase, $olat, $olon, $minlon, $maxlon, $minlat, $maxlat, $stationdb, $tmppf) = @_;
        $outgrid = "grids/$gridbase";
        if ($opt_e) { # if OPT_ERASE, then erase grid file
                &runCommand("rm -rf $outgrid", 1) if (-e $outgrid);
        }
        unless (-e $outgrid) { # if grid file already exists, skip this part - do not overwrite (to overwrite all, use -e option)
                $tmpdb = "grids/db$gridbase";
                #$expr = "deg2km(distance(lat, lon, $olat, $olon)) < 50";
                $expr = "lon > $minlon && lon < $maxlon && lat > $minlat && lat < $maxlat && offdate == NULL";
                @dbst = dbopen_table("$stationdb.site", "r");
                @dbst = dbsubset(@dbst, $expr);
                $nstations = dbquery(@dbst, "dbRECORD_COUNT");
                if ($nstations > 0 ) {
                        dbunjoin(@dbst, $tmpdb);
                        eval {
                                &runCommand("ttgrid -pf $tmppf $tmpdb > $outgrid ", 1);
                        };
                        # &runCommand("rm -rf $tmpdb $tmpdb.site", 0) if (-e $tmpdb);
                }
                dbclose(@dbst);
        }
}


sub move_x {
        ($xdeg, $strike, $lon, $lat) = @_;
        $newlon = `dbcalc -c "longitude($lat, $lon, $xdeg, $strike)"`; chomp($newlon);
        $newlat = `dbcalc -c "latitude($lat, $lon, $xdeg, $strike)"`; chomp($newlat);
        $newlon = sprintf("%.3f", $newlon);
        $newlat = sprintf("%.3f", $newlat);
        return ($newlon, $newlat);
}

sub move_y {
        ($ydeg, $strike, $lon, $lat) = @_;
        $newlon = `dbcalc -c "longitude($lat, $lon, $ydeg, $strike-90.0)"`; chomp($newlon);
        $newlat = `dbcalc -c "latitude($lat, $lon, $ydeg, $strike-90.0)"`; chomp($newlat);
        $newlon = sprintf("%.3f", $newlon);
        $newlat = sprintf("%.3f", $newlat);
        return ($newlon, $newlat);
}


sub orbdetect_stations {
        my $dbname = "dbmaster/detection_stations";
	open(FDB, ">$dbname");
	print FDB<<"EOF";
# Datascope Database Descriptor file
schema css3.0
dbpath dbmaster/{master_stations}
EOF
	close(FDB);
        my $orbdetectstations = "pf/orbdetect_stations.pf";
        open(FDET, ">$orbdetectstations");
        &runCommand("cat grids*/dbgrid*.site | sort | uniq > $dbname.site", 1);
        my @db = dbopen_table("$dbname.site", "r");
        my @db2 = dbopen_table("$dbname.sitechan", "r");
        @db2 = dbsubset(@db2, "offdate == NULL");
        @db = dbjoin(@db, @db2);
        @db = dbsubset(@db, "chan =~ /[BES]HZ.*/");
        @db2 = dbopen_table("$dbname.snetsta", "r");
        @db = dbjoin(@db, @db2);
	dbunjoin(@db, "dborbdetect");
        my $nstations = dbquery(@db, "dbRECORD_COUNT");
        my $laststa = "DUMM";
	print FDET "netstachanlocs &Tbl{\n";
        for (my $j=0; $j < $nstations; $j++) {
                $db[3] = $j;
                my ($sta, $lat, $lon, $elev, $snet, $chan, $staname) = dbgetv(@db, "sta", "lat", "lon", "elev", "snet", "chan", "staname");
                print FDET "\t".$snet."_".$sta."_".$chan."_*\n";
        }
	print FDET "}\n";
        close(FDET);
	unlink("$dbname $dbname.site");
        return 1;
}

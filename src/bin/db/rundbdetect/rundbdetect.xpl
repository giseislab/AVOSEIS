use Avoseis::SwarmAlarm qw(runCommand getPf);
use Datascope;
use Getopt::Std;

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

# Usage - command line options and arguments
our ($opt_p, $opt_v);
if ( ! &getopts('p:v') || $#ARGV > -1  ) {
    print STDERR <<"EOU" ;

    Usage: $PROG_NAME [-p pffile]

    For more information:
        > man $PROG_NAME
EOU
    exit 1 ;
}

# End of  GT Antelope Perl header
#################################################################

$RUN = 1;

my ($TSTART, $TWIN, $refdb, $volcano, $stachansref) = &getParams($PROG_NAME, $opt_p, $opt_v);
print "refdb = $refdb\n";
die("No parameter file\n") if ($opt_p eq "");

$TEND = $TSTART + $TWIN * 60;
@filters = ("BW 0.5 4 15.0 4", "BW 0.5 4 3.0 4", "BW 0.8 4 10.0 4", "BW 1.5 4 12.0 4", "BW 3.0 4 18.0 4");
$dataset_index = 0;

foreach $sta_twin (0.5, 0.8, 1.4, 2.3) {
    $sta_tmin = $sta_twin * 2/3;
    $sta_maxtgap = $sta_twin * 0.5;
    
    foreach $lta_twin ($sta_twin*5, $sta_twin*10) {
        $lta_tmin = $lta_twin * 2/3;
        $lta_maxtgap = $lta_twin * 0.5;

	foreach $thresh (2.4, 3.0, 4.2) {
		foreach $threshoff ($thresh*0.5, $thresh*2/3) {
			foreach $nodet_twin (0.5, 1.2, 2.7) {
				foreach $det_tmin (2.0, 4.0) {
					foreach $det_tmax (8.0, 16.0) {
						foreach $goodvalue_min (0.0, 100.0) {
        						$dataset_index++;
        						$fstr = sprintf("%s_%d",$volcano,$dataset_index);
        						$pffile = "dbdetect_$fstr";
        						$newdb = "detect/trialdb/$fstr";
							print "Writing params to pf/$pffile.pf\n";
        						open(FOUT, ">pf/$pffile.pf");
        						print FOUT<<EOF;
# 
TEND	$TEND
TSTART	$TSTART

# Constants
ave_type        rms
nodet_twin     	$nodet_twin 
pamp            500.0
thresh         $thresh 
threshoff      $threshoff 
det_tmin       $det_tmin
det_tmax       $det_tmax 
h               0
iphase          D
process_twin    60.0
latency         3
maxfuturetime   600.0
otime_noise_tfac 1.0
goodvalue_min   $goodvalue_min       
goodvalue_max   0

# Variables
sta_twin        $sta_twin
sta_tmin        $sta_tmin
sta_maxtgap     $sta_maxtgap
lta_twin        $lta_twin
lta_tmin        $lta_tmin
lta_maxtgap     $lta_maxtgap
filter          none

bands   &Tbl{
EOF
							foreach $filter (@filters) {
								print FOUT<<FEOF;
        &Arr{
                filter          $filter
        }
FEOF
							}

							# Now print out the stachans
							@stachans = @$stachansref;
							print FOUT "}\nstachans &Tbl{\n";
							foreach $stachan (@stachans) {
								print FOUT "$stachan\n";
							}
							print FOUT "}\n";
							print FOUT "reject &Tbl{\n}\n";
							close(FOUT);
        						runCommand("cp $refdb $newdb",$RUN);
							unless (-e "$newdb.detection") {
        							runCommand("dbdetect -pf $pffile -tstart $TSTART -twin $TWIN $refdb $newdb",$RUN);
							}
        						runCommand("~/src/GTResearchTools/bin/makelastid $newdb",$RUN);
						} # goodvalue_min
					} # det_tmax
				} # det_tmin
			} # nodet_tmin
		} # threshoff
		} # thresh
	} # lta_twin
} #sta_twin
###############################################################################
sub getParams {

        my ($PROG_NAME, $opt_p, $opt_v) = @_;
        my $pfobjectref = &getPf($PROG_NAME, $opt_p, $opt_v);


        my ($TSTART, $TWIN, $refdb, $volcano, $stachansref);

        # Generic parameters
        $TSTART             = $pfobjectref->{'TSTART'};
        $TWIN               = $pfobjectref->{'TWIN'};
	$refdb              = $pfobjectref->{'refdb'};
        $volcano            = $pfobjectref->{'volcano'};

        # Now read any subnet specific overrides
        $stachansref        = $pfobjectref->{'stachans'};
 
        return ($TSTART, $TWIN, $refdb, $volcano, $stachansref);
}

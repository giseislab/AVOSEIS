
#
# db2pick
# 
# Convert a css3.0 catalog of hypocenters to CNSS Unified Single Line Catalog Format
#
# Kent Lindquist
# Geophysical Institute
# University of Alaska
# December, 1996

# Edited: Summer 2007, 2008
# by Anna Bulanova
#

use Datascope;
use Getopt::Long qw(:config bundling);
use File::Path;




if( $#ARGV != 1 ) {
	die( "Usage: $0 dbname outpath\n" );
} else {
	$dbname = $ARGV[0];
	$outpath = $ARGV[1];
}

# open  and join database tables
@db = dbopen( $dbname, "r" );

if( ! -f "$dbname.origin" ) {
	die( "No origin table present in $dbname\n" );
}

# origins
if( -f "$dbname.event" ) {
	@dbor = dblookup( @db, "", "origin", "", "" );
	@dbevent = dblookup( @db, "", "event", "", "" );         
	@dbor = dbjoin( @dbor, @dbevent );
	@dbor = dbsubset( @dbor, "orid == prefor" );
	dbfree(@dbevent);
} else	{
	@dbor= dblookup( @dbor, "", "origin", "", "" );
}
$dbor_size = dbquery( @dbor, "dbRECORD_COUNT" );

# magnitudes (origin x netmag)
$Mags=0;
if( -f "$dbname.netmag" ) {
	@dbnetmag = dblookup( @db, "", "netmag", "", "" );         
	@dbnetmag = dbjoin( @dbor, @dbnetmag );
	@dbnetmag = dbsort( @dbnetmag, "orid" );
$dbnetmag_size = dbquery( @dbnetmag, "dbRECORD_COUNT" );
	$Mags=1;
}

# origerr
if( -f "$dbname.origerr" ) {
	@dborigerr = dblookup( @db, "", "origerr", "", "" );
	$nrecords = dbquery( @dborigerr, "dbRECORD_COUNT" );
	for( $dborigerr[3] = 0; $dborigerr[3] < $nrecords; $dborigerr[3]++ ) {
		($orid, $sdobs, $smajax, $sdepth, $stime, $strike, $sminax ) = dbgetv( @dborigerr,
		"orid", "sdobs", "smajax", "sdepth", "stime" , "strike", "sminax");
		$Origerr{$orid}++;
		$Sdobs{$orid} = $sdobs;
		$Smajax{$orid} = $smajax;
		$Sdepth{$orid} = $sdepth;
		$Stime{$orid} = $stime;
		$Strike{$orid} = $strike;
		$Sminax{$orid} = $sminax;
	}
	dbfree(@dborigerr);

}

#arrivals
# origin x assoc x arrival
#if( $Arrivals && (-f "$dbname.arrival") &&  (-f "$dbname.assoc") ) {
#	@dbassoc1 = dblookup( @db, "", "assoc", "", "" );
#	@dbassoc2 = dbsubset( @dbassoc1, "phase!='amp'" );
#	@dbassoc = dbjoin(@dbor, @dbassoc2);
#	@dbarr1 = dblookup( @db, "", "arrival", "", "" );
#	@dbarr = dbjoin(@dbassoc, @dbarr1);
#	@dbarr = dbsort(@dbarr, "orid");
#	$dbarr_size = dbquery( @dbarr, "dbRECORD_COUNT" );
#} else {
	# if some tables are missing, do not print picks
#	$Arrivals = 0;
#}

$nrecords = dbquery( @dbor, "dbRECORD_COUNT" );

if( $nrecords == 0 ) {
	die( "No applicable records in $dbname\n" );
}

#open( F, ">$outfile" );
# create outpath if it doesn't exist


# number of the current element in the list of arrivals
$picknum=0;
# number of the current element in the list of magnitudes
$filenum=0;
# read the origin table
for( $dbor[3] = 0; $dbor[3] < $nrecords; $dbor[3]++ ) {
	# read one record
	($orid, $lat, $lon, $time, $depth, $ndef, $ml, $mb, $ms, $lddate, $etype) =dbgetv( @dbor, 
	"orid", "lat", "lon", "time", "depth", "ndef", "ml", "mb", "ms", "lddate",  "etype");
	# translate and print the origin fields
	translate_fields();

	$fn = epoch_to_file_name($time);
	mkpath( "$outpath/$curr_folder" );

	if ($fn eq $old_fn) {
		$filenum = $filenum+1;
	} else {
		$filenum = 0;
	}
	$old_fn = $fn;
	$outfile = sprintf("%s/%s_%03d", $outpath, $fn, $filenum);

	open( F, ">$outfile" );
	print_summary();
	close( F );

	# read and print picks
	#get_and_print_data();
}
dbclose(@db);

sub get_and_print_data {
# read and print magnitudes and arrivals
			if ($Mags){
				get_mag_fields();
				translate_mag_fields();
				print_mag_fields();		
			}
			if ($Arrivals){
				get_picks();
				translate_picks();
				print_picks();
			}
}

sub get_picks {
# reads several picks  from  (origin x assoc x arrival) 
# if orid in the record is equal to $orid, put the data into @picks array
# if orid in the record < $orid, try the next record ($picknum++)
# if orid in the record > $orid, exit the procedure
	@picks = ();
	do{
		$dbarr[3] = $picknum;
		($porid,$ptime, $psta, $ptype, $pchan, $pqual, $pfm, $pwgt) = dbgetv( @dbarr, 
		"origin.orid", "arrival.time", "arrival.sta", "arrival.iphase", 
		"arrival.chan", "arrival.qual", "arrival.fm", "assoc.wgt"
		);
		if($orid==$porid){
			push(@picks,[$ptime, $psta, $ptype, $pchan, $pqual, $pfm, $pwgt]);
			$picknum++;
		}
		if($orid>$porid){
			$picknum++;
		}
	}while($orid >= $porid && $picknum<$dbarr_size);
}

sub translate_picks {
# takes data form @picks,
# fills @pick_picks with translations of the fields
	@pick_picks=();
	my $j;
	for( $j = 0; $j<scalar(@picks) ; $j++) {
		@tmp=@{$picks[$j]};
		($ptime, $psta, $ptype, $pchan, $pqual, $pfm, $pwgt) =@tmp;
		$pick_ptime=epoch_to_pick_timestr( $ptime ); #
		$pick_psta = sprintf( "%-5.5s", $psta );
		$pick_ptype = sprintf( "%-8.8s", $ptype );
		$pick_pchan = sprintf( "%-3.3s", $pchan );
		if($pqual eq "-"){$pick_pqual=" "; 
			}else{
				$pick_pqual = sprintf( "%1.1s", $pqual );
				$pick_pqual = uc($pick_pqual);
			}
		if($pfm eq "-"){$pick_pfm=" ";
			}else{
				$pick_pfm = sprintf( "%1.1s", $pfm );
				if ($pick_pfm eq "c") {$pick_pfm = "u";}
			}
		$pick_pnetcode = sprintf( "%-2.2s", $Source );
		$pick_psrccode = sprintf( "%-3.3s", $Source );
		$pick_pinstr = "   ";
		if ($pwgt==.25) {$pick_pwgt = 3;}
			elsif($pwgt== .5) {$pick_pwgt = 2;}
			elsif ($pwgt==.75) {$pick_pwgt = 1;}
			elsif ($pwgt== 1) {$pick_pwgt = 0;}
			else {$pick_pwgt = 4;}
		
		push ( @pick_picks, [$pick_ptime,$pick_psta,$pick_pnetcode,$pick_ptype,
			$pick_psrccode, $pick_pinstr, $pick_pchan,
			$pick_pqual,$pick_pfm,$pick_pwgt ] );
	}

}

sub print_picks {
# prints translated data stored in @pick_picks
	my $j; my $i;
	for( $j = 0; $j<scalar(@pick_picks) ; $j++) {
			@pick_data =  @{$pick_picks[$j]};
 			print F '$pic';
		for($i=0; $i<scalar(@pick_data); $i++){
 			print F $pick_data[$i];
		}
 		print F "\n";
	}
}

sub get_mag_fields {
# reads several magnitudes  from  (origin x netmag) 
# if orid in the record is equal to $orid, put the data into magnitude  arrays
# if orid in the record < $orid, try the next record ($magnum++)
# if orid in the record > $orid, exit the procedure
	@mags = ();
	@mag_types = ();
	@mag_sources = ();
	do{
		$dbnetmag[3] = $magnum;
		($morid,$magtype, $magnitude, $auth) = dbgetv( @dbnetmag, 
		"origin.orid", "magtype", "magnitude", "netmag.auth" 
		);
		if($orid==$morid){
			push(@mags, $magnitude);
			push(@mag_types, $magtype);
			push(@mag_sources, $auth);
			$magnum++;
		}
		if($orid>$morid){
			$magnum++;
		}
	}while($orid >= $morid && $magnum<$dbnetmag_size);
}

sub find_pref_mag {
# gets information from @mags, @mag_types, @mag_sources
# fills out @pick_mags, @pick_magtypes, @pick_magsources

	# list with orders of preference of magnitudes
	@mags_order = ("mw Hrvd", "mw AEIC", "mb Hrvd", "mb PDE", "ml aeic_dbml", "ms Hrvd", "ms PDE");
	local $j;
	local $k;
	$pref_mag=-1;
	# find the preferred magnitude
	for ($j=0; $j<scalar(@mags_order); $j++){
		for ($k = 0; $k < scalar(@mags); $k++){
			if ($mag_types[$k]." ".$mag_sources[$k] eq $mags_order[$j]){
				$pref_mag=$k;  # preferred magnitude
				last;
			}
		}
		if($pref_mag!=-1){last;}
	}
	# prepare lists with magnitude information
	@pick_mags=();
	@pick_magtypes=();
	@pick_magsources=();
	for ($j=0; $j<scalar(@mags); $j++){
		push( @pick_mags, sprintf( "%5.2f", $mags[$j] ) );
		push( @pick_magtypes, substr($mag_types[$j],1,1)." " );
		if ($mag_sources[$j] eq "PDE"){
			$pick_magsource = "GO"; # Source of magnitude information 
		}
		elsif($mag_sources[$j] eq "Hrvd"){
			$pick_magsource = "HVD"; # Source of magnitude information
		}
		else { 
			$pick_magsource =$Source; # Source of magnitude information
		}
		push(@pick_magsources, $pick_magsource);
	}
}


sub translate_fields {
# translates the data read from the origin table 
# results are stored in numerous global variables pick_*
	$pick_timestr = epoch_to_pick_timestr( $time ); #
	$pick_lat = ( $lat == -999. ) ? "       " : (($lat<0)? 
		sprintf( "%2dS%4.0f", int(-$lat),  (int($lat)-$lat)*6000) : sprintf( "%2dN%4.0f", int($lat),  ($lat-int($lat))*6000)); #
	$pick_lon = ( $lon == -999. ) ? "        " : (($lon<0)? 
		sprintf( "%3dW%4.0f", int(-$lon),  int($lon)*6000-$lon*6000) : sprintf( "%3dE%4.0f", int($lon),  ($lon-int($lon))*6000)); #
	$pick_depth = ( $depth == -999. ) ? "     " :( ($depth<0)?"  -00" :
					 sprintf( "%5.0f", $depth*100 )); #
	$pick_extra_depth = ( $depth == -999. ) ? "     " :sprintf( "%5.0f",$depth*100 );#
	$|=1;
	#print $depth," ", $depth*100, " ", $pick_extra_depth,"\n";
	

	$pick_pref_mag = ($ml == -999.) ? "  ": sprintf("%2.0f",$ml*10); #
	$pick_xmag = ($ml == -999.) ? "  ": sprintf("%2.0f", $ml*10); #
	$pick_fmag = "  "; #
	$pick_npha = ( $ndef == -1 ) ? "    " : sprintf( "%3.0f", $ndef );
#origerrs
	if( $Origerr{$orid} ) {
		$pick_rms = ( $Sdobs{$orid} == -1. ) ? "    " : sprintf( "%4.0f", $Sdobs{$orid}*100 );#
		$pick_azim1 = ( $Strike{$orid} == -1. ) ? "   " : sprintf( "%3.0f", $Strike{$orid} ); #
		$pick_dip1 = ( $Sdepth{$orid} == -1. ) ? "  " :" 0";#
		$pick_stder1 = ( $Smajax{$orid} == -1. ) ? "    " :
						sprintf( "%4.0f", $Smajax{$orid}*100/.8095 );
		$pick_azim2 = ( $Strike{$orid} == -1. ) ? "   " : sprintf( "%3.0f", $Strike{$orid}+90 ); #
		$pick_dip2 = ( $Sdepth{$orid} == -1. ) ? "  " :" 0";#
		$pick_stder2 = ( $Sminax{$orid} == -1. ) ? "    " :
						sprintf( "%4.0f", $Sminax{$orid}*100/.8095 );
		$pick_stder = ( $Sdepth{$orid} == -1. ) ? "    " :
						sprintf( "%4.0f", $Sdepth{$orid}*100/.5338 );
	} else {
		$pick_rms = "    ";
		$pick_azim1 = "   ";
		$pick_dip1 = "  ";
		$pick_stder1 = "    ";
		$pick_azim2 = "   ";
		$pick_dip2 = "  ";
		$pick_stder2 = "    ";
		$pick_stder = "    ";
	}
	$pick_magtyp = "X";
	$pick_slash="/";
	$pick_t=sprintf("%-1.1s", $etype);
	if ($dtype=="f"){ $pick_f="0";}
		elsif ($dtype == "g") {$pick_f="1";}
		else {$pick_f=" ";}
}



sub print_summary {
# print translated origin fields
	
	print F $pick_timestr;
	print F $pick_lat;
	print F $pick_lon;
	print F $pick_depth;
	print F $pick_pref_mag;
	print F $pick_npha;
	print F "      ";
	print F $pick_rms;
	print F $pick_azim1;
	print F $pick_dip1;
	print F $pick_stder1;
	print F $pick_azim2;
	print F $pick_dip2;
	print F $pick_stder2;
	print F $pick_xmag;
	print F $pick_fmag;
	print F " ";
	print F $pick_stder;
	print F " ";
	print F $pick_magtyp;
	print F "  ";
	print F $pick_slash;
	print F "        ";
	print F $pick_t;
	print F $pick_f;
	print F "                   ";
	print F $pick_extra_depth;
	print F "\n";
}


sub epoch_to_pick_date {
	my( $epoch ) = pop( @_ );

	my( $temp, $mo, $dy, $yr );

	$temp = strdate( $epoch );
	$temp =~ tr@(\s+|/)@ @;
	$temp =~ s@^\s+@@;

	($mo, $dy, $yr) = split( /\s+/, $temp );

	return sprintf( "%4d%02d%02d", $yr, $mo, $dy );
}
sub epoch_to_file_name {
	my( $epoch ) = pop( @_ );

	my( $temp, $mo, $dy, $yr, $hr, $min, $sec );

	$temp = strtime( $epoch );
	$temp =~ tr@(\s+|/|:)@ @;
	$temp =~ s@^\s+@@;

	($mo, $dy, $yr, $hr, $min, $sec) = split( /\s+/, $temp );
	$curr_folder = sprintf( "%4d/%4d_%02d", $yr, $yr, $mo);
	return sprintf( "%4d/%4d_%02d/%4d%02d%02d_%02d%02d%02d", $yr, $yr, $mo,$yr,$mo, $dy,$hr, $min, $sec );
}

sub epoch_to_pick_timestr {
	my( $epoch ) = pop( @_ );

	my( $temp, $mo, $dy, $yr, $hr, $min, $sec );

	$temp = strtime( $epoch );
	$temp =~ tr@(\s+|/|:)@ @;
	$temp =~ s@^\s+@@;

	($mo, $dy, $yr, $hr, $min, $sec) = split( /\s+/, $temp );
	
	return sprintf( "%4d%02d%02d%02d%02d%04d", $yr, $mo, $dy, $hr, $min, $sec*100 );
}

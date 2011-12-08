use Datascope;
use Getopt::Std;
use Env;
use File::Copy;

$public = $ENV{'PUBLICWEBPRODUCTS'};
$histfig 	= "$public/images/AVO_recentEQ_histogram";
$internal = $ENV{'INTERNALWEBPRODUCTS'};
$dbname 	= "$internal/AVOEQ/db_AVO_recentEQ";
$AVOEQ = $internal."/AVOEQ";
chdir($AVOEQ);
&getopt('pd');          # had to remove error checking, but shouldn't have - MEW
$result = `which psxy`;
die("GMT does not appear to be installed\n") if ($result=~/Command not found/ || $result=="\n");
if ( $#ARGV>-1 ) {
        die($Usage);
} else {
        # Checks if the user wants to specify a custom database.
        if ($opt_d) {
                $dbname = $opt_d;
        }
        # If not, use the default location
        else {
                $dbname = "$AVOEQ/db_AVO_recentEQ";
        }
        # Checks if the user wants to specify a custom parameter file
        if ($opt_p) {
                $param_file = $opt_p;
        }
        # If not, uses the default parameter file in the pf directory
        else {
                $param_file = "/home/iceweb/run/pf/avo_volcs.pf";
        }
print "    database:       $dbname\n";
print "    parameter file: $param_file\n";
}

# Open temporary data file read/write for use with GMT script
open(TEMPOUT, ">temp.dat");



# Open and join the database origin, event, and netmag tables, and sort event by time
@db = dbopen($dbname,'r');
@db = dblookup(@db,"","origin","",1);
@db2 = dblookup(@db,"","event","",1);
@db3 = dblookup(@db,"","netmag","",1);
@db  = dbjoin(@db,@db2);
@db  = dbsubset(@db,'orid==prefor');
@db  = dbjoin(@db,@db3);
@db = dbsort(@db,'-r','time');
$nrecords = dbquery(@db,"dbRECORD_COUNT");

# Checks that the database opened properly
if ($nrecords == 0) {
	die ("database does not exist or origin table contains no records");
}


# Get time of last earthquake
@db_end = @db;
@db_end[3] = 0;
$lastorigintime = dbgetv(@db_end,'time');
$lastorigintime = epoch2str($lastorigintime,'%m/%d/%Y');
open(TEMP2OUT, ">temp2.dat");
	print TEMP2OUT "$lastorigintime\n";
close(TEMP2OUT);



# Opens the required parameter file containing volcano information.  To associate 
# an earthquake with a volcano, the program requires a rectangular area around
# the volcano defined by minimum and maximum latitude and longitude coordinates.  
# Currently, the given ranges roughly match with the seismicity maps produced by
# Scott Stihler on the AVO internal webpage
# Parameter file format:
# Volcano_Name Latitude Longitude Min_Latitude Max_Latitude Min_Longitude Max_Longitude
open(VOLCANOES, $param_file) || die ("Error: Could not open parameter file");
@volcano_location=<VOLCANOES>;
close(VOLCANOES);

# Parses the parameter file
foreach $volcano (@volcano_location)
{
	chop($volcano);
	($volc_name1,$volc_lat1,$volc_lon1,$min_lat1,$max_lat1,$min_lon1,$max_lon1)=split(/\s/,$volcano);
	push(@volc_name,$volc_name1);
	push(@volc_lat,$volc_lat1);
	push(@volc_lon,$volc_lon1);
	push(@min_lat,$min_lat1);
	push(@max_lat,$max_lat1);
	push(@min_lon,$min_lon1);
	push(@max_lon,$max_lon1);
}

# Reads in the current system time in epoch format
$current_time = time;

# Initializes counter variables
@firstweek=0;
@secondweek=0;
@thirdweek=0;
@fourthweek=0;

# Fills counter variables with zeroes
for ($i=0 ; $i<scalar @volc_name-1 ; $i++) {
	push(@firstweek,0);
	push(@secondweek,0);
	push(@thirdweek,0);
	push(@fourthweek,0);
}

# Loops through the database origins, extracting latitude, longitude, depth, and
# origin time (in epoch format)
DB:for ($db[3]=0 ; $db[3]<$nrecords ; $db[3]++) {
	($lon,$lat,$depth,$time) = dbgetv(@db,"lon","lat","depth","time");
	
	# Loops through the volcanoes from the parameter file
	for ($i=0 ; $i<scalar @volc_name ; $i++){
		
		# Checks if the earthquake occurred within the last 7 days.
		if ($time>$current_time-604800) {
			
			# Checks if the earthquake occurred within the area defined in the parameter file.
			# If it did, increments the earthquake count at the volcano by 1.
			if ($lat>=$min_lat[$i] && $lat<=$max_lat[$i] && $lon>=$min_lon[$i] && $lon<=$max_lon[$i]){
				# Sets the maximum value for number of earthquakes per week at a volcano at 35
				if ($firstweek[$i]>=35) {
					next DB;
				}
				else {
					$count=$firstweek[$i];
					splice(@firstweek,$i,1,$count+1);
					next DB;
				}
			}
		}
		
		# Checks if the earthquake occurred between 7 and 14 days ago.
		elsif ($time>$current_time-1209600 && $time<=$current_time-604800){
			
			# Checks if the earthquake occurred within the area defined in the parameter file.
			# If it did, increments the earthquake count at the volcano by 1.
			if ($lat>=$min_lat[$i] && $lat<=$max_lat[$i] && $lon>=$min_lon[$i] && $lon<=$max_lon[$i]){
				# Sets the maximum value for number of earthquakes per week at a volcano at 35
				if ($secondweek[$i]>=35) {
					next DB;
				}
				else {
					$count=$secondweek[$i];
					splice(@secondweek,$i,1,$count+1);
					next DB;
				}
			}
		}
		
		# Checks if the earthquake occurred between 14 and 21 days ago.
		elsif ($time>$current_time-1814400 && $time<=$current_time-1209600){
			
			# Checks if the earthquake occurred within the area defined in the parameter file.
			# If it did, increments the earthquake count at the volcano by 1.
			if ($lat>=$min_lat[$i] && $lat<=$max_lat[$i] && $lon>=$min_lon[$i] && $lon<=$max_lon[$i]){
				# Sets the maximum value for number of earthquakes per week at a volcano at 35
				if ($thirdweek[$i]>=35) {
					next DB;
				}
				else {
					$count=$thirdweek[$i];
					splice(@thirdweek,$i,1,$count+1);
					next DB;
				}
			}
		}
		
		# Checks if the earthquake occurred between 21 and 28 days ago.
		elsif ($time>$current_time-2419200 && $time<=$current_time-1814400){
			
			# Checks if the earthquake occurred within the area defined in the parameter file.
			# If it did, increments the earthquake count at the volcano by 1.
			if ($lat>=$min_lat[$i] && $lat<=$max_lat[$i] && $lon>=$min_lon[$i] && $lon<=$max_lon[$i]){
				# Sets the maximum value for number of earthquakes per week at a volcano at 35
				if ($fourthweek[$i]>=35) {
					next DB;
				}
				else {
					$count=$fourthweek[$i];
					splice(@fourthweek,$i,1,$count+1);
					next DB;
				}
			}
		}
	}
}

# Close the database
dbclose(@db);

# Outputs to file temp.dat the line number, volcano name, # of earthquake during the first week, # during second week, 
# # during third week, # during fourth week.
for ($i=0 ; $i<scalar @volc_name ; $i++){
	printf TEMPOUT "%d %s %d %d %d %d %d %d %d %d\n",$i+1,$volc_name[$i],1,$firstweek[$i],2,$secondweek[$i],3,$thirdweek[$i],4,$fourthweek[$i];
}

# Close the output file for reading/writing
close(TEMPOUT);

$command = "avo_hist_gmt";
print "$command\n";
system($command);
$command = "ps2pdf AVO_recent_EQ_hist.ps";
print "$command\n";
system($command);
#$command = "convert AVO_recent_EQ_hist.pdf -rotate "+90<" AVO_recent_EQ_hist.png";
$command = "convert AVO_recent_EQ_hist.pdf AVO_recent_EQ_hist.png";
print "$command\n";
system($command);
copy('AVO_recent_EQ_hist.pdf',"$histfig.pdf");
copy('AVO_recent_EQ_hist.png',"$histfig.png");

# Removes temporary data file
system("rm -f ./temp.dat");





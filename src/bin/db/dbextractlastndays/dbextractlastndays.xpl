use Datascope ;
use File::Copy;

sub descriptor {
	open(OUT,">$outdb");
	print OUT "\#\n";
	print OUT "schema css3.0\n";
	print OUT "dblocks\n";
	print OUT "dbidserver\n";
	print OUT "dbpath\n";
	close(OUT);
}

if ($#ARGV!=2) {
	die("Usage: $0 DAYS INDB OUTDB\nExtract the last DAYS days from INDB and write output to OUTDB\n");
}
$days = $ARGV[0];
$indb = $ARGV[1];
$outdb = $ARGV[2];

# REMOVE OLD DB
@files = glob("$outdb*");
foreach $file (@files) {
	unlink($file);
}

# GET LAST X DAYS OF LOCATED EVENTS
$sepoch = now()-(86400 * $days);
$sepochstr = epoch2str($sepoch,'%D');
$eepoch = now();	
$eepochstr = epoch2str($eepoch,'%D');
print "$sepoch $eepoch\n";

# MAKE DB
$command = "extractavodb -af -i $indb $sepochstr $eepochstr $outdb";
print "\n$command\n";
system($command);
&descriptor;





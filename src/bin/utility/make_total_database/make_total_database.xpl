use File::Basename;
use Env;
my $monthlydb = $ENV{'MONTHLYDB'};
my $totaldb = $ENV{'TOTALDB'};
my $totaldir = dirname $totaldb;
mkdir $totaldir unless(-d $totaldir);
my $totalbase = basename $totaldb;
my $tempdir = "tmp_dbt_total_avo";
mkdir $tempdir unless(-d $tempdir);
my $tempdb = "$tempdir/$totalbase";
print "monthlydb=$monthlydb\ntotaldb=$totaldb\ntotaldir=$totaldir\ntotalbase=$totalbase\n";
print "tempdir=$tempdir\ntempdb=$tempdb\n";
foreach my $table  qw(origin origerr event netmag stamag assoc arrival remark) {
	print "Concatenating all $table tables\n";
	print "cat $monthlydb/????/db????_??.$table > $tempdb.$table\n";
	system("cat $monthlydb/????/db????_??.$table > $tempdb.$table");
};
print "Moving new total tables to $totaldir\n";
print "mv $tempdir/* $totaldir/\n";
system("mv $tempdir/* $totaldir/"); 
rmdir $tempdir;



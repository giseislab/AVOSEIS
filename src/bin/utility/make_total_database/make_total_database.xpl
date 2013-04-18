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
foreach my $table  qw(origin origerr event netmag stamag assoc arrival remark) {
	print "Concatenating all $table tables\n";
	system("cat $monthlydb/????/db????_??.$table > $tempdb.$total");
};
print "Moving new total tables to $totaldir\n";
system("mv $tempdir/* $totaldir/"); 
rmdir $tempdir;



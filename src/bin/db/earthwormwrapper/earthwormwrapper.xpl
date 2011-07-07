@carlsublogs = glob("logs_earthworm/carlsubtrig85.log*");
#@carlstalogs = glob("logs_earthworm/carlstatrig*");
use Env;
foreach $log (@carlsublogs) {
	print "$ENV{\"AVOSEIS\"}/bin/carlsubtrig2antelope dbquakes_ew/dbew $log\n";
	system("$ENV{\"AVOSEIS\"}/bin/carlsubtrig2antelope dbquakes_ew/dbew $log");
}

foreach $log (@carlstalogs) {
	system("$ENV{\"AVOSEIS\"}/bin/carlstatrig2antelope -w logs_earthworm/warning.log dbquakes_ew/dbew $log");
}



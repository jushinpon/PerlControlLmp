=b
1. only use one "timestep" keyword in your lmp script
2. mkdir by perl, but not by lmp script
3. You may terminate your job after several folders have been done, 
and then use a larger timestep for this Perl rerun
=cut

use strict;
use warnings;
use POSIX;
use Cwd;
my @restrainK;
#log()/log(5);
my $time = 0.5/1e-5;
my $power = int(log($time)/log(1.5));

$restrainK[0] = 1e-5;
for (1..$power){
	$restrainK[$_] = $restrainK[$_ - 1] * 1.5;
	#print "$_: $restrainK[$_]\n";
}
$restrainK[$power + 1] = 0.5; #final value

my $loopSegment = 3;#int(999/($power*4));
#print "power: $power, loopSegment: $loopSegment\n";
#sleep(100);
#  = (1e-5,5e-5,1e-4,1e-3,1e-2,1e-1,5e-1);

#my@$finalK = 0.(1e-6,1e-5,1e-4,1e-3,1e-2,5e-2,5e-1)nc = ($finalK - $initialK)/999.;

my $lmpfile = "secondary_NVT.lmp";
my $pwd = getcwd();
my $lmpStartLoop = 0;
# do the initial folder check if rerun:
my @oldFolder = `ls -t|sed -rn '/secondary[0-9]{3}/p'`;#r for re extention
print "listed folders: @oldFolder\n";

for my $folder (@oldFolder){
	chomp $folder;
    my @ls = `ls -t $pwd/$folder/`;
	print "ls[0]: $ls[0]\n";
	chomp $ls[0];
	if($ls[0]){
		$folder =~ /(\d+)/;
		print "\$folder: $folder\n";
		print "\$1: $1\n";
		$lmpStartLoop = $1 + 1;
		print "\$lmpStartLoop: $lmpStartLoop\n";
		# sleep(100);
		`sed -i 's:^read_data.*:read_data $pwd/$folder/$ls[0]:' $pwd/$lmpfile`;		
		last;	
	}
    else{
		`rm -rf $pwd/$folder`;
	}
}
# sleep(100);
if(! -e "$pwd/secondary"){# no this folder
	 system("mkdir secondary");	
 }
else{#if we have an old one
	 system("rm -rf secondary");
	 system("mkdir secondary");	# make tis for lmp script
}

`echo "starting for rerun loop counting" > loop.txt`;
for my $loop ($lmpStartLoop..999){
	`echo "*****Restart job for $loop times" >>loop.txt`;
	#print "*****Restart job for $loop times\n";
	my $rand = ceil(1234567 * rand());
	chomp $rand;
	`sed -i 's:variable seed.*:variable seed equal $rand:' $pwd/$lmpfile`;
	my $restrainK;
	my $restrainKID = int($loop/$loopSegment);
	if ($restrainKID > ($power + 1) ){$restrainKID = $power + 1;}
    $restrainK =  $restrainK[$restrainKID];
	`echo "Current Random number seed: $rand" >>loop.txt`;
	`echo "Current restrainK: $restrainK" >>loop.txt`;

	`sed -ir 's:fix restrain_\$\{restrainloop\}.*:fix restrain_\$\{restrainloop\} all restrain bond \$\{start\} \$\{end\} $restrainK $restrainK \$\{R0\}:' $pwd/$lmpfile`;
	
	system ("/opt/mpich-3.3.2/bin/mpiexec -np 24 /opt/lammps/lmp_mpiGCC_20200922 -in secondary_NVT.lmp");
	sleep(1);
	my $ID = sprintf("%03d",$loop);
	system("rm -rf secondary$ID");# remove old folder first
	system("mv secondary secondary$ID");
	sleep(1);	
	my @ls = ` ls -t $pwd/secondary$ID/`;
	chomp $ls[0];
	#print "****path: ls -t $pwd/secondary$ID/\n";
	#print "**ls[0]: $ls[0]\n";
	#print "pwd: $pwd\n";
	if (!$ls[0]){ #no output file in this folder,redo for smaller timestep
		#die "no output data file for the next run\n";
		my $timestep = `grep "^timestep" ./$lmpfile| sed 's/timestep *//'`;
		chomp $timestep;
		print "original timestep: $timestep for loop $loop\n";
		`echo "original timestep: $timestep for loop $loop" >>loop.txt`;
		$timestep = $timestep * 0.9;
		print "adjusted timestep: $timestep\n";
		`echo "adjusted timestep: $timestep for loop $loop" >>loop.txt`;
		`sed -i 's:^timestep.*:timestep $timestep:' $pwd/$lmpfile`;
		my $prevLoop = sprintf("%03d",$loop - 1);# previous loop id
		my @ls = ` ls -t $pwd/secondary$prevLoop/`;
		chomp $ls[0];
		#print "****path: ls -t $pwd/secondary$prevLoop/\n";
		#print "**ls[0]: $ls[0]\n";
		`sed -i 's:^read_data.*:read_data $pwd/secondary$prevLoop/$ls[0]:' $pwd/$lmpfile`;		
	     system("mkdir secondary");	# make this for lmp script.
		redo; # redo this loop from the beginning!
	}
	else{# output file exists. do the next run
		`sed -i 's:^read_data.*:read_data $pwd/secondary$ID/$ls[0]:' $pwd/$lmpfile`;		
	     system("mkdir secondary");	# make tis for lmp script.
	}
}
print "all done";


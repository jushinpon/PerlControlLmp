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

my $lmpfile = "secondary_NVT_Anneal.lmp";
my $pwd = getcwd();
my $lmpStartLoop = 0;
# do the initial folder check if rerun:
my @oldFolder = `ls -t|sed -rn '/anneal[0-9]{3}/p'`;#r for re extention
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
if(! -e "$pwd/anneal"){# no this folder
	 system("mkdir anneal");	
 }
else{#if we have an old one
	 system("rm -rf anneal");
	 system("mkdir anneal");	# make tis for lmp script
}

`echo "starting for rerun anneal_loop counting" > anneal_loop.txt`;
for my $loop ($lmpStartLoop..100){
	`echo "*****Restart job for $loop times" >>anneal_loop.txt`;
	#print "*****Restart job for $loop times\n";
	my $rand = ceil(1234567 * rand());
	chomp $rand;
	`sed -i 's:variable seed.*:variable seed equal $rand:' $pwd/$lmpfile`;
	`echo "Current Random number seed: $rand" >>anneal_loop.txt`;
	
	system ("/opt/mpich-3.3.2/bin/mpiexec -np 8 /opt/lammps/lmp_mpiGCC_20200922 -in secondary_NVT_Anneal.lmp");
	sleep(1);
	my $ID = sprintf("%03d",$loop);
	system("rm -rf anneal$ID");# remove old folder first
	system("mv anneal anneal$ID");
	sleep(1);	
	my @ls = ` ls -t $pwd/anneal$ID/`;
	chomp $ls[0];
	#print "****path: ls -t $pwd/secondary$ID/\n";
	#print "**ls[0]: $ls[0]\n";
	#print "pwd: $pwd\n";
	if (!$ls[0]){ #no output file in this folder,redo for smaller timestep
		#die "no output data file for the next run\n";
		my $timestep = `grep "^timestep" ./$lmpfile| sed 's/timestep *//'`;
		chomp $timestep;
		print "original timestep: $timestep for loop $loop\n";
		`echo "original timestep: $timestep for loop $loop" >>anneal_loop.txt`;
		$timestep = $timestep * 0.9;
		print "adjusted timestep: $timestep\n";
		`echo "adjusted timestep: $timestep for loop $loop" >>anneal_loop.txt`;
		`sed -i 's:^timestep.*:timestep $timestep:' $pwd/$lmpfile`;
		my $prevLoop = sprintf("%03d",$loop - 1);# previous loop id
		my @ls = ` ls -t $pwd/anneal$prevLoop/`;
		chomp $ls[0];
		#print "****path: ls -t $pwd/secondary$prevLoop/\n";
		#print "**ls[0]: $ls[0]\n";
		`sed -i 's:^read_data.*:read_data $pwd/anneal$prevLoop/$ls[0]:' $pwd/$lmpfile`;		
	     system("mkdir anneal");	# make this for lmp script.
		redo; # redo this loop from the beginning!
	}
	else{# output file exists. do the next run
		`sed -i 's:^read_data.*:read_data $pwd/anneal$ID/$ls[0]:' $pwd/$lmpfile`;		
	     system("mkdir anneal");	# make tis for lmp script.
	}
}
print "all done";


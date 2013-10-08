#!/usr/bin/perl -w
#author: Luke Matarazzo
#file_updater perl script
use strict;

my @page = <STDIN>;
chomp @page;
my @temp = `cat $ARGV[0]`;
chomp @temp;
my @orig, my @change;
my $found = 0;
foreach (@temp){
	if($_ eq "~"){
		$found = 1;
		next;
	}
	if(!$found){
		push(@orig, $_);
	} else {
		push(@change, $_);
	}
}

my $start = $#page + 1;
my $end = 0;
for(my $i = 0; $i <= $#page; $i++){
	#print "from \@page: '$page[$i]'\n";
	#print "from \@orig: '$orig[0]'\n";
	my $j;
	for($j = 0; $j <= $#orig; $j++){
		my $next = $i + $j;
		if($page[$next] ne $orig[$j]){
			$start = $#page + 1;
			last;
		}
		#print "\$next: '$next'\n";
		$start = $next < $start ? $next : $start;
		$end = $next > $end ? $next : $end;
	}
	if($end - $start >= $#orig){
		last;
	}
}

for(my $i = $start; $i <= $end; $i++){
	$page[$i] = $change[$i - $start];
}

# print "these are values to be changed [$start,$end]\n";
# for(my $i = $start; $i <= $end; $i++){
# 	print "'$page[$i]'\n";
# }

#print "@page";
foreach (@page){
	print "$_\n";
}

#print "after for\n";
# print "\noriginal: \n@orig\n";
# print "\nchange: \n@change\n";

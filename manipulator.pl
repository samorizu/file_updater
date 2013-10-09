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
my $counter = 0;
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
	my $j;
	for($j = 0; $j <= $#orig; $j++){
		my $next = $i + $j;
		if($page[$next] ne $orig[$j]){
			$start = $#page + 1;
			last;
		}
		$start = $next < $start ? $next : $start;
		$end = $next > $end ? $next : $end;
	}
	if($end - $start >= $#orig){
		last;
	}
}

if($start == $#page + 1){
	exit 1;
}

for(my $i = $start; $i <= $end; $i++){
	$page[$i] = $change[$i - $start];
}

foreach (@page){
	print "$_\n";
}


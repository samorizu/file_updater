#!/usr/bin/perl -w
#author: Luke Matarazzo
#file_updater perl script
#filename: manipulator.pl
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

my $difference = scalar @change - scalar @orig;

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

if($difference == 0){
	for(my $i = $start; $i <= $end; $i++){
		$page[$i] = $change[$i - $start];
	}
} elsif($difference < 0){
	for(my $i = $start; $i <= $end + $difference; $i++){
		$page[$i] = $change[$i - $start];
	}
	splice(@page, $end, $difference * -1);
} else{
	splice(@page, $start, scalar @orig);
	splice(@page, $end, 0, @change);
}

foreach (@page){
	print "$_\n";
}

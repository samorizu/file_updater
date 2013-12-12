#!/usr/bin/perl -w
#author: Luke Matarazzo
#file_updater perl script
#takes 1 command line argument (changes text file) and expects the web page to be directed to STDIN when called
#filename: manipulator.pl

use strict;

my @page = <STDIN>;
chomp @page;
my @temp = `cat $ARGV[0]`; #get all lines of given changes file
chomp @temp;
my @orig, my @change;
my $found = 0;
my $counter = 0;
foreach (@temp){ #get the text from given file into two separate arrays
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

my $difference = scalar @change - scalar @orig; #get difference in lines of criteria text and replacement text

my $start = $#page + 1;
my $end = 0;
for(my $i = 0; $i <= $#page; $i++){ #find the start and end points of replacing the text
	for(my $j = 0; $j <= $#orig; $j++){
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

if($start == $#page + 1){ #error because start point is more than the number of lines the page has
	exit 1;
}

#replace the text based upon start and end indexes found above
if($difference == 0){ #if text to replace is same as text to find
	for(my $i = $start; $i <= $end; $i++){
		$page[$i] = $change[$i - $start]; #go through and replace each line with replacement text
	}
} elsif($difference < 0){ #if text to replace is less than text to find
	for(my $i = $start; $i <= $end + $difference; $i++){
		$page[$i] = $change[$i - $start];
	}
	splice(@page, $end + $difference, $difference * -1);
} else{ #if text to replace is more than text to find
	splice(@page, $start, scalar @orig); #remove the lines we found
	splice(@page, $start, 0, @change); #add the lines we want to replace with
}

foreach (@page){ #output new page
	print "$_\n";
}

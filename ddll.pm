#######################################################################
## Name    : ddll (dynamic double linked list) module, under ddll.pm ##
## Synopsis: Contains dynamic double linked list functions           ##
##           Converts polygon adjacency hash into linked list        ##
##           Converts polygon adjacency into seperated polygons list ##
## Author  : Ameer Abdelhadi                                         ##
##           ameer.abdelhadi@gmail.com                               ##
#######################################################################


## Data structure
######################################
##  _______________     _____________
## |               |   |             |
## | Hash          |   | ddll        |
## |_______________|   |_____________|
##  _______________
## |     ||        |
## | Key ||  Value |
## |_____||________|               _
##  _______________          head ===
## |  |  ||  |  |  |           |   |
## |  |  ||  |  |  |    _______v___|_
## |x0|y0||x1|y1| -|-->|x0|y0|   | | |
## |  |  ||  |  |  |   |__|__|_|_|_ _|
## |__|__||__|__|__|           |   ^
## |  |  ||  |  |  |           |   |
## |  |  ||  |  |  |    _______v___|_
## |x4|y4||x2|y2| -|-->|x4|y4|   | | |
## |  |  ||  |  |  |   |__|__|_|_|_ _|
## |__|__||__|__|__|           |   ^
## |  |  ||  |  |  |           |   |
## |  |  ||  |  |  |    _______v___|_
## |x3|y3||x5|y5| -|-->|x3|y3|   | | |
## |  |  ||  |  |  |   |__|__|_|_|_ _|
## |__|__||__|__|__|           |   ^
## |  |  ||  |  |  |           |   |
## |  |  ||  |  |  |    _______v___|_
## |x5|x5||x3|y3| -|-->|x5|y5|   | | |
## |  |  ||  |  |  |   |__|__|_|_|___|
## |__|__||__|__|__|           |   ^
## |  |  ||  |  |  |           |   |
## |  |  ||  |  |  |    _______v___|_
## |x1|y1||x4|y4| -|-->|x5|y5|   | | |
## |  |  ||  |  |  |   |__|__|_|_|___|
## |__|__||__|__|__|           |   ^
##                             |   |
##                            === tail
##                             -

package ddll; # ddll module definition

use strict;	# Install all strictures
use FileHandle;	# Use file handle, for dealing with files
use GraphViz;	# Use graph visualization module
use warnings;	# Show warnings
$|++;		# Force auto flush of output buffer

###################################################################
## Synopsis:   Converts polygon adjacency hash into linked list  ##	
## Input:      Polygon adjacency hash pointer                    ##
## Output:     Dynamic double linked list - ddll                 ##
## Complexity: O(polygons adjacency hash size)                   ##
###################################################################
sub hash2ddll {
	my ($package,$layer_hashp)=@_;
	my %layer_hash=%{$layer_hashp};
	my $ddllhead;
	my $ddlltail;	
	my $prevp1=undef;
	foreach my $key (keys %layer_hash) {
		my $currp=$layer_hash{$key};
		if (defined $prevp1) {
			${$currp}[3]=$prevp1;
		} else {
			$ddllhead=$currp;
		}
		$prevp1=$currp;
	}
	my $prevp2=undef;
	foreach my $key (reverse(keys %layer_hash)) {
		my $currp=$layer_hash{$key};
		if (defined $prevp2) {
			${$currp}[2]=$prevp2;
		} else {
			$ddlltail=$currp;
		}
		$prevp2=$currp;
	}
	return ($ddllhead,$ddlltail);
}

#####################################################################################
## Synopsis:   Converts polygon adjacency hash and ddll structure into polygons    ##	
## Input:      ddll head/tail pointers, Polygon adjacency hash pointer, layer name ##
## Output:     polygons array                                                      ##
## Complexity: O(polygons number)                                                  ##
#####################################################################################
sub ddllHash2polygons {
	my ($package,$ddllhead,$ddlltail,$layer_hashp,$layer)=@_;
	my %layer_hash=%{$layer_hashp};
	my @pols;
	while (defined $ddllhead ) {
		my $frst=${$ddllhead}[0];
		my $next=${$layer_hash{$frst}}[1];
		my @pol; push(@pol,"$layer");
		my @coor=split(/\s+/,$frst); push (@pol,@coor); ddllRemove($package,\$ddllhead,\$ddlltail,$layer_hash{$frst});
		while ($frst ne $next) {
			my $pnext=$next;
			$next=${$layer_hash{$pnext}}[1];
			my @coor=split(/\s+/,$pnext); push (@pol,@coor); ddllRemove($package,\$ddllhead,\$ddlltail,$layer_hash{$pnext});
		}
		push(@pols,\@pol);
	}
	return @pols;
}

################################################
## Synopsis:   Removes an element from a ddll ##	
## Input:      head and tail pointer of ddll  ##
##             pointer to element             ##
## Complexity: O(1)                           ##
################################################
sub ddllRemove {
	my ($package,$ddllheadp,$ddlltailp,$elem)=@_;
	my $prev=${$elem}[3];
	my $next=${$elem}[2];
	if (${$ddllheadp} == ${$ddlltailp}) {
		${$ddllheadp}=undef;
		${$ddlltailp}=undef;
	} elsif (${$ddllheadp} == $elem) {
		${$next}[3]=undef;
		${$ddllheadp}=$next;		
	} elsif (${$ddlltailp} == $elem) {
		${$prev}[2]=undef;
		${$ddlltailp}=$prev;
	} else {
		${$prev}[2]=$next;
		${$next}[3]=$prev;
	}
}

################################################
## Synopsis:   Print ddll contents to stdout  ##	
## Input:      ddll head pointer              ##
## Complexity: O(ddll size)                   ##
################################################
sub ddllPrint {
	my ($package,$ddllhead)=@_;
	my $curr=$ddllhead;
	print "ddll:";
	while (defined $curr) {
		my $currv=${$curr}[0];
		print "($currv)";
		$curr=${$curr}[2];
		if (defined $curr) {
			print "->";
		}
	}
	print ":\n";
}

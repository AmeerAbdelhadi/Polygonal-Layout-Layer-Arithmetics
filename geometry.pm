#####################################################################
## Name    : geometry module, under geometry.pm                    ##
## Synopsis: Contains Geometry related functions                   ##
##           polygons, intervals, bound boxes, Coordinates ...etc. ##
## Author  : Ameer Abdelhadi                                       ##
##           ameer.abdelhadi@gmail.com                             ##
#####################################################################

package geometry;  # geometry module definition

use strict;	   # Install all strictures
use FileHandle;	   # Use file handle, for dealing with files
use GraphViz;	   # Use graph visualization module
use warnings;	   # Show warnings
$|++;		   # Force auto flush of output buffer

require 'aux.pm';  # Uses aux module (auxiliary)
require 'ddll.pm'; # Uses ddll module (dynamic double inked list)

#####################################################
## Synopsis:	prints polygons to cif file format ##	
## Input:	cif file name, polygons            ##
## Output:	Erites to cif file                 ##
## Complexity:	O(polygons number)                 ##
#####################################################
sub polygons2cif {
	my ($package,$cif_fn,@pols)=@_;
	my $newlayer="";
	my $oldlayer="";
	## open cif file handler
	open (OUT_HND,">$cif_fn") || die "Cannot open ${cif_fn}. Program terminated!\n";
	## print header
	print OUT_HND "4 1000;\n";
	print OUT_HND "DS 1;\n";
	## print each polygon
	foreach my $polp (@pols) {
		my @pol=@{$polp};
		$newlayer=shift(@pol);
		## print layer only when changed
		if ($newlayer ne $oldlayer) {
			print OUT_HND "L $newlayer;\n";
		}
		$oldlayer=$newlayer;
		print OUT_HND "P @pol;\n";
	}
	## print footer
	print OUT_HND "DF;\n";
	print OUT_HND "E\n";	
}

########################################################
## Synopsis:	Sorts boundary polygon coordinates    ##
##              s.t. it starts from left buttom point ##	
## Input:	Boundary polygon                      ##
## Output:	Sorted polygon                        ##
## Complexity:	O(1)                                  ##
########################################################
sub sort_boundary_polygon {
	my ($package,@pol)=@_;
	my $layer=shift(@pol);
	my ($x0,$x1)=aux->minmax(@pol[0,2,4,6]);
	my ($y0,$y1)=aux->minmax(@pol[1,3,5,7]);
	return ($layer,$x0,$y0,$x0,$y1,$x1,$y1,$x1,$y0);
}

######################################################
## Synopsis:	Shrinks boundary polygon dimensions ##
## Input:	Boundary polygon                    ##
## Output:	Shrinked polygon                    ##
## Complexity:	O(1)                                ##
######################################################
sub shrink_boundary_polygon {
	my ($package,$Xfactor,$Yfactor,@pols)=@_;
	if (($Xfactor == 0) && ($Yfactor == 0)) {
		return @pols;
	}
	else {
		my @pols_shrinked;
		foreach my $polp (@pols) {
			my @pol=@{$polp};
			srand;
			my $rx=((1-$Xfactor)*rand());
			my $ry=((1-$Yfactor)*rand());
			my $dx=($pol[5]-$pol[3]);
			my $dy=($pol[4]-$pol[2]);
			$pol[4]-=int($dy*$ry);
			$pol[5]-=int($dx*$rx);
			$pol[6]-=int($dy*$ry);
			$pol[7]-=int($dx*$rx);
			@pol=sort_boundary_polygon($package,@pol);
			push(@pols_shrinked,\@pol);
		}
		return @pols_shrinked;
	}
}

######################################################################
## Synopsis:	Reflects boundary polygon dimensions around Y=X axis##
## Input:	Boundary polygon                                    ##
## Output:	Reflected polygon                                   ##
## Complexity:	O(polygons number)                                  ##
######################################################################
sub reflect_boundary_polygons {
	my ($package,@pols)=@_;
	my @pols_reflected;	
	foreach my $polp (@pols) {
		my @pol_reflected=sort_boundary_polygon($package,@{$polp}[0,2,1,4,3,6,5,8,7]);
		push(@pols_reflected,\@pol_reflected);
	}
	return @pols_reflected;
}

#################################################################
## Synopsis:	Returns Y-axis ordinates of a boundary polygon ##
## Input:	Boundary polygon                               ##
## Output:	Y-axis ordinates polygon (cut points)          ##
## Complexity:	O(polygons number)                             ##
#################################################################
sub boundary_polygons2cut_points {
	my ($package,@pols)=@_;
	my @cp;
	foreach my $polp (@pols) {
		push(@cp, aux->minmax(@{$polp}[2,4,6,8]));
	}
	return @cp;
}

####################################################
## Synopsis:	Returns X coordinates of polygons ##
## Input:	Polygons                          ##
## Output:	X coordinates of the polygons     ##
## Complexity:	O(polygons number)                ##
####################################################
sub polygons2Xcoordinates {
	my ($package,@pols)=@_;
	my @xcoors;
	foreach my $polp (@pols) {
		my @pol=@{$polp};
		shift(@pol);
		while (@pol) {
			shift(@pol);
			push(@xcoors,shift(@pol));
		}
	}
	return @xcoors;
}

#####################################################
## Synopsis:	Returns vertical edges of polygons ##
## Input:	Polygons                           ##
## Output:	vertical edges of the polygons     ##
##              returns array of pointers to this  ##
##              structure: (layer,x0,y0,y1)        ##
## Complexity:	O(polygons number)                 ##
#####################################################
sub polygons2verticals {
	my ($package,@pols)=@_;
	my @vers;
	my $layer;
	foreach my $polp (@pols) {
		my @pol=@{$polp};
		$layer=shift(@pol);
		@pol=(@pol,@pol[0,1]);
		for (my $i=0;$i<=$#pol-3;$i+=2) {
			my ($x0,$y0)=@pol[$i,$i+1];
			my ($x1,$y1)=@pol[$i+2,$i+3];
			my @ver;
			if ($x0 == $x1) { #X abs
				@ver=($layer,$x0,$y0,$y1);
				unshift(@vers,\@ver);
			}
		}
	}
	my @sorted_vers=sort {$a->[1] <=> $b->[1]} @vers; #sort by x
	return @sorted_vers;
}

########################################################
## Synopsis:	Returns coordinates of vertical edges ##
## Input:	vertical edges, array of pointers to  ##
##              this structure: (layer,x0,y0,y1)      ##
## Output:	coordinates                           ##
## Complexity:	O(vertical edges)                     ##
########################################################
sub verticals2coordinates {
	my ($package,@vers)=@_;
	my @coords;
	foreach my $verp (@vers) {
		my @ver=@{$verp};
		my ($layer,$x0,$y0,$y1)=@ver;
		my @coord1=($layer,"src",$x0,$y0);
		unshift(@coords,\@coord1);
		my @coord2=($layer,"snk",$x0,$y1);
		unshift(@coords,\@coord2);		
	}
	my @sorted_coords=sort {$a->[0] cmp $b->[0] || # layer
				$a->[3] <=> $b->[3] || # y
				$a->[2] <=> $b->[2]    # x
				} @coords;
	
	return @sorted_coords;				
}
	
########################################################
## Synopsis:	Converts vertical edges to horizontal ##
## Input:	vertical edges, array of pointers to  ##
##              this structure: (layer,x0,y0,y1)      ##
## Output:	Horizontal edges, array of pointers   ##
##              to this structure: (layer,y0,x0,x1)   ##
## Complexity:	O(vertical edges)                     ##
########################################################
sub verticals2horizontals {
	my ($package,@vers)=@_;
	my @coords=verticals2coordinates($package,@vers);
	my @hers;
	for (my $i=0;$i<=($#coords);$i+=2) {
		my @coord0=@{$coords[$i]};
		my @coord1=@{$coords[$i+1]};
		my ($layer0,$dir0,$x0,$y0)=@coord0;
		my ($layer1,$dir1,$x1,$y1)=@coord1;
		my @her;
		if ($dir0 eq "snk") {
			@her=($layer0,$y0,$x0,$x1);
		} else {
			@her=($layer0,$y0,$x1,$x0);
		}
		unshift(@hers,\@her);
	}
	return @hers;
}
	
############################################################################
## Synopsis:	Converts vertical edges to horizontal                     ##
##              Uses a hash of points as keys, and values is next points, ##
##              Same hash connected to ddll (dynamic double linked list). ##
##              Traversal on this hash while remove visited point from    ##
##		ddll will generates polygons.                             ##
## Input:	vertical edges, array of pointers to                      ##
##              this structure: (layer,x0,y0,y1)                          ##
## Output:	Polygons                                                  ##
## Complexity:	O(Polygons number)                                        ##
############################################################################
sub verticals2polygons {
	my ($package,@vers)=@_;
	my @hers=verticals2horizontals($package,@vers);
	my %poly_hash;
	my %diff_hash;
	foreach my $verp (@vers) {
		my @ver=@{$verp};
		my ($layer,$x0,$y0,$y1)=@ver;
		## includes hash key/next/prev pointers
		my @hash_elem=("$x0 $y0","$x0 $y1",undef,undef);
		if ($layer eq "polysilicon") {
			$poly_hash{"$x0 $y0"}=\@hash_elem;
		} else {
			$diff_hash{"$x0 $y0"}=\@hash_elem;
		}
	}
	## includes hash key/next/prev pointers
	foreach my $herp (@hers) {
		my @her=@{$herp};
		my ($layer,$y0,$x0,$x1)=@her;
		my @hash_elem=("$x0 $y0","$x1 $y0",undef,undef); 
		if ($layer eq "polysilicon") {
			$poly_hash{"$x0 $y0"}=\@hash_elem;
		} else {
			$diff_hash{"$x0 $y0"}=\@hash_elem;
		}
	}
	my ($ddllhead_poly,$ddlltail_poly)=ddll->hash2ddll(\%poly_hash);
	my ($ddllhead_diff,$ddlltail_diff)=ddll->hash2ddll(\%diff_hash);
	return (ddll->ddllHash2polygons($ddllhead_poly,$ddlltail_poly,\%poly_hash,"polysilicon"),
	        ddll->ddllHash2polygons($ddllhead_diff,$ddlltail_diff,\%diff_hash,"diffusion"  ));

}

#####################################################################
## Synopsis:	Merge intervals with same start/end point 	   ##
## Input:	Array of numbers pairs, intervals start/end points ##
## Output:	Array with merged intervals			   ##
## Complexity:	O(n)                                               ##
#####################################################################
sub merge_intervals {
	my ($package,@arr)=@_;
	my @merged_arr;
	push(@merged_arr,shift(@arr));
	## iterate on input arrat
	foreach my $val (@arr) {
		my $mergedtop=pop(@merged_arr); ## array top
		##check interval start/end points
		if ($mergedtop != $val) {
			push(@merged_arr,($mergedtop,$val));
		}
	}
	return @merged_arr;
}

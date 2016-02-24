##################################################
## Name    : cif module, under cif.pm           ##
## Synopsis: Contains all cif related functions ##
## Author  : Ameer Abdelhadi                    ##
##           ameer.abdelhadi@gmail.com          ##
##################################################

package cif;           # cif module definition
	
use strict;            # Install all strictures
use FileHandle;        # Use file handle, for dealing with files
use GraphViz;          # Use graph visualization module
use warnings;          # Show warnings
$|++;                  # Force auto flush of output buffer

require 'geometry.pm'; # Uses geometry module

####################################################
## Synopsis:	Reads cif format file into a list ##
## Input:	Cif file name			  ##
## Output:	List of cif rows		  ##
## Complexity:	O(cif rows)                       ##
####################################################
sub cif2lst {
	my ($package,$cif_fn)=@_;
	open (CIF_HND,$cif_fn) || die "Cannot open ${cif_fn}. Program terminated!\n";
	my @cif_lst=<CIF_HND>;
	return @cif_lst;
}

######################################################
## Synopsis:	Split cif commands by semicolons    ##
## Input:	Cif file rows list                  ##
## Output:	List of cif comman (semicolon split ##
## Complexity:	O(cif commands)                     ##
######################################################
sub semicolon_split {
	my ($package,@cif_lst)=@_;
	my @cif;
	my $line; my $command;
	foreach $line (@cif_lst) {
		chomp($line);
		if ($line=~/(.*)\s*;\s*(.*)/) {
			$command=$command.$1;
			if ($command!~/^\s*$/) { push(@cif,$command); }
				$command=$2;
			}
		else {
			$command=$command." $line";
		}
	}
	return @cif;
}

##############################################################
## Synopsis:		Translates cif commands to polygons ##
## Input:		cif commands list                   ##
## Output:		list of polygons pointers           ##
## Polygon format:	list: (layer,x0,x1,x2,y2,...)       ##
## Complexity:		O(cif commands)                     ##
##############################################################
sub layer_cif2pol {
	my ($package,@cif)=@_;
	my @pols;
	my $layer;
	for (my $i=0;$i<=$#cif;$i++) {
		if ($cif[$i]=~/^\s*L\s+(.*)\s*$/) {
			$layer=$1;
		}
		elsif ($cif[$i]=~/^\s*P\s+(.*)\s*$/) {
			my @pol=split(/\s+/,$1);
			unshift(@pol,$layer);
			push(@pols,\@pol);
		}
	}
	return @pols;
}

#######################################################################
## Synopsis:		Translates cif commands to boundary polygons ##
## Input:		cif commands list                            ##
## Output:		list of polygons pointers                    ##
## Polygon format:	list: (layer,x0,x1,x2,y2,...)                ##
## Complexity:		O(cif commands)                              ##
#######################################################################
sub bound_cif2pol {
	my ($package,@cif)=@_;
	my %defs;
	my @calls;
	my @pols;
	for (my $i=0;$i<=$#cif;$i++) {
		if ($cif[$i]=~/^\s*DS\s+(\d*)$/) {
			my $defn=$1;
			$i++;
			while ($cif[$i]!~/^\s*DF\s*$/) {
				if ($cif[$i]=~/^\s*C\s+(-?\d*)\s*(.*)\s*/) {
					my $callc="$1 $2";
					push(@calls, $callc);
				}
				if ($cif[$i]=~/^\s*P\s+\S*\s*(-?\d*)\s*(-?\d*)\s*(-?\d*)\s*(-?\d*)\s*(-?\d*)\s*(-?\d*)\s*(-?\d*)\s*(-?\d*)/) {
					my @pcoord=($1,$2,$3,$4,$5,$6,$7,$8);
					$defs{$defn}=\@pcoord;
				}
				$i++;
			}
		}
	}
	foreach my $callc (@calls) {
		my @calla=split(/\s+/,$callc);
		my $defn=shift(@calla);
		my @pol=@{$defs{$defn}};
		while (my $call_attr=shift(@calla)) {
			if ($call_attr eq "T") {
				my $xdiff=shift(@calla);
				my $ydiff=shift(@calla);
				for my $i (0,2,4,6) {
					$pol[$i]+=$xdiff;
					$pol[$i+1]+=$ydiff;				
				}
			}
			if ($call_attr eq "MX") {
				for my $i (0,2,4,6) {
					$pol[$i]*=-1;
				}
			}
			if ($call_attr eq "MY") {
				for my $i (1,3,5,7) {
					$pol[$i]*=-1;	
				}
			}				
		}

		unshift(@pol,"chkBoundary");

		@pol=geometry->sort_boundary_polygon(@pol);
		
		push(@pols,\@pol);
	}
	return @pols;
}

#!/usr/bin/perl -w

# SYNOPSIS:
#   Segments tree based algorithmic VLSI layout layer arithmetic operations.
#   The algorithm is based on the Segments tree algorithm for finding the contour of union of rectangles.
#   Input data contains polygons of diffusion and polysilicon in CIF format.
#   The algorithm finds intersection and relative complement of the two layers.
#   Assuming two layer, polysilion and diffusion, the algorithm finds:
#   1. Pure diffusion nodes, namely diffusion minus polysilicon. (relative complement)
#   2. Transistor gates, namely diffusion intersection with polysilicon. (intersection)
# USAGE:
#   layerArithmetics.pl -input <CIF input file> -inter <CIF intersection output file> -pdiff <CIF pure diffusion output file>
# PARAMETERS:
#   -input: input CIF file, contains polysilicon and diffusion layers.
#   -inter: Generated output CIF file, contains intersection between polysilicon and diffusion.
#   -pdiff: Generated output CIF file, contains pure diffusion.
#   -ps   : Plots the segments tree graph as a PostScript file.
#   >> (-input) and at least one of (-inter) and (-pdiff) are required.
# EXAMPLE:
#   layerArithmetics.pl -input polygons.cif -inter intersection.cif -pdiff pureDiffusion.cif -ps segmentsTree.ps
# SUPPORT:
#   Ameer Abdelhadi
#   ameer.abdelhadi@gmail.com

use strict;	  # Install all strictures
use warnings;	  # Show warnings
use FileHandle;   # Use file handle, for dealing with files
use GraphViz;	  # Use graph visualization module
use Getopt::Long; # For command line options (flags)
$|++;		  # Force auto flush of output buffer

require 'cif.pm';
require 'aux.pm';
require 'segmentsTree.pm';
require 'geometry.pm';
require 'ddll.pm';


############################################################################################

my $input_cif=undef;
my $inter_cif=undef;
my $pdiff_cif=undef;
my $ps=undef;
my $help=undef;

if ( ! &GetOptions (
	"input|inp|in:s"			=> \$input_cif,
	"intersection|int|inter:s"	=> \$inter_cif,
	"pureDiffusion|pdiff|diff:s"=> \$pdiff_cif,
    "ps:s"						=> \$ps,
	"h|help"					=> \$help
) || $help || (!defined($input_cif)) || (!defined($inter_cif) && !defined($pdiff_cif)) ) {
print STDOUT <<END_OF_HELP;
USAGE:
  layerArithmetics.pl -input <CIF input file> -inter <CIF intersection output file> -pdiff <CIF pure diffusion output file>
PARAMETERS:
  -input: input CIF file, contains polysilicon and diffusion layers.
  -inter: Generated output CIF file, contains intersection between polysilicon and diffusion.
  -pdiff: Generated output CIF file, contains pure diffusion.
  >> (-input) and at least one of (-inter) and (-pdiff) are required.
EXAMPLE:
  layerArithmetics.pl -input polygons.cif -inter intersection.cif -pdiff pureDiffusion.cif -ps segmentsTree.ps
SUPPORT:
  ameer.abdelhadi\@gmail.com
END_OF_HELP
exit;
}

my @cif=cif->semicolon_split(cif->cif2lst($input_cif));
my @pols=cif->layer_cif2pol(@cif);
my ($intr_vers,$diff_vers)=intersection_pureDiffusion(@pols);

if (defined $inter_cif) {
	geometry->polygons2cif($inter_cif,geometry->verticals2polygons(@{$intr_vers}));
}

if (defined $pdiff_cif) {
	geometry->polygons2cif($pdiff_cif,geometry->verticals2polygons(@{$diff_vers}));
}

############################################################################################



####################################################################
## Synopsis:   Returns intersection and pure diffusion polygons   ##
## Input:      Input (polysilicon and diffusion) polygons         ##
## Output:     Intersection and pure diffusion polygons           ##
## Complexity: O(nlog(n)) n=input polygons number                 ##
####################################################################
sub  intersection_pureDiffusion {
	my @pols=@_;
	my @vers=geometry->polygons2verticals(@pols);
	my $st=segmentsTree->buildSegmentsTree(2,"polystat","empty","diffstat","empty",geometry->polygons2Xcoordinates(@pols));
	if ($ps) {segmentsTree->printSegmentsTreeGraph($st,"$ps")}
	my @out_intr_vers;
	my @out_diff_vers;
	foreach my $verp (@vers) {
		my @ver=@{$verp};
		my $layer=shift(@ver); my $nlayer=($layer eq "polysilicon") ? "diffusion" : "polysilicon"; #layer
		my ($x0,$y0,$y1)=(shift(@ver),shift(@ver),shift(@ver));
		if ($y1 > $y0) { ## opening edge
			insertSegment($st,$y0,$y1,$layer);
			my @stnodes=findNodes($st,"empty","empty",$y0,$y1);
			my @intervals;
			my @diff_intervals;
			foreach my $stnodep (@stnodes) {
				my ($stnode,$polystat,$diffstat)=(${$stnodep}[0],${$stnodep}[1],${$stnodep}[2]);
				push(@intervals,intersection($stnode,$polystat,$diffstat,$nlayer));
				push(@diff_intervals,pureDiffusion($stnode,$polystat,$diffstat,$nlayer));
			}
			my @merged_intervals=geometry->merge_intervals(@intervals);
			my @merged_diff_intervals=geometry->merge_intervals(@diff_intervals);		
			if (scalar(@merged_intervals) > 1) {
				for (my $i=0;$i<=$#merged_intervals;$i+=2) {
					my @out_ver=("polysilicon",$x0,$merged_intervals[$i],$merged_intervals[$i+1]);
					push(@out_intr_vers,\@out_ver);
				}
			}
			if (scalar(@merged_diff_intervals) > 1) {
				for (my $i=0;$i<=$#merged_diff_intervals;$i+=2) {
					my @out_diff_ver;
					if ($layer eq "diffusion") {
						@out_diff_ver=("diffusion",$x0,$merged_diff_intervals[$i],$merged_diff_intervals[$i+1]);
					} else {@out_diff_ver=("diffusion",$x0,$merged_diff_intervals[$i+1],$merged_diff_intervals[$i]);}
					push(@out_diff_vers,\@out_diff_ver);
				}
			}
		} else {
			## check here if contribute to intersection
			my @stnodes=findNodes($st,"empty","empty",$y1,$y0);
			my @intervals;
			my @diff_intervals;
			foreach my $stnodep (@stnodes) {
				my ($stnode,$polystat,$diffstat)=(${$stnodep}[0],${$stnodep}[1],${$stnodep}[2]);
				push(@intervals,intersection($stnode,$polystat,$diffstat,$nlayer));
				push(@diff_intervals,pureDiffusion($stnode,$polystat,$diffstat,$nlayer));
			}
			my @merged_intervals=geometry->merge_intervals(@intervals);
			my @merged_diff_intervals=geometry->merge_intervals(@diff_intervals);		
			if (scalar(@merged_intervals) > 1) {
				for (my $i=0;$i<=$#merged_intervals;$i+=2) {
					my @out_ver=("polysilicon",$x0,$merged_intervals[$i+1],$merged_intervals[$i]);
					push(@out_intr_vers,\@out_ver);
				}	
			}
			if (scalar(@merged_diff_intervals) > 1) {
				for (my $i=0;$i<=$#merged_diff_intervals;$i+=2) {
					my @out_diff_ver;
					if ($layer eq "diffusion") {
						@out_diff_ver=("diffusion",$x0,$merged_diff_intervals[$i+1],$merged_diff_intervals[$i]);
					} else {@out_diff_ver=("diffusion",$x0,$merged_diff_intervals[$i],$merged_diff_intervals[$i+1]);}
					push(@out_diff_vers,\@out_diff_ver);
				}
			}
			removeSegment($st,$y1,$y0,$layer);
		}
	}
	return (\@out_intr_vers,\@out_diff_vers);
}

##############################################################################
## Synopsis:   Inserts segment (layer's vertical edge) to the segments tree ##
## Input:      - Segments tree root pointer                                 ##
##             - Segment start/end points                                   ##
##             - Layer                                                      ##
## Complexity: O(log(n)) n=segments tree segments number                    ##
##############################################################################
sub insertSegment {
	my ($st,$sb,$se,$layer)=@_;
	my $stat_keyName=($layer eq "polysilicon") ? "polystat" :"diffstat"; ## key name
	if ( defined $st ) {
		if ( (($st->{segB})>=$sb)&&(($st->{segE})<=$se) ) {
				$st->{"$stat_keyName"}="full";
				if (defined $st->{left}) {
					my $lson=$st->{left};
					my $rson=$st->{right};
					$lson->{"$stat_keyName"}="empty";
					$rson->{"$stat_keyName"}="empty";
				}	
		} else {
			if ($sb<($st->{segM})) {
				insertSegment($st->{left},$sb,$se,$layer);
			}
			if ($se>($st->{segM})) {
				insertSegment($st->{right},$sb,$se,$layer);
			}
			updateNode($st);		
		}
	}
}

################################################################################
## Synopsis:   Removes segment (layer's vertical edge) from the segments tree ##
## Input:      - Segments tree root pointer                                   ##
##             - Segment start/end points                                     ##
##             - Layer                                                        ##
## Complexity: O(log(n)) n=segments tree segments number                      ##
################################################################################
sub removeSegment {
	my ($st,$sb,$se,$layer)=@_;
	my $stat_keyName=($layer eq "polysilicon") ? "polystat" :"diffstat"; ## key name	
	if ( defined $st ) {
		if ( (($st->{segB})>=$sb)&&(($st->{segE})<=$se) ) {
				$st->{"$stat_keyName"}="empty";
		} else {
			my $xson;
			my $visited=0;
			if ($sb<($st->{segM})) {
				removeSegment($st->{left},$sb,$se,$layer);
				$xson=$st->{right}; $visited++;
      				
			}
			if ($se>($st->{segM})) {
				removeSegment($st->{right},$sb,$se,$layer);
				$xson=$st->{left}; $visited++;
			}
			## roll "full" if son removed
			if (($visited == 1) && ($st->{"$stat_keyName"} ne "partial")) {
				$xson->{"$stat_keyName"}="full";
			}					
			updateNode($st);		
		}
	}
}

#############################################################
## Synopsis:   Update nodes attributes while insert/remove ##
## Input:      Segments tree root pointer                  ##
## Complexity: O(1)                                        ##
#############################################################
sub updateNode {
	my $st=$_[0];
	if ( (defined $st) && (defined $st->{left}) ) { ## not a leaf
		my $lson=$st->{left};
		my $rson=$st->{right};
		foreach my $stat_keyName ("polystat","diffstat") {
			if ( ($lson->{"$stat_keyName"} eq "full") &&  ($rson->{"$stat_keyName"} eq "full") ) {
				$st->{"$stat_keyName"}="full";
				$lson->{"$stat_keyName"}="empty";
				$rson->{"$stat_keyName"}="empty";
			} elsif ( ($lson->{"$stat_keyName"} eq "empty") &&  ($rson->{"$stat_keyName"} eq "empty") ) {
				$st->{"$stat_keyName"}="empty";
			} else {
				$st->{"$stat_keyName"}="partial";			
			}
		}
	}
}

###############################################################
## Synopsis:   Find intersection intervals with current node ##
## Input:      - Segments tree node pointer                  ##
##             - Node status (diff/poly)                     ##
##             - Layer to find intersection with             ##
##  Output:    Intersection intervals with current node      ##
## Complexity: O(log(n)) n=segments tree segments number     ##
###############################################################
sub intersection {
	my ($st,$polystat,$diffstat,$layer)=@_;
	my @inter;
	if ($polystat ne "full") {$polystat=$st->{polystat}} ## update polystat
	if ($diffstat ne "full") {$diffstat=$st->{diffstat}} ## update diffstat
	if (defined $st) {
		my $layer_stat=($layer eq "polysilicon") ? $polystat : $diffstat; ## key name	
		if ($layer_stat eq "full") {
			push(@inter,($st->{segB},$st->{segE}));
		} elsif ($layer_stat eq "partial") {
			push(@inter,intersection($st->{left},$polystat,$diffstat,$layer));
			push(@inter,intersection($st->{right},$polystat,$diffstat,$layer));
		}
	}
	return @inter;
}


###############################################################
## Synopsis:   Find pure diffusion intervals at current node ##
## Input:      - Segments tree node pointer                  ##
##             - Node status (diff/poly)                     ##
##             - Layer to find intersection with             ##
##  Output:    Pure diffusion intervals at current node      ##
## Complexity: O(log(n)) n=segments tree segments number     ##
###############################################################
sub pureDiffusion {
	my ($st,$polystat,$diffstat,$layer)=@_;
	my @diff;
	if ($polystat ne "full") {$polystat=$st->{polystat}} ## update polystat
	if ($diffstat ne "full") {$diffstat=$st->{diffstat}} ## update diffstat
	if (defined $st) {
		if ($layer eq "diffusion") {
			if ($diffstat eq "full") {
				push(@diff,($st->{segB},$st->{segE}));
			} elsif ($diffstat eq "partial") {
				push(@diff,pureDiffusion($st->{left},$polystat,$diffstat,$layer));
				push(@diff,pureDiffusion($st->{right},$polystat,$diffstat,$layer));
			}
		} elsif ($layer eq "polysilicon") {
			if ($polystat eq "empty") {
				push(@diff,($st->{segB},$st->{segE}));
			} elsif ($polystat eq "partial") {
				push(@diff,pureDiffusion($st->{left},$polystat,$diffstat,$layer));
				push(@diff,pureDiffusion($st->{right},$polystat,$diffstat,$layer));				
			}
		}
	}
	return @diff;
}
		
##########################################################################
## Synopsis:   Find deepest sons of current node (st) with their status ##
## Input:      - Segments tree node pointer                             ##
##             - Node status (diff/poly)                                ##
##             - Segment start/end points                               ##
##  Output:    Deepest sons of current node (st) with their status      ##
## Complexity: O(log(n)) n=segments tree segments number                ##
##########################################################################
sub findNodes {
	my ($st,$polystat,$diffstat,$sb,$se)=@_;
	my @stnodes;
	my $currpolystat;
	my $currdiffstat;
	if ($polystat ne "full") {$currpolystat=$st->{polystat}} else {$currpolystat=$polystat}## update polystat
	if ($diffstat ne "full") {$currdiffstat=$st->{diffstat}} else {$currdiffstat=$diffstat} ## update diffstat
	if ( (($st->{segB})>=$sb)&&(($st->{segE})<=$se) ) {
		my @node=($st,$currpolystat,$currdiffstat); push(@stnodes,\@node);
	} else {
		if ($sb<($st->{segM})) {
			 push(@stnodes,findNodes($st->{left},$currpolystat,$currdiffstat,$sb,$se));
		}
		if ($se>($st->{segM})) {
			 push(@stnodes,findNodes($st->{right},$currpolystat,$currdiffstat,$sb,$se));
		}	
	}
	return @stnodes;
}

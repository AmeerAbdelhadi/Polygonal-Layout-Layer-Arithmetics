#######################################################
## Name    : segmentsTree under segmentsTree.pm      ##
## Synopsis: Contains segment tree related functions ##
## Author  : Ameer Abdelhadi                         ##
##           ameer.abdelhadi@gmail.com               ##
#######################################################

package segmentsTree; # segmentsTree module definition

use strict;	      # Install all strictures
use FileHandle;	      # Use file handle, for dealing with files
use GraphViz;	      # Use graph visualization module
use warnings;	      # Show warnings
$|++;		      # Force auto flush of output buffer

require 'aux.pm';     # Uses aux module (auxiliary)

##################################################################
## Synopsis:   Builds segements tree structure (recursively)    ##
## Input:      - Number of extra attributes needed at each node ##
##             - List of attributes name+defult value pairs     ##
##             - Array of sgements cut points                   ##
## Output:     Pointer to segment tree		                ##
## Complexity:	O(Segment number)                               ##
##################################################################
sub buildSegmentsTree {
	my ($package,$attr_num,@input_list)=@_;
	my @attr=@input_list[0..($attr_num*2)-1];
	my @points=@input_list[($attr_num*2)..$#input_list];
	my @spoints=aux->sort_uniq(@points);
	if ($#spoints>0) {
		my $mid_range=int(($#spoints)/2);
		my $lson= ($mid_range > 0) ? buildSegmentsTree($package,2,@attr,@spoints[0..$mid_range]) : undef;
		my $rson= ($mid_range > 0) ? buildSegmentsTree($package,2,@attr,@spoints[$mid_range..$#spoints]) : undef;
		my %curr_node = (
			segB	=> $spoints[0]		,
			segE	=> $spoints[$#spoints]	,
			segM	=> $spoints[$mid_range]	,
			left	=> $lson		,
			right	=> $rson		,
		);
		for (my $i=0;$i<($attr_num*2);$i+=2) {
			$curr_node{$attr[$i]}=$attr[$i+1];
		}
		return \%curr_node;
	}
	return undef;
}

############################################
## Synopsis:   Updates a segment value    ##
## Input:      Segemts tree pointer       ##
##             Begining/end of segment    ##
##             Attribute name             ##
##             Attribute value	          ##
## Complexity: O(log(n)) n=Segment number ##
############################################
sub updateAttribute {
	my ($package,$st,$sb,$se,$attr,$val)=@_;
	if ( defined $st ) {
		if ( (($st->{segB})>=$sb)&&(($st->{segE})<=$se) ) {
			$st->{$attr}=$val;
		}
		else {
			if ($sb<($st->{segM})) {
				updateAttribute($package,$st->{left},$sb,$se,$attr,$val);
			}
			if ($se>($st->{segM})) {
				updateAttribute($package,$st->{right},$sb,$se,$attr,$val);
			}
		}	
	}
}

###############################################################################
## Synopsis:	Returns maximum value of of an attribue at a segment         ##
## Input:	Segemts tree pointer,Begining/end of segment, Attribute name ##
## Output:	Max value above	      	      	      	      	   	     ##
## Complexity:	O(log(n)) n=Segment number                  	             ##
###############################################################################
sub getMaxValue {
	my ($package,$st,$sb,$se,$attr)=@_;
	if ( defined $st ) {
		my $vall=0;
		my $valr=0;
		if ($sb<($st->{segM})) {
			$vall=getMaxValue($package,$st->{left},$sb,$se,$attr);
		}
		if ($se>($st->{segM})) {
			$valr=getMaxValue($package,$st->{right},$sb,$se,$attr);
		}
		my $valc= ($st->{$attr});
		if ( ($valc > $vall) && ($valc > $valr) ) {
			return $valc;
		} elsif ($vall > $valr) {
			return $vall;
		} else {
			return $valr;
		}
	}
}

######################################################################
## Synopsis:	build a graph for the segments tree                 ##
## Input:	-Segemts tree pointer                               ##
##              -Attribute names (to be printed)                    ##
##              -Pointer to a graph structure                       ##
##              Call: buildSegmentsTreeGraph($st,"root","root",$g); ##
## Output:	Graph structure of the segments tree	            ##
## Complexity:	O(Segment number)                              	    ##
######################################################################
sub buildSegmentsTreeGraph {
	my ($package,$st,$father,$direction,$g,@attrs)=@_;
	if ( defined $st ) {
		my $curr_node="$st->{segB}:$st->{segE}";
		my $label=$curr_node;
		foreach my $attr (@attrs) {
			$label="$label\n$attr=$st->{$attr}"
		}
		$g->add_node("$curr_node", label => "$label");
		if ( $father ne "root" ) {
			$g->add_edge("$father" => "$curr_node", label => "$direction");
		}
		buildSegmentsTreeGraph($package,$st->{left},"$curr_node","left",$g,@attrs);
		buildSegmentsTreeGraph($package,$st->{right},"$curr_node","right",$g,@attrs);
	}
}

################################################################
## Synopsis:	Prints the segement tree graph into a ps file ##
## Input:	segement tree root pointer, ps file name      ##
## Output:	ps file contains segmenmt tree graph	      ##
## Complexity:	O(Segment number )                              	      ##
################################################################
sub printSegmentsTreeGraph {
	my ($package,$st,$fn)=@_;
	my $g = GraphViz->new();
	buildSegmentsTreeGraph($package,$st,"root","root",$g);
	$g->as_ps("$fn"); 
}

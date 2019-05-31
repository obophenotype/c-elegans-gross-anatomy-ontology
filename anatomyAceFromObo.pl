#!/usr/bin/perl

# for Daniela to download a Lifestage .obo file and generate a .ace file.  2013 06 17
#
# added part_of and starts_at_end_of.  2014 03 27
#
# modified to suppress additional synonym junk, and print paper_evidence of definition.  2019 02 05


use strict;
use LWP::Simple;

my $url = 'https://raw.githubusercontent.com/obophenotype/c-elegans-gross-anatomy-ontology/master/wbbt-full.obo';

my $page = get $url;

my @objects = split/\n\n/, $page;

my $header = shift @objects;

my %parents = ();

my %ancestors = ();

my $outfile = 'anatomy.ace';
open (OUT, ">$outfile") or die "Cannot create $outfile : $!";

foreach my $obj (@objects) {
  my ($id, $name, $def, $isa, $rel) = ('', '', '', '', '');
  if ($obj =~ m/id: (WBbt:\d+)/) {
    my $ace;
    $id = $1;
    $ace .= qq(Anatomy_term : "$id"\n);
    if ($obj =~ m/name: (.*)/) { $ace .= qq(Term\t"$1"\n); }
    while ($obj =~ m/synonym: "(.*)"(.*)/g) {
	my $syn = $1;
	my ($refs) = $2 =~ m/\[(.*)\]/g;
	my @refs = split /,/, $refs;
	if (scalar @refs < 1) { $ace .= qq(Synonym\t"$syn"\n); }
	else {
	    foreach my $ref (@refs) {
		$ref = evidence ($ref);
		$ace .= qq(Synonym\t"$syn"\t$ref\n); } }
    }
    if ($obj =~ m/def: "(.*)"(.*)/) { 
	my $def = $1;
	my ($paps) = $2 =~ m/\[(.*)\]/g;
	my @paps = split /,/, $paps;
	if (scalar @paps < 1) { $ace .= qq(Definition\t"$def"\n); }
	else {
	    foreach my $pap (@paps) {
		$pap = evidence ($pap);
		$ace .= qq(Definition\t"$def"\t$pap\n); } }
    }
    while ($obj =~ m/is_a: (WBbt:\d+)/g) { 
	$ace .= qq(IS_A_p\t"$1"\n);
	push @{ $parents{$id} }, $1;
    }
    while ($obj =~ m/relationship: develops_from (WBbt:\d+)/g) { $ace .= qq(DEVELOPS_FROM_p\t"$1"\n); }
    while ($obj =~ m/relationship: part_of (WBbt:\d+)/g) { 
	$ace .= qq(PART_OF_p\t"$1"\n);
	push @{ $parents{$id} }, $1;    
    }
    while ($obj =~ m/relationship: DESCENDENTOF (WBbt:\d+)/g) { $ace .= qq(DESCENDENT_OF_p\t"$1"\n); }
    while ($obj =~ m/relationship: DESCINHERM (WBbt:\d+)/g) { $ace .= qq(DESC_IN_HERM_p\t"$1"\n); }
    while ($obj =~ m/relationship: DESCINMALE (WBbt:\d+)/g) { $ace .= qq(DESC_IN_MALE_p\t"$1"\n); }
    while ($obj =~ m/union_of: (WBbt:\d+)/g) { 
	$ace .= qq(XUNION_OF_p\t"$1"\n);
	push @{ $parents{$1} }, $id;
    }
    while ($obj =~ m/alt_id: (WBbt:\d+)/g) { $ace .= qq(Remark\t\"Secondary ID $1"\n); }    
    while ($obj =~ m/comment: (.*)/g) { $ace .= qq(Remark\t"$1"\n); }
    $ace .= qq(\n);
    print OUT qq($ace);
  }
} # foreach my $obj (@objects)

for my $child (keys %parents) {
    findAncestor ($child, $child);
}

for my $id (sort keys %ancestors) {
    my $ace;
    $ace .= qq(Anatomy_term : "$id"\n);
    for my $ancestor (sort keys %{$ancestors{$id}}) {
	$ace .= qq(Ancestor\t"$ancestor"\n); }
    $ace .= qq(\n);
    print OUT qq($ace);
}

sub findAncestor {
    my ($root, $child) = @_;
    foreach my $parent (@{ $parents{$child} }) {
	$ancestors{$root}{$parent}++;
	findAncestor ($root, $parent);
    }
    return;
} # findAncestor

sub evidence {
    my $def_ref = shift;
    my $ref = "";
    
    if ($def_ref =~ /[ISBN|WB]:0-87969-307-X/) { #KLUGE
	$ref = "Paper_evidence WBPaper00004052";
    }
    elsif ($def_ref =~ m/wb(:?)paper(:?)(\d{8})/i) {
	$ref = "Paper_evidence WBPaper$3";
    }
    elsif ($def_ref =~ m/wb:rynl/i) {
	$ref = "Person_evidence WBPerson363";
    }
    elsif ($def_ref =~ m/wb:pws/i) {
	$ref = "Person_evidence WBPerson625";
    }
    elsif ($def_ref =~ m/wa:dh/i) {
	$ref = "Person_evidence WBPerson233";
    }
    elsif ($def_ref =~ m/wb:s[bd]m/i) { #KLUGE
	$ref = "Person_evidence WBPerson1250";
    }
    elsif ($def_ref =~ m/wb:wjc/i) {
	$ref = "Person_evidence WBPerson101";
    }
    elsif ($def_ref =~ m/wb:cgc938/i) {
	$ref = "Paper_evidence WBPaper00000938";
    }		    
    elsif ($def_ref =~ m/wb:([?)cgc938(\\?)(]?)/i) {
	$ref = "Paper_evidence WBPaper00000938";
    }
    elsif ($def_ref =~ m/wb:cgc938 \"\"/i) {
	$ref = "Paper_evidence WBPaper00000938";
    }
    elsif ($def_ref =~ m/wb:\\\[cgc3760\\\]/i) {
	$ref = "Paper_evidence WBPaper00003760";
	
    } elsif ($def_ref =~ m/wb:Paper(.*) \"\"/i) {
	$ref = "Paper_evidence WBPaper$1";
    }
    elsif ($def_ref =~ m/wb:(.*) \"\"/i) {
	$ref = "Paper_evidence [$1]";
    } 
    elsif ($def_ref =~ m/wbpaper:(\d{8})(| \"\")/i) {   # WBPaper:00000653
	$ref = "Paper_evidence WBPaper$1";
    }
    elsif ($def_ref =~ m/caro:(.*)(|\"\")/i) { #KLUGE
    }
    elsif ($def_ref =~ m/ISBN:(\d*) \"\"/i) {
    }
    elsif ($def_ref =~ m/ISBN:(.*)/i) {
	#		    print "Paper_evidence \[isbn$1\]";
    }
    else {
	print "UNKNOWN Reference: \"$def_ref\"\n";
	exit;    
    }
    return $ref;
} # evidence

    
close (OUT) or die "Cannot close $outfile : $!";


__END__


OBO
id: WBls:0000007
name: 2-cell embryo
def: "0-20min after first cleavage at 20 Centigrade.  Contains 2 cells." [wb:wjc]
is_a: WBls:0000005 ! blastula embryo
relationship: preceded_by WBls:0000006 ! 1-cell embryo

and should be converted in .ace so that it becomes

.ace
Life_stage : "WBls:0000007"
Public_name	"2-cell embryo"
Definition	"0-20min after first cleavage at 20 Centigrade.  Contains 2 cells."
Contained_in	"WBls:0000005"
Preceded_by	"WBls:0000006"


the conversions are
id: -> Life_stage :
name: -> Public_name
def: -> Definition
is_a: -> Contained_in
relationship: -> Preceded_by



#!/usr/local/bin/perl -w

=head1 NAME

  get_human_ests.pl

=head1 SYNOPSIS
 
  get_human_ests.pl

=head1 DESCRIPTION

  gets human ESTs from dbEST or cDNAs from embl/vertRNA and polyT/polyA clips them

=head1 OPTIONS

  -estfile
  -outfile
  -clip (clips polyA/T) 
  -clip_ends n (clips n bases from both ends - default = 0, 20 seems to be ok)
  -quality (filters ESTs based on sequence quality)
  -softmask ( softmask the polyA/T )
  -min_length n (default n = 100bp)

=cut


use strict; 
use Getopt::Long;
use Bio::Seq;
use Bio::SeqIO;
use Bio::EnsEMBL::Utils::PolyA;
use Bio::EnsEMBL::Pipeline::Tools::ESTFilter;

#$| = 1; # disable buffering
#local $/ = '>';

my $estfile;
my $seqoutfile;
my $clip;
my $quality;
my $softmask;

############################################################
# we usually clip 20bp on either end of the EST to eliminate low quality sequence
my $clip_ends = 0;

############################################################
# we don't want any EST which is shorter than 100bp
my $min_length = 100;


&GetOptions( 
	    'estfile:s'     => \$estfile,
	    'outfile:s'     => \$seqoutfile,
	    'clip'          => \$clip,
	    'quality'       => \$quality,
	    'clip_ends:n'   => \$clip_ends,
	    'softmask'      => \$softmask,
	    'min_length'    => \$min_length,
	   );

# usage
if(!defined $estfile    ||
   !defined $seqoutfile 
  ){
  print STDERR "script to collect human ESTs.\n";
  print STDERR "It rejects ESTs labelled as pseudogenes, non-coding RNAs or cancer genes\n";
  print STDERR "\n";
  print STDERR "USAGE: get_human_ests.pl -estfile estfile -outfile outfile\n";
  print STDERR "                         -clip (clips polyA/T) -clip_ends n (clips n bases from both ends)\n";
  print STDERR "                                                             default = 0, 20 seems to be ok\n";
  print STDERR "                         -quality (filters ESTs based on sequence quality)";
  print STDERR "                         -softmask ( softmask the polyA/T )\n";
  print STDERR "                         -min_length ( min_est_length, default = 100 )\n";
  exit(0);
}


my $seqin  = new Bio::SeqIO(-file   => "<$estfile",
			    -format => "Fasta",
			  );

my $seqout = new Bio::SeqIO(-file   => ">$seqoutfile", 
			    -format => "Fasta"
			   );

if ( $clip_ends ){
  print STDERR "clipping $clip_ends from both ends of ESTs\n";
}

my $quality_filter;

if ($quality) {
  print STDERR "removing low-quality sequences from EST dataset.\n";
  $quality_filter = 
    Bio::EnsEMBL::Pipeline::Tools::ESTFilter->new('-max_single_base_run' => 8);
}

SEQFETCH:
while( my $cdna = $seqin->next_seq ){

  next unless $cdna->length > $min_length;
  
  my $display_id  = $cdna->display_id;
  my $description = $cdna->desc;
  
  # First select the species:
  next SEQFETCH unless (   $description =~ /Homo sapiens/
			   || $description =~ /DNA.*coding.*human/
		       );
  
  if(  $description =~ /similar to/ || $description =~ /homolog/i ){
    
    next SEQFETCH unless ( $description =~ /Homo sapiens.*similar to/ 
			   || $description =~ /Homo sapiens.*homolog/i 
			 );
  }

  ############################################################
  # reject pseudogenes
  if ( $description =~ /pseudogene/i ){
    print STDERR "rejecting potential  pseudogene: $description\n";
    next SEQFETCH;
  }

  ############################################################
  # reject non-coding RNAs
  if ( $description =~/tRNA/i 
       && 
       !( $description =~/synthetase/i
	  ||
	  $description =~/protein/i
	  ||
	  $description =~/ligase/i
	)
     ){
    print STDERR "rejecting potential non-coding RNA: $description\n";
    next SEQFETCH;
  }
  
  ############################################################
  # reject cancer ESTs
  if ( $description =~/similar to/ ){
    
    if ( $description =~/carcinoma.*similar to/i 
	 ||
	 $description =~/cancer.*similar to/i
	 ||
	 $description =~/tumor.*similar to/i
       ){
      print STDERR "rejecting cancer EST: $description\n";
      next SEQFETCH;
    }
  }
  else{
    if ( $description =~/carcinoma/i 
	 ||
	 $description =~/cancer/i
	 ||
	 $description =~/tumor/i
       ){
      print STDERR "rejecting cancer EST: $description\n";
      next SEQFETCH;
    }
    
  }
  
  #print STDERR "keeping $description\n";

  ############################################################
  # parse description to get the id

  # GenBank
  if ( $display_id =~/gi\|\S+\|\S+\|(\S+\.\d+)\|/ || $description =~/gi\|\S+\|\S+\|(\S+\.\d+)\|/ ){
    $display_id = $1;
 
    if ($display_id =~ /NG/){
      print STDERR "rejecting $display_id\n";
      next SEQFETCH;
    }
  }
  # EMBL vert-RNA
  else{
    my @labels = split /\s+/, $description;
    $display_id = $labels[0];
  }
  
  $cdna->display_id($display_id);
  $cdna->desc("");
  
  if($@){
    warn("can't parse sequence for [$description]:\n$@\n");
    next SEQFETCH;
  }
  
  ############################################################
  # clipping? 
  my $polyA_clipper = Bio::EnsEMBL::Utils::PolyA->new();
  my $new_cdna;
  
  if ( $clip_ends ){
    my $seq = $cdna->seq;
    my $seq_length = length( $seq );
    
    # skip it if you are going to clip more than the actual length of the EST
    if ( 2*$clip_ends >= $seq_length ){
      next SEQFETCH;
    }
    #print STDERR "$description\n";
    #print STDERR "seq:$seq\n";
    #print STDERR "clip_ends:$clip_ends\n";
    #print STDERR "\n";
    my $new_seq = substr( $seq, $clip_ends, $seq_length - 2*$clip_ends );
    
    # skip it if you are left with an EST of less than 100bp
    if ( length( $new_seq ) < $min_length ){
      next SEQFETCH;
    }
    $new_cdna = new Bio::Seq;
    $new_cdna->display_id( $cdna->display_id );
    $new_cdna->seq($new_seq);
  }
  else{ 
    $new_cdna = $cdna;
  }
  
  my $new_new_cdna;
  if ($clip){
    #print STDERR "going to pass ".$new_cdna->display_id."\n";
    $new_new_cdna = $polyA_clipper->clip($new_cdna);
  }
  elsif( $softmask ){
    $new_new_cdna = $polyA_clipper->mask($new_cdna, 'soft');
  }
  else{
    $new_new_cdna = $new_cdna;
  }
  
  unless( $new_new_cdna ){
    next SEQFETCH;
  }

  # skip it if you are left with an EST of less than 100bp
  if ( length( $new_new_cdna->seq ) < 100 ){
    next SEQFETCH;
  }


  ############################################################
  # Apply the EST quality filter

  if ($quality) {
    if ($quality_filter->appraise($new_new_cdna)){
      $new_new_cdna = $quality_filter->filtered_seq;
    } else {
      next
    }
  }

  # write sequence
  $seqout->write_seq($new_new_cdna);
}


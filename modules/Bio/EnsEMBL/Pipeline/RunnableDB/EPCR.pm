#
#
# Cared for by Michele Clamp  <michele@sanger.ac.uk>
#
# Copyright Michele Clamp
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Pipeline::RunnableDB::EPCR

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::DBLoader->new($locator);
my $epcr   = Bio::EnsEMBL::Pipeline::RunnableDB::EPCR->new ( 
                                                    -dbobj      => $db,
			                                        -input_id   => $input_id
                                                    -analysis   => $analysis );
$epcr->fetch_input();
$epcr->run();
$epcr->output();
$epcr->write_output(); #writes to DB

=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Pipeline::Runnable::EPCR to add
functionality for reading and writing to databases. The appropriate
Bio::EnsEMBL::Analysis object must be passed for extraction
of appropriate parameters. A Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor
is required for databse access.

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Pipeline::RunnableDB::EPCR;

use strict;
use Bio::EnsEMBL::Pipeline::RunnableDB;
use Bio::EnsEMBL::Pipeline::Runnable::EPCR;

use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);

=head2 new

    Title   :   new
    Usage   :   $self->new(-DBOBJ       => $db
                           -INPUT_ID    => $id
                           -ANALYSIS    => $analysis);
                           
    Function:   creates a Bio::EnsEMBL::Pipeline::RunnableDB::EPCR object
    Returns :   A Bio::EnsEMBL::Pipeline::RunnableDB::EPCR object
    Args    :   -dbobj:     A Bio::EnsEMBL::DB::Obj, 
                -input_id:   Contig input id , 
                -analysis:  A Bio::EnsEMBL::Analysis 

=cut

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    
    $self->{'_fplist'}      = [];
    $self->{'_genseq'}      = undef;
    $self->{'_runnable'}    = undef;
    $self->{'_parameters'}  = undef;
    
    $self->throw("Analysis object required") unless ($self->analysis);
    
    # inheritance is tripping us up here
    &Bio::EnsEMBL::Pipeline::RunnableDB::EPCR::runnable($self,'Bio::EnsEMBL::Pipeline::Runnable::EPCR');
    return $self;
}

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for epcr from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
    my($self) = @_;
    
    $self->throw("No input id") unless defined($self->input_id);

    my $contigid  = $self->input_id;
    my $contig    = $self->dbobj->get_Contig($contigid);
    my $genseq    = $contig->primary_seq() or $self->throw("Unable to fetch contig");
    $self->genseq($genseq);
}

#get/set for runnable and args
sub runnable {
    my ($self, $runnable) = @_;
    my $arguments = "";

    # $self->analysis->parameters is a comma-delimited list.
    # Anything of the form a => b is passed to the runnable's new method.
    # Other text is given to the runnable as "options"
    
    if ($runnable)
    {
        #extract parameters into a hash
        my ($parameter_string) = $self->analysis->parameters() ;
        my %parameters;
        if ($parameter_string)
        {
            my @pairs = split (/,/, $parameter_string);
            foreach my $pair (@pairs)
            {
		# FIXME: must sort out this whitespace issue
		my ($key, $value) = split (/=>/, $pair);
		if ($key && $value) {
                    $value =~ s/^\s+//g;
                    $value =~ s/\s+$//g;
                    $key =~ s/^\s+//g;
                    $key =~ s/\s+$//g;
		    $parameters{$key} = $value;
		}
		else
		{
		    $arguments .= " $key ";
		}
            }
        }
        $parameters {'-db'}      = $self->analysis->db_file();  
        $parameters {'-options'} = $arguments;
        $parameters {'-pcr'}     = $self->analysis->program_file();  
        #creates empty Bio::EnsEMBL::Runnable::EPCR object
        $self->{'_runnable'} = $runnable->new(%parameters);
    }
    return $self->{'_runnable'};
}

=head2 fetch_output

    Title   :   fetch_output
    Usage   :   $self->fetch_output($file_name);
    Function:   Fetches output data from a frozen perl object
                stored in file $file_name
    Returns :   array of repeats (with start and end)
    Args    :   none

=cut


1;

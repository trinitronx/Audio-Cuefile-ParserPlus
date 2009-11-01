package Audio::Cuefile::ParserPlus;
use strict;
use warnings;
use diagnostics;
use File::Basename;
use 5.010;

BEGIN {
    use Exporter ();
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    $VERSION     = '0.01';
    @ISA         = qw(Exporter);
    #Give a hoot don't pollute, do not export more than needed by default
    @EXPORT      = qw();
    @EXPORT_OK   = qw();
    %EXPORT_TAGS = ();
}

#################### main pod documentation begin ###################
## Below is the stub of documentation for your module. 
## You better edit it!


=head1 NAME

Audio::Cuefile::ParserPlus - Class to read, write & manipulate CUE files

=head1 SYNOPSIS

  use Audio::Cuefile::ParserPlus;
  Class to parse a cuefile and access all available data within.
  Can print track list, output cue files, or return a Audio::Cuefile::ParserPlus object


=head1 DESCRIPTION

  Audio::Cuefile::ParserPlus was built using the CUE sheet file specification 
  found at: 
    http://digitalx.org/cuesheetsyntax.php
  The internal data structure organizes the CUE sheet commands mainly by what are 
  considered 'global' attributes and those specific to a single 'TRACK'.
  To print track specific attributes, use the printTracks() method.


=head1 USAGE

 use Audio::Cuefile::ParserPlus;

 $filepath = 'filename.cue';

 # Create an empty object & read a file with readCUE()
 my $cuefile = new Audio::Cuefile::ParserPlus();
 $cuefile->readCUE($filepath);
 # OR specify the file in the constructor:
 my $other_cuefile = new Audio::Cuefile::ParserPlus($filepath);
 
 # Print the track data
 $cuefile->printTracks();
 $other_cuefile->printTracks();
 
=head1 CLASS DOCUMENTATION
 
 Here is some more detailed information about using the class:
 
=head2 Static Package Variables
 
 
 @AUDIO::Cuefile::ParserPlus::CUESHEET_COMMANDS
        - Array containing track specific cuesheet 
          commands in the order we want to print them 
          in (using printTracks)
 $AUDIO::Cuefile::ParserPlus::DEBUG
        - Turn debugging output on
 
=cut
 
#################### main pod documentation end ###################

## Constructor
sub new
{
	my $class = shift;
	my $CUEfilepath = shift;
	
	@AUDIO::Cuefile::ParserPlus::CUESHEET_COMMANDS = qw(
		track datatype file filetype flags performer title songwriter pregap isrc index postgap
		);
	$AUDIO::Cuefile::ParserPlus::DEBUG = 0;
	
	my $self = bless (
	{
		CUEfilepath => $CUEfilepath,
		file => undef,
		filetype => undef,
		cdtextfile => undef,
		title => undef,
		performer => undef,
		catalog => undef,
		tracks => undef
	}, ref ($class) || $class);
	
	if (defined($CUEfilepath) && -e $CUEfilepath)
	{
		# Get the file path, name and suffix
		my ( $name, $path, $suffix ) = File::Basename::fileparse( $CUEfilepath, qr/\.[^.]*/ );
		readCUE($self, $CUEfilepath); # Read & set all attributes in the object!
	}
	
	return $self; # since we blessed it above, need to return self
}

#################### subroutine header begin ####################
 
 
=head2 readCUE

 Usage     : $cuefileparser->readCUE('path/to/cuefile.cue');
 Purpose   : Gives the parse a CUE sheet to read & parse
 Returns   : Nothing! (Sets all member variables however)
 Argument  : What it wants to know
 Throws    : Nothing yet!
 Comment   : After using readCUE(), you may access the member variables
           : that it sets as public properties for ease of use.

See Also   : 

=cut

#################### subroutine header end ####################

sub readCUE
{
	my ($self) = shift;
	my ($filepath) = shift;
	
	if (!defined($self->{CUEfilepath}) && defined($filepath) && -e $filepath)
	{
		$self->{CUEfilepath} = $filepath;
	}
	
	my $src_cue = openStripCUE($filepath);
	
	my %cuesheet; # a hash to contain the cuesheet's global commands, and the @tracks array
	my @tracks; # this will be an array of hashes containing parsed data on each track
	my $i = 0;
	
	my %rgx_CUE_global; # hash to hold regex patterns for commands global to the CUE file
	my %rgx; # hash to hold regex patterns for commands that must be within a TRACK/INDEX block
	
	# Large gory match for the TRACK/INDEX block for each track
	# Note that the POSTGAP cmd is optional
	# Since we must treat storing these match captures differently, don't put it in %rgx
	$rgx_CUE_global{'track_index_block'} = qr!TRACK\s+(?<track>\d{2})\s+ # match the track cmd, capture number
								    (?<datatype>AUDIO|CDG|MODE1/2048|MODE1/2352|MODE2/2336|MODE2/2352|CDI/2336|CDI/2352) # match the track datatype
									(?<stuff>.+?) # match other stuff inside block to do more matches later
									INDEX\s+\d{2}\s+(?<index>(?<mins>\d{1,3}):(?<secs>\d{2}):(?<frames>\d{2}))\s+ # match the INDEX cmd, capture mins:secs:frames
									(POSTGAP\s+(?<postgap>(?<pgap_mins>\d{1,3}):(?<pgap_secs>\d{2}):(?<pgap_frames>\d{2})))? # optional match for postgap
									!smx;
	$rgx_CUE_global{'cdtextfile'} = qr/\s*CDTEXTFILE\s+"?(?<cdtextfile>[^"]*)"?/;
	$rgx_CUE_global{'performer'} = qr/\s*PERFORMER\s+"?(?<performer>[^"]*)"/;
	$rgx_CUE_global{'title'} = qr/\s*TITLE\s+"?(?<title>[^"]*)"?/;
	$rgx_CUE_global{'songwriter'} = qr/\s*SONGWRITER\s+"?(?<songwriter>[^"]*)"?/;
	$rgx_CUE_global{'file'} = qr/\s*FILE\s+"?(?<file>[^"]*)"?\s+(?<filetype>BINARY|MOTOROLA|AIFF|WAVE|MP3)/;
	$rgx_CUE_global{'filetype'} = $rgx_CUE_global{'file'};
	$rgx_CUE_global{'catalog'} = qr/\s*CATALOG\s+(?<catalog>\d{13})/;
	
	$rgx{'file'} = $rgx_CUE_global{'file'}; # same as above
	$rgx{'filetype'} = $rgx{'file'}; # quick hack so the generic matching loop below can work easily
	$rgx{'flags'} = qr/\s*FLAGS\s+(?<flags>.*?)/;
	$rgx{'performer'} = $rgx_CUE_global{'performer'}; #use same regexes
	$rgx{'title'} = $rgx_CUE_global{'title'};
	$rgx{'songwriter'} = $rgx_CUE_global{'songwriter'};
	$rgx{'pregap'} = qr/\s*PREGAP\s+(?<pregap>(?<mins>\d{1,3}):(?<secs>\d{2}):(?<frames>\d{2}))/;
	$rgx{'isrc'} = qr/\s*ISRC\s+(?<isrc>[a-zA-Z]{5}\d{7})/; # the "International Standard Recording Code"
	
	
	# First, grab the global matches for the cue file
	while ( my ($key, $value) = each(%rgx_CUE_global))
	{
		if (!($key =~ m/track_index_block/))
		{
			if ( $src_cue =~ m/$value/ )
			{
				if ($AUDIO::Cuefile::ParserPlus::DEBUG)
				{
					print "Looking for CUE global: $key \n";
					print 'trying to set: $self->{'.$key.'} = ' . $+{$key} . "\n\n";
				}
				
				my $match = $+{$key};
				# if there is no preceding TRACK command, it's a global parameter
				# we should set it!
				if ( !($` =~ m/TRACK\s+(\d{2})/) )
				{
					$self->{$key} = $match;
				}
			}
		}
	}
	# Now start matching TRACK blocks, and extract the info we need
	# Since we don't know the order of the PERFORMER & TITLE commands, 
	#  we'll just capture that as 'stuff', and do another match on it
	while( $src_cue =~ m/$rgx_CUE_global{'track_index_block'}/g)
	{
		if ($Audio::Cuefile::ParserPlus::DEBUG)
		{
			print "------------------------\n";
			print "MATCH #$i: \n" . $& . "\n\n";
			print scalar(keys %+) . "\n";
			while (my ($key, $value) = each(%+))
			{
		     print $key." = ";
		     print $value."\n";
			}
			print "\n";
		}
		
		$tracks[$i]{'track'} = $+{'track'};
		$tracks[$i]{'datatype'} = $+{'datatype'};
		$tracks[$i]{'index'} = $+{'index'};
		if (defined $+{'postgap'})
		{
			$tracks[$i]{'postgap'} = $+{'postgap'};
		}
		# get the rest of the stuff for each track/index block
		my $stuff = $+{'stuff'};
		
		# The magical matching loop!
		foreach my $key (@AUDIO::Cuefile::ParserPlus::CUESHEET_COMMANDS)
		{
			if ( defined($rgx{$key}) && $stuff =~ m/$rgx{$key}/)
			{
				$tracks[$i]{$key} = $+{$key};
			}
		}
		$i++;
	}
	
	$self->{tracks} = \@tracks;
}

#################### subroutine header begin ####################

=head2 printTracks

 Usage     : $cuefileparser->printTracks();
 Purpose   : Print the parsed cue sheet @tracks array of hashes
 Returns   : Nothing! (prints output to console)
 Constraint: Must have loaded a CUE sheet with readCUE first if you 
           : expect any output!
 Throws    : Nothing
 Comment   : 
           : 

See Also   : 

=cut

#################### subroutine header end ####################

# Function to print the parsed cue sheet @tracks array of hashes
# Takes an array of hashes representing a cuesheet (as created by readCUE)
sub printTracks
{
	my ($self) = shift;
	
	print "PARSED CUE SHEET: \n";
	#my @tracks = @{ $self->{tracks} }; # don't use local var anymore
	
	my $track_no = scalar( @{ $self->{tracks} } );
	for (my $i=0; $i < $track_no; $i++)
	{
		print "tracks[$i]\n";
		# Print the data we've got for the tracks in the order
		# specified in the CUESHEET_COMMANDS array
		foreach my $key (@AUDIO::Cuefile::ParserPlus::CUESHEET_COMMANDS)
		{
			if (defined $self->{tracks}[$i]{$key})
			{
				printf "\t%-15s = %-s\n", $key, $self->{tracks}[$i]{$key};
			}
		}
	}
}

#################### subroutine header begin ####################

=head2 openStripCUE

 Usage     : Meant for private use within Audio::Cuefile::ParserPlus
 Purpose   : Utility function to open & read entire CUE file, stripping
           : any REM comments or blank lines.
 Returns   : String containing the stripped CUE file.
 Argument  : filepath = path to a CUE sheet file.
 Throws    : Nothing yet! (TODO: file IO exceptions)
 Comment   : 
           : 

See Also   : 

=cut

#################### subroutine header end ####################

# Private utility function to read in a CUE file and output it as a string
# Strips empty lines and REM comments (to avoid matching problems later)
sub openStripCUE
{
	my ($filepath) = shift;
	
	open(FILE, $filepath) or die ("Could not open $filepath!\n");
	my $file = "";
	# Read data from the source CUE file
	while(<FILE>)
	{
		if (m/^\s*REM.*$/i)
		{
			# Do nothing for comments
		}
		elsif (m/^[\r\n+]$/i)
		{
			# Do nothing for empty lines
		}
		else
		{
			$file .= $_; # append the line to the src string
		}
	}
	return $file;
}

#################### rest-of-main pod documentation begin ####################
=head1 BUGS

 Doesn't support multi-file CUE sheets yet! (TODO!)

 CUE file output support not added yet! (TODO!!!)

=head1 SUPPORT

This module is provided as is, use at your own risk.  If you *really* need help, 
then you can email me at: jcuzella@lyraphase.com, or my website http://www.lyraphase.com/ 

=head1 AUTHOR

    James Cuzella
    CPAN ID: JCUZELLA
    .:[ HoTSC ]:.
    jcuzella@lyraphase.com
    http://www.lyraphase.com/

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

perl(1).

=cut
#################### rest-of-main pod documentation end ####################

1; # End of Audio::Cuefile::Parser
# The preceding line will help the module return a true value


# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 2;

BEGIN { use_ok( 'Audio::Cuefile::ParserPlus' ); }

my $object = Audio::Cuefile::ParserPlus->new ();
isa_ok ($object, 'Audio::Cuefile::ParserPlus');



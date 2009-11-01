

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Audio::Cuefile::ParserPlus',
    VERSION_FROM => 'lib/Audio/Cuefile/ParserPlus.pm', # finds \$VERSION
    AUTHOR       => 'James Cuzella (jcuzella@lyraphase.com)',
    ABSTRACT     => 'Class to read, write & manipulate CUE files',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
                    },
);

use ExtUtils::MakeMaker;
WriteMakefile( NAME         => "Music::Tag",
               VERSION_FROM => "lib/Music/Tag.pm",
               ABSTRACT     => 'Routines to edit tags of sound files',
               AUTHOR       => 'Edward Allen (edwardallenthethird@hotmail.com)',
               EXE_FILES    => [
                              'bin/autotag',   'bin/safetag', 'bin/quicktag', 'bin/musictag',
                              'bin/musicsort', 'bin/musicinfo'
                            ],
               PREREQ_PM => { 'MP3::Info'                     => '.9701',
                              'WebService::MusicBrainz'       => '0.06',
                              'Net::Amazon'                   => '.35',
                              'Audio::FLAC::Header'           => '1.4',
                              'Cache::Cache'                  => '1.05',
                              'HTML::Parser'                  => '3.56',
                              'LWP'                           => '0.01',
                              'MP3::Tag'                      => '0.01',
                              'MP4::Info'                     => '0.01',
                              'Net::Amazon'                   => '0.01',
                              'Ogg::Vorbis::Header::PurePerl' => '0.01',
                              'URI::Escape'                   => '0.01',
                              'URI::WithBase'                 => '0.01',
                            },
             );


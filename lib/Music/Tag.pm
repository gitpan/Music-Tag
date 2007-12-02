package Music::Tag;

# Copyright (c) 2007 Edward Allen III. All rights reserved.
#
## This program is free software; you can redistribute it and/or
## modify it under the terms of the Artistic License, distributed
## with Perl.
#

=pod

=head1 NAME

Music::Tag - Module for collecting information about music files.

=head1 SYNOPSIS

use Music::Tag;

my $info = Music::Tag->new($filename);
   
# Read basic info

$info->get_tag();
   
print "Performer is ", $info->artist();
print "Album is ", $info->album();
print "Release Date is ", $info->releasedate();

# Change info
   
$info->artist('Throwing Muses');
$info->album('University');
   
# Augment info from online database!
   
$info->add_plugin("MusicBrainz");
$info->add_plugin("Amazon");

$info->get_tag;

print "Record Label is ", $info->label();

# Save back to file

$info->set_tag();
$info->close();

=head1 AUTHOR

Edward Allen, ealleniii _at_ cpan _dot_ org

=head1 DESCRIPTION

The motiviation behind this was to provide a convenient method for fixing broken tags.

This module is a wrapper module, which calls various plugin modules to find information about a music file and write it back into the tag. 

=cut

use strict qw(vars);
use Carp;
use Locale::Country;
use File::Spec;
use Encode;
use Config::Options;
use Digest::SHA1;
use utf8;
our $VERSION = 0.23;

use vars qw($AUTOLOAD);

=pod

=over 4

=head1 METHODS

=item new()

my $info = Music::Tag->new($filename, [ $options ], [ "PLUGIN" ] ) ;

Takes a filename, a hashref of options, and an optonal first plugin and returns a new Music::Tag object. 

If no plugin is listed, then it will automatically add the appropriate file plugin based
on the extension. If it can't do that, it will return undef. Please note that when a plugin
is added, the plugin's get_tag method is immediatly called. If you are the kind of person who
uses ID3v2 and ID3v1 tags for everything, then use "MP3" as an option here to prevent it from
trying to use iTunes tags for you .m4a files.
 
Options are global (apply to all plugins) and default (can be overridden).
Plugin specific options can be applied here, if you wish. They will be ignored by
plugins that don't know what to do with them. See the POD for each plugins for more
details on options a particular plugin accepts.

Current global options include:

=over 4

=item verbose

Default is false. Setting this to true causes plugin to generate a lot of noise.

=item quiet

Default is false. Setting this to true causes prevents the plugin from giving status messages.

=back

=cut

sub default_options {
    {  verbose       => 0,
       quiet         => 0,
       ANSIColor     => 1,
       LevenshteinXS => 1,
       Levenshtein   => 1,
       Unaccent      => 1,
       Inflect       => 1,
       Stem          => 0,
       StemLocale    => "en-us",
       optionfile    => [ "/etc/musictag.conf", $ENV{HOME} . "/.musictag.conf" ],
    };
}

sub new {
    my $class    = shift;
    my $filename = shift;
    my $options  = shift || {};
    my $plugin   = shift;
    my $self     = {};
    if ( ref $class ) {
        my $clone = {%$class};
        bless $clone, ref $class;
        return $clone;
    }
    else {
        bless $self, $class;
        $self->{_plugins} = [];
        $self->options( $self->default_options );
        $self->options->fromfile_perl();
        $self->options($options);
        $self->filename($filename);
    }
    if ( $self->options->{ANSIColor} ) {
        eval { require Term::ANSIColor; };
        if ($@) {
            warn "Couldn't load ANSIColor: $@\n";
            $self->options->{ANSIColor} = 0;
        }
    }
    if ( $self->options->{LevenshteinXS} ) {
        eval { require Text::LevenshteinXS; };
        if ($@) {
            warn "Couldn't load LevenshteinXS: $@\n";
            $self->options->{LevenshteinXS} = 0;
        }
        $self->options->{Levenshtein} = 0;
    }
    elsif ( $self->options->{Levenshtein} ) {
        eval {
            if ($@) {
                warn "Couldn't load Levenshtein: $@\n";
                $self->options->{Levenshtein} = 0;
            }
        };
    }
    if ( $self->options->{Unaccent} ) {
        eval { require Text::Unaccent; };
        if ($@) {
            warn "Couldn't load Text::Unaccent: $@\n";
            $self->options->{Unaccent} = 0;
        }
    }
    if ( $self->options->{Inflect} ) {
        eval { require Lingua::EN::Inflect; };
        if ($@) {
            warn "Couldn't load Lingua::EN::Inflect: $@\n";
            $self->options->{Inflect} = 0;
        }
    }
    if ( $self->options->{Stem} ) {
        eval { require Lingua::Stem; };
        if ($@) {
            warn "Couldn't load Lingua::Stem: $@\n";
            $self->options->{Stem} = 0;
        }
        Lingua::Stem::set_locale( $self->options->{StemLocale} );
    }
    if ($plugin) {
        $self->add_plugin( $plugin, $options );
        return $self;
    }
    else {
        return $self->auto_plugin($options);
        return undef;
    }
}

=pod

=item add_plugin()

my $plugin = $info->add_plugin("PLUGIN", $options)

Takes a plugin name and optional set of options and it to a the Music::Tag object. Returns reference to a new plugin object.

$options is a hashref that can be used to override the global options for a plugin.

Current plugins include L<MP3|Music::Tag::MP3>, L<OGG|Music::Tag::OGG>, L<FLAC|Music::Tag::FLAC>, L<M4A|Music::Tag::M4A>, L<Amazon|Music::Tag::Amazon>, L<File|Music::Tag::File>, and L<MusicBrainz|Music::Tag::MusicBrainz>. Additional plugins can be created. See <L/Plugin Syntax> for information.

First option can be an string such as "MP3" in which case Music::Tag::MP3->new($self, $options) is called,an object name such as "Music::Tag::Custom::MyPlugin" in which case Music::Tag::MP3->new($self, $options) is called. It can also be an object.

Options can also be included in the string, as in Amazon;locale=us;trust_title=1.

=cut

sub auto_plugin {
    my $self     = shift;
    my $options  = shift;
    my $filename = $self->filename;
    my $plugin   = "";

    if ( $filename =~ /\.mp3$/i ) {
        $plugin = "MP3";
    }
    elsif ( $filename =~ /\.m4a$/i ) {
        $plugin = "M4A";
    }
    elsif ( $filename =~ /\.m4p$/i ) {
        $plugin = "M4A";
    }
    elsif ( $filename =~ /\.mp4$/i ) {
        $plugin = "M4A";
    }
    elsif ( $filename =~ /\.m4b$/i ) {
        $plugin = "M4A";
    }
    elsif ( $filename =~ /\.ogg$/i ) {
        $plugin = "OGG";
    }
    elsif ( $filename =~ /\.flac$/i ) {
        $plugin = "FLAC";
    }
    if ($plugin) {
        $self->add_plugin( $plugin, $options );
        return $self;
    }
    else {
        warn "Sorry, I can't find a plugin for $filename\n";
        return undef;
    }
}

sub add_plugin {
    my $self    = shift;
    my $object  = shift;
    my $opts    = shift || {};
    my $options = $self->options->clone->options($opts);
    my $type    = shift || 0;

    my $ref;
    if ( ref $object ) {
        $ref = $object;
        $ref->info($self);
        $ref->options($options);
    }
    else {
        my ( $plugin, $popts ) = split( ":", $object );
        if ($popts) {
            my @opts = split( /[;]/, $popts );
            foreach (@opts) {
                my ( $k, $v ) = split( "=", $_ );
                $options->{$k} = $v;
            }
        }
        eval {
            eval { require "Music/Tag/${plugin}.pm" };
            unless ( $plugin =~ /::/ ) {
                $plugin = "Music::Tag::" . $plugin;
            }
            $ref = $plugin->new( $self, $options );
        };
        warn $@ if $@;
    }
    if ($ref) {
        push @{ $self->{_plugins} }, $ref;
    }
    return $ref;
}

=pod

=item plugin()

my $plugin = $item->plugin("MP3")->strip_tag();

The plugin method takes a regular expression as a string value and returns the first plugin whose package name matches the regular expression. Used to access package methods directly. Please see <L/PLUGINS> section for more details on standard plugin methods.

=cut

sub plugin {
    my $self   = shift;
    my $plugin = shift;
    if ( defined $plugin ) {
        foreach ( @{ $self->{_plugins} } ) {
            if ( ref($_) =~ /$plugin$/ ) {
                return $_;
            }
        }
    }
    else {
        return $self->{_plugins};
    }
}

=pod

=item get_tag()

$info->get_tag();

get_tag applies all active plugins to the current tag object in the order that the plugin was added. Specifically, it runs through the list of plugins and performs the get_tag() method on each. 

=cut

sub get_tag {
    my $self = shift;
    foreach ( @{ $self->{_plugins} } ) {
        if ( ref $_ ) {
            $_->get_tag();
        }
        else {
            warn "Invalid Plugin in list: $_\n";
        }
    }
    return $self;
}

=pod

=item set_tag()

$info->set_tag();

set_tag writes info back to disk for all tags, or submits info if appropriate. Specifically, it runs through the list of plugins and performs the set_tag() method on each.

=cut

sub set_tag {
    my $self = shift;
    foreach ( @{ $self->{_plugins} } ) {
        if ( ref $_ ) {
            $_->set_tag();
        }
        else {
            warn "Invalid Plugin in list!\n";
        }
    }
    return $self;
}

=pod

=item strip_tag()

$info->strip_tag();

strip_tag removes info from on disc tag for all plugins. Specifically, it performs the strip_tag methd on all plugins in the order added.

=cut

sub strip_tag {
    my $self = shift;
    foreach ( @{ $self->{_plugins} } ) {
        if ( ref $_ ) {
            $_->strip_tag();
        }
        else {
            warn "Invalid Plugin in list!\n";
        }
    }
    return $self;
}

=pod

=item close()

$info->close();

closes active filehandles on all plugins. Should be called before object destroyed.

=cut

sub close {
    my $self = shift;
    foreach ( @{ $self->{_plugins} } ) {
        if ( ref $_ ) {
            $_->close(@_);
            $_->{info} = undef;
            $_ = undef;
        }
        else {
            warn "Invalid Plugin in list!\n";
        }
    }
    $self = undef;
}

=pod

=item changed()

$ischanged = $info->changed($new);

Returns true if changed. Optional value $new sets changed set to True of $new is true. A "change" is any tag additions done by MusicBrainz, Amazon, or File plugins.

=cut

sub changed {
    my $self = shift;
    my $new  = shift;
    if ( defined $new ) {
        $self->{changed}++;
    }
    return $self->{changed};
}

=pod

=item options()

my $verbose = $info->options("verbose");
my $verbose = $info->options->{verbose};
$info->options("verbose", 0);
$info->options->{verbose} = 0;

This method is used to access or change the options. When called with no options, returns a reference to the options hash. When called with one string option returns the value for that key. When called with one hash value, merges hash with current options. When called with 2 options, the first is a key and the second is a value and the ket gets set to the value. This method is for global options.

=cut

sub options {
    my $self = shift;
    if ( exists $self->{_options} ) {
        return $self->{_options}->options(@_);
    }
    else {
        $self->{_options} = Config::Options->new();
        return $self->{_options}->options(@_);
    }
}

sub setfileinfo {
	my $self = shift;
	if ($self->filename) {
		my @stat = stat $self->filename;
		$self->mtime($stat[9]);
		$self->bytes($stat[7]);
	}
}

sub sha1 {
   my $self = shift;
   return unless (($self->filename) && (-e $self->filename ));
   my $maxsize = 4 * 4096;
   open (IN, $self->filename) or die "Bad file: $self->filename\n";
   my @stat = stat $self->filename;
   my $sha1 = Digest::SHA1->new();
   $sha1->add(pack("V",$stat[7]));
   my $d;
   if (read(IN, $d, $maxsize)) {
      $sha1->add($d);
   }
   CORE::close(IN);
   return $sha1->hexdigest;
}


=pod

=item datamethods()

Returns a list of all data methods supported.

=cut

our @DATAMETHODS = qw(artist album title comment secs duration tracknum year releasedate sortname mb_artistid mb_albumid mb_trackid album_type artist_type lyrics picture url genre disc track discnum totaldiscs totaltracks tempo label encoder frequency bitrate compilation composer copyright rating lastplayed playcount filename asin stereo bytes mtime codec frames framesize vbr appleid recorddate country mip_puid originalartist countrycode artist_start artist_end encoded_by songkey artkey albkey albumid songid artistid path user ipod ipod_location ipod_trackid ipod_dbid disctitle booklet pregap postgap samplecount gaplessdata);

sub datamethods {
	return \@DATAMETHODS;
}

=pod

=head2 Data access methods

These methods are used to access the tag info. Not all methods are supported by all plugins. In fact, no single plugin supports all methods (yet). Each of these is an accessort function. If you pass it a value, it will set the variable. It always returns the value of the variable. It can return undef.

=cut


# This method is far from perfect.  It can't be perfect.
# It won't mangle valid UTF-8, however.
# Just be sure to always return perl utf8 in plugins when possible.

sub _isutf8 {
	my $self = shift;
	my $in = shift;
	# If it is a proper utf8, with tag, just return it.
	if (Encode::is_utf8($in,1)) {
		return $in;
	}

	my $has7f = 0;
	foreach (split(//, $in)) {
		if (ord($_) >= 0x7f) {
			$has7f++;
		}
	}
	# No char >7F it is prob. valid ASCII, just return it.
	unless ($has7f) {
		return $in;
	}

	# See if it is a valid UTF-16 encoding.
	#my $out;
	#eval {
	#	$out = decode("UTF-16", $in, 1);
	#};
	#return $out unless $@;

	# See if it is a valid UTF-16LE encoding.
	#my $out;
	#eval {
	#	$out = decode("UTF-16LE", $in, 1);
	#};
	#return $out unless $@;

	# See if it is a valid UTF-8 encoding.
	my $out;
    eval {
		$out = decode("UTF-8", $in, 1);
	};
	return $out unless $@;

	# Finally just give up and return it.
	
	return $in;
}
    

sub _accessor {
    my $self    = shift;
    my $attr    = shift;
    my $value   = shift;
    my $default = shift;
    unless ( exists $self->{ uc($attr) } ) {
        $self->{ uc($attr) } = undef;
    }
    if ( defined $value ) {
		$value = $self->_isutf8($value);
        if ( $self->options('verbose') ) {
            $self->status( "VERBOSE:  Setting $attr to ",
                           ( defined $value ) ? $value : "UNDEFINED" );
        }
        $self->{ uc($attr) } = $value;
    }
    if ( ( defined $default ) && ( not defined $self->{ uc($attr) } ) ) {
        $self->{ uc($attr) } = $default;
    }
    return $self->{ uc($attr) };
}

=pod
=item album

The title of the release.

=item album_type

The type of the release. Specifically, the MusicBrainz type (ALBUM OFFICIAL, etc.) 

=item albumartist

The artist responsible for the album. Usually the same as the artist, and will return the value of artist if unset.

=cut

sub albumartist {
    my $self = shift;
    my $new  = shift;
    return $self->_accessor( "albumartist", $new, $self->artist() );
}

=pod

=item artist

The artist responsible for the track.

=item artist_type

The type of artist. Usually Group or Person.

=item asin

The Amazon ASIN number for this album.

=item bitrate

Enconding bitrate.

=item booklet

URL to a digital booklet. Usually in PDF format. iTunes passes these out sometimes, or you could scan a booklet
and use this to store value. URL is assumed to be realtive to file location.

=item comment

A comment about the track.

=item compilation

True if album is Various Artist, false otherwise.  Don't set to true for Best Hits.

=item composer

Composer of song.

=item copyright

A copyright message can be placed here.

=cut

sub country {
    my $self = shift;
    my $new  = shift;
    if ( defined($new) ) {
        if ( $self->options('verbose') ) {
            $self->status( "VERBOSE:  Setting country  to ",
                           ( defined $new ) ? $new : "UNDEFINED" );
        }
        $self->{COUNTRYCODE} = country2code($new);
    }
    if ( $self->countrycode ) {
        return $self->code2country( $self->countrycode );
    }
    return undef;
}

=pod

=item disc

In a multi-volume set, the disc number.

=item disctitle

In a multi-volume set, the title of a disc.

=item discnum

The disc number and optionally the total number of discs, seperated by a slash. Setting it sets the disc and totaldiscs values (and vice-versa).

=cut

sub discnum {
    my $self = shift;
    my $new  = shift;
    if ( defined($new) ) {
        if ( $self->options('verbose') ) {
            $self->status( "VERBOSE:  Setting discnum  to ",
                           ( defined $new ) ? $new : "UNDEFINED" );
        }
        my ( $t, $tt ) = split( "/", $new );
        my $r = "";
        if ($t) {
            $self->disc($t);
            $r .= $t;
        }
        if ($tt) {
            $self->totaldiscs($tt);
            $r .= "/" . $tt;
        }
        $self->{DISCNUM} = $r;
    }
    my $ret = $self->disc();
    if ( $self->totaldiscs ) {
        $ret .= "/" . $self->totaldiscs;
    }
    return $ret;
}


=pod

=item duration

The length of the track in milliseconds. Returns secs * 1000 if not set. Changes the value of secs when set.

=cut

sub duration {
    my $self = shift;
    my $new  = shift;
    if ( defined($new) ) {
        if ( $self->options('verbose') ) {
            $self->status( "VERBOSE:  Setting duration  to ",
                           ( defined $new ) ? $new : "UNDEFINED" );
        }
        $self->{DURATION} = $new;
        $self->{SECS}     = int( $new / 1000 );
    }
    if ( ( exists $self->{DURATION} ) && ( $self->{DURATION} ) ) {
        return $self->{DURATION};
    }
    elsif ( ( exists $self->{SECS} ) && ( $self->{SECS} ) ) {
        return $self->secs * 1000;
    }
}

=pod

=item encoder

The codec used to encode the song.

=item filename

The filename of the track.

=cut

sub filename {
    my $self = shift;
    my $new  = shift;
    if ( defined($new) ) {
        my $file = $new;
        if ($new) {
            $file = File::Spec->rel2abs($new);
        }
        if ( $self->options('verbose') ) {
            $self->status( "VERBOSE:  Setting filename  to ",
                           ( defined $file ) ? $file : "UNDEFINED" );
        }
        $self->{filename} = $file;
    }
    return $self->{filename};

}

=item filedir

The path that music file is located in.

=cut

sub filedir {
	my $self = shift;
	if ($self->filename) {
		my ($vol, $path, $file) = File::Spec->splitpath($self->filename);
		return File::Spec->catpath($vol, $path, "");
	}
	return undef;
}


=pod


=item frequency

The frequency of the recording (in Hz).

=item genre

The genre of the song. Various tags use this field differently, so it may be lost.

=item label

The label responsible for distributing the recording.

=item lyrics

The lyrics of the recording.

=item mb_albumid

The MusicBrainz database ID of the album or release object.

=item mb_artistid

The MusicBrainz database ID for the artist.

=item mb_trackid

The MusicBrainz database ID for the track.

=item picture

A hashref that contains the following:

{
   "MIME type"     => The MIME Type of the picture encoding
   "Picture Type"  => What the picture is off.  Usually set to 'Cover (front)'
   "Description"   => A short description of the picture
   "_Data"	       => The binary data for the picture.
   "filename"	   => A filename for the picture.  Data overrides "_Data" and will
   				      be returned as _Data if queried.  Filename is calculated as relative
					  to the path of the music file as stated in "filename" or root if no
					  filename for music file available.
}


Note hashref MAY be generated each call.  Do not modify and assume tag will be modified!

=cut

sub _binslurp {
    my $file = shift;
    local *IN;
    open( IN, $file ) or die "Couldn't open $file: $!";
    my $ret;
    my $off = 0;
    while ( my $r = read IN, $ret, 1024, $off ) { last unless $r; $off += $r }
    return $ret;
}

sub picture {
    my $self = shift;
    unless ( exists $self->{PICTURE} ) {
        $self->{PICTURE} = {};
    }
    $self->{PICTURE} = shift if @_;

	if ( (exists $self->{PICTURE}->{filename}) && ($self->{PICTURE}->{filename})) {
		my $root = File::Spec->rootdir();
		if ($self->filename) {
			$root = $self->filedir;
		}
		my $picfile = File::Spec->rel2abs($self->{PICTURE}->{filename}, $root);
		if (-f $picfile) {
			if ($self->{PICTURE}->{_Data}) { 
				 delete $self->{PICTURE}->{_Data} 
			}
			my %ret = %{$self->{PICTURE}}; # Copy ref
			$ret{_Data} = _binslurp($picfile);
			return \%ret;
		}
	}
    elsif (    ( exists $self->{PICTURE}->{_Data} )
         && ( length $self->{PICTURE}->{_Data} ) ) {
        return $self->{PICTURE};
    }
    else {
        return undef;
    }
}

=pod

=item picture_filename

Returns filename used for picture data.  If no filename returns 0.  If no picture returns undef.

=cut

sub picture_filename {
    my $self = shift;
	if ((exists $self->{PICTURE}) && ($self->{PICTURE}->{filename})) {
		return $self->{PICTURE}->{filename};
	}
	elsif ((exists $self->{PICTURE}) && ($self->{PICTURE}->{_Data}) && (length($self->{PICTURE}->{_Data}))) {
		return 0;
	}
	else {
		return undef;
	}
}

=pod

=item picture_exists

Returns true if tag has picture data (or filename), false if not.  Convenience method to prevant reading the file. 
Does check for existense of picture file, however.


=cut

sub picture_exists {
    my $self = shift;
	if ( (exists $self->{PICTURE}->{filename}) && ($self->{PICTURE}->{filename})) {
		my $root = File::Spec->rootdir();
		if ($self->filename) {
			$root = $self->filedir;
		}
		my $picfile = File::Spec->rel2abs($self->{PICTURE}->{filename}, $root);
		if (-f $picfile) {
			return 1;
		}
		else {
			$self->status("Picture: ", $picfile, " does not exists");
		}
	}
    elsif (    ( exists $self->{PICTURE}->{_Data} )
         && ( length $self->{PICTURE}->{_Data} ) ) {
        return 1; 
    }
    else {
        return undef;
    }
}

=pod
=item rating

The rating (value is 0 - 100) for the track.

=item releasedate

The release date in the form YYYY-MM-DD. Months and days can be left off.

=item secs

The number of seconds in the recording.

=item sortname

The name of the sort-name of the artist (e.g. Hersh, Kristin or Throwing Muses, The)

=item tempo

The tempo of the track

=item title

The name of the song.

=item totaldiscs

The total number of discs, if a multi volume set.

=item totaltracks

The total number of tracks on the album.

=item track

The track number

=item tracknum

The track number and optionally the total number of tracks, seperated by a slash. Setting it sets the track and totaltracks values (and vice-versa).

=cut

sub tracknum {
    my $self = shift;
    my $new  = shift;
    if ( defined($new) ) {
        if ( $self->options('verbose') ) {
            $self->status( "VERBOSE:  Setting tracknum  to ",
                           ( defined $new ) ? $new : "UNDEFINED" );
        }
        my ( $t, $tt ) = split( "/", $new );
        my $r = "";
        if ($t) {
            $self->track($t);
            $r .= $t;
        }
        if ($tt) {
            $self->totaltracks($tt);
            $r .= "/" . $tt;
        }
        $self->{TRACKNUM} = $r;
    }
    my $ret = $self->track();
    if ( $self->totaltracks ) {
        $ret .= "/" . $self->totaltracks;
    }
    return $ret;
}

=pod
=item url

A url associated with the track (often the buy link for Amazon).

=item year

The year a track was released.  Defaults to year set in releasedate if not set.

=cut

sub year {
    my $self = shift;
    my $new  = shift;
    if ( defined($new) ) {
        if ( $self->options('verbose') ) {
            $self->status( "VERBOSE:  Setting year  to ", ( defined $new ) ? $new : "UNDEFINED" );
        }
        $self->{YEAR} = $new;
    }
    if ( ( exists $self->{YEAR} ) && ( $self->{YEAR} ) ) {
        return $self->{YEAR};
    }
    elsif ( $self->releasedate ) {
        if ( $self->releasedate =~ /^(\d\d\d\d)-?/ ) {
            $self->{YEAR} = $1;
            return $1;
        }
    }
    return undef;
}

sub status {
    my $self = shift;
    unless ( $self->options('quiet') ) {
        my $name = ref($self);
        $name =~ s/^Music:://g;
        print $self->tenprint( $name, 'bold white' ), @_, "\n";
    }
}

sub tenprint {
    my $self  = shift;
    my $text  = shift;
    my $color = shift || "bold yellow";
    my $size  = shift || 10;
    return $self->color($color)
      . sprintf( '%' . $size . 's: ', substr( $text, 0, $size ) )
      . $self->color('reset');
}

sub color {
    my $self = shift;
    if ( $self->options->{ANSIColor} ) {
        return Term::ANSIColor::color(@_);
    }
    else {
        return "";
    }
}

sub error {
    my $self = shift;
    unless ( $self->options('quiet') ) {
        warn ref($self), " ", @_, "\n";
    }
}

sub AUTOLOAD {
    my $self = shift;
    my $attr = $AUTOLOAD;
    $attr =~ s/.*:://;
    my $new = shift;
    my $okmethods = { map { lc($_) => 1 } @DATAMETHODS };
    if ( $okmethods->{ lc($attr) } ) {
        return $self->_accessor( $attr, $new );
    }
    else {
        croak "Music::Tag:  Invalid method: $attr called";
    }
}

sub DESTROY {
}

1;

package Music::Tag::Generic;
use Encode;
use strict;
use vars qw($AUTOLOAD);

=pod

=head1 PLUGINS

All plugins should set @ISA to include Music::Tag::Generic and contain one or more of the following methods:

=item new()

Set in template. If you override, it should take as options a reference to a Music::Tag object and an href of options. 

=cut

sub new {
    my $class   = shift;
    my $parent  = shift;
    my $options = shift || {};
    my $self    = {};
    bless $self, $class;
    $self->info($parent);
    $self->options( $self->default_options );
    $self->options($options);
    return $self;
}

=pod

=item info()

Should return a reference to the associated Music::Tag object. If passed an object, should set the associated Music::Tag object to it.

=cut

sub info {
    my $self = shift;
    my $val  = shift;
    if ( defined $val && ref $val ) {
        $self->{info} = $val;
    }
    return $self->{info};
}

=item get_tag()

Populates the data in the Music::Tag object.

=cut

sub get_tag {
}

=item set_tag()

Optional method to save info back to tag.

=cut

sub set_tag {
}

=pod

=item strip_tag

Optional method to remove a tag.

=cut

sub strip_tag {
}

=item close

Optional method to close open file handles.

=cut

sub close {
}

=item tagchange

Inhereted method that can be called to announce a tag change from what is read on file. Used by secondary plugins like Amazon, MusicBrainz, and File.

=cut

sub tagchange {
    my $self = shift;
    my $tag  = uc(shift);
    my $to   = shift || $self->info->{$tag};
    $self->status( $self->info->tenprint( $tag, 'bold blue', 15 ) . '"'.$to.'"' );
    $self->info->changed(1);
}

=item simplify

A usfull method for simplifying artist names and titles. Takes a string, and returns a sting with no whitespace.  Also removes accents (if Text::Unaccent is available) and converts numbers like 1,2,3 as words to one, two, three.  Removes a,the

=cut

sub simplify {
    my $self = shift;
    my $text = shift;
    chomp $text;

    # Text::Unaccent wants a char set, this enforces that...
    if ( $self->options->{Unaccent} ) {
        $text = Text::Unaccent::unac_string( "UTF-8", encode( "utf8", $text, Encode::FB_DEFAULT ) );
    }

    $text = lc($text);

    $text =~ s/\[[^\]]+\]//g;
    $text =~ s/[\s_]/ /g;

    if ( $self->options->{Stem} ) {
        $text = join( " ", @{ Lingua::Stem::stem( split( /\s/, $text ) ) } );
    }

    if ( length($text) > 5 ) {
        $text =~ s/\bthe\s//g;
        $text =~ s/\ba\s//g;
        $text =~ s/\ban\s//g;
        $text =~ s/\band\s//g;
        $text =~ s/\ble\s//g;
        $text =~ s/\bles\s//g;
        $text =~ s/\bla\s//g;
        $text =~ s/\bde\s//g;
    }
    if ( $self->options->{Inflect} ) {
        $text =~ s/(\.?\d+\,?\d*\.?\d*)/Lingua::EN::Inflect::NUMWORDS($1)/eg;
    }
    else {
        $text =~ s/\b10\s/ten /g;
        $text =~ s/\b9\s/nine /g;
        $text =~ s/\b8\s/eight /g;
        $text =~ s/\b7\s/seven /g;
        $text =~ s/\b6\s/six /g;
        $text =~ s/\b5\s/five /g;
        $text =~ s/\b4\s/four /g;
        $text =~ s/\b3\s/three /g;
        $text =~ s/\b2\s/two /g;
        $text =~ s/\b1\s/one /g;
    }

    $text =~ s/\sii\b/two/g;
    $text =~ s/\siii\b/three/g;
    $text =~ s/\siv\b/four/g;
    $text =~ s/\sv\b/five/g;
    $text =~ s/\svi\b/six/g;
    $text =~ s/\svii\b/seven/g;
    $text =~ s/\sviii\b/eight/g;

    $text =~ s/[^a-z0-9]//g;
    return $text;
}

# similar_percent is a precent, so should be open set (0..1)
sub simple_compare {
    my $self            = shift;
    my $a               = shift;
    my $b               = shift;
    my $similar_percent = shift;
    my $crop_percent    = shift;

    #warn "Simple_compare called\n";
    my $sa = $self->simplify($a);
    my $sb = $self->simplify($b);
    if ( $sa eq $sb ) {
        return 1;
    }

    return unless ( $similar_percent || $crop_percent );

    my $la  = length($sa);
    my $lb  = length($sb);
    my $max = ( $la < $lb ) ? $lb : $la;
    my $min = ( $la < $lb ) ? $la : $lb;

    return unless ( $min and $max );

    my $dist = undef;
    if ( $self->options->{LevenshteinXS} ) {
        $dist = Text::LevenshteinXS::distance( $sa, $sb );
    }
    elsif ( $self->options->{Levenshtein} ) {
        $dist = Text::Levenshtein::distance( $sa, $sb );
    }
    unless ($crop_percent) {
        $crop_percent = $similar_percent * ( 2 / 3 );
    }

    if ( ( defined $dist ) && ( ( ( $min - $dist ) / $min ) >= $similar_percent ) ) {
        return -1;
    }

    if ( $min < 10 ) {
        return 0;
    }
    if ( ( ( ( 2 * $min ) - $max ) / $min ) <= $crop_percent ) {
        return 0;
    }
    if ( substr( $sa, 0, $min ) eq substr( $sb, 0, $min ) ) {
        return -1;
    }
    return 0;
}

=item status

Inhereted method to print a pretty status message.

=cut

sub status {
    my $self = shift;
    unless ( $self->info->options('quiet') ) {
        my $name = ref($self);
        $name =~ s/^Music::Tag:://g;
        print $self->info->tenprint( $name, 'bold white', 12 ), @_, "\n";
    }
}

=item error

Inhereted method to print an error message.

=cut

sub error {
    my $self = shift;
    warn ref($self), " ", @_, "\n";
}

sub changed {
    my $self = shift;
    my $new  = shift;
    if ( defined $new ) {
        $self->{changed}++;
    }
    return $self->{changed};
}

=item options

Returns a hashref of options (or sets options, just like Music::Tag method).

=cut

sub options {
    my $self = shift;
    if ( exists $self->{_options} ) {
        return $self->{_options}->options(@_);
    }
    else {
        $self->{_options} = Config::Options->new();
        return $self->{_options}->options(@_);
    }
}

=pod

=item default_options

method should return default options

=cut

sub default_options { {} }

sub DESTROY {
}

1;

=pod

=head1 BUGS

No method for analysing album as a whole, only track-by-track method.

=cut

1;

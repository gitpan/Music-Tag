package Music::Tag::FLAC;
our $VERSION = 0.25;

# Copyright (c) 2007 Edward Allen III. All rights reserved.
#
## This program is free software; you can redistribute it and/or
## modify it under the terms of the Artistic License, distributed
## with Perl.
#

=pod

=head1 NAME

Music::Tag::Flac - Plugin module for Music::Tag to get information from flac headers. 

=head1 SYNOPSIS

use Music::Tag

my $filename = "/var/lib/music/artist/album/track.flac";

my $info = Music::Tag->new($filename, { quiet => 1 }, "FLAC");

$info->get_info();
   
print "Artist is ", $info->artist;

=head1 DESCRIPTION

Music::Tag::FLAC is used to read flac header information. It uses Audio::FLAC::Header. 

No values are required (except filename, which is usually provided on object creation). You normally read information from Music:Tag::FLAC first.

=over 4

=head1 SET VALUES

=cut

use strict;
use Audio::FLAC::Header;

#use Image::Magick;
our @ISA = qw(Music::Tag::Generic);

sub flac {
	my $self = shift;
	unless ((exists $self->{_Flac}) && (ref $self->{_Flac})) {
		if ($self->info->filename) {
			$self->{_Flac} = Audio::FLAC::Header->new($self->info->filename);
		}
	}
	return $self->{_Flac};

}

sub flactag {
	my $self = shift;
	my $tag = shift;
	my $new = shift;
	if (defined $new) {
		$self->flac->tags->{$tag} = $new;
	}
	if ($self->flac) {
		return $self->flac->tags($tag);
	}
}

=pod

=item title, track, totaltracks, artist, album, comment, releasedate, genre, disc, label

Uses standard tags for these

=item asin

Uses custom tag "ASIN" for this

=item mb_artistid, mb_albumid, mb_trackid, mip_puid, countrycode, albumartist

Uses MusicBrainz recommended tags for these.

=item secs, bitrate

Gathers this info from file.  Please note that secs is fractional.

=cut


sub get_tag {
    my $self     = shift;
    if ( $self->flac ) {
        $self->flactag('TITLE') && $self->info->title( $self->flactag('TITLE') );
        $self->flactag('TRACKNUMBER') && $self->info->track( $self->flactag('TRACKNUMBER') );
        $self->flactag('TRACKTOTAL') && $self->info->totaltracks( $self->flactag('TRACKTOTAL') );
        $self->flactag('ARTIST') && $self->info->artist( $self->flactag('ARTIST') );
        $self->flactag('ALBUM') && $self->info->album( $self->flactag('ALBUM') );
        $self->flactag('COMMENT') && $self->info->comment( $self->flactag('COMMENT') );
        $self->flactag('RELEASEDATE') && $self->info->releasedate( $self->flactag('DATE') );
        $self->flactag('GENRE') &&  $self->info->genre( $self->flactag('GENRE') );
        $self->flactag('DISC') && $self->info->disc( $self->flactag('DISC') );
        $self->flactag('LABEL') && $self->info->label( $self->flactag('LABEL') );
        $self->flactag('ASIN') && $self->info->asin( $self->flactag('ASIN') );
        $self->flactag('MUSICBRAINZ_ARTISTID') && $self->info->mb_artistid( $self->flactag('MUSICBRAINZ_ARTISTID') );
        $self->flactag('MUSICBRAINZ_ALBUMID') && $self->info->mb_albumid( $self->flactag('MUSICBRAINZ_ALBUMID') );
        $self->flactag('MUSICBRAINZ_TRACKID') && $self->info->mb_trackid( $self->flactag('MUSICBRAINZ_TRACKID') );
        $self->flactag('MUSICBRAINZ_SORTNAME') && $self->info->sortname( $self->flactag('MUSICBRAINZ_SORTNAME') ); 
        $self->flactag('RELEASECOUNTRY') && $self->info->countrycode( $self->flactag('RELEASECOUNTRY') ); 
        $self->flactag('MUSICIP_PUID') && $self->info->mip_puid( $self->flactag('MUSICIP_PUID') ); 
        $self->flactag('MUSICBRAINZ_ALBUMARTIST') && $self->info->albumartist( $self->flactag('MUSICBRAINZ_ALBUMARTIST') ); 
        $self->info->secs( $self->flac->{trackTotalLengthSeconds} );
        $self->info->bitrate( $self->flac->{bitRate} );

=pod

=item picture

This is currently read-only.

=cut

		#"MIME type"     => The MIME Type of the picture encoding
		#"Picture Type"  => What the picture is off.  Usually set to 'Cover (front)'
		#"Description"   => A short description of the picture
		#"_Data"	       => The binary data for the picture.
        if (( $self->flac->picture) && ( not $self->info->picture_exists)) {
			my $pic = $self->flac->picture;
            $self->info->picture( {
					"MIME type" => $pic->{mimeType},
					"Picture Type" => $pic->{description},
					"_Data"	=> $pic->{imageData},
				});
        }
        #$self->info->url(		$self->flac->tags('URL')		);
    }
    return $self;
}

sub set_tag {
    my $self = shift;
    if ( $self->flac ) {
        $self->flactag('TITLE', $self->info->title);
        $self->flactag('TRACKNUMBER', $self->info->tracknum);
        $self->flactag('TRACKTOTAL', $self->info->totaltracks);
        $self->flactag('ARTIST', $self->info->artist);
        $self->flactag('ALBUM', $self->info->album);
        $self->flactag('COMMENT', $self->info->comment);
        $self->flactag('DATE', $self->info->releasedate);
        $self->flactag('GENRE', $self->info->genre);
        $self->flactag('DISC', $self->info->disc);
        $self->flactag('LABEL', $self->info->label);
        $self->flactag('ASIN', $self->info->asin);
        $self->flactag('MUSICBRAINZ_ARTISTID', $self->info->mb_artistid( $self->flactag));
        $self->flactag('MUSICBRAINZ_ALBUMID', $self->info->mb_albumid( $self->flactag));
        $self->flactag('MUSICBRAINZ_TRACKID', $self->info->mb_trackid( $self->flactag));
        $self->flactag('MUSICBRAINZ_SORTNAME', $self->info->sortname( $self->flactag)); 
        $self->flactag('RELEASECOUNTRY', $self->info->countrycode( $self->flactag)); 
        $self->flactag('MUSICIP_PUID', $self->info->mip_puid( $self->flactag)); 
        $self->flactag('MUSICBRAINZ_ALBUMARTIST', $self->info->albumartist( $self->flactag)); 
        $self->flac->write();
    }
    return $self;
}

=pod

=head1 OPTIONS

None currently.

=head1 BUGS

This method is always unreliable unless great care is taken in file naming. 

=head1 SEE ALSO INCLUDED

L<Music::Tag>, L<Music::Tag::Amazon>, L<Music::Tag::File>, L<Music::Tag::Lyrics>,
L<Music::Tag::M4A>, L<Music::Tag::MP3>, L<Music::Tag::MusicBrainz>, L<Music::Tag::OGG>, L<Music::Tag::Option>

=head1 SEE ALSO

L<Audio::FLAC::Header>

=head1 AUTHOR 

Edward Allen III <ealleniii _at_ cpan _dot_ org>


=head1 COPYRIGHT

Copyright (c) 2007 Edward Allen III. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the Artistic License, distributed
with Perl.


=cut

1;

# vim: tabstop=4

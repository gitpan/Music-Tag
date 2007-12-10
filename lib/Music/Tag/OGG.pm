package Music::Tag::OGG;
our $VERSION = 0.25;

# Copyright (c) 2006 Edward Allen III. All rights reserved.
#
## This program is free software; you can redistribute it and/or
## modify it under the terms of the Artistic License, distributed
## with Perl.
#

=pod

=head1 NAME

Music::Tag::Ogg - Plugin module for Music::Tag to get information from ogg-vorbis headers. 

=head1 SYNOPSIS

use Music::Tag

my $filename = "/var/lib/music/artist/album/track.ogg";

my $info = Music::Tag->new($filename, { quiet => 1 }, "ogg");

$info->get_info();
   
print "Artist is ", $info->artist;

=head1 DESCRIPTION

Music::Tag::OGG is used to read ogg-vorbis header information. It uses Music::Tag::OGG. 

No values are required (except filename, which is usually provided on object creation). You normally read information from Music:Tag::OGG first.

=over 4

=head1 SET VALUES

=item title, track, totaltracks, artist, album, comment, releasedate, genre, disc, label

Uses standard tags for these

=item asin

Uses custom tag "ASIN" for this

=item mb_artistid, mb_albumid, mb_trackid, mip_puid, countrycode, albumartist

Uses MusicBrainz recommended tags for these.


=cut
use strict;
use Ogg::Vorbis::Header;

#use Image::Magick;
our @ISA = qw(Music::Tag::Generic);

sub ogg {
	my $self = shift;
	unless ((exists $self->{_OGG}) && (ref $self->{_OGG})) {
		if ($self->info->filename) {
			$self->{_OGG} = Ogg::Vorbis::Header->new($self->info->filename);
		}
		else {
			return undef;
		}
	}
	return $self->{_OGG};
}

sub oggtag {
	my $self = shift;
	my $tag = lc(shift);
	my $new = shift;
	my %comments = map { $_ => 1 } ( $self->ogg->comment_tags() );
	if ($new) {
	    if($comments{$tag}) {
			$self->ogg->edit_comment($tag => $new);
		}
		else {
			$self->ogg->add_comments($tag => $new);
		}
	}
	if (exists $comments{$tag}) {
		return $self->ogg->comment($tag);
	}
	else {
		return undef;
	}
}

sub get_tag {
    my $self     = shift;
    if ( ( $self->ogg ) && ( $self->ogg->load ) ) {
        $self->oggtag('TITLE') && $self->info->title( $self->oggtag('TITLE') );
        $self->oggtag('TRACKNUMBER') && $self->info->track( $self->oggtag('TRACKNUMBER') );
        $self->oggtag('TRACKTOTAL') && $self->info->totaltracks( $self->oggtag('TRACKTOTAL') );
        $self->oggtag('ARTIST') && $self->info->artist( $self->oggtag('ARTIST') );
        $self->oggtag('ALBUM') && $self->info->album( $self->oggtag('ALBUM') );
        $self->oggtag('COMMENT') && $self->info->comment( $self->oggtag('COMMENT') );
        $self->oggtag('RELEASEDATE') && $self->info->releasedate( $self->oggtag('DATE') );
        $self->oggtag('GENRE') &&  $self->info->genre( $self->oggtag('GENRE') );
        $self->oggtag('DISC') && $self->info->disc( $self->oggtag('DISC') );
        $self->oggtag('LABEL') && $self->info->label( $self->oggtag('LABEL') );
        $self->oggtag('ASIN') && $self->info->asin( $self->oggtag('ASIN') );
        $self->oggtag('MUSICBRAINZ_ARTISTID') && $self->info->mb_artistid( $self->oggtag('MUSICBRAINZ_ARTISTID') );
        $self->oggtag('MUSICBRAINZ_ALBUMID') && $self->info->mb_albumid( $self->oggtag('MUSICBRAINZ_ALBUMID') );
        $self->oggtag('MUSICBRAINZ_TRACKID') && $self->info->mb_trackid( $self->oggtag('MUSICBRAINZ_TRACKID') );
        $self->oggtag('MUSICBRAINZ_SORTNAME') && $self->info->sortname( $self->oggtag('MUSICBRAINZ_SORTNAME') ); 
        $self->oggtag('RELEASECOUNTRY') && $self->info->countrycode( $self->oggtag('RELEASECOUNTRY') ); 
        $self->oggtag('MUSICIP_PUID') && $self->info->mip_puid( $self->oggtag('MUSICIP_PUID') ); 
        $self->oggtag('MUSICBRAINZ_ALBUMARTIST') && $self->info->albumartist( $self->oggtag('MUSICBRAINZ_ALBUMARTIST') ); 
        $self->info->secs( $self->ogg->info->{"length"});
        $self->info->bitrate( $self->ogg->info->{"bitrate_nominal"});
        $self->info->frequency( $self->ogg->info->{"rate"});
	}
    return $self;
}


sub set_tag {
    my $self = shift;
    return $self;
    if ( $self->ogg ) {
        $self->oggtag('TITLE', $self->info->title);
        $self->oggtag('TRACKNUMBER', $self->info->tracknum);
        $self->oggtag('TRACKTOTAL', $self->info->totaltracks);
        $self->oggtag('ARTIST', $self->info->artist);
        $self->oggtag('ALBUM', $self->info->album);
        $self->oggtag('COMMENT', $self->info->comment);
        $self->oggtag('DATE', $self->info->releasedate);
        $self->oggtag('GENRE', $self->info->genre);
        $self->oggtag('DISC', $self->info->disc);
        $self->oggtag('LABEL', $self->info->label);
        $self->oggtag('ASIN', $self->info->asin);
        $self->oggtag('MUSICBRAINZ_ARTISTID', $self->info->mb_artistid( $self->oggtag));
        $self->oggtag('MUSICBRAINZ_ALBUMID', $self->info->mb_albumid( $self->oggtag));
        $self->oggtag('MUSICBRAINZ_TRACKID', $self->info->mb_trackid( $self->oggtag));
        $self->oggtag('MUSICBRAINZ_SORTNAME', $self->info->sortname( $self->oggtag)); 
        $self->oggtag('RELEASECOUNTRY', $self->info->countrycode( $self->oggtag)); 
        $self->oggtag('MUSICIP_PUID', $self->info->mip_puid( $self->oggtag)); 
        $self->oggtag('MUSICBRAINZ_ALBUMARTIST', $self->info->albumartist( $self->oggtag)); 
        $self->ogg->write_vorbis();
    }
    return $self;
}

sub close {
	my $self = shift;
	$self->{_OGG} = undef;
}

1;

=pod

=head1 OPTIONS

None at the momment.

=head1 BUGS

No known additional bugs provided by this Module

=head1 SEE ALSO INCLUDED

L<Music::Tag>, L<Music::Tag::Amazon>, L<Music::Tag::File>, L<Music::Tag::FLAC>, L<Music::Tag::Lyrics>,
L<Music::Tag::M4A>, L<Music::Tag::MP3>, L<Music::Tag::MusicBrainz>, L<Music::Tag::Option>

=head1 SEE ALSO

L<Ogg::Vorbis::Heaader>

=head1 AUTHOR 

Edward Allen III <ealleniii _at_ cpan _dot_ org>


=head1 COPYRIGHT

Copyright (c) 2007 Edward Allen III. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the Artistic License, distributed
with Perl.


=cut


# vim: tabstop=4

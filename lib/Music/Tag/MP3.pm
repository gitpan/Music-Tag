package Music::Tag::MP3;
our $VERSION=0.19;

# Copyright (c) 2007 Edward Allen III. All rights reserved.
#
## This program is free software; you can redistribute it and/or
## modify it under the terms of the Artistic License, distributed
## with Perl.
#

=pod

=head1 NAME

Music::Tag::MP3 - Plugin module for Music::Tag to get information from id3 and id4v3 tags

=head1 SYNOPSIS

use Music::Tag

my $info = Music::Tag->new($filename, { quiet => 1 }, "MP3");
   
print "Artist is ", $info->artist;

=head1 DESCRIPTION

Music::Tag::MP3 is used to read id3 tag information. It uses MP3::Tag to read id3v2 and id3 tags from mp3 files. As such, it's limitations are the same as MP3::Tag. It does not write id3v2.4 tags, causing it to have some trouble with unicode.

No values are required (except filename, which is usually provided on object creation). You normally read information from Music:Tag::MP3 first.

=over 4

=head1 SET VALUES

=cut

use strict;
use MP3::Tag;
use Data::Dumper;

#use Image::Magick;
our @ISA = qw(Music::Tag::Generic);

sub default_options {
   { apic_cover => 1, };
}

sub decode_bad_uf {
   my $in = shift;
   if ( unpack( "U", substr( $in, 0, 1 ) ) == 255 ) {
      $in =~ s/^[^A-Za-z0-9]*//;
      $in =~ s/ \/ //g;
   }
   return $in;
}

sub get_tag {
   my $self     = shift;
   my $filename = $self->info->filename;
   $self->{_mp3} = MP3::Tag->new($filename);
   return unless ( $self->{_mp3} );
   $self->{_mp3}->config( id3v2_mergepadding => 0 );
   return unless $self->{_mp3};
   $self->{_mp3}->get_tags;

=pod

=item mp3 file info added:

   Currently this includes bitrate, duration, frequency, stereo, bytes, codec, frames, vbr, 
=cut

   $self->info->bitrate( $self->{_mp3}->bitrate_kbps );
   $self->info->duration( $self->{_mp3}->total_millisecs_int );
   $self->info->frequency( $self->{_mp3}->frequency_Hz() );
   $self->info->stereo( $self->{_mp3}->is_stereo() );
   $self->info->bytes( $self->{_mp3}->size_bytes() );
   if ( $self->{_mp3}->mpeg_version() ) {
      $self->info->codec(   "MPEG Version "
                          . $self->{_mp3}->mpeg_version()
                          . " Layer "
                          . $self->{_mp3}->mpeg_layer() );
   }
   $self->info->frames( $self->{_mp3}->frames() );
   $self->info->vbr( $self->{_mp3}->is_vbr() );

=pod

=item id3v1 tag info added:

title, artist, album, track, comment, year and genre

=cut

   eval {
      $self->info->title( decode_bad_uf( $self->{_mp3}->title ) );
      $self->info->artist( decode_bad_uf( $self->{_mp3}->artist ) );
      $self->info->album( decode_bad_uf( $self->{_mp3}->album ) );
      $self->info->tracknum( decode_bad_uf( $self->{_mp3}->track ) );
      $self->info->comment( decode_bad_uf( $self->{_mp3}->comment ) );
      $self->info->year( decode_bad_uf( $self->{_mp3}->year ) );
      $self->info->genre( decode_bad_uf( $self->{_mp3}->genre ) );
   };
   warn $@ if $@;

=pod

=item id3v2 tag info added:

title, artist, album, track, totaltracks, year, genre, disc, totaldiscs, label, releasedate, lyrics (using USLT), url (using WCOM), encoder (using TFLT),  and picture (using apic). 

=cut

   if ( exists $self->{_mp3}->{ID3v2} ) {
      unless ( $self->info->title  eq $self->{_mp3}->{ID3v2}->title )  { $self->info->changed }
      unless ( $self->info->artist eq $self->{_mp3}->{ID3v2}->artist ) { $self->info->changed }
      unless ( $self->info->album  eq $self->{_mp3}->{ID3v2}->album )  { $self->info->changed }
      unless ( $self->info->year   eq $self->{_mp3}->{ID3v2}->year )   { $self->info->changed }
      unless ( $self->info->track  eq $self->{_mp3}->{ID3v2}->track )  { $self->info->changed }
      unless ( $self->info->genre  eq $self->{_mp3}->{ID3v2}->genre )  { $self->info->changed }
      if ( $self->info->{changed} ) {
         $self->status("ID3v2 tag does not have all needed information");
      }
      $self->info->discnum( $self->{_mp3}->{ID3v2}->get_frame('TPOS') );
      $self->info->label( $self->{_mp3}->{ID3v2}->get_frame('TPUB') );
      $self->info->sortname( $self->{_mp3}->{ID3v2}->get_frame('TPE1') );
      $self->info->sortname( $self->{_mp3}->{ID3v2}->get_frame('XSOP') );

      # Remove this eventually, changing tag to TXXX[ASIN]
      $self->info->asin( $self->{_mp3}->{ID3v2}->get_frame('TOWN') );
      my $t;

      my $day = $self->{_mp3}->{ID3v2}->get_frame('TDAT');
      if ( ( $day =~ /(\d\d)(\d\d)/ ) && ( $self->info->year ) ) {
         $self->info->releasedate( $self->info->year . "-" . $1 . "-" . $2 );
      }
      my $lyrics = $self->{_mp3}->{ID3v2}->get_frame('USLT');
      if ( ref $lyrics ) {
         $self->info->lyrics( $lyrics->{Text} );
      }
      if ( ref $self->{_mp3}->{ID3v2}->get_frame('WCOM') ) {
         $self->info->url( $self->{_mp3}->{ID3v2}->get_frame('WCOM')->{URL} );
      }
      else {
         $self->info->url("");
      }
      if ( ref $self->{_mp3}->{ID3v2}->get_frame('TFLT') ) {
         $self->info->encoder( $self->{_mp3}->{ID3v2}->get_frame('TFLT') );
      }
      if ( $self->{_mp3}->{ID3v2}->get_frame('TENC') ) {
         $self->info->encoded_by( $self->{_mp3}->{ID3v2}->get_frame('TENC') );
      }
      if ( ref $self->{_mp3}->{ID3v2}->get_frame('USER') ) {
         if ( $self->{_mp3}->{ID3v2}->get_frame('USER')->{Language} eq "Cop" ) {
            $self->status("Emusic mistagged file found");
            $self->info->encoded_by('emusic');
         }
      }
      if (    ( not $self->options->{ignore_apic} )
           && ( $self->{_mp3}->{ID3v2}->get_frame('APIC') ) ) {
         $self->info->picture( $self->{_mp3}->{ID3v2}->get_frame('APIC') );
      }

=pod

=item The following information is gathered from the ID3v2 tag using custom tags

TXXX[ASIN]   asin
TXXX[Sortname] sortname
TXXX[MusicBrainz Artist Id] mb_artistid
TXXX[MusicBrainz Album Id] mb_albumid
TXXX[MusicBrainz Track Id] mb_trackid
TXXX[MusicBrainz Album Type] album_type
TXXX[MusicBrainz Artist Type] artist_type

=cut

      $t = $self->{_mp3}->{ID3v2}->frame_select( "TXXX", "ASIN", [''] );
      if ($t) { $self->info->asin($t); }
      $t = $self->{_mp3}->{ID3v2}->frame_select( "TXXX", "Sortname", [''] );
      if ($t) { $self->info->sortname($t); }
      $t =
        $self->{_mp3}->{ID3v2}->frame_select( "TXXX", "MusicBrainz Album Artist Sortname", [''] );
      if ($t) { $self->info->sortname($t); }
      $t = $self->{_mp3}->{ID3v2}->frame_select( "TXXX", "MusicBrainz Album Artist", [''] );
      if ($t) { $self->info->albumartist($t); }
      $t =
        $self->{_mp3}->{ID3v2}->frame_select( "TXXX", "MusicBrainz Album Release Country", [''] );
      if ($t) { $self->info->countrycode($t); }
      $t = $self->{_mp3}->{ID3v2}->frame_select( "TXXX", "MusicBrainz Artist Id", [''] );
      if ($t) { $self->info->mb_artistid($t); }
      $t = $self->{_mp3}->{ID3v2}->frame_select( "TXXX", "MusicBrainz Album Id", [''] );
      if ($t) { $self->info->mb_albumid($t); }
      $t = $self->{_mp3}->{ID3v2}->frame_select( "TXXX", "MusicBrainz Track Id", [''] );
      if ($t) { $self->info->mb_trackid($t); }
      $t = $self->{_mp3}->{ID3v2}->frame_select( "TXXX", "MusicBrainz Album Status", [''] );
      if ($t) { $self->info->album_type($t); }
      $t = $self->{_mp3}->{ID3v2}->frame_select( "TXXX", "MusicBrainz Artist Type", [''] );
      if ($t) { $self->info->artist_type($t); }
      $t = $self->{_mp3}->{ID3v2}->frame_select( "TXXX", "MusicIP PUID", [''] );
      if ($t) { $self->info->mip_puid($t); }
      $t = $self->{_mp3}->{ID3v2}->frame_select( "TXXX", "Artist Begins", [''] );
      if ($t) { $self->info->artist_start($t); }
      $t = $self->{_mp3}->{ID3v2}->frame_select( "TXXX", "Artist Ends", [''] );
      if ($t) { $self->info->artist_end($t); }
   }
   return $self;
}

sub strip_tag {
   my $self = shift;
   $self->status("Stripping current tags");
   if ( exists $self->{_mp3}->{ID3v2} ) {
      $self->{_mp3}->{ID3v2}->remove_tag;
      $self->{_mp3}->{ID3v2}->write_tag;
   }
   if ( exists $self->{_mp3}->{ID3v1} ) {
      $self->{_mp3}->{ID3v1}->remove_tag;
   }
   return $self;
}

sub set_tag {
   my $self     = shift;
   my $filename = $self->info->filename;
   $self->status("Updating MP3");
   my $id3v1;
   my $id3v2;
   if ( $self->{_mp3}->{ID3v2} ) {
      $id3v2 = $self->{_mp3}->{ID3v2};
   }
   else {
      $id3v2 = $self->{_mp3}->new_tag("ID3v2");
   }
   if ( $self->{_mp3}->{ID3v1} ) {
      $id3v1 = $self->{_mp3}->{ID3v1};
   }
   else {
      $id3v1 = $self->{_mp3}->new_tag("ID3v1");
   }
   $self->status("Writing ID3v2 Tag");
   $id3v2->title( $self->info->title );
   $id3v2->artist( $self->info->artist );
   $id3v2->album( $self->info->album );
   $id3v2->year( $self->info->year );
   $id3v2->track( $self->info->tracknum );
   $id3v2->genre( $self->info->genre );
   $id3v2->remove_frame('TPOS');
   $id3v2->add_frame( 'TPOS', 0, $self->info->disc );
   $id3v2->remove_frame('TPUB');
   $id3v2->add_frame( 'TPUB', 0, $self->info->label );
   $id3v2->remove_frame('WCOM');
   $id3v2->add_frame( 'WCOM', 0, url_encode( $self->info->url ) );
   $id3v2->remove_frame('TOWN');

   if ( $self->info->encoded_by ) {
      $id3v2->remove_frame('TENC');
      $id3v2->add_frame( 'TENC', 0, $self->info->encoded_by );
   }
   if ( $self->info->asin ) {
      $id3v2->frame_select( 'TXXX', 'ASIN', [''], $self->info->asin );
   }
   if ( $self->info->mb_trackid ) {
      $id3v2->frame_select( 'TXXX', 'MusicBrainz Track Id', [''], $self->info->mb_trackid );
   }
   if ( $self->info->mb_artistid ) {
      $id3v2->frame_select( 'TXXX', 'MusicBrainz Artist Id', [''], $self->info->mb_artistid );
   }
   if ( $self->info->mb_albumid ) {
      $id3v2->frame_select( 'TXXX', 'MusicBrainz Album Id', [''], $self->info->mb_albumid );
   }
   if ( $self->info->album_type ) {
      $id3v2->frame_select( 'TXXX', 'MusicBrainz Album Status', [''], $self->info->album_type );
   }
   if ( $self->info->artist_type ) {
      $id3v2->frame_select( 'TXXX', 'MusicBrainz Artist Type', [''], $self->info->artist_type );
   }
   if ( $self->info->albumartist ) {
      $id3v2->frame_select( 'TXXX', 'MusicBrainz Album Artist', [''], $self->info->albumartist );
   }
   if ( $self->info->sortname ) {
      $id3v2->frame_select( 'TXXX', 'MusicBrainz Album Artist Sortname',
                            [''], $self->info->sortname );
   }
   if ( $self->info->countrycode ) {
      $id3v2->frame_select( 'TXXX', 'MusicBrainz Album Release Country',
                            [''],   $self->info->countrycode );
   }
   if ( $self->info->mip_puid ) {
      $id3v2->frame_select( 'TXXX', 'MusicIP PUID', [''], $self->info->mip_puid );
   }
   if ( $self->info->artist_start ) {
      $id3v2->frame_select( 'TXXX', 'Artist Begins', [''], $self->info->artist_start );
   }
   if ( $self->info->artist_end ) {
      $id3v2->frame_select( 'TXXX', 'Artist Ends', [''], $self->info->artist_end );
   }
   $id3v2->remove_frame('USLT');
   $id3v2->add_frame( 'USLT', 0, "ENG", "Lyrics", $self->info->lyrics );
   $id3v2->remove_frame('UFID');

   if ( $self->info->releasedate =~ /(\d\d\d\d)-(\d\d)-(\d\d)/ ) {
      my $day = "$2$3";
      $id3v2->remove_frame('TDAT');
      $id3v2->add_frame( 'TDAT', 0, $day );
   }
   unless ( $self->options->{ignore_apic} ) {
      $id3v2->remove_frame('APIC');
      if ( ( $self->options->{apic_cover} ) && ( $self->info->picture ) ) {
         $self->status("Saving Cover to APIC frame");
         $id3v2->add_frame( 'APIC', apic_encode( $self->info->picture ) );
      }
   }
   $self->status("Writing ID3v1 Tag for $filename");
   eval { $id3v2->write_tag(); };
   $id3v1->title( $self->info->title );
   $id3v1->artist( $self->info->artist );
   $id3v1->album( $self->info->album );
   $id3v1->year( $self->info->year );
   $id3v1->track( $self->info->tracknum );
   $id3v1->genre( $self->info->genre );
   $id3v1->write_tag();
   return $self;
}

sub close {
   my $self = shift;
   $self->{_mp3}->close();
   $self->{_mp3}->{ID3v2} = undef;
   $self->{_mp3}->{ID3v1} = undef;
   $self->{_mp3}          = undef;
   $self                  = undef;
}

sub apic_encode {
   my $code = shift;
   my @PICTYPES = ( "Other",
                    "32x32 pixels 'file icon' (PNG only)",
                    "Other file icon",
                    "Cover (front)",
                    "Cover (back)",
                    "Leaflet page",
                    "Media (e.g. lable side of CD)",
                    "Lead artist/lead performer/soloist",
                    "Artist/performer",
                    "Conductor",
                    "Band/Orchestra",
                    "Composer",
                    "Lyricist/text writer",
                    "Recording Location",
                    "During recording",
                    "During performance",
                    "Movie/video screen capture",
                    "A bright coloured fish",
                    "Illustration",
                    "Band/artist logotype",
                    "Publisher/Studio logotype"
                  );
   my $c = 0;
   my %PICBYTES = map { $_ => chr( $c++ ) } @PICTYPES;
   return ( 0, $code->{"MIME type"}, $code->{"Picture Type"}, $code->{"Description"},
            $code->{_Data} );
}

sub url_encode {
   my $url = shift;
   return ($url);
}

1;

# vim: tabstop=4

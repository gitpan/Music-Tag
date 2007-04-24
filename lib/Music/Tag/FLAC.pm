package Music::Tag::FLAC;
our $VERSION=0.19;

# Copyright (c) 2007 Edward Allen III. All rights reserved.
#
## This program is free software; you can redistribute it and/or
## modify it under the terms of the Artistic License, distributed
## with Perl.
#
use strict;
use Audio::FLAC::Header;

#use Image::Magick;
our @ISA = qw(Music::Tag::Generic);

sub get_tag {
   my $self     = shift;
   my $filename = $self->info->filename();
   $self->{_flac} = Audio::FLAC::Header->new($filename);

   if ( $self->{_flac} ) {
      $self->info->title( $self->{_flac}->tags->{'TITLE'} );
      $self->info->track( $self->{_flac}->tags->{'TRACKNUMBER'} );
      $self->info->totaltracks( $self->{_flac}->tags->{'TRACKTOTAL'} );
      $self->info->artist( $self->{_flac}->tags->{'ARTIST'} );
      $self->info->album( $self->{_flac}->tags->{'ALBUM'} );
      $self->info->comment( $self->{_flac}->tags->{'COMMENT'} );
      $self->info->releasedate( $self->{_flac}->tags->{'DATE'} );
      $self->info->genre( $self->{_flac}->tags->{'GENRE'} );
      $self->info->secs( $self->{_flac}->{trackTotalLengthSeconds} );
      $self->info->disc( $self->{_flac}->tags->{'DISC'} );
      $self->info->label( $self->{_flac}->tags->{'LABEL'} );
      $self->info->asin( $self->{_flac}->tags->{'ASIN'} );
      $self->info->bitrate( $self->{_flac}->{bitRate} );

      #$self->info->url(		$self->{_flac}->tags('URL')		);
   }
   return $self;
}

sub set_tag {
   my $self = shift;
   if ( $self->{_flac} ) {
      $self->{_flac}->tags->{TITLE}       = $self->info->title;
      $self->{_flac}->tags->{TRACKNUMBER} = $self->info->tracknum;
      $self->{_flac}->tags->{TRACKTOTAL}  = $self->info->totaltracks;
      $self->{_flac}->tags->{ARTIST}      = $self->info->artist;
      $self->{_flac}->tags->{ALBUM}       = $self->info->album;
      $self->{_flac}->tags->{COMMENT}     = $self->info->comment;
      $self->{_flac}->tags->{DATE}        = $self->info->releasedate;
      $self->{_flac}->tags->{GENRE}       = $self->info->genre;
      $self->{_flac}->tags->{DISC}        = $self->info->disc;
      $self->{_flac}->tags->{LABEL}       = $self->info->label;
      $self->{_flac}->tags->{ASIN}        = $self->info->asin;
      $self->{_flac}->write();
   }
   return $self;
}

1;

# vim: tabstop=4

package Music::Tag::OGG;
our $VERSION = 0.19;

# Copyright (c) 2006 Edward Allen III. All rights reserved.
#
## This program is free software; you can redistribute it and/or
## modify it under the terms of the Artistic License, distributed
## with Perl.
#
use strict;
use Ogg::Vorbis::Header::PurePerl;

#use Image::Magick;
our @ISA = qw(Music::Tag::Generic);

sub get_tag {
    my $self     = shift;
    my $filename = $self->info->filename;
    $self->{_ogg} = Ogg::Vorbis::Header::PurePerl->new($filename);

    if ( ( $self->{_ogg} ) && ( $self->{_ogg}->load ) ) {
        my $oinfo = $self->{_ogg}->info;
        $self->info->title( $self->{_ogg}->comment('title') );
        $self->info->track( $self->{_ogg}->comment('tracknumber') );

        $self->info->totaltracks( $self->{_ogg}->comment('tracktotal') );
        $self->info->artist( $self->{_ogg}->comment('artist') );
        $self->info->album( $self->{_ogg}->comment('album') );
        $self->info->comment( $self->{_ogg}->comment('comment') );
        $self->info->year( $self->{_ogg}->comment('date') );
        $self->info->genre( $self->{_ogg}->comment('genre') );
        $self->info->secs( $oinfo->{length} );

        $self->info->disc( $self->{_ogg}->comment('disc') );
        $self->info->label( $self->{_ogg}->comment('organization') );
        $self->info->asin( $self->{_ogg}->comment('asin') );

        #$self->url(		$self->{_ogg}->comment('URL')		);
    }
    return $self;
}

sub set_tag {
    my $self = shift;
    return $self;
    if ( $self->{_ogg} ) {
        my $comments = {};
        foreach ( $self->{_ogg}->comment_tags() ) {
            $comments->{ uc($_) } = 1;
            print STDERR "$_\n";
        }

        if ( exists $comments->{TITLE} ) {
            $self->{_ogg}->edit_comment( title => $self->info->title() );
        }
        else {
            $self->{_ogg}->add_comments( title => $self->info->title() );
        }
        if ( exists $comments->{ARTIST} ) {
            $self->{_ogg}->edit_comment( artist => $self->info->artist() );
        }
        else {
            $self->{_ogg}->add_comments( artist => $self->info->artist() );
        }
        if ( exists $comments->{ALBUM} ) {
            $self->{_ogg}->edit_comment( album => $self->info->album() );
        }
        else {
            $self->{_ogg}->add_comments( album => $self->info->album() );
        }
        if ( exists $comments->{DATE} ) {
            $self->{_ogg}->edit_comment( date => $self->info->date() );
        }
        else {
            $self->{_ogg}->add_comments( album => $self->info->date() );
        }
        if ( exists $comments->{ORGANIZATION} ) {
            $self->{_ogg}->edit_comment( organization => $self->info->label() );
        }
        else {
            $self->{_ogg}->add_comments( organization => $self->info->label() );
        }
        if ( exists $comments->{ASIN} ) {
            $self->{_ogg}->edit_comment( asin => $self->info->asin() );
        }
        else {
            $self->{_ogg}->add_comments( asin => $self->info->asin() );
        }

        $self->{_ogg}->write_vorbis;
    }
    return $self;

}

sub url_encode {
    my $url = shift;
    return ($url);
}

1;

# vim: tabstop=4

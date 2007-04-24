package Music::Tag::M4A;
our $VERSION=0.19;

# Copyright (c) 2007 Edward Allen III. All rights reserved.
#
## This program is free software; you can redistribute it and/or
## modify it under the terms of the Artistic License, distributed
## with Perl.
#

use strict;
use MP4::Info;
use Music::Tag;
our @ISA = qw(Music::Tag::Generic);

sub get_tag {
   my $self     = shift;
   my $filename =  $self->info->filename();
   my $tinfo  = get_mp4tag($filename);
   my $ftinfo = get_mp4info($filename);
   $self->info->album( $tinfo->{ALB} );
   $self->info->artist( $tinfo->{ART} );
   $self->info->year( $tinfo->{DAY} );
   $self->info->disc( $tinfo->{DISK}->[0] );
   $self->info->totaldiscs( $tinfo->{DISK}->[1] );
   $self->info->genre( $tinfo->{GNRE} );
   $self->info->title( $tinfo->{NAM} );
   $self->info->compilation( $tinfo->{CPIL} );
   $self->info->copyright( $tinfo->{CPRT} );
   $self->info->tempo( $tinfo->{TMPO} );
   $self->info->encoder( $tinfo->{TOO} );
   $self->info->composer( $tinfo->{WRT} );
   $self->info->track( $tinfo->{TRKN}->[0]);
   $self->info->totaltracks( $tinfo->{TRKN}->[1] );
   my ( $comment, $url, $asin ) = split( ":", $tinfo->{CMT} );
   $self->info->comment($comment);
   $self->info->url($url);
   $self->info->asin($asin);
   $self->info->secs( $ftinfo->{SECS} );
   $self->info->bitrate( $ftinfo->{BITRATE} );
   $self->info->frequency( $ftinfo->{FREQUENCY} );
   return $self;
}

sub close {


}

1;

# vim: tabstop=4

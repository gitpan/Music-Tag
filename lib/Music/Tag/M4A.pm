package Music::Tag::M4A;
our $VERSION = 0.19;

# Copyright (c) 2007 Edward Allen III. All rights reserved.
#
## This program is free software; you can redistribute it and/or
## modify it under the terms of the Artistic License, distributed
## with Perl.
#

use strict;
use MP4::Info;
use Music::Tag;
use Audio::M4P::QuickTime;
our @ISA = qw(Music::Tag::Generic);

sub get_tag {
	my $self = shift;
	$self->get_tag_mp4_info;
	$self->get_tag_qt_info;
	return $self;
}

sub get_tag_qt_info {
    my $self     = shift;
    my $filename = $self->info->filename();
	my $qt = Audio::M4P::QuickTime->new(file => $filename);
    my $tinfo    = $qt->iTMS_MetaInfo;
	my $minfo    = $qt->GetMP4Info;
	my $ginfo    = $qt->GetMetaInfo;
    $self->info->album( $ginfo->{ALB} );
    $self->info->artist( $ginfo->{ART} );
	my $date = $tinfo->{year} || $ginfo->{DAY};
	$date =~ s/T.*$//;
	$self->info->releasedate($date);
	$self->info->disc( $tinfo->{discNumber});
	$self->info->totaldiscs( $tinfo->{discCount});
    $self->info->tempo( $ginfo->{TMPO} );
    $self->info->encoder( $ginfo->{TOO} || "iTMS");
	$self->info->genre( $qt->genre_as_text );
	$self->info->title( $ginfo->{NAM} );
    $self->info->composer( $ginfo->{WRT} );
	$self->info->copyright( $tinfo->{copyright} );
	$self->info->track( $qt->track);
	$self->info->totaltracks( $qt->total);
	$self->info->comment($ginfo->{COMMENT});
	$self->info->lyrics($ginfo->{LYRICS});
    $self->info->bitrate( $minfo->{BITRATE} );
    $self->info->duration( $minfo->{SECONDS} * 1000 );
	if (not $self->info->picture_exists) {
	  my $picture = $qt->GetCoverArt;
	  if ((ref $picture) && (@{$picture}) && ($picture->[0])) {
		$self->info->picture( { "MIME type" => "image/jpg", "_Data" => $picture->[0] } );
	  }
	}
    return $self;
}

sub get_tag_mp4_info {
    my $self     = shift;
    my $filename = $self->info->filename();
    my $tinfo    = get_mp4tag($filename);
    my $ftinfo   = get_mp4info($filename);
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
    $self->info->encoder( $tinfo->{TOO} || "iTMS");
    $self->info->composer( $tinfo->{WRT} );
    $self->info->track( $tinfo->{TRKN}->[0] );
    $self->info->totaltracks( $tinfo->{TRKN}->[1] );
    $self->info->comment($tinfo->{CMT});
    $self->info->duration( $ftinfo->{SECS} * 1000 );
    $self->info->bitrate( $ftinfo->{BITRATE} );
    $self->info->frequency( $ftinfo->{FREQUENCY} );
    return $self;
}

sub set_tag {
    my $self     = shift;
    my $filename = $self->info->filename();
	my $qt = Audio::M4P::QuickTime->new(file => $filename);
    my $tinfo    = $qt->iTMS_MetaInfo;
	my $minfo    = $qt->GetMP4Info;
	my $ginfo    = $qt->GetMetaInfo;
	my $changed = 0;
	$self->status("Writing M4A files is in development. Only some tags supported.");

=cut

	unless ($ginfo->{ALB} eq $self->info->album) {
		$self->status("Storing new tag info for album");
		$qt->SetMetaInfo(ALB => $self->info->album, 1);
		$changed++;
    }
	unless ($ginfo->{ART} eq $self->info->artist) {
		$self->status("Storing new tag info for artist");
		$qt->SetMetaInfo(ART => $self->info->artist, 1);
		$changed++;
    }
	unless ($ginfo->{TMPO} eq $self->info->tempo) {
		$self->status("Storing new tag info for tempo");
		$qt->SetMetaInfo(TMPO => $self->info->tempo, 1);
		$changed++;
    }
	unless ($ginfo->{TOO} eq $self->info->encoder) {
		$self->status("Storing new tag info for encoder");
		$qt->SetMetaInfo(TOO => $self->info->encoder, 1);
		$changed++;
    }
	unless ($ginfo->{NAM} eq $self->info->title) {
		$self->status("Storing new tag info for title");
		$qt->SetMetaInfo(NAM => $self->info->title, 1);
		$changed++;
    }
	unless ($ginfo->{WRT} eq $self->info->composer) {
		$self->status("Storing new tag info for composer");
		$qt->SetMetaInfo(WRT => $self->info->composer, 1);
		$changed++;
    }
	unless ($ginfo->{COMMENT} eq $self->info->comment) {
		$self->status("Storing new tag info for comment");
		$qt->SetMetaInfo(COMMENT => $self->info->comment, 1);
		$changed++;
    }


	unless ($ginfo->{LYRICS} eq $self->info->lyrics) {
		$self->status("Storing new tag info for lyrics");
		my $lyrics = $self->info->lyrics;
		$lyrics =~ s/\r?\n/\r/g;
		$qt->SetMetaInfo(LYRICS => $self->info->lyrics, 1);
		$changed++;
    }

=cut

	if ($changed) {
		$self->status("Writing to $filename...");
		$qt->WriteFile($filename);
	}
    return $self;
}

sub close {

}

1;

# vim: tabstop=4

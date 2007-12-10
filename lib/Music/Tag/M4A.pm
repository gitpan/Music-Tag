package Music::Tag::M4A;
our $VERSION = 0.25;

# Copyright (c) 2007 Edward Allen III. All rights reserved.
#
## This program is free software; you can redistribute it and/or
## modify it under the terms of the Artistic License, distributed
## with Perl.
#

=pod

=head1 NAME

Music::Tag::M4A - Plugin module for Music::Tag to get information from Apple QuickTime headers. 

=head1 SYNOPSIS

use Music::Tag

my $filename = "/var/lib/music/artist/album/track.m4a";

my $info = Music::Tag->new($filename, { quiet => 1 }, "M4A");

$info->get_info();
   
print "Artist is ", $info->artist;

=head1 DESCRIPTION

Music::Tag::M4A is used to read  header information from QuickTime MP4 contonainers. It uses Audio::M4P::Quicktime and MP4::Info.

It is not currently able to write M4A tags.  Audio::M4P::QuickTime can write these tags, but iTunes has trouble reading them after
they have been writen.  Setting the option "write_m4a" will enable some tags to be writen, but iTunes will have problems!

No values are required (except filename, which is usually provided on object creation). You normally read information from Music:Tag::M4P first.

=over 4

=head1 SET VALUES

=cut

use strict;
use Music::Tag;
use Audio::M4P::QuickTime;
use MP4::Info;
our @ISA = qw(Music::Tag::Generic);

sub _default_options {
	{ write_m4a => 0 }
}

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

=pod

=item artist, album 

=item disc, totaldiscs, tempo, encoder, title, composer

=item copyright, track, totaltracks, comment, lyrics

=item bitrate, duration, picture

=cut

	$self->info->releasedate($date);

	$self->info->disc( $tinfo->{discNumber});
	$self->info->totaldiscs( $tinfo->{discCount});
	$self->info->copyright( $tinfo->{copyright} );

    $self->info->tempo( $ginfo->{TMPO} );
    $self->info->encoder( $ginfo->{TOO} || "iTMS");
	$self->info->genre( $qt->genre_as_text );
	$self->info->title( $ginfo->{NAM} );
    $self->info->composer( $ginfo->{WRT} );
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

	if ($self->options->{write_m4a}) {
		$self->status("Writing M4A files is in development and dangerous if you use iTunes. Only some tags supported.");
	}
	else {
		$self->status("Writing M4A files is dangerous.  Set write_m4a to true if you want to try.");
		return $self;
	}

	unless ($ginfo->{ALB} eq $self->info->album) {
		$self->status("Storing new tag info for album");
		$qt->SetMetaInfo(ALB => $self->info->album, 1, 'day');
		$changed++;
    }
	unless ($ginfo->{ART} eq $self->info->artist) {
		$self->status("Storing new tag info for artist");
		$qt->SetMetaInfo(ART => $self->info->artist, 1 , 'nam');
		$changed++;
    }
	unless ($ginfo->{TMPO} eq $self->info->tempo) {
		$self->status("Storing new tag info for tempo");
		$qt->SetMetaInfo(TMPO => $self->info->tempo, 1);
		$changed++;
    }
	unless ($ginfo->{TOO} eq $self->info->encoder) {
		$self->status("Storing new tag info for encoder");
		$qt->SetMetaInfo(TOO => $self->info->encoder, 1, 'covr');
		$changed++;
    }
	unless ($ginfo->{NAM} eq $self->info->title) {
		$self->status("Storing new tag info for title");
		$qt->SetMetaInfo(NAM => $self->info->title, 1, 'wrt');
		$changed++;
    }
	unless ($ginfo->{WRT} eq $self->info->composer) {
		$self->status("Storing new tag info for composer");
		$qt->SetMetaInfo(WRT => $self->info->composer, 1, 'alb');
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
	if ($changed) {
		$self->status("Writing to $filename...");
		$qt->WriteFile($filename);
	}
    return $self;
}

sub close {

}

=pod

=head1 OPTIONS

=item write_m4a

Set to true to allow some tags to be writen to disc.  Not recommended.

=head1 BUGS

M4A Tags are error-prone. Writing tags is not reliable.

=head1 SEE ALSO INCLUDED

L<Music::Tag>, L<Music::Tag::Amazon>, L<Music::Tag::File>, L<Music::Tag::FLAC>, L<Music::Tag::Lyrics>,
L<Music::Tag::MP3>, L<Music::Tag::MusicBrainz>, L<Music::Tag::OGG>, L<Music::Tag::Option>,

=head1 SEE ALSO

L<Audio::M4P::QuickTime>, L<MP4::Info>

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

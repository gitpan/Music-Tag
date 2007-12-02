package Music::Tag::File;
our $VERSION = 0.19;

# Copyright (c) 2007 Edward Allen III. All rights reserved.
#
## This program is free software; you can redistribute it and/or
## modify it under the terms of the Artistic License, distributed
## with Perl.
#
use strict;
use MP3::Tag;
use File::Spec;

#use Image::Magick;
our @ISA = qw(Music::Tag::Generic);

sub get_tag {
    my $self     = shift;
    my $filename = $self->info->filename();
    my @dirs     = File::Spec->splitdir( File::Spec->rel2abs($filename) );
    my $fname    = pop @dirs;
    my $dname    = File::Spec->catdir(@dirs);
    my $album    = pop @dirs;
    my $artist   = pop @dirs;

    $album =~ s/_/ /g;
    $album =~ s/\b(\w)/uc($1)/ge;
    $album =~ s/ *$//g;
    $album =~ s/^ *//g;

    if ( length($album) < 2 ) {
        $album = "";
    }

    $artist =~ s/_/ /g;
    $artist =~ s/\b(\w)/uc($1)/ge;
    $artist =~ s/ *$//g;
    $artist =~ s/ *$//g;
    unless ( $self->info->track ) {
        if ( $fname =~ /^[^\d]*(\d+)[^\d]/ ) {
            my $num = sprintf( "%d", $1 );
            $self->info->track($num);
            $self->tagchange("TRACK");
        }
        else {
            $self->info->track(0);
            $self->tagchange("TRACK");
        }
    }
    unless ( $self->info->title ) {
        my $title = $fname;
        $title =~ s/\..+$//g;
        $title =~ s/^\d+\.?\ +//g;
        $title =~ s/^ *//g;
        $title =~ s/ *$//g;
        $self->info->title($title);
        $self->tagchange("TITLE");
    }
    unless ( $self->info->artist ) {
        $self->info->artist($artist);
        $self->tagchange("ARTIST");
    }
    unless ( $self->info->album ) {
        $self->info->album($album);
        $self->tagchange("ALBUM");
    }
    unless ( $self->info->disc ) {
        $self->info->disc("1/1");
        $self->tagchange("DISC");
    }

    if ( ( not $self->info->picture ) or ( $self->options->{coveroverwrite} ) ) {
        my $fname    = File::Spec->catdir($dname, "folder.jpg");
        my $pfname    = File::Spec->catdir($dname, "folder.png");
        my $cfname    = File::Spec->catdir($dname, "cover.jpg");
        if ( -e $fname ) {
            $self->tagchange( "COVER ART", "from folder.jpg" );
            $self->info->picture( $self->cover_art($fname) );
        }
        elsif ( -e $pfname ) {
            $self->tagchange( "COVER ART", "from folder.png" );
            $self->info->picture( $self->cover_art($pfname) );
        }
        elsif ( -e $cfname ) {
            $self->tagchange( "COVER ART", "from cover.jpg" );
            $self->info->picture( $self->cover_art($cfname) );
        }

    }
    if (    ( not $self->info->lyrics )
         or ( $self->options->{lyricsoverwrite} )
         or ( length( $self->info->lyrics ) < 10 ) ) {
        my $fname = $self->info->filename;
        $fname =~ s/\.[^\.]*$/.txt/;
        if ( -e "$fname" ) {
            $self->tagchange( "LYRICS", "from $fname" );
			my $l = $self->slurp_file($fname);
            $self->info->lyrics($l);
            $l =~ s/\n\r?/ \/ /g;
            $self->tagchange( "LYRICS", substr( $l, 0, 40 ) );
        }
    }
	local *DIR;
	opendir(DIR, $dname);
	while ( my $f = readdir(DIR) ) {
		next if $f =~ /^\./;
        my $fname    = File::Spec->catdir($dname, $f);
		if ($f =~ /\.pdf$/i) {
			unless ($self->info->booklet) {
				$self->tagchange( "BOOKLET", "from $f" );
				$self->info->booklet($f);
			}
		}
		#if ($f =~ /\.txt$/i) {
			#unless ($self->info->lyrics) {
				#$self->tagchange( "LYRICS", "from $fname" );
				#my $l = $self->slurp_file($fname);
				#$self->info->lyrics($l);
				#$l =~ s/\n\r?/ \/ /g;
				#$self->tagchange( "LYRICS", substr( $l, 0, 40 ) );
				#}
		#}
		if ($f =~ /\.jpg$/i) {
			unless ($self->info->picture) {
				$self->tagchange( "COVER ART", "from $f" );
				$self->info->picture( $self->cover_art($fname) );
			}
		}
	}



    return $self;
}

sub slurp_file {
	my $self = shift;
	my $fname = shift;
	local *IN;
	open( IN, $fname ) or return "";
	my $l = "";
	while (<IN>) { $l .= $_ }
	close(IN);
	return $l;
}

sub cover_art {
    my $self    = shift;
    my $picture = shift;
	my ($vol, $root, $file) = File::Spec->splitpath($picture);
    my $pic = { "Picture Type" => "Cover (front)",
                "MIME type"    => "image/jpg",
                Description    => "",
				filename	   => $file,
                _Data          => "",
              };
    if ( $picture =~ /\.png$/i ) {
        $pic->{"MIME type"} = "image/png";
    }
	return $pic;
    local *IN;
	#unless ( open( IN, $picture ) ) {
	#    $self->error("Could not open $picture for read: $!");
	#    return undef;
	#}
	#my $n = 0;
	#my $b = 1;
	#while ($b) {
	#    $b = sysread( IN, $pic->{"_Data"}, 1024, $n );
	#    $n += $b;
	#}
	#close(IN);
	#return $pic;
}

sub save_cover {
    my $self = shift;
    my ( $vol, $dir, $file ) = File::Spec->splitpath( $self->info->filename );
    my $filename = File::Spec->catpath( $vol, $dir, "folder.jpg" );

    #if ($dname eq "/") { $dname = "" } else {$dname = File::Spec->catpath($vol, $dir) }
    my $art = $self->info->picture;
    if ( exists $art->{_Data} ) {
        local *OUT;
        if ( $art->{"MIME type"} eq "image/png" ) {
            $filename = File::Spec->catpath( $vol, $dir, "folder.png" );
        }
        elsif ( $art->{"MIME type"} eq "image/bmp" ) {
            $filename = File::Spec->catpath( $vol, $dir, "folder.jpg" );
        }
        $self->status("Saving cover image to $filename");
        unless ( open OUT, ">$filename" ) {
            $self->status("Error writing to $filename: $!, skipping.");
            return undef;
        }
        my $b = 0;
        my $l = length( $art->{_Data} );
        while ( $b < $l ) {
            my $s = syswrite OUT, $art->{_Data}, 1024, $b;
            if ( defined $s ) {
                $b += $s;
            }
            else {
                $self->status("Error writing to $filename: $!, skipping.");
                return undef;
            }
        }
        close OUT;
    }
    return 1;
}

sub save_lyrics {
    my $self  = shift;
    my $fname = $self->info->filename;
    $fname =~ s/\.[^\.]*$/.txt/;
    my $lyrics = $self->info->lyrics;
    if ($lyrics) {
        local *OUT;
        $self->status("Saving lyrics image to $fname");
        unless ( open OUT, ">$fname" ) {
            $self->status("Error writing to $fname: $!, skipping.");
            return undef;
        }
        print OUT $lyrics;
        close OUT;
    }
    return 1;
}

sub set_tag {
    my $self = shift;
    $self->save_cover( $self->info );
    unless ( $self->info->filename =~ /\.mp3$/i ) {
        $self->save_lyrics( $self->info );
    }
    return $self;
}

1;


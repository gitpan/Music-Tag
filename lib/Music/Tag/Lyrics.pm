package Music::Tag::Lyrics;
our $VERSION = 0.25;

# Copyright (c) 2007 Edward Allen III. All rights reserved.
#
## This program is free software; you can redistribute it and/or
## modify it under the terms of the Artistic License, distributed
## with Perl.
#

=pod

=head1 NAME

Music::Tag::Lyrics - Screen Scraping plugin for downloading lyrics from the web.  

=head1 SYNOPSIS

use Music::Lyrics

my $info = Music::Tag->new($filename, { quiet => 1 });
$info->add_plugin("Lyrics");
$info->get_info();
   
print "Lyrics are ", $info->lyrics;

=head1 DESCRIPTION

Music::Tag::Lyrics is a screen scraper which supports a few lyrics sites to gather lyrics from.  Please note that lyrics
are copyright'd material and downloading them from these sites should only be done for personal use, and never if the 
artist has expressed his/her/their desire to not publize their lyrics.

Artist, Album, and Title are required to be set before using this plugin.

=over 4

=head1 SET VALUES

=item lyrics

=cut

use strict;

#use Music::Tag::Rget;
use URI::WithBase;
use File::Spec;
use URI::Escape qw(uri_escape uri_escape_utf8);
use Encode;
use XML::Simple;
our @ISA = qw(Music::Tag::Generic);

sub _default_options {
	'lyrics_path' => "/mnt/media/music/Lyrics/"
}

sub url_escape {
    my $in = shift;
    $in =~ s/ /+/g;
    return uri_escape_utf8( encode( "utf8", $in ), "^A-Za-z0-9\-_.!\/?=\+" );
}

sub get_tag {
    my $self = shift;
    $self->{rget} = Music::Tag::Rget->new( par => $self );
    $self->{rget}->ua->timeout(20);
    unless ( $self->info->artist && $self->info->title ) {
        $self->status("Lyrics lookup requires ARTIST and TITLE already set!");
        return;
    }
    if ( $self->info->lyrics && not $self->options->{lyricsoverwrite} ) {
        $self->status("Lyrics already in tag");
    }
    else {
        my $lyrics;

=pod

=head1 LYRICS SOURCES

=item filename

Looks for $filename.txt

=cut


        unless ($lyrics) {
            $self->status("Checking for filename...");
            $lyrics = $self->get_lyrics_from_file( $self->info->filename );
        }

=pod

=item wearethelyrics.com

=cut

		unless ($lyrics) {
			$self->status("Checking WeAreThelyrics Lyrics...");
            $lyrics =
              $self->get_lyrics_watl( $self->info->artist, $self->info->title, $self->info->album );
		}

=pod

=item www.uppercutmusic.com

=cut

        unless ($lyrics) {
            $self->status("Checking UC Lyrics...");
            $lyrics =
              $self->get_lyrics_uc( $self->info->artist, $self->info->title, $self->info->album );
        }

=pod

=item www.houseoflyrics.com

=cut

        unless ($lyrics) {
            $self->status("Checking HOL Lyrics...");
            $lyrics =
              $self->get_lyrics_hol( $self->info->artist, $self->info->title, $self->info->album );
        }

=pod

=item leoslyrics.com

=cut

        unless ($lyrics) {
            $self->status("Checking Leos Lyrics...");
            $lyrics =
              $self->get_lyrics_leos( $self->info->artist, $self->info->title, $self->info->album );
        }

=pod

=item lyricsmania.com

=cut

	    unless ($lyrics) {
	        $self->status("Checking Lyricsmania Lyrics...\n");
	        $lyrics = $self->get_lyrics_mania( $self->info->artist, $self->info->title, $self->info->album );
	    }
        if ($lyrics) {
            my $lyricsl = $lyrics;
            $lyricsl =~ s/[\r\n]+/ \/ /g;
            $self->tagchange( "Lyrics", substr( "$lyricsl", 0, 50 ) . "..." );
            $self->info->lyrics($lyrics);
            $self->info->changed(1);
        }
        else {
            $self->status("Lyrics not found");
            if ( $self->options->{lyricsoverwrite} ) {
                $self->info->lyrics("");
            }
        }
    }
    return $self;
}

sub fetch_url {
    my $self  = shift;
    my $url   = shift;
    my $post  = shift;
    my $cache = shift;
    unless ( defined $cache ) {
        $cache = 1;
    }
    my $file = $url;
    if ( $file =~ /\/$/ ) {
        $file .= "index.html";
    }
    $file =~ s/^https?:\/\///;
    $file =~ s/\?\&/_/g;
    my $dir = dirname($file);
    if ( ( -e $file ) && ( not $cache ) ) {
        unlink $file;
    }
    system( "mkdir", "-p", "/tmp/lyrics/$dir" );
    my $res =
      $self->{rget}
      ->fetch_url( url => $url, file => "/tmp/lyrics/$file", post => $post, use_cache => $cache );
    if ( ref $res ) {
        return $res->content;
    }
    else {
        return undef;
    }
}

sub simplify {
    my $self = shift;
    my $in   = shift;
    my $ret  = $in;
    $ret =~ s/\bthe\b//ig;
    $ret =~ s/[^A-Za-z0-9]//g;
    return lc($ret);
}

sub get_lyrics_leos {
    my $self   = shift;
    my $artist = url_escape(shift);
    my $song   = url_escape(shift);
    my $album  = url_escape(shift);

    my $res =
      $self->fetch_url(
        "http://api.leoslyrics.com/api_search.php?auth=LeosLyrics5&artist=${artist}&songtitle=${song}"
      );

	my $xml= XML::Simple::XMLin($res);
	if ((ref $xml) &&  (exists $xml->{searchResults}) && (ref $xml->{searchResults}) && (exists $xml->{searchResults}->{result}) && (ref $xml->{searchResults}->{result})) {
		if ($xml->{searchResults}->{result}->{exactMatch} eq "true") {
			my $hid = $xml->{searchResults}->{result}->{hid};
			return $self->get_lyrics_leos_byhid($hid);
		}
	}
    else {
        return undef;
    }
}

sub get_lyrics_leos_byhid {
    my $self = shift;
    my $hid  = url_escape(shift);
    my $res  = $self->fetch_url("http://api.leoslyrics.com/api_lyrics.php?auth=LeosLyrics5&hid=$hid");
	my $xml= XML::Simple::XMLin($res);
	if ((ref $xml) && (exists $xml->{lyric}) && (ref $xml->{lyric}) && (exists $xml->{lyric}->{text})) {
		my $ret = $xml->{lyric}->{text};
		if (( $ret =~ /The lyrics you requested is not in our archive yet/ ) or 
			( $ret =~ /This artist has requested that the lyrics to th..r songs be removed/) or
            ( $ret =~ /No lyrics available/ )) {
			return undef;
		}
	}
}

sub get_lyrics_mania {
    my $self   = shift;
    my $artist = shift;
    my $song   = shift;
    my $album  = shift;
    my $base   = shift || 'http://www.lyricsmania.com';

    my $res =
      $self->fetch_url( "$base/search.php", "k=" . url_escape($artist) . "&c=artist&I1i=1", 0 );

#print $res;
#<a href="http://www.lyricsmania.com/lyrics/tina_dico_lyrics_7439/" title="Tina Dico lyrics">Tina Dico</a>
    my $simpleartist = $self->simplify($artist);
    my $simplesong   = $self->simplify($song);
    while ( $res =~ /href="[^"]*(\/lyrics\/[^"]+)"[^>]*>([^<]+)\</g ) {
        my $url      = $base . $1;
        my $canidate = $2;
        if ( $self->simplify($canidate) eq $simpleartist ) {
            return $self->get_lyrics_mania_artist( $url, $artist, $song, $album );
        }
        elsif ( $self->simplify($canidate) eq $simplesong ) {
            return $self->get_lyrics_mania_song( $url, $artist, $song, $album );
        }
    }
    return undef;
}

sub get_lyrics_mania_artist {
    my $self   = shift;
    my $url    = shift;
    my $artist = shift;
    my $song   = shift;
    my $album  = shift;
    my $base   = shift || 'http://www.lyricsmania.com';
    my $res    = $self->fetch_url($url);

#<a href="http://www.lyricsmania.com/lyrics/tina_dico_lyrics_7439/in_the_red_lyrics_25123/losing_lyrics_275507.html" title="Losing lyrics">Losing</a><br>
#<a href="http://www.lyricsmania.com/lyrics/abigail_washburn_lyrics_4654/song_of_the_traveling_daughter_lyrics_15187/sometimes_lyrics_176271.html" title="Sometimes lyrics">Sometimes</a><br>
#
    my $simplesong = $self->simplify($song);
    while ( $res =~ /href="[^"]*(\/lyrics\/[^"]+)"[^>]*>([^<]+)</ig ) {
        my $url      = $base . $1;
        my $canidate = $2;
        if ( $self->simplify($canidate) eq $simplesong ) {
            return $self->get_lyrics_mania_song( $url, $artist, $song, $album );
        }
    }
    return undef;
}

sub get_lyrics_mania_song {
    my $self   = shift;
    my $url    = shift;
    my $artist = shift;
    my $song   = shift;
    my $album  = shift;
    my $base   = shift || 'http://www.lyricsmania.com';
    my $res    = $self->fetch_url($url);
    my @lines  = split( /\r?\n/, $res );
    my $ret    = "";
    my $rec    = 0;
    foreach (@lines) {

        if (/<script/i) {
            $rec = 0;
        }
        if (/<h3/i) {
            $rec = 1;
        }
        if ($rec) {
            next if /www.lyricsmania.com\/print.php/;
            next if /www.lyricsmania.com\/lyricsoptions.php/;
            next if /www.lyricsmania.com/;
            next if /$artist.*lyrics/i;
            next if /Artist:/i;
            next if /Album:/i;
            next if /Year:/i;
            next if /Title:/i;
            my $n = $_;
			$n =~ s/\&\#91;.*www\.lyricsmania\.com\/\&\#93;//;
			$n =~ s/<a .*<\/a>//;
            $n =~ s/<br[^>]*>/\n/g;
            $n =~ s/<[^>]*>//g;
            $n =~ s/^\s*//g;
            $n =~ s/\s*$//g;

            if ($n) {
                $ret .= $n . "\n";
            }
        }
    }
    if (( $ret =~ /The lyrics you requested is not in our archive yet/ ) or 
		( $ret =~ /This artist has requested that the lyrics to th..r songs be removed/) or
        ( $ret =~ /No lyrics available/ )) {
        return undef;
    }
    if ($ret) {
        return $ret;
    }
    else {
        return undef;
    }
}

sub basename {
	my $file = shift;
	my ($vol, $dir, $base) = File::Spec->splitpath($file);
	return $base;
}

sub dirname {
	my $file = shift;
	my ($vol, $dir, $base) = File::Spec->splitpath($file);
	return File::Spec->catpath($vol, $dir);
}

sub get_lyrics_from_file {
    my $self     = shift;
    my $filename = shift;
    my $in;
    if ( -e $filename . ".txt " ) {
        $in = $filename . ".txt";
    }
    elsif ( -e $self->options->{lyrics_path} . basename($filename) . ".txt" ) {
        $in =  File::Spec->catdir($self->options->{lyrics_path}, basename($filename) . ".txt");
    }
    if ($in) {
        if ( open( IN, $in ) ) {
            $self->status("Grabing lyrics from text file: $in");
            my $ret = "";
            while (<IN>) {
                $ret .= $_;
            }
            close(IN);
            return $ret;
        }
        else {
            $self->status("Error opening $in for read: $!");
        }
    }
    return undef;

}

sub get_lyrics_hol {
    my $self   = shift;
    my $artist = shift;
    my $song   = shift;
    my $album  = shift;
    my $base   = shift || 'http://www.houseoflyrics.com';

    my $artists = {};
    $self->get_lyrics_hol_alpha( lc( substr( $self->simplify($artist), 0, 1 ) ), $base, $artists );
    $self->get_lyrics_hol_alpha( 't', $base, $artists );

    if ( exists $artists->{ $self->simplify($artist) } ) {
        my $songs = {};
        $self->get_lyrics_hol_artist( $artists->{ $self->simplify($artist) }, $base, $songs );
        if ( exists $songs->{ $self->simplify($song) } ) {
            return $self->get_lyrics_hol_song( $songs->{ $self->simplify($song) } );
        }
        else {
            return undef;
        }
    }
    else {
        return undef;
    }
}

sub get_lyrics_hol_alpha {
    my $self  = shift;
    my $alpha = shift;
    my $base  = shift;
    my $ret   = shift;
    $alpha = lc($alpha);
    $alpha =~ s/[^a-z]/other/g;
    my $res = $self->fetch_url( "$base/${alpha}.html", 1 );
    $res =~ s/[\n\r]/ /g;

    while ( $res =~ /\<A HREF=\"(\/lyrics\/[^"]*)\"[^\>]*\>([^<]*) - Lyrics\</mg ) {
        $ret->{ $self->simplify($2) } = $base . $1;
    }
    return $ret;
}

sub get_lyrics_hol_artist {
    my $self = shift;
    my $url  = shift;
    my $base = shift;
    my $ret  = shift;
    my $res  = $self->fetch_url( "$url", 1 );
    $res =~ s/[\n\r]/ /g;
    while ( $res =~ /\<A HREF=\"(\/lyrics\/[^"]*)\"[^\>]*\>([^<]*)\</mg ) {
        $ret->{ $self->simplify($2) } = $base . $1;
    }
    return $ret;
}

sub get_lyrics_hol_song {
    my $self = shift;
    my $url  = shift;
    my $ret  = shift;
    my $res  = $self->fetch_url( "$url", 1 );
    my $ret  = "";
    my $rec  = 0;
    foreach ( split "\n", $res ) {
        if ($rec) {
            next if /<div/i;
            $ret .= $_;
        }
        if (/<div id="lyrics">/i) {
            $rec = 1;
        }
        if (/<\/div>/i) {
            $rec = 0;
        }
    }
    $ret =~ s/[\r\n]//g;
    $ret =~ s/<br>/\n/gi;
    $ret =~ s/<p>/\n\n/gi;
    $ret =~ s/<[^>]*>//gi;
    if (( $ret =~ /The lyrics you requested is not in our archive yet/ ) or 
		( $ret =~ /This artist has requested that the lyrics to th..r songs be removed/) or
        ( $ret =~ /No lyrics available/ )) {
        return undef;
    }
    else {
        return $ret;
    }
}

sub get_lyrics_watl {
	my $self = shift;
    my $artist = shift;
    my $song   = shift;
    my $album  = shift;
    my $base   = shift || 'http://www.wearethelyrics.com';
    my $artists = $self->get_lyrics_watl_alpha( lc( substr( $self->simplify($artist), 0, 1 ) ), $base );
    if ( exists $artists->{ $self->simplify($artist) } ) {
        my $songs = $self->get_lyrics_watl_artist( $artists->{ $self->simplify($artist) }, $base );
        if ( exists $songs->{ $self->simplify($song) } ) {
            return $self->get_lyrics_watl_song( $songs->{ $self->simplify($song) } );
        }
        else {
            return undef;
        }
    }
    else {
        return undef;
    }
}

sub get_lyrics_watl_alpha {
    my $self  = shift;
    my $alpha = shift;
    my $base  = shift;
    my $ret   = shift || {};
    $alpha = lc($alpha);
    $alpha =~ s/[^a-z]/num/g;
    my $res = $self->fetch_url( "$base/artists/${alpha}.html", 1 );
    $res =~ s/[\n\r]/ /g;

	#<a href="/0/a_fine_frenzy_lyrics_12631.html">A Fine Frenzy</a><br>
    while ( $res =~ /\<a href=\"(\/\d\/[^"]*lyrics_\d+\.html)\"[^\>]*\>([^<]*)\</mgi ) {
        $ret->{ $self->simplify($2) } = $base . $1;
    }
    return $ret;
}

sub get_lyrics_watl_artist {
    my $self = shift;
    my $url  = shift;
    my $base = shift;
    my $ret  = shift || {};
    my $res  = $self->fetch_url( "$url", 1 );
    $res =~ s/[\n\r]/ /g;
	#<a href="/0/a_fine_frenzy_lyrics_12631/one_cell_in_the_sea_lyrics_69412/rangers_lyrics_672507.html">Rangers</a><br>
    while ( $res =~ /\<a href=\"(\/\d\/[^"]*lyrics_\d+\.html)\"[^\>]*\>([^<]*)\</mgi ) {
        $ret->{ $self->simplify($2) } = $base . $1;
    }
    return $ret;
}

sub get_lyrics_watl_song {
    my $self = shift;
    my $url  = shift;
    my $ret  = shift || {};
    my $res  = $self->fetch_url( "$url", 1 );
    my $ret  = "";
    my $rec  = 0;
    foreach ( split "\n", $res ) {
        if ($rec) {
            $ret .= $_ . "\n";
        }
        if (/id="page"/i) {
            $rec = 1;
        }
        if (/id="sidebar"/i) {
            $rec = 0;
        }
    }
    $ret =~ s/<h2>.*<\/h2>//g;
    $ret =~ s/<h3>.*<\/h3>//g;
    $ret =~ s/[\r\n]//g;
    $ret =~ s/<br[^>]*>/\n/gi;
    $ret =~ s/<[^>]*>//gi;
    $ret =~ s/^\s*//;
    $ret =~ s/\s*$//;
    if (( $ret =~ /The lyrics you requested is not in our archive yet/ ) or 
		( $ret =~ /This artist has requested that the lyrics to th..r songs be removed/) or
        ( $ret =~ /No lyrics available/ )) {
        return undef;
    }
    else {
        return $ret;
    }
}


sub get_lyrics_uc {
    my $self   = shift;
    my $artist = shift;
    my $song   = shift;
    my $album  = shift;
    my $base   = shift || 'http://www.uppercutmusic.com';

    my $artists = $self->get_lyrics_uc_alpha( lc( substr( $self->simplify($artist), 0, 1 ) ), $base );

    if ( exists $artists->{ $self->simplify($artist) } ) {
        my $songs = {};
        $self->get_lyrics_uc_artist( $artists->{ $self->simplify($artist) }, $base, $songs );
        if ( exists $songs->{ $self->simplify($song) } ) {
            return $self->get_lyrics_uc_song( $songs->{ $self->simplify($song) } );
        }
        else {
            return undef;
        }
    }
    else {
        return undef;
    }
}

sub get_lyrics_uc_alpha {
    my $self  = shift;
    my $alpha = shift;
    my $base  = shift;
    my $ret   = shift || {};
    $alpha = lc($alpha);
    $alpha =~ s/[^a-z]/other/g;
    my $res = $self->fetch_url( "$base/artist_${alpha}.html", 1 );
    $res =~ s/[\n\r]/ /g;

    #<a href="/artist_t/t-bone_lyrics.html" title="T-Bone lyrics of songs">T-Bone</a><br>
    #<a href="/artist_p/pj_harvey_lyrics.html" title="Pj Harvey lyrics of songs">Pj Harvey</a><br>
    while ( $res =~ /\<A HREF=\"(\/artist_.\/[^"]*)\"[^\>]*\>([^<]*)\</mgi ) {
        $ret->{ $self->simplify($2) } = $base . $1;
    }
    return $ret;
}

sub get_lyrics_uc_artist {
    my $self = shift;
    my $url  = shift;
    my $base = shift;
    my $ret  = shift || {};
    my $res  = $self->fetch_url( "$url", 1 );
    $res =~ s/[\n\r]/ /g;
    while ( $res =~ /\<A HREF=\"(\/artist_.\/[^"]*)\"[^\>]*\>([^<]*)\</mgi ) {
        $ret->{ $self->simplify($2) } = $base . $1;
    }
    return $ret;
}

sub get_lyrics_uc_song {
    my $self = shift;
    my $url  = shift;
    my $ret  = shift || {};
    my $res  = $self->fetch_url( "$url", 1 );
    my $ret  = "";
    my $rec  = 0;
    foreach ( split "\n", $res ) {
        if ($rec) {

            #         next if /<div/i;
            $ret .= $_ . "\n";
        }
        if (/id="song_txt"/i) {
            $rec = 1;
        }
        if (/<\/table>/i) {
            $rec = 0;
        }
    }

    #$ret =~ s/[\r\n]//g;
    $ret =~ s/<br>/\n/gi;
    $ret =~ s/<p>/\n\n/gi;
    $ret =~ s/<[^>]*>//gi;
    $ret =~ s/^[ \t\r\n]*//;
    $ret =~ s/[ \t\r\n]*$//;
    if (( $ret =~ /The lyrics you requested is not in our archive yet/ ) or 
		( $ret =~ /This artist has requested that the lyrics to th..r songs be removed/) or
        ( $ret =~ /No lyrics available/ )) {
        return undef;
    }
    else {
        return $ret;
    }
}

1;

package Music::Tag::Rget;
use strict;
use vars qw($AUTOLOAD);

$Music::Tag::Rget::VERSION = "0.1";

use URI::WithBase;
use LWP::MediaTypes qw(media_suffix);
use HTML::Entities ();
use Time::HiRes qw(sleep);

$DB::deep = 200;

our $WIDTH = 80;

sub new {
    my $class = shift;
    my $self  = _named_options(@_);
    bless $self, $class;
    $self->init();
    return $self;
}

sub init {
    my $self = shift;
    unless ( exists $self->{filter} ) {
        $self->{filter} = {};
    }
    unless ( exists $self->{depth} ) {
        $self->{depth} = {};
    }
}

sub ua {
    my $self = shift;
    if ( ref $_[0] ) {
        $self->{ua} = shift;
    }
    unless ( ref $self->{ua} ) {
        $self->get_ua();
    }
    return $self->{ua};
}

sub referer {
    my $self = shift;
    if ( defined $_[0] ) {
        my $referer = shift;
        unless ( ref $referer ) {
            $referer = URI::WithBase->new($referer);
        }
        $self->{referer} = $referer;
    }
    unless ( exists $self->{referer} ) {
        $self->{referer} = {};
    }
    return $self->{referer};
}

sub url {
    my $self = shift;
    if ( defined $_[0] ) {
        my $url = shift;
        unless ( ref $url ) {
            $url = URI::WithBase->new($url);
        }
        $self->{url} = $url;
    }
    unless ( exists $self->{url} ) {
        $self->{url} = {};
    }
    return $self->{url};
}

sub get_ua {
    my $self = shift;
    require LWP::UserAgent;
    my $ua = new LWP::UserAgent;
    $ua->agent(
          'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.8) Gecko/20050511 Firefox/1.0.4');
    $ua->env_proxy;
    $ua->cookie_jar( { file => "$ENV{HOME}/cookies.txt", autosave => 1, ignore_discard => 1 } );
    $self->{ua} = $ua;
    return $ua;
}

sub _pp {
    my $x  = shift || "0";
    my $kb = 1024;
    my $mb = 1024 * $kb;
    my $gb = 1024 * $mb;
    if ( $x > $gb ) {
        return int( $x / $gb ) . " GB";
    }
    if ( $x > $mb ) {
        return int( $x / $mb ) . " MB";
    }
    if ( $x > $kb ) {
        return int( $x / $kb ) . " KB";
    }
    return "$x";
}

sub _progress_bar {
    my ( $got, $total, $width, $char ) = @_;
    $width ||= 25;
    $char  ||= '=';
    my $num_width = length $total;
    sprintf "|%-${width}s|", $char x ( ( $width - 1 ) * $got / $total ) . '>';
}

sub status {
    my $self     = shift;
    my $priority = shift;
	#$self->{par}->status( "Rget: ", @_ );
}

sub status_print {
    my $self = shift;

   #  my ( $size, $total, $url ) = @_;
   #  my @animation = qw ( \ | / - );
   #  my $c         = $self->{count};
   #  if ($total) {
   #     $self->status( 1,
   #                    sprintf( " [%6s / %6s] %1s ", _pp($size), _pp($total), $animation[ $c++ ] ),
   #                    _progress_bar( $size, $total, $WIDTH - 24, "=" ), "\r" );
   #  }
   #  else {
   #     $self->status( 1, sprintf( "[%6s] %1s \r", _pp($size), $animation[ $c++ ] ) );
   #  }
   #  $c = 0 if $c == scalar(@animation);
   #  $self->{count} = $c;
}

sub border {
    my $self = shift;
    $self->status( 1, "-" x $WIDTH );
}

sub _named_options {
    my $options = {};
    if   ( ref $_[0] ) { $options = $_[0]; }
    else               { $options = {@_}; }
    return $options;
}

sub fetch_url {
    my $self    = shift;
    my $options = _named_options(@_);

    my @stored = qw(url referer overwrite use_cache);
    foreach (@stored) {
        unless ( exists $options->{$_} ) {
            $options->{$_} = $self->{$_};
        }
    }
    unless ( $options->{recursions} ) {
        $options->{recursions} = 0;
    }
    if ( $options->{recursions} > 10 ) {
        $self->status( 0, "Too many recurssions!" );
        return undef;
    }

    my $ua      = $self->ua;
    my $url     = $options->{url};
    my $file    = $options->{file};
    my $referer = $options->{referer};
    my $post    = $options->{post};
    my $force   = $options->{overwrite};

    unless ($url) {
        print STDERR 'usage: fetch_url(url => $url)', "\n";
        return;
    }

    unless ( ref $referer ) {
        $referer = URI::WithBase->new($referer);
    }

    $url = $url->as_string if ( ref($url) );
    while ( $url =~ s#(https?://[^/]+/)\.\.\/#$1# ) { }
    $self->status( 1, "Fetching $url" );
    $url = URI::WithBase->new($url);

    # The $plain_url is a WithBase without the fragment part
    my $plain_url = $url->clone;
    $plain_url->fragment(undef);

    my $req = HTTP::Request->new( GET => $url );

    # Submit a Post request if post defined
    if ( defined $post ) {
        $req = HTTP::Request->new( POST => $url );
        $req->content_type('application/x-www-form-urlencoded');
        $req->content($post);
    }

    if ($referer) {
        if ( $req->url->scheme eq 'http' ) {
            $referer = URI::WithBase->new($referer) unless ref($referer);

            # RFC 2616, section 15.1.3
            #undef $referer if ($referer->scheme || '') eq 'https';
        }
        $req->referer($referer) if $referer;
    }

    $ua->cookie_jar->add_cookie_header($req);

    my $filehandle = undef;
    if ( defined $file ) {
        $filehandle = Music::Tag::Auto::Rget::File->new($file);
    }

    my $res = undef;
    unless ($force) {
        if ( ( defined $file ) && ( -f $file ) ) {
            my @stat = stat $file;
            $req->headers->if_modified_since( $stat[9] );
            return if ( $options->{nooverwrite} );
            if ( $options->{use_cache} ) {
                $self->status( 1, "Using $file to get response" );
                $res = $self->use_cache( $req, $filehandle );
            }
        }
    }

    my $content = "";
    my $size    = 0;
    my $total   = 0;
    unless ($res) {

        #print STDERR $req->as_string();
        $res = $ua->request(
            $req,
            sub {
                my ( $data, $response, $protocol ) = @_;
                if ( defined($total) && ( not $total ) ) {
                    $total = $response->headers->content_length();
                }

                $size += length($data);
                $self->status_print( $size, $total, $url );

                if ( ( $total || 0 ) > ( 100 * 1024 ) ) {
                    $filehandle->write($data);
                }
                if ( ( $total || 0 ) < ( 10 * 1024 * 1024 ) ) {
                    $content .= $data;
                }

            },
            4096
                           );
        $self->status( 1, sprintf( "[%6s]", _pp($size) ), " " x ( $WIDTH - 9 ) );
    }

    unless ( defined $res ) {
        $self->status( 0, "Error: response is undefined" );
        return;
    }

    if ( defined $filehandle ) {
        $filehandle->register_res($res);
    }

    if ( $res->is_success ) {
        $ua->cookie_jar->extract_cookies($res);
        $ua->cookie_jar->save;
        if ( defined $file ) {
            unless ( $filehandle->written > 0 ) {
                $self->status( 1, "Writing content to file" );
                $res->content_ref( \$content );
                $filehandle->write_res($res);
            }
            $filehandle->close();
            $self->status( 1, "Saved to $file" );
        }
        return $res;
    }

    # Check for redirection...
    elsif ( $res->code == 302 ) {
        $options->{recursions}++;
        $options->{url} = $res->header('Location');
        return $self->fetch_url($options);
    }
    else {
        $self->status( 0, "Request failed: ", $res->status_line );
        print $res->headers->as_string;
        return undef;
    }
}

sub get_filename {
    my $self = shift;
    my $url  = shift;
    unless ( ref $url ) {
        $url = URI::WithBase->new($url);
    }
    return
      unless (    ( $url->scheme eq "http" )
               or ( $url->scheme eq "https" )
               or ( $url->scheme eq "ftp" ) );
    my $file = $url->host . "/" . $url->path;
    $file =~ s/\/+/\//g;
    $file =~ s/\/+$//g;
    $file =~ s/[\n\r\t]/_/g;

    # If $file has no extension, rename to /index.html
    unless ( $file =~ /[^\/]+\.[^\/]+$/ ) {
        $file = $file . "/index.html";
    }
    return $file;
}

sub gather_urls {
    my $self        = shift;
    my $res         = shift;
    my $extra_regex = shift;
    my $base        = $res->base;
    my @imgs        = ();
    my @urls        = ();
    my $cont        = "";
    $cont = $res->content;

    while (
        $cont =~ /
  (
    <(img|a|body|area|frame|td)\b   # some interesting tag
    [^>]+			    # still inside tag (not strictly correct)
    \b(?:src|href|background)	    # some link attribute
    \s*=\s*			    # =
  )
    (?:				    # scope of OR-ing
	 (")([^"]*)"	|	    # value in double quotes  OR
	 (')([^']*)'	|	    # value in single quotes  OR
	    ([^\s>]+)		    # quoteless value
    )
/gix
      ) {
        my $url = URI::WithBase->new( HTML::Entities::decode( $4 || $6 || $7 ), $base )->abs;
        if ( $url->as_string =~ /\.(jpg|gif|swf)/i ) {
            push @imgs, $url;
        }
        else {
            push @urls, $url;
        }
    }

    # Look for a refresh
    if ( $cont =~ /HTTP-EQUIV=\"Refresh\"[^>]+CONTENT=\"\d+;WithBase=([^"]+)\"/i ) {
        my $url = URI::WithBase->new( HTML::Entities::decode($1), $base )->abs;
        if ( $url->as_string =~ /\.(jpg|gif|swf)/i ) {
            push @imgs, $url;
        }
        else {
            push @urls, $url;
        }
    }
    foreach my $re ( @{$extra_regex} ) {
        while ( $cont =~ /$re/gi ) {

            #print STDERR "Found Regex: $re\n";
            my $url = URI::WithBase->new( HTML::Entities::decode($1), $base )->abs;
            if ( $url->as_string =~ /\.(jpg|gif|swf)/i ) {
                push @imgs, $url;
            }
            else {
                push @urls, $url;
            }
        }
    }
    push @imgs, @urls;
    return \@imgs;
}

sub filter_urls {
    my $self    = shift;
    my $inurls  = shift;
    my $filter  = shift;
    my $outurls = [];
    foreach my $url ( @{$inurls} ) {
        if ( $self->filter_url( $url, $filter ) ) {
            push @{$outurls}, $url;
        }
    }
    return $outurls;
}

sub filter_url {
    my $self   = shift;
    my $url    = shift;
    my $filter = shift;
    $url = URI::WithBase->new($url) unless ( ref $url );
    return
      unless (    ( $url->scheme eq "http" )
               or ( $url->scheme eq "https" )
               or ( $url->scheme eq "ftp" ) );

    #    print STDERR "Processing ", $url->as_string(), "\n";
    if ( exists $filter->{accept_domains} ) {
        return unless ( exists $filter->{accept_domains}->{ $url->host } );
    }
    if ( exists $filter->{reject_domains} ) {
        return if ( exists $filter->{reject_domains}->{ $url->host } );
    }

    #    print STDERR "Domain OK\n";
    my $extension = 'html';
    if ( $url->path =~ /[^\/]+\.([^\/]+)$/ ) {
        $extension = lc($1);
    }
    if ( exists $filter->{reject_extensions} ) {
        return if ( $filter->{reject_extensions}->{$extension} );
    }
    if ( exists $filter->{accept_extensions} ) {
        return unless ( $filter->{accept_extensions}->{$extension} );
    }

    #    print STDERR "Extensions OK\n";
    if ( exists $filter->{reject_regex} ) {
        foreach my $re ( @{ $filter->{reject_regex} } ) {
            return if ( $url->path =~ /$re/ );
        }
    }

    #    print STDERR "REGEX OK\n";
    if ( exists $filter->{parent} ) {
        my $re = $filter->{parent};
        return unless ( $url->path =~ /^\Q$re\E/i );
    }

    #    print STDERR "Parent OK\n";
    return $url;
}

sub sleep_rand {
    my $self    = shift;
    my $options = shift;
    my $sleep   = 1;
    if ( ref $options ) {
        my $sleep_min = $options->{sleep_min};
        my $sleep_max = shift || $sleep_min;
        $sleep = rand( $sleep_max - $sleep_min ) + $sleep_min;
    }
    else {
        $sleep = $options;
    }
    if ( $sleep > 0 ) {
        sleep $sleep;
    }
}

sub recurse {
    my $self               = shift;
    my $options            = _named_options(@_);
    my $ua                 = $self->ua;
    my $url                = $options->{url} || $self->url;
    my $depth              = $options->{depth} || $self->depth;
    my $referer            = $options->{referer} || $self->referer;
    my $filter             = $options->{filter} || $self->filter;
    my $overwrite          = $options->{overwrite} || $self->overwrite;
    my $nooverwrite        = $options->{nooverwrite} || $self->nooverwrite;
    my $nooverwrite_filter = $options->{nooverwrite_filter} || $self->noverwrite_filter;
    my $use_cache_filter   = $options->{use_cache_filter};
    my $use_cache          = $options->{use_cache};

    delete $options->{depth};
    delete $options->{referer};
    delete $options->{url};

    if ( ref $url ) {
        $url = $url->as_string;
    }

    if ( exists $self->seen->{$url} ) {
        return;
    }

    if ( $depth == 0 ) {
        return;
    }
    elsif ( $depth < -60 ) {
        return;
    }

    my $file = $self->get_filename($url);
    return unless $file;

    if ( ($nooverwrite) && ( -e $file ) ) {
        $self->status( 1, "Skipping existing file $file" );
        $self->border();
        return;
    }
    elsif ( ( defined $nooverwrite_filter ) && ( -e $file ) ) {
        if ( $self->filter_url( $url, $nooverwrite_filter ) ) {
            $self->status( 1, "Not overwriting because of filter for $url" );
            $self->border();
            return;
        }
    }

    if ( ( defined $use_cache_filter ) && ( -e $file ) ) {
        if ( $self->filter_url( $url, $use_cache_filter ) ) {
            $use_cache = 1;
        }
    }

    my $res = $self->fetch_url( url       => $url,
                                file      => $file,
                                referer   => $referer,
                                overwrite => $overwrite,
                                use_cache => $use_cache,
                              );

    $self->seen->{$url} = 1;
    return unless $res;

    if ( defined $options->{callback} ) {
        &{ $options->{callback} }( $url, $res, $file );
    }
    if ( defined $options->{sleep} ) {
        $self->sleep_rand( $options->{sleep} );
    }
    $self->border();

    if ( $res->content_type eq "text/html" ) {
        my $urls = $self->filter_urls( $self->gather_urls( $res, $options->{url_regex} ), $filter );
        foreach ( @{$urls} ) {

            #	    print STDERR $_, "\n";
            $self->recurse( url     => $_,
                            depth   => $depth - 1,
                            referer => $url,
                            %{$options}
                          );
        }
    }
}

sub use_cache {
    my $self       = shift;
    my $req        = shift;
    my $filehandle = shift;
    my $res        = HTTP::Response->new( 200, "OK", $req->headers );

    my $file = $filehandle->{filename};

    my $base = $req->uri->as_string();

    unless ( $base =~ /[^\/]+\.[^\/]+$/ ) {
        $base =~ s/\/$//g;
        $base = $base . "/index.html";
    }

    local *IN;
    unless ( -e $file ) {
        $self->status( 1, "$file doesn't exists yet" );
        return undef;
    }

    unless ( open( IN, $file ) ) {
        $self->status( 1, "Couldn't open $file" );
        return undef;
    }

    my $content = "";
    while (<IN>) {
        $content .= $_;
    }
    $res->content($content);
    $res->content_type('text/html');
    $res->header( 'Content-Base', $base );
    $res->request($req);
    close(IN);
    my @stat = stat($file);
    $res->date( $stat[9] );
    $filehandle->written(1024);
    return $res;
}

sub AUTOLOAD {
    my $self = shift;
    my $attr = $AUTOLOAD;
    $attr =~ s/.*:://;
    if (@_) {
        my $val     = shift;
        my $default = shift;
        if ( defined $val ) {
            $self->{ lc($attr) } = $val;
        }
        elsif ( defined $default ) {
            $self->{ lc($attr) } = $default;
        }
    }
    return $self->{ lc($attr) };
}

=pod

=head1 OPTIONS

=item lyrics_path

Path to folder containing lyrics text files.

=head1 BUGS

This method is always unreliable unless great care is taken in file naming. 

=head1 SEE ALSO INCLUDED

L<Music::Tag>, L<Music::Tag::Amazon>, L<Music::Tag::File>, L<Music::Tag::FLAC>, 
L<Music::Tag::M4A>, L<Music::Tag::MP3>, L<Music::Tag::MusicBrainz>, L<Music::Tag::OGG>, L<Music::Tag::Option>

=head1 AUTHOR 

Edward Allen III <ealleniii _at_ cpan _dot_ org>


=head1 COPYRIGHT

Copyright (c) 2007 Edward Allen III. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the Artistic License, distributed
with Perl.


=cut


1;

package Music::Tag::Auto::Rget::File;
use strict;
use vars qw($AUTOLOAD);
use IO::File;
use File::Spec;

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    $self->{filename} = shift;
    return $self;
}

sub basename {
	my $file = shift;
	my ($vol, $dir, $base) = File::Spec->splitpath($file);
	return $base;
}

sub dirname {
	my $file = shift;
	my ($vol, $dir, $base) = File::Spec->splitpath($file);
	return File::Spec->catpath($vol, $dir);
}

sub open {
    my $self = shift;
    my $dir  = dirname( $self->{filename} );
    unless ( -d $dir ) {

        #_mkdirp ($dir, 0775);
        system( "mkdir", "-p", $dir );
    }
    unless ( $self->handle->open( $self->{filename}, "w", 0666 ) ) {
        die "Couldn't open $self->{filename} for write";
    }
    $self->{opened} = 1;
    return $self;
}

sub handle {
    my $self = shift;
    unless ( exists $self->{handle} ) {
        $self->{handle} = IO::File->new();
    }
    return $self->{handle};
}

sub mtime {
    my $self = shift;
    if ( defined $_[0] ) {
        $self->{mtime} = shift;
    }
    unless ( exists $self->{mtime} ) {
        $self->{mtime} = time;
    }
    return $self->{handle};
}

sub written {
    my $self = shift;
    if ( defined $_[0] ) {
        $self->{written} = shift;
    }
    unless ( defined $self->{written} ) {
        $self->{written} = 0;
    }
    return $self->{written};
}

sub _mkdirp {
    my ( $directory, $mode ) = @_;
    my @dirs   = split( /\//, $directory );
    my $path   = shift(@dirs);                # build it as we go
    my $result = 1;                           # assume it will work

    unless ( -d $path ) {
        $result &&= mkdir( $path, $mode );
    }

    foreach (@dirs) {
        $path .= "/$_";
        if ( !-d $path ) {
            $result &&= mkdir( $path, $mode );
        }
    }
    return $result;
}

sub register_res {
    my $self = shift;
    my $res  = shift;
    $self->mtime( $res->headers->last_modified || $res->headers->date );
}

sub write_res {
    my $self = shift;
    my $res  = shift;

    $self->register_res($res);
    unless ( $self->{opened} ) {
        $self->open();
    }

    my $content = "";
    $content = $res->content;
    $self->mtime( $res->headers->last_modified || $res->headers->date );

    $self->write( $res->content_ref );
    $self->written(1);
}

sub write {
    my $self    = shift;
    my $content = shift;
    my $ref;
    if ( ref $content ) {
        $ref = $content;
    }
    else {
        $ref = \$content;
    }
    $self->written( $self->written + length($$ref) );
    unless ( $self->{opened} ) {
        $self->open();
    }
    $self->handle->print($$ref);

}

sub close {
    my $self = shift;
    if ( $self->{opened} ) {
        die "Couldn't close file $self->{filename}\n" unless ( $self->handle->close );
    }
    my $mtime = $self->{mtime} || time;
    utime $mtime, $mtime, $self->{filename};
    return 1;
}

sub AUTOLOAD {
    my $self = shift;
    my $attr = $AUTOLOAD;
    $attr =~ s/.*:://;
    if (@_) {
        my $val     = shift;
        my $default = shift;
        if ( defined $val ) {
            $self->{ lc($attr) } = $val;
        }
        elsif ( defined $default ) {
            $self->{ lc($attr) } = $default;
        }
    }
    return $self->{ lc($attr) };
}

1;


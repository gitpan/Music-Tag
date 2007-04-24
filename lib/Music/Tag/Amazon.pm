package Music::Tag::Amazon;
our $VERSION=0.19;

# Copyright (c) 2007 Edward Allen III. All rights reserved.
#
## This program is free software; you can redistribute it and/or
## modify it under the terms of the Artistic License, distributed
## with Perl.
#

=pod

=head1 NAME

Music::Tag::Amazon - Plugin module for Music::Tag to get information from Amazon.com

=head1 SYNOPSIS

use Music::Tag

my $info = Music::Tag->new($filename);
   
my $plugin = $info->add_plugin("Amazon");
$plugin->get_tag;

print "Record Label is ", $info->label();

=head1 DESCRIPTION

Music::Tag::Amazon is normally created in Music::Tag. This plugin gathers additional information about a track from amazon, and updates the tag object.


=over 4

=head1 REQUIRED VALUES


=item artist

=head1 USED VALUES

=item asin

If the asin is set, this is used to look up the results instead of the artist name.

=item album

This is used to filter results. 

=item releasedate

This is used to filter results. 

=item totaltracks

This is used to filter results. 

=item title

title is used only if track is not true, or if trust_title option is set.

=item tracknum

tracknum is used only if title is not true, or if trust_track option is set.

=head1 SET VALUES

=item album

=item title

title is set only if trust_track is true.

=item track

track is set only if track is not true or trust_title is true.

=item picture

highres is tried, then medium-res, then low. If low-res is a gif, it gives up.

=item asin

=item label

=item releasedate


=cut

use strict;
use Net::Amazon;
use Net::Amazon::Request::Artist;
use Net::Amazon::Request::ASIN;
use Cache::FileCache;
use LWP::UserAgent;
our @ISA = qw(Music::Tag::Generic);

sub default_options {
   {
   	quiet		=> 0,
	verbose		=> 0,
	trust_title   	=> 0,
	trust_track   	=> 0,
	coveroverwrite  => 0,
        token        	=> "0V2FQAQSWYH6XMJB8G82",
	min_album_points	=> 10,
	ignore_asin     => 0,
	max_pages	=> 10,
	locale		=> "us",
   };
}
=pod
=head1 OPTIONS

Music::Tag::Amazon accepts the following options:

=item  quiet

Setting to true turns off status messages.

=item verbose

Setting to true increases verbosity.

=item trust_title

When this is true, and a tag object's track number is different than the track number of the song with the same title in the Amazon listing, then the tagobject's tracknumber is updated. In other words, we trust that the song has accurate titles, but the tracknumbers may not be accurate.  If this is true and trust_track is true, then trust_track is ignored.

=item trust_track

When this is true, and a tag objects's title conflicts with the title of the corresponding track number on the Amazon listing, then the tag object's title is set to that of the track number on amazon.  In other words, we trust that the track numbers are accurate in the tag object. If trust_title is true, this option is ignored.

=item coveroverwrite

When this is true, a new cover is downloaded and the current cover is replaced.  The current cover is only replaced if a new cover is found.

=item token

Amazon Developer token. Change to one given to you by Amazon.

=item amazon_ua

A Net::Amazon object. Used if you want to define your own options for Net::Amazon. 

=item lwp_ua

A LWP::UserAgent object. Used if you want to define your own options.

=item amazon_cache

A cache object. Used by default Net::Amazon object to store results. A Cache::FileCache object by default.

=item coverart_cache

A cache object. Used to store coverart in.  A Cache::FileCache object by default.

=item min_album_points

Minimum number of points an album must have to win election. Default 10.

=head1 METHODS

=item get_tag

Updates current tag object with information from Amazon database.

=cut

sub get_tag {
   my $self = shift;

   my $filename = $self->info->filename;

   unless ( $self->info->artist ) {
      $self->status("Amazon lookup requires ARTIST already set!");
   }

   my $p = $self->_album_lookup( $self->info, $self->options );
   unless ( ( defined $p ) && ( $p->{album} ) ) {
      $self->status("Amazon lookup failed");
      return $self->info;
   }
   $self->status("Amazon lookup successfull");
   my $totaltracks = scalar @{ $p->{tracks} };
   unless ( $totaltracks == $totaltracks ) {
      $self->info->totaltracks($totaltracks);
      $self->tagchange("TOTALTRACKS");
   }
   my $tracknum = 0;
   if (($self->options->{trust_title}) or ( not $self->info->track )) {
      my $n = 0;
      foreach my $tr ( @{ $p->{tracks} } ) {
         $n++;
         if ( $self->simple_compare( $self->info->title, $tr, ".90" ) ) {
	    unless ($self->info->track eq $n) {
               $self->info->track($n);
               $self->tagchange("TRACK");
	    }
	    $tracknum = $n;
            last;
         }
      }
   }
   elsif ($self->options->{trust_track} && $self->info->track()) {
      $tracknum = $self->info->track();
   }
   if (($tracknum) and not (lc($p->{tracks}->[$tracknum - 1]) eq lc($self->info->title))) {
      $self->info->title($p->{tracks}->[$tracknum - 1]);
      $self->tagchange("TITLE");
   }
   unless ( ( $p->{album} ) && ( lc( $p->{album} ) eq lc( $self->info->album ) ) ) {
      $self->info->album( $p->{album} );
      $self->tagchange("ALBUM");
   }
   my $releasedate = $self->_amazon_to_sql( $p->ReleaseDate );
   unless ( ($releasedate) && ( $releasedate eq $self->info->releasedate ) ) {
      $self->info->releasedate($releasedate);
      $self->tagchange("RELEASEDATE");
   }
   unless ( ( $p->{label} ) && ( lc( $p->{label} ) eq lc( $self->info->label ) ) ) {
      $self->info->label( $p->{label} );
      $self->tagchange("LABEL");
   }
  my $asin = $p->{Asin} || $p->{ASIN};
   unless ( ( $asin ) && ( lc( $asin ) eq lc( $self->info->asin ) ) ) {
      $self->info->asin( $asin );
      $self->tagchange("ASIN");
   }
   if (    ( $p->{ImageUrlLarge} )
        && ( ( not $self->info->picture ) || ( $self->options('coveroverwrite') ) ) ) {
      $self->status("DOWNLOADING COVER ART");
      $self->info->picture( $self->_cover_art($p) );
   }
   return $self;
}

sub lwp {
   my $self = shift;
   unless ((exists $self->{lwp}) && ($self->{lwp})) {
      if ($self->options->{amazon_ua}) {
         $self->{lwp_ua} = $self->options->{lwp_ua};
      }
      else {
         $self->{lwp_ua} = LWP::UserAgent->new();
      }

   }
   return $self->{lwp_ua}
}

sub amazon_cache {
   my $self = shift;
   unless ((exists $self->{amazon_cache}) && ($self->{amazon_cache})) {
      if ($self->options->{amazon_cache}) {
         $self->{amazon_cache} = $self->options->{amazon_cache};
      }
      else {
         $self->{amazon_cache} = Cache::FileCache->new(
                                                  { namespace          => "amazon_cache",
                                                    default_expires_in => 60000,
                                                  }
                                                );
      }
   }
   return $self->{amazon_cache};
}

sub coverart_cache {
   my $self = shift;
   unless ((exists $self->{coverart_cache}) && ($self->{coverart_cache})) {
      if ($self->options->{coverart_cache}) {
         $self->{coverart_cache} = $self->options->{coverart_cache};
      }
      else {
         $self->{coverart_cache} = Cache::FileCache->new(
                                                  { namespace          => "coverart_cache",
                                                    default_expires_in => 60000,
                                                  }
                                                );
      }
   }
   return $self->{coverart_cache};

}

sub amazon_ua {
   my $self = shift;
   unless ((exists $self->{amazon_ua}) && ($self->{amazon_ua})) {
      if ($self->options->{amazon_ua}) {
         $self->{amazon_ua} = $self->options->{amazon_ua};
      }
      else {
         $self->{amazon_ua} = Net::Amazon->new( token => $self->options->{token}, 
                                          cache => $self->amazon_cache, 
					  max_pages => $self->options->{max_pages},
					  locale => $self->options->{locale},
					  strict => 1,
					  rate_limit => 1,);
      }
   }
   return $self->{amazon_ua};
}

=pod

=head1 METHEDOLOGY

If the asin value is true in the tag object, then the lookup is done with this value. Otherwise, it performs a search for all albums by artist, and then waits each album to see which is the most likely. It assigns point using the following values:

  Matches ASIN:            64 pts
  Full name match:         32 pts
   or close name match:    16 pts
  Contains name of track:  10 pts
   or title match:         8 pts 
  Matches totaltracks:     4 pts
  Matches year:            2 pts
  Older than last match:   1 pts

Highest album wins. A minimum of 10 pts needed to win the election by default (set by min_album_points option).

Close name match means that both names are the same, after you get rid of white space, articles (the, a, an), lower case everything, translate roman numerals to decimal, etc.

=cut
sub _album_lookup {
   my $self = shift;

   my $req = Net::Amazon::Request::Artist->new( artist => $self->info->artist );

   if ( ($self->info->asin) && (not $self->options->{ignore_asin}) ) {
      $self->status( "Doing ASIN lookup with ASIN: ", $self->info->asin );
      $req = Net::Amazon::Request::ASIN->new( asin => $self->info->asin );
   }

   my $resp = $self->amazon_ua->request($req);
   my $n    = 0;

   my $maxscore = 0;
   my $curmatch = undef;

   if ( $resp->is_error() ) {
      $self->error( $resp->message() );
      return;
   }

   for my $p ( $resp->properties ) {
      $n++;
      my $score = 0;
      unless ( exists $p->{tracks} ) {
         next;
      }
      unless ($curmatch) {
         $curmatch = $p;
      }
	  my $asin = $p->{Asin} || $p->{ASIN};
	  print STDERR "Checking out ASIN: ", $asin, "\n";
      if (($asin) && ( uc($asin) eq uc($self->info->asin) ) && (not $self->options->{ignore_asin})) {
         $score += 64;
      }
      if ( $p->{album} eq $self->info->album ) {
         $score += 32;
      }
      elsif ( $self->simple_compare( $p->{album}, $self->info->album, ".80" ) ) {
         $score += 16;
      }
      if ( scalar @{ $p->{tracks} } == $self->info->totaltracks ) {
         $score += 4;
      }
      if ( $p->{year} == $self->info->year ) {
         $score += 2;
      }
      if ( $p->{year} < $curmatch->{year} ) {
         $score += 1;
      }
      my $m = 0;
      my $t = 0;
      foreach ( @{ $p->{tracks} } ) {
         if ( $self->simple_compare( $_, $self->info->title, ".90" ) ) {
            $m++;
            $t = $m;
         }
      }
     if ($m) {
         $score += 8;
         if ( $t == $self->info->track ) {
            $score += 2;
         }
      }
      if ( $score > $maxscore ) {
         $curmatch = $p;
         $maxscore = $score;
      }
   }
   if ( $maxscore < $self->options->{min_album_points} ) {
      $self->status( "No album scored over " . $self->options->{min_album_points} ." [ " . $n . " canidates ]" );
      return;
   }
   $self->status(   "Album title "
                  . $curmatch->{album}
                  . " won with score of $maxscore [ "
                  . $n
                  . " canidates]" );
   return $curmatch;
}


sub _cover_art {
   my $self = shift;
   my $p    = shift;
   return unless ( ref $p );
   my $url = $p->{ImageUrlLarge} || $p->{ImageUrlMedium};
   my $art = $self->coverart_cache->get($url);

   unless ($art) {
      $self->status("DOWNLOADING URL: $url");
      my $res = $self->lwp->get($url);
      $art = $res->content;
      $self->coverart_cache->set( $url, $art );
   }

   if ( substr( $art, 0, 6 ) eq "GIF89a" ) {
      $self->status("Current cover is gif, downloading medium");
      $url = $p->{ImageUrlMedium};
      $art = $self->coverart_cache->get($url);
      unless ($art) {
         $self->status("DOWNLOADING URL: $url");
         my $res = $self->lwp->get($url);
         $art = $res->content;
         $self->coverart_cache->set( $url, $art );
      }
   }

   if ( substr( $art, 0, 6 ) eq "GIF89a" ) {
      $self->status("Image is STILL a gif, sorry Amazon must not have the cover");
      return;
   }

   #   my $image = Image::Magick->new(magick=>'jpg');
   #   $image->Resize(width=>300, height=>300);
   #   $image->BlobToImage($art);

   return {
      "Picture Type" => "Cover (front)",
      "MIME type"    => "image/jpg",
      Description    => "",

      #       _Data => $image->ImageToBlob(magick => 'jpg'),
      _Data => $art,
          }

}

sub _amazon_to_sql {
   my $self = shift; 
   my $in = shift;
   my %months = ( "january"   => 1,
                  "february"  => 2,
                  "march"     => 3,
                  "april"     => 4,
                  "may"       => 5,
                  "june"      => 6,
                  "july"      => 7,
                  "august"    => 8,
                  "september" => 9,
                  "october"   => 10,
                  "november"  => 11,
                  "december"  => 12
                );
   if ( $in =~ /(\d\d) ([^,]+), (\d+)/ ) {
      return sprintf( "%4d-%02d-%02d", $3, $months{ lc($2) }, $1 );
   }
   else {
      return undef;
   }
}

1;

=pod

=head1 BUGS

Does not do well with artist who have over 50 releases. Amazon sorts by most popular.



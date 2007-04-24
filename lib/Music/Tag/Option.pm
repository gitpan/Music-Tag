package Music::Tag::Option;
our $VERSION=0.19;
# Copyright (c) 2006 Edward Allen III. All rights reserved.
#
## This program is free software; you can redistribute it and/or
## modify it under the terms of the Artistic License, distributed
## with Perl.
#
use strict;
our @ISA = qw(Music::Tag::Generic);

sub set_tag {
   my $self = shift;
   my $okmethods = { map { lc($_) => 1 } @{$self->info->datamethods} };
   while (my ($k, $v) = each %{$self->options}) {
       if ((defined $v) and ($okmethods->{lc($k)})) {
           $self->info->{uc($k)} = $v;
           $self->tagchange(uc($k));
       }
   }
}

sub get_tag { set_tag(@_); }


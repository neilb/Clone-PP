package Clone::PP;

use strict;
use vars qw($VERSION @EXPORT_OK);
use Exporter;

$VERSION = 1.01;

@EXPORT_OK = qw( clone );
sub import { goto &Exporter::import } # lazy Exporter

# These methods can be temporarily overriden to work with a given class.
use vars qw( $CloneSelfMethod $CloneInitMethod );
$CloneSelfMethod ||= 'clone_self';
$CloneInitMethod ||= 'clone_init';

# Used to detect looped networks and avoid infinite recursion. 
use vars qw( %CloneCache );

# Generic cloning function
sub clone {
  my $source = shift;
  
  # Optional depth limiting -- after this many levels, do shallow copy.
  my $depth = shift;
  if ( defined $depth ) { 
    return $source if $depth < 1;
    $depth --;
  }
  
  # Maintain a shared cache during recursive calls, then clear it at the end.
  local %CloneCache = ( undef => undef ) unless ( exists $CloneCache{undef} );
  
  return $CloneCache{ $source } if ( exists $CloneCache{ $source } );
  
  # Non-reference values are copied shallowly
  my $ref_type = ref $source or return $source;
  
  # Extract both the structure type and the class name of referent
  my $class_name;
  if ( "$source" =~ /^\Q$ref_type\E\=([A-Z]+)\(0x[0-9a-f]+\)$/ ) {
    $class_name = $ref_type;
    $ref_type = $1;
    # Some objects would prefer to clone themselves; check for clone_self().
    return $CloneCache{ $source } = $source->$CloneSelfMethod() 
				  if $source->can($CloneSelfMethod);
  }
  
  # To make a copy:
  # - Prepare a reference to the same type of structure;
  # - Store it in the cache, to avoid looping it it refers to itself;
  # - Tie in to the same class as the original, if it was tied;
  # - Assign a value to the reference by cloning each item in the original;
  
  my $copy;
  if ($ref_type eq 'HASH') {
    $CloneCache{ $source } = $copy = {};;
    if ( my $tied = tied( %$source ) ) { tie %$copy, ref $tied }
    %$copy = map { ! ref($_) ? $_ : clone($_, $depth) } %$source;
  } elsif ($ref_type eq 'ARRAY') {
    $CloneCache{ $source } = $copy = [];
    if ( my $tied = tied( @$source ) ) { tie @$copy, ref $tied }
    @$copy = map { ! ref($_) ? $_ : clone($_, $depth) } @$source;
  } elsif ($ref_type eq 'REF' or $ref_type eq 'SCALAR') {
    $CloneCache{ $source } = $copy = \( my $var = "" );
    if ( my $tied = tied( $$source ) ) { tie $$copy, ref $tied }
    $$copy = clone($$source, $depth);
  } else {
    $CloneCache{ $source } = $copy = $source;
  }
  
  # - Bless it into the same class as the original, if it was blessed;
  # - If it has a post-cloning initialization method, call it.
  if ( $class_name ) {
    bless $copy, $class_name;
    $copy->$CloneInitMethod() if $copy->can($CloneInitMethod);
  }
  
  return $copy;
}

1;

__END__

=head1 NAME

Clone::PP - Recursively copy Perl datatypes

=head1 SYNOPSIS

  use Clone::PP qw(clone);
  
  $a = { 'foo' => 'bar', 'move' => 'zig' };
  $b = [ 'alpha', 'beta', 'gamma', 'vlissides' ];
  $c = new Foo();
  
  $d = clone($a);
  $e = clone($b);
  $f = clone($c);
  
  # or
  
  use Clone::PP;
  push @Foo::ISA, 'Clone';
  
  $a = new Foo;
  $b = $a->clone();

=head1 DESCRIPTION

This module provides a clone() method which makes recursive
copies of nested hash, array, scalar and reference types, 
including tied variables and objects.

The clone() function takes a scalar argument and an optional parameter that 
can be used to limit the depth of the copy. To duplicate lists,
arrays or hashes, pass them in by reference. e.g.
    
  my $copy = clone (\@array);
  # or
  my %copy = %{ clone (\%hash) };  

=head1 SEE ALSO

For a faster implementation in XS, see L<Clone>. 

For a slower, but more flexible solution use the dclone function from <Storable>.

=head1 CREDITS AND COPYRIGHT

Developed by Matthew Simon Cavalletto, simonm@cavalletto.org. 
Mode modules from Evolution Softworks are available at www.evoscript.org.
Copyright 2003 Matthew Simon Cavalletto. 

Interface based on Clone by Ray Finch, rdf@cpan.org. 
Portions Copyright 2001 Ray Finch.

Code based on initial design from Ref.pm. 
Portions Copyright 1994 David Muir Sharnoff.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

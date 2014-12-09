package MooX::Failover;

use Moo::Role;

use Carp;
use Class::Load qw/ try_load_class /;

{
    use version 0.77;
    $MooX::Failover::VERSION = version->declare('v0.1.0_02');
}

# RECOMMEND PREREQ: Class::Load::XS

=head1 NAME

MooX::Failover - Instantiate Moo classes with failover

=for readme plugin version

=head1 SYNOPSIS

  # In your class:

  package MyClass;

  use Moo;

  has 'attr' => ( ... );

  with 'MooX::Failover'; # use *after* attributes are declared

  # When using the class

  my $obj = MyClass->new( %args, failover_to => 'OtherClass' );

  # If %args contains missing or invalid values or new otherwise
  # fails, then $obj will be of type "OtherClass".

=begin :readme

=head1 INSTALLATION

See
L<How to install CPAN modules|http://www.cpan.org/modules/INSTALL.html>.

=for readme plugin requires heading-level=2 title="Required Modules"

=for readme plugin changes

=end :readme

=head1 DESCRIPTION

This role provides constructor failover for L<Moo> classes.

If a class cannot be instantiated because of invalid arguments
(perhaps from an untrusted source), then instead it returns the
failover class (passing the same arguments to that class).

This allows for cleaner design, by not forcing you to duplicate type
checking for class parameters.

Note that this is roughly equivalent to using

  my $obj = eval { MyClass->new(%args) //
     OtherClass->new( %args, error => $@ );

Note that your failover class should support the same methods as the
original class.  A use case for this role would be for instantiating
L<Web::Machine::Resource> objects, where the failover is a
Web::Machine::Resource object that returns an error page.

Ideally, your failover class would satisy the Liskov Substitution
Principle, so that (roughly) all provable properties of the original
class are also provable of the failover class.  In practice, we only
care about the properties (methods and attributes) that are actually
used in our programs.

=for readme stop

=head1 ARGUMENTS

=head2 C<failover_to>

This argument should contain a hash reference with the following keys:

=over

=item C<class>

The name of the class to fail over to.

This can be an array reference of multiple classes.

=item C<args>

A hash reference of arguments to pass to the failover class.  When
omitted, then the same arguments will be passed to it.

=item C<err_arg>

This is the name of the constructor argument to pass the error to (it
defaults to "error".  This is useful if the failover class can inspect
the error and act appropriately.

For example, if the original class is a handler for a website, where
the attributes correspond to URL parameters, then the failover class
can return HTTP 400 responses if the errors are for invalid
parameters.

To disable it, set it to C<undef>.

=back

Note that

  failover_to => 'OtherClass'

is equivalent to

  failover_to => { class => 'OtherClass' }

Note that this is not an attribute.Failover attributes from parent classes are not used. (This
restriction is to improve the performance.)

This is a L<Moo> port of L<MooseX::Failover>. The only differences are
that:

=over

item 1.

You need to consume the role I<after> the attributes have been
declared.

=item 2.

A default C<failover_to> attribute cannot be declared in the
class. You must specify it in an argument.

=item

This is signficantly slower than using an

  my $obj = eval { MyClass->new(%args) //
     OtherClass->new( %args, error => $@ );

for the L<Moo> version than the L<Moose> version of this module.  Some
rough benchmarks suggest several times slower.

=back

=cut

around new => sub {
    my ( $orig, $class, %args ) = @_;

    eval { $class->$orig(%args) } // do {

        my $failover = delete $args{failover_to};
        my %next = ( ref $failover ) ? %{$failover} : ( class => $failover );

        %args = %{ $next{args} } if $next{args};

        $next{err_arg} = 'error' unless exists $next{err_arg};
        $args{ $next{err_arg} } = $@ if defined $next{err_arg};

        $class = $next{class};
        if ( ref $class ) {
            $class = shift @{ $next{class} };
            $args{failover_to} = \%next;
        }

        croak $@ unless $class;

        try_load_class($class)
          or croak "unable to load class ${class}";

        $class->new(%args);
    };

};

=for readme continue

=head1 CAVEATS

This module is experimental. It works, but the current version is
significantly slower than using a simple eval or try block.  So it's
not recommended for production code.

=head1 SEE ALSO

L<MooseX::Failover>

=head1 AUTHOR

Robert Rothenberg C<<rrwo@thermeon.com>>

=head1 Acknowledgements

=over

=item Thermeon Europe.

=item Piers Cawley.

=item Graham Knop.

=back

=head1 COPYRIGHT

Copyright 2014 Thermeon Europe.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

use namespace::clean;

1;

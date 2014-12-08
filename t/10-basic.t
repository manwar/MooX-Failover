use Test::Most;

{

    package Sub1;

    use Moo;
    use MooX::Types::MooseLike::Base qw/ Int Str /;

    has num => (
        is  => 'ro',
        isa => Int,
    );

    has r_str => (
        is       => 'ro',
        isa      => Str,
        required => 1,
    );

    has d_str => (
        is       => 'ro',
        isa      => Str,
        required => 1,
        default  => 'wibble',
    );

    with 'MooX::Failover';

}

{

    package Sub2;

    use Moo;
    extends 'Sub1';

    use MooX::Types::MooseLike::Base qw/ Str /;

    has q_str => (
        is       => 'ro',
        isa      => Str,
        required => 1,
        init_arg => 'str',
    );

    with 'MooX::Failover';

}

{

    package Failover;

    use Moo;

    has error => ( is => 'ro', );

}

{
    note "no errors";

    my $obj = Sub1->new(
        num   => 123,
        r_str => 'test',
    );

    isa_ok $obj, 'Sub1';
}

{
    note "no errors";

    my $obj = Sub2->new(
        num   => 123,
        r_str => 'test',
        str   => 'foo',
    );

    isa_ok $obj, 'Sub1';
    isa_ok $obj, 'Sub2';
}

{
    note "errors with no failover";
    throws_ok {
        my $obj = Sub1->new( num => 123, );
        fail 'no object';
    }
    qr/Missing required arguments: r_str/, 'expected error';

}

{
    note "errors with failover";

    my $obj = Sub1->new(
        num         => 123,
        failover_to => 'Failover',
    );
    isa_ok $obj, 'Failover';
}

{
    note "errors with failover (err_arg)";

    my $obj = Sub1->new(
        num         => 123,
        failover_to => {
            class   => 'Failover',
            err_arg => 'error',
        },
    );

    isa_ok $obj, 'Failover';
}

{
    note "errors with failover (err_arg)";

    my $obj = Sub2->new(
        num         => 123,
        r_str       => 'test',
        failover_to => {
            class   => 'Failover',
            err_arg => 'error',
        },
    );

    isa_ok $obj, 'Failover';
}

{
    note "errors with failover (err_arg)";

    my $obj = Sub1->new(
        num         => '123x',
        r_str       => 'test',
        failover_to => {
            class   => 'Failover',
            err_arg => 'error',
        },
    );

    isa_ok $obj, 'Failover';
}

{
    note "errors with failover (err_arg ignored)";

    my $obj = Sub2->new(
        num         => 123,
        r_str       => 'test',
        failover_to => {
            class   => 'Sub1',
            err_arg => 'error',
        },
    );

    isa_ok $obj, 'Sub1';
    ok !$obj->can('error'), 'no error attribute';
}

{
    note "errors with failover (err_arg ignored)";

    my %args = ( num => 123 );

    my $obj = Sub2->new(
        %args,
        failover_to => {
            class => 'Sub1',
            args  => {
                %args,
                failover_to => {
                    class   => 'Failover',
                    err_arg => 'error',
                }
            },
        },

    );

    isa_ok $obj, 'Failover';
}

{
    note "errors with failover (err_arg ignored, list of classes)";

    my %args = ( num => 123 );

    my $obj = Sub2->new(
        %args,
        failover_to => {
            class   => [qw/ Sub1 Failover /],
            err_arg => 'error',
            args    => \%args,
        },
    );

    isa_ok $obj, 'Failover';
}

{
    note "bad failover";

    my %args = ( num => 123 );

    throws_ok {
        my $obj = Sub2->new(
            %args,
            failover_to => {
                class   => [qw/ Sub1 Sub1 /],
                err_arg => 'error',
                args    => \%args,
            },
        );
        fail 'no object';
    }
    qr/Missing required arguments: r_str/, 'bad failover';
}

done_testing;
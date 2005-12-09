package MARC::Charset::Code;

use strict;
use warnings;
use base qw(Class::Accessor);
use Carp qw(croak);
use Encode qw(encode_utf8);
use MARC::Charset::Constants;

MARC::Charset::Code
    ->mk_accessors(qw(marc ucs name charset is_combining));

=head1 NAME

MARC::Charset::Code - represents a MARC-8/UTF-8 mapping

=head1 SYNOPSIS

=head1 DESCRIPTION

Each mapping from a MARC-8 value to a UTF-8 value is represented by 
a MARC::Charset::Code object in a MARC::Charset::Table.

=head1 METHODS 

=head2 new()

The constructor.

=head2 name()

A descriptive name for the code point.

=head2 marc()

A string representing the MARC-8 bytes codes.

=head2 ucs()

A string representing the UCS code point in hex.

=head2 charset_code()

The MARC-8 character set code.

=head2 is_combining()

Returns true/false to tell if the character is a combining character.

=head2 to_string()

A stringified version of the object suitable for pretty printing.

=head2 char_value()

Returns the unicode character. Essentially just a helper around
ucs().

=cut

sub char_value() 
{
    return chr(hex(shift->ucs()));
}

=head2 marc_value()

The string representing the MARC-8 encoding.

=cut

sub marc_value
{
    my $code = shift;
    my $marc = $code->marc();
    return chr(hex($marc)) unless $code->charset_name eq 'CJK';
    return 
        chr(hex(substr($marc,0,2))) .
        chr(hex(substr($marc,2,2))) .
        chr(hex(substr($marc,4,2)));
}


=head2 charset_name()

Returns the name of the character set, instead of the code.

=cut

sub charset_name()
{
    return MARC::Charset::Constants::charset_name(chr(hex(shift->charset())));
}

=head2 to_string()

Returns a stringified version of the object.

=cut

sub to_string
{
    my $self = shift;
    my $str = 
        $self->name() . ': ' .
        'charset_code=' . $self->charset() . ' ' .
        'marc='         . $self->marc() . ' ' . 
        'ucs='          . $self->ucs() .  ' ';

    $str .= ' combining' if $self->is_combining();
    return $str;
}


=head2 hash_code()

Returns a hash code for this Code object. First portion is the 
character set code and the second is the MARC-8 value.

=cut

sub hash_code 
{
    my $self = shift;
    my $marc = $self->marc();

    # most MARC-8 character sets use 2 characters representing 
    # the hex value for a byte
    if (length($marc) == 2)
    {
        return sprintf(
            '%s:%s', 
            chr(hex($self->charset())),
            chr(hex($marc)));
    }

    # the East Asian character set uses three bytes
    # encoded as three, 2 character sequences run together
    if (length($marc) == 6)
    {
        return sprintf(
            '%s:%s%s%s',
            chr(hex($self->charset())),
            chr(hex(substr($marc,0,2))),
            chr(hex(substr($marc,2,2))),
            chr(hex(substr($marc,4,2))))
    }

    croak("invalid hex code size: $marc in ".$self->to_string());
}


1;
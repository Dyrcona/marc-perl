package MARC::Charset;

=head1 NAME

MARC::Charset - A module for doing MARC-8/UTF8 translation

=cut 

use 5.6.0;
use strict;
use base qw( Exporter );

our $VERSION = 0.1;

=head1 SYNOPSIS

 use MARC::Charset;

 ## create a MARC::Charset object
 my $charset = MARC::Charset->new();

 ## a string containing the Ansel value for a copyright symbol 
 my $ansel = chr(0xC3) . ' copyright 1969'.

 ## the same string, but now encoded in UTF8!
 my $utf8 = $charset->to_utf8($extLatin);

=head1 DESCRIPTION

MARC::Charset is a package that allows you to easily convert between
the MARC-8 character encodings and Unicode (UTF-8). If you are interested
the Library of Congress maintains some essential mapping tables and 
information about the MARC-8 and Unicode environments at

 http://www.loc.gov/marc/specifications/spechome.html

MARC::Charset is essentially a Perl implementation of the specifications 
found at LC, and supports the following character sets:

=over 4 

=item * Latin (Basic/Extended + Greek Symbols, Subscripts and Superscripts)

=item * Hebrew

=item * Cyrillic (Basic + Extended)

=item * Arabic (Basic + Extended)

=item * Greek

=back

Since the East Asian character set is 32 bit, there isn't support just yet
in MARC::Char for them. It's been built with an eye for the future, and so 
when more is understood about how 32 bit graphical character sets are
designated as working G0 and G1 sets, then more will be done.

=cut


## Packages for default character sets, and other small ones
## We will load larger character sets dynamically as needed to hopefully 
## save a bit on our memory footprint

use MARC::Charset::ASCII;
use MARC::Charset::Ansel;
use MARC::Charset::Controls;
use MARC::Charset::Subscripts;
use MARC::Charset::Superscripts;
use MARC::Charset::GreekSymbols;

my $controls = MARC::Charset::Controls->new();


## Constants for object attributes
## That's right, it's a blessed array so we can get any speed pickup 
## we can get when pulling stuff later

use constant G0			=> 0;
use constant G1			=> 1;
use constant DIAGNOSTICS	=> 2;


## Constants for escaping to different character sets
## we allow export of these constants for testing purposes

## Technique #1

use constant ESCAPE		=> chr(0x1B);
use constant GREEK_SYMBOLS	=> chr(0x67);
use constant SUBSCRIPTS		=> chr(0x62);
use constant SUPERSCRIPTS	=> chr(0x70);
use constant ASCII_DEFAULT	=> chr(0x73);

## Technique #2 

use constant SINGLE_G0_A	=> chr(0x28);
use constant SINGLE_G0_B	=> chr(0x2C);
use constant MULTI_G0_A		=> chr(0x24);
use constant MULTI_G0_B		=> chr(0x24) . chr(0x2C);

use constant SINGLE_G1_A	=> chr(0x29);
use constant SINGLE_G1_B	=> chr(0x2D);
use constant MULTI_G1_A		=> chr(0x24) . chr(0x29);
use constant MULTI_G1_B		=> chr(0x24) . chr(0x2D);

use constant BASIC_ARABIC	=> chr(0x33);
use constant EXTENDED_ARABIC	=> chr(0x34);
use constant BASIC_LATIN	=> chr(0x42);
use constant CJK		=> chr(0x31);
use constant BASIC_CYRILLIC	=> chr(0x4E);
use constant EXTENDED_CYRILLIC	=> chr(0x51);

our %EXPORT_TAGS = ( all => 
	[ qw( 
	ESCAPE  GREEK_SYMBOLS  SUBSCRIPTS  SUPERSCRIPTS  ASCII_DEFAULT 
	SINGLE_G0_A  SINGLE_G0_B  MULTI_G0_A  MULTI_G0_B  SINGLE_G1_A 
	SINGLE_G1_B  MULTI_G1_A  MULTI_G1_B  BASIC_ARABIC  
	EXTENDED_ARABIC  BASIC_LATIN  CJK  BASIC_CYRILLIC  
	EXTENDED_CYRILLIC
	) ]
    );

our @EXPORT_OK = qw(
	ESCAPE  GREEK_SYMBOLS  SUBSCRIPTS  SUPERSCRIPTS  ASCII_DEFAULT 
	SINGLE_G0_A  SINGLE_G0_B  MULTI_G0_A  MULTI_G0_B  SINGLE_G1_A 
	SINGLE_G1_B  MULTI_G1_A  MULTI_G1_B  BASIC_ARABIC  
	EXTENDED_ARABIC  BASIC_LATIN  CJK  BASIC_CYRILLIC  
	EXTENDED_CYRILLIC
    );


=head1 METHODS

=head2 new()

The constructor which will return  MARC::Charset object. If you like 
you can pass in the default G0 and G1 charsets (using the g0 and g1
parameters, but if you don't ASCII/Ansel will be assumed.

 ## for standard characters sets: ASCII and Ansel
 my $cs = MARC::Charset->new(); 

 ## or if you want to specify Arabic Basic + Extended as the G0/G1 character
 ## sets. 
 my $cs = MARC::Charset->new( 
    g0 => MARC::Charset::ArabicBasic->new(),
    g1 => MARC::Charset::ArabicExtended->new()
 );

If you would like diagnostics turned on pass in the DIAGNOSTICS 
parameter and set it to a value that will evaluate to true (eg. 1).

 my $cs = MARC::Charset->new( diagnostics => 1 );

=cut 

sub new {

    my ($class,%args) = @_;
    my $self = bless [ ], ref($class) || $class;

    ## lowercase all the parameters 
    %args = map { lc($_) => $args{$_} } keys(%args);

    $self->[ DIAGNOSTICS ] = $args{ diagnostics };

    ## set the default working graphical charset 0 (G0)
    if (ref($args{ g0 }) =~ /^MARC::Charset/ ) {
	$self->g0($args{ g0 });
    } else {
	$self->g0( MARC::Charset::ASCII->new() );
    }

    ## set the default working graphical charset 1 (G1)
    if (ref($args{ g1 }) =~ /^MARC::Charset/ ) {
	$self->g1($args{ g1 });
    } else {
	$self->g1( MARC::Charset::Ansel->new() );
    }

    return($self);

}


=head2 to_utf8()

Pass to_unicode() a string of MARC encoded characters and get back a string
of UTF8 characters. to_utf8() will handle escape sequences within the string 
that change the working character sets to Greek, Hebrew, Arabic (Basic + 
Extended), Cyrillic (Basic + Extended)...but not 32 bit East Asian (see TODO).

=cut

sub to_utf8 ($) {

    my ($self,$str) = @_;

    ## we delegate the work to an internal method which takes 
    ## a reference to a string (to avoid copying if the string is very long), 
    ## as well as the initial left and right index which will 
    ## change as _marc2unicode is called recursively
    return( $self->_marc2utf8(\$str,0,length($str)) );

}


=head2 g0() 

Returns an object representing the character set that is being used as 
the first graphic character set (G0). If you pass in a MARC::CHAR:* object you
will set the G0 character set, and as a side effect you'll get the previous
G0 value returned to you. You probably don't ever need to call this since 
character settting is handled internally, but it's here if you want it.


 ## figure out the currenty 
 my $charset = MARC::Charset->new();
 my $g0 = MARC::Charset->g0();

 my $newg0 = MARC::Charset::Greek;
 my $oldg0 = $charset->g0($newg0);

=cut

sub g0 {
    my ($self,$arg) = @_;
    return( $self->_g(0,$arg) );
}


=head2 g1()

Same as g0() above, but operates on the second graphic set that is available.

=cut


sub g1 {
    my ($self,$arg) = @_;
    return( $self->_g(1,$arg) );
}
	

=head1 TODO

=over 4

=item * Support for 32bit MARC-8 characters: 

This concerns the East Asian character sets: Han, Hiragana, Katakana, Hangul 
and Punctuation. I'm a bit confused about whether 7/8 bit character sets can 
interoperate with 32 bit character sets. For example if ASCII is designated as 
the working G0 character set, and East Asian as the working G1 character set. 
While I've tried to program towards supporting 32 bit character sets I need to 
know exactly how they are implemented in the 'real world'. So if you have 
any East Asian MARC data please email it to me!!

=back


=head1 VERSION HISTORY

=over 4

=item * 

v.01 - 2002.07.17 (ehs)

=back 

=cut


=head1 AUTHORS

=over 4

=item Ed Summers <ehs@pobox.com>

=back

=cut



## Internal Subroutines & Methods


## This is our workhorse for doing the translation, and is normally 
## only called by to_unicode() which optimizes some stuff by making sure 
## _marc2unicode() gets a reference to a string, a left index, a right index 

sub _marc2utf8 ($$$$) {

    my ($self,$strRef,$left,$right) = @_;
    return('') if $left >= $right;

    my $g0 = $self->[ G0 ];
    my $g1 = $self->[ G1 ];

    ## charsize is 1 now, but will need to change when 
    ## support for East Asian character sets is added
    my $charSize = 1;
    my $char = substr($$strRef,$left,$charSize);

    ## if we've found an escape character check if we've got
    ## a character escape sequence
    if ( $char eq  ESCAPE ) {
	$left = $self->_escape($strRef,$left,$right);
	$g0 = $self->[ G0 ];
	$g1 = $self->[ G1 ];
	## reset charSize here when we've got East Asian support
	$char = substr($$strRef,$left,$charSize);
    }

    ## handle sequences of valid combining characters by putting them
    ## AFTER the character that they modify. In MARC-8 combining characters
    ## modify the character that follows them, whereas in Unicode combining
    ## characters modify the character that they follow

    my $combining_chars = '';

    while ($g0->combining($char) || $g1->combining($char)) {
	$combining_chars .= $g0->lookup($char) || $g1->lookup($char);
	$left += $charSize;
	$char = substr($$strRef,$left,$charSize);
    } 

    ## look up the character in our working character sets
    ## since g0 can include 0 we have can't short circuit on a g0 lookup

    my $translated = $g0->lookup($char);
    if (! defined($translated) ) {
	$translated = $g1->lookup($char) || $controls->lookup($char);
    }

    ## if we didn't get anything then this character isn't valid!

    if ( !defined($translated) ) { 
	## to avoid warnings on concatenation
	$translated = ''; 
	## give em a warning if they want them
	if ( $self->[ DIAGNOSTICS ] ) {
	    my $hex = sprintf("0x%2x",ord($char));
	    warning(
		"chr($hex) is not a valid character in " . 
		'the control sets or the current working sets ' .  
		$g0->name() . '(G0), ' . $g1->name() . '(G1)'
	    );
	}
    }

    ## here's the magic: return the concatenation of our translated character 
    ## to any combining characters we found plus the rest of the string 
    ## converted to unicode

    return(
	$translated .
	$combining_chars .
	$self->_marc2utf8($strRef,$left+$charSize,$right)
    );

}

sub _escape($$$$) {

    my ($self,$strRef,$left,$right) = @_;

    ## if we don't have at least one character after the escape
    ## then this can't be a character escape sequence
    return($left) if ($left+1 >= $right); 

    my $escChar1 = substr($$strRef,$left+1,1);
    my $newCharset;

    ## the first method of escaping for limited character sets

    if ( $escChar1 eq GREEK_SYMBOLS ) {
	$newCharset = MARC::Charset::GreekSymbols->new();
    } elsif ( $escChar1 eq SUBSCRIPTS ) {
	$newCharset = MARC::Charset::Subscripts->new();
    } elsif ( $escChar1 eq SUPERSCRIPTS ) {
	$newCharset = MARC::Charset::Superscripts->new();
    } elsif ( $escChar1 eq ASCII_DEFAULT ) {
	$newCharset = MARC::Charset::ASCII->new();
    }

    if ($newCharset) {
	$self->g0($newCharset); 
	return($left+2);
    }

    ## otherwise try the second method of escaping for other sets 

    return($left+3);
}

sub _g {
    my ($self,$g,$arg) = @_;
    if (ref($arg) =~ /^MARC::Charset::/) {
	my $tmp = $self->[ $g ];
	$self->[ $g ] = $arg;
	return( $tmp );
    }
    return($self->[ $g ]);
}

sub warning {
    my $message = shift;
    print STDERR __PACKAGE__ . " : $message\n";
}

1;
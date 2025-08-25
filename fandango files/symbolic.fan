#!/usr/bin/env -S fandango fuzz -f

<start> ::= "cat(" <fields> ")"

<fields> ::= (<field> ",")* <field2>

<field> ::= <int_field> | <byte_field> | <string_field>
<field2> ::= <int_field2> | <byte_field2> | <string_field2>

<int_field> ::= "int(" <value_ref> "," <length_spec> ")"
<int_field2> ::= "int(" <value_ref> ("," <length_spec>)? ")"

<byte_field> ::= "byte(" <value_ref> "," <length_spec> ")"
<byte_field2> ::= "byte(" <value_ref> ("," <length_spec>)? ")"

<string_field> ::= "string(" <value_ref> "," <length_spec> ")"
<string_field2> ::= "string(" <value_ref> ("," <length_spec>)? ")"

<value_ref> ::= <var> | <const_bitstring>

<length_spec> ::= <quoted_digit> | <var>

<var> ::= <identifier>
<identifier> ::= <letter> (<letter> | <digit>)*

<const_bitstring> ::= "'" <bit_sequence> "'"
<bit_sequence> ::= <bit>+
<bit> ::= "0" | "1"

<quoted_digit> ::= "'" <digits> "'"
<digits> ::= <digit>+

<letter> ::= <ascii_lowercase_letter> | <ascii_uppercase_letter>
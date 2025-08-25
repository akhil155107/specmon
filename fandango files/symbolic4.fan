#!/usr/bin/env -S fandango fuzz -f

<start> ::= "cat(" <fields> ")"

<fields> ::= (<field> ",")* <field2>

<field> ::= <int_field> | <byte_field> | <string_field>
<field2> ::= <int_field2> | <byte_field2> | <string_field2>

<int_field> ::= "int(" <value_ref> "," <length_spec> ")"
where check_length(<value_ref>, <length_spec>)

<int_field2> ::= <int_field_with_length> | <int_field_without_length>
<int_field_with_length> ::= "int(" <value_ref> "," <length_spec> ")"
where check_length(<value_ref>, <length_spec>)
<int_field_without_length> ::= "int(" <value_ref> ")"

<byte_field> ::= "byte(" <value_ref> "," <length_spec> ")"
where check_length(<value_ref>, <length_spec>)

<byte_field2> ::= <byte_field_with_length> | <byte_field_without_length>
<byte_field_with_length> ::= "byte(" <value_ref> "," <length_spec> ")"
where check_length(<value_ref>, <length_spec>)
<byte_field_without_length> ::= "byte(" <value_ref> ")"

<string_field> ::= "string(" <value_ref> "," <length_spec> ")"
where check_length(<value_ref>, <length_spec>)

<string_field2> ::= <string_field_with_length> | <string_field_without_length>
<string_field_with_length> ::= "string(" <value_ref> "," <length_spec> ")"
where check_length(<value_ref>, <length_spec>)
<string_field_without_length> ::= "string(" <value_ref> ")"

<value_ref> ::= <var> | <const_bitstring>

<length_spec> ::= <quoted_digit> | <var>

<var> ::= <identifier>
<identifier> ::= <letter> (<letter> | <digit>)*

<const_bitstring> ::= "'" <bit_sequence> "'"
<bit_sequence> ::= <bit>+
<bit> ::= "0" | "1"

<quoted_digit> ::= "'" <digits> "'"
<digits> ::= <digit>+

<letter> ::= r'[a-zA-Z]'
<digit> ::= r'[0-9]'

# Python functions for constraints
def lookup(value_ref):
    """
    Resolves a value reference to its actual value
    Returns strings but represents byte data
    """
    # For grammar purposes, we'll use some default bindings
    # Values represent byte data as hex strings or actual strings
    bindings = {
        'x': '10B3',  # 2 bytes as hex string
        'y': '55AA',  # 2 bytes as hex string  
        'z': 'hello world!',  # 12 bytes as string
        'data': '01020304',  # 4 bytes as hex string
        'len2': '2',
        'len4': '4',
        'len8': '8',
        'len12': '12'
    }
    
    if isinstance(value_ref, str) and value_ref.startswith("'") and value_ref.endswith("'"):
        # It's a constant bitstring - convert to hex representation
        bit_str = value_ref[1:-1]  # Remove quotes
        # Convert bitstring to hex string (pad to nearest byte boundary)
        while len(bit_str) % 8 != 0:
            bit_str = '0' + bit_str
        
        hex_str = ''
        for i in range(0, len(bit_str), 8):
            byte_val = int(bit_str[i:i+8], 2)
            hex_str += '{:02X}'.format(byte_val)
        return hex_str
    else:
        # It's a variable - convert to string if needed
        var_name = str(value_ref)
        if var_name in bindings:
            return bindings[var_name]
        else:
            # Return a default hex value to keep grammar working
            return 'FF00'  # Default 2 bytes as hex

def to_int(length_spec):
    """
    Converts a length specification to an integer (number of bytes)
    """
    if isinstance(length_spec, str) and length_spec.startswith("'") and length_spec.endswith("'"):
        # It's a quoted digit
        return int(length_spec[1:-1])
    else:
        # It's a variable - use default bindings
        bindings = {
            'len2': 2,
            'len4': 4,
            'len8': 8,
            'len12': 12,
            'len16': 16
        }
        var_name = str(length_spec)
        if var_name in bindings:
            return bindings[var_name]
        else:
            # Try to convert directly
            try:
                return int(var_name)
            except:
                return 2  # Default length in bytes

def get_byte_length(value_str):
    """
    Calculate byte length from a string value
    """
    # If it looks like hex (even length, only hex chars), treat as hex
    if len(value_str) % 2 == 0 and all(c in '0123456789ABCDEFabcdef' for c in value_str):
        return len(value_str) // 2  # 2 hex chars per byte
    else:
        # Treat as regular string, encode to get byte length
        return len(value_str.encode('utf-8'))

def check_length(value_ref, length_spec):
    """
    Checks if the byte length of value_ref matches length_spec
    """
    try:
        value = lookup(value_ref)
        expected_byte_length = to_int(length_spec)
        actual_byte_length = get_byte_length(value)
        return actual_byte_length == expected_byte_length
    except:
        # If anything goes wrong, allow it for grammar generation
        return False
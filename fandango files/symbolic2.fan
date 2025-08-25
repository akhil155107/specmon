#!/usr/bin/env -S fandango fuzz -f

<start> ::= "cat(" <fields> ")"

<fields> ::= (<field> ",")* <field2>

<field> ::= <int_field> | <byte_field> | <string_field>
<field2> ::= <int_field2> | <byte_field2> | <string_field2>

<int_field> ::= "int(" <value_ref> "," <length_spec> ")"
where check_length(<value_ref>, <length_spec>, bindings)

<int_field2> ::= "int(" <value_ref> ("," <length_spec>)? ")"
where check_length(<value_ref>, <length_spec>, bindings) if <length_spec> is present

<byte_field> ::= "byte(" <value_ref> "," <length_spec> ")"
where check_length(<value_ref>, <length_spec>, bindings)

<byte_field2> ::= "byte(" <value_ref> ("," <length_spec>)? ")"
where check_length(<value_ref>, <length_spec>, bindings) if <length_spec> is present

<string_field> ::= "string(" <value_ref> "," <length_spec> ")"
where check_length(<value_ref>, <length_spec>, bindings)

<string_field2> ::= "string(" <value_ref> ("," <length_spec>)? ")"
where check_length(<value_ref>, <length_spec>, bindings) if <length_spec> is present

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
<digit> ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"

def lookup(value_ref, bindings):
    """
    Resolves a value reference to its actual bitstring
    - If value_ref is a variable, looks it up in bindings
    - If value_ref is a constant bitstring, returns it directly
    """
    if value_ref.startswith("'") and value_ref.endswith("'"):
        # It's a constant bitstring
        return value_ref[1:-1]  # Remove quotes
    else:
        # It's a variable
        if value_ref in bindings:
            return bindings[value_ref]
        else:
            raise ValueError(f"Variable {value_ref} not found in bindings")

def to_int(length_spec, bindings):
    """
    Converts a length specification to an integer
    - If length_spec is a quoted digit, converts to int
    - If length_spec is a variable, looks it up in bindings and converts to int
    """
    if length_spec.startswith("'") and length_spec.endswith("'"):
        # It's a quoted digit
        return int(length_spec[1:-1])
    else:
        # It's a variable
        if length_spec in bindings:
            value = bindings[length_spec]
            try:
                return int(value)
            except ValueError:
                # Try interpreting as binary and convert to int
                try:
                    return int(value, 2)
                except ValueError:
                    raise ValueError(f"Cannot convert value of {length_spec} to integer")
        else:
            raise ValueError(f"Variable {length_spec} not found in bindings")

def check_length(value_ref, length_spec, bindings):
    """
    Checks if the length of value_ref matches length_spec
    """
    value = lookup(value_ref, bindings)
    expected_length = to_int(length_spec, bindings)
    actual_length = len(value)
    return actual_length == expected_length

def sum_lengths(fields, bindings):
    """
    Calculate the sum of lengths of all fields
    """
    total = 0
    for field in fields:
        # Extract value_ref and length_spec from field
        # This is a simplified version; actual parsing would be more complex
        value_ref = extract_value_ref(field)
        value = lookup(value_ref, bindings)
        total += len(value)
    return total

def extract_value_ref(field):
    """
    Extract the value reference from a field definition
    
    Args:
        field: A string representing a field like "int(x, '8')" or "byte(y)"
        
    Returns:
        The value reference part (e.g., "x" from the examples above)
    """
    # Parse the field to extract the value reference
    # This is a simplified version using regex
    import re
    
    # Match the pattern: function_name(value_ref, optional_length)
    match = re.match(r'(\w+)\(([^,\)]+)(?:,\s*([^,\)]+))?\)', field)
    
    if match:
        # Group 1: function name (int, byte, string)
        # Group 2: value reference
        # Group 3: length specification (optional)
        function_name, value_ref, length_spec = match.groups()
        return value_ref.strip()
    else:
        raise ValueError(f"Could not extract value reference from field: {field}")
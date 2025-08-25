#!/usr/bin/env -S fandango fuzz -f

def hex_to_int(hex_str):
    # Convert to string if it's not already a string
    if not isinstance(hex_str, str):
        hex_str = str(hex_str)
    # Remove '0x' prefix if present
    if hex_str.startswith('0x'):
        hex_str = hex_str[2:]
    ans = int(hex_str,16)
    return ans

<start> ::= <fields>

<fields> ::= "0x"<l><t><m><h>

<l> ::= <hexbits>{16}
<t> ::= <hexbits>{2}
<m> ::= <hexbits>{2*(hex_to_int(<l>))}
<h> ::= <hexbits>*

<hexbits> ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" | "a" | "b" | "c" | "d" | "e" | "f"
#!/usr/bin/env python3
"""
Fandango Parser Script for SpecMon Integration
This script receives format specifications and byte data from SpecMon,
uses Fandango for parsing, and returns the results in JSON format.
"""

import json
import sys
import base64
import traceback
from typing import Dict, Any, List, Optional, Union
import logging

# Import Fandango - adjust this import based on your Fandango installation
try:
    import fandango  # Replace with actual Fandango import
    # import your_fandango_module as fandango
except ImportError as e:
    print(f"Error importing Fandango: {e}", file=sys.stderr)
    sys.exit(1)

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class FandangoParser:
    """Main parser class that integrates with Fandango"""
    
    def __init__(self):
        self.bindings = {}
        
    def parse_format(self, fields: List[Dict], byte_data: bytes) -> Dict[str, Any]:
        """
        Parse byte data using field specifications with Fandango
        
        Args:
            fields: List of field specifications from SpecMon
            byte_data: Raw byte data to parse
            
        Returns:
            Dictionary of variable bindings
        """
        try:
            # Convert SpecMon field specifications to Fandango format
            fandango_spec = self._convert_fields_to_fandango(fields)
            
            # Use Fandango to parse the data
            # This is where we'll integrate specific Fandango parsing logic
            parsed_data = self._parse_with_fandango(fandango_spec, byte_data)
            
            # Convert Fandango results back to SpecMon format
            bindings = self._convert_fandango_results(parsed_data, fields)
            
            return bindings
            
        except Exception as e:
            logger.error(f"Error in parse_format: {e}")
            raise
    
    def _convert_fields_to_fandango(self, fields: List[Dict]) -> Any:
        """
        Convert SpecMon field specifications to Fandango format
        
        This is where you'll need to adapt based on your specific Fandango usage
        """
        fandango_fields = []
        
        for field in fields:
            # Example conversion - adjust based on Fandango API
            fandango_field = {
                'type': field['name'],  # int, byte, string
                'args': []
            }
            
            for arg in field['args']:
                if arg['type'] == 'variable':
                    fandango_field['args'].append({
                        'type': 'variable',
                        'name': arg['name']
                    })
                elif arg['type'].startswith('constant_'):
                    const_type = arg['type'].replace('constant_', '')
                    value = arg['value']
                    
                    # Handle base64 encoded bytes
                    if const_type == 'bytes' and isinstance(value, str):
                        value = self._decode_base64_bytes(value)
                    
                    fandango_field['args'].append({
                        'type': 'constant',
                        'value_type': const_type,
                        'value': value
                    })
            
            # Add length information if present
            if 'length' in field and field['length'] > 0:
                fandango_field['length'] = field['length']
                
            fandango_fields.append(fandango_field)
        
        return fandango_fields
    
    def _parse_with_fandango(self, fandango_spec: Any, byte_data: bytes) -> Any:
        """
        Use Fandango to parse the byte data
        
        Replace this with your actual Fandango parsing logic
        """
        # PLACEHOLDER: Replace with actual Fandango API calls
        # This is where we'll use Fandango's parsing capabilities
        
        # Example structure - adapt to Fandango API:
        try:
            # Option 1: If Fandango has a direct parsing method
            # result = fandango.parse(fandango_spec, byte_data)
            
            # Option 2: If we need to build a Fandango parser
            # parser = fandango.Parser(fandango_spec)
            # result = parser.parse(byte_data)
            
            # Option 3: If Fandango uses a different approach
            # context = fandango.Context()
            # parser = context.create_parser(fandango_spec)
            # result = parser.parse_bytes(byte_data)
            
            # For now, return a mock result - TODO
            logger.warning("Using mock Fandango parsing - replace with actual implementation")
            result = self._mock_fandango_parse(fandango_spec, byte_data)
            
            return result
            
        except Exception as e:
            logger.error(f"Fandango parsing failed: {e}")
            raise
    
    def _mock_fandango_parse(self, spec: Any, data: bytes) -> Dict[str, Any]:
        """
        Mock Fandango parsing for testing - REMOVE THIS in production
        """
        results = {}
        offset = 0
        
        for field in spec:
            field_type = field['type']
            args = field['args']
            
            # Determine field length
            length = field.get('length', 4)  # Default length
            
            if offset + length > len(data):
                break
                
            field_data = data[offset:offset + length]
            
            # Process each argument
            for arg in args:
                if arg['type'] == 'variable':
                    var_name = arg['name']
                    
                    # Convert based on field type
                    if field_type == 'int':
                        value = int.from_bytes(field_data, byteorder='little')
                    elif field_type == 'string':
                        value = field_data.decode('utf-8', errors='ignore')
                    else:  # bytes
                        value = f"base64:{base64.b64encode(field_data).decode()}"
                    
                    results[var_name] = value
            
            offset += length
        
        return results
    
    def _convert_fandango_results(self, fandango_results: Any, original_fields: List[Dict]) -> Dict[str, Any]:
        """
        Convert Fandango parsing results back to SpecMon format
        """
        # If using mock results, return as-is
        if isinstance(fandango_results, dict):
            return fandango_results
        
        # Otherwise, convert Fandango results to SpecMon bindings
        bindings = {}
        
        # This conversion depends on Fandango output format
        # Adapt based on how Fandango returns parsed data
        
        try:
            # Example conversion - adjust based on actual Fandango output
            for var_name, value in fandango_results.items():
                bindings[var_name] = self._convert_value_to_specmon(value)
                
        except Exception as e:
            logger.error(f"Error converting Fandango results: {e}")
            raise
            
        return bindings
    
    def _convert_value_to_specmon(self, value: Any) -> Any:
        """Convert a single value from Fandango format to SpecMon format"""
        # Handle different value types
        if isinstance(value, int):
            return value
        elif isinstance(value, str):
            return value
        elif isinstance(value, bytes):
            return f"base64:{base64.b64encode(value).decode()}"
        else:
            # For complex types, might need more sophisticated conversion
            return str(value)
    
    def _decode_base64_bytes(self, encoded: str) -> bytes:
        """Decode base64 encoded byte strings"""
        if encoded.startswith("base64:"):
            encoded = encoded[7:]  # Remove "base64:" prefix
            return base64.b64decode(encoded)
        else:
            # Handle hex encoding from Go side
            return bytes.fromhex(encoded)

def main():
    """Main entry point for the script"""
    try:
        # Parse command line arguments
        if len(sys.argv) < 3:
            logger.error("Usage: python fandango_parser.py <input_file> <output_file>")
            sys.exit(1)
        
        input_file = sys.argv[1]
        output_file = sys.argv[2]
        
        # Read input JSON
        with open(input_file, 'r') as f:
            request = json.load(f)
        
        # Decode byte data
        byte_data_b64 = request['byte_data']
        if byte_data_b64.startswith("base64:"):
            # Handle the encoding from Go side - adjust as needed
            hex_data = byte_data_b64[7:]  # Remove "base64:" prefix
            byte_data = bytes.fromhex(hex_data)
        else:
            byte_data = base64.b64decode(byte_data_b64)
        
        # Create parser and parse
        parser = FandangoParser()
        bindings = parser.parse_format(request['fields'], byte_data)
        
        # Create response
        response = {
            'success': True,
            'bindings': bindings
        }
        
        # Write output JSON
        with open(output_file, 'w') as f:
            json.dump(response, f, indent=2)
        
        logger.info(f"Successfully parsed data, found {len(bindings)} bindings")
        
    except Exception as e:
        logger.error(f"Script failed: {e}")
        logger.error(traceback.format_exc())
        
        # Write error response
        error_response = {
            'success': False,
            'error': str(e)
        }
        
        try:
            with open(sys.argv[2], 'w') as f:
                json.dump(error_response, f, indent=2)
        except:
            pass  # If we can't write the error file, just exit
        
        sys.exit(1)

def main_stdin():
    """Alternative main function that uses stdin/stdout instead of files"""
    try:
        # Read from stdin
        request = json.load(sys.stdin)
        
        # Decode byte data
        byte_data_b64 = request['byte_data']
        if byte_data_b64.startswith("base64:"):
            hex_data = byte_data_b64[7:]
            byte_data = bytes.fromhex(hex_data)
        else:
            byte_data = base64.b64decode(byte_data_b64)
        
        # Create parser and parse
        parser = FandangoParser()
        bindings = parser.parse_format(request['fields'], byte_data)
        
        # Create and output response
        response = {
            'success': True,
            'bindings': bindings
        }
        
        json.dump(response, sys.stdout, indent=2)
        
    except Exception as e:
        error_response = {
            'success': False,
            'error': str(e)
        }
        json.dump(error_response, sys.stdout, indent=2)
        sys.exit(1)

if __name__ == "__main__":
    main()  # Use main() for file-based I/O or main_stdin() for stdin/stdout
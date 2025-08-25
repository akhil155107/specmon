// fandango_bridge.go
// Bridge implementation for integrating Fandango with SpecMon

package term

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// FandangoConfig holds configuration for the Fandango integration
type FandangoConfig struct {
	PythonPath     string `json:"python_path"`      // Path to Python executable
	ScriptPath     string `json:"script_path"`      // Path to your Fandango script
	TimeoutSeconds int    `json:"timeout_seconds"`  // Timeout for script execution
	TempDir        string `json:"temp_dir"`         // Directory for temporary files
}

// FandangoRequest represents the data sent to the Python script
type FandangoRequest struct {
	Fields    []FieldSpec `json:"fields"`     // Format specification
	ByteData  string      `json:"byte_data"`  // Base64 encoded byte data
	Timestamp int64       `json:"timestamp"`  // For debugging/logging
}

// FieldSpec represents a field specification in JSON format
type FieldSpec struct {
	Name   string      `json:"name"`             // Field type (int, byte, string)
	Args   []ArgSpec   `json:"args"`             // Field arguments
	Length int         `json:"length,omitempty"` // Field length if specified
}

// ArgSpec represents an argument in the field specification
type ArgSpec struct {
	Type  string      `json:"type"`            // "variable", "constant_int", "constant_string", "constant_bytes"
	Name  string      `json:"name,omitempty"`  // Variable name if type is "variable"
	Value interface{} `json:"value,omitempty"` // Constant value if type is "constant_*"
}

// FandangoResponse represents the response from the Python script
type FandangoResponse struct {
	Success  bool                   `json:"success"`
	Error    string                 `json:"error,omitempty"`
	Bindings map[string]interface{} `json:"bindings,omitempty"` // Variable name -> value mappings
}

// Default configuration
var defaultFandangoConfig = FandangoConfig{
	PythonPath:     "python3",
	ScriptPath:     "./scripts/fandango_parser.py",
	TimeoutSeconds: 30,
	TempDir:        "/tmp/specmon",
}

// Global config instance
var fandangoConfig = defaultFandangoConfig

// SetFandangoConfig allows customizing the Fandango configuration
func SetFandangoConfig(config FandangoConfig) {
	fandangoConfig = config
}

// ParseFormatWithFandango replaces the original ParseFormat function
// This is your main integration point
func ParseFormatWithFandango(fields []*Function, s []byte) (*Binding, error) {
	// Convert Go structures to JSON format for Python
	request, err := createFandangoRequest(fields, s)
	if err != nil {
		return nil, fmt.Errorf("failed to create Fandango request: %w", err)
	}

	// Execute the Python script
	response, err := executeFandangoScript(request)
	if err != nil {
		return nil, fmt.Errorf("failed to execute Fandango script: %w", err)
	}

	// Convert response back to Go Binding
	binding, err := createBindingFromResponse(response)
	if err != nil {
		return nil, fmt.Errorf("failed to create binding from response: %w", err)
	}

	return binding, nil
}

// createFandangoRequest converts Go structures to JSON format
func createFandangoRequest(fields []*Function, s []byte) (*FandangoRequest, error) {
	fieldSpecs := make([]FieldSpec, len(fields))
	
	for i, field := range fields {
		spec, err := convertFunctionToFieldSpec(field)
		if err != nil {
			return nil, fmt.Errorf("failed to convert field %d: %w", i, err)
		}
		fieldSpecs[i] = spec
	}

	// Encode byte data as base64 for JSON transport
	byteDataBase64 := encodeBase64(s)

	request := &FandangoRequest{
		Fields:    fieldSpecs,
		ByteData:  byteDataBase64,
		Timestamp: time.Now().Unix(),
	}

	return request, nil
}

// convertFunctionToFieldSpec converts a Go Function to JSON FieldSpec
func convertFunctionToFieldSpec(f *Function) (FieldSpec, error) {
	spec := FieldSpec{
		Name: f.Name,
		Args: make([]ArgSpec, len(f.Args)),
	}

	for i, arg := range f.Args {
		argSpec, err := convertTermToArgSpec(arg)
		if err != nil {
			return spec, fmt.Errorf("failed to convert argument %d: %w", i, err)
		}
		spec.Args[i] = argSpec
	}

	return spec, nil
}

// convertTermToArgSpec converts a Go Term to JSON ArgSpec
func convertTermToArgSpec(term Term) (ArgSpec, error) {
	switch t := term.(type) {
	case *Variable:
		return ArgSpec{
			Type: "variable",
			Name: t.Name,
		}, nil
	case *Constant[int]:
		return ArgSpec{
			Type:  "constant_int",
			Value: t.Value,
		}, nil
	case *Constant[string]:
		return ArgSpec{
			Type:  "constant_string",
			Value: t.Value,
		}, nil
	case *Constant[[]byte]:
		return ArgSpec{
			Type:  "constant_bytes",
			Value: encodeBase64(t.Value),
		}, nil
	default:
		return ArgSpec{}, fmt.Errorf("unsupported term type: %T", t)
	}
}

// executeFandangoScript runs the Python script and returns the response
func executeFandangoScript(request *FandangoRequest) (*FandangoResponse, error) {
	// Ensure temp directory exists
	if err := os.MkdirAll(fandangoConfig.TempDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create temp directory: %w", err)
	}

	// Create temporary files for input and output
	inputFile := filepath.Join(fandangoConfig.TempDir, fmt.Sprintf("input_%d.json", time.Now().UnixNano()))
	outputFile := filepath.Join(fandangoConfig.TempDir, fmt.Sprintf("output_%d.json", time.Now().UnixNano()))

	// Clean up temporary files
	defer func() {
		os.Remove(inputFile)
		os.Remove(outputFile)
	}()

	// Write request to input file
	if err := writeJSONToFile(request, inputFile); err != nil {
		return nil, fmt.Errorf("failed to write input file: %w", err)
	}

	// Execute Python script
	cmd := exec.Command(fandangoConfig.PythonPath, fandangoConfig.ScriptPath, inputFile, outputFile)
	
	// Set timeout
	if fandangoConfig.TimeoutSeconds > 0 {
		cmd.WaitDelay = time.Duration(fandangoConfig.TimeoutSeconds) * time.Second
	}

	// Capture stderr for debugging
	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("Python script failed: %w, stderr: %s", err, stderr.String())
	}

	// Read response from output file
	response, err := readJSONFromFile[FandangoResponse](outputFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read output file: %w", err)
	}

	// Check if Python script reported an error
	if !response.Success {
		return nil, fmt.Errorf("Fandango script error: %s", response.Error)
	}

	return response, nil
}

// createBindingFromResponse converts the JSON response back to Go Binding
func createBindingFromResponse(response *FandangoResponse) (*Binding, error) {
	binding := NewBinding()

	for varName, value := range response.Bindings {
		variable := NewVariable(varName)
		
		// Convert the value back to appropriate Go type
		term, err := convertValueToTerm(value)
		if err != nil {
			return nil, fmt.Errorf("failed to convert value for variable %s: %w", varName, err)
		}

		binding.Set(variable, term)
	}

	return binding, nil
}

// convertValueToTerm converts a JSON value back to a Go Term
func convertValueToTerm(value interface{}) (Term, error) {
	switch v := value.(type) {
	case float64:
		// JSON numbers are float64 by default
		return NewConstant[int](int(v)), nil
	case string:
		// Check if it's base64 encoded bytes
		if strings.HasPrefix(v, "base64:") {
			decoded, err := decodeBase64(strings.TrimPrefix(v, "base64:"))
			if err != nil {
				return nil, fmt.Errorf("failed to decode base64: %w", err)
			}
			return NewConstant[[]byte](decoded), nil
		}
		return NewConstant[string](v), nil
	default:
		return nil, fmt.Errorf("unsupported value type: %T", v)
	}
}

// Utility functions for file I/O and encoding

func writeJSONToFile(data interface{}, filename string) error {
	file, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	return encoder.Encode(data)
}

func readJSONFromFile[T any](filename string) (*T, error) {
	file, err := os.Open(filename)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var result T
	decoder := json.NewDecoder(file)
	err = decoder.Decode(&result)
	return &result, err
}

func encodeBase64(data []byte) string {
	// Using a simple base64 encoding - you might want to import encoding/base64
	// For now, this is a placeholder
	return fmt.Sprintf("base64:%x", data)
}

func decodeBase64(encoded string) ([]byte, error) {
	// Placeholder for base64 decoding
	// This should properly decode base64 strings
	var result []byte
	_, err := fmt.Sscanf(encoded, "%x", &result)
	return result, err
}

// Alternative implementation using stdin/stdout instead of files
func executeFandangoScriptStdin(request *FandangoRequest) (*FandangoResponse, error) {
	cmd := exec.Command(fandangoConfig.PythonPath, fandangoConfig.ScriptPath)
	
	// Set up pipes
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, fmt.Errorf("failed to create stdin pipe: %w", err)
	}
	
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, fmt.Errorf("failed to create stdout pipe: %w", err)
	}

	// Start the command
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("failed to start command: %w", err)
	}

	// Send request as JSON to stdin
	encoder := json.NewEncoder(stdin)
	if err := encoder.Encode(request); err != nil {
		stdin.Close()
		return nil, fmt.Errorf("failed to encode request: %w", err)
	}
	stdin.Close()

	// Read response from stdout
	var response FandangoResponse
	decoder := json.NewDecoder(stdout)
	if err := decoder.Decode(&response); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	// Wait for command to finish
	if err := cmd.Wait(); err != nil {
		return nil, fmt.Errorf("command failed: %w", err)
	}

	if !response.Success {
		return nil, fmt.Errorf("Fandango script error: %s", response.Error)
	}

	return &response, nil
}
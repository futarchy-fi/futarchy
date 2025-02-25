# Configuration Parser Testing

This directory contains tests for the Futarchy Proposal & Liquidity configuration parser.

## Testing Approach

The testing approach follows these key principles:

1. **Test with known values**: We create test configuration files with known values and verify that the parsing functions correctly extract these values.

2. **Test validation functions**: We test both valid and invalid configurations to ensure the validation functions correctly identify issues.

3. **Verify error messages**: We check that error messages are clear, helpful, and specific to the validation failure.

4. **Test with missing environment variables**: We ensure proper error handling when environment variables are missing or invalid.

5. **Test batch processing**: We verify that batch processing of multiple proposals works correctly.

6. **Test error handling**: We verify that the system handles malformed JSON and non-existent files gracefully.

## Test Cases

The test suite includes the following test cases:

### Proposal Configuration Tests

1. **Valid Configuration**: Verify loading a valid proposal configuration
2. **Batch Configuration**: Verify loading multiple proposal configurations
3. **Invalid Configuration**: Verify loading an invalid configuration file fails
4. **Missing Fields**: Verify loading a configuration with missing fields fails
5. **Malformed JSON**: Verify handling of malformed JSON
6. **Non-existent File**: Verify handling of non-existent file

### Validation Tests

7. **Valid Proposal**: Verify validation of a valid proposal configuration
8. **Empty Name**: Verify validation fails with empty name
9. **Empty Question**: Verify validation fails with empty question
10. **Same Tokens**: Verify validation fails with same tokens
11. **Zero Bond**: Verify validation fails with zero bond
12. **Zero Liquidity**: Verify validation fails with zero liquidity amount

### Environment Configuration Tests

13. **Valid Environment**: Verify loading environment configuration
14. **Missing Variables**: Verify validation of environment config with missing variables
15. **Invalid Addresses**: Verify validation of environment config with invalid addresses
16. **Missing RPC URL**: Verify validation of environment config with missing RPC URL
17. **Missing Private Key**: Verify validation of environment config with missing private key

## Running the Tests

To run the tests, use the provided script:

```bash
./script/test_config_parser.sh
```

This script will run all the tests and provide a summary of the results.

## Test Fixtures

The test fixtures are created dynamically in the `setUp()` function of the test contract:

- `test/fixtures/test_proposal.json`: Valid proposal configuration
- `test/fixtures/test_batch_proposals.json`: Multiple proposal configurations
- `test/fixtures/invalid_proposal.json`: Invalid proposal configuration (same tokens)
- `test/fixtures/missing_fields_proposal.json`: Proposal with missing required fields
- `test/fixtures/malformed_json.json`: Malformed JSON file (syntax error)
- Non-existent file: Test with a file path that doesn't exist 
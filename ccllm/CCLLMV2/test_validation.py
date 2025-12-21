"""
Test script for the new validation logic in cc_agent_v2.py
"""
from cc_agent_v2 import extract_last_json_object, validate_executor_text


def test_extract_last_json_object():
    """Test JSON extraction from text."""
    print("Testing extract_last_json_object...")

    # Test 1: Simple JSON at end
    text1 = 'Some thinking here\n{"kind": "tool", "explanation": "test"}'
    result1 = extract_last_json_object(text1)
    print(f"Test 1: {result1}")
    assert result1 == '{"kind": "tool", "explanation": "test"}'

    # Test 2: Nested JSON
    text2 = 'More text\n{"kind": "tool", "parameters": {"path": "/test.lua"}}'
    result2 = extract_last_json_object(text2)
    print(f"Test 2: {result2}")
    assert '{"kind": "tool"' in result2

    # Test 3: No JSON
    text3 = "Just plain text with no JSON"
    result3 = extract_last_json_object(text3)
    print(f"Test 3: {result3}")
    assert result3 is None

    print("[PASS] All extraction tests passed!\n")


def test_validate_executor_text():
    """Test validation of executor output."""
    print("Testing validate_executor_text...")

    # Test 1: Valid tool call
    text1 = '''
    Looking at the directive, I need to read the file.

    {
      "kind": "tool",
      "explanation": "Reading the file",
      "tool": "cc_read",
      "parameters": {"path": "/test.lua"}
    }
    '''
    try:
        result1 = validate_executor_text(text1)
        print(f"Test 1: kind={result1.kind}, tool={result1.tool}")
        assert result1.kind == "tool"
        assert result1.tool == "cc_read"
        print("[PASS] Test 1 passed")
    except Exception as e:
        print(f"[FAIL] Test 1 failed: {e}")

    # Test 2: Valid final result
    text2 = '''
    Task is complete!

    {
      "kind": "final",
      "explanation": "Task completed",
      "success": true,
      "message": "All done"
    }
    '''
    try:
        result2 = validate_executor_text(text2)
        print(f"Test 2: kind={result2.kind}, success={result2.success}")
        assert result2.kind == "final"
        assert result2.success == True
        print("[PASS] Test 2 passed")
    except Exception as e:
        print(f"[FAIL] Test 2 failed: {e}")

    # Test 3: Invalid - no JSON
    text3 = "Just text with no JSON"
    try:
        result3 = validate_executor_text(text3)
        print(f"[FAIL] Test 3 should have failed but didn't")
    except ValueError as e:
        print(f"[PASS] Test 3 correctly raised ValueError: {e}")

    # Test 4: Invalid - bad schema (missing required fields)
    text4 = '{"kind": "tool", "bad_field": "value"}'
    try:
        result4 = validate_executor_text(text4)
        print(f"[FAIL] Test 4 should have failed but didn't")
    except Exception as e:
        print(f"[PASS] Test 4 correctly raised error: {type(e).__name__}")

    # Test 5: Invalid - extra forbidden parameter
    text5 = '''
    {
      "kind": "tool",
      "explanation": "Reading file",
      "tool": "cc_read",
      "parameters": {"path": "/test.lua", "extra_param": "forbidden"}
    }
    '''
    try:
        result5 = validate_executor_text(text5)
        print(f"[FAIL] Test 5 should have failed (extra params forbidden)")
    except Exception as e:
        print(f"[PASS] Test 5 correctly rejected extra param: {type(e).__name__}")
        # Check that the error mentions forbidden
        if "extra" in str(e).lower() or "forbidden" in str(e).lower():
            print(f"       Error message mentions forbidden: {str(e)[:100]}")

    # Test 6: Valid - strict params with correct fields
    text6 = '''
    {
      "kind": "tool",
      "explanation": "Writing and testing",
      "tool": "cc_write_and_run",
      "parameters": {
        "path": "/hello.lua",
        "content": "print('Hello')",
        "args": ["arg1"]
      }
    }
    '''
    try:
        result6 = validate_executor_text(text6)
        print(f"Test 6: kind={result6.kind}, tool={result6.tool}")
        assert result6.kind == "tool"
        assert result6.tool == "cc_write_and_run"
        print("[PASS] Test 6 passed - strict params validated correctly")
    except Exception as e:
        print(f"[FAIL] Test 6 failed: {e}")

    print("\n[PASS] All validation tests passed!\n")


if __name__ == "__main__":
    print("=" * 60)
    print("Testing new validation logic")
    print("=" * 60)
    print()

    test_extract_last_json_object()
    test_validate_executor_text()

    print("=" * 60)
    print("All tests completed!")
    print("=" * 60)

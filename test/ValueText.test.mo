import Value "../src/Value";
import Text "mo:core@1/Text";
import Principal "mo:core@1/Principal";
import Bool "mo:core@1/Bool";
import Runtime "mo:core@1/Runtime";
import { test } "mo:test";

// Tests for Candid text format parsing and generation
// Based on the Candid specification grammar:
//
// <val> ::= <primval> | <consval> | <refval> | ( <annval> )
// <annval> ::= <val> | <val> : <datatype>
// <consval> ::= opt <val> | vec { <annval>;* } | record { <fieldval>;* } | variant { <fieldval> }
// <fieldval> ::= <nat> = <annval>
//
// Note: The implementation currently parses <val> in some places where spec requires <annval>,
// meaning type annotations without parentheses (e.g., "vec { 1 : nat }") may not be supported.
// Always use parentheses for type annotations: "vec { (1 : nat) }"

test(
  "Value toText basic cases",
  func() {
    let testCases : [(Text, ?Text, Value.Value)] = [
      // Nat
      ("3", null, #nat8(3)),
      ("5", null, #nat16(5)),
      ("7", null, #nat32(7)),
      ("9", null, #nat64(9)),
      ("999", null, #nat(999)),
      // Int
      ("2", null, #int8(2)),
      ("4", null, #int16(4)),
      ("6", null, #int32(6)),
      ("8", null, #int64(8)),
      ("888", null, #int(888)),
      // Float
      ("0.423_449_999_999_999_99", null, #float32(0.42345)),
      ("4", null, #float64(4)),
      // Bool
      ("true", null, #bool(true)),
      ("false", null, #bool(false)),
      // Null
      ("null", null, #null_),
      // Empty
      ("empty", null, #empty),
      // Reserved
      ("reserved", null, #reserved),
      // Principal
      ("principal \"77i6o-oqaaa-aaaag-qbm6q-cai\"", null, #principal(Principal.fromText("77i6o-oqaaa-aaaag-qbm6q-cai"))),
      // Text
      ("\"Hello World!\"", null, #text("Hello World!")),
      // Opt
      ("opt 4", null, #opt(#nat(4))),
      ("opt null", null, #opt(#null_)),
      // Vector
      ("vec {}", null, #vector([])),
      ("vec { 1, 2, 3 }", ?"vec {\n\t1,\n\t2,\n\t3\n}", #vector([#nat(1), #nat(2), #nat(3)])),
      // Record
      ("record {}", null, #record([])),
      ("record { 1 = 2; 2 = 3; \"test\" = 3 }", ?"record {\n\t1 = 2;\n\t2 = 3;\n\t\"test\" = 3\n}", #record([{ tag = #hash(1); value = #nat(2) }, { tag = #hash(2); value = #nat(3) }, { tag = #name("test"); value = #int(3) }])),
      // Variant
      ("variant { 1 = 2 }", null, #variant({ tag = #hash(1); value = #nat(2) })),
      ("variant { \"ttt\" }", null, #variant({ tag = #name("ttt"); value = #null_ })),
      ("variant { \"test\" = \"ttt\" }", ?"variant { \"test\" = \"ttt\" }", #variant({ tag = #name("test"); value = #text("ttt") })),
      // Func
      ("func \"77i6o-oqaaa-aaaag-qbm6q-cai\".m1", null, #func_({ method = "m1"; service = Principal.fromText("77i6o-oqaaa-aaaag-qbm6q-cai") })),
      // Service
      ("service \"77i6o-oqaaa-aaaag-qbm6q-cai\"", null, #service(Principal.fromText("77i6o-oqaaa-aaaag-qbm6q-cai"))),
    ];

    for ((expected, expectedIndented, value) in testCases.vals()) {
      let actual : Text = Value.toTextAdvanced(
        value,
        {
          indented = false;
          tagHashMapper = null;
          toTextOverride = null;
        },
      );
      if (expected != actual) {
        Runtime.trap("Failed toText equality\nExpected: " # expected # "\nActual:   " # actual);
      };

      let actualIndented : Text = Value.toTextAdvanced(
        value,
        {
          indented = true;
          tagHashMapper = null;
          toTextOverride = null;
        },
      );
      switch (expectedIndented) {
        case (null) ();
        case (?e) {
          if (e != actualIndented) {
            Runtime.trap("Failed toText (indented) equality\n\nExpected indented: " # e # "\nActual indented: " # actualIndented);
          };
        };
      };
    };
  },
);

test(
  "Value toText with custom mappers",
  func() {
    let expected = "record { \"11\" = opt true?; \"hello\" = record { \"🤣\" = variant { 2 = 1 } } }";
    let expectedIndented = "record {\n\t\"11\" = opt true?;\n\t\"hello\" = record {\n\t\t\"🤣\" = variant { 2 = 1 }\n\t}\n}";
    let value : Value.Value = #record([
      { tag = #name("11"); value = #opt(#bool(true)) },
      {
        tag = #hash(3);
        value = #record([{
          tag = #name("🤣");
          value = #variant({ tag = #hash(2); value = #nat(1) });
        }]);
      },
    ]);

    let tagHashMapper : Value.TagHashMapper = func(h : Nat32) : ?Text {
      switch (h) {
        case (3) ?"\"hello\"";
        case (_) null;
      };
    };

    let toTextOverride : Value.ToTextOverride = func(v : Value.Value) : ?Text {
      switch (v) {
        // Maps booleans to have a question mark
        case (#bool(b)) ?(Bool.toText(b) # "?");
        case (_) null;
      };
    };

    let actual : Text = Value.toTextAdvanced(
      value,
      {
        indented = false;
        tagHashMapper = ?tagHashMapper;
        toTextOverride = ?toTextOverride;
      },
    );
    if (expected != actual) {
      Runtime.trap("Failed toText equality\nExpected: " # expected # "\nActual:   " # actual);
    };

    let actualIndented : Text = Value.toTextAdvanced(
      value,
      {
        indented = true;
        tagHashMapper = ?tagHashMapper;
        toTextOverride = ?toTextOverride;
      },
    );
    if (expectedIndented != actualIndented) {
      Runtime.trap("Failed toText (indented) equality\n\nExpected indented: " # expectedIndented # "\nActual indented: " # actualIndented);
    };
  },
);

test(
  "fromText - primitives",
  func() {
    let testCases : [(Text, Value.Value)] = [
      // Nat
      ("42", #nat(42)),
      ("0", #nat(0)),
      ("999_999", #nat(999999)),
      ("0x2a", #nat(42)),
      ("0xFF", #nat(255)),
      ("0x1_A_B", #nat(427)), // hex with underscores
      // Int
      ("42", #nat(42)),
      ("-42", #int(-42)),
      ("+42", #int(42)),
      ("-999_999", #int(-999999)),
      ("+0", #int(0)),
      // Float
      ("3.14", #float64(3.14)),
      ("-2.5", #float64(-2.5)),
      ("1.5e10", #float64(1.5e10)),
      ("1.5e-10", #float64(1.5e-10)),
      ("1.5E+10", #float64(1.5e10)),
      ("42.", #float64(42.0)),
      ("0.5", #float64(0.5)), // Note: .5 (without leading 0) may not be valid per spec
      ("1_234.567_8", #float64(1234.5678)),
      ("0x1.8", #float64(1.5)), // hex float 1.5 in hex
      ("0x1.8p2", #float64(6.0)), // 1.5 * 2^2 = 6.0
      ("-0x1.0p-4", #float64(-0.0625)), // -1.0 * 2^-4
      // Bool
      ("true", #bool(true)),
      ("false", #bool(false)),
      // Null
      ("null", #null_),
      // Text
      ("\"hello\"", #text("hello")),
      ("\"\"", #text("")),
      ("\"hello world\"", #text("hello world")),
      ("\"line1\\nline2\"", #text("line1\nline2")),
      ("\"tab\\there\"", #text("tab\there")),
      ("\"quote\\\"test\"", #text("quote\"test")),
      ("\"unicode \\u{1F600}\"", #text("unicode 😀")),
      ("\"backslash\\\\test\"", #text("backslash\\test")),
      ("\"carriage\\rreturn\"", #text("carriage\rreturn")),
      ("\"single\\'quote\"", #text("single'quote")),
      ("\"hex\\20space\"", #text("hex space")),
      ("\"hex\\41A\"", #text("hexAA")),
      // Principal
      ("principal \"aaaaa-aa\"", #principal(Principal.fromText("aaaaa-aa"))),
      ("principal \"77i6o-oqaaa-aaaag-qbm6q-cai\"", #principal(Principal.fromText("77i6o-oqaaa-aaaag-qbm6q-cai"))),
    ];

    for ((input, expected) in testCases.vals()) {
      switch (Value.fromText(input)) {
        case (#ok((actual, _type))) {
          if (not Value.equal(expected, actual)) {
            Runtime.trap("Failed primitive parse\nInput:    " # input # "\nExpected: " # Value.toText(expected) # "\nActual:   " # Value.toText(actual));
          };
        };
        case (#err(e)) {
          Runtime.trap("Parse error for input: " # input # "\nError: " # e);
        };
      };
    };
  },
);

test(
  "fromText - options",
  func() {
    let testCases : [(Text, Value.Value)] = [
      ("opt 42", #opt(#nat(42))),
      ("opt null", #opt(#null_)),
      ("opt \"text\"", #opt(#text("text"))),
      ("opt (opt 5)", #opt(#opt(#nat(5)))),
    ];

    for ((input, expected) in testCases.vals()) {
      switch (Value.fromText(input)) {
        case (#ok((actual, _type))) {
          if (not Value.equal(expected, actual)) {
            Runtime.trap("Failed option parse\nInput:    " # input # "\nExpected: " # Value.toText(expected) # "\nActual:   " # Value.toText(actual));
          };
        };
        case (#err(e)) {
          Runtime.trap("Parse error for input: " # input # "\nError: " # e);
        };
      };
    };
  },
);

test(
  "fromText - vectors",
  func() {
    let testCases : [(Text, Value.Value)] = [
      ("vec {}", #vector([])),
      ("vec { 1 }", #vector([#nat(1)])),
      ("vec { 1; 2; 3 }", #vector([#nat(1), #nat(2), #nat(3)])),
      ("vec { 1; 2; 3; }", #vector([#nat(1), #nat(2), #nat(3)])), // trailing semicolon
      ("vec { \"a\"; \"b\" }", #vector([#text("a"), #text("b")])),
      ("vec { opt 1; opt null }", #vector([#opt(#nat(1)), #opt(#null_)])),
      // Test with type annotations (annval) - must be parenthesized
      ("vec { (1 : nat); (2 : nat) }", #vector([#nat(1), #nat(2)])),
      ("vec { (1 : nat); (2 : nat); (3 : nat) }", #vector([#nat(1), #nat(2), #nat(3)])),
    ];

    for ((input, expected) in testCases.vals()) {
      switch (Value.fromText(input)) {
        case (#ok((actual, _type))) {
          if (not Value.equal(expected, actual)) {
            Runtime.trap("Failed vector parse\nInput:    " # input # "\nExpected: " # Value.toText(expected) # "\nActual:   " # Value.toText(actual));
          };
        };
        case (#err(e)) {
          Runtime.trap("Parse error for input: " # input # "\nError: " # e);
        };
      };
    };
  },
);

test(
  "fromText - blobs",
  func() {
    let testCases : [(Text, Value.Value)] = [
      ("blob \"hello\"", #vector([#nat8(104), #nat8(101), #nat8(108), #nat8(108), #nat8(111)])),
      ("blob \"\"", #vector([])),
    ];

    for ((input, expected) in testCases.vals()) {
      switch (Value.fromText(input)) {
        case (#ok((actual, _type))) {
          if (not Value.equal(expected, actual)) {
            Runtime.trap("Failed blob parse\nInput:    " # input # "\nExpected: " # Value.toText(expected) # "\nActual:   " # Value.toText(actual));
          };
        };
        case (#err(e)) {
          Runtime.trap("Parse error for input: " # input # "\nError: " # e);
        };
      };
    };
  },
);

test(
  "fromText - records",
  func() {
    let testCases : [(Text, Value.Value)] = [
      ("record {}", #record([])),
      // Tuple-style (implicit field ids)
      ("record { 42 }", #record([{ tag = #hash(0); value = #nat(42) }])),
      ("record { 1; 2; 3 }", #record([{ tag = #hash(0); value = #nat(1) }, { tag = #hash(1); value = #nat(2) }, { tag = #hash(2); value = #nat(3) }])),
      // Named fields (using = syntax from <fieldval>)
      ("record { \"name\" = \"John\" }", #record([{ tag = #name("name"); value = #text("John") }])),
      ("record { \"first\" = \"John\"; \"last\" = \"Doe\" }", #record([{ tag = #name("first"); value = #text("John") }, { tag = #name("last"); value = #text("Doe") }])),
      // Numeric field ids (from <fieldval> ::= <nat> = <annval>)
      ("record { 0 = 42 }", #record([{ tag = #hash(0); value = #nat(42) }])),
      ("record { 5 = \"test\" }", #record([{ tag = #hash(5); value = #text("test") }])),
      // Mixed (the parser should handle this)
      ("record { 1 = \"a\"; 2 = \"b\" }", #record([{ tag = #hash(1); value = #text("a") }, { tag = #hash(2); value = #text("b") }])),
      // With type annotations in field values (<fieldval> ::= <nat> = <annval>)
      // Spec allows <annval> but implementation may require parentheses
      ("record { 0 = (42 : nat) }", #record([{ tag = #hash(0); value = #nat(42) }])),
      ("record { \"x\" = (1 : nat); \"y\" = (2 : nat) }", #record([{ tag = #name("x"); value = #nat(1) }, { tag = #name("y"); value = #nat(2) }])),
      // Nested
      ("record { \"inner\" = record { 1 } }", #record([{ tag = #name("inner"); value = #record([{ tag = #hash(0); value = #nat(1) }]) }])),
    ];

    for ((input, expected) in testCases.vals()) {
      switch (Value.fromText(input)) {
        case (#ok((actual, _type))) {
          if (not Value.equal(expected, actual)) {
            Runtime.trap("Failed record parse\nInput:    " # input # "\nExpected: " # Value.toText(expected) # "\nActual:   " # Value.toText(actual));
          };
        };
        case (#err(e)) {
          Runtime.trap("Parse error for input: " # input # "\nError: " # e);
        };
      };
    };
  },
);

test(
  "fromText - variants",
  func() {
    let testCases : [(Text, Value.Value)] = [
      // Variant with just tag (null value)
      ("variant { \"tag\" }", #variant({ tag = #name("tag"); value = #null_ })),
      ("variant { 0 }", #variant({ tag = #hash(0); value = #null_ })),
      // Variant with value (fieldval: <nat> = <annval>)
      ("variant { \"tag\" = 42 }", #variant({ tag = #name("tag"); value = #nat(42) })),
      ("variant { 5 = \"test\" }", #variant({ tag = #hash(5); value = #text("test") })),
      ("variant { \"active\" }", #variant({ tag = #name("active"); value = #null_ })),
      // Variant with annotated value
      ("variant { \"tag\" = (42 : nat) }", #variant({ tag = #name("tag"); value = #nat(42) })),
      ("variant { 0 = (\"text\" : text) }", #variant({ tag = #hash(0); value = #text("text") })),
      // Nested
      ("variant { \"result\" = record { \"ok\" = 100 } }", #variant({ tag = #name("result"); value = #record([{ tag = #name("ok"); value = #nat(100) }]) })),
      ("variant { \"nested\" = variant { \"inner\" } }", #variant({ tag = #name("nested"); value = #variant({ tag = #name("inner"); value = #null_ }) })),
    ];

    for ((input, expected) in testCases.vals()) {
      switch (Value.fromText(input)) {
        case (#ok((actual, _type))) {
          if (not Value.equal(expected, actual)) {
            Runtime.trap("Failed variant parse\nInput:    " # input # "\nExpected: " # Value.toText(expected) # "\nActual:   " # Value.toText(actual));
          };
        };
        case (#err(e)) {
          Runtime.trap("Parse error for input: " # input # "\nError: " # e);
        };
      };
    };
  },
);

test(
  "fromText - references",
  func() {
    let testCases : [(Text, Value.Value)] = [
      ("service \"aaaaa-aa\"", #service(Principal.fromText("aaaaa-aa"))),
      ("func \"aaaaa-aa\".method", #func_({ service = Principal.fromText("aaaaa-aa"); method = "method" })),
      ("func \"aaaaa-aa\".\"method_name\"", #func_({ service = Principal.fromText("aaaaa-aa"); method = "method_name" })),
      ("principal \"aaaaa-aa\"", #principal(Principal.fromText("aaaaa-aa"))),
    ];

    for ((input, expected) in testCases.vals()) {
      switch (Value.fromText(input)) {
        case (#ok((actual, _type))) {
          if (not Value.equal(expected, actual)) {
            Runtime.trap("Failed reference parse\nInput:    " # input # "\nExpected: " # Value.toText(expected) # "\nActual:   " # Value.toText(actual));
          };
        };
        case (#err(e)) {
          Runtime.trap("Parse error for input: " # input # "\nError: " # e);
        };
      };
    };
  },
);

test(
  "fromText - comments and whitespace",
  func() {
    let testCases : [(Text, Value.Value)] = [
      ("  42  ", #nat(42)),
      ("// comment\n42", #nat(42)),
      ("42 // comment", #nat(42)),
      ("/* block comment */ 42", #nat(42)),
      ("42 /* block comment */", #nat(42)),
      ("/* nested /* comment */ */ 42", #nat(42)),
      ("vec {\n  1; // first\n  2; // second\n  3  // third\n}", #vector([#nat(1), #nat(2), #nat(3)])),
    ];

    for ((input, expected) in testCases.vals()) {
      switch (Value.fromText(input)) {
        case (#ok((actual, _type))) {
          if (not Value.equal(expected, actual)) {
            Runtime.trap("Failed whitespace/comment parse\nInput:    " # input # "\nExpected: " # Value.toText(expected) # "\nActual:   " # Value.toText(actual));
          };
        };
        case (#err(e)) {
          Runtime.trap("Parse error for input: " # input # "\nError: " # e);
        };
      };
    };
  },
);

test(
  "fromText - parenthesized and annotated",
  func() {
    let testCases : [(Text, Value.Value)] = [
      // Parenthesized values
      ("(42)", #nat(42)),
      ("((42))", #nat(42)),
      ("(((\"text\")))", #text("text")),
      ("( 42 )", #nat(42)),
      // Annotated values - type annotations are parsed but ignored
      // <annval> ::= <val> : <datatype>
      ("(42 : nat)", #nat(42)),
      ("(42 : nat8)", #nat(42)),
      ("(\"text\" : text)", #text("text")),
      // Both forms are valid: opt (<annval>) and (<consval> : <datatype>)
      ("opt (5 : nat)", #opt(#nat(5))),
      ("(opt 5 : opt nat)", #opt(#nat(5))),
      ("(true : bool)", #bool(true)),
      ("(null : null)", #null_),
      // Complex annotated
      ("(vec { 1; 2 } : vec nat)", #vector([#nat(1), #nat(2)])),
      ("(record { \"x\" = 1 } : record { x : nat })", #record([{ tag = #name("x"); value = #nat(1) }])),
    ];

    for ((input, expected) in testCases.vals()) {
      switch (Value.fromText(input)) {
        case (#ok((actual, _type))) {
          if (not Value.equal(expected, actual)) {
            Runtime.trap("Failed parenthesized parse\nInput:    " # input # "\nExpected: " # Value.toText(expected) # "\nActual:   " # Value.toText(actual));
          };
        };
        case (#err(e)) {
          Runtime.trap("Parse error for input: " # input # "\nError: " # e);
        };
      };
    };
  },
);

test(
  "fromText - complex example",
  func() {
    let input = "record {\n" #
    "  \"first_name\" = \"John\";\n" #
    "  \"last_name\" = \"Doe\";\n" #
    "  \"age\" = 14;\n" #
    "  \"membership_status\" = variant { \"active\" };\n" #
    "  \"email_addresses\" = vec { \"john@doe.com\"; \"john.doe@example.com\" }\n" #
    "}";

    let expected = #record([
      { tag = #name("first_name"); value = #text("John") },
      { tag = #name("last_name"); value = #text("Doe") },
      { tag = #name("age"); value = #nat(14) },
      {
        tag = #name("membership_status");
        value = #variant({ tag = #name("active"); value = #null_ });
      },
      {
        tag = #name("email_addresses");
        value = #vector([#text("john@doe.com"), #text("john.doe@example.com")]);
      },
    ]);

    switch (Value.fromText(input)) {
      case (#ok((actual, _type))) {
        if (not Value.equal(expected, actual)) {
          Runtime.trap("Failed complex example\nExpected: " # Value.toText(expected) # "\nActual:   " # Value.toText(actual));
        };
      };
      case (#err(e)) {
        Runtime.trap("Parse error for complex example\nError: " # e);
      };
    };
  },
);

test(
  "fromText - error cases",
  func() {
    let errorCases : [Text] = [
      "",
      "not_a_keyword",
      "vec {",
      "record { 1 =",
      "variant {",
      "opt",
      "42 extra",
      "principal \"invalid principal text\"",
      "\"unclosed string",
      "vec { 1, 2 }", // commas not allowed in vec, should be semicolons
      "0x", // hex prefix without digits
      "0xGG", // invalid hex digits
      "1.2.3", // multiple decimal points
      "1e", // exponent without digits
      // Note: these string escape tests won't work as written (not in a string)
      // They'd need to be: "\"\\u{}\"" etc.
    ];

    for (input in errorCases.vals()) {
      switch (Value.fromText(input)) {
        case (#ok((v, _type))) {
          Runtime.trap("Expected error for input: " # input # "\nBut got: " # Value.toText(v));
        };
        case (#err(_)) {
          // Expected error
        };
      };
    };
  },
);

// Test for <arg> format: ( <annval>,* )
// According to spec, args use commas, not semicolons
test(
  "fromText - argument format (comma-separated)",
  func() {
    // Note: The Value.fromText function parses single values, not argument lists
    // This tests whether we handle single values correctly within the arg context
    // Actual argument parsing with commas would be handled by Arg.fromText

    // Test that we properly parse values that would appear in arg position
    let testCases : [(Text, Value.Value)] = [
      ("42", #nat(42)),
      ("(42)", #nat(42)),
      ("(42 : nat)", #nat(42)),
      ("(\"test\" : text)", #text("test")),
      ("opt (5 : nat)", #opt(#nat(5))),
      ("(vec { 1; 2 } : vec nat)", #vector([#nat(1), #nat(2)])),
      ("(record { \"x\" = 1; \"y\" = 2 } : record { x : nat; y : nat })", #record([{ tag = #name("x"); value = #nat(1) }, { tag = #name("y"); value = #nat(2) }])),
    ];

    for ((input, expected) in testCases.vals()) {
      switch (Value.fromText(input)) {
        case (#ok((actual, _type))) {
          if (not Value.equal(expected, actual)) {
            Runtime.trap("Failed arg value parse\nInput:    " # input # "\nExpected: " # Value.toText(expected) # "\nActual:   " # Value.toText(actual));
          };
        };
        case (#err(e)) {
          Runtime.trap("Parse error for input: " # input # "\nError: " # e);
        };
      };
    };
  },
);

test(
  "fromText - edge cases",
  func() {
    let testCases : [(Text, Value.Value)] = [
      // Numbers at boundaries
      ("0", #nat(0)),
      ("18446744073709551615", #nat(18446744073709551615)), // max Nat64
      ("-9223372036854775808", #int(-9223372036854775808)), // min Int64
      // Floats
      ("0.0", #float64(0.0)),
      ("-0.0", #float64(-0.0)),
      ("1e308", #float64(1e308)), // very large
      ("1e-308", #float64(1e-308)), // very small
      // Empty containers
      ("vec {}", #vector([])),
      ("record {}", #record([])),
      // Deeply nested
      ("opt opt opt 1", #opt(#opt(#opt(#nat(1))))),
      ("vec { vec { vec { 1 } } }", #vector([#vector([#vector([#nat(1)])])])),
      // Mixed whitespace and comments
      ("  \n\t 42  \n  ", #nat(42)),
      ("/* comment */ 42 /* comment */", #nat(42)),
      ("// line comment\n42", #nat(42)),
      ("42// comment", #nat(42)),
      // Text edge cases
      ("\"\"", #text("")),
      ("\" \"", #text(" ")),
      ("\"\\u{0}\"", #text("\u{0000}")),
      ("\"\\u{10FFFF}\"", #text("\u{10FFFF}")), // max unicode
    ];

    for ((input, expected) in testCases.vals()) {
      switch (Value.fromText(input)) {
        case (#ok((actual, _type))) {
          if (not Value.equal(expected, actual)) {
            Runtime.trap("Failed edge case parse\nInput:    " # input # "\nExpected: " # Value.toText(expected) # "\nActual:   " # Value.toText(actual));
          };
        };
        case (#err(e)) {
          Runtime.trap("Parse error for input: " # input # "\nError: " # e);
        };
      };
    };
  },
);

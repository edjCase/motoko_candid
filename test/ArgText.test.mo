import Arg "../src/Arg";
import Value "../src/Value";
import Text "mo:core@1/Text";
import Principal "mo:core@1/Principal";
import Runtime "mo:core@1/Runtime";
import { test } "mo:test";

// Tests for Candid argument text format parsing
// Based on the Candid specification grammar:
//
// <arg> ::= ( <annval>,* )
// <annval> ::= <val> | <val> : <datatype>
//
// This tests the parsing of comma-separated lists of values,
// potentially with type annotations, wrapped in parentheses.

test(
    "fromText - empty arguments",
    func() {
        switch (Arg.fromText("()")) {
            case (#ok(args)) {
                if (args.size() != 0) {
                    Runtime.trap("Expected empty array but got " # debug_show (args.size()) # " arguments");
                };
            };
            case (#err(e)) {
                Runtime.trap("Parse error for empty args: " # e);
            };
        };
    },
);

test(
    "fromText - single argument",
    func() {
        let testCases : [(Text, Value.Value)] = [
            ("(42)", #nat(42)),
            ("(\"hello\")", #text("hello")),
            ("(true)", #bool(true)),
            ("(null)", #null_),
            ("(-123)", #int(-123)),
            ("(3.14)", #float64(3.14)),
            ("(principal \"aaaaa-aa\")", #principal(Principal.fromText("aaaaa-aa"))),
            ("( record { owner = null } )", #record([{ tag = #name("owner"); value = #null_ }])),
        ];

        for ((input, expectedValue) in testCases.vals()) {
            switch (Arg.fromText(input)) {
                case (#ok(args)) {
                    if (args.size() != 1) {
                        Runtime.trap("Expected 1 argument but got " # debug_show (args.size()) # " for input: " # input);
                    };
                    if (not Value.equal(args[0].value, expectedValue)) {
                        Runtime.trap("Failed single arg parse\nInput:    " # input # "\nExpected: " # Value.toText(expectedValue) # "\nActual:   " # Value.toText(args[0].value));
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
    "fromText - multiple arguments",
    func() {
        let testCases : [(Text, [Value.Value])] = [
            ("(1, 2, 3)", [#nat(1), #nat(2), #nat(3)]),
            ("(42, \"hello\", true)", [#nat(42), #text("hello"), #bool(true)]),
            ("(\"a\", \"b\", \"c\")", [#text("a"), #text("b"), #text("c")]),
            ("(-1, 0, +1)", [#int(-1), #nat(0), #int(1)]),
            ("(1.5, 2.5, 3.5)", [#float64(1.5), #float64(2.5), #float64(3.5)]),
            ("(true, false, true)", [#bool(true), #bool(false), #bool(true)]),
        ];
        for ((input, expectedValues) in testCases.vals()) {
            switch (Arg.fromText(input)) {
                case (#ok(args)) {
                    if (args.size() != expectedValues.size()) {
                        Runtime.trap("Expected " # debug_show (expectedValues.size()) # " arguments but got " # debug_show (args.size()) # " for input: " # input);
                    };
                    for (i in expectedValues.keys()) {
                        if (not Value.equal(args[i].value, expectedValues[i])) {
                            Runtime.trap("Failed multiple args parse at index " # debug_show (i) # "\nInput:    " # input # "\nExpected: " # Value.toText(expectedValues[i]) # "\nActual:   " # Value.toText(args[i].value));
                        };
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
    "fromText - with type annotations",
    func() {
        let testCases : [(Text, [Value.Value])] = [
            ("((42 : nat))", [#nat(42)]),
            ("((42 : nat), (\"hello\" : text))", [#nat(42), #text("hello")]),
            ("((1 : nat), (2 : nat), (3 : nat))", [#nat(1), #nat(2), #nat(3)]),
            ("((true : bool), (false : bool))", [#bool(true), #bool(false)]),
            // Mixed annotated and non-annotated
            ("(42, (\"hello\" : text), true)", [#nat(42), #text("hello"), #bool(true)]),
        ];

        for ((input, expectedValues) in testCases.vals()) {
            switch (Arg.fromText(input)) {
                case (#ok(args)) {
                    if (args.size() != expectedValues.size()) {
                        Runtime.trap("Expected " # debug_show (expectedValues.size()) # " arguments but got " # debug_show (args.size()) # " for input: " # input);
                    };
                    for (i in expectedValues.keys()) {
                        if (not Value.equal(args[i].value, expectedValues[i])) {
                            Runtime.trap("Failed annotated args parse at index " # debug_show (i) # "\nInput:    " # input # "\nExpected: " # Value.toText(expectedValues[i]) # "\nActual:   " # Value.toText(args[i].value));
                        };
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
    "fromText - trailing commas",
    func() {
        let testCases : [(Text, [Value.Value])] = [
            ("(42,)", [#nat(42)]),
            ("(1, 2, 3,)", [#nat(1), #nat(2), #nat(3)]),
            ("(\"hello\", true,)", [#text("hello"), #bool(true)]),
            ("(42, \"hello\", true,)", [#nat(42), #text("hello"), #bool(true)]),
            // With whitespace after comma
            ("(42, )", [#nat(42)]),
            ("(1, 2, 3, )", [#nat(1), #nat(2), #nat(3)]),
        ];

        for ((input, expectedValues) in testCases.vals()) {
            switch (Arg.fromText(input)) {
                case (#ok(args)) {
                    if (args.size() != expectedValues.size()) {
                        Runtime.trap("Expected " # debug_show (expectedValues.size()) # " arguments but got " # debug_show (args.size()) # " for input: " # input);
                    };
                    for (i in expectedValues.keys()) {
                        if (not Value.equal(args[i].value, expectedValues[i])) {
                            Runtime.trap("Failed annotated args parse at index " # debug_show (i) # "\nInput:    " # input # "\nExpected: " # Value.toText(expectedValues[i]) # "\nActual:   " # Value.toText(args[i].value));
                        };
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
    "fromText - complex nested structures",
    func() {
        let testCases : [(Text, [Value.Value])] = [
            // Opt values
            ("(opt 42, opt null)", [#opt(#nat(42)), #opt(#null_)]),
            // Vectors
            ("(vec { 1; 2; 3 })", [#vector([#nat(1), #nat(2), #nat(3)])]),
            ("(vec { 1; 2 }, vec { 3; 4 })", [#vector([#nat(1), #nat(2)]), #vector([#nat(3), #nat(4)])]),
            // Records
            ("(record { \"name\" = \"Alice\" })", [#record([{ tag = #name("name"); value = #text("Alice") }])]),
            (
                "(record { 1; 2; 3 }, record { \"x\" = 10 })",
                [
                    #record([{ tag = #hash(0); value = #nat(1) }, { tag = #hash(1); value = #nat(2) }, { tag = #hash(2); value = #nat(3) }]),
                    #record([{ tag = #name("x"); value = #nat(10) }]),
                ],
            ),
            // Variants
            ("(variant { \"ok\" = 100 })", [#variant({ tag = #name("ok"); value = #nat(100) })]),
            (
                "(variant { \"success\" }, variant { \"error\" = \"failed\" })",
                [
                    #variant({ tag = #name("success"); value = #null_ }),
                    #variant({ tag = #name("error"); value = #text("failed") }),
                ],
            ),
            // Mixed complex types
            (
                "(42, vec { 1; 2 }, record { \"test\" = true })",
                [
                    #nat(42),
                    #vector([#nat(1), #nat(2)]),
                    #record([{ tag = #name("test"); value = #bool(true) }]),
                ],
            ),
            // Nested structures
            (
                "(record { \"data\" = vec { 1; 2; 3 } })",
                [
                    #record([{
                        tag = #name("data");
                        value = #vector([#nat(1), #nat(2), #nat(3)]);
                    }]),
                ],
            ),
            (
                "(vec { record { \"x\" = 1 }; record { \"x\" = 2 } })",
                [
                    #vector([
                        #record([{ tag = #name("x"); value = #nat(1) }]),
                        #record([{ tag = #name("x"); value = #nat(2) }]),
                    ]),
                ],
            ),
        ];

        for ((input, expectedValues) in testCases.vals()) {
            switch (Arg.fromText(input)) {
                case (#ok(args)) {
                    if (args.size() != expectedValues.size()) {
                        Runtime.trap("Expected " # debug_show (expectedValues.size()) # " arguments but got " # debug_show (args.size()) # " for input: " # input);
                    };
                    for (i in expectedValues.keys()) {
                        if (not Value.equal(args[i].value, expectedValues[i])) {
                            Runtime.trap("Failed complex args parse at index " # debug_show (i) # "\nInput:    " # input # "\nExpected: " # Value.toText(expectedValues[i]) # "\nActual:   " # Value.toText(args[i].value));
                        };
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
    "fromText - with whitespace and comments",
    func() {
        let testCases : [(Text, [Value.Value])] = [
            // Extra whitespace
            ("(  42  ,  \"hello\"  )", [#nat(42), #text("hello")]),
            ("(\n\t42,\n\t\"hello\"\n)", [#nat(42), #text("hello")]),
            // Line comments
            ("(42, // comment\n\"hello\")", [#nat(42), #text("hello")]),
            ("(// first arg\n42, // second arg\n\"hello\")", [#nat(42), #text("hello")]),
            // Block comments
            ("(42, /* comment */ \"hello\")", [#nat(42), #text("hello")]),
            ("(/* start */42, \"hello\"/* end */)", [#nat(42), #text("hello")]),
            // Nested block comments
            ("(42, /* outer /* inner */ outer */ \"hello\")", [#nat(42), #text("hello")]),
        ];

        for ((input, expectedValues) in testCases.vals()) {
            switch (Arg.fromText(input)) {
                case (#ok(args)) {
                    if (args.size() != expectedValues.size()) {
                        Runtime.trap("Expected " # debug_show (expectedValues.size()) # " arguments but got " # debug_show (args.size()) # " for input: " # input);
                    };
                    for (i in expectedValues.keys()) {
                        if (not Value.equal(args[i].value, expectedValues[i])) {
                            Runtime.trap("Failed whitespace/comment parse at index " # debug_show (i) # "\nInput:    " # input # "\nExpected: " # Value.toText(expectedValues[i]) # "\nActual:   " # Value.toText(args[i].value));
                        };
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
        let testCases : [(Text, [Value.Value])] = [
            ("(service \"aaaaa-aa\")", [#service(Principal.fromText("aaaaa-aa"))]),
            ("(func \"aaaaa-aa\".test)", [#func_({ service = Principal.fromText("aaaaa-aa"); method = "test" })]),
            ("(principal \"aaaaa-aa\")", [#principal(Principal.fromText("aaaaa-aa"))]),
            // Multiple references
            (
                "(service \"aaaaa-aa\", principal \"rrkah-fqaaa-aaaaa-aaaaq-cai\")",
                [
                    #service(Principal.fromText("aaaaa-aa")),
                    #principal(Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai")),
                ],
            ),
        ];

        for ((input, expectedValues) in testCases.vals()) {
            switch (Arg.fromText(input)) {
                case (#ok(args)) {
                    if (args.size() != expectedValues.size()) {
                        Runtime.trap("Expected " # debug_show (expectedValues.size()) # " arguments but got " # debug_show (args.size()) # " for input: " # input);
                    };
                    for (i in expectedValues.keys()) {
                        if (not Value.equal(args[i].value, expectedValues[i])) {
                            Runtime.trap("Failed reference parse at index " # debug_show (i) # "\nInput:    " # input # "\nExpected: " # Value.toText(expectedValues[i]) # "\nActual:   " # Value.toText(args[i].value));
                        };
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
    "fromText - strings with commas",
    func() {
        // Ensure that commas inside strings don't break argument parsing
        let testCases : [(Text, [Value.Value])] = [
            ("(\"a,b,c\")", [#text("a,b,c")]),
            ("(\"first,second\", \"third\")", [#text("first,second"), #text("third")]),
            ("(\"comma: ,\", 42)", [#text("comma: ,"), #nat(42)]),
        ];

        for ((input, expectedValues) in testCases.vals()) {
            switch (Arg.fromText(input)) {
                case (#ok(args)) {
                    if (args.size() != expectedValues.size()) {
                        Runtime.trap("Expected " # debug_show (expectedValues.size()) # " arguments but got " # debug_show (args.size()) # " for input: " # input);
                    };
                    for (i in expectedValues.keys()) {
                        if (not Value.equal(args[i].value, expectedValues[i])) {
                            Runtime.trap("Failed string comma parse at index " # debug_show (i) # "\nInput:    " # input # "\nExpected: " # Value.toText(expectedValues[i]) # "\nActual:   " # Value.toText(args[i].value));
                        };
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
    "fromText - blob arguments",
    func() {
        let testCases : [(Text, [Value.Value])] = [
            ("(blob \"hello\")", [#vector([#nat8(104), #nat8(101), #nat8(108), #nat8(108), #nat8(111)])]),
            (
                "(blob \"\", blob \"test\")",
                [
                    #vector([]),
                    #vector([#nat8(116), #nat8(101), #nat8(115), #nat8(116)]),
                ],
            ),
        ];

        for ((input, expectedValues) in testCases.vals()) {
            switch (Arg.fromText(input)) {
                case (#ok(args)) {
                    if (args.size() != expectedValues.size()) {
                        Runtime.trap("Expected " # debug_show (expectedValues.size()) # " arguments but got " # debug_show (args.size()) # " for input: " # input);
                    };
                    for (i in expectedValues.keys()) {
                        if (not Value.equal(args[i].value, expectedValues[i])) {
                            Runtime.trap("Failed blob parse at index " # debug_show (i) # "\nInput:    " # input # "\nExpected: " # Value.toText(expectedValues[i]) # "\nActual:   " # Value.toText(args[i].value));
                        };
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
    "fromText - error cases",
    func() {
        let errorCases : [Text] = [
            "", // Empty string
            "42", // Missing parentheses
            "(42", // Missing closing paren
            "42)", // Missing opening paren
            "(,)", // Empty value between commas
            "(42,,43)", // Double comma
            "(42 43)", // Missing comma
            "( ,42)", // Leading comma
            "(42) extra", // Trailing content
            "extra (42)", // Leading content
        ];

        for (input in errorCases.vals()) {
            switch (Arg.fromText(input)) {
                case (#ok(args)) {
                    Runtime.trap("Expected error for input: " # input # "\nBut got successful parse with " # debug_show (args.size()) # " arguments");
                };
                case (#err(_)) {
                    // Expected error - test passes
                };
            };
        };
    },
);

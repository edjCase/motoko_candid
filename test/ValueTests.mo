import Value "../src/Value";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Bool "mo:base/Bool";
import Hash "mo:base/Hash";

module {

    public func run() {
        let errors = Buffer.Buffer<Text>(0);

        func areEqual(
            expected : Text,
            expectedIdented : ?Text,
            value : Value.Value,
        ) {
            areEqualAdvanced(
                expected,
                expectedIdented,
                value,
                {
                    tagHashMapper = null;
                    toTextOverride = null;
                },
            );
        };

        func areEqualAdvanced(
            expected : Text,
            expectedIdented : ?Text,
            value : Value.Value,
            options : {
                tagHashMapper : ?Value.TagHashMapper;
                toTextOverride : ?Value.ToTextOverride;
            },
        ) {
            let actual : Text = Value.toTextAdvanced(
                value,
                {
                    options with indented = false;
                },
            );
            if (expected != actual) {
                errors.add(expected # " != " # actual);
            };
            let actualIdented : Text = Value.toTextAdvanced(
                value,
                {
                    options with indented = true;
                },
            );
            let eIndented = switch (expectedIdented) {
                // If expected indented is null, use the unindented
                case (null) expected;
                case (?e) e;
            };
            if (eIndented != actualIdented) {
                errors.add(eIndented # "\n!=\n" # actualIdented);
                // errors.add(debug_show (Text.encodeUtf8(eIndented)) # "\n!=\n" # debug_show (Text.encodeUtf8(actualIdented)));
            };
        };

        // Nat
        areEqual("3", null, #nat8(3));
        areEqual("5", null, #nat16(5));
        areEqual("7", null, #nat32(7));
        areEqual("9", null, #nat64(9));
        areEqual("999", null, #nat(999));

        // Int
        areEqual("2", null, #int8(2));
        areEqual("4", null, #int16(4));
        areEqual("6", null, #int32(6));
        areEqual("8", null, #int64(8));
        areEqual("888", null, #int(888));

        // Float
        areEqual("34.560000", null, #float32(34.56));
        areEqual("45.670000", null, #float64(45.67));
        // Bool
        areEqual("true", null, #bool(true));
        areEqual("false", null, #bool(false));

        // Null
        areEqual("null", null, #null_);

        // Empty
        areEqual("empty", null, #empty);

        // Reserved
        areEqual("reserved", null, #reserved);

        // Principal
        areEqual("principal \"77i6o-oqaaa-aaaag-qbm6q-cai\"", null, #principal(Principal.fromText("77i6o-oqaaa-aaaag-qbm6q-cai")));

        // Text
        areEqual("\"Hello World!\"", null, #text("Hello World!"));

        // Opt
        areEqual("opt 4", null, #opt(#nat(4)));
        areEqual("opt null", null, #opt(#null_));

        // Vector
        areEqual("vec {}", null, #vector([]));
        areEqual("vec { 1, 2, 3 }", ?"vec {\n\t1,\n\t2,\n\t3\n}", #vector([#nat(1), #nat(2), #nat(3)]));

        // Record
        areEqual("record {}", null, #record([]));
        areEqual("record { 1 = 2; 2 = 3; \"test\" = 3 }", ?"record {\n\t1 = 2;\n\t2 = 3;\n\t\"test\" = 3\n}", #record([{ tag = #hash(1); value = #nat(2) }, { tag = #hash(2); value = #nat(3) }, { tag = #name("test"); value = #int(3) }]));

        // Variant
        areEqual("variant { 1 = 2 }", null, #variant({ tag = #hash(1); value = #nat(2) }));
        areEqual("variant { \"ttt\" }", null, #variant({ tag = #name("ttt"); value = #null_ }));
        areEqual("variant { \"test\" = \"ttt\" }", ?"variant { \"test\" = \"ttt\" }", #variant({ tag = #name("test"); value = #text("ttt") }));

        // Func
        areEqual("func \"77i6o-oqaaa-aaaag-qbm6q-cai\".m1", null, #_func({ method = "m1"; service = Principal.fromText("77i6o-oqaaa-aaaag-qbm6q-cai") }));

        // Service
        areEqual("service \"77i6o-oqaaa-aaaag-qbm6q-cai\"", null, #service(Principal.fromText("77i6o-oqaaa-aaaag-qbm6q-cai")));

        areEqualAdvanced(
            "record { \"11\" = opt true?; \"hello\" = record { \"🤣\" = variant { 2 = 1 } } }",
            ?"record {\n\t\"11\" = opt true?;\n\t\"hello\" = record {\n\t\t\"🤣\" = variant { 2 = 1 }\n\t}\n}",
            #record([
                { tag = #name("11"); value = #opt(#bool(true)) },
                {
                    tag = #hash(3);
                    value = #record([{
                        tag = #name("🤣");
                        value = #variant({ tag = #hash(2); value = #nat(1) });
                    }]);
                },
            ]),
            {
                tagHashMapper = ?(
                    func(h : Hash.Hash) : ?Text {
                        switch (h) {
                            case (3) ?"\"hello\"";
                            case (_) null;
                        };
                    },
                );
                toTextOverride = ?(
                    func(v : Value.Value) : ?Text {
                        switch (v) {
                            // Maps booleans to have a question mark
                            case (#bool(b)) ?(Bool.toText(b) # "?");
                            case (_) null;
                        };
                    },
                );
            },
        );
        if (errors.size() > 0) {
            let errorText = Text.join("\n\n", errors.vals());
            Debug.trap("\nValue tests failure:\n\n" # errorText);
        };
    };
};

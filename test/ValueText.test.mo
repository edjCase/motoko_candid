import Value "../src/Value";
import Text "mo:core@1/Text";
import Principal "mo:core@1/Principal";
import Bool "mo:core@1/Bool";
import Runtime "mo:core@1/Runtime";
import List "mo:core@1/List";
import { test } "mo:test";

let errors = List.empty<Text>();

func testToText(
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
  test(
    "Value toText for value: " # debug_show (value),
    func() {
      let actual : Text = Value.toTextAdvanced(
        value,
        {
          options with indented = false;
        },
      );
      if (expected != actual) {
        Runtime.trap("Failed toText equality\nExpected: " # expected # "\nActual:   " # actual);
      };
      let actualIdented : Text = Value.toTextAdvanced(
        value,
        {
          options with indented = true;
        },
      );
      switch (expectedIdented) {
        // If expected indented is null, skip the indented test
        case (null) ();
        case (?e) {
          if (e != actualIdented) {
            Runtime.trap("Failed toText (indented) equality\n\nExpected indented: " # e # "\nActual indented: " # actualIdented);
          };
        };
      };

    },
  );
};

// Nat
testToText("3", null, #nat8(3));
testToText("5", null, #nat16(5));
testToText("7", null, #nat32(7));
testToText("9", null, #nat64(9));
testToText("999", null, #nat(999));

// Int
testToText("2", null, #int8(2));
testToText("4", null, #int16(4));
testToText("6", null, #int32(6));
testToText("8", null, #int64(8));
testToText("888", null, #int(888));

// Float
testToText("0.423_449_999_999_999_99", null, #float32(0.42345));
testToText("4", null, #float64(4));
// Bool
testToText("true", null, #bool(true));
testToText("false", null, #bool(false));

// Null
testToText("null", null, #null_);

// Empty
testToText("empty", null, #empty);

// Reserved
testToText("reserved", null, #reserved);

// Principal
testToText("principal \"77i6o-oqaaa-aaaag-qbm6q-cai\"", null, #principal(Principal.fromText("77i6o-oqaaa-aaaag-qbm6q-cai")));

// Text
testToText("\"Hello World!\"", null, #text("Hello World!"));

// Opt
testToText("opt 4", null, #opt(#nat(4)));
testToText("opt null", null, #opt(#null_));

// Vector
testToText("vec {}", null, #vector([]));
testToText("vec { 1, 2, 3 }", ?"vec {\n\t1,\n\t2,\n\t3\n}", #vector([#nat(1), #nat(2), #nat(3)]));

// Record
testToText("record {}", null, #record([]));
testToText("record { 1 = 2; 2 = 3; \"test\" = 3 }", ?"record {\n\t1 = 2;\n\t2 = 3;\n\t\"test\" = 3\n}", #record([{ tag = #hash(1); value = #nat(2) }, { tag = #hash(2); value = #nat(3) }, { tag = #name("test"); value = #int(3) }]));

// Variant
testToText("variant { 1 = 2 }", null, #variant({ tag = #hash(1); value = #nat(2) }));
testToText("variant { \"ttt\" }", null, #variant({ tag = #name("ttt"); value = #null_ }));
testToText("variant { \"test\" = \"ttt\" }", ?"variant { \"test\" = \"ttt\" }", #variant({ tag = #name("test"); value = #text("ttt") }));

// Func
testToText("func \"77i6o-oqaaa-aaaag-qbm6q-cai\".m1", null, #func_({ method = "m1"; service = Principal.fromText("77i6o-oqaaa-aaaag-qbm6q-cai") }));

// Service
testToText("service \"77i6o-oqaaa-aaaag-qbm6q-cai\"", null, #service(Principal.fromText("77i6o-oqaaa-aaaag-qbm6q-cai")));

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
      func(h : Nat32) : ?Text {
        switch (h) {
          case (3) ?"\"hello\"";
          case (_) null;
        };
      }
    );
    toTextOverride = ?(
      func(v : Value.Value) : ?Text {
        switch (v) {
          // Maps booleans to have a question mark
          case (#bool(b)) ?(Bool.toText(b) # "?");
          case (_) null;
        };
      }
    );
  },
);
if (List.size(errors) > 0) {
  let errorText = Text.join("\n\n", List.values(errors));
  Runtime.trap("\nValue tests failure:\n\n" # errorText);
};

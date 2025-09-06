import Type "../src/Type";
import Text "mo:core@1/Text";
import { test } "mo:test";
import Runtime "mo:core@1/Runtime";

func testToText(
  expected : Text,
  expectedIdented : ?Text,
  value : Type.Type,
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
  value : Type.Type,
  options : {
    tagHashMapper : ?Type.TagHashMapper;
    toTextOverride : ?Type.ToTextOverride;
  },
) {
  test(
    "Type toText for value: " # debug_show (value),
    func() {
      let actual : Text = Type.toTextAdvanced(
        value,
        {
          options with indented = false;
        },
      );
      if (expected != actual) {
        Runtime.trap("Failed toText equality\nExpected: " # expected # "\nActual:   " # actual);
      };
      let actualIdented : Text = Type.toTextAdvanced(
        value,
        {
          options with indented = true;
        },
      );
      switch (expectedIdented) {
        // If expected indented is null, use the unindented
        case (null) ();
        case (?e) {
          if (e != actualIdented) {
            Runtime.trap("Failed toText (indented) equality\nExpected indented: " # e # "\nActual indented: " # actualIdented);
          };
        };
      };

    },
  );
};

// Nat
testToText("nat8", null, #nat8);
testToText("nat16", null, #nat16);
testToText("nat32", null, #nat32);
testToText("nat64", null, #nat64);
testToText("nat", null, #nat);

// Int
testToText("int8", null, #int8);
testToText("int16", null, #int16);
testToText("int32", null, #int32);
testToText("int64", null, #int64);
testToText("int", null, #int);

// Float
testToText("float32", null, #float32);
testToText("float64", null, #float64);
// Bool
testToText("bool", null, #bool);

// Null
testToText("null", null, #null_);

// Empty
testToText("empty", null, #empty);

// Reserved
testToText("reserved", null, #reserved);

// Principal
testToText("principal", null, #principal);

// Text
testToText("text", null, #text);

// Opt
testToText("opt nat", null, #opt(#nat));
testToText("opt null", null, #opt(#null_));

// Vector
testToText("vec nat8", null, #vector(#nat8));

// Record
testToText("record {}", null, #record([]));
testToText(
  "record { 1 : nat; 2 : null; \"test\" : principal }",
  ?"record {\n\t1 : nat;\n\t2 : null;\n\t\"test\" : principal\n}",
  #record([
    { tag = #hash(1); type_ = #nat },
    { tag = #hash(2); type_ = #null_ },
    { tag = #name("test"); type_ = #principal },
  ]),
);
testToText(
  "recursiveId1.record { 1 : opt recursiveId1 }",
  ?"recursiveId1.record {\n\t1 : opt recursiveId1\n}",
  #recursiveType({
    id = "recursiveId1";
    type_ = #record([
      {
        tag = #hash(1);
        type_ = #opt(#recursiveReference("recursiveId1"));
      },
    ]);
  }),
);

// Variant
testToText(
  "variant { 1 : nat; 2 : nat8 }",
  ?"variant {\n\t1 : nat;\n\t2 : nat8\n}",
  #variant([
    { tag = #hash(1); type_ = #nat },
    { tag = #hash(2); type_ = #nat8 },
  ]),
);
testToText(
  "variant { \"ttt\"; 34 : bool }",
  ?"variant {\n\t\"ttt\";\n\t34 : bool\n}",
  #variant([
    { tag = #name("ttt"); type_ = #null_ },
    { tag = #hash(34); type_ = #bool },
  ]),
);
// Func
testToText(
  "( opt nat, reserved ) -> ( opt vec nat8, variant { 1 : nat; \"t\" : nat8 } ) query oneway",
  ?"(\n\topt nat,\n\treserved\n) -> (\n\topt vec nat8,\n\tvariant {\n\t\t1 : nat;\n\t\t\"t\" : nat8\n\t}\n) query oneway",
  #func_({
    modes = [#query_, #oneway];
    argTypes = [
      #opt(#nat),
      #reserved,
    ];
    returnTypes = [
      #opt(#vector(#nat8)),
      #variant([
        { tag = #hash(1); type_ = #nat },
        { tag = #name("t"); type_ = #nat8 },
      ]),
    ];
  }),
);
testToText(
  "() -> ()",
  ?"() -> ()",
  #func_({
    modes = [];
    argTypes = [];
    returnTypes = [];
  }),
);

// Service
testToText(
  "service : { m1 : ( opt nat, reserved ) -> ( opt vec nat8, variant { 1 : nat; \"t\" : nat8 } ) query oneway; m2 : () -> () }",
  ?"service : {\n\tm1 : (\n\t\topt nat,\n\t\treserved\n\t) -> (\n\t\topt vec nat8,\n\t\tvariant {\n\t\t\t1 : nat;\n\t\t\t\"t\" : nat8\n\t\t}\n\t) query oneway;\n\tm2 : () -> ()\n}",
  #service({
    methods = [
      (
        "m1",
        {
          modes = [#query_, #oneway];
          argTypes = [
            #opt(#nat),
            #reserved,
          ];
          returnTypes = [
            #opt(#vector(#nat8)),
            #variant([
              { tag = #hash(1); type_ = #nat },
              { tag = #name("t"); type_ = #nat8 },
            ]),
          ];
        },
      ),
      (
        "m2",
        {
          modes = [];
          argTypes = [];
          returnTypes = [];
        },
      ),
    ];
  }),
);

areEqualAdvanced(
  "record { \"11\" : opt bool?; \"hello\" : record { \"🤣\" : variant { 2 : nat } } }",
  ?"record {\n\t\"11\" : opt bool?;\n\t\"hello\" : record {\n\t\t\"🤣\" : variant {\n\t\t\t2 : nat\n\t\t}\n\t}\n}",
  #record([
    { tag = #name("11"); type_ = #opt(#bool) },
    {
      tag = #hash(3);
      type_ = #record([{
        tag = #name("🤣");
        type_ = #variant([{ tag = #hash(2); type_ = #nat }]);
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
      func(v : Type.Type) : ?Text {
        switch (v) {
          // Maps booleans to have a question mark
          case (#bool) ?"bool?";
          case (_) null;
        };
      }
    );
  },
);

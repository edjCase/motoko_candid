# Motoko Candid

[![MOPS](https://img.shields.io/badge/MOPS-candid-blue)](https://mops.one/candid)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/edjCase/motoko_candid/blob/main/LICENSE)

A comprehensive Motoko implementation of the Candid binary format for encoding and decoding structured data on the Internet Computer.

## Funding

This library was originally incentivized by [ICDevs](https://ICDevs.org). You
can view more about the bounty on the
[forum](https://forum.dfinity.org/t/icdevs-org-bounty-18-cbor-and-candid-motoko-parser-3-000/11398)
or [website](https://icdevs.org/bounties/2022/02/22/CBOR-and-Candid-Motoko-Parser.html). The
bounty was funded by The ICDevs.org commuity and the award paid to
@Gekctek. If you use this library and gain value from it, please consider
a [donation](https://icdevs.org/donations.html) to ICDevs.

## Package

### MOPS

```bash
mops add candid
```

To set up MOPS package manager, follow the instructions from the [MOPS Site](https://mops.one)

## What is Candid?

Candid is an interface description language (IDL) developed by the DFINITY Foundation for the Internet Computer. It provides a language-agnostic way to describe the public interfaces of services, including the signatures of methods and the structure of data. This library implements the binary serialization format that allows Motoko programs to encode and decode Candid data.

## Supported Features

-   **Complete Candid type system support** including all primitive and compound types
-   **Type-safe value representation** with comprehensive type definitions
-   **Binary encoding/decoding** following the official Candid specification
-   **Text parsing and generation** for human-readable value representation
-   **Automatic type inference** to derive minimal types from values
-   **Streaming support** with buffer-based encoding for memory efficiency
-   **Full round-trip fidelity** between Motoko types and binary format
-   **Principal and service support** for Internet Computer integration
-   **Comparison and hashing** utilities for types and values
-   **Rich type system** including:
    -   All integer types (Int, Int8, Int16, Int32, Int64, Nat, Nat8, Nat16, Nat32, Nat64)
    -   Floating-point types (Float32, Float64)
    -   Text and Boolean types
    -   Optional and Vector types
    -   Record and Variant types
    -   Function and Service types
    -   Principal type

## Quick Start

### Example 1: Basic Encoding and Decoding

```motoko
import Candid "mo:candid";
import Runtime "mo:core/Runtime";

// Create arguments with values and types
let args : [Candid.Arg] = [
    {
        value = #text("Hello, Candid!");
        type_ = #text
    },
    {
        value = #nat(42);
        type_ = #nat
    },
    {
        value = #bool(true);
        type_ = #bool
    }
];

// Encode to bytes
let bytes: [Nat8] = Candid.toBytes(args);

// Decode back to arguments
let ?decodedArgs = Candid.fromBytes(bytes.vals()) else Runtime.trap("Failed to decode candid");
```

### Example 2: Buffer-based Encoding

```motoko
import Candid "mo:candid";
import List "mo:core/List";

let args : [Candid.Arg] = [
    {
        value = #record([
            { tag = #name("name"); value = #text("Alice") },
            { tag = #name("age"); value = #nat(30) }
        ]);
        type_ = #record([
            { tag = #name("name"); type_ = #text },
            { tag = #name("age"); type_ = #nat }
        ])
    }
];

// Create a buffer for streaming encoding
let buffer = List.empty<Nat8>();

// Encode to buffer
Candid.toBytesBuffer(Buffer.fromList(buffer), args);

// Buffer now contains the encoded data
let encodedBytes = List.toArray(buffer);
```

### Example 3: Working with Complex Types

```motoko
import Candid "mo:candid";

// Create a variant value
let variantArg : Candid.Arg = {
    value = #variant({ tag = #name("success"); value = #text("Operation completed") });
    type_ = #variant([
        { tag = #name("success"); type_ = #text },
        { tag = #name("error"); type_ = #text }
    ]);
};

// Create an optional value
let optionalArg : Candid.Arg = {
    value = #opt(#nat(123));
    type_ = #opt(#nat);
};

// Create a vector value
let vectorArg : Candid.Arg = {
    value = #vector([#nat(1), #nat(2), #nat(3)]);
    type_ = #vector(#nat);
};

let args = [variantArg, optionalArg, vectorArg];
let bytes = Candid.toBytes(args);
```

### Example 4: Creating Args from Values

```motoko
import CandidArg "mo:candid/Arg";
import CandidValue "mo:candid/Value";

// Create a value
let value : CandidValue.Value = #record([
    { tag = #name("name"); value = #text("Bob") },
    { tag = #name("balance"); value = #nat(1000) }
]);

// Automatically infer the type from the value
let arg = CandidArg.fromValue(value);
// arg.type_ is automatically set to the minimal implicit type

// Or manually get the implicit type
let implicitType = CandidValue.toImplicitType(value);
// implicitType is #record([...]) with inferred field types
```

### Example 5: Text Representation and Parsing

```motoko
import CandidValue "mo:candid/Value";

// Parse a Value from text (returns value and its type)
let textValue = "record { age = 30; name = \"Alice\"; active = true }";
let result = CandidValue.fromText(textValue);

switch (result) {
  case (#ok((value, type_))) {
    // value is the parsed Value
    // type_ is the inferred Type for the value

    // Convert back to text
    let compactText = CandidValue.toText(value);
    // compactText is "record { age = 30; name = \"Alice\"; active = true }"

    // Convert to indented text for better readability
    let indentedText = CandidValue.toTextIndented(value);
    // indentedText is formatted with newlines and tabs

    // Use advanced options with custom tag mapping
    let options : CandidValue.ToTextOptions = {
      tagHashMapper = ?(func(h : Nat32) : ?Text {
        // Map hash to custom field name if needed
        null
      });
      toTextOverride = null;
      indented = true
    };
    let customText = CandidValue.toTextAdvanced(value, options);
  };
  case (#err(e)) {
    // Handle parse error
  };
};
```

### Example 6: Parsing Argument Lists

```motoko
import CandidArg "mo:candid/Arg";
import CandidValue "mo:candid/Value";
import Candid "mo:candid";

// Parse an argument list from text
let argText = "(42, \"hello\", true)";
let result = CandidArg.fromText(argText);

switch (result) {
  case (#ok(args)) {
    // args is [Arg] with parsed values and inferred types
    // args[0].value is #nat(42), args[0].type_ is #nat
    // args[1].value is #text("hello"), args[1].type_ is #text
    // args[2].value is #bool(true), args[2].type_ is #bool

    // You can now use these args for encoding
    let bytes = Candid.toBytes(args);
  };
  case (#err(e)) {
    // Handle parse error
  };
};

// Argument lists support trailing commas
let withTrailingComma = "(1, 2, 3,)";
switch (CandidArg.fromText(withTrailingComma)) {
  case (#ok(args)) {
    // Successfully parses as [#nat(1), #nat(2), #nat(3)]
  };
  case (#err(e)) { /* error */ };
};
```

## API Reference

### Main Functions

-   **`toBytes()`** - Converts Candid arguments to binary format
-   **`fromBytes()`** - Converts binary data back to Candid arguments
-   **`toBytesBuffer()`** - Streams encoding to a buffer

### Types

```motoko
// Main argument type combining value and type information
public type Arg = {
    value : Value;
    type_ : Type;
};

// Comprehensive value type supporting all Candid data types
public type Value = {
    #int : Int;                    // Arbitrary precision integers
    #int8 : Int8;                  // 8-bit signed integers
    #int16 : Int16;                // 16-bit signed integers
    #int32 : Int32;                // 32-bit signed integers
    #int64 : Int64;                // 64-bit signed integers
    #nat : Nat;                    // Natural numbers
    #nat8 : Nat8;                  // 8-bit natural numbers
    #nat16 : Nat16;                // 16-bit natural numbers
    #nat32 : Nat32;                // 32-bit natural numbers
    #nat64 : Nat64;                // 64-bit natural numbers
    #bool : Bool;                  // Boolean values
    #float32 : Float;              // 32-bit floating point
    #float64 : Float;              // 64-bit floating point
    #text : Text;                  // UTF-8 text strings
    #null_;                        // Null value
    #reserved;                     // Reserved placeholder
    #empty;                        // Empty type
    #opt : Value;                  // Optional values
    #vector : [Value];             // Homogeneous arrays
    #record : [RecordFieldValue];  // Named field records
    #variant : VariantOptionValue; // Tagged union types
    #func_ : Func;                 // Function references
    #service : Principal;          // Service references
    #principal : Principal;        // Principal identifiers
};

// Record field with tag and value
public type RecordFieldValue = {
    tag : Tag;
    value : Value;
};

// Function reference
public type Func = {
    service : Principal;
    method : Text;
};

// Type system mirroring the value system
public type Type = {
    #int; #int8; #int16; #int32; #int64;
    #nat; #nat8; #nat16; #nat32; #nat64;
    #bool; #float32; #float64; #text;
    #null_; #reserved; #empty; #principal;
    #opt : Type;
    #vector : Type;
    #record : [RecordFieldType];
    #variant : [VariantOptionType];
    #func_ : FuncType;
    #service : ServiceType;
    #recursive : {
        id : Nat32;
        type_ : Type;
    };
};

// Tag for field identification
public type Tag = {
    #hash : Nat32;    // Hash-based tag
    #name : Text;     // Name-based tag
};
```

### Functions

#### Main Module

```motoko
// Encode Candid arguments to bytes
public func toBytes(args : [Arg]) : [Nat8];

// Encode Candid arguments to an existing buffer
public func toBytesBuffer(buffer : Buffer.Buffer<Nat8>, args : [Arg]);

// Decode bytes to Candid arguments
public func fromBytes(bytes : Iter.Iter<Nat8>) : ?[Arg];
```

#### Value Module

```motoko
// Parse a Value from its text representation
// Returns both the parsed value and its inferred type
public func fromText(text : Text) : Result.Result<(Value, Type), Text>;

// Convert a Value to text (compact format)
public func toText(value : Value) : Text;

// Convert a Value to text (indented format)
public func toTextIndented(value : Value) : Text;

// Convert a Value to text with advanced options
public func toTextAdvanced(value : Value, options : ToTextOptions) : Text;

// Get the implicit minimum type for a Value
public func toImplicitType(value : Value) : Type;

// Compare two Values for equality
public func equal(v1 : Value, v2 : Value) : Bool;

// Compare two Values
public func compare(v1 : Value, v2 : Value) : Order.Order;
```

#### Type Module

```motoko
// Convert a Type to text (compact format)
public func toText(type_ : Type) : Text;

// Convert a Type to text (indented format)
public func toTextIndented(type_ : Type) : Text;

// Convert a Type to text with advanced options
public func toTextAdvanced(type_ : Type, options : ToTextOptions) : Text;

// Compare two Types for equality
public func equal(t1 : Type, t2 : Type) : Bool;

// Compare two Types
public func compare(t1 : Type, t2 : Type) : Order.Order;

// Compute hash of a Type
public func hash(t : Type) : Nat32;

// Compute hash of text (used for field names)
public func hashText(t : Text) : Nat32;
```

#### Arg Module

```motoko
// Parse argument list from text
public func fromText(text : Text) : Result.Result<[Arg], Text>;

// Create an Arg from a Value by inferring its implicit type
public func fromValue(value : Value) : Arg;

// Convert an Arg to its text representation
public func toText(arg : Arg) : Text;
```

## Candid Type System

This implementation supports the complete Candid type system:

### Text Representation

The library supports parsing and generating text representations of Candid values:

-   **Parsing**: Convert text like `"record { age = 30; name = \"Alice\" }"` to a `Value`
-   **Compact format**: Single-line text representation for all values
-   **Indented format**: Multi-line formatted output for complex structures
-   **Custom mapping**: Map hash-based field tags to meaningful names
-   **Override support**: Custom text rendering for specific value types

Supported text syntax includes:

-   Primitive values: `42`, `true`, `"text"`, `null`
-   Optional values: `opt 42`
-   Vectors: `vec { 1; 2; 3 }`
-   Records: `record { field1 = value1; field2 = value2 }`
-   Variants: `variant { tag = value }`
-   Tuples: `record { value1; value2 }` (fields numbered 0, 1, 2, ...)
-   Principals: `principal "aaaaa-aa"`
-   Services: `service "aaaaa-aa"`
-   Functions: `func "aaaaa-aa".methodName`
-   Comments: `// line comment` and `/* block comment */`
-   Hex numbers: `0x1a2b`, `0x1a.2bp10`
-   Type annotations: `(42 : nat)` (parsed but type info is discarded)

### Primitive Types

-   **Integers**: `int`, `int8`, `int16`, `int32`, `int64`
-   **Natural Numbers**: `nat`, `nat8`, `nat16`, `nat32`, `nat64`
-   **Floating Point**: `float32`, `float64`
-   **Text**: UTF-8 encoded strings
-   **Boolean**: `bool`
-   **Special**: `null`, `reserved`, `empty`
-   **Principal**: Internet Computer principal identifiers

### Compound Types

-   **Optional**: `opt T` - nullable values
-   **Vector**: `vec T` - homogeneous arrays
-   **Record**: `record { field1: T1; field2: T2 }` - structured data with named fields
-   **Variant**: `variant { option1: T1; option2: T2 }` - tagged union types
-   **Function**: `func (args) -> (results)` - function signatures
-   **Service**: Service type definitions with method signatures

### Type Features

-   **Recursive Types**: Support for self-referential type definitions
-   **Field Tags**: Both hash-based and name-based field identification
-   **Type Safety**: Compile-time type checking with runtime validation
-   **Subtyping**: Compatible with Candid's structural subtyping rules

## Error Handling

The library uses option types for error handling:

-   `toBytes()` returns `[Nat8]` (never fails with valid input)
-   `fromBytes()` returns `?[Arg]` (null on invalid input)
-   Buffer operations are infallible for valid inputs

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

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

The `lib.mo` module provides the primary API for working with Candid data. Import it as `mo:candid` to access all core functionality including encoding/decoding bytes and text representation. Additional modules (`Arg`, `Value`, `Type`) are available for advanced operations like type comparison, custom text formatting, and type utilities.

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

### Example 4: Text Representation

```motoko
import Candid "mo:candid";

// Create arguments
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

// Convert arguments to text
let text = Candid.toText(args);
// text is "(record { age = 30; name = "Alice" })"

// Parse arguments from text
let result = Candid.fromText("(42, \"hello\", true)");
switch (result) {
    case (#ok(parsedArgs)) {
        // parsedArgs contains the parsed arguments with inferred types
        let bytes = Candid.toBytes(parsedArgs);
    };
    case (#err(e)) { /* Handle error */ };
};
```

### Example 5: Advanced Value Operations

For advanced operations on individual values, types, or arguments, use the specialized modules:

```motoko
import CandidValue "mo:candid/Value";
import CandidType "mo:candid/Type";

// Parse a Value from text (returns value and its type)
let textValue = "record { age = 30; name = \"Alice\"; active = true }";
let result = CandidValue.fromText(textValue);

switch (result) {
  case (#ok((value, type_))) {
    // Convert back to text with different formats
    let compactText = CandidValue.toText(value);
    let indentedText = CandidValue.toTextIndented(value);

    // Compare values
    let value2 = #record([{ tag = #name("age"); value = #nat(30) }]);
    let areEqual = CandidValue.equal(value, value2);

    // Get the implicit type from a value
    let implicitType = CandidValue.toImplicitType(value);

    // Type operations
    let typeHash = CandidType.hash(type_);
    let typeText = CandidType.toText(type_);
  };
  case (#err(e)) {
    // Handle parse error
  };
};
```

## API Reference

### Main Module (`mo:candid`)

The primary API for encoding/decoding Candid data. Import this module for standard operations:

```motoko
import Candid "mo:candid";
```

#### Core Functions

-   **`toBytes(args : [Arg]) : [Nat8]`** - Encode arguments to binary format
-   **`fromBytes(bytes : Iter.Iter<Nat8>) : ?[Arg]`** - Decode binary data to arguments
-   **`toBytesBuffer(buffer : Buffer.Buffer<Nat8>, args : [Arg])`** - Stream encoding to a buffer
-   **`toText(args : [Arg]) : Text`** - Convert arguments to text representation
-   **`fromText(text : Text) : Result.Result<[Arg], Text>`** - Parse arguments from text

### Advanced Modules

For specialized operations, import the specific modules:

-   **`mo:candid/Value`** - Value operations (comparison, text formatting, type inference)
-   **`mo:candid/Type`** - Type operations (comparison, hashing, text representation)
-   **`mo:candid/Arg`** - Argument utilities (same functions as main module, plus `fromValue`)
-   **`mo:candid/Tag`** - Tag hashing utilities
-   **`mo:candid/FuncMode`** - Function mode type definitions

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

### Additional Module Functions

#### Value Module (`mo:candid/Value`)

For operations on individual values:

```motoko
// Parse a Value from text (returns value and inferred type)
public func fromText(text : Text) : Result.Result<(Value, Type), Text>;

// Convert Value to text
public func toText(value : Value) : Text;
public func toTextIndented(value : Value) : Text;
public func toTextAdvanced(value : Value, options : ToTextOptions) : Text;

// Get the implicit minimum type for a Value
public func toImplicitType(value : Value) : Type;

// Compare Values
public func equal(v1 : Value, v2 : Value) : Bool;
public func compare(v1 : Value, v2 : Value) : Order.Order;
```

#### Type Module (`mo:candid/Type`)

For operations on types:

```motoko
// Convert Type to text
public func toText(type_ : Type) : Text;
public func toTextIndented(type_ : Type) : Text;
public func toTextAdvanced(type_ : Type, options : ToTextOptions) : Text;

// Compare Types
public func equal(t1 : Type, t2 : Type) : Bool;
public func compare(t1 : Type, t2 : Type) : Order.Order;

// Compute hash of a Type
public func hash(t : Type) : Nat32;
public func hashText(t : Text) : Nat32;
```

#### Arg Module (`mo:candid/Arg`)

Same functions as main module, plus:

```motoko
// Create an Arg from a Value by inferring its implicit type
public func fromValue(value : Value) : Arg;
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

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

- **Complete Candid type system support** including all primitive and compound types
- **Type-safe value representation** with comprehensive type definitions
- **Binary encoding/decoding** following the official Candid specification
- **Streaming support** with buffer-based encoding for memory efficiency
- **Full round-trip fidelity** between Motoko types and binary format
- **Principal and service support** for Internet Computer integration
- **Rich type system** including:
  - All integer types (Int, Int8, Int16, Int32, Int64, Nat, Nat8, Nat16, Nat32, Nat64)
  - Floating-point types (Float32, Float64)
  - Text and Boolean types
  - Optional and Vector types
  - Record and Variant types
  - Function and Service types
  - Principal type

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
import Buffer "mo:buffer";

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

## API Reference

### Main Functions

- **`toBytes()`** - Converts Candid arguments to binary format
- **`fromBytes()`** - Converts binary data back to Candid arguments
- **`toBytesBuffer()`** - Streams encoding to a buffer

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

```motoko
// Encode Candid arguments to bytes
public func toBytes(args : [Arg]) : [Nat8];

// Encode Candid arguments to an existing buffer
public func toBytesBuffer(buffer : Buffer.Buffer<Nat8>, args : [Arg]);

// Decode bytes to Candid arguments
public func fromBytes(bytes : Iter.Iter<Nat8>) : ?[Arg];
```

## Candid Type System

This implementation supports the complete Candid type system:

### Primitive Types

- **Integers**: `int`, `int8`, `int16`, `int32`, `int64`
- **Natural Numbers**: `nat`, `nat8`, `nat16`, `nat32`, `nat64`
- **Floating Point**: `float32`, `float64`
- **Text**: UTF-8 encoded strings
- **Boolean**: `bool`
- **Special**: `null`, `reserved`, `empty`
- **Principal**: Internet Computer principal identifiers

### Compound Types

- **Optional**: `opt T` - nullable values
- **Vector**: `vec T` - homogeneous arrays
- **Record**: `record { field1: T1; field2: T2 }` - structured data with named fields
- **Variant**: `variant { option1: T1; option2: T2 }` - tagged union types
- **Function**: `func (args) -> (results)` - function signatures
- **Service**: Service type definitions with method signatures

### Type Features

- **Recursive Types**: Support for self-referential type definitions
- **Field Tags**: Both hash-based and name-based field identification
- **Type Safety**: Compile-time type checking with runtime validation
- **Subtyping**: Compatible with Candid's structural subtyping rules

## Error Handling

The library uses option types for error handling:

- `toBytes()` returns `[Nat8]` (never fails with valid input)
- `fromBytes()` returns `?[Arg]` (null on invalid input)
- Buffer operations are infallible for valid inputs

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

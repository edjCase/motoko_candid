## Funding

This library was originally incentivized by [ICDevs](https://ICDevs.org). You
can view more about the bounty on the
[forum](https://forum.dfinity.org/t/icdevs-org-bounty-18-cbor-and-candid-motoko-parser-3-000/11398)
or [website](https://icdevs.org/bounties/2022/02/22/CBOR-and-Candid-Motoko-Parser.html). The
bounty was funded by The ICDevs.org commuity and the award paid to
@Gekctek. If you use this library and gain value from it, please consider
a [donation](https://icdevs.org/donations.html) to ICDevs.

# Overview

This is a library that enables encoding/decoding of bytes to candid values

# Package

### MOPS

```
mops install candid
```

To setup MOPS package manage, follow the instructions from the [MOPS Site](https://j4mwm-bqaaa-aaaam-qajbq-cai.ic0.app/)

# Usage

## Decode 
```
let encodedArgs : Blob = ...;
let ?args: ?[Arg.Arg] = Decoder.decode(encodedArgs) else Debug.trap("Invalid candid");
```

## Encode
```
let returnArgs: [Arg.Arg] = [
    {
        type_=#bool;
        value=#bool(true)
    }
];
let encodedArgs : Blob = Encoder.encode(returnArgs);
```

# API

## Decoder

`decode(candidBytes: Blob) : ?[Arg.Arg]`

Decodes a series of bytes to CandiArgs. If invalid candid bytes, will return null

## Encoder

`encode(args: [Arg.Arg]) : Blob`

Encodes an array of candid arguments to bytes

`encodeToBuffer(buffer : Buffer.Buffer<Nat8>, args : [Arg.Arg]) : ()`

Encodes an array of candid arguments to a byte buffer

## Tag

`hash(t : Tag) : Nat32`

Hashes a tag name to a Nat32. If already hashed, will use hash value

`hashName(name : Text) : Nat32`

Hashes a tag name to a Nat32

`equal(t1: Tag, t2: Tag) : Bool`

Checks for equality between two tags

`compare(t1: Tag, t2: Tag) : Order.Order`

Compares order between two tags

## Type

`equal(v1: Type, v2: Type): Bool`

Checks for equality between two types

`hash(t : Type) : Hash.Hash`

Hashes a type to a Nat32

## Value

`equal(v1: Value, v2: Value): Bool`

Checks for equality between two values

# Testing

```
mops test
```

## TODO

- Opaque reference byte encoding/decoding
- Error messaging vs null return type for decoding
- Better/Documented error messages
- More test cases

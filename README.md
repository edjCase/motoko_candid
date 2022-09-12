# Overview

This is a library that enables encoding/decoding of bytes to candid values

# Package

### Vessel

Currently there is no official package but there is a manual process:

1. Add the following to the `additions` list in the `package-set.dhall`

```
{
    name = "candid"
    , version = "{{Version}}"
    , repo = "https://github.com/gekctek/motoko_candid"
    , dependencies = [] : List Text
}
```

Where `{{Version}}` should be replaced with the latest release from https://github.com/Gekctek/motoko_numbers/releases/

2. Add `candid` as a value in the dependencies list
3. Run `./build.sh` which runs the vessel command to install the package

# Usage

Example of `call_raw` usage:

```
func call_raw(p : Principal, m : Text, a : Blob) : async Blob {
    // Parse parameters
    let args: [Arg.Arg] = switch(Decoder.decode(a)) {
        case (null) Debug.trap("Invalid candid");
        case (?c) c;
    };

    // Validate request...

    // Process request...

    // Return result
    let returnArgs: [Arg.Arg] = [
        {
            _type=#bool;
            value=#bool(true)
        }
    ];
    Encoder.encode(returnArgs);
};
```

# API

# Library Devlopment:

## First time setup

To build the library, the `Vessel` library must be installed. It is used to pull down packages and locate the compiler for building.

https://github.com/dfinity/vessel

## Building

To build, run the `./build.sh` file. It will output wasm files to the `./build` directory

## Testing

To run tests, use the `./test.sh` file.
The entry point for all tests is `test/Tests.mo` file
It will compile the tests to a wasm file and then that file will be executed.
Currently there are no testing frameworks and testing will stop at the first broken test. It will then output the error to the console

## TODO

- How to properly escape special words like 'func'. Currently doing '\_func'
- Opaque reference byte encoding/decoding
- Error messaging vs null return type for decoding
- Better/Documented error messages
- More test cases
- Use testing framework

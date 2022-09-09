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

# Library Devlopment:

## First time setup

To build the library, the `Vessel` library must be installed. It is used to pull down packages and locate the compiler for building.

https://github.com/dfinity/vessel

## Building

To build, run the `./build.sh` file.
It uses the entry point of

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

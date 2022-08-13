


# Usage



# Library Devlopment:

## First time setup
To build the library, the `Vessel` library must be installed. It is used to pull down packages and locate the compiler for building.

https://github.com/dfinity/vessel


## Building
To build, run the `./build.sh` file.
It uses the entry point of 

## Running
The only 

## Testing
To run tests, use the `./test.sh` file.
The entry point for all tests is `test/Tests.mo` file
It will compile the tests to a wasm file and then that file will be executed.
Currently there are no testing frameworks and testing will stop at the first broken test. It will then output the error to the console


## TODO
- Better perfomance. Maybe use buffers instead of generating [Nat8] and concatinating them? 
- Proper serialization. Specifiying a type and properly serializing/deserializing it. Also custom serializers to override/customize serialization
- Consistant naming and styling





 Notes for self:
 - Convert between 2 different number types like Nat8/Nat16?
 - String concatination - `#`
 - Join binary values together and create Nat
 - Built in type methods like [].size(), where documented
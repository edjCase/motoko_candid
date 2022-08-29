import ArgEncoder "../src/ArgEncoder";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Types "../src/Types";

module {
  public func run() {
      // Nat
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7D, 0x00], #nat(0));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7D, 0x01], #nat(1));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7D, 0x7F], #nat(127));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7D, 0xE5, 0x8E, 0x26], #nat(624485));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7D, 0x80, 0x80, 0x98, 0xF4, 0xE9, 0xB5, 0xCA, 0x6A], #nat(60000000000000000));

    // Nat8
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7B, 0x00], #nat8(0));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7B, 0x10], #nat8(16));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7B, 0x63], #nat8(99));

    // Nat16
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7A, 0x00, 0x00], #nat16(0));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7A, 0x10, 0x00], #nat16(16));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7A, 0x0F, 0x27], #nat16(999));

    // Nat32
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x79, 0x00, 0x00, 0x00, 0x00], #nat32(0));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x79, 0x10, 0x00, 0x00, 0x00], #nat32(16));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x79, 0xEA, 0x49, 0x08, 0x00], #nat32(543210));
    
    // Nat64
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], #nat64(0));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x78, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], #nat64(16));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x78, 0xEA, 0x49, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00], #nat64(543210));

    // Int
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7C, 0x00], #int(0));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7C, 0x10], #int(16));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7C, 0x7C], #int(-4));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7C, 0x71], #int(-15));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7C, 0xBC, 0x7F], #int(-68));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7C, 0xE5, 0x8E, 0x26], #int(624485));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7C, 0xC0, 0xBB, 078], #int(-123456));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7C, 0x80, 0x01], #int(128));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7C, 0x80, 0x80, 0xE8, 0x8B, 0x96, 0xCA, 0xB5, 0x95, 0x7F], #int(-60000000000000000));

    // Int8
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x77, 0x00], #int8(0));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x77, 0x10], #int8(16));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x77, 0x63], #int8(99));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x77, 0xF1], #int8(-15));
    
    // Int16
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x76, 0x00, 0x00], #int16(0));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x76, 0x10, 0x00], #int16(16));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x76, 0xF1, 0xFF], #int16(-15));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x76, 0x0F, 0x27], #int16(9999));

    // Int32
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x75, 0x00, 0x00, 0x00, 0x00], #int32(0));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x75, 0x10, 0x00, 0x00, 0x00], #int32(16));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x75, 0xF1, 0xFF, 0xFF, 0xFF], #int32(-15));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x75, 0xFF, 0xFF, 0x00, 0x00], #int32(65535));
    
    // Int64
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x74, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], #int64(0));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x74, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], #int64(16));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x74, 0xF1, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF], #int64(-15));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x74, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00], #int64(4294967295));

    // Float32
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x73, 0x00, 0x00, 0x80, 0x3F], #float32(1.0));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x73, 0x10, 0x06, 0x9E, 0x3F], #float32(1.23456));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x73, 0xB7, 0xE6, 0xC0, 0xC7], #float32(-98765.4321));

    // Float64
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x72, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x3F], #float64(1.0));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x72, 0x38, 0x32, 0x8F, 0xFC, 0xC1, 0xC0, 0xF3, 0x3F], #float64(1.23456));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x72, 0x8A, 0xB0, 0xE1, 0xE9, 0xD6, 0x1C, 0xF8, 0xC0], #float64(-98765.4321));
    
    // Bool
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7E, 0x01], #bool(true));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7E, 0x00], #bool(false));

    // Text
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x71, 0x00], #text(""));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x71, 0x01, 0x41], #text("A"));
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x71, 0x2B, 0x54, 0x68, 0x65, 0x20, 0x71, 0x75, 0x69, 0x63, 0x6B, 0x20, 0x62, 0x72, 0x6F, 0x77, 0x6E, 0x20, 0x66, 0x6F, 0x78, 0x20, 0x6A, 0x75, 0x6D, 0x70, 0x73, 0x20, 0x6F, 0x76, 0x65, 0x72, 0x20, 0x74, 0x68, 0x65, 0x20, 0x6C, 0x61, 0x7A, 0x79, 0x20, 0x64, 0x6F, 0x67], #text("The quick brown fox jumps over the lazy dog"));

    // Null
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x7F], #_null);

    // Reserved
    test([0x44, 0x49, 0x44, 0x4C, 0x00, 0x01, 0x70], #reserved);

    // Opt

    // Vector

    // Record

    // Variant

    // 

    

  };

  private func test(bytes: [Nat8], arg: Types.CandidArg) {
    let actualBytes: [Nat8] = Blob.toArray(ArgEncoder.encode([arg]));
    if (not areEqual(bytes, actualBytes)) {
        Debug.trap("Failed.\nExpected Bytes: " # toHexString(bytes) # "\nActual Bytes:   " # toHexString(actualBytes) # "\nValue: " # debug_show(arg));
    }
    // TODO decode
  };

  private func areEqual(b1: [Nat8], b2: [Nat8]) : Bool {
    if (b1.size() != b2.size()) {
      return false;
    };
    for (i in Iter.range(0, b1.size() - 1)) {
      if (b1[i] != b2[i]) {
          return false;
      };
    };
    true;
  };

  private func toHexString(array : [Nat8]) : Text {
    Array.foldLeft<Nat8, Text>(array, "", func (accum, w8) {
      var pre = "";
      if(accum != ""){
          pre #= ", ";
      };
      accum # pre # encodeW8(w8);
    });
  };
  private let base : Nat8 = 0x10; 

  private let symbols = [
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ];
  /**
  * Encode an unsigned 8-bit integer in hexadecimal format.
  */
  private func encodeW8(w8 : Nat8) : Text {
    let c1 = symbols[Nat8.toNat(w8 / base)];
    let c2 = symbols[Nat8.toNat(w8 % base)];
    "0x" # Char.toText(c1) # Char.toText(c2);
  };
}
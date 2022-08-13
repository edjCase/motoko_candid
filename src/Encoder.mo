import Binary "./Binary";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Int8 "mo:base/Int8";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Util "./Util";
import Types "./Types";
import FloatX "./FloatX";

module {
  public func encode(value: Types.CborValue) : Result.Result<[Nat8], Types.CborEncodingError> {
    switch(value) {
      case (#majorType0(t0)) encodeMajorType0(t0);
      case (#majorType1(t1)) encodeMajorType1(t1);
      case (#majorType2(t2)) encodeMajorType2(t2);
      case (#majorType3(t3)) encodeMajorType3(t3);
      case (#majorType4(t4)) encodeMajorType4(t4);
      case (#majorType5(t5)) encodeMajorType5(t5);
      case (#majorType6(t6)) encodeMajorType6(t6.tag, t6.value);
      case (#majorType7(t7)) {
        switch(t7) {
          case (#_break) return #err(#invalidValue("Break is not allowed as a value"));
          case (#_null) encodeMajorType7(#_null);
          case (#_undefined) encodeMajorType7(#_undefined);
          case (#bool(b)) encodeMajorType7(#bool(b));
          case (#float(f)) encodeMajorType7(#float(f));
          case (#integer(i)) encodeMajorType7(#integer(i));
        }
      };
    };
  };

  public func encodeMajorType0(value: Nat64) : Result.Result<[Nat8], Types.CborEncodingError> {
    let bytes = encodeNatHeaderInternal(0, value);
    return #ok(bytes);
  };

  public func encodeMajorType1(value: Int) : Result.Result<[Nat8], Types.CborEncodingError> {
    let maxValue: Int = -1;
    let minValue: Int = -0x10000000000000000;
    if(value > maxValue or value < minValue) {
      return #err(#invalidValue("Major type 1 values must be between -2^64 and -1"));
    };
    // Convert negative number (-1 - N) to Nat (N) to store as bytes
    let natValue: Nat = Int.abs(value + 1);
    let bytes = encodeNatHeaderInternal(1, Nat64.fromNat(natValue));
    return #ok(bytes);
  };

  public func encodeMajorType2(value: [Nat8]) : Result.Result<[Nat8], Types.CborEncodingError> {
    let byteLength: Nat64 = Nat64.fromNat(value.size());
    let headerBytes: [Nat8] = encodeNatHeaderInternal(2, byteLength);
    // Value is header bits + value bytes
    // Header is major type and value byte length
    let bytes: [Nat8] = Util.concatArrays<Nat8>(headerBytes, value);
    #ok(bytes);
  };

  public func encodeMajorType3(value: Text) : Result.Result<[Nat8], Types.CborEncodingError> {
    let utf8Bytes: [Nat8] = Blob.toArray(Text.encodeUtf8(value));
    let byteLength: Nat64 = Nat64.fromNat(utf8Bytes.size());
    let headerBytes: [Nat8] = encodeNatHeaderInternal(3, byteLength);
    // Value is header bits + utf8 encoded string bytes
    // Header is major type and utf8 byte length
    let bytes: [Nat8] = Util.concatArrays<Nat8>(headerBytes, utf8Bytes);
    #ok(bytes);
  };

  public func encodeMajorType4(value: [Types.CborValue]) : Result.Result<[Nat8], Types.CborEncodingError> {
    let arrayLength: Nat64 = Nat64.fromNat(value.size());
    let headerBytes: [Nat8] = encodeNatHeaderInternal(4, arrayLength);
    // Value is header bits + concatenated encoded cbor values
    // Header is major type and array length
    let buffer = Buffer.Buffer<Nat8>(value.size() + headerBytes.size());
    Util.appendArrayToBuffer(buffer, headerBytes);
    for (v in Iter.fromArray(value)) {
      let vBytes: [Nat8] = switch(encode(v)){
        case (#err(e)) return #err(e);
        case (#ok(b)) b;
      };
      Util.appendArrayToBuffer(buffer, vBytes);
    };
    #ok(buffer.toArray());
  };

  public func encodeMajorType5(value: [(Types.CborValue, Types.CborValue)]) : Result.Result<[Nat8], Types.CborEncodingError> {
    let arrayLength: Nat64 = Nat64.fromNat(value.size());
    let headerBytes: [Nat8] = encodeNatHeaderInternal(5, arrayLength);
    // Value is header bits + concatenated encoded cbor key value map pairs
    // Header is major type and map key length
    let buffer = Buffer.Buffer<Nat8>(value.size() * 2 + headerBytes.size());
    Util.appendArrayToBuffer(buffer, headerBytes);
    for ((k, v) in Iter.fromArray(value)) {
      let kBytes: [Nat8] = switch(encode(k)){
        case (#err(e)) return #err(e);
        case (#ok(b)) b;
      };
      Util.appendArrayToBuffer(buffer, kBytes);
      let vBytes: [Nat8] = switch(encode(v)){
        case (#err(e)) return #err(e);
        case (#ok(b)) b;
      };
      Util.appendArrayToBuffer(buffer, vBytes);
    };
    #ok(buffer.toArray());
  };

  public func encodeMajorType6(tag: Nat64, value: Types.CborValue) : Result.Result<[Nat8], Types.CborEncodingError> {
    let headerBytes: [Nat8] = encodeNatHeaderInternal(6, tag);
    // Value is header bits + concatenated encoded cbor value
    // Header is major type and tag value
    let buffer = Buffer.Buffer<Nat8>(2 + headerBytes.size());
    Util.appendArrayToBuffer(buffer, headerBytes);
    let encodedValue: [Nat8] = switch(encode(value)){
      case (#err(e)) return #err(e);
      case (#ok(b)) b;
    };
    Util.appendArrayToBuffer(buffer, encodedValue);
    #ok(buffer.toArray());
  };

  public func encodeMajorType7(value: {#integer: Nat8; #bool: Bool; #_null; #_undefined; #float: FloatX.FloatX}) : Result.Result<[Nat8], Types.CborEncodingError> {
    let (additionalBits: Nat8, additionalBytes: ?[Nat8]) = switch (value) {
      case (#bool(false)) (20: Nat8, null: ?[Nat8]);
      case (#bool(true)) (21: Nat8, null: ?[Nat8]);
      case (#_null) (22: Nat8, null: ?[Nat8]);
      case (#_undefined) (23: Nat8, null: ?[Nat8]);
      case (#integer(i)) {
        if(i <= 19) {
          (i, null: ?[Nat8]);
        } else if (i <= 31) {
          // TODO not allowed???
          return #err(#invalidValue(""));
        } else {
          (24: Nat8, ?[i]: ?[Nat8]);
        };
      };
      case (#float(f)) {
        let bytes: [Nat8] = FloatX.encodeFloatX(f);
        let n: Nat8 = switch (f.precision) {
          case (#f16) 25;
          case (#f32) 26;
          case (#f64) 27;
        };
        (n, ?bytes);
      };
    };
    let bytes: [Nat8] = encodeRaw(7, additionalBits, additionalBytes);
    #ok(bytes);
  };

  private func encodeRaw(majorType: Nat8, additionalBits: Nat8, additionalBytes: ?[Nat8]) : [Nat8] {
    let firstByte: Nat8 = majorType << 5 + additionalBits;
    // Concatenate the header byte and the additional bytes (if available)
    switch(additionalBytes) {
      case (null) [firstByte];
      case (?bytes) {
        let buffer = Buffer.Buffer<Nat8>(bytes.size() + 1);
        buffer.add(firstByte);
        Util.appendArrayToBuffer(buffer, bytes);
        buffer.toArray();
      };
    }
  };

  private func encodeNatHeaderInternal(majorType: Nat8, value: Nat64) : [Nat8] {
    let (additionalBits: Nat8, additionalBytes: ?[Nat8]) = if (value <= 23) {
      (Nat8.fromNat(Nat64.toNat(value)), null);
    } else {
      if (value <= 0xff) {
        (24: Nat8, ?[Nat8.fromNat(Nat64.toNat(value))]); // 24 indicates 1 more byte of info
      } else if (value <= 0xffff) {
        (25: Nat8, ?Binary.BigEndian.fromNat16(Nat16.fromNat(Nat64.toNat(value))));// 25 indicates 2 more bytes of info
      } else if (value <= 0xffffffff) {
        (26: Nat8, ?Binary.BigEndian.fromNat32(Nat32.fromNat(Nat64.toNat(value)))); // 26 indicates 4 more byte of info
      } else {
        (27: Nat8, ?Binary.BigEndian.fromNat64(value)); // 27 indicates 8 more byte of info
      }
    };
    encodeRaw(majorType, additionalBits, additionalBytes);
  };

};


  // func cbor_tree(tree : HashTree) : Blob {
  //   let buf = Buffer.Buffer<Nat8>(100);

  //   // CBOR self-describing tag
  //   buf.add(0xD9);
  //   buf.add(0xD9);
  //   buf.add(0xF7);

  //   func add_blob(b: Blob) {
  //     // Only works for blobs with less than 256 bytes
  //     buf.add(0x58);
  //     buf.add(Nat8.fromNat(b.size()));
  //     for (c in Blob.toArray(b).vals()) {
  //       buf.add(c);
  //     };
  //   };

  //   func go(t : HashTree) {
  //     switch (t) {
  //       case (#empty)        { buf.add(0x81); buf.add(0x00); };
  //       case (#fork(t1,t2))  { buf.add(0x83); buf.add(0x01); go(t1); go (t2); };
  //       case (#labeled(l,t)) { buf.add(0x83); buf.add(0x02); add_blob(l); go (t); };
  //       case (#leaf(v))      { buf.add(0x82); buf.add(0x03); add_blob(v); };
  //       case (#pruned(h))    { buf.add(0x82); buf.add(0x04); add_blob(h); }
  //     }
  //   };

  //   go(tree);

  //   return Blob.fromArray(buf.toArray());
  // };
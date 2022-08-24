import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import FloatX "mo:xtendedNumbers/FloatX";
import Int "mo:base/Int";
import Int8 "mo:base/Int8";
import IntX "mo:xtendedNumbers/IntX";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import NatX "mo:xtendedNumbers/NatX";
import Order "mo:base/Order";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Types "./Types";

module {
  type CandidValue = Types.CandidValue;
  type CandidId = Types.CandidId;
  type CandidTag = Types.CandidTag;
  type CandidFunc = Types.CandidFunc;
  type CandidService = Types.CandidService;

  public func encode(value: CandidValue) : [Nat8] {
    let buffer = Buffer.Buffer<Nat8>(4);
    encodeToBuffer(buffer, value);
    buffer.toArray();
  };

  public func encodeToBuffer(buffer: Buffer.Buffer<Nat8>, value: CandidValue) {
    switch(value) {
      case (#int(i)) encodeInt(buffer, i);
      case (#int8(i8)) encodeInt8(buffer, i8);
      case (#int16(i16)) encodeInt16(buffer, i16);
      case (#int32(i32)) encodeInt32(buffer, i32);
      case (#int64(i64)) encodeInt64(buffer, i64);
      case (#nat(n)) encodeNat(buffer, n);
      case (#nat8(n8)) encodeNat8(buffer, n8);
      case (#nat16(n16)) encodeNat16(buffer, n16);
      case (#nat32(n32)) encodeNat32(buffer, n32);
      case (#nat64(n64)) encodeNat64(buffer, n64);
      case (#_null) encodeNull(buffer);
      case (#bool(b)) encodeBool(buffer, b);
      case (#floatX(f)) encodeFloatX(buffer, f);
      case (#text(t)) encodeText(buffer, t);
      case (#reserved) encodeReserved(buffer); // TODO allowed?
      case (#empty) encodeEmpty(buffer); // TODO allowed?
      case (#opt(o)) encodeOpt(buffer, o);
      case (#vector(v)) encodeVector(buffer, v);
      case (#record(r)) encodeRecord(buffer, r);
      case (#_func(f)) encodeFunc(buffer, f);
      case (#service(s)) encodeService(buffer, s);
      case (#principal(p)) encodePrincipal(buffer, p);
      case (#variant(v)) encodeVariant(buffer, v.tag, v.value);
    };
  };

  public func encodeInt(buffer: Buffer.Buffer<Nat8>, value: Int) {
    let _ = IntX.encodeInt(buffer, value, #signedLEB128);
  };

  public func encodeInt8(buffer: Buffer.Buffer<Nat8>, value: Int8) {
    IntX.encodeInt8(buffer, value);
  };

  public func encodeInt16(buffer: Buffer.Buffer<Nat8>, value: Int16) {
    IntX.encodeInt16(buffer, value, #lsb);
  };

  public func encodeInt32(buffer: Buffer.Buffer<Nat8>, value: Int32) {
    IntX.encodeInt32(buffer, value, #lsb);
  };

  public func encodeInt64(buffer: Buffer.Buffer<Nat8>, value: Int64) {
    IntX.encodeInt64(buffer, value, #lsb);
  };

  public func encodeNat(buffer: Buffer.Buffer<Nat8>, value: Nat) {
    let _ = NatX.encodeNat(buffer, value, #unsignedLEB128);
  };

  public func encodeNat8(buffer: Buffer.Buffer<Nat8>, value: Nat8) {
    buffer.add(value);
  };

  public func encodeNat16(buffer: Buffer.Buffer<Nat8>, value: Nat16) {
    NatX.encodeNat16(buffer, value, #lsb);
  };

  public func encodeNat32(buffer: Buffer.Buffer<Nat8>, value: Nat32) {
    NatX.encodeNat32(buffer, value, #lsb);
  };

  public func encodeNat64(buffer: Buffer.Buffer<Nat8>, value: Nat64) {
    NatX.encodeNat64(buffer, value, #lsb);
  };

  public func encodeNull(buffer: Buffer.Buffer<Nat8>) {
    // nothing to encode
  };

  public func encodeBool(buffer: Buffer.Buffer<Nat8>, value: Bool) {
    buffer.add(if (value) 0x01 else 0x00);
  };

  public func encodeFloatX(buffer: Buffer.Buffer<Nat8>, value: FloatX.FloatX) {
    if (value.precision == #f16) {
      Debug.trap("Unable to encode 16 bit floats, only 32 and 64"); // TODO allow and convert?
    };
    FloatX.encodeFloatX(buffer, value, #lsb);
  };

  public func encodeFloat32(buffer: Buffer.Buffer<Nat8>, value: Float) {
    let floatX: FloatX.FloatX = FloatX.floatToFloatX(value, #f32);
    FloatX.encodeFloatX(buffer, floatX, #lsb);
  };

  public func encodeFloat64(buffer: Buffer.Buffer<Nat8>, value: Float) {
    let floatX: FloatX.FloatX = FloatX.floatToFloatX(value, #f64);
    FloatX.encodeFloatX(buffer, floatX, #lsb);
  };

  public func encodeText(buffer: Buffer.Buffer<Nat8>, value: Text) {
    let utf8Bytes: Blob = Text.encodeUtf8(value);
    for (byte in utf8Bytes.vals()) {
      buffer.add(byte);
    };
  };

  public func encodeReserved(buffer: Buffer.Buffer<Nat8>) {
    // nothing to encode
  };

  public func encodeEmpty(buffer: Buffer.Buffer<Nat8>) {
    // nothing to encode
  };

  public func encodeOpt(buffer: Buffer.Buffer<Nat8>, value: ?CandidValue) {
    switch (value) {
      case (null) buffer.add(0x00); // Indicate there is no value
      case (?v) {
        buffer.add(0x01); // Indicate there is a value
        encodeToBuffer(buffer, v); // Encode value
      }
    }
  };

  public func encodeVector(buffer: Buffer.Buffer<Nat8>, value: [CandidValue]) {
    let _ = NatX.encodeNat(buffer, value.size(), #unsignedLEB128); // Encode the length of the vector
    for (v in Iter.fromArray(value)) {
      encodeToBuffer(buffer, v); // Encode each value
    };
  };

  public func encodeRecord(buffer: Buffer.Buffer<Nat8>, value: [{tag: CandidTag; value: CandidValue}]) {
    // Sort properties by the hash of the 
    let sortedKVs: [{tag: CandidTag; value: CandidValue}] = Array.sort<{tag: CandidTag; value: CandidValue}>(value, func (v1, v2) { Nat32.compare(v1.tag.value, v2.tag.value) });
    for (kv in Iter.fromArray(sortedKVs)) {
      encodeToBuffer(buffer, kv.value); // Encode each value in order
    };
  };

  public func encodeFunc(buffer: Buffer.Buffer<Nat8>, value: CandidFunc) {
    switch (value) {
      case (#opaque) {
        buffer.add(0); // 0 if opaque reference
      };
      case (#transparent(t)) {
        buffer.add(1); // 1 if not opaque
        encodeService(buffer, t.service); // Encode the service
        encodeText(buffer, t.method); // Encode the method
      };
    };
  };

  public func encodeService(buffer: Buffer.Buffer<Nat8>, value: CandidService) {
    switch (value) {
      case (#opaque) {
        buffer.add(0); // 0 if opaque reference
      };
      case (#transparent(principal)) {
        buffer.add(1); // 1 if not opaque
        encodePrincipal(buffer, principal); // Encode the service principal
      };
    };
  };

  public func encodePrincipal(buffer: Buffer.Buffer<Nat8>, value: Principal) {
    // TODO opaque/null principal id? where bytes returned is [0x00]
    let bytes: [Nat8] = Blob.toArray(Principal.toBlob(value));
    let _ = NatX.encodeNat(buffer, bytes.size(), #unsignedLEB128); // Encode the byte length
    for (b in Iter.fromArray(bytes)) {
      buffer.add(b); // Encode the raw principal bytes
    };
  };

  public func encodeVariant(buffer: Buffer.Buffer<Nat8>, tag: CandidTag, value: CandidValue) {
    let _ = NatX.encodeNat(buffer, Nat32.toNat(tag.value), #unsignedLEB128); // Encode tag value
    encodeToBuffer(buffer, value); // Encode value
  };
}
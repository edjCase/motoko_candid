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
import Types "./Types";

module {

  type Buffer<Nat8> = Buffer.Buffer<Nat8>;
  type CandidValue = Types.CandidValue;
  type CandidId = Types.CandidId;
  type CandidTag = Types.CandidTag;

  public func encode(value: CandidValue) : [Nat8] {
    let buffer = Buffer<Nat8>(4);
    encodeToBuffer(buffer, value);
    buffer.toArray();
  };

  public func encodeToBuffer(buffer: Buffer<Nat8>, value: CandidValue) : () {
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
      case (#null) encodeNull(buffer);
      case (#bool(b)) encodeBool(buffer, b);
      case (#float32(f32)) encodeFloat32(buffer, f32);
      case (#float64(f64)) encodeFloat64(buffer, f64);
      case (#text(t)) encodeText(buffer, t);
      case (#reserved) encodeReserved(buffer); // TODO allowed?
      case (#empty) encodeEmpty(buffer); // TODO allowed?
      case (#opt(o)) encodeOpt(buffer, o);
      case (#vector(v)) encodeVector(buffer, v);
      case (#record(r)) encodeRecord(buffer, r);
      case (#func(f)) encodeFunc(buffer, f);
      case (#service(s)) encodeService(buffer, s);
      case (#principal(p)) encodePrincipal(buffer, p);
    };
  };

  public func encodeInt(buffer: Buffer<Nat8>, value: Int) : () {
    // TODO
  };

  public func encodeInt8(buffer: Buffer<Nat8>, value: Int8) : () {
    // TODO
  };

  public func encodeInt16(buffer: Buffer<Nat8>, value: Int16) : () {
    // TODO
  };

  public func encodeInt32(buffer: Buffer<Nat8>, value: Int32) : () {
    // TODO
  };

  public func encodeInt64(buffer: Buffer<Nat8>, value: Int64) : () {
    // TODO
  };

  public func encodeNat(buffer: Buffer<Nat8>, value: Nat) : () {
    // TODO
  };

  public func encodeNat8(buffer: Buffer<Nat8>, value: Nat8) : () {
    buffer.add(value);
  };

  public func encodeNat16(buffer: Buffer<Nat8>, value: Nat16) : () {
    
  };

  public func encodeNat32(buffer: Buffer<Nat8>, value: Nat32) : () {
    // TODO
  };

  public func encodeNat64(buffer: Buffer<Nat8>, value: Nat64) : () {
    // TODO
  };

  public func encodeNull(buffer: Buffer<Nat8>) : () {
    // nothing to encode
  };

  public func encodeBool(buffer: Buffer<Nat8>, value: Bool) : () {
    // TODO
  };

  public func encodeFloat32(buffer: Buffer<Nat8>, value: Float32) : () {
    // TODO
  };

  public func encodeFloat64(buffer: Buffer<Nat8>, value: Float) : () {
    // TODO
  };

  public func encodeText(buffer: Buffer<Nat8>, value: Text) : () {
    // TODO
  };

  public func encodeReserved(buffer: Buffer<Nat8>) : () {
    // nothing to encode
  };

  public func encodeEmpty(buffer: Buffer<Nat8>) : () {
    // nothing to encode
  };

  public func encodeOpt(buffer: Buffer<Nat8>, value: ?CandidValue) : () {
    // TODO
  };

  public func encodeVector(buffer: Buffer<Nat8>, value: [CandidValue]) : () {
    // TODO
  };

  public func encodeRecord(buffer: Buffer<Nat8>, value: [(CandidId, CandidValue)]) : () {
    // TODO
  };

  public func encodeFunc(buffer: Buffer<Nat8>, value: CandidFunc) : () {
    // TODO
  };

  public func encodeService(buffer: Buffer<Nat8>, value: CandidService) : () {
    // TODO
  };

  public func encodePrincipal(buffer: Buffer<Nat8>, value: Principal) : () {
    // TODO
  };
}
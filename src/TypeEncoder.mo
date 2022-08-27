import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import CandidTypeCode "mo:base/List";
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
  type CandidType = Types.CandidType;
  type CandidTag = Types.CandidTag;
  type CandidFuncType = Types.CandidFuncType;
  type CandidServiceType = Types.CandidServiceType;

  public func encode(value : CandidType) : [Nat8] {
    let buffer = Buffer.Buffer<Nat8>(4);
    encodeToBuffer(buffer, value);
    buffer.toArray();
  };

  public func encodeToBuffer(buffer : Buffer.Buffer<Nat8>, value : CandidType) {
    switch (value) {
      case (#int) encodeInt(buffer);
      case (#int8) encodeInt8(buffer);
      case (#int16) encodeInt16(buffer);
      case (#int32) encodeInt32(buffer);
      case (#int64) encodeInt64(buffer);
      case (#nat) encodeNat(buffer);
      case (#nat8) encodeNat8(buffer);
      case (#nat16) encodeNat16(buffer);
      case (#nat32) encodeNat32(buffer);
      case (#nat64) encodeNat64(buffer);
      case (#_null) encodeNull(buffer);
      case (#bool) encodeBool(buffer);
      case (#float32) encodeFloat32(buffer);
      case (#float64) encodeFloat64(buffer);
      case (#text) encodeText(buffer);
      case (#reserved) encodeReserved(buffer);
      // TODO allowed?
      case (#empty) encodeEmpty(buffer);
      // TODO allowed?
      case (#principal) encodePrincipal(buffer);
      case (#opt(o)) encodeOpt(buffer, o);
      case (#vector(v)) encodeVector(buffer, v);
      case (#record(r)) encodeRecord(buffer, r);
      case (#_func(f)) encodeFunc(buffer, f);
      case (#service(s)) encodeService(buffer, s);
      case (#variant(v)) encodeVariant(buffer, v);
    };
  };

  public func encodeInt(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.int);
  };

  public func encodeInt8(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.int8);
  };

  public func encodeInt16(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.int16);
  };

  public func encodeInt32(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.int32);
  };

  public func encodeInt64(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.int64);
  };

  public func encodeNat(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.nat);
  };

  public func encodeNat8(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.nat8);
  };

  public func encodeNat16(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.nat16);
  };

  public func encodeNat32(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.nat32);
  };

  public func encodeNat64(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.nat64);
  };

  public func encodeNull(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode._null);
  };

  public func encodeBool(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.bool);
  };

  public func encodeFloat32(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.float32);
  };

  public func encodeFloat64(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.float64);
  };

  public func encodeText(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.text);
  };

  public func encodeReserved(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.reserved);
  };

  public func encodeEmpty(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.empty);
  };

  public func encodePrincipal(buffer : Buffer.Buffer<Nat8>) {
    encodeCandidTypeCode(buffer, Types.CandidTypeCode.principal);
  };

  public func encodeOpt(buffer : Buffer.Buffer<Nat8>, innerType : CandidType) {
    // TODO compound
  };

  public func encodeVector(buffer : Buffer.Buffer<Nat8>, innerType : CandidType) {
    // TODO compound
  };

  public func encodeRecord(
    buffer : Buffer.Buffer<Nat8>,
    fields : [{ tag : CandidTag; _type : CandidType }],
  ) {
    // TODO compound
  };

  public func encodeFunc(buffer : Buffer.Buffer<Nat8>, value : CandidFuncType) {
    // TODO compound
  };

  public func encodeService(
    buffer : Buffer.Buffer<Nat8>,
    value : CandidServiceType,
  ) {
    // TODO compound
  };

  public func encodeVariant(
    buffer : Buffer.Buffer<Nat8>,
    options : [{ tag : CandidTag; _type : CandidType }],
  ) {
    // TODO compound
  };

  private func encodeCandidTypeCode(
    buffer : Buffer.Buffer<Nat8>,
    typeCode : Int,
  ) {
    let _ = IntX.encodeInt(buffer, typeCode, #signedLEB128);
  };
};

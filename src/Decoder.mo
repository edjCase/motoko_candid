import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import FloatX "mo:xtendedNumbers/FloatX";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import IntX "mo:xtendedNumbers/IntX";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import NatX "mo:xtendedNumbers/NatX";
import Order "mo:base/Order";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";
import Types "./Types";

module {

  type Value = Types.Value;
  type TypeDef = Types.TypeDef;
  type CompoundReferenceType = Types.CompoundReferenceType;
  type Tag = Types.Tag;


  public func decode(candidBytes: Blob) : [(Value, TypeDef)] {
    switch (decodeInternal(candidBytes)) {
      case (null) Debug.trap(""); // TODO or should do result?
      case (?r) r;
    }
  };

  private func decodeInternal(candidBytes: Blob) : ?[(Value, TypeDef)] {
    do ? {
      let bytes : Iter.Iter<Nat8> = Iter.fromArray(Blob.toArray(candidBytes));
      let prefix1: Nat8 = bytes.next()!;
      let prefix2: Nat8 = bytes.next()!;
      let prefix3: Nat8 = bytes.next()!;
      let prefix4: Nat8 = bytes.next()!;

      // Check "DIDL" prefix
      if ((prefix1, prefix2, prefix3, prefix4) != (0x44, 0x49, 0x44, 0x4c)) {
        return null;
      };
      let (compoundTypes: [CompoundReferenceType], argTypes: [Int]) = decodeTypes(bytes)!;
      let types : [TypeDef] = buildTypes(compoundTypes, argTypes);
      let values: [Value] = decodeValues(bytes, types)!;
      var i = 0;
      let valueTypes = Buffer.Buffer<(Value, TypeDef)>(types.size());
      for (t in Iter.fromArray(types)) {
        let v = values[i];
        valueTypes.add((v, t));
        i += 1;
      };
      valueTypes.toArray();
    };
  };

  private func decodeValues(bytes: Iter.Iter<Nat8>, types: [TypeDef]) : ?[Value] {
    do ? {
      let valueBuffer = Buffer.Buffer<Value>(types.size());
      for (t in Iter.fromArray(types)) {
        let v = decodeValue(bytes, t)!;
        valueBuffer.add(v);
      };
      valueBuffer.toArray();
    };
  };

  private func decodeValue(bytes: Iter.Iter<Nat8>, t: TypeDef) : ?Value {
    do ? {
      switch (t) {
        case (#int) #int(IntX.decodeInt(bytes, #signedLEB128)!);
        case (#int8) #int8(IntX.decodeInt8(bytes, #lsb)!);
        case (#int16) #int16(IntX.decodeInt16(bytes, #lsb)!);
        case (#int32) #int32(IntX.decodeInt32(bytes, #lsb)!);
        case (#int64) #int64(IntX.decodeInt64(bytes, #lsb)!);
        case (#nat) #nat(NatX.decodeNat(bytes, #unsignedLEB128)!);
        case (#nat8) #nat8(NatX.decodeNat8(bytes, #lsb)!);
        case (#nat16) #nat16(NatX.decodeNat16(bytes, #lsb)!);
        case (#nat32) #nat32(NatX.decodeNat32(bytes, #lsb)!);
        case (#nat64) #nat64(NatX.decodeNat64(bytes, #lsb)!);
        case (#_null) #_null;
        case (#bool) {
          let nextByte: Nat8 = bytes.next()!;
          #bool(nextByte != 0x00);
        };
        case (#float32) {
          let fX = FloatX.decodeFloatX(bytes, #f32, #lsb)!;
          let f = FloatX.floatXToFloat(fX);
          #float32(f);
        };
        case (#float64) #float64(FloatX.decodeFloat(bytes, #lsb)!);
        case (#text) {
          let length : Nat = NatX.decodeNat(bytes, #unsignedLEB128)!;
          let textBytes: [Nat8] = takeBytes(bytes, length)!; 
          let text : Text = Text.decodeUtf8(Blob.fromArray(textBytes))!;
          #text(text);
        };
        case (#reserved) #reserved;
        case (#empty) #empty;
        case (#principal) {
          let transparentByte = bytes.next()!;
          switch (transparentByte) {
            case (0x00) #principal(#opaque);
            case (0x01) {
              let length : Nat = NatX.decodeNat(bytes, #unsignedLEB128)!;
              let principalBytes = takeBytes(bytes, length)!;
              #principal(#transparent(Principal.fromBlob(Blob.fromArray(principalBytes))));
            };
            case (_) return null;
          };
        };
        case (#opt(o)) {
          let optionalByte = bytes.next()!;
          switch (optionalByte) {
            case (0x00) #opt(null);
            case (0x01) {
              let innerType: TypeDef = switch (t) {
                case (#opt(o)) o;
                case (_) return null; // type definition doesnt match
              };
              let v = decodeValue(bytes, innerType)!;
              #opt(?v);
            };
            case (_) return null;
          };
        };
        case (#vector(v)) {
          let length : Nat = NatX.decodeNat(bytes, #unsignedLEB128)!;
          let buffer = Buffer.Buffer<Value>(length);
          let innerType: TypeDef = switch (t) {
            case (#vector(vv)) vv;
            case (_) return null; // type definition doesnt match
          };
          for (i in Iter.range(0, length - 1)) {
            let innerValue: Value = decodeValue(bytes, innerType)!;
            buffer.add(innerValue);
          };
          #vector(buffer.toArray());
        };
        case (#record(r)) {
          let innerTypes: [Types.RecordFieldType] = switch (t) {
            case (#record(vv)) Array.sort(vv, Types.tagObjCompare); // Order fields by tag
            case (_) return null; // type definition doesnt match
          };
          let buffer = Buffer.Buffer<Types.RecordFieldValue>(innerTypes.size());
          for (innerType in Iter.fromArray(innerTypes)) {
            let innerValue: Value = decodeValue(bytes, innerType._type)!;
            buffer.add({tag=innerType.tag; value=innerValue});
          };
          #record(buffer.toArray());
        };
        case (#_func(f)) {
          // TODO
          #_func(#opaque);
        };
        case (#service(s)) {
          // TODO
          #opt(null);
        };
        case (#variant(v)) {
          let innerTypes: [Types.VariantOptionType] = switch (t) {
            case (#record(vv)) Array.sort(vv, Types.tagObjCompare); // Order fields by tag
            case (_) return null; // type definition doesnt match
          };
          let optionIndex = NatX.decodeNat(bytes, #unsignedLEB128)!; // Get index of option chosen
          let innerType: Types.VariantOptionType = innerTypes[optionIndex];
          let innerValue: Value = decodeValue(bytes, innerType._type)!; // Get value of option chosen
          #variant({tag=innerType.tag; value=innerValue});
        };
      };
    };
  };

  private func takeBytes(bytes: Iter.Iter<Nat8>, length: Nat) : ?[Nat8] {
    do ? {
      let buffer = Buffer.Buffer<Nat8>(length);
      for (i in Iter.range(0, length - 1)) {
        buffer.add(bytes.next()!);
      };
      buffer.toArray();
    }
  };

  private func buildTypes(compoundTypes: [CompoundReferenceType], argTypes: [Int]) : [TypeDef] {
    [];
  };
  
  private func decodeTypes(bytes: Iter.Iter<Nat8>) : ?([CompoundReferenceType], [Int]) {
    null;
  };
};

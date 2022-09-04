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


  // TODO change ? to be result with specific error messages
  public func decode(candidBytes: Blob) : ?[(Value, TypeDef)] {
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
      let types : [TypeDef] = buildTypes(compoundTypes, argTypes)!;
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
          let t: Text = decodeText(bytes)!;
          #text(t);
        };
        case (#reserved) #reserved;
        case (#empty) #empty;
        case (#principal) {
          let p: Types.Reference<Principal> = decodeReference(bytes, decodePrincipal)!;
          #principal(p);
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
          let f = decodeReference(bytes, decodeFunc)!;
          #_func(f);
        };
        case (#service(s)) {
          let principal: Types.Reference<Principal> = decodeReference(bytes, decodePrincipal)!;
          #service(principal);
        };
        case (#variant(v)) {
          let innerTypes: [Types.VariantOptionType] = switch (t) {
            case (#variant(vv)) Array.sort(vv, Types.tagObjCompare); // Order fields by tag
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

  private func decodeFunc(bytes: Iter.Iter<Nat8>): ?Types.Func {
    do ? {
      let service = decodeReference(bytes, decodePrincipal)!;
      let methodName = decodeText(bytes)!;
      { service=service; method=methodName; }
    }
  };

  private func decodePrincipal(bytes: Iter.Iter<Nat8>) : ?Principal {
    do ? {
      let length : Nat = NatX.decodeNat(bytes, #unsignedLEB128)!;
      let principalBytes = takeBytes(bytes, length)!;
      Principal.fromBlob(Blob.fromArray(principalBytes));
    }
  };

  private func decodeReference<T>(bytes: Iter.Iter<Nat8>, innerDecode: (Iter.Iter<Nat8>) -> ?T) : ?Types.Reference<T> {
    do ? {
      let transparentByte = bytes.next()!;
      switch (transparentByte) {
        case (0x00) #opaque;
        case (0x01) {
          let v: T = innerDecode(bytes)!;
          #transparent(v);
        };
        case (_) return null;
      };
    }
  };

  private func decodeText(bytes: Iter.Iter<Nat8>) : ?Text {
    do ? {
      let length : Nat = NatX.decodeNat(bytes, #unsignedLEB128)!;
      let textBytes: [Nat8] = takeBytes(bytes, length)!; 
      Text.decodeUtf8(Blob.fromArray(textBytes))!;
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

  private func buildTypes(compoundTypes: [CompoundReferenceType], argTypes: [Int]) : ?[TypeDef] {
    do ? {
      let typeDefs = Buffer.Buffer<TypeDef>(argTypes.size());
      for (argType in Iter.fromArray(argTypes)) {
        let typeDef: TypeDef = buildType(argType, compoundTypes)!;
        typeDefs.add(typeDef);
      };
      typeDefs.toArray();
    }
  };

  private func buildType(indexOrCode: Int, compoundTypes: [CompoundReferenceType]) : ?TypeDef {
    do ? {
      switch (indexOrCode) {
        case (-1) #_null;
        case (-2) #bool;
        case (-3) #nat;
        case (-4) #int;
        case (-5) #nat8;
        case (-6) #nat16;
        case (-7) #nat32;
        case (-8) #nat64;
        case (-9) #int8;
        case (-10) #int16;
        case (-11) #int32;
        case (-12) #int64;
        case (-13) #float32;
        case (-14) #float64;
        case (-15) #text;
        case (-16) #reserved;
        case (-17) #empty;
        case (-24) #principal;
        case (i) {
          if (i < 0) {
            return null; // Invalid, all negatives are listed
          };
          // Positives are indices for compound types
          let index: Nat = Int.abs(indexOrCode);
          let refType = compoundTypes[index];
          switch (refType) {
            case (#opt(o)) {
              let inner: TypeDef = buildType(o, compoundTypes)!;
              #opt(inner);
            };
            case (#vector(ve)) {
              let inner: TypeDef = buildType(ve, compoundTypes)!;
              #vector(inner);
            };
            case (#record(r)) {
              let fields = Buffer.Buffer<Types.RecordFieldType>(r.size());
              for (fieldRefType in Iter.fromArray(r)) {
                let fieldType: TypeDef = buildType(fieldRefType._type, compoundTypes)!;
                fields.add({tag=fieldRefType.tag; _type=fieldType});
              };
              #record(fields.toArray());
            };
            case (#variant(va)) {
              let options = Buffer.Buffer<Types.VariantOptionType>(va.size());
              for (optionRefType in Iter.fromArray(va)) {
                let optionType: TypeDef = buildType(optionRefType._type, compoundTypes)!;
                options.add({tag=optionRefType.tag; _type=optionType});
              };
              #variant(options.toArray());
            };
            case (#_func(f)) {
              // TODO
              #opt(#int);
            };
            case (#service(s)) {
              // TODO
              #opt(#int);
            };
          };
        }
      }
    };
  };
  
  private func decodeTypes(bytes: Iter.Iter<Nat8>) : ?([CompoundReferenceType], [Int]) {
    do ? {
      let compoundTypeLength: Nat = NatX.decodeNat(bytes, #unsignedLEB128)!;
      let types = Buffer.Buffer<CompoundReferenceType>(compoundTypeLength);
      for (i in Iter.range(0, compoundTypeLength - 1)) {
        let t = decodeType(bytes)!;
        types.add(t);
      };
      let codeLength = NatX.decodeNat(bytes, #unsignedLEB128)!;
      let indicesOrCodes = Buffer.Buffer<Int>(codeLength);
      for (i in Iter.range(0, codeLength - 1)) {
        let indexOrCode: Types.ReferenceType = decodeReferenceType(bytes)!;
        indicesOrCodes.add(indexOrCode);
      };

      (types.toArray(), indicesOrCodes.toArray());
    }
  };

  private func decodeType(bytes: Iter.Iter<Nat8>) : ?Types.CompoundReferenceType {
    do ? {
      let typeCode: Int = decodeReferenceType(bytes)!;
      switch(typeCode) {
        // opt
        case (-18) { // TODO why cant use Types.TypeDef.opt here
          let innerRef = decodeReferenceType(bytes)!;
          #opt(innerRef);
        };
        // vector
        case (-19) {
          let innerRef = decodeReferenceType(bytes)!;
          #vector(innerRef);
        };
        // record
        case (-20) {
          let fields: [Types.RecordFieldReferenceType] = decodeTypeMulti(bytes, decodeTaggedType)!;
          #record(fields);
        };
        // variant
        case (-21) {
          let options: [Types.VariantOptionReferenceType] = decodeTypeMulti(bytes, decodeTaggedType)!;
          #variant(options);
        };
        // func
        case (-22) {
          let modes: [Types.FuncMode] = decodeTypeMulti(bytes, decodeFuncMode)!;
          let argTypes: Types.FuncReferenceArgs = decodeFuncArgs(bytes)!;
          let returnTypes: Types.FuncReferenceArgs = decodeFuncArgs(bytes)!;
          #_func({
            modes=modes;
            argTypes=argTypes;
            returnTypes=returnTypes;
          });
        };
        // service
        case (-23) {
          let methods: [(Types.Id, Types.ReferenceType)] = decodeTypeMulti(bytes, decodeMethod)!;
          #service({
            methods=methods;
          });
        };
        case (_) return null;
      };
    };
  };

  private func decodeFuncArgs(bytes: Iter.Iter<Nat8>) : ?Types.FuncReferenceArgs {
    do ? {
      let ordered = decodeTypeMulti(bytes, decodeReferenceType)!;
      // TODO what about named?
      #ordered(ordered);
    }
  };

  private func decodeFuncMode(bytes: Iter.Iter<Nat8>): ?Types.FuncMode {
    do ? {
      let modeByte = bytes.next()!;
      switch(modeByte) {
        case (0x01) #_query;
        case (0x02) #oneWay;
        case (_) return null;
      }
    }
  };

  private func decodeReferenceType(bytes: Iter.Iter<Nat8>): ?Types.ReferenceType {
    IntX.decodeInt(bytes, #signedLEB128);
  };

  private func decodeMethod(bytes: Iter.Iter<Nat8>): ?(Types.Id, Types.ReferenceType) {
    do ? {
      let methodName: Text = decodeText(bytes)!;
      let innerType: Types.ReferenceType = decodeReferenceType(bytes)!;
      (methodName, innerType);
    }
  };

  private func decodeTaggedType(bytes: Iter.Iter<Nat8>): ?{_type:Types.ReferenceType; tag:Types.Tag} {
    do ? {
      let tag = Nat32.fromNat(NatX.decodeNat(bytes, #unsignedLEB128)!);
      let innerRef = decodeReferenceType(bytes)!;
      {_type=innerRef; tag=#hash(tag)};
    }
  };

  private func decodeTypeMulti<T>(bytes: Iter.Iter<Nat8>, decodeType: (Iter.Iter<Nat8>) -> ?T): ?[T] {
    do ? {
      let optionCount = NatX.decodeNat(bytes, #unsignedLEB128)!;
      let options = Buffer.Buffer<T>(optionCount);
      for (i in Iter.range(0, optionCount - 1)) {
        let item = decodeType(bytes)!;
        options.add(item);
      };
      options.toArray();
    }
  }
};

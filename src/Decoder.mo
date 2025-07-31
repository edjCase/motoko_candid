import Array "mo:core/Array";
import Blob "mo:core/Blob";
import FloatX "mo:xtended-numbers/FloatX";
import Int "mo:core/Int";
import IntX "mo:xtended-numbers/IntX";
import Iter "mo:core/Iter";
import Nat "mo:core/Nat";
import Nat32 "mo:core/Nat32";
import NatX "mo:xtended-numbers/NatX";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Map "mo:core/Map";
import List "mo:core/List";
import Value "./Value";
import Type "./Type";
import Tag "./Tag";
import InternalTypes "./InternalTypes";
import FuncMode "./FuncMode";
import Arg "./Arg";

module {

  type ShallowCompoundType<T> = InternalTypes.ShallowCompoundType<T>;
  type Tag = Tag.Tag;
  type ReferenceType = InternalTypes.ReferenceType;

  /// Decodes Candid-encoded bytes into an array of Candid arguments.
  /// If the decoding fails at any point, it returns null.
  ///
  /// ```motoko
  /// let bytes : [Nat8] = ...;
  ///
  /// let ?args = Decoder.fromBytes(bytes) else return #err("Failed to decode Candid data");
  /// ```
  public func fromBytes(bytes : Iter.Iter<Nat8>) : ?[Arg.Arg] {
    do ? {
      let prefix1 : Nat8 = bytes.next()!;
      let prefix2 : Nat8 = bytes.next()!;
      let prefix3 : Nat8 = bytes.next()!;
      let prefix4 : Nat8 = bytes.next()!;

      // Check "DIDL" prefix
      if ((prefix1, prefix2, prefix3, prefix4) != (0x44, 0x49, 0x44, 0x4c)) {
        return null;
      };
      let (compoundTypes : [ShallowCompoundType<ReferenceType>], argTypes : [Int]) = decodeTypes(bytes)!;
      let types : [Type.Type] = buildTypes(compoundTypes, argTypes)!;
      let values : [Value.Value] = decodeValues(bytes, types)!;
      var i = 0;
      let valueTypes = List.empty<Arg.Arg>();
      for (t in Iter.fromArray(types)) {
        let v = values[i];
        List.add(valueTypes, { value = v; type_ = t });
        i += 1;
      };
      List.toArray(valueTypes);
    };
  };

  private func decodeValues(bytes : Iter.Iter<Nat8>, types : [Type.Type]) : ?[Value.Value] {
    do ? {
      let valueBuffer = List.empty<Value.Value>();
      let referencedTypes = Map.empty<Text, Type.Type>();
      for (t in Iter.fromArray(types)) {
        addReferenceTypes(t, referencedTypes);
      };
      for (t in Iter.fromArray(types)) {
        let v = decodeValue(bytes, t, referencedTypes)!;
        List.add(valueBuffer, v);
      };
      List.toArray(valueBuffer);
    };
  };

  private func addReferenceTypes(t : Type.Type, referencedTypes : Map.Map<Text, Type.Type>) {
    switch (t) {
      case (#opt(o)) {
        addReferenceTypes(o, referencedTypes);
      };
      case (#variant(options)) {
        for (option in Iter.fromArray(options)) {
          addReferenceTypes(option.type_, referencedTypes);
        };
      };
      case (#record(fields)) {
        for (field in Iter.fromArray(fields)) {
          addReferenceTypes(field.type_, referencedTypes);
        };
      };
      case (#recursiveType(rT)) {
        Map.add(referencedTypes, Text.compare, rT.id, rT.type_);
        addReferenceTypes(rT.type_, referencedTypes);
      };
      case (_) {};
    };
  };

  private func decodeValue(bytes : Iter.Iter<Nat8>, t : Type.Type, referencedTypes : Map.Map<Text, Type.Type>) : ?Value.Value {
    do ? {
      switch (t) {
        case (#int) #int(IntX.fromIntBytes(bytes, #signedLEB128)!);
        case (#int8) #int8(IntX.fromInt8Bytes(bytes, #lsb)!);
        case (#int16) #int16(IntX.fromInt16Bytes(bytes, #lsb)!);
        case (#int32) #int32(IntX.fromInt32Bytes(bytes, #lsb)!);
        case (#int64) #int64(IntX.fromInt64Bytes(bytes, #lsb)!);
        case (#nat) #nat(NatX.fromNatBytes(bytes, #unsignedLEB128)!);
        case (#nat8) #nat8(NatX.fromNat8Bytes(bytes, #lsb)!);
        case (#nat16) #nat16(NatX.fromNat16Bytes(bytes, #lsb)!);
        case (#nat32) #nat32(NatX.fromNat32Bytes(bytes, #lsb)!);
        case (#nat64) #nat64(NatX.fromNat64Bytes(bytes, #lsb)!);
        case (#null_) #null_;
        case (#bool) {
          let nextByte : Nat8 = bytes.next()!;
          #bool(nextByte != 0x00);
        };
        case (#float32) {
          let fX = FloatX.fromBytes(bytes, #f32, #lsb)!;
          let f = FloatX.toFloat(fX);
          #float32(f);
        };
        case (#float64) {
          let fX = FloatX.fromBytes(bytes, #f64, #lsb)!;
          let f = FloatX.toFloat(fX);
          #float64(f);
        };
        case (#text) {
          let t : Text = decodeText(bytes)!;
          #text(t);
        };
        case (#reserved) #reserved;
        case (#empty) #empty;
        case (#principal) {
          let p : Principal = decodeTransparencyState(bytes, decodePrincipal)!;
          #principal(p);
        };
        case (#opt(_)) {
          let optionalByte = bytes.next()!;
          switch (optionalByte) {
            case (0x00) #opt(#null_);
            case (0x01) {
              let innerType : Type.Type = switch (t) {
                case (#opt(o)) o;
                case (_) return null; // type definition doesnt match
              };
              let v = decodeValue(bytes, innerType, referencedTypes)!;
              #opt(v);
            };
            case (_) return null;
          };
        };
        case (#vector(_)) {
          let length : Nat = NatX.fromNatBytes(bytes, #unsignedLEB128)!;
          let buffer = List.empty<Value.Value>();
          let innerType : Type.Type = switch (t) {
            case (#vector(vv)) vv;
            case (_) return null; // type definition doesnt match
          };
          for (i in Nat.range(0, length)) {
            let innerValue : Value.Value = decodeValue(bytes, innerType, referencedTypes)!;
            List.add(buffer, innerValue);
          };
          #vector(List.toArray(buffer));
        };
        case (#record(_)) {
          let innerTypes : [Type.RecordFieldType] = switch (t) {
            case (#record(vv)) Array.sort(vv, InternalTypes.tagObjCompare); // Order fields by tag
            case (_) return null; // type definition doesnt match
          };
          let buffer = List.empty<Value.RecordFieldValue>();
          for (innerType in Iter.fromArray(innerTypes)) {
            let innerValue : Value.Value = decodeValue(bytes, innerType.type_, referencedTypes)!;
            List.add(buffer, { tag = innerType.tag; value = innerValue });
          };
          #record(List.toArray(buffer));
        };
        case (#func_(_)) {
          let f = decodeTransparencyState(bytes, decodeFunc)!;
          #func_(f);
        };
        case (#service(_)) {
          let principal : Principal = decodeTransparencyState(bytes, decodePrincipal)!;
          #service(principal);
        };
        case (#variant(_)) {
          let innerTypes : [Type.VariantOptionType] = switch (t) {
            case (#variant(vv)) Array.sort(vv, InternalTypes.tagObjCompare); // Order fields by tag
            case (_) return null; // type definition doesnt match
          };
          let optionIndex = NatX.fromNatBytes(bytes, #unsignedLEB128)!; // Get index of option chosen
          let innerType : Type.VariantOptionType = innerTypes[optionIndex];
          let innerValue : Value.Value = decodeValue(bytes, innerType.type_, referencedTypes)!; // Get value of option chosen
          #variant({ tag = innerType.tag; value = innerValue });
        };
        case (#recursiveType(rT)) {
          decodeValue(bytes, rT.type_, referencedTypes)!;
        };
        case (#recursiveReference(rI)) {
          let rType : Type.Type = Map.get(referencedTypes, Text.compare, rI)!;
          decodeValue(bytes, rType, referencedTypes)!;
        };
      };
    };
  };

  private func decodeFunc(bytes : Iter.Iter<Nat8>) : ?Value.Func {
    do ? {
      let service = decodeTransparencyState(bytes, decodePrincipal)!;
      let methodName = decodeText(bytes)!;
      { service = service; method = methodName };
    };
  };

  private func decodePrincipal(bytes : Iter.Iter<Nat8>) : ?Principal {
    do ? {
      let length : Nat = NatX.fromNatBytes(bytes, #unsignedLEB128)!;
      let principalBytes = takeBytes(bytes, length)!;
      Principal.fromBlob(Blob.fromArray(principalBytes));
    };
  };

  private func decodeTransparencyState<T>(bytes : Iter.Iter<Nat8>, innerDecode : (Iter.Iter<Nat8>) -> ?T) : ?T {
    do ? {
      let transparentByte = bytes.next()!;
      switch (transparentByte) {
        case (0x00) return null; // TODO opaque
        case (0x01) innerDecode(bytes)!;
        case (_) return null;
      };
    };
  };

  private func decodeText(bytes : Iter.Iter<Nat8>) : ?Text {
    do ? {
      let length : Nat = NatX.fromNatBytes(bytes, #unsignedLEB128)!;
      let textBytes : [Nat8] = takeBytes(bytes, length)!;
      Text.decodeUtf8(Blob.fromArray(textBytes))!;
    };
  };

  private func takeBytes(bytes : Iter.Iter<Nat8>, length : Nat) : ?[Nat8] {
    do ? {
      let buffer = List.empty<Nat8>();
      for (i in Nat.range(0, length)) {
        List.add(buffer, bytes.next()!);
      };
      List.toArray(buffer);
    };
  };

  private func buildTypes(compoundTypes : [ShallowCompoundType<ReferenceType>], argTypes : [Int]) : ?[Type.Type] {
    do ? {
      let types = List.empty<Type.Type>();
      for (argType in Iter.fromArray(argTypes)) {
        let t : Type.Type = buildType(argType, compoundTypes, Map.empty<Nat, (Text, Bool)>())!;
        List.add(types, t);
      };
      List.toArray(types);
    };
  };

  private func buildType(indexOrCode : Int, compoundTypes : [ShallowCompoundType<ReferenceType>], parentTypes : Map.Map<Nat, (Text, Bool)>) : ?Type.Type {
    do ? {
      switch (indexOrCode) {
        case (-1) #null_;
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
          let index : Nat = Int.abs(indexOrCode);

          // Check to see if a parent type is being referenced (cycle)
          switch (Map.get(parentTypes, Nat.compare, index)) {
            case (null) ();
            case (?recursiveId) {
              Map.add(parentTypes, Nat.compare, index, (recursiveId.0, true));
              return ?#recursiveReference(recursiveId.0); // Stop and return recursive reference
            };
          };

          let recursiveId = "μ" # Nat.toText(index);
          Map.add(parentTypes, Nat.compare, index, (recursiveId, false));
          let refType = compoundTypes[index];
          let t : Type.CompoundType = switch (refType) {
            case (#opt(o)) {
              let inner : Type.Type = buildType(o, compoundTypes, parentTypes)!;
              #opt(inner);
            };
            case (#vector(ve)) {
              let inner : Type.Type = buildType(ve, compoundTypes, parentTypes)!;
              #vector(inner);
            };
            case (#record(r)) {
              let fields = List.empty<Type.RecordFieldType>();
              for (fieldRefType in Iter.fromArray(r)) {
                let fieldType : Type.Type = buildType(fieldRefType.type_, compoundTypes, parentTypes)!;
                List.add(fields, { tag = fieldRefType.tag; type_ = fieldType });
              };
              #record(List.toArray(fields));
            };
            case (#variant(va)) {
              let options = List.empty<Type.VariantOptionType>();
              for (optionRefType in Iter.fromArray(va)) {
                let optionType : Type.Type = buildType(optionRefType.type_, compoundTypes, parentTypes)!;
                List.add(options, { tag = optionRefType.tag; type_ = optionType });
              };
              #variant(List.toArray(options));
            };
            case (#func_(f)) {
              let modes : [FuncMode.FuncMode] = f.modes;
              let map = func(a : [ReferenceType]) : ?[Type.Type] {
                do ? {
                  let newO = List.empty<Type.Type>();
                  for (item in Iter.fromArray(a)) {
                    let t : Type.Type = buildType(item, compoundTypes, parentTypes)!;
                    List.add(newO, t);
                  };
                  List.toArray(newO);
                };
              };
              let argTypes : [Type.Type] = map(f.argTypes)!;
              let returnTypes : [Type.Type] = map(f.returnTypes)!;
              #func_({
                argTypes = argTypes;
                modes = modes;
                returnTypes = returnTypes;
              });
            };
            case (#service(s)) {
              let methods = List.empty<(Text, Type.FuncType)>();
              for (method in Iter.fromArray(s.methods)) {
                let t : Type.Type = buildType(method.1, compoundTypes, parentTypes)!;
                switch (t) {
                  case (#func_(f)) {
                    List.add(methods, (method.0, f));
                  };
                  case (_) return null;
                };
              };
              #service({
                methods = List.toArray(methods);
              });
            };
          };
          let isRecursive = Map.get(parentTypes, Nat.compare, index)!.1;
          Map.remove(parentTypes, Nat.compare, index); // Remove to not affect sibling/parent types
          if (isRecursive) {
            #recursiveType({
              id = recursiveId;
              type_ = t;
            });
          } else {
            t;
          };
        };
      };
    };
  };

  private func decodeTypes(bytes : Iter.Iter<Nat8>) : ?([ShallowCompoundType<ReferenceType>], [Int]) {
    do ? {
      let compoundTypeLength : Nat = NatX.fromNatBytes(bytes, #unsignedLEB128)!;
      let types = List.empty<ShallowCompoundType<ReferenceType>>();
      for (i in Nat.range(0, compoundTypeLength)) {
        let t = decodeType(bytes)!;
        List.add(types, t);
      };
      let codeLength = NatX.fromNatBytes(bytes, #unsignedLEB128)!;
      let indicesOrCodes = List.empty<Int>();
      for (i in Nat.range(0, codeLength)) {
        let indexOrCode : Int = IntX.fromIntBytes(bytes, #signedLEB128)!;
        List.add(indicesOrCodes, indexOrCode);
      };

      (List.toArray(types), List.toArray(indicesOrCodes));
    };
  };

  private func decodeType(bytes : Iter.Iter<Nat8>) : ?InternalTypes.ShallowCompoundType<ReferenceType> {
    do ? {
      let referenceType : ReferenceType = decodeTransparencyStateType(bytes)!;
      switch (referenceType) {
        // opt
        case (-18) {
          let innerRef = decodeTransparencyStateType(bytes)!;
          #opt(innerRef);
        };
        // vector
        case (-19) {
          let innerRef = decodeTransparencyStateType(bytes)!;
          #vector(innerRef);
        };
        // record
        case (-20) {
          let fields : [InternalTypes.RecordFieldReferenceType<ReferenceType>] = decodeTypeMulti(bytes, decodeTaggedType)!;
          #record(fields);
        };
        // variant
        case (-21) {
          let options : [InternalTypes.VariantOptionReferenceType<ReferenceType>] = decodeTypeMulti(bytes, decodeTaggedType)!;
          #variant(options);
        };
        // func
        case (-22) {
          let argTypes : [ReferenceType] = decodeTypeMulti(bytes, decodeTransparencyStateType)!;
          let returnTypes : [ReferenceType] = decodeTypeMulti(bytes, decodeTransparencyStateType)!;
          let modes : [FuncMode.FuncMode] = decodeTypeMulti(bytes, decodeFuncMode)!;
          #func_({
            modes = modes;
            argTypes = argTypes;
            returnTypes = returnTypes;
          });
        };
        // service
        case (-23) {
          let methods : [(Text, ReferenceType)] = decodeTypeMulti(bytes, decodeMethod)!;
          #service({
            methods = methods;
          });
        };
        case (_) return null;
      };
    };
  };

  private func decodeFuncMode(bytes : Iter.Iter<Nat8>) : ?FuncMode.FuncMode {
    do ? {
      let modeByte = bytes.next()!;
      switch (modeByte) {
        case (0x01) #query_;
        case (0x02) #oneway;
        case (_) return null;
      };
    };
  };

  private func decodeTransparencyStateType(bytes : Iter.Iter<Nat8>) : ?Int {
    IntX.fromIntBytes(bytes, #signedLEB128);
  };

  private func decodeMethod(bytes : Iter.Iter<Nat8>) : ?(Text, ReferenceType) {
    do ? {
      let methodName : Text = decodeText(bytes)!;
      let innerType : Int = decodeTransparencyStateType(bytes)!;
      (methodName, innerType);
    };
  };

  private func decodeTaggedType(bytes : Iter.Iter<Nat8>) : ?{
    type_ : ReferenceType;
    tag : Tag.Tag;
  } {
    do ? {
      let tag = Nat32.fromNat(NatX.fromNatBytes(bytes, #unsignedLEB128)!);
      let innerRef = decodeTransparencyStateType(bytes)!;
      { type_ = innerRef; tag = #hash(tag) };
    };
  };

  private func decodeTypeMulti<T>(bytes : Iter.Iter<Nat8>, decodeType : (Iter.Iter<Nat8>) -> ?T) : ?[T] {
    do ? {
      let optionCount = NatX.fromNatBytes(bytes, #unsignedLEB128)!;
      let options = List.empty<T>();
      for (i in Nat.range(0, optionCount)) {
        let item = decodeType(bytes)!;
        List.add(options, item);
      };
      List.toArray(options);
    };
  };
};

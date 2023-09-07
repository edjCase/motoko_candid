import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import FloatX "mo:xtended-numbers/FloatX";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import IntX "mo:xtended-numbers/IntX";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import NatX "mo:xtended-numbers/NatX";
import Order "mo:base/Order";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";
import Value "./Value";
import Type "./Type";
import Tag "./Tag";
import InternalTypes "./InternalTypes";
import FuncMode "./FuncMode";
import TypeCode "./TypeCode";
import Arg "./Arg";

module {

  type Tag = Tag.Tag;
  type RecordFieldValue = Value.RecordFieldValue;
  type PrimitiveType = Type.PrimitiveType;
  type CompoundType = Type.CompoundType;
  type RecordFieldType = Type.RecordFieldType;
  type VariantOptionType = Type.VariantOptionType;
  type ReferenceType = InternalTypes.ReferenceType;
  type ShallowCompoundType<T> = InternalTypes.ShallowCompoundType<T>;
  type RecordFieldReferenceType<T> = InternalTypes.RecordFieldReferenceType<T>;
  type VariantOptionReferenceType<T> = InternalTypes.VariantOptionReferenceType<T>;

  public func encode(args : [Arg.Arg]) : Blob {
    let buffer = Buffer.Buffer<Nat8>(10);
    encodeToBuffer(buffer, args);
    Blob.fromArray(Buffer.toArray(buffer));
  };

  public func encodeToBuffer(buffer : Buffer.Buffer<Nat8>, args : [Arg.Arg]) {
    // "DIDL" prefix
    buffer.add(0x44);
    buffer.add(0x49);
    buffer.add(0x44);
    buffer.add(0x4c);

    let argTypes = Buffer.Buffer<Type.Type>(args.size());
    let argValues = Buffer.Buffer<Value.Value>(args.size());
    for (arg in Iter.fromArray(args)) {
      argTypes.add(arg.type_);
      argValues.add(arg.value);
    };

    let table : CompoundTypeTable = getTypeInfo(Buffer.toArray(argTypes));
    encodeTypes(buffer, table); // Encode compound type table + primitive types
    encodeValues(buffer, table, Buffer.toArray(argValues)); // Encode all the values for the types
  };

  type CompoundTypeTable = {
    compoundTypes : [ShallowCompoundType<ReferenceType>];
    typeCodes : [Int];
  };

  private func encodeTypes(buffer : Buffer.Buffer<Nat8>, table : CompoundTypeTable) {

    NatX.encodeNat(buffer, table.compoundTypes.size(), #unsignedLEB128); // Encode compound type count

    // Encode type table for compound types
    for (t in Iter.fromArray(table.compoundTypes)) {
      encodeType(buffer, t);
    };

    NatX.encodeNat(buffer, table.typeCodes.size(), #unsignedLEB128); // Encode type count
    for (code in Iter.fromArray(table.typeCodes)) {
      IntX.encodeInt(buffer, code, #signedLEB128); // Encode each type
    };
  };

  private func encodeType(buffer : Buffer.Buffer<Nat8>, t : ShallowCompoundType<ReferenceType>) {
    let typeCode : Int = switch (t) {
      case (#opt(o)) TypeCode.opt;
      case (#vector(v)) TypeCode.vector;
      case (#record(r)) TypeCode.record;
      case (#func_(f)) TypeCode.func_;
      case (#service(s)) TypeCode.service;
      case (#variant(v)) TypeCode.variant;
    };
    IntX.encodeInt(buffer, typeCode, #signedLEB128); // Encode compound type code
    switch (t) {
      case (#opt(o)) {
        IntX.encodeInt(buffer, o, #signedLEB128); // Encode reference index or type code
      };
      case (#vector(v)) {
        IntX.encodeInt(buffer, v, #signedLEB128); // Encode reference index or type code
      };
      case (#record(r)) {
        NatX.encodeNat(buffer, r.size(), #unsignedLEB128); // Encode field count
        for (field in Iter.fromArray(r)) {
          NatX.encodeNat(buffer, Nat32.toNat(Tag.hash(field.tag)), #unsignedLEB128); // Encode field tag
          IntX.encodeInt(buffer, field.type_, #signedLEB128); // Encode reference index or type code
        };
      };
      case (#func_(f)) {
        let argCount = f.argTypes.size();
        NatX.encodeNat(buffer, argCount, #unsignedLEB128); // Encode arg count

        for (argType in Iter.fromArray(f.argTypes)) {
          IntX.encodeInt(buffer, argType, #signedLEB128); // Encode each arg
        };

        let returnArgCount = f.returnTypes.size();
        NatX.encodeNat(buffer, returnArgCount, #unsignedLEB128); // Encode return arg count

        for (argType in Iter.fromArray(f.returnTypes)) {
          IntX.encodeInt(buffer, argType, #signedLEB128); // Encode each return arg
        };

        let modeCount = f.modes.size();
        NatX.encodeNat(buffer, modeCount, #unsignedLEB128); // Encode mode count

        for (mode in Iter.fromArray(f.modes)) {
          let value : Int = switch (mode) {
            case (#query_) 1;
            case (#oneway) 2;
          };
          IntX.encodeInt(buffer, value, #signedLEB128); // Encode each mode
        };
      };
      case (#service(s)) {
        NatX.encodeNat(buffer, s.methods.size(), #unsignedLEB128); // Encode method count

        for (method in Iter.fromArray(s.methods)) {
          encodeText(buffer, method.0); // Encode method name
          IntX.encodeInt(buffer, method.1, #signedLEB128); // Encode method type
        };
      };
      case (#variant(v)) {
        NatX.encodeNat(buffer, v.size(), #unsignedLEB128); // Encode option count
        for (option in Iter.fromArray(v)) {
          NatX.encodeNat(buffer, Nat32.toNat(Tag.hash(option.tag)), #unsignedLEB128); // Encode option tag
          IntX.encodeInt(buffer, option.type_, #signedLEB128); // Encode reference index or type code
        };
      };
    };
  };

  type ReferenceOrRecursiveType = {
    #indexOrCode : ReferenceType;
    #recursiveReference : Text;
  };
  type NonRecursiveCompoundType = {
    #opt : Type.Type;
    #vector : Type.Type;
    #record : [RecordFieldType];
    #variant : [VariantOptionType];
    #func_ : Type.FuncType;
    #service : Type.ServiceType;
  };

  private func getTypeInfo(args : [Type.Type]) : CompoundTypeTable {
    let shallowTypes = Buffer.Buffer<ShallowCompoundType<ReferenceOrRecursiveType>>(args.size());
    let recursiveTypeIndexMap = TrieMap.TrieMap<Text, Nat>(Text.equal, Text.hash);
    let uniqueTypeMap = TrieMap.TrieMap<NonRecursiveCompoundType, Nat>(Type.equal, Type.hash);

    // Build shallow args and recursive types first, then resolve all recursive references
    let shallowArgs = Buffer.Buffer<ReferenceOrRecursiveType>(args.size());
    for (arg in Iter.fromArray(args)) {
      let t = buildShallowTypes(shallowTypes, recursiveTypeIndexMap, uniqueTypeMap, arg);
      shallowArgs.add(t);
    };

    let resolvedCompoundTypes = Buffer.Buffer<ShallowCompoundType<ReferenceType>>(shallowTypes.size());
    let typeIndexOrCodeList = Buffer.Buffer<Int>(args.size());
    for (sArg in shallowArgs.vals()) {
      let indexOrCode = resolveArg(sArg, shallowTypes, recursiveTypeIndexMap, resolvedCompoundTypes);
      typeIndexOrCodeList.add(indexOrCode);
    };

    {
      compoundTypes = Buffer.toArray(resolvedCompoundTypes);
      typeCodes = Buffer.toArray(typeIndexOrCodeList);
    };
  };

  private func resolveArg(
    arg : ReferenceOrRecursiveType,
    shallowTypes : Buffer.Buffer<ShallowCompoundType<ReferenceOrRecursiveType>>,
    recursiveTypeIndexMap : TrieMap.TrieMap<Text, Nat>,
    resolvedCompoundTypes : Buffer.Buffer<ShallowCompoundType<ReferenceType>>,
  ) : Int {
    switch (arg) {
      case (#indexOrCode(i)) {
        if (i < 0) {
          return i; // Primitive
        };
        let typeIndex : Nat = Int.abs(i);
        switch (resolvedCompoundTypes.getOpt(typeIndex)) {
          case (?t) {
            // Already resolved
            return typeIndex;
          };
          case (null) {
            // Need to resolve
          };
        };
        let mapArg = func(t : ReferenceOrRecursiveType) : ReferenceType {
          resolveArg(t, shallowTypes, recursiveTypeIndexMap, resolvedCompoundTypes);
        };
        // Compound
        let t : ShallowCompoundType<ReferenceType> = switch (shallowTypes.get(typeIndex)) {
          case (#opt(o)) {
            let innerResolution = mapArg(o);
            #opt(innerResolution);
          };
          case (#vector(v)) {
            let innerResolution : Int = mapArg(v);
            #vector(innerResolution);
          };
          case (#record(r)) {
            let resolvedFields = Array.map(
              r,
              func(f : RecordFieldReferenceType<ReferenceOrRecursiveType>) : RecordFieldReferenceType<ReferenceType> {
                let innerResolution : Int = mapArg(f.type_);
                { tag = f.tag; type_ = innerResolution };
              },
            );
            #record(resolvedFields);
          };
          case (#variant(v)) {
            let resolvedOptions = Array.map(
              v,
              func(o : VariantOptionReferenceType<ReferenceOrRecursiveType>) : VariantOptionReferenceType<ReferenceType> {
                let innerResolution : Int = mapArg(o.type_);
                { tag = o.tag; type_ = innerResolution };
              },
            );
            #variant(resolvedOptions);
          };
          case (#func_(f)) {
            let argTypes = Array.map(f.argTypes, mapArg);
            let returnTypes = Array.map(f.returnTypes, mapArg);
            #func_({
              modes = f.modes;
              argTypes = argTypes;
              returnTypes = returnTypes;
            });
          };
          case (#service(s)) {
            let methods = Array.map<(Text, ReferenceOrRecursiveType), (Text, ReferenceType)>(
              s.methods,
              func(m) {
                let t = mapArg(m.1);
                (m.0, t);
              },
            );
            #service({
              methods = methods;
            });
          };
        };
        let index = resolvedCompoundTypes.size();
        resolvedCompoundTypes.insert(typeIndex, t);
        index;
      };
      case (#recursiveReference(r)) {
        switch (recursiveTypeIndexMap.get(r)) {
          case (null) Debug.trap("Unable to find named type reference '" # r # "'");
          case (?i) i;
        };
      };
    };
  };

  private func buildShallowTypes(
    buffer : Buffer.Buffer<ShallowCompoundType<ReferenceOrRecursiveType>>,
    recursiveTypes : TrieMap.TrieMap<Text, Nat>,
    uniqueTypeMap : TrieMap.TrieMap<NonRecursiveCompoundType, Nat>,
    t : Type.Type,
  ) : ReferenceOrRecursiveType {

    let compoundType : NonRecursiveCompoundType = switch (t) {
      case (#opt(o)) #opt(o);
      case (#vector(v)) #vector(v);
      case (#variant(v)) #variant(v);
      case (#record(r)) #record(r);
      case (#func_(f)) #func_(f);
      case (#service(s)) #service(s);
      case (#recursiveType(rT)) {
        let innerReferenceType = buildShallowTypes(buffer, recursiveTypes, uniqueTypeMap, rT.type_);
        switch (innerReferenceType) {
          case (#indexOrCode(i)) {
            if (i < 0) {
              Debug.trap("Recursive types can only be compound types");
            };
            recursiveTypes.put(rT.id, Int.abs(i));
            return #indexOrCode(i);
          };
          case (#recursiveReference(r)) Debug.trap("A named recursived type cannot itself be a recursive reference");
        };
      };
      case (#recursiveReference(r)) {
        return #recursiveReference(r);
      };
      // Primitives are just type codes
      case (#int) return #indexOrCode(TypeCode.int);
      case (#int8) return #indexOrCode(TypeCode.int8);
      case (#int16) return #indexOrCode(TypeCode.int16);
      case (#int32) return #indexOrCode(TypeCode.int32);
      case (#int64) return #indexOrCode(TypeCode.int64);
      case (#nat) return #indexOrCode(TypeCode.nat);
      case (#nat8) return #indexOrCode(TypeCode.nat8);
      case (#nat16) return #indexOrCode(TypeCode.nat16);
      case (#nat32) return #indexOrCode(TypeCode.nat32);
      case (#nat64) return #indexOrCode(TypeCode.nat64);
      case (#null_) return #indexOrCode(TypeCode.null_);
      case (#bool) return #indexOrCode(TypeCode.bool);
      case (#float32) return #indexOrCode(TypeCode.float32);
      case (#float64) return #indexOrCode(TypeCode.float64);
      case (#text) return #indexOrCode(TypeCode.text);
      case (#reserved) return #indexOrCode(TypeCode.reserved);
      case (#empty) return #indexOrCode(TypeCode.empty);
      case (#principal) return #indexOrCode(TypeCode.principal);
    };
    switch (uniqueTypeMap.get(compoundType)) {
      case (null) {}; // No duplicate found, continue
      case (?i) return #indexOrCode(i); // Duplicate type, return index
    };

    let rT : ShallowCompoundType<ReferenceOrRecursiveType> = switch (compoundType) {
      case (#opt(o)) {
        let innerTypeReference : ReferenceOrRecursiveType = buildShallowTypes(buffer, recursiveTypes, uniqueTypeMap, o);
        #opt(innerTypeReference);
      };
      case (#vector(v)) {
        let innerTypeReference : ReferenceOrRecursiveType = buildShallowTypes(buffer, recursiveTypes, uniqueTypeMap, v);
        #vector(innerTypeReference);
      };
      case (#record(r)) {
        let fields : [RecordFieldReferenceType<ReferenceOrRecursiveType>] = Iter.toArray(
          Iter.map<RecordFieldType, RecordFieldReferenceType<ReferenceOrRecursiveType>>(
            Iter.fromArray(r),
            func(f : RecordFieldType) : RecordFieldReferenceType<ReferenceOrRecursiveType> {
              let indexOrCode : ReferenceOrRecursiveType = buildShallowTypes(buffer, recursiveTypes, uniqueTypeMap, f.type_);
              { tag = f.tag; type_ = indexOrCode };
            },
          )
        );
        let sortedFields = Array.sort<RecordFieldReferenceType<ReferenceOrRecursiveType>>(fields, func(f1, f2) { Tag.compare(f1.tag, f2.tag) });
        #record(sortedFields);
      };
      case (#variant(v)) {
        let options : [VariantOptionReferenceType<ReferenceOrRecursiveType>] = Iter.toArray(
          Iter.map<VariantOptionType, VariantOptionReferenceType<ReferenceOrRecursiveType>>(
            Iter.fromArray(v),
            func(o : VariantOptionType) : VariantOptionReferenceType<ReferenceOrRecursiveType> {
              let indexOrCode : ReferenceOrRecursiveType = buildShallowTypes(buffer, recursiveTypes, uniqueTypeMap, o.type_);
              { tag = o.tag; type_ = indexOrCode };
            },
          )
        );
        let sortedOptions = Array.sort<RecordFieldReferenceType<ReferenceOrRecursiveType>>(options, func(o1, o2) { Tag.compare(o1.tag, o2.tag) });
        #variant(sortedOptions);
      };
      case (#func_(fn)) {
        let funcTypesToReference = func(types : [Type.Type]) : [ReferenceOrRecursiveType] {
          let refTypeBuffer = Buffer.Buffer<ReferenceOrRecursiveType>(types.size());
          for (t in Iter.fromArray(types)) {
            let refType : ReferenceOrRecursiveType = buildShallowTypes(buffer, recursiveTypes, uniqueTypeMap, t);
            refTypeBuffer.add(refType);
          };
          Buffer.toArray(refTypeBuffer);
        };
        let argTypes : [ReferenceOrRecursiveType] = funcTypesToReference(fn.argTypes);
        let returnTypes : [ReferenceOrRecursiveType] = funcTypesToReference(fn.returnTypes);
        #func_({
          modes = fn.modes;
          argTypes = argTypes;
          returnTypes = returnTypes;
        });
      };
      case (#service(s)) {
        let methods : [(Text, ReferenceOrRecursiveType)] = Array.map<(Text, Type.FuncType), (Text, ReferenceOrRecursiveType)>(
          s.methods,
          func(a : (Text, Type.FuncType)) : (Text, ReferenceOrRecursiveType) {
            let refType : ReferenceOrRecursiveType = buildShallowTypes(buffer, recursiveTypes, uniqueTypeMap, #func_(a.1));
            (a.0, refType);
          },
        );
        #service({
          methods = methods;
        });
      };
    };
    let index = buffer.size();
    uniqueTypeMap.put(compoundType, index);
    buffer.add(rT);
    #indexOrCode(index);
  };

  private func encodeValues(buffer : Buffer.Buffer<Nat8>, table : CompoundTypeTable, args : [Value.Value]) {
    var i = 0;
    for (arg in Iter.fromArray(args)) {
      encodeValue(buffer, arg, table.typeCodes[i], table.compoundTypes);
      i += 1;
    };
  };

  private func encodeValue(buffer : Buffer.Buffer<Nat8>, value : Value.Value, t : ReferenceType, types : [ShallowCompoundType<ReferenceType>]) {
    if (t < 0) {
      return switch (value) {
        case (#int(i)) IntX.encodeInt(buffer, i, #signedLEB128);
        case (#int8(i8)) IntX.encodeInt8(buffer, i8);
        case (#int16(i16)) IntX.encodeInt16(buffer, i16, #lsb);
        case (#int32(i32)) IntX.encodeInt32(buffer, i32, #lsb);
        case (#int64(i64)) IntX.encodeInt64(buffer, i64, #lsb);
        case (#nat(n)) NatX.encodeNat(buffer, n, #unsignedLEB128);
        case (#nat8(n8)) NatX.encodeNat8(buffer, n8);
        case (#nat16(n16)) NatX.encodeNat16(buffer, n16, #lsb);
        case (#nat32(n32)) NatX.encodeNat32(buffer, n32, #lsb);
        case (#nat64(n64)) NatX.encodeNat64(buffer, n64, #lsb);
        case (#null_) {}; // Nothing to encode
        case (#bool(b)) buffer.add(if (b) 0x01 else 0x00);
        case (#float32(f)) {
          let floatX : FloatX.FloatX = FloatX.fromFloat(f, #f32);
          FloatX.encode(buffer, floatX, #lsb);
        };
        case (#float64(f)) {
          let floatX : FloatX.FloatX = FloatX.fromFloat(f, #f64);
          FloatX.encode(buffer, floatX, #lsb);
        };
        case (#text(t)) {
          encodeText(buffer, t);
        };
        case (#reserved) {}; // Nothing to encode
        case (#empty) {}; // Nothing to encode
        case (#principal(p)) encodeTransparencyState<Principal>(buffer, p, encodePrincipal);
        case (_) Debug.trap("Invalid type definition. Doesn't match value");
      };
    };

    // Compound types
    let i = Int.abs(t);
    switch (value) {
      case (#opt(o)) {
        switch (o) {
          case (#null_) buffer.add(0x00); // Indicate there is no value
          case (v) {
            buffer.add(0x01); // Indicate there is a value
            let innerType : ReferenceType = switch (types[i]) {
              case (#opt(inner)) inner;
              case (_) Debug.trap("Invalid type definition. Doesn't match value");
            };
            encodeValue(buffer, v, innerType, types); // Encode value
          };
        };
      };
      case (#vector(ve)) {
        let innerType : ReferenceType = switch (types[i]) {
          case (#vector(inner)) inner;
          case (_) Debug.trap("Invalid type definition. Doesn't match value");
        };
        NatX.encodeNat(buffer, ve.size(), #unsignedLEB128); // Encode the length of the vector
        for (v in Iter.fromArray(ve)) {
          encodeValue(buffer, v, innerType, types); // Encode each value
        };
      };
      case (#record(r)) {
        let innerTypes : TrieMap.TrieMap<Tag, ReferenceType> = switch (types[i]) {
          case (#record(inner)) {
            let innerKV = Iter.fromArray(Array.map<RecordFieldReferenceType<ReferenceType>, (Tag, ReferenceType)>(inner, func(i) { (i.tag, i.type_) }));
            TrieMap.fromEntries<Tag, ReferenceType>(innerKV, Tag.equal, Tag.hash);
          };
          case (_) Debug.trap("Invalid type definition. Doesn't match value");
        };
        // Sort properties by the hash of the
        let sortedKVs : [RecordFieldValue] = Array.sort<RecordFieldValue>(r, InternalTypes.tagObjCompare);

        for (kv in Iter.fromArray(sortedKVs)) {
          let innerType = switch (innerTypes.get(kv.tag)) {
            case (?t) t;
            case (_) Debug.trap("Invalid type definition. Doesn't match value");
          };
          encodeValue(buffer, kv.value, innerType, types); // Encode each value in order
        };
      };
      case (#func_(f)) {
        encodeTransparencyState<Value.Func>(
          buffer,
          f,
          func(b, f) {
            let innerType : InternalTypes.FuncReferenceType<ReferenceType> = switch (types[i]) {
              case (#func_(inner)) inner;
              case (_) Debug.trap("Invalid type definition. Doesn't match value");
            };
            encodeValue(buffer, #principal(f.service), TypeCode.principal, types); // Encode the service
            encodeValue(buffer, #text(f.method), TypeCode.text, types); // Encode the method
          },
        );
      };
      case (#service(s)) encodeTransparencyState<Principal>(buffer, s, encodePrincipal);
      case (#variant(v)) {
        let innerTypes : [InternalTypes.VariantOptionReferenceType<ReferenceType>] = switch (types[i]) {
          case (#variant(inner)) inner;
          case (_) Debug.trap("Invalid type definition. Doesn't match value");
        };
        var typeIndex : ?Nat = firstIndexOf<InternalTypes.VariantOptionReferenceType<ReferenceType>>(innerTypes, func(t) { Tag.equal(t.tag, v.tag) });
        switch (typeIndex) {
          case (?i) {
            NatX.encodeNat(buffer, i, #unsignedLEB128); // Encode tag value
            encodeValue(buffer, v.value, innerTypes[i].type_, types); // Encode value
          };
          case (null) Debug.trap("Invalid type definition. Doesn't match value");
        };
      };
      case (_) Debug.trap("Invalid type definition. Doesn't match value");
    };
  };

  private func encodeTransparencyState<T>(
    buffer : Buffer.Buffer<Nat8>,
    r : T,
    encodeInner : (Buffer.Buffer<Nat8>, T) -> (),
  ) {
    // TODO opaque, how to handle?
    buffer.add(0x01); // 1 if transparent
    encodeInner(buffer, r);
  };

  private func encodePrincipal(buffer : Buffer.Buffer<Nat8>, p : Principal) {
    let bytes : [Nat8] = Blob.toArray(Principal.toBlob(p));
    NatX.encodeNat(buffer, bytes.size(), #unsignedLEB128); // Encode the byte length
    for (b in Iter.fromArray(bytes)) {
      buffer.add(b); // Encode the raw principal bytes
    };
  };

  private func firstIndexOf<T>(a : [T], isMatch : (T) -> Bool) : ?Nat {
    var i : Nat = 0;
    for (item in Iter.fromArray(a)) {
      if (isMatch(item)) {
        return ?i;
      };
      i += 1;
    };
    return null;
  };

  private func encodeText(buffer : Buffer.Buffer<Nat8>, t : Text) {
    let utf8Bytes : Blob = Text.encodeUtf8(t);
    NatX.encodeNat(buffer, utf8Bytes.size(), #unsignedLEB128);
    for (byte in utf8Bytes.vals()) {
      buffer.add(byte);
    };
  };
};

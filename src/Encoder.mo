import Array "mo:core@1/Array";
import Blob "mo:core@1/Blob";
import Buffer "mo:buffer@0";
import FloatX "mo:xtended-numbers@2/FloatX";
import Int "mo:core@1/Int";
import IntX "mo:xtended-numbers@2/IntX";
import Iter "mo:core@1/Iter";
import Nat "mo:core@1/Nat";
import Nat32 "mo:core@1/Nat32";
import NatX "mo:xtended-numbers@2/NatX";
import Principal "mo:core@1/Principal";
import Text "mo:core@1/Text";
import Map "mo:core@1/Map";
import Runtime "mo:core@1/Runtime";
import List "mo:core@1/List";
import Value "./Value";
import Type "./Type";
import Tag "./Tag";
import InternalTypes "./InternalTypes";
import TypeCode "./TypeCode";

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

  /// Encodes an array of Candid arguments into a byte array.
  ///
  /// This function takes an array of Candid arguments and encodes them into a binary format
  /// as specified by the Candid specification. The result is returned as a byte array.
  ///
  /// ```motoko
  /// import Candid "mo:candid";
  ///
  /// let args : [Candid.Arg] = [
  ///   { type_ = #nat; value = #nat(42) },
  ///   { type_ = #text; value = #text("Hello, Candid!") }
  /// ];
  ///
  /// let bytes : [Nat8] = Candid.toBytes(args);
  /// // bytes now contains the Candid-encoded representation of the arguments
  /// ```
  public func toBytes(args : [InternalTypes.Arg]) : [Nat8] {
    let buffer = List.empty<Nat8>();
    toBytesBuffer(Buffer.fromList(buffer), args);
    List.toArray(buffer);
  };

  /// Encodes an array of Candid arguments into a provided buffer.
  ///
  /// This function takes a mutable buffer and an array of Candid arguments, and encodes the arguments
  /// into the buffer according to the Candid specification. The buffer is modified in-place.
  ///
  /// ```motoko
  /// import Buffer "mo:buffer@0";
  /// import Candid "mo:candid";
  ///
  /// let args : [Candid.Arg] = [
  ///   { type_ = #nat; value = #nat(42) },
  ///   { type_ = #text; value = #text("Hello, Candid!") }
  /// ];
  ///
  /// let list = List.empty<Nat8>();
  /// let buffer = Buffer.fromList(list);
  /// Candid.toBytesBuffer(buffer, args);
  /// // list now contains the Candid-encoded representation of the arguments
  /// ```
  public func toBytesBuffer(buffer : Buffer.Buffer<Nat8>, args : [InternalTypes.Arg]) {
    // "DIDL" prefix
    buffer.write(0x44);
    buffer.write(0x49);
    buffer.write(0x44);
    buffer.write(0x4c);

    let argTypes = List.empty<Type.Type>();
    let argValues = List.empty<Value.Value>();
    for (arg in Iter.fromArray(args)) {
      List.add(argTypes, arg.type_);
      List.add(argValues, arg.value);
    };

    let table : CompoundTypeTable = getTypeInfo(List.toArray(argTypes));
    encodeTypes(buffer, table); // Encode compound type table + primitive types
    encodeValues(buffer, table, List.toArray(argValues)); // Encode all the values for the types
  };

  type CompoundTypeTable = {
    compoundTypes : [ShallowCompoundType<ReferenceType>];
    typeCodes : [Int];
  };

  private func encodeTypes(buffer : Buffer.Buffer<Nat8>, table : CompoundTypeTable) {

    NatX.toNatBytesBuffer(buffer, table.compoundTypes.size(), #unsignedLEB128); // Encode compound type count

    // Encode type table for compound types
    for (t in Iter.fromArray(table.compoundTypes)) {
      encodeType(buffer, t);
    };

    NatX.toNatBytesBuffer(buffer, table.typeCodes.size(), #unsignedLEB128); // Encode type count
    for (code in Iter.fromArray(table.typeCodes)) {
      IntX.toIntBytesBuffer(buffer, code, #signedLEB128); // Encode each type
    };
  };

  private func encodeType(buffer : Buffer.Buffer<Nat8>, t : ShallowCompoundType<ReferenceType>) {
    let typeCode : Int = switch (t) {
      case (#opt(_)) TypeCode.opt;
      case (#vector(_)) TypeCode.vector;
      case (#record(_)) TypeCode.record;
      case (#func_(_)) TypeCode.func_;
      case (#service(_)) TypeCode.service;
      case (#variant(_)) TypeCode.variant;
    };
    IntX.toIntBytesBuffer(buffer, typeCode, #signedLEB128); // Encode compound type code
    switch (t) {
      case (#opt(o)) {
        IntX.toIntBytesBuffer(buffer, o, #signedLEB128); // Encode reference index or type code
      };
      case (#vector(v)) {
        IntX.toIntBytesBuffer(buffer, v, #signedLEB128); // Encode reference index or type code
      };
      case (#record(r)) {
        NatX.toNatBytesBuffer(buffer, r.size(), #unsignedLEB128); // Encode field count
        for (field in Iter.fromArray(r)) {
          NatX.toNatBytesBuffer(buffer, Nat32.toNat(Tag.hash(field.tag)), #unsignedLEB128); // Encode field tag
          IntX.toIntBytesBuffer(buffer, field.type_, #signedLEB128); // Encode reference index or type code
        };
      };
      case (#func_(f)) {
        let argCount = f.argTypes.size();
        NatX.toNatBytesBuffer(buffer, argCount, #unsignedLEB128); // Encode arg count

        for (argType in Iter.fromArray(f.argTypes)) {
          IntX.toIntBytesBuffer(buffer, argType, #signedLEB128); // Encode each arg
        };

        let returnArgCount = f.returnTypes.size();
        NatX.toNatBytesBuffer(buffer, returnArgCount, #unsignedLEB128); // Encode return arg count

        for (argType in Iter.fromArray(f.returnTypes)) {
          IntX.toIntBytesBuffer(buffer, argType, #signedLEB128); // Encode each return arg
        };

        let modeCount = f.modes.size();
        NatX.toNatBytesBuffer(buffer, modeCount, #unsignedLEB128); // Encode mode count

        for (mode in Iter.fromArray(f.modes)) {
          let value : Int = switch (mode) {
            case (#query_) 1;
            case (#oneway) 2;
          };
          IntX.toIntBytesBuffer(buffer, value, #signedLEB128); // Encode each mode
        };
      };
      case (#service(s)) {
        NatX.toNatBytesBuffer(buffer, s.methods.size(), #unsignedLEB128); // Encode method count

        for (method in Iter.fromArray(s.methods)) {
          encodeText(buffer, method.0); // Encode method name
          IntX.toIntBytesBuffer(buffer, method.1, #signedLEB128); // Encode method type
        };
      };
      case (#variant(v)) {
        NatX.toNatBytesBuffer(buffer, v.size(), #unsignedLEB128); // Encode option count
        for (option in Iter.fromArray(v)) {
          NatX.toNatBytesBuffer(buffer, Nat32.toNat(Tag.hash(option.tag)), #unsignedLEB128); // Encode option tag
          IntX.toIntBytesBuffer(buffer, option.type_, #signedLEB128); // Encode reference index or type code
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
    let shallowTypes = List.empty<ShallowCompoundType<ReferenceOrRecursiveType>>();
    let recursiveTypeIndexMap = Map.empty<Text, Nat>();
    let uniqueTypeMap = Map.empty<NonRecursiveCompoundType, Nat>();

    // Build shallow args and recursive types first, then resolve all recursive references
    let shallowArgs = List.empty<ReferenceOrRecursiveType>();
    for (arg in Iter.fromArray(args)) {
      let t = buildShallowTypes(shallowTypes, recursiveTypeIndexMap, uniqueTypeMap, arg);
      List.add(shallowArgs, t);
    };

    let resolvedCompoundTypes = Map.empty<Nat, ShallowCompoundType<ReferenceType>>();
    let typeIndexOrCodeList = List.empty<Int>();
    for (sArg in List.values(shallowArgs)) {
      let indexOrCode = resolveArg(sArg, shallowTypes, recursiveTypeIndexMap, resolvedCompoundTypes);
      List.add(typeIndexOrCodeList, indexOrCode);
    };
    let compoundTypes = Array.tabulate(
      Map.size(resolvedCompoundTypes),
      func(i : Nat) : ShallowCompoundType<ReferenceType> {
        switch (Map.get(resolvedCompoundTypes, Nat.compare, i)) {
          case (?t) t;
          case (null) Runtime.trap("Unable to resolve type at index " # Nat.toText(i));
        };
      },
    );

    {
      compoundTypes = compoundTypes;
      typeCodes = List.toArray(typeIndexOrCodeList);
    };
  };

  private func resolveArg(
    arg : ReferenceOrRecursiveType,
    shallowTypes : List.List<ShallowCompoundType<ReferenceOrRecursiveType>>,
    recursiveTypeIndexMap : Map.Map<Text, Nat>,
    resolvedCompoundTypes : Map.Map<Nat, ShallowCompoundType<ReferenceType>>,
  ) : Int {
    switch (arg) {
      case (#indexOrCode(i)) {
        if (i < 0) {
          return i; // Primitive
        };
        let typeIndex : Nat = Int.abs(i);
        switch (Map.get(resolvedCompoundTypes, Nat.compare, typeIndex)) {
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
        let t : ShallowCompoundType<ReferenceType> = switch (List.at(shallowTypes, typeIndex)) {
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

        Map.add(resolvedCompoundTypes, Nat.compare, typeIndex, t);
        typeIndex;
      };
      case (#recursiveReference(r)) {
        switch (Map.get(recursiveTypeIndexMap, Text.compare, r)) {
          case (null) Runtime.trap("Unable to find named type reference '" # r # "'");
          case (?i) i;
        };
      };
    };
  };

  private func buildShallowTypes(
    buffer : List.List<ShallowCompoundType<ReferenceOrRecursiveType>>,
    recursiveTypes : Map.Map<Text, Nat>,
    uniqueTypeMap : Map.Map<NonRecursiveCompoundType, Nat>,
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
              Runtime.trap("Recursive types can only be compound types");
            };
            Map.add(recursiveTypes, Text.compare, rT.id, Int.abs(i));
            return #indexOrCode(i);
          };
          case (#recursiveReference(_)) Runtime.trap("A named recursived type cannot itself be a recursive reference");
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
    switch (Map.get(uniqueTypeMap, Type.compare, compoundType)) {
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
          let refTypeBuffer = List.empty<ReferenceOrRecursiveType>();
          for (t in Iter.fromArray(types)) {
            let refType : ReferenceOrRecursiveType = buildShallowTypes(buffer, recursiveTypes, uniqueTypeMap, t);
            List.add(refTypeBuffer, refType);
          };
          List.toArray(refTypeBuffer);
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
    let index = List.size(buffer);
    Map.add(uniqueTypeMap, Type.compare, compoundType, index);
    List.add(buffer, rT);
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
        case (#int(i)) IntX.toIntBytesBuffer(buffer, i, #signedLEB128);
        case (#int8(i8)) IntX.toInt8BytesBuffer(buffer, i8);
        case (#int16(i16)) IntX.toInt16BytesBuffer(buffer, i16, #lsb);
        case (#int32(i32)) IntX.toInt32BytesBuffer(buffer, i32, #lsb);
        case (#int64(i64)) IntX.toInt64BytesBuffer(buffer, i64, #lsb);
        case (#nat(n)) NatX.toNatBytesBuffer(buffer, n, #unsignedLEB128);
        case (#nat8(n8)) NatX.toNat8BytesBuffer(buffer, n8);
        case (#nat16(n16)) NatX.toNat16BytesBuffer(buffer, n16, #lsb);
        case (#nat32(n32)) NatX.toNat32BytesBuffer(buffer, n32, #lsb);
        case (#nat64(n64)) NatX.toNat64BytesBuffer(buffer, n64, #lsb);
        case (#null_) {}; // Nothing to encode
        case (#bool(b)) buffer.write(if (b) 0x01 else 0x00);
        case (#float32(f)) {
          let floatX : FloatX.FloatX = FloatX.fromFloat(f, #f32);
          FloatX.toBytesBuffer(buffer, floatX, #lsb);
        };
        case (#float64(f)) {
          let floatX : FloatX.FloatX = FloatX.fromFloat(f, #f64);
          FloatX.toBytesBuffer(buffer, floatX, #lsb);
        };
        case (#text(t)) {
          encodeText(buffer, t);
        };
        case (#reserved) {}; // Nothing to encode
        case (#empty) {}; // Nothing to encode
        case (#principal(p)) encodeTransparencyState<Principal>(buffer, p, encodePrincipal);
        case (_) Runtime.trap("Invalid type definition. Doesn't match value");
      };
    };

    // Compound types
    let i = Int.abs(t);
    switch (value) {
      case (#opt(o)) {
        switch (o) {
          case (#null_) buffer.write(0x00); // Indicate there is no value
          case (v) {
            buffer.write(0x01); // Indicate there is a value
            let innerType : ReferenceType = switch (types[i]) {
              case (#opt(inner)) inner;
              case (_) Runtime.trap("Invalid type definition. Doesn't match value");
            };
            encodeValue(buffer, v, innerType, types); // Encode value
          };
        };
      };
      case (#vector(ve)) {
        let innerType : ReferenceType = switch (types[i]) {
          case (#vector(inner)) inner;
          case (_) Runtime.trap("Invalid type definition. Doesn't match value");
        };
        NatX.toNatBytesBuffer(buffer, ve.size(), #unsignedLEB128); // Encode the length of the vector
        for (v in Iter.fromArray(ve)) {
          encodeValue(buffer, v, innerType, types); // Encode each value
        };
      };
      case (#record(r)) {
        let innerTypes : Map.Map<Tag, ReferenceType> = switch (types[i]) {
          case (#record(inner)) {
            let innerKV = Iter.fromArray(Array.map<RecordFieldReferenceType<ReferenceType>, (Tag, ReferenceType)>(inner, func(i) { (i.tag, i.type_) }));
            Map.fromIter<Tag, ReferenceType>(innerKV, Tag.compare);
          };
          case (_) Runtime.trap("Invalid type definition. Doesn't match value");
        };
        // Sort properties by the hash of the
        let sortedKVs : [RecordFieldValue] = Array.sort<RecordFieldValue>(r, InternalTypes.tagObjCompare);

        for (kv in Iter.fromArray(sortedKVs)) {
          let innerType = switch (Map.get(innerTypes, Tag.compare, kv.tag)) {
            case (?t) t;
            case (_) Runtime.trap("Invalid type definition. Doesn't match value");
          };
          encodeValue(buffer, kv.value, innerType, types); // Encode each value in order
        };
      };
      case (#func_(f)) {
        encodeTransparencyState<Value.Func>(
          buffer,
          f,
          func(b, f) {
            let _ : InternalTypes.FuncReferenceType<ReferenceType> = switch (types[i]) {
              case (#func_(inner)) inner;
              case (_) Runtime.trap("Invalid type definition. Doesn't match value");
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
          case (_) Runtime.trap("Invalid type definition. Doesn't match value");
        };
        var typeIndex : ?Nat = firstIndexOf<InternalTypes.VariantOptionReferenceType<ReferenceType>>(innerTypes, func(t) { Tag.equal(t.tag, v.tag) });
        switch (typeIndex) {
          case (?i) {
            NatX.toNatBytesBuffer(buffer, i, #unsignedLEB128); // Encode tag value
            encodeValue(buffer, v.value, innerTypes[i].type_, types); // Encode value
          };
          case (null) Runtime.trap("Invalid type definition. Doesn't match value");
        };
      };
      case (_) Runtime.trap("Invalid type definition. Doesn't match value");
    };
  };

  private func encodeTransparencyState<T>(
    buffer : Buffer.Buffer<Nat8>,
    r : T,
    encodeInner : (Buffer.Buffer<Nat8>, T) -> (),
  ) {
    // TODO opaque, how to handle?
    buffer.write(0x01); // 1 if transparent
    encodeInner(buffer, r);
  };

  private func encodePrincipal(buffer : Buffer.Buffer<Nat8>, p : Principal) {
    let bytes : [Nat8] = Blob.toArray(Principal.toBlob(p));
    NatX.toNatBytesBuffer(buffer, bytes.size(), #unsignedLEB128); // Encode the byte length
    for (b in Iter.fromArray(bytes)) {
      buffer.write(b); // Encode the raw principal bytes
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
    NatX.toNatBytesBuffer(buffer, utf8Bytes.size(), #unsignedLEB128);
    for (byte in utf8Bytes.vals()) {
      buffer.write(byte);
    };
  };
};

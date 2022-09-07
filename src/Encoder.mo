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

  type Id = Types.Id;
  type Tag = Types.Tag;
  type TypeDef = Types.TypeDef;
  type Value = Types.Value;
  type RecordFieldValue = Types.RecordFieldValue;
  type PrimitiveType = Types.PrimitiveType;
  type CompoundType = Types.CompoundType;
  type RecordFieldType = Types.RecordFieldType;
  type VariantOptionType = Types.VariantOptionType;
  type ReferenceType = Types.ReferenceType;
  type ShallowCompoundType<T> = Types.ShallowCompoundType<T>;
  type RecordFieldReferenceType<T> = Types.RecordFieldReferenceType<T>;
  type VariantOptionReferenceType<T> = Types.VariantOptionReferenceType<T>;


  public func encode(argTypes: [TypeDef], args : [Value]) : Blob {
    let buffer = Buffer.Buffer<Nat8>(10);
    encodeToBuffer(buffer, argTypes, args);
    Blob.fromArray(buffer.toArray());
  };

  public func encodeToBuffer(buffer : Buffer.Buffer<Nat8>, argTypes: [TypeDef], args : [Value]) {
    // "DIDL" prefix
    buffer.add(0x44);
    buffer.add(0x49);
    buffer.add(0x44);
    buffer.add(0x4c);

    encodeTypes(buffer, argTypes); // Encode compound type table + primitive types
    encodeValues(buffer, argTypes, args); // Encode all the values for the types
  };

  type CompoundTypeTable = {
    compoundTypes : [ShallowCompoundType<ReferenceType>];
    typeCodes : [Int]
  };

  private func encodeTypes(buffer : Buffer.Buffer<Nat8>, args : [TypeDef]) {
    let info : CompoundTypeTable = getTypeInfo(args);

    NatX.encodeNat(buffer, info.compoundTypes.size(), #unsignedLEB128); // Encode compound type count

    // Encode type table for compound types
    for (t in Iter.fromArray(info.compoundTypes)) {
      encodeType(buffer, t);
    };

    IntX.encodeInt(buffer, info.typeCodes.size(), #signedLEB128); // Encode type count // TODO validate this is a SIGNED leb128, not unsigned
    for (code in Iter.fromArray(info.typeCodes)) {
      IntX.encodeInt(buffer, code, #signedLEB128); // Encode each type
    };
  };

  private func encodeType(buffer : Buffer.Buffer<Nat8>, t : ShallowCompoundType<ReferenceType>) {
    let typeCode : Int = switch(t){
      case (#opt(o)) Types.TypeDefCode.opt;
      case (#vector(v)) Types.TypeDefCode.vector;
      case (#record(r)) Types.TypeDefCode.record;
      case (#_func(f)) Types.TypeDefCode._func;
      case (#service(s)) Types.TypeDefCode.service;
      case (#variant(v)) Types.TypeDefCode.variant;
    };
    IntX.encodeInt(buffer, typeCode, #signedLEB128);
    // Encode compound type code
    switch (t) {
      case (#opt(o)) {
        IntX.encodeInt(buffer, o, #signedLEB128); // Encode reference index or type code
      };
      case (#vector(v)) {
        IntX.encodeInt(buffer, v, #signedLEB128); // Encode reference index or type code
      };
      case (#record(r)) {
        IntX.encodeInt(buffer, r.size(), #signedLEB128); // Encode field count // TODO validate should be signed
        for (field in Iter.fromArray(r)) {
          NatX.encodeNat(buffer, Nat32.toNat(Types.getTagHash(field.tag)), #unsignedLEB128); // Encode field tag
          IntX.encodeInt(buffer, field._type, #signedLEB128); // Encode reference index or type code
        };
      };
      case (#_func(f)) {
        let getSize = func (a: Types.FuncReferenceArgs<ReferenceType>): Nat {
          switch(a) {
            case (#ordered(o)) o.size();
            case (#named(n)) n.size(); 
          }
        };
        let getOrderedTypes = func (a: Types.FuncReferenceArgs<ReferenceType>): [ReferenceType] {
          switch(f.argTypes) {
            case (#ordered(o)) o;
            case (#named(n)) {
              // TODO are they in order?
              Array.map<(Id, ReferenceType), ReferenceType>(n, func(kv) {kv.1});
            };
          }
        };
        let argCount = getSize(f.argTypes);
        NatX.encodeNat(buffer, argCount, #unsignedLEB128); // Encode arg count

        let orderedArgTypes = getOrderedTypes(f.argTypes);
        for (argType in Iter.fromArray(orderedArgTypes)) {
          IntX.encodeInt(buffer, argType, #signedLEB128); // Encode each arg
        };

        let returnArgCount = getSize(f.returnTypes);
        NatX.encodeNat(buffer, returnArgCount, #unsignedLEB128); // Encode return arg count

        let orderedReturnTypes = getOrderedTypes(f.returnTypes);
        for (argType in Iter.fromArray(orderedReturnTypes)) {
          IntX.encodeInt(buffer, argType, #signedLEB128); // Encode each return arg
        };

        let modeCount = f.modes.size();
        NatX.encodeNat(buffer, modeCount, #unsignedLEB128); // Encode mode count

        for (mode in Iter.fromArray(f.modes)) {
          let value: Int = switch(mode) {
            case (#_query) 1;
            case (#oneWay) 2; 
          };
          IntX.encodeInt(buffer, value, #signedLEB128); // Encode each mode
        };
      };
      case (#service(s)) {
        NatX.encodeNat(buffer, s.methods.size(), #unsignedLEB128); // Encode method count

        for (method in Iter.fromArray(s.methods)) {
          encodeText(buffer, method.0); // Encode method name
          IntX.encodeInt(buffer, method.1, #signedLEB128); // Encode method type
        }
      };
      case (#variant(v)) {
        IntX.encodeInt(buffer, v.size(), #signedLEB128); // Encode option count // TODO validate should be signed
        for (option in Iter.fromArray(v)) {
          NatX.encodeNat(buffer, Nat32.toNat(Types.getTagHash(option.tag)), #unsignedLEB128); // Encode option tag
          IntX.encodeInt(buffer, option._type, #signedLEB128); // Encode reference index or type code
        };
      };
    };
  };

  type ReferenceOrRecursiveType = {
    #indexOrCode: ReferenceType;
    #recursiveReference: Text;
  };
  
  private func getTypeInfo(args : [TypeDef]) : CompoundTypeTable {
    let shallowTypes = Buffer.Buffer<ShallowCompoundType<ReferenceOrRecursiveType>>(args.size());
    let recursiveTypeIndexMap = TrieMap.TrieMap<Text, Nat>(Text.equal, Text.hash);

    // Build shallow args and recursive types first, then resolve all recursive references
    let shallowArgs = Buffer.Buffer<ReferenceOrRecursiveType>(args.size());
    for (arg in Iter.fromArray(args)) {
      let t = buildShallowTypes(shallowTypes, recursiveTypeIndexMap, arg);
      shallowArgs.add(t);
    };
    // TODO remove duplicate compound types
    let shallowTypesArray: [ShallowCompoundType<ReferenceOrRecursiveType>]  = shallowTypes.toArray();
    let resolvedCompoundTypes = Buffer.Buffer<ShallowCompoundType<ReferenceType>>(args.size());
    let typeIndexOrCodeList = Buffer.Buffer<Int>(args.size());
    for (sArg in Iter.fromArray(shallowArgs.toArray())) {
      let indexOrCode = resolveArg(sArg, shallowTypesArray, recursiveTypeIndexMap, resolvedCompoundTypes);
      typeIndexOrCodeList.add(indexOrCode);
    };

    var table = TrieMap.TrieMap<ShallowCompoundType<ReferenceType>, Nat>(typesAreEqual, buildTypeHash);
    let codes = Buffer.Buffer<Int>(args.size());
    
    type TypeInfo = (ShallowCompoundType<ReferenceType>, Nat);
    let sortedTable : [TypeInfo] = Array.sort<TypeInfo>(
      Iter.toArray(table.entries()),
      func(t1 : TypeInfo, t2 : TypeInfo) { Nat.compare(t1.1, t2.1) },
    );
    let compoundTypes : [ShallowCompoundType<ReferenceType>] = Iter.toArray(
      Iter.map<TypeInfo, ShallowCompoundType<ReferenceType>>(
        Iter.fromArray(sortedTable),
        func(kv : TypeInfo) { kv.0 },
      ),
    );
    {
      compoundTypes = compoundTypes;
      typeCodes = codes.toArray();
    };
  };

  // TODO Deduplicate this and `buildShallowArgs`
  private func resolveArg(
    arg: ReferenceOrRecursiveType,
    shallowTypeArray: [ShallowCompoundType<ReferenceOrRecursiveType>],
    recursiveTypeIndexMap: TrieMap.TrieMap<Text, Nat>,
    resolvedCompoundTypes: Buffer.Buffer<ShallowCompoundType<ReferenceType>>) : Int {
      switch (arg) {
        case (#indexOrCode(i)) {
          if (i < 0) {
            return i; // Primitive
          };
          let mapArg = func (t: ReferenceOrRecursiveType) : ReferenceType {
            resolveArg(t, shallowTypeArray, recursiveTypeIndexMap, resolvedCompoundTypes);
          };
          // Compound
          let t: ShallowCompoundType<ReferenceType> = switch (shallowTypeArray[Int.abs(i)]) {
            case (#opt(o)) {
              let innerResolution = mapArg(o);
              #opt(innerResolution);
            };
            case (#vector(v)) {
              let innerResolution: Int = mapArg(v);
              #opt(innerResolution);
            };
            case (#record(r)) {
              let resolvedFields = Array.map(r, func(f: RecordFieldReferenceType<ReferenceOrRecursiveType>): RecordFieldReferenceType<ReferenceType> {
                let innerResolution: Int = mapArg(f._type);
                { tag=f.tag; _type=innerResolution }
              });
              #record(resolvedFields);
            };
            case (#variant(v)) {
              let resolvedOptions = Array.map(v, func(o: VariantOptionReferenceType<ReferenceOrRecursiveType>): VariantOptionReferenceType<ReferenceType> {
                let innerResolution: Int = mapArg(o._type);
                { tag=o.tag; _type=innerResolution }
              });
              #variant(resolvedOptions);
            };
            case (#_func(f)) {
              let map = func(t: Types.FuncReferenceArgs<ReferenceOrRecursiveType>): Types.FuncReferenceArgs<ReferenceType> {
                switch (t) {
                  case (#ordered(o)) {
                    #ordered(Array.map(o, mapArg));
                  };
                  case (#named(n)) {
                    #named(Array.map<(Id, ReferenceOrRecursiveType), (Id, ReferenceType)>(n, func (a) {
                      let t: ReferenceType = mapArg(a.1);
                      (a.0, t);
                    }))
                  };
                }
              };
              let argTypes = map(f.argTypes);
              let returnTypes = map(f.returnTypes);
              #_func({
                modes=f.modes;
                argTypes=argTypes;
                returnTypes=returnTypes;
              });
            };
            case (#service(s)) {
              let methods = Array.map<(Id, ReferenceOrRecursiveType), (Id, ReferenceType)>(s.methods, func (m) {
                let t = mapArg(m.1);
                (m.0, t);
              });
              #service({
                methods=methods;
              });
            };
          };
          let index = resolvedCompoundTypes.size();
          resolvedCompoundTypes.add(t);
          index;
        };
        case (#recursiveReference(r)) {
          switch(recursiveTypeIndexMap.get(r)) {
            case (null) Debug.trap("Unable to find named type reference '" # r # "'");
            case (?i) i; 
          };
        };
      }
  };

  private func buildShallowTypes(buffer: Buffer.Buffer<ShallowCompoundType<ReferenceOrRecursiveType>>, recursiveTypes: TrieMap.TrieMap<Text, Nat>, t: TypeDef) : ReferenceOrRecursiveType {
    let rT: ShallowCompoundType<ReferenceOrRecursiveType> = switch (t) {
      case (#opt(o)) {
        let innerTypeReference: ReferenceOrRecursiveType = buildShallowTypes(buffer, recursiveTypes, o);
        #opt(innerTypeReference);
      };
      case (#vector(v)) {
        let innerTypeReference: ReferenceOrRecursiveType = buildShallowTypes(buffer, recursiveTypes, v);
        #vector(innerTypeReference);
      };
      case (#record(r)) {
        let fields : [RecordFieldReferenceType<ReferenceOrRecursiveType>] = Iter.toArray(Iter.map<RecordFieldType, RecordFieldReferenceType<ReferenceOrRecursiveType>>(Iter.fromArray(r), func (f: RecordFieldType) : RecordFieldReferenceType<ReferenceOrRecursiveType> {
          let indexOrCode : ReferenceOrRecursiveType = buildShallowTypes(buffer, recursiveTypes, f._type);
          { tag = f.tag; _type = indexOrCode };
        }));
        #record(fields);
      };
      case (#variant(v)) {
        let options : [VariantOptionReferenceType<ReferenceOrRecursiveType>] = Iter.toArray(Iter.map<VariantOptionType, VariantOptionReferenceType<ReferenceOrRecursiveType>>(Iter.fromArray(v), func (o: VariantOptionType) : VariantOptionReferenceType<ReferenceOrRecursiveType> {
          let indexOrCode : ReferenceOrRecursiveType = buildShallowTypes(buffer, recursiveTypes, o._type);
          { tag = o.tag; _type = indexOrCode };
        }));
        #variant(options);
      };
      case (#_func(fn)) {
        let funcTypesToReference = func (t : Types.FuncArgs) : Types.FuncReferenceArgs<ReferenceOrRecursiveType> {
          switch(t){
            case (#named(namedTypes)) {
              let refTypeBuffer = Buffer.Buffer<(Id, ReferenceOrRecursiveType)>(namedTypes.size());
              for (t in Iter.fromArray(namedTypes)) {
                let refType : ReferenceOrRecursiveType = buildShallowTypes(buffer, recursiveTypes, t.1);
                refTypeBuffer.add((t.0, refType));
              };
              #named(refTypeBuffer.toArray());
            };
            case (#ordered(orderdTypes)) {
              let refTypeBuffer = Buffer.Buffer<ReferenceOrRecursiveType>(orderdTypes.size());
              for (t in Iter.fromArray(orderdTypes)) {
                let refType : ReferenceOrRecursiveType = buildShallowTypes(buffer, recursiveTypes, t);
                refTypeBuffer.add(refType);
              };
              #ordered(refTypeBuffer.toArray());
            };
          };
        };
        let argTypes : Types.FuncReferenceArgs<ReferenceOrRecursiveType> = funcTypesToReference(fn.argTypes);
        let returnTypes : Types.FuncReferenceArgs<ReferenceOrRecursiveType> = funcTypesToReference(fn.returnTypes);
        #_func({
          modes=fn.modes;
          argTypes=argTypes;
          returnTypes=returnTypes;
        });
      };
      case (#service(s)) {
        let methods : [(Id, ReferenceOrRecursiveType)] = Array.map<(Id, Types.FuncType), (Id, ReferenceOrRecursiveType)>(s.methods, func (a: (Id, Types.FuncType)) : (Id, ReferenceOrRecursiveType) {
          let refType : ReferenceOrRecursiveType = buildShallowTypes(buffer, recursiveTypes, #_func(a.1));
          (a.0, refType);
        });
        #service({
          methods=methods;
        });
      };
      case (#recursiveType(rT)) {
        let innerReferenceType = buildShallowTypes(buffer, recursiveTypes, rT._type);
        switch (innerReferenceType){
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
      case (#int) return #indexOrCode(Types.TypeDefCode.int);
      case (#int8) return #indexOrCode(Types.TypeDefCode.int8);
      case (#int16) return #indexOrCode(Types.TypeDefCode.int16);
      case (#int32) return #indexOrCode(Types.TypeDefCode.int32);
      case (#int64) return #indexOrCode(Types.TypeDefCode.int64);
      case (#nat) return #indexOrCode(Types.TypeDefCode.nat);
      case (#nat8) return #indexOrCode(Types.TypeDefCode.nat8);
      case (#nat16) return #indexOrCode(Types.TypeDefCode.nat16);
      case (#nat32) return #indexOrCode(Types.TypeDefCode.nat32);
      case (#nat64) return #indexOrCode(Types.TypeDefCode.nat64);
      case (#_null) return #indexOrCode(Types.TypeDefCode._null);
      case (#bool) return #indexOrCode(Types.TypeDefCode.bool);
      case (#float32) return #indexOrCode(Types.TypeDefCode.float32);
      case (#float64) return #indexOrCode(Types.TypeDefCode.float64);
      case (#text) return #indexOrCode(Types.TypeDefCode.text);
      case (#reserved) return #indexOrCode(Types.TypeDefCode.reserved);
      case (#empty) return #indexOrCode(Types.TypeDefCode.empty);
      case (#principal) return #indexOrCode(Types.TypeDefCode.principal);
    };
    buffer.add(rT);
    #indexOrCode(buffer.size());
  };

  private func typesAreEqual(t1 : ShallowCompoundType<ReferenceType>, t2 : ShallowCompoundType<ReferenceType>) : Bool {
    return t1 == t2;
  };

  private func buildTypeHash(t : ShallowCompoundType<ReferenceType>) : Hash.Hash {
    switch (t) {
      case (#opt(o)) {
        let h = Int.hash(Types.TypeDefCode.opt);
        let innerHash = Int.hash(o);
        combineHash(h, innerHash);
      };
      case (#vector(v)) {
        let h = Int.hash(Types.TypeDefCode.vector);
        let innerHash = Int.hash(v);
        combineHash(h, innerHash);
      };
      case (#record(r)) {
        let h = Int.hash(Types.TypeDefCode.record);
        Array.foldLeft<RecordFieldReferenceType<ReferenceType>, Hash.Hash>(r, h, func (v: Hash.Hash, f: RecordFieldReferenceType<ReferenceType>) : Hash.Hash {
          let innerHash = Int.hash(f._type);
          combineHash(combineHash(v, Types.getTagHash(f.tag)), innerHash);
        });
      };
      case (#_func(f)) {
        let h = Int.hash(Types.TypeDefCode._func);
        // TODO
      };
      case (#service(s)) {
        let h = Int.hash(Types.TypeDefCode.service);
        // TODO 
        1;
      };
      case (#variant(v)) {
        var h = Int.hash(Types.TypeDefCode.variant);
        Array.foldLeft<VariantOptionReferenceType<ReferenceType>, Hash.Hash>(v, 0, func (h: Hash.Hash, f: VariantOptionReferenceType<ReferenceType>) : Hash.Hash {
          let innerHash = Int.hash(f._type);
          combineHash(combineHash(h, Types.getTagHash(f.tag)), innerHash);
        });
      };
      case (#recursiveReference(r)) {
        var h = Int.hash(0);
        combineHash(h, Text.hash(r));
      };
    };
  };

  private func combineHash(seed: Hash.Hash, value: Hash.Hash) : Hash.Hash {
    // From `C++ Boost Hash Combine`
    seed ^ (value +% 0x9e3779b9 +% (seed << 6) +% (seed >> 2));
  };

  private func encodeValues(buffer : Buffer.Buffer<Nat8>, argTypes: [TypeDef], args : [Value]) {
    var i = 0;
    for (arg in Iter.fromArray(args)) {
      let t = argTypes[i];
      i += 1;
      encodeValue(buffer, arg, t);
    };
  };

  private func encodeValue(buffer : Buffer.Buffer<Nat8>, value : Value, t : TypeDef) {
    switch (value) {
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
      case (#_null) {}; // Nothing to encode
      case (#bool(b)) buffer.add(if (b) 0x01 else 0x00);
      case (#float32(f)) {
        let floatX : FloatX.FloatX = FloatX.floatToFloatX(f, #f32);
        FloatX.encodeFloatX(buffer, floatX, #lsb);
      };
      case (#float64(f)) {
        let floatX : FloatX.FloatX = FloatX.floatToFloatX(f, #f64);
        FloatX.encodeFloatX(buffer, floatX, #lsb);
      };
      case (#text(t)) {
        encodeText(buffer, t);
      };
      case (#reserved) {}; // Nothing to encode   TODO allowed?
      case (#empty) {}; // Nothing to encode   TODO allowed?
      case (#principal(p)) {
        switch (p) {
          case (#opaque) {
            buffer.add(0x00); // 0 if opaque
          };
          case (#transparent(pr)) {
            buffer.add(0x01); // 1 if transparent
            let bytes : [Nat8] = Blob.toArray(Principal.toBlob(pr));
            NatX.encodeNat(buffer, bytes.size(), #unsignedLEB128); // Encode the byte length
            for (b in Iter.fromArray(bytes)) {
              buffer.add(b); // Encode the raw principal bytes
            };
          }
        }
      };
      case (#opt(o)) {
        switch (o) {
          case (null) buffer.add(0x00); // Indicate there is no value
          case (?v) {
            buffer.add(0x01); // Indicate there is a value
            let innerType : TypeDef = switch(t) {
              case (#opt(inner)) inner;
              case (_) Debug.trap("Invalid type definition. Doesn't match value");
            };
            encodeValue(buffer, v, innerType); // Encode value
          };
        };
      };
      case (#vector(ve)) {
        let innerType : TypeDef = switch(t) {
          case (#vector(inner)) inner;
              case (_) Debug.trap("Invalid type definition. Doesn't match value");
        };
        NatX.encodeNat(buffer, ve.size(), #unsignedLEB128); // Encode the length of the vector
        for (v in Iter.fromArray(ve)) {
          encodeValue(buffer, v, innerType); // Encode each value
        };
      };
      case (#record(r)) {
        let innerTypes : TrieMap.TrieMap<Tag, TypeDef> = switch(t) {
          case (#record(inner)) {
            let innerKV = Iter.fromArray(Array.map<RecordFieldType, (Tag, TypeDef)>(inner, func(i: RecordFieldType) : (Tag, TypeDef) { (i.tag, i._type) }));
            TrieMap.fromEntries<Tag, TypeDef>(innerKV, Types.tagsAreEqual, Types.getTagHash);
          };
          case (_) Debug.trap("Invalid type definition. Doesn't match value");
        };
        // Sort properties by the hash of the
        let sortedKVs : [RecordFieldValue] = Array.sort<RecordFieldValue>(r, Types.tagObjCompare);
        
        for (kv in Iter.fromArray(sortedKVs)) {
          let innerType = switch(innerTypes.get(kv.tag)) {
            case (?t) t;
            case (_) Debug.trap("Invalid type definition. Doesn't match value");
          };
          encodeValue(buffer, kv.value, innerType); // Encode each value in order
        };
      };
      case (#_func(f)) {
        switch (f) {
          case (#opaque) {
            buffer.add(0);
            // 0 if opaque reference
          };
          case (#transparent(tr)) {
            buffer.add(1); // 1 if not opaque

            // TODO
            // let _type : Types.FuncType = switch(t) {
            //   case (#_func(inner)) inner;
            //   case (_) Debug.trap(""); // TODO
            // };
            // encodeValue(buffer, #service(tr.service), _type.service); // Encode the service
            // encodeValue(buffer, #text(tr.method), ); // Encode the method
          };
        };
      };
      case (#service(s)) {
        switch (s) {
          case (#opaque) {
            buffer.add(0); // 0 if opaque reference
          };
          case (#transparent(principal)) {
            buffer.add(1); // 1 if not opaque
            encodeValue(buffer, #principal(#transparent(principal)), #principal); // Encode the service principal
          };
        };
      };
      case (#variant(v)) {
        let innerTypes : [VariantOptionType] = switch(t) {
          case (#variant(inner)) inner;
          case (_) Debug.trap("Invalid type definition. Doesn't match value");
        };
        var typeIndex : ?Nat = firstIndexOf<VariantOptionType>(innerTypes, func (t) { Types.tagsAreEqual(t.tag, v.tag) });
        switch(typeIndex) {
          case (?i) {
            NatX.encodeNat(buffer, i, #unsignedLEB128); // Encode tag value
            encodeValue(buffer, v.value, innerTypes[i]._type); // Encode value
          };
          case (null) Debug.trap("Invalid type definition. Doesn't match value");
        };
      };
    };
  };

  private func firstIndexOf<T>(a : [T], isMatch: (T) -> Bool) : ?Nat {
    var i : Nat = 0;
    for (item in Iter.fromArray(a)){
      if (isMatch(item)) {
        return ?i;
      };
      i += 1;
    };
    return null;
  };

  private func encodeText(buffer: Buffer.Buffer<Nat8>, t: Text) {
    let utf8Bytes : Blob = Text.encodeUtf8(t);
    NatX.encodeNat(buffer, utf8Bytes.size(), #unsignedLEB128);
    for (byte in utf8Bytes.vals()) {
      buffer.add(byte);
    };
  }
};

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
  type CompoundReferenceType = Types.CompoundReferenceType;
  type RecordFieldReferenceType = Types.RecordFieldReferenceType;
  type VariantOptionReferenceType = Types.VariantOptionReferenceType;


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
    compoundTypes : [CompoundReferenceType];
    typeCodes : [Int]
  };

  private func encodeTypes(buffer : Buffer.Buffer<Nat8>, args : [TypeDef]) {
    let info : CompoundTypeTable = getTypeInfo(args);

    NatX.encodeNat(buffer, info.compoundTypes.size(), #unsignedLEB128); // Encode compound type count

    // Encode type table for compound types
    for (t in Iter.fromArray(info.compoundTypes)) {
      encodeType(buffer, t);
    };

    IntX.encodeInt(buffer, info.typeCodes.size(), #signedLEB128);
    // Encode type count // TODO validate this is a SIGNED leb128, not unsigned
    for (code in Iter.fromArray(info.typeCodes)) {
      IntX.encodeInt(buffer, code, #signedLEB128); // Encode each type
    };
  };

  private func getTypeCode(t : TypeDef) : Int {
    switch (t) {
      case (#int) Types.TypeDefCode.int;
      case (#int8) Types.TypeDefCode.int8;
      case (#int16) Types.TypeDefCode.int16;
      case (#int32) Types.TypeDefCode.int32;
      case (#int64) Types.TypeDefCode.int64;
      case (#nat) Types.TypeDefCode.nat;
      case (#nat8) Types.TypeDefCode.nat8;
      case (#nat16) Types.TypeDefCode.nat16;
      case (#nat32) Types.TypeDefCode.nat32;
      case (#nat64) Types.TypeDefCode.nat64;
      case (#_null) Types.TypeDefCode._null;
      case (#bool) Types.TypeDefCode.bool;
      case (#float32) Types.TypeDefCode.float32;
      case (#float64) Types.TypeDefCode.float64;
      case (#text) Types.TypeDefCode.text;
      case (#reserved) Types.TypeDefCode.reserved;
      case (#empty) Types.TypeDefCode.empty;
      case (#principal) Types.TypeDefCode.principal;
      case (#opt(o)) Types.TypeDefCode.opt;
      case (#vector(v)) Types.TypeDefCode.vector;
      case (#record(r)) Types.TypeDefCode.record;
      case (#_func(f)) Types.TypeDefCode._func;
      case (#service(s)) Types.TypeDefCode.service;
      case (#variant(v)) Types.TypeDefCode.variant;
    };
  };

  private func encodeType(buffer : Buffer.Buffer<Nat8>, t : CompoundReferenceType) {
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
        // TODO
      };
      case (#service(s)) {
        // TODO
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


  private func getTypeInfo(args : [TypeDef]) : CompoundTypeTable {
    var table = TrieMap.TrieMap<CompoundReferenceType, Nat>(typesAreEqual, buildTypeHash);
    let codes = Buffer.Buffer<Int>(args.size());
    for (arg in Iter.fromArray(args)) {
      addTypeToTable(arg, table, codes);
    };
    type TypeInfo = (CompoundReferenceType, Nat);
    let sortedTable : [TypeInfo] = Array.sort<TypeInfo>(
      Iter.toArray(table.entries()),
      func(t1 : TypeInfo, t2 : TypeInfo) { Nat.compare(t1.1, t2.1) },
    );
    let compoundTypes : [CompoundReferenceType] = Iter.toArray(
      Iter.map<TypeInfo, CompoundReferenceType>(
        Iter.fromArray(sortedTable),
        func(kv : TypeInfo) { kv.0 },
      ),
    );
    {
      compoundTypes = compoundTypes;
      typeCodes = codes.toArray();
    };
  };

  private func addTypeToTable(t : TypeDef, table : TrieMap.TrieMap<CompoundReferenceType, Nat>, codes: Buffer.Buffer<Int>) {
    let indexOrCode : Int = addTypeToTableInternal(t, table, codes, false);
    codes.add(indexOrCode);
  };

  private func addTypeToTableInternal(t : TypeDef, table : TrieMap.TrieMap<CompoundReferenceType, Nat>, codes: Buffer.Buffer<Int>, nestedCall: Bool) : Int {
    // Only add compound types
    switch (t) {
      case (#opt(o)) addCompoundTypeToTable(#opt(o), table, codes);
      case (#vector(v)) addCompoundTypeToTable(#vector(v), table, codes);
      case (#record(r)) addCompoundTypeToTable(#record(r), table, codes);
      case (#_func(fn)) addCompoundTypeToTable(#_func(fn), table, codes);
      case (#service(s)) addCompoundTypeToTable(#service(s), table, codes);
      case (#variant(v)) addCompoundTypeToTable(#variant(v), table, codes);
      case (_) getTypeCode(t); // Primitives are just type codes
    };    
  };


  private func addCompoundTypeToTable(t : CompoundType, table : TrieMap.TrieMap<CompoundReferenceType, Nat>, codes: Buffer.Buffer<Int>) : Nat {
    let refType : CompoundReferenceType = switch(t) {
      case (#opt(o)) {
        let indexOrCode : ReferenceType = addTypeToTableInternal(o, table, codes, true);
        #opt(indexOrCode);
      };
      case (#vector(v)) {
        let indexOrCode : ReferenceType = addTypeToTableInternal(v, table, codes, true);
        #vector(indexOrCode);
      };
      case (#record(r)) {
        let fields : [RecordFieldReferenceType] = Iter.toArray(Iter.map<RecordFieldType, RecordFieldReferenceType>(Iter.fromArray(r), func (f: RecordFieldType) : RecordFieldReferenceType {
          let indexOrCode : ReferenceType = addTypeToTableInternal(f._type, table, codes, true);
          { tag = f.tag; _type = indexOrCode };
        }));
        #record(fields);
      };
      case (#_func(fn)) {
        let funcTypesToReference = func (t : Types.FuncArgs) : Types.FuncReferenceArgs {
          switch(t){
            case (#named(namedTypes)) {
              let refTypeBuffer = Buffer.Buffer<(Id, ReferenceType)>(namedTypes.size());
              for (t in Iter.fromArray(namedTypes)) {
                let refType : ReferenceType = addTypeToTableInternal(t.1, table, codes, true);
                refTypeBuffer.add((t.0, refType));
              };
              #named(refTypeBuffer.toArray());
            };
            case (#ordered(orderdTypes)) {
              let refTypeBuffer = Buffer.Buffer<ReferenceType>(orderdTypes.size());
              for (t in Iter.fromArray(orderdTypes)) {
                let refType : ReferenceType = addTypeToTableInternal(t, table, codes, true);
                refTypeBuffer.add(refType);
              };
              #ordered(refTypeBuffer.toArray());
            };
          };
        };
        let argTypes : Types.FuncReferenceArgs = funcTypesToReference(fn.argTypes);
        let returnTypes : Types.FuncReferenceArgs = funcTypesToReference(fn.returnTypes);
        #_func({
          modes=fn.modes;
          argTypes=argTypes;
          returnTypes=returnTypes;
        });
      };
      case (#service(s)) {
        let methods : [(Id, ReferenceType)] = Array.map<(Id, Types.FuncType), (Id, ReferenceType)>(s.methods, func (a: (Id, Types.FuncType)) : (Id, ReferenceType) {
          let refType : ReferenceType = addTypeToTableInternal(#_func(a.1), table, codes, true);
          (a.0, refType);
        });
        #service({
          methods=methods;
        });
      };
      case (#variant(v)) {
        let options : [VariantOptionReferenceType] = Iter.toArray(Iter.map<VariantOptionType, VariantOptionReferenceType>(Iter.fromArray(v), func (f: VariantOptionType) : VariantOptionReferenceType {
          let indexOrCode : ReferenceType = addTypeToTableInternal(f._type, table, codes, true);
          { tag = f.tag; _type = indexOrCode };
        }));
        #variant(options);
      };
    };
    let nextIndex : Nat = table.size();

    let previousValue : ?Nat = table.get(refType);
    
    switch (previousValue) {
      case (?i) i; // Already exists
      case (null) { // Doesn't exist
        table.put(refType, nextIndex);
        nextIndex;
      }; 
    };
  };

  private func typesAreEqual(t1 : CompoundReferenceType, t2 : CompoundReferenceType) : Bool {
    return t1 == t2;
  };

  private func buildTypeHash(t : CompoundReferenceType) : Hash.Hash {
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
        Array.foldLeft<RecordFieldReferenceType, Hash.Hash>(r, h, func (v: Hash.Hash, f: RecordFieldReferenceType) : Hash.Hash {
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
        Array.foldLeft<VariantOptionReferenceType, Hash.Hash>(v, 0, func (h: Hash.Hash, f: VariantOptionReferenceType) : Hash.Hash {
          let innerHash = Int.hash(f._type);
          combineHash(combineHash(h, Types.getTagHash(f.tag)), innerHash);
        });
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
        let utf8Bytes : Blob = Text.encodeUtf8(t);
        IntX.encodeInt(buffer, utf8Bytes.size(), #signedLEB128); // TODO validate it is signed vs unsigned
        for (byte in utf8Bytes.vals()) {
          buffer.add(byte);
        };
      };
      case (#reserved) {}; // Nothing to encode   TODO allowed?
      case (#empty) {}; // Nothing to encode   TODO allowed?
      case (#principal(p)) {
        // TODO opaque/null principal id? where bytes returned is [0x00]
        let bytes : [Nat8] = Blob.toArray(Principal.toBlob(p));
        NatX.encodeNat(buffer, bytes.size(), #unsignedLEB128); // Encode the byte length
        for (b in Iter.fromArray(bytes)) {
          buffer.add(b); // Encode the raw principal bytes
        };
      };
      case (#opt(o)) {
        switch (o) {
          case (null) buffer.add(0x00); // Indicate there is no value
          case (?v) {
            buffer.add(0x01); // Indicate there is a value
            let innerType : TypeDef = switch(t) {
              case (#opt(inner)) inner;
              case (badT) Debug.trap("F" # debug_show(badT)); // TODO
            };
            encodeValue(buffer, v, innerType); // Encode value
          };
        };
      };
      case (#vector(ve)) {
        let innerType : TypeDef = switch(t) {
          case (#vector(inner)) inner;
          case (_) Debug.trap("E"); // TODO
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
            TrieMap.fromEntries<Tag, TypeDef>(innerKV, tagEquals, Types.getTagHash);
          };
          case (_) Debug.trap("D"); // TODO
        };
        // Sort properties by the hash of the
        let sortedKVs : [RecordFieldValue] = Array.sort<RecordFieldValue>(r, func (v1, v2) : Order.Order { tagCompare(v1.tag, v2.tag) });
        
        for (kv in Iter.fromArray(sortedKVs)) {
          let innerType = switch(innerTypes.get(kv.tag)) {
            case (?t) t;
            case (null) Debug.trap("C"); // TODO
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
            encodeValue(buffer, #principal(principal), #principal); // Encode the service principal
          };
        };
      };
      case (#variant(v)) {
        let innerTypes : [VariantOptionType] = switch(t) {
          case (#variant(inner)) inner;
          case (badT) Debug.trap("A" # debug_show(badT)); // TODO
        };
        var typeIndex : ?Nat = firstIndexOf<VariantOptionType>(innerTypes, func (t) { tagEquals(t.tag, v.tag) });
        switch(typeIndex) {
          case (?i) {
            NatX.encodeNat(buffer, i, #unsignedLEB128); // Encode tag value
            encodeValue(buffer, v.value, innerTypes[i]._type); // Encode value
          };
          case (null) Debug.trap("B"); // TODO
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

  private func tagEquals(t1: Tag, t2: Tag) : Bool {
    tagCompare(t1, t2) == #equal;
  };

  private func tagCompare(t1: Tag, t2: Tag) : Order.Order {
    Nat32.compare(Types.getTagHash(t1), Types.getTagHash(t2));
  };
};

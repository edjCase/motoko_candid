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
import TrieMap "mo:base/TrieMap";
import Types "./Types";
import ValueEncoder "./ValueEncoder";

module {

  type CandidId = Types.CandidId;
  type CandidTag = Types.CandidTag;
  type CandidType = Types.CandidType;
  type CandidValue = Types.CandidValue;
  type RecordFieldValue = Types.RecordFieldValue;
  type PrimitiveType = Types.PrimitiveType;
  type CompoundType = Types.CompoundType;
  type RecordFieldType = Types.RecordFieldType;
  type VariantOptionType = Types.VariantOptionType;
  type CandidArg = Types.CandidArg;
  type RecordFieldArg = Types.RecordFieldArg;


  public func encode(args : [CandidArg]) : Blob {
    let buffer = Buffer.Buffer<Nat8>(10);
    encodeToBuffer(buffer, args);
    Blob.fromArray(buffer.toArray());
  };

  public func encodeToBuffer(buffer : Buffer.Buffer<Nat8>, args : [CandidArg]) {
    // "DIDL" prefix
    buffer.add(0x44);
    buffer.add(0x49);
    buffer.add(0x44);
    buffer.add(0x4c);

    encodeTypes(buffer, args); // Encode compound type table + primitive types
    encodeValues(buffer, args); // Encode all the values for the types
  };

  type CompoundTypeTable = {
    compoundTypes : [CompoundReferenceType];
    typeCodes : [Int]
  };
  private func encodeTypes(buffer : Buffer.Buffer<Nat8>, args : [CandidArg]) {
    let info : CompoundTypeTable = getTypeInfo(args);

    let _ = NatX.encodeNat(buffer, info.compoundTypes.size(), #unsignedLEB128); // Encode compound type count

    // Encode type table for compound types
    for (t in Iter.fromArray(info.compoundTypes)) {
      encodeType(buffer, t);
    };

    let _ = IntX.encodeInt(buffer, info.typeCodes.size(), #signedLEB128);
    // Encode type count // TODO validate this is a SIGNED leb128, not unsigned
    for (code in Iter.fromArray(info.typeCodes)) {
      let _ = IntX.encodeInt(buffer, code, #signedLEB128); // Encode each type
    };
  };

  private func getTypeCode(t : CandidType) : Int {
    switch (t) {
      case (#int) Types.CandidTypeCode.int;
      case (#int8) Types.CandidTypeCode.int8;
      case (#int16) Types.CandidTypeCode.int16;
      case (#int32) Types.CandidTypeCode.int32;
      case (#int64) Types.CandidTypeCode.int64;
      case (#nat) Types.CandidTypeCode.nat;
      case (#nat8) Types.CandidTypeCode.nat8;
      case (#nat16) Types.CandidTypeCode.nat16;
      case (#nat32) Types.CandidTypeCode.nat32;
      case (#nat64) Types.CandidTypeCode.nat64;
      case (#_null) Types.CandidTypeCode._null;
      case (#bool) Types.CandidTypeCode.bool;
      case (#float32) Types.CandidTypeCode.float32;
      case (#float64) Types.CandidTypeCode.float64;
      case (#text) Types.CandidTypeCode.text;
      case (#reserved) Types.CandidTypeCode.reserved;
      case (#empty) Types.CandidTypeCode.empty;
      case (#principal) Types.CandidTypeCode.principal;
      case (#opt(o)) Types.CandidTypeCode.opt;
      case (#vector(v)) Types.CandidTypeCode.vector;
      case (#record(r)) Types.CandidTypeCode.record;
      case (#_func(f)) Types.CandidTypeCode._func;
      case (#service(s)) Types.CandidTypeCode.service;
      case (#variant(v)) Types.CandidTypeCode.variant;
    };
  };

  private func encodeType(buffer : Buffer.Buffer<Nat8>, t : CompoundReferenceType) {
    let typeCode : Int = switch(t){
      case (#opt(o)) Types.CandidTypeCode.opt;
      case (#vector(v)) Types.CandidTypeCode.vector;
      case (#record(r)) Types.CandidTypeCode.record;
      case (#_func(f)) Types.CandidTypeCode._func;
      case (#service(s)) Types.CandidTypeCode.service;
      case (#variant(v)) Types.CandidTypeCode.variant;
    };
    let _ = IntX.encodeInt(buffer, typeCode, #signedLEB128);
    // Encode compound type code
    switch (t) {
      case (#opt(o)) {
        let _ = IntX.encodeInt(buffer, o, #signedLEB128); // Encode reference index or type code
      };
      case (#vector(v)) {
        let _ = IntX.encodeInt(buffer, v, #signedLEB128); // Encode reference index or type code
      };
      case (#record(r)) {
        let _ = IntX.encodeInt(buffer, r.size(), #signedLEB128); // Encode field count // TODO validate should be signed
        for (field in Iter.fromArray(r)) {
          let _ = NatX.encodeNat(buffer, Nat32.toNat(Types.getTagHash(field.tag)), #unsignedLEB128); // Encode field tag
          let _ = IntX.encodeInt(buffer, field._type, #signedLEB128); // Encode reference index or type code
        };
      };
      case (#_func(f)) {
        // TODO
      };
      case (#service(s)) {
        // TODO
      };
      case (#variant(v)) {
        let _ = IntX.encodeInt(buffer, v.size(), #signedLEB128); // Encode option count // TODO validate should be signed
        for (option in Iter.fromArray(v)) {
          let _ = NatX.encodeNat(buffer, Nat32.toNat(Types.getTagHash(option.tag)), #unsignedLEB128); // Encode option tag
          let _ = IntX.encodeInt(buffer, option._type, #signedLEB128); // Encode reference index or type code
        };
      };
    };
  };


  private func getTypeInfo(args : [CandidArg]) : CompoundTypeTable {
    var table = TrieMap.TrieMap<CompoundReferenceType, Nat>(typesAreEqual, buildTypeHash);
    let codes = Buffer.Buffer<Int>(args.size());
    for (arg in Iter.fromArray(args)) {
      let t : CandidType = getTypeFromArg(arg);
      addTypeToTable(t, table, codes);
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

  private func getTypeFromArg(arg : CandidArg) : CandidType {
    switch (arg) {
      case (#int(i)) #int;
      case (#int8(i8)) #int8;
      case (#int16(i16)) #int16;
      case (#int32(i32)) #int32;
      case (#int64(i64)) #int64;
      case (#nat(n)) #nat;
      case (#nat8(n8)) #nat8;
      case (#nat16(n16)) #nat16;
      case (#nat32(n32)) #nat32;
      case (#nat64(n64)) #nat64;
      case (#_null) #_null;
      case (#bool(b)) #bool;
      case (#float32(f)) #float32;
      case (#float64(f)) #float64;
      case (#text(t)) #text;
      case (#reserved) #reserved;
      case (#empty) #empty;
      case (#principal(p)) #principal;
      case (#opt(o)) {
        let inner : CandidType = switch(o){
          case(#novalue(t)) t;
          case(#value(a)) getTypeFromArg(a);
        };
        #opt(inner);
      };
      case (#vector(v)) #vector(v._type);
      case (#record(r)) {
        let mapFunc = func(f : RecordFieldArg): RecordFieldType {
          let fieldType : CandidType = getTypeFromArg(f.value);
          { tag = f.tag; _type = fieldType };
        };
        let fields : [RecordFieldType] = Array.map<RecordFieldArg, RecordFieldType>(r, mapFunc);
        #record(fields);
      };
      case (#_func(f)) {
        #opt(#int); // TODO
      };
      case (#service(s)) {
        #opt(#int); // TODO
      };
      case (#variant(v)) {
        let optionTypes = Buffer.Buffer<VariantOptionType>(v.otherOptions.size() + 1);

        let selectedType : CandidType = getTypeFromArg(v.selectedOption.value);
        optionTypes.add({tag = v.selectedOption.tag; _type=selectedType});

        for (o in Iter.fromArray(v.otherOptions)) {
          optionTypes.add(o);
        };
        #variant(optionTypes.toArray());
      };
    };
  };

  private func addTypeToTable(t : CandidType, table : TrieMap.TrieMap<CompoundReferenceType, Nat>, codes: Buffer.Buffer<Int>) {
    let indexOrCode : Int = addTypeToTableInternal(t, table, codes, false);
    codes.add(indexOrCode);
  };

  private func addTypeToTableInternal(t : CandidType, table : TrieMap.TrieMap<CompoundReferenceType, Nat>, codes: Buffer.Buffer<Int>, nestedCall: Bool) : Int {
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

  type ReferenceType = Int;

  type RecordFieldReferenceType = {
    tag: CandidTag;
    _type : ReferenceType;
  };

  type VariantOptionReferenceType = RecordFieldReferenceType;

  type CompoundReferenceType = {
    #opt : ReferenceType;
    #vector : ReferenceType;
    #record : [RecordFieldReferenceType];
    #variant : [VariantOptionReferenceType];
    #_func : ReferenceType; // TODO
    #service : ReferenceType; // TODO
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
        // TODO
        // addTypeToTableInternal(fn, table, codes);
        #opt(0);
      };
      case (#service(s)) {
        // TODO
        // addTypeToTableInternal(s, table, codes);
        #opt(0);
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
        let h = Int.hash(Types.CandidTypeCode.opt);
        let innerHash = Int.hash(o);
        combineHash(h, innerHash);
      };
      case (#vector(v)) {
        let h = Int.hash(Types.CandidTypeCode.vector);
        let innerHash = Int.hash(v);
        combineHash(h, innerHash);
      };
      case (#record(r)) {
        var h = Int.hash(Types.CandidTypeCode.record);
        Array.foldLeft<RecordFieldReferenceType, Hash.Hash>(r, 0, func (h: Hash.Hash, f: RecordFieldReferenceType) : Hash.Hash {
          let innerHash = Int.hash(f._type);
          combineHash(combineHash(h, Types.getTagHash(f.tag)), innerHash);
        });
      };
      case (#_func(f)) {
        let h = Int.hash(Types.CandidTypeCode._func);
        // TODO
        1;
      };
      case (#service(s)) {
        let h = Int.hash(Types.CandidTypeCode.service);
        // TODO 
        1;
      };
      case (#variant(v)) {
        var h = Int.hash(Types.CandidTypeCode.variant);
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

  private func encodeValues(buffer : Buffer.Buffer<Nat8>, args : [CandidArg]) {
    for (arg in Iter.fromArray(args)) {
      let v : CandidValue = getValueFromArg(arg);
      ValueEncoder.encodeToBuffer(buffer, v);
    };
  };

  private func getValueFromArg(arg: CandidArg) : CandidValue {
    switch (arg) {
      case (#int(i)) #int(i);
      case (#int8(i8)) #int8(i8);
      case (#int16(i16)) #int16(i16);
      case (#int32(i32)) #int32(i32);
      case (#int64(i64)) #int64(i64);
      case (#nat(n)) #nat(n);
      case (#nat8(n8)) #nat8(n8);
      case (#nat16(n16)) #nat16(n16);
      case (#nat32(n32)) #nat32(n32);
      case (#nat64(n64)) #nat64(n64);
      case (#_null) #_null;
      case (#bool(b)) #bool(b);
      case (#float32(f)) #float32(f);
      case (#float64(f)) #float64(f);
      case (#text(t)) #text(t);
      case (#reserved) #reserved;
      case (#empty) #empty;
      case (#principal(p)) #principal(p);
      case (#opt(o)) {
        let v : ?CandidValue = switch(o){
          case(#novalue(t)) null;
          case(#value(a)) ?getValueFromArg(a);
        };
        #opt(v);
      };
      case (#vector(ve)) {
        #vector(ve.values);
      };
      case (#record(r)) {
        let mapFunc = func(f : RecordFieldArg): RecordFieldValue {
          let v : CandidValue = getValueFromArg(f.value);
          { tag = f.tag; value = v };
        };
        let fields : [RecordFieldValue] = Array.map<RecordFieldArg, RecordFieldValue>(r, mapFunc);
        #record(fields);
      };
      case (#_func(f)) {
        // TODO
        #int(0)
      };
      case (#service(s)) {
        // TODO
        #int(0)
      };
      case (#variant(va)) {
        let v : CandidValue = getValueFromArg(va.selectedOption.value);
        #variant({tag=va.selectedOption.tag; value=v});
      };
    };
  };
};

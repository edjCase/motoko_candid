import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import FloatX "mo:xtendedNumbers/FloatX";
import IntX "mo:xtendedNumbers/IntX";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import NatX "mo:xtendedNumbers/NatX";
import TrieMap "mo:base/TrieMap";
import TypeEncoder "./TypeEncoder";
import Types "./Types";

module {

  type CandidId = Types.CandidId;
  type CandidTag = Types.CandidTag;
  type CandidType = Types.CandidType;
  type PrimitiveType = Types.PrimitiveType;
  type CompoundType = Types.CompoundType;
  type RecordFieldType = Types.RecordFieldType;
  type VariantOptionType = Types.VariantOptionType;

  type RecordFieldArg = {
    tag : CandidTag;
    value : CandidArg;
  };

  type VariantOptionArg = RecordFieldArg;

  type CandidServiceArg = {
    value : {
      #opaque;
      #transparent : Principal;
    };
    methods : [(CandidId, Types.CandidFuncType)];
    // TODO func in here?
  };

  type CandidArg = {
    #int : Int;
    #int8 : Int8;
    #int16 : Int16;
    #int32 : Int32;
    #int64 : Int64;
    #nat : Nat;
    #nat8 : Nat8;
    #nat16 : Nat16;
    #nat32 : Nat32;
    #nat64 : Nat64;
    #_null;
    #bool : Bool;
    #float32 : FloatX.FloatX;
    #float64 : Float;
    #text : Text;
    #principal : Principal;
    #reserved;
    #empty;
    #opt : CandidArg;
    #vector : CandidArg;
    #record : [RecordFieldArg];
    #variant : {
      selectedOption : VariantOptionArg;
      otherOptions : [VariantOptionType];
    };
    #_func : {
      value : {
        #opaque;
        #transparent : {
          service : CandidServiceArg;
          method : Text;
        };
      };
    };
    #service : CandidServiceArg;
  };

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

    encodeTypes(buffer, args);
    // Encode compound type table + primitive types
    encodeValues(buffer, args);
    // Encode all the values for the types
  };

  type CompoundTypeTable = {
    compoundTypes : [CompoundType];
    typeCodes : [Int]
  };
  private func encodeTypes(buffer : Buffer.Buffer<Nat8>, args : [CandidArg]) {
    let info : CompoundTypeTable = getTypeInfo(args);

    let _ = NatX.encodeNat(buffer, info.compoundTypes.size(), #unsignedLEB128);
    // Encode compound type count

    // Encode type table for compound types
    for (t in Iter.fromArray(info.compoundTypes)) {
      let typeCode : Int = getTypeCode(t);
      encodeType(buffer, t, typeCode);
    };

    let _ = IntX.encodeInt(buffer, info.typeCodes.size(), #signedLEB128);
    // Encode type count // TODO validate this is a SIGNED leb128, not unsigned
    for (code in Iter.fromArray(info.typeCodes)) {
      let _ = IntX.encodeInt(buffer, code, #signedLEB128);
      // Encode each type
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

  private func encodeType(
    buffer : Buffer.Buffer<Nat8>,
    t : CompoundType,
    typeCode : Int,
  ) {
    let _ = IntX.encodeInt(buffer, typeCode, #signedLEB128);
    // Encode compound type code
    switch (t) {
      case (#opt(o)) {
        // TODO
      };
      case (#vector(v)) {
        // TODO
      };
      case (#record(r)) {
        // TODO
      };
      case (#_func(f)) {
        // TODO
      };
      case (#service(s)) {
        // TODO
      };
      case (#variant(v)) {
        // TODO
      };
    };
  };

  private func doIfCompound(t : CandidType, f: (CompoundType) -> ()) {
    switch (t) {
      case (#opt(o)) f(#opt(o));
      case (#vector(v)) f(#vector(v));
      case (#record(r)) f(#record(r));
      case (#_func(fn)) f(#_func(fn));
      case (#service(s)) f(#service(s));
      case (#variant(v)) f(#variant(v));
      case (_) {}; // Do nothing if primitive
    };
  };

  private func getTypeInfo(args : [CandidArg]) : CompoundTypeTable {
    var table = TrieMap.TrieMap<CompoundType, Nat>(typesAreEqual, buildTypeHash);
    let codes = Buffer.Buffer<Int>(args.size());
    for (arg in Iter.fromArray(args)) {
      let _ = addArgTypeToTable(arg, table, codes);
    };
    type TypeInfo = (CompoundType, Nat);
    let sortedTable : [TypeInfo] = Array.sort<TypeInfo>(
      Iter.toArray(table.entries()),
      func(t1 : TypeInfo, t2 : TypeInfo) { Nat.compare(t1.1, t2.1) },
    );
    let compoundTypes : [CompoundType] = Iter.toArray(
      Iter.map<TypeInfo, CompoundType>(
        Iter.fromArray(sortedTable),
        func(kv : TypeInfo) { kv.0 },
      ),
    );
    {
      compoundTypes = compoundTypes;
      typeCodes = codes.toArray();
    };
  };

  private func addArgTypeToTable(
    arg : CandidArg,
    table : TrieMap.TrieMap<CompoundType, Nat>,
    codes : Buffer.Buffer<Int>,
  ) : CandidType {
    let (t: CandidType, index: ?Nat) = switch (arg) {
      case (#int(i)) (#int, null: ?Nat);
      case (#int8(i8)) (#int8, null: ?Nat);
      case (#int16(i16)) (#int16, null: ?Nat);
      case (#int32(i32)) (#int32, null: ?Nat);
      case (#int64(i64)) (#int64, null: ?Nat);
      case (#nat(n)) (#nat, null: ?Nat);
      case (#nat8(n8)) (#nat8, null: ?Nat);
      case (#nat16(n16)) (#nat16, null: ?Nat);
      case (#nat32(n32)) (#nat32, null: ?Nat);
      case (#nat64(n64)) (#nat64, null: ?Nat);
      case (#_null) (#_null, null: ?Nat);
      case (#bool(b)) (#bool, null: ?Nat);
      case (#float32(f)) (#float32, null: ?Nat);
      case (#float64(f)) (#float64, null: ?Nat);
      case (#text(t)) (#text, null: ?Nat);
      case (#reserved) (#reserved, null: ?Nat);
      case (#empty) (#empty, null: ?Nat);
      case (#principal(p)) (#principal, null: ?Nat);
      case (#opt(o)) {
        let inner : CandidType = addArgTypeToTable(o, table, codes);
        let t = #opt(inner);
        let index = getOrAdd(table, t);
        (t, ?index);
      };
      case (#vector(v)) {
        let inner : CandidType = addArgTypeToTable(v, table, codes);
        let t = #vector(inner);
        let index = getOrAdd(table, t);
        (t, ?index);
      };
      case (#record(r)) {
        let mapFunc = func(f : RecordFieldArg): RecordFieldType {
          let fieldType : CandidType = addArgTypeToTable(
            f.value,
            table,
            codes,
          );
          { tag = f.tag; _type = fieldType };
        };
        let fields : [RecordFieldType] = Array.map<RecordFieldArg, RecordFieldType>(r, mapFunc);
        let t = #record(fields);
        let index = getOrAdd(table, t);
        (t, ?index);
      };
      case (#_func(f)) {
        let t = #opt(#int);
        // TODO
        let index = getOrAdd(table, t);
        (t, ?index);
      };
      case (#service(s)) {
        let t = #opt(#int);
        // TODO
        let index = getOrAdd(table, t);
        (t, ?index);
      };
      case (#variant(v)) {
        let optionTypes = Buffer.Buffer<VariantOptionType>(v.otherOptions.size() + 1);

        let selectedType : CandidType = addArgTypeToTable(v.selectedOption.value, table, codes);
        optionTypes.add({tag = v.selectedOption.tag; _type=selectedType});

        for (o in Iter.fromArray(v.otherOptions)) {
          doIfCompound(o._type, func (t: CompoundType) { let _ = getOrAdd(table, t); });
          
          optionTypes.add(o);
        };
        let t = #variant(optionTypes.toArray());
        let index = getOrAdd(table, t);
        (t, ?index);
      };
    };
    let typeCodeOrIndex: Int = switch (index) {
      case (null) getTypeCode(t); // If null, then its a primitive, so use the type code 
      case (?i) i; // If not null then its a compound type, so use the index
    };
    codes.add(typeCodeOrIndex);
    t;
  };

  private func getOrAdd(
    table : TrieMap.TrieMap<CompoundType, Nat>,
    t : CompoundType,
  ) : Nat {
    let nextIndex : Nat = table.size();
    let previousValue : ?Nat = table.get(t);
    switch (previousValue) {
      case (?i) i; // Already existed, return existing
      case (null) {
        table.put(t, nextIndex);
        nextIndex;
      }; // Doesn't exist, return new
    };
  };

  private func typesAreEqual(t1 : CandidType, t2 : CandidType) : Bool {
    return t1 == t2;
  };

  private func buildTypeHash(t : CandidType) : Hash.Hash {
    1; // TODO
  };

  private func encodeValues(buffer : Buffer.Buffer<Nat8>, args : [CandidArg]) {

  };
};

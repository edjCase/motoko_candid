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
  type RecordFieldType = Types.

  type RecordFieldArg = {
    tag : CandidTag;
    value : CandidArg;
  };

  type VariantOptionArg = RecordFieldArg;

  type CandidServiceObj = {
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
    #record : [
      {
        tag : CandidTag;
        value : CandidArg;
      },
    ];
    #variant : {
      tag : CandidTag;
      value : CandidArg;
    };
    #_func : {
      value : {
        #opaque;
        #transparent : {
          service : CandidServiceObj;
          method : Text;
        };
      };
    };
    #service : CandidServiceObj;
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

  private func encodeTypes(buffer : Buffer.Buffer<Nat8>, args : [CandidArg]) {
    let info : { compoundTypes : [CandidType]; typeCodes : [Int] } = getTypeInfo(
      args,
    );

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
    t : CandidType,
    typeCode : Int,
  ) {
    let _ = IntX.encodeInt(buffer, typeCode, #signedLEB128);
    // Encode compound type code
    switch (t) {
      case (#opt(o)) {

      };
      case (#vector(v)) {

      };
      case (#record(r)) {

      };
      case (#_func(f)) {

      };
      case (#service(s)) {

      };
      case (#variant(v)) {

      };
    };
  };

  private func getTypeInfo(args : [CandidArg]) : {
    compoundTypes : [CandidType];
    typeCodes : [Int];
  } {
    var table = TrieMap.TrieMap<CandidType, Nat>(typesAreEqual, buildTypeHash);
    let codes = Buffer.Buffer<Int>(args.size());
    for (arg in Iter.fromArray(args)) {
      let _ = addArgTypeToTable(arg, table, codes);
    };
    type TypeInfo = (CandidType, Nat);
    let sortedTable : [TypeInfo] = Array.sort<TypeInfo>(
      Iter.toArray(table.entries()),
      func(t1 : TypeInfo, t2 : TypeInfo) { Nat.compare(t1.1, t2.1) },
    );
    let compoundTypes : [CandidType] = Iter.toArray(
      Iter.map<TypeInfo, CandidType>(
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
    table : TrieMap.TrieMap<CandidType, Nat>,
    codes : Buffer.Buffer<Int>,
  ) : CandidType {
    let (typeCodeOrIndex : Int, _type : CandidType) = switch (arg) {
      case (#int(i))(getTypeCode(#int), #int);
      case (#int8(i8))(getTypeCode(#int8), #int8);
      case (#int16(i16))(getTypeCode(#int16), #int16);
      case (#int32(i32))(getTypeCode(#int32), #int32);
      case (#int64(i64))(getTypeCode(#int64), #int64);
      case (#nat(n))(getTypeCode(#nat), #nat);
      case (#nat8(n8))(getTypeCode(#nat8), #nat8);
      case (#nat16(n16))(getTypeCode(#nat16), #nat16);
      case (#nat32(n32))(getTypeCode(#nat32), #nat32);
      case (#nat64(n64))(getTypeCode(#nat64), #nat64);
      case (#_null)(getTypeCode(#_null), #_null);
      case (#bool(b))(getTypeCode(#bool), #bool);
      case (#float32(f))(getTypeCode(#float32), #float32);
      case (#float64(f))(getTypeCode(#float64), #float64);
      case (#text(t))(getTypeCode(#text), #text);
      case (#reserved)(getTypeCode(#reserved), #reserved);
      case (#empty)(getTypeCode(#empty), #empty);
      case (#principal(p))(getTypeCode(#principal), #principal);
      case (#opt(o)) {
        let inner : CandidType = addArgTypeToTable(o, table, codes);
        let t = #opt(inner);
        let index = getOrAdd(table, t);
        (index, t);
      };
      case (#vector(v)) {
        let inner : CandidType = addArgTypeToTable(v, table, codes);
        let t = #vector(inner);
        let index = getOrAdd(table, t);
        (index, t);
      };
      case (#record(r)) {
        let fields : [RecordFieldType] = Array.map<
          RecordFieldArg,
          RecordFieldType,
        >(
          r,
          func(f : RecordFieldArg) {
            let fieldType : CandidType = addArgTypeToTable(
              f.value,
              table,
              codes,
            );
            { tag = f.tag; _type = fieldType };
          },
        );
        let t = #record(fields);
        let index = getOrAdd(table, t);
        (index, t);
      };
      case (#_func(f)) {
        let t = #opt(#int);
        // TODO
        let index = getOrAdd(table, t);
        (index, t);
      };
      case (#service(s)) {
        let t = #opt(#int);
        // TODO
        let index = getOrAdd(table, t);
        (index, t);
      };
      case (#variant(v)) {
        let options : [VariantOptionType] = Array.map<
          RecordFieldArg,
          VariantOptionType,
        >(
          r,
          func(o : VariantOptionArg) {
            let optionType : CandidType = addArgTypeToTable(
              o.value,
              table,
              codes,
            );
            (o.tag, optionType);
          },
        );
        let t = #variant(options);
        let index = getOrAdd(table, t);
        (index, t);
      };
    };
    codes.add(typeCodeOrIndex);
    _type;
  };

  private func getOrAdd(
    table : TrieMap.TrieMap<CandidType, Nat>,
    t : CandidType,
  ) : Nat {
    let nextIndex : Nat = table.size();
    let previousValue : ?Nat = table.get(t);
    switch (previousValue) {
      case (?i) i;
      // Already existed, return existing
      case (null) {
        table.put(t, nextIndex);
        nextIndex;
      };
      // Doesn't exist, return new
    };
  };

  private func typesAreEqual(t1 : CandidType, t2 : CandidType) : Bool {
    return t1 == t2;
  };

  private func buildTypeHash(t : CandidType) : Hash.Hash {
    1;
    // TODO
  };

  private func encodeValues(buffer : Buffer.Buffer<Nat8>, args : [CandidArg]) {

  };
};

import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import IntX "mo:xtendedNumbers/IntX";
import NatX "mo:xtendedNumbers/NatX";
import TrieMap "mo:base/TrieMap";
import TypeEncoder "./TypeEncoder";
import Types "./Types";

module {

  type CandidServiceObj = {
    value: {
      #opaque;
      #transparent: Principal;
    };
    methods: [(CandidId, Types.CandidFuncType)]; // TODO func in here?
  };
    
  type CandidObj = {
    #int : Int;
    #int8: Int8;
    #int16: Int16;
    #int32: Int32;
    #int64: Int64;
    #nat : Nat;
    #nat8 : Nat8;
    #nat16 : Nat16;
    #nat32 : Nat32;
    #nat64 : Nat64;
    #_null;
    #bool : Bool;
    #floatX : FloatX.FloatX;
    #text: Text;
    #principal : Principal;
    #reserved;
    #empty;
    #opt : ?CandidObj;
    #vector : CandidObj;
    #record : [{
      tag: CandidTag;
      value: CandidObj;
    }];
    #variant: {
      tag: CandidTag;
      value: CandidObj
    };
    #_func: {
      value: {
        #opaque;
        #transparent: {
          service: CandidServiceObj;
          method: Text;
        };
      };
    };
    #service : CandidServiceObj;
  };

  public func encode(args: [CandidObj]) : Blob {
    let buffer = Buffer.Buffer<Nat8>(10);
    encodeToBuffer(buffer, args);
    Blob.fromArray(buffer.toArray());
  };

  public func encodeToBuffer(buffer: Buffer.Buffer<Nat8>, args: [CandidObj]) {
    buffer.append([0x44, 0x49, 0x44, 0x4c]); // "DIDL" prefix
    encodeTypes(buffer, args); // Encode compound type table + primitive types
    encodeValues(buffer, args); // Encode all the values for the types
  };

  private func encodeTypes(buffer: Buffer.Buffer<Nat8>, args: [CandidObj]) {
    let (table: CompoundTypeTable, codes: [Int]) = getTypeInfo(args);
    encodeCompoundTypeTable(buffer, table); // Encode type table for compound types
    IntX.encodeInt(buffer, types.size(), #signedLEB128); // Encode type count // TODO validate this is a SIGNED leb128, not unsigned
    for (code in codes) {
      IntX.encodeInt(buffer, code, #signedLEB128); // Encode each type
    };
  };

  private func encodeCompoundTypeTable(buffer: Buffer.Buffer<Nat8>, table: {}) {
    NatX.encodeNat(buffer, table.key.length); // Encode compound type count
    // TODO Order by index
    for (t in table) {
      IntX.encodeInt(buffer, t.typeCode, #signedLEB128); // Encode compound type code
      // TODO Encode inner types
    }
  };

  private func getTypeInfo(buffer: Buffer.Buffer<Nat8>): (CompoundTypeTable, [Int]) {
    let table = TrieMap.TrieMap<CandidObj, Nat>();
    let codes = Buffer.Buffer<Int>(args.size());
    for (arg in args) {
      let typeCodeOrIndex: Int = switch(arg) {
        case (#int(i)) Types.CandidTypeCode.int;
        case (#int8(i8)) Types.CandidTypeCode.int8;
        case (#int16(i16)) Types.CandidTypeCode.int16;
        case (#int32(i32)) Types.CandidTypeCode.int32;
        case (#int64(i64)) Types.CandidTypeCode.int64;
        case (#nat(n)) Types.CandidTypeCode.nat;
        case (#nat8(n8)) Types.CandidTypeCode.nat8;
        case (#nat16(n16)) Types.CandidTypeCode.nat16;
        case (#nat32(n32)) Types.CandidTypeCode.nat32;
        case (#nat64(n64)) Types.CandidTypeCode.nat64;
        case (#_null) Types.CandidTypeCode._null;
        case (#bool(b)) Types.CandidTypeCode.bool;
        case (#float32(f)) Types.CandidTypeCode.float32;
        case (#float64(f)) Types.CandidTypeCode.float64;
        case (#text(t)) Types.CandidTypeCode.text;
        case (#reserved) Types.CandidTypeCode.reserved;
        case (#empty) Types.CandidTypeCode.empty;
        case (#principal(p)) Types.CandidTypeCode.principal;
        // case (#opt(o)) {
          
        // };
        // case (#vector(v)) {
          
        // };
        // case (#record(r)) {
          
        // };
        // case (#_func(f)) {
          
        // };
        // case (#service(s)) {
          
        // };
        // case (#variant(v)) {

        // };
        case (_) getOrAdd(table, arg);
      };
    };
    (table, codes.toArray());
  };

  private func getOrAdd(table: TrieMap.TrieMap<CandidType, Nat>, arg: CandidType) {
    
  };

  private func encodeValues(buffer: Buffer.Buffer<Nat8>, args: [CandidObj]) {

  };
};
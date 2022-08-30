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


  public func decode(candidBytes: Blob) : [(Value, TypeDef)] {
    switch (decodeInternal(candidBytes)) {
      case (null) Debug.trap(""); // TODO or should do result?
      case (?r) r;
    }
  };

  private func decodeInternal(candidBytes: Blob) : ?[(Value, TypeDef)] {
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
      let types : [TypeDef] = buildTypes(compoundTypes, argTypes);
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
    null;
  };

  private func buildTypes(compoundTypes: [CompoundReferenceType], argTypes: [Int]) : [TypeDef] {
    [];
  };
  
  private func decodeTypes(bytes: Iter.Iter<Nat8>) : ?([CompoundReferenceType], [Int]) {
    null;
  };
};

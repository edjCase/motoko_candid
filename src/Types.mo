import Array "mo:base/Array";
import Blob "mo:base/Blob";
import FloatX "mo:xtendedNumbers/FloatX";
import Iter "mo:base/Iter";
import Nat "mo:base/Blob";
import Nat32 "mo:base/Nat32";
import NatX "mo:xtendedNumbers/NatX";
import Order "mo:base/Order";
import Text "mo:base/Text";

module {

  public type RecordFieldValue = {
    tag: Tag;
    value: Value;
  };

  public type VariantOptionValue = RecordFieldValue;

  public type Value = {
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
    #float32 : Float;
    #float64 : Float;
    #text : Text;
    #reserved;
    #empty;
    #opt : ?Value;
    #vector : [Value];
    #record : [RecordFieldValue];
    #variant : VariantOptionValue;
    #_func : Reference<Func>;
    #service : Reference<Principal>;
    #principal : Reference<Principal>;
  };

  public func valuesAreEqual(v1: Value, v2: Value): Bool {
    switch (v1) {
      case (#float32(f1)) {
        let f2 = switch (v2) {
          case(#float32(f2)) f2;
          case(#float64(f2)) f2;
          case (_) return false;
        };
        FloatX.nearlyEqual(f1, f2, 0.0000001, 0.000001);
      };
      case (#float64(f1)) {
        let f2 = switch (v2) {
          case(#float32(f2)) f2;
          case(#float64(f2)) f2;
          case (_) return false;
        };
        FloatX.nearlyEqual(f1, f2, 0.0000001, 0.000001);
      };
      case (#opt(o1)) {
        let o2 = switch (v2) {
          case(#opt(o2)) o2;
          case (_) return false;
        };
        switch (o1) {
          case (null) return o2 == null;
          case (?o1) {
            switch(o2) {
              case (null) return false;
              case (?o2) valuesAreEqual(o1, o2);
            }
          }
        };
      };
      case (#vector(ve1)) {
        let ve2 = switch (v2) {
          case(#vector(ve)) ve;
          case (_) return false;
        };
        if (ve1.size() != ve2.size()) {
          return false;
        };
        for (i in Iter.range(0, ve1.size() - 1)) {
          if (not valuesAreEqual(ve1[i], ve2[i])) {
            return false;
          };
        };
        true;
      };
      case (#record(r1)) {
        let r2 = switch (v2) {
          case(#record(r2)) r2;
          case (_) return false;
        };
        if (r1.size() != r2.size()) {
          return false;
        };
        let orderFunc = func (r1: RecordFieldValue, r2: RecordFieldValue) : Order.Order {
          tagCompare(r1.tag, r2.tag)
        };
        let orderedR1 = Array.sort(r1, orderFunc);
        let orderedR2 = Array.sort(r2, orderFunc);
        for (i in Iter.range(0, orderedR1.size() - 1)) {
          let r1I = orderedR1[i];
          let r2I = orderedR2[i];
          if (not tagsAreEqual(r1I.tag, r2I.tag)) {
            return false;
          };
          if (not valuesAreEqual(r1I.value, r2I.value)) {
            return false;
          };
        };
        true;
      };
      case (#variant(va1)) {
        let va2 = switch (v2) {
          case(#variant(va2)) va2;
          case (_) return false;
        };
        if (not tagsAreEqual(va1.tag, va2.tag)) {
          return false;
        };
        if (not valuesAreEqual(va1.value, va2.value)) {
          return false;
        };
        true;
      };
      case (#_func(f1)) {
        let f2 = switch (v2) {
          case(#_func(f2)) f2;
          case (_) return false;
        };
        // TODO
        f1 == f2;
      };
      case (#service(s1)) {
        let s2 = switch (v2) {
          case(#service(s2)) s2;
          case (_) return false;
        };
        // TODO
        s1 == s2;
      };
      case (a) a == v2;
    };
  };

  public type Tag = {
    #name : Text;
    #hash : Nat32;
  };
  public func getTagHash(t : Tag) : Nat32 {
    switch (t) {
      case (#name(n)) hashTagName(n);
      case (#hash(h)) h;
    };
  };

  public func tagsAreEqual(t1: Tag, t2: Tag) : Bool {
    tagCompare(t1, t2) == #equal;
  };

  public func tagCompare(t1: Tag, t2: Tag) : Order.Order {
    Nat32.compare(getTagHash(t1), getTagHash(t2));
  };

  public func tagObjCompare(o1: {tag: Tag}, o2: {tag: Tag}) : Order.Order {
    tagCompare(o1.tag, o2.tag);
  };

  public func hashTagName(name : Text) : Nat32 {
    // hash(name) = ( Sum_(i=0..k) utf8(name)[i] * 223^(k-i) ) mod 2^32 where k = |utf8(name)|-1
    let bytes : [Nat8] = Blob.toArray(Text.encodeUtf8(name));
    Array.foldLeft<Nat8, Nat32>(bytes, 0, func (accum: Nat32, byte : Nat8) : Nat32 {
      (accum *% 223) +% NatX.from8To32(byte);
    });
  };

  public type Id = Text;

  public type Reference<T> = {
    #opaque;
    #transparent : T;
  };

  public type ServiceType = {
    methods : [(Id, FuncType)];
  };

  public type Func = {
    service : Reference<Principal>;
    method : Text;
  };

  public type RecordFieldType = {
    tag : Tag;
    _type : TypeDef;
  };

  public type VariantOptionType = RecordFieldType;

  public type FuncMode = {
    #oneWay;
    #_query;
  };

  public type FuncType = {
    modes : [FuncMode];
    argTypes : [TypeDef];
    returnTypes : [TypeDef];
  };

  public type PrimitiveType = {
    #int;
    #int8;
    #int16;
    #int32;
    #int64;
    #nat;
    #nat8;
    #nat16;
    #nat32;
    #nat64;
    #_null;
    #bool;
    #float32;
    #float64;
    #text;
    #reserved;
    #empty;
    #principal;
  };

  public type CompoundType = {
    #opt : TypeDef;
    #vector : TypeDef;
    #record : [RecordFieldType];
    #variant : [VariantOptionType];
    #_func : FuncType;
    #service : ServiceType;
    #recursiveType : {id:Id; _type:CompoundType};
    #recursiveReference : Id;
  };

  public type TypeDef = CompoundType or PrimitiveType;



  public func typesAreEqual(v1: TypeDef, v2: TypeDef): Bool {
    switch (v1) {
      case (#opt(o1)) {
        let o2 = switch (v2) {
          case(#opt(o2)) o2;
          case (_) return false;
        };
        typesAreEqual(o1, o2);
      };
      case (#vector(ve1)) {
        let ve2 = switch (v2) {
          case(#vector(ve)) ve;
          case (_) return false;
        };
        typesAreEqual(ve1, ve2);
      };
      case (#record(r1)) {
        let r2 = switch (v2) {
          case(#record(r2)) r2;
          case (_) return false;
        };
        if (r1.size() != r2.size()) {
          return false;
        };
        let orderFunc = func (r1: RecordFieldType, r2: RecordFieldType) : Order.Order {
          tagCompare(r1.tag, r2.tag)
        };
        let orderedR1 = Array.sort(r1, orderFunc);
        let orderedR2 = Array.sort(r2, orderFunc);
        for (i in Iter.range(0, orderedR1.size() - 1)) {
          let r1I = orderedR1[i];
          let r2I = orderedR2[i];
          if (not tagsAreEqual(r1I.tag, r2I.tag)) {
            return false;
          };
          if (not typesAreEqual(r1I._type, r2I._type)) {
            return false;
          };
        };
        true;
      };
      case (#variant(va1)) {
        let va2 = switch (v2) {
          case(#variant(va2)) va2;
          case (_) return false;
        };
        if (va1.size() != va2.size()) {
          return false;
        };
        let orderFunc = func (t1: VariantOptionType, t2: VariantOptionType) : Order.Order {
          tagCompare(t1.tag, t2.tag)
        };
        let orderedVa1 = Array.sort(va1, orderFunc);
        let orderedVa2 = Array.sort(va2, orderFunc);
        for (i in Iter.range(0, orderedVa1.size() - 1)) {
          let va1I = orderedVa1[i];
          let va2I = orderedVa2[i];
          if (not tagsAreEqual(va1I.tag, va2I.tag)) {
            return false;
          };
          if (not typesAreEqual(va1I._type, va2I._type)) {
            return false;
          };
        };
        true;
      };
      case (#_func(f1)) {
        let f2 = switch (v2) {
          case(#_func(f2)) f2;
          case (_) return false;
        };
        // TODO
        f1 == f2;
      };
      case (#service(s1)) {
        let s2 = switch (v2) {
          case(#service(s2)) s2;
          case (_) return false;
        };
        // TODO
        s1 == s2;
      };
      case (#recursiveType(r1)) {
        let r2 = switch (v2) {
          case(#recursiveType(r2)) r2;
          case (_) return false;
        };
        // TODO names can be different
        typesAreEqual(r1._type, r2._type);
      };
      case (#recursiveReference(r1)) {
        let r2 = switch (v2) {
          case(#recursiveReference(r2)) r2;
          case (_) return false;
        };
        // TODO names can be different
        true;
      };
      case (a) a == v2;
    };
  };


  public type ReferenceType = Int;

  public type RecordFieldReferenceType<TReference> = {
    tag: Tag;
    _type : TReference;
  };

  public type VariantOptionReferenceType<TReference> = RecordFieldReferenceType<TReference>;

  public type FuncReferenceType<TReference> = {
    modes : [FuncMode];
    argTypes : [TReference];
    returnTypes : [TReference];
  };



  public type ServiceReferenceType<TReference> = {
    methods : [(Id, TReference)];
  };



  public type ShallowCompoundType<TReference> = {
    #opt : TReference;
    #vector : TReference;
    #record : [RecordFieldReferenceType<TReference>];
    #variant : [VariantOptionReferenceType<TReference>];
    #_func : FuncReferenceType<TReference>;
    #service : ServiceReferenceType<TReference>;
  };


  public object TypeDefCode {
    public let _null = -1;
    public let bool = -2;
    public let nat = -3;
    public let int = -4;
    public let nat8 = -5;
    public let nat16 = -6;
    public let nat32 = -7;
    public let nat64 = -8;
    public let int8 = -9;
    public let int16 = -10;
    public let int32 = -11;
    public let int64 = -12;
    public let float32 = -13;
    public let float64 = -14;
    public let text = -15;
    public let reserved = -16;
    public let empty = -17;
    public let opt = -18;
    public let vector = -19;
    public let record = -20;
    public let variant = -21;
    public let _func = -22;
    public let service = -23;
    public let principal = -24;
  };
};

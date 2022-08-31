import Blob "mo:base/Blob";
import Iter "mo:base/Array";
import NatX "mo:xtendedNumbers/NatX";
import Text "mo:base/Text";
import Order "mo:base/Order";
import Nat32 "mo:base/Nat32";

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
    #_func : Func;
    #service : PrincipalValue;
    #principal : PrincipalValue;
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
    Iter.foldLeft<Nat8, Nat32>(bytes, 0, func (accum: Nat32, byte : Nat8) : Nat32 {
      (accum *% 223) +% NatX.from8To32(byte);
    });
  };

  public type Id = Text;

  public type PrincipalValue = {
    #opaque;
    #transparent : Principal;
  };

  public type ServiceType = {
    methods : [(Id, FuncType)];
  };

  public type Func = {
    #opaque;
    #transparent : {
      service : PrincipalValue;
      method : Text;
    };
  };

  public type RecordFieldType = {
    tag : Tag;
    _type : TypeDef;
  };

  public type VariantOptionType = RecordFieldType;

  public type FuncArgs = {
    #ordered : [TypeDef];
    #named : [(Id, TypeDef)];
  };

  public type FuncType = {
    modes : [{ #oneWay; #_query }];
    // TODO check the spec
    argTypes : FuncArgs;
    returnTypes : FuncArgs;
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
  };

  public type TypeDef = CompoundType or PrimitiveType;


  public type ReferenceType = Int;

  public type RecordFieldReferenceType = {
    tag: Tag;
    _type : ReferenceType;
  };

  public type VariantOptionReferenceType = RecordFieldReferenceType;

  public type FuncReferenceArgs = {
    #ordered : [ReferenceType];
    #named : [(Id, ReferenceType)];
  };

  public type FuncReferenceType = {
    modes : [{ #oneWay; #_query }];
    // TODO check the spec
    argTypes : FuncReferenceArgs;
    returnTypes : FuncReferenceArgs;
  };



  public type ServiceReferenceType = {
    methods : [(Id, ReferenceType)];
  };

  public type CompoundReferenceType = {
    #opt : ReferenceType;
    #vector : ReferenceType;
    #record : [RecordFieldReferenceType];
    #variant : [VariantOptionReferenceType];
    #_func : FuncReferenceType;
    #service : ServiceReferenceType;
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

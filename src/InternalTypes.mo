import Tag "./Tag";
import FuncMode "./FuncMode";
import Order "mo:core@1/Order";
import Array "mo:core@1/Array";
import Nat "mo:core@1/Nat";

module {
  public type Arg = {
    value : Value;
    type_ : Type;
  };

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
    #bool : Bool;
    #float32 : Float;
    #float64 : Float;
    #text : Text;
    #null_;
    #reserved;
    #empty;
    #opt : Value;
    #vector : [Value];
    #record : [RecordFieldValue];
    #variant : VariantOptionValue;
    #func_ : Func;
    #service : Principal;
    #principal : Principal;
  };

  public type RecordFieldValue = {
    tag : Tag.Tag;
    value : Value;
  };

  public type Func = {
    service : Principal;
    method : Text;
  };

  public type VariantOptionValue = RecordFieldValue;

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
    #null_;
    #bool;
    #float32;
    #float64;
    #text;
    #reserved;
    #empty;
    #principal;
  };

  public type CompoundType = {
    #opt : Type;
    #vector : Type;
    #record : [RecordFieldType];
    #variant : [VariantOptionType];
    #func_ : FuncType;
    #service : ServiceType;
    #recursiveType : { id : Text; type_ : CompoundType };
    #recursiveReference : Text;
  };

  public type FuncType = {
    modes : [FuncMode.FuncMode];
    argTypes : [Type];
    returnTypes : [Type];
  };

  public type RecordFieldType = {
    tag : Tag.Tag;
    type_ : Type;
  };

  public type VariantOptionType = RecordFieldType;

  public type ServiceType = {
    methods : [(Text, FuncType)];
  };

  public type Type = CompoundType or PrimitiveType;

  public type ReferenceType = Int;

  public type RecordFieldReferenceType<TReference> = {
    tag : Tag.Tag;
    type_ : TReference;
  };

  public type VariantOptionReferenceType<TReference> = RecordFieldReferenceType<TReference>;

  public type FuncReferenceType<TReference> = {
    modes : [FuncMode.FuncMode];
    argTypes : [TReference];
    returnTypes : [TReference];
  };

  public type ServiceReferenceType<TReference> = {
    methods : [(Text, TReference)];
  };

  public type ShallowCompoundType<TReference> = {
    #opt : TReference;
    #vector : TReference;
    #record : [RecordFieldReferenceType<TReference>];
    #variant : [VariantOptionReferenceType<TReference>];
    #func_ : FuncReferenceType<TReference>;
    #service : ServiceReferenceType<TReference>;
  };

  /// Compares two objects by their tag field.
  /// Returns the order comparison result of the two tags.
  ///
  /// ```motoko
  /// let obj1 = { tag = #name("field1") };
  /// let obj2 = { tag = #name("field2") };
  /// let order = InternalTypes.tagObjCompare(obj1, obj2);
  /// ```
  public func tagObjCompare(o1 : { tag : Tag.Tag }, o2 : { tag : Tag.Tag }) : Order.Order {
    Tag.compare(o1.tag, o2.tag);
  };

  /// Compares two arrays using a custom comparison function.
  /// If `reorder` is true, arrays are sorted before comparison for consistent results.
  /// The comparison function receives a `shallow` flag indicating whether to do a shallow comparison.
  ///
  /// ```motoko
  /// let arr1 = [1, 2, 3];
  /// let arr2 = [3, 2, 1];
  /// let order = InternalTypes.compareArrays(
  ///   arr1,
  ///   arr2,
  ///   func(a, b, shallow) { Nat.compare(a, b) },
  ///   true // reorder for consistent comparison
  /// );
  /// // order is #equal since arrays have same elements
  /// ```
  public func compareArrays<T>(
    a1 : [T],
    a2 : [T],
    compareFunc : (T, T, shallow : Bool) -> Order.Order,
    reorder : Bool,
  ) : Order.Order {
    let sizeOrder = Nat.compare(a1.size(), a2.size());
    if (sizeOrder != #equal) {
      return sizeOrder;
    };
    let (orderedA1, orderedA2) = switch (reorder) {
      case (false) (a1, a2);
      case (true) {
        let sortFunc = func(t1 : T, t2 : T) : Order.Order {
          compareFunc(t1, t2, true);
        };
        (Array.sort(a1, sortFunc), Array.sort(a2, sortFunc));
      };
    };
    for (i in Nat.range(0, orderedA1.size())) {
      let a1I = orderedA1[i];
      let a2I = orderedA2[i];
      let compareResult = compareFunc(a1I, a2I, false);
      if (compareResult != #equal) {
        return compareResult;
      };
    };
    #equal;
  };
};

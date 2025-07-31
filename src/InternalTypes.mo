import Tag "./Tag";
import FuncMode "./FuncMode";
import Order "mo:core/Order";
import Array "mo:core/Array";
import Nat "mo:core/Nat";

module {

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

  public func tagObjCompare(o1 : { tag : Tag.Tag }, o2 : { tag : Tag.Tag }) : Order.Order {
    Tag.compare(o1.tag, o2.tag);
  };

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

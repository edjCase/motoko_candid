import Tag "./Tag";
import FuncMode "./FuncMode";
import Order "mo:base/Order";

module {

  public type ReferenceType = Int;

  public type RecordFieldReferenceType<TReference> = {
    tag: Tag.Tag;
    _type : TReference;
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
    #_func : FuncReferenceType<TReference>;
    #service : ServiceReferenceType<TReference>;
  };



  public func tagObjCompare(o1: {tag: Tag.Tag}, o2: {tag: Tag.Tag}) : Order.Order {
    Tag.compare(o1.tag, o2.tag);
  };
}
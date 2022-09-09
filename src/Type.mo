import FuncMode "./FuncMode";
import Tag "./Tag";
import TypeCode "./TypeCode";
import Order "mo:base/Order";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import Text "mo:base/Text";

module {
  public type FuncType = {
    modes : [FuncMode.FuncMode];
    argTypes : [Type];
    returnTypes : [Type];
  };

  public type RecordFieldType = {
    tag : Tag.Tag;
    _type : Type;
  };

  public type VariantOptionType = RecordFieldType;

  public type ServiceType = {
    methods : [(Text, FuncType)];
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
    #opt : Type;
    #vector : Type;
    #record : [RecordFieldType];
    #variant : [VariantOptionType];
    #_func : FuncType;
    #service : ServiceType;
    #recursiveType : {id: Text; _type: CompoundType};
    #recursiveReference : Text;
  };

  public type Type = CompoundType or PrimitiveType;


  public func equal(v1: Type, v2: Type): Bool {
    switch (v1) {
      case (#opt(o1)) {
        let o2 = switch (v2) {
          case(#opt(o2)) o2;
          case (_) return false;
        };
        equal(o1, o2);
      };
      case (#vector(ve1)) {
        let ve2 = switch (v2) {
          case(#vector(ve)) ve;
          case (_) return false;
        };
        equal(ve1, ve2);
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
          Tag.compare(r1.tag, r2.tag)
        };
        let orderedR1 = Array.sort(r1, orderFunc);
        let orderedR2 = Array.sort(r2, orderFunc);
        for (i in Iter.range(0, orderedR1.size() - 1)) {
          let r1I = orderedR1[i];
          let r2I = orderedR2[i];
          if (not Tag.equal(r1I.tag, r2I.tag)) {
            return false;
          };
          if (not equal(r1I._type, r2I._type)) {
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
          Tag.compare(t1.tag, t2.tag)
        };
        let orderedVa1 = Array.sort(va1, orderFunc);
        let orderedVa2 = Array.sort(va2, orderFunc);
        for (i in Iter.range(0, orderedVa1.size() - 1)) {
          let va1I = orderedVa1[i];
          let va2I = orderedVa2[i];
          if (not Tag.equal(va1I.tag, va2I.tag)) {
            return false;
          };
          if (not equal(va1I._type, va2I._type)) {
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
        equal(r1._type, r2._type);
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

  public func hash(t : Type) : Hash.Hash {
    switch (t) {
      case (#opt(o)) {
        let h = Int.hash(TypeCode.opt);
        let innerHash = hash(o);
        combineHash(h, innerHash);
      };
      case (#vector(v)) {
        let h = Int.hash(TypeCode.vector);
        let innerHash = hash(v);
        combineHash(h, innerHash);
      };
      case (#record(r)) {
        let h = Int.hash(TypeCode.record);
        Array.foldLeft<RecordFieldType, Hash.Hash>(r, h, func (v: Hash.Hash, f: RecordFieldType) : Hash.Hash {
          let innerHash = hash(f._type);
          combineHash(combineHash(v, Tag.hash(f.tag)), innerHash);
        });
      };
      case (#_func(f)) {
        let h = Int.hash(TypeCode._func);
        let h2 = Array.foldLeft<Type, Hash.Hash>(f.argTypes, h, func (v: Hash.Hash, f: Type) : Hash.Hash {
          combineHash(v, hash(f));
        });
        let h3 = Array.foldLeft<Type, Hash.Hash>(f.returnTypes, h2, func (v: Hash.Hash, f: Type) : Hash.Hash {
          combineHash(v, hash(f));
        });
        Array.foldLeft<FuncMode.FuncMode, Hash.Hash>(f.modes, h3, func (v: Hash.Hash, f: FuncMode.FuncMode) : Hash.Hash {
          combineHash(v, Int.hash(switch(f){
            case (#_query) 1;
            case (#oneWay) 2;
          }));
        });
      };
      case (#service(s)) {
        let h = Int.hash(TypeCode.service);
        Array.foldLeft<(Text, FuncType), Hash.Hash>(s.methods, h, func (v: Hash.Hash, f: (Text, FuncType)) : Hash.Hash {
          combineHash(h, combineHash(Text.hash(f.0), hash(#_func(f.1))));
        });
      };
      case (#variant(v)) {
        var h = Int.hash(TypeCode.variant);
        Array.foldLeft<VariantOptionType, Hash.Hash>(v, 0, func (h: Hash.Hash, o: VariantOptionType) : Hash.Hash {
          let innerHash = hash(o._type);
          combineHash(combineHash(h, Tag.hash(o.tag)), innerHash);
        });
      };
      case (#recursiveType(rT)) {
        hash(rT._type);
      };
      case (#recursiveReference(r)) {
        var h = Int.hash(0);
        combineHash(h, Text.hash(r));
      };
      case (#int) Int.hash(TypeCode.int);
      case (#int8) Int.hash(TypeCode.int8);
      case (#int16) Int.hash(TypeCode.int16);
      case (#int32) Int.hash(TypeCode.int32);
      case (#int64) Int.hash(TypeCode.int64);
      case (#nat) Int.hash(TypeCode.nat);
      case (#nat8) Int.hash(TypeCode.nat8);
      case (#nat16) Int.hash(TypeCode.nat16);
      case (#nat32) Int.hash(TypeCode.nat32);
      case (#nat64) Int.hash(TypeCode.nat64);
      case (#_null) Int.hash(TypeCode._null);
      case (#bool) Int.hash(TypeCode.bool);
      case (#float32) Int.hash(TypeCode.float32);
      case (#float64) Int.hash(TypeCode.float64);
      case (#text) Int.hash(TypeCode.text);
      case (#reserved) Int.hash(TypeCode.reserved);
      case (#empty) Int.hash(TypeCode.empty);
      case (#principal) Int.hash(TypeCode.principal);
    };
  };

  private func combineHash(seed: Hash.Hash, value: Hash.Hash) : Hash.Hash {
    // From `C++ Boost Hash Combine`
    seed ^ (value +% 0x9e3779b9 +% (seed << 6) +% (seed >> 2));
  };
}
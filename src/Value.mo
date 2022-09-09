import Tag "./Tag";
import TransparencyState "./TransparencyState";
import FloatX "mo:xtendedNumbers/FloatX";
import Order "mo:base/Order";
import Iter "mo:base/Iter";
import Array "mo:base/Array";

module {
  type Tag = Tag.Tag;
  type TransparencyState<T> = TransparencyState.TransparencyState<T>;

  public type RecordFieldValue = {
    tag: Tag;
    value: Value;
  };

  public type Func = {
    service : TransparencyState<Principal>;
    method : Text;
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
    #_func : TransparencyState<Func>;
    #service : TransparencyState<Principal>;
    #principal : TransparencyState<Principal>;
  };

  public func equal(v1: Value, v2: Value): Bool {
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
              case (?o2) equal(o1, o2);
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
          if (not equal(ve1[i], ve2[i])) {
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
          if (not equal(r1I.value, r2I.value)) {
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
        if (not Tag.equal(va1.tag, va2.tag)) {
          return false;
        };
        if (not equal(va1.value, va2.value)) {
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
}
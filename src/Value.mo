import Array "mo:base/Array";
import FloatX "mo:xtended-numbers/FloatX";
import InternalTypes "InternalTypes";
import Iter "mo:base/Iter";
import Order "mo:base/Order";
import Tag "./Tag";
import TransparencyState "./TransparencyState";
import Type "./Type";
import Buffer "mo:base/Buffer";
import Prelude "mo:base/Prelude";
import Bool "mo:base/Bool";
import Float "mo:base/Float";
import Principal "mo:base/Principal";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import Nat16 "mo:base/Nat16";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Int64 "mo:base/Int64";
import Int32 "mo:base/Int32";
import Int16 "mo:base/Int16";
import Int "mo:base/Int";
import Int8 "mo:base/Int8";
import Debug "mo:base/Debug";
import Text "mo:base/Text";

module {
  type Tag = Tag.Tag;
  type TransparencyState<T> = TransparencyState.TransparencyState<T>;

  public type RecordFieldValue = {
    tag : Tag;
    value : Value;
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

  public func equal(v1 : Value, v2 : Value) : Bool {
    switch (v1) {
      case (#float32(f1)) {
        let f2 = switch (v2) {
          case (#float32(f2)) f2;
          case (#float64(f2)) f2;
          case (_) return false;
        };
        FloatX.nearlyEqual(f1, f2, 0.0000001, 0.000001);
      };
      case (#float64(f1)) {
        let f2 = switch (v2) {
          case (#float32(f2)) f2;
          case (#float64(f2)) f2;
          case (_) return false;
        };
        FloatX.nearlyEqual(f1, f2, 0.0000001, 0.000001);
      };
      case (#opt(o1)) {
        let o2 = switch (v2) {
          case (#opt(o2)) o2;
          case (_) return false;
        };
        switch (o1) {
          case (null) return o2 == null;
          case (?o1) {
            switch (o2) {
              case (null) return false;
              case (?o2) equal(o1, o2);
            };
          };
        };
      };
      case (#vector(ve1)) {
        let ve2 = switch (v2) {
          case (#vector(ve)) ve;
          case (_) return false;
        };
        InternalTypes.arraysAreEqual(
          ve1,
          ve2,
          null, // Dont reorder
          equal,
        );
      };
      case (#record(r1)) {
        let r2 = switch (v2) {
          case (#record(r2)) r2;
          case (_) return false;
        };

        InternalTypes.arraysAreEqual(
          r1,
          r2,
          ?(
            func(t1 : RecordFieldValue, t2 : RecordFieldValue) : Order.Order {
              Tag.compare(t1.tag, t2.tag);
            },
          ),
          func(t1 : RecordFieldValue, t2 : RecordFieldValue) : Bool {
            if (not Tag.equal(t1.tag, t2.tag)) {
              return false;
            };
            equal(t1.value, t2.value);
          },
        );
      };
      case (#variant(va1)) {
        let va2 = switch (v2) {
          case (#variant(va2)) va2;
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
          case (#_func(f2)) f2;
          case (_) return false;
        };
        switch (f1) {
          case (#opaque) f2 == #opaque;
          case (#transparent(t1)) {
            switch (f2) {
              case (#opaque) false;
              case (#transparent(t2)) {
                if (t1.method != t2.method) {
                  false;
                } else {
                  t1.service == t2.service;
                };
              };
            };
          };
        };
      };
      case (#service(s1)) {
        let s2 = switch (v2) {
          case (#service(s2)) s2;
          case (_) return false;
        };
        s1 == s2;
      };
      case (a) a == v2;
    };
  };

  public func toText(value : Value, _type : Type.Type) : Text {
    switch (value) {
      // Nat
      case (#nat(n)) Nat.toText(n);
      case (#nat8(n)) Nat8.toText(n);
      case (#nat16(n)) Nat16.toText(n);
      case (#nat32(n)) Nat32.toText(n);
      case (#nat64(n)) Nat64.toText(n);
      // Int
      case (#int(n)) Int.toText(n);
      case (#int8(n)) Int8.toText(n);
      case (#int16(n)) Int16.toText(n);
      case (#int32(n)) Int32.toText(n);
      case (#int64(n)) Int64.toText(n);
      // Float
      case (#float32(n)) Float.toText(n);
      case (#float64(n)) Float.toText(n);
      // Bool
      case (#bool(b)) Bool.toText(b);
      // Principal
      case (#principal(service)) toTextPrincipal(service);
      // Text
      case (#text(n)) n;
      // Null
      case (#_null) "null";
      // Opt
      case (#opt(optVal)) {
        let innerType : Type.Type = switch (_type) {
          case (#opt(innerType)) innerType;
          case (_) Debug.trap(getTypeMismatchError(_type, value));
        };
        toTextOpt(optVal, innerType);
      };
      // Vector
      case (#vector(arr)) {
        let innerType : Type.Type = switch (_type) {
          case (#vector(innerType)) innerType;
          case (_) Debug.trap(getTypeMismatchError(_type, value));
        };
        toTextVector(arr, innerType);
      };
      // Record
      case (#record(fieldValues)) {
        let fields : [RecordField] = switch (_type) {
          case (#record(fieldTypes)) {
            Iter.toArray(
              Iter.map<Type.RecordFieldType, RecordField>(
                Iter.fromArray(fieldTypes),
                func(t) {
                  let fieldValue = switch (Array.find<RecordFieldValue>(fieldValues, func(v) = v.tag == t.tag)) {
                    case (null) Debug.trap(getTypeMismatchError(_type, value));
                    case (?v) v;
                  };
                  {
                    tag = t.tag;
                    value = fieldValue.value;
                    _type = t._type;
                  };
                },
              ),
            );
          };
          case (_) Debug.trap(getTypeMismatchError(_type, value));
        };
        toTextRecord(fields);
      };
      // Variant
      case (#variant(v)) {
        let optionType : Type.Type = switch (_type) {
          case (#variant(optionTypes)) {
            // Get the matching option type by tag
            switch (Array.find<Type.VariantOptionType>(optionTypes, func(t) = t.tag == v.tag)) {
              case (null) Debug.trap(getTypeMismatchError(_type, value));
              case (?v) v._type;
            };
          };
          case (_) Debug.trap(getTypeMismatchError(_type, value));
        };
        toTextVariant(v.tag, v.value, optionType);
      };
      // Func
      case (#_func(f)) {
        let funcText = toTextTrasparencyState<Func>(
          f,
          func(f) {
            let serviceText : Text = toTextPrincipal(f.service);
            "{ method = " # f.method # "; service = " # serviceText # "}";
          },
        );
        "func " # funcText;
      };
      // Empty
      case (#empty) "empty";
      // Reserved
      case (#reserved) "reserved";
      // Service
      case (#service(s)) toTextService(s);
    };
  };

  private func toTextService(principal : TransparencyState<Principal>) : Text {
    let principalText : Text = toTextPrincipal(principal);
    "service " # principalText;
  };

  private func toTextTrasparencyState<T>(state : TransparencyState<T>, converter : (T) -> Text) : Text {
    switch (state) {
      case (#transparent(p)) converter(p);
      case (#opaque) "opaque";
    };
  };

  private func toTextPrincipal(principal : TransparencyState<Principal>) : Text {
    let principalText : Text = toTextTrasparencyState(principal, Principal.toText);
    "principal " # principalText;
  };

  private func toTextOpt(innerValue : ?Value, innerType : Type.Type) : Text {
    let innerTextValue = switch (innerValue) {
      case (null) "null";
      case (?v) toText(v, innerType);
    };
    "opt " # innerTextValue;
  };

  private func toTextVector(innerValues : [Value], innerType : Type.Type) : Text {
    // Convert each inner value to a Text value
    let textValues = Iter.map<Value, Text>(Iter.fromArray(innerValues), func(v) = toText(v, innerType));
    // ex: [1, 2, 3]
    "[" # Text.join(", ", textValues) # "]";
  };

  private type RecordField = {
    tag : Tag.Tag;
    value : Value;
    _type : Type.Type;
  };

  private func toTextRecord(fields : [RecordField]) : Text {
    // Order fields by tag
    let orderedFields : Iter.Iter<RecordField> = Iter.sort<RecordField>(
      Iter.fromArray(fields),
      func(f1 : RecordField, f2 : RecordField) : Order.Order = Tag.compare(f1.tag, f2.tag),
    );

    // Convert field to text representation
    let orderedTextFields : Iter.Iter<Text> = Iter.map<RecordField, Text>(
      Iter.fromArray(fields),
      func(f : RecordField) : Text {
        let key : Text = Tag.toText(f.tag);
        let valueText : Text = toText(f.value, f._type);
        key # " = " # valueText;
      },
    );

    let fieldsText = Text.join("; ", orderedTextFields);
    "record { " # fieldsText # " }";
  };

  private func toTextVariant(tag : Tag, optionValue : Value, optionType : Type.Type) : Text {
    let key : Text = Tag.toText(tag);
    let valueText : Text = toText(optionValue, optionType);
    "variant { " # key # " = " # valueText # " }";
  };

  private func getTypeMismatchError(_type : Type.Type, value : Value) : Text {
    "Invalid type and value combo. Type: " # debug_show (_type) # " Value: " # debug_show (value);
  };

};

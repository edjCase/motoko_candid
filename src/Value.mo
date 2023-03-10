import Array "mo:base/Array";
import FloatX "mo:xtended-numbers/FloatX";
import InternalTypes "InternalTypes";
import Iter "mo:base/Iter";
import Order "mo:base/Order";
import Tag "./Tag";
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

  public type RecordFieldValue = {
    tag : Tag;
    value : Value;
  };

  public type Func = {
    service : Principal;
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
  public type TagHashMapper = (tagHash : Nat32) -> ?Text;
  public type ToTextOverride = (value : Value) -> ?Text;

  public type ToTextOptions = {
    tagHashMapper : ?TagHashMapper;
    toTextOverride : ?ToTextOverride;
    indented : Bool;
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
        equal(o1, o2);
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
      case (#func_(f1)) {
        let f2 = switch (v2) {
          case (#func_(f2)) f2;
          case (_) return false;
        };
        if (f1.method != f2.method) {
          false;
        } else {
          f1.service == f2.service;
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

  public func toText(value : Value) : Text {
    toTextAdvanced(value, { tagHashMapper = null; toTextOverride = null; indented = false });
  };

  public func toTextIndented(value : Value) : Text {
    toTextAdvanced(value, { tagHashMapper = null; toTextOverride = null; indented = true });
  };

  public func toTextAdvanced(value : Value, options : ToTextOptions) : Text {
    toTextAdvancedInternal(value, options, 0);
  };

  private func toTextAdvancedInternal(value : Value, options : ToTextOptions, depth : Nat) : Text {
    // Check overrides to get value if needed
    switch (options.toTextOverride) {
      case (?o) switch (o(value)) {
        case (?t) return t;
        case (_)();
      };
      case (_)();
    };
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
      // Null
      case (#null_) "null";
      // Empty
      case (#empty) "empty";
      // Reserved
      case (#reserved) "reserved";

      // Principal
      case (#principal(p)) toTextPrincipal(p);
      // Text
      case (#text(n)) "\"" # n # "\"";
      // Opt
      case (#opt(optVal)) toTextOpt(optVal, options, depth);
      // Vector
      case (#vector(values)) toTextVector(values, options, depth);
      // Record
      case (#record(fieldValues)) toTextRecord(fieldValues, options, depth);
      // Variant
      case (#variant(v)) toTextVariant(v.tag, v.value, options, depth);
      // Func
      case (#func_(f)) toTextFunc(f, options, depth);
      // Service
      case (#service(s)) toTextService(s);
    };
  };

  private func toTextFunc(f : Func, options : ToTextOptions, depth : Nat) : Text {
    "func \"" # Principal.toText(f.service) # "\"." # f.method;
  };

  private func toTextService(serviceId : Principal) : Text {
    "service \"" # Principal.toText(serviceId) # "\"";
  };

  private func toTextPrincipal(principal : Principal) : Text {
    "principal \"" # Principal.toText(principal) # "\"";
  };

  private func toTextOpt(innerValue : Value, options : ToTextOptions, depth : Nat) : Text {
    let innerTextValue = toTextAdvancedInternal(innerValue, options, depth + 1);
    "opt " # innerTextValue;
  };

  private func toTextVector(innerValues : [Value], options : ToTextOptions, depth : Nat) : Text {
    // Convert each inner value to a Text value
    let textValues = Iter.map<Value, Text>(Iter.fromArray(innerValues), func(v) = toTextAdvancedInternal(v, options, depth + 1));
    // ex: [1, 2, 3]
    formatObj("vec {", "}", ",", Iter.toArray(textValues), options.indented, depth);
  };

  private func toTextRecord(fields : [RecordFieldValue], options : ToTextOptions, depth : Nat) : Text {
    // Order fields by tag
    let orderedFields : Iter.Iter<RecordFieldValue> = Iter.sort<RecordFieldValue>(
      Iter.fromArray(fields),
      func(f1, f2) = Tag.compare(f1.tag, f2.tag),
    );
    var isTuple = true;
    var i : Nat32 = 0;
    label l for (f in orderedFields) {
      // Check to see if the hashes are 0, 1, 2, etc... if so its a tuple
      if (f.tag != #hash(i)) {
        isTuple := false;
        break l;
      };
      i += 1;
    };
    // Convert field to text representation
    let textItems = if (isTuple) {
      Iter.map<RecordFieldValue, Text>(
        Iter.fromArray(fields),
        func(f : RecordFieldValue) : Text {
          // Just have value, but in order
          toTextAdvancedInternal(f.value, options, depth + 1);
        },
      );
    } else {
      Iter.map<RecordFieldValue, Text>(
        Iter.fromArray(fields),
        func(f : RecordFieldValue) : Text {
          let key : Text = toTextTag(f.tag, options.tagHashMapper);
          let valueText : Text = toTextAdvancedInternal(f.value, options, depth + 1);
          key # " = " # valueText;
        },
      );
    };

    formatObj("record {", "}", ";", Iter.toArray(textItems), options.indented, depth);
  };

  private func toTextVariant(tag : Tag, optionValue : Value, options : ToTextOptions, depth : Nat) : Text {
    let key : Text = toTextTag(tag, options.tagHashMapper);
    let value = switch (optionValue) {
      case (#null_) "";
      case (v) {
        let valueText : Text = toTextAdvancedInternal(optionValue, options, depth + 1);
        " = " # valueText;
      };
    };
    "variant { " # key # value # " }";
  };

  private func toTextTag(tag : Tag, tagHashMapper : ?TagHashMapper) : Text {
    switch (tag) {
      // Return name if set
      case (#name(n)) "\"" # n # "\"";

      case (#hash(id)) {
        switch (tagHashMapper) {
          // If there is no hash -> name mapper, just return the id
          case (null) Nat32.toText(id);
          // Use custom mapper
          case (?m) switch (m(id)) {
            // If there is no name found, just return the id
            case (null) Nat32.toText(id);
            // If there is a name found, use it
            case (?n) n;
          };
        };
      };
    };
  };

  private func formatObj(
    prefix : Text,
    suffix : Text,
    seperator : Text,
    items : [Text],
    indented : Bool,
    depth : Nat,
  ) : Text {
    if (items.size() < 1) {
      return prefix # suffix;
    };
    if (indented) {
      // If indented, always do new line and X tabs depending on depth
      var indentation = "\n";
      if (depth > 0) {
        Iter.iterate<Nat>(
          Iter.range(1, depth),
          func(i) {
            // Add an extra tab per depth
            indentation #= "\t";
          },
        );
      };
      let contents = Text.join(seperator # indentation # "\t", Iter.fromArray(items));
      prefix # indentation # "\t" # contents # indentation # suffix;
    } else {
      let contents = Text.join(seperator # " ", Iter.fromArray(items));

      prefix # " " # contents # " " # suffix;
    };
  };
};

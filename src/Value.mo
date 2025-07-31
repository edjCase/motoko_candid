import FloatX "mo:xtended-numbers/FloatX";
import InternalTypes "InternalTypes";
import Iter "mo:core/Iter";
import Order "mo:core/Order";
import Tag "./Tag";
import Bool "mo:core/Bool";
import Float "mo:core/Float";
import Principal "mo:core/Principal";
import Nat8 "mo:core/Nat8";
import Nat "mo:core/Nat";
import Nat16 "mo:core/Nat16";
import Nat64 "mo:core/Nat64";
import Nat32 "mo:core/Nat32";
import Int64 "mo:core/Int64";
import Int32 "mo:core/Int32";
import Int16 "mo:core/Int16";
import Int "mo:core/Int";
import Int8 "mo:core/Int8";
import Text "mo:core/Text";

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
    compare(v1, v2) == #equal;
  };

  public func compare(v1 : Value, v2 : Value) : Order.Order {
    switch (v1, v2) {
      case (#float32(f1), #float32(f2)) {
        if (FloatX.nearlyEqual(f1, f2, 0.0000001, 0.000001)) {
          #equal;
        } else {
          Float.compare(f1, f2);
        };
      };
      case (#float32(f1), #float64(f2)) {
        if (FloatX.nearlyEqual(f1, f2, 0.0000001, 0.000001)) {
          #equal;
        } else {
          Float.compare(f1, f2);
        };
      };
      case (#float64(f1), #float32(f2)) {
        if (FloatX.nearlyEqual(f1, f2, 0.0000001, 0.000001)) {
          #equal;
        } else {
          Float.compare(f1, f2);
        };
      };
      case (#float64(f1), #float64(f2)) {
        if (FloatX.nearlyEqual(f1, f2, 0.0000001, 0.000001)) {
          #equal;
        } else {
          Float.compare(f1, f2);
        };
      };
      case (#opt(o1), #opt(o2)) {
        compare(o1, o2);
      };
      case (#vector(ve1), #vector(ve2)) {
        InternalTypes.compareArrays(
          ve1,
          ve2,
          func(v1 : Value, v2 : Value, _ : Bool) : Order.Order {
            compare(v1, v2);
          },
          false, // Do not reorder vector elements as order matters
        );
      };
      case (#record(r1), #record(r2)) {
        InternalTypes.compareArrays(
          r1,
          r2,
          func(t1 : RecordFieldValue, t2 : RecordFieldValue, shallow : Bool) : Order.Order {
            switch (Tag.compare(t1.tag, t2.tag)) {
              case (#equal) if (shallow) #equal else compare(t1.value, t2.value);
              case (order) order;
            };
          },
          true, // Reorder for consistent comparison
        );
      };
      case (#variant(va1), #variant(va2)) {
        switch (Tag.compare(va1.tag, va2.tag)) {
          case (#equal) compare(va1.value, va2.value);
          case (order) order;
        };
      };
      case (#func_(f1), #func_(f2)) {
        switch (Text.compare(f1.method, f2.method)) {
          case (#equal) Principal.compare(f1.service, f2.service);
          case (order) order;
        };
      };
      case (#service(s1), #service(s2)) {
        Principal.compare(s1, s2);
      };
      case (#int(n1), #int(n2)) Int.compare(n1, n2);
      case (#int8(n1), #int8(n2)) Int8.compare(n1, n2);
      case (#int16(n1), #int16(n2)) Int16.compare(n1, n2);
      case (#int32(n1), #int32(n2)) Int32.compare(n1, n2);
      case (#int64(n1), #int64(n2)) Int64.compare(n1, n2);
      case (#nat(n1), #nat(n2)) Nat.compare(n1, n2);
      case (#nat8(n1), #nat8(n2)) Nat8.compare(n1, n2);
      case (#nat16(n1), #nat16(n2)) Nat16.compare(n1, n2);
      case (#nat32(n1), #nat32(n2)) Nat32.compare(n1, n2);
      case (#nat64(n1), #nat64(n2)) Nat64.compare(n1, n2);
      case (#bool(b1), #bool(b2)) Bool.compare(b1, b2);
      case (#text(t1), #text(t2)) Text.compare(t1, t2);
      case (#principal(p1), #principal(p2)) Principal.compare(p1, p2);
      case (#null_, #null_) #equal;
      case (#reserved, #reserved) #equal;
      case (#empty, #empty) #equal;
      case (a, b) {
        // For different variant types, use a consistent ordering based on the variant tag
        let getVariantOrder = func(v : Value) : Nat {
          switch (v) {
            case (#null_) 0;
            case (#bool(_)) 1;
            case (#nat(_)) 2;
            case (#nat8(_)) 3;
            case (#nat16(_)) 4;
            case (#nat32(_)) 5;
            case (#nat64(_)) 6;
            case (#int(_)) 7;
            case (#int8(_)) 8;
            case (#int16(_)) 9;
            case (#int32(_)) 10;
            case (#int64(_)) 11;
            case (#float32(_)) 12;
            case (#float64(_)) 13;
            case (#text(_)) 14;
            case (#reserved) 15;
            case (#empty) 16;
            case (#principal(_)) 17;
            case (#opt(_)) 18;
            case (#vector(_)) 19;
            case (#record(_)) 20;
            case (#variant(_)) 21;
            case (#func_(_)) 22;
            case (#service(_)) 23;
          };
        };
        let orderA = getVariantOrder(a);
        let orderB = getVariantOrder(b);
        Nat.compare(orderA, orderB);
      };
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
        case (_) ();
      };
      case (_) ();
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

  private func toTextFunc(f : Func, _ : ToTextOptions, _ : Nat) : Text {
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
        Iter.forEach<Nat>(
          Nat.range(1, depth + 1),
          func(i : Nat) : () {
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

import Array "mo:base/Array";
import FuncMode "./FuncMode";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import Nat32 "mo:base/Nat32";
import InternalTypes "./InternalTypes";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Order "mo:base/Order";
import Tag "./Tag";
import Text "mo:base/Text";
import TypeCode "./TypeCode";
import Util "InternalTypes";

module {
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

  public type Type = CompoundType or PrimitiveType;

  public type TagHashMapper = (tagHash : Nat32) -> ?Text;
  public type ToTextOverride = (value : Type) -> ?Text;

  public type ToTextOptions = {
    tagHashMapper : ?TagHashMapper;
    toTextOverride : ?ToTextOverride;
    indented : Bool;
  };

  public func equal(v1 : Type, v2 : Type) : Bool {
    switch (v1) {
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
        equal(ve1, ve2);
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
            func(t1 : RecordFieldType, t2 : RecordFieldType) : Order.Order {
              Tag.compare(t1.tag, t2.tag);
            },
          ),
          func(t1 : RecordFieldType, t2 : RecordFieldType) : Bool {
            if (not Tag.equal(t1.tag, t2.tag)) {
              return false;
            };
            equal(t1.type_, t2.type_);
          },
        );
      };
      case (#variant(va1)) {
        let va2 = switch (v2) {
          case (#variant(va2)) va2;
          case (_) return false;
        };
        InternalTypes.arraysAreEqual(
          va1,
          va2,
          ?(
            func(t1 : VariantOptionType, t2 : VariantOptionType) : Order.Order {
              Tag.compare(t1.tag, t2.tag);
            },
          ),
          func(t1 : VariantOptionType, t2 : VariantOptionType) : Bool {
            if (not Tag.equal(t1.tag, t2.tag)) {
              return false;
            };
            equal(t1.type_, t2.type_);
          },
        );
      };
      case (#func_(f1)) {
        let f2 = switch (v2) {
          case (#func_(f2)) f2;
          case (_) return false;
        };

        // Mode Types
        let getModeValue = func(m : FuncMode.FuncMode) : Nat {
          switch (m) {
            case (#oneway) 2;
            case (#query_) 1;
          };
        };
        let modesAreEqual = InternalTypes.arraysAreEqual(
          f1.modes,
          f2.modes,
          ?(
            func(m1 : FuncMode.FuncMode, m2 : FuncMode.FuncMode) : Order.Order {
              let mv1 : Nat = getModeValue(m1);
              let mv2 : Nat = getModeValue(m2);
              Nat.compare(mv1, mv2);
            },
          ),
          func(m1 : FuncMode.FuncMode, m2 : FuncMode.FuncMode) : Bool {
            m1 == m2;
          },
        );
        if (not modesAreEqual) {
          return false;
        };
        // Arg Types
        let argTypesAreEqual = InternalTypes.arraysAreEqual(
          f1.argTypes,
          f2.argTypes,
          null, // Dont reorder
          equal,
        );
        if (not argTypesAreEqual) {
          return false;
        };
        // Return types
        InternalTypes.arraysAreEqual(
          f1.returnTypes,
          f2.returnTypes,
          null, // Dont reorder
          equal,
        );
      };
      case (#service(s1)) {
        let s2 = switch (v2) {
          case (#service(s2)) s2;
          case (_) return false;
        };
        Util.arraysAreEqual(
          s1.methods,
          s2.methods,
          ?(
            func(t1 : (Text, FuncType), t2 : (Text, FuncType)) : Order.Order {
              Text.compare(t1.0, t2.0);
            },
          ),
          func(t1 : (Text, FuncType), t2 : (Text, FuncType)) : Bool {
            if (t1.0 != t1.0) {
              false;
            } else {
              equal(#func_(t1.1), #func_(t2.1));
            };
          },
        );
      };
      case (#recursiveType(r1)) {
        let r2 = switch (v2) {
          case (#recursiveType(r2)) r2;
          case (_) return false;
        };
        equal(r1.type_, r2.type_);
      };
      case (#recursiveReference(r1)) {
        let r2 = switch (v2) {
          case (#recursiveReference(r2)) r2;
          case (_) return false;
        };
        true;
      };
      case (a) a == v2;
    };
  };

  public func toText(value : Type) : Text {
    toTextAdvanced(value, { tagHashMapper = null; toTextOverride = null; indented = false });
  };

  public func toTextIndented(value : Type) : Text {
    toTextAdvanced(value, { tagHashMapper = null; toTextOverride = null; indented = true });
  };

  public func toTextAdvanced(value : Type, options : ToTextOptions) : Text {
    toTextAdvancedInternal(value, options, 0);
  };

  private func toTextAdvancedInternal(value : Type, options : ToTextOptions, depth : Nat) : Text {
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
      case (#nat) "nat";
      case (#nat8) "nat8";
      case (#nat16) "nat16";
      case (#nat32) "nat32";
      case (#nat64) "nat64";
      // Int
      case (#int) "int";
      case (#int8) "int8";
      case (#int16) "int16";
      case (#int32) "int32";
      case (#int64) "int64";
      // Float
      case (#float32) "float32";
      case (#float64) "float64";
      // Bool
      case (#bool) "bool";
      // Null
      case (#null_) "null";
      // Empty
      case (#empty) "empty";
      // Reserved
      case (#reserved) "reserved";

      // Principal
      case (#principal) "principal";
      // Text
      case (#text) "text";
      // Opt
      case (#opt(innerType)) toTextOpt(innerType, options, depth);
      // Vector
      case (#vector(innerType)) toTextVector(innerType, options, depth);
      // Record
      case (#record(fieldTypes)) toTextRecord(fieldTypes, options, depth);
      // Variant
      case (#variant(optionTypes)) toTextVariant(optionTypes, options, depth);
      // Func
      case (#func_(f)) toTextFunc(f, options, depth);
      // Service
      case (#service(serviceType)) toTextService(serviceType, options, depth);
      // Recursive Type
      case (#recursiveType(r)) {
        let innerTextType = toTextAdvancedInternal(r.type_, options, depth);
        r.id # "." # innerTextType; // {recursiveId}.{type}
      };
      // Recursive Reference
      case (#recursiveReference(r)) {
        r; // {recursiveId}
      };
    };
  };

  private func toTextFunc(f : FuncType, options : ToTextOptions, depth : Nat) : Text {
    let argsTextArray = Array.map<Type, Text>(
      f.argTypes,
      func(t : Type) : Text {
        toTextAdvancedInternal(t, options, depth + 1);
      },
    );
    let argsText = formatObj("(", ")", ",", argsTextArray, options.indented, depth);
    let returnTypesTextArray = Array.map<Type, Text>(
      f.returnTypes,
      func(t : Type) : Text {
        toTextAdvancedInternal(t, options, depth + 1);
      },
    );
    let returnTypesText = formatObj("(", ")", ",", returnTypesTextArray, options.indented, depth);

    let modes = if (f.modes.size() < 1) {
      "";
    } else {
      " " # Text.join(
        " ",
        Iter.map<FuncMode.FuncMode, Text>(
          Iter.fromArray(f.modes),
          func(m : FuncMode.FuncMode) : Text {
            switch (m) {
              case (#query_) "query";
              case (#oneway) "oneway";
            };
          },
        ),
      );
    };
    argsText # " -> " # returnTypesText # modes;
  };

  private func toTextService(serviceType : ServiceType, options : ToTextOptions, depth : Nat) : Text {
    let methods = Array.map<(Text, FuncType), Text>(
      serviceType.methods,
      func(t : (Text, FuncType)) : Text {
        let (name, funcType) = t;
        let funcText = toTextFunc(funcType, options, depth + 1);
        name # " : " # funcText;
      },
    );
    formatObj("service : {", "}", ";", methods, options.indented, depth);
  };

  private func toTextOpt(innerType : Type, options : ToTextOptions, depth : Nat) : Text {
    let innerTextType = toTextAdvancedInternal(innerType, options, depth + 1);
    "opt " # innerTextType;
  };

  private func toTextVector(innerType : Type, options : ToTextOptions, depth : Nat) : Text {
    let innerTextType = toTextAdvancedInternal(innerType, options, depth + 1);
    "vec " # innerTextType;
  };

  private func toTextRecord(fields : [RecordFieldType], options : ToTextOptions, depth : Nat) : Text {
    toTextRecordOrVariant("record", fields, options, depth, false);
  };

  private func toTextVariant(optionTypes : [VariantOptionType], options : ToTextOptions, depth : Nat) : Text {
    toTextRecordOrVariant("variant", optionTypes, options, depth, true);
  };

  private func toTextRecordOrVariant(prefix : Text, fields : [RecordFieldType], options : ToTextOptions, depth : Nat, ignoreNullTypes : Bool) : Text {
    // Order fields by tag
    let orderedFields : Iter.Iter<RecordFieldType> = Iter.sort<RecordFieldType>(
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
      Iter.map<RecordFieldType, Text>(
        Iter.fromArray(fields),
        func(f : RecordFieldType) : Text {
          // Just have value, but in order
          toTextAdvancedInternal(f.type_, options, depth + 1);
        },
      );
    } else {
      Iter.map<RecordFieldType, Text>(
        Iter.fromArray(fields),
        func(f : RecordFieldType) : Text {
          let key : Text = toTextTag(f.tag, options.tagHashMapper);
          if (ignoreNullTypes and f.type_ == #null_) {
            return key;
          };
          let typeText = toTextAdvancedInternal(f.type_, options, depth + 1);
          key # " : " # typeText;
        },
      );
    };

    formatObj(prefix # " {", "}", ";", Iter.toArray(textItems), options.indented, depth);
  };

  private func toTextTag(tag : Tag.Tag, tagHashMapper : ?TagHashMapper) : Text {
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

  public func hash(t : Type) : Hash.Hash {
    switch (t) {
      case (#opt(o)) {
        let h = hashTypeCode(TypeCode.opt);
        let innerHash = hash(o);
        combineHash(h, innerHash);
      };
      case (#vector(v)) {
        let h = hashTypeCode(TypeCode.vector);
        let innerHash = hash(v);
        combineHash(h, innerHash);
      };
      case (#record(r)) {
        let h = hashTypeCode(TypeCode.record);
        Array.foldLeft<RecordFieldType, Hash.Hash>(
          r,
          h,
          func(v : Hash.Hash, f : RecordFieldType) : Hash.Hash {
            let innerHash = hash(f.type_);
            combineHash(combineHash(v, Tag.hash(f.tag)), innerHash);
          },
        );
      };
      case (#func_(f)) {
        let h = hashTypeCode(TypeCode.func_);
        let h2 = Array.foldLeft<Type, Hash.Hash>(
          f.argTypes,
          h,
          func(v : Hash.Hash, f : Type) : Hash.Hash {
            combineHash(v, hash(f));
          },
        );
        let h3 = Array.foldLeft<Type, Hash.Hash>(
          f.returnTypes,
          h2,
          func(v : Hash.Hash, f : Type) : Hash.Hash {
            combineHash(v, hash(f));
          },
        );
        Array.foldLeft<FuncMode.FuncMode, Hash.Hash>(
          f.modes,
          h3,
          func(v : Hash.Hash, f : FuncMode.FuncMode) : Hash.Hash {
            combineHash(
              v,
              switch (f) {
                case (#query_) 1;
                case (#oneway) 2;
              },
            );
          },
        );
      };
      case (#service(s)) {
        let h = hashTypeCode(TypeCode.service);
        Array.foldLeft<(Text, FuncType), Hash.Hash>(
          s.methods,
          h,
          func(v : Hash.Hash, f : (Text, FuncType)) : Hash.Hash {
            combineHash(h, combineHash(Text.hash(f.0), hash(#func_(f.1))));
          },
        );
      };
      case (#variant(v)) {
        var h = hashTypeCode(TypeCode.variant);
        Array.foldLeft<VariantOptionType, Hash.Hash>(
          v,
          0,
          func(h : Hash.Hash, o : VariantOptionType) : Hash.Hash {
            let innerHash = hash(o.type_);
            combineHash(combineHash(h, Tag.hash(o.tag)), innerHash);
          },
        );
      };
      case (#recursiveType(rT)) {
        hash(rT.type_);
      };
      case (#recursiveReference(r)) {
        Text.hash(r);
      };
      case (#int) hashTypeCode(TypeCode.int);
      case (#int8) hashTypeCode(TypeCode.int8);
      case (#int16) hashTypeCode(TypeCode.int16);
      case (#int32) hashTypeCode(TypeCode.int32);
      case (#int64) hashTypeCode(TypeCode.int64);
      case (#nat) hashTypeCode(TypeCode.nat);
      case (#nat8) hashTypeCode(TypeCode.nat8);
      case (#nat16) hashTypeCode(TypeCode.nat16);
      case (#nat32) hashTypeCode(TypeCode.nat32);
      case (#nat64) hashTypeCode(TypeCode.nat64);
      case (#null_) hashTypeCode(TypeCode.null_);
      case (#bool) hashTypeCode(TypeCode.bool);
      case (#float32) hashTypeCode(TypeCode.float32);
      case (#float64) hashTypeCode(TypeCode.float64);
      case (#text) hashTypeCode(TypeCode.text);
      case (#reserved) hashTypeCode(TypeCode.reserved);
      case (#empty) hashTypeCode(TypeCode.empty);
      case (#principal) hashTypeCode(TypeCode.principal);
    };
  };

  private func hashTypeCode(i : Int) : Hash.Hash {
    Nat32.fromNat(Int.abs(i));
  };

  private func combineHash(seed : Hash.Hash, value : Hash.Hash) : Hash.Hash {
    // From `C++ Boost Hash Combine`
    seed ^ (value +% 0x9e3779b9 +% (seed << 6) +% (seed >> 2));
  };

};

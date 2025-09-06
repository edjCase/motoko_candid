import Array "mo:core@1/Array";
import FuncMode "./FuncMode";
import Int "mo:core@1/Int";
import Nat32 "mo:core@1/Nat32";
import Iter "mo:core@1/Iter";
import Nat "mo:core@1/Nat";
import Order "mo:core@1/Order";
import Tag "./Tag";
import Text "mo:core@1/Text";
import Char "mo:core@1/Char";
import TypeCode "./TypeCode";
import InternalTypes "InternalTypes";

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

  /// Compares two Type values for equality.
  /// Returns true if the types are equal, false otherwise.
  ///
  /// ```motoko
  /// let type1 : Type = #opt(#nat);
  /// let type2 : Type = #opt(#nat);
  /// let areEqual = Type.equal(type1, type2);
  /// // areEqual is true
  /// ```
  public func equal(v1 : Type, v2 : Type) : Bool {
    compare(v1, v2) == #equal;
  };

  /// Compares two Type values and returns an Order.Order value.
  /// Returns #equal if the types are equal, #less if v1 is less than v2, and #greater if v1 is greater than v2.
  /// ```motoko
  /// let type1 : Type = #opt(#nat);
  /// let type2 : Type = #opt(#nat);
  /// let order = Type.compare(type1, type2);
  /// // order is #equal
  /// ```
  public func compare(v1 : Type, v2 : Type) : Order.Order {
    switch (v1, v2) {
      case (#opt(o1), #opt(o2)) {
        compare(o1, o2);
      };
      case (#vector(ve1), #vector(ve2)) {
        compare(ve1, ve2);
      };
      case (#record(r1), #record(r2)) {
        InternalTypes.compareArrays(
          r1,
          r2,
          func(t1 : RecordFieldType, t2 : RecordFieldType, shallow : Bool) : Order.Order {
            switch (Tag.compare(t1.tag, t2.tag)) {
              case (#equal) if (shallow) #equal else compare(t1.type_, t2.type_);
              case (order) order;
            };
          },
          true, // Reorder for consistent comparison
        );
      };
      case (#variant(va1), #variant(va2)) {
        InternalTypes.compareArrays(
          va1,
          va2,
          func(t1 : VariantOptionType, t2 : VariantOptionType, shallow : Bool) : Order.Order {
            switch (Tag.compare(t1.tag, t2.tag)) {
              case (#equal) if (shallow) #equal else compare(t1.type_, t2.type_);
              case (order) order;
            };
          },
          true, // Reorder for consistent comparison
        );
      };
      case (#func_(f1), #func_(f2)) {
        // Compare modes first
        let getModeValue = func(m : FuncMode.FuncMode) : Nat {
          switch (m) {
            case (#query_) 1;
            case (#oneway) 2;
          };
        };
        let modesCompare = InternalTypes.compareArrays(
          f1.modes,
          f2.modes,
          func(m1 : FuncMode.FuncMode, m2 : FuncMode.FuncMode, _ : Bool) : Order.Order {
            let mv1 : Nat = getModeValue(m1);
            let mv2 : Nat = getModeValue(m2);
            Nat.compare(mv1, mv2);
          },
          true, // Reorder for consistent comparison
        );
        switch (modesCompare) {
          case (#equal) {
            // Compare arg types
            let argTypesCompare = InternalTypes.compareArrays(
              f1.argTypes,
              f2.argTypes,
              func(t1 : Type, t2 : Type, _ : Bool) : Order.Order {
                compare(t1, t2);
              },
              false, // Do not reorder arg types for comparison because order matters
            );
            switch (argTypesCompare) {
              case (#equal) {
                // Compare return types
                InternalTypes.compareArrays(
                  f1.returnTypes,
                  f2.returnTypes,
                  func(t1 : Type, t2 : Type, _ : Bool) : Order.Order {
                    compare(t1, t2);
                  },
                  false, // Do not reorder return types for comparison because order matters
                );
              };
              case (order) order;
            };
          };
          case (order) order;
        };
      };
      case (#service(s1), #service(s2)) {
        InternalTypes.compareArrays(
          s1.methods,
          s2.methods,
          func(t1 : (Text, FuncType), t2 : (Text, FuncType), shallow : Bool) : Order.Order {
            switch (Text.compare(t1.0, t2.0)) {
              case (#equal) if (shallow) #equal else compare(#func_(t1.1), #func_(t2.1));
              case (order) order;
            };
          },
          true,
        );
      };
      case (#recursiveType(r1), #recursiveType(r2)) {
        switch (Text.compare(r1.id, r2.id)) {
          case (#equal) compare(r1.type_, r2.type_);
          case (order) order;
        };
      };
      case (#recursiveReference(r1), #recursiveReference(r2)) {
        Text.compare(r1, r2);
      };
      case (a, b) {
        // For primitive types and different variant types, use hash-based ordering
        let h1 = hash(a);
        let h2 = hash(b);
        Nat32.compare(h1, h2);
      };
    };
  };

  /// Converts a Type value to its text representation.
  ///
  /// ```motoko
  /// let type : Type = #opt(#nat);
  /// let text = Type.toText(type);
  /// // text is "opt nat"
  /// ```
  public func toText(value : Type) : Text {
    toTextAdvanced(value, { tagHashMapper = null; toTextOverride = null; indented = false });
  };

  /// Converts a Type value to its indented text representation.
  ///
  /// ```motoko
  /// let type : Type = #record([{tag = #name("nat"); type_ = #nat}, {tag = #name("text"); type_ = #text}]);
  /// let text = Type.toTextIndented(type);
  /// // text is "record {\n  nat : nat;\n  text : text;\n}"
  /// ```
  public func toTextIndented(value : Type) : Text {
    toTextAdvanced(value, { tagHashMapper = null; toTextOverride = null; indented = true });
  };

  /// Converts a Type value to its text representation with advanced options.
  /// The `tagHashMapper` function can be used to map tag hashes to names (since tags are encoded as hashes in candid).
  /// The `toTextOverride` function can be used to override the text representation of a type.
  /// The `indented` flag can be used to format the text representation with indentation.
  ///
  /// ```motoko
  /// let type : Type = #record([{tag = #name("nat"); type_ = #nat}, {tag = #name("text"); type_ = #text}]);
  /// let options : ToTextOptions = { tagHashMapper = ?(func (t : Tag) : Text { "field_" # Nat32.toText(t) }); toTextOverride = null; indented = true };
  /// let text = Type.toTextAdvanced(type, options);
  /// // text is "record {\n  field_name : nat;\n  field_text : text;\n}"
  /// ```
  public func toTextAdvanced(value : Type, options : ToTextOptions) : Text {
    toTextAdvancedInternal(value, options, 0);
  };

  private func toTextAdvancedInternal(value : Type, options : ToTextOptions, depth : Nat) : Text {
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

  public func hash(t : Type) : Nat32 {
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
        Array.foldLeft<RecordFieldType, Nat32>(
          r,
          h,
          func(v : Nat32, f : RecordFieldType) : Nat32 {
            let innerHash = hash(f.type_);
            combineHash(combineHash(v, Tag.hash(f.tag)), innerHash);
          },
        );
      };
      case (#func_(f)) {
        let h = hashTypeCode(TypeCode.func_);
        let h2 = Array.foldLeft<Type, Nat32>(
          f.argTypes,
          h,
          func(v : Nat32, f : Type) : Nat32 {
            combineHash(v, hash(f));
          },
        );
        let h3 = Array.foldLeft<Type, Nat32>(
          f.returnTypes,
          h2,
          func(v : Nat32, f : Type) : Nat32 {
            combineHash(v, hash(f));
          },
        );
        Array.foldLeft<FuncMode.FuncMode, Nat32>(
          f.modes,
          h3,
          func(v : Nat32, f : FuncMode.FuncMode) : Nat32 {
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
        Array.foldLeft<(Text, FuncType), Nat32>(
          s.methods,
          h,
          func(v : Nat32, f : (Text, FuncType)) : Nat32 {
            combineHash(h, combineHash(hashText(f.0), hash(#func_(f.1))));
          },
        );
      };
      case (#variant(v)) {
        var h = hashTypeCode(TypeCode.variant);
        Array.foldLeft<VariantOptionType, Nat32>(
          v,
          0,
          func(h : Nat32, o : VariantOptionType) : Nat32 {
            let innerHash = hash(o.type_);
            combineHash(combineHash(h, Tag.hash(o.tag)), innerHash);
          },
        );
      };
      case (#recursiveType(rT)) {
        hash(rT.type_);
      };
      case (#recursiveReference(r)) {
        hashText(r);
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

  private func hashTypeCode(i : Int) : Nat32 {
    Nat32.fromNat(Int.abs(i));
  };

  private func combineHash(seed : Nat32, value : Nat32) : Nat32 {
    // From `C++ Boost Hash Combine`
    seed ^ (value +% 0x9e3779b9 +% (seed << 6) +% (seed >> 2));
  };

  public func hashText(t : Text) : Nat32 {
    var x : Nat32 = 5381;
    for (char in t.chars()) {
      let c : Nat32 = Char.toNat32(char);
      x := ((x << 5) +% x) +% c;
    };
    return x;
  };

};

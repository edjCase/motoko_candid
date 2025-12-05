import FloatX "mo:xtended-numbers@2/FloatX";
import InternalTypes "InternalTypes";
import Iter "mo:core@1/Iter";
import Order "mo:core@1/Order";
import Tag "./Tag";
import Bool "mo:core@1/Bool";
import Float "mo:core@1/Float";
import Principal "mo:core@1/Principal";
import Nat8 "mo:core@1/Nat8";
import Nat "mo:core@1/Nat";
import Nat16 "mo:core@1/Nat16";
import Nat64 "mo:core@1/Nat64";
import Nat32 "mo:core@1/Nat32";
import Int64 "mo:core@1/Int64";
import Int32 "mo:core@1/Int32";
import Int16 "mo:core@1/Int16";
import Int "mo:core@1/Int";
import Int8 "mo:core@1/Int8";
import Text "mo:core@1/Text";
import Result "mo:core@1/Result";
import Array "mo:core@1/Array";
import Char "mo:core@1/Char";

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

  /// Compares two Value objects for equality.
  /// Returns true if the values are equal, false otherwise.
  /// Floating point values are compared with a tolerance for near-equality.
  ///
  /// ```motoko
  /// let value1 : Value = #nat(42);
  /// let value2 : Value = #nat(42);
  /// let areEqual = Value.equal(value1, value2);
  /// // areEqual is true
  /// ```
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

  /// Parse a Value from its Text representation
  ///
  /// ```motoko
  /// let result = Value.fromText("record { age = 30; name = \"Alice\"; }");
  /// let value : Value.Value = switch (result) {
  ///   case (#ok(v)) v;
  ///   case (#err(e)) *... Failed to parse value ...*;
  /// ```
  public func fromText(text : Text) : Result.Result<Value, Text> {
    switch (parseValue(text, 0)) {
      case (#ok((value, pos))) {
        let finalPos = skipWhitespace(text, pos);
        if (finalPos < text.size()) {
          #err("Unexpected input after value at position " # Nat.toText(finalPos));
        } else {
          #ok(value);
        };
      };
      case (#err(e)) #err(e);
    };
  };

  /// Converts a Value to its text representation.
  /// This function produces a compact, single-line text representation of the value.
  ///
  /// ```motoko
  /// let value : Value = #record([{ tag = #name("age"); value = #nat(30) }]);
  /// let text = Value.toText(value);
  /// // text is "record { age = 30 }"
  /// ```
  public func toText(value : Value) : Text {
    toTextAdvanced(value, { tagHashMapper = null; toTextOverride = null; indented = false });
  };

  /// Converts a Value to its indented text representation.
  /// This function produces a multi-line, indented text representation for better readability.
  ///
  /// ```motoko
  /// let value : Value = #record([{ tag = #name("age"); value = #nat(30) }, { tag = #name("name"); value = #text("Alice") }]);
  /// let text = Value.toTextIndented(value);
  /// // text is "record {\n\tage = 30;\n\tname = \"Alice\"\n}"
  /// ```
  public func toTextIndented(value : Value) : Text {
    toTextAdvanced(value, { tagHashMapper = null; toTextOverride = null; indented = true });
  };

  /// Converts a Value to its text representation with advanced customization options.
  /// The `tagHashMapper` function can be used to map tag hashes to custom names.
  /// The `toTextOverride` function can be used to override the text representation of specific values.
  /// The `indented` flag controls whether the output is formatted with indentation.
  ///
  /// ```motoko
  /// let value : Value = #record([{ tag = #hash(12345); value = #nat(30) }]);
  /// let options : ToTextOptions = {
  ///   tagHashMapper = ?(func(h : Nat32) : ?Text { if (h == 12345) ?"age" else null });
  ///   toTextOverride = null;
  ///   indented = true
  /// };
  /// let text = Value.toTextAdvanced(value, options);
  /// // text is "record {\n\tage = 30\n}"
  /// ```
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

  // Helper to skip whitespace and comments
  private func skipWhitespace(input : Text, start : Nat) : Nat {
    var pos = start;
    let chars = Text.toArray(input);
    let len = chars.size();

    label w while (pos < len) {
      let c = chars[pos];
      // Skip whitespace
      if (Char.isWhitespace(c)) {
        pos += 1;
        continue w;
      };
      // Skip // comments
      if (pos + 1 < len and c == '/' and chars[pos + 1] == '/') {
        pos += 2;
        while (pos < len and chars[pos] != '\n') {
          pos += 1;
        };
        continue w;
      };
      // Skip /* */ comments (with nesting)
      if (pos + 1 < len and c == '/' and chars[pos + 1] == '*') {
        pos += 2;
        var depth = 1;
        while (pos + 1 < len and depth > 0) {
          if (chars[pos] == '/' and chars[pos + 1] == '*') {
            depth += 1;
            pos += 2;
          } else if (chars[pos] == '*' and chars[pos + 1] == '/') {
            depth -= 1;
            pos += 2;
          } else {
            pos += 1;
          };
        };
        continue w;
      };
      break w;
    };
    pos;
  };

  private func parseChar(expected : Char, input : Text, start : Nat) : Result.Result<Nat, Text> {
    let pos = skipWhitespace(input, start);
    let chars = Text.toArray(input);
    if (pos >= chars.size()) {
      return #err("Unexpected end of input, expected '" # Char.toText(expected) # "'");
    };
    if (chars[pos] != expected) {
      return #err("Expected '" # Char.toText(expected) # "' at position " # Nat.toText(pos));
    };
    #ok(pos + 1);
  };

  private func parseKeyword(keyword : Text, input : Text, start : Nat) : Result.Result<Nat, Text> {
    let pos = skipWhitespace(input, start);
    let chars = Text.toArray(input);
    let kwChars = Text.toArray(keyword);

    if (pos + kwChars.size() > chars.size()) {
      return #err("Unexpected end of input, expected '" # keyword # "'");
    };

    for (i in kwChars.keys()) {
      if (chars[pos + i] != kwChars[i]) {
        return #err("Expected '" # keyword # "' at position " # Nat.toText(pos));
      };
    };

    let nextPos = pos + kwChars.size();
    // Check that keyword is not followed by identifier character
    if (nextPos < chars.size()) {
      let nextChar = chars[nextPos];
      if (Char.isAlphabetic(nextChar) or nextChar == '_' or Char.isDigit(nextChar)) {
        return #err("Expected '" # keyword # "' at position " # Nat.toText(pos));
      };
    };

    #ok(nextPos);
  };

  private func parseNat(input : Text, start : Nat) : Result.Result<(Nat, Nat), Text> {
    let pos = skipWhitespace(input, start);
    let chars = Text.toArray(input);

    if (pos >= chars.size()) {
      return #err("Expected number");
    };

    var current = pos;
    var numText = "";
    let isHex = current + 1 < chars.size() and chars[current] == '0' and (chars[current + 1] == 'x' or chars[current + 1] == 'X');

    if (isHex) {
      current += 2;
      label w while (current < chars.size()) {
        let c = chars[current];
        if (Char.isDigit(c) or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F')) {
          numText #= Char.toText(c);
          current += 1;
        } else if (c == '_') {
          current += 1;
        } else {
          break w;
        };
      };

      switch (parseHexNat(numText)) {
        case (#ok(n)) #ok((n, current));
        case (#err(e)) #err(e);
      };
    } else {
      label w while (current < chars.size()) {
        let c = chars[current];
        if (Char.isDigit(c)) {
          numText #= Char.toText(c);
          current += 1;
        } else if (c == '_') {
          current += 1;
        } else {
          break w;
        };
      };

      if (numText == "") {
        return #err("Expected number at position " # Nat.toText(pos));
      };

      switch (Nat.fromText(numText)) {
        case (?n) #ok((n, current));
        case null #err("Invalid number: " # numText);
      };
    };
  };

  private func parseHexNat(hex : Text) : Result.Result<Nat, Text> {
    var result : Nat = 0;
    for (c in hex.chars()) {
      result *= 16;
      if (c >= '0' and c <= '9') {
        result += Nat32.toNat(Char.toNat32(c) - Char.toNat32('0'));
      } else if (c >= 'a' and c <= 'f') {
        result += Nat32.toNat(Char.toNat32(c) - Char.toNat32('a')) + 10;
      } else if (c >= 'A' and c <= 'F') {
        result += Nat32.toNat(Char.toNat32(c) - Char.toNat32('A')) + 10;
      } else {
        return #err("Invalid hex digit: " # Char.toText(c));
      };
    };
    #ok(result);
  };

  private func parseInt(input : Text, start : Nat) : Result.Result<(Int, Nat), Text> {
    let pos = skipWhitespace(input, start);
    let chars = Text.toArray(input);

    if (pos >= chars.size()) {
      return #err("Expected number");
    };

    var current = pos;
    var isNegative = false;

    if (chars[current] == '-') {
      isNegative := true;
      current += 1;
    } else if (chars[current] == '+') {
      current += 1;
    };

    switch (parseNat(input, current)) {
      case (#ok((n, newPos))) {
        let value = if (isNegative) { -n } else { n };
        #ok((value, newPos));
      };
      case (#err(e)) #err(e);
    };
  };

  private func parseFloat(input : Text, start : Nat) : Result.Result<(Float, Nat), Text> {
    let pos = skipWhitespace(input, start);
    let chars = Text.toArray(input);

    if (pos >= chars.size()) {
      return #err("Expected number");
    };

    var current = pos;
    var numText = "";

    // Handle sign
    if (chars[current] == '-' or chars[current] == '+') {
      numText #= Char.toText(chars[current]);
      current += 1;
    };

    // Check for hex float
    let isHex = current + 1 < chars.size() and chars[current] == '0' and (chars[current + 1] == 'x' or chars[current + 1] == 'X');

    if (isHex) {
      numText #= "0x";
      current += 2;

      // Hex digits before decimal
      label w while (current < chars.size()) {
        let c = chars[current];
        if (Char.isDigit(c) or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F')) {
          numText #= Char.toText(c);
          current += 1;
        } else if (c == '_') {
          current += 1;
        } else {
          break w;
        };
      };

      // Decimal point
      if (current < chars.size() and chars[current] == '.') {
        numText #= ".";
        current += 1;

        label w while (current < chars.size()) {
          let c = chars[current];
          if (Char.isDigit(c) or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F')) {
            numText #= Char.toText(c);
            current += 1;
          } else if (c == '_') {
            current += 1;
          } else {
            break w;
          };
        };
      };

      // Exponent (p or P for hex)
      if (current < chars.size() and (chars[current] == 'p' or chars[current] == 'P')) {
        numText #= Char.toText(chars[current]);
        current += 1;

        if (current < chars.size() and (chars[current] == '+' or chars[current] == '-')) {
          numText #= Char.toText(chars[current]);
          current += 1;
        };

        while (current < chars.size() and Char.isDigit(chars[current])) {
          numText #= Char.toText(chars[current]);
          current += 1;
        };
      };
    } else {
      // Regular decimal float
      while (current < chars.size() and (Char.isDigit(chars[current]) or chars[current] == '_')) {
        if (chars[current] != '_') {
          numText #= Char.toText(chars[current]);
        };
        current += 1;
      };

      // Decimal point
      if (current < chars.size() and chars[current] == '.') {
        numText #= ".";
        current += 1;

        while (current < chars.size() and (Char.isDigit(chars[current]) or chars[current] == '_')) {
          if (chars[current] != '_') {
            numText #= Char.toText(chars[current]);
          };
          current += 1;
        };
      };

      // Exponent
      if (current < chars.size() and (chars[current] == 'e' or chars[current] == 'E')) {
        numText #= Char.toText(chars[current]);
        current += 1;

        if (current < chars.size() and (chars[current] == '+' or chars[current] == '-')) {
          numText #= Char.toText(chars[current]);
          current += 1;
        };

        while (current < chars.size() and (Char.isDigit(chars[current]) or chars[current] == '_')) {
          if (chars[current] != '_') {
            numText #= Char.toText(chars[current]);
          };
          current += 1;
        };
      };
    };

    switch (FloatX.fromText(numText, #f64)) {
      case (?f) #ok((FloatX.toFloat(f), current));
      case (null) #err("Invalid float: " # numText);
    };
  };

  private func parseText(input : Text, start : Nat) : Result.Result<(Text, Nat), Text> {
    let pos = skipWhitespace(input, start);
    let chars = Text.toArray(input);

    if (pos >= chars.size() or chars[pos] != '\"') {
      return #err("Expected '\"' at position " # Nat.toText(pos));
    };

    var current = pos + 1;
    var result = "";

    while (current < chars.size()) {
      let c = chars[current];

      if (c == '\"') {
        return #ok((result, current + 1));
      } else if (c == '\\') {
        current += 1;
        if (current >= chars.size()) {
          return #err("Unexpected end of string");
        };

        let escaped = chars[current];
        switch (escaped) {
          case ('n') { result #= "\n"; current += 1 };
          case ('r') { result #= "\r"; current += 1 };
          case ('t') { result #= "\t"; current += 1 };
          case ('\\') { result #= "\\"; current += 1 };
          case ('\"') { result #= "\""; current += 1 };
          case ('\'') { result #= "'"; current += 1 };
          case ('u') {
            if (current + 1 < chars.size() and chars[current + 1] == '{') {
              current += 2;
              var hexCode = "";
              while (current < chars.size() and chars[current] != '}') {
                hexCode #= Char.toText(chars[current]);
                current += 1;
              };
              if (current >= chars.size()) {
                return #err("Unclosed unicode escape");
              };
              current += 1;

              switch (parseHexNat(hexCode)) {
                case (#ok(codepoint)) {
                  result #= Text.fromChar(Char.fromNat32(Nat32.fromNat(codepoint)));
                };
                case (#err(e)) return #err(e);
              };
            } else {
              return #err("Invalid unicode escape");
            };
          };
          case _ {
            // \xHH format
            if (Char.isDigit(escaped) or (escaped >= 'a' and escaped <= 'f') or (escaped >= 'A' and escaped <= 'F')) {
              if (current + 1 >= chars.size()) {
                return #err("Invalid hex escape");
              };
              let hex1 = escaped;
              let hex2 = chars[current + 1];
              let hexStr = Char.toText(hex1) # Char.toText(hex2);
              switch (parseHexNat(hexStr)) {
                case (#ok(byte)) {
                  result #= Text.fromChar(Char.fromNat32(Nat32.fromNat(byte)));
                  current += 2;
                };
                case (#err(e)) return #err(e);
              };
            } else {
              return #err("Invalid escape sequence: \\" # Char.toText(escaped));
            };
          };
        };
      } else {
        result #= Char.toText(c);
        current += 1;
      };
    };

    #err("Unclosed string");
  };

  private func parseValue(input : Text, start : Nat) : Result.Result<(Value, Nat), Text> {
    let pos = skipWhitespace(input, start);
    let chars = Text.toArray(input);

    if (pos >= chars.size()) {
      return #err("Unexpected end of input");
    };

    // Try parenthesized value (possibly with type annotation)
    if (chars[pos] == '(') {
      switch (parseChar('(', input, pos)) {
        case (#ok(pos1)) {
          switch (parseValue(input, pos1)) {
            case (#ok((val, pos2))) {
              // Check for type annotation
              let pos3 = skipWhitespace(input, pos2);
              if (pos3 < chars.size() and chars[pos3] == ':') {
                // Skip type annotation - we ignore it
                var current = pos3 + 1;
                var depth = 0;
                label w while (current < chars.size()) {
                  if (chars[current] == '(') depth += 1 else if (chars[current] == ')') {
                    if (depth == 0) break w else depth -= 1;
                  };
                  current += 1;
                };
                switch (parseChar(')', input, current)) {
                  case (#ok(pos4)) #ok((val, pos4));
                  case (#err(e)) #err(e);
                };
              } else {
                switch (parseChar(')', input, pos2)) {
                  case (#ok(pos3)) #ok((val, pos3));
                  case (#err(e)) #err(e);
                };
              };
            };
            case (#err(e)) #err(e);
          };
        };
        case (#err(e)) #err(e);
      };
    }
    // Try keywords
    else if (pos + 4 <= chars.size() and Text.fromIter(Array.sliceToArray(chars, pos, pos + 4).vals()) == "true") {
      switch (parseKeyword("true", input, pos)) {
        case (#ok(newPos)) #ok((#bool(true), newPos));
        case (#err(e)) #err(e);
      };
    } else if (pos + 5 <= chars.size() and Text.fromIter(Array.sliceToArray(chars, pos, pos + 5).vals()) == "false") {
      switch (parseKeyword("false", input, pos)) {
        case (#ok(newPos)) #ok((#bool(false), newPos));
        case (#err(e)) #err(e);
      };
    } else if (pos + 4 <= chars.size() and Text.fromIter(Array.sliceToArray(chars, pos, pos + 4).vals()) == "null") {
      switch (parseKeyword("null", input, pos)) {
        case (#ok(newPos)) #ok((#null_, newPos));
        case (#err(e)) #err(e);
      };
    } else if (pos + 3 <= chars.size() and Text.fromIter(Array.sliceToArray(chars, pos, pos + 3).vals()) == "opt") {
      parseOptValue(input, pos);
    } else if (pos + 3 <= chars.size() and Text.fromIter(Array.sliceToArray(chars, pos, pos + 3).vals()) == "vec") {
      parseVecValue(input, pos);
    } else if (pos + 6 <= chars.size() and Text.fromIter(Array.sliceToArray(chars, pos, pos + 6).vals()) == "record") {
      parseRecordValue(input, pos);
    } else if (pos + 7 <= chars.size() and Text.fromIter(Array.sliceToArray(chars, pos, pos + 7).vals()) == "variant") {
      parseVariantValue(input, pos);
    } else if (pos + 4 <= chars.size() and Text.fromIter(Array.sliceToArray(chars, pos, pos + 4).vals()) == "blob") {
      parseBlobValue(input, pos);
    } else if (pos + 7 <= chars.size() and Text.fromIter(Array.sliceToArray(chars, pos, pos + 7).vals()) == "service") {
      parseServiceValue(input, pos);
    } else if (pos + 4 <= chars.size() and Text.fromIter(Array.sliceToArray(chars, pos, pos + 4).vals()) == "func") {
      parseFuncValue(input, pos);
    } else if (pos + 9 <= chars.size() and Text.fromIter(Array.sliceToArray(chars, pos, pos + 9).vals()) == "principal") {
      parsePrincipalValue(input, pos);
    }
    // Try string
    else if (chars[pos] == '\"') {
      switch (parseText(input, pos)) {
        case (#ok((t, newPos))) #ok((#text(t), newPos));
        case (#err(e)) #err(e);
      };
    }
    // Try number (int, nat, or float)
    else {
      parseNumericValue(input, pos);
    };
  };

  private func parseNumericValue(input : Text, start : Nat) : Result.Result<(Value, Nat), Text> {
    let pos = skipWhitespace(input, start);
    let chars = Text.toArray(input);

    // Look ahead to determine if it's a float
    var current = pos;
    var hasSign = false;
    var hasDecimal = false;
    var hasExp = false;

    if (current < chars.size() and (chars[current] == '+' or chars[current] == '-')) {
      hasSign := true;
      current += 1;
    };

    // Check for hex
    let isHex = current + 1 < chars.size() and chars[current] == '0' and (chars[current + 1] == 'x' or chars[current + 1] == 'X');

    if (isHex) {
      current += 2;
      label w while (current < chars.size()) {
        let c = chars[current];
        if (Char.isDigit(c) or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F') or c == '_') {
          current += 1;
        } else if (c == '.') {
          hasDecimal := true;
          current += 1;
        } else if (c == 'p' or c == 'P') {
          hasExp := true;
          break w;
        } else {
          break w;
        };
      };
    } else {
      label w while (current < chars.size()) {
        let c = chars[current];
        if (Char.isDigit(c) or c == '_') {
          current += 1;
        } else if (c == '.') {
          hasDecimal := true;
          current += 1;
        } else if (c == 'e' or c == 'E') {
          hasExp := true;
          break w;
        } else {
          break w;
        };
      };
    };

    if (hasDecimal or hasExp) {
      switch (parseFloat(input, pos)) {
        case (#ok((f, newPos))) #ok((#float64(f), newPos));
        case (#err(e)) #err(e);
      };
    } else if (hasSign) {
      switch (parseInt(input, pos)) {
        case (#ok((i, newPos))) #ok((#int(i), newPos));
        case (#err(e)) #err(e);
      };
    } else {
      switch (parseNat(input, pos)) {
        case (#ok((n, newPos))) #ok((#nat(n), newPos));
        case (#err(e)) #err(e);
      };
    };
  };

  private func parseOptValue(input : Text, start : Nat) : Result.Result<(Value, Nat), Text> {
    switch (parseKeyword("opt", input, start)) {
      case (#ok(pos)) {
        switch (parseValue(input, pos)) {
          case (#ok((val, newPos))) #ok((#opt(val), newPos));
          case (#err(e)) #err(e);
        };
      };
      case (#err(e)) #err(e);
    };
  };

  private func parseVecValue(input : Text, start : Nat) : Result.Result<(Value, Nat), Text> {
    switch (parseKeyword("vec", input, start)) {
      case (#ok(pos1)) {
        switch (parseChar('{', input, pos1)) {
          case (#ok(pos2)) {
            var values : [Value] = [];
            var current = pos2;

            label l loop {
              let pos3 = skipWhitespace(input, current);
              let chars = Text.toArray(input);

              if (pos3 < chars.size() and chars[pos3] == '}') {
                current := pos3;
                break l;
              };

              switch (parseValue(input, pos3)) {
                case (#ok((val, pos4))) {
                  values := Array.concat(values, [val]);

                  let pos5 = skipWhitespace(input, pos4);
                  if (pos5 < chars.size() and chars[pos5] == ';') {
                    current := pos5 + 1;
                  } else {
                    current := pos5;
                  };
                };
                case (#err(e)) return #err(e);
              };
            };

            switch (parseChar('}', input, current)) {
              case (#ok(pos6)) #ok((#vector(values), pos6));
              case (#err(e)) #err(e);
            };
          };
          case (#err(e)) #err(e);
        };
      };
      case (#err(e)) #err(e);
    };
  };

  private func parseRecordValue(input : Text, start : Nat) : Result.Result<(Value, Nat), Text> {
    switch (parseKeyword("record", input, start)) {
      case (#ok(pos1)) {
        switch (parseChar('{', input, pos1)) {
          case (#ok(pos2)) {
            var fields : [RecordFieldValue] = [];
            var current = pos2;
            var nextId : Nat32 = 0;

            label l loop {
              let pos3 = skipWhitespace(input, current);
              let chars = Text.toArray(input);

              if (pos3 < chars.size() and chars[pos3] == '}') {
                current := pos3;
                break l;
              };

              // Try to parse field id (nat or name) or just value (for tuple)
              let fieldResult = if (pos3 < chars.size() and chars[pos3] == '\"') {
                // Named field
                switch (parseText(input, pos3)) {
                  case (#ok((name, pos4))) {
                    let tag = #name(name) : Tag;
                    switch (parseChar('=', input, pos4)) {
                      case (#ok(pos5)) {
                        switch (parseValue(input, pos5)) {
                          case (#ok((val, pos6))) #ok((tag, val, pos6));
                          case (#err(e)) #err(e);
                        };
                      };
                      case (#err(e)) #err(e);
                    };
                  };
                  case (#err(e)) #err(e);
                };
              } else {
                // Try numeric field id
                let natResult = parseNat(input, pos3);
                switch (natResult) {
                  case (#ok((id, pos4))) {
                    let pos5 = skipWhitespace(input, pos4);
                    if (pos5 < chars.size() and chars[pos5] == '=') {
                      // Explicit field id
                      switch (parseChar('=', input, pos4)) {
                        case (#ok(pos6)) {
                          switch (parseValue(input, pos6)) {
                            case (#ok((val, pos7))) {
                              #ok((#hash(Nat32.fromNat(id)), val, pos7));
                            };
                            case (#err(e)) #err(e);
                          };
                        };
                        case (#err(e)) #err(e);
                      };
                    } else {
                      // Just a value (tuple), backtrack and parse as value
                      switch (parseValue(input, pos3)) {
                        case (#ok((val, pos4))) {
                          let tag = #hash(nextId);
                          #ok((tag, val, pos4));
                        };
                        case (#err(e)) #err(e);
                      };
                    };
                  };
                  case (#err(_)) {
                    // Not a number, must be a value (tuple)
                    switch (parseValue(input, pos3)) {
                      case (#ok((val, pos4))) {
                        let tag = #hash(nextId);
                        #ok((tag, val, pos4));
                      };
                      case (#err(e)) #err(e);
                    };
                  };
                };
              };

              switch (fieldResult) {
                case (#ok((tag, val, pos4))) {
                  fields := Array.concat(fields, [{ tag = tag; value = val }]);
                  nextId += 1;

                  let pos5 = skipWhitespace(input, pos4);
                  if (pos5 < chars.size() and chars[pos5] == ';') {
                    current := pos5 + 1;
                  } else {
                    current := pos5;
                  };
                };
                case (#err(e)) return #err(e);
              };
            };

            switch (parseChar('}', input, current)) {
              case (#ok(pos6)) #ok((#record(fields), pos6));
              case (#err(e)) #err(e);
            };
          };
          case (#err(e)) #err(e);
        };
      };
      case (#err(e)) #err(e);
    };
  };

  private func parseVariantValue(input : Text, start : Nat) : Result.Result<(Value, Nat), Text> {
    switch (parseKeyword("variant", input, start)) {
      case (#ok(pos1)) {
        switch (parseChar('{', input, pos1)) {
          case (#ok(pos2)) {
            let pos3 = skipWhitespace(input, pos2);
            let chars = Text.toArray(input);

            // Parse tag (name or nat)
            let tagResult = if (pos3 < chars.size() and chars[pos3] == '\"') {
              switch (parseText(input, pos3)) {
                case (#ok((name, pos4))) #ok((#name(name) : Tag, pos4));
                case (#err(e)) #err(e);
              };
            } else {
              switch (parseNat(input, pos3)) {
                case (#ok((id, pos4))) #ok((#hash(Nat32.fromNat(id)), pos4));
                case (#err(e)) #err(e);
              };
            };

            switch (tagResult) {
              case (#ok((tag, pos4))) {
                let pos5 = skipWhitespace(input, pos4);

                // Check for value after '='
                let valResult = if (pos5 < chars.size() and chars[pos5] == '=') {
                  switch (parseChar('=', input, pos4)) {
                    case (#ok(pos6)) {
                      switch (parseValue(input, pos6)) {
                        case (#ok((val, pos7))) #ok((val, pos7));
                        case (#err(e)) #err(e);
                      };
                    };
                    case (#err(e)) #err(e);
                  };
                } else {
                  #ok((#null_, pos5));
                };

                switch (valResult) {
                  case (#ok((val, pos6))) {
                    switch (parseChar('}', input, pos6)) {
                      case (#ok(pos7)) {
                        #ok((#variant({ tag = tag; value = val }), pos7));
                      };
                      case (#err(e)) #err(e);
                    };
                  };
                  case (#err(e)) #err(e);
                };
              };
              case (#err(e)) #err(e);
            };
          };
          case (#err(e)) #err(e);
        };
      };
      case (#err(e)) #err(e);
    };
  };

  private func parseBlobValue(input : Text, start : Nat) : Result.Result<(Value, Nat), Text> {
    switch (parseKeyword("blob", input, start)) {
      case (#ok(pos1)) {
        switch (parseText(input, pos1)) {
          case (#ok((text, pos2))) {
            let bytes = Text.encodeUtf8(text);
            let values = Array.tabulate<Value>(bytes.size(), func(i) = #nat8(bytes.get(i)));
            #ok((#vector(values), pos2));
          };
          case (#err(e)) #err(e);
        };
      };
      case (#err(e)) #err(e);
    };
  };

  private func parseServiceValue(input : Text, start : Nat) : Result.Result<(Value, Nat), Text> {
    switch (parseKeyword("service", input, start)) {
      case (#ok(pos1)) {
        switch (parseText(input, pos1)) {
          case (#ok((uri, pos2))) {
            switch (principalFromText(uri)) {
              case (?p) #ok((#service(p), pos2));
              case (null) #err("Invalid principal: " # uri);
            };
          };
          case (#err(e)) #err(e);
        };
      };
      case (#err(e)) #err(e);
    };
  };

  private func principalFromText(value : Text) : ?Principal {
    // Basic validation
    if (value.size() == 0 or value.size() > 63) {
      return null;
    };

    // Check characters and separator pattern
    let chars = Text.toIter(value);
    var pos = 0;
    for (c in chars) {
      let isValidBase32 = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '2' and c <= '7');
      let isSeparator = c == '-';

      if (not isValidBase32 and not isSeparator) {
        return null;
      };

      // Separator should appear every 6th position (after 5 chars)
      if (isSeparator and (pos + 1) % 6 != 0) {
        return null;
      };

      if (not isSeparator and (pos + 1) % 6 == 0) {
        return null;
      };

      pos += 1;
    };

    // TODO no try parse?
    ?Principal.fromText(value);
  };

  private func parseFuncValue(input : Text, start : Nat) : Result.Result<(Value, Nat), Text> {
    switch (parseKeyword("func", input, start)) {
      case (#ok(pos1)) {
        switch (parseText(input, pos1)) {
          case (#ok((uri, pos2))) {
            let serviceId = switch (principalFromText(uri)) {
              case (?principal) principal;
              case (null) return #err("Invalid principal: " # uri);
            };

            switch (parseChar('.', input, pos2)) {
              case (#ok(pos3)) {
                // Parse method name (id or text)
                let nameResult = if (skipWhitespace(input, pos3) < Text.toArray(input).size() and Text.toArray(input)[skipWhitespace(input, pos3)] == '\"') {
                  parseText(input, pos3);
                } else {
                  // Parse identifier
                  let chars = Text.toArray(input);
                  var current = skipWhitespace(input, pos3);
                  var id = "";
                  while (current < chars.size() and (Char.isAlphabetic(chars[current]) or chars[current] == '_' or Char.isDigit(chars[current]))) {
                    id #= Char.toText(chars[current]);
                    current += 1;
                  };
                  if (id == "") {
                    #err("Expected method name");
                  } else {
                    #ok((id, current));
                  };
                };

                switch (nameResult) {
                  case (#ok((method, pos4))) {
                    #ok((#func_({ service = serviceId; method = method }), pos4));
                  };
                  case (#err(e)) #err(e);
                };
              };
              case (#err(e)) #err(e);
            };
          };
          case (#err(e)) #err(e);
        };
      };
      case (#err(e)) #err(e);
    };
  };

  private func parsePrincipalValue(input : Text, start : Nat) : Result.Result<(Value, Nat), Text> {
    switch (parseKeyword("principal", input, start)) {
      case (#ok(pos1)) {
        switch (parseText(input, pos1)) {
          case (#ok((uri, pos2))) {

            switch (principalFromText(uri)) {
              case (?principal) #ok((#principal(principal), pos2));
              case (null) #err("Invalid principal: " # uri);
            };

          };
          case (#err(e)) #err(e);
        };
      };
      case (#err(e)) #err(e);
    };
  };
};

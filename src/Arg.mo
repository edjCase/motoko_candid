import Value "./Value";
import Result "mo:core@1/Result";
import Array "mo:core@1/Array";
import Text "mo:core@1/Text";
import Char "mo:core@1/Char";
import Nat "mo:core@1/Nat";
import Encoder "./Encoder";
import Decoder "./Decoder";
import InternalTypes "./InternalTypes";

module {
  /// Represents an argument with a value and its corresponding type.
  ///
  /// ```motoko
  /// let arg : Arg = { value = #nat(42); type_ = #nat };
  /// ```
  public type Arg = InternalTypes.Arg;

  public let toBytes = Encoder.toBytes;

  public let toBytesBuffer = Encoder.toBytesBuffer;

  public let fromBytes = Decoder.fromBytes;

  /// Converts an Arg to its text representation.
  /// This function returns the text representation of the Arg's value.
  ///
  /// ```motoko
  /// let arg : Arg = { value = #nat(42); type_ = #nat };
  /// let text = Arg.toText(arg);
  /// // text is "42"
  /// ```
  public func toText(arg : Arg) : Text {
    Value.toText(arg.value);
  };

  /// Creates an Arg from a Value by inferring its implicit type.
  /// The type is automatically determined from the value's structure.
  ///
  /// ```motoko
  /// let value : Value.Value = #nat(42);
  /// let arg = Arg.fromValue(value);
  /// // arg is { value = #nat(42); type_ = #nat }
  /// ```
  public func fromValue(value : Value.Value) : Arg {
    {
      value = value;
      type_ = Value.toImplicitType(value);
    };
  };

  /// Parse arguments from text representation according to the Candid spec.
  /// Parses the format: ( <annval>,* )
  /// where <annval> is either <val> or <val> : <datatype>
  ///
  /// Returns an array of Args on success, or an error message on failure.
  ///
  /// ```motoko
  /// let result = Arg.fromText("(42, \"hello\", true)");
  /// switch (result) {
  ///   case (#ok(args)) {
  ///     // args is [{ value = #nat(42); type_ = #nat }, ...]
  ///   };
  ///   case (#err(e)) { /* error */ };
  /// };
  /// ```
  public func fromText(text : Text) : Result.Result<[Arg], Text> {
    let trimmed = Text.trim(text, #text " \t\n\r");

    // Parse opening parenthesis
    switch (parseChar('(', trimmed, 0)) {
      case (#ok(pos1)) {
        var args : [Arg] = [];
        var current = pos1;
        let chars = Text.toArray(trimmed);

        // Handle empty argument list
        let afterWhitespace = skipWhitespace(trimmed, current);
        if (afterWhitespace < chars.size() and chars[afterWhitespace] == ')') {
          return #ok([]);
        };

        // Parse comma-separated list of annotated values
        label l loop {
          // Extract the next value and get its end position
          let (valueText, valueEndPos) = extractNextValue(trimmed, current);
          switch (Value.fromText(valueText)) {
            case (#ok((value, type_))) {
              args := Array.concat(args, [{ value = value; type_ = type_ }]);

              // Move position to after the value
              current := skipWhitespace(trimmed, valueEndPos);

              // Check for comma or closing paren
              if (current >= chars.size()) {
                return #err("Unexpected end of input, expected ',' or ')'");
              };

              if (chars[current] == ',') {
                current += 1; // Skip comma
                // Check for trailing comma (closing paren after comma)
                let afterComma = skipWhitespace(trimmed, current);
                if (afterComma < chars.size() and chars[afterComma] == ')') {
                  current := afterComma;
                  break l; // Trailing comma, done parsing
                };
                // Continue to parse next value
              } else if (chars[current] == ')') {
                break l; // Done parsing
              } else {
                return #err("Expected ',' or ')' at position " # Nat.toText(current));
              };
            };
            case (#err(e)) return #err(e);
          };
        };

        // Parse closing parenthesis
        switch (parseChar(')', trimmed, current)) {
          case (#ok(finalPos)) {
            // Verify no trailing content
            let afterClose = skipWhitespace(trimmed, finalPos);
            if (afterClose < chars.size()) {
              #err("Unexpected input after closing parenthesis at position " # Nat.toText(afterClose));
            } else {
              #ok(args);
            };
          };
          case (#err(e)) #err(e);
        };
      };
      case (#err(e)) #err(e);
    };
  };

  // Extract the next value from the input until we hit a comma or closing paren
  // Returns the extracted text and the position after the value
  private func extractNextValue(input : Text, start : Nat) : (Text, Nat) {
    let chars = Text.toArray(input);
    var current = skipWhitespace(input, start);
    var depth = 0;
    var inString = false;
    var escape = false;
    let startPos = current;

    label w while (current < chars.size()) {
      let c = chars[current];

      if (escape) {
        escape := false;
        current += 1;
        continue w;
      };

      if (c == '\\' and inString) {
        escape := true;
        current += 1;
        continue w;
      };

      if (c == '\"' and not escape) {
        inString := not inString;
        current += 1;
        continue w;
      };

      if (not inString) {
        if (c == '(' or c == '{') {
          depth += 1;
        } else if (c == ')' or c == '}') {
          if (depth == 0) {
            break w; // End of this value
          };
          depth -= 1;
        } else if (c == ',' and depth == 0) {
          break w; // End of this value
        } else if (c == ':' and depth == 0) {
          // Type annotation, continue parsing
        };
      };

      current += 1;
    };

    (Text.fromIter(Array.sliceToArray(chars, startPos, current).vals()), current);
  };
  private func skipWhitespace(input : Text, start : Nat) : Nat {
    var pos = start;
    let chars = Text.toArray(input);
    let len = chars.size();

    label w while (pos < len) {
      let c = chars[pos];
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
      // Skip /* */ comments
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
};

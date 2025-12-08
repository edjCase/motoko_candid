import Value "./Value";
import Type "./Type";

module {
  /// Represents an argument with a value and its corresponding type.
  ///
  /// ```motoko
  /// let arg : Arg = { value = #nat(42); type_ = #nat };
  /// ```
  public type Arg = {
    value : Value.Value;
    type_ : Type.Type;
  };

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
};

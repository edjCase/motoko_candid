import Value "./Value";
import Type "./Type";
import Float "mo:base/Float";
import Bool "mo:base/Bool";
import Principal "mo:base/Principal";
import Prelude "mo:base/Prelude";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";

module {
  public type Arg = {
    value : Value.Value;
    type_ : Type.Type;
  };

  public func toText(arg : Arg) : Text {
    Value.toText(arg.value);
  };

};

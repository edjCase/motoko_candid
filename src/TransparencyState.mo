
module {
  public type TransparencyState<T> = {
    #opaque: [Nat8];
    #transparent : T;
  };
}
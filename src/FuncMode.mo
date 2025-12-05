module {

  /// Represents the mode of a Candid function.
  /// - `#oneway`: Function does not return a response
  /// - `#query_`: Function is a query (read-only) call
  public type FuncMode = {
    #oneway;
    #query_;
  };

};

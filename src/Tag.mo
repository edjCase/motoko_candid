import Order "mo:base/Order";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Nat32 "mo:base/Nat32";
import NatX "mo:xtended-numbers/NatX";

module {
  public type Tag = {
    #name : Text;
    #hash : Nat32;
  };

  /// Computes the hash of a given name.
  ///
  /// ```motoko
  /// let nameHash = Tag.hashName("example");
  /// // nameHash is a Nat32 value
  /// ```
  public func hashName(name : Text) : Nat32 {
    // hash(name) = ( Sum_(i=0..k) utf8(name)[i] * 223^(k-i) ) mod 2^32 where k = |utf8(name)|-1
    let bytes : [Nat8] = Blob.toArray(Text.encodeUtf8(name));
    Array.foldLeft<Nat8, Nat32>(
      bytes,
      0,
      func(accum : Nat32, byte : Nat8) : Nat32 {
        (accum *% 223) +% NatX.from8To32(byte);
      },
    );
  };

  /// Returns the hash value of a Tag.
  ///
  /// ```motoko
  /// let tag : Tag = #name("example");
  /// let tagHash = Tag.hash(tag);
  /// // tagHash is a Nat32 value
  /// ```
  public func hash(t : Tag) : Nat32 {
    switch (t) {
      case (#name(n)) hashName(n);
      case (#hash(h)) h;
    };
  };

  /// Converts a Tag to its text representation.
  ///
  /// ```motoko
  /// let tag : Tag = #name("example");
  /// let tagText = Tag.toText(tag);
  /// // tagText is "example"
  /// ```
  public func toText(t : Tag) : Text {
    switch (t) {
      case (#name(n)) n;
      case (#hash(h)) Nat32.toText(h);
    };
  };

  /// Checks if two Tags are equal.
  ///
  /// ```motoko
  /// let tag1 : Tag = #name("example");
  /// let tag2 : Tag = #name("example");
  /// let areEqual = Tag.equal(tag1, tag2);
  /// // areEqual is true
  /// ```
  public func equal(t1 : Tag, t2 : Tag) : Bool {
    compare(t1, t2) == #equal;
  };

  /// Compares two Tags.
  ///
  /// ```motoko
  /// let tag1 : Tag = #name("apple");
  /// let tag2 : Tag = #name("banana");
  /// let result = Tag.compare(tag1, tag2);
  /// // result is #less
  /// ```
  public func compare(t1 : Tag, t2 : Tag) : Order.Order {
    Nat32.compare(hash(t1), hash(t2));
  };
};

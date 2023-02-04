import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Bool "mo:base/Bool";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import Order "mo:base/Order";
import Prelude "mo:base/Prelude";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";

import Arg "./Arg";
import Decoder "./Decoder";
import Encoder "./Encoder";
import Tag "./Tag";
import Type "./Type";
import Value "./Value";
import { hashName } "./Tag";

import T "./Types";

module {
    type Arg = Arg.Arg;
    type Type = Type.Type;
    type Value = Value.Value;
    type RecordFieldType = Type.RecordFieldType;
    type RecordFieldValue = Value.RecordFieldValue;

    type KeyValuePair = T.KeyValuePair;
    type ResolverFunc = Nat;
    public func stringify(blob : Blob, recordKeys : [Text], resolver : ResolverFunc) : Text {
        let res = Decoder.decode(blob);

        let keyEntries = Iter.map<Text, (Nat32, Text)>(
            recordKeys.vals(),
            func(key : Text) : (Nat32, Text) {
                (hashName(key), key);
            },
        );

        let recordKeyMap = TrieMap.fromEntries<Nat32, Text>(
            keyEntries,
            Nat32.equal,
            func(n : Nat32) : Hash.Hash = n,
        );

        switch (res) {
            case (?args) {
                fromArgs(args, recordKeyMap);
            };
            case (_) {
                Debug.print("here unreachable");
                Prelude.unreachable();
            };
        };
    };

    public func fromArgs(args : [Arg], recordKeyMap : TrieMap.TrieMap<Nat32, Text>) : Text {
        let arg = args[0];
        fromArgValueToText(arg._type, arg.value, recordKeyMap);
    };

    func fromArgValueToText(_type : Type, val : Value, recordKeyMap : TrieMap.TrieMap<Nat32, Text>) : Text {

    };

    func getKey(tag : Tag.Tag, recordKeyMap : TrieMap.TrieMap<Nat32, Text>) : Text {
        switch (tag) {
            case (#hash(hash)) {
                switch (recordKeyMap.get(hash)) {
                    case (?key) key;
                    case (_) debug_show hash;
                };
            };
            case (#name(key)) key;
        };
    };

    public func cmpRecords(a : (Text, Any), b : (Text, Any)) : Order.Order {
        Text.compare(a.0, b.0);
    };
};

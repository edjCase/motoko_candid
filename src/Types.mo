import FloatX "mo:xtendedNumbers/FloatX";

module {
  public type CandidValue = {
    #int : Int;
    #int8: Int8;
    #int16: Int16;
    #int32: Int32;
    #int64: Int64;
    #nat : Nat;
    #nat8 : Nat8;
    #nat16 : Nat16;
    #nat32 : Nat32;
    #nat64 : Nat64;
    #_null;
    #bool : Bool;
    #floatX : FloatX.FloatX;
    #text: Text;
    #reserved;
    #empty;
    #opt : ?CandidValue;
    #vector : [CandidValue];
    #record : [{
      tag: CandidTag;
      value: CandidValue
    }];
    #variant: {
      tag: CandidTag;
      value: CandidValue
    };
    #_func: CandidFunc;
    #service : CandidService;
    #principal : Principal;
  };

  public type CandidTag = {
    value : Nat32;
    _label : ?Text;
  };

  public type CandidId = Text;

  public type CandidService = {
    #opaque;
    #transparent: Principal;
  };

  public type CandidServiceType = {
    methods: [(CandidId, CandidFunc)];
  };

  public type CandidFunc = {
    #opaque;
    #transparent: {
      service: CandidService;
      method: Text;
    };
  };

  public type RecordFieldType = {
    tag: CandidTag;
    _type: CandidType;
  };

  public type VariantOptionType = RecordFieldType;

  public type CandidFuncType = {
    modes: [{#oneWay; #_query}]; // TODO check the spec
    argTypes: [(?CandidId, CandidFunc)];
    returnTypes: [(?CandidId, CandidFunc)];
  };


  public type CandidType = {
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
    #_null;
    #bool;
    #float32;
    #float64;
    #text;
    #reserved;
    #empty;
    #principal;
    #opt : CandidType;
    #vector : CandidType;
    #record : [RecordFieldType];
    #variant: [VariantOptionType];
    #_func: CandidFuncType;
    #service : CandidServiceType;
  };


	public object CandidTypeCode
	{
		public let _null = -1;
		public let bool = -2;
		public let nat = -3;
		public let int = -4;
		public let nat8 = -5;
		public let nat16 = -6;
		public let nat32 = -7;
		public let nat64 = -8;
		public let int8 = -9;
		public let int16 = -10;
		public let int32 = -11;
		public let int64 = -12;
		public let float32 = -13;
		public let float64 = -14;
		public let text = -15;
		public let reserved = -16;
		public let empty = -17;
		public let opt = -18;
		public let vector = -19;
		public let record = -20;
		public let variant = -21;
		public let _func = -22;
		public let service = -23;
		public let principal = -24;
	};
}
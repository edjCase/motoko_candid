import EncoderTests "./EncoderTests";
import ValueTests "./ValueTests";
import Debug "mo:base/Debug";

ValueTests.run();
EncoderTests.run();

Debug.print("Tests passed!");

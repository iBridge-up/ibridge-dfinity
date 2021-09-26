import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Blob "mo:base/Blob";
import Prim "mo:⛔";

module {
    public func toBlob(num: Nat16) : Blob {
      Blob.fromArray([
        Nat8.fromNat(Nat16.toNat((num >> 8) & 0xFF)),
        Nat8.fromNat(Nat16.toNat(num & 0xFF))
      ]);
    };

    public func toNat8Array(num: Nat16) : [Nat8] {
      [ Nat8.fromNat(Nat16.toNat((num >> 8) & 0xFF)),
        Nat8.fromNat(Nat16.toNat(num & 0xFF))];
    };
};
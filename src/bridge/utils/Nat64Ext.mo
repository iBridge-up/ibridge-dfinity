import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Prim "mo:⛔";

module {
    public func toBlob(num: Nat64) : Blob {
      Blob.fromArray([
          Nat8.fromNat(Nat64.toNat((num >> 56) & 0xFF)), 
          Nat8.fromNat(Nat64.toNat((num >> 48) & 0xFF)),
          Nat8.fromNat(Nat64.toNat((num >> 40) & 0xFF)),
          Nat8.fromNat(Nat64.toNat((num >> 32) & 0xFF)),
          Nat8.fromNat(Nat64.toNat((num >> 24) & 0xFF)),
          Nat8.fromNat(Nat64.toNat((num >> 16) & 0xFF)),
          Nat8.fromNat(Nat64.toNat((num >> 8) & 0xFF)),
      ]);
    };

    public func toNat8Array(num: Nat64) : [Nat8] {
      [ Nat8.fromNat(Nat64.toNat((num >> 56) & 0xFF)), 
        Nat8.fromNat(Nat64.toNat((num >> 48) & 0xFF)),
        Nat8.fromNat(Nat64.toNat((num >> 40) & 0xFF)),
        Nat8.fromNat(Nat64.toNat((num >> 32) & 0xFF)),
        Nat8.fromNat(Nat64.toNat((num >> 24) & 0xFF)),
        Nat8.fromNat(Nat64.toNat((num >> 16) & 0xFF)),
        Nat8.fromNat(Nat64.toNat((num >> 8) & 0xFF)),];
    };
};
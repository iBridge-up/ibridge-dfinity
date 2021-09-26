import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Prim "mo:⛔";
import Debug "mo:base/Debug";

module {
    public func bitand(arr1: [Nat8], arr2: [Nat8]) : [Nat8] {
      var largeArr : [Nat8] = arr1;
      var smallArr : [Nat8] = arr2;

      var rtnVals: [Nat8] = [];
      if (arr2.size() > arr1.size()) {
        largeArr := arr2;
        smallArr := arr1;
      };
      var index = 0;
      for (v in largeArr.vals()){
         if (index < smallArr.size()) {
           rtnVals := Array.append(rtnVals,[v & smallArr[index]]);
         };
         index += 1;
      };
      return rtnVals;
    };

    public func bitor(arr1: [Nat8], arr2: [Nat8]) : [Nat8] {
      var largeArr : [Nat8] = arr1;
      var smallArr : [Nat8] = arr2;

      var rtnVals: [Nat8] = [];
      
      if (arr2.size() > arr1.size()) {
        largeArr := arr2;
        smallArr := arr1;
      };
      var index = 0;
      for (v in largeArr.vals()){
         if (index < smallArr.size()) {
           rtnVals := Array.append(rtnVals,[v | smallArr[index]]);
         } else rtnVals := Array.append(rtnVals, Array.make(v));
         
         index += 1;
      };
      return rtnVals;
    };
};
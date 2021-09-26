import Text "mo:base/Text";
import Bool "mo:base/Bool";
import Nat "mo:base/Nat";
module {
    
    private let MSG_ONLY_Bridge = "caller sender must be bridge contract";

    public func _onlyBridge() : Bool {
        // assert (_onlyBridge());
       return false;
    };

    
    public func setResource(resourceID: Text, contractAddress: Text) : Bool {
        // assert (_onlyBridge());
       return false;
    };


    public func setBurnable(contractAddress: Text): Bool {
        // assert (_onlyBridge());
       return false;
    };

   
    public func  withdraw(tokenAddress: Text, recipient: Text, amountOrTokenID: Nat){

    };

    private func _setResource(resourceID: Text, contractAddress: Text) : Bool {
        return false;
    };

    private func _setBurnable(contractAddress: Text) : Bool {
        return false;
    };



}
import Time "mo:base/Time";

module {
    public type DepositRecord = {
        caller: Principal;
        index: Nat;
        destinationChainID: Nat8;
        depositNonce: Nat64;
        desIdNonce: Text;
        resourceID: Text;
        depositer: ?Principal;
        recipientAddress: ?Principal;
        amount: Nat;
        fee: Nat;
        timestamp: Time.Time;
    };
};    

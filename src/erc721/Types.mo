/**
 * Module     : types.mo
 * Copyright  : 
 */

import Time "mo:base/Time";

module {
 
    public type DepositRecord = {
        caller: Text;
        index: Nat;
        destinationChainID: Nat8;
        depositNonce: Nat64;
        desIdNonce: Text;
        resourceID: Text;
        depositer: ?Text;
        recipientAddress: ?Text;
        amount: Nat;
        fee: Nat;
        timestamp: Time.Time;
    };
};    

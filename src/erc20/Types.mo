/**
 * Module     : types.mo
 * Copyright  : 
 */

import Time "mo:base/Time";

module {
 
    public type ResourceContract = {
        resourceID: Text;
        contractAddress: Text;
        tokenActorType: TokenActorType;
        fee: Nat;
    };

    public type TokenContract = {
        contractAddress: Text;
        tokenActorType: TokenActorType;
        fee: Nat;
    };

    // Support multiple token standards
    public type TokenActorType = {
        #dft;
        #ext;
        #undefined;
    };

    public type CommonResult = {
      #Ok : ?Text;
      #Err : Text;
    };

    public type TransactionId = Nat;

    public type ProposalResult = {
      //transfer succeed; but call failed & notify failed
      #Ok : { txid : TransactionId; error : ?[Text]};
      #Err : Text;
    };
    
};    

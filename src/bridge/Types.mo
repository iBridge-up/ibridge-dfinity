/**
 * Module     : types.mo
 * Copyright  : 
 */

import Time "mo:base/Time";


module {
    /// Update call operations
    public type ProposalStatus = {
        #inactive;
        #active;
        #passed;
        #executed;
        #cancelled;
    };


    /// Update call operation record fields
    public type RoleData = {
        members: [var Text];
        adminRole: Text;
    };

    /// Update call operation record fields
    public type Proposal = {
        status: ProposalStatus;
        yesVotes: [Nat8];
        yesVotesTotal : Nat8;
        proposedTime: Time.Time;
    };

    public type DepositData = {
        recipientAddress: Text;
        amount: Nat;
    };

    public type DepositRecord = {
        caller: Text;
        destinationChainID: Nat16;
        depositNonce: Nat64;
        resourceID: Text;
        depositer: Text;
        recipientAddress: Text;
        amount: Nat;
        fee: Nat;
        timestamp: Time.Time;
    };

    public type CommonResult = {
      #Ok : ?Text;
      #Err : Text;
    };

        // Support multiple token standards
    public type TokenActorType = {
        #dft;
        #ext;
        #undefined;
    };
};    

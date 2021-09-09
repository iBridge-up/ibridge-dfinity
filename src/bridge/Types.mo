/**
 * Module     : types.mo
 * Copyright  : 2021 DFinance Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : DFinance Team <hello@dfinance.ai>
 * Stability  : Experimental
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
    public type Proposal = {
        status: ProposalStatus;
        yesVotes: Nat;
        yesVotesTotal: Nat;
        proposedBlock: Nat;
    };
    
    public type VoteResult = {
      #Ok : ?Text;
      #Err : Text;
    };
    
    public type CommonResult = {
      #Ok : ?Text;
      #Err : Text;
    };
};    

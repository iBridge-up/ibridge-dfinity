import Debug "mo:base/Debug";
import ICErc20Handler "canister:ERC20Handler";
import Error "mo:base/Error";
import Text "mo:base/Text";
import Nat "mo:base/Nat8";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Bool "mo:base/Bool";
import Cycles "mo:base/ExperimentalCycles";
import Types "./Types";
import ShareTypes "../share/Types";
import IC "../share/IC";
actor Bridge {
    //fee
    private stable let fee : Nat = 10;
    type DepositRecord = ShareTypes.DepositRecord;
    private stable var owner_ : Principal = Principal.fromText("xvfsm-gaya2-2xarb-luyiv-cuec2-tszas-n3tda-opqk6-drk22-v65j5-sqe");
    private stable var feeTo : Principal = owner_;
    // deposit
    private var depositNonceAcc = HashMap.HashMap<Nat32, Nat64>(1, Nat32.equal, func(x : Nat32) : Hash.Hash {x});
    private stable var depositNonceAccEntries: [(Nat32, Nat64)] = [];

    private let MSG_ONLY_OWNER = "caller is not the owner";

    // Proposal
    type ProposalStatus = Types.ProposalStatus;
    type Proposal = Types.Proposal;
    type VoteResult = Types.VoteResult;
    type CommonResult = Types.CommonResult;

    private let _relayerThreshold :Nat = 10;

    // destinationChainID + depositNonce => dataHash => Proposal
    private var _proposals = HashMap.HashMap<Text, HashMap.HashMap<Text, Proposal>>(1, Text.equal, Text.hash);

     private func _onlyAdminOrRelayer() : async Bool {
        return false;
    };

    private func _onlyAdmin() : async Bool {
        return false;
    };

    private func _onlyRelayers() : async Bool {
        return false;
    };

    private func _relayerBit(relayer: Text) : async Nat {
        return 1;
    };

    private func _hasVoted(proposal: Proposal, relayer: Text) : async Bool { 
        return false;
    };


    public shared(msg) func _hasVotedOnProposal(destNonce: Nat, dataHash: Text, relayer: Text) : async Bool { 
        return false;
    };


    public shared(msg) func isRelayer(relayer: Text) : async Bool {
        return false;
    };


    public shared(msg) func renounceAdmin(newAdmin: Text) : async Bool { 
        // assert (_onlyAdmin());
        return false;
    };
  
    public shared(msg) func adminPauseTransfers() : async Bool {
        // assert (_onlyAdmin());
        return false;
    };

    public shared(msg) func adminUnpauseTransfers() : async Bool {
        // assert (_onlyAdmin());
        return false;
    };

    public shared(msg) func adminChangeRelayerThreshold(newThreshold: Nat) : async Bool {
        // assert (_onlyAdmin());
        return false;
    };

    public shared(msg) func adminAddRelayer(relayerAddress: Text) : async Bool {
        // assert (_onlyAdmin());
        return false;
    };

    public shared(msg) func adminRemoveRelayer(relayerAddress: Text) : async Bool {
        // assert (_onlyAdmin());
        return false;
    };

    public shared(msg) func adminSetResource(handlerAddress: Text, resourceID: Text, tokenAddress: Text) : async CommonResult {
        // assert (_onlyAdmin());
        return #Ok(null);
    };

    public shared(msg) func adminSetGenericResource(
        handlerAddress: Text,
        resourceID: Text,
        contractAddress: Text,
        depositFunctionSig: Text,
        depositFunctionDepositerOffset: Nat,
        executeFunctionSig: Text
    ) : async CommonResult { 
        // assert (_onlyAdmin());
        return #Ok(null);
    };     

    public shared(msg) func adminSetBurnable(handlerAddress: Text, tokenAddress: Text) : async CommonResult { 
        // assert (_onlyAdmin());
        return #Ok(null);
    };

    public shared(msg) func getProposal(originChainID: Nat, depositNonce: Nat, dataHash: Text) :  async ?Proposal {
        return null;
    };

    public shared(msg) func _totalRelayers() : async Nat {
        return 1;
    };

    public shared(msg) func adminChangeFee(newFee: Nat) : async Bool {
        // assert (_onlyAdmin());
        return false;
    };

    public shared(msg) func adminWithdraw(
        handlerAddress: Text,
        tokenAddress: Text,
        recipient: Text,
        amountOrTokenID: Nat
    ) : async CommonResult {
        // assert (_onlyAdmin())
        return #Ok(null);
    };
    
    public shared(msg) func deposit(resourceID :Text, destinationChainID: Nat32,
        depositer: Text,recipientAddress: Text, amount: Nat, fee: Nat
        ) : async CommonResult {
            return #Ok(null);
      };

    // get deposit record
    public shared(msg) func getDepositRecord(resourceID: Text,destinationChainID: Nat8, depositNonce: Nat) : async CommonResult {
        return #Ok(null);
    };

    public shared(msg) func voteProposal(chainID: Nat32, depositNonce: Nat, resourceID: Text, dataHash: Text) : async CommonResult {
        return #Ok(null);
    };

    public shared(msg) func cancelProposal(chainID: Nat32, depositNonce:Nat , dataHash: Text) : async CommonResult {
        // assert (_onlyAdmin())
        return #Ok(null);
    };

    public shared(msg) func transferFunds(addrs: [Text], amounts: [Nat]) : async CommonResult {
        // assert (_onlyAdmin())
        return #Ok(null);
    };
}
import Tokens "./Token";
import Storage "./Storage";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Bool "mo:base/Bool";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Types "./Types";
import ShareTypes "../share/Types";
import Cycles "mo:base/ExperimentalCycles";
import IC "../share/IC";
actor ERC20Handler {
   type DepositRecord = ShareTypes.DepositRecord;
    
    public shared(msg) func getDepositRecord(depositNonce: Nat, destId: Nat) :  async ?DepositRecord {
        return null;
    };

    
    public shared(msg) func deposit(
        resourceID: Text,
        destinationChainID: Nat,
        depositNonce: Text,
        depositer: Text,
        data: Text
    ) :  async Bool {
        // assert (_onlyBridge());
        return false;
    };


    public shared(msg) func executeProposal(resourceID: Text, data: Text) :  async Bool {
        // assert (_onlyBridge());
        return false;
    };


    public shared(msg) func withdraw(tokenAddress: Text, recipient: Text, amount: Nat) :  async Bool {
        // assert (_onlyBridge());
        return false;
    };

    // get cycles 
    public query func getCycles() : async Nat {
        return Cycles.balance();
    };

    // Return the cycles received up to the capacity allowed
    public func wallet_receive() : async { accepted: Nat64 } {
        let amount = Cycles.available();
        let deposit = Cycles.accept(amount);
        assert (deposit == amount);
        { accepted = Nat64.fromNat(amount) };
    };

}
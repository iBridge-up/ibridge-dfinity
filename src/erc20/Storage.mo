/**
 * Module     : storage.mo
 * Copyright  : 2021 DFinance Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : DFinance Team <hello@dfinance.ai>
 * Stability  : Experimental
 */
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Types "./Types";
import ShareTypes "../share/Types";
import Cycles "mo:base/ExperimentalCycles";
import IC "../share/IC";

shared(msg) actor class Storage(_owner: Principal) = this {
    type Operation = Types.Operation;
    type OpRecord = Types.OpRecord;
    type DepositRecord = ShareTypes.DepositRecord;

    private stable var owner_ : Principal = _owner;
    private stable var token_canister_id_ : Principal = msg.caller;
    // OpRecord
    private stable var ops : [var OpRecord] = [var];
    private var ops_acc = HashMap.HashMap<Principal, [Nat]>(1, Principal.equal, Principal.hash);
    private stable var opsAccEntries: [(Principal, [Nat])] = [];

    // deposit Records
    private stable var depositRecords : [var DepositRecord] = [var];
    // destinationChainID+depositNonce 
    private var depositChainNonceAcc = HashMap.HashMap<Text, Nat>(1, Text.equal, Text.hash);
    // private var depositPrincipalAcc = HashMap.HashMap<Principal, [Nat]>(1, Principal.equal, Principal.hash);
    private stable var depositChainNonceAccEntries: [(Text, Nat)] = [];
    

    system func preupgrade() {
        opsAccEntries := Iter.toArray(ops_acc.entries());
        depositChainNonceAccEntries := Iter.toArray(depositChainNonceAcc.entries());
    };

    system func postupgrade() {
        ops_acc := HashMap.fromIter<Principal, [Nat]>(opsAccEntries.vals(), 1, Principal.equal, Principal.hash);
        opsAccEntries := [];
        depositChainNonceAcc := HashMap.fromIter<Text, Nat>(depositChainNonceAccEntries.vals(), 1, Text.equal, Text.hash);
        depositChainNonceAccEntries := [];
    };

    public shared func getCanisterId() : async Principal {
        return Principal.fromActor(this);
    };

    public shared(msg) func setTokenCanisterId(token: Principal) : async Bool {
        assert(msg.caller == owner_);
        token_canister_id_ := token;
        return true;
    };

    private func putOpsAcc(who: Principal, o: OpRecord) {
        switch (ops_acc.get(who)) {
            case (?op_acc) {
                var op_new : [Nat] = Array.append(op_acc, [o.index]);
                ops_acc.put(who, op_new);
            };
            case (_) {
                ops_acc.put(who, [o.index]);
            };   
        }
    };

    // put nonce record
    private func putDepositNonceAcc(nonce: Text, o: DepositRecord) {
        switch (depositChainNonceAcc.get(nonce)) {
            case (?nonce) {
                // repeat
            };
            case (_) {
                depositChainNonceAcc.put(nonce, o.index);
            };   
        }
    };

    // add deposite record
    public shared(msg) func addDepositRecord(
        caller: Principal, destinationChainID: Nat8, depositNonce: Nat64
        ,resourceID: Text, depositer: ?Principal, recipientAddress: ?Principal, amount: Nat,
        fee: Nat
    ) : async Nat {
        var indexsize : Nat = depositRecords.size();
        // 记录的标识Id destinationChainID + _ + depositNonce
        let desIdNonce :Text = Nat8.toText(destinationChainID) # "_" # Nat64.toText(depositNonce);
        let o : DepositRecord = {
            caller = caller;
            index = indexsize;
            destinationChainID = destinationChainID;
            depositNonce = depositNonce;
            desIdNonce = desIdNonce;
            resourceID = resourceID;
            depositer = depositer;
            recipientAddress = recipientAddress;
            amount = amount;
            fee = fee;
            timestamp = Time.now();
        };
        depositRecords := Array.thaw(Array.append(Array.freeze(depositRecords), Array.make(o)));
        putDepositNonceAcc(desIdNonce, o);
        return indexsize;
    };

    /// Get deposit record by desIdNonce Text
    public func getDepositRecordNonce(desIdNonce: Text) : async ?DepositRecord {
        Array.find<DepositRecord>(Array.freeze(depositRecords), func x { x.desIdNonce == desIdNonce });
    };

    //// Get deposit record by desId and nonce 
    public shared(msg) func getDepositRecordByDesIdAndNonce(destinationChainID: Nat8, depositNonce: Nat64) : async ?DepositRecord {
        Array.find<DepositRecord>(Array.freeze(depositRecords), func x { x.destinationChainID == destinationChainID and x.depositNonce == depositNonce});
    };



    public shared(msg) func addRecord(
        caller: Principal, op: Operation, from: ?Principal, to: ?Principal, amount: Nat,
        fee: Nat, timestamp: Time.Time
    ) : async Nat {
        assert(msg.caller == token_canister_id_);
        let index = ops.size();
        let o : OpRecord = {
            caller = caller;
            op = op;
            index = index;
            from = from;
            to = to;
            amount = amount;
            fee = fee;
            timestamp = timestamp;
        };
        ops := Array.thaw(Array.append(Array.freeze(ops), Array.make(o)));
        putOpsAcc(caller, o);
        // record from and to
        if ((not Option.isNull(from)) and (from != ?caller)) { putOpsAcc(Option.unwrap(from), o); };
        if ((not Option.isNull(to)) and (to != ?caller) and (to != from) ) { putOpsAcc(Option.unwrap(to), o); };
        return index;
    };

    /// Get History by index.
    public query func getHistoryByIndex(index: Nat) : async OpRecord {
        return ops[index];
    };

    /// Get history
    public query func getHistory(start: Nat, num: Nat) : async [OpRecord] {
        var ret: [OpRecord] = [];
        var i = start;
        while(i < start + num and i < ops.size()) {
            ret := Array.append(ret, [ops[i]]);
            i += 1;
        };
        return ret;
    };

    /// Get history by account.
    public query func getHistoryByAccount(a: Principal) : async ?[OpRecord] {
        switch (ops_acc.get(a)) {
            case (?op_acc) {
                var ret: [OpRecord] = [];
                for(i in Iter.fromArray(op_acc)) {
                    ret := Array.append(ret, [ops[i]]);
                };
                return ?ret;
            };
            case (_) {
                return null;
            };
        }
    };
    
    /// Get all update call history.
    public query func allHistory() : async [OpRecord] {
        return Array.freeze(ops);
    };

    public query func tokenCanisterId() : async Principal {
        return token_canister_id_;
    };

    public query func owner() : async Principal {
        return owner_;
    };

    public query func txAmount() : async Nat {
        return ops.size();
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

    private let ic : IC.Self = actor "aaaaa-aa";

    public shared({ caller }) func transferCycles(canisterId: Principal): async() {
      assert(Principal.equal(owner_, caller));
      let balance: Nat = Cycles.balance();
      // We have to retain some cycles to be able to transfer the balance and delete the canister afterwards
      let cycles: Nat = balance - 100_000_000_000;

        if (cycles > 0) {
            Cycles.add(cycles);
            await ic.deposit_cycles({ canister_id = canisterId });
        };
    };
};
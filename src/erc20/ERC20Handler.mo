import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Bool "mo:base/Bool";
import Blob "mo:base/Blob";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import BridgeTypes "../bridge/Types";
import AID "../bridge/utils/AccountIdentifier";
import Types "./Types";
import DftTypes "./dft/types";
import Error "mo:base/Error";
import Iter "mo:base/Iter";
import Cycles "mo:base/ExperimentalCycles";
actor class ICErc20Handler(bridgeAddress_: Text, initResourceContractAddresses_: [Types.ResourceContract] 
,burnableContractAddresses_: [Text]) = this {

    // type DepositRecord = Types.DepositRecord;
    type ResourceContract = Types.ResourceContract;
    type TokenContract = Types.TokenContract;
    type TokenActorType = Types.TokenActorType;
    type ProposalResult = Types.ProposalResult;
    type CommonResult = Types.CommonResult;

    type DepositData = BridgeTypes.DepositData;
    type DepositRecord = BridgeTypes.DepositRecord;
    

    type DftTokenActor = actor {
        allowance : (owner: Text, spender: Text) -> async Nat;
        approve : (subAccount: ?AID.Subaccount, spender: Text, value: Nat, callData: ?DftTypes.CallData) -> async DftTypes.ApproveResult;
        balanceOf : (owner: Text) -> async Nat;
        burn : (subAccount: ?AID.Subaccount, value: Nat) -> async DftTypes.BurnResult;
        // new add
        burnFrom : (subAccount: ?AID.Subaccount, account: Text, value: Nat) -> async DftTypes.BurnResult;
        decimals : () -> async Nat8;
        extend : () -> async [DftTypes.KeyValuePair];
        fee : () -> async DftTypes.Fee;
        logo : () -> async [Nat8];
        meta : () -> async DftTypes.MetaData;
        name : () -> async Text;
        symbol : () -> async Text;
        totalSupply : () -> async Nat;
        tokenGraphql : () -> async ?Principal;
        transfer : (subAccount: ?AID.Subaccount, to: Text, value: Nat, callData: ?DftTypes.CallData) -> async DftTypes.TransferResult;
        transferFrom : (subAccount: ?AID.Subaccount, from: Text, to: Text, value: Nat) -> async DftTypes.TransferResult;
        cyclesBalance : () -> async Nat;
    };

    type ExtTokenActor = actor {
        allowance : (owner: Text, spender: Text) -> async Nat;
        approve : (subAccount: ?AID.Subaccount, spender: Text, value: Nat, callData: ?DftTypes.CallData) -> async DftTypes.ApproveResult;
    };

    private stable var _bridgeAddress : Text = bridgeAddress_;
    // resourceID => token contract address
    private var _resourceIDToTokenContractAddress = HashMap.HashMap<Text, TokenContract>(1, Text.equal, Text.hash);
    // token contract address => resourceID
    private var _tokenContractAddressToResourceID = HashMap.HashMap<Text, Text>(1, Text.equal, Text.hash);
    // token contract address => is whitelisted
    private var _contractWhitelist = HashMap.HashMap<Text, Bool>(1, Text.equal, Text.hash);
    // token contract address => is burnable
    private var _burnList = HashMap.HashMap<Text, Bool>(1, Text.equal, Text.hash);

    private var _depositRecords = HashMap.HashMap<Nat16, HashMap.HashMap<Nat64, DepositRecord>>(1, Nat16.equal, func(x: Nat16) : Hash.Hash { Nat32.fromNat(Nat16.toNat(x)) });

    // default token standard
    private stable var _defaultTokenActorType : TokenActorType = #dft;



    private let MSG_ONLY_BRIDGE = "sender must be bridge contract";
    private let MSG_NOT_WHITELISTED = "provided contract is not whitelisted";
    private let MSG_NOT_RESOURCE_CONTRACT = "resourceId can not find contract address";

    private func _setResource(resourceID: Text, contractAddress: Text, tokenActorType: TokenActorType, fee: Nat) : Bool {
        let tokenContract = {
            contractAddress = contractAddress;
            tokenActorType = tokenActorType;
            fee = fee;
        };
        _resourceIDToTokenContractAddress.put(resourceID, tokenContract);
        _tokenContractAddressToResourceID.put(contractAddress, resourceID);

        _contractWhitelist.put(contractAddress, true);
        true;
    };

    private func _setBurnable(contractAddress: Text) : Bool {
        _burnList.put(contractAddress, true);
        return true;
    };

    // init resource contract
    for( i in Iter.range(0, initResourceContractAddresses_.size() - 1)) {
        let resourceContract = initResourceContractAddresses_[i];
        ignore _setResource(resourceContract.resourceID, resourceContract.contractAddress, resourceContract.tokenActorType,resourceContract.fee);
    };
    // init _burnList
    for (i in Iter.range(0, burnableContractAddresses_.size() - 1)) {
        ignore _setBurnable(burnableContractAddresses_[i]);
    };
    
    public shared(msg) func getDepositRecord(destinationChainID: Nat16, depositNonce: Nat64) :  async ?DepositRecord {
        switch(_depositRecords.get(destinationChainID)) {
            case(?recordsMap) recordsMap.get(depositNonce);
            case(_) null;
        };
    };

    private func _onlyBridge(sender: Text) : Bool {
        if(sender == _bridgeAddress) {return true;};
        return false;
    };

    /**
        @notice First verifies {_resourceIDToContractAddress}[{resourceID}] and
        {_contractAddressToResourceID}[{contractAddress}] are not already set,
        then sets {_resourceIDToContractAddress} with {contractAddress},
        {_contractAddressToResourceID} with {resourceID},
        and {_contractWhitelist} to true for {contractAddress}.
        @param resourceID ResourceID to be used when making deposits.
        @param contractAddress Address of contract to be called when a deposit is made and a deposited is executed.
     */
    public shared(msg) func setResource(resourceID: Text, contractAddress: Text, tokenActorType: TokenActorType, fee: Nat) : async Bool {
        // assert (_onlyBridge());
        if(_onlyBridge(Principal.toText(msg.caller)) != true) {
            throw Error.reject(MSG_ONLY_BRIDGE);
        };
        // default dft token
        _setResource(resourceID, contractAddress, tokenActorType,fee);
    };

    


    public shared(msg) func setBurnable(contractAddress: Text) : async Bool {
        // assert (_onlyBridge());
        if(_onlyBridge(Principal.toText(msg.caller)) != true) {
            throw Error.reject(MSG_ONLY_BRIDGE);
        };

        if (_isContractWhitelist(contractAddress) != true) {
            throw Error.reject(MSG_NOT_WHITELISTED);
        };
        _setBurnable(contractAddress);
    };



    private func _isContractWhitelist(tokenAddress: Text) : Bool {
        switch(_contractWhitelist.get(tokenAddress)) {
            case(?w) true;
            case(_) false;
        };
    };

    private func getArrayRange(arr: [Nat8],from: Nat, to: Nat) : [Nat8] {
        var nat8Array : [var Nat8] = [var];
        for (i in Iter.range(from, to)) {
            nat8Array := Array.thaw(Array.append(Array.freeze(nat8Array), Array.make(arr[i])));
        };
        return Array.freeze(nat8Array);
    };

    /**
        @notice A deposit is initiatied by making a deposit in the Bridge contract.
        @param destinationChainID Chain ID of chain tokens are expected to be bridged to.
        @param depositNonce This value is generated as an ID by the Bridge contract.
        @param depositer Address of account making the deposit in the Bridge contract.
        @param data Consists of: {resourceID}, {amount}, {lenRecipientAddress}, and {recipientAddress}
        all padded to 32 bytes.
        @notice Data passed into the function should be constructed as follows:
        amount                      uint256     bytes   0 - 32
        recipientAddress length     uint256     bytes  32 - 64
        recipientAddress            bytes       bytes  64 - END
        @dev Depending if the corresponding {tokenAddress} for the parsed {resourceID} is
        marked true in {_burnList}, deposited tokens will be burned, if not, they will be locked.
     */
    public shared(msg) func deposit(resourceID: Text,destinationChainID: Nat16,
        depositNonce: Nat64, depositer: Text, data: DepositData, fee: Nat
    ) :  async Bool {
        if(_onlyBridge(Principal.toText(msg.caller)) != true) {
            throw Error.reject(MSG_ONLY_BRIDGE);
        };
        switch (_resourceIDToTokenContractAddress.get(resourceID)) {
            case(?tokenContract){
                if (_isContractWhitelist(tokenContract.contractAddress) != true) {
                    throw Error.reject(MSG_NOT_WHITELISTED);
                };
                let thisPrincipal = Principal.toText(Principal.fromActor(this));
                // need to discuss => depositAmount = fee + amount ?????????? 
                let depositAmount = data.amount + fee;
                if(_isBurnList(tokenContract.contractAddress) == true){
                    ignore await burnERC20(tokenContract,depositer,depositAmount);
                } else {
                    // lockERC20(tokenAddress, depositer, address(this), amount);
                    ignore await lockERC20(tokenContract,depositer,thisPrincipal,depositAmount);
                };

                let record : DepositRecord = {
                    caller = Principal.toText(msg.caller);
                    destinationChainID = destinationChainID;
                    depositNonce = depositNonce;
                    resourceID = resourceID;
                    depositer = depositer;
                    recipientAddress = data.recipientAddress;
                    amount = data.amount;
                    fee = fee;
                    timestamp = Time.now();
                };

                switch(_depositRecords.get(destinationChainID)){
                    case(?recordsMap) {
                        recordsMap.put(depositNonce, record);
                        _depositRecords.put(destinationChainID, recordsMap);
                    };
                    case(_){
                        var tmpMap = HashMap.HashMap<Nat64, DepositRecord>(1, Nat64.equal, func(x: Nat64) : Hash.Hash { Nat32.fromNat(Nat64.toNat(x)) });
                        tmpMap.put(depositNonce, record);
                        _depositRecords.put(destinationChainID, tmpMap);
                    };
                };
                return true;
            };
            case(_) false;
        };
    };

    private func lockERC20(tokenContract: TokenContract, depositer: Text, recipient: Text, amount: Nat) : async Bool {
        let result = await _lockERC20(tokenContract,depositer,recipient,amount);
        switch(result) {
            case(#Ok(msg)) true;
            case(#Err(errmsg)) false;
        };
    };

    private func _lockERC20(tokenContract: TokenContract, depositer: Text, recipient: Text, amount: Nat) : async CommonResult {
        switch (tokenContract.tokenActorType) {
            case(#dft){
                let dftTokenActor : DftTokenActor = actor(tokenContract.contractAddress);
                // need to approve ?
                // transferFrom
                let result : DftTypes.TransferResult = await dftTokenActor.transferFrom(null, depositer, recipient, amount);
                switch (result) {
                    case(#Ok { txid; error; }) {
                        return #Ok(?"lock success");
                    };
                    case(#Err(errmsg)) { return #Err(errmsg); };
                };
            };
            case(#ext){
                // TODO Support ext token
                return #Err("not yet supported, coming soon");
            };
            case(#undefined){
                // TODO Support ext token
                return #Err("token undefined");
            };
        };
    };

    private func burnERC20(tokenContract: TokenContract, depositer: Text, amount: Nat): async Bool {
        let result = await _burnERC20(tokenContract, depositer, amount);
        switch(result) {
            case(#Ok(msg)) true;
            case(#Err(errmsg)) false;
        };
    };

    private func _burnERC20(tokenContract: TokenContract, depositer: Text, amount: Nat) : async CommonResult {
        switch (tokenContract.tokenActorType) {
            case(#dft){
                let dftTokenActor : DftTokenActor = actor(tokenContract.contractAddress);
                // need to approve ?
                // transferFrom
                let result : DftTypes.BurnResult = await dftTokenActor.burnFrom(null, depositer,amount);
                switch (result) {
                    case(#Ok()) {
                        return #Ok(?"burn success ");
                    };
                    case(#Err(errmsg)) { return #Err(errmsg); };
                };
            };
            case(#ext){
                // TODO Support ext token
                return #Err("not yet supported, coming soon");
            };
            case(#undefined){
                // TODO Support ext token
                return #Err("token undefined");
            };
        };
    };


    // Return the principal identifier of this canister via the optional `this` binding.
    public shared func getTokenAddress() : async Principal {
        return Principal.fromActor(this);
    };

    private func _isBurnList(tokenAddress: Text) : Bool {
        switch(_burnList.get(tokenAddress)){
            case(?t) true;
            case(_) false;
        };
    };

    public shared(msg) func executeProposal(resourceID: Text, data: DepositData) :  async Bool {
        if(_onlyBridge(Principal.toText(msg.caller)) != true) {
            throw Error.reject(MSG_ONLY_BRIDGE);
        };
        Debug.print("handler 1 -> " # debug_show(data));
        switch(_resourceIDToTokenContractAddress.get(resourceID)) {
            case(?tokenContract) {
                if (_isContractWhitelist(tokenContract.contractAddress) != true) {
                    throw Error.reject(MSG_NOT_WHITELISTED);
                };
                if(_isBurnList(tokenContract.contractAddress) == true){
                    // mintERC20(tokenAddress, address(recipientAddress), amount);
                    // TODO mint
                } else {
                    // releaseERC20(tokenAddress, address(recipientAddress), amount);
                    Debug.print("handler 2 tokenContract-> " # debug_show(tokenContract));
                    let recipientAddress = data.recipientAddress;
                    return await releaseERC20(tokenContract, recipientAddress, data.amount);
                };
            };
            case(_){
                throw Error.reject(MSG_NOT_RESOURCE_CONTRACT);
            };
        };
        return false;
    };

    private func releaseERC20(tokenContract: TokenContract, recipientAddress: Text,amount: Nat) : async Bool {
        let result = await _releaseERC20(tokenContract, recipientAddress, amount);
        Debug.print("handler releaseERC20 result-> " # debug_show(result));
        switch (result) {
            case(#Ok { txid; error; }) {
                return true;
            };
            case(#Err(errmsg)) { return false; };
        };
    };

    private func _releaseERC20(tokenContract: TokenContract, recipient: Text,amount: Nat) : async ProposalResult {
        switch (tokenContract.tokenActorType) {
            case(#dft){
                let dftTokenActor : DftTokenActor = actor(tokenContract.contractAddress);
                let thisPrincipal = Principal.toText(Principal.fromActor(this));
                // approve ?
                let approveAmount = amount + tokenContract.fee;
                let apResult = await dftTokenActor.approve(null, thisPrincipal, approveAmount,null);
                Debug.print("handler approve result-> " # debug_show(apResult));
                // switch (apResult) {
                //     case(#Ok(msg)) {
                //     };
                //     case(#Err(errmsg)) {};
                // };
                // from bridge contract  to recipient
                // transferFrom
                Debug.print("handler _releaseERC20 thisPrincipal-> " # debug_show(thisPrincipal));
                let result : DftTypes.TransferResult = await dftTokenActor.transferFrom(null, thisPrincipal,recipient,amount);
                switch (result) {
                    case(#Ok { txid; error; }) {
                        return #Ok {txid = txid; error = error;};
                    };
                    case(#Err(errmsg)) { return #Err(errmsg); };
                };
            };
            case(#ext){
                // TODO Support ext token
                return #Err("not yet supported, coming soon");
            };
            case(#undefined){
                // TODO Support ext token
                return #Err("token undefined");
            };
        };
    };

    
    /**
        @notice Used to manually release ERC20 tokens from ERC20Safe.
        @param tokenAddress Address of token contract to release.
        @param recipient Address to release tokens to.
        @param amount The amount of ERC20 tokens to release.
     */
    public shared(msg) func withdraw(tokenAddress: Text, recipient: Text, amount: Nat) :  async Bool {
        // assert (_onlyBridge());
        if(_onlyBridge(Principal.toText(msg.caller)) != true) {
            throw Error.reject(MSG_ONLY_BRIDGE);
        };
        await _withdraw(tokenAddress, recipient, amount);
    };

    private func _withdraw(tokenAddress: Text, recipient: Text, amount: Nat) :  async Bool {
        // assert (_onlyBridge());
        switch(_getTokenContractByAddress(tokenAddress)){
            case(?tokenContract){
                return await releaseERC20(tokenContract, recipient, amount);
            };
            case(_) false;
        };
    };

    private func _getTokenContractByAddress(tokenAddress: Text) : ?TokenContract {
        switch (_tokenContractAddressToResourceID.get(tokenAddress)) {
            case(?resourceID) {
                return _resourceIDToTokenContractAddress.get(resourceID);
            };
            case(_) null;
        };
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
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat8ArrayExt "./utils/Nat8ArrayExt";
import Nat16 "mo:base/Nat16";
import Nat16Ext "./utils/Nat16Ext";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Nat64Ext "./utils/Nat64Ext";
import Option "mo:base/Option";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Bool "mo:base/Bool";
import Types "./Types";
import SHA256 "./utils/SHA256";
// import PrincipalExt "./utils/PrincipalExt";
// import AID "./utils/AccountIdentifier";


shared(msg) actor class Bridge(chainID_: Nat16, initialRelayerThreshold_: Nat8, fee_: Nat, expiry_: Nat, owner_ : Principal) {

    // Limit relayers number because proposal can fit only so much votes
    stable let MAX_RELAYERS : Nat = 200;

    type CommonResult = Types.CommonResult;
    type Proposal = Types.Proposal;
    type RoleData = Types.RoleData;
    type DepositData = Types.DepositData;
    type DepositRecord =  Types.DepositRecord;
    type TokenActorType = Types.TokenActorType;

    type ERCHandlerActor = actor {
        deposit : (resourceID: Text,destinationChainID: Nat16,depositNonce: Nat64, depositer: Text, data: DepositData, fee: Nat) -> async Bool;
        getDepositRecord : (destinationChainID: Nat16, depositNonce: Nat64) ->  async ?DepositRecord; 
        setResource : (resourceID: Text, contractAddress: Text, tokenActorType: TokenActorType, fee: Nat) -> async Bool;
        setBurnable : (contractAddress: Text) -> async Bool;
        withdraw : (tokenAddress: Text, recipient: Text, amount: Nat) ->  async Bool;
        executeProposal : (resourceID: Text, data: DepositData) ->  async Bool;
    };

    private stable var _owner : Principal = owner_;
    private stable var _chainID : Nat16 = chainID_;
    private stable var _relayerThreshold : Nat8 = initialRelayerThreshold_;
    private stable var _fee : Nat = fee_ ;
    // expiry_ Time 
    private stable var _expiry : Nat = expiry_ ;
    private stable var _paused : Bool = false;

    private stable var _ercHandlerCanister : ?ERCHandlerActor = null;

    stable let RELAYER_ROLE : Text = Nat32.toText(Text.hash("RELAYER_ROLE"));
    stable let DEFAULT_ADMIN_ROLE : Text = "0x00";

    

    private stable var _rolesEntries : [(Text, RoleData)] = [];
    private stable var _resourceIDToHandlerAddressEntries : [(Text, Text)] = [];
    private stable var _depositCountsEntries : [(Nat32, Nat)] = [];
    private stable var _proposalsEntries : [(Text, [(Text, Proposal)])] = [];

    
    private var _roles = HashMap.HashMap<Text, RoleData>(1, Text.equal, Text.hash);
    private var _resourceIDToHandlerAddress = HashMap.HashMap<Text, Text>(1, Text.equal, Text.hash);
    private var _depositCounts = HashMap.HashMap<Nat16, Nat64>(1, Nat16.equal, func(x: Nat16) : Hash.Hash { Nat32.fromNat(Nat16.toNat(x)) });
    // proposal ( depositNonce << 8 | destinationChainID ) => dataHash => Proposal
    private var _proposals = HashMap.HashMap<Blob, HashMap.HashMap<Text, Proposal>>(1, Blob.equal, Blob.hash);
  

    private let MSG_ONLY_OWNER = "caller is not the owner";
    private let MSG_ONLY_ADMIN = "sender doesn't have admin role";
    private let MSG_ONLY_RELAYER = "sender doesn't have relayer role";
    private let MSG_ADMIN_OR_RELAYER = "sender is not relayer or admin";
    private let MSG_HAS_RELAYER = "addr already has relayer role!";
    private let MSG_HAS_NOT_RELAYER = "addr doesn't have relayer role!";
    private let MSG_LIMIT_RELAYER = "relayers limit reached";
    private let MSG_PAUSED = "the contract is paused!";
    private let MSG_NO_HANDLER = "no handler for resourceID";


    // init owner to admin role
    let rd_ : RoleData = {
        members = [var Principal.toText(owner_)];
        adminRole = DEFAULT_ADMIN_ROLE;
    };
    _roles.put(DEFAULT_ADMIN_ROLE, rd_);

    private func onlyAdmin(sender: Text) : async () {
        if (_onlyAdmin(sender) != true ) {
            throw Error.reject(MSG_ONLY_ADMIN);
        };
    };

    private func onlyRelayers(sender: Text) : async () {
        if (_onlyRelayers(sender) != true ) {
            throw Error.reject(MSG_ONLY_RELAYER);
        };
    };

    private func onlyAdminOrRelayer(sender: Text) : async () {
        if (_onlyAdminOrRelayer(sender) != true ) {
            throw Error.reject(MSG_ADMIN_OR_RELAYER);
        };
    };

    private func _onlyAdmin(sender: Text) : Bool {
        hasRole(DEFAULT_ADMIN_ROLE, sender);
    };

    private func _onlyRelayers(sender: Text) : Bool {
        hasRole(RELAYER_ROLE, sender);
    };

    private func _onlyAdminOrRelayer(sender: Text) : Bool {
        hasRole(DEFAULT_ADMIN_ROLE, sender) or hasRole(RELAYER_ROLE, sender);
    };

    private func _getRelayerMemberIndex(relayer: Text) : Nat8 {
        var index = 0;
        switch (_roles.get(RELAYER_ROLE)) {
            case(?roleData) {
                for (v in roleData.members.vals()){
                  index += 1;
                  if (v  == relayer) return Nat8.fromNat(index);
                }
            };
            case(_) return Nat8.fromNat(0);
        };
        return Nat8.fromNat(0);
    };

    private func _relayerBit(relayer: Text) : [Nat8] {
        let index: Nat8 = _getRelayerMemberIndex(relayer);
        let bitIndex : Nat8 = index / 8;
        let bitInnerIndex : Nat8 = index % 8;
        var loopIndex: Nat8 = 0;
        let one: Nat8 = 1;
        var tmpNat8Array: [Nat8] = [0];
        var nat8Array: [Nat8] =[0];

        loop {
            if (loopIndex == 0) {
                var tmpNat8ArrayForIndex : [Nat8] = [ one << (bitInnerIndex - 1) ];
                nat8Array := tmpNat8ArrayForIndex;
            }
            else nat8Array := Array.append(nat8Array, tmpNat8Array);

            loopIndex += 1;
        } while (loopIndex < bitIndex);

        return nat8Array;
    };

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    private func hasRole(role: Text, account: Text) : Bool {
        switch (_roles.get(role)) {
            case(?roleData) {
                let caller = Array.find<Text>(Array.freeze(roleData.members), func x { x == account });
                if (Option.isSome(caller)) {
                    return true;
                };
                return false;
            };
            case(_) return false;
        };
    };

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
    */
    public shared(msg) func grantRole(role: Text, account: Text) : async Bool {
        // await onlyAdmin(Principal.toText(msg.caller));
        if (_onlyAdmin(Principal.toText(msg.caller)) != true ) {
            throw Error.reject(MSG_ONLY_ADMIN);
        };
        _grantRole(role,account);
    };

    private func _grantRole(role: Text, account: Text) : Bool { 
        switch (_roles.get(role)) {
            case(?roleData) {
                var members_new = roleData.members;
                members_new := Array.thaw(Array.append(Array.freeze(members_new), Array.make(account)));
                let rd : RoleData = {
                    members =  members_new;
                    adminRole = roleData.adminRole;
                };
                _roles.put(role, rd);
                // Todo emit record
                return true;
            };
            case(_) {
                // put default
                var members_default :[var Text] = Array.thaw(Array.make(account));
                let rd : RoleData = {
                    members =  members_default;
                    adminRole = role;
                };
                _roles.put(role, rd);
                return true;
            };
        };
    };

    private func _revokeRole(role: Text, account: Text) : Bool { 
        switch (_roles.get(role)) {
            case(?roleData) {
                var members_new = roleData.members;
                members_new := Array.thaw(Array.filter<Text>(Array.freeze(members_new), func x { x!= account}));
                let rd : RoleData = {
                    members =  members_new;
                    adminRole = roleData.adminRole;
                };
                _roles.put(role, rd);
                // Todo emit record
                return true;
            };
            case(_) return false;
        };
    };

    

    /**
        @notice Returns true if {relayer} has the relayer role.
        @param relayer Address to check.
     */
    public shared(msg) func isRelayer(relayer: Text) : async Bool {
        hasRole(RELAYER_ROLE, relayer);
    };

    /**
        @notice Removes admin role from {msg.sender} and grants it to {newAdmin}.
        @notice Only callable by an address that currently has the admin role.
        @param newAdmin Address that admin role will be granted to.
     */
    public shared(msg) func renounceAdmin(newAdmin: Text) : async Bool { 
        // Cannot renounce oneself
        assert(Principal.toText(msg.caller) != newAdmin);
        // await onlyAdmin(Principal.toText(msg.caller));
        if (_onlyAdmin(Principal.toText(msg.caller)) != true ) {
            throw Error.reject(MSG_ONLY_ADMIN);
        };
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin) 
        and _revokeRole(DEFAULT_ADMIN_ROLE, Principal.toText(msg.caller));
    };
    
    /**
        @notice Pauses deposits, proposal creation and voting, and deposit executions.
        @notice Only callable by an address that currently has the admin role.
     */
    public shared(msg) func adminPauseTransfers() : async Bool {
        // assert (_onlyAdmin());
        // await onlyAdmin(Principal.toText(msg.caller));
        if (_onlyAdmin(Principal.toText(msg.caller)) != true ) {
            throw Error.reject(MSG_ONLY_ADMIN);
        };
        _pausedf();
        return true;
    };

    private func _pausedf() {
        if (_paused == false) {
            _paused :=  true;
            // Todo emit Record
            // emit Paused(msg.sender);
        }
    };

    private func _unpause() {
        if (_paused == true) {
            _paused :=  false;
            // Todo emit Record
            // emit _unpause(msg.sender);
        }
    };

    /**
        @notice Unpauses deposits, proposal creation and voting, and deposit executions.
        @notice Only callable by an address that currently has the admin role.
     */
    public shared(msg) func adminUnpauseTransfers() : async Bool {
        // await onlyAdmin(Principal.toText(msg.caller));
        if (_onlyAdmin(Principal.toText(msg.caller)) != true ) {
            throw Error.reject(MSG_ONLY_ADMIN);
        };
        _unpause();
        return true;
    };

    /**
        @notice Modifies the number of votes required for a proposal to be considered passed.
        @notice Only callable by an address that currently has the admin role.
        @param newThreshold Value {_relayerThreshold} will be changed to.
        @notice Emits {RelayerThresholdChanged} event.
     */
    public shared(msg) func adminChangeRelayerThreshold(newThreshold: Nat8) : async Bool {
        // assert (_onlyAdmin());
        // await onlyAdmin(Principal.toText(msg.caller));
        if (_onlyAdmin(Principal.toText(msg.caller)) != true ) {
            throw Error.reject(MSG_ONLY_ADMIN);
        };
        _relayerThreshold := newThreshold;
        return true;
    };

    public shared(msg) func adminAddRelayer(relayerAddress: Text) : async Bool {
        // if (_onlyAdmin(Principal.toText(msg.caller)) != true ) {
        //     throw Error.reject(MSG_ONLY_ADMIN);
        // };
        if (hasRole(RELAYER_ROLE, relayerAddress) == true)  {
            throw Error.reject(MSG_HAS_RELAYER);
        };
        if (_totalRelayers() > MAX_RELAYERS ) {
            throw Error.reject(MSG_LIMIT_RELAYER);
        };
        // Todo emit RelayerAdded(relayerAddress);
        _grantRole(RELAYER_ROLE, relayerAddress);
    };

    /**
        @notice Removes relayer role for {relayerAddress}.
        @notice Only callable by an address that currently has the admin role, which is
                checked in revokeRole().
        @param relayerAddress Address of relayer to be removed.
        @notice Emits {RelayerRemoved} event.
     */
    public shared(msg) func adminRemoveRelayer(relayerAddress: Text) : async Bool {
        if (hasRole(RELAYER_ROLE, relayerAddress) != true)  {
            throw Error.reject(MSG_HAS_NOT_RELAYER);
        };
        // Todo emit RelayerRemoved(relayerAddress);
        _revokeRole(RELAYER_ROLE, relayerAddress);
    };

     /**
        @notice Sets a new resource for handler contracts that use the IERCHandler interface,
        and maps the {handlerAddress} to {resourceID} in {_resourceIDToHandlerAddress}.
        @notice Only callable by an address that currently has the admin role.
        @param handlerAddress Address of handler resource will be set for.
        @param resourceID ResourceID to be used when making deposits.
        @param tokenAddress Address of contract to be called when a deposit is made and a deposited is executed.
     */
    public shared(msg) func adminSetResource(handlerAddress: Text, resourceID: Text
    , tokenAddress: Text, tokenActorType: TokenActorType, fee: Nat) : async CommonResult {
        // assert (_onlyAdmin());
        if (_onlyAdmin(Principal.toText(msg.caller)) != true ) {
            throw Error.reject(MSG_ONLY_ADMIN);
        };
        // put handlerAddress to Map
        _resourceIDToHandlerAddress.put(resourceID, handlerAddress);
        _ercHandlerCanister := ?actor(handlerAddress);
        switch(_ercHandlerCanister) {
            case(?handler) {
                let r = await handler.setResource(resourceID,tokenAddress,tokenActorType,fee);
                if (r == true) {
                    return #Ok(?"set resource success");
                };
                return #Err(handlerAddress # " handler set resource error");
            };
            case(_) return #Err("handlerAddress cann't find handler actor");
        };
    };



    /**
        @notice Sets a resource as burnable for handler contracts that use the IERCHandler interface.
        @notice Only callable by an address that currently has the admin role.
        @param handlerAddress Address of handler resource will be set for.
        @param tokenAddress Address of contract to be called when a deposit is made and a deposited is executed.
     */
    public shared(msg) func adminSetBurnable(handlerAddress: Text, tokenAddress: Text) : async CommonResult { 
        // assert (_onlyAdmin());
        if (_onlyAdmin(Principal.toText(msg.caller)) != true ) {
            throw Error.reject(MSG_ONLY_ADMIN);
        };
        _ercHandlerCanister := ?actor(handlerAddress);
        switch(_ercHandlerCanister) {
            case(?handler) {
                let r = await handler.setBurnable(tokenAddress);
                if (r == true) {
                    return #Ok(?"SetBurnable success");
                };
                return #Err(handlerAddress # " handler set SetBurnable error");
            };
            case(_) return #Err("handlerAddress cann't find handler actor");
        };
    };


    /**
        @notice Returns total relayers number.
        @notice Added for backwards compatibility.
     */
    public shared(msg) func totalRelayers() : async Nat {
        _totalRelayers();
    };

    private func _totalRelayers() : Nat {
        switch (_roles.get(RELAYER_ROLE)) {
            case(?roleData) {
                return roleData.members.size();
            };
            case(_) {
                return 0;
            };
        };
    };

    /**
        @notice Changes deposit fee.
        @notice Only callable by admin.
        @param newFee Value {_fee} will be updated to.
     */
    public shared(msg) func adminChangeFee(newFee: Nat) : async Bool {
        // assert (_onlyAdmin());
        if (_onlyAdmin(Principal.toText(msg.caller)) != true ) {
            throw Error.reject(MSG_ONLY_ADMIN);
        };
        assert(_fee != newFee);
        _fee := newFee;
        return true;
    };

    /**
        @notice Used to manually withdraw funds from ERC safes.
        @param handlerAddress Address of handler to withdraw from.
        @param tokenAddress Address of token to withdraw.
        @param recipient Address to withdraw tokens to.
        @param amountOrTokenID Either the amount of ERC20 tokens or the ERC721 token ID to withdraw.
     */
    public shared(msg) func adminWithdraw(
        handlerAddress: Text,
        tokenAddress: Text,
        recipient: Text,
        amountOrTokenID: Nat
    ) : async CommonResult {
        // assert (_onlyAdmin())
        if (_onlyAdmin(Principal.toText(msg.caller)) != true ) {
            throw Error.reject(MSG_ONLY_ADMIN);
        };
        _ercHandlerCanister := ?actor(handlerAddress);
        switch(_ercHandlerCanister) {
            case(?handler) {
                let r = await handler.withdraw(tokenAddress,recipient,amountOrTokenID);
                if (r == true) {
                    return #Ok(?"withdraw success");
                };
                return #Err(handlerAddress # " handler withdraw error");
            };
            case(_) return #Err("handlerAddress cann't find handler actor");
        };
    };
    
    /**
        @notice Initiates a transfer using a specified handler contract.
        @notice Only callable when Bridge is not paused.
        @param destinationChainID ID of chain deposit will be bridged to.
        @param resourceID ResourceID used to find address of handler to be used for deposit.
        @param data Additional data to be passed to specified handler.
        @notice Emits {Deposit} event.
     */
    public shared(msg) func deposit(resourceID :Text, destinationChainID: Nat16,
        depositer: Text,data: DepositData
    ) : async CommonResult {
            // whenNotPaused
        if (_paused == true) {
            throw Error.reject(MSG_PAUSED);
        };
        // check the fee ?
        switch(_resourceIDToHandlerAddress.get(resourceID)) {
            case(?handlerAddress){
                let depositNonce = switch(_depositCounts.get(destinationChainID)) {
                    case(?d) d+1;
                    case(_) Nat64.fromNat(1);
                };
                _depositCounts.put(destinationChainID, depositNonce);
                _ercHandlerCanister := ?actor(handlerAddress);
                switch(_ercHandlerCanister) {
                    case(?depositHandler) {
                        let r = await depositHandler.deposit(resourceID,destinationChainID,depositNonce,depositer,data,_fee);
                        if (r == true) {
                            // Todo 
                            return #Ok(?("deposit success. depositNonce:" # Nat64.toText(depositNonce)));
                        };
                        return #Err(handlerAddress # " handler deposit error");
                    };
                    case(_) return #Err("handlerAddress cann't find handler actor");
                };
            };
            case(_) return #Err("resourceID not mapped to handler");
        };
    };

    // Todo get deposit record
    public shared(msg) func getDepositRecord(resourceID: Text,destinationChainID: Nat16, depositNonce: Nat64) : async ?DepositRecord {
        switch(_resourceIDToHandlerAddress.get(resourceID)) {
            case(?handlerAddress){
                _ercHandlerCanister := ?actor(handlerAddress);
                switch(_ercHandlerCanister) {
                    case(?handler) {
                        return await handler.getDepositRecord(destinationChainID, depositNonce);
                    };
                    case(_) null;
                };
            };
            case(_) null;
        };
    };

    private func _hasVoted(proposal: Proposal, relayer: Text) : Bool {
        let relayerBitArr = _relayerBit(relayer);
        if (relayerBitArr.size() > proposal.yesVotes.size()) {
            return false;
        };
        let res = Nat8ArrayExt.bitand(relayerBitArr, proposal.yesVotes);
        let votes = Array.find<Nat8>(res, func x { x > 0 });

        if (Option.isSome(votes)) {
            return true;
        };
        return false;
    };

    /**
        @notice Returns true if {relayer} has voted on {destNonce} {dataHash} proposal.
        @notice Naming left unchanged for backward compatibility.
        @param destNonce destinationChainID + depositNonce of the proposal.
        @param dataHash Hash of data to be provided when deposit proposal is executed.
        @param relayer Address to check.
     */
    public shared(msg) func _hasVotedOnProposal(destNonce: Blob, dataHash: Text, relayer: Text) : async Bool { 
        switch(_proposals.get(destNonce)) {
            case(?data){
                switch (data.get(dataHash)) {
                    case (?proposal) {
                        return _hasVoted(proposal,relayer);
                    };
                    case (_) false;
                };
            };
            case(_) false;
        };
    };

    /**
        @notice Returns a proposal.
        @param originChainID Chain ID deposit originated from.
        @param depositNonce ID of proposal generated by proposal's origin Bridge contract.
        @param dataHash Hash of data to be provided when deposit proposal is executed.
        @return Proposal which consists of:
        - _dataHash Hash of data to be provided when deposit proposal is executed.
        - _yesVotes Number of votes in favor of proposal.
        - _noVotes Number of votes against proposal.
        - _status Current status of proposal.
     */
    public shared(msg) func getProposal(originChainID: Nat16, depositNonce: Nat64, dataHash: Text) :  async ?Proposal {
        _getProposal(originChainID,depositNonce,dataHash);
    };

    private func _getProposal(chainID: Nat16, depositNonce: Nat64, dataHash: Text) : ?Proposal {
        let proposalId = getProposalId(chainID, depositNonce);
        switch(_proposals.get(proposalId)) {
            case(?dataMap) dataMap.get(dataHash);
            case(_)  null;
        };
    };

    private func _hasResourceIDToHandlerAddress(resourceID: Text) : Bool {
        switch(_resourceIDToHandlerAddress.get(resourceID)) {
            case(?t) true;
            case(_) false;
        }
    };

    public shared(msg) func voteProposal(chainID: Nat16, depositNonce: Nat64, resourceID: Text, dataHash: Text) : async CommonResult {
        // onlyRelayers
        // assert (_onlyAdmin())
        if (_onlyRelayers(Principal.toText(msg.caller)) != true ) {
            throw Error.reject(MSG_ONLY_RELAYER);
        };

        if (_hasResourceIDToHandlerAddress(resourceID) == false ) {
            throw Error.reject(MSG_NO_HANDLER);
        };
        // whenNotPaused
        if (_paused == true) {
            throw Error.reject(MSG_PAUSED);
        };

        let proposalId = getProposalId(chainID, depositNonce);
        let defaultPropoasl : Proposal = {
            status = #inactive;
            yesVotes =  [];
            yesVotesTotal = 0;
            proposedTime = Time.now();
        };
        let proposalMap = _proposals.get(proposalId);

        var proposal = switch(proposalMap) {
            case(?dataMap) switch (dataMap.get(dataHash)) {
                case (?p) p;
                case (_) defaultPropoasl;
            };
            case(_) defaultPropoasl;
        };

        let relayer = Principal.toText(msg.caller);
        if(_hasVoted(proposal, relayer) == true) {
            throw Error.reject("relayer already voted");
        };
        if (proposal.status == #passed or proposal.status == #executed
            or proposal.status == #cancelled) {
                return #Err("proposal already passed/executed/cancelled");
        };
        var statusNew = proposal.status;
        var yesVotesNew = proposal.yesVotes;
        var yesVotesTotalNew = proposal.yesVotesTotal;
        if(proposal.status == #inactive){
            // create proposal
            statusNew := #active; 
            // TODO: emit Proposal
        } else if (Time.now() - proposal.proposedTime > expiry_) {
            statusNew := #cancelled;
            // TODO: ProposalEvent
        };

        if (statusNew != #cancelled) {
            yesVotesNew := Nat8ArrayExt.bitor(yesVotesNew, _relayerBit(relayer));
            yesVotesTotalNew += 1;
            // TODO: emit ProposalVote

            if (yesVotesTotalNew >= _relayerThreshold) {
                statusNew := #passed;
                // TODO: emit ProposalVote
            }
             
        };
        proposal := {
            status = statusNew;
            yesVotes =  yesVotesNew;
            yesVotesTotal = yesVotesTotalNew;
            proposedTime = Time.now();
        };

        Debug.print("voteProposal dataHash :" # debug_show(dataHash));

        if (Option.isSome(proposalMap)){
            var tmpMap = switch(proposalMap) {
                case(?dataMap) dataMap;
                case(_) HashMap.HashMap<Text, Proposal>(1, Text.equal, Text.hash);
            };
            tmpMap.put(dataHash, proposal);
            _proposals.put(proposalId, tmpMap);
            Debug.print("voteProposal is :" # debug_show(proposal));
        } else {
            var tmpMap = HashMap.HashMap<Text, Proposal>(1, Text.equal, Text.hash);
            tmpMap.put(dataHash, proposal);
            _proposals.put(proposalId, tmpMap);
            Debug.print("voteProposal __ :" # debug_show(proposal));
        };
        return #Ok(?"vote proposal success");
    };

    /**
        @notice Cancels a deposit proposal that has not been executed yet.
        @notice Only callable by relayers when Bridge is not paused.
        @param chainID ID of chain deposit originated from.
        @param depositNonce ID of deposited generated by origin Bridge contract.
        @param dataHash Hash of data originally provided when deposit was made.
        @notice Proposal must be past expiry threshold.
        @notice Emits {ProposalEvent} event with status {Cancelled}.
     */
    public shared(msg) func cancelProposal(chainID: Nat16, depositNonce: Nat64, dataHash: Text) : async CommonResult {
        // assert (_onlyAdmin())
        if (_onlyAdminOrRelayer(Principal.toText(msg.caller)) != true ) {
            throw Error.reject(MSG_ADMIN_OR_RELAYER);
        };
        let proposalId = getProposalId(chainID, depositNonce);
        switch(_proposals.get(proposalId)) {
            case(?dataMap){
                var proposal = switch (dataMap.get(dataHash)) {
                    case (?p) p;
                    case (_) return #Err("proposal not found");
                };
                var currentStatus = proposal.status;
                if (currentStatus != #active or currentStatus != #passed) {
                    return #Err("Proposal cannot be cancelled");
                };

                // need to discuss in-depth
                if(Time.now() - proposal.proposedTime > expiry_){
                    return #Err("Proposal not at expiry threshold");
                };
                
                currentStatus := #cancelled;

                proposal := {
                    status = currentStatus;
                    yesVotes =   proposal.yesVotes;
                    yesVotesTotal =  proposal.yesVotesTotal;
                    proposedTime = Time.now();
                };
                dataMap.put(dataHash, proposal);
                _proposals.put(proposalId, dataMap);

                // Todo emit ProposalEvent

                return #Ok(?"proposal excute cancel success");
            };
            case(_) return #Err("can't not find proposal data");
        };
    };


    /**
        @notice Executes a deposit proposal that is considered passed using a specified handler contract.
        @notice Only callable by relayers when Bridge is not paused.
        @param chainID ID of chain deposit originated from.
        @param resourceID ResourceID to be used when making deposits.
        @param depositNonce ID of deposited generated by origin Bridge contract.
        @param data Data originally provided when deposit was made.
        @notice Proposal must have Passed status.
        @notice Hash of {data} must equal proposal's {dataHash}.
        @notice Emits {ProposalEvent} event with status {Executed}.
     */
    public shared(msg) func executeProposal(chainID: Nat16, depositNonce: Nat64, data: DepositData, resourceID: Text) : async CommonResult {
        // onlyRelayers whenNotPaused
        // assert (_onlyAdmin())
        if (_onlyRelayers(Principal.toText(msg.caller)) != true ) {
            throw Error.reject(MSG_ONLY_RELAYER);
        };
        // whenNotPaused
        if (_paused == true) {
            throw Error.reject(MSG_PAUSED);
        };
    
        let proposalId = getProposalId(chainID, depositNonce);
        switch(_resourceIDToHandlerAddress.get(resourceID)) {
            case(?handlerAddress){
                _ercHandlerCanister := ?actor(handlerAddress);
                // bytes32 dataHash = keccak256(abi.encodePacked(handler, data));
                
                let handlerAddressBytes = Blob.toArray(Text.encodeUtf8(handlerAddress));
                let dataBytes = Blob.toArray(Text.encodeUtf8(data.recipientAddress # Nat.toText(data.amount)));
                let bytes : [Nat8]= Array.flatten([ Nat64Ext.toNat8Array(depositNonce),
                                                    Nat16Ext.toNat8Array(chainID),
                                                    handlerAddressBytes, dataBytes]);

                let dataHash = SHA256.encode(SHA256.sha256(bytes));
                Debug.print("executeProposal dataHash--> :" # debug_show(dataHash));
                switch(_proposals.get(proposalId)) {
                    case(?dataMap){
                        switch (dataMap.get(dataHash)) {
                            case(?p) {
                                Debug.print("executeProposal Proposal--> :" # debug_show(p));
                                if(p.status != #passed){
                                    return #Err("Proposal must have Passed status");
                                };
                                let proposal = {
                                    status = #executed;
                                    yesVotes =  p.yesVotes;
                                    yesVotesTotal =  p.yesVotesTotal;
                                    proposedTime = p.proposedTime;
                                };
                                dataMap.put(dataHash, proposal);
                                _proposals.put(proposalId, dataMap);
                            };
                            case(_) return #Err("proposal not found");
                        };
                    };
                    case(_) return #Err("proposal not found");
                };

                switch(_ercHandlerCanister) {
                    case(?handler) {
                        let execRes = await handler.executeProposal(resourceID, data);
                        if (execRes == true) {
                            // Todo emit ProposalEvent
                            return #Ok(?"execute proposal success");
                        };
                        return #Err(handlerAddress # " handler execute proposal error");
                    };
                    case(_) throw Error.reject(MSG_NO_HANDLER);
                };
            };
            case(_) throw Error.reject(MSG_NO_HANDLER);
        };
    };

   
    /**
        @notice Transfers eth in the contract to the specified addresses. The parameters addrs and amounts are mapped 1-1.
        This means that the address at index 0 for addrs will receive the amount (in WEI) from amounts at index 0.
        @param addrs Array of addresses to transfer {amounts} to.
        @param amounts Array of amonuts to transfer to {addrs}.
     */
    public shared(msg) func transferFunds(addrs: [Text], amounts: [Nat]) : async CommonResult {
        // assert (_onlyAdmin())
        if (_onlyAdmin(Principal.toText(msg.caller)) != true ) {
            throw Error.reject(MSG_ONLY_ADMIN);
        };
         // Todo
        // Transfers eth in the contract to the specified addresses. The parameters addrs and amounts are mapped 1-1.
        return #Ok(null);
    };
    
    private func getProposalId(chainID: Nat16, depositNonce: Nat64) : Blob {
        Blob.fromArray(Array.flatten([ Nat64Ext.toNat8Array(depositNonce),Nat16Ext.toNat8Array(chainID)]));
    };

    // system func preupgrade() {
    //     _rolesEntries := Iter.toArray(_roles.entries());
    //     _resourceIDToHandlerAddressEntries := Iter.toArray(_resourceIDToHandlerAddress.entries());
    //     _depositCountsEntries := Iter.toArray(_depositCounts.entries());

    //     let proposalSize : Nat = _proposals.size();
    //     var tmpProposalArr : [var (Text, [(Text, Proposal)])] = Array.init<(Text, [(Text, Proposal)])>(proposalSize, ("1", []));
        
    //     var index : Nat = 0;
    //     for ((k, v) in _proposals.entries()) {
    //         tmpProposalArr[index] := (k, Iter.toArray(v.entries()));
    //         index += 1;
    //     };
    //     _proposalsEntries := Array.freeze(tmpProposalArr);

    // };

    // system func postupgrade() {
    //     _roles := HashMap.fromIter<Text, RoleData>(_rolesEntries.vals(), 1, Text.equal, Text.hash);
    //     _rolesEntries := [];

    //     _resourceIDToHandlerAddress := HashMap.fromIter<Text, Text>(_resourceIDToHandlerAddressEntries.vals(), 1, Text.equal, Text.hash);
    //     _resourceIDToHandlerAddressEntries := [];

    //     _depositCounts := HashMap.fromIter<Nat32, Nat>(_depositCountsEntries.vals(), 1, Nat32.equal, func(x : Nat32) : Hash.Hash {x});
    //     _depositCountsEntries := [];

    //     for ((k, v) in _proposalsEntries.vals()) {
    //         let proposalTemp = HashMap.fromIter<Text, Proposal>(v.vals(), 1, Text.equal, Text.hash);
    //         _proposals.put(k, proposalTemp);
    //     };
    //     _proposalsEntries := [];

    // };

}
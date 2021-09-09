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
    type Token = Tokens.Token;
    type DepositRecord = ShareTypes.DepositRecord;
    private stable var owner_ : Principal = Principal.fromText("xvfsm-gaya2-2xarb-luyiv-cuec2-tszas-n3tda-opqk6-drk22-v65j5-sqe");

    // resourceID => token contract address
    private var _resourceIDToTokenContractAddress = HashMap.HashMap<Text, Token>(1, Text.equal, Text.hash);

    // token contract address => resourceID
    private var _tokenContractAddressToResourceID = HashMap.HashMap<Text, Text>(1, Text.equal, Text.hash);

    // token contract address => is whitelisted
    private var _contractWhitelist = HashMap.HashMap<Text, Bool>(1, Text.equal, Text.hash);

    // token contract address => is burnable
    private var _burnList = HashMap.HashMap<Text, Bool>(1, Text.equal, Text.hash);

    // return resourceId
    public shared({ caller }) func setResource(chainId: Nat32, _name: Text, _symbol: Text, _decimals: Nat
    , _totalSupply: Nat, _owner: Principal) : async Text {
        assert(Principal.equal(owner_, caller));
        var resourceID : Text = "";
        Debug.print("setResource Cycles: " # debug_show(Cycles.balance(), resourceID));
        // provision cycles for next call (might need some more)
        Cycles.add(5_000_000_000_000); 
        var token_ = ?(await Tokens.Token(_name, _symbol, _decimals, _totalSupply, owner_));
        let thisAddress = Principal.fromActor(ICErc20Handler);
        if (token_ != null) {
            let tokenAddress : Principal = await Option.unwrap(token_).getTokenAddress();
            var tokenAddressText = Principal.toText(tokenAddress);
            // put resourceId & tokenAddress
            resourceID := Nat32.toText(chainId) # "_" # Principal.toText(tokenAddress);
            // set resource token
            _resourceIDToTokenContractAddress.put(resourceID, Option.unwrap(token_));
            // set token resource
            _tokenContractAddressToResourceID.put(tokenAddressText, resourceID);
            // set whitelist
            _contractWhitelist.put(tokenAddressText, true);
            ignore await Option.unwrap(token_).newStorageCanister(owner_);
        };
        resourceID; 
    };

    // set _burnList
    public func setBurnable(tokenAddressText : Text) : async Bool {
        switch (_contractWhitelist.get(tokenAddressText)) {
            case (?r) {
                _burnList.put(tokenAddressText, true);
                true;
            };
            case (_) false;
      };
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
    public shared(msg) func deposit(resourceID :Text, destinationChainID: Nat8,depositNonce: Nat64
    , depositer: Principal,recipientAddress: Principal, amount: Nat, fee: Nat) : async ?Text {
        // only Bridge call
        // assert(msg.caller == bridge);
        // 2 get resourceId map token
        var token_ = _resourceIDToTokenContractAddress.get(resourceID);
        assert(Option.isSome(token_));
        var tokenAddress : Principal = await Option.unwrap(token_).getTokenAddress();
        var tokenAddressText = Principal.toText(tokenAddress);
        let desIdNonce :Text = Nat8.toText(destinationChainID) # "_" # Nat64.toText(depositNonce);
        // white list
        switch (_contractWhitelist.get(tokenAddressText)) {
            case (?r) {
                assert(r);
                // burn list
                switch (_burnList.get(tokenAddressText)) {
                    case(?r) {
                        let burnR = await Option.unwrap(token_).burn(depositer,amount);
                    };
                    case(_) {
                        // lockERC20(tokenAddress, depositer, address(this), amount);
                        let contractAddress = Principal.fromActor(ICErc20Handler);
                        // 侵入性
                        let lockR = await lockERC20(Option.unwrap(token_),depositer,contractAddress,amount);
                    };
                }; 
                let o : DepositRecord = {
                    caller = msg.caller;
                    index = 0;
                    destinationChainID = destinationChainID;
                    depositNonce = depositNonce;
                    desIdNonce = desIdNonce;
                    resourceID = resourceID;
                    depositer = ?depositer;
                    recipientAddress = ?recipientAddress;
                    amount = amount;
                    fee = fee;
                    timestamp = Time.now();
                };
                ignore await Option.unwrap(token_).addDepositeRecord(o);
          };
          case (_) {
            Debug.print("provided tokenAddress is not whitelisted");
          };
        };
        ?desIdNonce;
    };

    /**
        @notice Used to gain custody of deposited token.
        @param tokenAddress Address of ERC20 to transfer.
        @param owner Address of current token owner.
        @param recipient Address to transfer tokens to.
        @param amount Amount of tokens to transfer.
     */
    private func lockERC20(token_: Token,from: Principal,
        to: Principal, value: Nat): async Bool {
        let r = await token_.transferFrom(from, to, value);
        r;
    };


    // query deposit record
    public shared(msg) func getDepositRecordByDesIdAndNonce(resourceID: Text,destinationChainID: Nat8, depositNonce: Nat64) : async ?DepositRecord {
        var token_ = _resourceIDToTokenContractAddress.get(resourceID);
        // 这里deposite 记录要独立存储
        var res: ?DepositRecord = null;
        if (token_ != null) {
            res := await Option.unwrap(token_).getDepositRecordByDesIdAndNonce(destinationChainID, depositNonce);
        };
        res;
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

}
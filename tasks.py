from invoke import task

@task
def start(c):
    c.run("dfx identity new id_alice || true")
    print("\033[0;32;40m start \033[0m")

@task(start)
def build(c):
    c.run("dfx canister --no-wallet create --all")
    c.run("dfx build --all")
    print("\033[0;32;40m build completed\033[0m")

@task(build)
def install(c):
    principal_id = c.run("dfx identity get-principal").stdout.replace("\n", "")
    resource_id_rs = "1-dft-rs"
    token_address_rs = "rrkah-fqaaa-aaaaa-aaaaq-cai"
    resource_id_mo = "1-dft-mo"
    token_address_mo = "rwlgt-iiaaa-aaaaa-aaaaa-cai"
    burn_address_1 = "rrkah-fqaaa-aaaaa-aaaaq-cai-b1"
    burn_address_2 = "rrkah-fqaaa-aaaaa-aaaaq-cai-b2"
    toke_fee = "1:nat"
    ## 300s 5min
    expiryTime = "300000000000:nat"
    c.run("dfx canister --no-wallet install Bridge --argument '(1:nat16, 2:nat8, 100:nat, "+expiryTime+", principal \"" + principal_id + "\")'")
    bridge_id = c.run("dfx canister id Bridge").stdout.replace("\n", "")
    c.run("dfx canister --no-wallet install Erc20Handler --argument '(\"" + bridge_id + "\", vec { record {contractAddress = \"" + token_address_rs + "\"; resourceID = \"" + resource_id_rs + "\";tokenActorType = variant { dft }; fee = "+toke_fee+" }; record {contractAddress = \"" + token_address_mo + "\"; resourceID = \"" + resource_id_mo + "\";tokenActorType = variant { ext }; fee = "+toke_fee+" } }, vec { \"" + burn_address_1 + "\"; \"" + burn_address_2 + "\"})' ")
    print("\033[0;32;40m install completed\033[0m")


@task(build)
def reinstall(c):
    principal_id = c.run("dfx identity get-principal").stdout.replace("\n", "")
    resource_id_rs = "1-dft-rs"
    token_address_rs = "rrkah-fqaaa-aaaaa-aaaaq-cai"
    resource_id_mo = "1-dft-mo"
    token_address_mo = "rwlgt-iiaaa-aaaaa-aaaaa-cai"
    burn_address_1 = "rrkah-fqaaa-aaaaa-aaaaq-cai-b1"
    burn_address_2 = "rrkah-fqaaa-aaaaa-aaaaq-cai-b2"
    toke_fee = "1:nat"
    expiryTime = "300000000000:nat"
    c.run("dfx canister --no-wallet install Bridge -m reinstall --all --argument '(1:nat16, 2:nat8, 100:nat, "+expiryTime+", principal \"" + principal_id + "\")'")
    bridge_id = c.run("dfx canister id Bridge").stdout.replace("\n", "")
    c.run("dfx canister --no-wallet install Erc20Handler -m reinstall --all --argument '(\"" + bridge_id + "\", vec { record {contractAddress = \"" + token_address_rs + "\"; resourceID = \"" + resource_id_rs + "\";tokenActorType = variant { dft }; fee = "+toke_fee+"}; record {contractAddress = \"" + token_address_mo + "\"; resourceID = \"" + resource_id_mo + "\";tokenActorType = variant { ext }; fee = "+toke_fee+"} }, vec { \"" + burn_address_1 + "\"; \"" + burn_address_2 + "\"})' ")
    print("\033[0;32;40m reinstall completed\033[0m")

@task(build)
def upgrade(c):
    principal_id = c.run("dfx identity get-principal").stdout.replace("\n", "")
    resource_id_rs = "1-dft-rs"
    token_address_rs = "rrkah-fqaaa-aaaaa-aaaaq-cai"
    resource_id_mo = "1-dft-mo"
    token_address_mo = "rwlgt-iiaaa-aaaaa-aaaaa-cai"
    burn_address_1 = "rrkah-fqaaa-aaaaa-aaaaq-cai-b1"
    burn_address_2 = "rrkah-fqaaa-aaaaa-aaaaq-cai-b2"
    toke_fee = "1:nat"
    expiryTime = "300000000000:nat"
    c.run("dfx canister --no-wallet install Bridge -m upgrade --all --argument '(1:nat16, 2:nat8, 100:nat, "+expiryTime+", principal \"" + principal_id + "\")'")
    bridge_id = c.run("dfx canister id Bridge").stdout.replace("\n", "")
    c.run("dfx canister --no-wallet install Erc20Handler -m upgrade --all --argument '(\"" + bridge_id + "\", vec { record {contractAddress = \"" + token_address_rs + "\"; resourceID = \"" + resource_id_rs + "\";tokenActorType = variant { dft }; fee = "+toke_fee+"}; record {contractAddress = \"" + token_address_mo + "\"; resourceID = \"" + resource_id_mo + "\";tokenActorType = variant { ext }; fee = "+toke_fee+"} }, vec { \"" + burn_address_1 + "\"; \"" + burn_address_2 + "\"})' ")
    print("\033[0;32;40m upgrade completed\033[0m")



@task(upgrade)
def adminSetResource(c):
    resource_id_rs = "1-dft-rs"
    toke_fee = "1:nat"
    token_address_rs = "rrkah-fqaaa-aaaaa-aaaaq-cai"
    bridge_id = c.run("dfx canister id Bridge").stdout.replace("\n", "")
    handler_id = c.run("dfx canister id Erc20Handler").stdout.replace("\n", "")
    assert "Ok" in c.run("dfx canister call " + bridge_id + " adminSetResource '(\"" + handler_id + "\",\"" + resource_id_rs + "\",\"" + token_address_rs + "\", variant { dft },"+ toke_fee +" )'").stdout
    print("\033[0;32;40m adminSetResource completed\033[0m")

@task()
def adminChangeRelayerThreshold(c):
    newThreshold = "2:nat8"
    bridge_id = c.run("dfx canister id Bridge").stdout.replace("\n", "")

    assert "true" in c.run("dfx canister call \"" + bridge_id + "\" adminChangeRelayerThreshold '(" + newThreshold + ")'").stdout

    print("\033[0;32;40m adminChangeRelayerThreshold success \033[0m")

@task(adminChangeRelayerThreshold)
def adminAddRelayer(c):
    relayer_default_id = c.run("dfx identity get-principal").stdout.replace("\n", "")
    relayser_alice_id = c.run("dfx --identity id_alice identity get-principal").stdout.replace("\n", "")
    bridge_id = c.run("dfx canister id Bridge").stdout.replace("\n", "")

    assert "true" in c.run("dfx canister call \"" + bridge_id + "\" adminAddRelayer '(\"" + relayer_default_id + "\")'").stdout

    assert "true" in c.run("dfx canister call \"" + bridge_id + "\" adminAddRelayer '(\"" + relayser_alice_id + "\")'").stdout

    print("\033[0;32;40m adminAddRelayer success \033[0m")

@task(adminSetResource,adminAddRelayer)
def initResource(c):
    print("\033[0;32;40m init resource success \033[0m")

@task()
def deposit(c):
    print("\033[0;32;40m start deposite ...\033[0m")
    resource_id = "1-dft-rs"
    bridge_id = c.run("dfx canister id Bridge").stdout.replace("\n", "")
    depositer_id = c.run("dfx identity get-principal").stdout.replace("\n", "")
    recipient_id = c.run("dfx --identity id_alice identity get-principal").stdout.replace("\n", "")
    print("\033[0;32;40m Bridge \"" + bridge_id + "\" \033[0m")
    print("\033[0;32;40m depositer_id \"" + depositer_id + "\" \033[0m")
    print("\033[0;32;40m recipient_id \"" + recipient_id + "\" \033[0m")

    assert "Ok" in c.run("dfx canister call \"" + bridge_id + "\" deposit '(\"" + resource_id + "\",1:nat16,\"" + depositer_id + "\",record {amount = 1000:nat;recipientAddress = \"" + recipient_id + "\"})'").stdout
    print("\033[0;32;40m deposit success \033[0m")

    assert "opt record" in c.run("dfx canister call \"" + bridge_id + "\" getDepositRecord '(\"" + resource_id + "\",1:nat16,1:nat64)'").stdout
    print("\033[0;32;40m getDepositRecord success \033[0m")






@task()
def voteProposal(c):
    print("\033[0;32;40m start voteProposal ...\033[0m")
    resource_id = "1-dft-rs"
    deposit_nonce  = "1:nat64"
    chainID = "1:nat16"
    dataHash = "ee66c40895a07961fe4efe6a6012c694ee873e644dc6c52406361d9e900f5783"
    bridge_id = c.run("dfx canister id Bridge").stdout.replace("\n", "")
    print("\033[0;32;40m Bridge \"" + bridge_id + "\" \033[0m")

    vote1 = c.run("dfx identity get-principal").stdout.replace("\n", "")

    assert "Ok" in  c.run("dfx canister call \"" + bridge_id + "\" voteProposal '(" + chainID + "," +deposit_nonce+ "," + "\"" + resource_id + "\", \"" + dataHash + "\")'").stdout

    print("\033[0;32;40m vote1:"+vote1+"-> vote success \033[0m")

    c.run("dfx identity use id_alice").stdout

    vote2 = c.run("dfx identity get-principal").stdout.replace("\n", "")

    assert "Ok" in  c.run("dfx canister call \"" + bridge_id + "\" voteProposal '(" + chainID + "," +deposit_nonce+ "," + "\"" + resource_id + "\", \"" + dataHash + "\")'").stdout

    print("\033[0;32;40m vote2:"+vote2+"-> vote success \033[0m")

    c.run("dfx identity use default").stdout

    print("\033[0;32;40m identity use default \033[0m")


@task()
def approveContract(c):
    token_address_rs = "rrkah-fqaaa-aaaaa-aaaaq-cai"
    # motoko
    # token_address_rs = "rwlgt-iiaaa-aaaaa-aaaaa-cai"
    recipientAddress = c.run("dfx canister id Erc20Handler").stdout.replace("\n", "")
    principal_id = c.run("dfx identity get-principal").stdout.replace("\n", "")
    value = "100000001:nat"
    tvalue = "100000000:nat"

    print("\033[0;32;40m balanceOf: "+principal_id+" \033[0m")
    c.run("dfx canister call " + token_address_rs + " balanceOf '(\"" + principal_id + "\")'").stdout

    print("\033[0;32;40m balanceOf: "+recipientAddress+" \033[0m")
    c.run("dfx canister call " + token_address_rs + " balanceOf '(\"" + recipientAddress + "\")'").stdout

    print("\033[0;32;40m approve: "+value+" \033[0m")
    c.run("dfx canister call " + token_address_rs + " approve '(null, \"" + principal_id + "\"," + value + ",null)'").stdout

    print("\033[0;32;40m allowance: "+value+" \033[0m")
    c.run("dfx canister call " + token_address_rs + " allowance '(\"" + principal_id + "\", \"" + recipientAddress + "\")'").stdout

    print("\033[0;32;40m transferFrom : "+tvalue+" \033[0m")
    c.run("dfx canister call " + token_address_rs + " transferFrom '(null,\"" + principal_id + "\", \"" + 
    recipientAddress + "\","+tvalue+")'").stdout

    print("\033[0;32;40m balanceOf: "+principal_id+" \033[0m")
    c.run("dfx canister call " + token_address_rs + " balanceOf '(\"" + principal_id + "\")'").stdout

    print("\033[0;32;40m balanceOf: "+recipientAddress+" \033[0m")
    c.run("dfx canister call " + token_address_rs + " balanceOf '(\"" + recipientAddress + "\")'").stdout


    print("\033[0;32;40m approveBridge success \033[0m")

@task(deposit,voteProposal)
def executeProposal(c):
    print("\033[0;32;40m start executeProposal ...\033[0m")
    resource_id = "1-dft-rs"
    deposit_nonce  = "1:nat64"
    chainID = "1:nat16"
    recipient_id = c.run("dfx --identity id_alice identity get-principal").stdout.replace("\n", "")
    bridge_id = c.run("dfx canister id Bridge").stdout.replace("\n", "")
    print("\033[0;32;40m Bridge \"" + bridge_id + "\" \033[0m")

    
    c.run("dfx canister call \"" + bridge_id + "\" executeProposal '(" + chainID + "," +deposit_nonce+ "," + "record {amount = 1000:nat; recipientAddress = \"" + recipient_id + "\";}, " + "\"" + resource_id + "\")'").stdout
    print("\033[0;32;40m executeProposal success \033[0m")


@task(install,initResource,deposit,voteProposal,executeProposal, default=True)
def invoke(c):
    print("\033[0;32;40m test flow \033[0m")

@task()
def showBalance(c):
    token_address_rs = "rrkah-fqaaa-aaaaa-aaaaq-cai"
    handlerAddress = c.run("dfx canister id Erc20Handler").stdout.replace("\n", "")
    depositer_id = c.run("dfx identity get-principal").stdout.replace("\n", "")
    bridge_id = c.run("dfx canister id Bridge").stdout.replace("\n", "")
    recipient_id = c.run("dfx --identity id_alice identity get-principal").stdout.replace("\n", "")
    
    print("\033[0;32;40m balanceOf depositer_id: "+depositer_id+" \033[0m")
    c.run("dfx canister call " + token_address_rs + " balanceOf '(\"" + depositer_id + "\")'").stdout

    print("\033[0;32;40m balanceOf bridge_id: "+bridge_id+" \033[0m")
    c.run("dfx canister call " + token_address_rs + " balanceOf '(\"" + bridge_id + "\")'").stdout


    print("\033[0;32;40m balanceOf handlerAddress: "+handlerAddress+" \033[0m")
    c.run("dfx canister call " + token_address_rs + " balanceOf '(\"" + handlerAddress + "\")'").stdout

    print("\033[0;32;40m balanceOf recipient_id: "+recipient_id+" \033[0m")
    c.run("dfx canister call " + token_address_rs + " balanceOf '(\"" + recipient_id + "\")'").stdout


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
    c.run("dfx canister --no-wallet install Bridge")
    c.run("dfx canister --no-wallet install ERC20Handler")
    print("\033[0;32;40m install completed\033[0m")


@task(build)
def upgrade(c):
    c.run("dfx canister --no-wallet install Bridge -m reinstall --all")
    c.run("dfx canister --no-wallet install ERC20Handler -m reinstall --all")
    print("\033[0;32;40m upgrade completed\033[0m")

@task(upgrade, default=True)
def deposit(c):
    print("\033[0;32;40m set resoure ...\033[0m")
    canister_id = c.run("dfx canister id ERC20Handler").stdout.replace("\n", "")
    principal_id = c.run("dfx identity get-principal").stdout.replace("\n", "")
    recipient_id = c.run("dfx --identity id_alice identity get-principal").stdout.replace("\n", "")
    print("\033[0;32;40m ERC20Handler \"" + canister_id + "\" \033[0m")
    print("\033[0;32;40m depositer_id \"" + principal_id + "\" \033[0m")
    print("\033[0;32;40m recipient_id \"" + recipient_id + "\" \033[0m")
    rid = c.run("dfx canister call ERC20Handler setResource '(1,\"WICP Name\",\"WICP\",8,1000000,principal \"" + principal_id + "\")'").stdout
    resource_id = rid.replace("\n", "").replace(" ", "").replace(
        "(\"", "").replace(
        "\")", "")
    print("\033[0;32;40m resource_id \"" + resource_id + "\" \033[0m")
    tokenAddr = resource_id.split("_")[1]
    print("\033[0;32;40m get token address \"" + tokenAddr + "\" \033[0m")
    print("\033[0;32;40m token approve start ....\033[0m")
    assert "true" in c.run("dfx canister call " + tokenAddr + " approve '(principal \"" + canister_id + "\",1000000:nat)'").stdout
    assert "true" in c.run("dfx canister call " + tokenAddr + " approve '(principal \"" + principal_id + "\",1000000:nat)'").stdout
    assert "true" in c.run("dfx canister call " + tokenAddr + " approve '(principal \"" + recipient_id + "\",1000000:nat)'").stdout
    
    print("\033[0;32;40m deposit start ....\033[0m")

    depositer_banlance = c.run("dfx canister call " + tokenAddr + " balanceOf '(principal \"" + principal_id + "\")'").stdout
    print("\033[0;32;40m depositer init banlance \"" + depositer_banlance + "\" \033[0m")

    contract_banlance = c.run("dfx canister call " + tokenAddr + " balanceOf '(principal \"" + canister_id + "\")'").stdout
    print("\033[0;32;40m contract init banlance \"" + contract_banlance + "\" \033[0m")


    record_r = c.run("dfx canister call Bridge deposit '(\"" + resource_id + "\",1,principal \"" + principal_id + "\",principal \"" + recipient_id + "\",1000,10)'").stdout
    deposit_id = record_r.replace("opt", "").replace("\n", "").replace(" ", "").replace(
        "(\"", "").replace(
        "\")", "")
    print("\033[0;32;40m deposit_id \"" + deposit_id + "\" \033[0m")
    deposit_nonces = deposit_id.split("_")
    chain_id = deposit_nonces[0]
    chain_nonce = deposit_nonces[1]
    deposit_record = c.run("dfx canister call Bridge getDepositRecord '(\"" + resource_id + "\"," + chain_id + "," + chain_nonce + ")'").stdout
    print("\033[0;32;40m deposit_record \"" + deposit_record + "\" \033[0m")

    depositer_banlance = c.run("dfx canister call " + tokenAddr + " balanceOf '(principal \"" + principal_id + "\")'").stdout
    print("\033[0;32;40m depositer deposit banlance \"" + depositer_banlance + "\" \033[0m")

    contract_banlance = c.run("dfx canister call " + tokenAddr + " balanceOf '(principal \"" + canister_id + "\")'").stdout
    print("\033[0;32;40m contract deposit banlance \"" + contract_banlance + "\" \033[0m")

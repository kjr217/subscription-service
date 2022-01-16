import brownie
import constants_mainnet


def test_deploy(contracts, deployer):
    print(contracts.host())
    print(contracts.cfa())
    print(contracts.acceptedToken())
    assert contracts.name() == "test"

def test_buy_sub_fails(contracts, deployer):
    with brownie.reverts():
        contracts.buySubscription({"from": deployer})

def test_buy_sub(contracts, deployer, cfav1):
    cfav1.createFlow(
        constants_mainnet.DAIx,
        contracts,
        constants_mainnet.FLOW,
        "0x",
        {"from": deployer}
    )
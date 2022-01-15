import brownie
import constants_mainnet


def test_deploy(contracts, deployer):
    print(contracts.host())
    print(contracts.cfa())
    print(contracts.acceptedToken())
    contracts.registerApp({"from": deployer})
    assert contracts.name() == "test"

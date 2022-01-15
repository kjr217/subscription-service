import brownie
import constants_mainnet


def test_deploy(contracts, deployer):
    assert contracts.name() == "test"

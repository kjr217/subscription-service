import pytest
import time
import constants_mainnet
from brownie import (
    accounts,
    SubscriptionService
)


@pytest.fixture(scope="function", autouse=True)
def isolate_func(fn_isolation):
    # perform a chain rewind after completing each test, to ensure proper isolation
    # https://eth-brownie.readthedocs.io/en/v1.10.3/tests-pytest-intro.html#isolation-fixtures
    pass

@pytest.fixture
def deployer():
    yield accounts[1]

@pytest.fixture
def contracts(accounts, deployer):
    sub = SubscriptionService.deploy(
        "test", 
        "test",
        constants_mainnet.HOST,
        constants_mainnet.CFA,
        constants_mainnet.DAIx,
        constants_mainnet.FLOW,
        {"from": deployer} 
        )
    yield sub 

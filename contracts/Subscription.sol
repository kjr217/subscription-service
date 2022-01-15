// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.4;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RedirectAll.sol";

import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    ContextDefinitions,
    SuperAppDefinitions
} from "./superfluid/interfaces/superfluid/ISuperfluid.sol";

/**
 * @title  SubscriptionService
 * @author LBL
 * @notice A contract that allows anyone to mint an NFT with an attached superfluid stream
 *         user then gets access to an offchain subscription so long as they hold the nft and
 *         pay the subscription
 */
contract SubscriptionService is ERC721, Ownable, RedirectAll {
uint256 public tokenIdEnum; 

constructor (
    string memory _name, 
    string memory _symbol,
    address _host,
    address _cfa,
    address _acceptedToken,
    int96 _expectedInflow
    )
    ERC721(_name, _symbol)
    RedirectAll (
      _host,
      _cfa,
      _acceptedToken,
      _expectedInflow
     )
    {}

function buySubscription() external returns (uint256 tokenId) {
    require(checkPaying(msg.sender), "pay ur sub mate");
    _safeMint(msg.sender, tokenIdEnum++ );
}

function validateSubscription(address _check) external view returns (bool sub) {
    if (balanceOf(_check) > 0 && checkPaying(_check)) {
        sub = true;
    }
}

function checkPaying(address _check) public view returns (bool paying) {
    (,int96 outFlowRate,,) = cfa.getFlow(acceptedToken, _check, address(this));
    if (outFlowRate >= expectedInflow) {
        paying = true;
    }
}

function _beforeTokenTransfer(
address from,
address to,
uint256 tokenId
) internal override {
    _deleteTokenSubscription(tokenId);
    _addPendingSub(to, tokenId);
}
}

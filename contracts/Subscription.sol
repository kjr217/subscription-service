// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.4;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    ContextDefinitions,
    SuperAppDefinitions
} from "./superfluid/interfaces/superfluid/ISuperfluid.sol";

import {
    IConstantFlowAgreementV1
} from "./superfluid/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {
    SuperAppBase
} from "./superfluid/apps/SuperAppBase.sol";

/**
 * @title  SubscriptionService
 * @author LBL
 * @notice A contract that allows anyone to mint an NFT with an attached superfluid stream
 *         user then gets access to an offchain subscription so long as they hold the nft and
 *         pay the subscription
 */
contract SubscriptionService is ERC721, Ownable, SuperAppBase {

uint256 public tokenIdEnum;

ISuperfluid public host; // host
IConstantFlowAgreementV1 public cfa; // the stored constant flow agreement class address
ISuperToken public acceptedToken; // accepted token

mapping(uint256 => address) public subscriptions; // tokenId to owner address

mapping(address => uint256) public pendingSubs;

mapping(address => uint256) public subscribers;
    
int96 public expectedInflow;

constructor (
    string memory _name, 
    string memory _symbol,
    address _host,
    address _cfa,
    address _acceptedToken,
    int96 _expectedInflow
    )
    ERC721(_name, _symbol)
    {host = ISuperfluid(_host);
        cfa = IConstantFlowAgreementV1(_cfa);
        acceptedToken = ISuperToken(_acceptedToken);
        expectedInflow = _expectedInflow;
        uint256 configWord = SuperAppDefinitions.APP_LEVEL_FINAL;
        host.registerApp(configWord);
    }

event SubscriptionDeleted(uint256 tokenId, address sender);
    /**************************************************************************
     * Redirect Logic
     *************************************************************************/

function checkSubscription(uint256 tokenId)
    external view
    returns (
        uint256 startTime,
        address receiver,
        int96 flowRate
    )
    {
        address _sender = subscriptions[tokenId];
        if (_sender != address(0)) {
            (startTime, flowRate,,) = cfa.getFlow(acceptedToken, _sender, address(this));
            receiver = _sender;
        }
}

function _deleteTokenSubscription( uint256 tokenId) internal returns (bytes memory newCtx) {
    if (subscriptions[tokenId] == address(0)) {
        return newCtx;
    } 
    address sender = subscriptions[tokenId];
    (,int96 outFlowRate,,) = cfa.getFlow(acceptedToken, sender, address(this)); //CHECK: unclear what happens if flow doesn't exist.
    if(outFlowRate > 0){
        newCtx = host.callAgreement(
            cfa,
            abi.encodeWithSelector(
                cfa.deleteFlow.selector,
                acceptedToken,
                subscriptions[tokenId],
                address(this),
                new bytes(0)
            ),
            "0x"
        );
    }
    
    subscribers[sender] = 0;
    subscriptions[tokenId] = address(0); // this token is now up for grabs (by the holder of the NFT)
    pendingSubs[sender] = tokenId;

    emit SubscriptionDeleted(tokenId, sender);
}

function _deleteAgreementSubscription( bytes memory _ctx) internal returns (bytes memory newCtx) {
    address sender = host.decodeCtx(_ctx).msgSender;
    uint256 tokenId = subscribers[sender];
    
    subscribers[sender] = 0;
    subscriptions[tokenId] = address(0); // this token is now up for grabs (by the holder of the NFT)

    emit SubscriptionDeleted(tokenId, sender);
}


function _addSubscription(bytes32 agreementId, bytes calldata ctx) internal  {
    address sender = host.decodeCtx(ctx).msgSender;

    // Just for reference of what we actually get back. Can be compressed soon
    (uint256 timestamp,int96 outFlowRate, uint256 deposit, uint256 owedDeposit) = cfa.getFlowByID(acceptedToken, agreementId);
    
    
    if (pendingSubs[sender] != 0) { 
        require(outFlowRate >= expectedInflow, "Need to update the flow, too little for subscription guidelines");
        // Require something about deposits maybe

        subscriptions[pendingSubs[sender]] = sender ; 
        subscribers[sender] = pendingSubs[sender];
        pendingSubs[sender] = 0;
    }
}

function _checkSubscription(bytes32 agreementId, bytes calldata ctx) internal returns (bool success){
    (,int96 outFlowRate, ,) = cfa.getFlowByID(acceptedToken, agreementId);

    if (outFlowRate >= expectedInflow) {
        return true;
    }
    else {
        address sender = host.decodeCtx(ctx).msgSender;
        subscriptions[subscribers[sender]] = address(0);
        subscribers[sender] = 0;
    }

}

function _addPendingSub(address subscriber, uint256 tokenId) internal {
    pendingSubs[subscriber] = tokenId;

}

/**************************************************************************
    * SuperApp callbacks
    *************************************************************************/

function afterAgreementCreated(
    ISuperToken _superToken,
    address _agreementClass,
    bytes32  _agreementId,
    bytes calldata _agreementData,
    bytes calldata ,// _cbdata,
    bytes calldata _ctx
)
    external override
    onlyExpected(_superToken, _agreementClass)
    onlyHost
    returns (bytes memory /*newCtx*/)
{
    // Update the dictionary after checking the outflow is the correct amount
    _addSubscription(_agreementId, _ctx);
}

function afterAgreementUpdated(
    ISuperToken _superToken,
    address _agreementClass,
    bytes32 _agreementId,
    bytes calldata, //agreementData,
    bytes calldata ,//_cbdata,
    bytes calldata _ctx
)
    external override
    onlyExpected(_superToken, _agreementClass)
    onlyHost
    returns (bytes memory /*newCtx*/)
{
    _checkSubscription(_agreementId, _ctx);
}

function afterAgreementTerminated(
    ISuperToken _superToken,
    address _agreementClass,
    bytes32 _agreementId,
    bytes calldata /*_agreementData*/,
    bytes calldata ,//_cbdata,
    bytes calldata _ctx
)
    external override
    onlyHost
    returns (bytes memory)
{
    // According to the app basic law, we should never revert in a termination callback
    if (!_isSameToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;
    
    return _deleteAgreementSubscription(_ctx);
}

function _isSameToken(ISuperToken superToken) private view returns (bool) {
    return address(superToken) == address(acceptedToken);
}

function _isCFAv1(address agreementClass) private view returns (bool) {
    return ISuperAgreement(agreementClass).agreementType()
        == keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
}

modifier onlyHost() {
    require(msg.sender == address(host), "Support only one host");
    _;
}

modifier onlyExpected(ISuperToken superToken, address agreementClass) {
    require(_isSameToken(superToken), "Not accepted token");
    require(_isCFAv1(agreementClass), "Only CFAv1 supported");
    _;
}

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

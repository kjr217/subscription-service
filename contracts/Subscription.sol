pragma solidity 0.8.4;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  SubscriptionService
 * @author LBL
 * @notice A contract that allows anyone to mint an NFT with an attached superfluid stream
 *         user then gets access to an offchain subscription so long as they hold the nft and
 *         pay the subscription
 */
contract SubscriptionService is ERC721, Ownable, RedirectAll {

uint256 public tokenIdEnum; 

constructor (string memory _name, 
    string memory _symbol,
    ISuperfluid host,
    IConstantFlowAgreementV1 cfa,
    ISuperToken acceptedToken
    ) 
    ERC721(_name, _symbol)
    RedirectAll (
      host,
      cfa,
      acceptedToken,
      owner
     )
    {

    }

function buySubscription() external returns (uint256 tokenId) {
    _safeMint(msg.sender, tokenIdEnum++ );
    openAgreement(); //TODO: Implement this
    
    // setup superfluid stream
}

function openAgreement(uint256 time) public {
    uint256 amount = _expectedInflow * time;
    require(ISuperToken(acceptedToken).balanceOf(msg.sender) > 2*amount, 
        "You don't have the sufficient funds, please acquire more superTokens");
    
    _createFlow(msg.sender);


function checkSubscription(address _check) external view returns (bool sub) {
    if (balanceOf(_check) > 0 && checkPaying(_check)) {
        sub = true;
    }
}

function checkPaying(address _check) public view returns (bool paying) {
    (,int96 outFlowRate,,) = cfa.getFlow(_acceptedToken, _check, address(this));
    if (outFlowRate >= _expectedInflow) {
        paying = True;
    }
}

function _beforeTokenTransfer(
address from,
address to,
uint256 tokenId
) internal override {
    _deleteSubscription(tokenId);

    _addPendingSub(to, tokenId);
    
}

function validateSubscription(

) public returns(bool success) {
    address subscriber = msg.sender();
    createFlow();
    
}



}

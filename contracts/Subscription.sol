pragma solidity 0.8.4;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";



/**
 * @title  SubscriptionService
 * @author LBL
 * @notice A contract that allows anyone to mint an NFT with an attached superfluid stream
 *         user then gets access to an offchain subscription so long as they hold the nft and
 *         pay the subscription
 */
contract SubscriptionService is ERC721, Ownable, RedirectAll {

using SafeERC20 for IERC20;
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
      owner,
     )
    {

    }
    //Can I pass tokenIdEnum to redirectAll??

function withdraw(uint256 amount, address token) external onlyOwner {
    ISuperToken(acceptedToken).transfer(msg.sender, amount);

}

function buySubscription() external returns (uint256 tokenId) {
    _safeMint(msg.sender, tokenIdEnum++ );
    
    checkSubscription(msg.sender);
    
    openAgreement(uint256 time, msg.sender); //TODO: Implement this
    
    // setup superfluid stream
}

function openAgreement(uint256 time, address sender) public {
    uint256 amount = _expectedInflow * time;
    require(ISuperToken(acceptedToken).balanceOf(sender) > 2*amount, 
        "You don't have the sufficient funds, please acquire more superTokens");
    
    _createFlow(sender);


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

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    ContextDefinitions,
    SuperAppDefinitions
} from "@superfluid/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

// When ready to move to leave Remix, change imports to follow this pattern:
// "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {
    SuperAppBase
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

contract RedirectAll is SuperAppBase {

    ISuperfluid private _host; // host
    IConstantFlowAgreementV1 private _cfa; // the stored constant flow agreement class address
    ISuperToken private _acceptedToken; // accepted token
    
    mapping(uint256 => address) private _subscriptions; // tokenId to owner address

    mapping(address => uint256) private _pendingsubs;

    mapping(address => uint256) private _subscribers;
    
    constructor(
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        ISuperToken acceptedToken,
        int96 expectedInflow)
        
        {
        require(address(host) != address(0), "host is zero address");
        require(address(cfa) != address(0), "cfa is zero address");
        require(address(acceptedToken) != address(0), "acceptedToken is zero address");
        require(address(receiver) != address(0), "receiver is zero address");
        require(!host.isApp(ISuperApp(receiver)), "receiver is an app");

        _host = host;
        _cfa = cfa;
        _acceptedToken = acceptedToken;
        _expectedInflow = expectedInflow;

        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        _host.registerApp(configWord);
    }


    /**************************************************************************
     * Redirect Logic
     *************************************************************************/

    function checkSubscription(tokenId)
        external view
        returns (
            uint256 startTime,
            address receiver,
            int96 flowRate
        )
    {
        address _sender = subscriptions[tokenId];
        if (_sender != address(0)) {
            (startTime, flowRate,,) = _cfa.getFlow(_acceptedToken, _sender, address(this));
            receiver = _sender;
        }
    }

    event SubscriptionDeleted(address sender); //what is this?

    /// @dev If a new stream is opened, or an existing one is opened
    function _updateOutflow(bytes calldata ctx)
        private
        returns (bytes memory newCtx)
    {
      newCtx = ctx;
      // @dev This will give me the new flowRate, as it is called in after callbacks
      int96 netFlowRate = _cfa.getNetFlow(_acceptedToken, address(this));
      (,int96 outFlowRate,,) = _cfa.getFlow(_acceptedToken, address(this), _receiver); // CHECK: unclear what happens if flow doesn't exist.
      int96 inFlowRate = netFlowRate + outFlowRate;

      // @dev If inFlowRate === 0, then delete existing flow.
      if (inFlowRate == int96(0)) {
        // @dev if inFlowRate is zero, delete outflow.
          (newCtx, ) = _host.callAgreementWithContext(
              _cfa,
              abi.encodeWithSelector(
                  _cfa.deleteFlow.selector,
                  _acceptedToken,
                  address(this),
                  _receiver,
                  new bytes(0) // placeholder
              ),
              "0x",
              newCtx
          );
        } else if (outFlowRate != int96(0)){
        (newCtx, ) = _host.callAgreementWithContext(
            _cfa,
            abi.encodeWithSelector(
                _cfa.updateFlow.selector,
                _acceptedToken,
                _receiver,
                inFlowRate,
                new bytes(0) // placeholder
            ),
            "0x",
            newCtx
        );
      } else {
      // @dev If there is no existing outflow, then create new flow to equal inflow
          (newCtx, ) = _host.callAgreementWithContext(
              _cfa,
              abi.encodeWithSelector(
                  _cfa.createFlow.selector,
                  _acceptedToken,
                  _receiver,
                  inFlowRate,
                  new bytes(0) // placeholder
              ),
              "0x",
              newCtx
          );
      }
    }

    function _deleteSubscription( uint256 tokenId) internal {
        
        if (_subscriptions[tokenId] == address(0)) return ;
        // @dev delete flow from the old NFT holder
        // The nice thing here is that either party can delete a flow, even the receiver so that's what I'm doing here.
        //TODO: check that the calls to deleteflow are equivalent from both sides of the agreement as this is copypastad from the opposite side (senders side)
        
        address sender = _subscriptions(tokenId)
        (,int96 outFlowRate,,) = _cfa.getFlow(_acceptedToken, sender, address(this)); //CHECK: unclear what happens if flow doesn't exist.
        if(outFlowRate > 0){
          _host.callAgreement(
              _cfa,
              abi.encodeWithSelector(
                  _cfa.deleteFlow.selector,
                  _acceptedToken,
                  _subscriptions[tokenId],
                  address(this),
                  new bytes(0)
              ),
              "0x"
          );
        }
        
        _subscribers[sender] = 0;
        _subscriptions[tokenId] = address(0); // this token is now up for grabs (by the holder of the NFT)

        emit SubscriptionDeleted(tokenId, sender);
    }

    function _addSubscription(bytes32 agreementId) internal  {
        ISuperfluid.Context memory decompiledContext = _host.decodeCtx(_ctx);

        // Just for reference of what we actually get back. Can be compressed soon
        (uint256 timestamp,int96 outFlowRate, uint256 deposit, uint256 owedDeposit) = _cfa.getFlowByID(_acceptedToken, aggreementId);
        
        sender = _getSender(); // No idea how to do this currently
        
        if (_pendingsubs[sender] != 0) { 
            require(outFlowRate >= expectedInFlow, "Need to update the flow, too little for subscription guidelines");
            // Require something about deposits maybe

            _subscriptions[_pendingsubs[sender]] = sender ; 
            _subscribers[sender] = _pendingsubs[sender];
            _pendingsubs[sender] = 0;
        }
    }

    function _checkSubscription(bytes32 agreementId) internal returns (bool success){
        (,int96 outFlowRate, ,) = _cfa.getFlowByID(_acceptedToken, aggreementId);

        if (outFlowRate >= expectedInFlow) {
            return True;
        }
        else {
            sender = _getSender();
            _subscriptions[_subscribers[sender]] = address(0);
            _subscribers[sender] = 0;
        }

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
        returns (bytes memory newCtx)
    {
        // Update the dictionary after checking the outflow is the correct amount
        
        return _addSubscription(_agreementId);
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
        returns (bytes memory newCtx)
    {
        return _checkSubscription(_agreementId);
    }

    function afterAgreementTerminated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 ,//_agreementId,
        bytes calldata /*_agreementData*/,
        bytes calldata ,//_cbdata,
        bytes calldata _ctx
    )
        external override
        onlyHost
        returns (bytes memory newCtx)
    {
        // According to the app basic law, we should never revert in a termination callback
        if (!_isSameToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;
        
        _deleteSubscription(_agreementId);
        
        return _updateOutflow(_ctx);
    }

    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(_acceptedToken);
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType()
            == keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    }

    modifier onlyHost() {
        require(msg.sender == address(_host), "RedirectAll: support only one host");
        _;
    }

    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        require(_isSameToken(superToken), "RedirectAll: not accepted token");
        require(_isCFAv1(agreementClass), "RedirectAll: only CFAv1 supported");
        _;
    }

}
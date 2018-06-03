pragma solidity ^0.4.21;

/**
 * @title EOSclassic
 */

// Imports
import "./StandardToken.sol";
import "./HasNoEther.sol";

// Contract to help import the original EOS Crowdsale public key
contract EOSContractInterface
{
    mapping (address => string) public keys;
    function balanceOf( address who ) constant returns (uint value);
}

// EOSclassic smart contract 
contract EOSclassic is StandardToken, HasNoEther 
{
    // Welcome to EOSclassic
    string public constant name = "EOSclassic";
    string public constant symbol = "EOSC";
    uint8 public constant decimals = 18;

    // Total amount minted
    uint public constant TOTAL_SUPPLY = 1000000000 * (10 ** uint(decimals));
    
    // Amount given to founders
    uint public constant foundersAllocation = 100000000 * (10 ** uint(decimals));   

    // Contract address of the original EOS contracts
    address public constant eosTokenAddress = 0x86Fa049857E0209aa7D9e616F7eb3b3B78ECfdb0;
    address public constant eosCrowdsaleAddress = 0xd0a6E6C54DbC68Db5db3A091B171A77407Ff7ccf;
    
    // Map EOS keys; if not empty it should be favored over the original crowdsale address
    mapping (address => string) public keys;
    
    // Keep track of EOS->EOSclassic claims
    mapping (address => bool) public eosClassicClaimed;

    // LogClaim is called any time an EOS crowdsale user claims their EOSclassic equivalent
    event LogClaim (address user, uint amount);

    // LogRegister is called any time a user registers a new EOS public key
    event LogRegister (address user, string key);

    // ************************************************************
    // Constructor; mints all tokens, assigns founder's allocation
    // ************************************************************
    constructor() public 
    {
        // Define total supply
        totalSupply_ = TOTAL_SUPPLY;
        // Allocate total supply of tokens to smart contract for disbursement
        balances[address(this)] = TOTAL_SUPPLY;
        // Announce initial allocation
        emit Transfer(0x0, address(this), TOTAL_SUPPLY);
        
        // Transfer founder's allocation
        balances[address(this)] = balances[address(this)].sub(foundersAllocation);
        balances[msg.sender] = balances[msg.sender].add(foundersAllocation);
        // Announce founder's allocation
        emit Transfer(address(this), msg.sender, foundersAllocation);
    }

    // Function that checks the original EOS token for a balance
    function queryEOSTokenBalance(address _address) view public returns (uint) 
    {
        //return ERC20Basic(eosCrowdsaleAddress).balanceOf(_address);
        EOSContractInterface eosTokenContract = EOSContractInterface(eosTokenAddress);
        return eosTokenContract.balanceOf(_address);
    }

    // Function that returns any registered EOS address from the original EOS crowdsale
    function queryEOSCrowdsaleKey(address _address) view public returns (string) 
    {
        EOSContractInterface eosCrowdsaleContract = EOSContractInterface(eosCrowdsaleAddress);
        return eosCrowdsaleContract.keys(_address);
    }

    // Use to claim EOS Classic from the calling address
    function claimEOSclassic() external returns (bool) 
    {
        return claimEOSclassicFor(msg.sender);
    }

    // Use to claim EOSclassic for any Ethereum address 
    function claimEOSclassicFor(address _toAddress) public returns (bool)
    {
        // Ensure that an address has been passed
        require (_toAddress != address(0));
        // Ensure that the address isn't unrecoverable
        require (_toAddress != 0x00000000000000000000000000000000000000B1);
        // Ensure this address has not already been claimed
        require (isClaimed(_toAddress) == false);

        
        // Query the original EOS Crowdsale for address balance
        uint _eosContractBalance = queryEOSTokenBalance(_toAddress);
        
        // Ensure that address had some balance in the crowdsale
        require (_eosContractBalance > 0);
        
        // Sanity check: ensure we have enough tokens to send
        require (_eosContractBalance <= balances[address(this)]);

        // Mark address as claimed
        eosClassicClaimed[_toAddress] = true;
        
        // Convert equivalent amount of EOS to EOSclassic
        // Transfer EOS Classic tokens from this contract to claiming address
        balances[address(this)] = balances[address(this)].sub(_eosContractBalance);
        balances[_toAddress] = balances[_toAddress].add(_eosContractBalance);
        
        // Broadcast transfer 
        emit Transfer(address(this), _toAddress, _eosContractBalance);
        
        // Broadcast claim
        emit LogClaim(_toAddress, _eosContractBalance);
        
        // Success!
        return true;
    }

    // Check any address to see if its EOSclassic has already been claimed
    function isClaimed(address _address) public view returns (bool) 
    {
        return eosClassicClaimed[_address];
    }

    // Returns the latest EOS key registered.
    // EOS token holders that never registered their EOS public key 
    // can do so using the 'register' function in EOSclassic and then request restitution 
    // via the EOS mainnet arbitration process.
    // EOS holders that previously registered can update their keys here;
    // This contract could be used in future key snapshots for future EOS forks.
    function getMyEOSKey() external view returns (string)
    {
        return getEOSKeyFor(msg.sender);
    }

    // Return the registered EOS public key for the passed address
    function getEOSKeyFor(address _address) public view returns (string)
    {
        string memory _eosKey;

        // Get any key registered with EOSclassic
        _eosKey = keys[_address];

        if (bytes(_eosKey).length > 0) {
            // EOSclassic key was registered; return this over the original crowdsale address
            return _eosKey;
        } else {
            // EOSclassic doesn't have an EOS public key registered; return any original crowdsale key
            _eosKey = queryEOSCrowdsaleKey(_address);
            return _eosKey;
        }
    }

    // EOSclassic developer's note: the registration function is identical
    // to the original EOS crowdsale registration function with only the
    // freeze function removed, and 'emit' added to the LogRegister event,
    // per updated Solidity standards.
    //
    // Value should be a public key.  Read full key import policy.
    // Manually registering requires a base58
    // encoded using the STEEM, BTS, or EOS public key format.
    function register(string key) public {
        assert(bytes(key).length <= 64);

        keys[msg.sender] = key;

        emit LogRegister(msg.sender, key);
    }

}
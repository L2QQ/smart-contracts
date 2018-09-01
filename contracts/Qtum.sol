pragma solidity ^0.4.24;

import './QRC20Token.sol';
import './SafeMath.sol';
import "./crypto/Secp256k1.sol";


contract Qtum is SafeMath {

  enum State { CanWithdraw, CantWithdraw }

  struct Account {
    // Amount of either ether (in weis) or token on the channel
    uint256 amount;
    // Index of the last pushed transaction
    uint256 nonce;
    // State of the account
    State state;
  }

  struct Channel {
    // Expiration date (timestamp)
    uint256 expiration;
    // Accounts related with the channel where key of a map is token address
    // Zero key [address(0)] is used to store ether amount instead of token amount
    mapping(address => Account) accounts;
  }


  // Minimal TTL that can be used to extend existing channel
  uint256 constant TTL_MIN = 5 minutes; // TODO: Short time only for tests
  // Initial TTL for new channels created just after the first deposit
  uint256 constant TTL_DEFAULT = 10 minutes; // TODO: Short time only for tests

  // Address of account which has all permissions to manage channels
  address public owner;
  // Reserved address that can be used only to change owner for emergency
  address public oracle;

  // Existing channels where key of map is address of account which owns a channel
  mapping(address => Channel) channels;


  event Deposit(address indexed channelOwner, address indexed token, uint256 amount);
  event Withdraw(address indexed channelOwner, address indexed token, uint256 amount);
  event ChannelUpdate(address indexed channelOwner, uint256 expiration, uint256 nonce, address indexed token, uint256 amount);
  event ChannelExtend(address indexed channelOwner, uint256 expiration);


  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Throws if called by any account other than the oracle.
   */
  modifier onlyOracle() {
    require(msg.sender == oracle);
    _;
  }

  /**
   * @dev Throws if channel cannot be withdrawn.
   */
  modifier canWithdraw(address token) {
    require(channels[msg.sender].accounts[token].amount > 0);
    require(channels[msg.sender].accounts[token].state == State.CanWithdraw || now >= channels[msg.sender].expiration);
    _;
  }


  /**
   * @dev Constructor sets initial owner and oracle addresses.
   */
  constructor(address _oracle) public {
    owner = msg.sender;
    oracle = _oracle;
  }

  /**
   * @dev Deposits ether to a channel by user.
   */
  function () public payable {
    deposit();
  }

  /**
   * @dev Changes owner address by oracle.
   */
  function changeOwner(address newOwner) public onlyOracle {
    require(newOwner != address(0));
    owner = newOwner;
  }

  /**
   * @dev Deposits ether to a channel by user.
   */
  function deposit() public payable {
    require(msg.value > 0);
    channels[msg.sender].expiration = safeAdd(now, TTL_DEFAULT);
    channels[msg.sender].accounts[address(0)].amount = safeAdd(channels[msg.sender].accounts[address(0)].amount, msg.value);
    channels[msg.sender].accounts[address(0)].state = State.CantWithdraw;
    emit Deposit(msg.sender, address(0), msg.value);
    emit ChannelUpdate(msg.sender, channels[msg.sender].expiration, channels[msg.sender].accounts[address(0)].nonce,
      address(0), channels[msg.sender].accounts[address(0)].amount);
  }

  /**
   * @dev Deposits tokens to a channel by user.
   */
  function deposit(address token, uint256 amount) public {
    require(amount > 0);
    // Transfer tokens from the sender to the contract and check result
    // Note: At least specified amount of tokens should be allowed to spend by the contract before deposit!
    require(QRC20Token(token).transferFrom(msg.sender, this, amount));
    channels[msg.sender].expiration = safeAdd(now, TTL_DEFAULT);
    channels[msg.sender].accounts[token].amount = safeAdd(channels[msg.sender].accounts[token].amount, amount);
    channels[msg.sender].accounts[token].state = State.CantWithdraw;
    emit Deposit(msg.sender, token, amount);
    emit ChannelUpdate(msg.sender, channels[msg.sender].expiration, channels[msg.sender].accounts[token].nonce,
      token, channels[msg.sender].accounts[token].amount);
  }

  /**
   * @dev Performs withdraw ether to user.
   */
  function withdraw() public canWithdraw(address(0)) {
    uint256 amount = channels[msg.sender].accounts[address(0)].amount;
    channels[msg.sender].accounts[address(0)].amount = 0;
    msg.sender.transfer(amount);
    emit Withdraw(msg.sender, address(0), amount);
  }

  /**
   * @dev Performs withdraw token to user.
   */
  function withdraw(address token) public canWithdraw(token) {
    uint256 amount = channels[msg.sender].accounts[token].amount;
    channels[msg.sender].accounts[token].amount = 0;
    require(QRC20Token(token).transfer(msg.sender, amount));
    emit Withdraw(msg.sender, token, amount);
  }

  /**
   * @dev Updates channel with most recent amount by user or by contract owner (for ether only).
   */
  function updateChannel(address channelOwner, uint256 amount, uint256 nonce, uint256[2] signature, uint256[2] signerPublicKey) public {
    updateChannel(channelOwner, address(0), amount, nonce, signature, signerPublicKey);
  }

  /**
   * @dev Updates channel with most recent amount by user or by contract owner.
   */
  function updateChannel(address channelOwner, address token, uint256 amount, uint256 nonce, uint256[2] signature, uint256[2] signerPublicKey) public {
    // TODO: Is it possible to validate message signed by Qtum private key without requesting public key?
    require(channels[channelOwner].expiration > 0 && nonce > channels[channelOwner].accounts[token].nonce);
    // Make sure signature is created using private key paired with specified public key and is valid
    bytes32 messageHash = sha256(abi.encodePacked(channelOwner, token, nonce, amount));
    require(Secp256k1.validateSignature(messageHash, signature, signerPublicKey));
    // Calculate Ethereum address from public like Qtum does
    bytes32 signerPublicKeyHash = sha256(abi.encodePacked(signerPublicKey[0]));
    address signerAddress = address(ripemd160(abi.encodePacked(signerPublicKeyHash)));
    if (signerAddress == channelOwner) {
      // Transaction from user who owns the channel
      require(now >= channels[channelOwner].expiration || msg.sender == owner);
    } else if (signerAddress == owner) {
      // Transaction from the contract owner
      require(now >= channels[channelOwner].expiration || msg.sender == channelOwner);
      channels[channelOwner].accounts[token].state = State.CantWithdraw; // TODO: Make sure it is safe
    } else {
      // Specified arguments are not valid
      revert();
    }
    channels[channelOwner].accounts[token].amount = amount;
    channels[channelOwner].accounts[token].nonce = nonce;
    emit ChannelUpdate(channelOwner, channels[channelOwner].expiration, channels[channelOwner].accounts[token].nonce,
      token, channels[channelOwner].accounts[token].amount);
  }

  /**
   * @dev Extends expiration of the channel by user.
   */
  function extendChannel(uint256 ttl) public {
    require(ttl >= TTL_MIN);
    require(channels[msg.sender].expiration > 0);
    uint256 expiration = safeAdd(now, ttl);
    require(channels[msg.sender].expiration < expiration);
    channels[msg.sender].expiration = expiration;
    emit ChannelExtend(msg.sender, channels[msg.sender].expiration);
  }
}
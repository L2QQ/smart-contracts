pragma solidity ^0.4.24;

import './common/ERC20.sol';
import './common/SafeMath.sol';


/// @title Base implementation L2
contract L2 {
    using SafeMath for uint256;

    struct Account {
        // Amount of either ETH/QTUM or token on the channel
        uint256 balance;
        // Index of the last pushed transaction
        uint256 nonce;
        // Ability to deposit/withdraw by user
        bool unlocked;
    }

    struct Channel {
        // Channel expiration date (timestamp)
        uint256 expiration;
        // Accounts related with the channel where key of a map is token address
        // Zero key [address(0)] is used for ETH/QTUM instead of token
        mapping(address => Account) accounts;
    }


    // Minimal TTL that can be used to extend existing channel
    uint256 constant TTL_MIN = 2 days;
    // Initial TTL for new channels created just after the first deposit
    uint256 constant TTL_DEFAULT = 14 days;

    // Address of account which has all permissions to manage channels
    address public owner;
    // Reserved address that can be used only to change owner for emergency
    address public oracle;

    // Existing channels where key of map is address of account which owns a channel
    mapping(address => Channel) channels;

    // Amount of ETH/QTUM or token owned by the contract
    // Zero key [address(0)] is used for ETH/QTUM instead of token
    mapping(address => uint256) balances;


    event DepositInternal(address indexed token, uint256 amount, uint256 balance);
    event WithdrawInternal(address indexed token, uint256 amount, uint256 balance);
    event Deposit(address indexed channelOwner, address indexed token, uint256 amount);
    event Withdraw(address indexed channelOwner, address indexed token, uint256 amount);
    event ChannelUpdate(address indexed channelOwner, uint256 expiration, address indexed token, uint256 balance, uint256 nonce, bool unlocked);
    event ChannelExtend(address indexed channelOwner, uint256 expiration);


    /// @dev Throws if called by any account other than the owner.
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /// @dev Throws if called by any account other than the oracle.
    modifier onlyOracle() {
        require(msg.sender == oracle);
        _;
    }

    /// @dev Throws if channel is locked (channel owner cannot deposit and withdraw).
    modifier channelUnlocked(address token) {
        require(channels[msg.sender].accounts[token].unlocked || now >= channels[msg.sender].expiration);
        _;
    }


    /// @dev Constructor sets initial owner and oracle addresses.
    constructor(address _oracle) public {
        owner = msg.sender;
        oracle = _oracle;
    }

    /// @dev Deposits ETH/QTUM to a channel by user.
    function () public channelUnlocked(address(0)) payable {
        deposit();
    }

    /// @dev Changes owner address by oracle.
    function changeOwner(address newOwner) public onlyOracle {
        require(newOwner != address(0));
        owner = newOwner;
    }

    /// @dev Deposits ETH/QTUM to the contract balance.
    function depositInternal() public payable {
        require(msg.value > 0);
        balances[address(0)] = balances[address(0)].add(msg.value);
        emit DepositInternal(address(0), msg.value, balances[address(0)]);
    }

    /// @dev Deposits tokens to the contract balance.
    function depositInternal(address token, uint256 amount) public {
        require(amount > 0);
        // Transfer tokens from the sender to the contract and check result
        // Note: At least specified amount of tokens should be allowed to spend by the contract before deposit!
        require(ERC20(token).transferFrom(msg.sender, this, amount));
        balances[token] = balances[token].add(amount);
        emit DepositInternal(token, amount, balances[token]);
    }

    /// @dev Withdraws specified amount of ETH/QTUM to the contract owner.
    function withdrawInternal(uint256 amount) public onlyOwner {
        if (amount == 0 || amount > balances[address(0)]) {
            amount = balances[address(0)];
        }
        balances[address(0)] = balances[address(0)].sub(amount);
        owner.transfer(amount);
        emit WithdrawInternal(address(0), amount, balances[address(0)]);
    }

    /// @dev Withdraws specified amount of token to the contract owner.
    function withdrawInternal(address token, uint256 amount) public onlyOwner {
        if (amount == 0 || amount > balances[token]) {
            amount = balances[token];
        }
        balances[token] = balances[token].sub(amount);
        require(ERC20(token).transfer(owner, amount));
        emit WithdrawInternal(token, amount, balances[token]);
    }

    /// @dev Deposits ETH/QTUM to a channel by user.
    function deposit() public channelUnlocked(address(0)) payable {
        require(msg.value > 0);
        Channel storage channel = channels[msg.sender];
        Account storage account = channel.accounts[address(0)];
        uint256 expiration = now.add(TTL_DEFAULT);
        if (channel.expiration < expiration) {
            channel.expiration = expiration;
        }
        account.balance = account.balance.add(msg.value);
        account.unlocked = false;
        emit Deposit(msg.sender, address(0), msg.value);
        emit ChannelUpdate(msg.sender, channel.expiration, address(0), account.balance, account.nonce, account.unlocked);
    }

    /// @dev Deposits tokens to a channel by user.
    function deposit(address token, uint256 amount) public channelUnlocked(token) {
        require(amount > 0);
        // Transfer tokens from the sender to the contract and check result
        // Note: At least specified amount of tokens should be allowed to spend by the contract before deposit!
        require(ERC20(token).transferFrom(msg.sender, this, amount));
        Channel storage channel = channels[msg.sender];
        Account storage account = channel.accounts[token];
        uint256 expiration = now.add(TTL_DEFAULT);
        if (channel.expiration < expiration) {
            channel.expiration = expiration;
        }
        account.balance = account.balance.add(amount);
        account.unlocked = false;
        emit Deposit(msg.sender, token, amount);
        emit ChannelUpdate(msg.sender, channel.expiration, token, account.balance, account.nonce, account.unlocked);
    }

    /// @dev Withdraws specified amount of ETH/QTUM to user.
    function withdraw(uint256 amount) public channelUnlocked(address(0)) {
        Channel storage channel = channels[msg.sender];
        Account storage account = channel.accounts[address(0)];
        if (amount == 0 || amount > account.balance) {
            amount = account.balance;
        }
        account.balance = account.balance.sub(amount);
        account.unlocked = false;
        msg.sender.transfer(amount);
        emit Withdraw(msg.sender, address(0), amount);
        emit ChannelUpdate(msg.sender, channel.expiration, address(0), account.balance, account.nonce, account.unlocked);
    }

    /// @dev Withdraws specified amount of token to user.
    function withdraw(address token, uint256 amount) public channelUnlocked(token) {
        Channel storage channel = channels[msg.sender];
        Account storage account = channel.accounts[token];
        if (amount == 0 || amount > account.balance) {
            amount = account.balance;
        }
        account.balance = account.balance.sub(amount);
        account.unlocked = false;
        emit Withdraw(msg.sender, token, amount);
        emit ChannelUpdate(msg.sender, channel.expiration, token, account.balance, account.nonce, account.unlocked);
    }

    //// @dev Updates channel with the most recent balance by user or by contract owner.
    function updateChannel(
        address channelOwner,
        address token,
        uint256 balance,
        uint256 nonce,
        bool unlock,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
    {
        Channel storage channel = channels[msg.sender];
        Account storage account = channel.accounts[token];
        require(channel.expiration > 0 && nonce > account.nonce);
        // Make sure signature is valid and recover signer address
        bytes32 messageHash = sha256(abi.encodePacked(channelOwner, token, balance, nonce, unlock));
        address signerAddress = recoverSignerAddress(messageHash, v, r, s);
        if (signerAddress == channelOwner) {
            // Transaction from user who owns the channel
            // Only contract owner can push offchain transactions signed by channel owner if the channel not expired
            require(now >= channel.expiration || msg.sender == owner);
        } else if (signerAddress == owner) {
            // Transaction from the contract owner
            // Only channel owner can push offchain transactions signed by contract owner if the channel not expired
            require(now >= channel.expiration || msg.sender == channelOwner);
            account.unlocked = unlock;
        } else {
            // Specified arguments are not valid
            revert();
        }
        if (account.unlocked) {
            if (balance < account.balance) {
                balances[token] = balances[token].add(account.balance.sub(balance));
            } else if (balance > account.balance) {
                balances[token] = balances[token].sub(balance.sub(account.balance));
            }
        }
        account.balance = balance;
        account.nonce = nonce;
        emit ChannelUpdate(msg.sender, channel.expiration, token, account.balance, account.nonce, account.unlocked);
    }

    /// @dev Extends expiration of the channel by user.
    function extendChannel(uint256 ttl) public {
        require(ttl >= TTL_MIN);
        Channel storage channel = channels[msg.sender];
        uint256 expiration = now.add(ttl);
        require(channel.expiration > 0 && channel.expiration < expiration);
        channel.expiration = expiration;
        emit ChannelExtend(msg.sender, channel.expiration);
    }
    

    function getExpiration(address channelOwner) public view returns (uint256) {
        return channels[channelOwner].expiration;
    }

    function getBalance(address channelOwner, address token) public view returns (uint256) {
        return channels[channelOwner].accounts[token].balance;
    }

    function getNonce(address channelOwner, address token) public view returns (uint256) {
        return channels[channelOwner].accounts[token].nonce;
    }

    function isUnlocked(address channelOwner, address token) public view returns (bool) {
        return channels[channelOwner].accounts[token].unlocked;
    }


    /// @dev Virtual function which should return signer address which can be compared to `msg.sender`
    function recoverSignerAddress(bytes32 dataHash, uint8 v, bytes32 r, bytes32 s) internal returns (address);
}
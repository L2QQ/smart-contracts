pragma solidity ^0.4.25;

import './common/ERC20.sol';
import './common/SafeMath.sol';


/// @title Base L2 smart contract implementation.
contract L2 {
    using SafeMath for uint256;

    struct Account {
        // Amount of either ETH/QTUM or tokens available to trade by user
        uint256 balance;
        // Amount of either ETH/QTUM or tokens pending to move to/from (depends on sign of the value) the balance
        int256 change;
        // Amount of either ETH/QTUM or tokens available to withdraw by user
        uint256 withdrawable;
        // Index of the last pushed transaction
        uint256 nonce;
    }

    struct Channel {
        // Channel expiration date (timestamp)
        uint256 expiration;
        // Accounts related to the channel where key of a map is token address
        // Zero key [address(0)] is used for ETH/QTUM instead of tokens
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

    // Amount of ETH/QTUM or tokens owned by the contract
    // Zero key [address(0)] is used for ETH/QTUM instead of tokens
    mapping(address => uint256) balances;


    event DepositInternal(address indexed token, uint256 amount, uint256 balance);
    event WithdrawInternal(address indexed token, uint256 amount, uint256 balance);
    event Deposit(address indexed channelOwner, address indexed token, uint256 amount, uint256 balance);
    event Withdraw(address indexed channelOwner, address indexed token, uint256 amount, uint256 balance);
    event ChannelExtend(address indexed channelOwner, uint256 expiration);
    event ChannelUpdate(
        address indexed channelOwner,
        address indexed token,
        uint256 balance,
        int256 change,
        uint256 withdrawable,
        uint256 nonce
    );
    

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

    /// @dev Throws if channel cannot be withdrawn.
    modifier canWithdraw(address token) {
        Account memory account = channels[msg.sender].accounts[token];
        // There should be something that can be withdrawn on the channel
        require(getAvailableBalance(account) > 0);
        // The channel should be either prepared for withdraw by owner or expired
        require(account.withdrawable > 0 || isChannelExpired(channels[msg.sender]));
        _;
    }


    /// @dev Constructor sets initial owner and oracle addresses.
    constructor(address _oracle) public {
        require(_oracle != address(0));
        owner = msg.sender;
        oracle = _oracle;
    }

    /// @dev Deposits ETH/QTUM to a channel by user.
    function() public payable {
        deposit();
    }

    /// @dev Changes owner address by oracle.
    function changeOwner(address _owner) public onlyOracle {
        require(_owner != address(0));
        owner = _owner;
    }

    /// @dev Deposits ETH/QTUM to the contract balance.
    function depositInternal() public payable {
        require(msg.value > 0);
        balances[address(0)] = balances[address(0)].add(msg.value);
        emit DepositInternal(address(0), msg.value, balances[address(0)]);
    }

    /// @dev Deposits tokens to the contract balance.
    function depositInternal(address token, uint256 amount) public {
        require(token != address(0) && amount > 0);
        // Transfer tokens from the sender to the contract and check result
        // Note: At least specified amount of tokens should be allowed to spend by the contract before deposit!
        require(ERC20(token).transferFrom(msg.sender, this, amount));
        balances[token] = balances[token].add(amount);
        emit DepositInternal(token, amount, balances[token]);
    }

    /// @dev Withdraws specified amount of ETH/QTUM to the contract owner.
    function withdrawInternal(uint256 amount) public onlyOwner {
        require(amount > 0 && amount <= balances[address(0)]);
        owner.transfer(amount);
        balances[address(0)] = balances[address(0)].sub(amount);
        emit WithdrawInternal(address(0), amount, balances[address(0)]);
    }

    /// @dev Withdraws specified amount of tokens to the contract owner.
    function withdrawInternal(address token, uint256 amount) public onlyOwner {
        require(token != address(0) && amount > 0 && amount <= balances[token]);
        require(ERC20(token).transfer(owner, amount));
        balances[token] = balances[token].sub(amount);
        emit WithdrawInternal(token, amount, balances[token]);
    }

    /// @dev Deposits ETH/QTUM to a channel by user.
    function deposit() public payable {
        require(msg.value > 0);
        Channel storage channel = channels[msg.sender];
        Account storage account = channel.accounts[address(0)];
        if (channel.expiration == 0) {
            channel.expiration = now.add(TTL_DEFAULT);
            emit ChannelExtend(msg.sender, channel.expiration);
        }
        account.balance = account.balance.add(msg.value);
        emit Deposit(msg.sender, address(0), msg.value, account.balance);
        emit ChannelUpdate(msg.sender, address(0), account.balance, account.change, account.withdrawable, account.nonce);
    }

    /// @dev Deposits tokens to a channel by user.
    function deposit(address token, uint256 amount) public {
        require(token != address(0) && amount > 0);
        // Transfer tokens from the sender to the contract and check result
        // Note: At least specified amount of tokens should be allowed to spend by the contract before deposit!
        require(ERC20(token).transferFrom(msg.sender, this, amount));
        Channel storage channel = channels[msg.sender];
        Account storage account = channel.accounts[token];
        if (channel.expiration == 0) {
            channel.expiration = now.add(TTL_DEFAULT);
            emit ChannelExtend(msg.sender, channel.expiration);
        }
        account.balance = account.balance.add(amount);
        emit Deposit(msg.sender, token, amount, account.balance);
        emit ChannelUpdate(msg.sender, token, account.balance, account.change, account.withdrawable, account.nonce);
    }

    /// @dev Withdraws specified amount of ETH/QTUM to user.
    function withdraw(uint256 amount) public canWithdraw(address(0)) {
        Channel storage channel = channels[msg.sender];
        Account storage account = channel.accounts[address(0)];
        // Check if channel is expired and there is something we should change in channel
        if (isChannelExpired(channel)) {
            // Before widthdraw it is necessary to apply current balance change
            updateBalance(account, address(0));
            // Before widthdraw it is also necessary to update withdrawable amount
            updateWithdrawable(account, account.balance);
        }
        require(amount > 0 && amount <= account.withdrawable);
        msg.sender.transfer(amount);
        account.withdrawable = account.withdrawable.sub(amount);
        emit Withdraw(msg.sender, address(0), amount, account.balance);
        emit ChannelUpdate(msg.sender, address(0), account.balance, account.change, account.withdrawable, account.nonce);
    }

    /// @dev Withdraws specified amount of tokens to user.
    function withdraw(address token, uint256 amount) public canWithdraw(token) {
        require(token != address(0));
        Channel storage channel = channels[msg.sender];
        Account storage account = channel.accounts[token];
        // Check if channel is expired and there is something we should change in channel
        if (isChannelExpired(channel)) {
            // Before widthdraw it is necessary to apply current balance change
            updateBalance(account, token);
            // Before widthdraw it is also necessary to update withdrawable amount
            updateWithdrawable(account, account.balance);
        }
        require(amount > 0 && amount <= account.withdrawable);
        require(ERC20(token).transfer(msg.sender, amount));
        account.withdrawable = account.withdrawable.sub(amount);
        emit Withdraw(msg.sender, token, amount, account.balance);
        emit ChannelUpdate(msg.sender, token, account.balance, account.change, account.withdrawable, account.nonce);
    }

    //// @dev Pushes offchain transaction with most recent balance change by user or by contract owner.
    function updateBalanceChange(
        address channelOwner,
        address token,
        int256 change,
        uint256 nonce,
        bool apply,
        uint256 free,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
    {
        Channel storage channel = channels[channelOwner];
        Account storage account = channel.accounts[token];
        require(channel.expiration > 0 && nonce > account.nonce);
        require(change >= 0 || account.balance >= uint256(-change));
        // Make sure signature is valid and recover signer address
        bytes32 messageHash = keccak256(abi.encodePacked(channelOwner, token, change, nonce, apply, free));
        address signer = recoverSignerAddress(messageHash, v, r, s);
        if (signer == channelOwner) {
            // Transaction from user who owns the channel
            // Only contract owner can push offchain transactions signed by channel owner if the channel not expired
            require(isChannelExpired(channel) || msg.sender == owner);
        } else if (signer == owner) {
            // Transaction from the contract owner
            // Only channel owner can push offchain transactions signed by contract owner if the channel not expired
            require(isChannelExpired(channel) || msg.sender == channelOwner);
        } else {
            // Specified arguments are not valid
            revert();
        }
        account.change = change;
        if (signer == owner) {
            if (apply) {
                // Applying balance change to a account balance is requested so just do it
                updateBalance(account, token);
            }
            if (free > 0) {
                updateWithdrawable(account, free);
            }
        }
        account.nonce = nonce;
        emit ChannelUpdate(channelOwner, token, account.balance, account.change, account.withdrawable, account.nonce);
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

    // READ FUNCTIONS

    function getBalanceInternal(address token) public view returns (uint256) {
        return balances[token];
    }

    function getExpiration(address channelOwner) public view returns (uint256) {
        return channels[channelOwner].expiration;
    }

    function getBalance(address channelOwner, address token) public view returns (uint256) {
        return channels[channelOwner].accounts[token].balance;
    }

    function getBalanceChange(address channelOwner, address token) public view returns (int256) {
        return channels[channelOwner].accounts[token].change;
    }

    function getWithdrawable(address channelOwner, address token) public view returns (uint256) {
        return channels[channelOwner].accounts[token].withdrawable;
    }

    function getNonce(address channelOwner, address token) public view returns (uint256) {
        return channels[channelOwner].accounts[token].nonce;
    }

    function getAvailable(address channelOwner, address token) public view returns (uint256) {
        return getAppliedBalance(channels[channelOwner].accounts[token]);
    }

    // INTERNAL FUNCTIONS

    /// @dev Virtual function which should return signer address which can be compared to `msg.sender`.
    function recoverSignerAddress(bytes32 dataHash, uint8 v, bytes32 r, bytes32 s) internal returns (address);

    // PRIVATE FUNCTIONS

    /// @dev Updates account balance according to balance change value.
    function updateBalance(Account storage account, address token) private {
        if (account.change > 0) {
            balances[token] = balances[token].sub(uint256(account.change));
            account.balance = account.balance.add(uint256(account.change));
            account.change = 0;
        } else if (account.change < 0) {
            account.balance = account.balance.sub(uint256(-account.change));
            balances[token] = balances[token].add(uint256(-account.change));
            account.change = 0;
        }
    }

    /// @dev Updates amount of ETH/QTUM or tokens allowed to withdraw by user.
    function updateWithdrawable(Account storage account, uint256 free) private {
        if (free > 0) {
            account.balance = account.balance.sub(free);
            account.withdrawable = account.withdrawable.add(free);
        }
    }

    function isChannelExpired(Channel memory channel) private view returns (bool) {
        return now >= channel.expiration;
    }

    function getAppliedBalance(Account memory account) private pure returns (uint256) {
        if (account.change > 0) {
            return account.balance.add(uint256(account.change));
        } else if (account.change < 0) {
            return account.balance.sub(uint256(-account.change));
        } else {
            return account.balance;
        }
    }

    function getAvailableBalance(Account memory account) private pure returns (uint256) {
        return getAppliedBalance(account).add(account.withdrawable);
    }
}
/**
 *Submitted for verification at BscScan.com on 2023-11-04
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ERC20Interface {
    function totalSupply() external view returns (uint);

    function balanceOf(address tokenOwner) external view returns (uint balance);

    function transfer(address to, uint tokens) external returns (bool success);

    function approve(
        address spender,
        uint tokens
    ) external returns (bool success);

    function transferFrom(
        address from,
        address to,
        uint tokens
    ) external returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(
        address indexed tokenOwner,
        address indexed spender,
        uint tokens
    );
}

contract StrategicRound {
    ERC20Interface public mmtToken;
    ERC20Interface public usdtToken;

    address public fundAddress;
    address public owner;

    uint256 public tokenPrice = 4e15;
    uint256 public SaleBalance = 50e24;
    uint256 public MINIMUM_PURCHASE = 10e18;
    uint256 public MAXIMUM_PURCHASE = 2e22;
    uint256 public VESTING_DURATION = 5 minutes;
    uint256 public VESTING_PERIODS = 12;
    uint256 public INITIAL_RELEASE_RATE = 4; // in percentage

    struct Vest {
        uint256 reservedMMT;
        uint256 sentUSDT;
        uint256 vestedAmount;
        uint256 startTime;
        uint256 initialRelease;
        uint256 monthlyReward;
        uint256 lastClaimedDate;
        uint256 claimedToken;
    }

    mapping(address => Vest) public userVesting;

    event BuyToken(address indexed user, uint256 usdtToken, uint256 mmtToken);
    event VestingToken(address indexed user, uint256 amount);
    event ClaimTokens(address indexed user, uint256 mmtAmount);
    event FundAddressUpdated(address newFundAddress);
    address[] public vestedAddress;
    bool public isActive = true;

    constructor(
        ERC20Interface _token,
        ERC20Interface _usdt,
        address _fundAddress
    ) {
        mmtToken = _token;
        usdtToken = _usdt;
        fundAddress = _fundAddress;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not Authorized");
        _;
    }

    function buyToken(uint256 usdtAmount) external {
        require(isActive, "Sale is not available");
        require(usdtAmount >= MINIMUM_PURCHASE, "Require more than 10 USDT");
        require(usdtAmount <= MAXIMUM_PURCHASE, "Require less than 20,000 USDT");
        require(fundAddress != address(0), "FundAddress is not set");

        Vest storage vest = userVesting[msg.sender];
        uint256 reservedAmount = (usdtAmount * 1e18) / tokenPrice;

        require(
            SaleBalance >= reservedAmount,
            "Not enough tokens in sale balance"
        );

        vest.reservedMMT += reservedAmount;
        vest.sentUSDT += usdtAmount;
        SaleBalance -= reservedAmount;

        require(
            usdtToken.transferFrom(msg.sender, fundAddress, usdtAmount),
            "Transfer USDT Failed"
        );

        emit BuyToken(msg.sender, usdtAmount, reservedAmount);
    }

    function setFundAddress(address _address) external onlyOwner {
        fundAddress = _address;
        emit FundAddressUpdated(_address);
    }

    function vestMMTToken(
        address[] memory _address,
        uint256[] memory _amount,
        uint256 startTime
    ) external onlyOwner {
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _address.length; i++) {
            initVest(_address[i], _amount[i], startTime);
            totalAmount += _amount[i];
        }

        require(
            mmtToken.transferFrom(msg.sender, address(this), totalAmount),
            "Vesting Failed"
        );
    }

    function claimTokens() external {
        Vest storage vest = userVesting[msg.sender];
        require(vest.vestedAmount > 0, "No vested Tokens are available");
        require(
            block.timestamp >= vest.lastClaimedDate + VESTING_DURATION,
            "Vesting Period Amount"
        );

        uint256 claimAmount = calculateClaimableToken(msg.sender);
        vest.vestedAmount -= claimAmount;
        vest.claimedToken += claimAmount;
        vest.lastClaimedDate = block.timestamp;

        require(mmtToken.transfer(msg.sender, claimAmount), "Transfer failed");
        emit ClaimTokens(msg.sender, claimAmount);
    }

    function initVest(
        address _address,
        uint256 _amount,
        uint256 startTime
    ) internal {
        Vest storage vest = userVesting[_address];
        require(vest.vestedAmount == 0, "Already Vested");

        vest.vestedAmount = _amount;
        vest.reservedMMT -= _amount;
        vest.startTime = startTime;
        vest.initialRelease = (_amount * INITIAL_RELEASE_RATE) / 100;
        vest.monthlyReward = (_amount - vest.initialRelease) / VESTING_PERIODS;
        vest.claimedToken = 0;
        vest.lastClaimedDate = startTime;

        vestedAddress.push(_address);

        emit VestingToken(_address, _amount);
    }

    function calculateClaimableToken(
        address _address
    ) internal view returns (uint256) {
        Vest storage vest = userVesting[_address];
        uint256 elapsedTime = block.timestamp - vest.lastClaimedDate;
        uint256 periodsPassed = elapsedTime / VESTING_DURATION;
        uint256 claimableToken = 0;

        if (vest.claimedToken == 0) {
            claimableToken = vest.initialRelease + periodsPassed * vest.monthlyReward;
            if(claimableToken >= vest.vestedAmount) {
                claimableToken = vest.vestedAmount;
            }
        } else {
            claimableToken = periodsPassed * vest.monthlyReward;
            if(claimableToken >= vest.vestedAmount - vest.claimedToken) {
                claimableToken = vest.vestedAmount - vest.claimedToken;
            }
        }
        return claimableToken;
    }

    function updateUserAddress(
        address sourceAddress,
        address targetAddress
    ) external onlyOwner {
        userVesting[targetAddress] = userVesting[sourceAddress];
        delete userVesting[sourceAddress];
    }

    function setSaleStatus (bool status) external onlyOwner{
        isActive = status;
    }
}
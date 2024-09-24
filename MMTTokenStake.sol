// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ERC20Interface {
  function totalSupply() external view returns (uint);
  function balanceOf(address tokenOwner) external view returns (uint balance);
  function allowance(address tokenOwner, address spender) external view returns (uint remaining);
  function transfer(address to, uint tokens) external returns (bool success);
  function approve(address spender, uint tokens) external returns (bool success);
  function transferFrom(address from, address to, uint tokens) external returns (bool success);

  event Transfer(address indexed from, address indexed to, uint tokens);
  event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract MMTTokenStake {
  ERC20Interface public token;
  uint256 public _totalStaked = 0;
  address owner;

  struct Stake {
    address _address;
    uint256 amount;
    uint256 startTime;
    uint256 endTime;
    uint256 lastRewardDate;
    uint256 totalReward;
    uint256 withdrawnAmount;
  }

  mapping(address => Stake) public stakes;

  uint256[] public aprs;

  uint256 public MIN_STAKE_AMOUNT = 100000 * (10 ** 18);
  uint256[] public stakingPeriod;
  uint256 unit = 1 minutes;

  Stake[] public stakeUsers;

  event Deposit(address address_, uint256 amount_);
  event Withdraw(address address_, uint256 amount_);
  event GetAddressAmount(address address_, uint amount);
  event Harvest(uint256 reward);
  event Compound(address address_, uint256 stakingLength);

  constructor (ERC20Interface token_) {
    token = token_;
    owner = msg.sender;
    stakingPeriod = [3, 6, 9, 12];
    aprs = [3, 4, 5, 6];
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "Not Authorized");
    _;
  }

  function deposit(uint256 amount_, uint256 stakingLength) external {
    bool isExist = false;
    require(amount_ >= MIN_STAKE_AMOUNT, "Amount should be at least MIN_STAKE_AMOUNT");
    require(stakes[msg.sender].amount == 0, "Already Staked");
    for(uint256 i = 0; i < stakingPeriod.length; i++) {
      if(stakingLength == stakingPeriod[i]) {
        isExist = true;
      }
    }
    require(isExist == true, "Invalid staking length");
    uint256 endTime = block.timestamp + (stakingLength * unit);
    uint256 _totalReward = _calculateReward(amount_, stakingLength * unit, stakingLength);
    stakes[msg.sender] = Stake(msg.sender, amount_, block.timestamp, endTime, block.timestamp, _totalReward, 0);
    require(token.transferFrom(msg.sender, address(this), amount_), "Token Transfer Failed");
    stakeUsers.push(stakes[msg.sender]);
    _totalStaked += amount_;
    emit Deposit(msg.sender, amount_);
  }

  function harvest() external {
    Stake storage stake = stakes[msg.sender];
    require(stake.amount > 0, "No stake found");
    require(block.timestamp >= stake.endTime, "Staking period not ended");
    require(block.timestamp >= stake.lastRewardDate + 3 * unit, "You attempt to harvest within 3 minutes");
    uint256 reward = _calculateReward(stake.amount, block.timestamp - stake.lastRewardDate, (stake.endTime - stake.startTime) / unit);
    require(token.transfer(msg.sender, reward), "Token transfer failed");
    stake.lastRewardDate = block.timestamp;
    stake.withdrawnAmount = reward;
    emit Harvest(reward);
  }

  function compound(uint256 stakingLength) external {
    Stake storage stake = stakes[msg.sender];
    require(stake.amount > 0, "No stake found");
    require(block.timestamp >= stake.endTime, "Staking period not ended");
    uint256 reward = _calculateReward(stake.amount, block.timestamp - stake.lastRewardDate, (stake.endTime - stake.startTime) / unit);

    stake.amount += reward;
    stake.startTime = block.timestamp;
    stake.endTime = block.timestamp + stakingLength * unit;
    stake.lastRewardDate = block.timestamp;
    _totalStaked += reward;
    emit Compound(msg.sender, stakingLength);
  }

  function withdraw() external {
    Stake storage stake = stakes[msg.sender];
    require(stake.amount > 0, "No Stake found");
    require(block.timestamp >= stake.endTime, "Staking period not ended");

    uint256 reward = _calculateReward(stake.amount, block.timestamp - stake.lastRewardDate, (stake.endTime - stake.startTime) / unit);
    uint256 totalRewardAmount = stake.amount + reward;

    require(token.transfer(msg.sender, totalRewardAmount), "Token transfer failed");

    _totalStaked -= stake.amount;
    stake.amount = 0;
    stake.startTime = block.timestamp;
    stake.endTime = block.timestamp;
    emit Withdraw(msg.sender, stake.amount);
  }

  function _calculateReward(uint256 amount, uint256 duration, uint256 _stakingPeriod) public view returns (uint256) {
    uint256 apr;
    for(uint256 i = 0; i < stakingPeriod.length; i++) {
      if(stakingPeriod[i] == _stakingPeriod)
      apr = aprs[i];
    }

    uint256 months = duration / unit;
    return apr * months * amount / 12 / 100;
  }

  function setAPR(uint256[] memory amount, uint256[] memory months) external onlyOwner {
    aprs = amount;
    stakingPeriod = months;
  }

  function updateUserAddress(address _newAddr) external {
    stakes[_newAddr] = stakes[msg.sender];
    delete stakes[msg.sender];
  }

  function setMinstake(uint256 minStake) external onlyOwner {
    MIN_STAKE_AMOUNT = minStake;
  }

  function getStakers() external view onlyOwner returns(Stake[] memory) {
    return stakeUsers;
  }

  function getPendingReward(address _address) public view returns(uint256){
    return stakes[_address].totalReward - stakes[_address].withdrawnAmount;
  }

  function getTotalPendingReward() external view returns(uint256){
    uint256 _totalPending = 0;
    for(uint256 i = 0; i < stakeUsers.length; i++) {
      _totalPending = getPendingReward(stakeUsers[i]._address);
    }
    return _totalPending;
  }
}

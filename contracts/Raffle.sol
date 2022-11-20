// Raffle

// Enter the lottery (paying some amount)
// Pick a random winner (verifyable random)
// Winner is selected every X minutes -> completely automated.
// Chainlink Oracle  -> randomness + triggers

// SPDX-License-Identifier: MIT

import '@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol';
import '@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol';
import '@chainlink/contracts/src/v0.8/AutomationCompatible.sol';

pragma solidity ^0.8.17;
error Raffle__NotEnoughEthEntered();
error Raffle__TransferFailed();
error Raffle__NotOpen();
error Raffle__UnkeepNotNeeded(uint256 currentBalance, uint256 numberOfPlayers, uint256 raffleState);

/**
 * @title A sample raffle contract
 * @author Tu Nguyen
 */
contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
  /* Types */
  enum RaffleState {
    OPEN,
    CALCULATING
  }

  /* State variables */
  address payable[] private s_players;
  uint256 private immutable i_entranceFee;
  bytes32 private immutable i_gasLane;
  uint64 private immutable i_subscriptionId;
  uint32 private immutable i_callbackGasLimit;
  uint256 private immutable i_interval;
  uint16 private constant REQUEST_CONFIRMATION = 3;
  uint32 private constant NUM_WORDS = 1;

  VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

  /* Events */
  event RaffleEnter(address indexed player);
  event RequestedRaffleWinner(uint256 indexed requestId);
  event WinnerPicked(address indexed winner);

  // Lottery variable
  address private s_recentWinner;
  RaffleState private s_raffleState;
  uint256 private s_lastTimeStamp;

  constructor(
    address vrfCoordinatorV2,
    uint256 entranceFee,
    bytes32 gasLane,
    uint64 subscriptionId,
    uint32 callbackGasLimit,
    uint256 interval
  ) VRFConsumerBaseV2(vrfCoordinatorV2) {
    i_entranceFee = entranceFee;
    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
    i_gasLane = gasLane;
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit;
    i_interval = interval;
    s_raffleState = RaffleState.OPEN;
    s_lastTimeStamp = block.timestamp;
  }

  function enterRaffle() public payable {
    if (msg.value < i_entranceFee) {
      revert Raffle__NotEnoughEthEntered();
    }

    if (s_raffleState != RaffleState.OPEN) {
      revert Raffle__NotOpen();
    }
    s_players.push(payable(msg.sender));
    emit RaffleEnter(msg.sender);
  }

  function getPlayer(uint256 playerIndex) public view returns (address) {
    return s_players[playerIndex];
  }

  function checkUpkeep(
    bytes calldata /* checkData */
  )
    public
    override
    returns (
      bool upKeepNeeded,
      bytes memory /* performData */
    )
  {
    bool isOpen = s_raffleState == RaffleState.OPEN;
    bool isTimePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
    bool hasPlayer = s_players.length > 0;
    bool hasBalance = address(this).balance > 0;

    upKeepNeeded = isOpen && isTimePassed && hasBalance && hasPlayer;
  }

  function performUpkeep(bytes calldata performData) external override {
    // Request the random number
    (bool upkeepNeeded, ) = checkUpkeep(performData);

    if (!upkeepNeeded) {
      revert Raffle__UnkeepNotNeeded(
        address(this).balance,
        s_players.length,
        uint256(s_raffleState)
      );
    }
    uint256 requestId = i_vrfCoordinator.requestRandomWords(
      i_gasLane,
      i_subscriptionId,
      REQUEST_CONFIRMATION,
      i_callbackGasLimit,
      NUM_WORDS
    );

    emit RequestedRaffleWinner(requestId);
  }

  function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
    s_raffleState = RaffleState.CALCULATING;

    uint256 indexOfWinner = randomWords[0] % s_players.length;
    address payable winner = s_players[indexOfWinner];
    s_recentWinner = winner;

    s_raffleState = RaffleState.OPEN;
    s_players = new address payable[](0);
    s_lastTimeStamp = block.timestamp;

    (bool success, ) = winner.call{value: address(this).balance}('');

    if (!success) {
      revert Raffle__TransferFailed();
    }

    emit WinnerPicked(winner);
  }

  function getEntranceFee() public view returns (uint256) {
    return i_entranceFee;
  }

  function getRecentWinner() public view returns (address) {
    return s_recentWinner;
  }
}

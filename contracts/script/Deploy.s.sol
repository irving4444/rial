// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/RialAttestation.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address trustedSubmitter = vm.envAddress("TRUSTED_SUBMITTER");
        
        vm.startBroadcast(deployerPrivateKey);
        
        RialAttestation attestation = new RialAttestation(trustedSubmitter);
        
        console.log("RialAttestation deployed to:", address(attestation));
        console.log("Owner:", attestation.owner());
        console.log("Trusted Submitter:", attestation.trustedSubmitter());
        
        vm.stopBroadcast();
    }
}


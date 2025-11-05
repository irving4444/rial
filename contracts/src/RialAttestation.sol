// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title RialAttestation
 * @notice Polygon smart contract for batched image attestations with privacy
 * @dev Proves images are real (not AI) with optional reveal mechanism
 */
contract RialAttestation {
    
    // ============ Structs ============
    
    /**
     * @notice Core attestation data stored on-chain
     * @dev Privacy-preserving: only hashes stored, actual data off-chain
     */
    struct Attestation {
        bytes32 merkleRoot;        // Merkle tree root of image tiles
        bytes32 imageHash;         // SHA-256 of full image
        bytes32 metadataHash;      // Hash of camera/GPS/accelerometer data
        address devicePublicKey;   // Derived from iOS Secure Enclave key
        uint256 timestamp;         // Block timestamp when attested
        uint256 batchId;          // Batch this attestation belongs to
        bool revealed;            // Has owner revealed the image publicly?
    }
    
    /**
     * @notice Batch of attestations (gas optimization)
     */
    struct Batch {
        uint256 count;            // Number of attestations in batch
        uint256 timestamp;        // When batch was submitted
        bytes32 batchRoot;        // Merkle root of all attestations
        address submitter;        // Who submitted the batch
    }
    
    /**
     * @notice Anti-AI proof metadata (stored off-chain, hash on-chain)
     */
    struct ProofMetadata {
        string cameraModel;       // e.g., "iPhone 15 Pro"
        string sensorInfo;        // Camera sensor details
        int256 latitude;          // GPS coordinates (optional)
        int256 longitude;
        bytes32 appAttestToken;   // Apple App Attest token hash
        bytes32 accelerometerHash; // Hash of movement data
    }
    
    // ============ State Variables ============
    
    /// @notice Mapping from attestation ID to attestation data
    mapping(bytes32 => Attestation) public attestations;
    
    /// @notice Mapping from batch ID to batch data
    mapping(uint256 => Batch) public batches;
    
    /// @notice Mapping from attestation ID to owner address
    mapping(bytes32 => address) public attestationOwners;
    
    /// @notice Mapping for revealed image URIs (IPFS/Arweave)
    mapping(bytes32 => string) public revealedImageURIs;
    
    /// @notice Mapping for revealed metadata URIs
    mapping(bytes32 => string) public revealedMetadataURIs;
    
    /// @notice Counter for batch IDs
    uint256 public batchCounter;
    
    /// @notice Total attestations created
    uint256 public totalAttestations;
    
    /// @notice Contract owner (can update verification logic)
    address public owner;
    
    /// @notice Trusted backend address (can submit batches)
    address public trustedSubmitter;
    
    // ============ Events ============
    
    event AttestationCreated(
        bytes32 indexed attestationId,
        address indexed owner,
        uint256 indexed batchId,
        bytes32 merkleRoot,
        uint256 timestamp
    );
    
    event BatchSubmitted(
        uint256 indexed batchId,
        uint256 count,
        bytes32 batchRoot,
        address submitter
    );
    
    event ImageRevealed(
        bytes32 indexed attestationId,
        string imageURI,
        string metadataURI
    );
    
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyTrustedSubmitter() {
        require(msg.sender == trustedSubmitter, "Not trusted submitter");
        _;
    }
    
    modifier onlyAttestationOwner(bytes32 attestationId) {
        require(attestationOwners[attestationId] == msg.sender, "Not attestation owner");
        _;
    }
    
    // ============ Constructor ============
    
    constructor(address _trustedSubmitter) {
        owner = msg.sender;
        trustedSubmitter = _trustedSubmitter;
        batchCounter = 0;
        totalAttestations = 0;
    }
    
    // ============ Core Functions ============
    
    /**
     * @notice Submit a batch of attestations (gas-optimized)
     * @dev Only callable by trusted backend
     * @param attestationIds Array of unique attestation IDs
     * @param merkleRoots Array of image Merkle roots
     * @param imageHashes Array of full image hashes
     * @param metadataHashes Array of metadata hashes
     * @param devicePublicKeys Array of device public keys
     * @param owners Array of attestation owners
     * @param batchRoot Merkle root of entire batch
     */
    function submitBatch(
        bytes32[] calldata attestationIds,
        bytes32[] calldata merkleRoots,
        bytes32[] calldata imageHashes,
        bytes32[] calldata metadataHashes,
        address[] calldata devicePublicKeys,
        address[] calldata owners,
        bytes32 batchRoot
    ) external onlyTrustedSubmitter {
        require(attestationIds.length > 0, "Empty batch");
        require(
            attestationIds.length == merkleRoots.length &&
            attestationIds.length == imageHashes.length &&
            attestationIds.length == metadataHashes.length &&
            attestationIds.length == devicePublicKeys.length &&
            attestationIds.length == owners.length,
            "Array length mismatch"
        );
        
        uint256 currentBatchId = batchCounter++;
        
        // Store batch info
        batches[currentBatchId] = Batch({
            count: attestationIds.length,
            timestamp: block.timestamp,
            batchRoot: batchRoot,
            submitter: msg.sender
        });
        
        // Store individual attestations
        for (uint256 i = 0; i < attestationIds.length; i++) {
            bytes32 attestationId = attestationIds[i];
            
            require(attestations[attestationId].timestamp == 0, "Attestation already exists");
            
            attestations[attestationId] = Attestation({
                merkleRoot: merkleRoots[i],
                imageHash: imageHashes[i],
                metadataHash: metadataHashes[i],
                devicePublicKey: devicePublicKeys[i],
                timestamp: block.timestamp,
                batchId: currentBatchId,
                revealed: false
            });
            
            attestationOwners[attestationId] = owners[i];
            
            emit AttestationCreated(
                attestationId,
                owners[i],
                currentBatchId,
                merkleRoots[i],
                block.timestamp
            );
        }
        
        totalAttestations += attestationIds.length;
        
        emit BatchSubmitted(currentBatchId, attestationIds.length, batchRoot, msg.sender);
    }
    
    /**
     * @notice Reveal an attested image publicly
     * @dev Only attestation owner can reveal
     * @param attestationId The attestation to reveal
     * @param imageURI IPFS/Arweave URI of the image
     * @param metadataURI URI of the full metadata (camera, GPS, etc.)
     */
    function revealImage(
        bytes32 attestationId,
        string calldata imageURI,
        string calldata metadataURI
    ) external onlyAttestationOwner(attestationId) {
        require(attestations[attestationId].timestamp > 0, "Attestation does not exist");
        require(!attestations[attestationId].revealed, "Already revealed");
        
        attestations[attestationId].revealed = true;
        revealedImageURIs[attestationId] = imageURI;
        revealedMetadataURIs[attestationId] = metadataURI;
        
        emit ImageRevealed(attestationId, imageURI, metadataURI);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Verify an attestation exists and get its data
     * @param attestationId The attestation to verify
     * @return exists Whether the attestation exists
     * @return attestation The attestation data
     * @return isRevealed Whether the image is publicly revealed
     * @return imageURI The revealed image URI (empty if not revealed)
     */
    function verifyAttestation(bytes32 attestationId)
        external
        view
        returns (
            bool exists,
            Attestation memory attestation,
            bool isRevealed,
            string memory imageURI,
            string memory metadataURI
        )
    {
        attestation = attestations[attestationId];
        exists = attestation.timestamp > 0;
        isRevealed = attestation.revealed;
        imageURI = isRevealed ? revealedImageURIs[attestationId] : "";
        metadataURI = isRevealed ? revealedMetadataURIs[attestationId] : "";
    }
    
    /**
     * @notice Get batch information
     * @param batchId The batch ID
     * @return batch The batch data
     */
    function getBatch(uint256 batchId) external view returns (Batch memory batch) {
        return batches[batchId];
    }
    
    /**
     * @notice Check if attestation is verified (exists on-chain)
     * @param attestationId The attestation to check
     * @return verified Whether it exists and is valid
     */
    function isVerified(bytes32 attestationId) external view returns (bool verified) {
        return attestations[attestationId].timestamp > 0;
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Update trusted submitter address
     * @param newSubmitter New trusted backend address
     */
    function updateTrustedSubmitter(address newSubmitter) external onlyOwner {
        require(newSubmitter != address(0), "Invalid address");
        trustedSubmitter = newSubmitter;
    }
    
    /**
     * @notice Transfer contract ownership
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    // ============ Helper Functions ============
    
    /**
     * @notice Generate attestation ID from image hash and timestamp
     * @param imageHash The image hash
     * @param timestamp The capture timestamp
     * @return The unique attestation ID
     */
    function generateAttestationId(bytes32 imageHash, uint256 timestamp)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(imageHash, timestamp));
    }
}


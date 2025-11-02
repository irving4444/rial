const express = require('express');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const EC = require('elliptic').ec;

const app = express();
const port = 3000;

// Elliptic curve setup - P-256 is used by iOS Secure Enclave
const ec = new EC('p256');

// Configure multer for file uploads
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// Create uploads directory if it doesn't exist
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir);
}

// Middleware for logging
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} from ${req.ip}`);
    next();
});

// Test endpoint
app.get('/test', (req, res) => {
    console.log('✅ Test endpoint hit!');
    res.json({ message: 'Backend is working!', timestamp: new Date().toISOString() });
});

// Main prove endpoint
app.post('/prove', upload.single('img_buffer'), async (req, res) => {
    console.log('📥 Received request to /prove');
    
    try {
        // 1. Validate file upload
        if (!req.file) {
            console.log('❌ No file uploaded');
            return res.status(400).json({ 
                error: 'No file uploaded',
                body: Object.keys(req.body)
            });
        }
        
        const imageBuffer = req.file.buffer;
        console.log(`✅ Image received: ${imageBuffer.length} bytes`);
        
        // 2. Extract form data
        const {
            signature: signatureBase64,
            public_key: publicKeyBase64,
            c2pa_claim: c2paClaimJson,
            transformations: transformationsJson
        } = req.body;
        
        console.log('📋 Form data:');
        console.log(`   - Signature: ${signatureBase64 ? signatureBase64.substring(0, 40) + '...' : 'missing'}`);
        console.log(`   - Public Key: ${publicKeyBase64 ? publicKeyBase64.substring(0, 40) + '...' : 'missing'}`);
        console.log(`   - Transformations: ${transformationsJson || 'none'}`);
        
        // 3. Save image to disk
        const filename = `image-${Date.now()}.png`;
        const filepath = path.join(uploadsDir, filename);
        fs.writeFileSync(filepath, imageBuffer);
        console.log(`💾 Image saved to ${filepath}`);
        
        // 4. Parse C2PA claim if provided (needed for verification)
        let c2paClaim = null;
        if (c2paClaimJson && c2paClaimJson !== 'undefined') {
            try {
                c2paClaim = JSON.parse(c2paClaimJson);
                console.log('📊 C2PA Claim parsed:');
                console.log(`   - Merkle Root: ${c2paClaim.imageRoot ? c2paClaim.imageRoot.substring(0, 40) + '...' : 'none'}`);
                console.log(`   - Timestamp: ${c2paClaim.timestamp || 'none'}`);
            } catch (e) {
                console.log(`⚠️ Failed to parse C2PA claim: ${e.message}`);
            }
        }
        
        // 5. Verify signature (if provided)
        let signatureValid = null;
        
        if (signatureBase64 && publicKeyBase64) {
            try {
                console.log('🔐 Starting signature verification...');
                signatureValid = await verifySignature(
                    imageBuffer,
                    signatureBase64,
                    publicKeyBase64,
                    c2paClaim
                );
                console.log(`🔐 Signature verification: ${signatureValid ? '✅ VALID' : '❌ INVALID'}`);
            } catch (error) {
                console.log(`⚠️ Signature verification error: ${error.message}`);
                console.log(`   Stack: ${error.stack}`);
                signatureValid = false;
            }
        } else {
            console.log('⚠️ No signature/public key provided - skipping verification');
        }
        
        // 6. Parse transformations
        let transformations = [];
        if (transformationsJson) {
            try {
                transformations = JSON.parse(transformationsJson);
                console.log(`✂️ Transformations: ${JSON.stringify(transformations)}`);
            } catch (e) {
                console.log(`⚠️ Failed to parse transformations: ${e.message}`);
            }
        }
        
        // 7. Generate response
        const response = {
            success: true,
            message: 'Image received and verified',
            signatureValid: signatureValid,
            imageUrl: `/uploads/${filename}`,
            c2paClaim: c2paClaim,
            transformations: transformations,
            timestamp: new Date().toISOString()
        };
        
        console.log('✅ Response ready:', response.success ? 'SUCCESS' : 'FAILURE');
        res.json(response);
        
    } catch (error) {
        console.error('❌ Error processing request:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: error.message
        });
    }
});

/**
 * Verify ECDSA signature using public key
 * Note: iOS Secure Enclave uses ECDSA with P-256 curve and SHA-256
 */
async function verifySignature(imageBuffer, signatureBase64, publicKeyBase64, c2paClaim) {
    return new Promise((resolve) => {
        try {
            console.log('   🔍 Starting signature verification...');
            
            // Validate inputs are not empty
            if (!signatureBase64 || signatureBase64.length === 0) {
                console.log('   ❌ Signature is empty');
                return resolve(false);
            }
            
            if (!publicKeyBase64 || publicKeyBase64.length === 0) {
                console.log('   ❌ Public key is empty');
                return resolve(false);
            }
            
            if (!c2paClaim || !c2paClaim.imageRoot) {
                console.log('   ❌ Missing merkle root in C2PA claim');
                return resolve(false);
            }
            
            // Decode base64 inputs
            const signatureDer = Buffer.from(signatureBase64, 'base64');
            const publicKeyBuffer = Buffer.from(publicKeyBase64, 'base64');
            
            console.log(`   📏 Signature length: ${signatureDer.length} bytes`);
            console.log(`   📏 Public key length: ${publicKeyBuffer.length} bytes`);
            
            // Extract the merkle root that was signed
            const merkleRootHex = c2paClaim.imageRoot;
            console.log(`   🌳 Merkle root to verify: ${merkleRootHex.substring(0, 40)}...`);
            
            // Parse public key from SPKI format
            // The public key is in X.509 SubjectPublicKeyInfo format
            // For P-256, the actual key data starts after the header
            let publicKeyHex;
            try {
                // SPKI format for P-256: header (26 bytes) + uncompressed point (65 bytes: 0x04 + 32-byte X + 32-byte Y)
                // We need to extract the raw uncompressed point
                if (publicKeyBuffer.length === 91) {
                    // Standard SPKI format
                    const rawPublicKey = publicKeyBuffer.slice(26); // Skip SPKI header
                    publicKeyHex = rawPublicKey.toString('hex');
                } else {
                    console.log(`   ⚠️ Unexpected public key length: ${publicKeyBuffer.length}`);
                    publicKeyHex = publicKeyBuffer.toString('hex');
                }
                console.log(`   🔑 Public key (hex): ${publicKeyHex.substring(0, 40)}...`);
            } catch (keyError) {
                console.log(`   ❌ Failed to parse public key: ${keyError.message}`);
                return resolve(false);
            }
            
            // Parse DER signature to extract r and s values
            // DER format: 0x30 [total-length] 0x02 [r-length] [r] 0x02 [s-length] [s]
            let r, s;
            try {
                let offset = 2; // Skip 0x30 and total length
                
                // Read r
                if (signatureDer[offset] !== 0x02) {
                    throw new Error('Invalid DER signature: expected INTEGER tag for r');
                }
                offset++;
                const rLength = signatureDer[offset];
                offset++;
                r = signatureDer.slice(offset, offset + rLength);
                offset += rLength;
                
                // Read s
                if (signatureDer[offset] !== 0x02) {
                    throw new Error('Invalid DER signature: expected INTEGER tag for s');
                }
                offset++;
                const sLength = signatureDer[offset];
                offset++;
                s = signatureDer.slice(offset, offset + sLength);
                
                // Remove leading zeros if present (DER encoding may add them for positive numbers)
                while (r.length > 32 && r[0] === 0x00) {
                    r = r.slice(1);
                }
                while (s.length > 32 && s[0] === 0x00) {
                    s = s.slice(1);
                }
                
                console.log(`   📝 Signature r length: ${r.length}, s length: ${s.length}`);
            } catch (sigError) {
                console.log(`   ❌ Failed to parse DER signature: ${sigError.message}`);
                return resolve(false);
            }
            
            // Create elliptic curve public key
            let publicKey;
            try {
                publicKey = ec.keyFromPublic(publicKeyHex, 'hex');
            } catch (keyError) {
                console.log(`   ❌ Failed to create EC public key: ${keyError.message}`);
                return resolve(false);
            }
            
            // Verify signature against merkle root
            try {
                const isValid = publicKey.verify(merkleRootHex, { r, s });
                console.log(`   ${isValid ? '✅' : '❌'} Signature verification: ${isValid ? 'VALID' : 'INVALID'}`);
                resolve(isValid);
            } catch (verifyError) {
                console.log(`   ❌ Signature verification failed: ${verifyError.message}`);
                resolve(false);
            }
            
        } catch (error) {
            console.error('   ❌ Verification error:', error.message);
            resolve(false);
        }
    });
}

// Start server
app.listen(port, '0.0.0.0', () => {
    console.log(`🚀 Backend server listening at http://0.0.0.0:${port}`);
    console.log(`📱 Access from iPhone at http://10.0.0.132:${port}`);
    console.log('');
    console.log('Endpoints:');
    console.log(`   GET  /test  - Health check`);
    console.log(`   POST /prove - Image attestation & verification`);
});


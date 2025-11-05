# 🚀 Smart Contract Deployment Instructions

## ✅ Compilation Successful!

Your `RialAttestation.sol` contract has been compiled successfully.

---

## 📋 Your Deployment Wallet

```
Address: 0x1e34ECF6695402ae5B4b7083BFB5b50d8551eF76
Network: Polygon Amoy Testnet (NEW!)
Private Key: Saved in contracts/.env
```

**⚠️ IMPORTANT: This is a TESTNET wallet. Do NOT use for mainnet!**

---

## Step 1: Get Free Testnet MATIC

### Option 1: Polygon Faucet (Recommended)
1. Visit: **https://faucet.polygon.technology/**
2. Connect your wallet OR paste address: `0x1e34ECF6695402ae5B4b7083BFB5b50d8551eF76`
3. Select **"Polygon Amoy"** network
4. Complete CAPTCHA
5. Click "Submit"
6. Wait ~30 seconds

### Option 2: Alchemy Faucet
1. Visit: **https://www.alchemy.com/faucets/polygon-amoy**
2. Paste address: `0x1e34ECF6695402ae5B4b7083BFB5b50d8551eF76`
3. Complete verification
4. Receive 0.5 POL

### Option 3: QuickNode Faucet
1. Visit: **https://faucet.quicknode.com/polygon/amoy**
2. Enter address
3. Receive testnet MATIC

---

## Step 2: Verify You Have MATIC

Once you have testnet MATIC, run this command to check your balance:

```bash
cd /Users/aungmaw/rial/contracts

cast balance 0x1e34ECF6695402ae5B4b7083BFB5b50d8551eF76 \\
  --rpc-url https://rpc-amoy.polygon.technology
```

You should see a balance like: `200000000000000000` (0.2 MATIC)

---

## Step 3: Deploy the Contract

Once you have MATIC, run:

```bash
cd /Users/aungmaw/rial/contracts

forge script script/Deploy.s.sol \\
  --rpc-url polygon_amoy \\
  --broadcast \\
  --slow
```

### What this does:
- Deploys `RialAttestation.sol` to Polygon Amoy testnet
- Sets `TRUSTED_SUBMITTER` to your wallet address
- Broadcasts the transaction
- Shows you the deployed contract address

### Expected output:
```
✅ RialAttestation deployed to: 0x...
✅ Owner: 0x1e34ECF6695402ae5B4b7083BFB5b50d8551eF76
✅ Trusted Submitter: 0x1e34ECF6695402ae5B4b7083BFB5b50d8551eF76
```

---

## Step 4: Save the Contract Address

After deployment, you'll see:
```
Contract deployed to: 0xABC123...
```

**Save this address!** You'll need it for:
1. Backend configuration
2. Verification
3. Testing

---

## Step 5: Update Backend Configuration

Copy the contract address and update backend `.env`:

```bash
cd /Users/aungmaw/rial/backend

# Add this line to .env:
CONTRACT_ADDRESS=0x...your_contract_address
```

---

## Step 6: Verify on PolygonScan (Optional)

View your contract on the block explorer:

```
https://www.oklink.com/amoy/address/0x...your_contract_address
```

---

## 🧪 Testing the Deployment

### Test 1: Check Contract on Chain
```bash
cast call 0x...your_contract_address \\
  "owner()" \\
  --rpc-url https://rpc-amoy.polygon.technology
```

Should return your wallet address.

### Test 2: Check Trusted Submitter
```bash
cast call 0x...your_contract_address \\
  "trustedSubmitter()" \\
  --rpc-url https://rpc-amoy.polygon.technology
```

Should return your wallet address.

### Test 3: Check Total Attestations
```bash
cast call 0x...your_contract_address \\
  "totalAttestations()" \\
  --rpc-url https://rpc-amoy.polygon.technology
```

Should return `0` (no attestations yet).

---

## 💡 Quick Reference

| Item | Value |
|------|-------|
| **Network** | Polygon Amoy Testnet |
| **Chain ID** | 80002 |
| **RPC URL** | https://rpc-amoy.polygon.technology |
| **Explorer** | https://www.oklink.com/amoy |
| **Faucet** | https://faucet.polygon.technology/ |
| **Your Address** | 0x1e34ECF6695402ae5B4b7083BFB5b50d8551eF76 |

---

## 🚨 Troubleshooting

### Error: "Insufficient funds"
- Get more testnet MATIC from faucet
- Each deployment costs ~$0.10 worth of testnet MATIC

### Error: "Nonce too low"
- Wait a few seconds and try again
- Or add `--legacy` flag to deployment command

### Error: "Transaction reverted"
- Check that you have enough MATIC
- Verify constructor parameters are correct

---

## 🎯 Next Steps After Deployment

1. ✅ Save contract address
2. ✅ Update backend `.env` file
3. ✅ Test backend connection
4. ✅ Submit first batch
5. ✅ Verify on blockchain explorer
6. ✅ Deploy to mainnet when ready!

---

## 📞 Need Help?

Check deployment logs for specific error messages and refer to:
- Foundry Book: https://book.getfoundry.sh/
- Polygon Docs: https://docs.polygon.technology/

---

**Ready to deploy when you have testnet MATIC!** 🚀


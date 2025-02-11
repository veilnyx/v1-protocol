import { Groth16VerifyingKey, UpaClient, UpaInstanceDescriptor } from '@nebrazkp/upa/sdk';
import { SnarkJSVKey } from 'snarkjs';
import * as path from "path";
import dotenv from "dotenv";
import * as fs from "fs";
import * as ethers from "ethers";
import { circuits } from "../test/fixtures/scripts/zk";

dotenv.config({
    path: path.resolve(__dirname, "../.env")
});

export const registerCircuitsOnNebra = async () => {
    // creating ether signer
    const sepoliaProvider = new ethers.JsonRpcProvider(process.env.RPC_ETHEREUM_SEPOLIA);
    const envPrivateKey = process.env.PRIVATE_KEY;
    const privateKey = envPrivateKey.slice(2).padStart(64, '0');
    console.log("PrivateKey:", privateKey);
    const wallet = new ethers.Wallet(privateKey);
    const signer = wallet.connect(sepoliaProvider);

    // Registering our circuits with Nebra UPA through the circuit's verification keys.
    /// @dev This step requires the Nebra verifier contract to be deployed on the chain and it's details in the upa.instance file.
    const upaClient = await UpaClient.init(signer, {
        "verifier": "0x3B946743DEB7B6C97F05B7a31B23562448047E3E",
        "deploymentBlockNumber": 6405136,
        "deploymentTx": "0xa8626318b76b71cd21cdfb93ef67c9571d94e01383e852a3eb6dc5dc6188808e",
        "chainId": "11155111"
    });
    console.log("Nebra client created");

    const registerCircuitVKSnarkJs = JSON.parse(fs.readFileSync(circuits.register.vKey, "ascii"));
    const registerVKNebraFormat: Groth16VerifyingKey = Groth16VerifyingKey.from_snarkjs(registerCircuitVKSnarkJs as SnarkJSVKey);
    console.log("Register circuit Groth16VK created");

    const transact21CircuitVKSnarkJs = JSON.parse(fs.readFileSync(circuits.transact21.vKey, "ascii"));
    const transact21VKNebraFormat: Groth16VerifyingKey = Groth16VerifyingKey.from_snarkjs(transact21CircuitVKSnarkJs as SnarkJSVKey);
    console.log("transact21 circuit Groth16VK created");

    // On-chain call to Nebra's verifier contract to register the verification key
    const registerVKTxRes = await upaClient.upaInstance.verifier.registerVK(transact21VKNebraFormat, {
        gasLimit: 15_00_000
    });
    console.log("VK registration on Nebra tx res:", registerVKTxRes);
}

registerCircuitsOnNebra().catch(console.error);
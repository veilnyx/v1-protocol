import { Groth16VerifyingKey, UpaClient, UpaInstanceDescriptor } from '@nebrazkp/upa/sdk';
import { SnarkJSVKey } from 'snarkjs';
import * as path from "path";
import dotenv from "dotenv";
import * as fs from "fs";
import * as ethers from "ethers";

dotenv.config({
    path: path.resolve(__dirname, "../.env")
});

export const registerCircuitsOnNebra = async () => {
    let upaInstanceDescriptor: UpaInstanceDescriptor;
    const upaInstanceFilePath = path.resolve(__dirname, "upa.instance");
    upaInstanceDescriptor = JSON.parse(fs.readFileSync(upaInstanceFilePath, "ascii")) as UpaInstanceDescriptor;

    // creating ether signer
    // @todo: read rpc & private key from .env
    const sepoliaProvider = new ethers.JsonRpcProvider(process.env.RPC_ETHEREUM_SEPOLIA);

    const envPrivateKey = process.env.PRIVATE_KEY;
    const privateKey = envPrivateKey.slice(2).padStart(64, '0');
    console.log("PrivateKey:", privateKey);
    const wallet = new ethers.Wallet(privateKey);
    const signer = wallet.connect(sepoliaProvider);

    // Registering our circuits with Nebra UPA through the circuit's verification keys.
    /// @dev This step requires the verifier contract to be deployed on the chain and it's details in the upa.instance file.
    const upaClient = await UpaClient.init(signer, upaInstanceDescriptor);
    console.log("Nebra client:", upaClient);

    const registerCircuitVKSnarkJs = JSON.parse(fs.readFileSync(path.resolve(__dirname, "vk/registerVK.json"), "utf-8"));
    const registerVKNebraFormat: Groth16VerifyingKey = Groth16VerifyingKey.from_snarkjs(registerCircuitVKSnarkJs as SnarkJSVKey);
    console.log("Groth16VK format:", registerVKNebraFormat);

    // On-chain call to Nebra's verifier contract to register the verification key
    const registerVKTxRes = await upaClient.upaInstance.verifier.registerVK(registerVKNebraFormat, {
        gasLimit: 100_000
    });
    console.log("VK registration tx res:", registerVKTxRes);
}

registerCircuitsOnNebra().catch(console.error);
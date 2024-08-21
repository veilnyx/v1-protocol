import hre from "hardhat";
import poolModule from "../ignition/modules/pool";
import config from "./config.json";

const chainId = hre.network.config.chainId;
const commonParams = config.common;
const chainParams = config[chainId];

// const hasherArtifacts = hre.artifacts.readArtifactSync("Hasher");

// const main1 = async () => {
//   const client = await hre.viem.getPublicClient();
//   const wallets = await hre.viem.getWalletClients();
//   const wallet = wallets[0];
//   const [walletAddress] = await wallet.getAddresses();

//   const merkleTree = await hre.viem.deployContract("MerkleTreeLogic");
//   const queuedMerkleTree = await hre.viem.deployContract(
//     "QueuedMerkleTreeLogic"
//   );
//   const poolImpl = await hre.viem.deployContract("Pool", [], {
//     libraries: {
//       AssetLogic: zeroAddress,
//       MerkleTreeLogic: merkleTree.address,
//       QueuedMerkleTreeLogic: queuedMerkleTree.address,
//       ShieldedAddressLogic: zeroAddress,
//       ShieldedTransactionLogic: zeroAddress,
//     },
//   });
//   console.log("poolImpl", poolImpl.address);
//   //   console.log("chainParams", chainParams);
//   const dHasher = await deployHasher();
//   console.log("dHasher", dHasher);

//   //   const hasher = await hre.viem.deployContract("Hasher", [
//   //     chainParams.poseidonT3,
//   //     chainParams.poseidonT4,
//   //   ]);
//   //   console.log("hasher", hasher.address);

//   const hasher = await hre.viem.getContractAt("Hasher", dHasher.hasher);

//   const v = await client.readContract({
//     address: hasher.address,
//     abi: hasherArtifacts.abi,
//     functionName: "hash",
//     args: [[BigInt(1), BigInt(2)]],
//   });
//   console.log("v", v);

//   const codeSize = await client.getCode({ address: hasher.address });
//   console.log("codeSize", codeSize.length);

//   const args = [
//     commonParams.addressTreeDepth,
//     commonParams.commitmentTreeDepth,
//     commonParams.commitmentTreeQueueSize,
//     zeroAddress,
//     zeroAddress,
//     zeroAddress,
//     hasher.address,
//     BigInt(commonParams.withdrawFeeBps),
//   ];
//   console.log("args", args);

//   const poolAbi = hre.artifacts.readArtifactSync("Pool").abi;

//   try {
//     //@ts-ignore
//     const hash = await wallet.writeContract({
//       address: poolImpl.address,
//       abi: poolAbi,
//       functionName: "initialize",
//       args: args as any,
//     });
//     const rct = await client.waitForTransactionReceipt({ hash });
//     console.log("rct", rct.status);
//   } catch (error) {
//     console.log(error.message);
//   }
// };

const main = async () => {
  const poolParams = {
    ...commonParams,
  };
  const hasherParams = {
    poseidonT3: chainParams.poseidonT3,
    poseidonT4: chainParams.poseidonT4,
  };
  const screenerParams = {
    sanctionsList: chainParams.sanctionsList,
  };
  await hre.ignition.deploy(poolModule, {
    parameters: {
      pool: poolParams,
      hasher: hasherParams,
      screener: screenerParams,
    },
  });
};

main().catch(console.error);

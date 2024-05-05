import hre from "hardhat";
import { encodeFunctionData, type Address, type Hex } from "viem";

async function main() {
  const billboardImpl = await hre.viem.deployContract("Billboard");
  const billboardFactoryImpl = await hre.viem.deployContract(
    "BillboardFactory"
  );

  const billboardFactoryProxyArgs: [Address, Hex] = [
    billboardFactoryImpl.address,
    encodeFunctionData({
      abi: billboardFactoryImpl.abi,
      functionName: "init",
      args: [billboardImpl.address],
    }),
  ];

  const billboardFactoryProxy = await hre.viem.deployContract(
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
    billboardFactoryProxyArgs
  );

  console.log("BillboardFactory deployed to:", billboardFactoryProxy.address);

  await new Promise((resolve) => setTimeout(resolve, 30_000));

  await hre.run("verify:verify", {
    address: billboardImpl.address,
    constructorArguments: [],
  });
  await hre.run("verify:verify", {
    address: billboardFactoryImpl.address,
    constructorArguments: [],
  });
  await hre.run("verify:verify", {
    address: billboardFactoryProxy.address,
    constructorArguments: billboardFactoryProxyArgs,
  });
}

main()
  .then(() => {
    console.log("Done");
    process.exit(0);
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });

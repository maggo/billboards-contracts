import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { decodeEventLog, encodeFunctionData, parseEther } from "viem";

describe("Billboard", () => {
  async function deployBillboardFixture() {
    const publicClient = await hre.viem.getPublicClient();
    // Contracts are deployed using the first signer/account by default
    const [deployer, alice, bob] = await hre.viem.getWalletClients();

    const billboardImpl = await hre.viem.deployContract("Billboard");
    const billboardFactoryImpl = await hre.viem.deployContract(
      "BillboardFactory"
    );
    const billboardFactoryProxy = await hre.viem.deployContract(
      "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
      [
        billboardFactoryImpl.address,
        encodeFunctionData({
          abi: billboardFactoryImpl.abi,
          functionName: "init",
          args: [billboardImpl.address],
        }),
      ]
    );

    const billboardFactory = await hre.viem.getContractAt(
      "BillboardFactory",
      billboardFactoryProxy.address
    );

    const exampleBillboardDeployTx = await billboardFactory.write.create([
      "Example Billboard",
      "EXMPL",
      parseEther("0.1"),
      parseEther("0.1"),
    ]);

    const data = await publicClient.waitForTransactionReceipt({
      hash: exampleBillboardDeployTx,
    });

    const exampleBillboardAddress = data.logs
      .filter((log) => log.address === billboardFactory.address)
      .map((log) =>
        decodeEventLog({
          abi: billboardFactory.abi,
          eventName: "BillboardCreated",
          ...log,
        })
      )[0].args.billboardProxy;

    const exampleBillboard = await hre.viem.getContractAt(
      "Billboard",
      exampleBillboardAddress
    );

    return {
      billboardImpl,
      billboardFactory,
      publicClient,
      deployer,
      alice,
      bob,
      exampleBillboard,
    };
  }

  describe("Deployment", () => {
    it("Should set the right price", async function () {
      const { exampleBillboard } = await loadFixture(deployBillboardFixture);
      expect(await exampleBillboard.read.getPrice([0n])).to.equal(
        parseEther("0.1")
      );
    });
  });
});

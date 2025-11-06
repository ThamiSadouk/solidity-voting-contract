import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-docgen";

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  docgen: {
    path: "./docs",
    clear: true,
    runOnCompile: true
  },
  defaultNetwork: "hardhat",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337
    }
  }
};

export default config;

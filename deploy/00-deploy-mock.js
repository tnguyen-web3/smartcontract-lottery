const { network } = require('hardhat');
const { networkConfig, developmentChains } = require('../helper-hardhat-config');

const BASE_FEE = ethers.utils.parseEther('0.25');
const GAS_PRICE_LINK = 1e9;
module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  if (developmentChains.includes(network.name)) {
    log('local network detected! deploying mock...');
    await deploy('VRFCoordinatorV2Mock', {
      from: deployer,
      log: true,
      args: [BASE_FEE, GAS_PRICE_LINK],
    });
    log('Mock deployed');
    log('-----------------------');
  }
};

module.exports.tags = ['all', 'mocks'];

import {expect} from "chai"
import hre from "hardhat"
// import {loadFixture} from "@nomicfoundation/hardhat-toolbox/network-helpers";

async function deploy() {
    const [owner, voter1, voter2, voter3] = await hre.ethers.getSigners()
    const Factory = await hre.ethers.getContractFactory("Voting")
    const voting = await Factory.deploy()
    await voting.waitForDeployment()

    return { voting, owner, voter1, voter2, voter3 }
}

// async function deployStorageFixture() {
//     const [owner, otherAccount] = await hre.ethers.getSigners();
//     const Factory = await hre.ethers.getContractFactory("Voting.sol")
//     const simpleStorage = await Factory.deploy(0)
//     return { simpleStorage, owner, otherAccount }
// }

describe("Voting", function () {
    describe("Add voter", function () {
        it("Should add voter to session", async function () {
            const {voting, voter1} = await deploy()

            await (await voting.addVoter(voter1.address)).wait()
            const voter = await voting.connect(voter1).getVoter(voter1.address)
            expect(voter.isRegistered).to.equal(true)
        })

        it("Should revert if already registered", async function () {
            const { voting, voter1 } = await deploy()

            await (await voting.addVoter(voter1.address)).wait()
            await expect(voting.addVoter(voter1.address)).to.be.revertedWith("Already registered")
        })

        it("Should revert if wrong status", async function () {
            const { voting, voter1 } = await deploy()

            await (await voting.startProposalsRegistering()).wait()
            await expect(voting.addVoter(voter1.address)).to.be.revertedWith("Voters registration is not open yet")
        })

        it("should emit event on addVoter", async function () {
            const {voting, voter1} = await deploy()

            await expect(await voting.addVoter(voter1.address))
                .to.emit(voting, "VoterRegistered")
                .withArgs(voter1)
        })
    })

    describe("Add proposal", function () {
        it("Should add proposal during proposals registration", async function () {
            const {voting, voter1} = await deploy()

            await (await voting.addVoter(voter1.address)).wait()

            await (await voting.startProposalsRegistering()).wait()

            const proposalDesc = "proposal1"

            // Add proposal as the registered voter
            await expect(voting.connect(voter1).addProposal(proposalDesc))
                .to.emit(voting, "ProposalRegistered")
                .withArgs(1)


            const proposal = await voting.connect(voter1).getOneProposal(1)
            expect(proposal.description).to.equal(proposalDesc)
            expect(proposal.voteCount).to.equal(0n)
        })

        it("Should revert if empty description", async function () {
            const { voting, voter1 } = await deploy()
            await (await voting.addVoter(voter1.address)).wait()
            await (await voting.startProposalsRegistering()).wait()

            await expect(voting.connect(voter1).addProposal("")).to.be.revertedWith("Vous ne pouvez pas ne rien proposer")
        })
    })

    describe("Set vote", function () {
        it("Should set vote and update state", async function () {
            const {voting, voter1} = await deploy()

            await (await voting.addVoter(voter1.address)).wait()

            await (await voting.startProposalsRegistering()).wait()
            await (await voting.connect(voter1).addProposal("P1")).wait()
            await (await voting.endProposalsRegistering()).wait()

            await (await voting.startVotingSession()).wait()

            // vote for proposal #1
            await expect(voting.connect(voter1).setVote(1))
                .to.emit(voting, "Voted")
                .withArgs(voter1.address, 1)

            const p1 = await voting.connect(voter1).getOneProposal(1)
            expect(p1.voteCount).to.equal(1n)

            const v = await voting.connect(voter1).getVoter(voter1.address)
            expect(v.hasVoted).to.equal(true)
            expect(v.votedProposalId).to.equal(1)
        })
    })
})
import {expect} from "chai"
import hre from "hardhat"
import {loadFixture} from "@nomicfoundation/hardhat-toolbox/network-helpers"

async function deployFixture() {
    const [owner, voter1, voter2, voter3] = await hre.ethers.getSigners()
    const Factory = await hre.ethers.getContractFactory("Voting")
    const voting = await Factory.deploy()
    await voting.waitForDeployment()

    return { voting, owner, voter1, voter2, voter3 }
}

async function deployFixtureWithVoters() {
    const {voting, owner, voter1, voter2, voter3} = await loadFixture(deployFixture)
    await voting.addVoter(voter1.address)
    await voting.addVoter(voter2.address)
    await voting.addVoter(voter3.address)

    return { voting, owner, voter1, voter2, voter3 }
}

describe("Voting", function () {
    describe("Registering voters session", function () {
        it("Should add voter", async function () {
            const {voting, voter1} = await deployFixtureWithVoters()
            const voter = await voting.connect(voter1).getVoter(voter1.address)
            expect(voter.isRegistered).to.equal(true)
        })

        it("Should revert if not owner", async function () {
            const {voting, voter1} = await loadFixture(deployFixture)

            await expect(voting.connect(voter1).addVoter(voter1.address)).to.be.revertedWithCustomError(voting, "OwnableUnauthorizedAccount")
              .withArgs(voter1.address)
        })

        it("Should revert if already registered", async function () {
            const { voting, voter1 } = await deployFixtureWithVoters()

            await expect(voting.addVoter(voter1.address)).to.be.revertedWith("Already registered")
        })

        it("Should revert if voter registration is not opened", async function () {
            const { voting, voter1 } = await loadFixture(deployFixture)
            await voting.startProposalsRegistering()

            await expect(voting.addVoter(voter1.address)).to.be.revertedWith("Voters registration is not open yet")
        })

        it("Should reverts getVoter for non voter", async () => {
            const { voting, voter1 } = await loadFixture(deployFixture)
            await expect(voting.getVoter(voter1.address)).to.be.revertedWith("You're not a voter")
        })

        it("should emit event on addVoter", async function () {
            const {voting, voter1} = await loadFixture(deployFixture)

            expect(await voting.addVoter(voter1.address))
                .to.emit(voting, "VoterRegistered")
                .withArgs(voter1.address)
        })
    })

    describe("Proposal session", function () {
        it("Should emit event on start proposal session", async () => {
            const { voting } = await loadFixture(deployFixture)

            await expect(voting.startProposalsRegistering())
              .to.emit(voting, "WorkflowStatusChange")
              .withArgs(0, 1)
        })

        it("Should reverts if called in wrong status", async () => {
            const { voting } = await loadFixture(deployFixture)
            await voting.startProposalsRegistering()

            await expect(voting.startProposalsRegistering()).to.be.revertedWith("Registering proposals cant be started now")
        })

        it("Should add proposal", async function () {
            const {voting, voter1} = await deployFixtureWithVoters()

            await voting.startProposalsRegistering()
            const pDesc = "A"
            await voting.connect(voter1).addProposal(pDesc)
            const p = await voting.connect(voter1).getOneProposal(1)

            expect(p.description).to.equal(pDesc)
        })

        it("Should revert if empty description", async function () {
            const { voting, voter1 } = await deployFixtureWithVoters()
            await voting.startProposalsRegistering()

            await expect(voting.connect(voter1).addProposal("")).to.be.revertedWith("Vous ne pouvez pas ne rien proposer")
        })

        it("Should revert if proposal phase is not opened", async function () {
            const { voting, voter1 } = await deployFixtureWithVoters()

            await expect(voting.connect(voter1).addProposal("A")).to.be.revertedWith("Proposals are not allowed yet")
        })

        it("Should revert getProposal for non voter", async function () {
            const { voting } = await loadFixture(deployFixture)

            await expect(voting.getOneProposal(1)).to.be.revertedWith("You're not a voter")
        })

        it("Should get the correct number of a proposal votes ", async function () {
            const {voting, voter1, voter2, voter3} = await deployFixtureWithVoters()

            // Proposal session
            await voting.startProposalsRegistering()
            await voting.connect(voter1).addProposal("A") // idx 1
            await voting.connect(voter2).addProposal("B") // idx 2
            await voting.connect(voter3).addProposal("C") // idx 3
            await voting.endProposalsRegistering()

            // Voting session
            await voting.startVotingSession()
            await voting.connect(voter1).setVote(1)
            await voting.connect(voter2).setVote(2)
            await voting.connect(voter3).setVote(2)

            const p1 = await voting.connect(voter1).getOneProposal(1)
            expect(p1.voteCount).to.equal(1)

            const p2 = await voting.connect(voter1).getOneProposal(2)
            expect(p2.voteCount).to.equal(2)
        })

        it('Should create "GENESIS" at index 0 on startProposalsRegistering', async () => {
            const { voting, voter1 } = await deployFixtureWithVoters()
            await voting.startProposalsRegistering()
            const p0 = await voting.connect(voter1).getOneProposal(0)
            expect(p0.description).to.equal("GENESIS")
        });

        it("Should emit event on addProposal", async function () {
            const { voting, voter1 } = await deployFixtureWithVoters()
            await voting.startProposalsRegistering()

            expect(await voting.connect(voter1).addProposal("A"))
              .to.emit(voting, "ProposalRegistered")
              .withArgs(1)
        })

        it("Should reverts if startProposalsRegistering not triggered before endProposalsRegistering", async () => {
            const { voting } = await loadFixture(deployFixture)

            await expect(voting.endProposalsRegistering()).to.be.revertedWith("Registering proposals havent started yet")
        })

        it("Should emit event on endProposalsRegistering", async () => {
            const { voting } = await loadFixture(deployFixture)
            await voting.startProposalsRegistering()

            await expect(voting.endProposalsRegistering())
              .to.emit(voting, "WorkflowStatusChange")
              .withArgs(1, 2)
        })
    })

    describe("Voting session", function () {
        let c: any
        let v1: any
        let v2: any
        beforeEach(async function () {
            const { voting, voter1, voter2 } = await deployFixtureWithVoters()
            c = voting
            v1 = voter1
            v2 = voter2
        })

        it("Should emit event on start voting session", async () => {
            await c.startProposalsRegistering()
            await c.endProposalsRegistering()

            await expect(c.startVotingSession())
              .to.emit(c, "WorkflowStatusChange")
              .withArgs(2, 3)
        })

        it("Should set vote and update state", async function () {
            await c.startProposalsRegistering()
            await c.connect(v1).addProposal("A") // idx 1
            await c.endProposalsRegistering()

            await c.startVotingSession()
            await c.connect(v1).setVote(1)

            const v = await c.connect(v1).getVoter(v1.address)
            expect(v.hasVoted).to.equal(true)
            expect(v.votedProposalId).to.equal(1)
        })

        it("Should revert if proposal registration is not finished", async function () {
            await c.startProposalsRegistering()
            await c.connect(v1).addProposal("A")

            await expect(c.startVotingSession()).to.be.revertedWith("Registering proposals phase is not finished")
        })

        it("Should revert if already voted", async function () {
            await c.startProposalsRegistering()
            await c.connect(v1).addProposal("A")
            await c.connect(v2).addProposal("B")
            await c.endProposalsRegistering()

            await c.startVotingSession()
            await c.connect(v1).setVote(1)
            await expect(c.connect(v1).setVote(2)).to.be.revertedWith("You have already voted")
        })

        it("Should revert if proposal not found", async function () {
            await c.startProposalsRegistering()
            await c.connect(v1).addProposal("A")
            await c.endProposalsRegistering()

            await c.startVotingSession()
            await expect(c.connect(v1).setVote(2)).to.be.revertedWith("Proposal not found")

        })

        it("Should revert if voting session has not started", async function () {
            await c.startProposalsRegistering()
            await c.connect(v1).addProposal("A")

            await expect(c.connect(v1).setVote(1)).to.be.revertedWith("Voting session havent started yet")
        })

        it("Should emit event on addVoter", async function () {
            await c.startProposalsRegistering()
            await c.connect(v1).addProposal("A") // idx 1
            await c.endProposalsRegistering()

            await c.startVotingSession()

            await expect(await c.connect(v1).setVote(1)) // vote A
              .to.emit(c, "Voted")
              .withArgs(v1.address, 1)
        })

        it("Should emit event on end voting session", async () => {
            await c.startProposalsRegistering()
            await c.endProposalsRegistering()
            await c.startVotingSession()

            await expect(c.endVotingSession())
              .to.emit(c, "WorkflowStatusChange")
              .withArgs(3, 4)
        })
    })

    describe("Tally session", function () {
        let c: any
        let v1: any
        let v2: any
        let v3: any
        beforeEach(async function () {
            const { voting, voter1, voter2, voter3 } = await deployFixtureWithVoters()
            c = voting
            v1 = voter1
            v2 = voter2
            v3 = voter3
        })

        it("Should revert if wrong workflowStatus", async function () {
            await expect(c.tallyVotes()).to.be.revertedWith("Current status is not voting session ended")
        })

        it("Should get the proposal with the most votes", async function () {
            // Proposals phase
            await c.startProposalsRegistering()
            await c.connect(v1).addProposal("A") // idx 1
            await c.connect(v2).addProposal("B") // idx 2
            await c.endProposalsRegistering()

            // Voting phase
            await c.startVotingSession()
            await c.connect(v1).setVote(2) // vote B
            await c.connect(v2).setVote(2) // vote B
            await c.connect(v3).setVote(1) // vote A
            await c.endVotingSession()

            await c.tallyVotes()

            const winningId = await c.winningProposalID()
            expect(winningId).to.equal(2)
        })

        it("Should emit event on tallyVotes", async function () {
            // Proposals phase
            await c.startProposalsRegistering()
            await c.connect(v1).addProposal("A") // idx 1
            await c.endProposalsRegistering()

            // Voting phase
            await c.startVotingSession()
            await c.connect(v1).setVote(1) // vote A
            await c.endVotingSession()

            expect(await c.tallyVotes())
              .to.emit(c, "WorkflowStatusChange")
              .withArgs(4, 5)
        })

        it("Should keep the first proposal on tie", async function () {
            // Proposals phase
            await c.startProposalsRegistering()
            await c.connect(v1).addProposal("A") // idx 1
            await c.connect(v2).addProposal("B") // idx 2
            await c.endProposalsRegistering()

            // Voting phase
            await c.startVotingSession()
            await c.connect(v1).setVote(1) // P1
            await c.connect(v2).setVote(2) // P2
            await c.endVotingSession()

            await c.tallyVotes()

            const winningId = await c.winningProposalID()
            expect(winningId).to.equal(1)
        })

        it("Should winingProposalId on 0 when tallyVotes has not been triggered", async function () {
            await c.startProposalsRegistering()
            await c.connect(v1).addProposal("Only")
            await c.endProposalsRegistering()
            await c.startVotingSession()
            await c.connect(v1).setVote(1)
            await c.endVotingSession()

            const winningId = await c.winningProposalID()
            expect(winningId).to.equal(0)
        })
    })
})
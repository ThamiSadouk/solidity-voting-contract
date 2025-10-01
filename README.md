# Voting — Hardhat v2 Project

A simple end-to-end example of a workflow-driven voting smart contract with a thorough unit-style test suite (fixtures, events, revert reasons, and custom errors).

Try running some of the following tasks to run the tests:

```shell
npm install
npx hardhat compile
npx hardhat test
npx hardhat coverage
```

# Test coverage
  Voting
    Registering voters session
      ✔ Should add voter
      ✔ Should revert if not owner
      ✔ Should revert if already registered
      ✔ Should revert if voter registration is not opened
      ✔ Should reverts getVoter for non voter
      ✔ should emit event on addVoter
    Proposal session
      ✔ Should emit event on start proposal session
      ✔ Should reverts if called in wrong status
      ✔ Should add proposal
      ✔ Should revert if empty description
      ✔ Should revert if proposal phase is not opened
      ✔ Should revert getProposal for non voter
      ✔ Should get the correct number of a proposal votes 
      ✔ Should create "GENESIS" at index 0 on startProposalsRegistering
      ✔ Should emit event on addProposal
      ✔ Should reverts if startProposalsRegistering not triggered before endProposalsRegistering
      ✔ Should emit event on endProposalsRegistering
    Voting session
      ✔ Should emit event on start voting session
      ✔ Should set vote and update state
      ✔ Should revert if proposal registration is not finished
      ✔ Should revert if already voted
      ✔ Should revert if proposal not found
      ✔ Should revert if voting session has not started
      ✔ Should emit event on addVoter
      ✔ Should emit event on end voting session
    Tally session
      ✔ Should revert if wrong workflowStatus
      ✔ Should get the proposal with the most votes
      ✔ Should emit event on tallyVotes
      ✔ Should keep the first proposal on tie
      ✔ Should winingProposalId on 0 when tallyVotes has not been triggered


  30 passing (241ms)

-------------|----------|----------|----------|----------|----------------|
File         |  % Stmts | % Branch |  % Funcs |  % Lines |Uncovered Lines |
-------------|----------|----------|----------|----------|----------------|
 contracts/  |      100 |    83.33 |      100 |      100 |                |
  Voting.sol |      100 |    83.33 |      100 |      100 |                |
-------------|----------|----------|----------|----------|----------------|
All files    |      100 |    83.33 |      100 |      100 |                |
-------------|----------|----------|----------|----------|----------------|

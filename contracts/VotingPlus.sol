// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "./Voting.sol";

error WinnersAlreadyTallied();
error MissingWinners();

contract VotingPlus is Voting {
    mapping(address => bool) private isWinning;
    address[] private winners;

    // L'administrateur détermine les électeurs ayant remporté le vote
    function tallyWinningVoters() external onlyOwner {
        require(workflowStatus == WorkflowStatus.VotesTallied, WrongWorkflowStatus());
        require(winners.length == 0, WinnersAlreadyTallied());

        for (uint i = 0; i < winningProposals.length; i++) {
            address proposer = winningProposals[i].proposer;
            if (!isWinning[proposer]) {
                isWinning[proposer] = true;
                winners.push(proposer);
            }
        }
    }

    // Retourne le ou les gagnants du vote
    function getWinners() external view returns (address[] memory) {
        require(workflowStatus == WorkflowStatus.VotesTallied, WrongWorkflowStatus());
        require(winners.length > 0, MissingWinners());

        return winners;
    }

    // L'administrateur réinitialise les votes (pas les électeurs).
    function resetVotes () external onlyOwner {
        for (uint i = 0; i < registeredVoters.length; i++) {
            address voter = registeredVoters[i];
            voters[voter].hasVoted = false;
            voters[voter].votedProposalId = 0;
            proposalsPerVoter[voter] = 0;
            isWinning[voter] = false;
        }

        for (uint i = 0; i < proposals.length; i++) {
            bytes32 descriptionHash = keccak256(bytes(proposals[i].description));
            proposalExists[descriptionHash] = false;
        }

        delete proposals;
        delete winningProposals;
        delete winners;

        workflowStatus = WorkflowStatus.RegisteringVoters;
    }
}
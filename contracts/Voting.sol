// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

error Unauthorized();
error AlreadyRegistered();
error AlreadyVoted();
error MissingRegisteredVoters();
error MissingProposals();
error MissingVotes();
error WrongWorkflowStatus();
error ProposalAlreadyExists();
error MaxProposalsPerVoter(uint maxProposalsPerVoter);
error InvalidProposalId();
error VotesAlreadyTallied();

contract Voting is Ownable {
    
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    mapping (address => Voter) voters;
    address[] registeredVoters;

    struct Proposal {
        uint id;
        string description;
        uint voteCount;
        address proposer;
    }

    Proposal[] proposals;
    Proposal[] winningProposals;
    mapping (address => uint) proposalsPerVoter;
    mapping (bytes32 => bool) proposalExists;
    bool hasVoted;

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    WorkflowStatus workflowStatus;

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    constructor() Ownable(msg.sender){}

    // L'administrateur du vote enregistre un électeur identifié par son adresse Ethereum.
    function registerVoter(address _voter) external onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, WrongWorkflowStatus());
        require(!voters[_voter].isRegistered, AlreadyRegistered());

        voters[_voter].isRegistered = true;
        registeredVoters.push(_voter);

        emit VoterRegistered(_voter);
    }

    // L'administrateur du vote enregistre une liste d'électeurs par leur adresse Ethereum.
    function registerVotersInBulk(address[] calldata _voters) external onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, WrongWorkflowStatus());

        for (uint i = 0; i < _voters.length; i++) {
            address voter = _voters[i];
            require(!voters[voter].isRegistered, AlreadyRegistered());

            voters[voter].isRegistered = true;
            registeredVoters.push(voter);

            emit VoterRegistered(voter);
        }
    }

    // L'administrateur du vote démarre la session d'enregistrement des propositions.
    function startProposalSession() external onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, WrongWorkflowStatus());
        require(registeredVoters.length > 0, MissingRegisteredVoters());

        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, workflowStatus);
    }

    // Les électeurs inscrits sont autorisés à enregistrer jusqu'à 3 propositions pendant que la session d'enregistrement est active.
    function registerProposals(string memory _description) external {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, WrongWorkflowStatus());
        require(voters[msg.sender].isRegistered, Unauthorized());
        require(proposalsPerVoter[msg.sender] < 3, MaxProposalsPerVoter(3));

        bytes32 descriptionHash = keccak256(bytes(_description));
        require(!proposalExists[descriptionHash], ProposalAlreadyExists());

        proposals.push(Proposal({
            id: proposals.length,  
            description: _description,
            voteCount: 0,
            proposer: msg.sender
        }));

        proposalsPerVoter[msg.sender] += 1;
        proposalExists[descriptionHash] = true;

        emit ProposalRegistered(proposals.length - 1);
    }

    // L'administrateur termine la session d'enregistrement des propositions.
    function endProposalSession() external onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, WrongWorkflowStatus());
        require(proposals.length > 0, MissingProposals());

        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;

        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, workflowStatus);
    }

    // L'administrateur démarre la session de vote.
    function startVotingSession() external onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, WrongWorkflowStatus());

        workflowStatus = WorkflowStatus.VotingSessionStarted;

        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, workflowStatus);
    }

    // tout le monde peut voir la liste des électeurs inscrits
    function getVoters() external view returns (address[] memory) {
        return registeredVoters;
    }

    // Les électeurs inscripts peuvent voir la liste des propositions.
    function getProposals() external view returns (Proposal[] memory) {
        require(voters[msg.sender].isRegistered, Unauthorized());

        return proposals;
    }

    // Les électeurs inscrits votent pour leur proposition préférée.
    function vote(uint _proposalId) external {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, WrongWorkflowStatus());
        require(voters[msg.sender].isRegistered, Unauthorized());
        require(!voters[msg.sender].hasVoted, AlreadyVoted());
        require(_proposalId < proposals.length, InvalidProposalId());

        voters[msg.sender].hasVoted = true;

        proposals[_proposalId].voteCount += 1;
        voters[msg.sender].votedProposalId = _proposalId;
        hasVoted = true;

        emit Voted(msg.sender, _proposalId);
    }

    // L'administrateur termine la session de vote.
    function endVotingSession() external onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, WrongWorkflowStatus());
        require(hasVoted, MissingVotes());

        workflowStatus = WorkflowStatus.VotingSessionEnded;

        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, workflowStatus);
    }

    // L'administrateur comptabilise les votes.
    function tallyVotes() external onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, WrongWorkflowStatus());
        require(winningProposals.length == 0, VotesAlreadyTallied());

        uint highestVoteCount = 0;

        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > highestVoteCount) {
                highestVoteCount = proposals[i].voteCount;
            }
        }

        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount == highestVoteCount) {
                winningProposals.push(proposals[i]);
            }
        }

        workflowStatus = WorkflowStatus.VotesTallied;

        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, workflowStatus);
    }

    // Tout le monde peut vérifier les derniers détails de la ou les propositions gagnantes.
    function getWinningProposal() external view returns (Proposal[] memory) {
        require(workflowStatus == WorkflowStatus.VotesTallied, WrongWorkflowStatus());

        return winningProposals;
    }
}
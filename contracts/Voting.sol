// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Voting smart contract
/// @notice Minimal voting system with gated phases: voter registration, proposal submission, voting, and tallying.
/// @dev Implements a structure voting workflow
contract Voting is Ownable {
    uint public winningProposalID;

    uint public constant MAX_VOTERS = 10;
    uint public constant MAX_PROPOSALS_PER_VOTER = 3;
    uint public constant MAX_DESC = 200;

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    enum  WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    WorkflowStatus public workflowStatus;
    uint256 public registeredVoters;
    mapping(address => uint256) public proposalsByVoter;
    Proposal[] proposalsArray;
    mapping (address => Voter) voters;
    address[] private votersArray;

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    constructor() Ownable(msg.sender) {    }

    modifier onlyVoters() {
        require(voters[msg.sender].isRegistered, "You're not a voter");
        _;
    }

    // ::::::::::::: GETTERS ::::::::::::: //

    /// @notice Get voter information.
    /// @dev Callable only by registered voters.
    /// @param _addr Address of the voter to query.
    /// @return Voter struct for the given address.
    function getVoter(address _addr) external onlyVoters view returns (Voter memory) {
        return voters[_addr];
    }

    /// @notice Get a proposal by ID.
    /// @dev Callable only by registered voters.
    /// @param _id Proposal ID (index in `proposalsArray`).
    /// @return Proposal struct for the given ID.
    function getOneProposal(uint _id) external onlyVoters view returns (Proposal memory) {
        // Retourne la proposition à l'index spécifié
        return proposalsArray[_id];
    }

    // ::::::::::::: REGISTRATION ::::::::::::: // 

    /// @notice Register a voter.
    /// @dev Only owner. Allowed only during `RegisteringVoters`.
    /// @param _addr Address to register.
    function addVoter(address _addr) external onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Voters registration is not open yet");
        require(voters[_addr].isRegistered != true, "Already registered");
        require(registeredVoters < MAX_VOTERS, "voters cap reached");

        voters[_addr].isRegistered = true;
        registeredVoters += 1;

        votersArray.push(_addr);

        emit VoterRegistered(_addr);
    }

    // ::::::::::::: PROPOSAL ::::::::::::: // 

    /// @notice Submit a proposal.
    /// @dev Only registered voters and only during `ProposalsRegistrationStarted`.
    /// @param _desc Short description; must be non-empty.
    function addProposal(string calldata _desc) external onlyVoters {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals are not allowed yet");
        require(proposalsByVoter[msg.sender] < MAX_PROPOSALS_PER_VOTER, "You can't propose more than 3 propositions");
        uint len = bytes(_desc).length;
        require(len != 0, "Proposal can't be empty");
        require(len <= MAX_DESC, "max desc is 200");

        proposalsByVoter[msg.sender] += 1;
        Proposal memory proposal;
        proposal.description = _desc;
        proposalsArray.push(proposal);

        emit ProposalRegistered(proposalsArray.length - 1);
    }

    // ::::::::::::: VOTE ::::::::::::: //

    /// @notice Cast a vote for a proposal.
    /// @dev Only registered voters and only during `VotingSessionStarted`.
    /// @param _id Proposal ID to vote for.
    function setVote(uint _id) external onlyVoters {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting session havent started yet");
        require(voters[msg.sender].hasVoted != true, "You have already voted");
        require(_id < proposalsArray.length, "Proposal not found");

        voters[msg.sender].votedProposalId = _id;
        voters[msg.sender].hasVoted = true;
        proposalsArray[_id].voteCount++;

        emit Voted(msg.sender, _id);
    }

    // ::::::::::::: STATE ::::::::::::: //

    /// @notice Open the proposals registration phase and create the `GENESIS` proposal at index 0.
    /// @dev Only owner. Allowed only from `RegisteringVoters`.
    function startProposalsRegistering() external onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Registering proposals cant be started now");
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;

        Proposal memory proposal;
        proposal.description = "GENESIS";
        proposalsArray.push(proposal);

        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    /// @notice Close the proposals registration phase.
    /// @dev Only owner. Allowed only from `ProposalsRegistrationStarted`.
    function endProposalsRegistering() external onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Registering proposals havent started yet");
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    /// @notice Open the voting session.
    /// @dev Only owner. Allowed only from `ProposalsRegistrationEnded`.
    function startVotingSession() external onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Registering proposals phase is not finished");
        workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    /// @notice Close the voting session.
    /// @dev Only owner. Allowed only from `VotingSessionStarted`.
    function endVotingSession() external onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting session havent started yet");
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    /// @notice Tally votes and set the winning proposal ID.
    /// @dev Only owner. Allowed only from `VotingSessionEnded`. Picks the first index that achieves the max (stable tie-break).
    function tallyVotes() external onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, "Current status is not voting session ended");

        uint _winningProposalId;
        for (uint256 p = 0; p < proposalsArray.length; p++) {
            if (proposalsArray[p].voteCount > proposalsArray[_winningProposalId].voteCount) {
                _winningProposalId = p;
            }
        }

        winningProposalID = _winningProposalId;
        workflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }

    /// @notice Réinitialize until the proposal registery session (not the voters)
    function startNewRound() external onlyOwner {
        require(workflowStatus == WorkflowStatus.VotesTallied, "finish first");

        for (uint i = 0; i < votersArray.length; i++) {
            address a = votersArray[i];
            voters[a].hasVoted = false;
            voters[a].votedProposalId = 0;
            proposalsByVoter[a] = 0;
        }

        delete winningProposalID;
        delete proposalsArray;

        // init proposition GENESIS for new round
        proposalsArray.push(Proposal({ description: "GENESIS", voteCount: 0 }));

        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.VotesTallied, WorkflowStatus.ProposalsRegistrationStarted);
    }
}
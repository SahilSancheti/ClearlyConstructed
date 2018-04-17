pragma solidity ^0.4.15;
contract Voting {
    
    uint public constant COST_PER_PROPOSAL = 0.1 ether;
    
    struct Voter {
        // Match each proposal i with 
        // True: if this voter has already voted for proposal[i] 
        // False: if this voter hasn't voted for proposal[i]
        mapping(uint16 => bool) votedProposals; 
        uint stakedBalance; // The balance of ether the contract is holding of the voter
    }

    struct Proposal {
        string content;
        uint voteFor;
        uint voteAgainst;
        uint blockNumber;
        bool canceled;
        address proposer;
    }

    // Events
    event VoteFor(string _content, address _voter);
    event VoteAgainst(string _content, address _voter);
    event ProposalAdded(string _content, address _proposer);
    event ProposalCanceled(string _content, address _proposer);
    event Refund(address _proposer, uint _value);
    
    // Local variables
    uint8 totalProposals;
    bool ended;
    mapping(address => Voter) voters;
    Proposal[] proposals;


    // The constructor of the contract. 
    // It is called exactly once and cannot be called again.

    function Voting() public {
        totalProposals = 0;
        ended = false;
    }
    
    // Check if the Vote event is still running
    modifier notEnded() {
        require(!ended);
        _;
    }
    
    // Check the value of ether sent to the contract, 
    // if it's larger than needed, refund the excess value back to sender
    modifier checkValue() {
        uint amountToRefund = msg.value - COST_PER_PROPOSAL;
        if (amountToRefund > 0) {
            if (!msg.sender.send(amountToRefund)) {
                revert();
            }
        }
        require(amountToRefund >= 0);
        _;
    }
    
    // Added a new proposal
    function addNewProposal(string newProposal) payable notEnded checkValue public {
        proposals.push(Proposal({
            content: newProposal,
            voteFor: 0,
            voteAgainst: 0,
            proposer: msg.sender,
            blockNumber: block.number,
            canceled: false
        }));
        totalProposals = totalProposals + 1;
        Voter storage sender = voters[msg.sender];
        sender.stakedBalance += COST_PER_PROPOSAL;
        ProposalAdded(newProposal, msg.sender);
    }


    /// Give a single vote to proposal $proposalIndex.
    function voteFor(uint8 proposalIndex) notEnded public {
        assert(proposalIndex >= 0 && proposalIndex < totalProposals && proposals[proposalIndex].canceled == false);
        Voter storage sender = voters[msg.sender];
        if (sender.votedProposals[proposalIndex] == true)
            revert();
        sender.votedProposals[proposalIndex] = true;
        proposals[proposalIndex].voteFor += msg.sender.balance;
        VoteFor(proposals[proposalIndex].content, msg.sender);
    }

    function voteAgainst(uint8 proposalIndex) notEnded public {
        assert(proposalIndex >= 0 && proposalIndex < totalProposals && proposals[proposalIndex].canceled == false);
        Voter storage sender = voters[msg.sender];
        if (sender.votedProposals[proposalIndex] == true)
            revert();
        sender.votedProposals[proposalIndex] = true;
        proposals[proposalIndex].voteAgainst += msg.sender.balance;
        VoteAgainst(proposals[proposalIndex].content, msg.sender);
    }

    // Get the number of Votes the proposal $proposalIndex received.
    // Return an array r[] where r[0] is # of vote for, r[1] is # of vote against
    function getVote(uint8 proposalIndex) public constant returns (uint[2] memory r) {
        assert(proposalIndex >= 0 && proposalIndex < totalProposals);
        r = [proposals[proposalIndex].voteFor, proposals[proposalIndex].voteAgainst];
    }
    
    function numberOfProposals() public constant returns (uint8) {
        return totalProposals;
    }
    
    // Get all information about the proposal $proposalIndex
    function getProposal(uint8 proposalIndex) public constant returns (string, uint, uint, address, uint) {
        assert(proposalIndex >= 0 && proposalIndex < totalProposals);
        Proposal storage p = proposals[proposalIndex];
        return (p.content, p.voteFor, p.voteAgainst, p.proposer, p.blockNumber);
    }
    
    // Cancel the proposal and receive the refunded staked ETH 
    function cancelProposal(uint8 proposalIndex) public {
        assert(proposalIndex >= 0 && proposalIndex < totalProposals && !proposals[proposalIndex].canceled && proposals[proposalIndex].proposer == msg.sender);
        proposals[proposalIndex].canceled = true;
        refund(COST_PER_PROPOSAL);
        ProposalCanceled(proposals[proposalIndex].content, msg.sender);
    }
    
    // Refund the amount of Ether the proposer staked in when proposed
    function refund(uint withdrawAmount) private returns (uint remainingBal) {
        Voter storage sender = voters[msg.sender];
        if (sender.stakedBalance >= withdrawAmount) {
            // Make sure to deduct the amount before calling send to prevent reentrancy.
            sender.stakedBalance -= withdrawAmount;
            if (!msg.sender.send(withdrawAmount)) {
                sender.stakedBalance += withdrawAmount;
            }
        }
        Refund(msg.sender, withdrawAmount);
        return sender.stakedBalance;
    }

    // Get the winning proposal (proposal with highest voteFor - voteAgainst)
    function winningProposal() public constant returns (uint8 _winningProposal) {
        uint256 winningVoteCount = 0;
        for (uint8 prop = 0; prop < totalProposals; prop++) {
            uint256 voteDiff = proposals[prop].voteFor - proposals[prop].voteAgainst;
            if (voteDiff > winningVoteCount) {
                winningVoteCount = voteDiff;
                _winningProposal = prop;
            }
        }
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Module 2 Project
/// @notice This contract provide interactions with auction functionalities
contract Auction {

    // define auction states
    enum States {Started, InProgress, Finished, Canceled}

    // define struct for bidding
    struct Bid {
        uint amount;
        bool isActive;
    }

    struct Article {
        string name;
        uint baseAmount;
    }

    // define owner contract
    address public owner; 

    // define address mapping for bidding
    mapping(address => Bid) public bids;
    mapping(address => Bid[]) public historyBids;
    mapping(address => uint) public pendingBids;
    address[] public bidders;

    // define article
    Article public article;
    // define article
    Bid public highestBid; 
    // define state
    States public state;
    // define auction open for bidding
    bool isOpen;
    // define has refund
    bool hasRefund;
    // define highest Bidder
    address highestBidder;
    // define bid count
    uint bidCount;
    // define minimum bidders
    uint public minimumBidders;
    // define start time 
    uint public startTime;
    // define end time 
    uint public endTime;
    // define extra minutes
    uint public extraTime;
    // define commission balance 
    uint public commissionBalance;

    // define events
    event NewBid(address indexed bidder, uint amount);
    event Refunded(address indexed bidder, uint amount);
    event CommissionWithdrawn(uint amount);
    event AuctionStarted(uint endTime, uint minimumBidders);
    event AuctionFinished(address winner, uint amount);
    event AuctionExtended(uint newEndTime);
    event AuctionCanceled();

    // declare auction constructor 
    constructor() {
        owner = msg.sender;
        isOpen = false;
        hasRefund = false;
        article = Article ({
            name: "",
            baseAmount: 0 ether
        });
        highestBid = Bid({
            amount: 0 ether,
            isActive: false
        });
    }
    
    modifier onlyOwner {
        require(msg.sender == owner, "Only Owner can perform this transaction");
        _;
    }

    modifier validArticleInput(string memory _name, uint _baseAmount) {
        require(!isOpen, "Operation not allowed during auction");
        require(bytes(_name).length > 0, "Article name cannot be empty");
        require(_baseAmount > 0, "Base amount must be greater than 0");
        _;
    }

    modifier onlyOpenAuction {
        require(isOpen, "Auction was not started");
        _;
    }

    function addArticle(string memory _name, uint _baseAmount) external onlyOwner validArticleInput(_name, _baseAmount) {
        require(bytes(article.name).length == 0, "Auction article is already added");
        
        article = Article ({
            name: _name,
            baseAmount: _baseAmount
        });
    }

    function setArticle(string memory _name, uint _baseAmount) external onlyOwner validArticleInput(_name, _baseAmount) {
        require(bytes(article.name).length > 0, "Auction article was not added");
        
        article = Article ({
            name: _name,
            baseAmount: _baseAmount
        });
    }

    function startAuction(uint _minumumBidders, uint _endTime, uint _extraTime) external onlyOwner {
        require(!isOpen, "Auction is already started");
        require(bytes(article.name).length > 0, "Not inserted article for started Auction");
        require(_endTime >= 15, "The duration of auction must be equal or greater than 15 minutes");
        require(_extraTime >= 5, "The extra time of auction must be equal or greater than 5 minutes");
        require(_minumumBidders > 0, "The minimum bidders of auction must be greater than 0");
        
        isOpen = true;
        hasRefund = false;
        state = States.Started;
        minimumBidders = _minumumBidders;
        startTime = block.timestamp;
        endTime = block.timestamp + (_endTime * 1 minutes);
        extraTime = _extraTime * 1 minutes;

        emit AuctionStarted(endTime, minimumBidders);
    }

    function finishAuction() external onlyOwner onlyOpenAuction {
        require(block.timestamp >= endTime, "Auction is still ongoing");
        require(bidCount >= minimumBidders, "Not enough bidders to close the auction");

        isOpen = false;
        state = States.Finished;
        startTime = 0;
        endTime = 0;
        extraTime = 0;
        article = Article ({
            name: "",
            baseAmount: 0 ether
        });

        emit AuctionFinished(highestBidder, highestBid.amount);

        highestBid = Bid({
            amount: 0 ether,
            isActive: false
        });
    }

    function cancelAuction() external onlyOwner onlyOpenAuction {
        require(block.timestamp < endTime, "Auction must be finished");
        require(bidCount < minimumBidders, "The auction cannot be canceled there are bidders");

        isOpen = false;
        state = States.Canceled;
        startTime = 0;
        endTime = 0;
        extraTime = 0;
        article = Article ({
            name: "",
            baseAmount: 0 ether
        });
        highestBid = Bid({
            amount: 0 ether,
            isActive: false
        });

        emit AuctionCanceled();
    }

    function addAuctionEndTime(uint _extraEndTime) external onlyOwner onlyOpenAuction {
        require(_extraEndTime >= 10, "The extra time for auction end time must be equal or greater than 10 minutes");
        endTime = endTime + (_extraEndTime * 1 minutes); 
    }

    function getRemainingAuctionTime() external onlyOpenAuction view returns (uint) {
        uint currentTime = block.timestamp;
        if (endTime > currentTime) {
            return endTime - currentTime;
        }

        return 0;
    }

    function bid() external payable onlyOpenAuction {
        require(msg.sender != highestBidder, "You're already the highest bidder");
        require(msg.value > 0, "Value Must be greater than 0");

        uint current = highestBid.amount > 0 ? highestBid.amount : article.baseAmount;
        uint minValid = current + (current * 5) / 100;
        require(msg.value >= minValid, "Bid must be greater than current highest bid by 5%");

        if (bids[msg.sender].isActive) {
            historyBids[msg.sender].push(bids[msg.sender]);
            pendingBids[msg.sender] += bids[msg.sender].amount;
        }

        if (bids[msg.sender].amount == 0) {
            bidders.push(msg.sender);
        }

        if (msg.sender != highestBidder && highestBidder != address(0)) {
            historyBids[highestBidder].push(highestBid);
            pendingBids[highestBidder] += highestBid.amount;
        }

        bids[msg.sender] = Bid(msg.value, true);
        highestBid = bids[msg.sender];
        highestBidder = msg.sender;
        bidCount++;

        if (state == States.Started) {
            state = States.InProgress;
        }

        if (endTime > block.timestamp && endTime - block.timestamp <= 10 minutes) {
           endTime += extraTime;
           emit AuctionExtended(endTime); 
        }

        emit NewBid(msg.sender, msg.value);
    }

    function withdrawExcess() external {
        uint amount = pendingBids[msg.sender];
        require(amount > 0, "Nothing pending bids");

        pendingBids[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    function refundNoWinners() external onlyOwner {
        require(state == States.Finished || state == States.Canceled, "Auction must be finished or canceled");
        require(!hasRefund, "Refunds already processed");

        hasRefund = true;

        for (uint i = 0; i < bidders.length; i++) {
            address bidder = bidders[i];
            if (bidder == highestBidder) continue;

            Bid memory aux = bids[bidder];

            if (aux.amount > 0 && aux.isActive) {
                uint commission = (aux.amount * 2) / 100;
                uint refund = aux.amount - commission;

                bids[bidder].amount = 0;
                bids[bidder].isActive = false;
                commissionBalance += commission;

                (bool success, ) = payable(bidder).call{value: refund}("");
                require(success, "Refund failed");

                emit Refunded(bidder, refund);
            }
        }
    } 

    function withdrawCommission() external onlyOwner {
        require(commissionBalance > 0, "No commission");
        uint amount = commissionBalance;
        commissionBalance = 0;
    
        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Commission withdrawal failed");

        emit CommissionWithdrawn(amount);
    }

    function getBidCount(address user) external view returns (uint) {
        return historyBids[user].length;
    }

    function getHighestBidder() external view returns (address winner, uint amount) {
        require(state == States.Finished, "Auction must be finished or canceled");
        return (highestBidder, highestBid.amount);
    }

    function getBidders() external view returns (address[] memory, uint[] memory) {
        uint length = bidders.length;
        address[] memory bidderAddresses = new address[](length);
        uint[] memory bidderAmounts = new uint[](length);

        for (uint i = 0; i < length; i++) {
            address bidder = bidders[i];
            bidderAddresses[i] = bidder;
            bidderAmounts[i] = bids[bidder].amount;
        }

        return (bidderAddresses, bidderAmounts);
    }
}
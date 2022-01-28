// SPDX-License-Identifier: GPL-3.0
pragma solidity >0.7.0 <=0.9.0;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint256 value);
    event Submit(uint256 txId);
    event Approve(address indexed owner, uint256 indexed txId);
    event Revoke(address indexed owner, uint256 indexed txId);
    event Execute(uint256 indexed txId);
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public approved;

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public requiredOwners;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Only Owners are allowed ");
        _;
    }

    modifier txExists(uint256 _txId) {
        require(_txId < transactions.length, "Valid Transaction id");
        _;
    }

    modifier notApproved(uint256 _txId) {
        require(!approved[_txId][msg.sender], "Owner already approved");
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(!transactions[_txId].executed, "Transactions already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredOwners) {
        require(_owners.length > 0, "Enter valid number of owners");
        require(
            _requiredOwners > 0 && _requiredOwners <= _owners.length,
            "Enter valid required owners"
        );
        for (uint256 i; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid Address ");
            require(!isOwner[owner], " Owner Already Exists ");
            owners.push(owner);
            isOwner[owner] = true;
        }
        requiredOwners = _requiredOwners;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submit(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwner {
        transactions.push(
            Transaction({to: _to, value: _value, data: _data, executed: false})
        );
        emit Submit(transactions.length - 1);
    }

    function approve(uint256 _txId)
        external
        onlyOwner
        txExists(_txId)
        notApproved(_txId)
        notExecuted(_txId)
    {
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    function _getApprovalCount(uint256 _txId)
        private
        view
        returns (uint256 count)
    {
        for (uint256 i; i < owners.length; i++) {
            if (approved[_txId][owners[i]]) {
                count++;
            }
        }
    }

    function revoke(uint256 _txId)
        external
        onlyOwner
        txExists(_txId)
        notExecuted(_txId)
    {
        require(!approved[_txId][msg.sender], "Transaction not approved");
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }

    function execute(uint256 _txId)
        external
        onlyOwner
        txExists(_txId)
        notExecuted(_txId)
    {
        require(
            _getApprovalCount(_txId) >= requiredOwners,
            "Transaction not approved "
        );
        Transaction storage transaction = transactions[_txId];
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "Transaction not executed");
        emit Execute(_txId);
    }
}

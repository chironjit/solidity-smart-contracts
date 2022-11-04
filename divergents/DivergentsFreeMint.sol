// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";




contract Divergents {
    function totalSupply() public view returns (uint256) {}

    function saleMint (uint[10] calldata mintList) public payable {}

    function charactersRemaining() public view returns (uint16[10] memory) {}

    function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public {
    safeTransferFrom(from, to, tokenId);
  }

}


contract DivergentsFreeMint is ERC721Holder, Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    address public divergentContractAddress;
    
    
    mapping(address => bool) public approvedTeamMinters; // Approved Minters
    
    uint public mainContractPrice = 100000000 gwei;
    uint public paymentGasLimit = 5000;

    function setMainContractPrice (uint _mainContractPriceInWei) external onlyOwner {
        mainContractPrice = _mainContractPriceInWei;
    }


    // Add address to approved team minters
    function addToApprovedTeamMinters(address[] memory _add) external onlyOwner {
        for (uint i = 0; i < _add.length; i++) {
            approvedTeamMinters[_add[i]] = true;
        }
    }

    // Set divergents contract address
    function setDivergentContractAddress(address _contractAddress) external onlyOwner {
        divergentContractAddress = _contractAddress;
    }

    // Fund this contract to make calls to the divergent contract
    function fundContract() external payable {}

    // Receive funds into the wallet
    receive() external payable { }

    // Get balance held in this contract
    function getBalance() external view returns (uint) {
        return address(this).balance / 1 ether;
    }

    // Withdraw specific amount from the balance held in this contract
    function withdrawBalance(uint _amount, address _recipient) external onlyOwner nonReentrant {
        require(_amount <= address(this).balance, "Withdrawal amount more than balance in contract");
        _recipient.call{ value:_amount, gas: 5000 }("");
    }

    // Helper functions

    // Standalone function to get characters remaining
    function charactersRemaining() public view returns (uint16[10] memory divergentCharacters) {
        Divergents divergent = Divergents(divergentContractAddress);
        return divergent.charactersRemaining();
    }

    // Standalone function to get totalSupply
    function totalSupply() public view returns (uint totalRemaining) {
        Divergents divergent = Divergents(divergentContractAddress);
        return divergent.totalSupply();
    }

    // Sum of arrays
    function _sumOfArray (uint[10] memory array) internal pure returns (uint sum) { 
        for(uint i = 0; i < array.length; i++) {
            sum = sum + array[i];
        }
    }

    

    // Standalone transfer function any token held by the contract to another recipient 
    function _transferToken(uint _tokenID, address _recipient) internal {
        Divergents divergent = Divergents(divergentContractAddress);
        divergent.safeTransferFrom(address(this), _recipient, _tokenID);
    }

    // Mint call function to be used
    function _mintCall(uint[10] memory _mintList, address _recipient) internal {
        Divergents divergent = Divergents(divergentContractAddress);
        uint _originalTotalMinted = divergent.totalSupply();

        uint _totalBeingMinted = _sumOfArray(_mintList);
        uint _priceToPay =  mainContractPrice * _totalBeingMinted;

        divergent.saleMint{value: _priceToPay}(_mintList);

        uint _newTotalMinted = divergent.totalSupply();

        for (uint m = _originalTotalMinted; m < _newTotalMinted; m++) {
            divergent.safeTransferFrom(address(this), _recipient, m);
        }

    }

    // Safety hatch to withdraw any NFTs stuck in this contract
    function transferUntransferredToken(uint[] calldata _tokenIDs, address _recipient) external {
        require(approvedTeamMinters[msg.sender], "Minter not approved");
        for (uint i; i < _tokenIDs.length; i++) {
            _transferToken (_tokenIDs[i], _recipient);
        }
    }

    mapping(address => uint) public freeMintsReceivedByAddress;
    address private _backendSigner;

    function setBackendSigner(address backendSigner) public onlyOwner {
        _backendSigner = backendSigner;
    }

    function getBackendSigner() public view returns (address) {
        return _backendSigner;
    }

    function getFreeMintsReceivedByAddress(address _recipient) public view returns (uint) {
        return freeMintsReceivedByAddress[_recipient];
    }

    function freeMint(
        bytes32 message,
        bytes32 messageHash,
        bytes memory signature,
        uint _allowedToMint,
        uint[10] calldata _mintList)
        public {
            // calculate signer address and check if it is equal to _backendSigner
            address signer = messageHash.recover(signature);
            require(signer == _backendSigner, "Content not signed by Divergents");

            bytes32 computedHash = keccak256(abi.encodePacked(_allowedToMint, msg.sender));
            require(computedHash == message, "Message hash does not match");

            uint _currentDivergentsMinted = totalSupply();

            uint _totalRequested = _sumOfArray(_mintList);
            uint _alreadyReceived = freeMintsReceivedByAddress[msg.sender];
            require (_totalRequested <= _allowedToMint - _alreadyReceived, "Requested amount more than allowed to mint");

            if(_totalRequested <= 10) {
                _mintCall (_mintList, msg.sender);  
            } else {
                for (uint m; m < 10; m++) {
                    uint[10] memory _mintItems;
                    _mintItems[m] = _mintList[m];
                    _mintCall(_mintItems, msg.sender);
                }
            }

            uint _newDivergentsMinted = totalSupply() - _currentDivergentsMinted;

            freeMintsReceivedByAddress[msg.sender] = freeMintsReceivedByAddress[msg.sender] + _newDivergentsMinted;

        }
}

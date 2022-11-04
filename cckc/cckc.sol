pragma solidity ^0.8.4;

import './ERC721AQueryable.sol';
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CoolKidsClub is ERC721AQueryable, Ownable, ReentrancyGuard {
    // metadata URI
    string private _baseTokenURI;
    string private _contractMetadataURI;

    // payable wallet addresses
    address payable private _artistAddress;
    address payable private _devAddress;

    // Other minting variables
    bool public isPublicSaleOpen;
    uint public discountedMints = 19;
    uint public mintPrice = 79000000 gwei;
    uint private constant PAYMENT_GAS_LIMIT = 5000;


    constructor(string memory name_,
        string memory symbol_,
        address payable artistAddress_,
        address payable devAddress_) 
        ERC721A(name_, symbol_) {
            _baseTokenURI = "https://test.me/"; // to set prior to deployment
            _contractMetadataURI = "ipfs://contractmetadata"; // to set prior to deployment
            isPublicSaleOpen = false;
            _artistAddress = artistAddress_; // to set prior to deployment
            _devAddress = devAddress_; // to set prior to deployment
        }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata uri_) external onlyOwner {
        _baseTokenURI = uri_;
    }

    function contractURI() public view returns (string memory) {
        return _contractMetadataURI;
    }

    function setContractMetadataURI(string memory contractMetadataURI_) external onlyOwner {
        _contractMetadataURI = contractMetadataURI_;
    }

    function setIsPublicSaleOpen(bool locked) external onlyOwner {
        isPublicSaleOpen = locked;
    }

    function setPayableAddresses(address payable artistAddress, address payable devAddress) external onlyOwner {
        _artistAddress = artistAddress;
        _devAddress = devAddress;
    }

    function setMintPrice (uint mintPriceInWei) external onlyOwner {
        mintPrice = mintPriceInWei;
    }

    // Calculate amount that needs to be paid
    function totalPaymentRequired (uint amountMinted) internal returns (uint) {
        uint discountedMintsRemaining = discountedMints;
        uint totalPrice;
        
        if(discountedMintsRemaining == 0) {
            totalPrice = amountMinted * mintPrice;
        } else if (discountedMintsRemaining >= amountMinted) { 
            totalPrice = 0;
            discountedMints = discountedMintsRemaining - amountMinted; 
        } else {
            totalPrice = ((amountMinted-discountedMintsRemaining) * mintPrice);
            discountedMints = 0;
        }

        return totalPrice;
    }

    // Public Sale mint
    function saleMint (uint qty) public payable nonReentrant {
        require(isPublicSaleOpen, "Public sale not open");

        require(msg.value >= qty * mintPrice, "Insufficient payment");

        require(qty <= 10, "Max purchase limit");

        require(totalSupply() <= 10000, "Sold Out");


        // Calculate how much to charge
        uint paymentRequired = totalPaymentRequired(qty);

        _safeMint(msg.sender, qty); // Only after all calculations

        // Pay
        // calculate amounts to transfer
        uint devAmount = (paymentRequired / 10000) * 2000;
        uint artistAmount = paymentRequired - devAmount;
        
        // transfer amounts to dev wallet
        (bool devSuccess, ) = _devAddress.call{ value:devAmount, gas: PAYMENT_GAS_LIMIT }("");
        require(devSuccess, "Dev payment failed");
        
        // transfer amounts to artist wallet
        (bool artistSuccess, ) = _artistAddress.call{ value:artistAmount, gas: PAYMENT_GAS_LIMIT }("");
        require(artistSuccess, "Artist payment failed");

        // Return any overpaid sum
        if (msg.value - paymentRequired > 0) {
            uint returnValue = msg.value - paymentRequired;
            (bool returnSuccess, ) = msg.sender.call{ value:returnValue, gas: PAYMENT_GAS_LIMIT }("");
            require(returnSuccess, "Return payment failed");
        }

    }


}
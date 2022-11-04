// SPDX-License-Identifier: GPL-3.0

// WAGMI

pragma solidity ^0.8.4;

import "./ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Divergents is ERC721A, Ownable, ReentrancyGuard {


    // metadata URI
    string private _baseTokenURI;
    string private _contractMetadataURI;

    //Tracked Variables
    bool public isPublicSaleOpen;
    bool public isWhitelistSaleOpen;

    // Approved Minters
    mapping(address => bool) public approvedTeamMinters;
    // mapping(address => uint) public approvedGuruMinters;

    // Whitelist Merkle
    bytes32 public merkleRoot;

    // payable wallet addresses
    address payable private _divergentsAddress;
    address payable private _devAddress;

    uint public discountedMints = 100;
    uint public discountedMintPrice = 80000000 gwei;
    uint public mintPrice = 100000000 gwei;
    uint private constant PAYMENT_GAS_LIMIT = 5000;
    uint private constant MAX_MINT = 2000; // Maximum that can be minted for sale (not including Guru mints)
    uint public constant MAX_PER_ORDER_SALE_MINT = 10;
    uint public constant MAX_PER_WALLET_WHITELIST_MINT = 3;
    mapping (address => uint) public totalMintedByAddress;
    uint public maxSupplyInSaleWave = 500;



    // Getter Functions
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function getOwnershipData(uint256 tokenId) public view returns (TokenOwnership memory) {
        return ownershipOf(tokenId);
    }

    function contractURI() public view returns (string memory) {
        return _contractMetadataURI;
    }

    function charactersRemaining() public view returns (uint16[10] memory) {
        return divergentCharacters;
    }



    // Setter functions (all must be onlyowner)

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function setContractMetadataURI(string memory contractMetadataURI) external onlyOwner {
        _contractMetadataURI = contractMetadataURI;
    }

    function setOwnersExplicit(uint256 quantity) external onlyOwner {
        _setOwnersExplicit(quantity);
    }

    function setIsPublicSaleOpen(bool locked) external onlyOwner {
        isPublicSaleOpen = locked;
    }

    function setIsWhitelistSaleOpen(bool locked) external onlyOwner {
        isWhitelistSaleOpen = locked;
    }

    function addToApprovedTeamMinters(address[] memory add) external onlyOwner {
        for (uint i = 0; i < add.length; i++) {
            approvedTeamMinters[add[i]] = true;
        }
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setPayableAddresses(address payable divergentsAddress, address payable devAddress) external onlyOwner {
        _divergentsAddress = divergentsAddress;
        _devAddress = devAddress;
    }

    function setMintPrice (uint mintPriceInWei) external onlyOwner {
        mintPrice = mintPriceInWei;
    }

    function setDiscountedMintPrice (uint discMintPriceInWei) external onlyOwner {
        discountedMintPrice = discMintPriceInWei;
    }

    function setMaxSupplyInSaleWave (uint increaseWave) external onlyOwner {
        maxSupplyInSaleWave = increaseWave;
    }



    //Constructor
    constructor() ERC721A("TheDivergents", "DVRG", 25, 2022) {
        _baseTokenURI = "https://api.thedivergents.io/";
        _contractMetadataURI = "ipfs://QmUmQW3n8k79dEd4Wtjx1ujjdx1WB2dcoifnCDyu8v21hh";

    }



    // Characters Tracker
    uint16[10] public divergentCharacters = [200,200,200,200,200,200,200,200,200,200];
    uint public divergentGuru = 22;
    uint private reservedMint = 200;


    // Helper functions
    // Sum of arrays
    function sumOfArray (uint[10] memory array) internal pure returns (uint sum) { 
        for(uint i = 0; i < array.length; i++) {
            sum = sum + array[i];
        }
    }

    // Generate Merkle Leaf (to verify whitelisted address)
    function generateMerkleLeaf (address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    // Calculate amount that needs to be paid
    function totalPaymentRequired (uint amountMinted) internal returns (uint) {
        uint discountedMintsRemaining = discountedMints;
        uint totalPrice;
        
        if(discountedMintsRemaining == 0) {
            totalPrice = amountMinted * mintPrice;
        } else if (discountedMintsRemaining >= amountMinted) { 
            totalPrice = amountMinted * discountedMintPrice;
            discountedMintsRemaining -= amountMinted; 
        } else {
            totalPrice = (discountedMintsRemaining * discountedMintPrice) + ((amountMinted-discountedMintsRemaining) * mintPrice);
            discountedMintsRemaining = 0;
        }

        discountedMints = discountedMintsRemaining;
        return totalPrice;
    }

    // Mint event - this is used to emit event indicating mint and what is minted
    event Minted (uint[10] charactersMinted, address receiver);
    event GuruMinted (uint totalGuruMinted, address receiver);

    // promoMultiMint - this mint is for marketing ,etc, minted directly to the wallet of the recepient
    // for each item, a random character is chosen and minted. Max inclusing team mint is 200 (tracking reserved mint)
    // only approved wallets
    function promoMultiMint (address receiver, uint quantity) public nonReentrant {
        require(approvedTeamMinters[msg.sender], "Minter not approved");
        require(reservedMint > 0, "No reserved mint remaining");

        uint16[10] memory characterTracker = divergentCharacters;
        uint[10] memory mintedCharacters;

        for (uint i= 0; i < quantity; i++ ){
            bytes32 newRandomSelection = keccak256(abi.encodePacked(block.difficulty, block.coinbase, i));
            uint pickCharacter = uint(newRandomSelection)%10;
            mintedCharacters[pickCharacter] += 1;
            characterTracker[pickCharacter] -= 1;
        }

        _safeMint(receiver, quantity);

        divergentCharacters = characterTracker;

        reservedMint -= quantity;

        emit Minted(mintedCharacters, receiver);

    }

    // promoMint
    function promoMint (address[] calldata receiver) public nonReentrant {
        require(approvedTeamMinters[msg.sender], "Minter not approved");
        require(reservedMint > 0, "No reserved mint remaining");

        uint16[10] memory characterTracker = divergentCharacters;
        

        for (uint i = 0; i < receiver.length; i++) {
            bytes32 newRandomSelection = keccak256(abi.encodePacked(block.difficulty, block.coinbase, i));
            uint pickCharacter = uint(newRandomSelection)%10;
            uint[10] memory mintedCharacters;
            mintedCharacters[pickCharacter] += 1;
            characterTracker[pickCharacter] -= 1;

            _safeMint(receiver[i], 1);

            emit Minted(mintedCharacters, receiver[i]);
        }

        divergentCharacters = characterTracker;

        reservedMint -= receiver.length;

    }

    // Team Mint - team can mint unlimited as long as reserved mints remain (only approved wallets)
    // function teamMint (uint quantity) public nonReentrant {
    //     require(approvedTeamMinters[msg.sender], "Minter not approved");
    //     require(reservedMint > 0, "No reserved mint remaining");

    //     uint16[10] memory characterTracker = divergentCharacters;
    //     uint[10] memory mintedCharacters;

    //     for (uint i= 0; i < quantity; i++ ){
    //         bytes32 newRandomSelection = keccak256(abi.encodePacked(block.difficulty, block.coinbase, i));
    //         uint pickCharacter = uint(newRandomSelection)%10;
    //         mintedCharacters[pickCharacter] += 1;
    //         characterTracker[pickCharacter] -= 1;
    //     }

    //     _safeMint(msg.sender, quantity);

    //     divergentCharacters = characterTracker;

    //     reservedMint -= quantity;

    //     emit Minted(mintedCharacters, msg.sender);


    // }

    //Guru minting
    function guruMint(address receiver, uint quantity) public nonReentrant {
        require(approvedTeamMinters[msg.sender], "Minter not approved");
        require(divergentGuru >= quantity, "Insufficient remaining Guru");

        // Mint
        _safeMint(msg.sender, quantity);

        // Net off against guruminted
        divergentGuru -= quantity;

        // emit event
        emit GuruMinted(quantity, receiver);

    }


    // whitelist mint

    function whitelistMint (uint[10] calldata mintList, bytes32[] calldata proof) public payable nonReentrant {
        require (isWhitelistSaleOpen, "WL sale not open");
        uint currentTotalSupply = totalSupply();
        require (currentTotalSupply < maxSupplyInSaleWave, "Sale wave filled");
        require (MerkleProof.verify(proof, merkleRoot, generateMerkleLeaf(msg.sender)), "User not in WL");
        uint totalRequested = sumOfArray(mintList);
        require ((totalMintedByAddress[msg.sender] + totalRequested) <= MAX_PER_WALLET_WHITELIST_MINT, "Insufficient WL allocation");
        require (msg.value >= (totalRequested * mintPrice), "Insufficient payment");
        require (currentTotalSupply < MAX_MINT, "Sold Out" );

        uint16[10] memory characterTracker = divergentCharacters;
        uint[10] memory mintedCharacters;

        for (uint i = 0; i < 10; i++) {
            
            if (mintList[i] != 0) {
                if(characterTracker[i] != 0){
                    if (characterTracker[i] >= mintList[i]) {
                        mintedCharacters[i] += mintList[i];
                        characterTracker[i] -= uint16(mintList[i]);

                    } else { 
                        mintedCharacters[i] += uint(characterTracker[i]);
                        characterTracker[i] -= characterTracker[i];
                    }

                }
            }
        }

        uint totalMinted = sumOfArray(mintedCharacters);
        require (totalMinted != 0, "No items to be minted");

        // Calculate how much to charge
        uint paymentRequired = totalPaymentRequired(totalMinted);

        _safeMint(msg.sender, totalMinted); // Only after all calculations

        // Pay
        // calculate amounts to transfer
        uint devAmount = (paymentRequired / 10000) * 1600;
        uint divergentsAmount = paymentRequired - devAmount;
        
        // transfer amounts to dev wallet
        (bool devSuccess, ) = _devAddress.call{ value:devAmount, gas: PAYMENT_GAS_LIMIT }("");
        require(devSuccess, "Dev payment failed");
        
        // transfer amounts to divergents wallet
        (bool divergentsSuccess, ) = _divergentsAddress.call{ value:divergentsAmount, gas: PAYMENT_GAS_LIMIT }("");
        require(divergentsSuccess, "Divergents payment failed");

        // Return any unneeded sum
        if (msg.value - paymentRequired > 0) {
            uint returnValue = msg.value - paymentRequired;
            (bool returnSuccess, ) = msg.sender.call{ value:returnValue, gas: PAYMENT_GAS_LIMIT }("");
            require(returnSuccess, "Return payment failed");
        }

        // Add to totalMintedByAddress
        totalMintedByAddress[msg.sender] += totalMinted;

        // Update divergentCharacters
        divergentCharacters = characterTracker;

        // Emit minted items
        emit Minted(mintedCharacters, msg.sender);
    }

    // Public Sale mint
    function saleMint (uint[10] calldata mintList) public payable nonReentrant {
        require(isPublicSaleOpen, "Public sale not open");
        uint currentTotalSupply = totalSupply();
        require (currentTotalSupply < maxSupplyInSaleWave, "Sale wave filled");
        uint totalRequested = sumOfArray(mintList);
        require(msg.value >= totalRequested * mintPrice, "Insufficient payment");
        require(totalRequested <= MAX_PER_ORDER_SALE_MINT, "Max purchase limit");
        require(currentTotalSupply < MAX_MINT, "Sold Out");

        uint16[10] memory characterTracker = divergentCharacters;
        uint[10] memory mintedCharacters;

        for (uint i = 0; i < 10; i++) {
            
            if (mintList[i] != 0) {
                if(characterTracker[i] != 0){
                    if (characterTracker[i] >= mintList[i]) {
                        mintedCharacters[i] += mintList[i];
                        characterTracker[i] -= uint16(mintList[i]);

                    } else { 
                        mintedCharacters[i] += uint(characterTracker[i]);
                        characterTracker[i] -= characterTracker[i];
                    }

                }
            }
        }

        uint totalMinted = sumOfArray(mintedCharacters);
        require (totalMinted != 0, "No items to be minted");

        // Calculate how much to charge
        uint paymentRequired = totalPaymentRequired(totalMinted);

        _safeMint(msg.sender, totalMinted); // Only after all calculations

        // Pay
        // calculate amounts to transfer
        uint devAmount = (paymentRequired / 10000) * 1600;
        uint divergentsAmount = paymentRequired - devAmount;
        
        // transfer amounts to dev wallet
        (bool devSuccess, ) = _devAddress.call{ value:devAmount, gas: PAYMENT_GAS_LIMIT }("");
        require(devSuccess, "Dev payment failed");
        
        // transfer amounts to divergents wallet
        (bool divergentsSuccess, ) = _divergentsAddress.call{ value:divergentsAmount, gas: PAYMENT_GAS_LIMIT }("");
        require(divergentsSuccess, "Divergents payment failed");

        // Return any unneeded sum
        if (msg.value - paymentRequired > 0) {
            uint returnValue = msg.value - paymentRequired;
            (bool returnSuccess, ) = msg.sender.call{ value:returnValue, gas: PAYMENT_GAS_LIMIT }("");
            require(returnSuccess, "Return payment failed");
        }

        // Add to totalMintedByAddress
        totalMintedByAddress[msg.sender] += totalMinted;

        // Update divergentCharacters
        divergentCharacters = characterTracker;

        // Emit minted items
        emit Minted(mintedCharacters, msg.sender);

    }

   

}
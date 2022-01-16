pragma solidity 0.8.11;


import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/utils/ERC721Holder.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";

contract DigiTrade is ERC721Holder, ReentrancyGuard, AccessControl {
    using SafeMath for uint256;

    event NewOffer(
        uint256 offerId,
        address[2] wallets,
        address[6] addresses,
        uint256[4] nftTokenIds,
        uint256 erc20QtyOffered,
        uint256 erc20QtyRequested
    );

    event TradeDone(
        uint256 offerId,
        address payable[2] wallets,
        address[6] addresses,
        uint256[4] nftTokenIds,
        uint256 erc20QtyOffered,
        uint256 erc20QtyRequested
    );

    event CxlOffer(
        uint256 offerId,
        address payable[2] wallets,
        address[6] addresses,
        uint256[4] nftTokenIds,
        uint256 erc20QtyOffered,
        uint256 erc20QtyRequested
    );

    struct Offer {
        uint256 offerId;
        address payable[2] wallets;
        address[6] addresses;
        uint256[4] nftTokenIds;
        uint256 erc20QtyOffered;
        uint256 erc20QtyRequested;        
        bool tradeDone;
        bool tradeCXL;
        bool processing;
    }

    bytes32 public constant KEYHOLDER = keccak256("KEYHOLDER"); //6d612b3fde744b74adc89304d13d4171d7999bba96e228aa3dd670050e4cd1a1
    uint256 private BIGNUMBER = 10**18;
    uint256 public totalOffers;

    mapping(uint256 => Offer) public offerMap;
    mapping(address => uint256[]) public offerIds_by_wallet_map;

    IERC20 public DIGI;
    uint256 public gasFee_MakeOffer;
    uint256 public gasFee_AcceptOffer;
    uint256 public gasFeePercentage;
    address payable _digiFeeCollectorAddress;

    constructor(address digi) payable {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(KEYHOLDER, msg.sender);
        DIGI = IERC20(digi);
        gasFee_MakeOffer = 1 * BIGNUMBER;
        gasFee_AcceptOffer = 100 * BIGNUMBER;
        _digiFeeCollectorAddress = payable(msg.sender);
    }

    //["0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8","0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8","0x417Bf7C9dc415FEEb693B6FE313d1186C692600F","0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8", "0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8", "0x417Bf7C9dc415FEEb693B6FE313d1186C692600F"]
    // other wallet 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4


    //@dev makeOffer has 4 potential transactions: 1 x ERC20, 2x ERC721, 1 x Gas
    function makeOffer(
        address payable otherWallet,
        address[6] memory addresses,
        uint256[4] memory nftTokenIds,
        uint256 erc20QtyOffered,
        uint256 erc20QtyRequested
    ) public payable nonReentrant returns (uint256 orderId) {
        require(
            otherWallet != address(msg.sender),
            "Cant make offer to yourself"
        );
        require(IERC721(addresses[0]).ownerOf(nftTokenIds[0]) == msg.sender);
        require(
            nftTokenIds[1] == 0 ||
                IERC721(addresses[1]).ownerOf(nftTokenIds[1]) == msg.sender
        );

        // @dev 4 TRANSFERs ERC20 (OPT) + ERC20 (GAS) + 1 NFT (REQRD) + 1 1NFT (OPT) (4 TOTAL)

        //1 OFFER ERC20
        require(
            erc20QtyOffered == 0 ||
                IERC20(addresses[2]).transferFrom(
                    msg.sender,
                    address(this),
                    erc20QtyOffered //* BIGNUMBER
                )
        );

        //2 GAS ERC20
        require(
            gasFee_MakeOffer == 0 || hasRole(KEYHOLDER, msg.sender) ||
                DIGI.transferFrom(
                    msg.sender,
                    _digiFeeCollectorAddress,
                    gasFee_MakeOffer
                )
        );
        //3 NFT1
        IERC721(addresses[0]).safeTransferFrom(
            msg.sender,
            address(this),
            nftTokenIds[0]
        );

        //4 NFT2
        if (nftTokenIds[1] > 0) {
            IERC721(addresses[1]).safeTransferFrom(
                msg.sender,
                address(this),
                nftTokenIds[1]
            );
        }
        // ---- END TRANSFERS
        
        totalOffers = totalOffers + 1;
        address payable[2] memory wallets = [payable(msg.sender), otherWallet];
        Offer memory _offer = Offer(
            totalOffers,
            wallets,
            addresses,
            nftTokenIds,
            erc20QtyOffered,
            erc20QtyRequested,
            false,
            false,
            false
        );

        offerMap[totalOffers] = _offer;
        offerIds_by_wallet_map[msg.sender].push(totalOffers);
        offerIds_by_wallet_map[otherWallet].push(totalOffers);
        emit NewOffer(
            orderId,
            [msg.sender, otherWallet],
            addresses,
            nftTokenIds,
            erc20QtyOffered,
            erc20QtyRequested
        );
        return orderId;
    }

    // @dev @acceptOffer has 7 potential transactions: 2x Exch Tokens, 4x Exchange NFTs, 1x Gas
    function acceptOffer(uint256 orderId)
        external
        payable
        nonReentrant
        returns (bool)
    {
        Offer memory _offer = offerMap[orderId];
        address[6] memory addresses = _offer.addresses;

        require(_offer.wallets[1] == msg.sender, "You are not offeree");
        require(!_offer.tradeDone && !_offer.tradeCXL, "Trade Done or CXL");
        require(!_offer.processing, "Offer is processing");
        require(
            IERC721(addresses[3]).ownerOf(_offer.nftTokenIds[2]) == msg.sender
        );
        require(
            _offer.nftTokenIds[3] == 0 ||
                IERC721(addresses[4]).ownerOf(_offer.nftTokenIds[3]) ==
                msg.sender
        );
        require(
            DIGI.balanceOf(msg.sender) >= gasFee_AcceptOffer,
            "Not enough DIGI for gas"
        );

        // 1 SEND ERC20 TO OFFEROR (wallets[0])
        require(
            _offer.erc20QtyRequested == 0 ||
                IERC20(addresses[5]).transferFrom(
                    msg.sender,
                    _offer.wallets[0],
                    _offer.erc20QtyRequested // * BIGNUMBER
                )
        );

        //2 SEND ERC20 GAS FEE TO FEE COLLECTOR
        require(
            gasFee_MakeOffer == 0 ||   hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
                DIGI.transferFrom(
                    msg.sender,
                    _digiFeeCollectorAddress,
                    gasFee_AcceptOffer
                ),
            "Fee Xfer Error"
        );

        _offer.processing = true;

        //3 SEND REQUESTED-NFT1 TO OFFERROR

        IERC721(addresses[3]).safeTransferFrom(
            msg.sender,
            _offer.wallets[0],
            _offer.nftTokenIds[2]
        );

        //4 SEND REQUESTED-NFT2 OFFEROR

        if (_offer.nftTokenIds[3] > 0) {
            IERC721(addresses[4]).safeTransferFrom(
                msg.sender,
                _offer.wallets[0],
                _offer.nftTokenIds[3]
            );
        }

        //5 RECV -OFFERED ERC20

        if (_offer.erc20QtyOffered > 0) {
            IERC20(addresses[2]).transfer(
                msg.sender,
                _offer.erc20QtyOffered // * BIGNUMBER
            );
        }

        //6 RECV -OFFERED NFT1

        IERC721(addresses[0]).safeTransferFrom(
            address(this),
            msg.sender,
            _offer.nftTokenIds[0]
        );

        //7 SEND REQUESTED-NFT2 OFFEROR

        if (_offer.nftTokenIds[1] > 0) {
            IERC721(addresses[1]).safeTransferFrom(
                address(this),
                msg.sender,
                _offer.nftTokenIds[1]
            );
        }

        _offer.tradeDone = true;


        emit TradeDone(
            orderId,
            _offer.wallets,
            addresses,
            _offer.nftTokenIds,
            _offer.erc20QtyOffered,
            _offer.erc20QtyRequested
        );
        return true;
    }


// @dev cancelOffer has 3 potential transactions (1 ERC20, 2 NFT)
    function cancelOffer(uint256 orderId) external nonReentrant returns (bool) {
        Offer memory _offer = offerMap[orderId];
        require(
            _offer.wallets[0] == msg.sender ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "You are not the offerror"
        );
        require(!_offer.tradeDone && !_offer.tradeCXL, "Too late to CXL");
        require(!_offer.processing, "Offer processing");
        _offer.processing = true;

        address payable offerror = _offer.wallets[0];

        //1 Send ERC20
        if(_offer.erc20QtyOffered > 0) {
        IERC20(_offer.addresses[2]).transfer(            
             offerror,
            _offer.erc20QtyOffered // *  BIGNUMBER
        );
        }

        //2 Send NFT1
        IERC721(_offer.addresses[0]).safeTransferFrom(  
            address(this)        ,
             offerror,
            _offer.nftTokenIds[0]
        );

        //3 Send NFT2
        if(_offer.nftTokenIds[1] > 0 ){
        IERC721(_offer.addresses[1]).safeTransferFrom(  
            address(this)        ,
             offerror,
            _offer.nftTokenIds[1]
        );

        }

        _offer.tradeCXL = true;
        emit CxlOffer(orderId,
            _offer.wallets,
            _offer.addresses,
            _offer.nftTokenIds,
            _offer.erc20QtyOffered,
            _offer.erc20QtyRequested);
        return true;
    }

    // @dev ADMIN ACTIONS

    function setGas(address payable digiFeeCollectorAddress, uint256 _gasFee_MakeOffer, uint256 _gasFee_AcceptOffer, uint256 _gasFeePercentage) public 
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "YOU ARE NOT ADMIN");
        _digiFeeCollectorAddress = digiFeeCollectorAddress;
        gasFee_MakeOffer = _gasFee_MakeOffer;
        gasFee_AcceptOffer = _gasFee_AcceptOffer;
        gasFeePercentage = _gasFeePercentage;   
    }

}
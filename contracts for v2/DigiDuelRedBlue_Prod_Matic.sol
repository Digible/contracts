    // SPDX-License-Identifier: MIT
    // @dev DIGIDUEL Version 2a 
    //  
    // CHALLENGER VS DEFENDER
    // CHAINLINK ORACLE 
    // COLOR WIN ALGORITHM (~50/50);
    // CHALLENGER PUTS UP A PRIZE CARD ALONG WITH AN ENEREGY CARD vd
    // DEFENDER PUTS UP THEIR OWN PRICE CARD WITH ENERGY CARD.
    // CHALLENGER IS ASSIGNED COLOR RED
    // DEFENDER IS ASSIGNED COLOR BLUE
    // THE DUEL:
    // *** IF CHAINLINK-ALGO SAYS "RED" 
    // * * CHALLENGER WINS THE DEFENDER'S PRIZE CARD BUT.
    // ** DEFENDER WINS THE CHALLENGERS ENERGY CARD.
    // ** IF THE RESULT IS  "BLUE" THEN
    // ** DEFENDER WIN'S THE CHALLANGER'S PRIZE CARD
    // ** 
    // Duels start at index 1. Index 0 for duelTotalyNftAddressAndTokenId means no duel
    //** Duel is initiated to a specific defending NFT. The defender chooses the DEFENSE Card */

    //  oracleStatus  0 = not consulted ; // -1 = Consulted No result Yet // ANy # > 0 = Raw Result Came // - 2 = Duel Cancelled // -3 Error any other number some other not foreseen circumstance 

    pragma solidity 0.8.11;

    import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/VRFConsumerBaseV2.sol";
    import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/ChainlinkClient.sol";
    import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

    import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";
    import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
    import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/utils/ERC721Holder.sol";
    import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
    import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";


    contract DigiDuelRedBlue is VRFConsumerBaseV2,
    AccessControl,
    ChainlinkClient, 
    ERC721Holder
     {
        using SafeMath for uint256; 
        VRFCoordinatorV2Interface COORDINATOR;
        // ChainlinkConfiguration

        uint64 private s_subscriptionId;
        bytes32 private s_keyHash;
 
        address public _linkAddress;  
        uint32 callbackGasLimit = 100000;
        uint16 requestConfirmations = 3;
        uint32 numWords =  2;

        mapping(uint256 => uint256) oracleStatus; // 0 = not consulted ; // -1 = Consulted No result Yet // ANy # > 0 = Raw Result Came // - 2 = Duel Cancelled // -3 Error any other number some other not foreseen circumstance 


    /******************
        EVENTS
        ******************/
        event IChallengeYou(uint256 indexed duelId, address indexed challanger_wallet, address your_prize_nftAddress, uint256 your_prize_tokenId, address defendersWallet, uint256 endDate);

        event ChallengeAccepted(uint256 indexed duelId, address indexed wallet, address energyNftAddress_def, uint256 energyTokenId_def);


        event WinnerDeclared(uint256 indexed duelId, 
        address indexed winningWallet, 
        address prize_nftAddress_ch,
        uint256 prize_tokenId_ch,
        address prize_nftAddress_def,
        uint256 prize_tokenId_def
        
        
        );

        event CxlDuel(uint256 indexed duelId, bool unDo);
    
    


        // Access Fee Accounting 

        IERC20 public DIGI; // ##!! SET CORRECT ADDRESS AT DEPLOYMENT ##!!
        uint256 public duel_fee_digi;   
        address private _digiFeeCollectorAddress;
        mapping (address => uint256) public freeDuelsByWallet;

        // guts

    bytes32 public constant CHALLENGER = keccak256("CHALLENGER"); //
    mapping (uint256 => Duel) public duels;
    mapping (uint256 => uint256) public requestId_by_duelId;
    mapping (uint256 => uint256) public duelId_by_requestId;
    mapping (uint256 => uint256) public duelStatus;
    mapping (address => uint256[]) public duels_byWallet;
    mapping(address => mapping(uint256 => Duel)) public lastDuelbyNftAddressAndTokenId;
    uint256 public duelsCount = 0;






        // Stats
    
        mapping (address => uint256) public duelsWon_byWallet; 
        mapping (address => uint256) public duelsTotal_byWallet;
        mapping(address => mapping(uint256 => uint256)) duelsWon_byNftAddressAndTokenId;
        mapping(address => mapping(uint256 => uint256)) duelsTotal_byNftAddressAndTokenId;
      




        struct Duel {
            address wallet_ch;
            address prize_nftAddress_ch;
            uint256 prize_tokenId_ch;
            address energy_nftAddress_ch;
            uint256 energy_tokenId_ch;                        
            address wallet_def;
            address prize_nftAddress_def;
            uint256 prize_tokenId_def;
            address energy_nftAddress_def;
            uint256 energy_tokenId_def;         
            address winner;
            uint256 endDate;
            bool claimed;
        }

   constructor()  VRFConsumerBaseV2(0xAE975071Be8F8eE67addBC1A82488F1C24858067)  {
            _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); 
            _setupRole(CHALLENGER, msg.sender);
            _linkAddress = 0xb0897686c545045aFc77CF20eC7A532E3120E0F1;
            s_keyHash = 0x6e099d640cde6de9d40ac749b4b594126b0169747122711109c9985d47751f93;
                
            // DIGI = IERC20(0x03d390Af242C8a8a5340489f2D2649e859d7ec2f);
            DIGI = IERC20(0x4d8181f051E617642e233Be09Cea71Cc3308ffD4);
            _digiFeeCollectorAddress = msg.sender;
           
            duel_fee_digi = 50 * 10 ** 18;

            s_subscriptionId = 115;
            COORDINATOR = VRFCoordinatorV2Interface(0xAE975071Be8F8eE67addBC1A82488F1C24858067);
           
            
        }
    
    //  Challengers selectes their Prize and Energy NFTs, and challenges another Prize NFT. The defender will then chose their Energy NFT or refuse / ignore duel.
    function createDuelChallenge(address _prize_nftAddress_ch, 
    uint256 _prize_tokenId_ch, address _energy_nftAddress_ch, 
    uint256 _energy_tokenId_ch,
    address _prize_nftAddress_def,
    uint256 _prize_tokenId_def,
    uint256 _duration
   
    ) public  {
    
        require(hasRole(CHALLENGER, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "No Challenger Status");    

        require(IERC721(_prize_nftAddress_ch).isApprovedForAll(msg.sender, address(this)), "Approve all first");
        require(IERC721(_energy_nftAddress_ch).isApprovedForAll(msg.sender, address(this)), "Approve all first");
        
        if(freeDuelsByWallet[msg.sender] > 0 || duel_fee_digi == 0 )  
        {
           
        freeDuelsByWallet[msg.sender] -= 1;
        }

        else if (hasRole(DEFAULT_ADMIN_ROLE, msg.sender)){
            // no need to pay fees
        }
        else {
            require(DIGI.transferFrom(msg.sender,_digiFeeCollectorAddress,  
                duel_fee_digi), "Digi Fees Xfer Error");
             
        }       
        
        duelsCount += 1; // to start at 1
        uint256 newDuelId = duelsCount; 
        
        

        duels[newDuelId] = Duel({
                // CHALLENGER INFO
                wallet_ch: msg.sender,
                prize_nftAddress_ch: _prize_nftAddress_ch,
                prize_tokenId_ch: _prize_tokenId_ch,
                energy_nftAddress_ch: _energy_nftAddress_ch,
                energy_tokenId_ch: _energy_tokenId_ch,
             
                
                // DEFENDER INFO                

                wallet_def: address(0x0),
                prize_nftAddress_def : _prize_nftAddress_def,
                prize_tokenId_def: _prize_tokenId_def,
                energy_nftAddress_def: address(0x0),
                energy_tokenId_def: 0,
                
                // RESULTS
                winner: address(0x0),
                endDate: block.timestamp + _duration,
                claimed: false
            });


        duels_byWallet[msg.sender].push(newDuelId);
        lastDuelbyNftAddressAndTokenId[_prize_nftAddress_ch][_prize_tokenId_ch] = duels[newDuelId];
    
    

        emit IChallengeYou(newDuelId, msg.sender, _prize_nftAddress_def, _prize_tokenId_def, IERC721(_prize_nftAddress_def).ownerOf(_prize_tokenId_def),  block.timestamp + _duration);


    }


    function acceptDuel(uint256 duelId, 
    address _energy_nftAddress_def, 
    uint256 _energy_tokenId_def)  public {

    require(
                (duels[duelId].endDate > block.timestamp) && duels[duelId].wallet_def == address(0x0),
                'Duel ended'
            );

    if(freeDuelsByWallet[msg.sender] > 0 || duel_fee_digi == 0 || hasRole(DEFAULT_ADMIN_ROLE, msg.sender))  {
        freeDuelsByWallet[msg.sender] -= 1;
        }
        else {
            require(DIGI.transferFrom(msg.sender,_digiFeeCollectorAddress,  
                duel_fee_digi));
              
        }       
       


    
    // 1A Collect Challenger's Prize Card
    IERC721(duels[duelId].prize_nftAddress_ch).transferFrom(duels[duelId].wallet_ch, address(this), duels[duelId].prize_tokenId_ch);
    // 1B Collect Challenger's Energy Card
    IERC721(duels[duelId].energy_nftAddress_ch).transferFrom(duels[duelId].wallet_ch, address(this), duels[duelId].energy_tokenId_ch);


    // 2A Collect Defender's Prize Card
    IERC721(duels[duelId].prize_nftAddress_def).transferFrom(msg.sender, address(this), duels[duelId].prize_tokenId_def);

    // 2B Collect Defender's Energy Card supplied in these arguments, it is uknown until then (assigned further below)
    IERC721(_energy_nftAddress_def).transferFrom(msg.sender, address(this), _energy_tokenId_def);

    // consultOracle
    uint256 requestId = COORDINATOR.requestRandomWords(
      s_keyHash,
      s_subscriptionId,
      requestConfirmations,
      callbackGasLimit,
      numWords
    ); 
    requestId_by_duelId[duelId] = requestId;
    duelId_by_requestId[requestId] = duelId;

    // assign duel values

    duels[duelId].wallet_def = msg.sender;
    duels[duelId].energy_nftAddress_def = _energy_nftAddress_def;
    duels[duelId].energy_tokenId_def = _energy_tokenId_def;

    duels_byWallet[msg.sender].push(duelId);
     


    emit ChallengeAccepted(duelId, msg.sender, _energy_nftAddress_def, _energy_tokenId_def );

    }


    function cxlDuel(uint256 duelId) external {
    require(
                (duels[duelId].endDate > block.timestamp) && duels[duelId].wallet_def == address(0x0),
                'Duel ended'
            );

    require(duels[duelId].wallet_ch == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not Challenger");

    duels[duelId].endDate = block.timestamp;
    duels[duelId].winner = address(0x000000000000000000000000000000000000dEaD);

    emit CxlDuel(duelId, false);


    }

    function claimResult(uint256 duelId) external {

        require(duels[duelId].wallet_ch == msg.sender || duels[duelId].wallet_def == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not Duelist");

        require(duels[duelId].winner == duels[duelId].wallet_ch || duels[duelId].winner == duels[duelId].wallet_def, "No Winner");

        

        address vanquishedWallet;

        //1A Send  Prize Card to Winner
        if(duels[duelId].winner == duels[duelId].wallet_ch){
        
           

            vanquishedWallet = duels[duelId].wallet_def;

        }  else{

           

            vanquishedWallet = duels[duelId].wallet_ch;


        }
       
     // 1A Transfer Prize Cards to Winner 
     IERC721(duels[duelId].prize_nftAddress_ch).transferFrom(address(this), duels[duelId].winner, duels[duelId].prize_tokenId_ch);


     IERC721(duels[duelId].prize_nftAddress_def).transferFrom(address(this), duels[duelId].winner, duels[duelId].prize_tokenId_def);
   
    // 2 Transfer Energy Cards to Vanquished 
     IERC721(duels[duelId].energy_nftAddress_ch).transferFrom(address(this), vanquishedWallet, duels[duelId].energy_tokenId_ch);

     IERC721(duels[duelId].energy_nftAddress_def).transferFrom(address(this), vanquishedWallet, duels[duelId].energy_tokenId_def);


     duels[duelId].claimed = true;

  




    }




     function getAllDuelsByWallet(address _wallet) external view returns (uint256[] memory){

           
            return duels_byWallet[_wallet];
        }




 


    //@ dev ORACLE HAS SPOKEN: CHAINLINK VRF CALLS THIS fulfillRandomWords FUNCTION:
            
       

   function fulfillRandomWords(
    uint256 requestId,
    uint256[] memory randomWords
  ) internal override {
    
        
        uint256 duelId = duelId_by_requestId[requestId];
        if(duels[duelId].winner != address(0x0)) {
            return; 
        }
        uint256 randomResult = (randomWords[0] % 2) + 1;
        
        if(randomResult == 1)  {
            duels[duelId].winner = duels[duelId].wallet_ch;
            duelsWon_byNftAddressAndTokenId[duels[duelId].prize_nftAddress_ch][duels[duelId].prize_tokenId_ch] +=1;
            
        }
        else{
            duels[duelId].winner = duels[duelId].wallet_def;
                duelsWon_byNftAddressAndTokenId[duels[duelId].prize_nftAddress_def][duels[duelId].prize_tokenId_def] +=1;
        }

    
            duels[duelId].endDate = block.timestamp;
            duelStatus[duelId] = randomWords[0];

            // POPULATE STATS

            duelsWon_byWallet[duels[duelId].winner] += 1;

            duelsTotal_byWallet[duels[duelId].wallet_ch] += 1;
            duelsTotal_byWallet[duels[duelId].wallet_def] += 1;
        
        duelsTotal_byNftAddressAndTokenId[duels[duelId].prize_nftAddress_ch][duels[duelId].prize_tokenId_ch] +=1;

        duelsTotal_byNftAddressAndTokenId[duels[duelId].prize_nftAddress_def][duels[duelId].prize_tokenId_def] +=1;
            
        



            emit WinnerDeclared(duelId, duels[duelId].winner, duels[duelId].prize_nftAddress_ch, duels[duelId].prize_tokenId_ch, duels[duelId].prize_nftAddress_def, duels[duelId].prize_tokenId_def);



        }



    // #########################@dev Admin only FUNCTIONS
    
    

 

        function setDigiFees(uint256 human_fee, address new_currencyAddress)  external  {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Admin only");
        duel_fee_digi = human_fee * 10 ** 18;
        DIGI = IERC20(new_currencyAddress);

    }

    function undoDuel(uint256 duelId) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Admin only");
        
        //1A Send Back Prize Card to Challenger
        if(IERC721(duels[duelId].prize_nftAddress_ch).ownerOf(duels[duelId].prize_tokenId_ch) == address(this)) {
            IERC721(duels[duelId].prize_nftAddress_ch).transferFrom(address(this),duels[duelId].wallet_ch, duels[duelId].prize_tokenId_ch );
        }

        //1B Send Back Energy Card to Challenger

    if(IERC721(duels[duelId].energy_nftAddress_ch).ownerOf(duels[duelId].energy_tokenId_ch) == address(this)) {
            IERC721(duels[duelId].energy_nftAddress_ch).transferFrom(address(this),duels[duelId].wallet_ch, duels[duelId].energy_tokenId_ch );
        }

        //2A Send Back Prize Card to Defender

    if(IERC721(duels[duelId].prize_nftAddress_def).ownerOf(duels[duelId].prize_tokenId_def) == address(this)) {
            IERC721(duels[duelId].prize_nftAddress_def).transferFrom(address(this),duels[duelId].wallet_def, duels[duelId].prize_tokenId_def );
        }

            //2B Send Back Energy Card to Defender

        if(IERC721(duels[duelId].energy_nftAddress_def).ownerOf(duels[duelId].energy_tokenId_def) == address(this)) {
            IERC721(duels[duelId].energy_nftAddress_def).transferFrom(address(this),duels[duelId].wallet_def, duels[duelId].energy_tokenId_def );
        }

        duels[duelId].endDate = block.timestamp;
    duels[duelId].winner = address(0x000000000000000000000000000000000000dEaD);
    emit CxlDuel(duelId, true);

    }

    function Spell1(address wallet, uint256 addFreeDuelsQty) external {
            require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Admin only");

        freeDuelsByWallet[wallet] += addFreeDuelsQty;

    }




    }

    // TESTNET DIGI ADDRESSES
    
    //     digiAddressMatic: '0x03d390Af242C8a8a5340489f2D2649e859d7ec2f',
    
    //     digiBSCAddress: '0x7144401c72dEa1f577d090F808C541b2A81108FD',
    
    //     digiEthAddress: '0xD312460817A60128964bc16E56c4f47fB89F4F21', // KOVAN

    // MAINNET DIGI ADDRESSES 


    //     digiAddressMatic: '0x4d8181f051E617642e233Be09Cea71Cc3308ffD4',
    
    //     digiBSCAddress: '0x82cD5A3342ccc1329E7022857d8DB73A52dfEbAb',
    
    //     digiEthAddress: '0x3cbf23c081faa5419810ce0f6bc1ecb73006d848',
    
    

    
pragma solidity ^0.4.0;
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

contract BananaGame is usingOraclize{
    uint constant times = 64;
    uint safeGas = 2300;
    uint constant ORACLIZE_GAS_LIMIT = 175000;
    uint percent = 50; //max is 100
    uint constant minBet =200 finney;
    address public owner;
    bool public isStopped;
    event LOG_OwnerAddressChanged(address owner,address newOwner);
    event LOG_NewBet(address addr, uint value);
    event LOG_ContractStopped(); 
    event LOG_GasLimitChanged(uint oldGasLimit, uint newGasLimit);
    event LOG_InjectEth(address addr,uint value); 
    event LOG_FailedSend(address receiver, uint amount); 
    event LOG_SuccessfulSend(address receiver, uint amount);
    struct Bet{
        address playerAddr;
        uint amountBet;
        bytes betResult;
    }
    
    modifier onlyOwner{
        if(msg.sender!=owner) throw;
        _;
    }
    
    modifier onlyOraclize{
        if(msg.sender !=oraclize_cbAddress()) throw;
        _;
    }
    modifier onlyIfNotStopped{
        if(isStopped) throw;
        _;
    }
     modifier onlyIfValidGas(uint newGasLimit) {
        if (ORACLIZE_GAS_LIMIT + newGasLimit < ORACLIZE_GAS_LIMIT) throw;
        if (newGasLimit < 25000) throw;
        _;
    }
    
    modifier checkBetValue(uint value){
        if(value<getMinBetAmount() ||value>getMaxBetAmount()) throw;
        _;
    }
    
    modifier onlyIfBetExist(bytes32 myid) {
        if(bets[myid].playerAddr == address(0x0)) throw;
        _;
    }
    
    modifier onlyIfNotProcessed(bytes32 myid) {
        if (bets[myid].betResult.length <=times) throw;
        _;
    }
    
    mapping (bytes32 => Bet) public bets;
    bytes32[] public betsKeys; 
    
     function BananaGame(){
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
        owner = msg.sender;
        isStopped=false;
     }
    
    function () payable{
        bet();
    }
    
    function bet() payable onlyIfNotStopped checkBetValue(msg.value){
        uint oraclizeFee = OraclizeI(OAR.getAddress()).getPrice("URL", ORACLIZE_GAS_LIMIT + safeGas);
        if (oraclizeFee >= msg.value) throw;
        uint betValue = msg.value - oraclizeFee;
        LOG_NewBet(msg.sender,betValue);
        // bytes32 myid =
        //         oraclize_query(
        //             "nested",
        //             "[URL] ['json(https://api.random.org/json-rpc/1/invoke).result.random.data', '\\n{\"jsonrpc\":\"2.0\",\"method\":\"generateSignedIntegers\",\"params\":{\"apiKey\":${[decrypt] BIm/tGMbfbvgqpywDDC201Jxob7/6+sSkRBtfCXN94GO0C7uD4eQ+aF+9xNJOigntWu8QHXU6XovJqRMEGHhnEnoaVqVWSqH1U1UFyE6WySavcbOb/h8hOfXv+jYBRuhkQr+tHXYrt1wx0P0dRdeCxbLp1nDuq8=},\"n\":64,\"min\":0,\"max\":1${[identity] \"}\"},\"id\":1${[identity] \"}\"}']",
        //             ORACLIZE_GAS_LIMIT + safeGas
        //         );
        bytes32 myid =oraclize_query("URL", "json(https://api.random.org/json-rpc/1/invoke).result.random.data",'{"jsonrpc":"2.0","method":"generateSignedIntegers","params":{"apiKey":"25b4b5c6-e9b0-4000-b991-77b8471e9a8a","n":64,"min":0,"max":1},"id":1}',ORACLIZE_GAS_LIMIT + safeGas);
        bets[myid] = Bet(msg.sender, betValue, "");
        betsKeys.push(myid);
    }
    
    function __callback(bytes32 myid, string result, bytes proof) onlyOraclize onlyIfBetExist(myid) 
    onlyIfNotProcessed(myid) {
        bytes memory queue = bytes(result);
        // bytes memory doResult = bytes(64);
        // string memory s =  new string(64);
        bytes memory sd;
        uint k=0;
        if(queue.length<64){
            throw;
        }
        for(uint i=0 ;i<queue.length;i++){
            if(queue[i]==48 || queue[i]==49){
                sd[k] =queue[i];
                k++;
                if(k>63){
                    break;
                }
            }   
        }
        bets[myid].betResult = sd;
        doExecute(myid,bets[myid].amountBet,sd);
    }
    function doExecute(bytes32 myid,uint _amountBet,bytes _betResult) internal {
        uint initAccount=_amountBet;
        uint getAccount;
        
        for(uint i=0;i<_betResult.length;i++){
            if(_betResult[i]==49){
                if(getAccount+initAccount<getAccount||_amountBet+getAccount<_amountBet){
                    throw;
                }
                getAccount +=initAccount;
                initAccount = initAccount*50/100;
            }else{
                break;
            }
        }
        if(getAccount!=0){
            // bets[myid].playerAddr.transfer(getAccount);
            safeSend(bets[myid].playerAddr,getAccount);
        }else{
            safeSend(bets[myid].playerAddr,1 wei);
        }
    }

    function safeSend(address addr,uint value) internal{
        if (value == 0) {
            
            return;
        }
        if (this.balance < value) {
           
            return;
        }
        if (!(addr.call.gas(safeGas).value(value)())) {
            LOG_FailedSend(addr, value);
        }
        LOG_SuccessfulSend(addr,value);
    }
    

    function setStopped() onlyOwner{
        isStopped =true;
        LOG_ContractStopped();
    }
    
    function setStarted() onlyOwner{
        isStopped =false;
    }
    
    function getBetNum() constant returns (uint){
        return betsKeys.length;
    }
    
     function changeOwnerAddress(address newOwner)
        onlyOwner {
        if (newOwner == address(0x0)) throw;
        owner = newOwner;
        LOG_OwnerAddressChanged(owner, newOwner);
    }
    
    function changeGasLimitOfSafeSend(uint newGasLimit)
        onlyOwner
        onlyIfValidGas(newGasLimit) {
        safeGas = newGasLimit;
        LOG_GasLimitChanged(safeGas, newGasLimit);
    }

    function injectEth() payable{
        if(msg.value<=0.6 ether) throw;
        LOG_InjectEth(msg.sender,msg.value);        
    }
    
    function changeOraclizeProofType(byte _proofType)
        onlyOwner {
        if (_proofType == 0x00) throw;
        oraclize_setProof( _proofType |  proofStorage_IPFS );
    }
    
    function changeOraclizeConfig(bytes32 _config)
        onlyOwner {

        oraclize_setConfig(_config);
    }
    function getMinBetAmount()
        constant
        returns(uint) {
        uint oraclizeFee = OraclizeI(OAR.getAddress()).getPrice("URL", ORACLIZE_GAS_LIMIT + safeGas);
        return oraclizeFee + minBet;
    }
    
    function getMaxBetAmount() constant returns (uint){
        return this.balance/20;
    }
 
}
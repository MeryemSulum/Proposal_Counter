// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";

contract ProposalContract{
    //Data

    using Counters for Counters.Counter;
    Counters.Counter private _counter;

        //Owner 
    address owner;
    
        //Teklif yapımız
    struct Proposal{
        string description;
        uint256 approve; //pozitip tamsayı-unsigned integer sayı kapasitesi için açılan hafıza yeri 256 bit pozitif tamsayı
                //unsigned integer = uint. Normalde sign yani işaret için 1 bit feda ediyorduk, 
                //işaretsiz yani pozitif olduğunu belirtince 1 bit kazanmış olduk. O 1 bit de kapasitemizi 2'ye katlıyor.
                //proposal'ı onaylayanlar
        uint256 reject; //proposal'a red verenler
        uint256 pass; //boş oy verenler
        uint256 total_vote_to_end;//kaç oy olunca oylama durmalı
        bool current_state;//  geçti mi kaldı mı onaylandı mı onaylanmadı mı
        bool is_active; //projenin işi bitti mi yoksa active hala üstünde çalışılan proje mi
    }

    //mapping  ---> proposal historysini tutmak için
    mapping (uint256 => Proposal) proposal_history;
           // (1.prosal--description:...)gibi

    //array, oy verenleri tutmak için---- herkesin bir oy hakkı var tekrar tekrar oy kullanılmamalı
    address[] private voted_addresses;

    constructor(){
        owner = msg.sender; //contractı oluşturan kişiyi belirtir. owner ile yapan aynı dedik burada
        voted_addresses.push(msg.sender); //oylamayı açan oy veremesin
    }

    modifier onlyOwner(){  //onlyOWner, fonksiyonun işlem şartıdır.
        require(msg.sender == owner, "Only owner can perform this action"); //fonksiyonun başındaki zorunluluk şartları
        _;     //Merge Wildcard       //fonksiyona devam et. bu işaret koyulmak zorunda.
    }

    modifier active(){  //active olan proposal'ı bulmak için yoksa kapanmış olan oylama üzerinde oylama yapılmasın diye
        require(proposal_history[_counter.current()].is_active == true, "Proposal is currently not active");
        _;
    }

    modifier newVoter(address _address) { // aynı adres birden fazla oy kullanmasın ve kullanırsa mesaj yayınlansın
         require(!isVoted(_address), "Address already voted");
         _;
    }
    //Execute Functions
    
    //owner'ı değiştirme - owner'ı yalnızca owner değiştirebilir(onlyOwner modifier)
    function setOwner(address new_owner) external onlyOwner{ 
        owner = new_owner;
    }

    //calldata --> readonly(çağırılan data değiştirilmiyecek.ve geçici memoryde olduğu için) (gasfee daha düşük oluyor.)
    //yeni proposal oluşturma
    function create(string calldata _description, uint _total_vote_to_end) external onlyOwner{
        _counter.increment(); //yeni proposal'ın kaçıncı proposal olduğunu counter'da +1 ile belirtme 
        proposal_history[_counter.current()] = Proposal(_description, 0, 0, 0, _total_vote_to_end, false, true);
    } //0,0,0 girilen parametreler approved,reject,pass oylarının default değeri
      // false--> current_state'in default değeri
      // true--> is_active değeri

    function vote(uint8 choice) external active newVoter(msg.sender) {
        Proposal storage proposal = proposal_history[_counter.current()]; 
        //storage:referans yaratmak. bu diye işaret etmek,proposal_history yerine proposal kullan. kopyalama yapmıyor.
        uint total_vote = proposal.approve + proposal.reject + proposal.pass;

        voted_addresses.push(msg.sender);

        if(choice == 1) {
            proposal.approve += 1;
            proposal.current_state = calculateCurrentState();
        }
        else if(choice == 2) {
            proposal.reject +=1 ;
            proposal.current_state = calculateCurrentState();
        }
        else if(choice == 0) {
            proposal.pass += 1;
            proposal.current_state = calculateCurrentState();
        }

        if((proposal.total_vote_to_end - total_vote == 1) && (choice == 1 || choice == 2 || choice == 0)) {
            proposal.is_active = false;
            voted_addresses = [owner];
        }
    }

    function terminatePoll() external onlyOwner active {
        proposal_history[_counter.current()].is_active = false;
         voted_addresses = [owner];
    }

    function calculateCurrentState() private view returns(bool) {
        Proposal storage proposal = proposal_history[_counter.current()];

        uint approve = proposal.approve;
        uint reject = proposal.reject;
        uint pass = proposal.pass;

        if(proposal.pass % 2 == 1){
            pass += 1;
        }
        pass = pass / 2;
        if(approve > reject + pass) {
            return true;
        } else {
            return false;
        }
    }

    function isVoted(address _address) public view returns(bool) { 
        for(uint i = 0; i < voted_addresses.length; i++){
            if( voted_addresses[i] == _address ) {
                return true;
            }

        }
        return false;
    }

    //Query Functions : gasfee kullanılmaz.
        // external : dışarıdan çağırılan, kontrat içinde kullanılmayan.
        // view : kontrattan bilgi alan, hiçbir şey değiştirmeyen.
        // pure : kontranttan hiçbir bilgi almayan, hiçbir şeyide değiştirmeyen. {(1+2)=3} gibi.
        // memory : geçici olarak hafızaya al, kopyasını yarat.Silinirse orjinali korunur.
        // storage : kopyasını yaratmaz, referans verir.Silinirse orjinali silinir.
    function get_owner() external view returns(address){
        return owner;
    }
    function get_current_poll() external view returns(Proposal memory){
        return proposal_history[_counter.current()];
    }
    function get_proposal(uint256 index) external view returns(Proposal memory){
        return proposal_history[index];
    } 
    function get_current_count() external view returns(uint){
        return _counter.current();
    }


}


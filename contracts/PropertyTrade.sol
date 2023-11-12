// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

contract PropertyManagment {
    struct User{
        bool isTenant;
        bool isLandlord;
        string name;
    }

    struct Property{
        int id;
        string location;
        string description;
        address owner;
        bool isRented;
        address tenant;
    }

    struct Rent{
        int rentalId;
        address tenant;
        uint256 startDate;
        uint256 endDate;
    }

    struct Complain{
        address user;
        int rentalId;
        string text;
        string reply;
    }

    struct EarlyTermination {
        address tenant;
        int rentalId; 
        uint256 requestTime;
        bool isApproved;
    }

    mapping(address => User) public users;
    mapping(int => Property) public properties;

    address[] public userList;
    int public propertyIdCounter;
    uint256 public tenantCount;
    uint256 public landlordCount;
    Rent[] public rents;
    Complain[] public complains;
    EarlyTermination[] public earlyTerminationRequests;

    constructor(){
        propertyIdCounter = 0;
    }

    function createUser(string memory name, bool _isTenant, bool _isLandlord) public {
        require(!users[msg.sender].isTenant && !users[msg.sender].isLandlord, "User already exists");
        users[msg.sender] = User(_isTenant, _isLandlord, name);
        userList.push(msg.sender);
    }



    function createProperty(string memory name, string memory description)public {
        require(users[msg.sender].isLandlord,"only Landlords can create property");
        properties[propertyIdCounter] = Property(propertyIdCounter, name, description, msg.sender,true,address(0));
        
        propertyIdCounter++; 
    }


    function createRent(int rentalId, address tenant , uint256 startDate,  uint256 endDate)public {
        require(users[tenant].isTenant && properties[rentalId].owner == msg.sender, "Invalid tenant or property");
        require(!properties[rentalId].isRented, "Property is not rentable");
        rents.push(Rent(rentalId,tenant, startDate, endDate));
        properties[rentalId].isRented = true; 
    }

    function rentedProperties() public view  returns(address[]memory){
        address[]memory rentedPropertyList = new address[](rents.length);
        for(uint256 i = 0; i<rents.length ; i++){
            rentedPropertyList[i] = properties[rents[i].rentalId].owner;
        }
        return rentedPropertyList;
    }

    function makeComplain(int rentalId, string memory text)public {
        require(users[msg.sender].isTenant,"only tenants can make a complain");
        require(properties[rentalId].tenant == msg.sender,"users can only complain about a their own rented property");
        complains.push(Complain(msg.sender, rentalId, text, ""));
    }

    function replyTheComplain(uint complainIndex , string memory reply)public{
        require(users[msg.sender].isLandlord,"only landlords can reply to complains");
        require(complainIndex < complains.length, "Invalid complaint index");
        Complain storage complain = complains[complainIndex];
        require(properties[complain.rentalId].owner == msg.sender, "You are not the owner of the property related to this complaint");
        complain.reply = reply;
    }

    function getTenantsComplains()public view returns (int[] memory, string[] memory, string[] memory, string[] memory){
        int[] memory rentalIds = new int[](complains.length);
        string[] memory texts = new string[](complains.length);
        string[] memory replies = new string[](complains.length);
        string[] memory replyOfOwners = new string[](complains.length);

        for (uint256 i = 0; i < complains.length; i++) {
            Complain memory complain = complains[i];
            if (complain.user == msg.sender) {
                rentalIds[i] = complain.rentalId;
                texts[i] = complain.text;
                replies[i] = complain.reply;
                replyOfOwners[i] = properties[complain.rentalId].owner == address(0) ? "" : users[properties[complain.rentalId].owner].name;
            }
        }

        return (rentalIds, texts, replies, replyOfOwners);
    }


    function getLandlordComplaints() public view returns (int[] memory, string[] memory, string[] memory) {
        int[] memory rentalIds = new int[](complains.length);
        string[] memory texts = new string[](complains.length);
        string[] memory replies = new string[](complains.length);

        for (uint256 i = 0; i < complains.length; i++) {
            Complain memory complain = complains[i];
            if (properties[complain.rentalId].owner == msg.sender) {
                rentalIds[i] = complain.rentalId;
                texts[i] = complain.text;
                replies[i] = complain.reply;
            }
        }

        return (rentalIds, texts, replies);
    }

    function getProperties(int id) public view returns (int[] memory, string[] memory, string[] memory, address[] memory) {
        int[] memory rentalIds = new int[](1);
        string[] memory propertyNames = new string[](1);
        string[] memory propertyDescriptions = new string[](1);
        address[] memory propertyOwners = new address[](1);

        Property memory property = properties[id];
        
        rentalIds[0] = property.id;
        propertyNames[0] = property.location;
        propertyDescriptions[0] = property.description;
        propertyOwners[0] = property.owner;

        return (rentalIds, propertyNames, propertyDescriptions, propertyOwners);
    }

    function terminateRent(int rentalId, address tenant) public {
        require(users[msg.sender].isLandlord, "Only landlords can terminate leases");
        require(properties[rentalId].owner == msg.sender, "You are not the owner of the property");

        for (uint256 i = 0; i < rents.length; i++) {
            if (rents[i].rentalId == rentalId && rents[i].tenant == tenant) {
                rents[i].endDate = block.timestamp;
                break;
            }
        }
    }


    function requestEarlyTermination(int rentalId) public {
        require(users[msg.sender].isTenant, "Only tenants can request early termination");
           
        bool hasRent = false;
        for (uint256 i = 0; i < rents.length; i++) {
            if (rents[i].rentalId == rentalId && rents[i].tenant == msg.sender) {
                hasRent = true;
                break;
            }
        }
        require(hasRent, "You do not have a lease for this property");
        earlyTerminationRequests.push(EarlyTermination(msg.sender, rentalId, block.timestamp, false));
    }

    function approveEarlyTermination(uint256 requestIndex) public {
        require(users[msg.sender].isLandlord, "Only landlords can approve early termination");
        require(requestIndex < earlyTerminationRequests.length, "Invalid request index");

        EarlyTermination storage request = earlyTerminationRequests[requestIndex];
        require(properties[request.rentalId].owner == msg.sender, "You are not the owner of the property");
        terminateRent(request.rentalId, request.tenant);
        request.isApproved = true;

        properties[request.rentalId].isRented=true;
    }

}
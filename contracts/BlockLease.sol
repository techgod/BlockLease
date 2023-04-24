// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract BlockLease {
    // Defines information for landlord
    struct Landlord {
        address payable addr;
        bool agrees;
    }
    
    // Defines information for tenant
    struct Tenant {
        address addr;
        bool agrees;
    }

    // Defines information for tenant
    struct Property {
        string name;
        string location;
    }
    
    // The lease can be in one of these few states
    enum LeaseState {INACTIVE, ACTIVE, TERMINATED, COMPLETE}

    // Defines information about the lease
    struct Lease {
        LeaseState state;
        uint256 rentAmount;
        uint256 rentalDuration;
    }

    // Variables store information
    Landlord public landlord;
    Tenant public tenant;
    Property public property;
    Lease public lease;

    /** 
     * @dev The tenant or landlord can accept the agreement. 
     * Both parties have to agree for the contract to be put in active state.
     */
    function signAgreement() public {
        require(msg.sender == landlord.addr || msg.sender == tenant.addr, "Only owner or tenent can sign agreement.");
        require(lease.state == LeaseState.INACTIVE, "The lease has to be in inactive state.");
        if(msg.sender == landlord.addr) {
            require (landlord.agrees == false, "Landlord has already agreed.");
            landlord.agrees = true;
        }
        if (msg.sender == tenant.addr) {
            require (tenant.agrees == false, "Tenant has already agreed.");
            tenant.agrees = true;
        }

        if (landlord.agrees && tenant.agrees) {
            // Both have agreed to the terms, set the lease state to active.
            lease.state = LeaseState.ACTIVE;
        }
    }

    /** 
     * @dev The tenant or landlord can revoke their agreement to the lease while the lease is inactive.
     */
    function unsignAgreement() public {
        require(msg.sender == landlord.addr || msg.sender == tenant.addr, "Only owner or tenent can unsign agreement.");
        require(lease.state == LeaseState.INACTIVE, "The lease has to be in inactive state to be unsigned.");
        if(msg.sender == landlord.addr) {
            require (landlord.agrees == true, "Landlord has not signed the agreement yet.");
            landlord.agrees = false;
        }
        if (msg.sender == tenant.addr) {
            require (tenant.agrees == true, "Tenant has not signed the agreement yet.");
            tenant.agrees = false;
        }
    }

    /** 
     * @dev Set the terms for lease. Can be called by the tenant or the landlord while the lease is inactive.
     * @param rentAmount amount of rent in GWei
     * @param rentDuration length of lease agreement in months
     */
    function setTerms(uint256 rentAmount, uint256 rentDuration) public {
        require(msg.sender == landlord.addr || msg.sender == tenant.addr, "Only owner or tenent can set terms.");
        require(lease.state == LeaseState.INACTIVE, "The lease has to be in inactive state to set terms.");

        // Set the terms of the lease
        lease.rentAmount = rentAmount;
        lease.rentalDuration = rentDuration;
        
        // If terms are updated, parties have to resign.
        landlord.agrees = false;
        tenant.agrees = false;
    }
    
    /** 
     * @dev Initialize the lease contract. Landlord, tenant, and property details cannot be changed for a contract.
     * @param landlordAddr the account address of the landlord 
     * @param tenantAddr the account address of the tenant
     * @param propertyName the name of the property being leased out
     * @param propertyLocation the location of the property being leased out
     */
    constructor(
        address landlordAddr,
        address tenantAddr,
        string memory propertyName,
        string memory propertyLocation
    ){
        require(msg.sender == landlordAddr || msg.sender == tenantAddr, "Only landlord or tenant should be allowed to create the lease.");

        // Set the details of the contract
        landlord.addr = payable(landlordAddr);
        tenant.addr = tenantAddr;
        property.name = propertyName;
        property.location = propertyLocation;

        // Set the state of the contract to be inactive initally
        lease.state = LeaseState.INACTIVE;
    }
}
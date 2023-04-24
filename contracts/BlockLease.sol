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
        address payable addr;
        bool agrees;
    }

    // Defines information for tenant
    struct Property {
        string name;
        string location;
    }
    
    // The lease can be in one of these few states
    enum LeaseState {INACTIVE, PENDING_DEPOSIT, ACTIVE, TERMINATED, PENDING_RETURN, FINISHED}

    // Defines information about the lease
    struct Lease {
        LeaseState state;
        uint256 rentAmount;
        uint256 securityDeposit;
        uint256 rentalDuration;
    }

    // Variables store information
    Landlord public landlord;
    Tenant public tenant;
    Property public property;
    Lease public lease;

    event Transfer(address indexed from, address indexed to, uint256 value);


    /** 
     * @dev The tenant can deposit money for the security deposit to activate the lease
     */
    function depositSecurityDeposit() payable public {
        require(msg.sender == tenant.addr, "Only tenent can send security deposit.");
        require(lease.state == LeaseState.PENDING_DEPOSIT, "The lease should be in pending deposit state.");
        require(msg.value == lease.securityDeposit, "The value being deposited should equal the security deposit amount.");

        // Security deposit is received - the lease is now active.
        // TODO: Change pending return to active later.
        lease.state = LeaseState.PENDING_RETURN;
    }

    /** 
     * @dev The tenant can withdraw the security deposit once the lease is complete.
     */
    function withdrawSecurityDeposit() payable public {
        require(msg.sender == tenant.addr, "Only tenent can withdraw security deposit.");
        require(lease.state == LeaseState.PENDING_RETURN, "The lease should be in pending return state.");

        // Withdraw security deposit.
        tenant.addr.transfer(lease.securityDeposit);

         // Security deposit is returned - the lease is now finished.
        lease.state = LeaseState.FINISHED;
    }

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
            // Both have agreed to the terms, set the lease state to pending deposit.
            lease.state = LeaseState.PENDING_DEPOSIT;
        }
    }

    /** 
     * @dev The tenant or landlord can revoke their agreement to the lease while the lease is inactive.
     */
    function unsignAgreement() public {
        require(msg.sender == landlord.addr || msg.sender == tenant.addr, "Only owner or tenent can unsign agreement.");
        require(lease.state == LeaseState.INACTIVE || lease.state == LeaseState.PENDING_DEPOSIT, "The lease should not have actived.");
        if(msg.sender == landlord.addr) {
            require (landlord.agrees == true, "Landlord has not signed the agreement yet.");
            landlord.agrees = false;
        }
        if (msg.sender == tenant.addr) {
            require (tenant.agrees == true, "Tenant has not signed the agreement yet.");
            tenant.agrees = false;
        }
        // Make it inactive - in case it was pending deposit, it no longer will.
        lease.state == LeaseState.INACTIVE;
    }

    /** 
     * @dev Set the terms for lease. Can be called by the tenant or the landlord while the lease is inactive.
     * @param rentAmount amount of rent in Wei
     * @param rentDuration length of lease agreement in months
     */
    function setTerms(uint256 rentAmount, uint256 rentDuration, uint256 securityDeposit) public {
        require(msg.sender == landlord.addr || msg.sender == tenant.addr, "Only owner or tenent can set terms.");
        require(lease.state == LeaseState.INACTIVE, "The lease has to be in inactive state to set terms.");

        // Set the terms of the lease
        lease.rentAmount = rentAmount;
        lease.rentalDuration = rentDuration;
        lease.securityDeposit = securityDeposit;
        
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
        tenant.addr = payable(tenantAddr);
        property.name = propertyName;
        property.location = propertyLocation;

        // Set the state of the contract to be inactive initally
        lease.state = LeaseState.INACTIVE;
    }
}
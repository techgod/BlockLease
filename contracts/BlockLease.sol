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
    enum LeaseState {INACTIVE, PENDING_DEPOSIT, ACTIVE, FINISHED}

    // Defines information about the lease
    struct Lease {
        LeaseState state;
        uint256 rentAmount;
        uint256 rentalDuration;
        uint startDate;
        uint256 latePenaltyPerDay;
        uint256 securityDeposit;
    }

    // Variables store information
    Landlord public landlord;
    Tenant public tenant;
    Property public property;
    Lease public lease;

    // Keeps track of current state
    uint8 public monthsRentPaid;


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
        monthsRentPaid = 0;
    }


    /** 
     * @dev Set the terms for lease. Can be called by the tenant or the landlord while the lease is inactive.
     * @param rentAmount amount of rent in Wei
     * @param rentalDuration length of lease agreement in months
     * @param startDate start date of the agreement (as a unix timestamp)
     * @param latePenaltyPerDay late penalty per day in Wei
     * @param securityDeposit security deposit in Wei 
     */
    function setTerms(uint256 rentAmount, uint256 rentalDuration, uint startDate, uint256 latePenaltyPerDay, uint256 securityDeposit) public {
        require(msg.sender == landlord.addr || msg.sender == tenant.addr, "Only owner or tenent can set terms.");
        require(lease.state == LeaseState.INACTIVE, "The lease has to be in inactive state to set terms.");

        // Set the terms of the lease
        lease.rentAmount = rentAmount;
        lease.rentalDuration = rentalDuration;
        lease.startDate = startDate;
        lease.latePenaltyPerDay = latePenaltyPerDay;
        lease.securityDeposit = securityDeposit;
        
        // If terms are updated, parties have to resign.
        landlord.agrees = false;
        tenant.agrees = false;
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
     * @dev The tenant can deposit money for the security deposit to activate the lease
     */
    function depositSecurityDeposit() payable public {
        require(msg.sender == tenant.addr, "Only tenent can send security deposit.");
        require(lease.state == LeaseState.PENDING_DEPOSIT, "The lease should be in pending deposit state.");
        require(msg.value == lease.securityDeposit, "The value being deposited should equal the security deposit amount.");

        // Security deposit is received - the lease is now active.
        lease.state = LeaseState.ACTIVE;
    }

    /**
     * @dev Handy function to calculate time since last rent
     */
    function findTimeSinceLastRent() private view returns (uint){
        // Find current date
        uint currDate = block.timestamp;
        
        // Find time since start
        uint res = currDate - lease.startDate;
        
        // Fast forward how many ever months of rent paid so far
        res -= (monthsRentPaid * (30 days));

        return res;
    }

    /**
     * @dev The tenant can deposit money for the security deposit to activate the lease
     */
    function payRent() payable public {
        require(msg.sender == tenant.addr, "Only tenent can send rent.");
        require(lease.state == LeaseState.ACTIVE, "The lease should be active to send rent.");
        require (monthsRentPaid < lease.rentalDuration, "The lease term is up - time to vacate the place.");

        uint timeSinceLastRent = findTimeSinceLastRent();

        uint256 netRentDue = lease.rentAmount;

        // Pay rent at the start of the month
        if (timeSinceLastRent <= 5 days) {
            // Five days grace period to pay rent
            // No penalty added
        } else if (timeSinceLastRent <= 5 days && timeSinceLastRent <= 30 days) {
            // Add late penalty
            uint daysLate = uint(timeSinceLastRent) / uint(1 days);
            netRentDue += (lease.latePenaltyPerDay * daysLate);
        } else if (timeSinceLastRent > 30 days) {
            // It's way too late
            // The contract is terminated with no return of security deposit
            lease.state = LeaseState.FINISHED;

            // Don't accept the current rent transaction
            require (timeSinceLastRent <= 30 days, "Lease has been terminated.");
        }

        require(msg.value == lease.rentAmount, "The value being sent should equal the rent amount (including late fees).");
        
        // A valid payment has taken place.
        // Now, let us update the months rent paid
        monthsRentPaid += 1;

        // Transfer rent amount to landlord
        landlord.addr.transfer(lease.rentAmount);
    }

    /**
     * @dev Called by landlord if the tenant hasn't met the terms of the lease 
     */
    function evict() public {
        require(msg.sender == landlord.addr, "Only the landlord can choose to evict.");
        require(lease.state == LeaseState.ACTIVE, "The lease should be active to start eviction process.");
        uint timeSinceLastRent = findTimeSinceLastRent();

        require(timeSinceLastRent > 30 days, "It has not been 30 days since the last rent.");

        if(monthsRentPaid == lease.rentalDuration) {
            // The lease is complete, transfer the security deposit
            tenant.addr.transfer(lease.securityDeposit);
        }

        lease.state = LeaseState.FINISHED;    
    }

    /**
     * @dev Called when the tenant wants to leave the house. This is provided the terms of the lease have been met.
     * Security deposit is transferred back
     */
    function vacate() public {
        require(msg.sender == tenant.addr, "Only the tenent can choose to vacate.");
        require(lease.state == LeaseState.ACTIVE, "The lease should be active to start vacate process.");
        require(monthsRentPaid == lease.rentalDuration, "The lease term has not yet completed.");

        // Transfer back the security deposit to tenant
        tenant.addr.transfer(lease.securityDeposit);
        lease.state = LeaseState.FINISHED;
    }
}